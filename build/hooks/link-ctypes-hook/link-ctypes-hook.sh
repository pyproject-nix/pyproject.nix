pyprojectLinkCtypesHook() {
  @linkCtypes@/bin/link-ctypes @linkCtypesFlags@ --dir "$out" $linkCtypesFlags
}

if [ -z "${dontLinkPyprojectCtypes-}" ]; then
  preFixupPhases+=" pyprojectLinkCtypesHook"
fi
