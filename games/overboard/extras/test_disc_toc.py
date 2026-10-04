import unittest
import ogg_tracks

class DiscTocTests(unittest.TestCase):
    def test_positions_include_data_leadin_and_embedded_pregaps(self):
        toc = '''CD_ROM_XA
TRACK MODE2_RAW
DATAFILE "disc.bin" 00:10:00
TRACK AUDIO
SILENCE 00:02:00
FILE "disc.bin" #1764000 0 00:05:00
START 00:02:00
TRACK AUDIO
FILE "disc.bin" #1764000 00:05:00 00:06:00
START 00:00:02
'''
        self.assertEqual(ogg_tracks.disc_positions(toc), [150, 1050, 1427])

if __name__ == '__main__':
    unittest.main()
