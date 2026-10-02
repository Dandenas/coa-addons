"""Builds the CoA patch kit from the difference between clean and patched addon files.

Each change becomes a hunk: the original text (with a little context) and its replacement.
apply_coa_patch.py replays the hunks on a fresh download. Re-run this after changing the
patched install, so the kit always matches it.

    python make_kit.py
"""
import difflib, json, os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = r'D:\COA Client\Interface\AddOns'
PRISTINE_ZYGOR = r'C:\Users\dotyt\Downloads\Compressed\ZygorGuidesRemaster-3.3.5a_WOTLK-main\ZygorGuidesViewerRM'

# addon: (patched dir, pristine dir or {rel: pristine file}, files edited by hunks, files copied whole)
TARGETS = {
    'zygor': {
        'patched': os.path.join(ADDONS, 'ZygorGuidesViewerRM'),
        'pristine': PRISTINE_ZYGOR,
        'edit': ['files.xml', 'Goal.lua', 'Item-ItemScore.lua', 'Libs/Astrolabe/Astrolabe.lua',
                 'Libs/Astrolabe/Load.xml', 'Libs/LibRover-1.0/LibRover-1.0.lua', 'MapCoords.lua',
                 'MapSpotSet.lua', 'Parser.lua', 'Pointer.lua', 'Waypoints.lua',
                 'Options.lua', 'GuideBrowser.lua'],
        'copy': ['CoAZones.lua', 'Data-WOTLK/CoA-ClassSpecs.lua', 'Libs/Astrolabe/AstrolabeCoAData.lua',
                 'ZygorTalentAdvisorCOA/files.xml', 'ZygorTalentAdvisorCOA/Data.lua',
                 'ZygorTalentAdvisorCOA/ZygorTalentAdvisorCOA.lua', 'ZygorTalentAdvisorCOA/Popout.lua',
                 'ZygorTalentAdvisorCOA/Overlay.lua', 'ZygorTalentAdvisorCOA/Preview.lua',
                 'ZygorTalentAdvisorCOA/Load.lua', 'ZygorTalentAdvisorCOA/Options.lua'],
    },
    'tomtom': {
        'patched': os.path.join(ADDONS, 'TomTom'),
        # Ascension/CoA clients replace TomTom's Astrolabe with their own (area IDs), so the
        # changes live in TomTom's own files. Originals were backed up before patching.
        'pristine': {rel: os.path.join(ADDONS, 'TomTom', '_CoA_original', os.path.basename(rel))
                     for rel in ('TomTom.lua', 'TomTom_Corpse.lua', 'TomTom_POIIntegration.lua')},
        'edit': ['TomTom.lua', 'TomTom_Corpse.lua', 'TomTom_POIIntegration.lua'],
        'copy': [],
    },
    'healbot': {
        'patched': os.path.join(ADDONS, 'HealBot'),
        # HealBot 3.3.5.4 keys its class tables by the first four letters of the class; CoA
        # classes ("CHRO", ...) are in none of them. Originals were backed up before patching.
        'pristine': {rel: os.path.join(ADDONS, 'HealBot', '_CoA_original', rel)
                     for rel in ('HealBot.lua', 'HealBot_Action.lua', 'HealBot_Options.lua')},
        'edit': ['HealBot.lua', 'HealBot_Action.lua', 'HealBot_Options.lua'],
        'copy': [],
    },
}
CONTEXT = 2  # unchanged lines kept on each side of a change, so each hunk is found in one place


def read_lines(path):
    with open(path, 'rb') as f:
        text = f.read().decode('latin-1')  # byte-transparent; files mix UTF-8 and Latin-1
    return text.replace('\r\n', '\n').split('\n')


def hunks_for(old, new):
    out = []
    whole = '\n'.join(old)
    sm = difflib.SequenceMatcher(None, old, new, autojunk=False)
    for group in sm.get_grouped_opcodes(CONTEXT):
        o1, o2 = group[0][1], group[-1][2]
        n1, n2 = group[0][3], group[-1][4]
        # Widen with unchanged lines until the original text occurs exactly once.
        while whole.count('\n'.join(old[o1:o2])) != 1:
            grew = False
            if o1 > 0 and n1 > 0 and old[o1 - 1] == new[n1 - 1]:
                o1, n1, grew = o1 - 1, n1 - 1, True
            if o2 < len(old) and n2 < len(new) and old[o2] == new[n2]:
                o2, n2, grew = o2 + 1, n2 + 1, True
            if not grew:
                break
        out.append({'old': '\n'.join(old[o1:o2]), 'new': '\n'.join(new[n1:n2])})
    return out


def main():
    kit = {}
    for addon, t in TARGETS.items():
        entries = {}
        for rel in t['edit']:
            pristine = t['pristine'][rel] if isinstance(t['pristine'], dict) else os.path.join(t['pristine'], rel)
            hunks = hunks_for(read_lines(pristine), read_lines(os.path.join(t['patched'], rel)))
            for h in hunks:
                assert '\n'.join(read_lines(pristine)).count(h['old']) == 1, (addon, rel, 'ambiguous hunk', h['old'][:80])
            entries[rel] = hunks
            print('%-7s %-38s %d hunk(s)' % (addon, rel, len(hunks)))
        for rel in t['copy']:
            dest = os.path.join(HERE, 'files', addon, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copyfile(os.path.join(t['patched'], rel), dest)
            print('%-7s %-38s copied' % (addon, rel))
        kit[addon] = {'edit': entries, 'copy': t['copy']}
    with open(os.path.join(HERE, 'hunks.json'), 'w', encoding='latin-1') as f:
        json.dump(kit, f, indent=1, ensure_ascii=True)
    print('wrote hunks.json')


if __name__ == '__main__':
    main()
