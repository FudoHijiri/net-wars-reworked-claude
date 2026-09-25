# Development Reference — Audit of net-wars-reworked and the-spire

Audit date: 2026-09-13. Read-only inspection; nothing in either project was modified during this audit.

This document exists so future implementation work does not re-derive architecture decisions from scratch. It records what exists today in both projects, what should be reused vs. rebuilt, and the recommended shape of the new five-phase architecture. See `CLAUDE.md` for the permanent project rules and the original design handoff.

---

## 1. Current/New Project — `D:\GitHub\net-wars-reworked`

**Status: empty.** This is a brand-new Godot 4.7 project skeleton with no gameplay code whatsoever.

```
net-wars-reworked/
├── CLAUDE.md          ← design handoff document (prose/diagrams only)
├── project.godot      ← default settings, Godot 4.7, GL Compatibility
├── icon.svg           ← stock Godot icon
└── .godot/            ← editor cache (gitignored)
```

- `project.godot`: Godot **4.7**, `renderer/rendering_method="gl_compatibility"`. No `[autoload]` section, no `[input]` map, no `[editor_plugins]`. A stray `[dotnet]` section exists (assembly name "NetWars") but no C# files exist — leftover from project creation, safe to ignore or remove.
- No scenes, no scripts, no `.tres` resources, no `assets/` folder, no `GameState` or `ScenarioManager` autoload.
- No `.git/` directory currently exists here, despite `.gitignore`/`.gitattributes` being present — version control has not been initialized yet.

**Implication:** there is nothing to preserve or migrate in this project. All five phases start from a blank slate. The only existing "asset" is the design document itself.

---

## 2. Previous Project — `D:\GitHub\the-spire`

**Status: a working prototype, already cybersecurity-themed**, not a generic Slay-the-Spire clone. Card names ("Review Logs," "MFA," "Host Isolation"), enemy types ("Ransomware," "Phishing," "DDoS Attack"), and win-condition framing (Containment / Integrity / Breach meters) are already aligned with the new game's domain — this is a significant head start for the Response phase specifically.

Godot version: **4.6** (vs. 4.7 in the new project — one minor version behind; no known 4.6→4.7 breaking API usage was observed in the scripts read, but this should be verified during actual migration/testing, not assumed).

### 2.1 Directory overview

```
the-spire/
├── project.godot              (autoloads: Music, GameManager, GlobalVars, SceneLoader, MCPGameBridge)
├── GameController.gd/.tscn    (root scene — swaps sub-scenes: MainMenu/StageSelect/EditDeck/PlayUI)
├── CSV/
│   ├── cards.csv               ← 33 cards, richest data source (incl. per-threat effectiveness, lore, hints)
│   └── threats.csv             ← 9 threat/"enemy" type definitions
├── Scenes/
│   ├── play_ui.tscn            ← THE combat scene (see §2.2)
│   ├── card_node.tscn          ← single reusable Card UI prefab
│   ├── EditDeck.tscn, ShopUI.tscn, PauseMenu.tscn, Tutorial.tscn, settings_ui.tscn
│   ├── main_menu.tscn, stage_select.tscn, story_intro.tscn
│   └── information_book.tscn, loading_screen.tscn
├── Scripts/
│   ├── CardNode.gd, DeckManager.gd, PlayUI.gd, EditDeck.gd
│   ├── Autoloader/GlobalVars.gd, Autoloader/scene_loader.gd
│   └── Menus/MainMenu.gd, Menus/PauseMenu.gd, Menus/Settings.gd
├── UI_script/
│   ├── GameManager.gd (autoload), StageSelect.gd, InformationBook.gd
│   └── BootSequence.gd, MatrixRain.gd, ScreenGlow.gd, TitleLabel.gd, ParallaxMouseDrift.gd, music.gd
├── addons/godot_mcp/           ← third-party AI dev-tooling plugin, irrelevant to gameplay
└── UI_asset/, Ui asset/        ← fonts, card art, one music track, decorative office pixel-art packs
```

Known dead/legacy code present (do not mistake these for the active systems): `global_vars.gd` (root duplicate of the real `GlobalVars` autoload), `Scripts/PauseMenu.gd` (empty stub — the real one is `Scripts/Menus/PauseMenu.gd`), `UI_script/CodexData.gd` (empty file), `julia.gd` / `inGameUI.gd` / `inGameUI.tscn` (legacy office-sim prototype, not part of the active scene flow), `Day1.tscn` (empty stub), unused `GameManager.STAGE_SCENES` paths pointing to nonexistent files, and a loading-screen signal-name typo (`_on_load_funished` vs. `_on_load_finished`) that silently breaks the load fade-out.

### 2.2 The Response/card-combat architecture

**There is no `Card.gd` or `Enemy.gd` Resource class.** Cards are plain `Dictionary` objects (`id`, `name`, `type`, `energy`, `logic`, `tooltip`); the `logic` field is a **free-text string** later parsed by substring matching. Content is authored in **three separate, manually-synced places**: `CSV/cards.csv` (richest, used only by the Codex/deck-builder fallback), `ShopUI.gd`'s hardcoded `ALL_CARDS` array (what the shop and deck-builder actually use in normal play), and `PlayUI.gd`'s `STARTER_CARDS` fallback constant. CLAUDE.md-equivalent notes in that repo already flag this triplication as a manual-sync burden.

Key pieces:

| Component | File | Reusability |
|---|---|---|
| Card UI view | `Scripts/CardNode.gd` + `Scenes/card_node.tscn` | **Reuse directly.** Pure view over a Dictionary; no theming lock-in. |
| Deck/hand/discard management | `Scripts/DeckManager.gd` | **Reuse directly.** Generic draw/shuffle/discard logic, zero StS-specific coupling. |
| Combat engine (turns, HUD, win/loss) | `Scripts/PlayUI.gd` | **Adapt, do not lift as-is.** See below. |
| Card-effect execution | Inside `PlayUI._apply_card_effect()` | **Rebuild.** String-matching interpreter (`"Containment" in line`), fragile and inseparable from the combat scene. |
| Boss/threat behavior | `PlayUI._load_current_threat()` (CSV-driven) | **Rebuild the "acting boss" part; reuse the reveal concept.** Threats are currently passive data records (alerts + clues revealed over time) with no HP, no intents, no attack patterns — closer to a "mystery to solve under time pressure" than a Slay-the-Spire monster. |
| Status effects/buffs | None — a few one-off scalar variables (`breach_per_turn`, `intel_cost_reduction`, `max_energy`) hacked in via the same string-matching | **Rebuild** as a proper system if the new Response phase needs stacking/duration-based effects. Note: some "each turn" recurring-effect cards in the current code only fire once at play time — a latent bug, not a working per-turn tick system. |
| Content library | `CSV/cards.csv`, `CSV/threats.csv` | **Reuse as seed content.** 33 cards and 9 threats, all cybersecurity-authentic, no StS lore (no relics/potions/classes) to strip out. |
| Tutorial overlay | `Scripts/Tutorial.gd` | **Reuse directly.** Generic step/highlight system driven by an `Array[Dictionary]`. |

Combat scene structure (`Scenes/play_ui.tscn`, root `Control` + `PlayUI.gd`): HUD with Integrity/Containment/Breach progress bars, an Alert/Clue reveal panel (threat identity hidden until fully revealed), a hand/deck/discard strip, and a result panel. `PlayUI.gd` currently conflates turn management, HUD rendering, card-effect resolution, and threat-reveal logic in one script — the single most important file to study before extending, and the one that most needs to be split apart before new mechanics (an actively-behaving boss, a real status-effect stack) can be layered on.

**Dependencies the old Response system pulls in:** `GlobalVars` (autoload, holds `player_deck` and cross-scene refs), `GameManager` (autoload, day/save progression via `ConfigFile`), `ShopUI.ALL_CARDS` (card source of truth for shop + deck-builder), CSV parsing logic duplicated independently in three places (`PlayUI`, `EditDeck`, `InformationBook`). Any reused Response engine needs to either bring equivalent autoloads/data sources into the new project or be re-wired to the new project's `GameState`/scenario-data system.

Full raw findings (every script and scene individually, asset paths, etc.) are preserved in the audit transcript from this session and are not re-duplicated here — this document keeps only what's decision-relevant.

---

## 3. Architectural Conflicts & Risks

1. **Godot version drift (4.6 vs 4.7).** Low risk based on what was read, but not yet verified — test any ported script in the 4.7 editor before trusting it.
2. **Dictionary-based cards vs. the new project's stated preference for `Resource` files.** CLAUDE.md's own scenario-data section says "Godot `Resource` files may be used instead of dictionaries if preferred" — this is a natural point to upgrade the data model (e.g. a `CardDef` Resource, a `ThreatDef` Resource) rather than dragging the three-way CSV/ShopUI/PlayUI duplication forward into the new project.
3. **String-matched effect resolution does not fit the "data-driven, add-a-threat-without-rewriting-core-systems" requirement** in CLAUDE.md §3/§13. If ported as-is, every new card effect for a new threat scenario would require editing a shared `if/elif` block in the combat script — directly contradicting the data-driven design goal. This is the one piece of the old Response system that should be redesigned (structured effect data, e.g. `effects: Array[Dictionary]` with a typed `effect_id`) rather than copied.
4. **No active boss behavior exists to reuse.** CLAUDE.md's Response phase (§8) expects the boss to "attempt to" take actions (create unauthorized logins, spread access, etc.) and for the player to "react to changing threat behavior." The old project's threats are passive. This is net-new work, not a migration task.
5. **GameState field names already anticipate the new architecture** (`response_deck`, `passive_upgrades`, `damaged_components`, etc. — CLAUDE.md §3) and do **not** correspond 1:1 to old-project globals (`containment`/`integrity`/`breach` on `PlayUI`, `player_deck` on `GlobalVars`). Whoever implements Response will need an explicit mapping/adapter layer between the old combat engine's internal state and `GameState`'s cross-phase fields — this should be designed deliberately, not left implicit.
6. **the-spire's autoloads (`Music`, `GameManager`, `GlobalVars`, `SceneLoader`) are progression/menu-shell singletons**, not Response-specific. If Response scripts are ported, decide explicitly whether the new project adopts equivalent autoloads or whether `GameState` alone absorbs their responsibilities — mixing both approaches would recreate the old project's duplication problem in the new one.

---

## 4. Recommendation Summary

**Reuse as-is:** `CardNode.gd`/`card_node.tscn` (card view), `DeckManager.gd` (deck/hand/discard), `Tutorial.gd` (onboarding overlay), and the `CSV/cards.csv` + `CSV/threats.csv` content as seed data for the Response phase's initial card/threat library.

**Adapt (structure, don't recreate):** the overall combat-scene layout and the Integrity/Containment/Breach three-meter concept from `PlayUI.gd` — but split its responsibilities (turn management, HUD, effect resolution, threat reveal) into separate, data-driven pieces before extending it, and replace the string-matched effect interpreter with structured effect data.

**Build new:** an active boss/intent system (the old project has none), a generic status-effect/buff-duration system, a `GameState`-integration layer that maps the Response engine's internal combat state onto `GameState.system_integrity` / `damaged_components` / `response_deck` etc., and — per CLAUDE.md's existing five-phase scope — all of Investigation, Monitoring, Hardening, and Recovery, none of which exist in either project today.

**Do not** copy `the-spire`'s Slay-the-Spire-era autoload/menu-shell layer (`GameManager`, `GlobalVars`, `SceneLoader`) wholesale — design the new project's `GameState`/`ScenarioManager` autoloads per CLAUDE.md §3 first, and pull in only the specific old-project logic (deck/hand/discard, card view, effect ideas) needed to serve that architecture.

---

## 5. Recommended Next Implementation Step

Per CLAUDE.md §14 ("Development Priority"), the first bounded task should be **Prototype 1: scaffold the overall scenario flow** — the `GameState` autoload, the `ScenarioManager`, placeholder scenes for all five phases wired together by scene transitions, and one placeholder `Scenario` data definition (e.g. `credential_abuse`) flowing through `Investigation → Monitoring → Hardening → Response → Recovery → back to menu`. This does not require touching `the-spire` at all and establishes the data-driven scaffold that the Response-phase reuse work (Prototype 5) will plug into later. Do not begin porting `the-spire`'s combat code until this scaffold and its `GameState` field set exist, so the Response phase has somewhere correct to write its output.
