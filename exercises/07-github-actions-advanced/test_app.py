import unittest

from app import greet


class TestGreet(unittest.TestCase):
    def test_named_greeting(self):
        self.assertEqual(greet("Osama"), "Hello, Osama!")

    def test_blank_falls_back_to_world(self):
        self.assertEqual(greet("   "), "Hello, world!")

    def test_none_falls_back_to_world(self):
        self.assertEqual(greet(None), "Hello, world!")


if __name__ == "__main__":
    unittest.main()
