from pathlib import Path
import os
import subprocess
import unittest


class SocketTests(unittest.TestCase):
    def test_local_display_socket_retains_dot_directory(self):
        text = Path(__file__).with_name('launch_kernel_free_test.sh').read_text()
        assignments = '\n'.join(line for line in text.splitlines()
                                if line.startswith(('display_number=', 'socket=')))
        for display in (':0', ':0.0', ':12.1'):
            with self.subTest(display=display):
                result = subprocess.run(['bash', '-eu', '-c', assignments + '\nprintf "%s" "$socket"'],
                                        env=dict(os.environ, DISPLAY=display), capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout, '/tmp/.X11-unix/X' + display[1:].split('.')[0])
