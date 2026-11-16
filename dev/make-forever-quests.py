# Задания Тюрьмы Альказа и Террасы ваятеля, которых нет в QuestieDB (forever-quests.json, собрано с
# Wowhead Forever 16.11.2026) -> записи в P.Data между -- BEGIN FOREVER QUESTS / -- END FOREVER QUESTS
# в конце ../ForeverDungeonPrep/Data.lua. Что уже есть в данных (NPC, предметы), не трогается.
import io, json, re
AREA = {"ALCAZ": 16620, "SHAPERS": 16985}
RACES = {"Alliance": 77, "Horde": 178, "both": 0}
SIDE = {"Alliance": "A", "Horde": "H", "both": "AH"}
src = json.load(io.open("forever-quests.json", encoding="utf-8"))
path = "../ForeverDungeonPrep/Data.lua"
data = io.open(path, encoding="utf-8").read()
a = data.find("-- BEGIN FOREVER QUESTS")
if a >= 0: data = data[:a].rstrip("\n") + "\n"
def section(name):
    i = data.find(name + "={")
    return data[i:]
have = {kind: set(int(x) for x in re.findall(r"\[(\d+)\]=\{", section(kind)[: (section(kind).find("},\n") if False else None)])) for kind in ("npcs", "objects", "items")}
def known(kind, id):
    # Quick check by key in the whole table text; ids in different tables rarely clash at these numbers.
    s = section(kind)
    return re.search(r"[{,]\[%d\]=\{" % id, s[: s.find("=", s.find("},") + 1) if False else len(s)]) is not None
def lua(v):
    if v is None: return "nil"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, list): return "{" + "".join(lua(x) + "," for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            parts.append(("[%d]=" % k if isinstance(k, int) else k + "=") + lua(x))
        return "{" + "".join(p + "," for p in parts) + "}"
npcs, objects, items, quests, lists = {}, {}, {}, {}, {}
def place(who, key):
    zone, x, y = who.get("zoneId"), who.get("x"), who.get("y")
    if zone == AREA.get(key) or (zone in (16620, 16667, 16985)) or x is None:
        return AREA[key], {AREA[key]: [[-1, -1]]}
    return zone, {zone: [[x, y]]}
def addNpc(id, name, who, key, side=None):
    if not id or id in npcs: return
    zone, spawns = place(who or {}, key)
    rec = {"name": name or "?", "spawns": spawns, "zoneID": zone}
    if side: rec["friendlyToFaction"] = side
    npcs[id] = rec
for key in ("ALCAZ", "SHAPERS"):
    lists[key] = []
    for q in src[key]:
        id = q["id"]; lists[key].append(id)
        g, t = q.get("giver") or {}, q.get("turnin") or {}
        side = SIDE.get(q.get("faction"), "AH")
        rec = {"name": q["name"], "questLevel": q.get("quest_level") or 0, "requiredLevel": q.get("required_level") or 0,
               "requiredRaces": RACES.get(q.get("faction"), 0), "requiredClasses": 0, "questFlags": 0, "specialFlags": 0, "parentQuest": 0}
        started, finished = [], []
        if g.get("id"):
            if g.get("type") == "object":
                started = [None, [g["id"]]]; objects.setdefault(g["id"], {"name": g.get("name") or "?", "spawns": place(g, key)[1], "zoneID": place(g, key)[0]})
            else:
                started = [[g["id"]]]; addNpc(g["id"], g.get("name"), g, key, side)
        if t.get("id"):
            if t.get("type") == "object":
                finished = [None, [t["id"]]]; objects.setdefault(t["id"], {"name": t.get("name") or "?", "spawns": place(t, key)[1], "zoneID": place(t, key)[0]})
            else:
                finished = [[t["id"]]]; addNpc(t["id"], t.get("name"), t, key, side)
        rec["startedBy"] = started; rec["finishedBy"] = finished
        kills, things, texts = [], [], []
        for o in q.get("objectives") or []:
            if o.get("type") == "kill" and o.get("npc_id"):
                kills.append({1: o["npc_id"], 3: 0}); addNpc(o["npc_id"], o.get("npc_name"), None, key)
                texts.append("%s slain: %d" % (o.get("npc_name") or "?", o.get("count") or 1))
            elif o.get("type") == "item" and o.get("item_id"):
                things.append({1: o["item_id"], 3: 0})
                drops = []
                for who in o.get("dropped_by") or []:
                    drops.append(who["npc_id"]); addNpc(who["npc_id"], who.get("name"), None, key)
                items.setdefault(o["item_id"], {"name": o.get("item_name") or o.get("name") or "?", "npcDrops": drops})
                texts.append("%s: %d" % (o.get("item_name") or o.get("name") or "?", o.get("count") or 1))
            elif o.get("text"):
                texts.append(o["text"])
        obj = {}
        if kills: obj[1] = kills
        if things: obj[3] = things
        rec["objectives"] = obj
        rec["objectivesText"] = texts or [q["name"]]
        pre = [p for p in (q.get("prerequisites") or [])]
        if len(pre) == 1: rec["preQuestSingle"] = pre
        elif len(pre) > 1: rec["preQuestGroup"] = pre
        nxt = q.get("next") or []
        rec["nextQuestInChain"] = nxt[0] if len(nxt) == 1 else 0
        inside = not g.get("id") or g.get("zoneId") in (16620, 16667, 16985)
        rec["zoneOrSort"] = AREA[key] if inside else (g.get("zoneId") or 0)
        quests[id] = rec
out = ["-- BEGIN FOREVER QUESTS: made by dungeon-quest-handoff/make-forever-quests.py from forever-quests.json (Wowhead Forever, 16.11.2026); do not edit by hand",
       "-- The quests of Alcaz Prison and Shaper's Terrace that QuestieDB does not have yet; what the data has already stays.",
       "do", "local D = P.Data"]
for kind, table in (("npcs", npcs), ("objects", objects), ("items", items)):
    for id in sorted(table):
        out.append("if not D.%s[%d] then D.%s[%d]=%s end" % (kind, id, kind, id, lua(table[id])))
for id in sorted(quests):
    out.append("D.quests[%d]=%s" % (id, lua(quests[id])))
out.append("P.ForeverQuests = {ALCAZ=%s, SHAPERS=%s}" % (lua(lists["ALCAZ"]), lua(lists["SHAPERS"])))
out.append("end"); out.append("-- END FOREVER QUESTS")
data = data.rstrip("\n") + "\n" + "\n".join(out) + "\n"
io.open(path, "w", encoding="utf-8").write(data)
print(len(quests), "quests,", len(npcs), "npcs,", len(objects), "objects,", len(items), "items")
