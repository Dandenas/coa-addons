# CoA client ↔ server mismatch — handoff for the client-side check

Written 2026-09-30 by the Claude session that installed the server. Hand this file to the Claude working on
the **gaming PC (game client)**. It explains what's wrong, what the server now expects, and what to report back.

## The symptom

Every login, for about 15 seconds, the chat fills with:

```
Command 'LocalSpecstate' does not exist
```

That text is the server's standard "unknown dot-command" reply (`acore_string` #6). Something on the
**client** sends `.localspecstate` as a chat message over and over right after login, and the server rejects
each one.

## Why it happens

- The server is **Conquest of Azeroth** (`jealous-sound/azerothcore-wotlk-coa`), built at commit **`b4aaf794`**
  (2026-09-30), with CoA playerbots (`Zyth45/mod-playerbots`, branch `coa`, `b9413a1d`).
- On **2026-09-28**, upstream commit **`2d13ffd7`** ("talk to the client through native Extensions.dll
  packets only", PR #5507) **removed every chat-command and whisper side channel** the older CoA client
  patch's Lua workarounds used. The server now talks to the client only through native packets, handled by a
  rebuilt `Extensions.dll`.
- The client appears to be running the **older client patch** (from before 9/28). It still sends the removed
  commands, so they bounce.

Removed server-side on 9/28 (anything on the client that sends these is obsolete for this server):

| Kind | Names |
|---|---|
| Dot-commands (sent as chat) | `.localspecstate`, `.localspec`, `.localtalent`, `.localappearance`, `.localvanity`, `.localcharges`, `.extprobe` |
| Addon whispers | `ASC_LOCAL_SPEC`, `ASC_LOCAL_TALENTS`, `ASC_LOCAL_RECORDS`, `ASC_LOCAL_RESOURCE`, `ASC_LOCAL_CAD`, `ASC_LOCAL_ECHOES` (plus the Reaper, Runemaster-echoes and Manastorm addon whispers) |

What replaced them (server side, already live):
- Specialization switch → client packet `CMSG 0x0727` (ChrSpecs identity/signature entries; a pure switch
  restores the stored build).
- Talent reset → stock `CMSG_UNLEARN_TALENTS`.
- Bug reports → `CMSG_CREATE_BUG_REPORT` (0x0562), answered with SMSG 0x0565 / 0x0566.
- World packet headers → the stock 3.3.5a header cipher (the old "plaintext world headers" mode is gone).

**Likely more than cosmetic:** with the old patch, **spec switching, talent saves, and possibly
appearance/vanity/charges** probably went through the removed commands, so they may silently fail. Please
test these (see the checklist below).

## What the client needs

A client that matches a server from **after 2026-09-28**:

1. **The rebuilt `Extensions.dll`** from **https://github.com/firstoni-dev/ascension-extensions-reconstruction**
   (last pushed 2026-09-30).
   - **No release downloads** — it has to be built from source on Windows:
     32-bit MSVC (Visual Studio 2022 Build Tools), CMake and Ninja, from an **x86** developer prompt
     (`vcvars32.bat`):
     ```bat
     cmake -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -S . -B build
     cmake --build build
     ```
   - Output: `build\Extensions.dll`. Put it **next to `Ascension.exe`** (the exe loads it itself; no
     injector). Back up the existing `Extensions.dll` first if there is one.
   - Debug log: start the client with `-extlog 1` → `Logs\Extensions.log`.
   - It uses stock SRP6 login, which is what this server's authserver expects.
   - Its README says to set `CoA.PlaintextWorldHeaders = 0` on the server. **Ignore that:** the setting was
     removed on 9/28, and this server already uses the stock header cipher.
2. **Remove or update the old client-patch Lua** that sends the commands above. Find whatever addon, or
   `Interface` / patch-MPQ Lua, calls `SendChatMessage(".localspecstate" ...)` or `.localspec` /
   `.localtalent`, or whispers `ASC_LOCAL_*`. An updated client patch built for the post-9/28 server is most
   likely on CoA's Discord (`discord.gg/k7qpSndvW`).
3. **Leave the SquidBotsLite addon alone.** It's the playerbots UI (from the CoA Bots package) and only sends
   `.playerbots ...` commands plus whispers to bots. It is **not** the source of this problem.

## Checklist: find out and report back

- [ ] Where is `.localspecstate` sent from? (addon name / file path / MPQ)
- [ ] Which `Extensions.dll` does the client have now? (file date and size; genuine Ascension, an older
      reconstruction, or none)
- [ ] Before changing anything, in game: does **switching specialization** work? Do **talent changes save**
      and survive a relog? Do appearance/vanity collections work?
- [ ] After installing the rebuilt DLL and removing/updating the old Lua: is the chat spam gone, and do
      spec/talents work?
- [ ] Any new problem after the change? (stuck at "Authenticating", disconnects, missing UI)

## Server facts (for reference)

| | |
|---|---|
| Realm address | `192.168.1.23` (realmlist; auth port 3724, world port **8086**) |
| Realm name | Conquest of Azeroth |
| Account | `DANDENAS` (GM 3) |
| Server code | `jealous-sound/azerothcore-wotlk-coa` @ `b4aaf794` (2026-09-30) |
| The change | `2d13ffd7` (2026-09-28); the last commit before it is `dcadf4db` |
| Server notes | `media-stack/COA/NOTES.md` on the server host |

## Fallback if the client can't be updated

The server can be rolled back to `dcadf4db` (just before the change), which brings the old commands back to
match the current client. The catch: the latest CoA playerbots were written against newer server code and may
need fixes to build there. That's a server-side job. Report back and the server-side session will handle it.
