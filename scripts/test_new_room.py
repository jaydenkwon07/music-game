import unittest
from new_room import scaffold
from lint_rooms import lint_room


class Scaffold(unittest.TestCase):
    def test_scaffold_is_lint_clean(self):
        data = scaffold("room_probe", 32, 18)
        self.assertEqual(data["size_tiles"], [32, 18])
        errors, _ = lint_room(data)
        self.assertEqual(errors, [])           # warnings (rock %) allowed

    def test_scaffold_has_spawn_on_floor(self):
        data = scaffold("room_probe", 20, 12)
        sx, sy = data["entries"]["spawn"]
        self.assertEqual(data["grid"][sy][sx], ".")


if __name__ == "__main__":
    unittest.main()
