"""Test AppRun's writable-state contract without copyrighted game files."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class AppRunTests(unittest.TestCase):
    def test_seed_is_writable_preserved_and_disc_is_remapped(self):
        with tempfile.TemporaryDirectory(prefix='gys test ') as tmp:
            root = Path(tmp)
            app = root / 'first.AppDir'
            for d in ('game/GAME', 'game/CDROM', 'runtime'):
                (app / d).mkdir(parents=True)
            (app / 'game/GAME/save.dat').write_text('seed')
            (app / 'game/gys.conf').write_text('recipe config')
            runner = app / 'runtime/dosbox'
            runner.write_text('#!/bin/sh\ntest -w GAME/save.dat && test -d CDROM && test "$1" = "-noprimaryconf"\n')
            runner.chmod(0o755)
            shutil.copy2(HERE / 'AppRun', app / 'AppRun')
            env = dict(os.environ, XDG_DATA_HOME=str(root / 'user data'))
            subprocess.run(['bash', str(app / 'AppRun')], env=env, check=True)
            state = root / 'user data/gys-paa-regneslottet'
            self.assertTrue((state / 'GAME/save.dat').is_file())
            (state / 'GAME/save.dat').write_text('progress')
            moved = root / 'second.AppDir'
            app.rename(moved)
            subprocess.run(['bash', str(moved / 'AppRun')], env=env, check=True)
            self.assertEqual((state / 'GAME/save.dat').read_text(), 'progress')
            self.assertEqual((state / 'CDROM').resolve(), moved / 'game/CDROM')
            self.assertEqual((state / 'gys.conf').read_text(), 'recipe config')

if __name__ == '__main__':
    unittest.main()
