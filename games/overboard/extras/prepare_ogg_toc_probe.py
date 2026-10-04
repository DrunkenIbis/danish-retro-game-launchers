#!/usr/bin/env python3
"""Prepare experimental, original-TOC-backed MCI track-position emulation.

Does not patch the game executable. Input emulator source must be the pinned
ogg-winmm checkout. Output is a separate source copy and test INI, not a release.
"""
from pathlib import Path
import argparse
from ogg_tracks import disc_positions


def patch_source(text):
    anchor = '\t\tGetModuleFileName(hinstDLL, path, sizeof(path));'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected upstream module-path code')
    text = text.replace('BOOL WINAPI DllMain(', 'static char disc_ini[MAX_PATH];\n\nBOOL WINAPI DllMain(', 1)
    text = text.replace(anchor, anchor + '\n\t\tstrcpy(disc_ini, path);\n\t\tchar *disc_ext = strrchr(disc_ini, \'.\');\n\t\tif (disc_ext) strcpy(disc_ext, ".ini");', 1)
    anchor = '\t\t\t\t\t\t\tcase MCI_STATUS_POSITION:'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected upstream position handling')
    code = '''
                                /* Optional original disc INDEX 01, in 75 Hz frames.
                                 * Do not infer mixed-mode positions from Ogg durations. */
                                if ((fdwCommand & MCI_TRACK) && parms->dwTrack > 0 && parms->dwTrack <= MAX_TRACKS) {
                                    char key[40];
                                    snprintf(key, sizeof(key), "Track%02uPositionFrames", (unsigned)parms->dwTrack);
                                    UINT frame = GetPrivateProfileIntA("OriginalDiscTOC", key, 0xffffffffu, disc_ini);
                                    if (frame != 0xffffffffu && time_format == MCI_FORMAT_MSF) {
                                        parms->dwReturn = MCI_MAKE_MSF(frame / 4500, frame / 75 % 60, frame % 75);
                                        break;
                                    }
                                }
'''
    return text.replace(anchor, anchor + code, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('toc', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name in ('ogg-winmm.c', 'winmm.ini'):
        if (args.output/name).exists():
            raise FileExistsError(args.output/name)
    (args.output/'ogg-winmm.c').write_text(patch_source(args.source.read_text()))
    positions = disc_positions(args.toc.read_text())
    ini = '[OGG-WinMM]\nCDDAPath=Music\n\n[OriginalDiscTOC]\n'
    ini += ''.join(f'Track{i:02d}PositionFrames={pos}\n' for i, pos in enumerate(positions, 1))
    (args.output/'winmm.ini').write_text(ini)
    print(f'Prepared {len(positions)} original track positions; game unchanged.')


if __name__ == '__main__':
    main()
