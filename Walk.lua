local _, P = ...

-- The owner: "it still does not lead to the goal quite right: it tries to cut across where
-- it may not get through." The game tells an addon nothing of the ground, so the arrow
-- pointed straight, into cliffs and mountains. Paths.lua holds the walkable paths of the two
-- continents (thinned from Guidelime Pathfinder's graph, which is made from the game's own
-- terrain and buildings; see that file). Here a way on foot is found over them, and the
-- arrow is turned to the next bend of that way instead of to the goal in a straight line;
-- the distance under it is counted along the way. Off the way, the way is found again.
--
-- Coordinates are those of the rest of the addon: yards east and south of the top-left corner
-- of the continent's map (atlas.Yards, atlas.PlayerYards).

local atlas = P.Core
local byte, floor, sqrt, huge = string.byte, math.floor, math.sqrt, math.huge
local DEC = {}
do
    local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do DEC[byte(ALPHA, i)] = i - 1 end
end
local NODE_W, EDGE_W = 11, 3
local SLOW = 2.5             -- a yard swum or along a narrow ledge costs this many walked
local NEAR = 70              -- yards: closer than this to the goal, straight is fine
local REACH = 120            -- yards: a node farther than this from where one stands is no start
local OFF_WAY = 45           -- yards off the way before it is found again
local LOST = 150             -- yards off the way: it is no use any more (a teleport, a fall)
local CUT = 60               -- yards: a node of the way this near may be gone to straight
local LOOK = 30              -- yards along the way ahead the arrow points to
local BUDGET_MS = 3          -- of a frame, for the search

local function v3(s, p)
    local a, b, c = byte(s, p, p + 2)
    return (DEC[a] * 64 + DEC[b]) * 64 + DEC[c]
end
local function v4(s, p)
    local a, b, c, d = byte(s, p, p + 3)
    return ((DEC[a] * 64 + DEC[b]) * 64 + DEC[c]) * 64 + DEC[d]
end

-- A continent's graph, read once: where each node stands, its flags, the cells, the
-- connected parts.
local graphs = {}
local function graph(continent)
    local raw = P.Paths and P.Paths[continent]
    if not (raw and raw.n and raw.n > 0) then return end
    local g = graphs[continent]
    if g and g.raw == raw then return g end
    -- One continent read at a time: the other is let go (the two together held some
    -- fifteen megabytes; the owner: "make it lighter, so it does not lag"). The cells are
    -- 128 yards a side: a quarter as many lists as at 64, and REACH still within one step.
    graphs = {}
    g = {raw=raw, n=raw.n, e=raw.e, nodes=raw.nodes, edges=raw.edges, cell=128, x={}, y={}, cells={}, part={}}
    local cs = g.cell
    for i = 1, g.n do
        local p = (i - 1) * NODE_W + 1
        local x, y = v3(raw.nodes, p) / 2, v3(raw.nodes, p + 3) / 2
        g.x[i], g.y[i] = x, y
        local key = floor(x / cs) * 4096 + floor(y / cs)
        local list = g.cells[key]
        if not list then list = {}; g.cells[key] = list end
        list[#list+1] = i
        -- Read a little at a time: tens of thousands of nodes.
        if i % 600 == 0 and coroutine.running() then coroutine.yield() end
    end
    graphs[continent] = g
    return g
end

local function edgeRange(g, i)
    local p = (i - 1) * NODE_W + 8
    local first = v4(g.nodes, p)
    local last = i < g.n and v4(g.nodes, p + NODE_W) or g.e
    return first, last
end
local function edgeAt(g, j)
    local value = v3(g.edges, j * EDGE_W + 1)
    local flags = value % 4
    return (value - flags) / 4 + 1, flags
end

-- Which connected part each node is in: a way between two parts does not exist.
local function parts(g)
    if g.parted then return end
    -- The owner: "the game freezes." One part may be the whole continent: the walk
    -- through it yields too, or it took a tenth of a second and more in one frame.
    local part, id, walked = g.part, 0, 0
    local yielding = coroutine.running() ~= nil
    for s = 1, g.n do
        if not part[s] then
            id = id + 1
            part[s] = id
            local stack = {s}
            while #stack > 0 do
                local a = stack[#stack]; stack[#stack] = nil
                local first, last = edgeRange(g, a)
                for j = first, last - 1 do
                    local b = edgeAt(g, j)
                    if not part[b] then part[b] = id; stack[#stack+1] = b end
                end
                walked = walked + 1
                if yielding and walked % 600 == 0 then coroutine.yield() end
            end
        end
    end
    g.parted = true
end

-- The nodes within REACH of a spot, nearest first: {id, yards}. Without heights a spot can
-- have a roof or a ledge nearest to it; the start and the end are taken from one part.
local function around(g, x, y)
    local cs = g.cell
    local cx, cy = floor(x / cs), floor(y / cs)
    local r = floor(REACH / cs) + 1
    local found = {}
    for dx = -r, r do
        for dy = -r, r do
            local list = g.cells[(cx + dx) * 4096 + (cy + dy)]
            if list then
                for _, i in ipairs(list) do
                    local d = sqrt((g.x[i] - x) ^ 2 + (g.y[i] - y) ^ 2)
                    if d <= REACH then found[#found+1] = {i, d} end
                end
            end
        end
    end
    table.sort(found, function(p, q) return p[2] < q[2] end)
    return found
end

-- A* from a to b; yields when the frame's time is spent (when it runs in a coroutine).
local clock = debugprofilestop or function() return os and os.clock and os.clock() * 1000 or 0 end
local function search(g, a, b, starts)
    local gx, gy = g.x, g.y
    local tx, ty = gx[b], gy[b]
    local cost, came, closed = {[a]=0}, {}, {}
    local heap, size = {a}, 1
    local score = {[a]=sqrt((gx[a] - tx) ^ 2 + (gy[a] - ty) ^ 2)}
    -- Several places to start from, each at the cost of walking to it straight: the way
    -- then begins at the node that makes it shortest, not at the nearest one (seen in the
    -- game: the nearest lay behind on the road, and the arrow sent the owner back west).
    if starts then
        cost, score, heap, size = {}, {}, {}, 0
        for _, s in ipairs(starts) do
            local i, d = s[1], s[2]
            if not cost[i] or d < cost[i] then
                cost[i] = d
                score[i] = d + sqrt((gx[i] - tx) ^ 2 + (gy[i] - ty) ^ 2) * 1.1
                size = size + 1
                heap[size] = i
            end
        end
        table.sort(heap, function(p, q) return score[p] < score[q] end)
    end
    local function push(i)
        size = size + 1
        heap[size] = i
        local k = size
        while k > 1 do
            local up = floor(k / 2)
            if score[heap[up]] <= score[heap[k]] then break end
            heap[up], heap[k] = heap[k], heap[up]
            k = up
        end
    end
    local function pop()
        local top = heap[1]
        heap[1] = heap[size]; heap[size] = nil; size = size - 1
        local k = 1
        while true do
            local l, r, m = k * 2, k * 2 + 1, k
            if l <= size and score[heap[l]] < score[heap[m]] then m = l end
            if r <= size and score[heap[r]] < score[heap[m]] then m = r end
            if m == k then break end
            heap[m], heap[k] = heap[k], heap[m]
            k = m
        end
        return top
    end
    local started, steps = clock(), 0
    while size > 0 do
        local u = pop()
        if u == b then
            local way = {}
            while u do table.insert(way, 1, u); u = came[u] end
            return way, cost[b]
        end
        if not closed[u] then
            closed[u] = true
            local first, last = edgeRange(g, u)
            local ux, uy, cu = gx[u], gy[u], cost[u]
            for j = first, last - 1 do
                local v, flags = edgeAt(g, j)
                if not closed[v] then
                    local length = sqrt((gx[v] - ux) ^ 2 + (gy[v] - uy) ^ 2)
                    local c = cu + (flags > 0 and length * SLOW or length)
                    if not cost[v] or c < cost[v] then
                        cost[v], came[v] = c, u
                        score[v] = c + sqrt((gx[v] - tx) ^ 2 + (gy[v] - ty) ^ 2) * 1.1
                        push(v)
                    end
                end
            end
        end
        steps = steps + 1
        if steps % 100 == 0 and coroutine.running() and clock() - started > BUDGET_MS then
            coroutine.yield()
            started = clock()
        end
    end
end

-- The way being walked: for one goal on one continent, the bends to pass.
local way          -- {key, continent, gx, gy, points={{x,y}...}, at=index of the next bend}
local job          -- the search under way: {key, co}
local lastTry = {} -- key -> when a way was last asked for (not more than once in two seconds)
local close        -- the key of the goal last found near: straight to it

local function goalKey(target)
    return tostring(target.mapID) .. ":" .. tostring(target.x) .. ":" .. tostring(target.y)
end

local function startSearch(key, continent, sx, sy, gx, gy)
    if not (P.Paths and P.Paths[continent]) then return end
    job = {key=key, co=coroutine.create(function()
        local g = graph(continent)
        if not g then return end
        local starts, ends = around(g, sx, sy), around(g, gx, gy)
        if #starts == 0 or #ends == 0 then return end
        parts(g)
        -- The pair nearest to both spots that lies in one part.
        local a, b, cost
        for _, s in ipairs(starts) do
            for _, e in ipairs(ends) do
                if g.part[s[1]] == g.part[e[1]] and (not cost or s[2] + e[2] < cost) then a, b, cost = s[1], e[1], s[2] + e[2] end
            end
        end
        if not a then return end
        -- Every node near the player in that part, at the cost of the straight walk to it.
        local from = {}
        for _, s in ipairs(starts) do
            if g.part[s[1]] == g.part[b] then from[#from+1] = {s[1], s[2]} end
        end
        local nodes = search(g, a, b, from)
        if not nodes then return end
        -- From where the player stood when it was asked for: one may start off the paths.
        -- The owner: "the arrow spins in all directions." The node nearest to the spot
        -- may lie behind; of the first nodes near enough to walk to straight, the one the
        -- way is shortest from is gone to, and those before it are left out.
        local n = #nodes
        local function span(i, j) return sqrt((g.x[i] - g.x[j]) ^ 2 + (g.y[i] - g.y[j]) ^ 2) end
        local rest = {[n] = sqrt((gx - g.x[nodes[n]]) ^ 2 + (gy - g.y[nodes[n]]) ^ 2)}
        for i = n - 1, 1, -1 do rest[i] = rest[i + 1] + span(nodes[i], nodes[i + 1]) end
        local first, shortest = 1, huge
        for i = 1, math.min(n, 16) do
            local d = sqrt((sx - g.x[nodes[i]]) ^ 2 + (sy - g.y[nodes[i]]) ^ 2)
            if (i == 1 or d <= CUT) and d + rest[i] < shortest then first, shortest = i, d + rest[i] end
        end
        local points = {{sx, sy}}
        for k = first, n do points[#points+1] = {g.x[nodes[k]], g.y[nodes[k]]} end
        points[#points+1] = {gx, gy}
        return points
    end)}
end

-- Runs the search a little at a time; true while it is not done.
function P.WalkStep(unlimited)
    if not job then return false end
    if unlimited then BUDGET_MS = huge end
    local ok, points = coroutine.resume(job.co)
    if unlimited then BUDGET_MS = 3 end
    if coroutine.status(job.co) ~= "dead" then return true end
    local key = job.key
    job = nil
    if ok and points then
        way = {key=key, points=points, at=1}
    elseif not (way and way.key == key and way.points) then
        way = {key=key, points=nil}
    end
    return false
end

local function segmentDistance(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local len = vx * vx + vy * vy
    local t = len > 0 and ((px - ax) * vx + (py - ay) * vy) / len or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx, cy = ax + t * vx, ay + t * vy
    return sqrt((px - cx) ^ 2 + (py - cy) ^ 2), t
end

-- For the arrow: where to point (yards east and south of the player) and how far the goal
-- is along the way. nil when there is no way to follow (it is then pointed straight).
function P.Steer(target)
    if P.char and P.char.noPaths then return end
    if not (target and target.mapID and atlas.Yards and atlas.PlayerYards) then return end
    if IsInInstance and IsInInstance() then return end
    local okT, tc, tx, ty = pcall(atlas.Yards, target)
    local okP, pc, px, py = pcall(atlas.PlayerYards)
    if not (okT and okP and tc and pc and tc == pc and tx and px) then return end
    local key = goalKey(target)
    -- Near the goal it is straight; and it stays straight a little past that, or at the
    -- edge the arrow would go back and forth between the two.
    local left = sqrt((tx - px) ^ 2 + (ty - py) ^ 2)
    if left < NEAR or (close == key and left < NEAR + 30) then close = key return end
    if close == key then close = nil end
    local now = GetTime and GetTime() or 0
    if not way or way.key ~= key then
        -- Under a roof no way is begun: the paths are drawn over the open land. A way
        -- already followed goes on under it, though: the Drag of Orgrimmar lies under the
        -- rock, and the arrow switched between the way and the straight line at every
        -- overhang. (The owner: "again the arrow turns in no clear direction.")
        if IsIndoors and IsIndoors() then return end
        if job and job.key == key then return end
        if (lastTry[key] or -huge) + 2 > now then return end
        lastTry[key] = now
        way = nil
        startSearch(key, tc, px, py, tx, ty)
        return
    end
    local points = way.points
    if not points then
        -- No way was found: try again in a while, from wherever the player is then.
        if (lastTry[key] or -huge) + 15 < now then way = nil end
        return
    end
    -- The bend to head for: past the ones already reached or left behind.
    local at = way.at
    local best, bestT, bestK = huge, 0, at
    -- Never back to a bend left behind: from one step to the next the nearest piece of
    -- the way was now the one before the bend and now the one after it, and the arrow
    -- swung between the two. Going back, if it comes to that, is a new way.
    for k = at, math.min(#points - 1, at + 6) do
        local d, t = segmentDistance(px, py, points[k][1], points[k][2], points[k + 1][1], points[k + 1][2])
        if d < best then best, bestT, bestK = d, t, k end
    end
    if best > LOST then
        -- Far from it: of no use any more; found again from here.
        way = nil
        if not job and (lastTry[key] or -huge) + 2 <= now then
            lastTry[key] = now
            startSearch(key, tc, px, py, tx, ty)
        end
        return
    end
    if best > OFF_WAY and not job and (lastTry[key] or -huge) + 2 <= now then
        lastTry[key] = now
        startSearch(key, tc, px, py, tx, ty)
    end
    -- Off the way and a new one being found: the arrow holds where it pointed (the old way
    -- sent the owner back to it for half a minute, while he ran a shorter road).
    if best > OFF_WAY and job then return end
    way.at = bestK
    -- The arrow points at the spot thirty yards on along the way from the nearest point of
    -- it, not at the next bend: on a winding road the bends come every few yards, and the
    -- hand jumped from one to the next.
    local ax, ay, bx, by = points[bestK][1], points[bestK][2], points[bestK + 1][1], points[bestK + 1][2]
    local cx, cy = ax + bestT * (bx - ax), ay + bestT * (by - ay)
    local fx, fy, k, ahead = cx, cy, bestK, LOOK
    while k < #points do
        local nx, ny = points[k + 1][1], points[k + 1][2]
        local piece = sqrt((nx - fx) ^ 2 + (ny - fy) ^ 2)
        if piece >= ahead then
            fx, fy = fx + (nx - fx) * ahead / piece, fy + (ny - fy) * ahead / piece
            break
        end
        ahead = ahead - piece
        fx, fy, k = nx, ny, k + 1
    end
    local along = sqrt((cx - px) ^ 2 + (cy - py) ^ 2) + sqrt((bx - cx) ^ 2 + (by - cy) ^ 2)
    for j = bestK + 1, #points - 1 do
        along = along + sqrt((points[j + 1][1] - points[j][1]) ^ 2 + (points[j + 1][2] - points[j][2]) ^ 2)
    end
    return fx - px, fy - py, along
end

-- The way found for a goal, for the tests and /dq path.
function P.WalkWay() return way, job end
-- A way is being looked for right now (the arrow holds its last bearing meanwhile).
function P.WalkBusy() return job ~= nil end
function P.WalkReset() way, job, lastTry, close = nil, nil, {}, nil end

-- The search runs a few milliseconds a frame.
if CreateFrame and UIParent then
    local runner = CreateFrame("Frame", "DungeonQuestForeverWalk", UIParent)
    runner:SetScript("OnUpdate", function() if job then pcall(P.WalkStep) end end)
end

