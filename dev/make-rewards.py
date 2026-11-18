# Награды заданий подземелий -> quest-rewards.json (для Dungeon Quest Forever).
#   python3 -I make-rewards.py
# Только стандартная библиотека. Всё скачанное лежит в SCRATCH/rewards-dl/ и читается как данные
# (json / sqlite / регулярные выражения), никогда не исполняется.
#
# Источники, по порядку доверия:
#  1. Wowhead Forever, страницы заданий (www.wowhead.com/forever/quest=ID) - то, что даёт сервер Forever
#     (Forever добавил к старым заданиям свои вещи 27xxxx, поменял часть наград, умножил опыт).
#     urllib получает от Wowhead 403, поэтому страницы читаются во встроенном браузере: на любой странице
#     www.wowhead.com/forever выполнить BROWSER_JS (ниже), затем JSON.stringify(window.__res) сохранить
#     в rewards-dl/wowhead-forever-quests.json под ключом "quests" (новые записи дописывать).
#     Если в rewards-dl/wh-quest/ID.html лежит сохранённая страница, она разбирается тем же разбором.
#     Wowhead отвечает «Human Verification» примерно после 30 страниц подряд - тогда остановиться.
#  2. VMaNGOS world DB (Classic 1.12, GPL; релиз db_latest на github.com/vmangos/core, sqlite):
#     quest_template (последний patch) для заданий, которых нет в п.1; item_template, item_display_info
#     (значок), locales_item.name_loc8 (русское имя) - для всех вещей.
#  3. Для заданий Forever (id >= 90000), которых нет в п.1: forever-quests.json (вещи без деления на
#     «выбор» и «всегда»: 2+ вещи считаются выбором) и опыт из QuestieDB Forever (xpDB-traces.lua).
#  4. Вещи из ../ForeverDungeonPrep/GearData.lua (timesaver.gg): значок/имена; его источники «q|..»
#     добавляют к заданиям из п.2 вещи Forever, которых нет в VMaNGOS (помечены "guessed").
#  5. Вещи, которых нет в VMaNGOS: всплывающая подсказка Wowhead nether.wowhead.com/tooltip/item/ID
#     ?dataEnv=16 (Forever) и &locale=7 (русский); не больше 1 запроса в секунду, с кэшем.
import glob, io, json, math, os, re, sqlite3, sys, time, urllib.error, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
# Downloads and the list of quest ids are kept outside the repository (DQ_REWARDS_WORK, else ./rewards-work).
SCRATCH = os.environ.get("DQ_REWARDS_WORK") or os.path.join(HERE, "rewards-work")
DL = os.path.join(SCRATCH, "rewards-dl")
IDS = os.path.join(SCRATCH, "reward-quest-ids.txt")
GEAR = os.path.join(HERE, "..", "ForeverDungeonPrep", "GearData.lua")
FOREVER_JSON = os.path.join(HERE, "forever-quests.json")
TRACES = os.path.join(SCRATCH, "qdb111/unz/QuestieDB/support/Forever/QuestXP/xpDB-traces.lua")
OUT = os.path.join(HERE, "quest-rewards.json")
UA = {"User-Agent": "Mozilla/5.0"}

BROWSER_JS = r"""
window.__parse=function(id,status,url,h){
 const o={s:status};
 const tm=h.match(/<title>([^<]*)<\/title>/); o.t=tm?tm[1].replace(/ - Quest - WoW Forever$/,''):'';
 if(!url.includes('quest='+id)) o.u=url;
 const a=h.indexOf('<h2 class="heading-size-3">Rewards</h2>');
 if(a>=0){ let b=h.indexOf('<h2',a+10); if(b<0)b=a+20000; const R=h.slice(a,b);
  const ca=R.indexOf('id="choicerewards"'); let cb=-1; if(ca>=0) cb=R.indexOf('</script>',ca);
  const re=/g_items\.createIcon\((\d+),\s*\d+,\s*"(\d+)"\)/g; let m; o.c=[];o.i=[];
  while((m=re.exec(R))){ const pair=[+m[1],+m[2]]; if(ca>=0&&m.index>ca&&m.index<cb)o.c.push(pair); else o.i.push(pair);}
  const rs=/g_spells\.createIcon\((\d+)/g; o.sp=[]; while((m=rs.exec(R)))o.sp.push(+m[1]);
  let tx=R.replace(/<table[\s\S]*?<\/table>/g,' ').replace(/<script[\s\S]*?<\/script>/g,' ').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ');
  for(const p of ['Rewards','You will be able to choose one of these rewards:','You will also receive:','You will receive:']) tx=tx.split(p).join(' ');
  tx=tx.trim(); if(tx)o.x=tx.slice(0,200);
  if(!o.c.length)delete o.c; if(!o.i.length)delete o.i; if(!o.sp.length)delete o.sp;
 }
 const k=h.indexOf('setupScalingRewards(');
 if(k>=0){ const e=h.indexOf(');</script>',k); try{ const j=JSON.parse(h.slice(k+20,e)); const L=String(j.maxLevel||j.minLevel); o.sc=[j.minLevel,j.maxLevel,j.xp&&j.xp.multiplier,j.xp&&j.xp.levels&&j.xp.levels[L],j.coin&&j.coin.levels&&j.coin.levels[L],j.coin&&j.coin.rewardAtCap,j.coin&&j.coin.multiplier];}catch(err){o.se=String(err).slice(0,80);} }
 return o;};
window.__res=window.__res||{};
// window.__ids=[...]; then:
(async()=>{ for(const id of window.__ids){ if(window.__res[id])continue; const r=await fetch('/forever/quest='+id); const h=await r.text();
  const o=window.__parse(id,r.status,r.url,h); if(o.s!==200){break;} window.__res[id]=o; await new Promise(r=>setTimeout(r,1500)); } })();
"""

_last = [0.0]
def fetch(url, path, polite=True):
    """Bytes of url, cached at path. None on HTTP error (cached as path + '.err')."""
    if os.path.exists(path): return open(path, "rb").read()
    if os.path.exists(path + ".err"): return None
    if polite:
        wait = _last[0] + 1.1 - time.time()
        if wait > 0: time.sleep(wait)
    _last[0] = time.time()
    try:
        data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
    except urllib.error.HTTPError as e:
        if e.code in (403, 405, 429): raise
        open(path + ".err", "w").write(str(e.code)); return None
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".part"; open(tmp, "wb").write(data); os.replace(tmp, path)
    return data

# ---------- VMaNGOS ----------
def vmangos():
    db = os.path.join(DL, "vmangos", "mangos.sqlite")
    zips = sorted(glob.glob(os.path.join(DL, "db-sqlite-*.zip")))
    if not os.path.exists(db):
        if not zips:
            rel = json.loads(fetch("https://api.github.com/repos/vmangos/core/releases/tags/db_latest",
                                   os.path.join(DL, "vmangos-release.json"), polite=False))
            asset = [a for a in rel["assets"] if re.fullmatch(r"db-sqlite-[0-9a-f]+\.zip", a["name"])][0]
            fetch(asset["browser_download_url"], os.path.join(DL, asset["name"]), polite=False)
            zips = [os.path.join(DL, asset["name"])]
        os.makedirs(os.path.dirname(db), exist_ok=True)
        with zipfile.ZipFile(zips[-1]) as z, open(db + ".part", "wb") as f:
            f.write(z.read("sqlite-dump/mangos.sqlite"))
        os.replace(db + ".part", db)
    name = os.path.basename(zips[-1]) if zips else "db-sqlite (cached)"
    c = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
    c.row_factory = sqlite3.Row
    last = "patch=(SELECT MAX(patch) FROM %s WHERE entry=t.entry)"
    quests = {r["entry"]: r for r in c.execute("SELECT * FROM quest_template t WHERE " + last % "quest_template")}
    items = {r["entry"]: r for r in c.execute("SELECT * FROM item_template t WHERE " + last % "item_template")}
    icons = {r[0]: r[1] for r in c.execute("SELECT ID, icon FROM item_display_info")}
    ru = {r[0]: r[1] for r in c.execute("SELECT entry, name_loc8 FROM locales_item WHERE name_loc8<>''")}
    return name, quests, items, icons, ru

# ---------- Wowhead Forever quest pages ----------
def js_round(x): return int(math.floor(x + 0.5))
def round_xp(x): step = 10 if x < 1000 else 50; return js_round(x / step) * step  # WH.Wow.Quest.roundQuestXp

def parse_quest_html(qid, h):
    """Python copy of BROWSER_JS __parse for saved pages."""
    o = {"s": 200}
    a = h.find('<h2 class="heading-size-3">Rewards</h2>')
    if a >= 0:
        b = h.find("<h2", a + 10)
        R = h[a:b if b >= 0 else a + 20000]
        ca = R.find('id="choicerewards"'); cb = R.find("</script>", ca) if ca >= 0 else -1
        for m in re.finditer(r'g_items\.createIcon\((\d+),\s*\d+,\s*"(\d+)"\)', R):
            o.setdefault("c" if ca >= 0 and ca < m.start() < cb else "i", []).append([int(m.group(1)), int(m.group(2))])
        sp = [int(x) for x in re.findall(r"g_spells\.createIcon\((\d+)", R)]
        if sp: o["sp"] = sp
    k = h.find("setupScalingRewards(")
    if k >= 0:
        try:
            j = json.loads(h[k + 20:h.find(");</script>", k)])
            L = str(j.get("maxLevel") or j.get("minLevel"))
            xp, coin = j.get("xp") or {}, j.get("coin") or {}
            o["sc"] = [j.get("minLevel"), j.get("maxLevel"), xp.get("multiplier"), (xp.get("levels") or {}).get(L),
                       (coin.get("levels") or {}).get(L), coin.get("rewardAtCap"), coin.get("multiplier")]
        except ValueError: pass
    return o

def wowhead_quests(ids):
    got = {}
    p = os.path.join(DL, "wowhead-forever-quests.json")
    if os.path.exists(p):
        for k, v in json.load(io.open(p, encoding="utf-8"))["quests"].items():
            if isinstance(v, dict) and v.get("s") == 200: got[int(k)] = v
    for qid in ids:
        f = os.path.join(DL, "wh-quest", "%d.html" % qid)
        if os.path.exists(f):
            h = io.open(f, encoding="utf-8", errors="replace").read()
            if "Human Verification" not in h[:3000]: got[qid] = parse_quest_html(qid, h)
    return got

def from_wowhead(o):
    pairs = lambda key: [{"id": int(a), "count": int(b)} for a, b in o.get(key, [])]
    rec = {"items": pairs("i"), "choice": pairs("c"), "money": 0, "src": "wowhead-forever"}
    sc = o.get("sc")
    if sc:
        mn, mx, xpm, xpb, coin, cap, coinm = (sc + [None] * 7)[:7]
        if coin: rec["money"] = js_round(coin * (coinm or 1))
        if cap: rec["moneyAtCap"] = int(cap)
        if xpb:
            rec["xp"] = round_xp(js_round(xpb * (xpm or 1)))
            rec["xpBase"] = int(xpb)
    if o.get("sp"): rec["spells"] = [int(x) for x in o["sp"]]
    return rec

def from_vmangos(r):
    rec = {"items": [], "choice": [], "money": max(0, r["RewOrReqMoney"] or 0), "src": "vmangos"}
    for i in range(1, 5):
        if r["RewItemId%d" % i]: rec["items"].append({"id": r["RewItemId%d" % i], "count": r["RewItemCount%d" % i] or 1})
    for i in range(1, 7):
        if r["RewChoiceItemId%d" % i]: rec["choice"].append({"id": r["RewChoiceItemId%d" % i], "count": r["RewChoiceItemCount%d" % i] or 1})
    if r["RewMoneyMaxLevel"]: rec["moneyAtCap"] = r["RewMoneyMaxLevel"]
    if r["RewXP"]: rec["xpBase"] = r["RewXP"]
    if r["RewSpell"] or r["RewSpellCast"]: rec["spells"] = [r["RewSpell"] or r["RewSpellCast"]]
    return rec

# ---------- GearData.lua (timesaver.gg) ----------
def gear():
    out, byquest = {}, {}
    s = r'"((?:[^"\\]|\\.)*)"'
    for m in re.finditer(r"^\[(\d+)\]=\{(\d+),(\d+),%s,%s,%s((?:,%s)*)\},?$" % (s, s, s, s), io.open(GEAR, encoding="utf-8").read(), re.M):
        iid = int(m.group(1))
        un = lambda x: x.replace('\\"', '"').replace("\\\\", "\\")
        out[iid] = {"quality": int(m.group(2)), "reqLevel": int(m.group(3)), "icon": un(m.group(4)), "en": un(m.group(5)), "ru": un(m.group(6))}
        for src in re.findall(s, m.group(7)):
            f = src.split("|")
            if f[0] == "q" and f[2].isdigit(): byquest.setdefault(int(f[2]), set()).add(iid)
    return out, byquest

# ---------- item tooltips (Wowhead nether, Forever) ----------
class Blocked(Exception): pass
def tooltip(iid, ru):
    url = "https://nether.wowhead.com/tooltip/item/%d?dataEnv=16%s" % (iid, "&locale=7" if ru else "")
    path = os.path.join(DL, "tooltip", "%d%s.json" % (iid, ".ru" if ru else ""))
    try: data = fetch(url, path)
    except urllib.error.HTTPError as e: raise Blocked(str(e))
    if not data: return None
    try: d = json.loads(data)
    except ValueError: return None
    return d if isinstance(d, dict) else None

def parse_tooltip(d):
    t = str(d.get("tooltip", ""))
    o = {"en": str(d.get("name", ""))[:200] or None, "quality": d.get("quality") if isinstance(d.get("quality"), int) else None,
         "icon": str(d.get("icon", "")).lower()[:100] or None}
    m = re.search(r"<!--ilvl-->(\d+)", t); o["level"] = int(m.group(1)) if m else None
    m = re.search(r"Requires Level (\d+)", t); o["reqLevel"] = int(m.group(1)) if m else None
    m = re.search(r'<table width="100%"><tr><td>([^<]*)</td><th>(.*?)</th>', t)
    if m:
        o["slot"] = m.group(1).strip() or None
        o["type"] = re.sub(r"<[^>]+>", "", m.group(2)).strip() or None
    return o

INV = {1: "Head", 2: "Neck", 3: "Shoulder", 4: "Shirt", 5: "Chest", 6: "Waist", 7: "Legs", 8: "Feet", 9: "Wrist", 10: "Hands",
       11: "Finger", 12: "Trinket", 13: "One-Hand", 14: "Off Hand", 15: "Ranged", 16: "Back", 17: "Two-Hand", 18: "Bag",
       19: "Tabard", 20: "Chest", 21: "Main Hand", 22: "Off Hand", 23: "Held In Off-hand", 24: "Projectile", 25: "Thrown",
       26: "Ranged", 27: "Quiver", 28: "Relic"}
CLASS = {0: "Consumable", 1: "Container", 2: "Weapon", 3: "Gem", 4: "Armor", 5: "Reagent", 6: "Projectile", 7: "Trade Goods",
         9: "Recipe", 11: "Quiver", 12: "Quest", 13: "Key", 15: "Miscellaneous"}
SUB = {2: {0: "Axe", 1: "Axe", 2: "Bow", 3: "Gun", 4: "Mace", 5: "Mace", 6: "Polearm", 7: "Sword", 8: "Sword", 10: "Staff",
           13: "Fist Weapon", 14: "Miscellaneous", 15: "Dagger", 16: "Thrown", 17: "Spear", 18: "Crossbow", 19: "Wand", 20: "Fishing Pole"},
       4: {0: "Miscellaneous", 1: "Cloth", 2: "Leather", 3: "Mail", 4: "Plate", 6: "Shield", 7: "Libram", 8: "Idol", 9: "Totem"},
       6: {2: "Arrow", 3: "Bullet"}, 11: {2: "Quiver", 3: "Ammo Pouch"}}

def main():
    ids = [int(x) for x in io.open(IDS) if x.strip()]
    vm_name, vq, vi, vicon, vru = vmangos()
    wh = wowhead_quests(ids)
    gi, gq = gear()
    fq = {}
    if os.path.exists(FOREVER_JSON):
        for key, lst in json.load(io.open(FOREVER_JSON, encoding="utf-8")).items():
            if isinstance(lst, list):
                for q in lst:
                    if isinstance(q, dict) and isinstance(q.get("id"), int) and isinstance(q.get("rewards"), list): fq[q["id"]] = q["rewards"]
    traces = {}
    if os.path.exists(TRACES):
        for m in re.finditer(r"QuestXP\.db\[(\d+)\] = \{(\d+), (\d+)\}", io.open(TRACES, encoding="utf-8").read()):
            traces[int(m.group(1))] = int(m.group(3))

    quests, diffs = {}, []
    for qid in ids:
        if qid in wh:
            rec = from_wowhead(wh[qid])
            if qid in vq:  # check against Classic
                v = from_vmangos(vq[qid])
                key = lambda l: sorted((x["id"], x["count"]) for x in l)
                d = []
                if key(v["items"]) != key(rec["items"]): d.append("items vm=%s wh=%s" % (key(v["items"]), key(rec["items"])))
                if key(v["choice"]) != key(rec["choice"]): d.append("choice vm=%s wh=%s" % (key(v["choice"]), key(rec["choice"])))
                if v["money"] != rec["money"]: d.append("money vm=%d wh=%d" % (v["money"], rec["money"]))
                if v.get("xpBase") != rec.get("xpBase"): d.append("xpBase vm=%s wh=%s" % (v.get("xpBase"), rec.get("xpBase")))
                if d: diffs.append((qid, d))
        elif qid in vq:
            rec = from_vmangos(vq[qid])
            have = {x["id"] for x in rec["items"] + rec["choice"]}
            extra = sorted(gq.get(qid, set()) - have)
            if extra:
                # On Forever a lone fixed item becomes one of the choices next to the new items (167, 704, 709).
                if len(rec["items"]) == 1 and not rec["choice"]: rec["choice"], rec["items"] = rec["items"], []
                rec["choice"] += [{"id": i, "count": 1} for i in extra]
                rec["guessed"] = extra; rec["src"] = "vmangos+timesaver"
        elif qid in fq:
            got = [int(x) for x in fq[qid] if isinstance(x, int)]
            rec = {"items": [], "choice": [], "money": None, "src": "forever-quests.json"}
            rec["choice" if len(got) > 1 else "items"] = [{"id": i, "count": 1} for i in got]
            if got: rec["guessed"] = got
        else:
            rec = {"items": [], "choice": [], "money": None, "src": "none"}
        if "xpBase" not in rec and qid in traces: rec["xpBase"] = traces[qid]
        rec.setdefault("xp", None)
        quests[str(qid)] = rec

    want = sorted({x["id"] for r in quests.values() for x in r["items"] + r["choice"]})
    items, blocked = {}, None
    for iid in want:
        it = {"en": None, "ru": None, "quality": None, "icon": None, "level": None, "reqLevel": None, "slot": None, "type": None}
        v, g = vi.get(iid), gi.get(iid)
        if v:
            it.update(en=v["name"], quality=v["quality"], level=v["item_level"] or None, reqLevel=v["required_level"] or None)
            if vicon.get(v["display_id"]): it["icon"] = vicon[v["display_id"]].lower()
            if v["inventory_type"] in INV: it["slot"] = INV[v["inventory_type"]]
            it["type"] = SUB.get(v["class"], {}).get(v["subclass"]) or CLASS.get(v["class"])
            it["ru"] = vru.get(iid)
        if g:
            for k in ("en", "quality", "reqLevel"):
                if it[k] is None: it[k] = g[k] or None
            it["icon"] = g["icon"] or it["icon"]
            if g["ru"] and not g["ru"].startswith("["): it["ru"] = g["ru"]
        if not v and not blocked:
            try:
                d = tooltip(iid, False)
                if d:
                    t = parse_tooltip(d)
                    for k, x in t.items():
                        if it.get(k) is None and x is not None: it[k] = x
                if it["ru"] is None:
                    d = tooltip(iid, True)
                    n = str(d.get("name", "")) if d else ""
                    if n and not n.startswith("["): it["ru"] = n[:200]
            except Blocked as e:
                blocked = "nether.wowhead.com stopped answering (%s); remaining tooltips skipped" % e
        items[str(iid)] = it

    src = {
        "quests": "Wowhead Forever quest pages (www.wowhead.com/forever, patch 1.60.1, read %s) where src=wowhead-forever; "
                  "otherwise VMaNGOS world DB %s (quest_template, latest patch row = 1.12). xp = Wowhead's shown Forever XP "
                  "(base x Forever multiplier, rounded like Wowhead); xpBase = base XP (VMaNGOS RewXP or QuestieDB Forever traces). "
                  "money in copper at the quest level; moneyAtCap = copper instead of XP at max level. "
                  "guessed = items not confirmed by a quest page (timesaver.gg gear sources or forever-quests.json)." % ("2026-11-17", vm_name),
        "items": "VMaNGOS item_template/item_display_info/locales_item (ruRU); ForeverDungeonPrep/GearData.lua (timesaver.gg + QuestieDB names); "
                 "Wowhead nether tooltips dataEnv=16 (Forever) for items not in VMaNGOS.",
    }
    if blocked: src["warning"] = blocked
    out = {"source": src, "quests": quests, "items": items}
    tmp = OUT + ".part"
    with io.open(tmp, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")
    os.replace(tmp, OUT)

    by = {}
    for r in quests.values(): by[r["src"]] = by.get(r["src"], 0) + 1
    rewarded = sum(1 for r in quests.values() if r["items"] or r["choice"] or r["money"])
    print("quests %d  with rewards %d  without %d  by source %s" % (len(quests), rewarded, len(quests) - rewarded, by))
    print("items %d  no ru %d  no icon %d  no en %d" % (len(items), sum(1 for x in items.values() if not x["ru"]),
          sum(1 for x in items.values() if not x["icon"]), sum(1 for x in items.values() if not x["en"])))
    print("wowhead vs vmangos: %d of %d checked quests differ" % (len(diffs), sum(1 for q in ids if q in wh and q in vq)))
    for qid, d in diffs: print("  %d: %s" % (qid, "; ".join(d)))
    if blocked: print("WARNING:", blocked)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
