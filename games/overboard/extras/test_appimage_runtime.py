import importlib.util
from pathlib import Path
import unittest

P = Path(__file__).with_name('appimage_runtime.py')

class RuntimeTests(unittest.TestCase):
    def test_free_device_and_toc_relocation(self):
        self.assertTrue(P.exists(), 'runtime implementation missing')
        spec = importlib.util.spec_from_file_location('runtime', P)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        self.assertEqual(m.empty_device('DEV LOADED FILENAME\n0 True other.iso\n1 False\n'), '1')
        self.assertIsNone(m.empty_device('0 True other.iso\n'))
        toc = 'TRACK MODE2_RAW\nDATAFILE "/old/cd.bin" 19:07:32\nTRACK AUDIO\nFILE "/old/cd.bin" #123 0 02:00:00\n'
        new = m.relocate_toc(toc, '/new/OVERBOARD.bin')
        self.assertNotIn('/old/', new)
        self.assertEqual(new.count('"/new/OVERBOARD.bin"'), 2)
        self.assertIn('#123 0 02:00:00', new)

if __name__ == '__main__':
    unittest.main()
