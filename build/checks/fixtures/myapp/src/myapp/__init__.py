from ctypes.util import find_library

def hello() -> None:
    # Used to test link-ctypes-hook
    libc = find_library("c")

    print("Hello from myapp!")
    print(f"Your libc: {libc}")
