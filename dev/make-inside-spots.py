#!/usr/bin/env python3
"""Where the goals of the dungeon quests lie inside 5-man dungeons: on the floor plans of
Dungeon Quest Atlas (Data/Maps.lua) and in the rooms the game names (GetSubZoneText).

Inputs:
  - ForeverDungeonPrep: Data.lua (QuestieDB: quests, npcs, objects, items), Core.lua (dungeon keys),
    Plan.lua (quests that belong to a dungeon by their source).
  - DungeonQuestAtlas (installed, read only): Data/Maps.lua, Data/Bosses.lua.
  - AzerothCore world DB (github.com/azerothcore/azerothcore-wotlk, master): creature.sql,
    gameobject.sql: the spawn points inside the instance maps.
  - wago.tools, WotLK Classic 3.4.3.58936: UiMapAssignment (world -> floor plan), AreaTable and
    WMOAreaTable (enUS, ruRU: room names), Map; and the client's WDT / ADT / WMO files of the
    instance maps (room geometry: which WMO group, and so which named room, a spawn stands in).
Downloads are cached in --cache (default: <system temp>/inside-spots-cache).
Run: python3 -I make-inside-spots.py [--cache DIR] [--out FILE]
"""
import argparse, collections, csv, json, math, os, re, struct, sys, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, '..', 'ForeverDungeonPrep'))
ATLAS = '/Applications/World of Warcraft/_forever_/Interface/AddOns/DungeonQuestAtlas/Data'
BUILD = '3.4.3.58936'
AC = 'https://raw.githubusercontent.com/azerothcore/azerothcore-wotlk/master/data/sql/base/db_world/'
# The instance maps' WDT files (wago.tools file search, world/maps/<Map.Directory>/<dir>.wdt).
WDT = {389: 789981, 43: 791429, 36: 780605, 33: 790796, 34: 791060, 48: 780169, 90: 782773, 47: 790640,
       129: 790517, 189: 788662, 70: 791372, 209: 791169, 349: 788656, 109: 791166, 230: 780172,
       229: 780175, 289: 790713, 329: 791063, 429: 780814}
# Core.lua tipKeys: one dungeon of the addon, several plans in the atlas.
ATLAS_KEYS = {'SM': ['SM_GY', 'SM_LIB', 'SM_ARM', 'SM_CATH'], 'BRS': ['LBRS', 'UBRS'],
              'DMAUL': ['DM_E', 'DM_N', 'DM_W'], 'STRAT': ['STRAT_LIVE', 'STRAT_UD']}
POINT_RADIUS = 0.08   # all spawns of a goal within this of one spot (0..1 of the plan): a point
CLUSTER_RADIUS = 0.06
PIN_OK = 0.03

# ---------------- luatable ----------------
_TOK = re.compile(r'''
    (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*)
  | (?P<str>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
  | (?P<num>-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+))
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<p>[{}\[\]=,;])
''', re.S | re.X)

_ESC = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}


def _unq(s):
    body = s[1:-1]
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            n = body[i + 1]
            if n.isdigit():
                j = i + 1
                while j < len(body) and j < i + 4 and body[j].isdigit():
                    j += 1
                out.append(chr(int(body[i + 1:j])))
                i = j
                continue
            out.append(_ESC.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def tokens(text):
    pos = 0
    n = len(text)
    while pos < n:
        m = _TOK.match(text, pos)
        if not m:
            raise ValueError('bad token at %d: %r' % (pos, text[pos:pos + 40]))
        pos = m.end()
        k = m.lastgroup
        if k == 'ws':
            continue
        v = m.group(k)
        if k == 'str':
            yield ('s', _unq(v))
        elif k == 'num':
            yield ('n', int(v, 16) if v.lower().startswith(('0x', '-0x')) else (float(v) if any(c in v for c in '.eE') else int(v)))
        elif k == 'name':
            yield ('id', v)
        else:
            yield ('p', v)


class _P:
    def __init__(self, toks):
        self.g = toks
        self.t = []
        self.i = 0

    def fill(self, k):
        while len(self.t) <= k:
            nxt = next(self.g, None)
            if nxt is None:
                return False
            self.t.append(nxt)
        return True

    def peek(self, ahead=0):
        return self.t[self.i + ahead] if self.fill(self.i + ahead) else (None, None)

    def take(self, kind=None, val=None):
        tok = self.peek()
        if (kind and tok[0] != kind) or (val and tok[1] != val):
            raise ValueError('expected %s %s got %r at %d' % (kind, val, tok, self.i))
        self.i += 1
        return tok

    def value(self):
        k, v = self.peek()
        if k == 'p' and v == '{':
            return self.table()
        self.i += 1
        if k in ('s', 'n'):
            return v
        if k == 'id':
            return {'true': True, 'false': False, 'nil': None}.get(v, ('ref', v))
        raise ValueError('bad value %r' % ((k, v),))

    def table(self):
        self.take('p', '{')
        arr, d, idx = [], {}, 1
        while True:
            k, v = self.peek()
            if k == 'p' and v == '}':
                self.i += 1
                break
            if k == 'p' and v == '[':
                self.i += 1
                key = self.value()
                self.take('p', ']')
                self.take('p', '=')
                d[key] = self.value()
            elif k == 'id' and self.peek(1) == ('p', '='):
                self.i += 2
                d[v] = self.value()
            else:
                d[idx] = self.value()
                idx += 1
            k, v = self.peek()
            if k == 'p' and v in (',', ';'):
                self.i += 1
        return d


def parse_value(text):
    return _P(tokens(text)).value()


def parse_assign(text, name):
    """Value of `name = {...}` inside a Lua file."""
    m = re.search(r'(?m)^\s*' + re.escape(name) + r'\s*=\s*\{', text)
    if not m:
        raise KeyError(name)
    p = _P(tokens(text[m.end() - 1:]))
    return p.table()


def seq(t):
    """Array part of a parsed table, in order."""
    if not isinstance(t, dict):
        return []
    out, i = [], 1
    while i in t:
        out.append(t[i])
        i += 1
    return out

# ---------------- acdb ----------------
ROW = re.compile(r"\(([^()]*(?:'[^']*'[^()]*)*)\)")


def columns(text, table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\n\) ENGINE" % table, text, re.S)
    return [c for c in re.findall(r"^\s*`(\w+)`", m.group(1), re.M)]


def load(path, table, maps):
    text = open(path, encoding='utf-8', errors='replace').read()
    cols = columns(text, table)
    ix = {c: i for i, c in enumerate(cols)}
    idcols = [ix[c] for c in ('id', 'id1', 'id2', 'id3') if c in ix]
    out = {}
    for block in re.finditer(r"INSERT INTO `%s` VALUES\s*(.*?);\s*$" % table, text, re.S | re.M):
        for m in ROW.finditer(block.group(1)):
            f = m.group(1).split(',', len(cols))
            if len(f) < ix['position_z'] + 1:
                continue
            mp = int(f[ix['map']])
            if mp not in maps:
                continue
            row = {'guid': int(f[ix['guid']]), 'x': float(f[ix['position_x']]), 'y': float(f[ix['position_y']]),
                   'z': float(f[ix['position_z']]), 'zoneId': int(f[ix['zoneId']]), 'areaId': int(f[ix['areaId']]),
                   'map': mp, 'ids': [int(f[i]) for i in idcols if int(f[i])]}
            out.setdefault(mp, []).append(row)
    return out

# ---------------- geo ----------------
UA = {'User-Agent': 'dungeon-map-tool'}
CACHE = None


def fetch(url, name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180).read()
        with open(path + '.part', 'wb') as f:
            f.write(data)
        os.replace(path + '.part', path)
    with open(path, 'rb') as f:
        return f.read()


VERSION = '3.4.3.58936'


def set_cache(path):
    global CACHE
    CACHE = path


def casc(fdid):
    # (without the version wago.tools serves the newest file of that id, which can be a later remake)
    return fetch('https://wago.tools/api/casc/%d?download&version=%s' % (fdid, VERSION), '%d_%s.bin' % (fdid, VERSION))


def search(term):
    return json.loads(fetch('https://wago.tools/api/files?search=' + urllib.parse.quote(term), 'search_' + term.replace('/', '_') + '.json'))


def chunks(b, start=0, end=None):
    i, end = start, len(b) if end is None else end
    while i + 8 <= end:
        tag = b[i:i + 4][::-1].decode('latin1')
        n = struct.unpack_from('<I', b, i + 4)[0]
        yield tag, i + 8, n
        i += 8 + n


class Group:
    """One WMO group: its id for WMOAreaTable, box and floor triangles in model space."""
    CELL = 4.0

    def __init__(self, data):
        self.ok = False
        for tag, off, n in chunks(data):
            if tag != 'MOGP':
                continue
            self.flags = struct.unpack_from('<I', data, off + 8)[0]
            self.box = struct.unpack_from('<6f', data, off + 12)
            self.gid = struct.unpack_from('<I', data, off + 0x38)[0]
            verts, idx, mopy = None, None, None
            for t2, o2, n2 in chunks(data, off + 0x44, off + n):
                if t2 == 'MOVT':
                    verts = struct.unpack_from('<%df' % (n2 // 4), data, o2)
                elif t2 == 'MOVI':
                    idx = struct.unpack_from('<%dH' % (n2 // 2), data, o2)
                elif t2 == 'MOPY':
                    mopy = data[o2:o2 + n2]
            self.tris = []
            if verts and idx:
                for t in range(len(idx) // 3):
                    # (MOPY flag 0x04 = detail, 0x20 = render only: not floor to stand on)
                    if mopy and len(mopy) >= 2 * t + 2:
                        fl = mopy[2 * t]
                        if not (fl & 0x08 or (fl & 0x20 and not fl & 0x04)):
                            continue
                    a, b, c = idx[3 * t:3 * t + 3]
                    p = (verts[3 * a:3 * a + 3], verts[3 * b:3 * b + 3], verts[3 * c:3 * c + 3])
                    self.tris.append(p)
            self.grid = {}
            for k, (a, b, c) in enumerate(self.tris):
                x0, x1 = min(a[0], b[0], c[0]), max(a[0], b[0], c[0])
                y0, y1 = min(a[1], b[1], c[1]), max(a[1], b[1], c[1])
                for gx in range(int(math.floor(x0 / self.CELL)), int(math.floor(x1 / self.CELL)) + 1):
                    for gy in range(int(math.floor(y0 / self.CELL)), int(math.floor(y1 / self.CELL)) + 1):
                        self.grid.setdefault((gx, gy), []).append(k)
            self.ok = True
            break

    def inbox(self, p, m=1.0):
        b = self.box
        return b[0] - m <= p[0] <= b[3] + m and b[1] - m <= p[1] <= b[4] + m and b[2] - 3 <= p[2] <= b[5] + 3

    def floor_below(self, p, up=3.0, down=80.0):
        """Height of the highest triangle under p (from p.z+up to p.z-down), or None."""
        x, y = p[0], p[1]
        best = None
        for k in self.grid.get((int(math.floor(x / self.CELL)), int(math.floor(y / self.CELL))), ()):
            a, b, c = self.tris[k]
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / d
            l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / d
            l3 = 1 - l1 - l2
            if l1 < -1e-6 or l2 < -1e-6 or l3 < -1e-6:
                continue
            z = l1 * a[2] + l2 * b[2] + l3 * c[2]
            if p[2] - down <= z <= p[2] + up and (best is None or z > best):
                best = z
        return best


class WMO:
    def __init__(self, fdid):
        root = casc(fdid)
        self.fdid = fdid
        self.wmoid = None
        gf = []
        ngroups = 0
        for tag, off, n in chunks(root):
            if tag == 'MOHD':
                ngroups = struct.unpack_from('<I', root, off + 4)[0]
                self.wmoid = struct.unpack_from('<I', root, off + 32)[0]
            elif tag == 'GFID':
                gf = list(struct.unpack_from('<%dI' % (n // 4), root, off))
        ids = [g for g in gf[:ngroups] if g]
        with ThreadPoolExecutor(8) as ex:
            blobs = list(ex.map(casc, ids))
        self.groups = [g for g in (Group(b) for b in blobs) if g.ok]


class Placement:
    """A WMO put into the world: world = R(angle) * model + origin."""

    def __init__(self, wmo, origin, angle, nameset=0):
        self.wmo, self.origin, self.angle, self.nameset = wmo, origin, angle, nameset
        self.c, self.s = math.cos(math.radians(angle)), math.sin(math.radians(angle))

    def to_model(self, p):
        dx, dy = p[0] - self.origin[0], p[1] - self.origin[1]
        return (self.c * dx + self.s * dy, -self.s * dx + self.c * dy, p[2] - self.origin[2])

    def locate(self, p):
        """(group, floor height gap) of the room p stands in, or (None, None)."""
        m = self.to_model(p)
        best, gap = None, None
        for g in self.wmo.groups:
            if not g.inbox(m):
                continue
            z = g.floor_below(m)
            if z is not None and (gap is None or m[2] - z < gap):
                best, gap = g, m[2] - z
        return best, gap


def wdt_info(fdid):
    b = casc(fdid)
    out = {'flags': 0, 'modf': [], 'maid': {}}
    for tag, off, n in chunks(b):
        if tag == 'MPHD':
            out['flags'] = struct.unpack_from('<I', b, off)[0]
        elif tag == 'MAID':
            for k in range(n // 32):
                f = struct.unpack_from('<8I', b, off + 32 * k)
                if f[0]:
                    out['maid'][(k % 64, k // 64)] = f  # (x = column, y = row)
        elif tag == 'MODF':
            for k in range(n // 64):
                e = struct.unpack_from('<II3f3f6fHHHH', b, off + 64 * k)
                out['modf'].append(e)
    return out


def adt_areas(fdid):
    """Terrain chunks of one root ADT: list of (maxX, maxY, areaId)."""
    b = casc(fdid)
    out = []
    for tag, off, n in chunks(b):
        if tag == 'MCNK':
            area = struct.unpack_from('<I', b, off + 0x34)[0]
            px, py, pz = struct.unpack_from('<3f', b, off + 0x68)
            out.append((px, py, area))
    return out


def adt_wmos(fdid):
    """WMO placements of one obj0 ADT: (fdid or None, uniqueId, pos, rot, flags, nameSet)."""
    b = casc(fdid)
    out = []
    for tag, off, n in chunks(b):
        if tag == 'MODF':
            for k in range(n // 64):
                e = struct.unpack_from('<II3f3f6fHHHH', b, off + 64 * k)
                out.append(e)
    return out

# ---------------- rooms ----------------
TILE = 533.33333
MID = 32 * TILE
CH = TILE / 16


def read_csv(path):
    with open(path, encoding='utf-8') as f:
        return list(csv.DictReader(f))


class Names:
    def __init__(self, dl):
        self.area = {}
        for loc, fn in (('en', 'AreaTable.csv'), ('ru', 'AreaTable_ruRU.csv')):
            for r in read_csv(os.path.join(dl, fn)):
                self.area.setdefault(int(r['ID']), {'parent': int(r['ParentAreaID'])})[loc] = r['AreaName_lang']
        self.wmo = {}
        for loc, fn in (('en', 'WMOAreaTable.csv'), ('ru', 'WMOAreaTable_ruRU.csv')):
            for r in read_csv(os.path.join(dl, fn)):
                key = (int(r['WMOID']), int(r['NameSetID']), int(r['WMOGroupID']))
                e = self.wmo.setdefault(key, {'id': int(r['ID']), 'areaTable': int(r['AreaTableID'])})
                e[loc] = r['AreaName_lang']

    def wmo_room(self, wmoid, nameset, gid):
        """(WMOAreaTable id, en, ru) the game shows as subzone in that group, or None."""
        for key in ((wmoid, nameset, gid), (wmoid, nameset, -1), (wmoid, 0, gid), (wmoid, 0, -1)):
            e = self.wmo.get(key)
            if e and (e.get('en') or e.get('ru')):
                return ('wmo:%d' % e['id'], e.get('en', ''), e.get('ru', ''))
            if e and e['areaTable']:
                return self.area_room(e['areaTable'])
        return None

    def area_room(self, aid):
        a = self.area.get(aid)
        if not a:
            return None
        return ('area:%d' % aid, a.get('en', ''), a.get('ru', ''))


class MapRooms:
    def __init__(self, mapid, wdt_fdid, names, spawns):
        self.mapid, self.names = mapid, names
        info = wdt_info(wdt_fdid)
        self.placements = []
        self.chunks = {}
        raw = []  # (wmo fdid, origin candidates, angle candidates, nameset, extents)
        if info['flags'] & 1:
            for e in info['modf']:
                raw.append((e[0], [(0.0, 0.0, 0.0)], [0, 90, 180, 270], e[16]))
        else:
            tiles = [f for f in info['maid'].values()]
            with ThreadPoolExecutor(8) as ex:
                areas = list(ex.map(lambda f: adt_areas(f[0]), tiles))
                objs = list(ex.map(lambda f: adt_wmos(f[1]) if f[1] else [], tiles))
            for lst in areas:
                for px, py, aid in lst:
                    self.chunks[(round((MID - px) / CH), round((MID - py) / CH))] = aid
            seen = set()
            for lst in objs:
                for e in lst:
                    uid = e[1]
                    if uid in seen:
                        continue
                    seen.add(uid)
                    if not e[14] & 0x8:
                        continue  # (name by string: not used by these maps)
                    pos, rot = e[2:5], e[5:8]
                    origin = (MID - pos[2], MID - pos[0], pos[1])
                    base = rot[1]
                    angs = sorted({(s * base + k) % 360 for s in (1, -1) for k in (0, 90, 180, 270)})
                    raw.append((e[0], [origin], angs, e[16]))
        cache = {}
        with ThreadPoolExecutor(4) as ex:
            wmos = list(ex.map(lambda r: WMO(r[0]), {r[0]: r for r in raw}.values()))
        for w in wmos:
            cache[w.fdid] = w
        pts = [(s['x'], s['y'], s['z']) for s in spawns]
        for fd, origins, angs, nameset in raw:
            w = cache[fd]
            best, score = None, -1
            for o in origins:
                for a in angs:
                    pl = Placement(w, o, a, nameset)
                    n = sum(1 for p in pts if pl.locate(p)[0] is not None)
                    if n > score:
                        best, score = pl, n
            best.score = score
            self.placements.append(best)

    def terrain(self, p):
        return self.chunks.get((math.floor((MID - p[0]) / CH), math.floor((MID - p[1]) / CH)))

    def locate(self, p):
        """(room key, en, ru, how) for a world point."""
        best, gap, bp = None, None, None
        for pl in self.placements:
            g, d = pl.locate(p)
            if g is not None and (gap is None or d < gap):
                best, gap, bp = g, d, pl
        if best is not None:
            r = self.names.wmo_room(bp.wmo.wmoid, bp.nameset, best.gid)
            if r:
                return r + ('wmo-group %d' % best.gid,)
            return (None, '', '', 'wmo-group %d (no name)' % best.gid)
        aid = self.terrain(p)
        if aid:
            r = self.names.area_room(aid)
            if r:
                return r + ('terrain',)
        return (None, '', '', 'none')



def download(cache, url, name):
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        print('download', url, file=sys.stderr)
        data = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'dungeon-map-tool'}), timeout=300).read()
        with open(path + '.part', 'wb') as f:
            f.write(data)
        os.replace(path + '.part', path)
    return path


def en(v):
    return v.get('__en') if isinstance(v, dict) else v


def ru(v):
    return v.get('__ru') if isinstance(v, dict) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', default=os.path.join(tempfile.gettempdir(), 'inside-spots-cache'))
    ap.add_argument('--out', default=os.path.join(HERE, 'inside-spots.json'))
    ap.add_argument('--addon', default=ADDON)
    ap.add_argument('--atlas', default=ATLAS)
    a = ap.parse_args()
    os.makedirs(os.path.join(a.cache, 'casc'), exist_ok=True)
    set_cache(os.path.join(a.cache, 'casc'))
    for f in ('creature', 'gameobject'):
        download(a.cache, AC + f + '.sql', f + '.sql')
    for t in ('UiMapAssignment', 'AreaTable', 'WMOAreaTable', 'Map'):
        download(a.cache, 'https://wago.tools/db2/%s/csv?build=%s' % (t, BUILD), t + '.csv')
    for t in ('AreaTable', 'WMOAreaTable'):
        download(a.cache, 'https://wago.tools/db2/%s/csv?build=%s&locale=ruRU' % (t, BUILD), t + '_ruRU.csv')

    # ---------------- addon data ----------------
    D = parse_assign(open(os.path.join(a.addon, 'Data.lua'), encoding='utf-8').read(), 'P.Data')
    core = open(os.path.join(a.addon, 'Core.lua'), encoding='utf-8').read()
    keys = {int(k): v for k, v in re.findall(r'\[(\d+)\]="([A-Z_]+)"', re.search(r'local keys = \{(.*?)\n\}', core, re.S).group(1))}
    plan = open(os.path.join(a.addon, 'Plan.lua'), encoding='utf-8').read()
    source_dungeon = {int(k): v for k, v in re.findall(r'\[(\d+)\]="([A-Z_]+)"', re.search(r'local sourceDungeon = \{(.*?)\}', plan).group(1))}
    maps_l = parse_assign(open(os.path.join(a.atlas, 'Maps.lua'), encoding='utf-8').read(), 'ns.Maps')
    bosses_l = parse_assign(open(os.path.join(a.atlas, 'Bosses.lua'), encoding='utf-8').read(), 'ns.Bosses')
    quests, npcs, objects, items = D['quests'], D['npcs'], D['objects'], D['items']

    instance_of = {}
    for inst, area in D['instances'].items():
        if area not in instance_of or inst < instance_of[area]:
            instance_of[area] = inst
    dungeons = {}
    area_owner = {}
    for area, key in keys.items():
        entry = D['dungeons'].get(area)
        if not entry or area not in instance_of or instance_of[area] not in WDT:
            continue
        d = {'key': key, 'area': area, 'map': instance_of[area], 'name': entry[1],
             'atlasKeys': [k for k in ATLAS_KEYS.get(key, [key]) if k in maps_l]}
        d['areas'] = [area] + seq(entry.get(2))
        for ar in d['areas']:
            area_owner[ar] = key
        dungeons[key] = d

    # ---------------- floors ----------------
    uma = read_csv(os.path.join(a.cache, 'UiMapAssignment.csv'))
    region = {}
    by_group = collections.defaultdict(set)
    zrows = collections.defaultdict(list)
    for r in uma:
        mp, um = int(r['MapID']), int(r['UiMapID'])
        reg = tuple(float(r['Region_%d' % i]) for i in range(6))
        if (r['UiMin_0'], r['UiMin_1'], r['UiMax_0'], r['UiMax_1']) == ('0', '0', '1', '1') and reg[3] > reg[0]:
            region.setdefault((mp, um), collections.Counter())[reg[:2] + reg[3:5]] += 1
            if int(r['WMOGroupID']):
                by_group[(mp, int(r['WMOGroupID']))].add(um)
            zrows[(mp, um)].append(reg)
    region = {k: c.most_common(1)[0][0] for k, c in region.items()}

    def to_plan(mp, um, x, y):
        reg = region.get((mp, um))
        if not reg:
            return None
        x0, y0, x1, y1 = reg
        return ((y1 - y) / (y1 - y0), (x1 - x) / (x1 - x0))

    floors = {}  # dungeon key -> list of (atlasKey, floor index, uiMap, pins)
    for d in dungeons.values():
        fl = []
        for ak in d['atlasKeys']:
            for i, f in enumerate(seq(maps_l[ak]), 1):
                fl.append({'atlasKey': ak, 'floor': i, 'uiMap': f['id'], 'pins': [seq(p) for p in seq(f.get('pins'))]})
        floors[d['key']] = fl

    # ---------------- spawns & rooms ----------------
    mapset = {d['map'] for d in dungeons.values()}
    cr = load(os.path.join(a.cache, 'creature.sql'), 'creature', mapset)
    go = load(os.path.join(a.cache, 'gameobject.sql'), 'gameobject', mapset)
    names = Names(a.cache)
    roomer = {}
    for d in dungeons.values():
        mp = d['map']
        print('rooms of', d['key'], file=sys.stderr)
        roomer[mp] = MapRooms(mp, WDT[mp], names, cr.get(mp, []) + go.get(mp, []))
    spawn_index = collections.defaultdict(list)  # (type, id, map) -> rows
    for mp, rows in cr.items():
        for r in rows:
            for i in r['ids']:
                spawn_index[('npc', i, mp)].append(r)
    for mp, rows in go.items():
        for r in rows:
            for i in r['ids']:
                spawn_index[('object', i, mp)].append(r)

    refs = collections.defaultdict(list)  # map -> (xyz, floor record) of matched pins

    def place(d, r):
        """Floor plan spot and room of one spawn row."""
        if '_place' in r:
            return r['_place']
        mp = d['map']
        p = (r['x'], r['y'], r['z'])
        room = roomer[mp].locate(p)
        gid = int(room[3].split()[1]) if room[3].startswith('wmo-group') else None
        cands = []
        for f in floors[d['key']]:
            uv = to_plan(mp, f['uiMap'], r['x'], r['y'])
            if uv and -0.02 <= uv[0] <= 1.02 and -0.02 <= uv[1] <= 1.02:
                cands.append((f, uv))
        how = 'single-floor'
        if len(cands) > 1:
            ums = by_group.get((mp, gid), set()) if gid is not None else set()
            pick = [c for c in cands if c[0]['uiMap'] in ums]
            if pick:
                cands, how = pick[:1], 'wmo-group'
            elif refs[mp]:
                best = min(refs[mp], key=lambda e: (e[0][0] - p[0]) ** 2 + (e[0][1] - p[1]) ** 2 + (3 * (e[0][2] - p[2])) ** 2)
                pick = [c for c in cands if c[0] is best[1]]
                cands, how = (pick or cands)[:1], 'nearest-boss-3d'
            else:
                cands, how = cands[:1], 'first-candidate'
        out = None
        if cands:
            f, uv = cands[0]
            # (one plan in two atlas keys, as LBRS/UBRS: the key with the nearest boss pin)
            same = [c for c in floors[d['key']] if c['uiMap'] == f['uiMap'] and c is not f and c['pins']]
            if same:
                f = min([f] + same, key=lambda c: min([math.hypot(pn[1] - uv[0], pn[2] - uv[1]) for pn in c['pins']] or [9]))
            out = {'f': f, 'x': round(uv[0], 3), 'y': round(uv[1], 3), 'how': how}
        r['_place'] = (out, room)
        return r['_place']

    # ---------------- boss pins check ----------------
    def lookup(table, name):
        for i, e in table.items():
            if en(e.get('name')) == name:
                return i
        return None

    pin_report = {}
    boss_info = {}
    for d in dungeons.values():
        rep = {'pins': 0, 'match': 0, 'off': [], 'noSpawn': [], 'noId': []}
        for f in floors[d['key']]:
            bl = seq(bosses_l.get(f['atlasKey']))
            for pin in f['pins']:
                idx, px, py = pin[0], pin[1], pin[2]
                b = bl[idx - 1] if 0 < idx <= len(bl) else {}
                kind = b.get('kind')
                typ = 'object' if kind == 'object' else 'npc'
                bid = b.get('npcID') if typ == 'npc' else None
                if not bid:
                    bid = lookup(npcs if typ == 'npc' else objects, b.get('name'))
                    if not bid and typ == 'npc':
                        bid = lookup(objects, b.get('name'))
                        typ = 'object' if bid else typ
                boss_info[(f['atlasKey'], idx)] = b
                rep['pins'] += 1
                if not bid:
                    rep['noId'].append(b.get('name'))
                    continue
                rows = spawn_index.get((typ, bid, d['map']), [])
                best = None
                for r in rows:
                    uv = to_plan(d['map'], f['uiMap'], r['x'], r['y'])
                    if uv:
                        dist = math.hypot(uv[0] - px, uv[1] - py)
                        if best is None or dist < best[0]:
                            best = (dist, r)
                if best is None:
                    rep['noSpawn'].append(b.get('name'))
                    continue
                if best[0] <= PIN_OK:
                    rep['match'] += 1
                    refs[d['map']].append(((best[1]['x'], best[1]['y'], best[1]['z']), f))
                else:
                    rep['off'].append('%s %.3f' % (b.get('name'), best[0]))
        pin_report[d['key']] = rep

    def boss_name(ak, idx):
        b = boss_info.get((ak, idx)) or {}
        if not b:
            bl = seq(bosses_l.get(ak))
            b = bl[idx - 1] if 0 < idx <= len(bl) else {}
        return b.get('name')

    def is_boss(ak, idx):
        bl = seq(bosses_l.get(ak))
        return 0 < idx <= len(bl) and bl[idx - 1].get('kind') in (None, 'rare')

    def nearest_boss(f, x, y):
        best = None
        for pin in f['pins']:
            if not is_boss(f['atlasKey'], pin[0]):
                continue
            dist = math.hypot(pin[1] - x, pin[2] - y)
            if best is None or dist < best[0]:
                best = (dist, pin[0])
        if not best:
            return None, None, None
        idx = best[1]
        ak = f['atlasKey']
        bl = seq(bosses_l.get(ak))
        prev = next((j for j in range(idx - 1, 0, -1) if is_boss(ak, j)), None)
        nxt = next((j for j in range(idx + 1, len(bl) + 1) if is_boss(ak, j)), None)
        return ({'index': idx, 'name': boss_name(ak, idx), 'distance': round(best[0], 3)},
                {'index': prev, 'name': boss_name(ak, prev)} if prev else None,
                {'index': nxt, 'name': boss_name(ak, nxt)} if nxt else None)

    # ---------------- quests ----------------
    listed = {}
    for qid, q in quests.items():
        k = area_owner.get(q.get('zoneOrSort'))
        if k and (q.get('specialFlags') or 0) % 2 == 0:
            listed[qid] = k
    for qid, k in source_dungeon.items():
        listed.setdefault(qid, k)

    def inside_dungeons(typ, sid):
        e = (npcs if typ == 'npc' else objects).get(sid)
        out = set()
        # (the database's word, or a spawn of AzerothCore on the instance map: some sources stand
        # both outside and inside, the database keeping only the outside spot)
        if e:
            for ar in (e.get('spawns') or {}):
                if ar in area_owner:
                    out.add(area_owner[ar])
        for d in dungeons.values():
            if spawn_index.get((typ, sid, d['map'])):
                out.add(d['key'])
        return out

    def src_name(typ, sid):
        e = (npcs if typ == 'npc' else objects).get(sid) or {}
        return en(e.get('name')) or ('#%d' % sid), ru(e.get('name'))

    goals = []  # (qid, kind, item, [(type, id)])
    for qid, q in sorted(quests.items()):
        ob = q.get('objectives') or {}
        for o in seq(ob.get(1)):
            goals.append((qid, 'kill', None, [('npc', o[1])]))
        for o in seq(ob.get(2)):
            goals.append((qid, 'use', None, [('object', o[1])]))
        for o in seq(ob.get(3)):
            it = items.get(o[1]) or {}
            srcs = [('npc', n) for n in seq(it.get('npcDrops'))] + [('object', n) for n in seq(it.get('objectDrops'))]
            goals.append((qid, 'loot', o[1], srcs))
        for o in seq(ob.get(5)):
            ids = seq(o.get(1)) if isinstance(o.get(1), dict) else [o.get(1)]
            goals.append((qid, 'kill', None, [('npc', i) for i in ids if i]))

    entries = []
    room_goals = collections.defaultdict(lambda: collections.defaultdict(list))
    def outside(typ, sid):
        e = (npcs if typ == 'npc' else objects).get(sid) or {}
        return any(ar not in area_owner for ar in (e.get('spawns') or {}))

    for qid, kind, item, srcs in goals:
        by_d = collections.defaultdict(list)
        for typ, sid in srcs:
            for k in inside_dungeons(typ, sid):
                by_d[k].append((typ, sid))
        # A quest not of that dungeon whose goal is also had outside (cloth from any chest):
        # nobody goes in for it.
        if any(outside(t, s) for t, s in srcs):
            by_d = {k: v for k, v in by_d.items() if listed.get(qid) == k}
        for k, ss in sorted(by_d.items()):
            if k not in dungeons:
                continue
            d = dungeons[k]
            q = quests[qid]
            pts = []
            src_list = []
            for typ, sid in ss:
                rows = spawn_index.get((typ, sid, d['map']), [])
                n_en, n_ru = src_name(typ, sid)
                src_list.append({'type': typ, 'id': sid, 'name': n_en, 'nameRu': n_ru, 'spawns': len(rows)})
                for r in rows:
                    pl, room = place(d, r)
                    pts.append((typ, sid, r, pl, room))
                    room_goals[k][room[0] or '(none)'].append((qid, kind, typ, sid, n_en, n_ru, item))
            e = {'dungeon': k, 'questID': qid, 'quest': en(q.get('name')), 'questRu': ru(q.get('name')),
                 'listed': listed.get(qid) == k, 'kind': kind}
            if item:
                it = items.get(item) or {}
                e['item'] = {'id': item, 'name': en(it.get('name')), 'nameRu': ru(it.get('name'))}
            e['spawns'] = len(pts)
            e['sources'] = src_list
            onplan = [p for p in pts if p[3]]
            rc = collections.Counter((p[4][0], p[4][1], p[4][2]) for p in pts)
            e['rooms'] = [{'id': r[0], 'en': r[1], 'ru': r[2], 'spawns': n} for r, n in rc.most_common()]
            e['spawnList'] = [{'type': p[0], 'id': p[1], 'guid': p[2]['guid'], 'world': [round(p[2]['x'], 1), round(p[2]['y'], 1), round(p[2]['z'], 1)],
                               'acZone': p[2]['zoneId'] or None, 'acArea': p[2]['areaId'] or None,
                               'room': p[4][0], 'roomHow': p[4][3],
                               'atlasKey': p[3]['f']['atlasKey'] if p[3] else None, 'floor': p[3]['f']['floor'] if p[3] else None,
                               'x': p[3]['x'] if p[3] else None, 'y': p[3]['y'] if p[3] else None,
                               'floorHow': p[3]['how'] if p[3] else None} for p in pts]
            if not onplan:
                e['status'] = 'no-spawn' if not pts else 'off-plan'
                e['spread'] = False
                entries.append(e)
                continue
            # medoid: the spawn with the least total distance to the others on its floor
            def dist(p1, p2):
                if p1[3]['f'] is not p2[3]['f']:
                    return 9
                return math.hypot(p1[3]['x'] - p2[3]['x'], p1[3]['y'] - p2[3]['y'])
            med = min(onplan, key=lambda p: sum(dist(p, o) for o in onplan))
            far = max(dist(med, o) for o in onplan)
            fc = collections.Counter((p[3]['f']['atlasKey'], p[3]['f']['floor'], p[3]['f']['uiMap']) for p in onplan)
            e['floors'] = [{'atlasKey': f[0], 'floor': f[1], 'uiMapID': f[2], 'spawns': n} for f, n in fc.most_common()]
            if far <= POINT_RADIUS:
                f = med[3]['f']
                e['spread'] = False
                e['status'] = 'point'
                n_en, n_ru = src_name(med[0], med[1])
                e['source'] = {'type': med[0], 'id': med[1], 'name': n_en, 'nameRu': n_ru}
                e.update({'atlasKey': f['atlasKey'], 'floor': f['floor'], 'uiMapID': f['uiMap'], 'x': med[3]['x'], 'y': med[3]['y'],
                          'floorHow': med[3]['how']})
                e['room'] = {'id': med[4][0], 'en': med[4][1], 'ru': med[4][2]}
                nb, pv, nx = nearest_boss(f, med[3]['x'], med[3]['y'])
                e['nearestBoss'], e['bossBefore'], e['bossAfter'] = nb, pv, nx
            else:
                e['spread'] = True
                e['status'] = 'spread'
                if len(ss) == 1:
                    n_en, n_ru = src_name(*ss[0])
                    e['source'] = {'type': ss[0][0], 'id': ss[0][1], 'name': n_en, 'nameRu': n_ru}
                # greedy clusters, for a hint of where most of them stand
                left = list(onplan)
                cl = []
                while left and len(cl) < 6:
                    c = max(left, key=lambda p: sum(1 for o in left if dist(p, o) <= CLUSTER_RADIUS))
                    mem = [o for o in left if dist(c, o) <= CLUSTER_RADIUS]
                    left = [o for o in left if dist(c, o) > CLUSTER_RADIUS]
                    nb = nearest_boss(c[3]['f'], c[3]['x'], c[3]['y'])[0]
                    cl.append({'atlasKey': c[3]['f']['atlasKey'], 'floor': c[3]['f']['floor'], 'uiMapID': c[3]['f']['uiMap'],
                               'x': c[3]['x'], 'y': c[3]['y'], 'spawns': len(mem), 'room': c[4][1] or None, 'roomRu': c[4][2] or None,
                               'nearestBoss': nb})
                e['clusters'] = cl
            entries.append(e)

    # ---------------- rooms section ----------------
    rooms_out = {}
    for k, d in sorted(dungeons.items()):
        mr = roomer[d['map']]
        allrooms = {}
        for pl in mr.placements:
            for g in pl.wmo.groups:
                r = names.wmo_room(pl.wmo.wmoid, pl.nameset, g.gid)
                if r:
                    e = allrooms.setdefault(r[0], {'id': r[0], 'en': r[1], 'ru': r[2], 'wmoGroups': [], 'floors': set()})
                    e['wmoGroups'].append(g.gid)
                    for um in by_group.get((d['map'], g.gid), ()):
                        e['floors'].add(um)
        for aid in set(mr.chunks.values()):
            r = names.area_room(aid)
            if r:
                allrooms.setdefault(r[0], {'id': r[0], 'en': r[1], 'ru': r[2], 'wmoGroups': [], 'floors': set()})
        # (rooms of the same name are one subzone for the game: merge them)
        merged = {}
        for r in allrooms.values():
            m = merged.setdefault((r['en'], r['ru']), {'en': r['en'], 'ru': r['ru'], 'ids': [], 'wmoGroups': [], 'floors': set()})
            m['ids'].append(r['id'])
            m['wmoGroups'] += r['wmoGroups']
            m['floors'] |= r['floors']
        uimap_floor = {f['uiMap']: (f['atlasKey'], f['floor']) for f in floors[k]}
        lst = []
        rg = room_goals.get(k, {})
        for m in sorted(merged.values(), key=lambda m: m['en']):
            gl = collections.OrderedDict()
            for rid in m['ids']:
                for qid, kind, typ, sid, n_en, n_ru, item in rg.get(rid, []):
                    key = (qid, kind, typ, sid, item)
                    if key not in gl:
                        gl[key] = {'questID': qid, 'kind': kind, 'sourceType': typ, 'sourceID': sid, 'name': n_en, 'nameRu': n_ru,
                                   'item': item, 'spawns': 0}
                    gl[key]['spawns'] += 1
            lst.append({'en': m['en'], 'ru': m['ru'], 'ids': sorted(m['ids']), 'wmoGroups': sorted(set(m['wmoGroups'])),
                        'floors': sorted('%s/%d' % uimap_floor[u] for u in m['floors'] if u in uimap_floor),
                        'goals': list(gl.values())})
        unnamed = collections.OrderedDict()
        for qid, kind, typ, sid, n_en, n_ru, item in rg.get('(none)', []):
            key = (qid, kind, typ, sid, item)
            unnamed.setdefault(key, {'questID': qid, 'kind': kind, 'sourceType': typ, 'sourceID': sid, 'name': n_en, 'nameRu': n_ru, 'item': item, 'spawns': 0})['spawns'] += 1
        rooms_out[k] = {'map': d['map'], 'zone': names.area_room(d['area'])[1:3] if names.area_room(d['area']) else None,
                        'rooms': lst, 'noRoomName': list(unnamed.values())}

    # ---------------- summary ----------------
    cover = {}
    for k in dungeons:
        qs = [q for q, kk in listed.items() if kk == k]
        st = collections.Counter()
        for q in qs:
            es = [e for e in entries if e['questID'] == q and e['dungeon'] == k]
            if not es:
                st['noInsideGoal'] += 1
            elif any(e['status'] == 'point' for e in es):
                st['point'] += 1
            elif any(e['status'] == 'spread' for e in es):
                st['spread'] += 1
            else:
                st['noSpawn'] += 1
        cover[k] = dict(st, quests=len(qs))
    out = {
        'about': 'Quest goals inside 5-man dungeons on the Dungeon Quest Atlas floor plans (x, y 0..1; floor = 1-based '
                 'index in Data/Maps.lua of atlasKey) and in the rooms the game names (GetSubZoneText; WMOAreaTable/AreaTable '
                 'names enUS/ruRU). Spawns: AzerothCore world DB; world->plan: UiMapAssignment %s; rooms and floors: '
                 'the WMO group each spawn stands in (client WMO geometry, wago.tools). Made by make-inside-spots.py.' % BUILD,
        'notes': {'acArea': 'AzerothCore creature/gameobject areaId: mostly 0 (empty) inside instances; zoneId is the instance zone when set',
                  'spread': 'spread = the goal spawns in several places (beyond %.2f of one spot); clusters give the main groups' % POINT_RADIUS,
                  'floorHow': 'single-floor: only one plan covers the spot; wmo-group: the floor the game shows for that WMO group; '
                              'nearest-boss-3d: guessed from the nearest boss in 3D'},
        'pinCheck': pin_report,
        'coverage': cover,
        'entries': entries,
        'rooms': rooms_out,
    }
    with open(a.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=False)
    print('wrote', a.out, len(entries), 'entries', file=sys.stderr)


if __name__ == '__main__':
    main()
