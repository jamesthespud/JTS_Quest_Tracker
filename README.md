# JTS Quest Tracker

A clean, customizable quest tracker for World of Warcraft, built for **WoW Forever**. Part of the JTS Suite.

> **A fork of Butter Quest Tracker.** JTS Quest Tracker is my own fork of
> [Butter Quest Tracker](https://github.com/butter-cookie-kitkat/ButterQuestTracker) by Butter Cookie Kitkat,
> used under its MIT license. It started as a fixed and updated version of Butter Quest Tracker for WoW Forever
> and now continues as a separate addon with its own features.
>
> It is **not** made, endorsed or supported by Butter Cookie Kitkat. Please report problems with JTS Quest Tracker
> to me, not to the original author.

JTS Quest Tracker replaces Blizzard's quest tracker with a tidy list that you control: what it shows, how it is
grouped, how it looks and where it sits on screen.

## What it adds over the original

- **Made for WoW Forever.** Built for Forever's modern quest API (it does not support other WoW clients).
- **Pin quests.** Right-click a quest > Pin Quest. Pinned quests are always tracked, ignore the zone filter and sit first in their zone, marked with a small icon.
- **Objective complete alert.** When an objective (or a whole quest) is finished the quest flashes briefly. Optional chat message and sound.
- **Objective colors by progress.** Objectives shade from red to yellow to green as you get closer to done.
- **Thin progress bars.** Optional slim bar under counted objectives such as 3/10.
- **Text outline and shadow.** Choose no outline, outline or thick outline, and default, strong or no shadow.
- **Show/hide command and key binding.** `/jtsqt toggle`, `/jtsqt show`, `/jtsqt hide`, or bind a key under Esc > Options > Key Bindings > AddOns.
- **Draggable scroll bar**, optionally visible while the mouse is over the tracker, and an adjustable **Scroll Speed** for the mouse wheel.
- **Zone grouping.** Quests sit under collapsible zone headers. Your current zone comes first, the rest follow A to Z.
- **Show Quest Level.** Optionally show `[12] Quest Name` or `Quest Name (12)`.
- **Clearer difficulty colors** and **no tracking limit**.
- **Color Blind Mode.** Covers every type of color vision deficiency: protanopia, protanomaly, deuteranopia, deuteranomaly, tritanopia, tritanomaly, achromatopsia, blue cone monochromacy and achromatomaly. It swaps the difficulty, progress, progress bar, turn-in, failed and flash colors for palettes checked with a color vision simulation. Optional **Difficulty Markers** (`!!` `!` `-` `--`) show difficulty without relying on color, and switch on by themselves in the no-color modes. Settings: Color Blind Mode.
- **Quest item buttons.** Quests that give you an item to use get a button beside them: click to use, Shift-click to link it. Shows charges, cooldown and a range dot. Settings: Buttons.
- **Quest tags.** `[E]` Elite, `[G3]` Group of 3, `[D]` Dungeon, `[R]` Raid, `[PvP]`, `[H]` Heroic, `[L]` Legendary after the quest name, or the full words. Settings: Appearance > Quest Names.
- **Font picker.** Choose the game's fonts or any SharedMedia font. Settings: Appearance > Text.
- **Alert sounds.** Pick separate sounds for "objective complete" and "quest complete" (game sounds or SharedMedia sounds), with a Play button to preview.
- **Minimap button.** Left-click for settings, right-click to show/hide the tracker, drag to move. Works with minimap button bags and Titan Panel/ElvUI data bars when LibDBIcon is present. `/jtsqt minimap` shows or hides it.
- **Profiles.** Every setting lives in a profile. All characters share "Default" until you choose otherwise; on the Profiles page you can switch, copy, create, reset or delete profiles, so a layout made on one character loads on any other.
- **Import / export.** Turn your profile into one line of text to share or back up, and paste someone else's to load it (into your current profile or a new one).
- **Easy to scan.** Finished objectives fade back, zone headers show how many quests they hold (`Elwynn Forest (3)`), and collapsed zones stay collapsed after a reload.
- **Safer startup.** If the tracker ever fails to start, you get Blizzard's default tracker back instead of none.
- **Bug fixes** for quest names containing `%`, quests without objectives looking "updated", a broken locale fallback, moved popup fields and stale quest log indexes.

## Features

- Move and lock the tracker anywhere on screen
- Collapsible zone headers
- Filter quests to your current zone or subzone
- Manually track or untrack quests
- Sort by level, percent complete, recently updated, or quest proximity (needs Questie)
- Color quest names by difficulty and optionally show their level
- Adjust font size, colors, padding and the quest name format
- Alt-click a quest for its Wowhead link, ctrl-click to link it in chat, shift-click to untrack it
- Right-click a quest to pin, view, share or abandon it

## Installing

1. Copy the `JTS_QuestTracker` folder into `Interface/AddOns`. The folder name must be exactly `JTS_QuestTracker`.
2. Start the game. If the addon is marked "out of date" after a patch, tick **Load out of date AddOns**.

JTS Quest Tracker has its own settings and does not touch Butter Quest Tracker's. Run only one quest tracker at a
time: if Butter Quest Tracker is also installed, disable it in the AddOn list.

All libraries (Ace3) are bundled, nothing else needs installing.

## Using it

| Action | What it does |
| --- | --- |
| `/jtsqt` | Open the settings (also in Esc > Options > AddOns) |
| `/jtsqt toggle` | Show or hide the tracker (also `show`, `hide`, or the key binding) |
| `/jtsqt minimap` | Show or hide the minimap button |
| `/jtsqt status` | Print which game APIs were found (include this in bug reports) |
| `/jtsqt reset` | Clear your manual track and untrack choices |
| Left-click the header | Collapse or expand the tracker |
| Right-click the header | Open the settings |
| Click a quest | Open it in the quest log |
| Shift-click / Alt-click / Ctrl-click a quest | Untrack / Wowhead link / link in chat |
| Right-click a quest | Quest menu (pin, view, share, abandon) |

## Reporting bugs

Please report problems on the JTS Quest Tracker CurseForge page (not to Butter Quest Tracker's author) and include:

- the output of `/jtsqt status`
- the full text of any Lua error (BugSack / BugGrabber capture these)
- what you were doing when it happened

## For developers

- New patch marks the addon out of date: add the interface number to the first line of `JTS_QuestTracker.toc`
  (`/dump (select(4, GetBuildInfo()))` in game).
- A quest, map or UI function is renamed or removed: fix it in `Compat/Compat.lua`. Every Blizzard quest, map and
  UI call goes through that file, wrapped so one missing function can't break the rest.
- New features go in their own files (`Extras.lua`, `ColorBlind.lua`, `Tags.lua`, `Media.lua`, `Profiles.lua`, `QuestItems.lua`, `Minimap.lua`) so the core tracker stays as close to the original design as possible.
- All internal libraries are registered under `JTSQT*` names and all globals start with `JTS_QuestTracker`, so this
  addon can be installed next to Butter Quest Tracker without the two overwriting each other.

## Version history

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

## Credits and license

- Original addon: **Butter Quest Tracker** by Butter Cookie Kitkat, (c) 2019, MIT license.
- JTS Quest Tracker fork and changes: (c) 2026 James, released under the same MIT license. See [`LICENSE`](LICENSE),
  which keeps the original copyright notice as the MIT license requires.
- Bundled libraries keep their own licenses: Ace3 including AceDBOptions and AceSerializer (see [`Libs/Ace3-LICENSE.txt`](Libs/Ace3-LICENSE.txt)), LibStub and CallbackHandler.
- "Butter Quest Tracker" is the original author's name for their addon; it is used here only to credit the source of this fork.
