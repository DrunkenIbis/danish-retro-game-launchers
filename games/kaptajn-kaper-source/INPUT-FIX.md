# Release 3 input compatibility fix

Status: input fix implemented; user confirmed improved movement, repeated F1 help/return and audible combat in the rebuilt AppImage. Interactive tests stopped at user request; Esc and exhaustive gameplay remain unverified.

PC-BASIC 2.0.7 reproducer: consume Enter through INKEY$, then execute
`DEF SEG=0:POKE 1050,PEEK(1052)`. Subsequent reads replay stale keyboard
entries instead of returning empty. A test of only the first accepted key
misses this bug.

`runner.adapt_special` replaces the BIOS pointer write in SPECIAL.BAS line
2410 with interpreter-level INKEY$ draining, preserving the accepted key
in A and DEF SEG=0. It also maps PC-BASIC's four extended arrow codes to
8/2/4/6. Original upstream source remains unchanged.

Regression tests (three tests pass):

```sh
local/runtime/kaptajn-kaper-source/venv312/bin/python -m unittest discover -s games/kaptajn-kaper-source -p test_input.py -v
```

Tests cover stale-key replay, numeric keys 0–9 and four arrow codes. PC-BASIC
emits ResourceWarning messages about /dev/null during this test run.
AppRun includes a hash-gated upgrade of the known original SPECIAL.BAS,
with a backup; custom source and saves are not replaced. Existing-state
migration still requires separate verification.

Rebuilt artifact:
`extras/dist/kaptajn-kaper-v1-release3-source-x86_64.AppImage`

SHA256: `364c304f48c922ce20957deb65f982839ed39390c0abefaeabea9805c6aba1d9`

The exact rebuilt AppImage was launched with isolated XDG state at
`local/runtime/kaptajn-kaper-source/fixed-input-test` and visually reached
the name prompt. Automated name entry was blocked without user consent;
no alternative input route was attempted. The user subsequently completed the interactive tests and confirmed the improvements described above. No agent-observed turn-counter claim is made.
The Release 5 artifact was not changed. Earlier APPIMAGE.md checksum and
size describe the previous build, not this rebuilt artifact.
