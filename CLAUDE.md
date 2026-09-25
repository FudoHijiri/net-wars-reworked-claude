# Cybersecurity Educational Game — Godot Development Handoff

## 0. Permanent Project Rules

These rules apply to all work in this project and override default behavior. They do not expire and are not specific to any single task.

1. **Godot 4.7 + GDScript only.** Do not use Godot 3.x syntax or deprecated APIs. Do not introduce C# even though `project.godot` has a leftover `[dotnet]` section from project creation.
2. **2D only.** No 3D nodes, no 3D physics, no 3D assets.
3. **Placeholder assets until official art arrives.** Do not create or source final visual/audio assets.
4. **Reuse existing systems where appropriate**, both within this project and from the reference project at `D:\GitHub\the-spire`. Check `PROJECT_REFERENCE.md` before building a new system from scratch.
5. **Do not recreate the existing Response/card-combat gameplay unnecessarily.** `the-spire` already has a working (if imperfect) card-combat engine that is already cybersecurity-themed. Adapt and extend it per `PROJECT_REFERENCE.md` §4 rather than writing a new one from zero.
6. **Do not modify `D:\GitHub\the-spire` unless explicitly instructed.** It is a read-only reference project. Copy or port logic into this project instead of editing the source.
7. **General-audience accessibility.** Assume no prior cybersecurity, command-line, scripting, or enterprise-security knowledge. Every mechanic should be learnable by interacting with it.
8. **Data-driven scenario design.** New threats/scenarios must be addable via scenario data (Resources or dictionaries), not by writing new gameplay code per threat.
9. **Five connected phases.** Investigation → Monitoring → Hardening → Response → Recovery must remain one continuous incident with data flowing forward (see §12), not five independent minigames.
10. **Do not implement future systems when working on a bounded task.** Build only the phase/feature currently in scope; do not pre-build later phases "while you're in there."
11. **Scenario story is day-specific, not a global intro.** The Title Menu must appear before any threat-specific story. A selected Day begins its own Visual Novel story, and story segments can appear between objectives and at the end of the Day.
12. **Day 1 contains integrated tutorials for all five gameplay systems.** Tutorials should teach by guided interaction inside the actual scenario and should not be separate training levels unless explicitly requested.
13. **Completed Days are replayable, but new Days unlock sequentially.** Day 1 unlocks Day 2, Day 2 unlocks Day 3, and so on.

## 1. Project Overview

Create a **2D, single-player, scenario-based cybersecurity educational game** in **Godot 4.7 using GDScript**.

The player takes the role of a security analyst responsible for protecting an organization from cybersecurity threats. The game is intended for a **general audience**, including players with little or no prior cybersecurity knowledge.

The game uses a continuous scenario/story structure. Each scenario is represented as a Day and contains five connected gameplay objectives:

**Investigation → Monitoring → Hardening → Response → Recovery**

The player's actions and performance in one objective affect the following objectives.

The game uses gameplay-first learning. Cybersecurity concepts should be learned through player interaction, decisions, consequences, and short contextual explanations rather than requiring prior technical knowledge.

The threat scenarios are fixed and must be implemented in this order:

1. Credential Abuse
2. Malware
3. Ransomware
4. Insider Threat
5. Data Exfiltration
6. Distributed Denial-of-Service (DDoS)
7. Phishing
8. Web Application Attack

Day mapping:

- Day 1 = Credential Abuse
- Day 2 = Malware
- Day 3 = Ransomware
- Day 4 = Insider Threat
- Day 5 = Data Exfiltration
- Day 6 = Distributed Denial-of-Service (DDoS)
- Day 7 = Phishing
- Day 8 = Web Application Attack

New Days unlock sequentially. Completed Days may be replayed freely.


---

# 2. Core Scenario Flow

The global game flow and Day flow are separate.

## Global Game Flow

```text
GAME START
    ↓
TITLE MENU
    ├── Play
    ├── Settings
    ├── Credits
    └── Exit
    ↓
PLAY
    ↓
SCENARIO BOOK / DAY SELECTION
    ↓
SELECT UNLOCKED DAY
```

Do NOT display scenario-specific story before the Title Menu.

## Day Flow

After the player selects a Day:

```text
DAY INTRODUCTION STORY
        ↓
INVESTIGATION
        ↓
BETWEEN-OBJECTIVE STORY
        ↓
MONITORING
        ↓
BETWEEN-OBJECTIVE STORY
        ↓
HARDENING
        ↓
BETWEEN-OBJECTIVE STORY
        ↓
RESPONSE
        ↓
BETWEEN-OBJECTIVE STORY
        ↓
RECOVERY
        ↓
DAY CONCLUSION STORY
        ↓
SCENARIO COMPLETE
        ↓
REVEAL COMPLETED DAY THREAT
        ↓
UNLOCK NEXT DAY
```

Story is used to provide narrative direction, context, and educational reinforcement between objectives.

## Day Selection

The Scenario Book initially displays:

```text
Day 1 - ???
Day 2 - LOCKED
Day 3 - LOCKED
...
```

After completing Day 1:

```text
Day 1 - Credential Abuse
Day 2 - ???
Day 3 - LOCKED
...
```

The same pattern continues through Day 8.

A completed Day remains available for replay.

## Day 1 Tutorial Flow

Day 1 introduces the gameplay systems through integrated tutorials:

```text
DAY 1 INTRODUCTION STORY
        ↓
INVESTIGATION TUTORIAL + INVESTIGATION
        ↓
STORY
        ↓
MONITORING TUTORIAL + MONITORING
        ↓
STORY
        ↓
HARDENING TUTORIAL + HARDENING
        ↓
STORY
        ↓
RESPONSE TUTORIAL + RESPONSE
        ↓
STORY
        ↓
RECOVERY TUTORIAL + RECOVERY
        ↓
DAY CONCLUSION STORY
```

Later Days should skip completed tutorials by default while allowing tutorials to be viewed again if a future UI supports it.

A `ScenarioManager` should control overall Day progression and scenario data.


---

# 3. Suggested Godot Structure

Use separate scenes for major game states while keeping story segments reusable.

```text
Main
├── MainMenu
├── ScenarioBook
├── StoryScene
├── InvestigationScene
├── MonitoringScene
├── HardeningScene
├── ResponseScene
├── RecoveryScene
└── ScenarioResult
```

Do not create a permanent `ScenarioIntro` that runs before the Title Menu. The reusable `StoryScene` is loaded only when a Day's story segment is active.

Suggested Autoload/singleton:

```text
GameState
```

The `GameState` should maintain information that needs to persist between scenes.

Example data:

```gdscript
var current_day: int
var current_threat: String
var scenario_data

var investigation_evidence: Array
var identified_threat: String

var investigation_tutorial_completed: bool = false
var monitoring_tutorial_completed: bool = false
var hardening_tutorial_completed: bool = false
var response_tutorial_completed: bool = false
var recovery_tutorial_completed: bool = false

var security_points: int
var monitoring_score: int
var reported_anomalies: Array

var purchased_defenses: Array
var response_deck: Array
var passive_upgrades: Array

var system_integrity: int
var max_system_integrity: int
var damaged_components: Array
var threat_defeated: bool = false

var repaired_components: Array

var scenario_completed: bool = false
var unlocked_days: Array
var completed_days: Array
```

Tutorial completion state persists between Days so that completed tutorials do not need to be repeated on later Days by default.

Keep scenario-specific information data-driven rather than hard-coded into individual scenes.


---

# 4. Scenario Data

Each threat should have its own scenario definition. Scenario data must include story segments as well as gameplay data.

Recommended structure:

```text
Scenario
├── ID
├── Threat Name
├── Day
├── Introduction Story
├── Investigation-to-Monitoring Story
├── Monitoring-to-Hardening Story
├── Hardening-to-Response Story
├── Response-to-Recovery Story
├── Conclusion Story
├── Tutorial Data
├── Investigation Data
├── Monitoring Data
├── Hardening Shop Pool
├── Response Boss Data
└── Recovery Data
```

Example concept:

```gdscript
{
    "id": "credential_abuse",
    "day": 1,
    "threat_name": "Credential Abuse",

    "story": {
        "introduction": [...],
        "investigation_to_monitoring": [...],
        "monitoring_to_hardening": [...],
        "hardening_to_response": [...],
        "response_to_recovery": [...],
        "conclusion": [...]
    },

    "tutorials": {
        "investigation": [...],
        "monitoring": [...],
        "hardening": [...],
        "response": [...],
        "recovery": [...]
    },

    "investigation": {...},
    "monitoring": {...},
    "hardening": {...},
    "response": {...},
    "recovery": {...}
}
```

Godot `Resource` files may be used instead of dictionaries if preferred.

The architecture must make it possible to add a new threat without rewriting the core gameplay systems.

Scenario-specific story, evidence, anomalies, shop contents, boss behavior, and recovery conditions must come from scenario data rather than being hard-coded into generic gameplay scenes.


---

# 5. Story and Tutorial System

## Gameplay Role

Story and tutorials provide context and teach the player how to interact with the current objective. They are not independent gameplay phases.

## Visual Novel Presentation

Story uses a reusable Visual Novel-style presentation:

- Character art
- Speaker name
- Dialogue text box
- Background
- Sequential dialogue

Use placeholder character art/backgrounds until official assets are provided.

## Story Placement

Story may appear:

- When a Day begins
- Between objectives
- Immediately before a gameplay phase when context is needed
- After an objective
- At the end of a Day

The story between objectives should explain why the next objective is necessary in the current incident.

## Tutorial Design

Day 1 must teach each gameplay system through guided interaction inside the real gameplay.

Tutorial sequence:

1. Investigation Tutorial
2. Monitoring Tutorial
3. Hardening Tutorial
4. Response Tutorial
5. Recovery Tutorial

A tutorial should:

1. Explain the immediate goal in simple language.
2. Point out what the player can interact with.
3. Require the player to perform the action.
4. Give immediate feedback.
5. Release control into the normal gameplay once the mechanic is understood.

Avoid long instructional screens. Assume no prior cybersecurity knowledge.

Store tutorial completion in `GameState`. Later Days should normally skip completed tutorials.

---

# 6. Investigation Phase

## Gameplay Type

**Detective Point & Click / Evidence Investigation**

## Purpose

The player investigates an ongoing incident by searching through information on a virtual computer.

The player must discover enough evidence to identify the threat.

---

## 5.1 Security Desktop

Create a desktop-style interface:

```text
┌─────────────────────────────────────────────┐
│              SECURITY DESKTOP               │
│                                             │
│   📧 Email              📋 Logs              │
│   💻 Computers          🔑 Login Activity    │
│   📁 Files              🌐 Network           │
│   🖥 Servers             📢 Reports           │
│                                             │
│   ⊞ Taskbar                                │
└─────────────────────────────────────────────┘
```

Eight applications must be available:

- Email
- Logs
- Computers
- Login Activity
- Files
- Network
- Servers
- Reports

Each application opens its own window/panel.

The applications should contain both **normal information** and **relevant evidence**.

---

## 5.2 Player Actions

The player can:

1. Open an application.
2. Inspect entries/information.
3. Click suspicious or relevant information.
4. Mark information as evidence.
5. Review collected evidence.
6. Compare evidence from different applications.
7. Eliminate possible threats.
8. Select the suspected threat.
9. Confirm the conclusion.

---

## 5.3 Evidence System

Evidence should not instantly reveal the answer.

Example for Credential Abuse:

```text
Login Activity
→ 02:43 — Anna — Germany — Unknown Device

Logs
→ 17 failed authentication attempts
→ Successful login at 02:43

Reports
→ Anna was not scheduled to work at that time
```

These clues together support Credential Abuse.

Create an evidence panel:

```text
┌─────────────────────────────────┐
│ INVESTIGATION EVIDENCE          │
│                                 │
│ ✓ Unusual login location        │
│ ✓ Unknown device                │
│ ✓ Repeated login attempts       │
│ ✓ Unusual login time            │
│                                 │
│ Possible Threats                │
│ ✓ Credential Abuse              │
│ ✕ Malware                       │
│ ✕ Ransomware                    │
│ ...                             │
│                                 │
│          [CONFIRM]              │
└─────────────────────────────────┘
```

The exact UI is flexible, but the player must be able to understand which clues have been collected.

---

## 5.4 Success Conditions

Investigation succeeds when:

```text
required_evidence_found >= scenario.required_evidence
AND
player_identified_threat == scenario.threat_name
```

The player should not be able to finish the phase with insufficient evidence.

Incorrect threat selection should not immediately end the scenario.

Instead:

- deny confirmation,
- indicate that the evidence is insufficient/inconsistent,
- allow the player to continue investigating.

---

## 5.5 Output

When completed, save:

```gdscript
GameState.investigation_evidence
GameState.identified_threat
```

Then transition to Monitoring.

---

# 7. Monitoring Phase

## Gameplay Type

**Observation / Anomaly Detection**

## Purpose

Monitoring changes from searching historical evidence to watching activity as it occurs.

The player observes several system perspectives and reports suspicious behavior.

---

## 6.1 Monitoring Interface

Use a dedicated monitoring screen.

```text
┌─────────────────────────────────────────────┐
│               SECURITY MONITOR              │
│                                             │
│              CURRENT VIEW                   │
│                                             │
│          [selected perspective]             │
│                                             │
│ [Computer] [Login] [Network] [Server]      │
│                                             │
│             Time Remaining                  │
│             02:41                           │
└─────────────────────────────────────────────┘
```

Perspectives:

- Computer View
- Login View
- Network View
- Server View

The player can switch between views.

---

## 6.2 Event System

Events appear over time.

Events may be:

- Normal
- Suspicious
- Clearly malicious

Events should be randomized within scenario-defined parameters.

Example:

```text
02:43
Anna
Germany
Unknown Device
```

Clicking the event opens:

```text
┌────────────────────────────────────┐
│ SUSPICIOUS LOGIN DETECTED          │
│                                    │
│ Account:  Anna                     │
│ Location: Germany                  │
│ Device:   Unknown Device           │
│ Time:     02:43                    │
│                                    │
│       [REPORT ANOMALY]             │
└────────────────────────────────────┘
```

---

## 6.3 Player Actions

The player can:

1. Switch monitoring perspectives.
2. Observe events.
3. Select suspicious events.
4. Inspect event details.
5. Report anomalies.
6. Continue watching for additional events.

---

## 6.4 False Positives

Not every unusual event should be an actual threat.

Example:

```text
02:50 — Mark — Philippines — Company Laptop
```

This could be legitimate activity.

Reporting it as suspicious should result in a resource penalty or reduced score.

This is important because the game should teach that **anomaly does not automatically mean attack**.

---

## 6.5 Resource System

Correct anomaly reports give the player resources.

Recommended name:

**Security Points**

Example:

```text
Correct anomaly: +20
Correct important anomaly: +30
False report: -10
Missed anomaly: 0
```

Do not make the resource system overly complex initially.

---

## 6.6 Monitoring Duration

The scenario can represent a long fictional monitoring period, such as 20 minutes, without requiring 20 real minutes of gameplay.

For example:

```text
Fictional monitoring period: 20 minutes
Actual gameplay time: approximately 2–5 minutes
```

The timer should be configurable per scenario.

---

## 6.7 Success Conditions

Monitoring succeeds when:

```text
monitoring_timer <= 0
```

The player can receive a performance grade based on:

```text
correct_reports
false_reports
important_anomalies_missed
```

The player should generally be allowed to proceed even with imperfect performance.

Poor performance mainly results in **fewer Security Points**, which affects Hardening.

---

## 6.8 Output

Save:

```gdscript
GameState.security_points
GameState.monitoring_score
GameState.reported_anomalies
```

Transition to Hardening.

---

# 8. Hardening Phase

## Gameplay Type

**Strategic Resource Management / Defense Preparation**

## Purpose

Hardening is the preparation stage before Response.

The player spends Security Points earned during Monitoring on cybersecurity defenses.

The presentation should resemble a game shop/loadout screen.

The shop is the **interface**. The gameplay is the player's strategic decision about how to spend limited resources.

---

## 7.1 Hardening Interface

Example:

```text
┌─────────────────────────────────────────────┐
│              SECURITY SHOP                  │
│                                             │
│ Security Points: 100                        │
│                                             │
│ DEFENSES                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ MFA                    30 Points        │ │
│ │ Network Segmentation   50 Points        │ │
│ │ Endpoint Protection    40 Points        │ │
│ │ Backup System          35 Points        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ SUPPORT                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Improved Logging       20 Points        │ │
│ │ Account Protection     25 Points        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│              [READY]                        │
└─────────────────────────────────────────────┘
```

---

## 7.2 Defense Categories

Items can be categorized as:

### Defense Cards

Examples:

- Block Connection
- Isolate System
- Quarantine Malware
- Restore Files

### Attack/Action Cards

Examples:

- Disable Account
- Force Re-authentication
- Block Malicious Request

### Support Cards

Examples:

- Trace Activity
- Scan System
- Analyze Logs

### Passive Upgrades

Examples:

- Increased System Integrity
- Reduced Damage
- Improved Detection
- Additional Card Draw

---

## 7.3 Player Actions

The player can:

1. View their available Security Points.
2. Browse available defenses.
3. Inspect cost and effects.
4. Purchase items.
5. Equip/select cards.
6. Select passive upgrades.
7. Review their final Response loadout.
8. Confirm preparation.

The player should have limited resources and/or loadout slots to force meaningful decisions.

---

## 7.4 Hardening-to-Response Connection

Purchases must directly modify Response.

Examples:

```text
MFA
→ Force Re-authentication card

Network Segmentation
→ Isolate Network card

Endpoint Protection
→ Quarantine Malware card

Backup System
→ Restore Clean Files card

Improved Logging
→ Trace Activity card
```

The Response deck should therefore be generated from:

```text
Base Deck
+
Hardening Purchases
+
Passive Upgrades
=
Final Response Deck
```

---

## 7.5 Success Conditions

Hardening succeeds when:

```text
player has a valid Response loadout
AND
player confirms preparation
```

There should not be a single correct loadout.

Different combinations should be viable, but some will naturally perform better against certain threats.

---

## 7.6 Output

Save:

```gdscript
GameState.purchased_defenses
GameState.response_deck
GameState.passive_upgrades
```

Transition to Response.

---

# 9. Response Phase

## Gameplay Type

**Deckbuilding / Card Combat**

## Purpose

Response is the primary gameplay section.

The threat identified during Investigation becomes a boss enemy.

The player uses the deck created through Hardening to contain and eliminate the threat.

The gameplay is inspired by **Slay the Spire-style card combat**, but the cards represent cybersecurity actions rather than physical attacks.

---

## 8.1 Response Setup

At the beginning of Response:

```text
Threat:
Credential Abuse

System Integrity:
100 / 100

Deck:
Base Cards
+
Purchased Cards
+
Passive Effects
```

The threat should have threat-specific behavior.

---

## 8.2 Player Actions

The player can:

1. Draw cards.
2. Review available actions.
3. Spend the appropriate card/action resource.
4. Play cybersecurity cards.
5. Counter boss actions.
6. Protect system components.
7. Reduce threat HP.
8. End the turn.
9. React to changing threat behavior.

---

## 8.3 Example Cards

Base cards:

- Investigate
- Scan
- Block
- Isolate

Credential Abuse-specific cards:

- Disable Account
- Force Re-authentication
- Trace Account
- Block Login

Ransomware-specific cards:

- Quarantine Malware
- Isolate Endpoint
- Restore Files
- Endpoint Scan

---

## 8.4 System Integrity

System Integrity functions as the player's HP.

Recommended structure:

```gdscript
var system_integrity: int
var max_system_integrity: int
```

Damage received during Response represents actual system damage.

The damage should be associated with network components.

Possible components:

- Server
- Router
- Switch
- Computer
- Database
- Other critical infrastructure

---

## 8.5 Visual System Damage

Use a visual network representation.

Example:

```text
              [SERVER]
                 │
             [ROUTER]
              /     \
        [SWITCH]   [SWITCH]
                      │
                  [DATABASE]
```

As the player takes damage, individual components can receive damage states.

The "network body" concept can be used as a **visual metaphor**, not as a literal technical network diagram.

---

## 8.6 Success Conditions

Response succeeds when:

```text
threat_hp <= 0
AND
required_containment_condition == true
```

Response fails when:

```text
system_integrity <= 0
```

Optional additional victory conditions may be defined per boss.

---

## 8.7 Output

At the end of Response:

```gdscript
GameState.system_integrity
GameState.damaged_components
GameState.threat_defeated
```

The amount and location of damage determine Recovery.

Transition to Recovery.

---

# 10. Recovery Phase

## Gameplay Type

**Repair / Restoration Minigames**

## Purpose

Recovery represents restoring the organization after the threat has been contained.

The damage accumulated during Response determines what the player must repair.

---

## 9.1 Recovery Interface

Display the network visually.

Example:

```text
              [SERVER] ⚠
                   │
              [ROUTER] ⚠
              /         \
        [SWITCH]       [SWITCH]
                         │
                    [DATABASE] ⚠
```

Damaged components should be visually distinct.

---

## 9.2 Player Actions

The player can:

1. Inspect the damaged network.
2. Select a damaged component.
3. Open its repair minigame.
4. Complete the minigame.
5. Restore the component.
6. Select the next damaged component.

---

## 9.3 Repair Minigames

Keep minigames short.

Possible types:

- Pattern matching
- Rhythm/timing
- Sequence puzzles
- Connection/path puzzles
- Memory puzzles

The specific minigame can be associated with a component.

Example:

```text
Server
→ Pattern repair

Router
→ Connection/path puzzle

Database
→ Sequence recovery

Computer
→ Timing/rhythm repair
```

The exact minigames can be replaced later without changing the Recovery system.

---

## 9.4 Success Conditions

Recovery succeeds when:

```text
all_required_damaged_components_repaired == true
```

A failed minigame should normally allow a retry rather than ending the scenario.

Optional penalties:

- Longer recovery time
- Lower scenario score

---

## 9.5 Dynamic Consequences

Recovery depends on Response.

Good Response:

```text
Less system damage
→ Fewer components to repair
→ Shorter Recovery
```

Poor Response:

```text
More system damage
→ More components to repair
→ Longer Recovery
```

This creates a direct consequence chain across the entire scenario.

---

# 11. Scenario Example — Credential Abuse

## Scenario Start

```text
DAY 1 — ???
```

After the player selects Day 1 from the Scenario Book, the Day's Visual Novel introduction begins. The threat name remains hidden from the Day Book until the scenario is completed, but the story can naturally establish the incident without directly naming the final threat.

Example opening story:

An employee account has shown unusual activity. The security analyst is assigned to determine whether the activity is legitimate or evidence of a compromise.

Day 1 then integrates the first-time tutorials into the scenario as the player reaches each objective.

---

## Investigation

If this is the player's first time using Investigation, the Investigation tutorial is integrated into the Day's opening investigation rather than being a separate tutorial level.

Player opens:

- Login Activity
- Logs
- Reports

Discovers:

```text
02:43 — Anna — Germany — Unknown Device

17 failed authentication attempts

Successful login immediately afterward

Anna is not scheduled to work at this time
```

Player records the evidence.

Threat options:

```text
Malware
Ransomware
Credential Abuse
Insider Threat
Data Exfiltration
DDoS
Phishing
Web Application Attack
```

Evidence progressively rules out unrelated options.

Player confirms:

**Credential Abuse**

---

## Story: Investigation → Monitoring

The Visual Novel story explains that the investigation has identified the likely incident and that the analyst now needs to watch for the suspicious behavior as it occurs.

If this is the player's first time using Monitoring, the Monitoring tutorial is integrated here before or at the start of the Monitoring gameplay.

## Monitoring

Player switches between:

- Computer View
- Login View
- Network View
- Server View

An event appears:

```text
02:43 — Anna — Germany — Unknown Device
```

Player clicks it:

```text
SUSPICIOUS LOGIN DETECTED

Account: Anna
Location: Germany
Device: Unknown Device

[REPORT ANOMALY]
```

Player reports it.

```text
+20 Security Points
```

Additional events appear.

Some are legitimate and some are suspicious.

Monitoring ends when the timer reaches zero.

Example result:

```text
Correct Reports: 5
False Reports: 1
Security Points Earned: 90
```

---

## Story: Monitoring → Hardening

The story explains what the monitoring results mean and why the organization now needs to strengthen its defenses before confronting the threat.

If this is the player's first time using Hardening, the Hardening tutorial is integrated here.

## Hardening

Player has:

```text
90 Security Points
```

Available:

```text
MFA                    30
Account Protection     25
Improved Logging       20
Network Segmentation   50
Endpoint Protection    40
```

Player purchases:

```text
MFA
Account Protection
Improved Logging
```

These modify the Response deck:

```text
Force Re-authentication
Protect Account
Trace Activity
```

---

## Story: Hardening → Response

The story establishes that the threat has now become an active incident and that the prepared defenses will be used to contain it.

If this is the player's first time using Response, the Response tutorial is integrated here before or at the start of card combat.

## Response

Boss:

```text
CREDENTIAL ABUSE
```

Player uses cybersecurity cards against the boss.

The boss attempts to:

- Create unauthorized logins
- Spread account access
- Bypass authentication
- Access protected systems

The player responds with:

- Force Re-authentication
- Disable Account
- Trace Activity
- Block Login
- Isolate affected system

Eventually:

```text
CREDENTIAL ABUSE
HP = 0
```

Threat is contained.

The player lost some System Integrity during the fight.

---

## Story: Response → Recovery

The story explains that the threat has been contained but the incident caused damage that must now be repaired.

If this is the player's first time using Recovery, the Recovery tutorial is integrated here.

## Recovery

Response resulted in:

```text
Server: Damaged
Database: Damaged
Computer 02: Damaged
```

The player enters Recovery.

They repair each component using short minigames.

After all required repairs:

```text
SYSTEM RESTORED

DAY 1 — CREDENTIAL ABUSE
COMPLETE
```

Then proceed to the next scenario/day.

---

# 12. Threat-Specific Content

The core systems should remain the same between scenarios.

What changes per threat:

```text
Story
Investigation Evidence
Monitoring Events
Relevant Views
Hardening Shop Options
Response Cards
Boss Behavior
System Damage
Recovery Components
```

Example:

| Threat | Primary Evidence | Monitoring Focus | Useful Hardening |
| --- | --- | --- | --- |
| Credential Abuse | Login records, authentication logs | Login/Computer | MFA, account protection |
| Malware | Email, program activity, logs | Computer/Network | Endpoint protection |
| Ransomware | File changes, suspicious programs | Computer/Network | Backups, endpoint protection |
| Insider Threat | User activity, files, access records | Computer/Login | Access controls, monitoring |
| Data Exfiltration | File access, network transfers | Network/Computer | Data controls, network monitoring |
| DDoS | Server load, traffic volume | Server/Network | Traffic filtering, availability protection |
| Phishing | Email, links, attachments | Login/Computer | Email protection, MFA |
| Web Application Attack | Web activity, server logs | Server/Network | Web protection, monitoring |

The table is a starting content design and can be expanded during implementation.

---

# 13. Required Cross-Phase Data Flow

The implementation must preserve the relationship between objectives.

```text
Investigation
    │
    └── identified_threat
          evidence
          ↓
Monitoring
    │
    └── security_points
          reported_anomalies
          monitoring_score
          ↓
Hardening
    │
    └── purchased_defenses
          response_deck
          passive_upgrades
          ↓
Response
    │
    └── system_integrity
          damaged_components
          threat_result
          ↓
Recovery
    │
    └── repaired_components
          scenario_result
```

Do not make every phase independent.

The player's decisions should have observable consequences.

---

# 14. Recommended Godot Implementation Principles

## Scene Separation

Each major objective should be its own scene so that development remains modular.

```text
investigation_scene.tscn
monitoring_scene.tscn
hardening_scene.tscn
response_scene.tscn
recovery_scene.tscn
```

---

## Reusable Components

Create reusable scenes/scripts for:

```text
EvidenceEntry
ApplicationWindow
MonitoringEvent
ShopItem
Card
Boss
NetworkComponent
RepairMinigame
```

This avoids hard-coding individual threats.

---

## Data-Driven Content

Do not create separate gameplay code for every threat.

Use scenario data to configure existing systems.

Example:

```text
Credential Abuse
→ scenario data

Ransomware
→ scenario data

DDoS
→ scenario data
```

The same Investigation, Monitoring, Hardening, Response, and Recovery systems should load different content depending on the current scenario.

---

# 15. Development Priority

Implement in this order:

### Prototype 1

Global and Day flow:

```text
Game Start
→ Title Menu
→ Scenario Book
→ Day Selection
→ Day Story
→ Investigation
→ Story
→ Monitoring
→ Story
→ Hardening
→ Story
→ Response
→ Story
→ Recovery
→ Day Conclusion
```

Use placeholder art and simple UI. Verify that story segments can occur between every objective.

### Prototype 2

Implement Investigation:

- Desktop
- 8 applications
- Evidence selection
- Threat identification

### Prototype 3

Implement Monitoring:

- Four views
- Random events
- Report button
- Security Points

### Prototype 4

Implement Hardening:

- Shop
- Resource spending
- Card purchasing
- Loadout construction

### Prototype 5

Implement Response:

- Deck
- Cards
- Turns
- Boss
- System Integrity
- Damage tracking

### Prototype 6

Implement Recovery:

- Network visualization
- Damaged components
- Repair minigames

### Prototype 7

Connect scenario data and create the eight threat scenarios.

---

# 16. Core Design Requirement

The game should maintain the following relationship:

> **The player investigates the incident, watches it develop, prepares defenses, responds to the attack, and restores the system afterward.**

Each phase should feel different mechanically:

```text
Investigation
= Find and connect clues

Monitoring
= Observe and classify anomalies

Hardening
= Make strategic preparation decisions

Response
= Play cards and counter the threat

Recovery
= Repair the consequences
```

The five phases should not feel like five unrelated minigames.

They should function as **one continuous cybersecurity incident**, with the player's decisions carrying forward from one objective to the next.

The game should remain fully 2D and should prioritize simple, readable interfaces and mechanics suitable for players with little or no prior cybersecurity knowledge.

---

# 17. Reference Project & Reuse Strategy

A full audit of this project and of the previous prototype at `D:\GitHub\the-spire` was performed on 2026-09-13. The detailed findings, file-by-file breakdown, and reuse recommendations live in [`PROJECT_REFERENCE.md`](PROJECT_REFERENCE.md) — read it before starting Response-phase work, and before assuming any system needs to be built from scratch.

Summary of the decision:

- This project currently has **no code** — everything below Prototype 1 in §14 starts from zero.
- `the-spire` has a working, already cybersecurity-themed card-combat prototype (Investigation/Monitoring/Hardening/Response/Recovery card types, Integrity/Containment/Breach meters). Its `DeckManager.gd`, `CardNode.gd`, `Tutorial.gd`, and CSV card/threat content are directly reusable. Its combat scene (`PlayUI.gd`) and card-effect system need to be adapted, not copied verbatim — see `PROJECT_REFERENCE.md` §2.2–§4 for specifics and why.
- `the-spire` has no active boss/intent system and no status-effect system; both must be newly designed for this project's Response phase.
- `the-spire` is a reference only. Never edit files under `D:\GitHub\the-spire` as part of this project's work.
