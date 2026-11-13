Tools used to build parts of the addon. Not packaged.

- `make-locale.py` — wraps Russian literals in `L"..."` and builds the English table in
  `Core.lua` from `locale/en.json`.
- `make-passes.py`, `passes.tsv` — the table of passes between zones in `Ways.lua`.
- `make-loot.lua` — the boss loot table in `Book.lua`, from QuestieDB.
- `make-flight-masters.lua` — lists flight masters from QuestieDB.
- `make-data.lua`, `make-data-extra.lua`, `data-extra.lua` — `Data.lua`: the part of QuestieDB
  the addon reads (dungeon quests and their chains, who gives and takes them, objective
  NPCs, objects and items, bosses and loot, flight masters, zones), in Russian and English,
  plus level and kind of every other quest for telling junk quests.
