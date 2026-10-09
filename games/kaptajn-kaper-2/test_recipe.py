"""Isolated recipe tests; never touches the real runtime."""
import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile
import runner


class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.archive = self.root / 'fixture.zip'
        with zipfile.ZipFile(self.archive, 'w') as z:
            for name in runner.FILES:
                z.writestr(name, ('fixture:' + name).encode())
        self.sha = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.game = self.root / 'game'

    def test_extract_and_preserve_mutable(self):
        runner.extract(self.archive, self.game, self.sha)
        self.assertEqual(set(p.name for p in self.game.iterdir()), set(runner.FILES))
        for name in runner.MUTABLE:
            (self.game / name).write_bytes(b'user data')
        runner.extract(self.archive, self.game, self.sha)
        for name in runner.MUTABLE:
            self.assertEqual((self.game / name).read_bytes(), b'user data')

    def test_checksum_before_writes(self):
        with self.assertRaises(ValueError):
            runner.extract(self.archive, self.game)
        self.assertFalse(self.game.exists())

    def test_missing_member_before_writes(self):
        with zipfile.ZipFile(self.archive, 'w') as z:
            z.writestr('KAPER.EXE', b'fixture')
        sha = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        with self.assertRaises(KeyError):
            runner.extract(self.archive, self.game, sha)
        self.assertFalse(self.game.exists())

    def test_symlink_rejected(self):
        self.game.mkdir()
        outside = self.root / 'outside'
        outside.write_bytes(b'unchanged')
        (self.game / 'KAPER.EXE').symlink_to(outside)
        with self.assertRaises(ValueError):
            runner.extract(self.archive, self.game, self.sha)
        self.assertEqual(outside.read_bytes(), b'unchanged')


if __name__ == '__main__':
    unittest.main()
