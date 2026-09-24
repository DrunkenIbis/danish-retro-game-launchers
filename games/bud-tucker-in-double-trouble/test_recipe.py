#!/usr/bin/env python3
"""Synthetic shell-contract tests; these do not establish gameplay."""
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

GAME = Path(__file__).resolve().parent
REPO = GAME.parents[1]


class AppRunTests(unittest.TestCase):
    def setUp(self):
        base = REPO / 'local/runtime/bud-tucker-in-double-trouble/tests'
        base.mkdir(parents=True, exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=base)
        self.root = Path(self.tmp.name)
        self.app = self.root / 'app'
        self.state = self.root / 'state'
        (self.app / 'runtime').mkdir(parents=True)
        (self.app / 'seed-c/TUCKER').mkdir(parents=True)
        (self.app / 'seed-c/TUCKER/BUD.BAT').write_text('synthetic fixture')
        (self.app / 'seed-c/G.IN').write_text('synthetic audio fixture')
        (self.app / 'base.conf').write_text('[sdl]\nfullscreen=false\n')
        binary = self.app / 'runtime/dosbox'
        binary.write_text('#!/bin/sh\nprintf "stub runtime invoked\\n"\n')
        binary.chmod(0o755)
        shutil.copy2(GAME / 'extras/AppRun', self.app / 'AppRun')
        self.env = dict(os.environ, BUD_APPIMAGE_STATE=str(self.state))

    def tearDown(self):
        self.tmp.cleanup()

    def run_app(self):
        return subprocess.run(['bash', str(self.app / 'AppRun')], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_seed_then_preserve_existing_data(self):
        self.assertEqual(self.run_app().returncode, 0)
        marker = self.state / 'c/TUCKER/user-save.fixture'
        marker.write_text('user data')
        self.assertEqual(self.run_app().returncode, 0)
        self.assertEqual(marker.read_text(), 'user data')
        config = (self.state / 'game.conf').read_text()
        self.assertIn(str(self.app / 'cd-files'), config)
        self.assertNotIn('imgmount', config)
        self.assertNotIn('-t cdrom', config)
        self.assertFalse(list(self.state.glob('.seed.*')))

    def test_overlap_rejected(self):
        self.state.mkdir()
        with (self.state / 'session.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_app()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('already running', result.stderr)
            self.assertFalse((self.state / 'c').exists())

    def test_incomplete_state_not_overwritten(self):
        (self.state / 'c').mkdir(parents=True)
        result = self.run_app()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Incomplete', result.stderr)

    def test_relative_state_rejected(self):
        self.env['BUD_APPIMAGE_STATE'] = 'relative-state'
        self.assertNotEqual(self.run_app().returncode, 0)

    def test_missing_folder_runtime_error(self):
        env = dict(os.environ, BUD_FOLDER_RUNTIME=str(self.root / 'missing'))
        result = subprocess.run(['bash', str(GAME / 'launch.sh')], env=env,
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Run launch.sh prepare', result.stderr)


if __name__ == '__main__':
    unittest.main()
