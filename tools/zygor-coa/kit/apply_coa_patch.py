"""Re-applies the Conquest of Azeroth changes to Zygor Guides Viewer RM and TomTom.

Run it after installing a new version of either addon:

    python apply_coa_patch.py              apply to D:\\COA Client, then run the tests
    python apply_coa_patch.py --dry-run    only report what would change

Nothing is written unless every change fits. Each changed file is first copied into
<addon>\\_CoA_backup_<date-time>\\. Edits already present are skipped, so running it twice
is harmless. If the addon's author changed the code an edit depends on, the script stops
and names that edit; the kit then needs updating (make_kit.py) before it can be applied.
"""
import argparse, json, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ADDONS = r'D:\COA Client\Interface\AddOns'
LUA = r'C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe'
UPSTREAM_TESTS = r'C:\Users\dotyt\Downloads\Compressed\ZygorGuidesRemaster-3.3.5a_WOTLK-main\tools'


def read(path):
    with open(path, 'rb') as f:
        raw = f.read().decode('latin-1')
    return raw.replace('\r\n', '\n'), '\r\n' in raw


def write(path, text, crlf):
    with open(path, 'wb') as f:
        f.write((text.replace('\n', '\r\n') if crlf else text).encode('latin-1'))


PRUNE_NOTES = {
    r'Guide\d\d\.lua': '\t<!-- Empty Guide02-Guide40 slots removed: each missing file logged an "Error loading" line at startup.\n'
                       '\t     To add your own guide, create Guide02.lua (and so on) here and add a matching Script line above. -->\n',
    r'build\d\d\.lua': '\t<!-- Empty build01-build10 slots removed (they only produced "Error loading" lines). '
                       'Add a Script line for any build file you create. -->\n',
}


def prune_autoload(text, folder, pattern):
    """Drop Script lines for numbered placeholder files that do not exist."""
    removed = []
    def keep(m):
        if os.path.exists(os.path.join(folder, m.group(1))):
            return m.group(0)
        removed.append(m.group(1))
        return ''
    text = re.sub(r'[ \t]*<Script file="(' + pattern + r')"/>\n', keep, text)
    if removed and PRUNE_NOTES[pattern] not in text:
        text = text.replace('</Ui>', PRUNE_NOTES[pattern] + '</Ui>', 1)
    return text, removed


def plan(addon, root, kit):
    """Returns (changes {rel: (new text, crlf)}, copies [rel], report lines, errors)."""
    changes, copies, report, errors = {}, [], [], []
    for rel, hunks in kit['edit'].items():
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            errors.append('%s: %s is missing' % (addon, rel))
            continue
        text, crlf = read(path)
        applied = skipped = 0
        for i, h in enumerate(hunks, 1):
            # Already-applied first: an edit's original text can reappear inside code
            # another edit added, and must not be applied a second time.
            if h['new'] and text.count(h['new']) == 1:
                skipped += 1
            elif text.count(h['old']) == 1:
                text = text.replace(h['old'], h['new'])
                applied += 1
            else:
                first = next((l for l in h['old'].split('\n') if l.strip()), '')
                errors.append('%s: %s change %d of %d no longer fits (it expects a line like: %s)'
                              % (addon, rel, i, len(hunks), first.strip()[:90]))
        if applied:
            changes[rel] = (text, crlf)
        report.append('%-7s %-38s %d applied, %d already present' % (addon, rel, applied, skipped))

    if addon == 'zygor':
        for rel, pattern in (('Guides/Autoload.xml', r'Guide\d\d\.lua'),
                             ('ZygorTalentAdvisor/Builds/Autoload.xml', r'build\d\d\.lua')):
            path = os.path.join(root, rel)
            if not os.path.exists(path):
                continue
            text, crlf = read(path)
            text, removed = prune_autoload(text, os.path.dirname(path), pattern)
            if removed:
                changes[rel] = (text, crlf)
            report.append('%-7s %-38s %d empty placeholder entries removed' % (addon, rel, len(removed)))

    for rel in kit['copy']:
        src = os.path.join(HERE, 'files', addon, rel)
        dest = os.path.join(root, rel)
        same = os.path.exists(dest) and open(src, 'rb').read() == open(dest, 'rb').read()
        if not same:
            copies.append(rel)
        report.append('%-7s %-38s %s' % (addon, rel, 'already current' if same else 'will be copied in'))
    return changes, copies, report, errors


def run_tests(zygor_root, tomtom_root):
    tests = []
    fixtures = [os.path.join(TOOLS, 'fixtures', f) for f in ('probe_sunstrider.lua', 'probe_human_start.lua')]
    if zygor_root:
        for fx in fixtures:
            tests.append([LUA, 'test_astrolabe_coa_maps.lua', zygor_root, fx])
        tests.append([LUA, 'test_coa_class_gear.lua', zygor_root])
        tests.append([LUA, 'test_coa_zones.lua', zygor_root] + fixtures)
        tests.append([LUA, 'test_ztacoa.lua', zygor_root])
        if os.path.isdir(UPSTREAM_TESTS):
            for dirpath, _, names in os.walk(UPSTREAM_TESTS):
                for n in sorted(names):
                    if n.startswith('test_') and n.endswith('.lua'):
                        tests.append([LUA, os.path.join(dirpath, n), zygor_root])
    if tomtom_root:
        tests.append([LUA, 'test_tomtom_area_ids.lua', tomtom_root, fixtures[1]])
    failed = 0
    for t in tests:
        r = subprocess.run(t, cwd=TOOLS, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        name = os.path.basename(t[1])
        if r.returncode == 0:
            print('  pass  %s' % (r.stdout.strip().splitlines() or [name])[-1])
        else:
            failed += 1
            print('  FAIL  %s: %s' % (name, (r.stderr or r.stdout).strip().splitlines()[0] if (r.stderr or r.stdout).strip() else '?'))
    print('tests: %d passed, %d failed' % (len(tests) - failed, failed))
    return failed == 0


def main():
    ap = argparse.ArgumentParser(description='Re-apply the CoA changes to Zygor and TomTom.')
    ap.add_argument('--zygor', default=os.path.join(ADDONS, 'ZygorGuidesViewerRM'))
    ap.add_argument('--tomtom', default=os.path.join(ADDONS, 'TomTom'))
    ap.add_argument('--dry-run', action='store_true', help='report only; change nothing')
    ap.add_argument('--skip-tests', action='store_true')
    args = ap.parse_args()

    kit = json.load(open(os.path.join(HERE, 'hunks.json'), encoding='latin-1'))
    roots = {'zygor': args.zygor, 'tomtom': args.tomtom}
    plans, all_errors = {}, []
    for addon, root in roots.items():
        if not os.path.isdir(root):
            print('%s not found at %s - skipped' % (addon, root))
            continue
        changes, copies, report, errors = plan(addon, root, kit[addon])
        plans[addon] = (root, changes, copies)
        print('\n'.join(report))
        all_errors += errors

    if all_errors:
        print('\nNOT APPLIED - these changes no longer fit the installed version:')
        for e in all_errors:
            print('  ' + e)
        print('Nothing was written. The kit needs updating for this version.')
        return 2
    if args.dry_run:
        print('\nDry run: nothing was written.')
        return 0

    stamp = time.strftime('%Y%m%d-%H%M%S')
    for addon, (root, changes, copies) in plans.items():
        touched = list(changes) + copies
        if not touched:
            continue
        backup = os.path.join(root, '_CoA_backup_' + stamp)
        for rel in touched:
            src = os.path.join(root, rel)
            if os.path.exists(src):
                dest = os.path.join(backup, rel)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copyfile(src, dest)
        for rel, (text, crlf) in changes.items():
            write(os.path.join(root, rel), text, crlf)
        for rel in copies:
            dest = os.path.join(root, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copyfile(os.path.join(HERE, 'files', addon, rel), dest)
        print('%s: %d file(s) changed; originals saved in %s' % (addon, len(touched), backup))

    if args.skip_tests:
        return 0
    print('\nRunning tests...')
    ok = run_tests(plans.get('zygor', (None,))[0], plans.get('tomtom', (None,))[0])
    print('\nDone. Fully restart the game (not /reload) so new files are picked up.' if ok else
          '\nSome tests failed - check the output above before playing.')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
