local _, P = ...
local QuestDB, NpcDB, ObjectDB, ItemDB = P.QuestDB or QuestDB, P.NpcDB or NpcDB, P.ObjectDB or ObjectDB, P.ItemDB or ItemDB
local L = P.L or function(s) return s end
local atlas = P.Core

local function field(id, name)
    return QuestDB.Get(id, name)
end

local function done(id)
    return C_QuestLog.IsQuestFlaggedCompleted(id)
end

local function active(id)
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) then return true end
    local i = C_QuestLog.GetLogIndexForQuestID(id)
    return i and i > 0
end
P.IsActive = active

local function matchesMask(mask, id)
    return not mask or mask <= 0 or not id or math.floor(mask / 2^(id-1)) % 2 == 1
end

local function characterMatches(id)
    local q = atlas.Quests[id] or {}
    local _, _, race = UnitRace("player")
    local _, _, class = UnitClass("player")
    if atlas.ForeignQuest and atlas.ForeignQuest(id, UnitFactionGroup("player")) then return false end
    if not atlas.MatchesFaction(q, UnitFactionGroup("player")) or not atlas.IsMyClass(q)
        or not matchesMask(field(id,"requiredRaces"),race) or not matchesMask(field(id,"requiredClasses"),class) then return false end
    return true
end

local function availableBranch(id)
    for _, alt in ipairs(field(id,"exclusiveTo") or {}) do
        if done(alt) or active(alt) then return false end
    end
    return true
end

local function eligible(id)
    return characterMatches(id) and availableBranch(id)
end

local sourceDungeon = {[6522]="RFK", [6922]="BFD", [6981]="WC"}
local sourceBoss = {[6522]=4421, [6922]=12876, [6981]=3654}
local function dropLocation(d,id)
    local npcID = sourceBoss[id]
    if not npcID then return end
    for index,boss in ipairs((atlas.Bosses or {})[d.key] or {}) do
        if boss.npcID==npcID then return index,atlas.BossName(boss,d) end
    end
end
local dungeonIDs = {}
local function questIDs(d)
    if dungeonIDs[d.key] then return dungeonIDs[d.key] end
    local ids, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            ids[#ids+1] = id
        end
    end
    for _, id in ipairs(d.quests) do add(id) end
    for id,key in pairs(sourceDungeon) do if key == d.key then add(id) end end
    -- An on-floor quest giver can be missing from the main catalog.
    for _,floor in pairs((atlas.MapQuests or {})[d.key] or {}) do
        for _,spot in ipairs(floor) do
            for i=4,#spot do
                local entry = spot[i]
                for j=2,#entry do
                    if entry[j]=="start" then add(entry[1]) end
                end
            end
        end
    end
    dungeonIDs[d.key]=ids
    return ids
end

-- The roster is stable for this character; completion and exclusive branches
-- are read again when the quest log changes.
local roster = {}
local function characterQuests(d)
    if roster[d.key] then return roster[d.key] end
    local ids = {}
    for _, id in ipairs(questIDs(d)) do
        if characterMatches(id) then ids[#ids+1] = id end
    end
    roster[d.key] = ids
    return ids
end

-- The owner, the Compendium of the Fallen not taken: it is for orcs, tauren and trolls,
-- and he is undead; another addon's book showed it open. The quests of a dungeon that the
-- character's side can take and the character cannot for race, with why.
local RACES = {L"Человек", L"Орк", L"Дворф", L"Ночной эльф", L"Нежить", L"Таурен", L"Гном", L"Тролль"}
local SIDE = {Horde={2, 5, 6, 8}, Alliance={1, 3, 4, 7}}
local function raceName(i)
    local ok, info = pcall(function() return C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(i) end)
    return ok and type(info) == "table" and info.raceName or RACES[i]
end
-- Worked out once for each dungeon (the owner: "take the lags away"; the faction of every
-- quest was looked up at every refresh); done and taken are left out as it is read.
local notMine = {}
function P.NotForMe(d)
    local out = {}
    if not d then return out end
    local list = notMine[d.key]
    if not list then
        list = {}
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        local _, _, race = UnitRace("player")
        local _, _, class = UnitClass("player")
        for _, id in ipairs(questIDs(d)) do
            local races, classes = field(id, "requiredRaces"), field(id, "requiredClasses")
            -- Only what the side can take: a quest of the other side is no news. Nor is a
            -- quest of another class: the books of Dire Maul are a list of ten of them.
            if not matchesMask(races, race) and matchesMask(classes, class) then
                local mine = {}
                for _, i in ipairs(SIDE[faction] or {}) do
                    if matchesMask(races, i) then mine[#mine+1] = raceName(i) end
                end
                if #mine > 0 and not (atlas.ForeignQuest and atlas.ForeignQuest(id, faction)) then
                    list[#list+1] = {id=id, why=L"только для рас: " .. table.concat(mine, ", ")}
                end
            end
        end
        notMine[d.key] = list
    end
    for _, other in ipairs(list) do
        if not done(other.id) and not active(other.id) then out[#out+1] = other end
    end
    return out
end

-- Several quests that shut each other out are one quest for the page: the one the
-- character holds or has done, else the first of them.
local function twin(id, members)
    if done(id) or active(id) then return false end
    for _, alt in ipairs(field(id,"exclusiveTo") or {}) do
        if members[alt] and alt < id then return true end
    end
    return false
end

-- A quest that begins with a thing dropped in the dungeon, or follows one that does, is
-- not something left undone while the thing has not dropped: the player cannot take it
-- and often does not know it exists. The owner had "everything handed in" at Blackfathom
-- Deeps and the list still said two were left. Such a quest counts once it is in the
-- log, handed in, or its item is in the bags.
local function awaitsDrop(id, depth)
    if done(id) or active(id) or (depth or 0) > 5 then return false end
    local ok, waits = pcall(function()
        local items = (field(id, "startedBy") or {})[3]
        if items and items[1] then
            local count = C_Item and C_Item.GetItemCount or GetItemCount
            for _, item in ipairs(items) do
                if count and (count(item) or 0) > 0 then return false end
            end
            return true
        end
        for _, before in ipairs(field(id, "preQuestSingle") or {}) do
            if not done(before) and awaitsDrop(before, (depth or 0) + 1) then return true end
        end
        return false
    end)
    return ok and waits or false
end
P.AwaitsDrop = awaitsDrop

-- How a dungeon stands: handed in, all that count, in the log; and, of those in the log,
-- how many are done and only wait to be handed in. (The owner: "the numbers are wrong: it
-- says three taken, and they are done" - a quest done and one just taken were one number.)
function P.Progress(d)
    local finished, total, taken, ready = 0, 0, 0, 0
    local members = {}
    for _, id in ipairs(characterQuests(d)) do members[id] = true end
    for _, id in ipairs(characterQuests(d)) do
        if twin(id, members) then
            -- counted with its twin
        elseif awaitsDrop(id) then
            -- not counted until its item drops
        elseif done(id) then
            finished, total = finished + 1, total + 1
        elseif active(id) then
            taken, total = taken + 1, total + 1
            if C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then ready = ready + 1 end
        elseif availableBranch(id) then
            total = total + 1
            -- A step of its chain in the log is the quest under way: the owner, at the
            -- list of dungeons, "where I have quests not handed in, a question mark should
            -- hang, not an exclamation mark."
            local ok, steps = pcall(P.Chain, id)
            for _, step in ipairs(ok and type(steps) == "table" and steps or {}) do
                if step ~= id and active(step) then
                    taken = taken + 1
                    if C_QuestLog.IsComplete and C_QuestLog.IsComplete(step) then ready = ready + 1 end
                    break
                end
            end
        end
    end
    return finished, total, taken, ready
end

function P.Catalog()
    local catalog = {}
    for _, d in ipairs(atlas.Dungeons) do catalog[#catalog+1] = d end
    table.sort(catalog, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        if a.maxLevel ~= b.maxLevel then return a.maxLevel < b.maxLevel end
        return a.key < b.key
    end)
    return catalog
end

local indoorCache = {}
local function startsInside(id,d)
    local cache = indoorCache[d.key]
    if not cache then cache={} indoorCache[d.key]=cache end
    if cache[id] ~= nil then return cache[id] end
    if sourceDungeon[id] then return sourceDungeon[id] == d.key end
    if atlas.StartsInside then cache[id] = atlas.StartsInside(id) return cache[id] end
    if atlas.QuestSpotFloor and atlas.QuestSpotFloor(d,id,"start") then cache[id]=true return true end
    local q = atlas.Quests[id] or {}
    -- All known starters must be inside before excusing an outside pickup.
    cache[id]=false
    if not q.starts or #q.starts == 0 then return false end
    for _, key in ipairs(q.starts) do
        if not (atlas.Places[key] and atlas.Places[key].inside) then return false end
    end
    cache[id]=true
    return true
end

function P.Title(id)
    local live = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if live and live ~= "" then return live end
    local name = field(id,"name")
    return (atlas.QuestText(id) or {}).title or name or atlas.QuestTitle(id)
end

-- Prison Break In and Key to the City can be picked up together.
local overrides = { [962]={}, [544]={}, [93680]={}, [545]={544,93680} }

local function missing(id, path)
    if done(id) or active(id) then return id end
    if path[id] then return id, L"Не удалось проверить цепочку" end
    path[id] = true
    local q = atlas.Quests[id] or {}
    local group = overrides[id] or field(id,"preQuestGroup")
    local alternatives = not overrides[id] and field(id,"preQuestSingle")
    if not group and not alternatives then group = q.prereqs end
    local nextID
    for _, requirement in ipairs(group or {}) do
        local pre = math.abs(requirement)
        local satisfied = done(pre)
        if requirement > 0 and not satisfied then
            for _, alt in ipairs(field(pre,"exclusiveTo") or {}) do
                if done(alt) then satisfied = true break end
            end
        end
        -- The first is followed; the others of the group are needed as well and are kept
        -- (the owner, 15.11.2026, killing murlocs for "Enemies in the Water": nothing said it
        -- was wanted, though "The Only Good Brinescale" asks for it beside the chain).
        if not satisfied then
            if not nextID then nextID = pre
            else
                path.also = path.also or {}
                path.also[#path.also+1] = pre
            end
        end
    end
    if not nextID and alternatives and #alternatives > 0 then
        for _, pre in ipairs(alternatives) do
            if done(pre) then nextID = nil break end
            if active(pre) or (not nextID and eligible(pre)) then nextID = pre end
        end
    end
    if not nextID and alternatives and #alternatives>0 then
        local possible=false
        for _,pre in ipairs(alternatives) do
            if done(pre) or eligible(pre) then possible=true break end
        end
        if not possible then return id,L"Нет доступной ветки цепочки" end
    end
    if nextID and field(nextID,"name") == nil and not (atlas.Quests[nextID]) then
        return id, L"В базе нет начала цепочки"
    end
    if nextID then return missing(nextID, path) end
    if q.chain == true and not group and not alternatives then return id,L"Предыдущий шаг не указан в базе" end
    return id
end

-- The owner showed the atlas's quest book once more, a chain open in it: every step by
-- number, the one to take marked, "step 8 of 10". The whole chain that leads to a quest,
-- first step first, and which of its steps is the one to do now. Where a step has
-- several forerunners the first is followed: the list is a road, not a tree.
function P.Chain(id)
    local steps, seen, at = {id}, {[id]=true}, id
    for _ = 1, 40 do
        local q = atlas.Quests and atlas.Quests[at] or {}
        local group = overrides[at] or field(at, "preQuestGroup")
        local singles = not overrides[at] and field(at, "preQuestSingle")
        if not group and not singles then group = q.prereqs end
        local pre
        if group and group[1] then
            pre = math.abs(group[1])
        elseif singles and #singles > 0 then
            for _, alt in ipairs(singles) do
                if done(alt) or active(alt) then pre = alt break end
            end
            if not pre then
                for _, alt in ipairs(singles) do
                    if eligible(alt) then pre = alt break end
                end
            end
            pre = pre or singles[1]
        end
        if not pre or seen[pre] then break end
        if field(pre, "name") == nil and not (atlas.Quests and atlas.Quests[pre]) then break end
        seen[pre] = true
        table.insert(steps, 1, pre)
        at = pre
    end
    local now = #steps
    for i, step in ipairs(steps) do
        if not done(step) then now = i break end
    end
    return steps, now
end

-- What the book says of a quest: its level, the level it asks for, what it wants done.
function P.QuestInfo(id)
    local info = {}
    pcall(function()
        info.level = tonumber(field(id, "questLevel"))
        info.required = tonumber(field(id, "requiredLevel"))
        local text = field(id, "objectivesText")
        if type(text) == "table" then text = table.concat(text, " ") end
        if type(text) == "string" and text ~= "" then info.text = text end
    end)
    return info
end

-- The chain in lines for a card or a tip: handed-in steps grey, the one to do now gold.
function P.ChainLines(id)
    local ok, steps, now = pcall(P.Chain, id)
    if not ok or type(steps) ~= "table" or #steps < 2 then return nil end
    local lines = {}
    for i, step in ipairs(steps) do
        local title = P.Title(step) or ("#" .. step)
        if done(step) then
            lines[i] = "|cff808080" .. i .. ". " .. title .. L" — сдано|r"
        elseif i == now then
            lines[i] = "|cffffd34d" .. i .. ". " .. title .. (active(step) and (L" — в журнале") or (L" — сейчас")) .. "|r"
        else
            lines[i] = "|cffc8c8c8" .. i .. ". " .. title .. "|r"
        end
    end
    return lines, now, #steps
end

local function share(id)
    if active(id) and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(id) then return true end
    local flags = field(id,"questFlags")
    return flags and math.floor(flags/8)%2 == 1
end

function P.Build(d)
    local result = {rows={}, taken=0, finished=0, need=0, later=0, group=0, inside=0}
    local members = {}
    local ids = characterQuests(d)
    for _, id in ipairs(ids) do members[id] = true end
    for _, id in ipairs(ids) do
        if not twin(id, members) and (done(id) or active(id) or availableBranch(id)) then
            local row = {id=id, step=id, share=share(id), inside=startsInside(id,d)}
            row.level = (atlas.Quests[id] or {}).level or field(id,"questLevel") or field(id,"requiredLevel") or 0
            if done(id) then
                row.state, row.note = "done",L"Сдано"
                result.finished = result.finished+1
            elseif active(id) then
                row.state = "active"
                result.taken = result.taken+1
                if C_QuestLog.IsComplete(id) and atlas.EndsInside and atlas.EndsInside(id) then
                    -- Handed in to someone, or to something, inside: no errand outside.
                    local to = P.Where(id, "ends")
                    row.note = L"Сдать внутри" .. (to and (": " .. to) or "")
                    row.handInside = to or true
                elseif C_QuestLog.IsComplete(id) then
                    local to, full, place = P.Where(id, "ends")
                    row.place = place
                    row.note = to and (L"Сдать: " .. to) or (L"Готово к сдаче")
                    row.detail = full and (L"Сдать: " .. full)
                    row.short = to
                    row.turnIn = true
                else
                    row.note = P.Objectives(id) or (L"Цели в подземелье")
                    -- Something of it to do outside, now: say what and where.
                    local work = atlas.QuestWork and atlas.QuestWork(id, d)[1]
                    if work then row.work, row.place = work, work end
                end
            else
                local route = {}
                local step, reason = missing(id, route)
                row.also = route.also
                local q = atlas.Quests[step] or {}
                local level = math.max(q.minLevel or 0, field(step,"requiredLevel") or 0)
                row.step, row.state = step, "missing"
                row.stepActive = step ~= id and active(step) or false
                if level > UnitLevel("player") then
                    row.levelLocked = true
                    row.note = L"С уровня " .. level
                    result.later = result.later+1
                elseif reason then
                    row.note, row.unknown = reason, true
                    result.need = result.need+1
                elseif step ~= id then
                    local title = "«" .. P.Title(step) .. "»"
                    if active(step) and C_QuestLog.IsComplete(step) then
                        local to, full, place = P.Where(step, "ends")
                        row.act, row.place = "turnin", place
                        row.note = L"Сначала сдай " .. title
                        row.detail = row.note .. (full and (": " .. full) or "")
                    elseif active(step) then
                        local what = P.Objectives(step)
                        row.act = "doing"
                        local work = atlas.QuestWork and atlas.QuestWork(step, d)[1]
                        if work then row.work, row.place = work, work end
                        row.note = L"Сначала выполни " .. title
                        row.detail = row.note .. (what and (": " .. what) or "")
                    else
                        local from, full, place = P.Where(step, "starts")
                        row.act, row.place = "take", place
                        row.note = L"Сначала " .. title .. (from and (" — " .. from) or "")
                        row.detail = L"Сначала " .. title .. (full and (L" — взять: " .. full) or "")
                    end
                    -- A follow-up to a quest already picked up for this run can wait until inside.
                    if (members[step] and active(step)) or startsInside(step,d) then
                        row.zone = "inside"
                        result.inside = result.inside+1
                    else
                        result.need = result.need+1
                    end
                elseif row.inside then
                    local from = P.Where(id, "starts")
                    -- A quest that starts from a dropped item is not taken from anyone.
                    local items = (field(id, "startedBy") or {})[3]
                    local itemID = items and items[1]
                    if itemID then
                        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
                        row.note = L"Начинается с предмета, выпадает внутри" .. ((name or from) and (": " .. (name or from)) or "")
                    else
                        row.note = L"Взять внутри" .. (from and (": " .. from) or "")
                    end
                    row.zone = "inside"
                    result.inside = result.inside+1
                else
                    local from, full, place = P.Where(id, "starts")
                    row.act, row.place = "take", place
                    row.note = from and (L"Взять: " .. from) or (L"Нужно взять")
                    row.detail = full and (L"Взять: " .. full)
                    row.short = from
                    if row.share then result.group = result.group+1 else result.need = result.need+1 end
                end
            end
            result.rows[#result.rows+1] = row
        end
    end
    table.sort(result.rows, function(a, b)
        if a.level ~= b.level then
            if a.level <= 0 then return false end
            if b.level <= 0 then return true end
            return a.level < b.level
        end
        return a.id < b.id
    end)
    -- Dalaran gives the sewer key when the final quest is accepted.
    if d.key == "DALARAN" and d.attunement then
        local steps = d.attunement[UnitFactionGroup("player")] or {}
        local final = steps[#steps]
        local count = C_Item and C_Item.GetItemCount or GetItemCount
        if final and not active(final) and not done(final) and not (count and count(d.attunement.item)>0) then
            result.gate = L"Нужна цепочка ключа"
        end
    end
    result.ready = not result.gate and #result.rows > result.later and result.need == 0 and result.finished < #result.rows-result.later
    return result
end

function P.ShowQuest(id)
    if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(id)
    elseif C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id) end
end

local function point(map, x, y)
    if map and map > 0 and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x > 0 or y > 0) then
        return {mapID=map, x=x*100, y=y*100}
    end
end

-- Atlas also knows places used by other quests. Reuse a known giver for
-- prerequisite quests without a catalogue entry of their own.
local function knownGiver(id, finishing)
    local by = field(id, finishing and "finishedBy" or "startedBy") or {}
    for kind, prefix in ipairs({"npc:", "object:"}) do
        for _, sourceID in ipairs(by[kind] or {}) do
            local place = atlas.Places[prefix .. sourceID]
            if place and place.mapID and place.x and place.y then return place end
        end
    end
end

-- "Who — Zone (x, y)" for the giver or the ender of a quest, as the atlas knows it.
function P.Where(id, which)
    local candidates = atlas.QuestPlaces(id, which)
    local place
    for _, p in ipairs(candidates) do
        if p.mapID and p.x and p.y then place = p break end
    end
    place = place or knownGiver(id, which == "ends") or candidates[1]
    if not place then return end
    local name = atlas.PlaceName(place) or place.name
    -- The client names a creature in its own language only once it has it cached.
    if place.npcID and name == place.name and GetLocale and GetLocale() ~= "enUS" then P.namesPending = true end
    -- Short for the row, with coordinates for the tooltip.
    if place.mapID and place.x and place.y then
        local zone = atlas.ZoneName(place.mapID)
        local spot = zone .. (" (%.0f, %.0f)"):format(place.x, place.y)
        return name and (name .. ", " .. zone) or zone, name and (name .. " — " .. spot) or spot, place
    end
    if not name then return end
    return name, name, place
end

-- What the quest asks for: live progress from the log, else the database text.
function P.Objectives(id)
    local lines = {}
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
    for _, objective in ipairs(objectives or {}) do
        local text = objective.text
        if text and text ~= "" and not (issecretvalue and issecretvalue(text)) then
            lines[#lines+1] = objective.finished and ("|cff71c886" .. text .. "|r") or text
        end
    end
    if #lines == 0 then
        local text = field(id, "objectivesText")
        if type(text) == "table" then text = text[1] end
        if type(text) == "string" and text ~= "" then lines[1] = text end
    end
    if #lines > 0 then return table.concat(lines, ", ") end
end

-- What a quest of the run asks for in there, in one line: who gives it, or from whom
-- and out of what its things come. The game's own list names the things; this names
-- where they are, which is what a player in a dungeon for the first time lacks.
local function called(db, id)
    if not (db and db.Get) then return end
    local ok, name = pcall(db.Get, id, "name")
    return ok and type(name) == "string" and name ~= "" and name or nil
end

local function few(names)
    local seen, list = {}, {}
    for _, name in ipairs(names) do
        if not seen[name] then seen[name] = true; list[#list+1] = name end
    end
    if #list > 2 then return list[1] .. ", " .. list[2] .. L" и другие" end
    return #list > 0 and table.concat(list, ", ") or nil
end

local function sources(itemID)
    local names = {}
    if not (ItemDB and ItemDB.Get) then return names end
    local ok, objects = pcall(ItemDB.Get, itemID, "objectDrops")
    for _, id in ipairs(ok and objects or {}) do names[#names+1] = called(ObjectDB, id) end
    local fine, npcs = pcall(ItemDB.Get, itemID, "npcDrops")
    for _, id in ipairs(fine and npcs or {}) do names[#names+1] = called(NpcDB, id) end
    return names
end

function P.InsideHint(row)
    local id = row.step or row.id
    local ok, hint = pcall(function()
        local objectives = field(id, "objectives") or {}
        if active(id) then
            if C_QuestLog.IsComplete(id) then
                if row.handInside then return (L"выполнено, сдать здесь") .. (type(row.handInside) == "string" and (": " .. row.handInside) or "") end
                return (L"выполнено, сдать после выхода")
            end
            local names = {}
            for _, creature in ipairs(objectives[1] or {}) do names[#names+1] = called(NpcDB, creature[1]) end
            for _, object in ipairs(objectives[2] or {}) do names[#names+1] = called(ObjectDB, object[1]) end
            for _, item in ipairs(objectives[3] or {}) do
                for _, name in ipairs(sources(item[1])) do names[#names+1] = name end
            end
            local list = few(names)
            return list and (L"нужны: " .. list)
        end
        local start = field(id, "startedBy") or {}
        if start[3] and start[3][1] then
            local list = few(sources(start[3][1]))
            return (L"начнётся с предмета") .. (list and (L"; падает с: " .. list) or "")
        end
        local giver = start[1] and start[1][1] and called(NpcDB, start[1][1])
        if giver then return (L"взять у: ") .. giver end
        local thing = start[2] and start[2][1] and called(ObjectDB, start[2][1])
        if thing then
            local item = objectives[3] and objectives[3][1] and called(ItemDB, objectives[3][1][1])
            return (L"взять: ") .. thing .. (item and (L"; нужен «" .. item .. "»") or "")
        end
    end)
    return ok and hint or nil
end

-- What a quest in the log still asks for, and where each thing comes from: the creature
-- to kill, the object to use, the item and who or what holds it. The game's own list
-- says which goals are met; the database says the source. The owner killed the last
-- boss for a code and learnt from his group that the blueprints lay in the safe beside.
function P.Needs(id)
    local list = {}
    pcall(function()
        local objectives = field(id, "objectives") or {}
        local live = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id) or {}
        local function wanted(name)
            for _, objective in ipairs(live) do
                local text = objective.text
                if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text:find(name, 1, true) then
                    return not objective.finished
                end
            end
            return true     -- the game does not name it: still wanted, as far as anyone can tell
        end
        for _, creature in ipairs(objectives[1] or {}) do
            local name = called(NpcDB, creature[1])
            if name and wanted(name) then list[#list+1] = {what=name, npc=creature[1]} end
        end
        for _, object in ipairs(objectives[2] or {}) do
            local name = called(ObjectDB, object[1])
            if name and wanted(name) then list[#list+1] = {what=name} end
        end
        for _, item in ipairs(objectives[3] or {}) do
            local name = called(ItemDB, item[1])
            if name and wanted(name) then
                -- Where it comes from is said when that is one place or two; a thing every
                -- other creature of the dungeon drops needs no address.
                local seen, from = {}, {}
                for _, source in ipairs(sources(item[1])) do
                    if not seen[source] then seen[source] = true; from[#from+1] = source end
                end
                local where = #from > 0 and #from <= 2 and table.concat(from, ", ") or nil
                if where and #from == 2 and select(2, where:gsub("[^\128-\191]", "")) > 44 then where = nil end
                if where == name then where = nil end      -- a thing picked up as itself
                list[#list+1] = {what=name, from=where, item=item[1]}
            end
        end
    end)
    return list
end

-- The quest to do next, in a few words, for the short page of a fight: what is left of
-- it, never the whole text of the quest.
function P.ShortHint(d, row)
    local id = row.step or row.id
    if active(id) and not C_QuestLog.IsComplete(id) then
        local needs = P.Needs(id)
        if #needs > 0 then return (L"осталось: ") .. P.NeedText(needs[1]) .. (#needs > 1 and (L" и ещё " .. (#needs - 1)) or "") end
    end
    local hint = P.StepHint(d, row) or ""
    -- By letters, not bytes: a Russian letter is two.
    local letters, cut = 0, nil
    for at in hint:gmatch("()[^\128-\191]") do
        letters = letters + 1
        if letters == 70 then cut = at end
    end
    if not cut then return hint end
    local short = hint:sub(1, cut - 1):gsub("%s+%S*$", "")
    return short .. "..."
end

function P.NeedText(need)
    return need.what .. (need.from and (" (" .. need.from .. ")") or "")
end

-- The one thing worth saying beside a quest of the run on the page inside.
function P.TaskHint(row)
    local ok, hint = pcall(function()
        if row.task == L"взято" then
            -- The boss it is done at says more than a list of things and their holders.
            if row.atBoss then return (L"босс: ") .. row.atBoss end
            local needs = P.Needs(row.step or row.id)
            if #needs == 0 then return end
            return (L"осталось: ") .. P.NeedText(needs[1]) .. (#needs > 1 and (L" и ещё " .. (#needs - 1)) or "")
        end
        if row.task == L"готово" then
            if row.handInside then return (L"сдать здесь") .. (type(row.handInside) == "string" and (": " .. row.handInside) or "") end
            return (L"сдать после выхода")
        elseif row.task == L"не взято" then
            local start = field(row.step or row.id, "startedBy") or {}
            if start[3] and start[3][1] then return (L"начнётся с предмета") end
            local giver = start[1] and start[1][1] and called(NpcDB, start[1][1])
            if giver then return (L"выдаёт ") .. giver end
            -- A thing that gives a quest often asks for another thing first: that is
            -- what the player has to know. Its own name beside a quest named after it says nothing.
            local thing = start[2] and start[2][1] and called(ObjectDB, start[2][1])
            if thing then
                local objectives = field(row.step or row.id, "objectives") or {}
                local item = objectives[3] and objectives[3][1] and called(ItemDB, objectives[3][1][1])
                local title = P.Title(row.step or row.id) or ""
                local named = title:find(thing, 1, true) ~= nil
                if item then return (named and "" or (thing .. ", ")) .. L"нужен «" .. item .. "»" end
                if not named then return thing end
            end
        end
    end)
    return ok and hint or nil
end

-- How a quest of the inside begins, said before the run: who gives it, what it asks
-- for first, or that a thing found there starts it.
function P.InsideSource(row)
    local was = row.task
    row.task = L"не взято"
    local hint = P.TaskHint(row)
    row.task = was
    return hint
end

local function activeObjective(id)
    if C_QuestLog.GetNextWaypoint then
        local spot = point(C_QuestLog.GetNextWaypoint(id))
        if spot then return spot end
    end
    -- Blood in the Streets: the sewer approach is the actual exploration trigger.
    if id == 92434 then return {mapID=1421, x=68.3, y=45.5} end
    if C_QuestLog.GetQuestsOnMap then
        local maps = {GetQuestUiMapID and GetQuestUiMapID(id, true) or 0,
            C_Map and C_Map.GetBestMapForUnit("player") or 0}
        for _, map in ipairs(maps) do
            if map > 0 then
                for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
                    if poi.questID == id then
                        local spot = point(map, poi.x, poi.y)
                        if spot then return spot end
                    end
                end
            end
        end
    end
end

local dalaranSteps = {
    [96986] = {order=1, boss=1, hint=L"Клоака • победи Атрексиса"},
    [96987] = {order=2, hint=L"Поднимись в город. Святилище Альянса, за ним зал порталов, дальняя стена библиотеки."},
    [96988] = {order=3, hint=L"Собери шесть треснувших сердечников с часовых."},
    [96984] = {order=4, boss=8, hint=L"Верхний этаж • тень верховного мага"},
}

function P.InDungeon(d)
    local _, kind, _, _, _, _, _, instance = GetInstanceInfo()
    if not (d and (kind == "party" or kind == "raid")) then return false end
    -- One of Forever's own, whose number is learned by its name the first time in: asked
    -- here too, or inside Alcaz Prison the arrow went to the entrance (the run over every
    -- quest, 17.11.2026).
    if not d.instanceID and atlas.CurrentDungeon then atlas.CurrentDungeon() end
    return d.instanceID ~= nil and instance == d.instanceID
end

-- Reuse the atlas staircase as an intermediate landmark, not as the book's coordinates.
local function markLibraryApproach(d)
    if not (atlas.MapQuests and atlas.MapMarks and atlas.MapMarks[d.key]) then return end
    if atlas.QuestSpotFloor(d,96987,"explore") or atlas.QuestSpotFloor(d,96987,"loot") then return end
    for floor, marks in ipairs(atlas.MapMarks[d.key]) do
        for _, mark in ipairs(marks) do
            if mark[1] == "up" and mark[4] == 2 then
                local floors = atlas.MapQuests[d.key] or {}
                atlas.MapQuests[d.key] = floors
                floors[floor] = floors[floor] or {}
                table.insert(floors[floor], {mark[2], mark[3], L"Подъём к библиотеке", {96987,"explore"}})
                return
            end
        end
    end
end

-- Where this faction walks in: the goblin transporter for some, the portal for the rest.
local function door(d)
    return P.Door and P.Door(d) or atlas.Entrance(d)
end

function P.StepHint(d,row)
    if active(row.step) and not C_QuestLog.IsComplete(row.step) then
        local step = d.key == "DALARAN" and dalaranSteps[row.step]
        if step then return step.hint end
        local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(row.step)
        for _, objective in ipairs(objectives or {}) do
            if not objective.finished and objective.text then return objective.text end
        end
    end
    return row.note
end

-- quiet: set the point and the arrow, but open neither the world map nor the quest log.
function P.Route(d,row, automatic, quiet)
    local id = row.step
    if done(row.id) then return (L"Это задание уже сдано.") end
    if row.unknown then return row.note .. " • " .. P.Title(row.id) end
    local title = P.Title(id)
    local finishing = active(id) and C_QuestLog.IsComplete(id)
    local place, label, kind
    if active(id) and not finishing then
        -- Inside, a goal that lies out there (the Tablet of Ryun'eh in the tunnels before the
        -- Uldaman portal) is said, not pointed at: the owner, 17.11.2026, inside: "it keeps
        -- leading the arrows to the entrance, I do not understand anything."
        if row.work and row.work.mapID and P.InDungeon(d) then
            if automatic then return end
            local what = row.work.name or title
            return (row.work.cave and (L"Это снаружи, в пещере перед порталом: ") or (L"Это снаружи: "))
                .. what .. L". Сделай на выходе.", "outside"
        end
        -- Inside, a goal whose place in here is known: the floor with its spot, and where in
        -- words (P.InsideSpots, BossRoute.lua).
        if P.InDungeon(d) and not dalaranSteps[id] and P.InsideSpots and P.InsideSpots[id] then
            local where = P.WhereInside and P.WhereInside(row)
            local shown = not automatic and P.ShowGoal and P.ShowGoal(d, id)
            if where or shown then return (where or title), "floor" end
        end
        -- The place where its open goal is done, when the database knows one outside.
        place = row.work and row.work.mapID and row.work or activeObjective(id)
        label, kind = row.work and row.work.name or title, "objective"
        if not place then
            local inside = P.InDungeon(d)
            local step = inside and d.key == "DALARAN" and dalaranSteps[id]
            if step and id == 96987 and atlas.QuestSpotFloor then markLibraryApproach(d) end
            for _, act in ipairs({"loot", "use", "explore"}) do
                if atlas.QuestSpotFloor and atlas.QuestSpotFloor(d,id,act) then
                    if inside then
                        if not automatic then atlas.ShowQuestOnDungeonMap(d,id,act) end
                        return step and step.hint or (L"Цель на плане этажа • " .. title), "floor"
                    end
                    place, label, kind = door(d), L"Вход • " .. title, "entrance"
                    break
                end
            end
            if not place and step and step.boss and atlas.BossFloor and atlas.BossFloor(d,step.boss) then
                if not automatic then atlas.ShowDungeonMap(d,step.boss) end
                return step.hint, "floor"
            end
        end
        -- A quest of this dungeon with its goals inside: the way leads to the door.
        if not place and not automatic and row.id == id and not P.InDungeon(d) and door(d) then
            place, label, kind = door(d), P.DoorLabel and P.DoorLabel(d) or (L"Вход • " .. atlas.DungeonName(d)), "entrance"
        end
        if not place then
            if not automatic and not quiet then P.ShowQuest(id) end
            return P.StepHint(d,row) or title, "journal"
        end
    else
        local which = finishing and "ends" or "starts"
        local candidates = atlas.QuestPlaces(id,which)
        for _, p in ipairs(candidates) do
            if p.mapID and p.x and p.y then place = p break end
        end
        place = place or knownGiver(id, finishing) or candidates[1]
        label = place and atlas.PlaceName(place) or title
        kind = finishing and "end" or "start"
        local home = sourceDungeon[id] and atlas.DungeonByKey[sourceDungeon[id]] or d
        local indoors = (not finishing and startsInside(id,home)) or (place and place.inside)
        if indoors and not (place and place.mapID and place.x and place.y) then
            local bossIndex,bossName
            if not finishing then bossIndex,bossName=dropLocation(home,id) end
            if bossName then label=L"Добыча с босса: " .. bossName end
            local _,_,_,_,_,_,_,instanceID = GetInstanceInfo()
            if instanceID and instanceID == home.instanceID then
                if automatic then
                    if atlas.QuestSpotFloor and atlas.QuestSpotFloor(home,id,kind) then
                        return (L"Место на плане этажа • ") .. label, "floor"
                    end
                    if bossIndex and atlas.BossFloor(home,bossIndex) then return label, "floor" end
                    return
                end
                if atlas.ShowQuestOnDungeonMap and atlas.ShowQuestOnDungeonMap(home,id,kind) then
                    return (L"Место на плане: ") .. label
                end
                if bossIndex and atlas.BossFloor(home,bossIndex) then
                    atlas.ShowDungeonMap(home,bossIndex)
                    return label
                end
                return (L"Ты уже внутри. ") .. label .. L" — точка на этаже неизвестна."
            end
            if automatic then return end
            place = door(home)
            label,kind = P.DoorLabel and P.DoorLabel(home) or (L"Вход • " .. atlas.DungeonName(home)),"entrance"
        end
    end
    if not (place and place.mapID and place.x and place.y) then
        return title .. " — " .. label .. L". Точных координат в базе нет."
    end
    -- A step asked for by hand is led across the sea as well; an automatic one is only marked.
    local hop
    if automatic or not P.Mark then atlas.AddMarker(place,label,kind or "start",id)
    else hop = P.Mark(place,label,kind or "start",id) end
    if not automatic and not quiet then atlas.OpenMapAt(place.mapID) end
    local where = label .. " — " .. atlas.ZoneName(place.mapID) .. (" (%.1f, %.1f)"):format(place.x,place.y)
    if hop then
        where = where .. (P.Overseas(place) and (L". Другой континент, ближайший путь: ") or hop.onFoot and (L". По прямой не пройти, идти так: ") or (L". Быстрее так: ")) .. hop.text
            .. (hop.point and (L". Стрелка ведёт туда.") or hop.spell and (L". Нажми иконку телепорта на месте стрелки.") or ".")
    end
    return where, true, place
end

-- Rank the work left for this particular run. Turn-ins outside can wait while inside.
function P.NextSteps(d, rows, turnedIn, goal)
    local inside = P.InDungeon(d)
    local candidates = {}
    for _, row in ipairs(rows) do
        if row.state ~= "done" and row.step ~= turnedIn and row.id ~= turnedIn
            and not row.levelLocked and not row.unknown then
            local rank
            if active(row.step) then
                if C_QuestLog.IsComplete(row.step) then
                    rank = inside and 4 or 0
                elseif inside and row.id == row.step then
                    rank = 1
                else
                    rank = 3
                end
            elseif startsInside(row.step,d) == (inside or false) then
                rank = inside and 0 or 1
            else
                rank = inside and 5 or 2
            end
            if row.id == goal and not inside then rank = 0 end
            local step = inside and d.key == "DALARAN" and dalaranSteps[row.step]
            candidates[#candidates+1] = {row=row, rank=rank, order=step and step.order or 0}
        end
    end
    table.sort(candidates, function(a,b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.order ~= b.order then return a.order < b.order end
        if a.row.level ~= b.row.level then return a.row.level < b.row.level end
        return a.row.id < b.row.id
    end)
    return candidates
end

function P.TrackStep(row)
    if active(row.step) and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(row.step)
    end
end

function P.NextPickup(d, rows, turnedIn, goal, showFloor)
    for _, c in ipairs(P.NextSteps(d,rows,turnedIn,goal)) do
        local label, marked = P.Route(d,c.row,true)
        if marked then
            P.TrackStep(c.row)
            if showFloor and (marked == "floor" or marked == "journal") then P.Route(d,c.row) end
            return (L"Следующее задание • ") .. P.Title(c.row.step) .. " — " .. label
        end
    end
end

-- ------------------------------------------
-- Quests taken and handed in by themselves; the junk in the log
-- ------------------------------------------
-- The owner: "I want quests to be accepted and handed in by themselves. And I need a
-- button that deletes the junk quests: low for my level, not begun, simply picked up some
-- time ago; not chains, not lines of quests, plain junk."
--
-- Whether a quest is grey for the character: nothing to gain from it.
local function trivial(id, level)
    if C_QuestLog and C_QuestLog.IsQuestTrivial then
        local ok, yes = pcall(C_QuestLog.IsQuestTrivial, id)
        if ok and type(yes) == "boolean" then return yes end
    end
    local junk = P.JunkData and P.JunkData[id]
    level = level and level > 0 and level or tonumber(QuestDB and QuestDB.Get and field(id, "questLevel")) or (junk and math.floor(junk / 10))
    local mine = UnitLevel and UnitLevel("player")
    if not (level and level > 0 and mine) then return false end
    -- The grey line of the old world: five levels and a tenth below up to forty, a fifth after.
    local line
    if mine <= 5 then line = 0
    elseif mine <= 39 then line = mine - math.floor(mine / 10) - 5
    elseif mine <= 59 then line = mine - math.floor(mine / 5) - 1
    else line = mine - 9 end
    return level <= line
end

-- The quests others are built on: a quest some other quest asks for first is a link of
-- a chain even when nothing stands before it. Counted once in a sitting.
local askedFor
local function neededByOthers(id)
    if not askedFor then
        askedFor = {}
        local ok, ids = pcall(QuestDB.GetAllIds)
        for _, other in ipairs(ok and ids or {}) do
            for _, name in ipairs({"preQuestSingle", "preQuestGroup"}) do
                local list = field(other, name)
                if type(list) == "table" then
                    for _, before in ipairs(list) do askedFor[before] = true end
                end
            end
        end
    end
    return askedFor[id] == true
end

local dungeonOnes
local function ofDungeon(id)
    if not dungeonOnes then
        dungeonOnes = {}
        for _, d in ipairs(atlas.Dungeons or {}) do
            for _, quest in ipairs(d.quests or {}) do dungeonOnes[quest] = true end
        end
    end
    return dungeonOnes[id] == true
end

local function filled(list)
    return type(list) == "table" and next(list) ~= nil
end

-- Why a quest of the log is kept; nil when it is junk. Junk is all of: known to the
-- database, grey, not begun (no goal counted, not ready to hand in), standing alone (nothing
-- before it, nothing after it, nothing built on it), not a quest of a dungeon, not a quest
-- of the character's class or craft.
function P.JunkWhy(id, level)
    -- A quest of a dungeon or of one of its chains is in the addon's own data in full; any
    -- other quest of the database only by its level and its kind (P.JunkData).
    local known = QuestDB and QuestDB.Get and field(id, "name")
    local junk = not known and P.JunkData and P.JunkData[id]
    if not known and not junk then return (L"нет в базе") end
    if not trivial(id, level) then return (L"не серое") end
    if C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then return (L"готово к сдаче") end
    local goals = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
    for _, goal in ipairs(type(goals) == "table" and goals or {}) do
        if goal.finished or (tonumber(goal.numFulfilled) or 0) > 0 then return (L"начато") end
        -- Where the client gives no numbers, the text "3/10" is read.
        local have = type(goal.text) == "string" and tonumber(goal.text:match("(%d+)%s*/%s*%d+"))
        if have and have > 0 then return (L"начато") end
    end
    if junk then
        local kind = junk % 10
        if kind == 1 then return (L"цепочка") end
        if kind == 3 then return (L"классовое или профессии") end
        return nil
    end
    if filled(field(id, "preQuestSingle")) or filled(field(id, "preQuestGroup")) then return (L"цепочка") end
    local nextOne = field(id, "nextQuestInChain")
    if type(nextOne) == "number" and nextOne > 0 then return (L"цепочка") end
    if neededByOthers(id) then return (L"цепочка") end
    local parent = field(id, "parentQuest")
    if (type(parent) == "number" and parent > 0) or filled(field(id, "childQuests")) then return (L"цепочка") end
    if ofDungeon(id) then return (L"задание подземелья") end
    local class, skill = field(id, "requiredClasses"), field(id, "requiredSkill")
    if (type(class) == "number" and class > 0) or filled(skill) then return (L"классовое или профессии") end
    return nil
end

-- The junk of the log: {id, title, level}, the lowest first.
function P.JunkQuests()
    local list = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and QuestDB and QuestDB.Get) then return list end
    local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
    for i = 1, ok and tonumber(count) or 0 do
        local okInfo, info = pcall(C_QuestLog.GetInfo, i)
        local id = okInfo and type(info) == "table" and not info.isHeader and info.questID
        if type(id) == "number" and id > 0 then
            local okWhy, why = pcall(P.JunkWhy, id, tonumber(info.level))
            if okWhy and why == nil then
                local level = tonumber(info.level)
                if not level or level <= 0 then level = tonumber(field(id, "questLevel")) or 0 end
                -- The quest log's own title first: the addon's data knows only the quests of dungeons by name.
                local title = (type(info.title) == "string" and info.title ~= "" and info.title) or P.Title(id) or ("#" .. id)
                list[#list+1] = {id=id, title=title, level=level}
            end
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.id < b.id
    end)
    return list
end

-- How many, without counting at every drawing of the page.
local junkCount
function P.JunkChanged() junkCount = nil end
function P.JunkCount()
    if junkCount == nil then
        local ok, list = pcall(P.JunkQuests)
        junkCount = ok and #list or 0
    end
    return junkCount
end

-- Abandon the quests given, as the button of the quest log does. Returns how many the
-- game let go at once (the log answers a moment later; P.StillInLog tells what stayed).
function P.AbandonQuests(list)
    if #list > 0 then if P.Track then P.Track("JunkRemoved") end end
    local sent = 0
    for _, quest in ipairs(list) do
        local ok = pcall(function()
            if C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
                C_QuestLog.SetSelectedQuest(quest.id)
                C_QuestLog.SetAbandonQuest()
                C_QuestLog.AbandonQuest()
            elseif SelectQuestLogEntry and SetAbandonQuest and AbandonQuest and GetQuestLogIndexByID then
                SelectQuestLogEntry(GetQuestLogIndexByID(quest.id))
                SetAbandonQuest()
                AbandonQuest()
            else
                error("no way to abandon")
            end
        end)
        if ok then sent = sent + 1 end
    end
    P.JunkChanged()
    return sent
end
function P.StillInLog(list)
    local left = {}
    for _, quest in ipairs(list) do
        if active(quest.id) then left[#left+1] = quest end
    end
    return left
end

-- Taken and handed in by themselves, as the hands would do it: at a quest offered,
-- accept; at a quest asked about with everything brought, go on; at the reward, take it
-- when there is nothing to choose. Left to the player: a grey quest (it would be junk in
-- the log tomorrow), a quest that can be done over and over (it may take things away each
-- time), a choice between rewards, and everything while Shift is held. /dq auto turns it
-- off and on.
local function inLog(id)
    return type(id) == "number" and id > 0 and active(id) and true or false
end
-- The owner: "in a chain, at handing in the next quest opens at once, and I have to click
-- it by hand." The next link is often grey for the game. A quest the same giver offers
-- right after a hand-in is the next link of what the player is doing, grey or not.
local handedIn
local function giverNow()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "npc")
    if not (ok and guid) then ok, guid = pcall(UnitGUID, "questnpc") end
    return ok and type(guid) == "string" and guid or nil
end
function P.HandedIn()
    handedIn = {at=GetTime and GetTime() or 0, giver=giverNow()}
end
local function nextLink()
    if not handedIn then return false end
    local now = GetTime and GetTime() or 0
    if now - handedIn.at > 10 then return false end
    local giver = giverNow()
    return not (giver and handedIn.giver and giver ~= handedIn.giver)
end
function P.QuestHands(event)
    local db = P.char
    if not db or db.noAuto then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if event == "QUEST_DETAIL" then
        local id = GetQuestID and GetQuestID()
        local grey = type(id) == "number" and id > 0 and trivial(id)
        local link = grey and nextLink()
        if grey and not link then return "grey" end
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            -- Given already by the game itself: the window is only to be closed.
            if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
        elseif AcceptQuest then
            AcceptQuest()
        end
        if P.Track then P.Track("AutoAccepted") end
        return link and "accept chain" or "accept"
    elseif event == "QUEST_PROGRESS" then
        local id = GetQuestID and GetQuestID()
        if inLog(id) and IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
            CompleteQuest()
            if P.Track then P.Track("AutoTurnedIn") end
            return "complete"
        end
    elseif event == "QUEST_COMPLETE" then
        -- At the reward the things asked for are brought and the hand-in is under way (by
        -- these hands or by the player's own click): it is finished whatever the quest,
        -- unless there is a choice to make.
        local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
        if choices <= 1 and GetQuestReward then
            GetQuestReward(choices)
            P.HandedIn()
            return "reward"
        end
        return choices > 1 and "choose" or nil
    elseif event == "GOSSIP_SHOW" then
        if not C_GossipInfo then return end
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
            if quest.isComplete and inLog(quest.questID) and C_GossipInfo.SelectActiveQuest then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return "pick"
            end
        end
        local offered = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}
        local lone = #offered == 1 and nextLink()
        for _, quest in ipairs(offered) do
            if not quest.repeatable and (lone or (not quest.isTrivial and not trivial(quest.questID, quest.questLevel))) and C_GossipInfo.SelectAvailableQuest then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return "pick"
            end
        end
    elseif event == "QUEST_GREETING" then
        for i = 1, GetNumActiveQuests and GetNumActiveQuests() or 0 do
            local _, ready = GetActiveTitle(i)
            if ready and SelectActiveQuest then
                SelectActiveQuest(i)
                return "pick"
            end
        end
        local count = GetNumAvailableQuests and GetNumAvailableQuests() or 0
        local lone = count == 1 and nextLink()
        for i = 1, count do
            local grey = not lone and IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
            local again = false
            if GetAvailableQuestInfo then
                local ok, isTrivial, _, repeatable = pcall(GetAvailableQuestInfo, i)
                if ok then grey, again = grey or (isTrivial and not lone), repeatable end
            end
            if not grey and not again and SelectAvailableQuest then
                SelectAvailableQuest(i)
                return "pick"
            end
        end
    end
end

-- The owner: "the quest is not clicked through to the end at handing in and at taking."
-- Which click was missed cannot be seen from outside the game, so: every step the hands
-- take is written down (db.handsLog, the last forty: the time, the window, the quest, what
-- was done or why not, an error if there was one), to be read afterwards. And a step is
-- taken again half a second later if its window still stands: a click sent the very
-- moment a window opens is sometimes lost.
local function stillUp(panel)
    local frame = _G[panel]
    return QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown() and frame and frame.IsShown and frame:IsShown()
end
local function note(event, did, err)
    local db = P.char
    if not db then return end
    db.handsLog = type(db.handsLog) == "table" and db.handsLog or {}
    local id = GetQuestID and GetQuestID() or "?"
    local clock = date and date("%H:%M:%S") or ""
    table.insert(db.handsLog, clock .. " " .. event .. " id=" .. tostring(id) .. " -> " .. tostring(did or (L"ничего")) .. (err and (L" ОШИБКА " .. tostring(err)) or ""))
    while #db.handsLog > 40 do table.remove(db.handsLog, 1) end
end
function P.QuestHandsEvent(event)
    -- What the quest gives is read first, while its window is open (Book.lua).
    if P.KeepReward then pcall(P.KeepReward, event) end
    local ok, did = pcall(P.QuestHands, event)
    note(event, ok and did or nil, not ok and did or nil)
    if not ok or not (C_Timer and C_Timer.After) then return end
    local again = ((did == "accept" or did == "accept chain") and "QuestFrameDetailPanel") or (did == "complete" and "QuestFrameProgressPanel") or (did == "reward" and "QuestFrameRewardPanel")
    if not again then return end
    C_Timer.After(.5, function()
        if not stillUp(again) then return end
        local okAgain, didAgain = pcall(P.QuestHands, event)
        note(event .. L" (повтор)", okAgain and didAgain or nil, not okAgain and didAgain or nil)
    end)
end

if CreateFrame and UIParent then
    local hands = CreateFrame("Frame", "DungeonQuestForeverHands", UIParent)
    for _, event in ipairs({"QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_TURNED_IN"}) do
        pcall(hands.RegisterEvent, hands, event)
    end
    hands:SetScript("OnEvent", function(_, event)
        -- Handed in by the player's own click too (a reward chosen): the next link follows.
        if event == "QUEST_TURNED_IN" then P.HandedIn() return end
        P.QuestHandsEvent(event)
    end)
end
