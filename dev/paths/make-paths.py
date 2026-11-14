# Builds ForeverDungeonPrep/Paths.lua: a walkable-path graph per continent, thinned from the graph of
# Guidelime Pathfinder (https://github.com/JagTheHero/guidelime-pathfinder, GPL-3.0-or-later,
# Copyright (c) 2026 JagTheHero), which is made from the terrain and buildings of the WoW: Forever client.
# Usage: python3 make-paths.py <path to guidelime-pathfinder> [cell yards] > ../../ForeverDungeonPrep/Paths.lua
#
# Their nodes are thinned to one per piece of a cell: the nodes of a cell joined by edges inside it make a
# piece, so the top and the foot of a cliff in one cell stay apart. A piece stands at its member nearest its
# middle; two pieces are joined where any of their members were. Coordinates become those of the addon: yards
# east and south from the top-left corner of the continent's map (HereBeDragons world x, y -> left - x, top - y).
import sys, re, math, collections
A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; D = {c: i for i, c in enumerate(A)}
def v(s, p, w):
    r = 0
    for k in range(w): r = r * 64 + D[s[p + k]]
    return r
def enc(x, w):
    out = []
    for _ in range(w): out.append(A[x % 64]); x //= 64
    assert x == 0
    return "".join(reversed(out))
root = sys.argv[1]; CELL = float(sys.argv[2]) if len(sys.argv) > 2 else 64.0
# The continent maps (uiMap 1414 Kalimdor, 1415 Eastern Kingdoms): width, height, left, top in world yards.
MAPS = {1414: (36799.81, 24533.2, 17066.6, 12799.9, root + "/addon/Guidelime_Pathfinder_Kalimdor/Kalimdor.lua"),
        1415: (35199.9, 23466.6, 16000.0, 7466.6, root + "/addon/Guidelime_Pathfinder_Azeroth/Azeroth.lua")}
out = ["-- Walkable paths of the two continents, thinned by dungeon-quest-handoff/paths/make-paths.py from the graph of",
       "-- Guidelime Pathfinder (https://github.com/JagTheHero/guidelime-pathfinder), GPL-3.0-or-later,",
       "-- Copyright (c) 2026 JagTheHero; made from the game's terrain and buildings. Do not edit by hand.",
       "-- nodes: x(3) y(3) in half-yards east and south of the map's corner, flags(1: 1 indoor, 2 swim), firstEdge(4)",
       "-- edges: neighbour * 4 + flags (3: 0-based neighbour; flags 1 swim, 2 narrow)",
       "local _, P = ...", "P.Paths = P.Paths or {}"]
for mapID, (W, H, LEFT, TOP, path) in MAPS.items():
    txt = open(path).read()
    ns = re.search(r'\tnodes = "([^"]*)"', txt).group(1); es = re.search(r'\tedges = "([^"]*)"', txt).group(1)
    n, e = len(ns) // 14, len(es) // 4
    X = [LEFT - (v(ns, i * 14, 3) / 4 - 17100) for i in range(n)]
    Y = [TOP - (v(ns, i * 14 + 3, 3) / 4 - 17100) for i in range(n)]
    F = [D[ns[i * 14 + 9]] for i in range(n)]
    FE = [v(ns, i * 14 + 10, 4) for i in range(n)] + [e]
    adj = []
    for i in range(n):
        lst = []
        for j in range(FE[i], FE[i + 1]):
            c = D[es[j * 4 + 3]]; fl = c % 4
            lst.append((v(es, j * 4, 3) + (c - fl) * 65536 // 4 * 4 // 4 * 0 + ((c >> 2) << 18), fl))
        adj.append(lst)
    cell = [(int(X[i] // CELL), int(Y[i] // CELL)) for i in range(n)]
    par = list(range(n))
    def find(a):
        while par[a] != a: par[a] = par[par[a]]; a = par[a]
        return a
    for i in range(n):
        for j, fl in adj[i]:
            if cell[j] == cell[i]:
                a, b = find(i), find(j)
                if a != b: par[a] = b
    groups = collections.defaultdict(list)
    for i in range(n): groups[find(i)].append(i)
    # Keep what lies on the map; drop specks (the GM island and the like) later by component size.
    piece, centre = {}, []
    for r, members in groups.items():
        mx = sum(X[i] for i in members) / len(members); my = sum(Y[i] for i in members) / len(members)
        best = min(members, key=lambda i: (X[i] - mx) ** 2 + (Y[i] - my) ** 2)
        k = len(centre); centre.append(best)
        for i in members: piece[i] = k
    m = len(centre)
    links = [dict() for _ in range(m)]
    for i in range(n):
        a = piece[i]
        for j, fl in adj[i]:
            b = piece[j]
            if a != b:
                old = links[a].get(b)
                if old is None or fl < old: links[a][b] = fl; links[b][a] = min(fl, links[b].get(a, fl))
    # Components: keep the big ones only.
    comp = [-1] * m; sizes = []
    for s in range(m):
        if comp[s] >= 0: continue
        cid = len(sizes); comp[s] = cid; stack = [s]; cnt = 0
        while stack:
            a = stack.pop(); cnt += 1
            for b in links[a]:
                if comp[b] < 0: comp[b] = cid; stack.append(b)
        sizes.append(cnt)
    keep = [k for k in range(m) if sizes[comp[k]] >= 30 and 0 <= X[centre[k]] <= W and 0 <= Y[centre[k]] <= H]
    # An edge that a detour through a common neighbour walks nearly as short is not needed.
    def dist(a, b):
        i, j = centre[a], centre[b]
        return math.hypot(X[i] - X[j], Y[i] - Y[j])
    dropped = 0
    for a in range(m):
        for b in sorted(links[a], key=lambda b: -dist(a, b)):
            if b < a or b not in links[a]: continue
            ab = dist(a, b)
            fl = links[a][b]
            for c in links[a]:
                if c != b and c in links[b] and links[a][c] <= fl and links[c][b] <= fl and dist(a, c) + dist(c, b) <= ab * 1.04:
                    del links[a][b]; del links[b][a]; dropped += 1
                    break
    sys.stderr.write("  dropped %d edges walked nearly as short through a neighbour\n" % dropped)
    newid = {k: idx for idx, k in enumerate(keep)}
    nodes, edges = [], []
    for k in keep:
        i = centre[k]
        flags = (1 if F[i] & 1 else 0) | (2 if F[i] & 2 else 0)
        nodes.append(enc(int(round(X[i] * 2)), 3) + enc(int(round(Y[i] * 2)), 3) + A[flags] + enc(len(edges), 4))
        for b, fl in sorted(links[k].items()):
            if b in newid: edges.append(enc(newid[b] * 4 + (fl & 3), 3))
    sys.stderr.write("map %d: %d nodes -> %d pieces kept, %d edges (components %d, biggest %d)\n" % (mapID, n, len(keep), len(edges), len(sizes), max(sizes)))
    out.append("P.Paths[%d] = {n=%d, e=%d, cell=%d, nodes=\"%s\", edges=\"%s\"}" % (mapID, len(nodes), len(edges), int(CELL), "".join(nodes), "".join(edges)))
print("\n".join(out))
