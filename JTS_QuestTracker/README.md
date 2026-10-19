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
- **Objective complete alert.** When an objective (or a whole quest) is finished the quest flashes briefly. Optional chat message and sound, and **Announce to Party** (on by default): your group sees `{star} JTS QT: Diseased Timber Wolf slain: 8/8 (Wolves Across the Border)` in party chat, like Questie's announce, even if they don't run Questie.
- **Objective colors by progress.** Objectives shade from red to yellow to green as you get closer to done.
- **Thin progress bars.** Optional slim bar under counted objectives such as 3/10, 2 to 6 pixels thick.
- **Text outline and shadow.** Choose no outline, outline or thick outline, and default, strong or no shadow.
- **Show/hide command and key binding.** `/jtsqt toggle`, `/jtsqt show`, `/jtsqt hide`, or bind a key under Esc > Options > Key Bindings > AddOns.
- **Draggable scroll bar**, optionally visible while the mouse is over the tracker or all the time (Always Show Scroll Bar), and an adjustable **Scroll Speed** for the mouse wheel.
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
- **Quest focus.** Point WoW's built-in quest helper (the on-screen arrow with distance, the map waypoint and the highlighted objective area) at any quest: middle-click it, or use Focus in its right-click menu. The focused quest is marked in the tracker, and optional Auto-focus follows the quest you just progressed or accepted. Settings: Filters & Sorting > Quest Focus.
- **Helpful tooltips.** Hover a quest to see its level (in its difficulty color), its type, its summary and every objective with its count, plus what each click does.
- **Grow Upwards.** Keep the tracker near the bottom of the screen: its bottom edge stays put and it grows up as you pick up quests, with the header below the list where it never moves (Header Position: Top / Bottom). Frame Settings > Position & Size.
- **Lock in Combat.** The tracker can't be dragged while you fight (on by default; Frame Settings > Position & Size).
- **Hide in combat or instances.** Fade the tracker or hide it while you fight, and hide it in dungeons, raids, or battlegrounds and arenas. Showing it by hand keeps it up until the fight ends or you leave. Settings: Frame Settings > Visibility.
- **Dungeon Quests Only / Raid Quests Only.** Inside a dungeon the tracker lists only dungeon quests (the Dungeon or Heroic tag, or quests filed under the dungeon in your quest log); inside a raid, only raid quests (the Raid tag, or filed under the raid). Pinned quests still show. Both on by default; Filters & Sorting > Filters.
- **Collapse All / Expand All.** Right-click the tracker header or a zone header, or use `/jtsqt collapse` and `/jtsqt expand`. Optional **Expand Current Zone Only** opens your zone and folds the others away as you travel.
- **Quest log full warning.** When your log is nearly full the header adds `Log 37/40`, and `Log full` at 40 (Appearance > Tracker Header, warns from 36 by default).
- **Ready to Turn In placement.** Put finished quests first or last instead of wherever your sorting puts them (Filters & Sorting > Sorting).
- **Quest timers.** Timed quests show `Time left: 4:32` under their name, counting down and turning red in the last minute.
- **Distance without Questie.** Sort by Quest Proximity now uses WoW Forever's own quest helper (the same distance its quest arrow shows), with Questie only filling in quests the game has no location for. Optional **Show Distance** puts `120 yd` after each quest name (Appearance > Quest Names).
- **Share quests with your group.** Right-click the tracker header for Share All Quests, or a zone header to share just that zone's quests (`/jtsqt share` too). They go out one every 3 seconds so your group can take each one. In a group, dungeon and raid headers (like Wailing Caverns) also get a **Share all** button.
- **Welcome screen.** On first login a short tour lists the features you might not know about, each with a checkbox to turn it on or off. After an update with new features you get a single **New in X.Y** page with just those. `/jtsqt welcome` (or Advanced > Welcome Screen) opens the full tour again.
- **New Forever quests marked.** Quests that are new in WoW Forever get a small blue infinity symbol in front of their name and a "New in WoW Forever" line in their tooltip (Appearance > Quest Names).
- **Party progress.** Group members who also use JTS Quest Tracker see each other's progress on shared quests: by default a small group icon and how many of them have it after the quest name, or a row per member under it (`Mike  5/8`), and always in the quest tooltip. Only quest IDs and counts are shared, through hidden addon messages. Settings: Alerts > Your Group (Show Party Progress As).
- **Auto-accept and auto-turn-in.** Optional (both off by default): accept the quests NPCs offer and hand in finished ones. It stops when there's a reward to choose, skips grey quests unless you include them, and holding Shift lets you do it yourself. Filters & Sorting > Auto Quest.
- **Drag to reorder.** Sorting > Manual (drag to reorder): drag a quest up or down to put it where you want it (a green line shows where it lands). The order is saved per character; new quests go to the end. Reset Manual Order starts over.
- **Collapse in Instances.** Optional: entering a dungeon, raid, battleground, arena or scenario folds the tracker up to its header, and leaving opens it again. Frame Settings > Visibility.
- **TomTom.** With TomTom installed, right-click a quest for **TomTom Waypoint** (it uses the same location as WoW's quest arrow), and optionally get a waypoint every time you focus a quest. Buttons > Other Addons.
- **Quest notes.** Right-click a quest > Add Note to leave yourself a reminder ("need a group", "drops from the ogres"). It shows in the quest's tooltip, a small note icon marks the quest (Show Note Icon, Appearance > Quest Names), and it's cleared when you turn the quest in. Saved per character.
- **Modern skin.** A dark rounded panel with level badges, quest type labels, counts on the right and rounded progress bars (Appearance > Skin). New installs start on Modern; Classic is the original look.
- **XP bar.** A thin bar under the header shows how far you are through your level, with the XP from quests that are ready to turn in drawn on top. It turns gold and the header says **Level up!** when handing them in would level you. Hover the header for the numbers and your rested XP.
- **Quest item hotkey.** Set a key in **Buttons > Quest Item Key** (or Key Bindings > AddOns > JTS Quest Tracker > Use Quest Item): it uses the item of your focused quest, or the closest quest that has one, and that item's button shows the key. Settings: Buttons > Quest Item Key.
- **Help out in the world.** Highlight Quest Objects marks and outlines the nearest thing you can use (WoW's own Interact Key icons), quest item buttons glow when your target is in range, and enemies you still need for a quest get a gold **!** by their nameplate.
- **Clean Up Quest Log.** Right-click the tracker header (or `/jtsqt cleanup`) to abandon all your grey and failed quests in one go. It lists them and asks first; pinned quests and grey quests that are ready to turn in are kept.
- **Masque.** With Masque installed, the quest item buttons can wear your Masque skin (Masque > JTS Quest Tracker > Quest Items).
- **Rewards in the tooltip.** Hover a quest to see its XP, money, items and the items you can choose from.
- **Turn-in XP.** The header shows what you're carrying back to town, like `3 ready · 4,250 XP`, and stays pinned to the top while you scroll the list (Keep Header in View).
- **Easy to scan.** Finished objectives fade back, zone headers show how many quests they hold (`Elwynn Forest (3)`), and collapsed zones stay collapsed after a reload.
- **Safer startup.** If the tracker ever fails to start, you get Blizzard's default tracker back instead of none.
- **Bug fixes** for quest names containing `%`, quests without objectives looking "updated", a broken locale fallback, moved popup fields and stale quest log indexes.

## Features

- Move and lock the tracker anywhere on screen
- Collapsible zone headers
- Filter quests to your current zone or subzone
- Manually track or untrack quests
- Sort by level, percent complete, recently updated, quest proximity, or by hand (drag to reorder)
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
| `/jtsqt welcome` | Open the welcome screen (a quick tour of features to turn on or off) |
| `/jtsqt toggle` | Show or hide the tracker (also `show`, `hide`, or the key binding) |
| `/jtsqt collapse` / `/jtsqt expand` | Collapse or expand every zone |
| `/jtsqt share` | Share all your quests with your group |
| `/jtsqt cleanup` | Abandon your grey and failed quests (lists them and asks first) |
| `/jtsqt minimap` | Show or hide the minimap button |
| `/jtsqt status` | Print which game APIs were found (include this in bug reports) |
| `/jtsqt reset` | Clear your manual track and untrack choices |
| Left-click the header | Collapse or expand the tracker |
| Right-click the header | Menu: Collapse All, Expand All, Share All Quests, Hide Tracker, Settings |
| Right-click a zone header | Menu: Share This Zone's Quests, Collapse All, Expand All |
| Click a quest | Open it in the quest log |
| Shift-click / Alt-click / Ctrl-click a quest | Untrack / Wowhead link / link in chat |
| Middle-click a quest | Focus it: WoW's quest arrow and map waypoint point to it (click again to stop) |
| Right-click a quest | Quest menu (focus, pin, view, share, abandon) |

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
- New features go in their own files (`Extras.lua`, `ColorBlind.lua`, `Tags.lua`, `Media.lua`, `Profiles.lua`, `QuestItems.lua`, `Minimap.lua`, `Focus.lua`, `Visibility.lua`, `Headers.lua`, `Timers.lua`, `Distance.lua`, `Rewards.lua`, `PartyProgress.lua`, `Welcome.lua`, `StickyHeader.lua`, `ForeverQuests.lua`, `Skin.lua`, `Highlights.lua`, `Nameplates.lua`, `XPBar.lua`, `QuestItemKey.lua`) so the core tracker stays as close to the original design as possible.
- All internal libraries are registered under `JTSQT*` names and all globals start with `JTS_QuestTracker`, so this
  addon can be installed next to Butter Quest Tracker without the two overwriting each other.

## Version history

- **2.0.3** Modern skin: easier-to-read numbers. Level badges are bigger and no longer outlined (the outline smudged
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

## Credits and license

- Original addon: **Butter Quest Tracker** by Butter Cookie Kitkat, (c) 2019, MIT license.
- JTS Quest Tracker fork and changes: (c) 2026 James, released under the same MIT license. See [`LICENSE`](LICENSE),
  which keeps the original copyright notice as the MIT license requires.
- Bundled libraries keep their own licenses: Ace3 including AceDBOptions and AceSerializer (see [`Libs/Ace3-LICENSE.txt`](Libs/Ace3-LICENSE.txt)), LibStub and CallbackHandler.
- "Butter Quest Tracker" is the original author's name for their addon; it is used here only to credit the source of this fork.
