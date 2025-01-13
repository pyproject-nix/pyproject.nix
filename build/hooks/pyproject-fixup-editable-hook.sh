pyprojectFixupEditableHook() {
  @editableHook@/bin/patch-editable
}

if [ -z "${dontUsePyprojectEditableFixup-}" ]; then
  preFixupPhases+=" pyprojectFixupEditableHook"
fi
