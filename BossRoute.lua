local _, P = ...
local L = P.L or function(s) return s end
local atlas = P.Core

function P.BossChoices(d)
    local choices = {}
    for index, boss in ipairs(d and atlas.Bosses and atlas.Bosses[d.key] or {}) do
        if (not boss.kind or boss.kind == "rare") and (not boss.faction or boss.faction == UnitFactionGroup("player")) then
            choices[#choices+1] = {boss=boss, index=index, dungeon=d}
        end
    end
    return choices
end

local positions = {L"север", L"северо-восток", L"восток", L"юго-восток", L"юг", L"юго-запад", L"запад", L"северо-запад"}
local atan2 = math.atan2 or math.atan
-- All atlas floor plans use the same 1002 x 668 drawing area.
local MAP_W, MAP_H = 1002, 668
local floorNames = {DALARAN = {L"Клоака", L"Город"}}

function P.FloorLabel(d, floor)
    local names = floorNames[d.key]
    return names and names[floor] or (L"Этаж " .. floor)
end

local function floorTo(d, floor)
    local names = floorNames[d.key]
    return names and names[floor] and (L"в " .. names[floor]) or (L"на этаж " .. floor)
end

-- Compass sector from one drawn point of a plan to another. nil when they coincide.
local function direction(from, to)
    local dx, dy = (to.x-from.x)*MAP_W, (to.y-from.y)*MAP_H
    if dx*dx + dy*dy <= 144 then return end
    return positions[math.floor(atan2(dx,-dy)/(math.pi/4) + .5) % 8 + 1]
end

local function marks(d, floor)
    local all = (atlas.MapMarks or {})[d.key]
    return all and all[floor] or {}
end

local passage = {up=true, down=true, floor=true}

local function passageTo(d, floor, to)
    for _, mark in ipairs(marks(d, floor)) do
        if passage[mark[1]] and mark[4] == to then return mark end
    end
end

-- Floors the drawn passages lead through, from the entrance floor to the target floor.
local function floorPath(d, from, to)
    local via, queue, head = {[from]=false}, {from}, 1
    while queue[head] do
        local floor = queue[head]
        head = head + 1
        if floor == to then
            local path = {}
            while floor do
                table.insert(path, 1, floor)
                floor = via[floor] or nil
            end
            return path
        end
        for _, mark in ipairs(marks(d, floor)) do
            if passage[mark[1]] and via[mark[4]] == nil then
                via[mark[4]] = floor
                queue[#queue+1] = mark[4]
            end
        end
    end
end

local origins = {entrance=L"от входа", up=L"от подъёма", down=L"от спуска", floor=L"от перехода", kill=L"от прошлого босса"}
local capital = {[L"от входа"]=L"От входа", [L"от подъёма"]=L"От подъёма", [L"от спуска"]=L"От спуска", [L"от перехода"]=L"От перехода",
    [L"от прошлого босса"]=L"От прошлого босса"}
local goals = {up=L"подъём", down=L"спуск", floor=L"переход"}
local goalsTo = {up=L"подъёма", down=L"спуска", floor=L"перехода"}

-- The way to a boss as legs, one per floor. Each leg starts at a landmark drawn on the
-- atlas plan (the entrance, or the stairs you just took) and names the compass sector of
-- the next landmark. Nothing is traced through walls: only the two points are known.
function P.BossLegs(choice)
    local d = choice.dungeon
    local floors = (atlas.Maps or {})[d.key] or {}
    local legs = {}
    choice.legs = legs
    choice.floor, choice.mapID, choice.x, choice.y = nil, nil, nil, nil
    for floor, plan in ipairs(floors) do
        for _, pin in ipairs(plan.pins) do
            if pin[1] == choice.index then choice.floor, choice.mapID, choice.x, choice.y = floor, plan.id, pin[2], pin[3] end
        end
    end
    if not choice.floor then return legs end
    local start, origin = 1, nil
    -- The spot of the last boss fight is where the player stands: the best start there is.
    if choice.from and choice.from ~= choice.index then
        for floor, plan in ipairs(floors) do
            for _, pin in ipairs(plan.pins) do
                if pin[1] == choice.from then start, origin = floor, {x=pin[2], y=pin[3], name=origins.kill} end
            end
        end
    end
    for floor = 1, #floors do
        if origin then break end
        for _, mark in ipairs(marks(d, floor)) do
            if mark[1] == "entrance" then start, origin = floor, {x=mark[2], y=mark[3], name=origins.entrance} end
        end
    end
    local path = floorPath(d, start, choice.floor)
    if not path then
        -- No drawn passage from the entrance: start from the way back to the floor below.
        path = {choice.floor}
        local back = passageTo(d, choice.floor, choice.floor-1)
        origin = back and {x=back[2], y=back[3], name=origins[back[1]]} or nil
    end
    for i, floor in ipairs(path) do
        local nextFloor = path[i+1]
        local leg = {floor=floor, label=P.FloorLabel(d, floor), origin=origin and origin.name, many=#floors > 1}
        if nextFloor then
            local mark = passageTo(d, floor, nextFloor)
            leg.kind, leg.to = mark[1], nextFloor
            leg.goal = goals[mark[1]] .. " " .. floorTo(d, nextFloor)
            leg.goalTo = goalsTo[mark[1]] .. " " .. floorTo(d, nextFloor)
            leg.dir = origin and direction(origin, {x=mark[2], y=mark[3]})
            local back = passageTo(d, nextFloor, floor)
            origin = back and {x=back[2], y=back[3], name=origins[back[1]]} or nil
        else
            leg.kind, leg.goal, leg.goalTo = "boss", L"босс", L"босса"
            leg.dir = origin and direction(origin, choice)
        end
        legs[#legs+1] = leg
    end
    return legs
end

function P.LegText(leg)
    local text
    if leg.dir then
        text = (leg.many and leg.origin or capital[leg.origin]) .. L" на " .. leg.dir .. L" до " .. leg.goalTo
    elseif leg.kind == "boss" then
        text = leg.many and (L"босс отмечен на плане") or (L"Босс отмечен на плане")
    else
        text = leg.goal .. L" отмечен на плане"
    end
    return leg.many and (leg.label .. ": " .. text) or text
end

function P.BossDestination(choice)
    local legs = P.BossLegs(choice)
    if #legs == 0 then return (L"Место на плане пока неизвестно") end
    local parts = {}
    for i, leg in ipairs(legs) do parts[i] = P.LegText(leg) end
    return table.concat(parts, " • ")
end

function P.OpenBoss(choice)
    if choice.floor then atlas.ShowDungeonMap(choice.dungeon, choice.index)
    else atlas.ShowBoss(choice.dungeon, choice.index) end
end

-- ------------------------------------------
-- Which leg the player is on
-- ------------------------------------------
-- Inside an instance the client gives no player position and no facing. What it does
-- give: the subzone name, and the nameplates of creatures in sight. A boss in sight pins
-- the floor; a subzone seen together with such a boss is remembered per character, so
-- the next run knows the floor from the subzone alone. A click on the row moves to the
-- next leg by hand.
local manual, seen

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function subzone()
    local zone = plain(GetSubZoneText and GetSubZoneText())
    if not zone or zone == "" then zone = plain(GetMinimapZoneText and GetMinimapZoneText()) end
    if zone and zone ~= "" then return zone end
end

local function zoneFloor(d, zone)
    if not zone then return end
    local learned = P.char and P.char.zones and P.char.zones[d.key]
    local floor = learned and learned[zone]
    if floor and floor > 0 then return floor end
    if d.key == "DALARAN" and (zone:find(L"Клоак", 1, true) or zone:find("Underbelly", 1, true)) then return 1 end
end

-- Remember what the client reports as the subzone, with the floor when it is known.
function P.NoteZone(d, floor)
    local zone = subzone()
    if not zone or not P.char then return end
    P.char.zones = P.char.zones or {}
    local zones = P.char.zones[d.key] or {}
    P.char.zones[d.key] = zones
    if floor then zones[zone] = floor elseif not zones[zone] then zones[zone] = 0 end
end

-- A boss of this floor is in sight.
function P.FloorEvidence(d, floor)
    local changed = not seen or seen.dungeon ~= d or seen.floor ~= floor
    seen = {dungeon=d, floor=floor, time=GetTime()}
    P.NoteZone(d, floor)
    if changed and P.Redraw then P.Redraw() end
end

-- The boss killed last in this run, by its index in the atlas list. The order of kills is
-- known only for those seen happening, so a run joined midway starts from the entrance.
function P.LastKill(d)
    if not P.char or not atlas.IsBossKilled then return end
    local memo = P.char.kills
    local fresh = not memo or memo.key ~= d.key
    if fresh then
        memo = {key=d.key, names={}}
        P.char.kills = memo
    end
    local list = atlas.Bosses and atlas.Bosses[d.key] or {}
    for index, boss in ipairs(list) do
        if atlas.IsBossKilled(d, boss) then
            if not memo.names[boss.name] then
                memo.names[boss.name] = true
                if not fresh then memo.last = index end
            end
        else
            memo.names[boss.name] = nil
            if memo.last == index then memo.last = nil end
        end
    end
    return memo.last
end

-- The next boss of the run: the first one in the atlas order still alive. Rare ones may
-- not be there at all and are left to a choice by hand.
function P.NextBoss(d)
    if not atlas.IsBossKilled then return end
    for _, choice in ipairs(P.BossChoices(d)) do
        if not choice.boss.kind and not atlas.IsBossKilled(d, choice.boss) then return choice end
    end
end

function P.BossLeg(choice)
    local legs = choice.legs or P.BossLegs(choice)
    local n = #legs
    if n == 0 then return nil, 0, 0 end
    local d = choice.dungeon
    local zone = subzone()
    local known = zoneFloor(d, zone)
    if manual and manual.boss == choice.boss and legs[manual.leg] and (not seen or seen.time <= manual.time)
        and (not known or zone == manual.zone or known == legs[manual.leg].floor) then
        return legs[manual.leg], manual.leg, n
    end
    local floor = known or (seen and seen.dungeon == d and seen.floor)
    local index = 1
    if floor then
        for i, leg in ipairs(legs) do if leg.floor == floor then index = i end end
    end
    return legs[index], index, n
end

function P.AdvanceBossLeg(choice)
    local _, index, n = P.BossLeg(choice)
    if n < 2 then return false end
    manual = {boss=choice.boss, leg=index % n + 1, time=GetTime(), zone=subzone()}
    return true
end

function P.ResetBossLeg()
    manual, seen = nil, nil
end

-- ------------------------------------------
-- Which wing of a shared instance
-- ------------------------------------------
-- The Scarlet Monastery wings are one instance for the client. What tells them apart:
-- the subzone name, a boss met face to face, and a boss the atlas has just crossed out.
-- A subzone seen together with such a boss is remembered per character.
local wingSeeds = {
    SM_LIB = {L"Двор охотника", L"Сокровищница", L"Читальня", "Huntsman's Cloister", "Gallery of Treasures", "Athenaeum"},
    SM_GY = {"Chamber of Atonement", "Forlorn Cloister", "Honor's Tomb"},
    SM_ARM = {"Training Grounds", "Footman's Armory", "Crusader's Armory", "Hall of Champions"},
    SM_CATH = {"Chapel Gardens", "Crusader's Chapel"},
}
local seedWing = {}
for key, names in pairs(wingSeeds) do
    for _, name in ipairs(names) do seedWing[name] = key end
end

local shared, wingSeen
local killCount = {}

local function siblings(instance)
    if not shared then
        shared = {}
        for _, d in ipairs(atlas.Dungeons) do
            if d.instanceID then
                shared[d.instanceID] = shared[d.instanceID] or {}
                table.insert(shared[d.instanceID], d)
            end
        end
    end
    return instance and shared[instance] or {}
end

-- The subzone, unless the client only repeats the name of the whole instance.
local function wingZone()
    local zone = subzone()
    if not zone then return end
    if zone == plain(GetRealZoneText and GetRealZoneText()) or zone == plain(GetZoneText and GetZoneText()) then return end
    return zone
end

local function noteWing(d)
    local changed = not wingSeen or wingSeen.key ~= d.key
    wingSeen = {instance=d.instanceID, key=d.key}
    local zone = wingZone()
    if zone and P.char then
        P.char.wings = P.char.wings or {}
        local known = P.char.wings[d.instanceID] or {}
        P.char.wings[d.instanceID] = known
        known[zone] = d.key
    end
    return changed
end

local function killed(d)
    local n = 0
    for _, boss in ipairs(atlas.Bosses and atlas.Bosses[d.key] or {}) do
        if atlas.IsBossKilled and atlas.IsBossKilled(d, boss) then n = n + 1 end
    end
    return n
end

-- The wing the player is in, given any dungeon of the current instance.
function P.Wing(d)
    local list = siblings(d.instanceID)
    if #list < 2 then return d end
    for _, other in ipairs(list) do
        local n = killed(other)
        if killCount[other.key] and n > killCount[other.key] then
            noteWing(other)
            P.Probe("kill:" .. other.key .. ":" .. n)
        end
        killCount[other.key] = n
    end
    local zone = wingZone()
    local known = P.char and P.char.wings and P.char.wings[d.instanceID]
    local key = zone and ((known and known[zone]) or seedWing[zone])
    if not key and wingSeen and wingSeen.instance == d.instanceID then key = wingSeen.key end
    return key and atlas.DungeonByKey[key] or d
end

function P.ForgetWing()
    wingSeen = nil
end

-- A creature under the cursor, in the target frame or behind a nameplate.
function P.SeenUnit(unit)
    local _, kind, _, _, _, _, _, instance = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    local list = siblings(instance)
    if #list < 2 or not unit or (issecretvalue and issecretvalue(unit)) then return end
    local id = atlas.NpcIDFromGUID(atlas.PlainText(UnitGUID(unit)))
    local name = not id and atlas.PlainText(UnitName(unit))
    if not id and not name then return end
    for _, d in ipairs(list) do
        for _, boss in ipairs(atlas.Bosses and atlas.Bosses[d.key] or {}) do
            if not boss.kind or boss.kind == "rare" then
                local same
                if id then same = boss.npcID == id
                else same = name == boss.name or name == atlas.BossName(boss, d) end
                if same then
                    P.Probe("see:" .. boss.name, unit)
                    if noteWing(d) and P.Refresh then P.Refresh() end
                    return d
                end
            end
        end
    end
end

-- ------------------------------------------
-- Probe: what position data the client gives inside an instance
-- ------------------------------------------
-- A live map needs the player's position. Whether this client gives one inside a
-- dungeon is measured, not assumed: samples go to the saved variables of the character
-- (ForeverDungeonPrepChar.probe) and can be read from disk after a /reload or logout.
local function reading(value)
    if value == nil then return "nil" end
    if issecretvalue and issecretvalue(value) then return "secret" end
    if type(value) == "number" then return math.floor(value*100 + .5)/100 end
    return value
end

local function position(unit)
    if not UnitPosition then return "no api" end
    local ok, y, x, z = pcall(UnitPosition, unit)
    if not ok then return "error" end
    return reading(x), reading(y), reading(z)
end

local function sample(reason, unit)
    local _, kind, _, _, _, _, _, instance = GetInstanceInfo()
    if (kind ~= "party" and kind ~= "raid") or not P.char then return end
    local log = P.char.probe or {}
    P.char.probe = log
    local s = {t=time and time() or 0, instance=reading(instance), zone=reading(subzone()), why=reason}
    s.wx, s.wy, s.wz = position("player")
    if unit then s.ux, s.uy = position(unit) end
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    s.map = reading(map)
    if map and s.map ~= "secret" then
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if pos then
            local x, y = pos:GetXY()
            s.mx, s.my = reading(x), reading(y)
        else
            s.mx = "nil"
        end
    end
    s.facing = reading(GetPlayerFacing and GetPlayerFacing())
    local last = log[#log]
    if not reason and last and last.zone == s.zone and last.map == s.map then
        -- The same spot says nothing new.
        local moved = type(s.wx) ~= type(last.wx) or (type(s.wx) == "number"
            and (s.wx-last.wx)^2 + (s.wy-last.wy)^2 >= 100)
        local slid = type(s.mx) ~= type(last.mx) or (type(s.mx) == "number"
            and (s.mx-last.mx)^2 + (s.my-last.my)^2 >= .0004)
        if not moved and not slid then return end
    end
    if #log >= 400 then table.remove(log, 1) end
    log[#log+1] = s
end

function P.Probe(reason, unit)
    pcall(sample, reason, unit)
end

-- What the client reports right here: for calibrating the floors by hand.
function P.WhereAmI()
    local function show(value)
        if value == nil then return (L"нет") end
        if issecretvalue and issecretvalue(value) then return (L"скрыто") end
        return tostring(value)
    end
    local name, kind, _, _, _, _, _, instance = GetInstanceInfo()
    local map = C_Map and C_Map.GetBestMapForUnit and plain(C_Map.GetBestMapForUnit("player"))
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    local coords = (plain(x) and plain(y)) and ("%.1f, %.1f"):format(x*100, y*100) or (pos and (L"скрыто") or (L"нет"))
    local facing = plain(GetPlayerFacing and GetPlayerFacing())
    local wx, wy = position("player")
    local world = (type(wx) == "number" and type(wy) == "number") and ("%.0f, %.0f"):format(wx, wy) or (wx == "secret" and (L"скрыто") or (L"нет"))
    P.Probe("where")
    return (L"%s (%s, instance %s) • зона: %s • подзона: %s • миникарта: %s • карта: %s • позиция: %s • мир: %s • направление: %s"):format(
        show(name), show(kind), show(instance), show(GetZoneText and GetZoneText()), show(GetSubZoneText and GetSubZoneText()),
        show(GetMinimapZoneText and GetMinimapZoneText()), show(map), coords, world, facing and (L"%.0f град."):format(math.deg(facing)) or (L"нет"))
end

-- ------------------------------------------
-- Compass button and arrow above the boss
-- ------------------------------------------
-- A compass bearing is valid only on the identical, georeferenced floor.
-- Forever's illustrated floors have string IDs and support only plan guidance.
local function liveBearing(choice)
    local map = choice.mapID
    if type(map) ~= "number" or not P.InDungeon(choice.dungeon) or not C_Map or C_Map.GetBestMapForUnit("player") ~= map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x,y = pos:GetXY()
    local facing = GetPlayerFacing()
    local width,height = C_Map.GetMapWorldSize(map)
    if issecretvalue and (issecretvalue(x) or issecretvalue(y) or issecretvalue(facing) or issecretvalue(width) or issecretvalue(height)) then return end
    if not (x and y and facing and width and height) or (x == 0 and y == 0) or width <= 0 or height <= 0 then return end
    local dx,dy = (choice.x-x)*width,(choice.y-y)*height
    if dx*dx+dy*dy < 1 then return end
    return atan2(-dx,-dy)-facing
end

local mapIcon = "Interface\\Icons\\INV_Misc_Map_01"
local arrowIcon = "Interface\\AddOns\\ForeverDungeonPrep\\arrow"
function P.BossButton(button, choice)
    local function update()
        local angle = liveBearing(choice)
        local icon = angle and arrowIcon or mapIcon
        if button.bossIcon ~= icon then button:SetNormalTexture(icon); button.bossIcon = icon end
        button:GetNormalTexture():SetRotation(angle or 0)
    end
    update()
    if type(choice.mapID) == "number" then
        local elapsed = 0
        button:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= .15 then elapsed = 0; update() end
        end)
    end
end

-- Point at the actual creature when its visible nameplate can be identified.
local plateEvents, pointer, watched, markedUnit
local function clearPointer()
    if pointer then pointer:Hide(); pointer:ClearAllPoints() end
    local shown = markedUnit ~= nil
    markedUnit = nil
    if shown and P.Redraw then P.Redraw() end
end

function P.BossInSight()
    return markedUnit ~= nil
end

-- Index in the atlas boss list of the creature behind a nameplate, or nil.
local function bossIndexOf(d, unit)
    local id = atlas.NpcIDFromGUID(atlas.PlainText(UnitGUID(unit)))
    local name = not id and atlas.PlainText(UnitName(unit))
    if not id and not name then return end
    for index, boss in ipairs(atlas.Bosses and atlas.Bosses[d.key] or {}) do
        if id then
            if boss.npcID == id then return index end
        elseif name == boss.name or name == atlas.BossName(boss, d) then
            return index
        end
    end
end

local function markUnit(unit)
    if not watched or (issecretvalue and issecretvalue(unit)) or not unit then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local index = bossIndexOf(watched.dungeon, unit)
    if not index then return end
    local floor = atlas.BossFloor and atlas.BossFloor(watched.dungeon, index)
    if floor then P.FloorEvidence(watched.dungeon, floor) end
    if index ~= watched.index then return end
    if not pointer then
        pointer = CreateFrame("Frame", nil, UIParent)
        pointer:SetSize(26,26)
        pointer:SetFrameStrata("HIGH")
        pointer:EnableMouse(false)
        local icon = pointer:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture(arrowIcon)
        icon:SetRotation(math.pi)
    end
    pointer:ClearAllPoints()
    pointer:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    pointer:Show()
    local fresh = markedUnit ~= unit
    markedUnit = unit
    if fresh and P.Redraw then P.Redraw() end
end

function P.WatchBoss(choice)
    if not C_NamePlate then return end
    if watched and choice and watched.boss == choice.boss and watched.dungeon == choice.dungeon then return end
    if not watched and not choice then return end
    clearPointer()
    P.ResetBossLeg()
    watched = choice
    if not choice then
        if plateEvents then plateEvents:UnregisterAllEvents() end
        return
    end
    if not plateEvents then
        plateEvents = CreateFrame("Frame")
        plateEvents:SetScript("OnEvent", function(_,event,unit)
            if issecretvalue and issecretvalue(unit) then return end
            if event == "NAME_PLATE_UNIT_ADDED" then markUnit(unit)
            elseif markedUnit == unit then clearPointer() end
        end)
    end
    plateEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    plateEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plate:IsForbidden() then markUnit(plate.namePlateUnitToken) end
    end
end

-- ------------------------------------------
-- Mini plan
-- ------------------------------------------
-- The plan of the floor, small, beside the tracker: the drawing and the boss faces are
-- the atlas's own, read from its folder and its tables (nothing is copied). The boss the
-- run is heading for stands out; the dead ones fade. No dot for the player: inside an
-- instance the client gives no position.
local ART = "Interface\\AddOns\\DungeonQuestAtlas\\Art\\Maps\\"
local PLAN_W = 320
local markArt = {
    entrance = {atlas="dungeon", file="Interface\\Icons\\Spell_Nature_AstralRecal", size=18},
    up = {atlas="poi-door-up", file="Interface\\Buttons\\Arrow-Up-Up", size=18},
    down = {atlas="poi-door-down", file="Interface\\Buttons\\Arrow-Down-Up", size=18},
    floor = {atlas="poi-door", file="Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", size=18},
}
local plan

local function planTip(owner, title, note)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, .83, .35, 1, true)   -- (text, r, g, b, alpha, wrap): "true" as the alpha was an error at every hover
    if note then GameTooltip:AddLine(note, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function buildPlan()
    local scale = PLAN_W / MAP_W
    plan = CreateFrame("Frame", "DungeonQuestForeverPlan", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    plan.scale = scale
    plan:SetSize(PLAN_W + 10, MAP_H*scale + 30)
    plan:SetFrameStrata("MEDIUM")
    plan:SetClampedToScreen(true)
    plan:EnableMouse(true)
    plan:SetMovable(true)
    plan:RegisterForDrag("LeftButton")
    plan:SetScript("OnDragStart", function(self) self.dragged = true; self:StartMoving() end)
    plan:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if P.char and point then P.char.planPos = {point=point, relPoint=relPoint, x=x, y=y} end
    end)
    if plan.SetBackdrop then
        plan:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
        plan:SetBackdropColor(.05, .05, .06, .94)
        plan:SetBackdropBorderColor(.62, .52, .32, 1)
    end
    plan.title = plan:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plan.title:SetPoint("TOPLEFT", 9, -8)
    plan.title:SetWidth(PLAN_W - 30)
    plan.title:SetJustifyH("LEFT")
    plan.title:SetWordWrap(false)
    local canvas = CreateFrame("Frame", nil, plan)
    plan.canvas = canvas
    canvas:SetPoint("TOPLEFT", 5, -24)
    canvas:SetSize(PLAN_W, MAP_H*scale)
    plan.tiles = {}
    for n = 1, 12 do
        local col, row = (n-1) % 4, math.floor((n-1) / 4)
        local w, h = math.min(256, MAP_W - col*256), math.min(256, MAP_H - row*256)
        local tile = canvas:CreateTexture(nil, "BACKGROUND")
        tile:SetSize(w*scale, h*scale)
        tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", col*256*scale, -row*256*scale)
        tile:SetTexCoord(0, w/256, 0, h/256)
        plan.tiles[n] = tile
    end
    plan.pins, plan.marks = {}, {}
    local close = CreateFrame("Button", nil, plan, "UIPanelCloseButton")
    plan.close = close
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        if P.char then P.char.planOff = true end
        plan.turned = nil
        plan:Hide()
    end)
    -- A click turns the page to the next floor; the right button opens the full plan.
    plan:SetScript("OnMouseUp", function(self, button)
        if self.dragged then self.dragged = nil return end
        if button == "RightButton" then
            if self.choice then P.OpenBoss(self.choice) end
        elseif self.floors and self.floors > 1 then
            self.turned = (self.floor or 1) % self.floors + 1
            P.DrawPlan()
        end
    end)
    plan:SetScript("OnEnter", function(self)
        planTip(self, L"План этажа", (self.floors and self.floors > 1 and (L"Щелчок: другой этаж. ") or "") .. L"ПКМ: большой план атласа. Потяни, чтобы переставить.")
    end)
    plan:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function planPin(i)
    local pin = plan.pins[i]
    if pin then return pin end
    pin = CreateFrame("Button", nil, plan.canvas)
    plan.pins[i] = pin
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetTexture("Interface\\Cooldown\\star4")
    pin.glow:SetBlendMode("ADD")
    pin.glow:SetPoint("CENTER")
    pin.face = pin:CreateTexture(nil, "ARTWORK")
    pin.face:SetAllPoints()
    if pin.CreateMaskTexture then
        local mask = pin:CreateMaskTexture()
        if mask then
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(pin.face)
            pin.face:AddMaskTexture(mask)
        end
    end
    pin.ring = pin:CreateTexture(nil, "OVERLAY")
    pin.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    pin.ring:SetPoint("TOPLEFT")
    pin:SetScript("OnEnter", function(self)
        planTip(self, self.name or "?", self.next and (L"Следующий босс") or self.dead and (L"Убит") or nil)
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return pin
end

local function planMark(i)
    local mark = plan.marks[i]
    if mark then return mark end
    mark = CreateFrame("Button", nil, plan.canvas)
    plan.marks[i] = mark
    mark.icon = mark:CreateTexture(nil, "ARTWORK")
    mark.icon:SetAllPoints()
    mark.glow = mark:CreateTexture(nil, "BACKGROUND")
    mark.glow:SetTexture("Interface\\Cooldown\\star4")
    mark.glow:SetBlendMode("ADD")
    mark.glow:SetPoint("CENTER")
    mark:SetScript("OnEnter", function(self) planTip(self, self.name or "?") end)
    mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mark:SetScript("OnClick", function(self)
        if self.to and plan.floors and self.to <= plan.floors then
            plan.turned = self.to
            P.DrawPlan()
        end
    end)
    return mark
end

-- Draw the floor the way is on now (or the one the player turned to) for plan.choice.
function P.DrawPlan()
    local choice = plan and plan.choice
    if not choice then return end
    local d = choice.dungeon
    local floors = (atlas.Maps or {})[d.key] or {}
    local leg = P.BossLeg(choice)
    local floor = plan.turned or (leg and leg.floor) or choice.floor or 1
    if not floors[floor] then floor = 1 end
    local data = floors[floor]
    if not data then plan:Hide() return end
    plan.floor, plan.floors = floor, #floors
    for n, tile in ipairs(plan.tiles) do tile:SetTexture(ART .. data.id .. "_" .. n) end
    local scale, canvas = plan.scale, plan.canvas
    local list = atlas.Bosses and atlas.Bosses[d.key] or {}
    for _, pin in ipairs(plan.pins) do pin:Hide() end
    for i, spot in ipairs(data.pins) do
        local boss = list[spot[1]]
        if boss then
            local pin = planPin(i)
            pin.index, pin.name = spot[1], atlas.BossName(boss, d)
            pin.next = spot[1] == choice.index
            pin.dead = atlas.IsBossKilled and atlas.IsBossKilled(d, boss) or false
            local size = pin.next and 26 or 18
            pin:SetSize(size, size)
            pin.ring:SetSize(size*53/20, size*53/20)
            pin.ring:SetPoint("TOPLEFT", -7*size/20, 5*size/20)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", spot[2]*MAP_W*scale, -spot[3]*MAP_H*scale)
            if atlas.SetBossPortrait then atlas.SetBossPortrait(pin.face, boss) else pin.face:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
            pin.face:SetDesaturated(pin.dead)
            pin:SetAlpha(pin.dead and .45 or 1)
            pin.glow:SetSize(size*2.6, size*2.6)
            pin.glow:SetShown(pin.next)
            pin:SetFrameLevel((canvas:GetFrameLevel() or 0) + (pin.next and 6 or 3))
            pin:Show()
        end
    end
    for _, mark in ipairs(plan.marks) do mark:Hide() end
    local wanted = leg and leg.floor == floor and leg.to
    for i, m in ipairs(marks(d, floor)) do
        local art = markArt[m[1]]
        if art then
            local mark = planMark(i)
            mark.to = m[1] ~= "entrance" and m[4] or nil
            mark.name = m[1] == "entrance" and (L"Вход") or ((m[1] == "up" and (L"Подъём ") or m[1] == "down" and (L"Спуск ") or (L"Переход ")) .. floorTo(d, m[4]))
            if art.atlas and mark.icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(art.atlas) then
                mark.icon:SetAtlas(art.atlas)
            else
                mark.icon:SetTexture(art.file)
            end
            -- The passage the way takes on this floor stands out like the boss does.
            mark.next = wanted and mark.to == wanted or false
            -- The owner: "the entrance has to be marked more clearly." Larger, always
            -- lit green, and its name under it.
            local door = m[1] == "entrance"
            local size = door and 30 or mark.next and art.size + 6 or art.size
            mark:SetSize(size, size)
            mark.glow:SetSize(size*2.4, size*2.4)
            mark.glow:SetShown(mark.next or door)
            if mark.glow.SetVertexColor then
                if door then mark.glow:SetVertexColor(.35, 1, .45) else mark.glow:SetVertexColor(1, 1, 1) end
            end
            if door and not mark.label then
                mark.label = mark:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                mark.label:SetPoint("TOP", mark, "BOTTOM", 0, -1)
                if mark.label.SetTextColor then mark.label:SetTextColor(.5, 1, .55) end
            end
            if mark.label then
                mark.label:SetText(L"Вход")
                mark.label:SetShown(door)
            end
            mark:ClearAllPoints()
            mark:SetPoint("CENTER", canvas, "TOPLEFT", m[2]*MAP_W*scale, -m[3]*MAP_H*scale)
            mark:SetFrameLevel((canvas:GetFrameLevel() or 0) + 2)
            mark:Show()
        end
    end
    local name = atlas.BossName(choice.boss, d)
    plan.title:SetText((#floors > 1 and (P.FloorLabel(d, floor) .. (" %d/%d • "):format(floor, #floors)) or "") .. name
        .. (choice.floor and choice.floor ~= floor and (L" • на другом этаже") or ""))
end

-- Show the plan for the boss the run is heading for; nil or hide puts it away.
function P.UpdatePlan(choice, hide)
    if not choice or hide or (P.char and P.char.planOff) or not choice.floor then
        if plan then plan:Hide() end
        return false
    end
    if not plan then buildPlan() end
    if plan.choice == nil or plan.choice.boss ~= choice.boss or plan.leg ~= select(2, P.BossLeg(choice)) then plan.turned = nil end
    plan.choice, plan.leg = choice, select(2, P.BossLeg(choice))
    if not plan.placed then
        plan.placed = true
        plan:ClearAllPoints()
        local pos = P.char and P.char.planPos
        if pos then plan:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        else plan:SetPoint("TOPRIGHT", (P.Board or ObjectiveTrackerFrame), "TOPLEFT", -100, -4) end
    end
    P.DrawPlan()
    plan:Show()
    return true
end

function P.TogglePlan(choice)
    if not P.char then return end
    P.char.planOff = not P.char.planOff or nil
    return P.UpdatePlan(choice)
end

-- ------------------------------------------
-- The floor plan, from the atlas the player has
-- ------------------------------------------
-- Words do not show a way. A drawn plan does, and the player may have one installed:
-- Dungeon Quest Atlas keeps the floors of every dungeon with a pin for each boss, and
-- offers itself to other addons as a global. Where it is loaded, the floor of the boss
-- the run is heading for stands small beside the tracker, that boss marked; a click on a
-- boss in the tracker opens the atlas's own big plan on him. Nothing of the atlas is
-- copied: its pictures are shown from its own folder and its tables are read in place.
-- Without the atlas none of this exists and the page is as it was.
local function theAtlas()
    local A = _G.DungeonQuestAtlas
    if type(A) == "table" and type(A.Maps) == "table" and type(A.Bosses) == "table" and type(A.DungeonByKey) == "table" then return A end
end

-- Where the atlas draws a boss: its dungeon key there, his place in its list, his floor
-- and his spot on it. By the creature's number, so that our merged dungeons find the
-- atlas's wings by themselves.
local drawn
local function spotOf(npc)
    local A = theAtlas()
    if not (A and npc) then return end
    if not drawn then
        drawn = {}
        for key, list in pairs(A.Bosses) do
            for index, boss in ipairs(list) do
                if boss.npcID and not drawn[boss.npcID] then drawn[boss.npcID] = {key=key, index=index, boss=boss} end
            end
        end
        for key, floors in pairs(A.Maps) do
            for floor, data in ipairs(floors) do
                -- The atlas tries the client's own picture of a floor first, and this
                -- client has none: its big plan came up black. Its own shipped picture
                -- is used instead (seen fixed in the game with the earlier version).
                data.tex = nil
                for _, pin in ipairs(data.pins or {}) do
                    local boss = A.Bosses[key] and A.Bosses[key][pin[1]]
                    local spot = boss and boss.npcID and drawn[boss.npcID]
                    if spot and spot.key == key and not spot.floor then spot.floor, spot.x, spot.y = floor, pin[2], pin[3] end
                end
            end
        end
    end
    local spot = drawn[npc]
    return spot and spot.floor and spot or nil
end

function P.HasPlan(npc)
    return spotOf(npc) ~= nil
end

-- The atlas's own window, on the floor of this boss, his pin lit.
function P.OpenPlan(npc)
    local A, spot = theAtlas(), spotOf(npc)
    if not (A and spot and A.ShowDungeonMap) then return false end
    return (pcall(A.ShowDungeonMap, A.DungeonByKey[spot.key], spot.index))
end

local floorPlan
local FLOOR_W = 300

local function buildFloor()
    local scale = FLOOR_W / MAP_W
    local f = CreateFrame("Frame", "DungeonQuestForeverFloor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    floorPlan = f
    f.scale = scale
    f:SetSize(FLOOR_W + 10, MAP_H*scale + 30)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self.dragged = true; self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if P.char and point then P.char.floorPos = {point=point, relPoint=relPoint, x=x, y=y} end
    end)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
        f:SetBackdropColor(.05, .05, .06, .94)
        f:SetBackdropBorderColor(.62, .52, .32, 1)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 9, -8)
    f.title:SetWidth(FLOOR_W - 30)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    local canvas = CreateFrame("Frame", nil, f)
    f.canvas = canvas
    canvas:SetPoint("TOPLEFT", 5, -24)
    canvas:SetSize(FLOOR_W, MAP_H*scale)
    f.tiles = {}
    for n = 1, 12 do
        local col, row = (n-1) % 4, math.floor((n-1) / 4)
        local w, h = math.min(256, MAP_W - col*256), math.min(256, MAP_H - row*256)
        local tile = canvas:CreateTexture(nil, "BACKGROUND")
        tile:SetSize(w*scale, h*scale)
        tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", col*256*scale, -row*256*scale)
        tile:SetTexCoord(0, w/256, 0, h/256)
        f.tiles[n] = tile
    end
    f.pins = {}
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close = close
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        if P.char then P.char.floorOff = true end
        f.turned = nil
        f:Hide()
    end)
    -- A click turns to the next floor; the right button opens the atlas's big plan.
    f:SetScript("OnMouseUp", function(self, button)
        if self.dragged then self.dragged = nil return end
        if button == "RightButton" then
            if self.npc then P.OpenPlan(self.npc) end
        elseif self.floors and self.floors > 1 then
            self.turned = (self.floor or 1) % self.floors + 1
            P.DrawFloor()
        end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L"План этажа", 1, .83, .35, 1, true)   -- (text, r, g, b, alpha, wrap): "true" as the alpha was an error at every hover
        GameTooltip:AddLine((self.floors and self.floors > 1 and (L"Щелчок: другой этаж. ") or "") .. L"ПКМ: большой план в атласе. Потяни, чтобы переставить. Крестик убирает план; щелчок по боссу в трекере возвращает.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function floorPin(i)
    local pin = floorPlan.pins[i]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, floorPlan.canvas)
    floorPlan.pins[i] = pin
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetTexture("Interface\\Cooldown\\star4")
    pin.glow:SetBlendMode("ADD")
    pin.glow:SetPoint("CENTER")
    pin.face = pin:CreateTexture(nil, "ARTWORK")
    pin.face:SetAllPoints()
    if pin.CreateMaskTexture then
        local mask = pin:CreateMaskTexture()
        if mask then
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(pin.face)
            pin.face:AddMaskTexture(mask)
        end
    end
    pin.ring = pin:CreateTexture(nil, "OVERLAY")
    pin.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    pin.ring:SetPoint("TOPLEFT")
    return pin
end

-- Draw the floor of the boss the run is heading for, or the one turned to by hand.
function P.DrawFloor()
    local f, A = floorPlan, theAtlas()
    local spot = f and f.npc and spotOf(f.npc)
    if not (A and spot) then if f then f:Hide() end return end
    local floors = A.Maps[spot.key]
    local floor = f.turned or spot.floor
    if not floors[floor] then floor = spot.floor end
    local data = floors[floor]
    f.floor, f.floors = floor, #floors
    for n, tile in ipairs(f.tiles) do tile:SetTexture(ART .. data.id .. "_" .. n) end
    local scale, canvas = f.scale, f.canvas
    local list = A.Bosses[spot.key] or {}
    local dead = P.char and P.char.kills or {}
    for _, pin in ipairs(f.pins) do pin:Hide() end
    for i, at in ipairs(data.pins or {}) do
        local boss = list[at[1]]
        if boss then
            local pin = floorPin(i)
            pin.npc, pin.next, pin.dead = boss.npcID, boss.npcID == f.npc, boss.npcID and dead[boss.npcID] and true or false
            local size = pin.next and 28 or 18
            pin:SetSize(size, size)
            pin.ring:SetSize(size*53/20, size*53/20)
            pin.ring:SetPoint("TOPLEFT", -7*size/20, 5*size/20)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", at[2]*MAP_W*scale, -at[3]*MAP_H*scale)
            if not (A.SetBossPortrait and pcall(A.SetBossPortrait, pin.face, boss)) then pin.face:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
            pin.face:SetDesaturated(pin.dead)
            pin:SetAlpha(pin.dead and .45 or 1)
            pin.glow:SetSize(size*2.6, size*2.6)
            pin.glow:SetShown(pin.next)
            pin:SetFrameLevel((canvas:GetFrameLevel() or 0) + (pin.next and 6 or 3))
            pin:Show()
        end
    end
    local room = P.Room and P.Room()
    f.title:SetText((f.name or "") .. (#floors > 1 and ((L" • этаж %d/%d"):format(floor, #floors)) or "")
        .. (floor ~= spot.floor and (L" • он на другом этаже") or "") .. (room and (L" • ты в «" .. room .. "»") or ""))
end

-- The plan for the boss the run is heading for; nil, a fight or no atlas puts it away.
function P.Floor(stop, hide)
    local spot = stop and stop.npc and spotOf(stop.npc)
    if not spot or hide or (P.char and P.char.floorOff) then
        if floorPlan then floorPlan:Hide() end
        return false
    end
    if not floorPlan then buildFloor() end
    if floorPlan.npc ~= stop.npc then floorPlan.turned = nil end
    floorPlan.npc, floorPlan.name = stop.npc, stop.name
    if not floorPlan.placed then
        floorPlan.placed = true
        floorPlan:ClearAllPoints()
        local pos = P.char and P.char.floorPos
        if pos then floorPlan:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        else floorPlan:SetPoint("TOPRIGHT", (P.Board or ObjectiveTrackerFrame), "TOPLEFT", -24, -4) end
    end
    P.DrawFloor()
    floorPlan:Show()
    return true
end

