local _, P = ...
local QuestDB, NpcDB, ObjectDB, ItemDB = P.QuestDB or QuestDB, P.NpcDB or NpcDB, P.ObjectDB or ObjectDB, P.ItemDB or ItemDB
local L = P.L or function(s) return s end
local atlas = P.Core

-- The owner, of the panel at half as large again: "it is huge. Can you make it just the
-- same, a book that opens on a click?" - and he had shown the quest book of the atlas
-- twice: a list of cards on the left page, the quest in full on the right, a chain
-- open by its steps. So: a book of this addon's own, opened by a click on the panel or
-- by /dq book. The left page lists every quest of the dungeon for this character, with
-- the sign of its state, and every boss; the right page says the quest in full. The
-- frame and the parchment are the game's own; nothing is drawn and nothing is taken
-- from the atlas.
local W, H, LEFT = 780, 520, 372
local SIGN = {
    take = "Interface\\GossipFrame\\AvailableQuestIcon",
    log = "Interface\\GossipFrame\\IncompleteQuestIcon",
    ready = "Interface\\GossipFrame\\ActiveQuestIcon",
    done = "Interface\\RaidFrame\\ReadyCheck-Ready",
    dead = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    boss = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    lock = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK",
}
local WORD = {take=L"Доступно", log=L"В процессе", ready=L"Можно сдать", done=L"Выполнено", lock=L"Недоступно"}
-- The right page is dark since the layout of 14.11.2026 (ChatGPT's, approved by the owner):
-- cream text, muted grey, gold headings.
local INK, FADED, RUST = "|cffe6e0d2", "|cffbcb7ab", "|cfff5cb66"

-- The owner: "a click on a boss, and the things he drops are in the description; and
-- the drop that is of use to me lit up - I play a mage, the boss that interests me must
-- stand out." What each boss of the runs drops is read off the database once, into the
-- table at the foot of this file. Whose a thing is: the armour a class looks for and the
-- weapons it can hold.
-- The colours of quality, as the game paints the names of things.
local QUALITY = {[0]="ff9d9d9d", [1]="ffffffff", [2]="ff1eff00", [3]="ff0070dd", [4]="ffa335ee", [5]="ffff8000"}
local WEAR = {
    MAGE = {armor={0, 1}, weapon={7, 10, 15, 19}},
    PRIEST = {armor={0, 1}, weapon={4, 10, 15, 19}},
    WARLOCK = {armor={0, 1}, weapon={7, 10, 15, 19}},
    ROGUE = {armor={0, 2}, weapon={2, 3, 4, 7, 13, 15, 16, 18}},
    DRUID = {armor={0, 2}, weapon={4, 5, 10, 13, 15}},
    HUNTER = {armor={0, 2, 3}, weapon={0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18}},
    SHAMAN = {armor={0, 2, 3, 6}, weapon={0, 1, 4, 5, 10, 13, 15}},
    WARRIOR = {armor={0, 3, 4, 6}, weapon={0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18}},
    PALADIN = {armor={0, 3, 4, 6}, weapon={0, 1, 4, 5, 6, 7, 8}},
}
local KIND = {
    [2] = {[0]=L"топор", [1]=L"двуручный топор", [2]=L"лук", [3]=L"ружьё", [4]=L"булава", [5]=L"двуручная булава", [6]=L"древковое", [7]=L"меч",
        [8]=L"двуручный меч", [10]=L"посох", [13]=L"кистевое", [15]=L"кинжал", [16]=L"метательное", [18]=L"арбалет", [19]=L"жезл"},
    [4] = {[0]=L"украшение", [1]=L"ткань", [2]=L"кожа", [3]=L"кольчуга", [4]=L"латы", [6]=L"щит"},
}

local function wears(class, kind, sub)
    local set = WEAR[class]
    if not set then return false end
    for _, wanted in ipairs(kind == 2 and set.weapon or set.armor) do
        if wanted == sub then return true end
    end
    return false
end

-- What a boss drops: the things of use to this character first.
local lootCache = {}
function P.LootOf(npc)
    local raw = npc and P.Loot and P.Loot[npc]
    if not raw then return {}, 0 end
    local class = (UnitClassBase and UnitClassBase("player")) or (UnitClass and select(2, UnitClass("player")))
    -- Worked out once for a boss: the page asks for it at every refresh.
    local key = tostring(class) .. ":" .. npc
    if lootCache[key] then return lootCache[key].list, lootCache[key].mine end
    local list, mine = {}, 0
    for i = 1, #raw, 3 do
        local id, kind, sub = raw[i], raw[i + 1], raw[i + 2]
        local ok, name = pcall(function() return ItemDB and ItemDB.Get(id, "name") end)
        local item = {id=id, name=(ok and type(name) == "string" and name ~= "" and name) or ("#" .. id), kind=KIND[kind] and KIND[kind][sub], mine=wears(class, kind, sub)}
        if item.mine then mine = mine + 1 end
        list[#list+1] = item
    end
    table.sort(list, function(a, b)
        if a.mine ~= b.mine then return a.mine end
        return a.id < b.id
    end)
    lootCache[key] = {list=list, mine=mine}
    return list, mine
end

-- ------------------------------------------
-- What a thing is worth to this character
-- ------------------------------------------
-- The owner: "pictures of the things, at the least; and the best ones, the very good, lit
-- up" - and before that: "I still do not know what intellect gives me and what spell power
-- does; show what is really better to wear". So a thing is weighed by what is written on
-- it (the game's GetItemStats, seen to work on Forever), each number times what it is
-- worth to the class, and set against what is worn in its place. The best of all the
-- dungeon drops for a place, among those the character can wear at his level, is "the best
-- for the slot". The weights are a rule of thumb, not a simulation: for the mage, spell
-- power counts whole and intellect about a third (seen on the owner's mage at 35: some 32
-- intellect to one percent of spell crit).
local STAT = {
    ITEM_MOD_SPELL_POWER_SHORT="SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT="HEAL",
    ITEM_MOD_INTELLECT_SHORT="INT", ITEM_MOD_STAMINA_SHORT="STA", ITEM_MOD_SPIRIT_SHORT="SPI", ITEM_MOD_STRENGTH_SHORT="STR",
    ITEM_MOD_AGILITY_SHORT="AGI", ITEM_MOD_MANA_REGENERATION_SHORT="MP5", ITEM_MOD_POWER_REGEN0_SHORT="MP5",
    ITEM_MOD_ATTACK_POWER_SHORT="AP", ITEM_MOD_MELEE_ATTACK_POWER_SHORT="AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT="RAP",
    ITEM_MOD_CRIT_RATING_SHORT="CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT="CRIT", ITEM_MOD_CRIT_RANGED_RATING_SHORT="CRIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT="SCRIT", ITEM_MOD_HIT_RATING_SHORT="HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT="HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT="HIT", ITEM_MOD_HIT_SPELL_RATING_SHORT="SPHIT", ITEM_MOD_DAMAGE_PER_SECOND_SHORT="DPS",
    RESISTANCE0_NAME="ARMOR",
}
local STATNAME = {SP=L"сила закл.", HEAL=L"исцеление", INT=L"инт", STA=L"вын", SPI=L"дух", STR=L"сила", AGI=L"ловк", MP5=L"мана за 5 с", AP=L"сила атаки",
    RAP=L"сила атаки дальн.", CRIT=L"крит", SCRIT=L"крит закл.", HIT=L"меткость", SPHIT=L"меткость закл.", DPS=L"урон в сек.", ARMOR=L"броня"}
local STATORDER = {"SP", "HEAL", "INT", "STA", "SPI", "STR", "AGI", "AP", "RAP", "SCRIT", "SPHIT", "CRIT", "HIT", "MP5", "DPS", "ARMOR"}
local WEIGHT = {
    MAGE = {SP=1, INT=.35, STA=.15, SPI=.1, MP5=.6, SCRIT=10, SPHIT=12},
    WARLOCK = {SP=1, INT=.3, STA=.3, SPI=.05, MP5=.4, SCRIT=10, SPHIT=12},
    PRIEST = {SP=.8, HEAL=.6, INT=.4, SPI=.4, STA=.15, MP5=1, SCRIT=8, SPHIT=6},
    DRUID = {SP=.6, HEAL=.5, INT=.35, SPI=.3, STA=.25, AGI=.5, STR=.6, AP=.3, MP5=.8, CRIT=8, SCRIT=6},
    SHAMAN = {SP=.7, HEAL=.5, INT=.4, STA=.2, STR=.5, AGI=.4, AP=.3, MP5=.8, CRIT=8, SCRIT=8, DPS=2},
    PALADIN = {STR=.8, STA=.4, INT=.4, AP=.4, HEAL=.4, SP=.3, CRIT=8, HIT=8, MP5=.6, DPS=3, ARMOR=.02},
    WARRIOR = {STR=1, AP=.5, AGI=.6, STA=.4, CRIT=12, HIT=10, DPS=4, ARMOR=.02},
    ROGUE = {AGI=1, AP=.5, STR=.5, STA=.2, CRIT=12, HIT=10, DPS=3},
    HUNTER = {AGI=1, AP=.45, RAP=.45, INT=.15, STA=.2, CRIT=12, HIT=10, DPS=2},
}
-- Where a thing is worn (the slots of the character), and which things vie for one place.
local SLOTS = {INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7},
    INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11, 12}, INVTYPE_TRINKET={13, 14}, INVTYPE_CLOAK={15},
    INVTYPE_WEAPON={16}, INVTYPE_WEAPONMAINHAND={16}, INVTYPE_2HWEAPON={16, 17, both=true}, INVTYPE_WEAPONOFFHAND={17}, INVTYPE_HOLDABLE={17},
    INVTYPE_SHIELD={17}, INVTYPE_RANGED={18}, INVTYPE_RANGEDRIGHT={18}, INVTYPE_THROWN={18}, INVTYPE_RELIC={18}}
local PLACE = {INVTYPE_ROBE="INVTYPE_CHEST", INVTYPE_WEAPON="MAIN", INVTYPE_WEAPONMAINHAND="MAIN", INVTYPE_2HWEAPON="MAIN", INVTYPE_WEAPONOFFHAND="OFF",
    INVTYPE_HOLDABLE="OFF", INVTYPE_SHIELD="OFF", INVTYPE_RANGED="RANGED", INVTYPE_RANGEDRIGHT="RANGED", INVTYPE_THROWN="RANGED"}
local PLACENAME = {INVTYPE_HEAD=L"голова", INVTYPE_NECK=L"шея", INVTYPE_SHOULDER=L"плечи", INVTYPE_CHEST=L"грудь", INVTYPE_ROBE=L"грудь", INVTYPE_WAIST=L"пояс",
    INVTYPE_LEGS=L"ноги", INVTYPE_FEET=L"ступни", INVTYPE_WRIST=L"запястья", INVTYPE_HAND=L"кисти", INVTYPE_FINGER=L"палец", INVTYPE_TRINKET=L"аксессуар",
    INVTYPE_CLOAK=L"спина", INVTYPE_WEAPON=L"одна рука", INVTYPE_WEAPONMAINHAND=L"правая рука", INVTYPE_2HWEAPON=L"две руки", INVTYPE_WEAPONOFFHAND=L"левая рука",
    INVTYPE_HOLDABLE=L"левая рука", INVTYPE_SHIELD=L"левая рука", INVTYPE_RANGED=L"дальний бой", INVTYPE_RANGEDRIGHT=L"дальний бой", INVTYPE_THROWN=L"метательное"}

local function playerClass()
    return (UnitClassBase and UnitClassBase("player")) or (UnitClass and select(2, UnitClass("player")))
end

-- What is written on a thing, kept between sittings (db.gear) once the game has told it:
-- loc where it is worn, q its quality, need the level it asks, s the numbers.
local gearStamp = 0
local function numbers(link)
    local read = GetItemStats or (C_Item and C_Item.GetItemStats)
    if not read then return end
    local ok, stats = pcall(read, link)
    if not ok or type(stats) ~= "table" then return end
    local s = {}
    for key, value in pairs(stats) do
        local code = STAT[key]
        if code and type(value) == "number" then s[code] = (s[code] or 0) + value end
    end
    return s
end
local function gear(id)
    local store = P.char
    if not (store and id) then return end
    store.gear = type(store.gear) == "table" and store.gear or {}
    local rec = store.gear[id]
    if rec then return rec end
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not info then return end
    local ok, name, link, quality, _, need, _, _, _, loc = pcall(info, id)
    if not (ok and name and link) then return end
    local s = numbers(link)
    if not s then return end
    rec = {loc=loc, q=quality, need=need, s=s}
    store.gear[id] = rec
    gearStamp = gearStamp + 1
    return rec
end

-- The game is asked about a thing once in a sitting; the answer comes by itself later.
local requested = {}
local function request(id)
    if requested[id] then return end
    requested[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id)
    elseif GetItemInfo then pcall(GetItemInfo, id) end
end

local function weigh(s, class)
    local weights, sum = WEIGHT[class] or {}, 0
    for code, value in pairs(s or {}) do sum = sum + value * (weights[code] or 0) end
    return sum
end

-- What is worn where the thing would go: its weight, and whether it is this very thing.
local wornCache = {}
local function worn(loc, id, class)
    local slots = SLOTS[loc]
    if not (slots and GetInventoryItemLink) then return 0, false end
    local least, sum, same = nil, 0, false
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        local weight = 0
        if link then
            if not wornCache[link] then wornCache[link] = numbers(link) or {} end
            weight = weigh(wornCache[link], class)
            if GetInventoryItemID and GetInventoryItemID("player", slot) == id then same = true end
        end
        sum = sum + weight
        if not least or weight < least then least = weight end
    end
    return slots.both and sum or least or 0, same
end

-- The best of every place among all the dungeon drops the character can wear now.
local bestKept
local function bestOf(class, level)
    local key = class .. ":" .. level .. ":" .. gearStamp
    if bestKept and bestKept.key == key then return bestKept.by end
    local by = {}
    for _, raw in pairs(P.Loot or {}) do
        for i = 1, #raw, 3 do
            local id = raw[i]
            local rec = wears(class, raw[i + 1], raw[i + 2]) and P.char and P.char.gear and P.char.gear[id]
            if rec and rec.loc and (rec.need or 0) <= level then
                local place = PLACE[rec.loc] or rec.loc
                local weight = weigh(rec.s, class)
                local top = by[place]
                if weight > 0 and (not top or weight > top.weight or (weight == top.weight and id < top.id)) then by[place] = {id=id, weight=weight} end
            end
        end
    end
    bestKept = {key=key, by=by}
    return by
end

-- A thing weighed. known: the game has told what is on it. weight: what it is worth; gain:
-- how much more than what is worn in its place; best: the best of its place and better
-- than what is worn; worn: it is on already; later: the level it asks is not reached yet.
function P.Worth(id)
    local class = playerClass()
    -- The owner, a mage, told by a loot line that a leather hat was "better than worn":
    -- what the class cannot wear is worth nothing to it, whatever its stats.
    if class and id then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local ok, _, _, _, _, _, kind, sub = pcall(instant or function() end, id)
        if ok and (kind == 2 or kind == 4) and sub and not wears(class, kind, sub) then
            return {known=true, weight=0, gain=0, worn=false, best=false, unusable=true, stats=""}
        end
    end
    local rec = gear(id)
    if not rec then request(id) end
    if not (rec and class) then return {known=false} end
    local level = UnitLevel and UnitLevel("player") or 60
    local weight = weigh(rec.s, class)
    local base, same = worn(rec.loc, id, class)
    local place = PLACE[rec.loc] or rec.loc
    local top = place and bestOf(class, level)[place]
    local parts = {}
    for _, code in ipairs(STATORDER) do
        local value = rec.s[code]
        if value and value ~= 0 and (code ~= "ARMOR" and code ~= "DPS" or (WEIGHT[class] or {})[code]) then
            parts[#parts+1] = STATNAME[code] .. " " .. (value % 1 == 0 and ("%d"):format(value) or ("%.1f"):format(value))
        end
    end
    local later = (rec.need or 0) > level and rec.need or nil
    local gain = weight - base
    return {known=true, weight=weight, gain=gain, worn=same, later=later, quality=rec.q, place=PLACENAME[rec.loc],
        best=(top ~= nil and top.id == id and gain > 0 and not same) or false, stats=table.concat(parts, ", ")}
end

-- The game is asked about the things one at a time, gently, a while after the character
-- comes in; what it tells is kept, so it is asked once.
local asking, asked, askTotal = nil, 0, 0
local function askList()
    if asking then return asking end
    local class = playerClass()
    if not (class and P.Loot and P.char) then return {} end
    asking = {}
    local seen = {}
    for _, raw in pairs(P.Loot) do
        for i = 1, #raw, 3 do
            local id = raw[i]
            if not seen[id] and wears(class, raw[i + 1], raw[i + 2]) then
                seen[id] = true
                askTotal = askTotal + 1
                if not (P.char.gear and P.char.gear[id]) then asking[#asking+1] = id end
            end
        end
    end
    return asking
end
-- How many of the things for this class are weighed: known, of all.
function P.GearProgress()
    local list = askList()
    local left = 0
    for _, id in ipairs(list) do if not (P.char.gear and P.char.gear[id]) then left = left + 1 end end
    return askTotal - left, askTotal
end
function P.AskGear(count)
    local list = askList()
    for _ = 1, count or 1 do
        asked = asked + 1
        local id = list[asked]
        if not id then return false end
        if not gear(id) then request(id) end
    end
    return true
end
function P.GearChanged()
    gearStamp = gearStamp + 1
    for key in pairs(wornCache) do wornCache[key] = nil end
end

local book, dungeon, items, picked, offset, mode, lootAt = nil, nil, {}, nil, 0, "quests", 0
local openChain = {}

-- The state of a quest of the dungeon, in one word of the legend.
local function stateOf(row)
    if row.state == "done" then return "done" end
    if row.state == "active" then
        local id = row.step or row.id
        return (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and "ready" or "log"
    end
    if row.levelLocked or row.unknown then return "lock" end
    if row.step and row.step ~= row.id then return "lock" end      -- an earlier step of its chain comes first
    return "take"
end

-- How far a dungeon is done: handed in, all, in the log, ready to hand in.
local function progressOf(d)
    local finished, total, taken, ready = P.Progress(d)
    return {finished=finished or 0, total=total or 0, taken=taken or 0, ready=ready or 0}
end

local function chainOf(id)
    if not P.Chain then return nil end
    local ok, steps, now = pcall(P.Chain, id)
    if ok and type(steps) == "table" and #steps > 1 then return steps, now end
end

local function stepState(id, index, now)
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return "done" end
    if P.IsActive and P.IsActive(id) then return (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and "ready" or "log" end
    return index == now and "take" or "lock"
end

-- What stands on the left page, top to bottom.
local function build()
    items = {}
    if not dungeon then return end
    if mode == "dungeons" then
        -- The owner: "so that the done dungeons can be hidden, and marked done too: the
        -- Blackfathom Deeps I will not go to any more." Marked by hand (the right click,
        -- the same mark as the panel's menu, db.hidden) or all handed in: passed; the
        -- button on top hides the passed.
        local db = P.char or {}
        db.hidden = db.hidden or {}
        for _, d in ipairs(P.Catalog()) do
            local c = progressOf(d)
            local marked = db.hidden[d.key] and true or false
            local passed = marked or c.finished >= c.total
            if c.total > 0 and not (db.bookHideDone and passed) then
                items[#items+1] = {kind="dungeon", d=d, count=c, marked=marked, passed=passed, height=40}
            end
        end
        return
    end
    local result = P.Build(dungeon)
    for _, row in ipairs(result.rows) do
        local steps, now = chainOf(row.id)
        items[#items+1] = {kind="quest", row=row, state=stateOf(row), steps=steps, now=now, height=40}
        if steps and openChain[row.id] then
            for i, id in ipairs(steps) do
                items[#items+1] = {kind="step", id=id, index=i, of=row, state=stepState(id, i, now), height=20}
            end
        end
    end
    local stops = P.Run and P.Run(dungeon, result.rows, "all") or {}
    -- Inside, the marks of this run; outside, who was ever killed.
    local inside = P.InDungeon and P.InDungeon(dungeon) and true or false
    local total, dead = 0, 0
    for _, stop in ipairs(stops) do
        if not stop.dim and not stop.wingRow then
            total = total + 1
            stop.before = not stop.dead and P.EverKilled and P.EverKilled(dungeon, stop.npc, stop.name) or false
            if stop.dead or (not inside and stop.before) then dead = dead + 1 end
        end
    end
    if total > 0 then
        items[#items+1] = {kind="label", text=(inside and (L"Боссы • в этом заходе убито ") or (L"Боссы • убивал ")) .. dead .. L" из " .. total, height=24}
        for _, stop in ipairs(stops) do
            if stop.dim then
                items[#items+1] = {kind="label", text=stop.name, small=true, height=20}
            elseif not stop.wingRow then
                items[#items+1] = {kind="boss", stop=stop, inside=inside, height=26}
            end
        end
    end
    return result
end

-- The right page: the quest in full.
local function questPage(id, row, item)
    local info = P.QuestInfo and P.QuestInfo(id) or {}
    local state = item and item.state or stateOf(row)
    local lines = {}
    local function head(text) lines[#lines+1] = "\n" .. RUST .. text .. "|r" end
    local status = WORD[state]
    if state == "lock" then
        if row.levelLocked then status = status .. ": " .. (row.note or (L"мал уровень"))
        elseif row.step and row.step ~= row.id and id == row.id then status = status .. L": сначала «" .. (P.Title(row.step) or "?") .. "»"
        elseif item and item.kind == "step" then status = status .. L": не выполнен предыдущий шаг"
        elseif row.note then status = status .. ": " .. row.note end
    end
    head(L"Что делать")
    local live = P.IsActive and P.IsActive(id) and P.Objectives and P.Objectives(id)
    if live and live ~= "" then lines[#lines+1] = INK .. L"Твой прогресс: " .. live .. "|r" end
    if info.text then lines[#lines+1] = INK .. info.text .. "|r" end
    if not live and not info.text then lines[#lines+1] = FADED .. L"В базе нет описания.|r" end
    head(L"Где")
    local from = P.Where and P.Where(id, "starts")
    local to = P.Where and P.Where(id, "ends")
    lines[#lines+1] = INK .. L"Начало: " .. (from or (atlas.StartsInside and atlas.StartsInside(id) and (L"внутри подземелья") or (L"место неизвестно"))) .. "|r"
    lines[#lines+1] = INK .. L"Сдать: " .. (to or (atlas.EndsInside and atlas.EndsInside(id) and (L"внутри подземелья") or (L"место неизвестно"))) .. "|r"
    local steps, now = chainOf(row.id)
    if steps then
        local at = now
        for i, step in ipairs(steps) do if step == id then at = i end end
        head(L"Цепочка • шаг " .. at .. L" из " .. #steps)
        for i, step in ipairs(steps) do
            local name = P.Title(step) or ("#" .. step)
            local s = stepState(step, i, now)
            local tone = s == "done" and FADED or (step == id) and RUST or INK
            lines[#lines+1] = tone .. i .. ". " .. name .. (s == "done" and (L" — сдано") or s == "log" and (L" — в журнале") or s == "ready" and (L" — можно сдать") or s == "take" and (L" — можно взять") or "") .. "|r"
        end
    end
    local meta = {}
    if info.level and info.level > 0 then meta[#meta+1] = L"Уровень: " .. info.level end
    if info.required and info.required > 0 then meta[#meta+1] = L"Требуется уровень " .. info.required end
    return {title=P.Title(id) or ("#" .. id), meta=table.concat(meta, "   "), status=status, state=state, body=table.concat(lines, "\n"), row=row, id=id}
end

-- The drop of a boss, each thing weighed, the best first: the best of a slot, then what
-- is better than the worn by how much, then the rest for the class, then the others.
-- Returns the list, how many suit the class, how many are the best of a slot, how many
-- are better than what is worn.
function P.LootFor(npc)
    local raw, mine = P.LootOf(npc)
    local list, best, better = {}, 0, 0
    for i, item in ipairs(raw) do
        local worth = item.mine and P.Worth(item.id) or {known=false}
        local row = {id=item.id, name=item.name, kind=item.kind, mine=item.mine, worth=worth, order=i}
        if worth.best then best = best + 1 end
        if worth.known and worth.gain > 0 and not worth.worn and not worth.later then better = better + 1 end
        row.rank = worth.best and 1 or (worth.known and worth.gain > 0 and not worth.worn) and 2 or item.mine and 3 or 4
        list[#list+1] = row
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.rank <= 2 and a.worth.gain ~= b.worth.gain then return a.worth.gain > b.worth.gain end
        return a.order < b.order
    end)
    return list, mine, best, better
end

local function bossPage(stop)
    local lines = {}
    lines[#lines+1] = "\n" .. RUST .. L"Как найти|r"
    local any = false
    for _, line in ipairs(stop.lines or {}) do
        any = true
        lines[#lines+1] = INK .. (line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. "|r"
    end
    if type(stop.way) == "table" and not stop.next then
        for _, line in ipairs(stop.way) do any = true; lines[#lines+1] = INK .. line .. "|r" end
    end
    if not any then lines[#lines+1] = FADED .. L"Пути к этому боссу в аддоне нет: игра не сообщает положение внутри подземелья.|r" end
    local loot, mine, best, better = P.LootFor(stop.npc)
    if #loot > 0 then
        local head = {}
        if best > 0 then head[#head+1] = L"лучшее в слот: " .. best end
        if better > 0 then head[#head+1] = L"лучше надетого: " .. better end
        if #head == 0 and mine > 0 then head[1] = L"тебе подходит: " .. mine end
        lines[#lines+1] = "\n" .. RUST .. L"Добыча" .. (#head > 0 and (" • " .. table.concat(head, " • ")) or "") .. "|r"
    else
        lines[#lines+1] = "\n" .. FADED .. L"Правая кнопка по боссу в списке отмечает его убитым или возвращает.|r"
    end
    return {title=stop.name, meta=stop.optional and (L"По желанию") or "", loot=loot, mine=mine, best=best, better=better, status=stop.dead and (L"Убит в этом заходе") or stop.before and (L"Убивал раньше") or (L"Ещё не убивал"),
        state=stop.dead and "dead" or "boss", body=table.concat(lines, "\n"), stop=stop}
end

local function draw()
    if not (book and book:IsShown()) then return end
    local result = build()
    local view = {items=items}
    book.view = view
    -- The head of the left page.
    local name = dungeon and atlas.DungeonName(dungeon) or (L"Подземелья")
    book.name:SetText(mode == "dungeons" and (L"Подземелья") or name)
    if mode == "dungeons" then
        book.meta:SetText(L"Уровень персонажа: " .. (UnitLevel and UnitLevel("player") or "?") .. L"  •  ПКМ — отметить пройденным")
    else
        local c = dungeon and progressOf(dungeon) or {finished=0, total=0}
        book.meta:SetText((L"Уровень: %d–%d    Выполнено: %d/%d"):format(dungeon.minLevel or 0, dungeon.maxLevel or 0, c.finished, c.total))
    end
    view.name, view.meta = name, book.meta.text
    book.switch.label:SetText(mode == "dungeons" and (L"Назад") or (L"Подземелья"))
    book.hideDone:SetShown(mode == "dungeons")
    book.hideDone.label:SetText((P.char and P.char.bookHideDone) and (L"Показать пройденные") or (L"Скрыть пройденные"))
    -- The list.
    offset = math.max(0, math.min(offset, math.max(0, #items - 1)))
    local y, shown = 0, 0
    local room = H - 150
    for i, row in ipairs(book.rows) do row:Hide() end
    for index = offset + 1, #items do
        local item = items[index]
        if y + item.height > room then break end
        shown = shown + 1
        local row = book:Row(shown)
        row.item = item
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", book.list, "TOPLEFT", item.kind == "step" and 28 or 0, -y)
        row:SetSize(LEFT - 28 - (item.kind == "step" and 28 or 0), item.height - 4)
        local sign, title, sub, right, plate = nil, "", nil, nil, true
        if item.kind == "quest" then
            local r = item.row
            sign = SIGN[item.state]
            local tone = item.state == "done" and "|cff40c040" or item.state == "lock" and "|cffb0a090" or item.state == "ready" and "|cffffd34d" or "|cffffd100"
            title = tone .. (P.Title(r.id) or "?") .. "|r"
            local info = P.QuestInfo and P.QuestInfo(r.id) or {}
            local parts = {}
            if info.required and info.required > 0 then parts[#parts+1] = L"Требуется уровень " .. info.required end
            if item.steps then parts[#parts+1] = L"цепочка " .. (item.now or #item.steps) .. "/" .. #item.steps end
            if #parts == 0 then parts[1] = WORD[item.state] end
            sub = table.concat(parts, " • ")
            right = info.level and info.level > 0 and tostring(info.level) or nil
            item.level = info.level
        elseif item.kind == "step" then
            sign = SIGN[item.state]
            title = (item.state == "done" and "|cff808080" or item.state == "lock" and "|cffb0a090" or "|cffffffff") .. item.index .. ". " .. (P.Title(item.id) or "?") .. "|r"
        elseif item.kind == "boss" then
            local s = item.stop
            sign = s.dead and SIGN.dead or (s.before and not item.inside) and SIGN.done or SIGN.boss
            title = s.dead and ("|cff808080" .. s.name .. L" — убит|r")
                or (s.before and not item.inside) and ("|cff9a9a9a" .. s.name .. L" — убивал|r")
                or (s.next and item.inside and ("|cffffd34d" .. s.name .. L" — следующий|r"))
                or (s.name .. (s.optional and (L" |cff999999• по желанию|r") or "") .. (s.before and (L" |cff999999• убивал раньше|r") or ""))
        elseif item.kind == "label" then
            plate = false
            title = (item.small and "|cffc8b27a" or "|cff6cc4ff") .. item.text .. "|r"
        elseif item.kind == "dungeon" then
            local c = item.count
            -- Quests in the log, or a step of a chain: "?" (gold when one is ready to hand in);
            -- something left to take: "!"; all handed in or marked passed: the tick.
            sign = item.passed and SIGN.done or c.ready > 0 and SIGN.ready or c.taken > 0 and SIGN.log or SIGN.take
            title = (item.marked and "|cff9a9a9a" or "|cffffd100") .. atlas.DungeonName(item.d) .. "|r"
            sub = (L"Уровень %d–%d  •  выполнено %d/%d"):format(item.d.minLevel or 0, item.d.maxLevel or 0, c.finished, c.total)
                .. (item.marked and (L"  •  отмечено пройденным") or "")
        end
        row.plate:SetShown(plate)
        row.sign:SetShown(sign ~= nil)
        if sign then row.sign:SetTexture(sign) end
        row.signFile = sign
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", sign and 30 or 6, sub and -5 or -(item.height - 4 - 14) / 2)
        row.title:SetText(title)
        row.text = title
        row.sub:SetText(sub or "")
        row.sub:SetShown(sub ~= nil)
        row.right:SetText(right or "")
        local tag
        if item.kind == "boss" then
            local loot, mine, best, better = P.LootFor(item.stop.npc)
            item.mine, item.best, item.better = mine, best, better
            local weighed = false
            for _, thing in ipairs(loot) do weighed = weighed or thing.worth.known end
            -- A boss with the best of a slot is gold; with something better than the worn,
            -- green; while nothing is weighed yet, what suits the class as before.
            if best > 0 then tag = L"|cffffd34dлучшее в слот: " .. best .. "|r"
            elseif better > 0 then tag = L"|cff40e040лучше надетого: " .. better .. "|r"
            elseif mine > 0 and not weighed then tag = L"|cff40e040тебе: " .. mine .. "|r" end
        end
        row.tag:SetText(tag or "")
        row.tagText = tag
        if right and GetQuestDifficultyColor and item.level then
            local c = GetQuestDifficultyColor(item.level)
            if c and row.right.SetTextColor then row.right:SetTextColor(c.r, c.g, c.b) end
        end
        local chosen = picked and ((item.kind == "quest" and picked.kind == "quest" and picked.row.id == item.row.id)
            or (item.kind == "step" and picked.kind == "step" and picked.id == item.id)
            or (item.kind == "boss" and picked.kind == "boss" and picked.stop.name == item.stop.name))
        row.chosen:SetShown(chosen and true or false)
        row:Show()
        y = y + item.height
    end
    view.shown = shown
    book.more:SetShown(offset + shown < #items or offset > 0)
    book.more:SetText(offset + shown < #items and (L"колесо мыши листает список") or (L"конец списка"))
    -- The right page.
    local page
    if picked and picked.kind == "quest" then page = questPage(picked.row.id, picked.row, picked)
    elseif picked and picked.kind == "step" then page = questPage(picked.id, picked.of, picked)
    elseif picked and picked.kind == "boss" then page = bossPage(picked.stop) end
    view.page = page
    if page then
        book.title:SetText(page.title)
        book.info:SetText(page.meta or "")
        book.status:SetText(page.status or "")
        book.statusSign:SetTexture(SIGN[page.state] or SIGN.take)
        book.statusPlate:Show()
        book.body:SetText(page.body)
        book.go:SetShown(page.row ~= nil and page.state ~= "done")
    else
        book.title:SetText(mode == "dungeons" and (L"Выбери подземелье") or name)
        book.info:SetText("")
        book.statusPlate:Hide()
        book.body:SetText(INK .. (mode == "dungeons" and (L"Щёлкни по подземелью слева: откроются его задания и боссы.")
            or (L"Щёлкни по заданию или боссу слева.\n\nЗадание с цепочкой раскрывается по шагам.")) .. "|r")
        book.go:Hide()
    end
    -- The drop of a boss: a row for each thing, with its picture.
    local loot = page and page.loot or {}
    for _, row in ipairs(book.loot) do row:Hide() end
    local fit = 7
    if book.body.GetBottom and book.paper.GetBottom then
        local top, floor = book.body:GetBottom(), book.paper:GetBottom()
        if type(top) == "number" and type(floor) == "number" then fit = math.max(2, math.floor((top - floor - 52) / 44)) end
    end
    lootAt = math.max(0, math.min(lootAt, math.max(0, #loot - fit)))
    local class = playerClass()
    local drawn = 0
    for index = lootAt + 1, math.min(#loot, lootAt + fit) do
        drawn = drawn + 1
        local thing, row = loot[index], book:LootRow(drawn)
        local worth = thing.worth
        row.thing = thing
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", book.body, "BOTTOMLEFT", 0, -6 - (drawn - 1) * 44)
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(thing.id)) or (GetItemIcon and GetItemIcon(thing.id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        row.icon:SetTexture(icon)
        row.iconFile = icon
        local quality = worth.quality or (C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(thing.id))
        local tone = QUALITY[quality or -1] or "ffffffff"
        row.name:SetText("|c" .. tone .. thing.name .. "|r")
        row.edge:SetVertexColor(tonumber(tone:sub(3, 4), 16) / 255, tonumber(tone:sub(5, 6), 16) / 255, tonumber(tone:sub(7, 8), 16) / 255)
        local sub = {}
        if worth.place then sub[#sub+1] = worth.place end
        if thing.kind and thing.kind ~= L"украшение" then sub[#sub+1] = thing.kind end
        if worth.stats and worth.stats ~= "" then sub[#sub+1] = worth.stats end
        row.sub:SetText(table.concat(sub, " • "))
        local badge
        if not thing.mine then badge = L"|cff8a8a8aне для твоего класса|r"
        elseif not worth.known then badge = L"|cff40e040тебе|r\n|cff8a8a8aещё не оценено|r"
        elseif worth.worn then badge = L"|cff9a9a9aуже надето|r"
        elseif worth.best then badge = L"|cffffd34dЛУЧШЕЕ В СЛОТ|r\n|cff40e040+" .. ("%.0f"):format(worth.gain) .. L" к надетому|r"
        elseif worth.gain > 0 then badge = "|cff40e040+" .. ("%.0f"):format(worth.gain) .. L" к надетому|r" .. (worth.later and (L"\n|cffffa64dс уровня " .. worth.later .. "|r") or "")
        else badge = L"|cff9a9a9aне лучше надетого|r" end
        row.badge:SetText(badge)
        row.badgeText = badge
        row.text = thing.name
        row.glow:SetShown(worth.best and true or false)
        row.gold:SetShown(worth.best and true or false)
        if row.SetAlpha then row:SetAlpha(thing.mine and 1 or .6) end
        row:Show()
    end
    view.loot, view.lootShown = loot, drawn
    local note
    if #loot > 0 then
        local parts = {}
        if #loot > drawn then parts[#parts+1] = L"вещей " .. #loot .. L", колесо мыши листает" end
        local known, total = P.GearProgress()
        if total > 0 and known < total then parts[#parts+1] = L"оценено " .. known .. L" из " .. total .. L" вещей для твоего класса" end
        parts[#parts+1] = L"наведи мышь на вещь: её описание; оценка — сила закл. целиком, инт на треть"
        if class ~= "MAGE" and class ~= "WARLOCK" then parts[#parts] = L"наведи мышь на вещь: её описание" end
        note = table.concat(parts, " • ")
    end
    book.lootNote:SetText(note and (FADED .. note .. "|r") or "")
    view.lootNote = note
end

local function create()
    local ok, frame = pcall(CreateFrame, "Frame", "DungeonQuestForeverBook", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not frame then
        frame = CreateFrame("Frame", "DungeonQuestForeverBook", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if frame.SetBackdrop then
            frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
            frame:SetBackdropColor(.05, .04, .03, .96)
        end
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
    end
    book = frame
    local bug = P.BugButton(frame)
    bug:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -3)
    frame:SetSize(W, H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    if type(frame.TitleText) == "table" and frame.TitleText.SetText then frame.TitleText:SetText(L"Dungeon Quest Forever — книга заданий") end
    if UISpecialFrames then table.insert(UISpecialFrames, "DungeonQuestForeverBook") end
    -- A thing named on the right page is a link: the mouse over it shows the game's own
    -- description of it.
    pcall(function()
        frame:SetHyperlinksEnabled(true)
        frame:SetScript("OnHyperlinkEnter", function(self, link)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)
        frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    end)

    -- The owner, at the right page: "how can anything be read here?" The frame of the game
    -- this book is made on lays its own dark marble over the inside, over the parchment:
    -- dark ink on dark. Its marble is put away and the pages lie on top.
    if type(frame.InsetBg) == "table" and frame.InsetBg.Hide then frame.InsetBg:Hide() end
    -- The left page: dark, with the cards.
    local left = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    if left.SetColorTexture then left:SetColorTexture(.07, .05, .04, .92) end
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -26)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    left:SetWidth(LEFT)
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -38)
    frame.name:SetWidth(LEFT - 130)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetWordWrap(false)
    frame.meta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.meta:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -6)
    local switch = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.switch = switch
    switch:SetSize(104, 22)
    switch:SetPoint("TOPRIGHT", frame, "TOPLEFT", LEFT, -36)
    if switch.SetFrameLevel and frame.GetFrameLevel then switch:SetFrameLevel((frame:GetFrameLevel() or 1) + 10) end
    switch.label = switch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    switch.label:SetPoint("CENTER")
    switch:SetScript("OnClick", function()
        mode = mode == "dungeons" and "quests" or "dungeons"
        offset, picked, lootAt = 0, nil, 0
        draw()
    end)
    local hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.hideDone = hide
    hide:SetSize(150, 22)
    hide:SetPoint("RIGHT", switch, "LEFT", -6, 0)
    if hide.SetFrameLevel and frame.GetFrameLevel then hide:SetFrameLevel((frame:GetFrameLevel() or 1) + 10) end
    hide.label = hide:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hide.label:SetPoint("CENTER")
    hide:SetScript("OnClick", function()
        local db = P.char
        if db then db.bookHideDone = not db.bookHideDone or nil end
        offset = 0
        draw()
    end)
    local list = CreateFrame("Frame", nil, frame)
    frame.list = list
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -84)
    list:SetSize(LEFT - 24, H - 150)
    if list.SetFrameLevel and frame.GetFrameLevel then list:SetFrameLevel((frame:GetFrameLevel() or 1) + 10) end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(#items - 1, offset - delta))
        draw()
    end)
    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 44)
    -- The legend, in the game's own signs.
    local function mark(key) return "|T" .. SIGN[key] .. ":14|t " .. WORD[key] end
    frame.legend = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.legend:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 14)
    frame.legend:SetWidth(LEFT - 30)
    frame.legend:SetJustifyH("LEFT")
    frame.legend:SetText(mark("take") .. "   " .. mark("log") .. "   " .. mark("ready") .. "\n" .. mark("done") .. "   " .. mark("lock"))

    frame.rows = {}
    function frame:Row(i)
        local row = self.rows[i]
        if row then return row end
        row = CreateFrame("Button", nil, list)
        self.rows[i] = row
        if row.EnableMouse then row:EnableMouse(true) end
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.plate = row:CreateTexture(nil, "BACKGROUND")
        if row.plate.SetColorTexture then row.plate:SetColorTexture(.16, .12, .09, .95) end
        row.plate:SetAllPoints(row)
        row.chosen = row:CreateTexture(nil, "BORDER")
        if row.chosen.SetColorTexture then row.chosen:SetColorTexture(.42, .77, 1, .9) end
        row.chosen:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.chosen:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.chosen:SetWidth(3)
        row.sign = row:CreateTexture(nil, "ARTWORK")
        row.sign:SetSize(18, 18)
        row.sign:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.title:SetWidth(LEFT - 110)
        row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.sub:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 30, 5)
        row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.right:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.tag:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnClick", function(self, mouse)
            local item = self.item
            if not item then return end
            if item.kind == "dungeon" and mouse == "RightButton" then
                -- Marked passed, or back in the list.
                local db = P.char
                if db then
                    db.hidden = db.hidden or {}
                    db.hidden[item.d.key] = not db.hidden[item.d.key] or nil
                    if P.Refresh then P.Refresh() end
                end
            elseif item.kind == "dungeon" then
                dungeon, mode, offset, picked, lootAt = item.d, "quests", 0, nil, 0
                if P.Choose then P.Choose(item.d) end
            elseif item.kind == "boss" and mouse == "RightButton" then
                if P.ToggleKilled then P.ToggleKilled(dungeon, item.stop.npc, item.stop.name) end
                if P.Refresh then P.Refresh() end
            elseif item.kind == "quest" then
                P.Track("QuestRead")
                picked = item
                if item.steps then openChain[item.row.id] = not openChain[item.row.id] or nil end
            elseif item.kind ~= "label" then
                if item.kind == "boss" then P.Track("BossRead") end
                picked, lootAt = item, 0
            end
            draw()
        end)
        return row
    end

    -- The right page: parchment, with the quest in the game's own quest fonts.
    local paper = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    if paper.SetColorTexture then paper:SetColorTexture(.161, .125, .086, .96) end
    paper:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 14, -26)
    paper:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    local grain = frame:CreateTexture(nil, "BORDER")
    grain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    grain:SetAllPoints(paper)
    -- Seen in the game at more than half: a dark brown page the ink did not read on.
    -- The page is dark now, with light text: the grain is put away.
    grain:Hide()
    local width = W - LEFT - 54
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if frame.title.SetTextColor then frame.title:SetTextColor(.96, .80, .40) end
    frame.title:SetPoint("TOPLEFT", paper, "TOPLEFT", 18, -16)
    frame.title:SetWidth(width)
    frame.title:SetJustifyH("LEFT")
    frame.info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if frame.info.SetTextColor then frame.info:SetTextColor(.74, .72, .67) end
    frame.info:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.info:SetWidth(width)
    frame.info:SetJustifyH("LEFT")
    local plate = CreateFrame("Frame", nil, frame)
    frame.statusPlate = plate
    plate:SetPoint("TOPLEFT", frame.info, "BOTTOMLEFT", 0, -8)
    plate:SetSize(width, 24)
    local dark = plate:CreateTexture(nil, "ARTWORK")
    if dark.SetColorTexture then dark:SetColorTexture(.1, .07, .05, .9) end
    dark:SetAllPoints(plate)
    frame.statusSign = plate:CreateTexture(nil, "OVERLAY")
    frame.statusSign:SetSize(16, 16)
    frame.statusSign:SetPoint("LEFT", plate, "LEFT", 6, 0)
    frame.status = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.status:SetPoint("LEFT", plate, "LEFT", 28, 0)
    frame.status:SetWidth(width - 34)
    frame.status:SetJustifyH("LEFT")
    frame.status:SetWordWrap(false)
    frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if frame.body.SetTextColor then frame.body:SetTextColor(.90, .88, .82) end
    frame.body:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", 0, -6)
    frame.body:SetWidth(width)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")
    if frame.body.SetSpacing then frame.body:SetSpacing(3) end
    local go = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.go = go
    go:SetSize(150, 24)
    go:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    if go.SetFrameLevel and frame.GetFrameLevel then go:SetFrameLevel((frame:GetFrameLevel() or 1) + 10) end
    go.label = go:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    go.label:SetPoint("CENTER")
    go.label:SetText(L"Показать путь")
    go:SetScript("OnClick", function()
        local page = frame.view and frame.view.page
        if page and page.row and P.OpenRow then P.OpenRow(page.row) end
    end)
    -- The drop: dark cards on the parchment, so that the colours of quality read; the
    -- picture of the thing in a rim of its quality; on the right what it is to the
    -- character. The best of a slot wears gold: a light round the picture, a gold edge.
    frame.paper = paper
    frame.loot = {}
    local function wheel(_, delta)
        lootAt = math.max(0, lootAt - delta)
        draw()
    end
    local catch = CreateFrame("Frame", nil, frame)
    catch:SetPoint("TOPLEFT", paper, "TOPLEFT", 0, -120)
    catch:SetPoint("BOTTOMRIGHT", paper, "BOTTOMRIGHT", 0, 0)
    catch:EnableMouseWheel(true)
    catch:SetScript("OnMouseWheel", wheel)
    frame.lootWheel = catch
    function frame:LootRow(i)
        if self.loot[i] then return self.loot[i] end
        local row = CreateFrame("Button", nil, self)
        self.loot[i] = row
        row:SetSize(width, 40)
        if row.SetFrameLevel and self.GetFrameLevel then row:SetFrameLevel((self:GetFrameLevel() or 1) + 6) end
        row.plate = row:CreateTexture(nil, "BACKGROUND")
        if row.plate.SetColorTexture then row.plate:SetColorTexture(.1, .07, .05, .88) end
        row.plate:SetAllPoints(row)
        row.gold = row:CreateTexture(nil, "BORDER")
        if row.gold.SetColorTexture then row.gold:SetColorTexture(1, .82, .25, .22) end
        row.gold:SetAllPoints(row)
        row.edge = row:CreateTexture(nil, "BORDER")
        if row.edge.SetColorTexture then row.edge:SetColorTexture(1, 1, 1, 1) end
        row.edge:SetSize(36, 36)
        row.edge:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("CENTER", row.edge, "CENTER", 0, 0)
        if row.icon.SetTexCoord then row.icon:SetTexCoord(.07, .93, .07, .93) end
        row.glow = row:CreateTexture(nil, "OVERLAY")
        row.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        row.glow:SetBlendMode("ADD")
        row.glow:SetVertexColor(1, .82, .25)
        row.glow:SetSize(66, 66)
        row.glow:SetPoint("CENTER", row.edge, "CENTER", 0, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -5)
        row.name:SetWidth(width - 46 - 118)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.sub:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 46, 6)
        row.sub:SetWidth(width - 46 - 118)
        row.sub:SetJustifyH("LEFT")
        row.sub:SetWordWrap(false)
        if row.sub.SetTextColor then row.sub:SetTextColor(.82, .78, .68) end
        row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.badge:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.badge:SetWidth(112)
        row.badge:SetJustifyH("RIGHT")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", wheel)
        row:SetScript("OnEnter", function(self)
            if not (self.thing and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.thing.id)
            if not ok then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.thing.id) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        -- With Shift the thing goes into the chat line, with Ctrl into the fitting room: as
        -- on any thing of the game.
        row:SetScript("OnClick", function(self)
            local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            local _, link = info and self.thing and info(self.thing.id)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
        end)
        return row
    end
    frame.lootNote = frame:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    frame.lootNote:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", 18, 10)
    frame.lootNote:SetWidth(width)
    frame.lootNote:SetJustifyH("LEFT")
    frame:Hide()
end

-- What the game tells of the things arrives a moment later, and what is worn changes: the
-- open book is drawn again. And the game is asked about the things for the class, gently:
-- one a second from half a minute after coming in, three a second while the book is open,
-- never in a fight.
do
    local ears = CreateFrame and CreateFrame("Frame", "DungeonQuestForeverGear", UIParent)
    if ears then
        for _, event in ipairs({"GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP"}) do pcall(ears.RegisterEvent, ears, event) end
        local due, pace, age = nil, 0, 0
        ears:SetScript("OnEvent", function(_, event, id)
            if event == "GET_ITEM_INFO_RECEIVED" then
                -- Only the things asked for here are read.
                if not (id and requested[id]) then return end
                gear(id)
            else
                P.GearChanged()
            end
            due = .5
        end)
        ears:SetScript("OnUpdate", function(_, elapsed)
            elapsed = elapsed or 0
            age = age + elapsed
            local open = book and book:IsShown()
            if due then
                due = due - elapsed
                if due <= 0 then due = nil; if open then draw() end end
            end
            pace = pace + elapsed
            if pace >= (open and .33 or 1) then
                pace = 0
                if (open or age > 30) and not (InCombatLockdown and InCombatLockdown()) then P.AskGear(1) end
            end
        end)
    end
end

-- Opened on a dungeon, and on one of its quests if asked.
function P.OpenBook(d, questID)
    if not book or not book:IsShown() then P.Track("BookOpened") end
    if not book then create() end
    dungeon = d or dungeon or (P.Selected and P.Selected())
    mode = dungeon and "quests" or "dungeons"
    if not dungeon then dungeon = P.Catalog()[1] end
    offset, picked, lootAt = 0, nil, 0
    book:Show()
    draw()
    if questID then
        for _, item in ipairs(items) do
            if item.kind == "quest" and (item.row.id == questID or item.row.step == questID) then
                picked = item
                P.Track("QuestRead")
                break
            end
        end
        draw()
    end
    return book
end

function P.ToggleBook(d)
    if book and book:IsShown() then book:Hide() return end
    return P.OpenBook(d)
end

-- The pages follow the quest log while the book is open.
function P.RefreshBook()
    if book and book:IsShown() then draw() end
end

function P.BookView()
    return book and book.view
end

-- BEGIN LOOT: generated by dungeon-quest-handoff/make-loot.lua from QuestieDB; do not edit by hand
-- [boss] = {item, class (2 weapon, 4 armour), subclass, ...}
P.Loot = {
    [639]={5191,2,7, 5193,4,1, 5202,4,1, 10399,4,2},
    [643]={5194,2,1, 5195,4,1, 273293,4,3},
    [644]={872,2,1, 273289,4,1, 5187,2,5},
    [645]={11982,4,0, 273298,4,0, 5198,2,19, 5197,2,4},
    [646]={7230,2,5, 5192,2,7, 284715,4,0, 5196,2,0},
    [647]={5200,2,6, 5201,2,10, 10403,4,2},
    [1663]={273817,2,5, 273819,2,6, 273820,4,0},
    [1666]={2280,2,10, 273807,4,2, 273808,4,1},
    [1696]={273804,4,2, 273805,4,2, 273806,4,0},
    [1716]={273824,4,2, 273825,4,0, 273827,2,7, 273829,2,18, 252514,4,2},
    [1717]={273809,2,0, 273810,4,3, 273811,4,6},
    [1720]={2941,2,15, 2942,2,13, 3228,4,3},
    [1763]={273297,2,4, 1156,4,0, 5199,4,2},
    [1853]={22433,4,0, 13398,4,2, 13937,2,10, 13938,2,19, 13944,4,2, 13951,4,4, 13953,2,7, 13964,2,15, 16667,4,3, 16677,4,3, 16686,4,1, 16693,4,1, 16698,4,1, 16707,4,2, 16720,4,2, 16727,4,4, 16731,4,4, 21525,4,1},
    [2748]={9413,2,5, 9418,2,8, 11118,4,0},
    [3586]={5443,4,6, 5444,4,1, 6581,4,2},
    [3653]={13245,4,6, 14371,4,1, 273084,4,0, 6447,4,6},
    [3654]={6461,4,1, 6463,4,0, 6627,4,3, 15333,4,1, 15503,4,3, 12053,4,0, 14565,4,2},
    [3669]={9767,4,1, 15113,4,6, 6460,4,3, 6465,4,1, 10410,4,2},
    [3670]={6472,2,4, 6473,4,2, 273089,4,1, 12978,4,3},
    [3671]={5404,4,2, 12992,2,8, 14568,4,2, 273088,4,0, 10412,4,2},
    [3673]={6469,2,2, 5970,4,1, 6459,4,3, 9767,4,1, 10411,4,2, 15115,4,2, 14129,4,1, 15110,4,2, 15307,4,6},
    [3674]={6449,4,1, 14743,4,3, 273137,4,0, 6448,2,15, 15893,4,6, 14121,4,1},
    [3872]={6641,2,8, 6642,4,3},
    [3886]={1292,2,0, 6226,4,1, 6633,2,7},
    [3887]={3212,4,3, 6321,4,0, 6323,2,4, 273637,2,7},
    [3914]={5254,4,2, 273456,2,13, 273457,4,0, 2985,4,2},
    [3927]={3748,4,1, 6314,4,1, 3212,4,3, 273647,4,2, 2292,4,1},
    [3974]={7710,2,10, 7756,4,2, 3456,4,0},
    [3975]={7717,2,1, 7718,4,3, 7719,4,3},
    [3976]={7723,2,5, 7724,4,3, 7726,4,6, 10330,4,3},
    [3977]={7495,4,6, 7720,4,1, 7721,2,4, 7722,4,0, 8157,4,4},
    [3983]={7682,2,15, 7683,2,13, 274290,4,6},
    [4274]={4064,4,6, 3230,4,2, 6340,4,1, 273646,4,3, 9804,4,6},
    [4275]={9829,4,2, 6220,2,15, 6324,4,1, 6392,4,1, 6605,4,2, 9809,4,2},
    [4278]={3191,2,1, 3212,4,3, 4707,4,3, 6320,4,6, 273643,4,0},
    [4279]={3067,4,1, 6318,2,10, 6319,4,2, 273645,4,0, 6567,4,1},
    [4420]={6686,4,3, 6687,2,1, 274161,4,3},
    [4421]={6692,2,0, 6693,4,0, 6694,4,6},
    [4422]={274160,2,16, 6691,2,15, 6690,4,2},
    [4424]={274159,4,2, 6681,2,15, 274158,2,10},
    [4425]={6695,4,0, 6696,2,2, 6697,4,1},
    [4428]={2816,2,4, 6685,4,1, 6682,4,1, 252514,4,2},
    [4542]={19507,4,1, 19508,4,2, 19509,4,3},
    [4543]={7685,4,0, 7684,4,1},
    [4829]={6909,2,8, 6911,4,2, 252514,4,2, 6910,4,1},
    [4830]={6901,4,1, 6904,2,15, 6902,4,2},
    [4831]={888,4,2, 3078,2,2, 11121,2,7},
    [4832]={252515,4,2, 273846,4,3, 1155,2,10, 6903,4,1},
    [4842]={6689,2,10, 6688,4,2},
    [4854]={9414,4,2, 9415,4,1, 9416,2,6, 8144,4,4},
    [4887]={6907,4,3, 6908,4,1, 273839,4,0},
    [5709]={10110,4,2, 10167,4,4},
    [5710]={10110,4,2, 10806,4,1, 10807,4,1, 10808,4,1},
    [5711]={10803,2,7, 10804,2,4, 10805,2,0},
    [5775]={6630,4,6, 14374,4,1, 15329,4,2, 6631,2,10, 6629,4,1, 11981,4,0},
    [5912]={5243,2,19, 6632,4,1},
    [6168]={274149,4,0, 274152,4,0, 274155,4,2},
    [6229]={9449,2,5, 9450,4,2, 9819,4,1, 274068,4,0, 6396,4,2, 10408,4,3, 5007,4,0},
    [6235]={9446,2,7, 9447,4,0, 9448,4,1, 7330,4,6, 4073,4,3},
    [6243]={273840,4,0, 6906,4,3, 6905,2,1},
    [6487]={7711,4,1, 7712,4,1, 7713,2,10, 7714,2,15, 274293,2,18},
    [6906]={9401,2,7, 9400,2,2},
    [6910]={9387,4,4, 9388,4,3, 9389,4,2, 9390,4,1},
    [7079]={7330,4,6, 9452,2,10, 9453,2,15, 9454,4,1, 6388,4,3},
    [7206]={9411,4,3, 9410,4,4},
    [7228]={9407,4,1, 9408,2,10, 9409,4,3, 9973,4,4, 7556,4,0, 12030,4,0},
    [7267]={9476,4,4, 9477,2,10, 9478,2,0, 9479,4,2, 11086,2,7, 14263,4,1},
    [7271]={18082,2,10, 18083,4,1},
    [7272]={9483,2,19, 2040,4,6, 9480,2,6, 5616,2,15, 9482,2,10, 14660,4,2, 15373,4,2, 9511,2,7, 9512,4,1, 15166,4,2, 15964,4,0},
    [7273]={9467,2,15, 9469,4,3, 14787,4,3, 14270,4,1},
    [7275]={9470,4,1, 9473,4,2, 9474,4,2, 9475,2,6},
    [7291]={9412,2,3, 11310,4,1, 9419,2,4, 11311,4,1, 4062,4,2},
    [7354]={10758,2,8, 10767,4,6, 10768,4,3},
    [7355]={10775,4,4, 10776,4,1, 10777,4,2},
    [7356]={10766,2,19, 10760,4,2},
    [7357]={10769,4,0, 10770,4,0, 10771,4,1},
    [7358]={10761,2,15, 10762,4,1, 10763,4,4, 10764,4,3, 10765,4,2},
    [7361]={9445,4,3, 274042,4,2, 274043,4,6, 6407,4,1, 12039,4,0, 6400,4,6, 252514,4,2, 252515,4,2},
    [7604]={5616,2,15, 9482,2,10},
    [7795]={9481,2,1, 9483,2,19, 5616,2,15, 1447,4,0, 9512,4,1},
    [7796]={9480,2,6, 14907,4,4, 9482,2,10, 9511,2,7},
    [7797]={6440,4,0, 5616,2,15, 9511,2,7, 9512,4,1},
    [7800]={9458,4,6, 9459,2,1, 9461,4,0, 9492,4,1, 4717,4,3},
    [8127]={9379,2,7, 9639,2,4, 9640,4,4, 9641,4,0, 14840,4,4},
    [8567]={10772,2,0, 10774,4,2},
    [8580]={10800,4,2, 10798,4,4, 10799,2,6},
    [8983]={11669,4,0, 11819,4,0, 11822,4,1, 11823,4,2},
    [9016]={11802,4,4, 11807,4,1, 11803,2,5, 11805,2,4},
    [9017]={11764,4,2, 11765,4,3, 11766,4,1, 11767,4,4},
    [9018]={11625,4,0, 11626,4,1, 22240,4,3, 11624,4,1},
    [9019]={11934,4,0, 11684,2,4, 11924,4,1, 11928,4,0, 11930,4,1, 11933,4,0, 22204,4,2, 22207,4,3, 11931,2,1, 11932,2,10, 11815,4,0, 21524,4,1},
    [9024]={11747,4,2, 11748,2,19, 11749,4,3, 11750,2,10},
    [9025]={22397,4,8, 22234,4,1, 11631,4,6, 11632,4,4},
    [9027]={11726,4,3, 22257,4,0, 22266,2,15, 22271,4,2},
    [9028]={11702,2,0, 11703,4,4, 11722,4,3, 22270,4,4},
    [9029]={11730,4,3, 11679,4,3, 11685,4,2, 11686,4,2},
    [9030]={11728,4,3, 11662,4,1, 11665,4,2, 11824,4,0},
    [9031]={11731,4,3, 11675,4,2, 11677,4,1, 11678,4,4},
    [9032]={11729,4,3, 11633,4,4, 11634,4,1, 11635,2,15},
    [9033]={11810,4,0, 11820,4,3, 11821,4,2, 11816,2,1, 11817,2,7},
    [9041]={11782,4,1, 11783,4,3, 22241,4,2, 11784,2,7},
    [9056]={11839,4,1, 11840,4,0, 11841,4,1, 11842,4,3, 22223,4,4},
    [9156]={11808,4,1, 11812,4,1, 11814,4,3, 11832,4,0, 11809,2,6},
    [9196]={13166,4,4, 13167,2,5, 13168,4,4, 13169,4,2, 13170,4,1, 16670,4,3},
    [9236]={12626,4,1, 12651,2,18, 12653,2,2, 13255,4,3, 13257,4,2, 16712,4,2},
    [9237]={22231,4,1, 12582,2,15, 13173,2,16, 13177,4,0, 13179,4,3, 16676,4,3, 21524,4,1},
    [9319]={10193,4,3, 11627,4,3, 11628,2,2, 11629,2,3, 11623,4,1},
    [9499]={12791,2,15, 12793,4,2},
    [9502]={11744,2,13, 11745,4,4, 22212,4,3},
    [9537]={11735,4,2, 18043,4,2, 18044,2,4, 22275,4,2},
    [9568]={13163,2,8, 13143,4,0, 13161,2,10, 13162,4,4, 22321,4,0, 16679,4,3},
    [9736]={13252,4,2, 13253,4,1},
    [9816]={12905,4,1, 12926,4,0, 12927,4,2, 12929,4,0, 16672,4,3},
    [9938]={11935,4,0, 22208,2,5, 22395,4,9, 22400,4,7, 11746,4,4},
    [10220]={22313,4,1, 13210,4,2, 13211,4,3, 13212,4,0},
    [10264]={12589,4,1, 12603,4,2, 12606,4,2, 12609,4,1, 16695,4,1},
    [10268]={13205,4,6, 13206,4,1, 13208,4,2, 16718,4,2},
    [10339]={12952,4,4, 12953,4,3, 12960,4,2, 16669,4,3, 22225,4,1},
    [10363]={12592,2,8, 12602,4,6, 13098,4,0, 13141,4,0, 13142,4,4, 16666,4,3, 16674,4,3, 16688,4,1, 16690,4,1, 16700,4,1, 16706,4,2, 16721,4,2, 16726,4,4, 16730,4,4, 22253,4,0, 22267,4,1, 22268,4,0, 22269,4,1},
    [10393]={13394,4,4, 13395,4,2, 13396,2,19},
    [10429]={12583,2,6, 12587,4,2, 12590,2,15, 12935,4,4, 12936,4,4, 12939,2,7, 12940,2,7, 18102,4,1, 18103,4,0, 18104,4,3, 22247,4,1, 16733,4,4},
    [10430]={12709,2,15, 12963,4,2, 12964,4,3, 12965,4,1, 12966,4,2, 12967,4,1, 12968,4,1, 12969,2,5, 22311,4,1, 16729,4,4},
    [10432]={14577,4,1, 18691,4,0},
    [10433]={14576,2,7, 18692,4,4},
    [10435]={23198,4,8, 18722,4,4, 13376,4,1, 18725,2,6, 18726,4,2, 18727,4,1},
    [10436]={13534,2,19, 13535,4,1, 13537,4,2, 13538,4,3, 13539,4,4, 18728,4,0, 18729,2,2, 18730,4,1, 16704,4,1},
    [10437]={13529,4,6, 13530,4,1, 13531,4,2, 13532,4,3, 13533,4,4, 18738,2,18, 18739,4,4, 18740,4,1, 16675,4,3},
    [10438]={13524,4,0, 13525,4,1, 13526,4,2, 13527,4,4, 13528,4,3, 18734,4,1, 18735,4,1, 18737,2,0, 16691,4,1},
    [10439]={18723,4,0, 13372,2,10, 13373,4,0, 13374,4,1, 13375,4,6, 13515,4,0, 16737,4,4},
    [10440]={13340,4,1, 13344,4,3, 13345,4,0, 13346,4,1, 13349,2,4, 13361,2,7, 13505,2,8, 22408,2,19, 22409,4,2, 22410,4,3, 22411,4,4, 22412,4,1, 13368,2,15, 16668,4,3, 16678,4,3, 16687,4,1, 16694,4,1, 16699,4,1, 16709,4,2, 16719,4,2, 16728,4,4, 16732,4,4},
    [10503]={14543,4,1, 14545,4,2, 14548,4,3, 18689,4,1, 18690,4,4, 22394,2,10, 14541,2,8, 16701,4,1},
    [10504]={16722,4,4},
    [10505]={16710,4,2},
    [10506]={13983,2,1, 13955,4,4, 13956,4,1, 13957,4,2, 13960,4,0, 13967,4,3, 13969,4,3, 14024,2,15, 16734,4,4},
    [10507]={16716,4,2},
    [10508]={13314,4,1},
    [10509]={12604,4,1, 12930,4,0, 12605,2,19},
    [10516]={16717,4,2, 13404,4,2, 13405,4,4, 13408,2,0, 13409,4,1},
    [10558]={16682,4,1, 13378,4,2, 13379,4,0, 13383,4,3, 13384,4,4},
    [10584]={13258,4,2, 13259,4,4, 22232,4,3, 13178,4,0},
    [10596]={13183,2,4, 13213,4,0, 13244,4,3, 16715,4,2},
    [10808]={13401,2,4, 13400,4,4, 13402,4,3, 13403,4,1, 16724,4,4},
    [10811]={13385,4,0, 13386,4,1, 13387,4,3, 18716,4,2, 16692,4,1, 22206,4,0},
    [10813]={12103,4,0, 13348,2,8, 13353,4,0, 13358,4,2, 13359,4,3, 13360,2,15, 13369,4,1, 18717,2,5, 18718,4,4, 18720,4,1, 16725,4,4},
    [10901]={16705,4,1, 22206,4,0},
    [10997]={13380,2,3, 13381,4,4, 13382,4,0, 18721,4,3, 22403,4,0, 22404,2,13, 22405,4,1, 22406,2,10, 22407,4,2, 16708,4,2, 21524,4,1},
    [11261]={16684,4,1, 14617,4,0},
    [11486]={18373,4,2, 18375,4,2, 18376,2,4, 18378,4,3, 18380,4,4, 18382,4,1, 18388,2,18, 18392,2,15, 18395,4,0, 18396,2,7, 21525,4,1},
    [11487]={18374,4,2, 18350,4,1, 18351,4,4, 18371,4,0, 18397,4,0},
    [11488]={18347,2,0, 18349,4,3, 18383,4,4, 18386,4,1, 22206,4,0},
    [11489]={18352,4,6, 18353,2,10, 18390,4,2, 18393,4,3},
    [11490]={18306,4,1, 18308,4,2, 18313,4,4, 18319,4,3, 18323,2,2},
    [11492]={18309,4,2, 18310,2,7, 18312,4,4, 18314,4,0, 18315,4,0, 18318,4,3, 18321,2,4, 18326,4,4, 18327,4,1, 18328,4,1},
    [11496]={18370,4,0, 18372,2,15, 18377,4,2, 18379,4,3, 18381,4,0, 18384,4,4, 18385,4,1, 18389,4,1, 18391,4,2, 18394,4,3},
    [11501]={18520,2,8, 18521,4,4, 18522,4,0, 18523,4,0, 18524,4,3, 18525,4,2, 18526,4,1, 18527,4,3},
    [11517]={272996,2,4, 272998,2,13, 272999,2,18, 14723,4,3},
    [11518]={14147,4,3, 14150,4,1, 14151,2,15},
    [11519]={273003,2,15, 273005,4,0, 273007,4,2},
    [11520]={14145,2,7, 14148,4,1, 14149,4,1},
    [11622]={14528,4,6, 14537,4,4, 14538,4,1, 14539,4,2, 18686,4,3, 14531,2,5, 16711,4,2},
    [12201]={14922,4,4, 14904,4,4},
    [12203]={17734,4,4, 17736,4,3, 17737,4,0, 17943,2,4, 15642,4,3, 14666,4,2, 14960,4,4, 14794,4,3},
    [12225]={14448,4,1, 17738,2,13, 17739,4,1, 17740,4,2},
    [12236]={17752,2,15, 17754,4,3, 17755,4,1},
    [12237]={17741,4,1, 17742,4,2, 17767,4,3},
    [12258]={17748,4,1, 17749,4,2, 17750,4,1, 17751,4,2},
    [12902]={273841,2,5, 273842,4,3, 273843,2,2},
    [13280]={18305,4,4, 18307,4,1, 18317,4,0, 18322,4,2, 18324,2,1},
    [13282]={17744,4,0, 17745,2,19, 17746,4,4},
    [13596]={17728,4,2, 17730,2,1, 17732,4,1, 14948,4,4, 15637,4,3},
    [13601]={17717,2,3, 17718,4,6, 17719,2,7},
    [14321]={18450,4,1, 18451,4,2, 18458,4,3, 18459,4,4, 18460,2,3, 18462,2,13, 18463,2,7, 18464,4,0},
    [14322]={18425,4,0},
    [14324]={18483,2,19, 18484,2,7, 18485,4,6, 18490,4,2},
    [14325]={18502,2,6, 18503,4,4, 18505,4,2, 18507,4,1},
    [14327]={18301,2,19, 18302,4,0, 18311,2,10, 18325,4,2},
}
-- END LOOT

-- ------------------------------------------
-- The loot of a boss, beside his row in the panel
-- ------------------------------------------
-- The owner: "a left click on a boss, and all he drops: what things, which stats, which
-- are the best for the slot." As ChatGPT drew it and the owner approved (14.11.2026): a
-- small dark window with a gold rim beside the list, a corner pointing at the boss; each
-- thing with its picture in the colour of its quality, its slot and kind, its stats, and
-- on the right a plate: BiS, better than worn +N, or not for the class (then dimmed).
local function rgba(h, a)
    return {tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255,
        a or (#h == 8 and tonumber(h:sub(7, 8), 16) / 255) or 1}
end
-- The sizes and colours of ChatGPT's code layout (art/код-макет-14.11/добыча-босса-размеры-и-цвета.txt).
local LOOT = {width=366, head=44, pad=8, icon=42, tagw=80, gap=22,
    bg=rgba("17120FF5"), headBg=rgba("251A12FA"), rim=rgba("B08B4E"), inner=rgba("523920"), divider=rgba("80623F99"),
    row=rgba("241A14E8"), rowAlt=rgba("1B1612E8"), noRow=rgba("181818EA"), noText=rgba("8A8783"), iconBg=rgba("24142B"),
    title=rgba("F2CC6D"), sub=rgba("B9B4AA"), slot=rgba("B9B4AA"), stat=rgba("ECE3D1"),
    bis={bg=rgba("562361"), rim=rgba("B94BE4"), text=rgba("FFE1FF")},
    better={bg=rgba("233E1D"), rim=rgba("5EAD49"), text=rgba("C1F1AA")},
    no={bg=rgba("29292A"), rim=rgba("656566"), text=rgba("B3B3B3")}}
-- The rim of the picture and the name, by quality (the layout's lighter names for blue and purple).
local QUALITY_LOOK = {
    [0] = {rim=rgba("9D9D9D"), name=rgba("A3A3A3")}, [1] = {rim=rgba("FFFFFF"), name=rgba("FFFFFF")},
    [2] = {rim=rgba("1EFF00"), name=rgba("1EFF00")}, [3] = {rim=rgba("0070DD"), name=rgba("69B5FF")},
    [4] = {rim=rgba("A335EE"), name=rgba("D395FF")}, [5] = {rim=rgba("FF8000"), name=rgba("FF8000")}}
local FOR_CLASS = {MAGE=L"не для мага", PRIEST=L"не для жреца", WARLOCK=L"не для чернокнижника", WARRIOR=L"не для воина",
    ROGUE=L"не для разбойника", HUNTER=L"не для охотника", DRUID=L"не для друида", SHAMAN=L"не для шамана", PALADIN=L"не для паладина"}

local lootFrame
local function colour(tex, c) if tex and tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end end

-- A plate with a rim and a word, in the column at the right of a row.
local function plate(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.rim = f:CreateTexture(nil, "BACKGROUND")
    f.rim:SetAllPoints()
    f.bg = f:CreateTexture(nil, "BORDER")
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")
    f.text:SetJustifyH("CENTER")
    if f.text.SetFont and f.text.GetFont then
        local font = f.text:GetFont()
        if font then pcall(f.text.SetFont, f.text, font, 10, "") end
    end
    function f:Look(look, word, wide)
        colour(self.rim, look.rim)
        colour(self.bg, look.bg)
        self.text:SetText(word)
        self.text:SetTextColor(look.text[1], look.text[2], look.text[3])
        local width = tonumber(self.text.GetStringWidth and self.text:GetStringWidth()) or 30
        local lines = select(2, word:gsub("\n", "")) + 1
        self:SetSize(wide and LOOT.tagw or math.max(37, math.min(LOOT.tagw, width + 10)), lines > 1 and (lines * 12 + 6) or 19)
        self:Show()
    end
    return f
end

local function lootRow(i)
    local f = lootFrame
    local row = f.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, f)
    f.rows[i] = row
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetAllPoints()
    row.edge = row:CreateTexture(nil, "BORDER")
    row.edge:SetHeight(1)
    row.edge:SetPoint("BOTTOMLEFT", 0, 0)
    row.edge:SetPoint("BOTTOMRIGHT", 0, 0)
    colour(row.edge, LOOT.divider)
    row.frame = row:CreateTexture(nil, "BORDER")
    row.frame:SetSize(LOOT.icon, LOOT.icon)
    row.frame:SetPoint("TOPLEFT", LOOT.pad, -LOOT.pad)
    row.back = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.back:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 2, -2)
    row.back:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", -2, 2)
    colour(row.back, LOOT.iconBg)
    row.icon = row:CreateTexture(nil, "ARTWORK", nil, 2)
    row.icon:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", -2, 2)
    local textWidth = LOOT.width - 4 - LOOT.pad * 2 - LOOT.icon - LOOT.tagw - 16
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.frame, "TOPRIGHT", 8, 0)
    row.name:SetWidth(textWidth)
    row.name:SetJustifyH("LEFT")
    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.slot:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.slot:SetWidth(textWidth)
    row.slot:SetJustifyH("LEFT")
    row.stats = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.stats:SetPoint("TOPLEFT", row.slot, "BOTTOMLEFT", 0, -3)
    row.stats:SetWidth(textWidth)
    row.stats:SetJustifyH("LEFT")
    row.tag = plate(row)
    row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LOOT.pad, -LOOT.pad)
    row.tag2 = plate(row)
    row.tag2:SetPoint("TOPRIGHT", row.tag, "BOTTOMRIGHT", 0, -6)
    row:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
        else pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.id) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Shift-click puts the thing into the chat, as everywhere in the game.
    row:SetScript("OnClick", function(self)
        local link = self.id and GetItemInfo and select(2, GetItemInfo(self.id))
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)
    return row
end

local function buildLoot()
    local f = CreateFrame("Frame", "DungeonQuestForeverLoot", UIParent)
    lootFrame = f
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetWidth(LOOT.width)
    f.rim = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.rim:SetAllPoints()
    colour(f.rim, LOOT.rim)
    f.inner = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.inner:SetPoint("TOPLEFT", 2, -2)
    f.inner:SetPoint("BOTTOMRIGHT", -2, 2)
    colour(f.inner, LOOT.inner)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.bg:SetPoint("TOPLEFT", 3, -3)
    f.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    colour(f.bg, LOOT.bg)
    f.headBg = f:CreateTexture(nil, "BACKGROUND", nil, 4)
    f.headBg:SetPoint("TOPLEFT", 3, -3)
    f.headBg:SetPoint("TOPRIGHT", -3, -3)
    f.headBg:SetHeight(LOOT.head - 3)
    colour(f.headBg, LOOT.headBg)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", LOOT.pad + 2, -9)
    f.title:SetPoint("RIGHT", f, "RIGHT", -30, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.title:SetTextColor(LOOT.title[1], LOOT.title[2], LOOT.title[3])
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.sub:SetTextColor(LOOT.sub[1], LOOT.sub[2], LOOT.sub[3])
    f.headLine = f:CreateTexture(nil, "ARTWORK")
    f.headLine:SetHeight(1)
    f.headLine:SetPoint("TOPLEFT", 3, -LOOT.head)
    f.headLine:SetPoint("TOPRIGHT", -3, -LOOT.head)
    colour(f.headLine, LOOT.divider)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() P.HideLoot() end)
    -- The corner pointing at the boss in the list: a square turned by 45 degrees, its
    -- rim and its inside, half out of the window's right side.
    f.cornerRim = f:CreateTexture(nil, "BORDER")
    f.cornerRim:SetSize(16, 16)
    colour(f.cornerRim, LOOT.rim)
    f.corner = f:CreateTexture(nil, "ARTWORK")
    f.corner:SetSize(12, 12)
    colour(f.corner, LOOT.bg)
    for _, t in ipairs({f.cornerRim, f.corner}) do
        if t.SetRotation then pcall(t.SetRotation, t, math.pi / 4) end
    end
    f.rows = {}
    f:SetScript("OnHide", function(self) self.npc = nil; if P.Refresh then pcall(P.Refresh) end end)
    if f.RegisterEvent then
        pcall(f.RegisterEvent, f, "GET_ITEM_INFO_RECEIVED")
        f:SetScript("OnEvent", function(self) if self:IsShown() and self.entry then P.DrawLoot() end end)
    end
end

local function height(fs) return tonumber(fs and fs.GetStringHeight and fs:GetStringHeight()) or 14 end

function P.DrawLoot()
    local f = lootFrame
    if not (f and f.entry) then return end
    local entry = f.entry
    f.title:SetText(entry.name or "")
    local loot = P.LootFor and P.LootFor(entry.npc) or {}
    f.sub:SetText(#loot > 0 and (L"добыча босса") or (L"добычи в базе нет"))
    local class = playerClass()
    for _, row in ipairs(f.rows) do row:Hide() end
    local y = LOOT.head + 1
    for i, thing in ipairs(loot) do
        local row = lootRow(i)
        row.id = thing.id
        local worth = thing.worth or {}
        local name, quality, icon
        if GetItemInfo then
            local got = {GetItemInfo(thing.id)}
            if got[1] then name, quality, icon = got[1], got[3], got[10] end
        end
        quality = quality or worth.quality or 1
        icon = icon or (GetItemIcon and GetItemIcon(thing.id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        local look = QUALITY_LOOK[quality] or QUALITY_LOOK[1]
        local unusable = not thing.mine or worth.unusable
        row.icon:SetTexture(icon)
        row.icon:SetAlpha(unusable and .45 or 1)
        colour(row.frame, look.rim)
        colour(row.fill, unusable and LOOT.noRow or (i % 2 == 0 and LOOT.rowAlt or LOOT.row))
        row.name:SetText(name or thing.name)
        local slot = {}
        if worth.place then slot[#slot+1] = worth.place end
        if thing.kind and thing.kind ~= worth.place then slot[#slot+1] = thing.kind end
        row.slot:SetText(table.concat(slot, " • "))
        row.stats:SetText((worth.stats and worth.stats ~= "") and (worth.stats:gsub(", ", " • ")) or "")
        local nameC, slotC, statC = look.name, LOOT.slot, LOOT.stat
        if unusable then nameC, slotC, statC = LOOT.noText, LOOT.noText, LOOT.noText end
        row.name:SetTextColor(nameC[1], nameC[2], nameC[3])
        row.slot:SetTextColor(slotC[1], slotC[2], slotC[3])
        row.stats:SetTextColor(statC[1], statC[2], statC[3])
        row.tag:Hide()
        row.tag2:Hide()
        local tags = 0
        if unusable then
            row.tag:Look(LOOT.no, FOR_CLASS[class] or (L"не для твоего класса"), true)
            tags = 19
        else
            local free = row.tag
            if worth.best then row.tag:Look(LOOT.bis, "BiS"); free = row.tag2; tags = 19 + 6 end
            if worth.known and (worth.gain or 0) > 0 and not worth.worn then
                free:Look(LOOT.better, ((L"лучше надетого +%d"):format(math.floor(worth.gain + .5)):gsub(" %+", "\n+", 1)), true)
                tags = tags + 30
            elseif worth.worn then
                free:Look(LOOT.no, L"надето", true)
                tags = tags + 19
            end
        end
        local text = height(row.name) + 3 + height(row.slot) + (row.stats:GetText() ~= "" and (3 + height(row.stats)) or 0)
        local h = math.max(LOOT.icon, text, tags) + LOOT.pad * 2
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -y)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -y)
        row:SetHeight(h)
        row.edge:SetShown(i < #loot)
        row:Show()
        y = y + h
    end
    f:SetHeight(y + 3 + (#loot == 0 and 6 or 0))
end

local function stand(f, block)
    f:ClearAllPoints()
    if block and block.GetTop then
        f:SetPoint("RIGHT", block, "LEFT", -LOOT.gap, 0)
        f.cornerRim:ClearAllPoints()
        f.cornerRim:SetPoint("CENTER", f, "RIGHT", 0, 0)
        f.corner:ClearAllPoints()
        f.corner:SetPoint("CENTER", f, "RIGHT", -1, 0)
        f.cornerRim:Show()
        f.corner:Show()
    else
        f:SetPoint("CENTER")
        f.cornerRim:Hide()
        f.corner:Hide()
    end
end

-- Opened beside a row of the panel; the same boss again puts it away.
function P.ToggleLoot(entry, block)
    if lootFrame and lootFrame:IsShown() and lootFrame.npc == entry.npc then P.HideLoot() return false end
    if not lootFrame then buildLoot() end
    local f = lootFrame
    f.entry, f.npc = entry, entry.npc
    P.DrawLoot()
    stand(f, block)
    f:Show()
    P.Track("LootOpened")
    if P.Refresh then pcall(P.Refresh) end
    return true
end

-- Stood again beside the row of its boss after the panel is laid out anew.
function P.AnchorLoot(block)
    local f = lootFrame
    if not (f and f:IsShown() and block) then return end
    stand(f, block)
end

function P.HideLoot()
    if lootFrame and lootFrame:IsShown() then lootFrame:Hide() end
end

-- The boss whose loot is open (his row wears the gold frame).
function P.LootOpenFor() return lootFrame and lootFrame:IsShown() and lootFrame.npc or nil end
