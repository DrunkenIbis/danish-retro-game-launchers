"""Shared no-follow output operations for the two Linux disc stagers.

Walk directories using held descriptors, not resolved path strings. Relative
media paths must remain beneath the selected output root. Callers must keep
staging directories private (not concurrently writable by another process).
"""
from contextlib import contextmanager
import io
import os
from pathlib import Path
import stat


@contextmanager
def output_directory(root, relative=Path()):
    root = Path(root).absolute()
    relative = Path(relative)
    if relative.is_absolute() or '..' in relative.parts or '..' in root.parts:
        raise ValueError('Output path must remain beneath its root')
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    fd = os.open(root.anchor, flags)
    try:
        for part in (*root.parts[1:], *relative.parts):
            try:
                os.mkdir(part, dir_fd=fd)
            except FileExistsError:
                pass
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd
    finally:
        os.close(fd)


def regular_stat(directory, name):
    if Path(name).name != name or name in ('', '.', '..'):
        raise ValueError('Expected output basename')
    try:
        info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(info.st_mode):
        raise ValueError(f'Refusing non-regular output (including symlink): {name}')
    return info


@contextmanager
def open_regular(directory, name, *, existing=False, readonly=False):
    # O_EXCL preserves even dangling symlinks; O_NOFOLLOW protects resumed reads
    # and writes. O_NONBLOCK prevents a raced FIFO from hanging before fstat.
    expected = regular_stat(directory, name)
    if existing and expected is None:
        raise FileNotFoundError(name)
    flags = os.O_RDONLY if readonly else os.O_RDWR
    if not existing:
        flags |= os.O_CREAT | os.O_EXCL
    fd = os.open(name, flags | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=directory)
    try:
        actual = os.fstat(fd)
        if not stat.S_ISREG(actual.st_mode):
            raise ValueError(f'Refusing non-regular output: {name}')
        if expected is not None and existing and (actual.st_dev, actual.st_ino) != (expected.st_dev, expected.st_ino):
            raise ValueError(f'Output changed while opening: {name}')
        with io.open(fd, 'rb' if readonly else 'r+b', closefd=False) as stream:
            yield stream
    finally:
        os.close(fd)


def publish(directory, partial, target, stream):
    info = regular_stat(directory, partial)
    opened = os.fstat(stream.fileno())
    if info is None or (info.st_dev, info.st_ino) != (opened.st_dev, opened.st_ino):
        raise ValueError('Partial output changed before publication')
    # Unlike rename(), link() never overwrites a destination created meanwhile.
    # Both names are relative to the same checked directory; never follow links.
    os.link(partial, target, src_dir_fd=directory, dst_dir_fd=directory, follow_symlinks=False)
    os.unlink(partial, dir_fd=directory)
