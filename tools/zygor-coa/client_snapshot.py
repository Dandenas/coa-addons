"""Read-only snapshot of the CoA client, for comparing before and after a client update.
  python client_snapshot.py snap <name>        hash list + copies of the files we customise
  python client_snapshot.py diff <old> <new>   what was added / removed / changed
Writes only to C:\\Users\\dotyt\\tools\\coa-snapshots\\<name>\\; the client folder is never changed."""
import csv, hashlib, os, shutil, sys

CLIENT = r"D:\COA Client"
OUT = r"C:\Users\dotyt\tools\coa-snapshots"
# top-level folders left out of the hash list (caches, logs, our own backups, settings)
SKIP_DIRS = {"Cache", "Logs", "Errors", "Screenshots", "DLL_Logs", "MaterialCache", "NativeShadowShaders",
             "WTF", "_CoA_UI_backup", "_ModernRenderer_backup", "_WTF_backup_20261002", ".coa-launcher"}
# copied in full so they can be diffed or put back after the update
KEEP_FILES = ["Ascension.exe", "Extensions.dll", "d3d9.dll", "README.txt", "CLIENT-RELEASE.json",
              "GraphicsEffects.ini", "ModernWoWRenderer.ini", "EnvironmentProfiles.ini",
              r"Data\patch-B.MPQ", r"Data\patch-T.MPQ", r"Data\patch-M.MPQ", r"Data\enUS\realmlist.wtf",
              r".coa-launcher\state.json", r".coa-launcher\addons.json"]
KEEP_DIRS = [r"Interface\AddOns\SexyMap\Libs\AceGUI-3.0-SharedMediaWidgets", "WTF"]

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def snap(name):
    dest = os.path.join(OUT, name)
    if os.path.exists(dest):
        sys.exit(f"{dest} already exists; pick another name")
    os.makedirs(dest)
    rows = []
    for root, dirs, files in os.walk(CLIENT):
        if root == CLIENT:
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            if fn.lower().endswith(".log"):
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, CLIENT)
            st = os.stat(p)
            rows.append((rel, st.st_size, int(st.st_mtime), sha256(p)))
            if len(rows) % 2000 == 0:
                print(len(rows), "files hashed")
    with open(os.path.join(dest, "manifest.csv"), "w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows([("path", "size", "mtime", "sha256")] + sorted(rows))
    for rel in KEEP_FILES:
        src = os.path.join(CLIENT, rel)
        if os.path.isfile(src):
            os.makedirs(os.path.dirname(os.path.join(dest, "files", rel)), exist_ok=True)
            shutil.copy2(src, os.path.join(dest, "files", rel))
    for rel in KEEP_DIRS:
        src = os.path.join(CLIENT, rel)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, "files", rel))
    print(f"{len(rows)} files listed, copies in {dest}\\files")

def load(name):
    with open(os.path.join(OUT, name, "manifest.csv"), encoding="utf-8") as f:
        return {r["path"]: r for r in csv.DictReader(f)}

def diff(old, new):
    a, b = load(old), load(new)
    lines = [f"added   {p}" for p in sorted(b.keys() - a.keys())]
    lines += [f"removed {p}" for p in sorted(a.keys() - b.keys())]
    lines += [f"changed {p}  ({a[p]['size']} -> {b[p]['size']} bytes)"
              for p in sorted(a.keys() & b.keys()) if a[p]["sha256"] != b[p]["sha256"]]
    out = os.path.join(OUT, new, f"diff-vs-{old}.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines) or "no differences")
    print(f"\n{len(lines)} differences, saved to {out}")

if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "snap":
        snap(sys.argv[2])
    elif len(sys.argv) == 4 and sys.argv[1] == "diff":
        diff(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
