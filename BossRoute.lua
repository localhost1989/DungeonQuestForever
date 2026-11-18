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
    if P.Track then P.Track("FloorPlanOpened") end
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
    if P.Track then P.Track("FloorPlanToggled") end
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
    if P.Track then P.Track("FloorPlanOpened") end
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
    -- The owner: "make this small map live: a boss on it pressed, and what he is, what he
    -- drops, right there." The game's tooltip over the pin; its right button, the big plan.
    if pin.EnableMouse then pin:EnableMouse(true) end
    pin:SetScript("OnEnter", function(self) P.BossTip(self, self.npc, self.boss, self.dungeon, self.dead, self.next) end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.npc then P.OpenPlan(self.npc) end
    end)
    return pin
end

-- What a boss is, for the tooltip over his pin: his name and level, killed or next, how he
-- comes out, a short note on the fight, and the drop weighed for this character.
local QUALITY = {[0]="|cff9d9d9d", [1]="|cffffffff", [2]="|cff1eff00", [3]="|cff0070dd", [4]="|cffa335ee", [5]="|cffff8000"}
function P.BossTip(owner, npc, boss, d, dead, isNext)
    if not (owner and GameTooltip) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local name = boss and boss.name or "?"
    if boss and atlas.BossName then
        local ok, said = pcall(atlas.BossName, boss, d)
        if ok and type(said) == "string" then name = said end
    end
    GameTooltip:SetText(name, 1, .82, .2, 1, true)
    local state = dead and (L"убит") or isNext and (L"следующий") or nil
    local level = boss and boss.level and ((L"уровень %d"):format(boss.level)) or nil
    local said = {}
    if level then said[#said+1] = level end
    if state then said[#said+1] = state end
    if #said > 0 then
        GameTooltip:AddLine(table.concat(said, " • "), dead and .6 or .45, dead and .6 or .9, dead and .6 or .5)
    end
    local note = P.StopNote and P.StopNote(npc)
    if note then GameTooltip:AddLine(note, 1, .82, .2, true) end
    local about = npc and P.BossNotes and P.BossNotes[npc]
    if about then GameTooltip:AddLine(about, 1, 1, 1, true) end
    local loot, _, best, better = {}, 0, 0, 0
    if npc and P.LootFor then loot, _, best, better = P.LootFor(npc) end
    if #loot > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L"Добыча", 1, .82, .2)
        for i, thing in ipairs(loot) do
            if i > 8 then break end
            local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            local quality = info and select(3, info(thing.id))
            local color = QUALITY[quality or 1] or "|cffffffff"
            local tag = ""
            if thing.worth and thing.worth.best then tag = L" |cffffd34d• лучшее в слот|r"
            elseif thing.worth and thing.worth.known and thing.worth.gain > 0 and not thing.worth.worn then tag = (" |cff40e040+%.0f|r"):format(thing.worth.gain)
            elseif not thing.mine then color = "|cff8e8c87" end
            local icon = GetItemIcon and GetItemIcon(thing.id)
            GameTooltip:AddLine((icon and ("|T" .. icon .. ":14:14|t ") or "") .. color .. thing.name .. "|r" .. tag, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L"ПКМ — большой план в атласе.", .55, .55, .55, true)
    GameTooltip:Show()
end

-- Draw the floor of the boss the run is heading for, or the one turned to by hand.
function P.DrawFloor()
    local f, A = floorPlan, theAtlas()
    local spot = f and (f.goal and {key=f.goal.key, floor=f.goal.floor} or (f.npc and spotOf(f.npc)))
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
            pin.boss, pin.dungeon = boss, A.DungeonByKey[spot.key]
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
    for _, dot in ipairs(f.dots or {}) do dot:Hide() end
    if f.goal then
        P.DrawGoal(f, floor, floors)
        return
    end
    local room = P.Room and P.Room()
    f.title:SetText((f.name or "") .. (#floors > 1 and ((L" • этаж %d/%d"):format(floor, #floors)) or "")
        .. (floor ~= spot.floor and (L" • он на другом этаже") or "") .. (room and (L" • ты в «" .. room .. "»") or ""))
end

-- The owner: "the button does not work" - the plan stood there already and nothing moved.
-- "Way to the boss" turns the plan back to his floor and makes his pin pulse a few times.
function P.FlashFloor()
    local f = floorPlan
    if not (f and f.IsShown and f:IsShown()) then return false end
    f.turned = nil
    P.DrawFloor()
    for _, pin in ipairs(f.pins) do
        if pin.next and pin.IsShown and pin:IsShown() then
            if not pin.flash and pin.glow.CreateAnimationGroup then
                pcall(function()
                    local group = pin.glow:CreateAnimationGroup()
                    local fade = group:CreateAnimation("Alpha")
                    fade:SetFromAlpha(.2)
                    fade:SetToAlpha(1)
                    fade:SetDuration(.35)
                    group:SetLooping("BOUNCE")
                    pin.flash = group
                end)
            end
            if pin.flash then
                pin.flash:Play()
                if C_Timer and C_Timer.After then C_Timer.After(2.8, function() pin.flash:Stop() end) end
            end
            if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
            return true
        end
    end
    return false
end

-- The plan for the boss the run is heading for; nil, a fight or no atlas puts it away.
function P.Floor(stop, hide)
    local spot = stop and stop.npc and spotOf(stop.npc)
    if not spot or hide or (P.char and P.char.floorOff) then
        if floorPlan then floorPlan:Hide() end
        return false
    end
    if not floorPlan then buildFloor() end
    if floorPlan.npc ~= stop.npc or floorPlan.goal then floorPlan.turned = nil end
    floorPlan.goal = nil
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

-- ------------------------------------------
-- Where the goal of a quest is, inside
-- ------------------------------------------
-- The owner, 17.11.2026, inside Uldaman: "nothing is clear in the dungeons; we walk into
-- rooms, we can get hints what to look for in this room." The game gives no position
-- inside, but the places of the things are known (P.InsideSpots, below: AzerothCore's
-- spawns laid on the atlas floors, with the room each stands in). Under a quest taken:
-- "где: Зал Карт, у Ревелоша"; a click opens the floor with the spot; walking into a room
-- where something is wanted says so in the middle of the screen.
local ruClient = (GetLocale and GetLocale() or "enUS") == "ruRU"
local function pick(ru, en) if ruClient then return ru or en end return en or ru end
local function roomName(p) return pick(p[6], p[7]) end

local bossNames
local function bossName(npc)
    if not npc then return end
    if not bossNames then
        bossNames = {}
        for _, list in pairs(P.Runs or {}) do
            for _, b in ipairs(list) do if b.npc and b.name then bossNames[b.npc] = b.name end end
        end
    end
    return bossNames[npc]
end

-- The goals of a quest still wanted inside, by what the quest log says is left.
function P.InsideGoals(id)
    local goals = P.InsideSpots and P.InsideSpots[id]
    if not goals then return {} end
    local needs = P.Needs and P.Needs(id) or {}
    if #needs == 0 then return goals end
    local left = {}
    for _, goal in ipairs(goals) do
        for _, need in ipairs(needs) do
            if (need.item and goal.item == need.item) or need.what == pick(goal.w[1], goal.w[2])
                or need.what == pick(goal.from[1], goal.from[2]) then left[#left+1] = goal break end
        end
    end
    return #left > 0 and left or goals
end

-- "где: ..." for a quest taken, inside; nil when nothing is known.
function P.WhereInside(row)
    local id = row and (row.step or row.id)
    if not id then return end
    if row.work and row.work.mapID then
        return row.work.cave and (L"где: снаружи, перед порталом") or (L"где: снаружи")
    end
    local goal = P.InsideGoals(id)[1]
    if not goal then return end
    local here = P.Room and P.Room()
    local rooms, seen = {}, {}
    for _, p in ipairs(goal.p) do
        local room = roomName(p)
        if room and room == here then return L"где: здесь, в «" .. room .. "»" end
        if room and not seen[room] then seen[room] = true; rooms[#rooms+1] = room end
    end
    if goal.spread then
        if #rooms == 0 then return L"где: по всему подземелью" end
        local text = table.concat(rooms, ", ", 1, math.min(2, #rooms))
        if #rooms > 2 then text = text .. L" и ещё " .. (#rooms - 2) end
        return L"где: " .. text
    end
    local p = goal.p[1]
    local boss = bossName(p[5])
    local who = pick(goal.from[1], goal.from[2])
    if goal.kind == "kill" and who then boss = boss ~= who and boss or nil end
    local parts = {}
    if rooms[1] then parts[#parts+1] = rooms[1] end
    if boss then parts[#parts+1] = L"рядом босс " .. boss end
    if #parts == 0 then return end
    return L"где: " .. table.concat(parts, ", ")
end

local function goalDot(f, i)
    f.dots = f.dots or {}
    local dot = f.dots[i]
    if dot then return dot end
    dot = CreateFrame("Frame", nil, f.canvas)
    f.dots[i] = dot
    dot.glow = dot:CreateTexture(nil, "BACKGROUND")
    dot.glow:SetTexture("Interface\\Cooldown\\star4")
    dot.glow:SetBlendMode("ADD")
    dot.glow:SetPoint("CENTER")
    dot.icon = dot:CreateTexture(nil, "ARTWORK")
    dot.icon:SetAllPoints()
    dot.icon:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    if dot.EnableMouse then dot:EnableMouse(true) end
    dot:SetScript("OnEnter", function(self) planTip(self, self.name or "?", self.room) end)
    dot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return dot
end

-- The goal's spots on the floor shown; the title: from which boss, which way.
function P.DrawGoal(f, floor, floors)
    local goal = f.goal
    local scale, canvas = f.scale, f.canvas
    local name = pick(goal.what[1], goal.what[2])
    local n, first = 0, nil
    for _, p in ipairs(goal.p) do
        if p[1] == goal.key and p[2] == floor then
            n = n + 1
            local dot = goalDot(f, n)
            local size = n == 1 and 16 or 12
            dot:SetSize(size, size)
            dot.glow:SetSize(size*2.6, size*2.6)
            dot.name, dot.room = name, roomName(p)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", canvas, "TOPLEFT", p[3]*MAP_W*scale, -p[4]*MAP_H*scale)
            dot:SetFrameLevel((canvas:GetFrameLevel() or 0) + 8)
            if not dot.label then
                dot.label = dot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                dot.label:SetPoint("LEFT", dot, "RIGHT", 2, 0)
            end
            dot.label:SetText(n == 1 and name or "")
            dot:Show()
            first = first or p
        end
    end
    -- The way to it: from the boss killed last on this floor nearest to it, or from the
    -- entrance drawn on the floor.
    local text
    if first then
        local A = theAtlas()
        local from, fromName, best
        local dead = P.char and P.char.kills or {}
        for _, at in ipairs(((A and A.Maps[goal.key] or {})[floor] or {}).pins or {}) do
            local boss = A.Bosses[goal.key] and A.Bosses[goal.key][at[1]]
            if boss and boss.npcID and dead[boss.npcID] then
                local gap = (at[2]-first[3])^2 + (at[3]-first[4])^2
                if not best or gap < best then best, from, fromName = gap, {x=at[2], y=at[3]}, bossName(boss.npcID) or boss.name end
            end
        end
        if not from then
            for _, m in ipairs(((A and A.MapMarks or {})[goal.key] or {})[floor] or {}) do
                if m[1] == "entrance" then from, fromName = {x=m[2], y=m[3]}, nil end
            end
        end
        local way = from and direction(from, {x=first[3], y=first[4]})
        if way then
            text = (fromName and (L"От босса " .. fromName) or (L"От входа")) .. L" на " .. way .. L" до точки"
        elseif fromName then
            text = L"Рядом босс " .. fromName
        end
    end
    f.title:SetText((text or name) .. (floors and #floors > 1 and ((L" • этаж %d/%d"):format(floor, #floors)) or "")
        .. ((not first) and (L" • цель на другом этаже") or ""))
end

-- Open the floor with the spots of a quest's goal. False when nothing is known or there is
-- no atlas to draw it.
function P.ShowGoal(d, id)
    local goal = P.InsideGoals(id)[1]
    local A = theAtlas()
    if not (goal and A and goal.p[1] and A.Maps[goal.p[1][1]]) then return false end
    spotOf(0)       -- (the atlas's own pictures are set once, on the first look)
    if not floorPlan then buildFloor() end
    local key, floor = goal.p[1][1], goal.p[1][2]
    floorPlan.goal = {key=key, floor=floor, p=goal.p, what=goal.w}
    floorPlan.turned = nil
    floorPlan.npc = nil
    if P.char then P.char.floorOff = nil end
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

-- Walking into a room where a quest taken wants something: said once a run in the middle
-- of the screen. Returns the text.
local roomSaid = {}
function P.RoomNews(d)
    local room = P.Room and P.Room()
    if not (d and room and P.InsideSpots) then return end
    local key = d.key .. ":" .. room
    if roomSaid[key] then return end
    for id in pairs(P.InsideSpots) do
        local taken = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
        local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
        if taken and not ready then
            for _, goal in ipairs(P.InsideGoals(id)) do
                for _, p in ipairs(goal.p) do
                    if roomName(p) == room then
                        roomSaid[key] = true
                        local what = goal.kind == "kill" and pick(goal.from[1], goal.from[2]) or pick(goal.w[1], goal.w[2])
                        local title = P.Title and P.Title(id) or "?"
                        local text = L"Здесь: " .. what .. L" — для «" .. title .. "»"
                        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
                        if RaidNotice_AddMessage and RaidWarningFrame then
                            pcall(RaidNotice_AddMessage, RaidWarningFrame, text, {r=1, g=.82, b=.3})
                        end
                        return text
                    end
                end
            end
        end
    end
end
function P.RoomNewsReset() roomSaid = {} end

-- ------------------------------------------
-- A word on each boss, for the tooltip over his pin on the small plan
-- ------------------------------------------
-- The owner: "can a boss not have at least a description written?" What a boss does that
-- matters and a short tip, for the bosses of the classic dungeons (the dungeons of this
-- client alone are left out: nothing sure is known of them). By creature id: {ru, en}.
-- BEGIN LOOT (both languages are written here: the locale table leaves this part alone)
local NOTES = {
    -- RFC
    [11517] = {"Огглфлинт: вожак троггов у входа, бьёт рассечением по всем перед собой. Танку стоит развернуть его от группы.", "Oggleflint: trogg leader near the entrance, Cleaves everyone in front of him. Tank should face him away from the group."},
    [11520] = {"Тарагаман Ненасытный: огненный взрыв вокруг себя и апперкот, отбрасывающий танка. Бой у края лавы, держите спину к стене.", "Taragaman the Hungerer: Fire Nova around himself and an Uppercut that knocks the tank back. Keep your back to a wall."},
    [11518] = {"Джергош Призыватель: чернокнижник, накладывает проклятие слабости, жертвенный огонь и стреляет стрелами тьмы. Прерывайте касты.", "Jergosh the Invoker: warlock, casts Curse of Weakness, Immolate and Shadow Bolt. Interrupt his casts."},
    [11519] = {"Баззалан: разбойник, коварный удар и смертельный яд. Снимайте яд, если есть чем.", "Bazzalan: rogue, uses Sinister Strike and Deadly Poison. Cure the poison if you can."},

    -- WC
    [3669] = {"Лорд Кобран: молнии, усыпление и яд; может принять облик змеи. Один из четырёх Клыкастых лордов.", "Lord Cobrahn: Lightning Bolt, Druid's Slumber and poison; can take serpent form. One of the four Fanglords."},
    [3671] = {"Леди Анакондра: молнии, усыпление, шипы и лечение. Прерывайте её лечение и усыпление.", "Lady Anacondra: Lightning Bolt, Druid's Slumber, Thorns and healing. Interrupt her heals and sleep."},
    [3653] = {"Креш: огромная черепаха в воде, просто бьёт, но очень прочная. Можно пропустить.", "Kresh: huge turtle in the water, only melees but has heavy armor. Optional."},
    [3670] = {"Лорд Пифас: молнии, усыпление, удар грома и лечение. Прерывайте лечение.", "Lord Pythas: Lightning Bolt, Druid's Slumber, Thunderclap and healing. Interrupt his heals."},
    [3673] = {"Лорд Серпентис: молнии, усыпление и лечение. Прерывайте лечение, держите при нём танка.", "Lord Serpentis: Lightning Bolt, Druid's Slumber and healing. Interrupt his heals."},
    [5775] = {"Вердан Вечноживущий: опутывающие лозы сбивают с ног всех рядом. Дальний бой может стоять подальше.", "Verdan the Everliving: Grasping Vines knock down everyone nearby. Ranged can stand back."},
    [3654] = {"Мутанус Пожиратель: появляется в конце ритуала Наралекса после смерти четырёх лордов. Усыпляет, пугает и оглушает.", "Mutanus the Devourer: appears at the end of Naralex's ritual once the four Fanglords are dead. Sleeps, fears and stuns."},

    -- DM (Deadmines)
    [644] = {"Рак'Зор: огр у первой двери, мощный удар оглушает танка. Простой бой, но больно бьёт.", "Rhahk'Zor: ogre at the first door, his Slam stuns the tank. Simple fight but hits hard."},
    [642] = {"Крошитель Снида: пугает и бьёт по танку. Когда машина ломается, из неё выпрыгивает Снид.", "Sneed's Shredder: fears and pounds the tank. When the shredder breaks, Sneed jumps out of it."},
    [643] = {"Снид: выходит из разбитого крошителя, обезоруживает танка. Бьёт слабо, добейте быстро.", "Sneed: comes out of the destroyed shredder and Disarms the tank. Weak, finish him quickly."},
    [1763] = {"Гилнид: ходит по литейной с охраной, бросает расплавленный металл. Сначала зачистите рабочих рядом.", "Gilnid: patrols the foundry with guards and throws Molten Metal. Clear the workers nearby first."},
    [646] = {"Мистер Смайт: на трети и двух третях здоровья оглушает всех вокруг и бежит к сундуку менять оружие.", "Mr. Smite: at two thirds and one third health stuns everyone around and runs to his chest to swap weapons."},
    [647] = {"Капитан Зелёная Шкура: на палубе корабля, рассекает и бросает отравленный гарпун.", "Captain Greenskin: on the ship deck, uses Cleave and a Poisoned Harpoon."},
    [639] = {"Эдвин ван Клиф: на низком здоровье зовёт двух стражей Братства. Держите силы на добивание.", "Edwin VanCleef: at low health calls two Defias Blackguards. Save cooldowns for the end."},
    [645] = {"Кукки: на корабле, бросает еду и лечит себя готовкой. Добивайте без пауз.", "Cookie: on the ship, throws food and heals himself with Cookie's Cooking. Keep up the damage."},

    -- SFK
    [3914] = {"Ретилгор: у камер в подземелье. После его смерти поговорите с узником, он откроет дверь во двор.", "Rethilgore: by the cells. After he dies, talk to the prisoner and he opens the courtyard door."},
    [3887] = {"Барон Сильверлейн: накладывает Пелену тени, сильно снижающую лечение. Снимайте проклятие, если можете.", "Baron Silverlaine: casts Veil of Shadow, a curse that greatly reduces healing taken. Decurse if you can."},
    [4278] = {"Командир Спрингвейл: паладин, оглушает молотом и лечит себя Светом небес. Прерывайте лечение.", "Commander Springvale: paladin, uses Hammer of Justice and heals himself with Holy Light. Interrupt the heal."},
    [4279] = {"Одо Слепой Страж: с падением здоровья накладывает на себя ярость и бьёт всё сильнее. Тратьте силы в конце.", "Odo the Blindwatcher: Howling Rage stacks as his health drops, so he hits harder and harder. Burn him at the end."},
    [4274] = {"Фенрус Пожиратель: ядовитая слюна. После его смерти появляется Аругал и вызывает пустотных стражей.", "Fenrus the Devourer: Toxic Saliva. After he dies, Arugal appears and summons voidwalkers."},
    [3927] = {"Волчий вожак Нандос: зовёт на помощь воргенов. Держите помощников на танке.", "Wolf Master Nandos: calls worgen helpers. Keep the adds on the tank."},
    [4275] = {"Верховный маг Аругал: прыгает по балконам, бьёт тьмой и превращает игрока в воргена, который бьёт своих.", "Archmage Arugal: teleports around the ledges, casts Void Bolt and curses a player into a worgen who attacks allies."},

    -- BFD
    [4887] = {"Гаму-ра: большая черепаха, топчет всех вокруг. Простой бой.", "Ghamoo-ra: big turtle, Trample hits everyone around. Simple fight."},
    [4831] = {"Леди Саревесс: раздвоенная молния и замедление, ходит с нагами. Прерывайте касты.", "Lady Sarevess: Forked Lightning and Slow, comes with naga guards. Interrupt her casts."},
    [6243] = {"Гелихаст: вожак мурлоков, ловит в сеть. После него можно взять благословение у алтаря.", "Gelihast: murloc leader, uses Net. The altar behind him gives a buff."},
    [12902] = {"Лоргус Джетт: шаман Сумеречного Молота, бьёт молниями под щитом молний. Бывает не всегда.", "Lorgus Jett: Twilight shaman, casts Lightning Bolt under Lightning Shield. Does not always spawn."},
    [12876] = {"Барон Акванис: призывается камнем в воде, бьёт магией льда.", "Baron Aquanis: summoned from the Fathom Stone in the water, uses frost magic."},
    [4832] = {"Повелитель сумерек Келрис: взрыв разума и усыпление. После него зажгите четыре огня, чтобы открыть дверь.", "Twilight Lord Kelris: Mind Blast and Sleep. After him, light the four braziers to open the door."},
    [4829] = {"Аку'май: ядовитое облако и бешенство на низком здоровье. Дверь к ней открывается после четырёх огней.", "Aku'mai: Poison Cloud and an enrage at low health. Her door opens after the four braziers are lit."},

    -- STOCKS
    [1717] = {"Хэмхок: цепная молния и жажда крови. Прерывайте и держите его на танке.", "Hamhock: Chain Lightning and Bloodlust. Interrupt and keep him on the tank."},
    [1716] = {"Базил Тредд: дымовая шашка оглушает. Сам бьёт несильно.", "Bazil Thredd: Smoke Bomb stuns. Not a hard hitter."},
    [1663] = {"Декстрен Уорд: устрашающий крик пугает группу. Деритесь в стороне от других камер.", "Dextren Ward: Intimidating Shout fears the group. Fight away from other cells."},

    -- GNOMER
    [7361] = {"Груббис: выходит с Чомпером в последней волне события Эми Шортфьюз. Держите его подальше от Эми.", "Grubbis: arrives with Chomper in the last wave of Emi Shortfuse's event. Keep him away from Emi."},
    [6235] = {"Электрошокер 6000: цепные разряды и шок. С него падает ключ от мастерской.", "Electrocutioner 6000: Chain Bolt and Shock. Drops the Workshop Key."},
    [6229] = {"Толпогон 9-60: удар по толпе отбрасывает всех перед ним. Держитесь за спиной или сбоку.", "Crowd Pummeler 9-60: Crowd Pummel knocks back everyone in front. Stand behind or to the side."},
    [7800] = {"Мекгинер Термоштепсель: отбрасывает танка, из стен выходят ходячие бомбы. Жмите кнопки у отверстий.", "Mekgineer Thermaplugg: Knock Away on the tank, walking bombs come out of wall vents. Press the button by each vent."},

    -- RFK
    [4428] = {"Вестник смерти Джаргба: подчиняет разум игрока и бьёт стрелами тьмы. Будьте готовы к контролю.", "Death Speaker Jargba: Dominate Mind on a player and Shadow Bolt. Be ready for a mind-controlled ally."},

    -- SM
    [3983] = {"Дознаватель Вишас: Слово Тьмы: Боль на группу. Простой бой.", "Interrogator Vishas: Shadow Word: Pain on the group. Simple fight."},
    [4543] = {"Кровавый маг Тальнос: огненный шок, огненный выброс вокруг и стрелы тьмы. Ближнему бою больно.", "Bloodmage Thalnos: Flame Shock, Fire Nova around him and Shadow Bolt. Melee takes the nova."},
    [3974] = {"Псарь Локси: ходит с тремя гончими, использует жажду крови. Сначала гончие или контроль.", "Houndmaster Loksey: has three hounds and uses Bloodlust. Deal with the dogs first."},
    [6487] = {"Чародей Доан: немота и превращение. На половине здоровья окружает себя щитом и взрывает всё рядом, отбегите.", "Arcanist Doan: Silence and Polymorph. At half health he shields himself, then Detonation hits everyone close. Run out."},
    [3975] = {"Ирод: вихрь, рывок и бешенство на низком здоровье. После смерти набегает толпа послушников.", "Herod: Whirlwind, Rushing Charge and an enrage at low health. When he dies a wave of trainees rushes in."},
    [3976] = {"Командир Могрейн: молот правосудия и божественный щит. После его смерти приходит Вайтмейн и воскрешает его.", "Scarlet Commander Mograine: Hammer of Justice and Divine Shield. When he dies Whitemane comes and resurrects him."},
    [3977] = {"Вайтмейн: усыпляет всю группу и воскрешает Могрейна, лечит и бьёт Светом. Убейте обоих быстро.", "High Inquisitor Whitemane: puts the group to sleep and resurrects Mograine, heals and smites. Burn both fast."},

    -- RFD
    [7355] = {"Тутен'каш: выходит после третьего удара в гонг, сначала волны пауков. Опутывает паутиной и травит ядом.", "Tuten'kash: comes out after the third gong strike, spider waves first. Webs and poisons the group."},
    [7357] = {"Мордреш Огненный Глаз: огненные шары и огненный выброс вокруг себя. Прерывайте касты.", "Mordresh Fire Eye: Fireball and Fire Nova around himself. Interrupt his casts."},
    [8567] = {"Обжора: облако болезни вокруг и бешенство на низком здоровье.", "Glutton: Disease Cloud around him and a Frenzy at low health."},
    [7358] = {"Амненнар Хладовей: ледяные стрелы, кольцо льда, гнев по группе; на половине здоровья вызывает призраков.", "Amnennar the Coldbringer: Frostbolt, Frost Nova and Amnennar's Wrath; at half health summons spectral adds."},

    -- ULDA
    [6906] = {"Бейлог: один из трёх дворфов, дерётся вместе с Эриком и Олафом, стреляет издалека. Контролируйте по одному.", "Baelog: one of three dwarves fought together with Eric and Olaf, shoots from range. Control and kill one at a time."},
    [6908] = {"Олаф: щитоносец из троицы с Эриком и Бейлогом. Убивайте их по одному.", "Olaf: shield bearer of the trio with Eric and Baelog. Kill them one at a time."},
    [6910] = {"Ревелош: шаман-трогг, бьёт молниями и цепной молнией. Прерывайте.", "Revelosh: trogg caster, uses Lightning Bolt and Chain Lightning. Interrupt him."},
    [7228] = {"Айроная: каменный великан, отбрасывает и бьёт по площади вокруг. Танк держит спину к стене.", "Ironaya: stone giant, Knock Away and War Stomp. Tank with your back to a wall."},
    [7206] = {"Древний каменный хранитель: вызывает песчаные вихри и топчет. Уходите от вихрей.", "Ancient Stone Keeper: summons sand storms and uses Trample. Move away from the storms."},
    [7291] = {"Гальганн Огненный Молот: огненный выброс вокруг себя и огненные удары.", "Galgann Firehammer: Fire Nova around himself and fire attacks."},
    [4854] = {"Гримлок: уменьшает игроков, бьёт молниями и вешает жажду крови.", "Grimlok: Shrink on players, Lightning Bolt and Bloodlust."},
    [2748] = {"Архедас: пробуждается от алтаря, сотрясает землю и оживляет каменных стражей. Добивайте помощников.", "Archaedas: wakes when the altar is used, Ground Tremor and awakens stone guardians. Kill the adds."},

    -- ZF
    [8127] = {"Анту'сул: ставит тотемы лечения и опутывания, по ходу боя зовёт василисков. Ломайте тотемы.", "Antu'sul: drops healing and Earthgrab totems and calls basilisks during the fight. Kill the totems."},
    [7271] = {"Знахарь Зум'ра: из могил вокруг лезут зомби, бьёт залпом стрел тьмы. Тяните его подальше от могил.", "Witch Doctor Zum'rah: zombies rise from the graves around, casts Shadow Bolt Volley. Pull him away from the graves."},
    [7274] = {"Палач Песчаной Бури: с него падает ключ палача от клеток с пленниками на пирамиде.", "Sandfury Executioner: drops the Executioner's Key that opens the prisoners' cages on the pyramid."},
    [7604] = {"Сержант Блай: после боя на лестнице пирамиды заговорите с ним, и его отряд нападёт. У него жезл для задания.", "Sergeant Bly: after the pyramid stairs event, talk to him and his crew attacks. Drops the rod for a quest."},
    [7273] = {"Газ'рилла: призывается ударом молота Зул'Фаррака в гонг у пруда. Замораживает игроков и подбрасывает ударом.", "Gahz'rilla: summoned by striking the gong at the pool with the Mallet of Zul'Farrak. Freezes players and slams them up."},
    [7267] = {"Вождь Укорз Песчаный Скальп: на вершине вместе с Руузлу, рассекает и впадает в бешенство.", "Chief Ukorz Sandscalp: at the top together with Ruuzlu, Cleaves and goes into a Frenzy."},

    -- MARA
    [13282] = {"Ноксион: залп яда и апперкот; временами исчезает и оставляет мелких слизней. Убивайте слизней.", "Noxxion: Toxic Volley and Uppercut; now and then hides and leaves small spawns. Kill the spawns."},
    [12203] = {"Оползень: каменный великан, отбрасывает танка и топчет. Танк держит спину к стене.", "Landslide: rock giant, Knock Away and Trample. Tank with your back to a wall."},
    [12201] = {"Принцесса Терадрас: пыльное поле, бросает валуны, пугает взглядом и сбивает с ног. Держите её у стены.", "Princess Theradras: Dust Field, throws boulders, fears with Repulsive Gaze and Knockdown. Tank her against a wall."},

    -- ST
    [8580] = {"Атал'аларион: появляется, если активировать статуи внизу в правильном порядке. Сильно бьёт в ближнем бою.", "Atal'alarion: appears when the statues on the lower level are activated in the right order. Hits hard in melee."},
    [5710] = {"Джаммал'ан Пророк: барьер падает после шести троллей на балконах. Порча превращает игрока во врага, ставит тотемы и лечится.", "Jammal'an the Prophet: barrier drops after the six balcony trolls. His Hex turns a player hostile; uses totems and heals."},
    [5709] = {"Тень Эраникуса: становится доступна после драконов. Усыпляет всю группу и бьёт по площади, держите её от группы.", "Shade of Eranikus: attackable after the dragons die. Deep Slumber sleeps the group, also War Stomp. Keep him off the group."},

    -- BRD
    [9025] = {"Лорд Роккор: огненный шок, земной шок и сотрясение земли. Простой бой.", "Lord Roccor: Flame Shock, Earth Shock and Ground Tremor. Simple fight."},
    [9018] = {"Верховный дознаватель Герштан: Слово Тьмы: Боль, ментальный крик и сожжение маны. Прерывайте.", "High Interrogator Gerstahn: Shadow Word: Pain, Psychic Scream and Mana Burn. Interrupt her."},
    [9027] = {"Горош Дервиш: один из случайных боссов Круга Закона, крутит вихрь. Ближнему бою отходить.", "Gorosh the Dervish: one of the random Ring of Law bosses, uses Whirlwind. Melee step out."},
    [9041] = {"Страж Стилгисс: в хранилище вместе с псом Вереком, кольцо льда и ледяные стрелы.", "Warder Stilgiss: in the Vault together with his hound Verek, uses Frost Nova and Frostbolt."},
    [9476] = {"Страж Думгрип: выходит с големами, когда открыты все сейфы хранилища.", "Watchman Doomgrip: comes out with golems once all the Vault safes are opened."},
    [9017] = {"Лорд Инсендиус: у Чёрной наковальни, огненная буря и мощный удар с отбрасыванием.", "Lord Incendius: at the Black Anvil, Fire Storm and Mighty Blow that knocks back."},
    [9033] = {"Генерал Гневная Кузня: на низком здоровье зовёт подкрепление дворфов. Тратьте силы в конце.", "General Angerforge: at low health calls Anvilrage reinforcements. Save cooldowns for the end."},
    [9156] = {"Посол Огнехлыст: из рун вокруг выходят горящие духи и усиливают его. Убивайте духов до того, как дойдут.", "Ambassador Flamelash: Burning Spirits come from the runes and empower him. Kill them before they reach him."},
    [9938] = {"Магмус: топот по площади; в зале статуи дышат огнём, не стойте у них.", "Magmus: War Stomp; the statues in the hall breathe fire, do not stand in front of them."},
    [8929] = {"Принцесса Мойра: лечит императора, взрыв разума и Слово Тьмы: Боль. Прерывайте лечение.", "Princess Moira Bronzebeard: heals the Emperor, Mind Blast and Shadow Word: Pain. Interrupt the heals."},
    [9019] = {"Император Дагран Тауриссан: Длань Тауриссана оглушает, Аватара пламени бьёт огнём вокруг.", "Emperor Dagran Thaurissan: Hand of Thaurissan stuns, Avatar of Flame burns everyone around."},

    -- LBRS
    [9196] = {"Верховный лорд Омокк: отбрасывает танка, бой у края обрыва. Держите спину к стене.", "Highlord Omokk: Knock Away on the tank, fought near a ledge. Keep your back to a wall."},
    [9236] = {"Тёмный охотник Вош'гаджин: порча, проклятие крови и рассечение.", "Shadow Hunter Vosh'gajin: Hex, Curse of Blood and Cleave."},
    [10596] = {"Мать Тлеющая Паутина: кристаллизация оглушает, Материнское молоко травит. Снимайте яд.", "Mother Smolderweb: Crystallize stuns, Mother's Milk poisons. Cure the poison."},
    [10584] = {"Урок Гибельный Вой: вызывается у кучи подношений Урока, сначала идут волны огров.", "Urok Doomhowl: summoned at Urok's Tribute Pile, waves of ogres come first."},
    [9736] = {"Интендант Зигрис: стреляет, бросает оглушающие бомбы и пьёт зелья лечения.", "Quartermaster Zigris: shoots, throws Stun Bombs and drinks healing potions."},
    [10220] = {"Халикон: ворг, после её смерти приходит Гизрул Поработитель.", "Halycon: worg, Gizrul the Slavener arrives after she dies."},
    [10268] = {"Гизрул Поработитель: появляется после Халикон, впадает в бешенство.", "Gizrul the Slavener: comes after Halycon dies, goes into a Frenzy."},
    [9568] = {"Властитель Змейталак: на половине здоровья зовёт двух помощников. Будьте готовы их взять.", "Overlord Wyrmthalak: at half health calls two adds. Be ready to pick them up."},

    -- UBRS
    [9816] = {"Пиростраж Угольный Провидец: событие начинается у алтаря, сначала тюремщики. Огненный выброс и огненный столб.", "Pyroguard Emberseer: the event starts at the altar, the Incarcerators come first. Fire Nova and Flamestrike."},
    [10264] = {"Солакар Огненный Венец: в гнездовье, приходит после волн дракончиков и смотрителей.", "Solakar Flamewreath: in the Rookery, comes after waves of whelps and handlers."},
    [10339] = {"Гит: дракон, на котором приезжает Ренд после волн на арене. Дышит разными дыханиями.", "Gyth: the dragon Rend rides in on after the arena waves. Uses several breath attacks."},
    [10429] = {"Вождь Ренд Чернорук: сначала волны орков и драконов, потом Гит. Затем Ренд спешивается, крутит вихрь.", "Warchief Rend Blackhand: first waves of orcs and dragons, then Gyth. Then Rend dismounts and uses Whirlwind."},
    [10430] = {"Зверь: огненные шары, огненный взрыв отбрасывает, рёв пугает. Танк у стены.", "The Beast: Fireball, Flamebreak knocks back and Terrifying Roar fears. Tank against a wall."},
    [10363] = {"Генерал Драккисат: с двумя стражами, Воспламенение дезориентирует игрока, огненный столб.", "General Drakkisath: with two elite guards, Conflagration disorients a player, also Flamestrike."},

    -- DM_E
    [14354] = {"Пузиллин: убегает, догоняйте по залам. В конце дерётся с бесами, взрывная волна. С него ключ.", "Pusillin: runs away, chase him through the halls. At the end fights with imps, Blast Wave. Drops the Crescent Key."},
    [11490] = {"Зеврим Терновое Копыто: Жертва приковывает игрока и наносит урон, лечите его.", "Zevrim Thornhoof: Sacrifice pins a player and drains him, heal that player."},
    [13280] = {"Гидророжденный: гейзер подбрасывает, ныряет под воду и выныривает.", "Hydrospawn: Massive Geyser throws players up, submerges and resurfaces."},
    [11492] = {"Алззин Перевёртыш: меняет облики, проклятие увядания и отбрасывание.", "Alzzin the Wildshaper: shifts forms, casts Wither and uses Knock Away."},

    -- DM_W
    [11489] = {"Тендрис Варпвуд: древо, опутывает корнями и топчет.", "Tendris Warpwood: treant, Entangle and Trample."},
    [11488] = {"Иллиана Вороний Дуб: охотница с медведем, залп стрел и огненная ловушка.", "Illyanna Ravenoak: hunter with a bear pet, Volley and Immolation Trap."},
    [11487] = {"Магистр Календрис: облик тьмы, взрыв разума и пытка разума. Прерывайте.", "Magister Kalendris: Shadowform, Mind Blast and Mind Flay. Interrupt him."},
    [11496] = {"Иммол'тар: освобождается после пяти кристаллов-пилонов. Зовёт глаза-помощников, топчет.", "Immol'thar: freed after the five pylons are shut down. Summons Eyes of Immol'thar and Tramples."},
    [11486] = {"Принц Тортелдрин: вихрь, чародейский взрыв, притягивает игроков к себе и прерывает касты.", "Prince Tortheldrin: Whirlwind, Arcane Blast, summons players to himself and Counterspells."},

    -- DM_N
    [14325] = {"Капитан Кромкруш: устрашающий крик пугает, на помощь зовёт стражников-огров.", "Captain Kromcrush: Intimidating Shout fears, calls ogre guards to help."},
    [11501] = {"Король Гордок: вместе с магом Чо'Рашем, смертельный удар и громовая поступь. Сначала Чо'Раш.", "King Gordok: with the mage Cho'Rush, Mortal Strike and War Stomp. Kill Cho'Rush first."},

    -- SCHOLO
    [10506] = {"Киртонос Глашатай: вызывается Кровью невинных на жаровне. Меняет облик летучей мыши и человека, обезоруживает.", "Kirtonos the Herald: summoned with the Blood of Innocents at the brazier. Switches between bat and human form, Disarms."},
    [10503] = {"Джандис Барова: создаёт много своих копий, проклятие крови. Ищите настоящую.", "Jandice Barov: creates many illusions of herself, Curse of Blood. Find the real one."},
    [11622] = {"Рэттлгор: громовая поступь и отбрасывание. Танк у стены.", "Rattlegore: War Stomp and Knock Away. Tank against a wall."},
    [10508] = {"Рас Ледяной Шёпот: залп ледяных стрел, кольцо холода и ледяная броня. Прерывайте.", "Ras Frostwhisper: Frostbolt Volley, Chill Nova and Ice Armor. Interrupt him."},
    [11261] = {"Доктор Теолен Крастинов: кровотечение и бешенство на низком здоровье.", "Doctor Theolen Krastinov: Rend and a Frenzy at low health."},
    [1853] = {"Тёмный магистр Гандлинг: приходит после шести боссов в боковых комнатах. Портал тьмы уносит игрока в комнату с нежитью.", "Darkmaster Gandling: appears after the six side room bosses. Shadow Portal sends a player into a room full of undead."},

    -- STRAT_LIVE
    [11143] = {"Почтальон Малоун: появляется после открытия трёх почтовых ящиков Ключом от города.", "Postmaster Malown: appears after three postboxes are opened with the Key to the City."},
    [10808] = {"Тимми Жестокий: появляется на площади, когда зачищена нежить вокруг.", "Timmy the Cruel: appears in the square once the undead around it are cleared."},
    [10997] = {"Канонир Вилли: зовёт стрелков Алого ордена и отбрасывает. Убивайте стрелков.", "Cannon Master Willey: calls Crimson Riflemen and uses Knock Away. Kill the riflemen."},
    [10813] = {"Бальназар: Великий рыцарь Датрохан превращается в демона. Подчиняет разум, пугает и бьёт залпом тьмы.", "Balnazzar: Grand Crusader Dathrohan turns into the demon. Mind controls, fears and casts Shadow Bolt Volley."},

    -- STRAT_UD
    [10436] = {"Баронесса Анастари: вселяется в игрока и управляет им, вопль банши и немота.", "Baroness Anastari: possesses a player and controls him, also Banshee Wail and Silence."},
    [10437] = {"Неруб'энкан: зовёт склепных жуков и опутывает паутиной.", "Nerub'enkan: summons Crypt Scarabs and uses Encasing Webs."},
    [10438] = {"Малеки Бледный: ледяные стрелы, похищение жизни и ледяная гробница. Прерывайте.", "Maleki the Pallid: Frostbolt, Drain Life and Ice Tomb. Interrupt him."},
    [10439] = {"Рамштайн Ненасытный: выходит после трёх зиккуратов, топчет. После его смерти идёт волна нежити.", "Ramstein the Gorger: comes after the three ziggurats, Trample. After he dies a wave of undead attacks."},
    [10440] = {"Барон Ривендер: поднимает скелетов, Смертельный союз и смертельный удар. Скелетов бейте по площади.", "Baron Rivendare: Raise Dead skeletons, Death Pact and Mortal Strike. AoE the skeletons."},
}
-- How to find what a quest wants where the arrow alone is not enough: in caves of several
-- levels, behind a turn, inside a ruin (the owner, 15.11.2026, by the Uldaman portal: "I
-- run about looking for the Garrett chest and cannot find it; the hard quests need hints").
-- By quest id: {ru, en}. Checked against the Warcraft Wiki pages of the objects.
local HINTS = {
    -- The Vile Reef (Stranglethorn), a step of the Drowned City's chain
    [629] = {"Обломок таблички берут с каменной таблички «Гри'лек Странник» — это не NPC. Она на дне Коварного рифа, к западу от Гром'гола: ныряй к ней и щёлкни по ней.",
        "The Tablet Shard is taken from a stone tablet called \"Gri'lek the Wanderer\": it is not an NPC. It lies on the bottom of the Vile Reef, west of Grom'gol: dive to it and click it."},
    [95748] = {"Третье предание троллей берут с каменной таблички «Водопад Гурубаши» — это не NPC. Она на северо-западе Тернистой долины, у воды: подойди и щёлкни по ней.",
        "The Third Troll Legend is taken from a stone tablet called \"Fall of Gurubashi\": it is not an NPC. It is in the north-west of Stranglethorn, by the water: walk up and click it."},
    -- Uldaman, the tunnels before the portal
    [2342] = {"Сундук семейства Гарретт — в туннелях прямо перед порталом в Ульдаман (Южный общий зал), не внутри подземелья. Дойди до портала, встань к нему лицом и иди вдоль стены налево.",
        "The Garrett Family Chest is in the tunnels right in front of the Uldaman portal (South Common Hall), not inside the dungeon. Go to the portal, face it and follow the wall to the left."},
    [1360] = {"Сундук Крома Крепкорука — в туннелях перед порталом в Ульдаман, не внутри подземелья: войдёшь в портал — его там уже нет.",
        "Krom Stoutarm's Chest is in the tunnels in front of the Uldaman portal, not inside the dungeon: once through the portal it is gone."},
    [709] = {"Табличка лежит в Древнем сундуке, в пещерах перед порталом (Запечатанный зал). От входа в раскопки иди налево, потом в первый поворот налево в пещеры, вверх по небольшому склону, на развилке направо — сундук посреди зала.",
        "The tablet is in the Ancient Chest in the caves before the portal (Sealed Hall). From the entrance go left into the dig site, then the first left into the caverns, up the small slope, and right at the fork: the chest is in the middle of the room."},
    [722] = {"Амулет у Магрегана Чернотени — дворф Чёрного Железа 38 уровня прямо перед порталом в Ульдаман. Бьёт вихрем: не стойте вокруг него толпой.",
        "The amulet is on Magregan Deepshadow, a level 38 Dark Iron dwarf just outside the Uldaman portal. He uses Whirlwind: don't stand around him in a crowd."},
}
-- END LOOT
local russian = (GetLocale and GetLocale() or "enUS") == "ruRU"
P.BossNotes = {}
for npc, pair in pairs(NOTES) do P.BossNotes[npc] = russian and pair[1] or pair[2] end
-- Quests whose goal lies in the cave before a dungeon portal, by the dungeon (not text).
P.QuestCave = {[2342]="ULDA", [1360]="ULDA", [709]="ULDA", [722]="ULDA"}
P.QuestHints = {}
for id, pair in pairs(HINTS) do P.QuestHints[id] = russian and pair[1] or pair[2] end

-- BEGIN BOSS TIPS: generated by dungeon-quest-handoff/make-boss-tips.py from boss-tips.json; do not edit by hand
-- [boss] = what to do so the group lives: one or two short actions.
P.BossTips = {
    [639]=L"Когда здоровье падает, он зовёт помощников: переключитесь на них или возьмите под контроль.",
    [643]=L"Сначала разбейте его машину, затем убейте выпрыгнувшего Снида. Машина пугает.",
    [646]=L"На 66% и 33% он оглушает всех рядом и меняет оружие: лекарь стоит в стороне.",
    [647]=L"Танк разворачивает его спиной к группе — рассекающий удар. Снимайте яд.",
    [1663]=L"Его крик пугает всех рядом — не деритесь возле других врагов.",
    [1696]=L"На низком здоровье впадает в ярость — добивайте быстро.",
    [1717]=L"Не стойте кучей: цепная молния.",
    [1853]=L"Он переносит игроков в комнаты с нежитью: держитесь, пока не откроется дверь, и бегите назад.",
    [2748]=L"Он оживляет статуи по залу: танк их подбирает, а группа бьёт самого босса.",
    [3654]=L"Его сон, страх и оглушение бьют тех, кто рядом: лекарь держится на расстоянии.",
    [3669]=L"Прерывайте исцеление и Сон. Позже он станет змеем — снимайте яд.",
    [3670]=L"Прерывайте его исцеление и Сон.",
    [3671]=L"Прерывайте её исцеление. Снимайте Сон с танка.",
    [3673]=L"Прерывайте его исцеление и Сон.",
    [3674]=L"Не стойте кучей: его молния перескакивает на соседей.",
    [3872]=L"Танк держит его спиной к группе.",
    [3887]=L"Снимайте с танка проклятие — оно сильно режет лечение.",
    [3927]=L"С ним прибегают волки: танк собирает их, сначала убейте волков.",
    [3974]=L"С ним прибегают псы: танк собирает их, бейте областью.",
    [3975]=L"Когда он крутится Вихрем, все кроме танка отбегают. После его смерти набегут ученики.",
    [3976]=L"Вайтмейн скоро его воскресит — оставьте ману и силы на второй бой.",
    [3977]=L"На половине здоровья усыпит всех и воскресит Могрейна. Прерывайте её лечение.",
    [3983]=L"Снимайте с танка Слово Тьмы: Боль.",
    [4274]=L"Снимайте яд с танка.",
    [4275]=L"Он прыгает по залу — бегите к нему. Снимите проклятие с того, кого он превратил в воргена.",
    [4278]=L"Прерывайте его Свет небес — он лечится.",
    [4279]=L"С потерей здоровья бьёт всё сильнее — добивайте быстро.",
    [4421]=L"Прерывайте её лечение; не стойте кучей — цепная молния.",
    [4422]=L"На низком здоровье он звереет — держите сильные заклинания на конец.",
    [4424]=L"Прерывайте его лечение; призванного кабана танк забирает на себя.",
    [4428]=L"Он берёт игрока под контроль: обездвижьте его, а не убивайте.",
    [4543]=L"Отходите от огня под ногами; прерывайте Стрелу Тьмы.",
    [4829]=L"Выходите из ядовитого облака. На низком здоровье он звереет — держите силы на конец.",
    [4831]=L"Танк держит её спиной к группе: её молния бьёт конусом вперёд.",
    [4832]=L"Прерывайте его Взрыв разума; снимайте Сон с танка.",
    [4854]=L"Прерывайте его молнии; снимайте с танка уменьшение.",
    [5709]=L"Танк держит его мордой от группы; лекарь стоит вдали — он усыпляет всех рядом.",
    [5710]=L"Прерывайте его исцеление; подчинённого им игрока обездвижьте, а не убивайте.",
    [5711]=L"Снимайте с игроков проклятие; прерывайте Стрелу Тьмы.",
    [5719]=L"Танк держит дракона мордой от группы: дыхание кислотой.",
    [5720]=L"Танк держит дракона мордой от группы: дыхание кислотой.",
    [5721]=L"Танк держит дракона мордой от группы: дыхание кислотой.",
    [5722]=L"Танк держит дракона мордой от группы: дыхание кислотой.",
    [5775]=L"Его лозы сбивают с ног всех рядом — лекарь стоит подальше.",
    [6229]=L"Ближний бой, следите за здоровьем: его удар по площади бьёт и отбрасывает всех рядом.",
    [6235]=L"Не стойте кучей: его цепная молния перескакивает между игроками.",
    [6487]=L"Когда он окружает себя пузырём, все отбегают подальше — следом будет взрыв.",
    [6906]=L"Три дворфа дерутся вместе: разберите цели, одного возьмите под контроль.",
    [6910]=L"Прерывайте его молнии; не стойте кучей.",
    [7023]=L"От ударов он рассыпается на осколки — танк их собирает, бейте областью.",
    [7206]=L"Уклоняйтесь от песчаных смерчей — они ходят по залу.",
    [7228]=L"Танк держит её спиной к группе: её удар бьёт по дуге.",
    [7267]=L"Танк держит его спиной к группе: он бьёт рассекающим ударом.",
    [7271]=L"Убейте его тотем первым; зомби из могил держите на танке.",
    [7273]=L"Её удар подбрасывает всех рядом — лекарь стоит подальше.",
    [7275]=L"Прерывайте его исцеление; будьте готовы к страху.",
    [7291]=L"Его огненный взрыв бьёт всех рядом — лекарь стоит подальше.",
    [7355]=L"Снимайте яд и проклятие с танка.",
    [7357]=L"Прерывайте его Огненный шар.",
    [7358]=L"На половине здоровья появятся призраки — бейте их областью. Ближний бой, бойтесь Кольца льда.",
    [7361]=L"Защищайте Ими от волн троггов: если она погибнет, событие сорвётся.",
    [7604]=L"В бою у пирамиды держитесь наверху лестницы и бейте волны областью.",
    [7795]=L"Прерывайте её исцеление.",
    [7800]=L"Жмите кнопки у стен, откуда идут бомбы, а прорвавшиеся бомбы убивайте сразу.",
    [8127]=L"При потере здоровья зовёт василисков; его лечащий тотем убейте сразу.",
    [8443]=L"Сошедшего с ума игрока обездвижьте, а не убивайте; снимайте проклятия.",
    [8567]=L"На низком здоровье он звереет — держите силы на конец.",
    [8580]=L"Он отбрасывает всех рядом — лекарь и дальний бой стоят подальше.",
    [8983]=L"Зачистите големов в зале до боя — он их оживляет.",
    [9017]=L"Снимайте проклятие; он отбрасывает — танк стоит спиной к стене.",
    [9018]=L"Её крик вызывает страх — не деритесь возле других групп врагов.",
    [9019]=L"Прерывайте лечение принцессы Мойры, иначе бой затянется.",
    [9024]=L"Убейте его тотемы первыми.",
    [9025]=L"Его топот оглушает всех рядом — лекарь держится подальше.",
    [9027]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9028]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9029]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9030]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9031]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9032]=L"Сначала две волны врагов, потом случайный босс арены — берегите ману до него.",
    [9033]=L"На низком здоровье зовёт подмогу — добивайте его быстро.",
    [9039]=L"Дворфы выходят по одному, после смерти предыдущего — следите за маной лекаря.",
    [9156]=L"Убивайте огненных духов, пока они не дошли до него, иначе он усилится.",
    [9196]=L"Танк держит его спиной к стене и к группе: он отбрасывает и рассекает.",
    [9236]=L"Снимайте с игроков проклятие и сглаз.",
    [9568]=L"На половине здоровья зовёт двух помощников — возьмите их под контроль.",
    [9816]=L"Его огненная волна бьёт всех рядом — дальний бой держится подальше.",
    [9938]=L"Не стойте на пути огня из статуй в зале.",
    [10220]=L"Сразу после неё выйдет Гизрул — не тратьте все силы.",
    [10264]=L"Держитесь вместе у входа и не бегайте по яйцам — из них вылупятся драконы.",
    [10268]=L"На низком здоровье звереет — добивайте быстро.",
    [10363]=L"Сначала уведите или убейте двух стражей. Не стойте в огне на полу.",
    [10429]=L"Сначала много волн у ворот — держитесь у входа. Танк держит Гита мордой от группы.",
    [10339]=L"Сначала много волн у ворот — держитесь у входа. Танк держит Гита мордой от группы.",
    [10430]=L"Танк держит его у стены мордой от группы: он пугает и отбрасывает.",
    [10432]=L"Не стойте в огне на полу.",
    [10436]=L"Когда она вселяется в игрока, обездвижьте его, а не убивайте.",
    [10437]=L"Бейте его скарабеев областью; снимайте яд.",
    [10438]=L"Прерывайте его Ледяную стрелу и Похищение жизни.",
    [10439]=L"После его смерти хлынет волна нежити — восстановитесь и держитесь вместе.",
    [10440]=L"Он поднимает скелетов — бейте их областью; танк держит его спиной к группе.",
    [10502]=L"Ждите страх и подчинение: подчинённого игрока обездвижьте, а не убивайте.",
    [10503]=L"Она делится на иллюзии — бейте их областью, затем добейте настоящую.",
    [10505]=L"Прерывайте её лечение.",
    [10506]=L"Снимайте проклятия; игрока под его контролем обездвижьте, а не убивайте.",
    [10507]=L"Танк держит его спиной к группе: рассекает и топчет.",
    [10508]=L"Прерывайте его Ледяную стрелу; ближний бой, бойтесь Кольца льда.",
    [10596]=L"Снимайте яд с танка.",
    [10811]=L"Его огненный взрыв бьёт всех рядом — лекарь стоит подальше.",
    [10813]=L"Подчинённого им игрока обездвижьте; ждите страх и сон.",
    [10901]=L"Снимайте болезни, особенно с танка.",
    [10997]=L"Убивайте стрелков, которых он зовёт, или танк забирает их на себя.",
    [11261]=L"На низком здоровье звереет — добивайте быстро.",
    [11486]=L"Ближний бой, отходите, когда он крутится вихрем.",
    [11490]=L"Лечите игрока, которого он приносит в жертву.",
    [11496]=L"Сначала отключите пять пилонов. В бою он зовёт глаза — убивайте их.",
    [11517]=L"Танк держит его спиной к группе: он бьёт рассекающим ударом.",
    [11518]=L"Прерывайте его Жертвенный огонь и снимайте проклятие с танка.",
    [11519]=L"Снимайте яд с танка.",
    [11520]=L"Он бьёт огнём по всем рядом: лекарь и дальний бой стоят подальше.",
    [12201]=L"Её пылевое облако бьёт всех рядом — лекарь и дальний бой стоят подальше.",
    [12203]=L"Он отбрасывает танка — танкуйте спиной к стене.",
    [12258]=L"Танк держит его спиной к группе.",
    [12876]=L"Прерывайте его Ледяную стрелу; ближний бой, бойтесь Кольца льда.",
    [12902]=L"Убейте его тотемы первыми; прерывайте молнию.",
    [13280]=L"В бою появляются мелкие водные отродья — убивайте их.",
    [13282]=L"Когда он исчезает, появляются его отродья — бейте их областью. Снимайте яд.",
    [13601]=L"Не стойте перед ним: огнемёт бьёт конусом.",
    [14322]=L"Ближний бой, отходите, когда он крутится вихрем.",
    [14325]=L"Он зовёт двух помощников и пугает криком.",
    [14327]=L"Прерывайте её залп Стрел Тьмы.",
    [14354]=L"Бегите за ним по коридорам, пока он не начнёт драться; его бесов бейте областью.",
    [258905]=L"Не стойте рядом, когда он бьёт по земле — оглушает. На 30% лечится и ускоряется: добейте быстро.",
    [270882]=L"Не стойте рядом, когда он бьёт по земле — оглушает. На 30% лечится и ускоряется: добейте быстро.",
    [258924]=L"Сначала убейте или возьмите под контроль двух жриц — они его лечат. Танк держит его спиной к группе.",
    [270883]=L"Сначала убейте или возьмите под контроль двух жриц — они его лечат. Танк держит его спиной к группе.",
    [260042]=L"Когда союзника запирает в водяной пузырь, все бьют пузырь. Прерывайте залп водяных стрел.",
    [270884]=L"Когда союзника запирает в водяной пузырь, все бьют пузырь. Прерывайте залп водяных стрел.",
    [260202]=L"Убивайте его прислужников: каждый даёт +20% урона по боссу. Первыми — стражей, они оглушают.",
    [269586]=L"Убивайте его прислужников: каждый даёт +20% урона по боссу. Первыми — стражей, они оглушают.",
    [270885]=L"Убивайте его прислужников: каждый даёт +20% урона по боссу. Первыми — стражей, они оглушают.",
    [260243]=L"Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху.",
    [260274]=L"Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху.",
    [267852]=L"Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху.",
    [269466]=L"Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху.",
    [270886]=L"Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху.",
    [263886]=L"Возьмите подводное дыхание. Прерывайте его заклинание по площади — оно замедляет группу.",
    [270887]=L"Возьмите подводное дыхание. Прерывайте его заклинание по площади — оно замедляет группу.",
}
-- END BOSS TIPS

-- BEGIN INSIDE SPOTS: generated by dungeon-quest-handoff/make-inside-lua.py from inside-spots.json; do not edit by hand
-- [quest] = its goals inside: k dungeon, w what (ru, en), from who has it, spread or one place,
-- p = {atlas key, floor, x, y, nearest boss (npc), room ru, room en}.
P.InsideSpots = {
    [17]={{k="ULDA",kind="loot",item=8047,w={"Гриб-малиновик","Magenta Fungus Cap"},from={"Семейка грибов-малиновиков","Magenta Cap Clusters"},spread=true,p={{"ULDA",1,0.482,0.685,6910,"Зал Карт","Map Chamber"},{"ULDA",1,0.361,0.247,7291,nil,nil},{"ULDA",1,0.457,0.34,7206,"Зал Ремесленников","Hall of the Crafters"},{"ULDA",1,0.344,0.503,7023,nil,nil},{"ULDA",1,0.464,0.532,7206,nil,nil},{"ULDA",1,0.292,0.56,7023,"Пещера Эхомок","Echomok Cavern"}}}},
    [166]={{k="DM",kind="loot",item=3637,w={"Голова ван Клифа","Head of VanCleef"},from={"Эдвин ван Клиф","Edwin VanCleef"},spread=false,p={{"DM",2,0.606,0.459,639,"Потайная бухта","Ironclad Cove"}}}},
    [214]={{k="DM",kind="loot",item=915,w={"Красная шелковая бандана","Red Silk Bandana"},from={"Шахтер из Братства Справедливости","Defias Miner"},spread=true,p={{"DM",1,0.453,0.624,644,"Мертвые копи","The Deadmines"},{"DM",1,0.259,0.307,3586,"Мертвые копи","The Deadmines"},{"DM",1,0.603,0.834,643,"Мертвые копи","The Deadmines"},{"DM",1,0.283,0.508,644,"Мертвые копи","The Deadmines"},{"DM",2,0.153,0.602,1763,"Мертвые копи","The Deadmines"},{"DM",2,0.579,0.401,647,"Потайная бухта","Ironclad Cove"}}}},
    [377]={{k="STOCKS",kind="loot",item=3628,w={"Рука Декстрена Варда","Hand of Dextren Ward"},from={"Декстрен Вард","Dextren Ward"},spread=false,p={{"STOCKS",1,0.146,0.214,1720,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [378]={{k="STOCKS",kind="loot",item=3640,w={"Голова Гневливого","Head of Deepfury"},from={"Кам Гневливый","Kam Deepfury"},spread=false,p={{"STOCKS",1,0.692,0.309,1666,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [386]={{k="STOCKS",kind="loot",item=3630,w={"Голова Таргорра","Head of Targorr"},from={"Таргорр Ужасный","Targorr the Dread"},spread=false,p={{"STOCKS",1,0.499,0.242,1696,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [387]={{k="STOCKS",kind="kill",item=nil,w={"Узник из Братства Справедливости","Defias Prisoner"},from={"Узник из Братства Справедливости","Defias Prisoner"},spread=true,p={{"STOCKS",1,0.543,0.524,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.579,0.435,1666,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.493,0.355,1696,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.421,0.542,1720,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.399,0.276,1720,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.499,0.217,1696,"Тюрьма Штормграда","Stormwind Stockade"}}},{k="STOCKS",kind="kill",item=nil,w={"Каторжник из Братства Справедливости","Defias Convict"},from={"Каторжник из Братства Справедливости","Defias Convict"},spread=true,p={{"STOCKS",1,0.65,0.462,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.724,0.595,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.627,0.361,1666,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.445,0.362,1696,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.689,0.381,1666,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.64,0.26,1666,"Тюрьма Штормграда","Stormwind Stockade"}}},{k="STOCKS",kind="kill",item=nil,w={"Мятежник из Братства Справедливости","Defias Insurgent"},from={"Мятежник из Братства Справедливости","Defias Insurgent"},spread=true,p={{"STOCKS",1,0.782,0.496,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.737,0.566,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.598,0.366,1666,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.602,0.481,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.676,0.436,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.615,0.293,1666,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [388]={{k="STOCKS",kind="loot",item=2909,w={"Красная шерстяная бандана","Red Wool Bandana"},from={"Декстрен Вард","Dextren Ward"},spread=true,p={{"STOCKS",1,0.33,0.287,1720,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.623,0.408,1666,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.146,0.214,1720,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.507,0.552,1717,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.389,0.437,1720,"Тюрьма Штормграда","Stormwind Stockade"},{"STOCKS",1,0.25,0.15,1720,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [391]={{k="STOCKS",kind="loot",item=2926,w={"Голова Базиля Тредда","Head of Bazil Thredd"},from={"Базиль Тредд","Bazil Thredd"},spread=false,p={{"STOCKS",1,0.864,0.52,1716,"Тюрьма Штормграда","Stormwind Stockade"}}}},
    [914]={{k="WC",kind="loot",item=9738,w={"Самоцвет Кобрана","Gem of Cobrahn"},from={"Лорд Кобран","Lord Cobrahn"},spread=false,p={{"WC",1,0.156,0.585,3669,"Змеиная яма","Pit of Fangs"}}},{k="WC",kind="loot",item=9739,w={"Самоцвет Анакондры","Gem of Anacondra"},from={"Повелительница Анакондра","Lady Anacondra"},spread=false,p={{"WC",1,0.281,0.318,3671,"Овраг Воплей","Screaming Gully"}}},{k="WC",kind="loot",item=9740,w={"Самоцвет Питонаса","Gem of Pythas"},from={"Лорд Питонас","Lord Pythas"},spread=false,p={{"WC",1,0.856,0.284,3673,"Извилистая расщелина","Winding Chasm"}}},{k="WC",kind="loot",item=9741,w={"Самоцвет Серпентиса","Gem of Serpentis"},from={"Лорд Серпентис","Lord Serpentis"},spread=false,p={{"WC",1,0.625,0.536,3673,"Утес Вечноживущего","Crag of the Everliving"}}}},
    [962]={{k="WC",kind="loot",item=5339,w={"Змеецвет","Serpentbloom"},from={"Змеецвет","Serpentbloom"},spread=true,p={{"WC",1,0.531,0.417,3670,"Овраг Воплей","Screaming Gully"},{"WC",1,0.312,0.393,3653,"Овраг Воплей","Screaming Gully"},{"WC",1,0.442,0.297,3654,"Овраг Воплей","Screaming Gully"},{"WC",1,0.305,0.269,3654,"Овраг Воплей","Screaming Gully"},{"WC",1,0.147,0.497,3669,"Змеиная яма","Pit of Fangs"},{"WC",1,0.159,0.338,3671,"Змеиная яма","Pit of Fangs"}}}},
    [971]={{k="BFD",kind="loot",item=5359,w={"Манускрипт Лоргалиса","Lorgalis Manuscript"},from={"Ржавый железный сундук","Pitted Iron Chest"},spread=false,p={{"BFD",1,0.329,0.412,4887,"Пруд Аск'ара","The Pool of Ask'ar"}}}},
    [1013]={{k="SFK",kind="loot",item=6283,w={"Книга Ура","The Book of Ur"},from={"Книга Ура","The Book of Ur"},spread=false,p={{"SFK",5,0.463,0.626,4274,"Крепость Темного Клыка","Shadowfang Keep"}}}},
    [1014]={{k="SFK",kind="loot",item=5442,w={"Голова Аругала","Head of Arugal"},from={"Верховный маг Аругал","Archmage Arugal"},spread=true,p={{"SFK",7,0.639,0.2,4275,"Крепость Темного Клыка","Shadowfang Keep"},{"SFK",1,0.577,0.57,4279,"Крепость Темного Клыка","Shadowfang Keep"}}}},
    [1048]={{k="SM",kind="kill",item=nil,w={"Верховный инквизитор Вайтмейн","High Inquisitor Whitemane"},from={"Верховный инквизитор Вайтмейн","High Inquisitor Whitemane"},spread=false,p={{"SM_CATH",1,0.49,0.169,3977,"Часовня Ордена","Crusader's Chapel"}}},{k="SM",kind="kill",item=nil,w={"Командир Могрейн из Алого ордена","Scarlet Commander Mograine"},from={"Командир Могрейн из Алого ордена","Scarlet Commander Mograine"},spread=false,p={{"SM_CATH",1,0.491,0.272,3976,"Часовня Ордена","Crusader's Chapel"}}},{k="SM",kind="kill",item=nil,w={"Герод","Herod"},from={"Герод","Herod"},spread=false,p={{"SM_ARM",1,0.786,0.108,3975,"Чертог Защитников","Hall of Champions"}}},{k="SM",kind="kill",item=nil,w={"Псарь Локси","Houndmaster Loksey"},from={"Псарь Локси","Houndmaster Loksey"},spread=false,p={{"SM_LIB",1,0.308,0.878,3974,nil,nil}}}},
    [1049]={{k="SM",kind="loot",item=5535,w={"\"Компендиум павших\"","Compendium of the Fallen"},from={"\"Компендиум павших\"","Compendium of the Fallen"},spread=false,p={{"SM_LIB",1,0.822,0.14,6487,"Читальня","Athenaeum"}}}},
    [1050]={{k="SM",kind="loot",item=5536,w={"\"Мифология Титанов\"","Mythology of the Titans"},from={"\"Мифология Титанов\"","Mythology of the Titans"},spread=false,p={{"SM_LIB",1,0.593,0.122,6487,nil,nil}}}},
    [1053]={{k="SM",kind="kill",item=nil,w={"Верховный инквизитор Вайтмейн","High Inquisitor Whitemane"},from={"Верховный инквизитор Вайтмейн","High Inquisitor Whitemane"},spread=false,p={{"SM_CATH",1,0.49,0.169,3977,"Часовня Ордена","Crusader's Chapel"}}},{k="SM",kind="kill",item=nil,w={"Командир Могрейн из Алого ордена","Scarlet Commander Mograine"},from={"Командир Могрейн из Алого ордена","Scarlet Commander Mograine"},spread=false,p={{"SM_CATH",1,0.491,0.272,3976,"Часовня Ордена","Crusader's Chapel"}}},{k="SM",kind="kill",item=nil,w={"Герод","Herod"},from={"Герод","Herod"},spread=false,p={{"SM_ARM",1,0.786,0.108,3975,"Чертог Защитников","Hall of Champions"}}},{k="SM",kind="kill",item=nil,w={"Псарь Локси","Houndmaster Loksey"},from={"Псарь Локси","Houndmaster Loksey"},spread=false,p={{"SM_LIB",1,0.308,0.878,3974,nil,nil}}}},
    [1101]={{k="RFK",kind="loot",item=5792,w={"Медальон Чарлги Остробок","Razorflank's Medallion"},from={"Чарлга Остробок","Charlga Razorflank"},spread=false,p={{"RFK",1,0.264,0.324,4421,"Лабиринты Иглошкурых","Razorfen Kraul"}}}},
    [1102]={{k="RFK",kind="loot",item=5793,w={"Сердце Чарлги Остробок","Razorflank's Heart"},from={"Чарлга Остробок","Charlga Razorflank"},spread=false,p={{"RFK",1,0.264,0.324,4421,"Лабиринты Иглошкурых","Razorfen Kraul"}}}},
    [1109]={{k="RFK",kind="loot",item=5801,w={"Гуано летучей мыши Лабиринтов","Kraul Guano"},from={"Лабиринтовый нетопырь","Kraul Bat"},spread=true,p={{"RFK",1,0.096,0.403,4425,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.162,0.545,4422,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.102,0.478,4425,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.114,0.327,4425,"Лабиринты Иглошкурых","Razorfen Kraul"}}}},
    [1113]={{k="SM",kind="loot",item=5805,w={"Сердце Доблести","Heart of Zeal"},from={"Псарь Локси","Houndmaster Loksey"},spread=true,p={{"SM_CATH",1,0.496,0.373,3976,"Часовня Ордена","Crusader's Chapel"},{"SM_ARM",1,0.716,0.248,3975,"Оружейная Рыцарей","Crusader's Armory"},{"SM_ARM",1,0.741,0.375,3975,"Оружейная Рыцарей","Crusader's Armory"},{"SM_CATH",1,0.489,0.512,3976,"Церковные сады","Chapel Gardens"},{"SM_ARM",1,0.665,0.755,3975,"Тренировочная площадка","Training Grounds"},{"SM_CATH",1,0.52,0.835,3976,"Церковные сады","Chapel Gardens"}}}},
    [1139]={{k="ULDA",kind="loot",item=5824,w={"Табличка Воли","Tablet of Will"},from={"Табличка Воли","Tablet of Will"},spread=false,p={{"ULDA",1,0.25,0.346,7291,"Третий раскоп","Dig Three"}}}},
    [1142]={{k="RFK",kind="loot",item=5825,w={"Подвеска Трешалы","Treshala's Pendant"},from={"Властитель Таранный Клык","Overlord Ramtusk"},spread=true,p={{"RFK",1,0.749,0.386,6168,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.649,0.477,6168,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.853,0.42,4428,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.291,0.349,4421,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.612,0.326,4438,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.717,0.702,4424,"Лабиринты Иглошкурых","Razorfen Kraul"}}}},
    [1160]={{k="SM",kind="loot",item=5861,w={"\"Истоки угрозы нежити\"","Beginnings of the Undead Threat"},from={"\"Истоки угрозы нежити\"","Beginnings of the Undead Threat"},spread=false,p={{"SM_LIB",1,0.454,0.322,6487,"Сокровищница","Gallery of Treasures"}}}},
    [1199]={{k="BFD",kind="loot",item=5879,w={"Подвеска Сумерек","Twilight Pendant"},from={"Служитель из культа Сумеречного Молота","Twilight Acolyte"},spread=true,p={{"BFD",2,0.455,0.807,4832,"Руины святилища Луны","Moonshrine Ruins"},{"BFD",2,0.407,0.652,12876,"Руины святилища Луны","Moonshrine Ruins"},{"BFD",2,0.334,0.69,12876,"Руины святилища Луны","Moonshrine Ruins"},{"BFD",2,0.501,0.865,4832,"Алтарь святилища Луны","Moonshrine Sanctum"},{"BFD",2,0.412,0.724,12876,"Руины святилища Луны","Moonshrine Ruins"},{"BFD",2,0.526,0.757,4832,"Алтарь святилища Луны","Moonshrine Sanctum"}}}},
    [1200]={{k="BFD",kind="loot",item=5881,w={"Голова Келриса","Head of Kelris"},from={"Повелитель сумрака Келрис","Twilight Lord Kelris"},spread=false,p={{"BFD",2,0.519,0.816,4832,"Алтарь святилища Луны","Moonshrine Sanctum"}}}},
    [1221]={{k="RFK",kind="loot",item=5876,w={"Корень синелиста","Blueleaf Tuber"},from={"Корень синелиста","Blueleaf Tuber"},spread=true,p={{"RFK",1,0.483,0.547,4842,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.702,0.392,6168,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.504,0.387,4438,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.395,0.6,4842,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.314,0.312,4421,"Лабиринты Иглошкурых","Razorfen Kraul"},{"RFK",1,0.26,0.65,4422,"Лабиринты Иглошкурых","Razorfen Kraul"}}}},
    [1275]={{k="BFD",kind="loot",item=5952,w={"Оскверненный ствол мозга","Corrupted Brain Stem"},from={"Тенелов из племени Змеящегося Корня","Fallenroot Shadowstalker"},spread=true,p={{"BFD",2,0.394,0.3,12902,"Непроглядная Пучина","Blackfathom Deeps"},{"BFD",1,0.406,0.921,4887,"Непроглядная Пучина","Blackfathom Deeps"},{"BFD",1,0.246,0.549,4887,"Пруд Аск'ара","The Pool of Ask'ar"},{"BFD",1,0.182,0.406,4831,"Непроглядная Пучина","Blackfathom Deeps"},{"BFD",1,0.517,0.844,6243,"Непроглядная Пучина","Blackfathom Deeps"},{"BFD",2,0.315,0.596,12902,"Непроглядная Пучина","Blackfathom Deeps"}}}},
    [1318]={{k="DMAUL",kind="loot",item=18336,w={"Латная рукавица мощи Гордока","Gauntlet of Gordok Might"},from={"Сундук принца","The Prince's Chest"},spread=false,p={{"DM_W",3,0.582,0.268,11486,"Читальня","The Athenaeum"}}}},
    [1445]={{k="ST",kind="loot",item=6181,w={"Фетиш Хаккара","Fetish of Hakkar"},from={"Воин из племени Атал'ай","Atal'ai Warrior"},spread=true,p={{"ST",1,0.747,0.458,5711,"Обитель Избранного","Lair of the Chosen"},{"ST",1,0.567,0.271,nil,"Зал Проклятых","Hall of the Cursed"},{"ST",1,0.428,0.318,nil,"Храм Атал'Хаккар","The Temple of Atal'Hakkar"},{"ST",1,0.547,0.644,5708,"Зал Проклятых","Hall of the Cursed"},{"ST",1,0.449,0.638,8580,"Зал Проклятых","Hall of the Cursed"},{"ST",1,0.398,0.458,5721,"Жертвенный колодец","The Pit of Sacrifice"}}}},
    [1446]={{k="ST",kind="loot",item=6212,w={"Голова Джаммалана","Head of Jammal'an"},from={"Джаммал'ан Пророк","Jammal'an the Prophet"},spread=false,p={{"ST",1,0.761,0.368,5710,"Обитель Избранного","Lair of the Chosen"}}}},
    [1486]={{k="WC",kind="loot",item=6443,w={"Искаженная шкура","Deviate Hide"},from={"Загадочный опустошитель","Deviate Ravager"},spread=true,p={{"WC",1,0.471,0.429,3670,"Овраг Воплей","Screaming Gully"},{"WC",1,0.372,0.323,3653,"Овраг Воплей","Screaming Gully"},{"WC",1,0.095,0.47,3671,"Змеиная яма","Pit of Fangs"},{"WC",1,0.552,0.653,5775,"Утес Вечноживущего","Crag of the Everliving"},{"WC",1,0.13,0.316,3671,"Змеиная яма","Pit of Fangs"},{"WC",1,0.369,0.459,3653,"Пещеры Стенаний","The Wailing Caverns"}}}},
    [1487]={{k="WC",kind="kill",item=nil,w={"Загадочный опустошитель","Deviate Ravager"},from={"Загадочный опустошитель","Deviate Ravager"},spread=true,p={{"WC",1,0.471,0.429,3670,"Овраг Воплей","Screaming Gully"},{"WC",1,0.369,0.459,3653,"Пещеры Стенаний","The Wailing Caverns"},{"WC",1,0.414,0.29,3654,"Овраг Воплей","Screaming Gully"},{"WC",1,0.342,0.514,3653,"Пещеры Стенаний","The Wailing Caverns"},{"WC",1,0.375,0.399,3653,"Овраг Воплей","Screaming Gully"}}},{k="WC",kind="kill",item=nil,w={"Загадочная гадюка","Deviate Viper"},from={"Загадочная гадюка","Deviate Viper"},spread=true,p={{"WC",1,0.113,0.332,3671,"Змеиная яма","Pit of Fangs"},{"WC",1,0.196,0.421,3671,"Змеиная яма","Pit of Fangs"},{"WC",1,0.115,0.506,3669,"Змеиная яма","Pit of Fangs"},{"WC",1,0.086,0.413,3671,"Змеиная яма","Pit of Fangs"}}},{k="WC",kind="kill",item=nil,w={"Загадочный шаркун","Deviate Shambler"},from={"Загадочный шаркун","Deviate Shambler"},spread=true,p={{"WC",1,0.753,0.454,3673,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.65,0.403,3670,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.765,0.3,3670,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.546,0.696,5775,"Утес Вечноживущего","Crag of the Everliving"},{"WC",1,0.574,0.897,5775,"Утес Вечноживущего","Crag of the Everliving"},{"WC",1,0.686,0.62,3673,"Утес Вечноживущего","Crag of the Everliving"}}},{k="WC",kind="kill",item=nil,w={"Загадочный страхозуб","Deviate Dreadfang"},from={"Загадочный страхозуб","Deviate Dreadfang"},spread=true,p={{"WC",1,0.71,0.831,5775,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.833,0.792,5775,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.596,0.576,3673,"Утес Вечноживущего","Crag of the Everliving"},{"WC",1,0.805,0.586,3673,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.931,0.545,3673,"Извилистая расщелина","Winding Chasm"},{"WC",1,0.864,0.697,5775,"Извилистая расщелина","Winding Chasm"}}}},
    [1491]={{k="WC",kind="loot",item=6464,w={"Воющая субстанция","Wailing Essence"},from={"Изменчивая эктоплазма","Evolving Ectoplasm"},spread=true,p={{"WC",1,0.415,0.376,3670,"Овраг Воплей","Screaming Gully"},{"WC",1,0.401,0.471,3653,"Пещеры Стенаний","The Wailing Caverns"},{"WC",1,0.377,0.246,3654,"Овраг Воплей","Screaming Gully"},{"WC",1,0.17,0.406,3671,"Змеиная яма","Pit of Fangs"},{"WC",1,0.536,0.674,5775,"Утес Вечноживущего","Crag of the Everliving"},{"WC",1,0.572,0.895,5775,"Утес Вечноживущего","Crag of the Everliving"}}}},
    [2040]={{k="DM",kind="loot",item=7365,w={"Зубчатый спрек-механизм гномов","Gnoam Sprecklesprocket"},from={"Крошшер Снида","Sneed's Shredder"},spread=false,p={{"DM",1,0.493,0.871,643,"Мачтовая мастерская","Mast Room"}}}},
    [2201]={{k="ULDA",kind="loot",item=7669,w={"Рубин поврежденного ожерелья","Shattered Necklace Ruby"},from={"Тайник Кузни Теней","Shadowforge Cache"},spread=false,p={{"ULDA",1,0.259,0.307,7291,"Третий раскоп","Dig Three"}}},{k="ULDA",kind="loot",item=7670,w={"Сапфир поврежденного ожерелья","Shattered Necklace Sapphire"},from={"Гримлок","Grimlok"},spread=false,p={{"ULDA",1,0.212,0.248,4854,"Каменный свод","The Stone Vault"}}},{k="ULDA",kind="loot",item=7671,w={"Топаз поврежденного ожерелья","Shattered Necklace Topaz"},from={"Подозрительная урна","Conspicuous Urn"},spread=false,p={{"ULDA",1,0.629,0.932,6906,"Второй раскоп","Dig Two"}}}},
    [2202]={{k="ULDA",kind="loot",item=8047,w={"Гриб-малиновик","Magenta Fungus Cap"},from={"Семейка грибов-малиновиков","Magenta Cap Clusters"},spread=true,p={{"ULDA",1,0.482,0.685,6910,"Зал Карт","Map Chamber"},{"ULDA",1,0.361,0.247,7291,nil,nil},{"ULDA",1,0.457,0.34,7206,"Зал Ремесленников","Hall of the Crafters"},{"ULDA",1,0.344,0.503,7023,nil,nil},{"ULDA",1,0.464,0.532,7206,nil,nil},{"ULDA",1,0.292,0.56,7023,"Пещера Эхомок","Echomok Cavern"}}}},
    [2204]={{k="ULDA",kind="loot",item=7672,w={"Источник Силы поврежденного ожерелья","Shattered Necklace Power Source"},from={"Аркедас","Archaedas"},spread=false,p={{"ULDA",2,0.554,0.506,2748,"Трон Каз'горота","Khaz'goroth's Seat"}}}},
    [2283]={{k="ULDA",kind="loot",item=7666,w={"Поврежденное ожерелье","Shattered Necklace"},from={"Камнеед из племени Каменного Свода","Stonevault Rockchewer"},spread=true,p={{"ULDA",1,0.577,0.73,6910,"Зал Хранителей","Hall of the Keepers"},{"ULDA",1,0.569,0.807,6910,"Зал Хранителей","Hall of the Keepers"},{"ULDA",1,0.623,0.636,6910,"Зал Хранителей","Hall of the Keepers"},{"ULDA",1,0.631,0.905,nil,"Второй раскоп","Dig Two"},{"ULDA",1,0.632,0.814,nil,"Зал Хранителей","Hall of the Keepers"},{"ULDA",1,0.532,0.643,6910,"Зал Хранителей","Hall of the Keepers"}}}},
    [2339]={{k="ULDA",kind="loot",item=7669,w={"Рубин поврежденного ожерелья","Shattered Necklace Ruby"},from={"Тайник Кузни Теней","Shadowforge Cache"},spread=false,p={{"ULDA",1,0.259,0.307,7291,"Третий раскоп","Dig Three"}}},{k="ULDA",kind="loot",item=7670,w={"Сапфир поврежденного ожерелья","Shattered Necklace Sapphire"},from={"Гримлок","Grimlok"},spread=false,p={{"ULDA",1,0.212,0.248,4854,"Каменный свод","The Stone Vault"}}},{k="ULDA",kind="loot",item=7671,w={"Топаз поврежденного ожерелья","Shattered Necklace Topaz"},from={"Подозрительная урна","Conspicuous Urn"},spread=false,p={{"ULDA",1,0.629,0.932,6906,"Второй раскоп","Dig Two"}}},{k="ULDA",kind="loot",item=7672,w={"Источник Силы поврежденного ожерелья","Shattered Necklace Power Source"},from={"Аркедас","Archaedas"},spread=false,p={{"ULDA",2,0.554,0.506,2748,"Трон Каз'горота","Khaz'goroth's Seat"}}}},
    [2418]={{k="ULDA",kind="loot",item=8009,w={"Дентриевый камень Силы","Dentrium Power Stone"},from={"Тенегорнский охотник за реликвиями","Shadowforge Relic Hunter"},spread=true,p={{"ULDA",1,0.259,0.322,7291,"Третий раскоп","Dig Three"},{"ULDA",1,0.315,0.613,7023,"Пещера Эхомок","Echomok Cavern"}}},{k="ULDA",kind="loot",item=8052,w={"Камень могущества Ан'Аллеума","An'Alleum Power Stone"},from={"Тенегорнский охотник за реликвиями","Shadowforge Relic Hunter"},spread=true,p={{"ULDA",1,0.259,0.322,7291,"Третий раскоп","Dig Three"},{"ULDA",1,0.315,0.613,7023,"Пещера Эхомок","Echomok Cavern"}}}},
    [2768]={{k="ZF",kind="loot",item=8548,w={"Изыскательский стержень","Divino-matic Rod"},from={"Сержант Блай","Sergeant Bly"},spread=false,p={{"ZF",1,0.235,0.183,7604,nil,nil}}}},
    [2841]={{k="GNOMER",kind="loot",item=9153,w={"Чертежи буровой установки","Rig Blueprints"},from={"Предохранитель Термоштепселя","Thermaplugg's Safe"},spread=false,p={{"GNOMER",4,0.354,0.177,7800,"Двор Механиков","Tinkers' Court"}}},{k="GNOMER",kind="loot",item=9299,w={"Код от сейфа Термоштепселя","Thermaplugg's Safe Combination"},from={"Мекжинер Термоштепсель","Mekgineer Thermaplugg"},spread=false,p={{"GNOMER",4,0.313,0.3,7800,"Двор Механиков","Tinkers' Court"}}}},
    [2846]={{k="ZF",kind="loot",item=9234,w={"Тиара Глубин","Tiara of the Deep"},from={"Гидромант Велрата","Hydromancer Velratha"},spread=false,p={{"ZF",1,0.299,0.383,7795,"Зул'Фаррак","Zul'Farrak"}}}},
    [2865]={{k="ZF",kind="loot",item=9238,w={"Нерасколотый панцирь скарабея","Uncracked Scarab Shell"},from={"Скарабей","Scarab"},spread=true,p={{"ZF",1,0.534,0.269,7272,nil,nil},{"ZF",1,0.503,0.431,10082,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.411,0.516,10080,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.579,0.58,10080,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.493,0.577,10080,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.344,0.182,10081,"Зул'Фаррак","Zul'Farrak"}}}},
    [2924]={{k="GNOMER",kind="loot",item=9278,w={"Важнейший артефакт","Essential Artificial"},from={"Искусственный экстраполятор","Artificial Extrapolator"},spread=true,p={{"GNOMER",2,0.325,0.775,6235,"Пусковая установка","Launch Bay"},{"GNOMER",2,0.55,0.579,6235,"Гномреган","Gnomeregan"},{"GNOMER",3,0.25,0.167,6229,"Пусковая установка","Launch Bay"},{"GNOMER",2,0.189,0.815,6235,"Пусковая установка","Launch Bay"},{"GNOMER",2,0.645,0.467,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.32,0.573,6235,"Пусковая установка","Launch Bay"}}}},
    [2926]={{k="GNOMER",kind="loot",item=9284,w={"Наполненный свинцовый коллекционный фиал","Full Leaden Collection Phial"},from={"Облученный погромщик","Irradiated Pillager"},spread=true,p={{"GNOMER",1,0.425,0.684,7079,"Безопасная зона","The Clean Zone"},{"GNOMER",2,0.72,0.681,6235,"Спальни","The Dormitory"},{"GNOMER",1,0.495,0.637,7079,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.852,0.733,6235,"Спальни","The Dormitory"},{"GNOMER",2,0.804,0.845,6235,"Спальни","The Dormitory"},{"GNOMER",1,0.409,0.56,7079,"Машинный зал","The Hall of Gears"}}}},
    [2928]={{k="GNOMER",kind="loot",item=9309,w={"Механические внутренности робота","Robo-mechanical Guts"},from={"Землеглот из пещерных глубин","Caverndeep Burrower"},spread=true,p={{"GNOMER",4,0.368,0.665,6228,"Гномреган","Gnomeregan"},{"GNOMER",2,0.267,0.524,6235,"Пусковая установка","Launch Bay"},{"GNOMER",2,0.795,0.721,6235,"Спальни","The Dormitory"},{"GNOMER",3,0.632,0.709,6229,"Гномреган","Gnomeregan"},{"GNOMER",4,0.287,0.601,6228,"Гномреган","Gnomeregan"},{"GNOMER",2,0.13,0.57,6235,"Пусковая установка","Launch Bay"}}}},
    [2929]={{k="GNOMER",kind="kill",item=nil,w={"Мекжинер Термоштепсель","Mekgineer Thermaplugg"},from={"Мекжинер Термоштепсель","Mekgineer Thermaplugg"},spread=false,p={{"GNOMER",4,0.313,0.3,7800,"Двор Механиков","Tinkers' Court"}}}},
    [2930]={{k="GNOMER",kind="loot",item=9316,w={"Призматическая перфокарта","Prismatic Punch Card"},from={"Матричный перфограф 3005-D","Matrix Punchograph 3005-D"},spread=false,p={{"GNOMER",4,0.624,0.863,6228,"Инженерные лаборатории","Engineering Labs "}}}},
    [2951]={{k="GNOMER",kind="loot",item=9308,w={"Предмет, покрытый грязью","Grime-Encrusted Object"},from={"Землеглот из пещерных глубин","Caverndeep Burrower"},spread=true,p={{"GNOMER",1,0.402,0.635,7079,"Спальни","The Dormitory"},{"GNOMER",2,0.795,0.721,6235,"Спальни","The Dormitory"},{"GNOMER",4,0.368,0.665,6228,"Гномреган","Gnomeregan"},{"GNOMER",1,0.537,0.636,7079,"Машинный зал","The Hall of Gears"},{"GNOMER",1,0.41,0.731,7079,"Безопасная зона","The Clean Zone"},{"GNOMER",4,0.287,0.601,6228,"Гномреган","Gnomeregan"}}}},
    [2962]={{k="GNOMER",kind="loot",item=9365,w={"Высокомощные радиоактивные осадки","High Potency Radioactive Fallout"},from={"Облученная слизь","Irradiated Slime"},spread=true,p={{"GNOMER",2,0.759,0.406,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.758,0.536,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.832,0.391,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.728,0.336,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.692,0.403,6235,"Машинный зал","The Hall of Gears"},{"GNOMER",2,0.834,0.53,6235,"Машинный зал","The Hall of Gears"}}}},
    [3042]={{k="ZF",kind="loot",item=9523,w={"Троллье месиво","Troll Temper"},from={"Темный чародей из племени Песчаной Бури","Sandfury Shadowcaster"},spread=true,p={{"ZF",1,0.547,0.454,10082,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.331,0.455,7273,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.331,0.164,10081,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.45,0.537,10080,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.564,0.586,10080,"Зул'Фаррак","Zul'Farrak"},{"ZF",1,0.283,0.382,7795,"Зул'Фаррак","Zul'Farrak"}}}},
    [3341]={{k="RFD",kind="loot",item=10420,w={"Череп Холодоноса","Skull of the Coldbringer"},from={"Амненнар Хладовей","Amnennar the Coldbringer"},spread=false,p={{"RFD",1,0.45,0.591,7358,"Тернистый серпантин","Spiral of Thorns"}}}},
    [3527]={{k="ZF",kind="loot",item=10660,w={"Первая табличка Мошару","First Mosh'aru Tablet"},from={"Тека Мученик","Theka the Martyr"},spread=false,p={{"ZF",1,0.553,0.297,7272,"Зул'Фаррак","Zul'Farrak"}}},{k="ZF",kind="loot",item=10661,w={"Вторая табличка Мошару","Second Mosh'aru Tablet"},from={"Гидромант Велрата","Hydromancer Velratha"},spread=false,p={{"ZF",1,0.299,0.383,7795,"Зул'Фаррак","Zul'Farrak"}}}},
    [3636]={{k="RFD",kind="kill",item=nil,w={"Амненнар Хладовей","Amnennar the Coldbringer"},from={"Амненнар Хладовей","Amnennar the Coldbringer"},spread=false,p={{"RFD",1,0.45,0.591,7358,"Тернистый серпантин","Spiral of Thorns"}}}},
    [3802]={{k="BRD",kind="loot",item=10999,w={"Железный Друг","Ironfel"},from={"Точень Темнострой","Fineous Darkvire"},spread=false,p={{"BRD",1,0.616,0.238,9056,"Зал Ремесла","Hall of Crafting"}}}},
    [3907]={{k="BRD",kind="kill",item=nil,w={"Лорд Опалитель","Lord Incendius"},from={"Лорд Опалитель","Lord Incendius"},spread=false,p={{"BRD",1,0.561,0.312,9017,"Тенегорн","Shadowforge City"}}},{k="BRD",kind="loot",item=11126,w={"Табличка Каринья","Tablet of Kurniya"},from={"Лорд Опалитель","Lord Incendius"},spread=false,p={{"BRD",1,0.561,0.312,9017,"Тенегорн","Shadowforge City"}}}},
    [3982]={{k="BRD",kind="kill",item=nil,w={"Командир Гор'шак","Commander Gor'shak"},from={"Командир Гор'шак","Commander Gor'shak"},spread=false,p={{"BRD",1,0.498,0.868,9018,"Тюремный блок","Detention Block"}}}},
    [4001]={{k="BRD",kind="kill",item=nil,w={"Каран Могучий Молот","Kharan Mighthammer"},from={"Каран Могучий Молот","Kharan Mighthammer"},spread=false,p={{"BRD",1,0.521,0.819,9024,"Тюремный блок","Detention Block"}}}},
    [4003]={{k="BRD",kind="kill",item=nil,w={"Император Дагран Тауриссан","Emperor Dagran Thaurissan"},from={"Император Дагран Тауриссан","Emperor Dagran Thaurissan"},spread=false,p={{"BRD",2,0.932,0.119,9019,"Императорский Трон","The Imperial Seat"}}}},
    [4024]={{k="BRD",kind="loot",item=11230,w={"Пойманная сущность огня","Encased Fiery Essence"},from={"Бейл'Гор","Bael'Gar"},spread=false,p={{"BRD",1,0.24,0.516,9016,"Тракт Черного Железа","Dark Iron Highway"}}}},
    [4063]={{k="BRD",kind="loot",item=11268,w={"Голова Аргелмаха","Head of Argelmach"},from={"Повелитель големов Аргелмах","Golem Lord Argelmach"},spread=false,p={{"BRD",2,0.369,0.65,8983,"Фабрика","The Manufactory"}}},{k="BRD",kind="loot",item=11269,w={"Невредимое ядро элементаля","Intact Elemental Core"},from={"Создание-завоеватель","Warbringer Construct"},spread=true,p={{"BRD",1,0.649,0.242,9056,"Зал Ремесла","Hall of Crafting"},{"BRD",2,0.345,0.69,8983,"Фабрика","The Manufactory"},{"BRD",2,0.483,0.369,8923,"Литейная","Mold Foundry"},{"BRD",2,0.607,0.683,9502,"Черное Хранилище","The Black Vault"},{"BRD",1,0.65,0.302,9041,"Зал Ремесла","Hall of Crafting"},{"BRD",2,0.408,0.707,8983,"Фабрика","The Manufactory"}}}},
    [4081]={{k="BRD",kind="kill",item=nil,w={"Охранник из клана Ярости Горна","Anvilrage Guardsman"},from={"Охранник из клана Ярости Горна","Anvilrage Guardsman"},spread=true,p={{"BRD",1,0.442,0.612,9025,"Восточный гарнизон","East Garrison"},{"BRD",1,0.446,0.865,9018,"Тюремный блок","Detention Block"},{"BRD",1,0.537,0.567,9025,"Галереи Правосудия","Halls of the Law"},{"BRD",1,0.526,0.872,9018,"Тюремный блок","Detention Block"},{"BRD",1,0.543,0.711,9024,"Галереи Правосудия","Halls of the Law"},{"BRD",2,0.474,0.827,9027,"Восточный гарнизон","East Garrison"}}},{k="BRD",kind="kill",item=nil,w={"Надсмотрщик из клана Ярости Горна","Anvilrage Warden"},from={"Надсмотрщик из клана Ярости Горна","Anvilrage Warden"},spread=true,p={{"BRD",1,0.438,0.757,9024,"Тюремный блок","Detention Block"},{"BRD",1,0.48,0.874,9018,"Тюремный блок","Detention Block"},{"BRD",1,0.453,0.95,9018,"Тюремный блок","Detention Block"},{"BRD",1,0.41,0.876,9018,"Тюремный блок","Detention Block"},{"BRD",1,0.427,0.818,9018,"Тюремный блок","Detention Block"}}},{k="BRD",kind="kill",item=nil,w={"Пехотинец из клана Ярости Горна","Anvilrage Footman"},from={"Пехотинец из клана Ярости Горна","Anvilrage Footman"},spread=true,p={{"BRD",1,0.483,0.587,9025,"Галереи Правосудия","Halls of the Law"},{"BRD",1,0.566,0.673,9024,"Галереи Правосудия","Halls of the Law"},{"BRD",1,0.429,0.664,9024,"Восточный гарнизон","East Garrison"},{"BRD",1,0.414,0.535,9025,"Тенегорн","Shadowforge City"},{"BRD",2,0.552,0.7,9502,"Жилой квартал","The Domicile "},{"BRD",1,0.35,0.62,9016,"Тракт Черного Железа","Dark Iron Highway"}}}},
    [4082]={{k="BRD",kind="kill",item=nil,w={"Медик из клана Ярости Горна","Anvilrage Medic"},from={"Медик из клана Ярости Горна","Anvilrage Medic"},spread=true,p={{"BRD",1,0.327,0.576,9016,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.409,0.552,9025,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.498,0.686,9024,"Зал Правосудия","Ring of the Law"},{"BRD",2,0.548,0.732,9502,"Жилой квартал","The Domicile "},{"BRD",1,0.465,0.493,9025,"Тенегорн","Shadowforge City"},{"BRD",1,0.473,0.584,9025,"Зал Правосудия","Ring of the Law"}}},{k="BRD",kind="kill",item=nil,w={"Солдат из клана Ярости Горна","Anvilrage Soldier"},from={"Солдат из клана Ярости Горна","Anvilrage Soldier"},spread=true,p={{"BRD",1,0.323,0.573,9016,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.411,0.555,9025,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.466,0.497,9025,"Тенегорн","Shadowforge City"},{"BRD",1,0.539,0.599,9025,"Зал Правосудия","Ring of the Law"},{"BRD",1,0.234,0.564,9016,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.473,0.659,9024,"Зал Правосудия","Ring of the Law"}}},{k="BRD",kind="kill",item=nil,w={"Офицер из клана Ярости Горна","Anvilrage Officer"},from={"Офицер из клана Ярости Горна","Anvilrage Officer"},spread=true,p={{"BRD",1,0.31,0.605,9016,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.408,0.556,9025,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.467,0.494,9025,"Тенегорн","Shadowforge City"},{"BRD",1,0.503,0.572,9025,"Зал Правосудия","Ring of the Law"},{"BRD",1,0.273,0.553,9016,"Тракт Черного Железа","Dark Iron Highway"},{"BRD",1,0.259,0.482,9016,"Тракт Черного Железа","Dark Iron Highway"}}}},
    [4083]={{k="BRD",kind="loot",item=7910,w={"Звездный рубин","Star Ruby"},from={"Черный ящик","Dark Coffer"},spread=false,p={{"BRD",2,0.616,0.693,9502,"Черное Хранилище","The Black Vault"}}}},
    [4126]={{k="BRD",kind="loot",item=11312,w={"Украденный рецепт громоварского","Lost Thunderbrew Recipe"},from={"Харли Пьянодых","Hurley Blackbreath"},spread=false,p={{"BRD",2,0.481,0.619,nil,"Трактир \"Угрюмый обжора\"","The Grim Guzzler"}}}},
    [4132]={{k="BRD",kind="kill",item=nil,w={"Генерал Кузня Гнева","General Angerforge"},from={"Генерал Кузня Гнева","General Angerforge"},spread=false,p={{"BRD",1,0.356,0.57,9016,"Западный гарнизон","West Garrison"}}}},
    [4134]={{k="BRD",kind="loot",item=11312,w={"Украденный рецепт громоварского","Lost Thunderbrew Recipe"},from={"Харли Пьянодых","Hurley Blackbreath"},spread=false,p={{"BRD",2,0.481,0.619,nil,"Трактир \"Угрюмый обжора\"","The Grim Guzzler"}}}},
    [4136]={{k="BRD",kind="loot",item=11313,w={"Голова Риббли","Ribbly's Head"},from={"Риббли Крутипроб","Ribbly Screwspigot"},spread=false,p={{"BRD",2,0.491,0.619,nil,"Трактир \"Угрюмый обжора\"","The Grim Guzzler"}}}},
    [4263]={{k="BRD",kind="kill",item=nil,w={"Лорд Опалитель","Lord Incendius"},from={"Лорд Опалитель","Lord Incendius"},spread=false,p={{"BRD",1,0.561,0.312,9017,"Тенегорн","Shadowforge City"}}}},
    [4282]={{k="BRD",kind="loot",item=11464,w={"Утерянная информация маршала Виндзора","Marshal Windsor's Lost Information"},from={"Генерал Кузня Гнева","General Angerforge"},spread=false,p={{"BRD",1,0.356,0.57,9016,"Западный гарнизон","West Garrison"}}},{k="BRD",kind="loot",item=11465,w={"Утерянная информация маршала Виндзора","Marshal Windsor's Lost Information"},from={"Повелитель големов Аргелмах","Golem Lord Argelmach"},spread=false,p={{"BRD",2,0.369,0.65,8983,"Фабрика","The Manufactory"}}}},
    [4286]={{k="BRD",kind="loot",item=11468,w={"Поясная сумка дворфов Черного Железа","Dark Iron Fanny Pack"},from={"Надзиратель из клана Ярости Горна","Anvilrage Overseer"},spread=true,p={{"BRD",2,0.505,0.654,9502,"Трактир \"Угрюмый обжора\"","The Grim Guzzler"},{"BRD",1,0.482,0.584,9025,"Зал Правосудия","Ring of the Law"},{"BRD",1,0.356,0.57,9016,"Западный гарнизон","West Garrison"},{"BRD",2,0.875,0.119,9938,"Императорский Трон","The Imperial Seat"},{"BRD",1,0.459,0.72,9024,"Тюремный блок","Detention Block"},{"BRD",1,0.48,0.874,9018,"Тюремный блок","Detention Block"}}}},
    [4342]={{k="BRD",kind="kill",item=nil,w={"Каран Могучий Молот","Kharan Mighthammer"},from={"Каран Могучий Молот","Kharan Mighthammer"},spread=false,p={{"BRD",1,0.521,0.819,9024,"Тюремный блок","Detention Block"}}}},
    [4362]={{k="BRD",kind="kill",item=nil,w={"Император Дагран Тауриссан","Emperor Dagran Thaurissan"},from={"Император Дагран Тауриссан","Emperor Dagran Thaurissan"},spread=false,p={{"BRD",2,0.932,0.119,9019,"Императорский Трон","The Imperial Seat"}}}},
    [4601]={{k="GNOMER",kind="loot",item=9308,w={"Предмет, покрытый грязью","Grime-Encrusted Object"},from={"Землеглот из пещерных глубин","Caverndeep Burrower"},spread=true,p={{"GNOMER",1,0.402,0.635,7079,"Спальни","The Dormitory"},{"GNOMER",2,0.795,0.721,6235,"Спальни","The Dormitory"},{"GNOMER",4,0.368,0.665,6228,"Гномреган","Gnomeregan"},{"GNOMER",1,0.537,0.636,7079,"Машинный зал","The Hall of Gears"},{"GNOMER",1,0.41,0.731,7079,"Безопасная зона","The Clean Zone"},{"GNOMER",4,0.287,0.601,6228,"Гномреган","Gnomeregan"}}}},
    [4602]={{k="GNOMER",kind="loot",item=9308,w={"Предмет, покрытый грязью","Grime-Encrusted Object"},from={"Землеглот из пещерных глубин","Caverndeep Burrower"},spread=true,p={{"GNOMER",1,0.402,0.635,7079,"Спальни","The Dormitory"},{"GNOMER",2,0.795,0.721,6235,"Спальни","The Dormitory"},{"GNOMER",4,0.368,0.665,6228,"Гномреган","Gnomeregan"},{"GNOMER",1,0.537,0.636,7079,"Машинный зал","The Hall of Gears"},{"GNOMER",1,0.41,0.731,7079,"Безопасная зона","The Clean Zone"},{"GNOMER",4,0.287,0.601,6228,"Гномреган","Gnomeregan"}}}},
    [4701]={{k="BRS",kind="kill",item=nil,w={"Халикон","Halycon"},from={"Халикон","Halycon"},spread=false,p={{"LBRS",5,0.393,0.843,10220,"Логово Халикон","Halycon's Lair"}}}},
    [4724]={{k="BRS",kind="kill",item=nil,w={"Халикон","Halycon"},from={"Халикон","Halycon"},spread=false,p={{"LBRS",5,0.393,0.843,10220,"Логово Халикон","Halycon's Lair"}}}},
    [4734]={{k="BRS",kind="use",item=nil,w={"Яйцо из Гнездовья","Rookery Egg"},from={"Яйцо из Гнездовья","Rookery Egg"},spread=true,p={{"UBRS",1,0.341,0.39,10264,"Гнездовье","The Rookery"},{"UBRS",1,0.472,0.18,10339,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.452,0.325,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.521,0.324,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.392,0.432,10363,"Гнездовье","The Rookery"}}}},
    [4735]={{k="BRS",kind="use",item=nil,w={"Яйцо из Гнездовья","Rookery Egg"},from={"Яйцо из Гнездовья","Rookery Egg"},spread=true,p={{"UBRS",1,0.341,0.39,10264,"Гнездовье","The Rookery"},{"UBRS",1,0.472,0.18,10339,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.452,0.325,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.521,0.324,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.392,0.432,10363,"Гнездовье","The Rookery"}}}},
    [4742]={{k="BRS",kind="loot",item=12336,w={"Самоцвет Черной Вершины","Gemstone of Spirestone"},from={"Вождь Омокк","Highlord Omokk"},spread=false,p={{"LBRS",3,0.351,0.553,9196,"Мок'Дум","Mok'Doom"}}},{k="BRS",kind="loot",item=12335,w={"Самоцвет Тлеющего Терновника","Gemstone of Smolderthorn"},from={"Воевода Вун","War Master Voone"},spread=false,p={{"LBRS",1,0.53,0.544,9237,"Тазз'Алаор","Tazz'Alaor"}}},{k="BRS",kind="loot",item=12337,w={"Самоцвет Кровавого Топора","Gemstone of Bloodaxe"},from={"Властитель Змейталак","Overlord Wyrmthalak"},spread=false,p={{"LBRS",6,0.56,0.553,9568,"Чертог Битвы","Chamber of Battle"}}},{k="BRS",kind="loot",item=12219,w={"Простая печать Вознесения","Unadorned Seal of Ascension"},from={"Послушник из легиона Изрубленного Щита","Scarshield Acolyte"},spread=true,p={{"LBRS",1,0.631,0.579,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.5,0.567,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",4,0.372,0.387,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.561,0.464,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.375,0.637,9718,"Ордамар","Hordemar City"}}}},
    [4764]={{k="BRS",kind="loot",item=12352,w={"Пряжка Роковой оснастки","Doomrigger's Clasp"},from={"Металлический ящик Рокового Зажима","Doomrigger's Coffer"},spread=false,p={{"UBRS",1,0.347,0.401,10264,"Гнездовье","The Rookery"}}}},
    [4768]={{k="BRS",kind="loot",item=12358,w={"Табличка Темного Камня","Darkstone Tablet"},from={"Табличка Темного Камня","Darkstone Tablet"},spread=false,p={{"UBRS",1,0.328,0.404,10264,"Гнездовье","The Rookery"}}}},
    [4771]={{k="SCHOLO",kind="kill",item=nil,w={"Вектус","Vectus"},from={"Вектус","Vectus"},spread=false,p={{"SCHOLO",2,0.482,0.662,10432,"Демонстрационная комната","The Viewing Room"}}}},
    [4788]={{k="BRS",kind="loot",item=12740,w={"Пятая табличка Мошару","Fifth Mosh'aru Tablet"},from={"Пятая табличка Мошару","Fifth Mosh'aru Tablet"},spread=false,p={{"LBRS",2,0.556,0.732,9236,"Тазз'Алаор","Tazz'Alaor"}}},{k="BRS",kind="loot",item=12741,w={"Шестая табличка Мошару","Sixth Mosh'aru Tablet"},from={"Шестая табличка Мошару","Sixth Mosh'aru Tablet"},spread=false,p={{"LBRS",1,0.538,0.534,9237,"Тазз'Алаор","Tazz'Alaor"}}}},
    [4862]={{k="BRS",kind="loot",item=12530,w={"Яйцо скального паука","Spire Spider Egg"},from={"Яйцо скального паука","Spire Spider Egg"},spread=true,p={{"LBRS",1,0.606,0.738,9237,"Паучий лабиринт","Skitterweb Tunnels"},{"LBRS",2,0.51,0.734,9236,"Паучий лабиринт","Skitterweb Tunnels"},{"LBRS",1,0.661,0.688,9237,"Паучий лабиринт","Skitterweb Tunnels"},{"LBRS",1,0.502,0.75,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.655,0.777,9237,"Паучий лабиринт","Skitterweb Tunnels"}}}},
    [4903]={{k="BRS",kind="kill",item=nil,w={"Властитель Змейталак","Overlord Wyrmthalak"},from={"Властитель Змейталак","Overlord Wyrmthalak"},spread=false,p={{"LBRS",6,0.56,0.553,9568,"Чертог Битвы","Chamber of Battle"}}},{k="BRS",kind="kill",item=nil,w={"Вождь Омокк","Highlord Omokk"},from={"Вождь Омокк","Highlord Omokk"},spread=false,p={{"LBRS",3,0.351,0.553,9196,"Мок'Дум","Mok'Doom"}}},{k="BRS",kind="kill",item=nil,w={"Воевода Вун","War Master Voone"},from={"Воевода Вун","War Master Voone"},spread=false,p={{"LBRS",1,0.53,0.544,9237,"Тазз'Алаор","Tazz'Alaor"}}},{k="BRS",kind="loot",item=12562,w={"Важные бумаги Черной горы","Important Blackrock Documents"},from={"Не вызывающие подозрений документы","Inconspicuous Documents"},spread=false,p={{"LBRS",1,0.514,0.531,9237,"Тазз'Алаор","Tazz'Alaor"}}}},
    [4974]={{k="BRS",kind="loot",item=12630,w={"Голова Ренда Чернорука","Head of Rend Blackhand"},from={"Вождь Ренд Чернорук","Warchief Rend Blackhand"},spread=false,p={{"UBRS",1,0.512,0.245,10339,"Стадион Черной горы","Blackrock Stadium"}}}},
    [4982]={{k="BRS",kind="loot",item=12345,w={"Вещи Блестяшки","Bijou's Belongings"},from={"Вещи Блестяшки","Bijou's Belongings"},spread=false,p={{"LBRS",1,0.537,0.458,9237,"Ордамар","Hordemar City"}}}},
    [5001]={{k="BRS",kind="loot",item=12345,w={"Вещи Блестяшки","Bijou's Belongings"},from={"Вещи Блестяшки","Bijou's Belongings"},spread=false,p={{"LBRS",1,0.537,0.458,9237,"Ордамар","Hordemar City"}}}},
    [5081]={{k="BRS",kind="kill",item=nil,w={"Воевода Вун","War Master Voone"},from={"Воевода Вун","War Master Voone"},spread=false,p={{"LBRS",1,0.53,0.544,9237,"Тазз'Алаор","Tazz'Alaor"}}},{k="BRS",kind="kill",item=nil,w={"Вождь Омокк","Highlord Omokk"},from={"Вождь Омокк","Highlord Omokk"},spread=false,p={{"LBRS",3,0.351,0.553,9196,"Мок'Дум","Mok'Doom"}}},{k="BRS",kind="kill",item=nil,w={"Властитель Змейталак","Overlord Wyrmthalak"},from={"Властитель Змейталак","Overlord Wyrmthalak"},spread=false,p={{"LBRS",6,0.56,0.553,9568,"Чертог Битвы","Chamber of Battle"}}}},
    [5102]={{k="BRS",kind="kill",item=nil,w={"Генерал Драккисат","General Drakkisath"},from={"Генерал Драккисат","General Drakkisath"},spread=false,p={{"UBRS",1,0.334,0.453,10363,"Верховный трон","Spire Throne"}}}},
    [5122]={{k="STRAT",kind="loot",item=12845,w={"Медальон Веры","Medallion of Faith"},from={"Сейф Малора","Malor's Strongbox"},spread=false,p={{"STRAT_LIVE",1,0.31,0.408,11032,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [5127]={{k="BRS",kind="loot",item=12847,w={"Окрашенная душой пика","Soul Stained Pike"},from={"Горалук Треснувшая Наковальня","Goraluk Anvilcrack"},spread=false,p={{"UBRS",1,0.286,0.269,10899,"Зал Чернорука","Hall of Blackhand"}}},{k="BRS",kind="loot",item=12806,w={"Заготовка рунической кирасы","Unforged Rune Covered Breastplate"},from={"Распаянный рунный латный нагрудник","Unforged Runic Breastplate"},spread=false,p={{"UBRS",1,0.283,0.266,10899,"Зал Чернорука","Hall of Blackhand"}}}},
    [5212]={{k="STRAT",kind="loot",item=13174,w={"Образец чумной плоти","Plagued Flesh Sample"},from={"Уничтоженный кадавр","Ravaged Cadaver"},spread=true,p={{"STRAT_UD",1,0.626,0.293,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.671,0.491,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.829,0.405,10558,"Праздничная улица","Festival Lane"},{"STRAT_LIVE",1,0.649,0.541,10393,"Королевская площадь","King's Square"},{"STRAT_LIVE",1,0.676,0.256,10516,"Торговый ряд","Market Row"},{"STRAT_LIVE",1,0.577,0.307,10516,"Торговый ряд","Market Row"}}}},
    [5213]={{k="STRAT",kind="loot",item=13176,w={"Сведения о Плети","Scourge Data"},from={"Сведения о Плети","Scourge Data"},spread=false,p={{"STRAT_UD",1,0.791,0.464,10436,"Улица Испытаний","The Gauntlet"}}}},
    [5243]={{k="STRAT",kind="loot",item=13180,w={"Святая вода Стратхольма","Stratholme Holy Water"},from={"Ящик с припасами","Supply Crate"},spread=true,p={{"STRAT_UD",1,0.698,0.436,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.808,0.477,10558,"Праздничная улица","Festival Lane"},{"STRAT_LIVE",1,0.652,0.639,10393,"Королевская площадь","King's Square"},{"STRAT_UD",1,0.654,0.292,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.595,0.686,10393,"Королевская площадь","King's Square"},{"STRAT_UD",1,0.575,0.31,10809,"Улица Испытаний","The Gauntlet"}}}},
    [5251]={{k="STRAT",kind="kill",item=nil,w={"Архивариус Галфорд","Archivist Galford"},from={"Архивариус Галфорд","Archivist Galford"},spread=false,p={{"STRAT_LIVE",1,0.271,0.751,10811,"Бастион Алого ордена","The Scarlet Bastion"}}},{k="STRAT",kind="use",item=nil,w={"Архив Алых","Scarlet Archive"},from={"Архив Алых","Scarlet Archive"},spread=false,p={{"STRAT_LIVE",1,0.276,0.749,10811,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [5263]={{k="STRAT",kind="loot",item=13251,w={"Голова Барона Ривендера","Head of Baron Rivendare"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [5341]={{k="SCHOLO",kind="loot",item=13471,w={"Документы на Брилл","The Deed to Brill"},from={"Документы на Брилл","The Deed to Brill"},spread=false,p={{"SCHOLO",4,0.373,0.859,10508,"Лаборатория","The Laboratory"}}},{k="SCHOLO",kind="loot",item=13448,w={"Документы на Каэр Дарроу","The Deed to Caer Darrow"},from={"Документы на Каэр Дарроу","The Deed to Caer Darrow"},spread=false,p={{"SCHOLO",4,0.843,0.289,10504,"Семейный склеп Баровых","Barov Family Vault"}}},{k="SCHOLO",kind="loot",item=13450,w={"Документы на Южнобережье","The Deed to Southshore"},from={"Документы на Южнобережье","The Deed to Southshore"},spread=false,p={{"SCHOLO",1,0.852,0.441,14861,"Усыпальница","The Reliquary"}}},{k="SCHOLO",kind="loot",item=13451,w={"Документы на Мельницу Таррен","The Deed to Tarren Mill"},from={"Документы на Мельницу Таррен","The Deed to Tarren Mill"},spread=false,p={{"SCHOLO",1,0.263,0.668,14861,"Некроситет","Scholomance"}}}},
    [5343]={{k="SCHOLO",kind="loot",item=13471,w={"Документы на Брилл","The Deed to Brill"},from={"Документы на Брилл","The Deed to Brill"},spread=false,p={{"SCHOLO",4,0.373,0.859,10508,"Лаборатория","The Laboratory"}}},{k="SCHOLO",kind="loot",item=13448,w={"Документы на Каэр Дарроу","The Deed to Caer Darrow"},from={"Документы на Каэр Дарроу","The Deed to Caer Darrow"},spread=false,p={{"SCHOLO",4,0.843,0.289,10504,"Семейный склеп Баровых","Barov Family Vault"}}},{k="SCHOLO",kind="loot",item=13450,w={"Документы на Южнобережье","The Deed to Southshore"},from={"Документы на Южнобережье","The Deed to Southshore"},spread=false,p={{"SCHOLO",1,0.852,0.441,14861,"Усыпальница","The Reliquary"}}},{k="SCHOLO",kind="loot",item=13451,w={"Документы на Мельницу Таррен","The Deed to Tarren Mill"},from={"Документы на Мельницу Таррен","The Deed to Tarren Mill"},spread=false,p={{"SCHOLO",1,0.263,0.668,14861,"Некроситет","Scholomance"}}}},
    [5382]={{k="SCHOLO",kind="kill",item=nil,w={"Доктор Теолен Крастинов","Doctor Theolen Krastinov"},from={"Доктор Теолен Крастинов","Doctor Theolen Krastinov"},spread=false,p={{"SCHOLO",3,0.956,0.459,11261,"Зал Проклятых","Hall of the Damned"}}},{k="SCHOLO",kind="use",item=nil,w={"Останки Ева Саркофф","Remains of Eva Sarkhoff"},from={"Останки Ева Саркофф","Remains of Eva Sarkhoff"},spread=false,p={{"SCHOLO",3,0.903,0.405,11261,"Зал Проклятых","Hall of the Damned"}}},{k="SCHOLO",kind="use",item=nil,w={"Останки Люсьена Саркофф","Remains of Lucien Sarkhoff"},from={"Останки Люсьена Саркофф","Remains of Lucien Sarkhoff"},spread=false,p={{"SCHOLO",3,0.921,0.521,11261,"Зал Проклятых","Hall of the Damned"}}}},
    [5466]={{k="SCHOLO",kind="loot",item=13626,w={"Человеческая голова Раса Ледяного Шепота","Human Head of Ras Frostwhisper"},from={"Рас Снегошепот","Ras Frostwhisper"},spread=false,p={{"SCHOLO",4,0.406,0.884,10508,"Лаборатория","The Laboratory"}}}},
    [5515]={{k="SCHOLO",kind="loot",item=13725,w={"Мешок ужасов Крастинова","Krastinov's Bag of Horrors"},from={"Джандис Баров","Jandice Barov"},spread=false,p={{"SCHOLO",3,0.543,0.144,10901,"Некроситет","Scholomance"}}}},
    [5518]={{k="DMAUL",kind="loot",item=18240,w={"Огрская дубильная кислота","Ogre Tannin"},from={"Огрский дубильный чан","Ogre Tannin Basket"},spread=false,p={{"DM_N",1,0.22,0.53,14323,"Гибельные залы","Halls of Destruction"}}}},
    [5525]={{k="DMAUL",kind="loot",item=18250,w={"Ключ от оков клана Гордок","Gordok Shackle Key"},from={"Громила из клана Гордок","Gordok Brute"},spread=true,p={{"DM_N",1,0.277,0.588,14323,"Гибельные залы","Halls of Destruction"},{"DM_N",1,0.53,0.78,14321,"Забытый Город","Dire Maul"},{"DM_N",1,0.488,0.891,14321,"Забытый Город","Dire Maul"},{"DM_N",1,0.591,0.706,14322,"Забытый Город","Dire Maul"},{"DM_N",1,0.706,0.87,14326,"Забытый Город","Dire Maul"},{"DM_N",1,0.253,0.674,14323,"Гибельные залы","Halls of Destruction"}}}},
    [5529]={{k="SCHOLO",kind="kill",item=nil,w={"Зачумленный детеныш дракона","Plagued Hatchling"},from={"Зачумленный детеныш дракона","Plagued Hatchling"},spread=true,p={{"SCHOLO",2,0.329,0.682,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.328,0.768,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.367,0.619,10433,"Великий оссуарий","The Great Ossuary"}}}},
    [5723]={{k="RFC",kind="kill",item=nil,w={"Трогг Огненной пропасти","Ragefire Trogg"},from={"Трогг Огненной пропасти","Ragefire Trogg"},spread=true,p={{"RFC",1,0.673,0.622,11517,nil,nil},{"RFC",1,0.642,0.4,11517,nil,nil},{"RFC",1,0.615,0.496,11517,nil,nil},{"RFC",1,0.651,0.691,11520,nil,nil},{"RFC",1,0.575,0.393,11517,nil,nil},{"RFC",1,0.707,0.487,11517,nil,nil}}},{k="RFC",kind="kill",item=nil,w={"Шаман Огненной пропасти","Ragefire Shaman"},from={"Шаман Огненной пропасти","Ragefire Shaman"},spread=true,p={{"RFC",1,0.7,0.632,11517,nil,nil},{"RFC",1,0.638,0.368,11517,nil,nil},{"RFC",1,0.701,0.435,11517,nil,nil},{"RFC",1,0.576,0.381,11517,nil,nil},{"RFC",1,0.623,0.509,11517,nil,nil}}}},
    [5725]={{k="RFC",kind="loot",item=14395,w={"Заклинания Тьмы","Spells of Shadow"},from={"Сектант из клана Огненного Клинка","Searing Blade Cultist"},spread=true,p={{"RFC",1,0.346,0.679,11520,nil,nil},{"RFC",1,0.327,0.83,11518,nil,nil},{"RFC",1,0.282,0.876,11518,nil,nil},{"RFC",1,0.488,0.627,11520,nil,nil},{"RFC",1,0.324,0.536,11520,nil,nil},{"RFC",1,0.497,0.507,11520,nil,nil}}},{k="RFC",kind="loot",item=14396,w={"Магическая формула Пустоты","Incantations from the Nether"},from={"Сектант из клана Огненного Клинка","Searing Blade Cultist"},spread=true,p={{"RFC",1,0.346,0.679,11520,nil,nil},{"RFC",1,0.327,0.83,11518,nil,nil},{"RFC",1,0.282,0.876,11518,nil,nil},{"RFC",1,0.488,0.627,11520,nil,nil},{"RFC",1,0.324,0.536,11520,nil,nil},{"RFC",1,0.497,0.507,11520,nil,nil}}}},
    [5728]={{k="RFC",kind="kill",item=nil,w={"Баззалан","Bazzalan"},from={"Баззалан","Bazzalan"},spread=false,p={{"RFC",1,0.415,0.862,11519,nil,nil}}},{k="RFC",kind="kill",item=nil,w={"Жергош Призыватель Духов","Jergosh the Invoker"},from={"Жергош Призыватель Духов","Jergosh the Invoker"},spread=false,p={{"RFC",1,0.33,0.845,11518,nil,nil}}}},
    [5761]={{k="RFC",kind="loot",item=14540,w={"Сердце Тарагамана Ненасытного","Taragaman the Hungerer's Heart"},from={"Тарагаман Ненасытный","Taragaman the Hungerer"},spread=false,p={{"RFC",1,0.41,0.577,11520,nil,nil}}}},
    [5848]={{k="STRAT",kind="loot",item=14679,w={"О любви и семье","Of Love and Family"},from={"Незаконченная картина","Unfinished Painting"},spread=false,p={{"STRAT_LIVE",1,0.274,0.762,10811,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [6502]={{k="BRS",kind="loot",item=16663,w={"Кровь могучего черного дракона","Blood of the Black Dragon Champion"},from={"Генерал Драккисат","General Drakkisath"},spread=false,p={{"UBRS",1,0.334,0.453,10363,"Верховный трон","Spire Throne"}}}},
    [6561]={{k="BFD",kind="loot",item=5881,w={"Голова Келриса","Head of Kelris"},from={"Повелитель сумрака Келрис","Twilight Lord Kelris"},spread=false,p={{"BFD",2,0.519,0.816,4832,"Алтарь святилища Луны","Moonshrine Sanctum"}}}},
    [6565]={{k="BFD",kind="kill",item=nil,w={"Лоргус Джетт","Lorgus Jett"},from={"Лоргус Джетт","Lorgus Jett"},spread=false,p={{"BFD",2,0.354,0.483,12902,"Непроглядная Пучина","Blackfathom Deeps"}}}},
    [6569]={{k="BRS",kind="loot",item=16786,w={"Глаз черного драконида","Black Dragonspawn Eye"},from={"Драконид Яростного Когтя","Rage Talon Dragonspawn"},spread=true,p={{"UBRS",1,0.393,0.285,10509,"Зал Чернорука","Hall of Blackhand"},{"LBRS",6,0.567,0.496,9568,"Горн","The Furnace"},{"UBRS",1,0.289,0.344,10264,"Гнездовье","The Rookery"},{"UBRS",1,0.457,0.281,10429,"Стадион Черной горы","Blackrock Stadium"},{"LBRS",5,0.368,0.242,9718,"Зал Драконов","Dragonspire Hall"},{"UBRS",1,0.388,0.349,10264,"Гнездовье","The Rookery"}}}},
    [6602]={{k="BRS",kind="loot",item=16663,w={"Кровь могучего черного дракона","Blood of the Black Dragon Champion"},from={"Генерал Драккисат","General Drakkisath"},spread=false,p={{"UBRS",1,0.334,0.453,10363,"Верховный трон","Spire Throne"}}}},
    [6921]={{k="BFD",kind="loot",item=16762,w={"Глубинный сердечник","Fathom Core"},from={"Глубинный Камень","Fathom Stone"},spread=false,p={{"BFD",2,0.415,0.754,12876,"Руины святилища Луны","Moonshrine Ruins"}}}},
    [7028]={{k="MARA",kind="loot",item=17684,w={"Терадрический хрустальный орнамент","Theradric Crystal Carving"},from={"Сатир из племени Тлетворных","Putridus Satyr"},spread=true,p={{"MARA",1,0.387,0.2,13282,"Ядовитая низина","The Noxious Hollow"},{"MARA",1,0.373,0.359,12258,"Зловонная пещера","Foulspore Cavern"},{"MARA",1,0.553,0.377,nil,"Зловонная пещера","Foulspore Cavern"},{"MARA",1,0.357,0.609,12236,"Ядопады","Poison Falls"},{"MARA",1,0.3,0.397,12258,"Зловонная пещера","Foulspore Cavern"},{"MARA",1,0.388,0.49,12236,"Ядопады","Poison Falls"}}}},
    [7044]={{k="MARA",kind="loot",item=17703,w={"Келебрийский бриллиант","Celebrian Diamond"},from={"Лорд Злоязыкий","Lord Vyletongue"},spread=false,p={{"MARA",1,0.377,0.694,12236,"Палата Злоязыкого","Vyletongue Seat"}}},{k="MARA",kind="loot",item=17702,w={"Келебрийский жезл","Celebrian Rod"},from={"Ноксион","Noxxion"},spread=false,p={{"MARA",1,0.348,0.107,13282,"Ядовитая низина","The Noxious Hollow"}}}},
    [7064]={{k="MARA",kind="kill",item=nil,w={"Принцесса Терадрас","Princess Theradras"},from={"Принцесса Терадрас","Princess Theradras"},spread=false,p={{"MARA",2,0.242,0.784,12201,"Могила Зейтара","Zaetar's Grave"}}}},
    [7065]={{k="MARA",kind="kill",item=nil,w={"Принцесса Терадрас","Princess Theradras"},from={"Принцесса Терадрас","Princess Theradras"},spread=false,p={{"MARA",2,0.242,0.784,12201,"Могила Зейтара","Zaetar's Grave"}}}},
    [7201]={{k="BRD",kind="loot",item=11129,w={"Суть Стихий","Essence of the Elements"},from={"Оплавленный боевой голем","Molten War Golem"},spread=true,p={{"BRD",1,0.38,0.527,9016,"Западный гарнизон","West Garrison"},{"BRD",1,0.46,0.608,9025,"Галереи Правосудия","Halls of the Law"},{"BRD",2,0.54,0.359,8923,"Колдовской чертог","Chamber of Enchantment"},{"BRD",1,0.561,0.312,9017,"Тенегорн","Shadowforge City"},{"BRD",1,0.495,0.389,9017,"Тенегорн","Shadowforge City"},{"BRD",2,0.565,0.514,9156,"Колдовской чертог","Chamber of Enchantment"}}}},
    [7441]={{k="DMAUL",kind="loot",item=18261,w={"Книга магических формул","Book of Incantations"},from={"Пузиллин","Pusillin"},spread=false,p={{"DM_E",1,0.122,0.31,14354,"Квартал Криводревов","Warpwood Quarter"}}}},
    [7461]={{k="DMAUL",kind="kill",item=nil,w={"Бессмер'тер","Immol'thar"},from={"Бессмер'тер","Immol'thar"},spread=false,p={{"DM_W",3,0.35,0.576,11496,"Тюрьма Пламе'тара","Prison of Immol'thar"}}},{k="DMAUL",kind="kill",item=nil,w={"Принц Тортелдрин","Prince Tortheldrin"},from={"Принц Тортелдрин","Prince Tortheldrin"},spread=false,p={{"DM_W",3,0.599,0.235,11486,"Читальня","The Athenaeum"}}}},
    [7481]={{k="DMAUL",kind="use",item=nil,w={"Останки Тельмия Сновидца","Skeletal Remains of Telmius Dreamseeker"},from={"Останки Тельмия Сновидца","Skeletal Remains of Telmius Dreamseeker"},spread=false,p={{"DM_W",3,0.726,0.174,11467,"Читальня","The Athenaeum"}}}},
    [7482]={{k="DMAUL",kind="use",item=nil,w={"Останки Тельмия Сновидца","Skeletal Remains of Telmius Dreamseeker"},from={"Останки Тельмия Сновидца","Skeletal Remains of Telmius Dreamseeker"},spread=false,p={{"DM_W",3,0.726,0.174,11467,"Читальня","The Athenaeum"}}}},
    [7484]={{k="SCHOLO",kind="loot",item=12753,w={"Шкура Тени","Skin of Shadow"},from={"Восставшее создание","Risen Construct"},spread=true,p={{"SCHOLO",2,0.351,0.745,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.349,0.653,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",4,0.667,0.112,10502,"Мрачный Свод","The Shadow Vault"},{"SCHOLO",2,0.267,0.684,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.263,0.797,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",4,0.672,0.172,10502,"Мрачный Свод","The Shadow Vault"}}}},
    [7485]={{k="STRAT",kind="loot",item=12735,w={"Истлевшая шовная нить поганища","Frayed Abomination Stitching"},from={"Лоскутный ужас","Patchwork Horror"},spread=true,p={{"STRAT_UD",1,0.46,0.219,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.434,0.107,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_LIVE",1,0.826,0.32,10558,"Праздничная улица","Festival Lane"},{"STRAT_LIVE",1,0.597,0.53,10393,"Королевская площадь","King's Square"},{"STRAT_LIVE",1,0.601,0.319,10516,"Торговый ряд","Market Row"},{"STRAT_UD",1,0.418,0.266,10439,"Площадь Живодерни","Slaughter Square"}}}},
    [7488]={{k="DMAUL",kind="loot",item=18426,w={"Сеть Лефтендрис","Lethtendris's Web"},from={"Лефтендрис","Lethtendris"},spread=false,p={{"DM_E",1,0.426,0.482,14354,"Забытый Город","Dire Maul"}}}},
    [7489]={{k="DMAUL",kind="loot",item=18426,w={"Сеть Лефтендрис","Lethtendris's Web"},from={"Лефтендрис","Lethtendris"},spread=false,p={{"DM_E",1,0.426,0.482,14354,"Забытый Город","Dire Maul"}}}},
    [7703]={{k="DMAUL",kind="loot",item=18336,w={"Латная рукавица мощи Гордока","Gauntlet of Gordok Might"},from={"Сундук принца","The Prince's Chest"},spread=false,p={{"DM_W",3,0.582,0.268,11486,"Читальня","The Athenaeum"}}}},
    [8905]={{k="SCHOLO",kind="loot",item=16714,w={"Наручи Буйного сердца","Wildheart Bracers"},from={"Болезненный вурдалак","Diseased Ghoul"},spread=true,p={{"SCHOLO",1,0.515,0.612,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.527,0.497,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.908,0.465,11261,"Зал Проклятых","Hall of the Damned"},{"SCHOLO",3,0.445,0.174,10901,"Некроситет","Scholomance"},{"SCHOLO",3,0.502,0.208,10901,"Некроситет","Scholomance"},{"SCHOLO",3,0.322,0.159,10901,"Некроситет","Scholomance"}}},{k="STRAT",kind="loot",item=16714,w={"Наручи Буйного сердца","Wildheart Bracers"},from={"Инквизитор из Багрового Легиона","Crimson Inquisitor"},spread=true,p={{"STRAT_UD",1,0.654,0.496,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.637,0.263,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.714,0.441,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.239,0.569,11120,"Бастион Алого ордена","The Scarlet Bastion"},{"STRAT_LIVE",1,0.26,0.65,10811,"Бастион Алого ордена","The Scarlet Bastion"},{"STRAT_UD",1,0.593,0.439,10437,"Улица Испытаний","The Gauntlet"}}}},
    [8906]={{k="BRS",kind="loot",item=16681,w={"Наручники загонщика","Beaststalker's Bindings"},from={"Драконид Яростного Когтя","Rage Talon Dragonspawn"},spread=true,p={{"UBRS",1,0.381,0.337,10264,"Гнездовье","The Rookery"},{"UBRS",1,0.289,0.344,10264,"Гнездовье","The Rookery"},{"LBRS",5,0.368,0.242,9718,"Зал Драконов","Dragonspire Hall"},{"UBRS",1,0.457,0.281,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.394,0.231,10509,"Зал Чернорука","Hall of Blackhand"},{"LBRS",5,0.341,0.183,9718,"Зал Драконов","Dragonspire Hall"}}},{k="STRAT",kind="loot",item=16681,w={"Наручники загонщика","Beaststalker's Bindings"},from={"Вурдалак-стервятник","Ghoul Ravener"},spread=true,p={{"STRAT_UD",1,0.671,0.491,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.655,0.284,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.105,0.57,11120,"Арсенал","The Hoard"},{"STRAT_UD",1,0.558,0.224,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.712,0.415,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.578,0.295,10809,"Улица Испытаний","The Gauntlet"}}}},
    [8907]={{k="BRS",kind="loot",item=16683,w={"Наручники Магистра","Magister's Bindings"},from={"Чароплет из легиона Изрубленного Щита","Scarshield Spellbinder"},spread=true,p={{"LBRS",1,0.502,0.701,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.536,0.421,9237,"Ордамар","Hordemar City"},{"LBRS",4,0.379,0.377,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.497,0.586,9596,"Ордамар","Hordemar City"},{"LBRS",5,0.365,0.662,9718,"Ордамар","Hordemar City"},{"LBRS",3,0.317,0.434,9196,"Зал Чернорука","Hall of Blackhand"}}}},
    [8908]={{k="SCHOLO",kind="loot",item=16722,w={"Наручи из светлостали","Lightforge Bracers"},from={"Восставший воин","Risen Warrior"},spread=true,p={{"SCHOLO",4,0.781,0.284,10504,"Семейный склеп Баровых","Barov Family Vault"},{"SCHOLO",1,0.388,0.677,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.308,0.655,14861,"Некроситет","Scholomance"},{"SCHOLO",2,0.334,0.265,10503,"Некроситет","Scholomance"},{"SCHOLO",1,0.246,0.558,14861,"Некроситет","Scholomance"},{"SCHOLO",4,0.844,0.308,10504,"Семейный склеп Баровых","Barov Family Vault"}}},{k="STRAT",kind="loot",item=16722,w={"Наручи из светлостали","Lightforge Bracers"},from={"Горгулья Крыла Скалы","Rockwing Gargoyle"},spread=true,p={{"STRAT_UD",1,0.579,0.243,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.717,0.464,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.673,0.524,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.596,0.46,10437,"Улица Испытаний","The Gauntlet"}}}},
    [8909]={{k="STRAT",kind="loot",item=16697,w={"Наручи Преданности","Devout Bracers"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.278,0.447,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.375,0.268,10808,"Площадь рыцарей","Crusaders' Square"}}}},
    [8911]={{k="BRS",kind="loot",item=16703,w={"Наручи Багрового Тумана","Dreadmist Bracers"},from={"Чернокнижник из легиона Изрубленного Щита","Scarshield Warlock"},spread=true,p={{"LBRS",1,0.546,0.569,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.505,0.684,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.524,0.445,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.342,0.704,10263,"Ордамар","Hordemar City"},{"LBRS",5,0.303,0.14,9718,"Зал Драконов","Dragonspire Hall"},{"LBRS",1,0.473,0.558,9596,"Ордамар","Hordemar City"}}}},
    [8912]={{k="BRS",kind="loot",item=16735,w={"Наручи Доблести","Bracers of Valor"},from={"Легионер из легиона Изрубленного Щита","Scarshield Legionnaire"},spread=true,p={{"LBRS",4,0.368,0.376,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.672,0.572,9237,"Ордамар","Hordemar City"},{"LBRS",3,0.332,0.483,9196,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.514,0.473,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.493,0.578,9596,"Ордамар","Hordemar City"}}}},
    [8913]={{k="SCHOLO",kind="loot",item=16714,w={"Наручи Буйного сердца","Wildheart Bracers"},from={"Болезненный вурдалак","Diseased Ghoul"},spread=true,p={{"SCHOLO",1,0.515,0.612,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.527,0.497,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.908,0.465,11261,"Зал Проклятых","Hall of the Damned"},{"SCHOLO",3,0.445,0.174,10901,"Некроситет","Scholomance"},{"SCHOLO",3,0.502,0.208,10901,"Некроситет","Scholomance"},{"SCHOLO",3,0.322,0.159,10901,"Некроситет","Scholomance"}}},{k="STRAT",kind="loot",item=16714,w={"Наручи Буйного сердца","Wildheart Bracers"},from={"Инквизитор из Багрового Легиона","Crimson Inquisitor"},spread=true,p={{"STRAT_UD",1,0.654,0.496,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.637,0.263,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.714,0.441,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.239,0.569,11120,"Бастион Алого ордена","The Scarlet Bastion"},{"STRAT_LIVE",1,0.26,0.65,10811,"Бастион Алого ордена","The Scarlet Bastion"},{"STRAT_UD",1,0.593,0.439,10437,"Улица Испытаний","The Gauntlet"}}}},
    [8914]={{k="BRS",kind="loot",item=16681,w={"Наручники загонщика","Beaststalker's Bindings"},from={"Драконид Яростного Когтя","Rage Talon Dragonspawn"},spread=true,p={{"UBRS",1,0.381,0.337,10264,"Гнездовье","The Rookery"},{"UBRS",1,0.289,0.344,10264,"Гнездовье","The Rookery"},{"LBRS",5,0.368,0.242,9718,"Зал Драконов","Dragonspire Hall"},{"UBRS",1,0.457,0.281,10429,"Стадион Черной горы","Blackrock Stadium"},{"UBRS",1,0.394,0.231,10509,"Зал Чернорука","Hall of Blackhand"},{"LBRS",5,0.341,0.183,9718,"Зал Драконов","Dragonspire Hall"}}},{k="STRAT",kind="loot",item=16681,w={"Наручники загонщика","Beaststalker's Bindings"},from={"Вурдалак-стервятник","Ghoul Ravener"},spread=true,p={{"STRAT_UD",1,0.671,0.491,11121,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.655,0.284,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.105,0.57,11120,"Арсенал","The Hoard"},{"STRAT_UD",1,0.558,0.224,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.712,0.415,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.578,0.295,10809,"Улица Испытаний","The Gauntlet"}}}},
    [8915]={{k="BRS",kind="loot",item=16683,w={"Наручники Магистра","Magister's Bindings"},from={"Чароплет из легиона Изрубленного Щита","Scarshield Spellbinder"},spread=true,p={{"LBRS",1,0.502,0.701,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.536,0.421,9237,"Ордамар","Hordemar City"},{"LBRS",4,0.379,0.377,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.497,0.586,9596,"Ордамар","Hordemar City"},{"LBRS",5,0.365,0.662,9718,"Ордамар","Hordemar City"},{"LBRS",3,0.317,0.434,9196,"Зал Чернорука","Hall of Blackhand"}}}},
    [8916]={{k="STRAT",kind="loot",item=16697,w={"Наручи Преданности","Devout Bracers"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.278,0.447,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.375,0.268,10808,"Площадь рыцарей","Crusaders' Square"}}}},
    [8918]={{k="SCHOLO",kind="loot",item=16671,w={"Наручники Стихий","Bindings of Elements"},from={"Раздробленный скелет","Splintered Skeleton"},spread=false,p={{"SCHOLO",4,0.678,0.444,10507,"Склеп Равениана","Vault of the Ravenian"}}},{k="STRAT",kind="loot",item=16671,w={"Наручники Стихий","Bindings of Elements"},from={"Некрорахнид-ползун","Crypt Crawler"},spread=true,p={{"STRAT_UD",1,0.625,0.47,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.623,0.275,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.72,0.459,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.258,0.715,10811,"Бастион Алого ордена","The Scarlet Bastion"},{"STRAT_UD",1,0.57,0.442,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.207,0.582,11120,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [8919]={{k="BRS",kind="loot",item=16703,w={"Наручи Багрового Тумана","Dreadmist Bracers"},from={"Чернокнижник из легиона Изрубленного Щита","Scarshield Warlock"},spread=true,p={{"LBRS",1,0.546,0.569,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.505,0.684,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.524,0.445,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.342,0.704,10263,"Ордамар","Hordemar City"},{"LBRS",5,0.303,0.14,9718,"Зал Драконов","Dragonspire Hall"},{"LBRS",1,0.473,0.558,9596,"Ордамар","Hordemar City"}}}},
    [8920]={{k="BRS",kind="loot",item=16735,w={"Наручи Доблести","Bracers of Valor"},from={"Легионер из легиона Изрубленного Щита","Scarshield Legionnaire"},spread=true,p={{"LBRS",4,0.368,0.376,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.672,0.572,9237,"Ордамар","Hordemar City"},{"LBRS",3,0.332,0.483,9196,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.514,0.473,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.493,0.578,9596,"Ордамар","Hordemar City"}}}},
    [8926]={{k="BRS",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Налетчик из легиона Изрубленного Щита","Scarshield Raider"},spread=true,p={{"LBRS",1,0.642,0.588,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.581,0.434,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.407,0.72,10263,"Ордамар","Hordemar City"},{"LBRS",3,0.372,0.483,9196,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.464,0.443,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.53,0.795,9736,"Ордамар","Hordemar City"}}},{k="SCHOLO",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Призрачный ученый","Spectral Researcher"},spread=true,p={{"SCHOLO",4,0.372,0.7,10508,"Лаборатория","The Laboratory"},{"SCHOLO",2,0.359,0.769,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.302,0.651,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",1,0.693,0.666,14861,"Усыпальница","The Reliquary"},{"SCHOLO",1,0.634,0.357,14861,"Усыпальница","The Reliquary"},{"SCHOLO",1,0.844,0.641,14861,"Усыпальница","The Reliquary"}}},{k="STRAT",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Желчеплюй","Bile Spewer"},spread=true,p={{"STRAT_UD",1,0.46,0.219,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.434,0.107,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.418,0.266,10439,"Площадь Живодерни","Slaughter Square"}}},{k="BRS",kind="loot",item=16717,w={"Перчатки Буйного сердца","Wildheart Gloves"},from={"Драконид Яростного Когтя","Rage Talon Dragonspawn"},spread=true,p={{"LBRS",1,0.604,0.58,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.493,0.618,9596,"Ордамар","Hordemar City"},{"UBRS",1,0.381,0.337,10264,"Гнездовье","The Rookery"},{"LBRS",1,0.55,0.712,9596,"Паучий лабиринт","Skitterweb Tunnels"},{"LBRS",1,0.544,0.469,9237,"Ордамар","Hordemar City"},{"UBRS",1,0.289,0.344,10264,"Гнездовье","The Rookery"}}},{k="STRAT",kind="loot",item=16717,w={"Перчатки Буйного сердца","Wildheart Gloves"},from={"Непрощенный","The Unforgiven"},spread=false,p={{"STRAT_LIVE",1,0.71,0.218,10516,"Торговый ряд","Market Row"}}}},
    [8927]={{k="BRS",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Налетчик из легиона Изрубленного Щита","Scarshield Raider"},spread=true,p={{"LBRS",1,0.642,0.588,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.581,0.434,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.407,0.72,10263,"Ордамар","Hordemar City"},{"LBRS",3,0.372,0.483,9196,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.464,0.443,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.53,0.795,9736,"Ордамар","Hordemar City"}}},{k="SCHOLO",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Призрачный ученый","Spectral Researcher"},spread=true,p={{"SCHOLO",4,0.372,0.7,10508,"Лаборатория","The Laboratory"},{"SCHOLO",2,0.359,0.769,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",2,0.302,0.651,10433,"Великий оссуарий","The Great Ossuary"},{"SCHOLO",1,0.693,0.666,14861,"Усыпальница","The Reliquary"},{"SCHOLO",1,0.634,0.357,14861,"Усыпальница","The Reliquary"},{"SCHOLO",1,0.844,0.641,14861,"Усыпальница","The Reliquary"}}},{k="STRAT",kind="loot",item=16716,w={"Пояс Буйного сердца","Wildheart Belt"},from={"Желчеплюй","Bile Spewer"},spread=true,p={{"STRAT_UD",1,0.46,0.219,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.434,0.107,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.418,0.266,10439,"Площадь Живодерни","Slaughter Square"}}},{k="BRS",kind="loot",item=16717,w={"Перчатки Буйного сердца","Wildheart Gloves"},from={"Драконид Яростного Когтя","Rage Talon Dragonspawn"},spread=true,p={{"LBRS",1,0.604,0.58,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.493,0.618,9596,"Ордамар","Hordemar City"},{"UBRS",1,0.381,0.337,10264,"Гнездовье","The Rookery"},{"LBRS",1,0.55,0.712,9596,"Паучий лабиринт","Skitterweb Tunnels"},{"LBRS",1,0.544,0.469,9237,"Ордамар","Hordemar City"},{"UBRS",1,0.289,0.344,10264,"Гнездовье","The Rookery"}}},{k="STRAT",kind="loot",item=16717,w={"Перчатки Буйного сердца","Wildheart Gloves"},from={"Непрощенный","The Unforgiven"},spread=false,p={{"STRAT_LIVE",1,0.71,0.218,10516,"Торговый ряд","Market Row"}}}},
    [8931]={{k="BRS",kind="loot",item=16680,w={"Пояс загонщика","Beaststalker's Belt"},from={"Охотник за головами из племени Тлеющего Терновника","Smolderthorn Headhunter"},spread=true,p={{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.493,0.578,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.514,0.473,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.642,0.588,9237,"Ордамар","Hordemar City"},{"LBRS",6,0.572,0.462,9568,"Горн","The Furnace"},{"LBRS",1,0.581,0.434,9237,"Ордамар","Hordemar City"}}},{k="BRS",kind="loot",item=16676,w={"Перчатки загонщика","Beaststalker's Gloves"},from={"Воевода Вун","War Master Voone"},spread=false,p={{"LBRS",1,0.53,0.544,9237,"Тазз'Алаор","Tazz'Alaor"}}}},
    [8932]={{k="BRS",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Мистик из племени Тлеющего Терновника","Smolderthorn Mystic"},spread=true,p={{"LBRS",2,0.52,0.578,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.662,0.567,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",2,0.557,0.673,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.534,0.522,9237,"Ордамар","Hordemar City"}}},{k="SCHOLO",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Адепт Некроситета","Scholomance Adept"},spread=true,p={{"SCHOLO",2,0.331,0.324,10503,"Некроситет","Scholomance"},{"SCHOLO",1,0.32,0.503,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.358,0.668,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.236,0.457,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.248,0.667,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.407,0.45,14861,"Некроситет","Scholomance"}}},{k="STRAT",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.279,0.435,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.732,0.507,11121,"Улица Испытаний","The Gauntlet"}}},{k="SCHOLO",kind="loot",item=16684,w={"Перчатки Магистра","Magister's Gloves"},from={"Адепт Некроситета","Scholomance Adept"},spread=true,p={{"SCHOLO",2,0.331,0.324,10503,"Некроситет","Scholomance"},{"SCHOLO",1,0.32,0.503,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.358,0.668,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.236,0.457,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.248,0.667,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.407,0.45,14861,"Некроситет","Scholomance"}}}},
    [8933]={{k="STRAT",kind="loot",item=16724,w={"Рукавицы из светлостали","Lightforge Gauntlets"},from={"Тайлер","Timmy the Cruel"},spread=false,p={{"STRAT_LIVE",1,0.394,0.335,10808,"Площадь рыцарей","Crusaders' Square"}}}},
    [8934]={{k="BRS",kind="loot",item=16696,w={"Пояс Преданности","Devout Belt"},from={"Чароплет из легиона Изрубленного Щита","Scarshield Spellbinder"},spread=true,p={{"LBRS",2,0.531,0.596,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.51,0.483,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.505,0.684,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.642,0.568,9237,"Ордамар","Hordemar City"},{"LBRS",4,0.379,0.377,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.473,0.558,9596,"Ордамар","Hordemar City"}}},{k="STRAT",kind="loot",item=16692,w={"Перчатки Преданности","Devout Gloves"},from={"Архивариус Галфорд","Archivist Galford"},spread=false,p={{"STRAT_LIVE",1,0.271,0.751,10811,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [8935]={{k="BRS",kind="loot",item=16712,w={"Перчатки Незаметности","Shadowcraft Gloves"},from={"Темная охотница Вос'гаджин","Shadow Hunter Vosh'gajin"},spread=false,p={{"LBRS",2,0.556,0.72,9236,"Тазз'Алаор","Tazz'Alaor"}}}},
    [8936]={{k="SCHOLO",kind="loot",item=16702,w={"Пояс Багрового Тумана","Dreadmist Belt"},from={"Некромант Некроситета","Scholomance Necromancer"},spread=true,p={{"SCHOLO",1,0.4,0.452,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.425,0.637,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.37,0.665,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.734,0.712,10505,"Ведьмин зал","The Coven "},{"SCHOLO",4,0.376,0.766,10508,"Лаборатория","The Laboratory"},{"SCHOLO",4,0.375,0.695,10508,"Лаборатория","The Laboratory"}}},{k="STRAT",kind="loot",item=16702,w={"Пояс Багрового Тумана","Dreadmist Belt"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.279,0.435,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.732,0.507,11121,"Улица Испытаний","The Gauntlet"}}},{k="SCHOLO",kind="loot",item=16705,w={"Повязки Багрового Тумана","Dreadmist Wraps"},from={"Некромант Некроситета","Scholomance Necromancer"},spread=true,p={{"SCHOLO",1,0.4,0.452,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.425,0.637,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.37,0.665,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.734,0.712,10505,"Ведьмин зал","The Coven "},{"SCHOLO",4,0.376,0.766,10508,"Лаборатория","The Laboratory"},{"SCHOLO",4,0.375,0.695,10508,"Лаборатория","The Laboratory"}}}},
    [8937]={{k="BRS",kind="loot",item=16736,w={"Пояс Доблести","Belt of Valor"},from={"Берсерк из племени Тлеющего Терновника","Smolderthorn Berserker"},spread=true,p={{"LBRS",1,0.565,0.625,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",6,0.56,0.622,9568,"Чертог Битвы","Chamber of Battle"},{"LBRS",1,0.596,0.523,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.518,0.585,9596,"Тазз'Алаор","Tazz'Alaor"}}},{k="STRAT",kind="loot",item=16736,w={"Пояс Доблести","Belt of Valor"},from={"Лоскутный ужас","Patchwork Horror"},spread=true,p={{"STRAT_UD",1,0.46,0.219,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.434,0.107,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_LIVE",1,0.826,0.32,10558,"Праздничная улица","Festival Lane"},{"STRAT_LIVE",1,0.597,0.53,10393,"Королевская площадь","King's Square"},{"STRAT_LIVE",1,0.601,0.319,10516,"Торговый ряд","Market Row"},{"STRAT_UD",1,0.418,0.266,10439,"Площадь Живодерни","Slaughter Square"}}}},
    [8938]={{k="BRS",kind="loot",item=16680,w={"Пояс загонщика","Beaststalker's Belt"},from={"Охотник за головами из племени Тлеющего Терновника","Smolderthorn Headhunter"},spread=true,p={{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.493,0.578,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.514,0.473,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.642,0.588,9237,"Ордамар","Hordemar City"},{"LBRS",6,0.572,0.462,9568,"Горн","The Furnace"},{"LBRS",1,0.581,0.434,9237,"Ордамар","Hordemar City"}}},{k="BRS",kind="loot",item=16676,w={"Перчатки загонщика","Beaststalker's Gloves"},from={"Воевода Вун","War Master Voone"},spread=false,p={{"LBRS",1,0.53,0.544,9237,"Тазз'Алаор","Tazz'Alaor"}}}},
    [8939]={{k="BRS",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Мистик из племени Тлеющего Терновника","Smolderthorn Mystic"},spread=true,p={{"LBRS",2,0.52,0.578,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.662,0.567,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",2,0.557,0.673,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.534,0.522,9237,"Ордамар","Hordemar City"}}},{k="SCHOLO",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Адепт Некроситета","Scholomance Adept"},spread=true,p={{"SCHOLO",2,0.331,0.324,10503,"Некроситет","Scholomance"},{"SCHOLO",1,0.32,0.503,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.358,0.668,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.236,0.457,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.248,0.667,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.407,0.45,14861,"Некроситет","Scholomance"}}},{k="STRAT",kind="loot",item=16685,w={"Пояс Магистра","Magister's Belt"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.279,0.435,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.732,0.507,11121,"Улица Испытаний","The Gauntlet"}}},{k="SCHOLO",kind="loot",item=16684,w={"Перчатки Магистра","Magister's Gloves"},from={"Адепт Некроситета","Scholomance Adept"},spread=true,p={{"SCHOLO",2,0.331,0.324,10503,"Некроситет","Scholomance"},{"SCHOLO",1,0.32,0.503,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.358,0.668,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.236,0.457,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.248,0.667,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.407,0.45,14861,"Некроситет","Scholomance"}}}},
    [8940]={{k="BRS",kind="loot",item=16696,w={"Пояс Преданности","Devout Belt"},from={"Чароплет из легиона Изрубленного Щита","Scarshield Spellbinder"},spread=true,p={{"LBRS",2,0.531,0.596,9236,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.51,0.483,9237,"Ордамар","Hordemar City"},{"LBRS",1,0.505,0.684,9596,"Ордамар","Hordemar City"},{"LBRS",1,0.642,0.568,9237,"Ордамар","Hordemar City"},{"LBRS",4,0.379,0.377,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.473,0.558,9596,"Ордамар","Hordemar City"}}},{k="STRAT",kind="loot",item=16692,w={"Перчатки Преданности","Devout Gloves"},from={"Архивариус Галфорд","Archivist Galford"},spread=false,p={{"STRAT_LIVE",1,0.271,0.751,10811,"Бастион Алого ордена","The Scarlet Bastion"}}}},
    [8941]={{k="BRS",kind="loot",item=16712,w={"Перчатки Незаметности","Shadowcraft Gloves"},from={"Темная охотница Вос'гаджин","Shadow Hunter Vosh'gajin"},spread=false,p={{"LBRS",2,0.556,0.72,9236,"Тазз'Алаор","Tazz'Alaor"}}}},
    [8942]={{k="BRS",kind="loot",item=16672,w={"Рукавицы Стихий","Gauntlets of Elements"},from={"Пиростраж Созерцатель Углей","Pyroguard Emberseer"},spread=false,p={{"UBRS",1,0.303,0.271,9816,"Зал Оков","Hall of Binding"}}}},
    [8943]={{k="SCHOLO",kind="loot",item=16702,w={"Пояс Багрового Тумана","Dreadmist Belt"},from={"Некромант Некроситета","Scholomance Necromancer"},spread=true,p={{"SCHOLO",1,0.4,0.452,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.425,0.637,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.37,0.665,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.734,0.712,10505,"Ведьмин зал","The Coven "},{"SCHOLO",4,0.376,0.766,10508,"Лаборатория","The Laboratory"},{"SCHOLO",4,0.375,0.695,10508,"Лаборатория","The Laboratory"}}},{k="STRAT",kind="loot",item=16702,w={"Пояс Багрового Тумана","Dreadmist Belt"},from={"Темный чародей из секты Тузадин","Thuzadin Shadowcaster"},spread=true,p={{"STRAT_UD",1,0.677,0.252,10438,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.595,0.468,10437,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.742,0.418,10436,"Улица Испытаний","The Gauntlet"},{"STRAT_UD",1,0.599,0.317,10809,"Улица Испытаний","The Gauntlet"},{"STRAT_LIVE",1,0.279,0.435,11032,"Зал Света","The Hall of Lights"},{"STRAT_UD",1,0.732,0.507,11121,"Улица Испытаний","The Gauntlet"}}},{k="SCHOLO",kind="loot",item=16705,w={"Повязки Багрового Тумана","Dreadmist Wraps"},from={"Некромант Некроситета","Scholomance Necromancer"},spread=true,p={{"SCHOLO",1,0.4,0.452,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.425,0.637,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.37,0.665,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.734,0.712,10505,"Ведьмин зал","The Coven "},{"SCHOLO",4,0.376,0.766,10508,"Лаборатория","The Laboratory"},{"SCHOLO",4,0.375,0.695,10508,"Лаборатория","The Laboratory"}}}},
    [8944]={{k="BRS",kind="loot",item=16736,w={"Пояс Доблести","Belt of Valor"},from={"Берсерк из племени Тлеющего Терновника","Smolderthorn Berserker"},spread=true,p={{"LBRS",1,0.565,0.625,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",6,0.56,0.622,9568,"Чертог Битвы","Chamber of Battle"},{"LBRS",1,0.596,0.523,9237,"Тазз'Алаор","Tazz'Alaor"},{"LBRS",1,0.518,0.585,9596,"Тазз'Алаор","Tazz'Alaor"}}},{k="STRAT",kind="loot",item=16736,w={"Пояс Доблести","Belt of Valor"},from={"Лоскутный ужас","Patchwork Horror"},spread=true,p={{"STRAT_UD",1,0.46,0.219,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_UD",1,0.434,0.107,10439,"Площадь Живодерни","Slaughter Square"},{"STRAT_LIVE",1,0.826,0.32,10558,"Праздничная улица","Festival Lane"},{"STRAT_LIVE",1,0.597,0.53,10393,"Королевская площадь","King's Square"},{"STRAT_LIVE",1,0.601,0.319,10516,"Торговый ряд","Market Row"},{"STRAT_UD",1,0.418,0.266,10439,"Площадь Живодерни","Slaughter Square"}}}},
    [8945]={{k="STRAT",kind="kill",item=nil,w={"Исида Хармон","Ysida Harmon"},from={"Исида Хармон","Ysida Harmon"},spread=false,p={{"STRAT_UD",1,0.37,0.187,10440,"Живодерня","The Slaughter House"}}}},
    [8949]={{k="DMAUL",kind="loot",item=21982,w={"Боевые бусы огров","Ogre Warbeads"},from={"Громила из клана Гордок","Gordok Brute"},spread=true,p={{"DM_N",1,0.244,0.589,14323,"Гибельные залы","Halls of Destruction"},{"DM_N",1,0.553,0.868,14321,"Забытый Город","Dire Maul"},{"DM_N",1,0.562,0.728,14322,"Забытый Город","Dire Maul"},{"DM_N",1,0.706,0.87,14326,"Забытый Город","Dire Maul"},{"DM_N",1,0.464,0.854,14321,"Забытый Город","Dire Maul"},{"DM_N",1,0.253,0.674,14323,"Гибельные залы","Halls of Destruction"}}}},
    [8950]={{k="DMAUL",kind="loot",item=22224,w={"Сущность язвительного призрака","Jeering Spectre's Essence"},from={"Элдретарский колдун","Eldreth Sorcerer"},spread=true,p={{"DM_W",2,0.445,0.219,11487,"Двор Высокорожденных","Court of the Highborne"},{"DM_W",2,0.361,0.372,11487,"Двор Высокорожденных","Court of the Highborne"},{"DM_W",2,0.369,0.706,11487,"Двор Высокорожденных","Court of the Highborne"},{"DM_W",1,0.234,0.62,11489,"Двор Высокорожденных","Court of the Highborne"},{"DM_W",2,0.575,0.167,11487,"Двор Высокорожденных","Court of the Highborne"},{"DM_W",1,0.15,0.289,11489,"Двор Высокорожденных","Court of the Highborne"}}},{k="SCHOLO",kind="loot",item=20520,w={"Темная руна","Dark Rune"},from={"Некромант Некроситета","Scholomance Necromancer"},spread=true,p={{"SCHOLO",2,0.482,0.302,10503,"Чертог Призыва","Chamber of Summoning"},{"SCHOLO",2,0.424,0.213,10503,"Чертог Призыва","Chamber of Summoning"},{"SCHOLO",1,0.4,0.452,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.425,0.637,14861,"Некроситет","Scholomance"},{"SCHOLO",1,0.37,0.665,14861,"Некроситет","Scholomance"},{"SCHOLO",3,0.734,0.712,10505,"Ведьмин зал","The Coven "}}}},
    [8951]={{k="BRS",kind="loot",item=16715,w={"Сапоги Буйного сердца","Wildheart Boots"},from={"Мать Дымная Паутина","Mother Smolderweb"},spread=false,p={{"LBRS",1,0.65,0.744,9237,"Паучий лабиринт","Skitterweb Tunnels"}}},{k="STRAT",kind="loot",item=16719,w={"Килт Буйного сердца","Wildheart Kilt"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [8952]={{k="STRAT",kind="loot",item=16675,w={"Сапоги загонщика","Beaststalker's Boots"},from={"Неруб'энкан","Nerub'enkan"},spread=false,p={{"STRAT_UD",1,0.564,0.469,10437,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16678,w={"Штаны загонщика","Beaststalker's Pants"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="BRS",kind="loot",item=16679,w={"Оплечье загонщика","Beaststalker's Mantle"},from={"Властитель Змейталак","Overlord Wyrmthalak"},spread=false,p={{"LBRS",6,0.56,0.553,9568,"Чертог Битвы","Chamber of Battle"}}}},
    [8953]={{k="STRAT",kind="loot",item=16682,w={"Сапоги Магистра","Magister's Boots"},from={"Певчий Форрестен","Hearthsinger Forresten"},spread=false,p={{"STRAT_LIVE",1,0.847,0.454,10558,"Праздничная улица","Festival Lane"}}},{k="STRAT",kind="loot",item=16687,w={"Поножи Магистра","Magister's Leggings"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [8954]={{k="STRAT",kind="loot",item=16728,w={"Ножные латы из светлостали","Lightforge Legplates"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="BRS",kind="loot",item=16729,w={"Наплеч из светлостали","Lightforge Spaulders"},from={"Зверь","The Beast"},spread=false,p={{"UBRS",1,0.648,0.305,10430,"Горн","The Furnace"}}}},
    [8955]={{k="STRAT",kind="loot",item=16691,w={"Сандалии Преданности","Devout Sandals"},from={"Малекай Бледный","Maleki the Pallid"},spread=false,p={{"STRAT_UD",1,0.682,0.199,10438,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16694,w={"Юбка Преданности","Devout Skirt"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [8956]={{k="SCHOLO",kind="loot",item=16711,w={"Сапоги Незаметности","Shadowcraft Boots"},from={"Громоклин","Rattlegore"},spread=false,p={{"SCHOLO",2,0.318,0.684,10433,"Великий оссуарий","The Great Ossuary"}}},{k="STRAT",kind="loot",item=16709,w={"Штаны Незаметности","Shadowcraft Pants"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="STRAT",kind="loot",item=16708,w={"Наплеч Незаметности","Shadowcraft Spaulders"},from={"Мастер-канонир Вилли","Cannon Master Willey"},spread=false,p={{"STRAT_LIVE",1,0.036,0.501,10997,"Арсенал","The Hoard"}}}},
    [8957]={{k="BRS",kind="loot",item=16670,w={"Сапоги Стихий","Boots of Elements"},from={"Вождь Омокк","Highlord Omokk"},spread=false,p={{"LBRS",3,0.351,0.553,9196,"Мок'Дум","Mok'Doom"}}},{k="STRAT",kind="loot",item=16668,w={"Килт Стихий","Kilt of Elements"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [8958]={{k="STRAT",kind="loot",item=16704,w={"Сандалии Багрового Тумана","Dreadmist Sandals"},from={"Баронесса Анастари","Baroness Anastari"},spread=false,p={{"STRAT_UD",1,0.75,0.468,10436,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16699,w={"Поножи Багрового Тумана","Dreadmist Leggings"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="SCHOLO",kind="loot",item=16701,w={"Оплечье Багрового Тумана","Dreadmist Mantle"},from={"Джандис Баров","Jandice Barov"},spread=false,p={{"SCHOLO",3,0.543,0.144,10901,"Некроситет","Scholomance"}}}},
    [8959]={{k="STRAT",kind="loot",item=16732,w={"Ножные латы Доблести","Legplates of Valor"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="BRS",kind="loot",item=16733,w={"Наплеч Доблести","Spaulders of Valor"},from={"Вождь Ренд Чернорук","Warchief Rend Blackhand"},spread=false,p={{"UBRS",1,0.512,0.245,10339,"Стадион Черной горы","Blackrock Stadium"}}}},
    [8961]={{k="BRD",kind="loot",item=21987,w={"Огневит Опалителя","Incendicite of Incendius"},from={"Лорд Опалитель","Lord Incendius"},spread=false,p={{"BRD",1,0.561,0.312,9017,"Тенегорн","Shadowforge City"}}},{k="BRS",kind="loot",item=21988,w={"Уголь Созерцателя Углей","Ember of Emberseer"},from={"Пиростраж Созерцатель Углей","Pyroguard Emberseer"},spread=false,p={{"UBRS",1,0.303,0.271,9816,"Зал Оков","Hall of Binding"}}}},
    [8994]={{k="BRS",kind="loot",item=22138,w={"Боевые наручи Черной горы","Blackrock Bracer"},from={"Послушник из легиона Изрубленного Щита","Scarshield Acolyte"},spread=true,p={{"UBRS",1,0.325,0.273,9816,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.504,0.675,9596,"Ордамар","Hordemar City"},{"LBRS",4,0.372,0.387,10584,"Зал Чернорука","Hall of Blackhand"},{"LBRS",1,0.499,0.443,9237,"Ордамар","Hordemar City"},{"LBRS",5,0.375,0.637,9718,"Ордамар","Hordemar City"},{"LBRS",3,0.332,0.483,9196,"Зал Чернорука","Hall of Blackhand"}}}},
    [9014]={{k="SCHOLO",kind="loot",item=16686,w={"Корона Магистра","Magister's Crown"},from={"Темный магистр Гандлинг","Darkmaster Gandling"},spread=false,p={{"SCHOLO",3,0.736,0.464,1853,"Кабинет Директора","Headmaster's Study"}}},{k="BRS",kind="loot",item=16688,w={"Одеяния Магистра","Magister's Robes"},from={"Генерал Драккисат","General Drakkisath"},spread=false,p={{"UBRS",1,0.334,0.453,10363,"Верховный трон","Spire Throne"}}}},
    [9016]={{k="BRS",kind="loot",item=16715,w={"Сапоги Буйного сердца","Wildheart Boots"},from={"Мать Дымная Паутина","Mother Smolderweb"},spread=false,p={{"LBRS",1,0.65,0.744,9237,"Паучий лабиринт","Skitterweb Tunnels"}}},{k="STRAT",kind="loot",item=16719,w={"Килт Буйного сердца","Wildheart Kilt"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [9017]={{k="STRAT",kind="loot",item=16675,w={"Сапоги загонщика","Beaststalker's Boots"},from={"Неруб'энкан","Nerub'enkan"},spread=false,p={{"STRAT_UD",1,0.564,0.469,10437,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16678,w={"Штаны загонщика","Beaststalker's Pants"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="BRS",kind="loot",item=16679,w={"Оплечье загонщика","Beaststalker's Mantle"},from={"Властитель Змейталак","Overlord Wyrmthalak"},spread=false,p={{"LBRS",6,0.56,0.553,9568,"Чертог Битвы","Chamber of Battle"}}}},
    [9018]={{k="STRAT",kind="loot",item=16682,w={"Сапоги Магистра","Magister's Boots"},from={"Певчий Форрестен","Hearthsinger Forresten"},spread=false,p={{"STRAT_LIVE",1,0.847,0.454,10558,"Праздничная улица","Festival Lane"}}},{k="STRAT",kind="loot",item=16687,w={"Поножи Магистра","Magister's Leggings"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [9019]={{k="STRAT",kind="loot",item=16691,w={"Сандалии Преданности","Devout Sandals"},from={"Малекай Бледный","Maleki the Pallid"},spread=false,p={{"STRAT_UD",1,0.682,0.199,10438,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16694,w={"Юбка Преданности","Devout Skirt"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}}},
    [9020]={{k="SCHOLO",kind="loot",item=16711,w={"Сапоги Незаметности","Shadowcraft Boots"},from={"Громоклин","Rattlegore"},spread=false,p={{"SCHOLO",2,0.318,0.684,10433,"Великий оссуарий","The Great Ossuary"}}},{k="STRAT",kind="loot",item=16709,w={"Штаны Незаметности","Shadowcraft Pants"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="STRAT",kind="loot",item=16708,w={"Наплеч Незаметности","Shadowcraft Spaulders"},from={"Мастер-канонир Вилли","Cannon Master Willey"},spread=false,p={{"STRAT_LIVE",1,0.036,0.501,10997,"Арсенал","The Hoard"}}}},
    [9021]={{k="STRAT",kind="loot",item=16704,w={"Сандалии Багрового Тумана","Dreadmist Sandals"},from={"Баронесса Анастари","Baroness Anastari"},spread=false,p={{"STRAT_UD",1,0.75,0.468,10436,"Улица Испытаний","The Gauntlet"}}},{k="STRAT",kind="loot",item=16699,w={"Поножи Багрового Тумана","Dreadmist Leggings"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="SCHOLO",kind="loot",item=16701,w={"Оплечье Багрового Тумана","Dreadmist Mantle"},from={"Джандис Баров","Jandice Barov"},spread=false,p={{"SCHOLO",3,0.543,0.144,10901,"Некроситет","Scholomance"}}}},
    [9022]={{k="STRAT",kind="loot",item=16732,w={"Ножные латы Доблести","Legplates of Valor"},from={"Барон Ривендер","Baron Rivendare"},spread=false,p={{"STRAT_UD",1,0.372,0.199,10440,"Живодерня","The Slaughter House"}}},{k="BRS",kind="loot",item=16733,w={"Наплеч Доблести","Spaulders of Valor"},from={"Вождь Ренд Чернорук","Warchief Rend Blackhand"},spread=false,p={{"UBRS",1,0.512,0.245,10339,"Стадион Черной горы","Blackrock Stadium"}}}},
}
-- END INSIDE SPOTS
