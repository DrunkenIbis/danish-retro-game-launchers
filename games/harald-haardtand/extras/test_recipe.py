#!/usr/bin/env python3
"""Recipe regression tests; synthetic archive fixtures contain no game media."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile
import os
import subprocess

HERE = Path(__file__).resolve().parent.parent


class RecipeTests(unittest.TestCase):
    def test_launch_config_and_cycle_override(self):
        with tempfile.TemporaryDirectory(prefix='harald runtime ') as tmp:
            runtime = Path(tmp)
            (runtime / 'game').mkdir()
            for name in ('HARALD.EXE', 'HARALD.001', 'HARALD.002', 'HARALD.DIR', 'HIGH.DAT'):
                (runtime / 'game' / name).write_bytes(b'fixture')
            env = {k: v for k, v in os.environ.items() if not k.startswith('HARALD_')}
            env.update(HARALD_RUNTIME_DIR=tmp, HARALD_DRY_RUN='1', HARALD_DOSBOX_BIN='/usr/bin/true')
            for cycles in ('6000', '8000'):
                env['HARALD_CPU_CYCLES'] = cycles
                result = subprocess.run(['bash', str(HERE / 'launch.sh')], env=env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                conf = (runtime / 'harald-haardtand.conf').read_text()
                self.assertIn('cpu_cycles = ' + cycles, conf)
                self.assertIn('mount c ./game', conf)
                self.assertIn('HARALD.EXE', conf)
                self.assertNotIn('TRAIN.EXE', conf)
                self.assertIn(tmp, result.stdout)
            env['HARALD_CPU_CYCLES'] = '6000\n[autoexec]\nBAD'
            result = subprocess.run(['bash', str(HERE / 'launch.sh')], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_extract_only_game_files(self):
        self.assertTrue((HERE / 'runner.py').is_file(), 'Recipe implementation is missing')
        spec = importlib.util.spec_from_file_location('harald', HERE / 'runner.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(prefix='harald test ') as tmp:
            tmp = Path(tmp)
            archive = tmp / 'fixture.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                for name in ('HARALD.EXE', 'HARALD.001', 'HARALD.002', 'HARALD.DIR', 'HIGH.DAT'):
                    z.writestr('Harald Hårdtand/SYSTEM/DOSBOX/GAME/' + name, b'fixture-' + name.encode())
                z.writestr('Harald Hårdtand/SYSTEM/DOSBOX/dosbox.exe', b'not Linux')
                z.writestr('Harald Hårdtand/SYSTEM/DOSBOX/GAME/TRAIN.EXE', b'not used')
                z.writestr('../../escape', b'not extracted')
            sha = hashlib.sha256(archive.read_bytes()).hexdigest()
            module.extract(archive, tmp / 'runtime/game', expected_sha=sha)
            self.assertEqual({p.name for p in (tmp / 'runtime/game').iterdir()},
                             {'HARALD.EXE', 'HARALD.001', 'HARALD.002', 'HARALD.DIR', 'HIGH.DAT'})
            self.assertFalse((tmp / 'escape').exists())
            high = tmp / 'runtime/game/HIGH.DAT'
            high.write_bytes(b'my high scores')
            module.extract(archive, tmp / 'runtime/game', expected_sha=sha)
            self.assertEqual(high.read_bytes(), b'my high scores')
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                module.extract(archive, tmp / 'bad/game', expected_sha='0' * 64)
            self.assertFalse((tmp / 'bad/game').exists())


if __name__ == '__main__':
    unittest.main()
