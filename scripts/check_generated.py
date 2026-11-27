"""Check that every committed file written by a script is still what its script writes.

Each generator below is run in place; the file it writes is compared with the committed one, then the committed one
is put back (this check never changes a file). A generator whose inputs are not on this machine (the Windower res/
folder, an unpacked npm package, AioHUD's icons) is skipped and says so.

    python scripts/check_generated.py           every generator
    python scripts/check_generated.py --fix     rewrite the files that drifted (the same as running their scripts)

Exits 1 when a file drifted (without --fix) or a generator failed.

@file    scripts/check_generated.py
"""
import os
import shutil
import subprocess
import sys

DATA = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.normpath(os.path.join(DATA, '..', '..', '..', 'res'))
GS_LIBS = os.path.normpath(os.path.join(DATA, '..', 'libs'))     # GearSwap's libs/: the HUD renders with them

# (script, the file it writes, what it reads besides the repo)
GENERATED = [
    ('scripts/atelier/build_state_help.py', 'atelier/app/js/state_help_data.js', []),
    ('scripts/atelier/build_ws_table.py', 'atelier/calc/calc_ws_table.js', []),
    ('scripts/atelier/gen_hud_sources.py', 'atelier/app/js/hud_sources.js', ['lua5.1', GS_LIBS]),
    ('scripts/atelier/build_job_access.py', 'atelier/app/js/job_access_data.js', [RES]),
    ('scripts/atelier/build_ws_access.py', 'atelier/app/js/ws_access_data.js', [RES]),
    ('scripts/atelier/build_long_names.py', 'atelier/app/js/long_names_data.js', [RES]),
    ('scripts/atelier/build_usables.py', 'atelier/app/js/usables_data.js', [RES]),
    ('scripts/item_db/build_fast_cast_db.py', 'shared/data/equipment/ITEM_FAST_CAST.lua',
     [RES, os.path.join(DATA, 'atelier', 'gear', 'items.json')]),
]
# Not checked: their inputs are outside any checkout (say so here, so the list above stays the whole story)
#   scripts/atelier/gen_buff_icons.py  -> atelier/app/js/buff_icons.js  (AioHUD's icon folder)
#   scripts/atelier/gen_game_icons.py  -> atelier/app/js/game_icons.js  (GI_PACKAGE, an unpacked npm package)


def missing(needs):
    for n in needs:
        if os.path.isabs(n):
            if not os.path.exists(n):
                return n
        elif not shutil.which(n):
            return n
    return None


def first_diff(a, b):
    x, y = a.decode('utf-8', 'replace').splitlines(), b.decode('utf-8', 'replace').splitlines()
    for i in range(max(len(x), len(y))):
        if i >= len(x) or i >= len(y) or x[i] != y[i]:
            return 'line %d (committed %d lines, script %d lines)' % (i + 1, len(x), len(y))
    return 'line endings or a final newline'


def main():
    fix = '--fix' in sys.argv
    drifted = failed = 0
    for script, out, needs in GENERATED:
        gone = missing(needs)
        if gone:
            print('skip   %-44s (needs %s)' % (out, gone))
            continue
        path = os.path.join(DATA, out)
        with open(path, 'rb') as f:
            before = f.read()
        try:
            r = subprocess.run([sys.executable, script], cwd=DATA, capture_output=True, text=True,
                               encoding='utf-8', errors='replace')
            with open(path, 'rb') as f:
                after = f.read()
        finally:
            if not fix:
                with open(path, 'wb') as f:
                    f.write(before)
        if r.returncode:
            failed += 1
            print('FAILED %-44s %s' % (out, (r.stderr or r.stdout).strip().splitlines()[-1:]))
        elif after != before:
            drifted += 1
            print('%s %-44s differs from %s at %s' % ('fixed ' if fix else 'DRIFT ', out, script, first_diff(before, after)))
        else:
            print('ok     %s' % out)
    if drifted and not fix:
        print('\n%d file(s) differ from what their script writes now: run the script, or --fix' % drifted)
    sys.exit(1 if failed or (drifted and not fix) else 0)


if __name__ == '__main__':
    main()
