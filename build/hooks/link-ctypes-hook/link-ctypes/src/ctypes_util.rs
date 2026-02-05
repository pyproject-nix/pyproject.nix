use regex::Regex;
use memoize::memoize;
use std::fs::File;
use std::process::{Command, Stdio};
use tempfile::NamedTempFile;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::env;

// Contains utility functions ported from ctypes.util

const DEFAULT_FRAMEWORK_FALLBACK: &[&str] = &[
    "~/Library/Frameworks",
    "/Library/Frameworks",
    "/Network/Library/Frameworks",
    "/System/Library/Frameworks",
];

const DEFAULT_LIBRARY_FALLBACK: &[&str] = &[
    "~/lib",
    "/usr/local/lib",
    "/lib",
    "/usr/lib",
];

#[derive(Debug, Clone)]
pub struct FrameworkInfo {
    pub name: String,
}

fn expand_home(path: &str) -> String {
    if path.starts_with("~/") {
        if let Some(home) = env::var("HOME").ok() {
            return path.replacen("~", &home, 1);
        }
    }
    path.to_string()
}

fn is_elf(path: &PathBuf) -> bool {
    let mut file = match File::open(path) {
        Ok(f) => f,
        Err(_) => return false,
    };

    let mut magic = [0u8; 4];
    if file.read_exact(&mut magic).is_err() {
        return false;
    }

    magic == [0x7f, b'E', b'L', b'F']
}

// Ported from ctypes.util._findLib_gcc
fn find_lib_gcc(name: &str) -> Option<PathBuf> {
    let pattern = format!(r"[^\(\)\s]*lib{}\.[^\(\)\s]*", regex::escape(name));
    let re = Regex::new(&pattern).ok()?;

    // Use CC from environment for cross compilation
    let c_compiler = std::env::var("CC")
        .ok()
        .and_then(|cc| which::which(cc).ok())
        .or_else(|| which::which("gcc").ok())
        .or_else(|| which::which("cc").ok())?;

    let temp = NamedTempFile::new().ok()?;
    let temp_path = temp.path().to_path_buf();

    let args = vec![
        "-Wl,-t".to_string(),
        "-o".to_string(),
        temp_path.to_string_lossy().to_string(),
        format!("-l{}", name),
    ];

    let mut env_vars = env::vars().collect::<Vec<_>>();
    env_vars.retain(|(k, _)| k != "LC_ALL" && k != "LANG");
    env_vars.push(("LC_ALL".to_string(), "C".to_string()));
    env_vars.push(("LANG".to_string(), "C".to_string()));

    let output = Command::new(&c_compiler)
        .args(&args)
        .envs(env_vars)
        .stdout(Stdio::piped())
        // .stderr(Stdio::piped()) // Note: Original code outputs stderr to stdout
        .output()
        .ok()?;

    let trace = output.stdout;

    let trace_str = String::from_utf8_lossy(&trace);
    let matches: Vec<&str> = re.find_iter(&trace_str).map(|m| m.as_str()).collect();

    if matches.is_empty() {
        return None;
    }

    for file_str in matches {
        let file_path = PathBuf::from(file_str);
        if is_elf(&file_path) {
            return Some(file_path);
        }
    }

    None
}

// Ported from ctypes.util._findLib_ld
fn find_lib_ld(name: &str) -> Option<PathBuf> {
    let pattern = format!(r"[^\(\)\s]*lib{}\.[^\(\)\s]*", regex::escape(name));
    let re = Regex::new(&pattern).ok()?;

    let mut args = vec!["-t".to_string()];

    if let Ok(libpath) = env::var("LD_LIBRARY_PATH") {
        for dir in libpath.split(':') {
            if !dir.is_empty() {
                args.push("-L".to_string());
                args.push(dir.to_string());
            }
        }
    }

    args.push("-o".to_string());
    args.push("/dev/null".to_string());
    args.push(format!("-l{}", name));

    let output = Command::new("ld")
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .ok()?;

    let mut out = output.stdout;
    out.extend_from_slice(&output.stderr);
    let out_str = String::from_utf8_lossy(&out);

    let matches: Vec<&str> = re.find_iter(&out_str).map(|m| m.as_str()).collect();

    for file_str in matches {
        let file_path = PathBuf::from(file_str);
        if is_elf(&file_path) {
            return Some(file_path);
        }
    }

    None
}

fn framework_info(filename: &str) -> Option<FrameworkInfo> {
    let parts: Vec<&str> = filename.split('/').collect();

    for (_, part) in parts.iter().enumerate() {
        if part.ends_with(".framework") {
            return Some(FrameworkInfo {
                name: part.to_string(),
            });
        }
    }
    None
}

fn dyld_env(var: &str) -> Vec<String> {
    env::var(var)
        .ok()
        .map(|val| val.split(':').map(|s| s.to_string()).collect())
        .unwrap_or_default()
}

fn dyld_fallback_framework_path() -> Vec<String> {
    let env_paths = dyld_env("DYLD_FALLBACK_FRAMEWORK_PATH");
    if !env_paths.is_empty() {
        env_paths
    } else {
        Vec::new()
    }
}

fn dyld_fallback_library_path() -> Vec<String> {
    let env_paths = dyld_env("DYLD_FALLBACK_LIBRARY_PATH");
    if !env_paths.is_empty() {
        env_paths
    } else {
        Vec::new()
    }
}

fn dyld_framework_search(name: &str) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    let framework = framework_info(name);

    if let Some(ref fw) = framework {
        for path in dyld_env("DYLD_FRAMEWORK_PATH") {
            paths.push(PathBuf::from(expand_home(&path)).join(&fw.name));
        }
    }

    paths
}

fn dyld_library_search(name: &str) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    let basename = Path::new(name).file_name().unwrap_or_default().to_string_lossy();

    for path in dyld_env("DYLD_LIBRARY_PATH") {
        paths.push(PathBuf::from(expand_home(&path)).join(basename.as_ref()));
    }

    paths
}

fn dyld_executable_path_search(name: &str, executable_path: Option<&str>) -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if name.starts_with("@executable_path/") {
        if let Some(exec_path) = executable_path {
            let relative = &name["@executable_path/".len()..];
            paths.push(PathBuf::from(exec_path).join(relative));
        }
    }

    paths
}

fn dyld_loader_search(name: &str, loader_path: Option<&str>) -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if name.starts_with("@loader_path/") {
        if let Some(load_path) = loader_path {
            let relative = &name["@loader_path/".len()..];
            paths.push(PathBuf::from(load_path).join(relative));
        }
    }

    paths
}

fn dyld_default_search(name: &str) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    paths.push(PathBuf::from(name));

    let framework = framework_info(name);

    if let Some(ref fw) = framework {
        let fallback_fw = dyld_fallback_framework_path();

        if !fallback_fw.is_empty() {
            for path in &fallback_fw {
                paths.push(PathBuf::from(expand_home(path)).join(&fw.name));
            }
        } else {
            for path in DEFAULT_FRAMEWORK_FALLBACK {
                paths.push(PathBuf::from(expand_home(path)).join(&fw.name));
            }
        }
    }

    let fallback_lib = dyld_fallback_library_path();
    let basename = Path::new(name).file_name().unwrap_or_default().to_string_lossy();

    if !fallback_lib.is_empty() {
        for path in &fallback_lib {
            paths.push(PathBuf::from(expand_home(path)).join(basename.as_ref()));
        }
    } else {
        for path in DEFAULT_LIBRARY_FALLBACK {
            paths.push(PathBuf::from(expand_home(path)).join(basename.as_ref()));
        }
    }

    paths
}

fn apply_image_suffix(paths: Vec<PathBuf>) -> Vec<PathBuf> {
    if let Some(suffix) = env::var("DYLD_IMAGE_SUFFIX").ok() {
        let mut result = Vec::new();
        for path in paths {
            if let Some(ext) = path.extension() {
                let stem = path.file_stem().unwrap().to_string_lossy();
                let parent = path.parent().unwrap_or(Path::new(""));
                let new_name = format!("{}{}.{}", stem, suffix, ext.to_string_lossy());
                result.push(parent.join(new_name));
            }
            result.push(path);
        }
        result
    } else {
        paths
    }
}

pub fn dyld_find(
    name: &str,
    executable_path: Option<&str>,
    loader_path: Option<&str>,
) -> Result<PathBuf, String> {
    let mut all_paths = Vec::new();
    all_paths.extend(dyld_executable_path_search(name, executable_path));
    all_paths.extend(dyld_loader_search(name, loader_path));
    all_paths.extend(dyld_framework_search(name));
    all_paths.extend(dyld_library_search(name));
    all_paths.extend(dyld_default_search(name));
    all_paths = apply_image_suffix(all_paths);

    for path in all_paths {
        if path.exists() {
            return Ok(path);
        }
    }

    Err(format!("dyld: Library not loaded: {}", name))
}

#[memoize(SharedCache)]
pub fn find_library_posix(name: String) -> Option<PathBuf> {
    if let Some(lib) = find_lib_gcc(&name) {
        Some(lib)
    } else {
        find_lib_ld(&name)
    }
}

#[memoize(SharedCache)]
pub fn find_library_darwin(name: String) -> Option<PathBuf> {
    let possible_names = vec![
        format!("lib{}.dylib", name),
        format!("{}.dylib", name),
        format!("{}.framework/{}", name, name),
    ];

    for variant in possible_names {
        if let Ok(path) = dyld_find(&variant, None, None) {
            return Some(path);
        }
    }

    None
}
