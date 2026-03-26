# Small utilities for internal reuse, not exposed externally
let
  inherit (builtins)
    filter
    match
    split
    head
    isString
    genList
    elemAt
    length
    fromJSON
    isInt
    ;

in
rec {
  isEmptyStr = s: isString s && match " *" s == null;

  splitComma = s: if s == "" then [ ] else filter isEmptyStr (split " *, *" s);

  # Like lib.sublist but stricter about length
  sublist' = offset: len: list: genList (i: elemAt list (offset + i)) len;

  # Like builtins.tail but with a starting offset
  tailAt = n: list: let len = length list; in genList (i: elemAt list (i + n)) (len - n);

  # Like lib.toInt but with less sanity checking
  toInt = s: let value = fromJSON s; in assert isInt value; value;

  stripStr =
    s:
    let
      t = match "[\t ]*(.*[^\t ])[\t ]*" s;
    in
    if t == null then "" else head t;
}
