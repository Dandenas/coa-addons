"""Moves the client's saved addon settings from one realm name to another after a realm rename.

WoW keeps settings under the realm's NAME: per character in WTF\\Account\\<ACCOUNT>\\<Realm>\\<Character>\\,
and many addons key their account-wide SavedVariables by "Character - Realm" or by realm. After a
rename the characters look under the new name and their settings appear reset. This script:

  1. copies WTF\\Account\\<ACCOUNT>\\<old realm>\\ to ...\\<new realm>\\ (the original stays), and replaces the
     realm name inside the copied files;
  2. replaces the realm name inside WTF\\Account\\<ACCOUNT>\\SavedVariables\\*.lua (account-wide);
  3. updates the last-used realm in WTF\\Config.wtf.

Run it with the game CLOSED, after the rename is live and BEFORE anyone logs in on the new name:
once a character has logged in there, addons have made fresh entries under the new name, and a
second copy of the same keys would be ambiguous - the script stops if it sees that.

    python realm_migrate.py                     dry run: report only, writes nothing
    python realm_migrate.py --apply             do it (each changed file is first copied to
                                                WTF\\_realm_migration_backup_<date-time>\\)
    --old "Conquest of Azeroth" --new "Nozdormu" --wtf "D:\\COA Client\\WTF"   (defaults)
"""
import argparse, os, shutil, subprocess, sys, time

DEFAULT_WTF = r'D:\COA Client\WTF'


def game_running():
    try:
        out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq Ascension.exe'], capture_output=True, text=True).stdout
        return 'ascension.exe' in out.lower()
    except OSError:
        return False


def count(path, needle):
    with open(path, 'rb') as f:
        return f.read().count(needle)


def replace_in(path, old, new):
    with open(path, 'rb') as f:
        data = f.read()
    n = data.count(old)
    if n:
        with open(path, 'wb') as f:
            f.write(data.replace(old, new))
    return n


def main():
    ap = argparse.ArgumentParser(description='Move saved addon settings to a renamed realm.')
    ap.add_argument('--wtf', default=DEFAULT_WTF)
    ap.add_argument('--old', default='Conquest of Azeroth')
    ap.add_argument('--new', default='Nozdormu')
    ap.add_argument('--apply', action='store_true', help='make the changes (default: dry run)')
    args = ap.parse_args()
    old, new = args.old.encode('utf-8'), args.new.encode('utf-8')
    accounts_dir = os.path.join(args.wtf, 'Account')
    if not os.path.isdir(accounts_dir):
        print('No WTF\\Account folder at %s' % args.wtf)
        return 2
    if args.apply and game_running():
        print('The game is running - close it first (it rewrites these files when you log out).')
        return 2

    plan, problems = [], []   # plan: (kind, description, action)
    for account in sorted(os.listdir(accounts_dir)):
        acct = os.path.join(accounts_dir, account)
        src, dst = os.path.join(acct, args.old), os.path.join(acct, args.new)
        if not os.path.isdir(acct) or not os.path.isdir(src):
            continue
        # 1. realm folder
        if os.path.exists(dst):
            problems.append('%s: "%s" already exists - someone has logged in on the new realm name' % (account, dst))
        else:
            files = [os.path.join(d, f) for d, _, fs in os.walk(src) for f in fs]
            inner = sum(count(p, old) for p in files if not p.endswith('.bak'))
            plan.append(('folder', '%s: copy "%s\\" to "%s\\" (%d files; %d realm-name mentions inside)'
                         % (account, args.old, args.new, len(files), inner), (src, dst)))
        # 2. account-wide SavedVariables
        sv = os.path.join(acct, 'SavedVariables')
        if os.path.isdir(sv):
            for name in sorted(os.listdir(sv)):
                if not name.endswith('.lua'):
                    continue   # .lua.bak files are the game's previous copy; left alone
                path = os.path.join(sv, name)
                n_old, n_new = count(path, old), count(path, new)
                if n_old and n_new:
                    problems.append('%s\\SavedVariables\\%s: already has %d "%s" entries next to %d "%s" ones'
                                    % (account, name, n_new, args.new, n_old, args.old))
                elif n_old:
                    plan.append(('sv', '%s\\SavedVariables\\%s: %d' % (account, name, n_old), path))
    # 3. last-used realm
    config = os.path.join(args.wtf, 'Config.wtf')
    if os.path.isfile(config):
        with open(config, 'rb') as f:
            lines = f.read().splitlines()
        if any(l.startswith(b'SET realmName ') and old in l for l in lines):
            plan.append(('config', 'Config.wtf: last-used realm "%s" -> "%s"' % (args.old, args.new), config))

    print('Realm rename: "%s" -> "%s" in %s' % (args.old, args.new, args.wtf))
    for kind, label in (('folder', 'Per-character folders'), ('sv', 'Account-wide SavedVariables (mentions to rename)'), ('config', 'Client config')):
        items = [p for p in plan if p[0] == kind]
        if items:
            print('\n%s:' % label)
            for _, desc, _ in items:
                print('  ' + desc)
    total = sum(count(p[2], old) for p in plan if p[0] == 'sv')
    print('\n%d account-wide files, %d mentions.' % (len([p for p in plan if p[0] == 'sv']), total))
    if problems:
        print('\nSTOPPED - not safe to migrate automatically:')
        for p in problems:
            print('  ' + p)
        print('Restore from the WTF backup, or sort these out by hand, before running again.')
        return 2
    if not plan:
        print('Nothing to migrate.')
        return 0
    if not args.apply:
        print('\nDry run: nothing was written. Run with --apply (game closed) to do it.')
        return 0

    stamp = time.strftime('%Y%m%d-%H%M%S')
    backup = os.path.join(args.wtf, '_realm_migration_backup_' + stamp)
    for kind, desc, action in plan:
        if kind == 'folder':
            src, dst = action
            shutil.copytree(src, dst)   # the original realm folder stays as it is
            for d, _, fs in os.walk(dst):
                for f in fs:
                    if not f.endswith('.bak'):
                        replace_in(os.path.join(d, f), old, new)
        else:
            rel = os.path.relpath(action, args.wtf)
            os.makedirs(os.path.dirname(os.path.join(backup, rel)), exist_ok=True)
            shutil.copy2(action, os.path.join(backup, rel))
            replace_in(action, old, new)
    print('\nDone. Changed files were first copied to %s' % backup)
    print('The old "%s" folders are untouched; delete them later once everything looks right.' % args.old)
    return 0


if __name__ == '__main__':
    sys.exit(main())
