{
  lib,
  pep440,
  pep508,
  ...
}:

let
  inherit (builtins) fromTOML;
  inherit (lib)
    concatStringsSep
    splitString
    elemAt
    match
    foldl'
    sublist
    head
    ;

  matchBegin = l: match " *# */// *script *" l != null;
  matchEnd = l: match " *# */// *" l != null;
  stripComment =
    l:
    let
      m = match " *# ?(.*)" l;
    in
    if match " *" l != null then
      l
    else if m != null then
      head m
    else
      throw "Invalid metadata line: ${l}";

  default = {
    requires-python = [ ];
    dependencies = [ ];
  };

in
{
  /*
    Parse the script metadata section from a PEP-723 script.

    Type: parseScript :: string -> AttrSet

    Example:
      # parseScript (readFile ./script.py)
      {
        requires-python = [ ];  # List of parsed version conditions (lib.pep440.parseVersionConds)
        dependencies = [ ];  # List of parsed PEP-508 strings (lib.pep508.parseString)
      }
  */
  parseScript =
    script:
    let
      lines = splitString "\n" script;

      # Find script metadata section line range
      range =
        foldl'
          (
            acc: line:
            # Most script lines are _not_ in the metadata section.
            # Only create scope/list if we're still searching for it.
            if (elemAt acc 0) >= 0 && (elemAt acc 1) >= 0 then
              acc
            else
              let
                begin = elemAt acc 0;
                end = elemAt acc 1;
                current = elemAt acc 2;
                next = current + 1;
              in
              if begin == (-1) && matchBegin line then
                [
                  current
                  end
                  next
                ]
              else if begin >= 0 && end == (-1) && matchEnd line then
                [
                  begin
                  current
                  next
                ]
              else
                [
                  begin
                  end
                  next
                ]
          )
          # Tuple-like (begin, end, current) for script section
          [
            (-1)
            (-1)
            0
          ]
          lines;

      begin = elemAt range 0;
      end = elemAt range 1;

      # Reassemble metadata string
      metadata' = concatStringsSep "\n" (map stripComment (sublist (begin + 1) (end - begin - 1) lines));
      # Structured metadata
      metadata = fromTOML metadata';

    in
    if end >= 0 then
      {
        requires-python = pep440.parseVersionConds (metadata.requires-python or "");
        dependencies = map pep508.parseString (metadata.dependencies or [ ]);
        inherit metadata;
      }
    else
      default;
}
