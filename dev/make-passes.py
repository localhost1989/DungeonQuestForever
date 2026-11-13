# Пишет таблицу проходов из passes.tsv в Ways.lua между метками PASSES BEGIN / PASSES END.
# Запуск из папки dungeon-quest-handoff:  python3 make-passes.py
import io, re
ZONES = {"Durotar":1411,"Mulgore":1412,"The Barrens":1413,"Alterac Mountains":1416,"Arathi Highlands":1417,"Badlands":1418,
 "Blasted Lands":1419,"Tirisfal Glades":1420,"Silverpine Forest":1421,"Western Plaguelands":1422,"Eastern Plaguelands":1423,
 "Hillsbrad Foothills":1424,"The Hinterlands":1425,"Dun Morogh":1426,"Searing Gorge":1427,"Burning Steppes":1428,"Elwynn Forest":1429,
 "Deadwind Pass":1430,"Duskwood":1431,"Loch Modan":1432,"Redridge Mountains":1433,"Stranglethorn Vale":1434,"Swamp of Sorrows":1435,
 "Westfall":1436,"Wetlands":1437,"Teldrassil":1438,"Darkshore":1439,"Ashenvale":1440,"Thousand Needles":1441,"Stonetalon Mountains":1442,
 "Desolace":1443,"Feralas":1444,"Dustwallow Marsh":1445,"Tanaris":1446,"Azshara":1447,"Felwood":1448,"Un'Goro Crater":1449,
 "Moonglade":1450,"Silithus":1451,"Winterspring":1452,"Stormwind City":1453,"Orgrimmar":1454,"Ironforge":1455,"Thunder Bluff":1456,
 "Darnassus":1457,"Undercity":1458}
rows = []
for line in io.open("passes.tsv", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith("#"): continue
    a, ax, ay, b, bx, by, note, sure = line.split("\t")
    if sure not in ("high", "medium"): continue
    rows.append("    {a=%d, ax=%s, ay=%s, b=%d, bx=%s, by=%s},   -- %s" % (ZONES[a], ax, ay, ZONES[b], bx, by, note))
path = "../ForeverDungeonPrep/Ways.lua"
text = io.open(path, encoding="utf-8").read()
new, n = re.subn(r"(-- PASSES BEGIN\nlocal passes = \{\n).*?(\}\n-- PASSES END)", lambda m: m.group(1) + "\n".join(rows) + "\n" + m.group(2), text, flags=re.S)
assert n == 1
io.open(path, "w", encoding="utf-8").write(new)
print(len(rows), "passes written")
