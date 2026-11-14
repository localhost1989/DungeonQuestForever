-- The addon's own copy of the part of QuestieDB it reads (QuestieDB is GPLv3; see README).
-- Step 1, once per language:  DQ_LOCALE=ruRU lua make-data.lua dump > /tmp/x.ru.lua
--                              DQ_LOCALE=enUS lua make-data.lua dump > /tmp/x.en.lua
-- Step 2:                      lua make-data.lua merge /tmp/x.ru.lua /tmp/x.en.lua > ../ForeverDungeonPrep/Data.lua
-- Extra ids the addon was seen to ask for (from the tests) can be given in data-extra.lua.
local here = arg[0]:match("^(.*[/])") or "./"
local mode = arg[1]

local function ser(v, out)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 2^53 then out[#out+1] = string.format("%d", v)
        else out[#out+1] = string.format("%.4g", v) end
    elseif t == "string" then out[#out+1] = string.format("%q", v):gsub("\\\n", "\\n")
    elseif t == "boolean" then out[#out+1] = tostring(v)
    elseif t == "table" then
        out[#out+1] = "{"
        local n = #v
        for i = 1, n do ser(v[i], out); out[#out+1] = "," end
        local keys = {}
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then keys[#keys+1] = k end
        end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        for _, k in ipairs(keys) do
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then out[#out+1] = k .. "="
            else out[#out+1] = "["; ser(k, out); out[#out+1] = "]=" end
            ser(v[k], out); out[#out+1] = ","
        end
        out[#out+1] = "}"
    else out[#out+1] = "nil" end
end
local function dumps(v) local out = {}; ser(v, out); return table.concat(out) end

if mode == "dump" then
    local locale = os.getenv("DQ_LOCALE") or "ruRU"
    GetLocale = function() return locale end
    dofile(here .. "questie-offline.lua")
    local Q, N, O, I = QuestDB, NpcDB, ObjectDB, ItemDB
    local function get(db, id, field) local ok, v = pcall(db.Get, id, field); if ok then return v end end
    local zones = LibQuestieDB.Support.Get("ZoneDB")
    local function readTable(src)
        if type(src) == "table" then return src end
        if type(src) ~= "string" then return {} end
        local ok, r = pcall(load(src:find("^%s*return") and src or ("return " .. src)))
        return ok and r or {}
    end
    local areaToMap = {}
    for a, m in pairs(readTable(zones.private.areaIdToUiMapId)) do areaToMap[a] = m end
    for a, m in pairs(readTable(zones.private.areaIdToUiMapIdOverride)) do areaToMap[a] = m end
    local keys = {2437, 718, 1581, 209, 719, 717, 721, 491, 796, 722, 1337, 1176, 2100, 1477, 1584, 1583, 2557, 2057, 2017, 16544, 16611, 16732, 16919}
    local dungeons, owner = {}, {}
    for _, area in ipairs(keys) do
        local e = zones.private.dungeons[area]
        if e then
            dungeons[area] = e
            owner[area] = true
            for _, o in ipairs(e[2] or {}) do owner[o] = true end
        end
    end
    local instances = {}
    for inst, area in pairs(zones.instanceIdToAreaId or {}) do
        if dungeons[area] then instances[inst] = area end
    end
    local QF = {"name", "questLevel", "requiredLevel", "requiredRaces", "requiredClasses", "requiredSkill", "zoneOrSort", "specialFlags",
        "questFlags", "preQuestSingle", "preQuestGroup", "nextQuestInChain", "parentQuest", "childQuests", "exclusiveTo", "startedBy",
        "finishedBy", "objectives", "objectivesText"}
    local all = Q.GetAllIds()
    -- The quests of the dungeons, and every quest linked to them, however far.
    local want, queue = {}, {}
    local function add(id)
        id = id and math.abs(id)
        if id and id > 0 and not want[id] and get(Q, id, "name") then want[id] = true; queue[#queue+1] = id end
    end
    for _, id in ipairs(all) do
        if owner[get(Q, id, "zoneOrSort") or 0] then add(id) end
    end
    local extra = {}
    local okExtra, loaded = pcall(dofile, here .. "data-extra.lua")
    if okExtra and type(loaded) == "table" then extra = loaded end
    for _, id in ipairs(extra.quests or {}) do add(id) end
    local i = 1
    while queue[i] do
        local id = queue[i]; i = i + 1
        for _, f in ipairs({"preQuestSingle", "preQuestGroup", "childQuests", "exclusiveTo"}) do
            for _, o in ipairs(get(Q, id, f) or {}) do add(o) end
        end
        add(get(Q, id, "nextQuestInChain")); add(get(Q, id, "parentQuest"))
    end
    local npcs, objects, items = {}, {}, {}
    local quests = {}
    for id in pairs(want) do
        local q = {}
        for _, f in ipairs(QF) do q[f] = get(Q, id, f) end
        quests[id] = q
        for _, k in ipairs({"startedBy", "finishedBy"}) do
            local by = q[k] or {}
            for _, n in ipairs(by[1] or {}) do npcs[n] = true end
            for _, o in ipairs(by[2] or {}) do objects[o] = true end
            for _, it in ipairs(by[3] or {}) do items[it] = true end
        end
        local ob = q.objectives or {}
        for _, c in ipairs(ob[1] or {}) do npcs[c[1]] = true end
        for _, o in ipairs(ob[2] or {}) do objects[o[1]] = true end
        for _, it in ipairs(ob[3] or {}) do items[it[1]] = true end
    end
    for _, id in ipairs(extra.npcs or {}) do npcs[id] = true end
    for _, id in ipairs(extra.objects or {}) do objects[id] = true end
    for _, id in ipairs(extra.items or {}) do items[id] = true end
    -- What drops the items asked for.
    local itemOut = {}
    for id in pairs(items) do
        local it = {name=get(I, id, "name"), npcDrops=get(I, id, "npcDrops"), objectDrops=get(I, id, "objectDrops")}
        if it.name then
            itemOut[id] = it
            for _, n in ipairs(it.npcDrops or {}) do npcs[n] = true end
            for _, o in ipairs(it.objectDrops or {}) do objects[o] = true end
        end
    end
    local usedAreas = {}
    local function keep(kind, db, set, fields)
        local out = {}
        for id in pairs(set) do
            local e = {}
            for _, f in ipairs(fields) do e[f] = get(db, id, f) end
            if e.name then
                -- The addon reads the first spot of each area only.
                if type(e.spawns) == "table" then
                    local first = {}
                    for area, list in pairs(e.spawns) do
                        if type(list) == "table" and list[1] then first[area] = {{list[1][1], list[1][2]}} end
                    end
                    e.spawns = first
                end
                out[id] = e
                for area in pairs(e.spawns or {}) do usedAreas[area] = true end
            end
        end
        return out
    end
    local npcOut = keep("npc", N, npcs, {"name", "spawns", "zoneID", "friendlyToFaction"})
    local objOut = keep("object", O, objects, {"name", "spawns"})
    for area, e in pairs(dungeons) do
        usedAreas[area] = true
        for _, o in ipairs(e[2] or {}) do usedAreas[o] = true end
        for _, door in ipairs(e[4] or {}) do usedAreas[door[1]] = true end
    end
    local maps = {}
    for area in pairs(usedAreas) do if areaToMap[area] then maps[area] = areaToMap[area] end end
    -- Junk: for every quest of the database not kept above, whether it stands alone, and its level.
    local askedFor = {}
    for _, id in ipairs(all) do
        for _, f in ipairs({"preQuestSingle", "preQuestGroup"}) do
            for _, b in ipairs(get(Q, id, f) or {}) do askedFor[math.abs(b)] = true end
        end
    end
    local function filled(t) return type(t) == "table" and next(t) ~= nil end
    local junk = {}
    for _, id in ipairs(all) do
        if not want[id] then
            local code
            local class, skill = get(Q, id, "requiredClasses"), get(Q, id, "requiredSkill")
            if filled(get(Q, id, "preQuestSingle")) or filled(get(Q, id, "preQuestGroup")) or askedFor[id]
                or (get(Q, id, "nextQuestInChain") or 0) > 0 or (get(Q, id, "parentQuest") or 0) > 0 or filled(get(Q, id, "childQuests")) then code = 1
            elseif (type(class) == "number" and class > 0) or filled(skill) then code = 3
            else code = 0 end
            junk[id] = math.max(0, get(Q, id, "questLevel") or 0) * 10 + code
        end
    end
    -- For the light over things to use: by object, every quest of the database that asks
    -- for it, or for an item that comes out of it.
    local uses = {}
    local function use(object, quest)
        uses[object] = uses[object] or {}
        for _, q in ipairs(uses[object]) do if q == quest then return end end
        table.insert(uses[object], quest)
    end
    local dropsOf = {}
    for _, id in ipairs(all) do
        local ob = get(Q, id, "objectives") or {}
        for _, o in ipairs(ob[2] or {}) do use(o[1], id) end
        for _, it in ipairs(ob[3] or {}) do
            if dropsOf[it[1]] == nil then dropsOf[it[1]] = get(I, it[1], "objectDrops") or false end
            for _, o in ipairs(dropsOf[it[1]] or {}) do use(o, id) end
        end
    end
    for _, list in pairs(uses) do table.sort(list) end
    io.write("return ", dumps({quests=quests, npcs=npcOut, objects=objOut, items=itemOut, maps=maps, dungeons=dungeons, instances=instances, junk=junk, uses=uses}), "\n")
elseif mode == "merge" then
    local ru, en = dofile(arg[2]), dofile(arg[3])
    -- A field that reads the same in both languages is kept once; one that differs, as {ru, en}.
    local function both(a, b)
        if dumps(a) == dumps(b) then return a end
        return {__ru=a, __en=b}
    end
    local out = {}
    for _, kind in ipairs({"quests", "npcs", "objects", "items"}) do
        out[kind] = {}
        for id, e in pairs(ru[kind]) do
            local o, f = {}, en[kind][id] or {}
            for k, v in pairs(e) do o[k] = both(v, f[k]) end
            out[kind][id] = o
        end
    end
    out.maps, out.instances, out.junk, out.uses = ru.maps, ru.instances, ru.junk, ru.uses
    out.dungeons = {}
    for area, e in pairs(ru.dungeons) do
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        copy[1] = both(e[1], en.dungeons[area] and en.dungeons[area][1])
        out.dungeons[area] = copy
    end
    local count = {}
    for _, kind in ipairs({"quests", "npcs", "objects", "items", "junk", "uses"}) do
        local n = 0; for _ in pairs(out[kind]) do n = n + 1 end; count[#count+1] = kind .. " " .. n
    end
    io.write("-- Generated by dungeon-quest-handoff/make-data.lua from QuestieDB (GPLv3); do not edit by hand.\n")
    io.write("-- " .. table.concat(count, ", ") .. "\n")
    io.write("local _, P = ...\n")
    io.write("P.Data = ", dumps(out), "\n")
end
