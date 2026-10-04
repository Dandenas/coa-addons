# Session notes: CoA client and addon work

Resume notes for Claude sessions. Last updated **2026-10-04**.

**To resume in a new session:**
> Read `C:\Users\dotyt\Documents\GitHub\coa-addons\docs\SESSION-NOTES.md` and the memory index.

The memory folder (`C:\Users\dotyt\.claude\projects\C--Users-dotyt-Desktop-Stream-Launcher-app\memory\`) loads automatically only for sessions started in `Desktop\Stream Launcher app`. From any other folder, ask the session to read `MEMORY.md` there.

## Working rules

- Lay out the plan and wait for the user's go-ahead before editing or creating files. The user reviews every diff and command.
- Show any script before running it.
- Ask before downloading anything, and give the size.
- "Research only" / "review only" means don't build.
- Keep this repo private, and keep the re-apply kit on this PC only. Ascension Sidekick hasn't given permission to redistribute its data.
- The user launches `Ascension.exe` themselves.
- Discord write-ups: one copy-paste block under 2,000 characters, in `~~~markdown` fences.

## Done

| Item | Notes |
|---|---|
| CoA Talent Advisor (`ZygorTalentAdvisorCOA`) | Preview another spec's tree, "Load build" (unsaved changes in the talent window; timeline-based, proportional two-tree trimming), point-based panel statuses, own tab in Zygor's options (opacity etc.) |
| HealBot 3.3.5.4 | CoA classes no longer crash it. In repo and kit, `test_healbot_coa.lua` |
| SexyMap | `Libs\AceGUI-3.0-SharedMediaWidgets` copied from Omen. **Not in the repo**: redo if SexyMap is reinstalled |
| Button Forge 0.9.4 | `Util.CacheCompanions` skips nameless companions (21 of 861 Ascension mounts), so start-up completes and `ButtonForgeSave` exists. In repo and kit, `test_buttonforge_coa.lua` |
| Realm rename | "Conquest of Azeroth" → **Nozdormu**, plus **Felstorm**. WTF backed up and migrated (`Migrate-RealmName.bat`); old folders kept |
| Extensions.dll | Rebuilt at firstoni 5197e75 and installed. Previous DLL: `D:\COA Client\_CoA_UI_backup\Extensions.dll.07b3a00` |
| dbc_clientset | Item / ItemDisplayInfo / CreatureDisplayInfo.dbc from patch-M, in `C:\Users\dotyt\tools\dbc_clientset\`, copied to the server |
| Realm cards, spec slots | Realm cards per realm. Spec slots and Tomes II–XX work since server #6244/#6297 |

## Waiting on the user

1. **Button Forge in-game test:** `/reload`, use bars, Create Bar, Advanced tools. Then run `Sync-ToRepo.bat` and commit in GitHub Desktop (suggested summary: *Button Forge: fix start-up with Ascension's nameless mounts*).
2. **Talent advisor "switch to spec slot + load build":** planned and reviewed; **don't build until the user says go**. Checks before building:
   - whether the talent window closes on a slot swap;
   - event timing after the swap;
   - loading into an empty slot;
   - whether `GetInspectedBuild` works on other slots.

## On the next official client patch

- **Before installing:** take a baseline snapshot (read-only hash manifest). Show the script to the user first; it isn't approved yet.
- **After installing:** three-way compare: the new patch, our client, and the extensions-reconstruction repo.
- Refresh `dbc_clientset` if the item/display DBCs changed, re-test the advisor and Zygor map data, and run the test suite.
- Details: memory `coa-client-patch-compare.md`.

## Backlog (parked)

Retail-style character select (outline only), HealBot CoA spell gaps, the realm-card "WotLK" notice, the VanillaGuide error on new characters, TSM on Felstorm (C_Hook overflow, disabled), High Elf race (server says it doesn't fit as-is). Details: memory `coa-ideas-backlog.md`.

## Key paths

| What | Where |
|---|---|
| Client | `D:\COA Client` (addons in `Interface\AddOns`; originals of patched files in `<addon>\_CoA_original\`) |
| This repo | `C:\Users\dotyt\Documents\GitHub\coa-addons`: `Sync-ToRepo.bat` copies the live folders in; commit with GitHub Desktop |
| Re-apply kit | `C:\Users\dotyt\tools\zygor-coa\Apply-ZygorCoA.bat` (`--dry-run` to preview): zygor, tomtom, healbot, buttonforge. Regenerate with `kit\make_kit.py` |
| Tests | `C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe`, 28 tests (run by the kit) |
| Extensions.dll source | `C:\Users\dotyt\tools\ascension-extensions-reconstruction` |

## Server

- **Repo:** jealous-sound/azerothcore-wotlk-coa at 192.168.1.23. Build 4b0adf33 (includes #6244/#6297).
- **Realms:** **Nozdormu** (id 1, port 8086, CoA) and **Felstorm** (id 2, port 8087, Wildcard / Hero). They share `acore_auth` / `acore_world` and have separate characters / playerbots databases.
- **Server Claude session:** "media-stack-fa". Message it with SendMessage at `bridge:session_01Ueq5RwKeT3RDasVwkvetqg`; the address changes when that session is recreated, so always reply to the latest `from`.
- **Watcher:** runs at 5:47 and 8:47 AM Phoenix time and **expires ~10/10** unless renewed. Its messages arrive only while a session here runs with Remote Control on.
