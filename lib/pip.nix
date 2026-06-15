{ lib, pep508, ... }:
let
  inherit (builtins)
    match
    head
    tail
    typeOf
    split
    filter
    elemAt
    genList
    length
    concatMap
    readFile
    dirOf
    hasContext
    unsafeDiscardStringContext
    ;
  inherit (import ./lib.nix) stripStr;

  uncomment = l: head (match " *([^#]*).*" l);

in
lib.fix (self: {

  /*
    Parse dependencies from requirements.txt

    Type: parseRequirementsTxt :: AttrSet -> list

    Example:
    # parseRequirements ./requirements.txt
    [ { flags = []; requirement = {}; # Returned by pep508.parseString } ]
  */

  parseRequirementsTxt =
    let
      # A line ending in a backslash continues onto the next one.
      matchCont = match "(.+) *\\\\";

      stripLine =
        l':
        let
          m = matchCont l';
        in
        stripStr (if m != null then (head m) else l');
    in
    # The contents of or path to requirements.txt
    requirements:
    let
      # Paths are either paths or strings with context.
      # Preferably we'd just use paths but because of
      #
      # $ ./. + requirements
      # "a string that refers to a store path cannot be appended to a path"
      #
      # We also need to support stringly paths...
      isPath = typeOf requirements == "path" || hasContext requirements;
      path' = if isPath then requirements else /. + unsafeDiscardStringContext requirements;
      root = dirOf path';

      # Requirements without comments and no empty strings
      requirements' = if isPath then readFile path' else requirements;
      lines' = filter (l: l != "") (
        map uncomment (filter (l: typeOf l == "string") (split "\n" requirements'))
      );

      endIdxs = concatMap (
        i: if matchCont (elemAt lines' i) != null then [ ] else [ i ]
      ) (genList (i: i) (length lines'));

      lines = genList (
        i:
        let
          end = elemAt endIdxs i;
          start = if i == 0 then 0 else (elemAt endIdxs (i - 1)) + 1;
        in
        genList (k: stripLine (elemAt lines' (start + k))) (end - start + 1)
      ) (length endIdxs);

    in
    concatMap (
      l:
      let
        m = match "-(c|r) (.+)" (head l);
      in
      # Common case, parse string
      if m == null then
        [
          {
            requirement = pep508.parseString (head l);
            flags = tail l;
          }
        ]

      # Don't support constraint files
      else if (head m) == "c" then
        throw "Unsupported flag: -c"

      # Recursive requirements.txt
      else
        (self.parseRequirementsTxt (
          if root == null then
            throw "When importing recursive requirements.txt requirements needs to be passed as a path"
          else
            root + "/${head (tail m)}"
        ))
    ) lines;
})
