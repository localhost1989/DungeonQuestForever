local _, P = ...
local L = P.L or function(s) return s end
local atlas = P.Core

-- The owner (15.11.2026): "a button somewhere in sight, and by it you see the things for your
-- class: an inventory that opens with the best things alone, where you can compare, and it
-- says in which dungeon, from which boss it drops." As ChatGPT drew it and the owner
-- approved: a window like the game's own character frame - the character in the middle,
-- the places of the things round it - with the level and the branch of talents on top; by
-- every place the best thing for it, where it comes from, and whether it is worn already or
-- how much better than the worn it is. The lists are those of GearData.lua (made by
-- dungeon-quest-handoff/make-gear.py).

-- The 17 places, in the order of the lists, with the game's own slots.
local SLOT = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot"}
local SLOTNAME = {L"Голова", L"Шея", L"Плечи", L"Спина", L"Грудь", L"Запястья", L"Кисти рук", L"Пояс", L"Ноги", L"Ступни",
    L"Кольцо", L"Кольцо", L"Аксессуар", L"Аксессуар", L"Правая рука", L"Левая рука", L"Дальний бой"}
local RANGED = {MAGE=L"Жезл", PRIEST=L"Жезл", WARLOCK=L"Жезл", DRUID=L"Реликвия", PALADIN=L"Реликвия", SHAMAN=L"Реликвия"}
-- Where each place stands: seven on the left, seven on the right, the weapons below.
local LEFTSIDE, RIGHTSIDE, BELOW = {1, 2, 3, 4, 5, 6, 7}, {8, 9, 10, 11, 12, 13, 14}, {15, 16, 17}
-- The branches of talents, should the game not tell them, in the order of its tabs.
local SPEC = {
    MAGE={L"Тайная магия", L"Огонь", L"Лёд"}, PRIEST={L"Послушание", L"Свет", L"Тьма"}, WARLOCK={L"Колдовство", L"Демонология", L"Разрушение"},
    DRUID={L"Баланс", L"Сила зверя", L"Исцеление"}, HUNTER={L"Чувство зверя", L"Стрельба", L"Выживание"},
    PALADIN={L"Свет", L"Защита", L"Возмездие"}, ROGUE={L"Ликвидация", L"Бой", L"Скрытность"},
    SHAMAN={L"Стихии", L"Совершенствование", L"Исцеление"}, WARRIOR={L"Оружие", L"Неистовство", L"Защита"},
}
local CRAFT = {Blacksmithing=L"Кузнечное дело", Enchanting=L"Наложение чар", Engineering=L"Инженерное дело",
    Leatherworking=L"Кожевничество", Tailoring=L"Портняжное дело"}
local QUALITY = {[0]={.62, .62, .62}, [1]={1, 1, 1}, [2]={.12, 1, 0}, [3]={0, .44, .87}, [4]={.64, .21, .93}, [5]={1, .5, 0}}

local W, H, CELL, CELLH, PAD = 620, 534, 196, 50, 14
local frame, specAt, levelAt
local russian = (GetLocale and GetLocale() or "enUS") == "ruRU"

local function playerClass()
    return (UnitClassBase and UnitClassBase("player")) or (UnitClass and select(2, UnitClass("player")))
end
local function side()
    return (UnitFactionGroup and UnitFactionGroup("player")) == "Alliance" and "a" or "h"
end
local function level()
    return (UnitLevel and UnitLevel("player")) or 60
end

-- The branches of the class: the game's own names and pictures, and the points spent in each.
local function specs(class)
    local list = {}
    for i, entry in ipairs(P.GearPicks and P.GearPicks[class] or {}) do
        local name, icon, points
        if GetTalentTabInfo then
            local ok, a, b, c, d, e = pcall(GetTalentTabInfo, i)
            if ok then
                if type(a) == "number" then name, icon, points = b, d, e else name, icon, points = a, b, c end
            end
        end
        list[i] = {name=(type(name) == "string" and name ~= "") and name or (SPEC[class] or {})[i] or entry.key, icon=icon,
            points=tonumber(points) or 0, picks=entry}
    end
    return list
end
-- The branch the character has put the most points into.
local function mainSpec(list)
    local best, most = 1, -1
    for i, spec in ipairs(list) do if spec.points > most then best, most = i, spec.points end end
    return best
end
-- The levels to look at: the step of five this one is in, the two after it, and 60.
local function levels()
    local first = math.min(60, math.max(5, math.ceil(level() / 5) * 5))
    local list, seen = {}, {}
    for _, value in ipairs({first, first + 5, first + 10, 60}) do
        if value <= 60 and not seen[value] then seen[value] = true; list[#list+1] = value end
    end
    return list
end

-- What a thing is, from the lists: its quality, the level it asks, its picture, its name,
-- and where it comes from (the source for this side first).
local function split(text)
    local out = {}
    for part in (text .. "|"):gmatch("(.-)|") do out[#out+1] = part end
    return out
end
local function areaName(area)
    area = tonumber(area) or 0
    if area <= 0 or not (C_Map and C_Map.GetAreaInfo) then return nil end
    local ok, name = pcall(C_Map.GetAreaInfo, area)
    if ok and type(name) == "string" and name ~= "" then return name end
end
-- A dungeon by its English name: the name the addon gives it, else the game's name of its zone.
local function dungeonName(english, area)
    local bare = english:gsub("^The ", "")
    for _, d in ipairs(atlas and atlas.Dungeons or {}) do
        local en = d.nameEn and tostring(d.nameEn):gsub("^The ", "")
        if en == bare then return (atlas.DungeonName and atlas.DungeonName(d)) or d.name end
    end
    return areaName(area) or english
end
function P.GearSource(id)
    local item = P.GearItems and P.GearItems[id]
    if not item then return nil end
    local mine, any = side(), nil
    for i = 6, #item do
        local s = split(item[i])
        local source = {kind=s[1], side=s[2], id=tonumber(s[3]), area=tonumber(s[4]), who=(russian and s[6] ~= "" and s[6]) or s[5], where=s[7]}
        any = any or source
        if source.side == "b" or source.side == mine then return source end
    end
    return any
end
-- Where a thing comes from: short, for the line under its name; and in full, for its tooltip.
function P.GearFrom(id)
    local s = P.GearSource(id)
    if not s then return "", "" end
    if s.kind == "d" then
        local place = dungeonName(s.where, s.area)
        return place .. " • " .. s.who, (L"Подземелье «%s», босс: %s"):format(place, s.who)
    elseif s.kind == "q" then
        local place = areaName(s.area)
        if not place and s.where ~= "" then place = dungeonName(s.where, 0) end
        return L"задание" .. (place and (" • " .. place) or (" «" .. s.who .. "»")), (L"Задание «%s»"):format(s.who) .. (place and (", " .. place) or "")
    elseif s.kind == "c" then
        local craft = CRAFT[s.who] or s.who
        return L"ремесло • " .. craft, L"Делается ремеслом: " .. craft
    elseif s.kind == "v" then
        local place = areaName(s.area) or s.where
        return L"торговец • " .. place, (L"Продаёт %s, %s"):format(s.who, place)
    end
    local place = areaName(s.area) or s.where
    return s.who .. " • " .. place, (L"Падает с «%s», %s"):format(s.who, place)
end
local function itemName(id)
    local item = P.GearItems[id]
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name = pcall(info or function() end, id)
    if ok and type(name) == "string" and name ~= "" then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return (russian and item[5] ~= "" and item[5]) or item[4]
end
local function itemIcon(id)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local ok, _, _, _, _, icon = pcall(instant or function() end, id)
    if ok and icon then return icon end
    local item = P.GearItems[id]
    return item[3] ~= "" and ("Interface\\Icons\\" .. item[3]) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- Is the thing on the character: in any place.
local function wornNow(id)
    if not (GetInventoryItemID and id) then return false end
    for slot = 1, 19 do
        if GetInventoryItemID("player", slot) == id then return true end
    end
    return false
end

-- The things of a branch at a level, place by place (0 where nothing is clearly better).
function P.GearPicksFor(class, specIndex, at)
    local entry = P.GearPicks and P.GearPicks[class] and P.GearPicks[class][specIndex]
    local row = entry and entry[at .. side()]
    local list = {}
    if not row then return list end
    for id in (row .. ","):gmatch("(%d+),") do list[#list+1] = tonumber(id) end
    return list
end

-- ------------------------------------------
-- The window
-- ------------------------------------------
local function paint(texture, r, g, b, a)
    if texture.SetColorTexture then texture:SetColorTexture(r, g, b, a or 1) else texture:SetTexture(r, g, b, a or 1) end
end
-- A switch of the top row: a dark plate with a thin rim, gold when it is the chosen one.
local function switch(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(24)
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetAllPoints(b)
    paint(b.back, .09, .07, .05, .92)
    b.rim = {}
    for i, edge in ipairs({{"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"}, {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"}}) do
        local t = b:CreateTexture(nil, "BORDER")
        t:SetPoint(edge[1], b, edge[1], 0, 0)
        t:SetPoint(edge[2], b, edge[2], 0, 0)
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        b.rim[i] = t
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    function b:Look(text, icon, on)
        self.label:ClearAllPoints()
        if icon then
            self.icon:SetTexture(icon)
            self.icon:Show()
            self.label:SetPoint("LEFT", self.icon, "RIGHT", 5, 0)
        else
            self.icon:Hide()
            self.label:SetPoint("CENTER", self, "CENTER", 0, 0)
        end
        self.label:SetText(text)
        local width = (tonumber(self.label:GetStringWidth()) or 30) + (icon and 34 or 18)
        self:SetWidth(math.max(icon and 60 or 40, width))
        for _, t in ipairs(self.rim) do
            if on then paint(t, 1, .82, .25, 1) else paint(t, .45, .38, .27, 1) end
        end
        if on then self.label:SetTextColor(1, .82, .25) else self.label:SetTextColor(.9, .88, .82) end
    end
    return b
end

-- A place of the character: the picture of the thing in a rim of its quality, and by it the
-- name of the place, the thing, where it comes from, and what it is to the character.
local function cell(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CELL, CELLH)
    c.plate = c:CreateTexture(nil, "BACKGROUND")
    c.plate:SetAllPoints(c)
    paint(c.plate, .08, .06, .04, .62)
    c.edge = c:CreateTexture(nil, "BORDER")
    c.edge:SetSize(42, 42)
    c.edge:SetPoint("LEFT", c, "LEFT", 4, 0)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(38, 38)
    c.icon:SetPoint("CENTER", c.edge, "CENTER", 0, 0)
    if c.icon.SetTexCoord then c.icon:SetTexCoord(.07, .93, .07, .93) end
    local x = 52
    c.slot = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.slot:SetPoint("TOPLEFT", c, "TOPLEFT", x, -2)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", x, -13)
    c.from = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.from:SetPoint("TOPLEFT", c, "TOPLEFT", x, -27)
    c.state = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.state:SetPoint("TOPLEFT", c, "TOPLEFT", x, -38)
    for _, text in ipairs({c.slot, c.name, c.from, c.state}) do
        text:SetWidth(CELL - x - 4)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
    end
    c.from:SetTextColor(.80, .76, .66)
    c:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    c:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.id then
            local ok = GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
            if not ok then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.id) end
            local _, full = P.GearFrom(self.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(full, 1, .82, .25, true)
            GameTooltip:AddLine(L"Shift+щелчок — ссылка в чат, Ctrl+щелчок — примерить.", .6, .6, .6, true)
        else
            GameTooltip:AddLine(self.slotName or "", 1, .82, .25)
            GameTooltip:AddLine(L"Для этой ветки на этом уровне нет вещи заметно лучше обычной.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    c:SetScript("OnClick", function(self)
        if not self.id then return end
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local _, link = info and info(self.id)
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    return c
end

local draw
local function create()
    local ok, f = pcall(CreateFrame, "Frame", "DungeonQuestForeverGear", UIParent, "PortraitFrameTemplate")
    if not ok or not f then
        ok, f = pcall(CreateFrame, "Frame", "DungeonQuestForeverGear", UIParent, "BasicFrameTemplateWithInset")
        if not ok then f = CreateFrame("Frame", "DungeonQuestForeverGear", UIParent) end
    end
    frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "DungeonQuestForeverGear") end
    local title = L"Лучшие вещи"
    if f.SetTitle then pcall(f.SetTitle, f, title)
    elseif type(f.TitleText) == "table" and f.TitleText.SetText then f.TitleText:SetText(title) end
    if type(f.TitleContainer) == "table" and type(f.TitleContainer.TitleText) == "table" then f.TitleContainer.TitleText:SetText(title) end
    f.portrait = (type(f.PortraitContainer) == "table" and f.PortraitContainer.portrait) or f.portrait or f.Portrait
    if type(f.InsetBg) == "table" and f.InsetBg.Hide then f.InsetBg:Hide() end
    if type(f.Inset) == "table" and f.Inset.Hide then f.Inset:Hide() end
    -- A dark ground under the top row, whatever the frame of the game brings of its own.
    local ground = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    ground:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -22)
    ground:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    paint(ground, .06, .05, .04, .95)

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.sub:SetPoint("TOP", f, "TOP", 10, -32)
    f.sub:SetText("Dungeon Quest Forever")
    f.sub:SetTextColor(.85, .80, .70)

    -- The top row: the level, then the branch.
    f.levelWord = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.levelWord:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -64)
    f.levelWord:SetText(L"Уровень:")
    f.levelTabs, f.specTabs = {}, {}
    for i = 1, 4 do
        local b = switch(f)
        b:SetScript("OnClick", function(self) levelAt = self.value; draw() end)
        f.levelTabs[i] = b
    end
    for i = 1, 3 do
        local b = switch(f)
        b:SetScript("OnClick", function(self)
            specAt = self.value
            if P.char then P.char.gearSpec = specAt end
            draw()
        end)
        f.specTabs[i] = b
    end
    f.specWord = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.specWord:SetText(L"Ветка:")

    -- The page: the game's parchment, the character in the middle.
    local page = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    page:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    page:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 4, -90)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD + 4, 8)
    page:SetVertexColor(.80, .70, .55)
    f.page = page
    local shade = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    shade:SetAllPoints(page)
    paint(shade, .12, .08, .04, .35)

    local made, model = pcall(CreateFrame, "DressUpModel", nil, f)
    if not made or not model then made, model = pcall(CreateFrame, "PlayerModel", nil, f) end
    if made and model then
        f.model = model
        model:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + CELL + 6, -96)
        model:SetSize(W - 2 * (PAD + CELL + 6), 7 * (CELLH + 3))
        -- Turned by dragging, as the game's own figures are.
        local turning, facing = nil, 0
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function() turning = GetCursorPosition and GetCursorPosition() end)
        model:SetScript("OnMouseUp", function() turning = nil end)
        model:SetScript("OnUpdate", function(self)
            if not turning or not GetCursorPosition then return end
            local x = GetCursorPosition()
            facing = facing + (x - turning) * .02
            turning = x
            if self.SetFacing then self:SetFacing(facing) end
        end)
        model:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L"Ты в этих вещах", 1, .82, .25)
            GameTooltip:AddLine(L"Потяни мышью, чтобы повернуть.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        model:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    f.cells = {}
    for row, index in ipairs(LEFTSIDE) do
        local c = cell(f)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -96 - (row - 1) * (CELLH + 3))
        f.cells[index] = c
    end
    for row, index in ipairs(RIGHTSIDE) do
        local c = cell(f)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", W - PAD - CELL, -96 - (row - 1) * (CELLH + 3))
        f.cells[index] = c
    end
    for i, index in ipairs(BELOW) do
        local c = cell(f)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * ((W - 2 * PAD - CELL) / 2), -96 - 7 * (CELLH + 3) - 4)
        f.cells[index] = c
    end

    -- What the game tells of the things comes a moment later; what is worn changes.
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    local due
    f:SetScript("OnEvent", function(self, event)
        if not self:IsShown() then return end
        if event == "PLAYER_LEVEL_UP" then levelAt = nil end
        due = .3
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if not due then return end
        due = due - (elapsed or 0)
        if due <= 0 then due = nil; draw() end
    end)
    f:Hide()
end

-- The character on the page, dressed in the things of the page.
local function dress(ids)
    local model = frame and frame.model
    if not model then return end
    pcall(model.SetUnit, model, "player")
    local function wear()
        if model.Undress then pcall(model.Undress, model) end
        for _, id in ipairs(ids) do
            if id > 0 and model.TryOn then pcall(model.TryOn, model, "item:" .. id) end
        end
    end
    wear()
    -- The figure loads a moment after it is set; dressed again then.
    if C_Timer and C_Timer.After then C_Timer.After(.2, wear) end
end

function draw()
    if not frame then return end
    local class = playerClass()
    local list = specs(class)
    if #list == 0 then return end
    specAt = specAt or (P.char and tonumber(P.char.gearSpec)) or mainSpec(list)
    if not list[specAt] then specAt = mainSpec(list) end
    local steps = levels()
    local fits = false
    for _, value in ipairs(steps) do if value == levelAt then fits = true end end
    if not fits then levelAt = steps[1] end

    -- The top row.
    local x = PAD + 4 + (tonumber(frame.levelWord:GetStringWidth()) or 60) + 8
    for i, b in ipairs(frame.levelTabs) do
        local value = steps[i]
        b.value = value
        if value then
            b:Look(tostring(value), nil, value == levelAt)
            b:ClearAllPoints()
            b:SetPoint("LEFT", frame, "TOPLEFT", x, -72)
            b:Show()
            x = x + (tonumber(b:GetWidth()) or 40) + 4
        else
            b:Hide()
        end
    end
    x = x + 14
    frame.specWord:ClearAllPoints()
    frame.specWord:SetPoint("LEFT", frame, "TOPLEFT", x, -72)
    x = x + (tonumber(frame.specWord:GetStringWidth()) or 50) + 8
    for i, b in ipairs(frame.specTabs) do
        local spec = list[i]
        b.value = i
        if spec then
            b:Look(spec.name, spec.icon, i == specAt)
            b:ClearAllPoints()
            b:SetPoint("LEFT", frame, "TOPLEFT", x, -72)
            b:Show()
            x = x + (tonumber(b:GetWidth()) or 80) + 4
        else
            b:Hide()
        end
    end
    local icon = list[specAt].icon
    if frame.portrait and icon then
        if SetPortraitToTexture then pcall(SetPortraitToTexture, frame.portrait, icon) else frame.portrait:SetTexture(icon) end
    end

    -- The places.
    local ids = P.GearPicksFor(class, specAt, levelAt)
    local now = level()
    for index, c in pairs(frame.cells) do
        local id = ids[index] or 0
        local slotName = index == 17 and RANGED[class] or SLOTNAME[index]
        c.slotName = slotName
        c.slot:SetText(slotName)
        if id > 0 and P.GearItems[id] then
            local item = P.GearItems[id]
            c.id = id
            local q = QUALITY[item[1]] or QUALITY[1]
            paint(c.edge, q[1], q[2], q[3], 1)
            c.icon:SetTexture(itemIcon(id))
            c.icon:SetDesaturated(false)
            c.icon:SetAlpha(1)
            c.name:SetText(itemName(id))
            c.name:SetTextColor(q[1], q[2], q[3])
            c.from:SetText((P.GearFrom(id)))
            local state = ""
            if wornNow(id) then
                state = "|cff40e040" .. L"надето" .. "|r |TInterface\\RaidFrame\\ReadyCheck-Ready:11|t"
            elseif (item[2] or 0) > now then
                state = "|cffff9933" .. (L"нужен %d уровень"):format(item[2]) .. "|r"
            else
                local worth = P.Worth and P.Worth(id)
                if worth and worth.known and not worth.unusable and (worth.gain or 0) >= 1 then
                    state = "|cff40e040+" .. ("%.0f"):format(worth.gain) .. L" к надетому" .. "|r"
                end
            end
            c.state:SetText(state)
        else
            c.id = nil
            paint(c.edge, .25, .22, .18, 1)
            local texture
            if GetInventorySlotInfo then
                local found, _, empty = pcall(GetInventorySlotInfo, SLOT[index])
                if found then texture = empty end
            end
            c.icon:SetTexture(texture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            c.icon:SetDesaturated(true)
            c.icon:SetAlpha(.7)
            c.name:SetText("")
            c.from:SetText("")
            c.state:SetText("")
        end
    end
    dress(ids)
end

function P.OpenGear()
    if not (P.GearPicks and P.GearPicks[playerClass() or ""]) then return end
    if not frame then create() end
    if not frame:IsShown() and P.Track then P.Track("GearOpened") end
    frame:Show()
    draw()
    return frame
end
function P.ToggleGear()
    if frame and frame:IsShown() then frame:Hide() return end
    return P.OpenGear()
end
function P.GearView()
    return frame
end
