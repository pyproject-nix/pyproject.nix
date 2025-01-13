print(
    '/build_dir/build/cp312',
    "/build_dir/build/cp312",
    '''/build_dir/build/cp312''',
    """/build_dir/build/cp312""",
    b'/build_dir/build/cp312',
    b"/build_dir/build/cp312",
    r'/build_dir/build/cp312',
    r"/build_dir/build/cp312",
    rB'''/build_dir/build/cp312''',
)

# Comment, not patched
#     '/build_dir/build/cp312',


def foo():
    """Look ma, not patched"""

    # This case is tricky to patch correctly, so we don't try
    x = r"also /build_dir/build/cp312 not patched"
    print(x)
