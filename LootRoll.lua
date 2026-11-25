local _, P = ...
local L = P.L or function(s) return s end

-- The owner, 24.11.2026: "let us make a damn convenient need and greed for dungeons: a good
-- window, and clear who has rolled what and who has not." ChatGPT's layout A, approved the
-- same day: one window, the things rolled for one under another; under each its name, how
-- long is left, what it is to this character, the three buttons, and the five of the group,
-- each with whether his class wears it, what he chose or that he still thinks, the number
-- he threw and a crown for the one who won. It stands in place of the game's own frames.
--
-- What the game tells: START_LOOT_ROLL (the roll and its time), CANCEL_LOOT_ROLL, and on
-- this engine (Forever runs the retail one) LOOT_HISTORY_UPDATE_DROP with
-- C_LootHistory.GetSortedInfoForDrop: each player's choice, his number and the winner.
-- Names may come as secret values in an instance: they are only ever handed to SetText.

local KEEP_DONE = 60          -- seconds a finished roll stays in the window
local ROWS = 5

local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local PASS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local WAIT = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local YES = "Interface\\RaidFrame\\ReadyCheck-Ready"
local NO = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local CROWN = "Interface\\GroupFrame\\UI-Group-LeaderIcon"

local CLASS_WORD = {MAGE=L"маг", WARRIOR=L"воин", PRIEST=L"жрец", ROGUE=L"разбойник", DRUID=L"друид",
    HUNTER=L"охотник", SHAMAN=L"шаман", WARLOCK=L"чернокнижник", PALADIN=L"паладин"}

local function secret(v) return issecretvalue and issecretvalue(v) end
local function now() return GetTime and GetTime() or 0 end

-- The choices as the game numbers them (Enum.EncounterLootDropRollState).
local S = (Enum and Enum.EncounterLootDropRollState) or {NeedMainSpec=0, NeedOffSpec=1, Transmog=2, Greed=3, NoRoll=4, Pass=5}
local function kindOf(state)
    if state == S.NeedMainSpec or state == S.NeedOffSpec then return "need" end
    if state == S.Greed or state == S.Transmog then return "greed" end
    if state == S.Pass then return "pass" end
end

local rolls, order = {}, {}
P.LootRolls = rolls

-- ------------------------------------------
-- What a thing is to whom
-- ------------------------------------------
local function itemOf(link)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (instant and link) then return end
    local ok, id, _, _, equip, _, kind, sub = pcall(instant, link)
    if ok and id then return id, kind, sub, equip end
end

-- Whether a class wears it: what it is of use to (Book.lua's table), a cloak to everyone;
-- nil for what is not worn at all.
function P.RollWears(class, link)
    local _, kind, sub, equip = itemOf(link)
    if not (kind == 2 or kind == 4) then return nil end
    if equip == "INVTYPE_CLOAK" or (kind == 4 and sub == 0) then return true end
    if not (class and P.Wears) then return nil end
    return P.Wears(class, kind, sub) and true or false
end

-- What it is to this character, in a few words and a colour.
function P.RollNote(link)
    local id = itemOf(link)
    if not (id and P.Worth) then return nil end
    local ok, worth = pcall(P.Worth, id)
    if not (ok and type(worth) == "table" and worth.known) then return nil end
    if worth.unusable then return "|cff9d9d9d" .. L"Не для тебя" .. "|r" end
    if worth.worn then return "|cff9d9d9d" .. L"Уже надето" .. "|r" end
    if worth.best and not worth.later then return "|cffffd34d" .. L"Лучшее в слот" .. "|r" end
    if (worth.gain or 0) > 0 then
        return "|cff40e040" .. L"Лучше надетого" .. (" +%.0f"):format(worth.gain) .. "|r" .. (worth.later and ("|cff9d9d9d" .. L", но позже по уровню" .. "|r") or "")
    end
    return "|cff9d9d9d" .. L"Не лучше надетого" .. "|r"
end

-- ------------------------------------------
-- The group and its choices
-- ------------------------------------------
local function shortName(name)
    if type(name) ~= "string" or secret(name) then return nil end
    return (name:match("^[^-]+")) or name
end

-- The five of the group: the player first, as on the layout.
local function members()
    local list = {}
    local units = {"player"}
    if not (IsInRaid and IsInRaid()) then for i = 1, 4 do units[#units+1] = "party" .. i end end
    for _, unit in ipairs(units) do
        local okE, exists = pcall(UnitExists or function() return unit == "player" end, unit)
        if okE and exists and not secret(exists) then
            local okN, name = pcall(UnitName, unit)
            local okC, _, class = pcall(UnitClass, unit)
            list[#list+1] = {unit=unit, name=okN and name or nil, key=okN and shortName(name) or nil, class=okC and not secret(class) and class or nil, me=unit == "player"}
        end
    end
    return list
end

-- The rows of one roll: the group, each with what the history says of him. Whoever the
-- history names and the group does not (a name kept secret) is added as he comes.
local function rowsOf(roll)
    local list, byKey = {}, {}
    for _, m in ipairs(members()) do
        list[#list+1] = m
        if m.key then byKey[m.key] = m end
    end
    for _, info in ipairs(roll.infos or {}) do
        local key = shortName(info.playerName)
        local row = (key and byKey[key]) or (info.isSelf and list[1] and list[1].me and list[1]) or nil
        if not row then
            row = {name=info.playerName, class=not secret(info.playerClass) and info.playerClass or nil}
            list[#list+1] = row
            if key then byKey[key] = row end
        end
        row.state, row.roll, row.winner = info.state, info.roll, info.isWinner
    end
    -- My own choice, known at the click before the history says it.
    if roll.mine and list[1] and list[1].me and list[1].state == nil then list[1].state = roll.mine end
    while #list > ROWS do table.remove(list) end
    return list
end
P.RollRows = rowsOf

-- What a row says: the sign and the words.
local function choiceOf(row, roll)
    local kind = kindOf(row.state)
    local number = (type(row.roll) == "number" and not secret(row.roll)) and (" (" .. row.roll .. ")") or ""
    if kind == "need" then return DICE, "|cff40e040" .. L"Нужно" .. number .. "|r" end
    if kind == "greed" then return COIN, "|cffffd34d" .. L"Не откажусь" .. number .. "|r" end
    if kind == "pass" then return nil, "|cffff6060" .. L"Отказался" .. "|r" end
    if roll.done then return nil, "|cff9d9d9d" .. L"не выбрал" .. "|r" end
    return WAIT, "|cffbcb7ab" .. L"ещё думает…" .. "|r"
end
P.RollChoice = choiceOf

-- ------------------------------------------
-- The window
-- ------------------------------------------
local window
local WIDTH, PAD = 380, 10

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end

local function makeButton(parent, icon, label, kind)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(112, 22)
    b:SetText("|T" .. icon .. ":14:14|t " .. label)
    b.kind = kind
    return b
end

local function newBlock()
    local f = CreateFrame("Frame", nil, window)
    f:SetWidth(WIDTH - 2 * PAD)
    f.icon = CreateFrame("Button", nil, f)
    f.icon:SetSize(36, 36)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.icon.tex = f.icon:CreateTexture(nil, "ARTWORK")
    f.icon.tex:SetAllPoints()
    f.icon:SetScript("OnEnter", function(self)
        local roll = self:GetParent().roll
        if not (roll and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if not roll.done and GameTooltip.SetLootRollItem then pcall(GameTooltip.SetLootRollItem, GameTooltip, roll.id)
        elseif roll.link then pcall(GameTooltip.SetHyperlink, GameTooltip, roll.link) end
        GameTooltip:Show()
    end)
    f.icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
    f.name:SetJustifyH("LEFT")
    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.time:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    f.name:SetPoint("RIGHT", f.time, "LEFT", -6, 0)
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.note:SetJustifyH("LEFT")
    f.won = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.won:SetPoint("TOPRIGHT", f.time, "BOTTOMRIGHT", 0, -4)
    f.buttons = {
        makeButton(f, DICE, L"Нужно", 1),
        makeButton(f, COIN, L"Не откажусь", 2),
        makeButton(f, PASS, L"Отказаться", 0),
    }
    f.buttons[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -44)
    f.buttons[2]:SetPoint("LEFT", f.buttons[1], "RIGHT", 6, 0)
    f.buttons[3]:SetPoint("LEFT", f.buttons[2], "RIGHT", 6, 0)
    for _, b in ipairs(f.buttons) do
        b:SetScript("OnClick", function(self)
            local roll = f.roll
            if not roll or roll.done or roll.mine ~= nil then return end
            if RollOnLoot then pcall(RollOnLoot, roll.id, self.kind) end
            roll.mine = self.kind == 1 and S.NeedMainSpec or self.kind == 2 and S.Greed or S.Pass
            P.LootWindowUpdate()
        end)
    end
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(WIDTH - 2 * PAD - 8, 18)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -72 - (i - 1) * 19)
        r.class = r:CreateTexture(nil, "ARTWORK")
        r.class:SetSize(15, 15)
        r.class:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.name:SetPoint("LEFT", r.class, "RIGHT", 5, 0)
        r.name:SetWidth(78)
        r.name:SetJustifyH("LEFT")
        r.word = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.word:SetPoint("LEFT", r.name, "RIGHT", 2, 0)
        r.word:SetWidth(74)
        r.word:SetJustifyH("LEFT")
        r.wears = r:CreateTexture(nil, "ARTWORK")
        r.wears:SetSize(14, 14)
        r.wears:SetPoint("LEFT", r, "LEFT", 182, 0)
        r.sign = r:CreateTexture(nil, "ARTWORK")
        r.sign:SetSize(15, 15)
        r.sign:SetPoint("LEFT", r.wears, "RIGHT", 10, 0)
        r.choice = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.choice:SetPoint("LEFT", r.sign, "RIGHT", 4, 0)
        r.choice:SetJustifyH("LEFT")
        r.crown = r:CreateTexture(nil, "OVERLAY")
        r.crown:SetSize(14, 14)
        r.crown:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.crown:SetTexture(CROWN)
        f.rows[i] = r
    end
    f:SetHeight(72 + ROWS * 19 + 6)
    return f
end

local blocks = {}
P.LootBlocks = blocks

local function classIcon(texture, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        if texture.SetTexCoord then texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
        texture:Show()
    else
        texture:Hide()
    end
end

local function fill(f, roll)
    f.roll = roll
    f.icon.tex:SetTexture(roll.texture)
    local quality = roll.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[roll.quality]
    f.name:SetText((quality and quality.hex or "|cffffffff") .. (roll.name or "?") .. "|r")
    if f.name.SetTextColor and quality then f.name:SetTextColor(quality.r, quality.g, quality.b) end
    f.note:SetText(roll.note or "")
    if roll.done then
        f.time:SetText(L"Завершено")
        local winner = roll.winnerName
        if roll.allPassed then f.won:SetText("|cff9d9d9d" .. L"Все отказались" .. "|r")
        elseif winner then
            -- (A secret name goes to SetText alone: no sums with it.)
            if secret(winner) then f.won:SetText(winner)
            else f.won:SetText(L"Победитель: " .. winner .. ((type(roll.winnerRoll) == "number" and not secret(roll.winnerRoll)) and (" (" .. roll.winnerRoll .. ")") or "")) end
        else f.won:SetText("") end
    else
        local left = math.max(0, math.floor((roll.ends or 0) - now() + .5))
        f.time:SetText("|T" .. DICE .. ":14:14|t " .. left .. L" с")
        f.won:SetText("")
    end
    for _, b in ipairs(f.buttons) do
        local can = not roll.done and roll.mine == nil and not roll.closed
            and (b.kind ~= 1 or roll.canNeed ~= false) and (b.kind ~= 2 or roll.canGreed ~= false)
        if b.SetEnabled then b:SetEnabled(can) end
    end
    local rows = rowsOf(roll)
    for i, r in ipairs(f.rows) do
        local row = rows[i]
        if row then
            classIcon(r.class, row.class)
            r.name:SetText(row.name or "?")
            if r.name.SetTextColor and row.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class] then
                local c = RAID_CLASS_COLORS[row.class]
                r.name:SetTextColor(c.r, c.g, c.b)
            end
            r.word:SetText(row.class and CLASS_WORD[row.class] and ("(" .. CLASS_WORD[row.class] .. ")") or "")
            local wears = P.RollWears(row.class, roll.link)
            if wears == nil then r.wears:Hide() else r.wears:SetTexture(wears and YES or NO); r.wears:Show() end
            local sign, words = choiceOf(row, roll)
            if sign then r.sign:SetTexture(sign); r.sign:Show() else r.sign:Hide() end
            r.choice:SetText(words)
            if row.winner then r.crown:Show() else r.crown:Hide() end
            r:Show()
        else
            r:Hide()
        end
    end
end

function P.LootWindowUpdate()
    if not window then return end
    -- Finished a minute ago: gone. (No word from the history a while after the time is up:
    -- finished all the same, without a winner to name.)
    for i = #order, 1, -1 do
        local roll = rolls[order[i]]
        if roll and not roll.done and now() > (roll.ends or 0) + 20 then roll.done, roll.doneAt = true, now() end
        if not roll or (roll.done and now() - (roll.doneAt or 0) > KEEP_DONE) then
            if roll then rolls[roll.id] = nil end
            table.remove(order, i)
        end
    end
    local y = -30
    for i, id in ipairs(order) do
        local f = blocks[i] or newBlock()
        blocks[i] = f
        fill(f, rolls[id])
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
        f:Show()
        y = y - (f:GetHeight() or 170) - 8
    end
    for i = #order + 1, #blocks do blocks[i]:Hide() end
    if #order == 0 then window:Hide() return end
    window:SetHeight(-y + 4)
end

local function makeWindow()
    if window or not CreateFrame then return window end
    window = CreateFrame("Frame", "DungeonQuestForeverLoot", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(WIDTH, 220)
    window:SetFrameStrata("HIGH")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if P.char and self.GetPoint then
            local point, _, relative, x, y = self:GetPoint()
            P.char.lootAt = {point, relative, x, y}
        end
    end)
    local at = P.char and P.char.lootAt
    if type(at) == "table" and at[1] then window:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else window:SetPoint("RIGHT", UIParent, "RIGHT", -260, 60) end
    local title = window.TitleText or (window.TitleContainer and window.TitleContainer.TitleText)
    if type(title) == "table" and title.SetText then title:SetText(L"Розыгрыш добычи") end
    window:SetScript("OnUpdate", function(self, elapsed)
        self.tick = (self.tick or 0) + (elapsed or 0)
        if self.tick < .25 then return end
        self.tick = 0
        P.LootWindowUpdate()
    end)
    window:Hide()
    return window
end

-- ------------------------------------------
-- The game's events
-- ------------------------------------------
local function off() return P.char and P.char.lootWindowOff end

function P.LootRollStarted(id, length)
    if off() or not (id and GetLootRollItemInfo) then return end
    local ok, texture, name, _, quality, _, canNeed, canGreed = pcall(GetLootRollItemInfo, id)
    if not ok then return end
    local okLink, link = pcall(GetLootRollItemLink, id)
    local roll = rolls[id] or {}
    roll.id, roll.texture, roll.name, roll.quality = id, texture, name, quality
    roll.canNeed, roll.canGreed = canNeed, canGreed
    roll.link = okLink and link or nil
    roll.duration = (tonumber(length) or 60000) / 1000
    roll.ends = now() + roll.duration
    roll.note = P.RollNote(roll.link)
    roll.done, roll.mine, roll.infos = nil, nil, nil
    if not rolls[id] then order[#order+1] = id end
    rolls[id] = roll
    if makeWindow() then window:Show() end
    P.LootWindowUpdate()
end

-- The history of a drop: matched to a roll by its key once seen, else by the item.
function P.LootDropChanged(encounterID, lootListID)
    local get = C_LootHistory and C_LootHistory.GetSortedInfoForDrop
    if not get then return end
    local ok, drop = pcall(get, encounterID, lootListID)
    if not (ok and type(drop) == "table") then return end
    local key = tostring(encounterID) .. ":" .. tostring(lootListID)
    local roll
    for _, id in ipairs(order) do
        local r = rolls[id]
        if r and r.drop == key then roll = r break end
    end
    if not roll then
        local link = drop.itemHyperlink
        for _, id in ipairs(order) do
            local r = rolls[id]
            if r and not r.drop and link and not secret(link) and r.link == link then roll = r break end
        end
    end
    if not roll then return end
    roll.drop = key
    roll.infos = drop.rollInfos
    local winner = drop.winner
    if winner or drop.allPassed then
        roll.done, roll.doneAt = true, roll.doneAt or now()
        roll.allPassed = drop.allPassed and not winner
        if winner then roll.winnerName, roll.winnerRoll = winner.playerName, winner.roll end
    end
    P.LootWindowUpdate()
end

-- The game's own frames step aside while the window holds their roll.
local hooked = false
local function hideGameFrames()
    if hooked or not hooksecurefunc then return end
    for i = 1, 4 do
        local frame = _G and _G["GroupLootFrame" .. i]
        if frame then
            hooked = true
            hooksecurefunc(frame, "Show", function(self)
                if not off() and window and window:IsShown() and self.rollID and rolls[self.rollID] then self:Hide() end
            end)
            if frame:IsShown() and not off() and window and window:IsShown() and frame.rollID and rolls[frame.rollID] then frame:Hide() end
        end
    end
end

if CreateFrame and UIParent then
    local watch = CreateFrame("Frame", nil, UIParent)
    for _, event in ipairs({"START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_HISTORY_UPDATE_DROP"}) do
        pcall(watch.RegisterEvent, watch, event)
    end
    watch:SetScript("OnEvent", function(_, event, a, b)
        if event == "START_LOOT_ROLL" then
            pcall(P.LootRollStarted, a, b)
            pcall(hideGameFrames)
        elseif event == "LOOT_HISTORY_UPDATE_DROP" then
            pcall(P.LootDropChanged, a, b)
        elseif event == "CANCEL_LOOT_ROLL" then
            -- This engine closes the roll for the player the moment he chooses (by any
            -- frame) and names the winner later: no more buttons; the others go on choosing
            -- till the time is up, and the history says the rest.
            local roll = rolls[a]
            if roll then roll.closed = true end
            pcall(P.LootWindowUpdate)
        end
    end)
end

-- /dq loot: the window on or off (the game's own frames come back when it is off).
function P.ToggleLootWindow()
    if not P.char then return end
    P.char.lootWindowOff = not P.char.lootWindowOff or nil
    if P.char.lootWindowOff and window then window:Hide() end
    return not P.char.lootWindowOff
end
