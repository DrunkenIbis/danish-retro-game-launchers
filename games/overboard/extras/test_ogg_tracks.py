"""Synthetic fixtures only; no original media required."""
import importlib.util
from pathlib import Path
import unittest

class TrackTests(unittest.TestCase):
    def test_cdrdao_offsets_and_embedded_pregap(self):
        spec = importlib.util.spec_from_file_location('ogg_tracks', Path(__file__).with_name('ogg_tracks.py'))
        self.assertTrue(Path(spec.origin).is_file(), 'track extraction helper missing')
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        text = '''CD_ROM_XA
TRACK MODE2_RAW
DATAFILE "disc.bin" 00:01:00
TRACK AUDIO
SILENCE 00:02:00
FILE "disc.bin" #176400 0 00:03:00
START 00:02:00
TRACK AUDIO
FILE "disc.bin" #176400 00:03:00 00:04:00
START 00:00:02
'''
        self.assertEqual(m.audio_ranges(text), [(2, 176400, 529200), (3, 710304, 700896)])

if __name__ == '__main__':
    unittest.main()
