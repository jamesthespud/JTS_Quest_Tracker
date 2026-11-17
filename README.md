<div align="center">

# 📜 JTS Quest Tracker

**A clean, modern quest tracker for WoW Forever.**<br>
Replaces Blizzard's tracker with a tidy list you control: what it shows, how it's sorted, how it looks and where it sits.

[![Latest release](https://img.shields.io/github/v/release/jamesthespud/JTS_Quest_Tracker?label=release&color=33cc88)](https://github.com/jamesthespud/JTS_Quest_Tracker/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/jamesthespud/JTS_Quest_Tracker/total?color=4a90d9)](https://github.com/jamesthespud/JTS_Quest_Tracker/releases)
![WoW Forever](https://img.shields.io/badge/WoW-Forever-f8b700)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

**[⬇️ Download](https://github.com/jamesthespud/JTS_Quest_Tracker/releases/latest)** &nbsp;·&nbsp; **[🐞 Report a bug](https://github.com/jamesthespud/JTS_Quest_Tracker/issues)** &nbsp;·&nbsp; **[📋 What's changed](#-version-history)**

Part of the **JTS Suite**

</div>

> [!NOTE]
> JTS Quest Tracker is my own fork of [Butter Quest Tracker](https://github.com/butter-cookie-kitkat/ButterQuestTracker) by Butter Cookie Kitkat, used under its MIT license. It is **not** made, endorsed or supported by Butter Cookie Kitkat, so please report problems here, not to the original author.

## ✨ New in 2.2

> [!TIP]
> - 🔍 **Search the settings** by name, in a tidier layout
> - 🪶 **Minimal skin**: a faint panel and plain text
> - ✅ **Ready to turn in** quests in their own section, and an optional **Turned in today** list
> - 🧭 **Edit Mode** support: move and resize the tracker from WoW's own Edit Mode
> - 📍 **TomTom** uses Questie's location when WoW has none
>
> New in 2.1: Tracker Scale, Fade When Idle, rested XP on the XP bar, and session stats (XP per hour, time to level).

## 🎯 Features

<table>
<tr>
<td width="50%" valign="top">

### 🎨 Three looks
- **Modern**: dark rounded panel, level badges, quest type labels, rounded progress bars
- **Minimal**: a faint panel and plain text
- **Classic**: the original look
- Fonts, colours, sizes, outlines, spacing and **Tracker Scale**

</td>
<td width="50%" valign="top">

### 🗡️ Questing made easier
- **Quest item buttons** with charges, cooldown, range and a glow when usable
- **One hotkey** uses the focused or closest quest's item
- **XP bar** that turns gold when your turn-ins level you
- **Quest focus**, distances, rewards in the tooltip, quest notes

</td>
</tr>
<tr>
<td valign="top">

### 👥 Better in a group
- **Party progress** on shared quests
- **Announce to Party** in chat
- **Share all quests**, or one zone's
- **Dungeon / Raid Quests Only** inside instances

</td>
<td valign="top">

### ⚙️ Your tracker, your way
- Sort by level, progress, distance, or **drag into your own order**
- Foldable zones, pinned quests, ready-to-turn-in section
- Fade in combat or **when idle**, hide in instances
- **Profiles** with import / export, **searchable settings**

</td>
</tr>
<tr>
<td valign="top">

### 🌍 Help in the world
- **Highlight Quest Objects** marks what you can use
- A gold **!** on enemies you still need
- **New in Forever** quests marked with ∞

</td>
<td valign="top">

### ♿ Easy to read
- **Color Blind Mode** for all nine types
- Difficulty markers (`!!` `!` `-` `--`) so colour is never the only signal
- A **welcome screen** that shows what's new after each update

</td>
</tr>
</table>

<details>
<summary><b>📖 The full feature list</b></summary>

- **Quest item buttons** beside quests that give you an item: click to use, Shift-click to link. Charges, cooldown, a range dot and a glow when your target is in range. Masque skins supported.
- **Quest item hotkey.** One key uses the item of your focused quest, or the closest quest that has one.
- **Quest focus.** Middle-click a quest to point WoW's quest arrow and map waypoint at it; optional Auto-focus follows the quest you just progressed.
- **XP bar** under the header, with the XP from finished quests drawn on top and rested XP as a faint band. It turns **gold** and the header says **Level up!** when turning them in would level you. Hover it for this session's quests, XP per hour and time to level.
- **Distance and proximity sorting** from WoW Forever's own quest helper, no Questie needed.
- **Rewards in the tooltip** (XP, money, items, choices) and **turn-in XP** in the header, like `3 ready · 4,250 XP`.
- **Quest notes.** Leave yourself a reminder on any quest; it shows in the tooltip.
- **Highlight Quest Objects** and **nameplate quest icons**.
- **Optional auto-accept and auto-turn-in** (off by default). Stops when there's a reward to choose; hold Shift to do it yourself.
- **Clean Up Quest Log** abandons your grey and failed quests in one go (it lists them and asks first).
- **TomTom waypoints** from WoW's location, or Questie's when WoW has none.
- **Party progress**, **Announce to Party**, **Share All Quests** and Share all buttons on dungeon headers.
- **Sort** by level, completion, recently updated, distance, or by hand. Ready-to-turn-in quests first, last or in their own section.
- **Zone headers** you can fold (your zone first), **pinned quests**, Expand Current Zone Only, **Turned in today**.
- **Move it** by dragging, from **Edit Mode**, or with exact sliders. **Grow upwards** for trackers near the bottom of the screen, with the header kept in view while you scroll.
- **Visibility:** fade or hide in combat, hide in dungeons, raids or PvP, collapse in instances, or fade when idle.
- **Color Blind Mode**, difficulty markers, **profiles** with import / export, a **minimap button**, a key binding and `/jtsqt` commands.
- **Safe startup:** if the tracker ever fails to start, you get Blizzard's tracker back instead of none.

</details>

## ⬇️ Installing

1. Download the latest zip from **[Releases](https://github.com/jamesthespud/JTS_Quest_Tracker/releases/latest)** (or CurseForge or Wago).
2. Unzip it into your `Interface/AddOns` folder. The folder must be named exactly `JTS_QuestTracker`.
3. Start the game and type `/jtsqt` for the settings.

> [!IMPORTANT]
> **WoW Forever only** for now. Run one quest tracker at a time: if Butter Quest Tracker is also installed, disable it.

<details>
<summary><b>⌨️ Commands and clicks</b></summary>

| Action | What it does |
| --- | --- |
| `/jtsqt` | Open the settings (also Esc > Options > AddOns, or the minimap button) |
| `/jtsqt welcome` | Open the welcome screen |
| `/jtsqt toggle` | Show or hide the tracker (also `show`, `hide`, or the key binding) |
| `/jtsqt collapse` / `/jtsqt expand` | Fold or open every zone |
| `/jtsqt share` | Share all your quests with your group |
| `/jtsqt cleanup` | Abandon your grey and failed quests (lists them and asks first) |
| `/jtsqt minimap` | Show or hide the minimap button |
| `/jtsqt status` | Print which game APIs were found (include this in bug reports) |
| `/jtsqt reset` | Clear your manual track and untrack choices |
| Click the header | Fold or open the tracker |
| Right-click the header | Collapse All, Expand All, Share All Quests, Clean Up Quest Log, Hide, Settings |
| Click a zone header | Fold or open that zone (right-click: share its quests, collapse or expand all) |
| Click a quest | Open it in the quest log |
| Middle-click a quest | Focus it: WoW's quest arrow and map waypoint point to it |
| Shift / Alt / Ctrl-click a quest | Untrack / Wowhead link / link in chat |
| Right-click a quest | Focus, pin, add a note, view, share, TomTom waypoint, abandon |

</details>

<details>
<summary><b>🗂️ Where the settings are</b></summary>

| Page | What's there |
| --- | --- |
| **Search** | Type part of a setting's name and press Enter |
| **General** | Skin and its options, preview, minimap button, welcome screen |
| **Tracking** | Sorting, zone order, ready-to-turn-in placement, filters, dungeon and raid quests only |
| **Questing** | Quest focus, quest item buttons and hotkey, auto quest, quest objects and nameplate icons, the world map, TomTom and Masque |
| **Appearance** | Text, Color Blind Mode, tracker header, XP bar, zone headers, quest names, objectives |
| **Alerts & Group** | Objective complete flash, chat and sounds, Announce to Party, party progress |
| **Window** | Position, size, scale, Edit Mode, visibility and fading, background, scrolling |
| **Profiles** | Switch, copy and reset profiles; import and export |
| **Advanced** | Language, developer tools, reset everything |

</details>

## 💡 Good to know

- For now the world map opens **without its quest log panel**: with the tracker running, the zones in the map's quest log won't fold. The arrow at the bottom of the map still opens it, or turn this off in **Questing > World Map**.
- The game doesn't let addons move secure buttons in combat, so quest item button changes made in a fight show up when it ends.

## 🐞 Found a bug?

Open an **[issue](https://github.com/jamesthespud/JTS_Quest_Tracker/issues)** (or post on CurseForge) with:
- the output of `/jtsqt status`
- the full text of any Lua error (BugSack / BugGrabber capture these)
- what you were doing when it happened

<details>
<summary><b>🛠️ For developers</b></summary>

- A new patch marks the addon out of date: add the interface number to the `## Interface` line of `JTS_QuestTracker.toc` (`/dump (select(4, GetBuildInfo()))` in game).
- A quest, map or UI function is renamed or removed: fix it in `Compat/Compat.lua`. Every Blizzard quest, map and UI call goes through that file, wrapped so one missing function can't break the rest.
- Features live in their own files (`Skin.lua`, `XPBar.lua`, `QuestItems.lua`, `Visibility.lua`, `EditMode.lua`, `TurnedInToday.lua`, and so on) and hook into the core, so `JTS_QuestTracker.lua` stays close to the original design. Settings are built in `Options.lua`; each feature file provides its own options for it to place.
- Pooled rows are reused: anything a feature adds to a row is reset in that row's `OnAcquire`.
- All internal libraries are registered under `JTSQT*` names and all globals start with `JTS_QuestTracker`, so this addon can be installed next to Butter Quest Tracker without the two overwriting each other.

</details>

## 📋 Version history

<details>
<summary><b>Show all versions</b></summary>

- **2.2.1** Welcome screen: the line under the title and the credit line fit inside the window again, and the
  "Also new" notes on the New page wrap under the checkboxes instead of running over them.
- **2.2.0** Settings search: a Search page at the top finds any setting by name. The settings are regrouped into
  General, Tracking, Questing, Appearance, Alerts & Group, Window, Profiles and Advanced. New, from ideas in
  Waltrapalo's fork: the Minimal skin, Ready to Turn In > Own Section (finished quests in a foldable section above the
  zones), Turned In Today (off by default), moving and resizing the tracker from WoW's Edit Mode, and TomTom waypoints
  that use Questie's location when WoW has none.
- **2.1.0** Tracker Scale slider (Window > Position & Size). Fade When Idle: the tracker fades while your
  mouse isn't over it (Window > Visibility, off by default). Rested XP shows as a faint band on the XP bar, and
  hovering the header shows this session's quests turned in, XP gained, XP per hour and time to level.
- **2.0.6** Modern skin: quest names and objectives follow your colour settings (colour by difficulty, your own
  quest name and objective colours, colour by progress), like Classic. Long quest names that wrap onto a second line no longer
  run into the objective below, a header that wraps no longer runs into the XP bar, and the pinned header is solid
  so rows don't show through it.
- **2.0.5** The world map opens without its quest log panel (Hide the Map's Quest Log, Frame Settings > Visibility;
  on by default), since its zones won't fold while the tracker runs. The arrow at the bottom of the map still opens it.
- **2.0.4** Fixed: zones in the world map's quest log can be folded again (the tracker no longer reads the quest
  log while the map is open; it catches up when the map closes). More room above and below quest names so they
  aren't cut off (Appearance > Quest Names > Space Around Quest Names).
- **2.0.3** Nine more fonts come with the tracker (Barlow Semi Condensed, Fira Sans Condensed, PT Sans Narrow,
  Ubuntu Condensed, Oswald, Titillium Web, Rajdhani, Alegreya Sans SC, Cinzel), also shared with other addons
  through SharedMedia. Modern skin: easier-to-read numbers. Level badges are bigger and no longer outlined (the outline smudged
  dark numbers on light badges), and the distance after quest names is a lighter grey.
- **2.0.2** Welcome screen: the page names are now tabs across the top (they were squeezed between the buttons);
  click one to jump to that page.
- **2.0.1** Fixed: the XP bar now stays pinned with the header when you scroll down (Keep Header in View). The quest
  item hotkey can be set right in the settings (Buttons > Quest Item Key > Key).
- **2.0.0** Modern skin (Appearance > Skin; the default for new installs): dark rounded panel, level badges,
  quest type labels, counts on the right, rounded progress bars, check marks and a "Ready to turn in" pill.
  XP bar under the header, with the XP from quests ready to turn in drawn on top (gold, and "Level up!", when they
  would level you). Quest item hotkey: one key uses the focused or closest quest's item.
  Highlight Quest Objects (Alerts > Quest Objects): turns on WoW's Interact Key icons and outlines to mark nearby
  quest objects, and puts your own settings back when turned off. Quest item buttons glow and sparkle when your
  target is in range. Quest icons on the nameplates of enemies you still need. (The 2.0 test builds were called
  3.0.0-alpha1 to alpha14.)

**1.x**

- **1.5.0** Quest notes: right-click a quest > Add Note; shown in the tooltip with a note icon on the quest, cleared on
  turn-in. Clean Up Quest Log: abandon grey and failed quests in one go from the tracker header menu or
  `/jtsqt cleanup` (asks first, keeps pinned quests and grey quests that are ready to turn in).
- **1.4.0** Party progress shows as a small group icon and a count by default (rows per member are still an
  option). Auto-accept and auto-turn-in (off by default; Shift skips, stops for reward choices). Drag to reorder
  quests by hand (Sorting > Manual). Collapse in Instances (off by default). TomTom waypoints from the quest menu
  and optionally on focus. Masque skins for the quest item buttons. Returning players get a "New in 1.4.0" page
  on the welcome screen instead of the whole tour.
- **1.3.1** Fixed: you couldn't track more than 25 quests from the quest log. WoW's own tracking list stops at 25;
  JTS Quest Tracker now tracks the quest anyway (WoW still flashes its error once), so you can track all 40.
- **1.3.0** Party progress: group members who also use JTS Quest Tracker see each other's progress on shared
  quests (hidden addon messages, nothing in chat). Rewards (XP, money, items, choices) in the quest tooltip. Turn-in
  XP in the header (`3 ready · 4,250 XP`). Welcome screen on first login, with checkboxes for the features people
  might miss (`/jtsqt welcome`). Grow Upwards: the bottom edge stays put and the tracker grows up, with
  Header Position Top / Bottom (Bottom by default with Grow Upwards). Keep Header in View: the header
  stays pinned to the top while you scroll. Always Show Scroll Bar. Blue infinity
  symbol on quests that are new in WoW Forever. Share all button on dungeon and raid headers in a group. The
  welcome screen walks through Questing, Group and Tracker one page at a time (Next / Back / Finish). Announce to Party is now on by default, in the new Alerts > Your Group section.
- **1.2.5b** Dungeon Quests Only and Raid Quests Only (on by default): inside a dungeon or raid, only its kind of
  quests are listed. Fixed "ADDON_ACTION_BLOCKED ... Button:SetPassThroughButtons()" in combat with the world map
  open (focus and tracking changes now wait until combat ends and the map is closed).
- **1.2.5** Hide in combat
  (fade or hide) and in dungeons, raids, or battlegrounds and arenas. Collapse All /
  Expand All and Expand Current Zone Only. Quest log full warning in the header. Ready to Turn In quests first or
  last. Countdown for timed quests. Quest distances from WoW's own quest helper, so Sort by Quest Proximity works
  without Questie, plus optional distance after quest names. Share all quests, or one zone's, with your group.
  Right-click menus on the tracker and zone headers.
- **1.2.0** Announce to Party (off by default; Alerts > Objective Complete Alert): when you finish an objective
  or a whole quest, your group sees it in party chat, like Questie's announce, e.g.
  `{rt1} JTS QT: Diseased Timber Wolf slain: 8/8 (Wolves Across the Border)`. Uses instance chat in dungeon
  finder groups and sends nothing when you're solo.
- **1.1.0** Quest focus: middle-click a quest, or choose Focus in its right-click menu, to point WoW Forever's
  built-in quest helper at it (on-screen arrow with distance, map waypoint, highlighted objective area). The
  focused quest is marked in the tracker, and it stays in sync when you focus a quest from the quest map. Optional
  Auto-focus (off by default) focuses the quest you just accepted or made progress on.
- **1.0.2** Progress bar thickness setting (2 to 6 pixels). Lock in Combat, on by default: the tracker can't be
  dragged during a fight, and is dropped in place if combat starts mid-drag. Richer quest tooltip: level, quest
  type, summary, each objective with its count, and click hints. Fixed: with Lock Frame on, a tiny mouse movement
  while clicking the header could stop it from collapsing the tracker. Faster: a burst of quest log updates (the game
  sends several per kill) is read once instead of once each, accepting or turning in a quest redraws the tracker once
  instead of twice, and sorting by proximity looks each distance up once per sort (about 10x fewer lookups).
- **1.0.1** Finished objectives fade back so the ones still to do stand out. Zone headers show a quest count, like
  `Elwynn Forest (3)`. Collapsed zones (and a collapsed tracker) stay collapsed after a reload or relog. The progress
  bar sits 3 pixels lower, clear of the objective text. Settings are now grouped into categories in a sidebar:
  Filters & Sorting, Appearance, Color Blind Mode, Alerts, Frame Settings, Buttons, Profiles and Advanced.
- **1.0.0** First release. Forked from the Butter Quest Tracker WoW Forever fan update (1.4.0) and extended with:
  adjustable scroll speed, bigger zone headers, WoW Forever's 40 quest limit in the header, Color Blind Mode for all
  nine types of color vision deficiency with Difficulty Markers, quest item buttons, quest tags, a font picker,
  separate objective and quest complete sounds, a minimap button, profiles and import / export, and new defaults
  (quest level before the name, color by difficulty, progress bars, outlined text). Support for other WoW clients was
  removed to keep the code small. Earlier version numbers were test builds.

</details>

## 📄 Credits and license

The bundled fonts in `Fonts/` are free fonts used under their own licences (SIL Open Font License, and the Ubuntu Font Licence for Ubuntu Condensed); each licence is in `Fonts/Licenses/`. Oswald and Cinzel are shipped as single-weight versions made from their variable fonts.


- Original addon: **Butter Quest Tracker** by Butter Cookie Kitkat, (c) 2019, MIT license.
- JTS Quest Tracker fork and changes: (c) 2026 James, released under the same MIT license. See [`LICENSE`](LICENSE),
  which keeps the original copyright notice as the MIT license requires.
- Ideas for the Minimal skin, the Ready to Turn In section, Turned In Today, Edit Mode support and the Questie
  location for TomTom came from **Waltrapalo**'s fork of JTS Quest Tracker (with testing by Torut). They were
  written again for this version.
- Bundled libraries keep their own licenses: Ace3 including AceDBOptions and AceSerializer (see [`Libs/Ace3-LICENSE.txt`](Libs/Ace3-LICENSE.txt)), LibStub and CallbackHandler.
- "Butter Quest Tracker" is the original author's name for their addon; it is used here only to credit the source of this fork.
