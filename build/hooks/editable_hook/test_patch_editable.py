import unittest

from editable_hook import patch_editable


class TestPatchEditable(unittest.TestCase):
    def test_py(self):
        with open("./fixtures/input.py") as fp:
            input = fp.read()

        with open("./fixtures/output.py") as fp:
            expected = fp.read()

        patched = patch_editable.patch_py("/build_dir", "$REPO_ROOT", input)
        self.assertTrue(patched.patched)
        self.assertEqual(expected, patched.code)

    def test_pth(self):
        with open("./fixtures/input.pth") as fp:
            input = fp.read()

        with open("./fixtures/output.pth") as fp:
            expected = fp.read()

        patched = patch_editable.patch_pth("/build_dir", "$REPO_ROOT", input)
        self.assertTrue(patched.patched)
        self.assertEqual(expected, patched.code)


if __name__ == "__main__":
    unittest.main()
