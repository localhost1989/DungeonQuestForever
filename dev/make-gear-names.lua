-- For make-gear.py: the Russian names and the zones of the things, creatures and quests of the
-- gear lists, from QuestieDB. Reads lines "item|npc|quest <id>" on stdin, writes
-- "kind id<TAB>Russian name<TAB>area" on stdout.
GetLocale = function() return "ruRU" end
local here = arg[0]:match("^(.*[/])") or "./"
dofile(here .. "questie-offline.lua")
local function get(db, id, field) local ok, v = pcall(db.Get, id, field) return ok and v or nil end
for line in io.lines() do
    local kind, id = line:match("^(%a+) (%d+)$")
    id = tonumber(id)
    local name, area = nil, 0
    if kind == "item" then name = get(ItemDB, id, "name")
    elseif kind == "npc" then
        name, area = get(NpcDB, id, "name"), get(NpcDB, id, "zoneID") or 0
        if area == 0 then for zone in pairs(get(NpcDB, id, "spawns") or {}) do area = zone break end end
    elseif kind == "quest" then
        name, area = get(QuestDB, id, "name"), get(QuestDB, id, "zoneOrSort") or 0
        if area < 0 then area = 0 end
    end
    -- A name with no Cyrillic in it is the English one: there is no Russian to give.
    if not (type(name) == "string" and name:find("[\208\209]")) then name = "" end
    print(("%s %d\t%s\t%d"):format(kind, id, name, area))
end
