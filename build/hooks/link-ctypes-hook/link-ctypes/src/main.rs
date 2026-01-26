mod ctypes_util;

use ruff_python_ast::{Expr, ExprAttribute, ExprCall, Stmt, StmtImport, StmtImportFrom};
use ruff_python_parser::parse_module;
use ruff_text_size::{Ranged, TextRange, TextSize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread;
use walkdir::WalkDir;
use ctypes_util::{find_library_posix, find_library_darwin};

#[derive(Debug)]
struct Config {
    jobs: usize,
    allow_lib_fail: Vec<String>,
    ignore_path: Vec<String>,
    dir: String,
    mode: String,
}

#[derive(Debug, Clone)]
struct Scope {
    // Maps name -> (module, original_name)
    // e.g., "find_library" -> ("ctypes.util", "find_library")
    bindings: HashMap<String, (String, String)>,
    // Maps variable name -> string constant value
    // e.g., "LIB_NAME" -> "c"
    constants: HashMap<String, String>,
}

struct Replacer {
    source: String,
    replacements: Vec<(TextRange, String)>,
    scopes: Vec<Scope>,
    allow_lib_fail: Vec<String>,
    find_library: Box<dyn Fn(String) -> Option<PathBuf>>,
}

impl Scope {
    fn new() -> Self {
        Scope {
            bindings: HashMap::new(),
            constants: HashMap::new(),
        }
    }

    fn add_binding(&mut self, name: String, module: String, original: String) {
        self.bindings.insert(name, (module, original));
    }

    fn lookup(&self, name: &str) -> Option<&(String, String)> {
        self.bindings.get(name)
    }

    fn add_constant(&mut self, name: String, value: String) {
        self.constants.insert(name, value);
    }

    fn get_constant(&self, name: &str) -> Option<&String> {
        self.constants.get(name)
    }
}

impl Replacer {
    fn new(source: String, mode: &String, allow_lib_fail: Vec<String>) -> Self {
        let find_library = Box::new(match mode.as_str() {
            "posix" => find_library_posix,
            "darwin" => find_library_darwin,
            _ => find_library_posix,
        });

        Replacer {
            source,
            replacements: Vec::new(),
            scopes: vec![Scope::new()],
            allow_lib_fail,
            find_library,
        }
    }

    fn push_scope(&mut self) {
        let parent = self.scopes.last().unwrap().clone();
        self.scopes.push(parent);
    }

    fn pop_scope(&mut self) {
        self.scopes.pop();
    }

    fn current_scope_mut(&mut self) -> &mut Scope {
        self.scopes.last_mut().unwrap()
    }

    fn current_scope(&self) -> &Scope {
        self.scopes.last().unwrap()
    }

    fn process_import(&mut self, stmt: &StmtImport) {
        for alias in &stmt.names {
            let module = alias.name.as_str();
            let asname = alias
                .asname
                .as_ref()
                .map(|id| id.as_str())
                .unwrap_or(module);

            // Track ctypes imports
            if module == "ctypes" || module.starts_with("ctypes.") {
                self.current_scope_mut().add_binding(
                    asname.to_string(),
                    module.to_string(),
                    module.to_string(),
                );
            }
        }
    }

    fn process_import_from(&mut self, stmt: &StmtImportFrom) {
        if let Some(module) = &stmt.module {
            let module_str = module.as_str();

            for alias in &stmt.names {
                let name = alias.name.as_str();
                let asname = alias.asname.as_ref().map(|id| id.as_str()).unwrap_or(name);

                // Track imports from ctypes modules
                if module_str == "ctypes"
                    || module_str == "ctypes.util"
                    || module_str == "ctypes.cdll"
                {
                    self.current_scope_mut().add_binding(
                        asname.to_string(),
                        module_str.to_string(),
                        name.to_string(),
                    );
                } else {
                    // For non-ctypes imports, mark them as shadowed by adding a dummy binding
                    // This prevents later ctypes imports with the same name from being used
                    self.current_scope_mut().add_binding(
                        asname.to_string(),
                        "non-ctypes".to_string(),
                        name.to_string(),
                    );
                }
            }
        }
    }

    fn check_shadowing(&mut self, stmt: &Stmt) {
        // Check for function/class definitions that shadow names
        match stmt {
            Stmt::FunctionDef(func) => {
                let name = func.name.as_str();
                // Shadow by removing from current scope
                self.current_scope_mut().bindings.remove(name);
            }
            Stmt::ClassDef(class) => {
                let name = class.name.as_str();
                self.current_scope_mut().bindings.remove(name);
            }
            _ => {}
        }
    }

    fn get_string_value(&self, expr: &Expr) -> Option<String> {
        match expr {
            Expr::StringLiteral(string_lit) => {
                for part in &string_lit.value {
                    let prefix_str = format!("{:?}", part.flags.prefix());
                    if prefix_str.contains('F') || prefix_str.to_lowercase().contains("format") {
                        return None;
                    }
                }
                Some(string_lit.value.iter().map(|part| part.as_str()).collect())
            }
            Expr::Name(name) => match self.current_scope().get_constant(name.id.as_str()) {
                Some(value) => Some(value.to_string()),
                _ => None,
            },
            _ => None,
        }
    }

    fn is_string_literal_or_tracked_constant(&self, expr: &Expr) -> bool {
        match expr {
            Expr::StringLiteral(string_lit) => {
                let is_fstring = string_lit.value.iter().any(|part| {
                    let prefix_str = format!("{:?}", part.flags.prefix());
                    prefix_str.contains('F') || prefix_str.to_lowercase().contains("format")
                });
                !is_fstring
            }
            Expr::Name(name) => self
                .current_scope()
                .get_constant(name.id.as_str())
                .is_some(),
            _ => false,
        }
    }

    fn process_call(&mut self, call: &ExprCall) -> Result<bool, String> {
        let mut replaced = false;

        match call.func.as_ref() {
            Expr::Name(name) => {
                let func_name = name.id.as_str();

                if let Some((module, original)) = self.current_scope().lookup(func_name) {
                    if module == "ctypes.util" && original == "find_library" {
                        replaced = self.replace_call(call)?;
                    } else if module == "ctypes" && original == "CDLL" {
                        replaced = self.replace_call_arg(call)?;
                    } else if module == "ctypes.cdll" && original == "LoadLibrary" {
                        replaced = self.replace_call_arg(call)?;
                    }
                }
            }
            Expr::Attribute(attr) => {
                replaced = self.process_attribute_call(call, attr)?;
            }
            _ => {}
        }

        // Only recursively process arguments if we didn't replace the entire call
        if !replaced || !self.is_find_library_call(call) {
            for arg in &call.arguments.args {
                replaced |= self.visit_expr(arg)?;
            }
            for keyword in &call.arguments.keywords {
                replaced |= self.visit_expr(&keyword.value)?;
            }
        }

        Ok(replaced)
    }

    fn process_attribute_call(
        &mut self,
        call: &ExprCall,
        attr: &ExprAttribute,
    ) -> Result<bool, String> {
        let attr_name = attr.attr.as_str();

        let full_path = self.build_attribute_path(&attr.value, attr_name);

        if self.matches_path(&full_path, "ctypes.util.find_library") {
            self.replace_call(call)
        } else if self.matches_path(&full_path, "ctypes.CDLL") {
            self.replace_call_arg(call)
        } else if self.matches_path(&full_path, "ctypes.cdll.LoadLibrary") {
            self.replace_call_arg(call)
        } else {
            Ok(false)
        }
    }

    fn build_attribute_path(&self, expr: &Expr, final_attr: &str) -> Vec<String> {
        let mut parts = Vec::new();
        self.collect_attribute_parts(expr, &mut parts);
        parts.push(final_attr.to_string());
        parts
    }

    fn collect_attribute_parts(&self, expr: &Expr, parts: &mut Vec<String>) {
        match expr {
            Expr::Name(name) => {
                parts.insert(0, name.id.to_string());
            }
            Expr::Attribute(attr) => {
                self.collect_attribute_parts(&attr.value, parts);
                parts.push(attr.attr.to_string());
            }
            _ => {}
        }
    }

    fn matches_path(&self, path: &[String], target: &str) -> bool {
        let target_parts: Vec<&str> = target.split('.').collect();

        if path.len() != target_parts.len() {
            return false;
        }

        // Check if the first part is a known ctypes import
        if let Some((module, _)) = self.current_scope().lookup(&path[0]) {
            // Resolve the full path
            let mut resolved = vec![module.clone()];
            resolved.extend(path[1..].iter().map(|s| s.to_string()));

            let resolved_str = resolved.join(".");
            return resolved_str == target;
        }

        // Check direct match
        path.iter().map(|s| s.as_str()).collect::<Vec<_>>() == target_parts
    }

    fn is_find_library_call(&self, call: &ExprCall) -> bool {
        match call.func.as_ref() {
            Expr::Name(name) => {
                let func_name = name.id.as_str();
                if let Some((module, original)) = self.current_scope().lookup(func_name) {
                    return module == "ctypes.util" && original == "find_library";
                }
            }
            Expr::Attribute(attr) => {
                let attr_name = attr.attr.as_str();
                let full_path = self.build_attribute_path(&attr.value, attr_name);
                return self.matches_path(&full_path, "ctypes.util.find_library");
            }
            _ => {}
        }
        false
    }

    fn replace_expr(&mut self, range: TextRange, call: &ExprCall) -> Result<bool, String> {
        let first_arg = &call.arguments.args[0];
        let lib_name = self.get_string_value(first_arg).unwrap();

        match (self.find_library)(lib_name.clone()) {
            Some(lib_path) => {
                let formatted = format!("\"{}\"", lib_path.to_str().unwrap());
                self.replacements.push((range, formatted));
                return Ok(true);
            }
            None => {
                // Lookup failed, check if failure is allowed
                if self.allow_lib_fail.iter().any(|e| *e == lib_name) {
                    return Ok(false)
                }


                return Err(format!("lookup of library '{}' failed", lib_name.as_str()).to_string());
            }
        }
    }

    fn replace_call(&mut self, call: &ExprCall) -> Result<bool, String> {
        if !call.arguments.args.is_empty()
            && self.is_string_literal_or_tracked_constant(&call.arguments.args[0])
        {
            return self.replace_expr(call.range(), call);
        }

        Ok(false)
    }

    fn replace_call_arg(&mut self, call: &ExprCall) -> Result<bool, String> {
        if !call.arguments.args.is_empty()
            && self.is_string_literal_or_tracked_constant(&call.arguments.args[0])
        {
            let first_arg = &call.arguments.args[0];
            return self.replace_expr(first_arg.range(), call);
        }

        Ok(false)
    }

    fn visit_stmt(&mut self, stmt: &Stmt) -> Result<bool, String> {
        let mut replaced = false;

        match stmt {
            Stmt::Import(import) => self.process_import(import),
            Stmt::ImportFrom(import_from) => self.process_import_from(import_from),
            Stmt::FunctionDef(func) => {
                self.check_shadowing(stmt);
                self.push_scope();
                for s in &func.body {
                    replaced |= self.visit_stmt(s)?;
                }
                self.pop_scope();
            }
            Stmt::ClassDef(class) => {
                self.check_shadowing(stmt);
                self.push_scope();
                for s in &class.body {
                    replaced |= self.visit_stmt(s)?;
                }
                self.pop_scope();
            }
            Stmt::Expr(expr_stmt) => {
                replaced = self.visit_expr(&expr_stmt.value)?;
            }
            Stmt::Assign(assign) => {
                // Track string constant assignments _before_ visiting the expression
                if assign.targets.len() == 1 {
                    if let Expr::Name(name) = &assign.targets[0] {
                        if let Some(value) = self.get_string_value(&assign.value) {
                            self.current_scope_mut()
                                .add_constant(name.id.to_string(), value);
                        }
                    }
                }
                // Visit the expression to handle nested calls
                replaced = self.visit_expr(&assign.value)?;
            }
            Stmt::AnnAssign(ann_assign) => {
                if let Expr::Name(name) = ann_assign.target.as_ref() {
                    if let Some(value) = &ann_assign.value {
                        if let Some(str_value) = self.get_string_value(value) {
                            self.current_scope_mut()
                                .add_constant(name.id.to_string(), str_value);
                        }
                    }
                }
                if let Some(value) = &ann_assign.value {
                    replaced = self.visit_expr(value)?;
                }
            }
            Stmt::If(if_stmt) => {
                replaced |= self.visit_expr(&if_stmt.test)?;
                for s in &if_stmt.body {
                    replaced |= self.visit_stmt(s)?;
                }
                for s in &if_stmt.elif_else_clauses {
                    if let Some(test) = &s.test {
                        replaced |= self.visit_expr(test)?;
                    }
                    for stmt in &s.body {
                        replaced |= self.visit_stmt(stmt)?;
                    }
                }
            }
            Stmt::While(while_stmt) => {
                replaced |= self.visit_expr(&while_stmt.test)?;
                for s in &while_stmt.body {
                    replaced |= self.visit_stmt(s)?;
                }
                for s in &while_stmt.orelse {
                    replaced |= self.visit_stmt(s)?;
                }
            }
            Stmt::For(for_stmt) => {
                replaced |= self.visit_expr(&for_stmt.iter)?;
                for s in &for_stmt.body {
                    replaced |= self.visit_stmt(s)?;
                }
                for s in &for_stmt.orelse {
                    replaced |= self.visit_stmt(s)?;
                }
            }
            Stmt::With(with_stmt) => {
                for item in &with_stmt.items {
                    replaced |= self.visit_expr(&item.context_expr)?;
                }
                for s in &with_stmt.body {
                    replaced |= self.visit_stmt(s)?;
                }
            }
            Stmt::Try(try_stmt) => {
                for s in &try_stmt.body {
                    replaced |= self.visit_stmt(s)?;
                }
                for handler in &try_stmt.handlers {
                    let ruff_python_ast::ExceptHandler::ExceptHandler(eh) = handler;
                    for s in &eh.body {
                        replaced |= self.visit_stmt(s)?;
                    }
                }
                for s in &try_stmt.orelse {
                    replaced |= self.visit_stmt(s)?;
                }
                for s in &try_stmt.finalbody {
                    replaced |= self.visit_stmt(s)?;
                }
            }
            _ => {}
        }

        Ok(replaced)
    }

    fn visit_expr(&mut self, expr: &Expr) -> Result<bool, String> {
        match expr {
            Expr::Call(call) => self.process_call(call),
            Expr::BinOp(binop) => {
                let mut replaced = self.visit_expr(&binop.left)?;
                replaced |= self.visit_expr(&binop.right)?;
                Ok(replaced)
            }
            Expr::UnaryOp(unary) => self.visit_expr(&unary.operand),
            Expr::Lambda(lambda) => self.visit_expr(&lambda.body),
            Expr::If(if_expr) => {
                let mut replaced = self.visit_expr(&if_expr.test)?;
                replaced |= self.visit_expr(&if_expr.body)?;
                replaced |= self.visit_expr(&if_expr.orelse)?;
                Ok(replaced)
            }
            Expr::List(list) => {
                let mut replaced = false;
                for e in &list.elts {
                    replaced |= self.visit_expr(e)?;
                }
                Ok(replaced)
            }
            Expr::Tuple(tuple) => {
                let mut replaced = false;
                for e in &tuple.elts {
                    replaced |= self.visit_expr(e)?;
                }
                Ok(replaced)
            }
            Expr::Dict(dict) => {
                let mut replaced = false;
                for item in &dict.items {
                    if let Some(key) = &item.key {
                        replaced |= self.visit_expr(key)?;
                    }
                    replaced |= self.visit_expr(&item.value)?;
                }
                Ok(replaced)
            }
            Expr::Set(set) => {
                let mut replaced = false;
                for e in &set.elts {
                    replaced |= self.visit_expr(e)?;
                }
                Ok(replaced)
            }
            Expr::ListComp(comp) => self.visit_expr(&comp.elt),
            Expr::SetComp(comp) => self.visit_expr(&comp.elt),
            Expr::DictComp(comp) => {
                let mut replaced = self.visit_expr(&comp.key)?;
                replaced |= self.visit_expr(&comp.value)?;
                Ok(replaced)
            }
            _ => Ok(false),
        }
    }

    fn apply_replacements(self) -> String {
        if self.replacements.is_empty() {
            return self.source;
        }

        let mut replacements = self.replacements;

        // Sort by start position, then by length (prefer smaller/inner replacements)
        replacements.sort_by(|(range_a, _), (range_b, _)| {
            match range_a.start().cmp(&range_b.start()) {
                std::cmp::Ordering::Equal => range_a.len().cmp(&range_b.len()),
                other => other,
            }
        });

        // Remove overlapping replacements, keeping inner ones
        let mut filtered_replacements = Vec::new();
        for (range, replacement) in replacements {
            let overlaps =
                filtered_replacements
                    .iter()
                    .any(|(prev_range, _): &(TextRange, String)| {
                        // Check if ranges overlap
                        range.intersect(*prev_range).is_some()
                    });

            if !overlaps {
                filtered_replacements.push((range, replacement));
            }
        }

        let mut result = String::new();
        let mut last_pos = TextSize::new(0);

        for (range, replacement) in filtered_replacements {
            result.push_str(&self.source[usize::from(last_pos)..usize::from(range.start())]);
            result.push_str(&replacement);
            last_pos = range.end();
        }

        result.push_str(&self.source[usize::from(last_pos)..]);
        result
    }
}

fn patch_python_file(path: &Path, mode: &String, allow_lib_fail: &Vec<String>) -> io::Result<()> {
    let source = fs::read_to_string(path)?;
    let parsed =
        parse_module(&source).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

    let mut replacer = Replacer::new(source.to_string(), mode, allow_lib_fail.clone());

    let mut replaced = false;
    for stmt in parsed.suite() {
        replaced |= replacer.visit_stmt(stmt).expect("Failed to replace");
    }
    if !replaced {
        return Ok(());
    }

    let patched = replacer.apply_replacements();
    fs::write(path, patched)?;

    Ok(())
}

fn patch_python_files(
    files: Vec<PathBuf>,
    workers: usize,
    mode: &String,
    allow_lib_fail: &Vec<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let files = Arc::new(Mutex::new(files.into_iter()));
    let errors = Arc::new(Mutex::new(Vec::new()));
    let mut handles = Vec::new();

    for _ in 0..workers {
        let files_clone = Arc::clone(&files);
        let errors_clone = Arc::clone(&errors);

        let allow_lib_fail = allow_lib_fail.clone();
        let mode = mode.clone();
        let handle = thread::spawn(move || loop {
            let file = {
                let mut files = files_clone.lock().unwrap();
                files.next()
            };

            match file {
                Some(path) => {
                    if let Err(e) = patch_python_file(&path, &mode, &allow_lib_fail) {
                        errors_clone.lock().unwrap().push(format!(
                            "Error processing {}: {}",
                            path.display(),
                            e
                        ));
                    }
                }
                None => break,
            }
        });

        handles.push(handle);
    }

    for handle in handles {
        handle.join().unwrap();
    }

    let errors = errors.lock().unwrap();
    if !errors.is_empty() {
        let summary = format!(
            "{} file(s) failed to process:\n{}",
            errors.len(),
            errors.join("\n")
        );
        return Err(summary.into());
    }

    Ok(())
}

fn parse_args() -> Result<Config, String> {
    let args: Vec<String> = env::args().collect();

    let mut jobs: Option<usize> = None;
    let mut allow_lib_fail: Vec<String> = Vec::new();
    let mut ignore_path: Vec<String> = Vec::new();
    let mut dir: Option<String> = None;
    let mut mode: Option<String> = None;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--jobs" => {
                i += 1;
                if i >= args.len() {
                    return Err("--jobs requires a value".to_string());
                }
                jobs = Some(
                    args[i]
                        .parse()
                        .map_err(|_| format!("Invalid value for --jobs: {}", args[i]))?,
                );
            }
            "--allow-lib-fail" => {
                i += 1;
                if i >= args.len() {
                    return Err("--allow-fail requires a value".to_string());
                }
                allow_lib_fail.push(args[i].clone());
            }
            "--ignore-path" => {
                i += 1;
                if i >= args.len() {
                    return Err("--ignore requires a value".to_string());
                }
                ignore_path.push(args[i].clone());
            }
            "--dir" => {
                i += 1;
                if i >= args.len() {
                    return Err("--dir requires a value".to_string());
                }
                dir = Some(args[i].clone());
            }
            "--mode" => {
                i += 1;
                if i >= args.len() {
                    return Err("--mode requires a value".to_string());
                }
                mode = Some(args[i].clone());
            }
            flag => {
                return Err(format!("Unknown flag: {}", flag));
            }
        }
        i += 1;
    }

    let jobs = jobs
        .or_else(|| {
            env::var("NIX_BUILD_CORES")
                .ok()
                .and_then(|s| s.parse().ok())
        })
        .unwrap_or(4);

    let dir = dir.ok_or("--dir is required")?;

    let mode = mode.ok_or("--mode is required")?;
    match mode.as_str() {
        "posix" => { },
        "darwin" => { },
        _ => {
            return Err("Only posix or darwin are valid operational modes".to_string())
        },
    }

    Ok(Config {
        jobs,
        allow_lib_fail,
        ignore_path,
        dir,
        mode,
    })
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    match parse_args() {
        Ok(config) => {
            let root_path = std::path::absolute(Path::new(config.dir.as_str())).unwrap();
            if !root_path.exists() {
                eprintln!("Error: Directory '{}' does not exist", config.dir);
                std::process::exit(1);
            }

            let root_path_prefix = root_path.to_str().unwrap().to_string() + "/";

            let files: Vec<PathBuf> = WalkDir::new(root_path.clone())
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| {
                    let rel = e.path().to_str().unwrap().strip_prefix(&root_path_prefix).unwrap_or("");
                    ! config.ignore_path.iter().any(|ignored_path| rel.starts_with(ignored_path))
                })
                .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("py"))
                .map(|e| e.path().to_path_buf())
                .collect();

            if !files.is_empty() {
                patch_python_files(files, config.jobs, &config.mode, &config.allow_lib_fail)?;
            }

            Ok(())
        }
        Err(e) => {
            eprintln!("Error: {}\n", e);
            eprintln!("Usage: {} [OPTIONS]\n", env::args().next().unwrap());
            eprintln!("Options:");
            eprintln!("  --dir <PATH>            Path to directory (required)");
            eprintln!(
                "  --jobs <N>              Number of workers (default: NIX_BUILD_CORES or 4)"
            );
            eprintln!("  --allow-fail <STRING>   Add to allow-fail list (can be repeated)");
            eprintln!("  --ignore <STRING>       Add to ignore list (can be repeated)");
            eprintln!("  --mode <STRING>         Operational mode (valid: posix, darwin)");
            std::process::exit(1);
        }
    }
}
