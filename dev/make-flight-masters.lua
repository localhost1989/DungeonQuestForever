GetLocale = function() return "ruRU" end
dofile(arg[1] .. "/questie-offline.lua")
local n, out = 0, {}
for _, id in ipairs(NpcDB.GetAllIds()) do
    local ok, flags = pcall(NpcDB.Get, id, "npcFlags")
    if ok and type(flags) == "number" and (flags // 8) % 2 == 1 then
        local spawns = NpcDB.Get(id, "spawns")
        local zone, x, y
        for z, list in pairs(spawns or {}) do zone, x, y = z, list[1] and list[1][1], list[1] and list[1][2] end
        out[#out+1] = ("%d\t%s\t%s\t%s\tzone %s %s %s\t%s"):format(id, tostring(NpcDB.Get(id, "name")), tostring(NpcDB.Get(id, "subName")), tostring(NpcDB.Get(id, "friendlyToFaction")), tostring(zone), tostring(x), tostring(y), tostring(NpcDB.Get(id, "zoneID")))
    end
end
print(#out)
for i = 1, #out do print(out[i]) end
