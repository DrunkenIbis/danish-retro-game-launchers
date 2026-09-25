"""Normalize BFV profile dimensions in a stopped prefix; host Python 3 only."""
import os
import re
import stat
import sys
import uuid
from contextlib import ExitStack

PROFILES = 'drive_c/Program Files/EA GAMES/Battlefield Vietnam/Mods/BfVietnam/settings/Profiles'
DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
DISPLAY = re.compile(rb'(?m)^(\s*game\.setGameDisplayMode[ \t]+)\d+([ \t]+)\d+(?=[ \t]+\d+[ \t]+\d+)')


def normalize(prefix):
    # Open every component relative to a pinned directory FD: never follow links,
    # including swapped ancestors. No Wine dosdevices links are involved.
    with ExitStack() as stack:
        def directory(name, parent=None):
            fd = os.open(name, DIRECTORY, dir_fd=parent)
            stack.callback(os.close, fd)
            return fd
        parent = directory(prefix)
        for part in PROFILES.split('/'):
            try:
                parent = directory(part, parent)
            except FileNotFoundError:
                return
        for profile in os.listdir(parent):
            info = os.stat(profile, dir_fd=parent, follow_symlinks=False)
            if not stat.S_ISDIR(info.st_mode):
                continue
            with ExitStack() as files:
                folder = os.open(profile, DIRECTORY, dir_fd=parent)
                files.callback(os.close, folder)
                try:
                    fd = os.open('Video.con', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=folder)
                except FileNotFoundError:
                    continue
                with os.fdopen(fd, 'rb') as source:
                    mode = os.fstat(source.fileno()).st_mode
                    if not stat.S_ISREG(mode):
                        raise ValueError('Video.con must be a regular file')
                    original = source.read()
                updated = DISPLAY.sub(lambda m: m[1] + b'1024' + m[2] + b'768', original)
                if updated == original:
                    continue
                try:
                    backup = os.open('Video.con.before-window-resolution',
                                     os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                     0o600, dir_fd=folder)
                except FileExistsError:
                    pass  # Never overwrite or follow an existing backup.
                else:
                    with os.fdopen(backup, 'wb') as target:
                        target.write(original)
                temporary = '.Video.con.' + uuid.uuid4().hex
                try:
                    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                 stat.S_IMODE(mode) & 0o777, dir_fd=folder)
                    with os.fdopen(fd, 'wb') as target:
                        target.write(updated)
                    os.replace(temporary, 'Video.con', src_dir_fd=folder, dst_dir_fd=folder)
                finally:
                    try:
                        os.unlink(temporary, dir_fd=folder)
                    except FileNotFoundError:
                        pass


if __name__ == '__main__':
    normalize(sys.argv[1])
