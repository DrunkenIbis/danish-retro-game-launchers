"""Run with the recipe's Python 3.12/PC-BASIC environment."""
import unittest
import pcbasic
import runner

INPUT = b'2400 A=INKEY$:IF A="" THEN 2400\r\n2410 DEF SEG=0:POKE 1050,PEEK(1052):RETURN\r\n'

class InputTests(unittest.TestCase):
    def program(self):
        adapt = getattr(runner, 'adapt_special', lambda data: data)
        return adapt(INPUT)

    def session(self, key):
        s = pcbasic.Session(peek_values={}, input_streams=[], output_streams=[])
        s.execute('10 DEFSTR A-H:GOSUB 2400:END')
        for line in self.program().splitlines():
            s.execute(line)
        s.press_keys(key)
        s.execute('RUN')
        return s

    def test_consumed_key_does_not_reappear(self):
        with self.session('\r') as s:
            self.assertEqual(s.evaluate('A'), b'\r')
            self.assertEqual(s.evaluate('INKEY$'), b'')

    def test_arrow_keys_map_to_directions(self):
        for key, expected in [('\x00H', b'8'), ('\x00P', b'2'), ('\x00K', b'4'), ('\x00M', b'6')]:
            with self.subTest(key=key), self.session(key) as s:
                self.assertEqual(s.evaluate('A'), expected)

    def test_numeric_keys_unchanged(self):
        for key in '0123456789':
            with self.subTest(key=key), self.session(key) as s:
                self.assertEqual(s.evaluate('A'), key.encode())

if __name__ == '__main__':
    unittest.main()
