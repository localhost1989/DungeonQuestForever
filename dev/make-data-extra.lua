-- Writes data-extra.lua: the ids the addon reads besides the quests of the dungeons (bosses
-- and their loot, flight masters, zeppelin masters, the stops of the routes), read from
-- the addon's own sources, plus any ids the tests were seen to ask for (a record file made
-- with DQ_RECORD=..., given as the first argument; optional).
local src = (arg[0]:match("^(.*[/])") or "./") .. "../ForeverDungeonPrep/"
local npcs, objects, items, quests = {}, {}, {}, {}
local function read(name) local f = assert(io.open(src .. name)); local t = f:read("a"); f:close(); return t end
local book = read("Book.lua")
local loot = book:match("%-%- BEGIN LOOT.-\n(.-)%-%- END LOOT")
local P = {}
load(loot, "loot", "t", {P=P})()
for npc, list in pairs(P.Loot or {}) do
    npcs[npc] = true
    for i = 1, #list, 3 do items[list[i]] = true end
end
for _, name in ipairs({"Ways.lua", "BossRoute.lua", "PartyTips.lua", "SecretCatalog.lua", "Secrets.lua", "Journal.lua", "Plan.lua", "Core.lua"}) do
    local text = read(name)
    for id in text:gmatch("npc%s*=%s*(%d+)") do npcs[tonumber(id)] = true end
    for id in text:gmatch("npcID%s*=%s*(%d+)") do npcs[tonumber(id)] = true end
    for id in text:gmatch('"npc:(%d+)"') do npcs[tonumber(id)] = true end
    for id in text:gmatch("item%s*=%s*(%d+)") do items[tonumber(id)] = true end
    for id in text:gmatch("itemID%s*=%s*(%d+)") do items[tonumber(id)] = true end
    for id in text:gmatch("quest%s*=%s*(%d+)") do quests[tonumber(id)] = true end
end
-- The flight masters of both factions.
local ways = read("Ways.lua")
local masters = ways:match("local masters = (%b{})")
for id in masters:gmatch("%d+") do npcs[tonumber(id)] = true end
if arg[1] then
    local kind = {NpcDB=npcs, ObjectDB=objects, ItemDB=items}
    for line in io.lines(arg[1]) do
        local db, id = line:match("^(%S+) (%d+)$")
        if kind[db] and tonumber(id) < 100000000 then kind[db][tonumber(id)] = true end
    end
end
local function list(set) local t = {}; for id in pairs(set) do t[#t+1] = id end; table.sort(t); return "{" .. table.concat(t, ",") .. "}" end
io.write("-- Made by make-data-extra.lua; read by make-data.lua.\nreturn {npcs=", list(npcs), ",\nobjects=", list(objects), ",\nitems=", list(items), ",\nquests=", list(quests), "}\n")
