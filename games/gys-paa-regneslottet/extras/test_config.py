"""Recipe config regression tests; no game media or DOSBox required."""
import configparser
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

LAUNCHER = Path(__file__).resolve().parents[1] / 'launch.sh'


def generate(**overrides):
    source = LAUNCHER.read_text()
    marker = 'python3 - "$BUNDLED_CONF" "$CONF" <<\'PY\'\n'
    code = source.split(marker, 1)[1].split('\nPY', 1)[0]
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp) / 'bundle.conf', Path(tmp) / 'output.conf'
        src.write_text('# test source profile\n')
        env = {k: v for k, v in os.environ.items() if not k.startswith('GYS_')}
        env.update(overrides)
        subprocess.run(['python3', '-', str(src), str(dst)], input=code,
                       text=True, env=env, check=True)
        return dst.read_text(encoding='latin-1')


class ConfigTests(unittest.TestCase):
    def test_conservative_cpu_default_and_overrides(self):
        text = generate().split('[autoexec]', 1)[0]
        config = configparser.ConfigParser()
        config.read_string(text)
        self.assertEqual(config['cpu']['core'], 'normal')
        self.assertEqual(config['cpu']['cpu_cycles'], '15000')
        config.read_string(generate(GYS_CPU_CORE='auto', GYS_CPU_CYCLES='20000').split('[autoexec]', 1)[0])
        self.assertEqual(config['cpu']['core'], 'auto')
        self.assertEqual(config['cpu']['cpu_cycles'], '20000')

    def test_host_mount_paths_use_unix_separators(self):
        text = generate()
        self.assertIn('MOUNT C ./GAME\n', text)
        self.assertIn('./CDROM/CDROM.iso', text)
        self.assertIn(r'WIN C:\GILISOFT\GYS_CD\WNEWADDD.EXE', text)


if __name__ == '__main__':
    unittest.main()
