-- Grafts the quests of Forever's new dungeons (and what they refer to) from a newer QuestieDB dump into Data.lua,
-- leaving every other entry as it was: lua make-data-graft.lua old/Data.lua new/Data.lua > Data.lua
-- Graft the quests of Forever's new dungeons (and all they refer to) from the new data
-- into the old one, leaving every other entry as it was.
local function load(path) local P = {}; assert(loadfile(path))("ForeverDungeonPrep", P); return P.Data end
local old, new = load(arg[1]), load(arg[2])
local roots = {95748, 95776, 95789, 95791, 96774, 97130, 94968, 94969, 94973, 94980, 94982, 94983, 92065, 96603, 97173, 98477}
local q, n, o, it = {}, {}, {}, {}
local queue = {}
local function addQ(id) id = id and math.abs(id); if id and id > 0 and new.quests[id] and not q[id] then q[id] = true; queue[#queue+1] = id end end
for _, id in ipairs(roots) do addQ(id) end
local i = 1
while queue[i] do
    local e = new.quests[queue[i]]; i = i + 1
    for _, f in ipairs({"preQuestSingle", "preQuestGroup", "childQuests", "exclusiveTo"}) do for _, x in ipairs(e[f] or {}) do addQ(x) end end
    addQ(e.nextQuestInChain); addQ(e.parentQuest)
    for _, k in ipairs({"startedBy", "finishedBy"}) do
        local by = e[k] or {}
        for _, x in ipairs(by[1] or {}) do n[x] = true end
        for _, x in ipairs(by[2] or {}) do o[x] = true end
        for _, x in ipairs(by[3] or {}) do it[x] = true end
    end
    local ob = e.objectives or {}
    for _, c in ipairs(ob[1] or {}) do n[c[1]] = true end
    for _, c in ipairs(ob[2] or {}) do o[c[1]] = true end
    for _, c in ipairs(ob[3] or {}) do it[c[1]] = true end
end
for id in pairs(it) do
    local e = new.items[id]
    if e then for _, x in ipairs(e.npcDrops or {}) do n[x] = true end; for _, x in ipairs(e.objectDrops or {}) do o[x] = true end end
end
local added = {quests=0, npcs=0, objects=0, items=0, maps=0}
local function copy(kind, set)
    for id in pairs(set) do
        if new[kind][id] and not old[kind][id] then old[kind][id] = new[kind][id]; added[kind] = added[kind] + 1 end
    end
end
copy("quests", q); copy("npcs", n); copy("objects", o); copy("items", it)
-- Map of every area a grafted thing stands in.
for _, kind in ipairs({"npcs", "objects"}) do
    for id in pairs(kind == "npcs" and n or o) do
        local e = old[kind][id]
        for area in pairs(e and e.spawns or {}) do
            if old.maps[area] == nil and new.maps[area] ~= nil then old.maps[area] = new.maps[area]; added.maps = added.maps + 1 end
        end
    end
end
for k, v in pairs(added) do io.stderr:write(k, " +", v, "\n") end
-- Serialize as make-data does.
local function ser(v, out)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 2^53 then out[#out+1] = string.format("%d", v)
        else out[#out+1] = string.format("%.4g", v) end
    elseif t == "string" then out[#out+1] = (string.format("%q", v):gsub("\\\n", "\\n"))
    elseif t == "boolean" then out[#out+1] = tostring(v)
    elseif t == "table" then
        out[#out+1] = "{"
        local cnt = #v
        for j = 1, cnt do ser(v[j], out); out[#out+1] = "," end
        local keys = {}
        for k in pairs(v) do if not (type(k) == "number" and k >= 1 and k <= cnt and k == math.floor(k)) then keys[#keys+1] = k end end
        table.sort(keys, function(a, b) if type(a) == type(b) then return a < b end return type(a) == "number" end)
        for _, k in ipairs(keys) do
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then out[#out+1] = k .. "=" else out[#out+1] = "["; ser(k, out); out[#out+1] = "]=" end
            ser(v[k], out); out[#out+1] = ","
        end
        out[#out+1] = "}"
    else out[#out+1] = "nil" end
end
local out = {}
ser(old, out)
local f = io.open(arg[1]); local l1, l2, l3 = f:read("l"), f:read("l"), f:read("l"); f:close()
local count = {}
for _, k in ipairs({"quests", "npcs", "objects", "items"}) do local c = 0; for _ in pairs(old[k]) do c = c + 1 end; count[k] = c end
l2 = l2:gsub("quests %d+, npcs %d+, objects %d+, items %d+", ("quests %d, npcs %d, objects %d, items %d"):format(count.quests, count.npcs, count.objects, count.items))
local NL = string.char(10)
io.write(l1, NL, l2, " (+ Forever's new dungeons from QuestieDB 1.1.1)", NL, l3, NL, "P.Data = ", table.concat(out), NL)
