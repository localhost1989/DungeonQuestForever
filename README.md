# Dungeon Quest Forever

An addon for **World of Warcraft: Forever** (Interface 16001). It gets you ready for a
dungeon right in the quest tracker.

- **Before the dungeon.** Which quests to pick up, where, and in what order: chains are
  followed step by step, and the arrow moves on by itself when a step is turned in.
- **The way there.** The arrow takes the short way: flight masters, zeppelins and ships,
  mage teleports, and the passes between zones instead of a straight line over mountains.
- **Inside.** Bosses in order, what is left to do at each, and their loot with the best
  items for your class marked.
- **Less clicking.** Quests are picked up and turned in automatically (grey and repeatable
  ones are left to you), and junk quests can be cleared from the log with one button.

English and Russian. On a Russian client the addon speaks Russian, on any other, English.

## Install

Requires [QuestieDB](https://www.curseforge.com/wow/addons/questie) (it comes with Questie).
Put the `ForeverDungeonPrep` folder into `World of Warcraft/_forever_/Interface/AddOns/`.

## Use

- The panel stands in the quest tracker column. `•••` in its heading chooses the dungeon.
- Click a quest: it unfolds in place and sets the arrow. Right-click: map and details.
- `Journal` opens the book with every quest, boss and loot table of the dungeon.
- `/dq` opens the list of dungeons. Other commands: `/dq welcome`, `/dq auto`, `/dq junk`,
  `/dq dock`, `/dq cards`, `/dq bug`.

## Bugs and ideas

Write in [Issues](https://github.com/localhost1989/DungeonQuestForever/issues). In the game,
the little bug (on the welcome page, in the menu behind `•••`, or `/dq bug`) shows the
address and a few lines about your game to paste into the report.

## Credits and licence

GPL-3.0-or-later, see `LICENSE`.

- Quest, NPC and item data are read from QuestieDB at run time; the boss loot table in
  `Book.lua` is generated from QuestieDB item data (Questie, GPL-3.0).
- Coordinates of the passes between zones were compiled from public sources (the zone
  connection table of Carbonite Classic, RestedXP and Guidelime guide steps) and
  cross-checked against the game's map geometry.
- The pointer hand artwork was generated for this addon.
- If *Dungeon Quest Atlas* is installed, its dungeon maps are used for the small floor
  plan; nothing of that addon is included here.

---

# Dungeon Quest Forever (по-русски)

Аддон для **World of Warcraft: Forever**. Готовит к подземелью прямо в колонке заданий:
какие задания взять и где, дорога с перелётами, дирижаблями, телепортами и проходами
между зонами, боссы по порядку и их добыча с пометкой лучшего для твоего класса,
автоприём и автосдача заданий, удаление мусорных заданий одной кнопкой.

Нужен QuestieDB (идёт вместе с Questie). Папку `ForeverDungeonPrep` положить в
`World of Warcraft/_forever_/Interface/AddOns/`. Команда `/dq` открывает список
подземелий, `/dq welcome` — страницу приветствия, `/dq bug` — окно «Сообщить об ошибке»
(адрес, куда написать, и строки для отчёта). Писать можно по-русски.
