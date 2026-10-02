# Idea for later: "card pack" spell progression (Wildcard variant) — handoff for the server-side session

Written 2026-09-30 by the Claude session that works on the **game client** (gaming PC), for the Claude session that maintains the **CoA server**.

**Status: back burner.** Nothing to build yet. Revisit once the Wildcard work below has settled and the client patch matches the server again (see "Dependencies").

## The idea

Take the OSRS "TCG plugin" loop (earn XP → earn card packs → open them → cards are in-game things) and use it for CoA progression:

- Playing and leveling earns **card packs**.
- A card pack is a **physical item in the bags**. Using it opens the client's existing card-pack window and plays its reveal animation.
- Cards grant **spells/talents**, plus maybe the odd **item**. Spells come from packs instead of Wildcard's dice rolls.

It fits naturally as a **mode or option of Wildcard**: the same card machinery, but packs replace the Dice of Destiny rolls as the main way to gain abilities.

## What already exists

### Server: PR #5861 "Wildcard" (jealous-sound/azerothcore-wotlk-coa, opened 2026-09-30, open at time of writing)

From its description, it already implements most of the plumbing:

- **Skill cards:** card slots and starter cards; **card packs** (pending cards, reveal, Darkmoon Tickets, duplicates filling the bonus pack bar); talent card purchases at SealedCardCosts prices; Silas' card store; **card drops from creatures**.
- **Silas Darkmoon:** leveling and max-level reward tracks paid in Runes of Ascension, plus **booster packs**. Silas and Burth stand in capitals, starting zones and early hubs.
- Rolls with **synergy weighting** (`wildcard.conf.dist`, default 65 %), 20 specializations, prestige, Runes of Ascension, Call Boards.
- The PR says these are unconfirmed: ticket payout per card, **pack rarity odds**, the bonus pack, the quick-roll threshold, reward-track counts, and starter weapon item IDs.

### Client: the card UI is already in the client patch (`Interface\AddOns\Ascension_SkillCards`)

Read on the client PC. These are the parts that matter for packs as items:

- **Packs are bag items.** `SkillCardUnlockFrame\SkillCardBoosterActionBar.lua` lists the booster items in the bags (`GetItemCount`, `boosterItemsRO`) and opens one per click. There is also a golden booster bar and a free booster.
- **Using a pack from the bags:** the client fires **`SKILL_CARD_COLLECTION_ITEM_USED(itemID)`**. `SkillCardUnlockFrameMixin` then classifies it with `SkillCardUtil.DefineCardType(itemID)` and opens it through the booster bar (`UseItemID`). The pack-opening window and the mass-reveal animation (`MassReveal\SkillCardMassRevealAnimation.lua`) are already there.
- **Other events the UI listens for:** `SKILL_CARD_UPDATED`, `SKILL_CARD_AUTO_REVEALED(cardID, rank)`, `CLAIM_SKILL_CARD_RESULT`, `PENDING_SKILL_CARD_REMOVED(pendingIndex, cardID)`, `BONUS_SEALED_CARD_PACK_REWARDED`, `PURCHASE_SEALED_CARD_RESULT`, `SKILL_CARD_BLOCKED` / `UNBLOCKED`, `SKILL_CARD_REMOVAL`.
- **APIs it calls:** `C_SkillCard.GetSkillCardInfoAtIndex / GetMaxCardCount / GetSkillCardQuality / IsCardAtIndexBlocked`, `C_SkillCardCollection.IsCollected / PurchaseSealedCard / CanPurchaseSealedCard / GetSealedCardCost`, and `C_CharacterAdvancement.GetEntryBySpellID / IsKnownSpellID / GetQualityLimit`.
- **Card data:** `Data\Content\SkillCardData.json` (2.4 MB) maps card entries to spells, with `IsGolden` / `IsLucky` variants. Example: `{"Entry":97731,"IsLucky":true,"Spell":19801}`.

Those events and APIs come from the client executable / Extensions.dll and are driven by server packets. **Which packets feed them is not mapped here.** #5861's harness additions ("field types and metrics for the new packets") should already cover them.

## Proposed design (to evaluate, not settled)

1. **Earning packs.** Track XP or levels per character and grant a pack item at configurable milestones, for example every N thousand XP, or per level with bonus packs at level brackets. Optionally also from dungeon or raid bosses (as Runes of Ascension already work) and from Silas' tracks.
2. **Pack = item.** Use the booster item IDs the client UI already recognises (`SkillCardUtil.DefineCardType`), so using one goes through `SKILL_CARD_COLLECTION_ITEM_USED` and the existing reveal flow. Decide whether packs are soulbound, or tradeable / sellable on the auction house (an economy question, especially with playerbots).
3. **Card pool.** The character's class/spec abilities and talents (Character Advancement entries), split into rarity tiers. Weight them toward the character's level bracket so a level-5 pack doesn't hand out level-60 spells. Reuse #5861's synergy scoring so packs favour cards that fit the build. Golden/Lucky variants come from the existing data.
4. **Duplicates** turn into Darkmoon Tickets or bonus-pack progress (#5861 already does this).
5. **Optional item cards:** a small chance of a real item, rolled through the normal loot code.
6. **Config switch.** A setting that makes packs the main ability source in place of Dice of Destiny level-up rolls. It's a variant of Wildcard, not a fork.

## Things to watch

- **Balance:** pure random packs can leave a character without a core ability. Guarantee per-bracket essentials, or use pity timers or the synergy weighting.
- **Playerbots** won't open packs or choose cards by themselves, so bots need a rule (for example, auto-learning by level, as they presumably do now).
- **The client UI has fixed expectations.** Card types the existing UI doesn't know would need changes to `Ascension_SkillCards` (a loose copy in Interface\AddOns can override the patch's version; the client session can do that).

## Dependencies / blockers

- **Client patch mismatch (#5852).** The current client patch (9/28, revision 8) predates #5507's switch to native Extensions.dll packets, so card features that depend on that protocol may not work until a matching client patch exists. The client PC is running Ascension.exe with an older reconstructed Extensions.dll and the modified patch-B.
- **#5861 needs to land** (or be tested locally) first, since this builds on its card and pack code.

## Client-side help available

The client session can:
- trace exactly how the booster bar and the reveal frame react to each event;
- confirm which booster item IDs `SkillCardUtil.DefineCardType` accepts;
- test pack opening in game against a test realm;
- adjust `Ascension_SkillCards` if new card types are needed.

It also has a Python MPQ reader for pulling client data files (DBCs, built-in UI code) when needed.

*Written with Claude (Anthropic's AI assistant).*
