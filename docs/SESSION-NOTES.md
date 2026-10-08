# Session notes: CoA client and addon work

Resume notes for Claude sessions. Last updated **2026-10-08** (Questie-X on CoA; progression V1 pending).

**To resume in a new session:**
> Read `C:\Users\dotyt\Documents\GitHub\coa-addons\docs\SESSION-NOTES.md` and the memory index.

The memory folder (`C:\Users\dotyt\.claude\projects\C--Users-dotyt-Desktop-Stream-Launcher-app\memory\`) loads automatically only for sessions started in `Desktop\Stream Launcher app`. From any other folder, ask the session to read `MEMORY.md` there.

## Working rules

- Lay out the plan and wait for the user's go-ahead before editing or creating files. The user reviews every diff and command.
- Show any script before running it.
- Ask before downloading anything, and give the size.
- "Research only" / "review only" means don't build.
- Keep this repo private, and keep the re-apply kit on this PC only. Scan anything going public for personal info first.
- Sidekick data: the user chose (10/04) to publish it in the public `coa-zygor` repo. Sidekick couldn't be reached, so the README invites them to ask for removal or credit.
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
| Extensions.dll | **Official launcher build since 10/05** (release 2026-10-05-01, firstoni a1d7f83). Our earlier 5197e75 build is in `coa-snapshots\before-update\files\` for rollback. Don't run `Restore-CoA-UI.bat` any more (it would restore the old 9/28 DLL and loose addons) |
| dbc_clientset | Item / ItemDisplayInfo / CreatureDisplayInfo.dbc from patch-M, in `C:\Users\dotyt\tools\dbc_clientset\`, copied to the server |
| Realm cards, spec slots | Realm cards per realm. Spec slots and Tomes II–XX work since server #6244/#6297 |
| Client update 2026-10-04 | Launcher release **2026-10-03-01** installed and compared (see "Client update" below) |
| Zygor taint fix (10/06) | `ZygorTalentAdvisorCOA\Load.lua` no longer re-assigns `StaticPopupDialogs`; that had blocked bind-on-use confirmations (Stones of Retreat). In coa-addons and coa-zygor. `Sync-ToRepo.bat` now refuses to run outside the repo root |
| Questie-X on CoA (10/08) | Detection patch (realm name → Ascension client API), map sizes for 26 CoA sub-maps (`CoAExtraZones.lua`), and **Questie-X-CoADB**, generated from the server's world DB (325 new + 499 changed quests). Confirmed in game. Tools and rebuild steps: `C:\Users\dotyt\tools\questie-x\README.md`. Kit targets `questie` / `questiedb`; suite is 29 tests |

## Client update (2026-10-04)

- **Snapshots:** made with `C:\Users\dotyt\tools\zygor-coa\client_snapshot.py`:
  - `snap <name>`: SHA-256 list of the client, plus copies of our customised files;
  - `diff <old> <new>`.
  They are in `C:\Users\dotyt\tools\coa-snapshots\`: `before-update` and `after-update-20261003-01`. `before-update\files\` has our Extensions.dll, d3d9.dll, the old patch-B/T/M, realmlist, renderer .ini files, WTF and the 28 removed `Ascension*` addon folders.
- **What changed:**
  - **patch-B (8 → 229 MB):** +289 `Interface\GLUES` art files, identical to the loose ones we already had. AccountLogin.lua and DressUpFrame.lua changed only in line endings. No GlueXML/FrameXML/addon code changed.
  - **patch-M:** only `CreatureDisplayInfo.dbc` changed (+13 records).
  - **patch-T, Ascension.exe:** unchanged.
  - **README.txt:** updated.
- **Addons removed by the launcher:**
  - the 28 loose `Ascension*` folders: 27 are built into patch-B; **AscensionRaidLootCompanion is not**, and it's backed up in the snapshot;
  - also **ProfessionMenu, Refactor, VanillaGuide and YABB** (not backed up; the launcher can reinstall them). It's not yet confirmed whether the user removed these.
- **Still on our builds:** our **Extensions.dll (5197e75)** and the **Modern Renderer d3d9.dll**.
  - The launcher wants to replace our DLL with the official one (6,865,920 bytes, sha256 b7760201…). That step fails on this PC: D: is **exFAT**, and the launcher's hard-link check throws `EISDIR`, which isn't in its fallback list.
  - Patching `app.asar` locally doesn't work: the launcher checks its own files and won't start. That was reverted; the backup is `app.asar.bak-20261004`.
  - No manual download exists, so **wait for a launcher hotfix**. Then snapshot again and compare their DLL with ours.
  - **Resolved 10/05.** The launcher's self-update added `EISDIR` to its fallback list. Release **2026-10-05-01** then installed the official Extensions.dll (6,878,208 bytes, sha256 28dce11b…).
    - The snapshot `after-official-dll` shows only the DLL changed.
    - It's firstoni's build of the reconstruction repo at **a1d7f83**. Its only code change over our 5197e75 is d9fcd12: cast-check and aura-removal callback order now match the original DLL.
    - The user kept the official DLL; an in-game test is pending.
    - The realmlist was not rewritten this time.
- **The launcher rewrites `Data\enUS\realmlist.wtf`** to `logon.coa-development.org` after every client update and every Play click. It was restored to `set realmlist 192.168.1.23` on 10/04. The user launches `Ascension.exe` directly, so it sticks until the next launcher update.
- **dbc_clientset:** refreshed 10/04 with the new CreatureDisplayInfo.dbc (sha256 225b019e…); the zip was rebuilt. The user copies it to the server.
- **Server update 10/04:** the server session checked the incoming commits (b392d4a5, e7c0ccab, 4c71515a, af8f4650): **no wire change, and nothing needs a DLL newer than 5197e75.** Item rows now also arrive after login, on demand.

## Waiting on the user

0. **Current (10/08):**
   - **Progression V1 on Nozdormu:** give the go after the 10/08 04:30 update verifies (raid gate #6771). Plan and reviewed script: `docs\PROGRESSION-PLAN.md`. V1 also sets the realm card to expansion 0, which replaces item 2 below for Nozdormu.
   - **Sync and commit** the Questie-X work (`Sync-ToRepo.bat`, then GitHub Desktop).
   - **A separate public repo for Questie-X on CoA:** requested 10/08.
   - **Mystic Enchants:** the server doesn't handle CMSG 0x60A (apply item to slot) or 0x60E (reforge slot). The server session offered to draft an upstream issue; the user hasn't decided.

1. **First play after the 10/04 client update.** Wait for the server session's "live and stable" message and copy `dbc_clientset.zip` to the server first. Then check:
   - items seen for the first time this session show an icon and name, not a red "?" (re-hover once);
   - Button Forge (`/reload`, bars, Create Bar, Advanced tools);
   - the talent advisor (panel, preview, Load build);
   - no UI errors at login.
   Button Forge is already committed. Sync and commit `client_snapshot.py` and these notes next time.
   **Result (10/04):** all fine. The only UI error was from TSM (a missing locale string in the launcher's customised TSM, harmless), and the user disabled TSM.
   Addons: the launcher removed ProfessionMenu, Refactor, VanillaGuide and YABB on its own; the user doesn't use them, so they stay removed. AscensionRaidLootCompanion is **not** built in (not in any MPQ); it's an optional addon in the launcher's catalog, and a backup is in the snapshot.
2. **Realm cards:** when convenient, ask the server session to change the RealmCards expansion from 2 to 0 for realm 1 (Nozdormu) and realm 2 (Felstorm), then restart the authserver.
   - Both realms are capped at 60, so "Vanilla (Progressive)" matches Ascension and is accurate.
   - The client only uses the card's expansion for display; the account's expansion stays at Wrath.
   - It also removes the "WotLK Alpha Bundle" notice (backlog item 4; kept in the backlog until done).
3. **Talent advisor "switch to spec slot + load build":** planned and reviewed; **don't build until the user says go**. Checks before building:
   - whether the talent window closes on a slot swap;
   - event timing after the swap;
   - loading into an empty slot;
   - whether `GetInspectedBuild` works on other slots.

## On the next client update (launcher)

1. Close the game and launcher, then run `python client_snapshot.py snap <name>`. The script is approved; running it still needs the user's go.
2. The user updates in the launcher. Don't start the game.
3. Snapshot again and `diff` the two. Diff the MPQ members of patch-B/M/T against the copies in the old snapshot.
4. Re-check the realmlist, and refresh `dbc_clientset` if Item / ItemDisplayInfo / CreatureDisplayInfo changed. patch-M is their only Data MPQ.
5. If the official Extensions.dll arrives, compare it with ours and with the reconstruction repo. Re-test the advisor and Zygor map data.

Details: memories `coa-client-patch-compare.md` and `coa-launcher.md`.

## Backlog (parked)

Retail-style character select (outline only), HealBot CoA spell gaps, the realm-card "WotLK" notice, the VanillaGuide error on new characters, TSM on Felstorm (C_Hook overflow, disabled), High Elf race (server says it doesn't fit as-is). Details: memory `coa-ideas-backlog.md`.

## Key paths

| What | Where |
|---|---|
| Client | `D:\COA Client` (addons in `Interface\AddOns`; originals of patched files in `<addon>\_CoA_original\`) |
| This repo | `C:\Users\dotyt\Documents\GitHub\coa-addons`: `Sync-ToRepo.bat` copies the live folders in; commit with GitHub Desktop |
| Public repos | `coa-zygor`, `coa-tomtom`, `coa-healbot`, `coa-buttonforge` in `Documents\GitHub\` (published 10/04). `Sync-ToRepo.bat` also updates them; commit each one that shows changes |
| Re-apply kit | `C:\Users\dotyt\tools\zygor-coa\Apply-ZygorCoA.bat` (`--dry-run` to preview): zygor, tomtom, healbot, buttonforge. Regenerate with `kit\make_kit.py` |
| Tests | `C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe`, 28 tests (run by the kit) |
| Extensions.dll source | `C:\Users\dotyt\tools\ascension-extensions-reconstruction` |
| Client snapshots | `C:\Users\dotyt\tools\zygor-coa\client_snapshot.py` → `C:\Users\dotyt\tools\coa-snapshots\` |
| CoA launcher | `%LOCALAPPDATA%\Programs\ConquestOfAzeroth\` (settings in `%APPDATA%\Conquest of AzerothCore\settings.json`, state in `D:\COA Client\.coa-launcher\`) |

## Server

- **Repo:** jealous-sound/azerothcore-wotlk-coa at 192.168.1.23. Build 4b0adf33 (includes #6244/#6297).
- **Realms:** **Nozdormu** (id 1, port 8086, CoA) and **Felstorm** (id 2, port 8087, Wildcard / Hero). They share `acore_auth` / `acore_world` and have separate characters / playerbots databases.
- **Server Claude session:** "media-stack-fa". Message it with SendMessage at `bridge:session_01Ueq5RwKeT3RDasVwkvetqg`; the address changes when that session is recreated, so always reply to the latest `from`.
- **Watcher:** runs at 5:47 and 8:47 AM Phoenix time and **expires ~10/10** unless renewed. Its messages arrive only while a session here runs with Remote Control on.
