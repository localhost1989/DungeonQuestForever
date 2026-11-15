-- Ways over the real walkable paths, outside the game: found, and how much longer than straight.
local here = arg[0]:match("^(.*[/])") or "./"
local src = here .. "../../ForeverDungeonPrep/"
local P = {Core={}}
CreateFrame, UIParent = nil, nil
assert(loadfile(src .. "Paths.lua"))("x", P)
assert(loadfile(src .. "Walk.lua"))("x", P)
-- A place on the continent's map in percent -> yards (the continent sizes of make-paths.py).
local size = {[1414]={36799.81, 24533.2}, [1415]={35199.9, 23466.6}}
local you = {}
P.Core.Yards = function(t) return t.mapID, t.x / 100 * size[t.mapID][1], t.y / 100 * size[t.mapID][2] end
P.Core.PlayerYards = function() return you.c, you.x, you.y end
IsInInstance = function() return false end
local clockT = 0
GetTime = function() clockT = clockT + 10 return clockT end
local function try(name, c, ax, ay, bx, by)
    P.WalkReset()
    you = {c=c, x=ax / 100 * size[c][1], y=ay / 100 * size[c][2]}
    local target = {mapID=c, x=bx, y=by}
    P.Steer(target)
    local t0 = os.clock()
    while P.WalkStep(true) do end
    local way = P.WalkWay()
    local dx, dy, along = P.Steer(target)
    local straight = math.sqrt((bx - ax) ^ 2 / 1e4 * size[c][1] ^ 2 + (by - ay) ^ 2 / 1e4 * size[c][2] ^ 2)
    print(("%-46s straight %6.0f  way %s  bends %s  %.2fs"):format(name, straight, along and ("%6.0f (x%.2f)"):format(along, along / straight) or "  none",
        way and way.points and #way.points or "-", os.clock() - t0))
    return along, straight
end
-- On the continent maps (percent): Orgrimmar gate -> the Crossroads; Crossroads -> Camp Taurajo;
-- Brill -> Tarren Mill (through the Silverpine road and Hillsbrad); Goldshire -> Lakeshire;
-- Ratchet -> Thousand Needles lift area; Stormwind -> Ironforge gates (around the mountains).
try("Kalimdor: Orgrimmar -> Crossroads", 1414, 58.5, 45.5, 53.0, 52.0)
try("Kalimdor: Crossroads -> Camp Taurajo", 1414, 53.0, 52.0, 51.0, 61.0)
try("Kalimdor: Ratchet -> Great Lift", 1414, 58.0, 53.0, 51.5, 67.0)
try("Kalimdor: Orgrimmar -> Ashenvale Splintertree", 1414, 58.5, 45.5, 56.0, 34.0)
try("EK: Brill -> Tarren Mill", 1415, 46.0, 21.0, 51.0, 37.0)
try("EK: Goldshire -> Lakeshire", 1415, 41.5, 72.5, 48.5, 72.0)
try("EK: Stormwind -> Ironforge", 1415, 40.5, 71.0, 47.0, 57.5)
try("EK: Ironforge -> Thelsamar", 1415, 47.0, 57.5, 52.5, 58.5)

-- Exact places: zone rectangles in world yards (from Guidelime Pathfinder's tests), zone percent -> continent.
local zones = {
    [1432] = {-1993.750, -4487.500, 2758.333, 1839.583}, -- Loch Modan
    [1453] = {1722.920, -7995.830, 1737.504, 1158.340},  -- Stormwind City
    [1455] = {-713.591, -4569.241, 790.625, 527.604},    -- Ironforge
    [1458] = {873.193, 1877.945, 959.375, 640.104},      -- Undercity
    [1436] = {3016.667, -9400.000, 3500.000, 2333.333},  -- Westfall
    [1420] = {3033.333, 3837.500, 4518.750, 3012.500},   -- Tirisfal Glades
}
local function onEK(zone, x, y)
    local z = zones[zone]
    local wx, wy = z[1] - z[3] * x / 100, z[2] - z[4] * y / 100
    return (16000.0 - wx) / 35199.9 * 100, (7466.6 - wy) / 23466.6 * 100
end
print("-- exact places")
local function exact(name, za, xa, ya, zb, xb, yb)
    local ax, ay = onEK(za, xa, ya)
    local bx, by = onEK(zb, xb, yb)
    try(name, 1415, ax, ay, bx, by)
end
exact("Stormwind gate -> Ironforge gate", 1453, 66, 87, 1455, 18, 51)
exact("Ironforge gate -> Thelsamar", 1455, 18, 51, 1432, 35, 47)
exact("Sentinel Hill -> Stormwind gate", 1436, 56, 47, 1453, 66, 87)
exact("Brill -> Undercity gate", 1420, 61, 52, 1420, 62, 65)
exact("Stormwind trade district -> Goldshire road", 1453, 60, 70, 1453, 66, 87)

-- The owner, running east along the Elwynn road toward the Badlands: "the arrow glitches,
-- no telling where to run." The node nearest lay behind on the road and the way began by
-- going back west. Now every node near is a start, at the cost of walking to it: north.
do
    P.WalkReset()
    you = {c=1415, x=18352, y=16920}
    local target = {mapID=1415, x=19084 / size[1415][1] * 100, y=14084 / size[1415][2] * 100}
    P.Steer(target)
    while P.WalkStep(true) do end
    local dx, dy = P.Steer(target)
    assert(dx and dy and dy < 0 and math.abs(dx) < -dy, "the way goes north, not back west: " .. tostring(dx) .. "," .. tostring(dy))
    print("PASS Elwynn road east -> Badlands: the way begins ahead, not behind")
end
