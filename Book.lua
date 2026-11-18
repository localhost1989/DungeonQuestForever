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

-- ------------------------------------------
-- What a quest gives
-- ------------------------------------------
-- The owner, 17.11.2026: "why is there no reward in our quest journal?" - and he approved
-- ChatGPT's layout of it: under "Где", "Награда"; the things to choose from, each picture
-- in a rim of its quality and its name in that colour, a green arrow on the one better than
-- what is worn; then what is given besides, and the money in coins. What the databases
-- know is at the foot of this file (P.Rewards); but Forever adds things of its own to the
-- choice, so the game's own answer, read while the quest is in the log or open at its
-- giver, is kept (db.rewards) and stands over the databases from then on.
local russian = (GetLocale and GetLocale() or "enUS") == "ruRU"
local function itemOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
-- count things read through link(i) and info(i) (the count third, as the game gives it).
local function readThings(count, link, info)
    local list = {}
    for i = 1, tonumber(count) or 0 do
        local id = itemOf(link(i))
        if not id then return nil end   -- the game does not know the thing yet: read again later
        local _, _, n = info(i)
        list[#list+1] = id
        list[#list+1] = tonumber(n) or 1
    end
    return list
end
local function keep(id, choice, given, money)
    local db = P.char
    if not (db and type(id) == "number" and id > 0 and choice and given) then return false end
    db.rewards = type(db.rewards) == "table" and db.rewards or {}
    db.rewards[id] = {c=choice, g=given, m=tonumber(money) or 0, at=time and time() or nil}
    return true
end
-- At the giver: the quest offered (QUEST_DETAIL) or handed in (QUEST_COMPLETE). Called by the
-- hands of Plan.lua before they accept or take anything, while the window is still open.
function P.KeepReward(event)
    if event ~= "QUEST_DETAIL" and event ~= "QUEST_COMPLETE" then return end
    if not (GetQuestID and GetNumQuestChoices and GetNumQuestRewards and GetQuestItemLink and GetQuestItemInfo) then return end
    local id = GetQuestID()
    local choice = readThings(GetNumQuestChoices(), function(i) return GetQuestItemLink("choice", i) end, function(i) return GetQuestItemInfo("choice", i) end)
    local given = readThings(GetNumQuestRewards(), function(i) return GetQuestItemLink("reward", i) end, function(i) return GetQuestItemInfo("reward", i) end)
    return keep(id, choice, given, GetRewardMoney and GetRewardMoney() or 0)
end
-- In the log: the quest's entry is chosen for a moment, read, and the choice put back. Not
-- while the player's own quest log is open, nor in a fight; a quest is read once a sitting
-- (again a little later if the game did not know a thing yet).
local readAt = {}
function P.RewardFromLog(id)
    if not (P.char and SelectQuestLogEntry and GetQuestLogSelection and GetQuestLogIndexByID and GetNumQuestLogChoices
        and GetNumQuestLogRewards and GetQuestLogItemLink and GetQuestLogChoiceInfo and GetQuestLogRewardInfo) then return false end
    local now = GetTime and GetTime() or 0
    if readAt[id] and (readAt[id] == true or now - readAt[id] < 10) then return false end
    if QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local index = GetQuestLogIndexByID(id)
    if not index or index == 0 then return false end
    readAt[id] = now
    local before = GetQuestLogSelection()
    local ok, choice, given, money = pcall(function()
        SelectQuestLogEntry(index)
        return readThings(GetNumQuestLogChoices(), function(i) return GetQuestLogItemLink("choice", i) end, GetQuestLogChoiceInfo),
            readThings(GetNumQuestLogRewards(), function(i) return GetQuestLogItemLink("reward", i) end, GetQuestLogRewardInfo),
            GetQuestLogRewardMoney and GetQuestLogRewardMoney() or 0
    end)
    pcall(SelectQuestLogEntry, before or 0)
    if ok and keep(id, choice, given, money) then readAt[id] = true return true end
    return false
end
-- What a quest gives: {choice={{id, count}...}, given={...}, money, live} or nil when nothing
-- is known of it, or it gives nothing.
function P.RewardOf(id)
    local live = P.char and type(P.char.rewards) == "table" and P.char.rewards[id]
    local raw = live or (P.Rewards and P.Rewards[id])
    if not raw then return nil end
    local out = {choice={}, given={}, money=tonumber(raw.m) or 0, live=live and true or false}
    for _, pair in ipairs({{raw.c, out.choice}, {raw.g, out.given}}) do
        local list, into = pair[1] or {}, pair[2]
        for i = 1, #list, 2 do into[#into+1] = {id=list[i], count=list[i + 1] or 1} end
    end
    if #out.choice == 0 and #out.given == 0 and out.money <= 0 then return nil end
    return out
end
-- The name and quality of a thing: the game's, else the databases' until the game tells.
local function thingName(id)
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, _, quality = pcall(info or function() end, id)
    if ok and type(name) == "string" and name ~= "" then return name, quality end
    request(id)
    local baked = P.RewardItems and P.RewardItems[id]
    if baked then return (russian and baked[1] or baked[2] or baked[1] or ("#" .. id)), baked[3] end
    local okDb, dbName = pcall(function() return ItemDB and ItemDB.Get(id, "name") end)
    return (okDb and type(dbName) == "string" and dbName ~= "" and dbName) or ("#" .. id), nil
end
P.RewardName = thingName
-- Money in coins: "1 золотой 20 серебра".
function P.MoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then
        local word = (gold % 10 == 1 and gold % 100 ~= 11) and (L"золотой") or (L"золотых")
        parts[#parts+1] = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t |cffffd100" .. gold .. " " .. word .. "|r"
    end
    if silver > 0 then parts[#parts+1] = "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:0:0|t |cffe6e0d2" .. silver .. " " .. L"серебра" .. "|r" end
    if rest > 0 then parts[#parts+1] = "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:0:0|t |cffe6e0d2" .. rest .. " " .. L"меди" .. "|r" end
    return table.concat(parts, "   ")
end

-- Every quest in the log whose reward the game has not told yet.
function P.SweepRewards()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return 0 end
    local read = 0
    for i = 1, tonumber(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local ok, info = pcall(C_QuestLog.GetInfo, i)
        local id = ok and type(info) == "table" and not info.isHeader and info.questID
        if id and not (P.char and type(P.char.rewards) == "table" and P.char.rewards[id]) and P.RewardFromLog(id) then read = read + 1 end
    end
    return read
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
            local passed = marked or (c.total > 0 and c.finished >= c.total)
            -- (Forever's new dungeons are listed without quests: the way in is worth having.)
            if (c.total > 0 or d.forever) and not (db.bookHideDone and passed) then
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
    -- The reward: its head ends the text; the things and the money stand under it.
    if P.IsActive and P.IsActive(id) and not (P.char and type(P.char.rewards) == "table" and P.char.rewards[id]) then pcall(P.RewardFromLog, id) end
    local reward = P.RewardOf(id)
    if reward then head(L"Награда") end
    local meta = {}
    if info.level and info.level > 0 then meta[#meta+1] = L"Уровень: " .. info.level end
    if info.required and info.required > 0 then meta[#meta+1] = L"Требуется уровень " .. info.required end
    return {title=P.Title(id) or ("#" .. id), meta=table.concat(meta, "   "), status=status, state=state, body=table.concat(lines, "\n"), row=row, id=id, reward=reward}
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
    -- The reward of a quest, under its head: "На выбор:" and the things, "Вы получите:" and
    -- the things given and the money. Two to a line when one to a line does not fit.
    for _, bit in ipairs(book.rewardRows) do bit:Hide() end
    for _, bit in ipairs(book.rewardLabels) do bit:Hide() end
    view.reward = nil
    local reward = page and page.reward
    if reward then
        local room = 1000
        if book.body.GetBottom and book.paper.GetBottom then
            local top, floor = book.body:GetBottom(), book.paper:GetBottom()
            if type(top) == "number" and type(floor) == "number" then room = top - floor - 48 end
        end
        local groups = {}
        if #reward.choice > 0 then groups[#groups+1] = {label=L"На выбор:", list=reward.choice} end
        if #reward.given > 0 or reward.money > 0 then groups[#groups+1] = {label=L"Вы получите:", list=reward.given, money=reward.money} end
        local LINE, ROW = 20, 34
        local need = 0
        for _, g in ipairs(groups) do need = need + LINE + #g.list * ROW + ((g.money or 0) > 0 and LINE or 0) end
        local columns = need > room and 2 or 1
        local cell = math.floor(book.body:GetWidth() / columns)
        local shown = {rows={}, labels={}, columns=columns}
        local y, rows, labels, left = 2, 0, 0, 0
        local function label(text)
            labels = labels + 1
            local l = book:RewardLabel(labels)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", book.body, "BOTTOMLEFT", 0, -y)
            l:SetText(text)
            l:Show()
            shown.labels[#shown.labels+1] = text
            y = y + LINE
        end
        for _, g in ipairs(groups) do
            label(INK .. g.label .. "|r")
            for i, thing in ipairs(g.list) do
                local column = (i - 1) % columns
                if y + ROW > room and column == 0 then left = left + 1
                elseif y + ROW <= room then
                    rows = rows + 1
                    local r = book:RewardRow(rows)
                    local name, quality = thingName(thing.id)
                    local worth = P.Worth(thing.id)
                    local better = worth.known and not worth.unusable and not worth.worn and (worth.gain or 0) > 0 or false
                    local tone = QUALITY[quality or -1] or "ffffffff"
                    r.thing = thing
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", book.body, "BOTTOMLEFT", column * cell, -y)
                    r:SetSize(cell - 6, ROW - 4)
                    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(thing.id))
                        or (P.RewardItems and P.RewardItems[thing.id] and P.RewardItems[thing.id][4] and ("Interface\\Icons\\" .. P.RewardItems[thing.id][4]))
                        or "Interface\\Icons\\INV_Misc_QuestionMark"
                    r.icon:SetTexture(icon)
                    r.iconFile = icon
                    r.edge:SetVertexColor(tonumber(tone:sub(3, 4), 16) / 255, tonumber(tone:sub(5, 6), 16) / 255, tonumber(tone:sub(7, 8), 16) / 255)
                    r.name:SetWidth(cell - 6 - 38)
                    r.name:SetText("|c" .. tone .. name .. "|r")
                    r.count:SetText((thing.count or 1) > 1 and tostring(thing.count) or "")
                    r.better:SetShown(better)
                    r.worth = worth
                    r:Show()
                    shown.rows[#shown.rows+1] = {id=thing.id, name=name, quality=quality, count=thing.count, better=better, choice=g.money == nil}
                else left = left + 1 end
                if (column == columns - 1 or i == #g.list) and y + ROW <= room then y = y + ROW end
            end
            if (g.money or 0) > 0 then
                label(P.MoneyText(g.money))
                shown.money = P.MoneyText(g.money)
            end
        end
        if left > 0 then label(FADED .. L"и ещё " .. left .. "|r") end
        view.reward = shown
    end
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
        if P.Track then P.Track("BookModeSwitched") end
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
        -- (The owner, 15.11.2026: "so that a dungeon passed can be hidden, as the bosses can,
        -- if I am not going to do its one quest left." The right click did it; now the row
        -- says so when pointed at.)
        row:SetScript("OnEnter", function(self)
            local it = self.item
            if not (it and it.kind == "dungeon" and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(atlas.DungeonName(it.d), 1, .82, .35)
            GameTooltip:AddLine(L"Щелчок — задания этого подземелья.", 1, 1, 1, true)
            GameTooltip:AddLine(it.marked and (L"ПКМ — вернуть в работу.")
                or (L"ПКМ — отметить пройденным, если больше туда не пойдёшь: оно уйдёт из списка. Кнопка «Показать пройденные» вернёт его."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
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
                if P.Track then P.Track("DungeonHidden") end
                -- Marked passed, or back in the list.
                local db = P.char
                if db then
                    db.hidden = db.hidden or {}
                    db.hidden[item.d.key] = not db.hidden[item.d.key] or nil
                    if P.LeaveHidden then P.LeaveHidden() end
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
    -- The reward of a quest (the layout of 17.11.2026): a picture in a rim of its quality,
    -- the count on it as the game puts it, the name in the colour of its quality, the green
    -- arrow of the game's bags on the thing better than what is worn.
    frame.rewardRows, frame.rewardLabels = {}, {}
    function frame:RewardLabel(i)
        if self.rewardLabels[i] then return self.rewardLabels[i] end
        local l = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l:SetWidth(width)
        l:SetJustifyH("LEFT")
        self.rewardLabels[i] = l
        return l
    end
    function frame:RewardRow(i)
        if self.rewardRows[i] then return self.rewardRows[i] end
        local row = CreateFrame("Button", nil, self)
        self.rewardRows[i] = row
        if row.SetFrameLevel and self.GetFrameLevel then row:SetFrameLevel((self:GetFrameLevel() or 1) + 6) end
        row.edge = row:CreateTexture(nil, "BORDER")
        if row.edge.SetColorTexture then row.edge:SetColorTexture(1, 1, 1, 1) end
        row.edge:SetSize(30, 30)
        row.edge:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(26, 26)
        row.icon:SetPoint("CENTER", row.edge, "CENTER", 0, 0)
        if row.icon.SetTexCoord then row.icon:SetTexCoord(.07, .93, .07, .93) end
        row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        row.count:SetPoint("BOTTOMRIGHT", row.edge, "BOTTOMRIGHT", -1, 1)
        row.better = row:CreateTexture(nil, "OVERLAY")
        row.better:SetSize(14, 14)
        row.better:SetPoint("BOTTOMRIGHT", row.edge, "BOTTOMRIGHT", 2, -2)
        local atlasOk = row.better.SetAtlas and pcall(row.better.SetAtlas, row.better, "bags-greenarrow")
        if not atlasOk or (row.better.GetAtlas and not row.better:GetAtlas()) then
            row.better:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\arrow")
            if row.better.SetDesaturated then row.better:SetDesaturated(true) end
            row.better:SetVertexColor(.25, 1, .25)
        end
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", row, "LEFT", 38, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnEnter", function(self)
            if not (self.thing and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.thing.id)
            if not ok then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.thing.id) end
            local worth = self.worth
            if worth and worth.known and not worth.unusable and not worth.worn and (worth.gain or 0) > 0 then
                GameTooltip:AddLine("+" .. ("%.0f"):format(worth.gain) .. L" к надетому", .25, .88, .25)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row:SetScript("OnClick", function(self)
            if P.Track then P.Track("RewardClicked") end
            local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            local _, link = info and self.thing and info(self.thing.id)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
        end)
        return row
    end
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
        local due, pace, age, swept = nil, 0, 0, false
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
                -- The rewards of the quests in the log, read once a while after coming in.
                if not swept and age > 20 and not (InCombatLockdown and InCombatLockdown()) then
                    swept = true
                    pcall(P.SweepRewards)
                end
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
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local link = self.id and info and select(2, info(self.id))
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
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if info then
            local got = {info(thing.id)}
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

-- BEGIN REWARDS: generated by dungeon-quest-handoff/make-rewards-lua.py from quest-rewards.json; do not edit by hand
-- [quest] = {c things to choose from {item, count, ...}, g things given, m money in copper}
P.Rewards = {
    [17]={g={250947,5},m=5500},
    [166]={c={6087,1,2041,1,2042,1}},
    [167]={c={1893,1,270012,1,270013,1}},
    [168]={c={2037,1,2036,1,270007,1}},
    [214]={c={2074,1,2089,1,6094,1,270005,1}},
    [261]={m=4500},
    [303]={m=2500},
    [373]={m=700},
    [377]={c={2033,1,2906,1,270029,1}},
    [378]={c={3562,1,1264,1,270036,1}},
    [386]={c={3400,1,1317,1,270027,1}},
    [387]={m=4000},
    [388]={m=4000},
    [391]={m=2500},
    [704]={c={4980,1,270059,1,270060,1}},
    [709]={c={4746,1,270074,1,270075,1}},
    [738]={g={4982,1,1529,1,2776,2},m=400},
    [739]={g={4983,1}},
    [762]={g={4987,1},m=12500},
    [865]={g={5342,5,5343,1}},
    [880]={m=800},
    [914]={c={6505,1,6504,1,270018,1}},
    [959]={m=1000},
    [962]={g={10919,1},m=2000},
    [971]={g={6743,1}},
    [1013]={c={6335,1,4534,1,270030,1}},
    [1014]={g={6414,1}},
    [1048]={c={6802,1,6803,1,10711,1}},
    [1049]={c={7747,1,17508,1,7749,1}},
    [1050]={g={7746,1}},
    [1051]={c={7750,1,4643,1},g={7751,1}},
    [1053]={c={6829,1,6830,1,6831,1,11262,1}},
    [1098]={c={3324,1,270023,1,270024,1},m=1800},
    [1101]={c={4197,1,6742,1,6725,1},g={3041,1}},
    [1102]={c={4197,1,6742,1,6725,1}},
    [1139]={g={6723,1},m=13000},
    [1142]={c={6751,1,6752,1}},
    [1144]={c={6748,1,6750,1,6749,1,274078,1}},
    [1199]={c={270025,1},g={6998,1,7000,1}},
    [1200]={c={7001,1,7002,1,270031,1,270032,1},m=6500},
    [1221]={g={6755,1}},
    [1275]={c={7003,1,7004,1},m=3500},
    [1318]={c={18366,1,18367,1,18368,1,18369,1}},
    [1360]={m=6000},
    [1424]={m=12000},
    [1445]={g={1490,1}},
    [1446]={c={11123,1,11124,1}},
    [1475]={g={1490,1}},
    [1486]={c={6480,1,918,1},m=1800},
    [1487]={c={6476,1,8071,1,6481,1},m=2500},
    [1491]={m=1000},
    [2040]={c={7606,1,7607,1,270015,1,270016,1}},
    [2202]={g={9030,5},m=5500},
    [2240]={c={9626,1,9627,1}},
    [2258]={m=4500},
    [2340]={m=12500},
    [2341]={g={7888,1}},
    [2342]={m=6000},
    [2361]={g={7673,1}},
    [2398]={m=500},
    [2418]={c={9522,1,10358,1,10359,1,270055,1}},
    [2439]={c={3928,5,6149,5},g={9587,1}},
    [2440]={c={3928,5,6149,5},g={9587,1}},
    [2500]={m=4500},
    [2768]={c={9533,1,9534,1,270099,1}},
    [2770]={g={11122,1},m=7500},
    [2841]={c={9623,1,9624,1,9625,1}},
    [2843]={g={9173,1}},
    [2846]={g={9527,1,9531,1},m=6500},
    [2865]={m=6500},
    [2904]={c={9535,1,9536,1,270042,1}},
    [2922]={m=2000},
    [2924]={m=5500},
    [2926]={m=2200},
    [2928]={c={9608,1,9609,1}},
    [2929]={c={9623,1,9624,1,9625,1},m=3500},
    [2930]={g={9605,1,9604,1},m=2500},
    [2952]={g={9363,1}},
    [2962]={m=2500},
    [2991]={m=7000},
    [3042]={m=19500},
    [3341]={c={270081,1},g={10823,1,10824,1}},
    [3373]={g={10455,1}},
    [3442]={m=14000},
    [3443]={m=14000},
    [3447]={g={10773,1}},
    [3452]={m=7500},
    [3454]={g={10515,1}},
    [3463]={c={10742,1,10743,1,10744,1},m=23000},
    [3481]={g={10569,1}},
    [3525]={g={10710,1}},
    [3528]={c={10749,1,10750,1,10751,1},m=24000},
    [3636]={c={270081,1},g={10823,1,10824,1}},
    [3701]={g={12102,1},m=16500},
    [3802]={g={11000,1},m=23000},
    [3906]={m=15500},
    [3907]={c={12113,1,12114,1,12112,1,12115,1},m=25500},
    [4004]={c={12544,1,12545,1},m=27000},
    [4024]={c={12066,1,12082,1,12083,1},m=26500},
    [4061]={m=16500},
    [4063]={c={12109,1,12110,1,12108,1,12111,1},m=26500},
    [4081]={m=15500},
    [4082]={m=16500},
    [4121]={m=26500},
    [4123]={m=8500},
    [4126]={c={11964,1,12000,1},g={12003,10},m=16500},
    [4132]={g={12059,1},m=26500},
    [4134]={c={11964,1,12000,1},g={3928,5,6149,5},m=8500},
    [4136]={c={11865,1,11963,1,12049,1},m=6000},
    [4182]={m=16500},
    [4201]={c={11962,1,11866,1},m=8000},
    [4242]={c={12018,1,12021,1,12041,1}},
    [4262]={m=15500},
    [4263]={c={12113,1,12114,1,12112,1,12115,1},m=8500},
    [4282]={m=9000},
    [4286]={g={11883,1},m=8500},
    [4322]={c={12061,1,12062,1},g={12065,1},m=17500},
    [4363]={c={12548,1,12543,1},m=26500},
    [4605]={g={9363,1}},
    [4606]={g={9363,1}},
    [4701]={c={15824,1,15825,1,15827,1},m=18000},
    [4724]={c={15824,1,15825,1,15827,1},m=18000},
    [4726]={m=7500},
    [4729]={g={12264,1},m=9000},
    [4734]={g={12144,1},m=18000},
    [4735]={m=27000},
    [4743]={g={12344,1}},
    [4765]={c={15861,1,15860,1},m=27000},
    [4768]={c={15861,1,15860,1},m=27000},
    [4771]={c={15853,1,15854,1},m=27000},
    [4810]={c={15862,1,15863,1}},
    [4862]={g={12529,1},m=9000},
    [4866]={g={15873,1},m=18000},
    [4867]={g={15867,1}},
    [4903]={c={13958,1,13959,1,13961,1,13962,1,13963,1},m=18000},
    [4974]={c={13966,1,13968,1,13965,1},m=27000},
    [4983]={c={15858,1,15859,1},m=18000},
    [5002]={m=18000},
    [5081]={c={13958,1,13959,1,13961,1,13962,1,13963,1},m=18000},
    [5102]={c={13966,1,13968,1,13965,1},m=27000},
    [5125]={c={17044,1,17045,1}},
    [5127]={g={12696,1,9224,5,12849,1}},
    [5212]={m=18000},
    [5213]={c={13209,1,19812,1}},
    [5214]={g={13171,1}},
    [5243]={c={13216,1,13217,1},g={3928,5,6149,5},m=18000},
    [5251]={m=18000},
    [5282]={g={13315,1},m=18000},
    [5341]={m=18000},
    [5343]={m=18000},
    [5384]={c={15805,1,15806,1},g={13544,1}},
    [5466]={c={13982,1,13986,1,13984,1},g={14002,1}},
    [5518]={g={18258,1}},
    [5528]={g={18269,5,18284,5}},
    [5529]={m=9000},
    [5723]={m=700},
    [5724]={c={15452,1,15453,1}},
    [5725]={c={15449,1,15450,1,15451,1}},
    [5726]={m=250},
    [5728]={m=800},
    [5761]={m=800},
    [6022]={m=9000},
    [6042]={m=9000},
    [6133]={m=9000},
    [6135]={c={16994,1,16995,1},m=9000},
    [6136]={c={17002,1,17003,1,17004,1},m=9000},
    [6163]={c={18022,1,17001,1},m=18000},
    [6502]={g={16309,1}},
    [6521]={c={17039,1,17042,1,17043,1},m=2000},
    [6522]={m=4000},
    [6561]={c={7001,1,7002,1,270031,1,270032,1},m=6500},
    [6563]={m=1400},
    [6564]={m=1100},
    [6565]={c={17694,1,17695,1},m=4000},
    [6602]={g={16309,1}},
    [6626]={m=7500},
    [6921]={m=4500},
    [6922]={c={16886,1,16887,1,270043,1}},
    [7028]={c={17775,1,17776,1,17777,1,17779,1}},
    [7029]={c={17768,1,17778,1,17770,1}},
    [7041]={c={17768,1,17778,1,17770,1}},
    [7046]={g={17191,1}},
    [7064]={c={17705,1,17743,1,17753,1}},
    [7065]={c={17705,1,17743,1,17753,1}},
    [7066]={m=15000},
    [7067]={g={17774,1},m=14000},
    [7068]={c={17772,1,17773,1}},
    [7070]={c={17772,1,17773,1}},
    [7201]={g={12038,1},m=24500},
    [7441]={c={18411,1,18410,1},m=17500},
    [7462]={c={18420,1,18421,1,18424,1},m=27000},
    [7481]={m=18000},
    [7482]={m=18000},
    [7488]={c={18491,1,270125,1},m=17000},
    [7489]={c={18491,1,270125,1},m=17000},
    [7498]={g={18465,1}},
    [7499]={g={18466,1}},
    [7500]={g={18468,1}},
    [7501]={g={18472,1}},
    [7502]={g={18467,1}},
    [7503]={g={18473,1}},
    [7504]={g={18469,1}},
    [7505]={g={18471,1}},
    [7506]={g={18470,1}},
    [7604]={g={18592,1}},
    [7703]={c={18366,1,18367,1,18368,1,18369,1}},
    [7877]={c={18420,1,18421,1,18424,1},m=27000},
    [8301]={g={20403,1}},
    [8905]={g={22108,1}},
    [8906]={g={22011,1}},
    [8907]={g={22063,1}},
    [8908]={g={22088,1}},
    [8909]={g={22079,1}},
    [8910]={g={22004,1}},
    [8911]={g={22071,1}},
    [8912]={g={21996,1}},
    [8913]={g={22108,1}},
    [8914]={g={22011,1}},
    [8915]={g={22063,1}},
    [8916]={g={22079,1}},
    [8917]={g={22004,1}},
    [8918]={g={22095,1}},
    [8919]={g={22071,1}},
    [8920]={g={21996,1}},
    [8921]={g={22320,1}},
    [8924]={m=9000},
    [8925]={m=9000},
    [8926]={g={22106,1,22110,1}},
    [8927]={g={22106,1,22110,1}},
    [8931]={g={22010,1,22015,1}},
    [8932]={g={22062,1,22066,1}},
    [8933]={g={22086,1,22090,1}},
    [8934]={g={22078,1,22081,1}},
    [8935]={g={22002,1,22006,1}},
    [8936]={g={22070,1,22077,1}},
    [8937]={g={21994,1,21998,1}},
    [8938]={g={22010,1,22015,1}},
    [8939]={g={22062,1,22066,1}},
    [8940]={g={22078,1,22081,1}},
    [8941]={g={22006,1,22002,1}},
    [8942]={g={22098,1,22099,1}},
    [8943]={g={22070,1,22077,1}},
    [8944]={g={21994,1,21998,1}},
    [8945]={g={22137,1}},
    [8949]={c={22150,1,22149,1}},
    [8951]={g={22107,1,22111,1,22112,1}},
    [8952]={g={22061,1,22017,1,22016,1}},
    [8953]={g={22064,1,22067,1,22068,1}},
    [8954]={g={22087,1,22092,1,22093,1}},
    [8955]={g={22084,1,22085,1,22082,1}},
    [8956]={g={22003,1,22007,1,22008,1}},
    [8957]={g={22096,1,22100,1,22101,1}},
    [8958]={g={22076,1,22072,1,22073,1}},
    [8959]={g={21995,1,22000,1,22001,1}},
    [8985]={c={22192,3,22193,3}},
    [8986]={c={22192,3,22193,3}},
    [8987]={c={22192,3,22193,3}},
    [8988]={c={22192,3,22193,3}},
    [9016]={g={22107,1,22111,1,22112,1}},
    [9017]={g={22061,1,22017,1,22016,1}},
    [9018]={g={22064,1,22067,1,22068,1}},
    [9019]={g={22084,1,22085,1,22082,1}},
    [9020]={g={22003,1,22007,1,22008,1}},
    [9021]={g={22076,1,22072,1,22073,1}},
    [9022]={g={21995,1,22000,1,22001,1}},
    [95264]={c={279833,1,279831,1,279474,1}},
    [95483]={c={279831,1,279833,1,279474,1}},
    [95790]={c={279931,1,279901,1}},
    [95924]={c={279903,1,279905,1}},
    [95925]={c={279908,1,279910,1,279912,1}},
    [95926]={c={279908,1,279910,1,279912,1}},
    [95928]={c={279904,1,279906,1}},
    [96332]={c={279824,1,279826,1,279829,1}},
    [96334]={c={279448,1,279473,1}},
    [96337]={g={274041,1}},
    [96376]={g={279450,1}},
    [96377]={g={279450,1}},
    [96381]={c={279825,1,279826,1,279829,1}},
    [97049]={c={279932,1,279902,1}},
}
-- [item] = {name ru, name en, quality, icon}: said until the game tells its own
P.RewardItems = {
    [918]={"\208\161\209\131\208\188\208\176 \208\184\208\183 \208\184\209\129\208\186\208\176\208\182\208\181\208\189\208\189\208\190\208\185 \209\136\208\186\209\131\209\128\209\139","Deviate Hide Pack",1,"inv_misc_bag_07_black"},
    [1264]={"\208\147\208\190\208\187\208\190\208\178\208\190\208\186\209\128\209\131\209\136\208\184\209\130\208\181\208\187\209\140","Headbasher",2,"inv_mace_07"},
    [1317]={"\208\163\208\191\209\128\208\190\209\135\208\189\208\181\208\189\208\189\209\139\208\185 \208\191\208\190\209\129\208\190\209\133 \208\184\208\183 \208\186\208\190\209\128\208\189\209\143","Hardened Root Staff",2,"inv_staff_16"},
    [1490]={"\208\162\208\176\208\187\208\184\209\129\208\188\208\176\208\189-\209\133\209\128\208\176\208\189\208\184\209\130\208\181\208\187\209\140","Guardian Talisman",2,"inv_jewelry_talisman_05"},
    [1529]={"\208\157\208\181\209\132\209\128\208\184\209\130","Jade",2,"inv_misc_gem_stone_01"},
    [1893]={"\208\156\208\181\209\129\209\130\209\140 \208\179\208\190\209\128\208\189\209\143\208\186\208\176","Miner's Revenge",2,"inv_pick_03"},
    [2033]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\191\208\190\209\129\208\187\208\176","Ambassador's Boots",2,"inv_boots_08"},
    [2036]={"\208\159\209\139\208\187\209\140\208\189\209\139\208\181 \209\136\208\176\209\133\209\130\208\181\209\128\209\129\208\186\208\184\208\181 \208\191\208\181\209\128\209\135\208\176\209\130\208\186\208\184","Dusty Mining Gloves",2,"inv_gauntlets_05"},
    [2037]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\191\209\128\208\190\209\133\208\190\208\180\209\135\208\184\208\186\208\176","Tunneler's Boots",2,"inv_boots_01"},
    [2041]={"\208\156\209\131\208\189\208\180\208\184\209\128 \208\151\208\176\208\191\208\176\208\180\208\189\208\190\208\179\208\190 \208\154\209\128\208\176\209\143","Tunic of Westfall",3,"inv_chest_leather_07"},
    [2042]={"\208\159\208\190\209\129\208\190\209\133 \208\151\208\176\208\191\208\176\208\180\208\189\208\190\208\179\208\190 \208\154\209\128\208\176\209\143","Staff of Westfall",3,"inv_staff_10"},
    [2074]={"\208\162\208\178\208\181\209\128\208\180\209\139\208\185 \208\186\208\187\208\184\208\189\208\190\208\186","Solid Shortblade",2,"inv_sword_23"},
    [2089]={"\208\160\208\181\208\183\208\189\208\190\208\185 \208\186\208\184\208\189\208\182\208\176\208\187","Scrimshaw Dagger",2,"inv_weapon_shortblade_01"},
    [2776]={"\208\151\208\190\208\187\208\190\209\130\208\176\209\143 \209\128\209\131\208\180\208\176","Gold Ore",2,"inv_ore_copper_01"},
    [2906]={"\208\154\208\190\208\187\209\140\209\135\209\131\208\182\208\189\209\139\208\181 \208\191\208\190\208\189\208\190\208\182\208\184 \208\162\208\181\208\188\208\189\208\190\208\187\208\181\209\129\209\140\209\143","Darkshire Mail Leggings",2,"inv_pants_03"},
    [3041]={"\208\156\209\131\209\136\208\186\208\181\209\130\208\190\208\189 \34\208\147\208\187\208\176\208\183 \208\188\208\176\208\179\208\176\34","\"Mage-Eye\" Blunderbuss",2,"inv_weapon_rifle_05"},
    [3324]={"\208\159\209\128\208\184\208\183\209\128\208\176\209\135\208\189\208\190\208\181 \208\190\208\191\208\187\208\181\209\135\209\140\208\181","Ghostly Mantle",2,"inv_shoulder_09"},
    [3400]={"\208\148\208\187\208\184\208\189\208\189\209\139\208\185 \208\188\208\181\209\135 \208\155\209\142\209\134\208\184\208\189\208\176","Lucine Longsword",2,"inv_sword_20"},
    [3562]={"\208\159\208\190\209\143\209\129 \208\158\208\191\208\190\209\128\209\139","Belt of Vindication",2,"inv_belt_05"},
    [3928]={"\208\157\208\176\208\184\208\187\209\131\209\135\209\136\208\181\208\181 \208\187\208\181\209\135\208\181\208\177\208\189\208\190\208\181 \208\183\208\181\208\187\209\140\208\181","Superior Healing Potion",1,"inv_potion_53"},
    [4197]={"\208\145\208\181\209\128\208\184\208\187\208\187\208\190\208\178\208\190\208\181 \208\190\208\191\208\187\208\181\209\135\209\140\208\181","Berylline Pads",3,"inv_shoulder_05"},
    [4534]={"\208\157\208\176\209\128\209\131\209\135\208\184 \209\129\208\190 \209\129\209\130\208\176\208\187\209\140\208\189\209\139\208\188\208\184 \208\183\208\176\209\129\209\130\208\181\208\182\208\186\208\176\208\188\208\184","Steel-clasped Bracers",2,"inv_bracer_06"},
    [4643]={"\208\157\208\176\208\186\208\184\208\180\208\186\208\176 \208\157\208\181\209\131\208\188\208\190\208\187\208\184\208\188\208\190\208\185 \209\129\209\130\208\176\208\187\208\184","Grimsteel Cape",2,"inv_misc_cape_02"},
    [4746]={"\208\158\208\180\208\181\209\143\208\189\208\184\208\181 \208\146\208\181\209\129\209\130\208\189\208\184\208\186\208\176 \209\128\208\190\208\186\208\176","Doomsayer's Robe",2,"inv_chest_cloth_19"},
    [4980]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\179\208\181\208\190\208\187\208\190\208\179\208\176","Prospector Gloves",2,"inv_gauntlets_04"},
    [4982]={"\208\148\209\128\208\176\208\189\209\139\208\185 \208\191\208\190\209\143\209\129 \208\179\208\181\208\190\208\187\208\190\208\179\208\176","Ripped Prospector Belt",0,"inv_belt_06"},
    [4983]={"\208\154\208\176\208\188\208\181\208\189\208\189\209\139\208\185 \209\128\208\176\209\129\208\191\209\139\208\187\208\184\209\130\208\181\208\187\209\140","Rock Pulverizer",2,"inv_hammer_17"},
    [4987]={"\208\156\208\181\209\135 \208\180\208\178\208\190\209\128\209\132\208\184\208\185\209\129\208\186\208\190\208\179\208\190 \208\186\208\176\208\191\208\184\209\130\208\176\208\189\208\176","Dwarf Captain's Sword",2,"inv_sword_25"},
    [5342]={"\208\159\209\131\208\189\209\136 \208\175\209\137\208\181\209\128\208\176","Raptor Punch",1,"inv_drink_04"},
    [5343]={"\208\159\208\187\208\176\209\137 \208\177\208\176\209\128\208\188\208\181\208\189\208\176","Barkeeper's Cloak",2,"inv_misc_cape_03"},
    [6087]={"\208\168\208\190\209\129\209\129\209\139 \208\151\208\176\208\191\208\176\208\180\208\189\208\190\208\179\208\190 \208\154\209\128\208\176\209\143","Chausses of Westfall",3,"inv_pants_03"},
    [6094]={"\208\159\209\128\208\190\208\189\208\183\208\176\209\142\209\137\208\184\208\185 \209\130\208\190\208\191\208\190\209\128","Piercing Axe",2,"inv_throwingaxe_01"},
    [6149]={"\208\161\208\184\208\187\209\140\208\189\208\190\208\181 \208\183\208\181\208\187\209\140\208\181 \208\188\208\176\208\189\209\139","Greater Mana Potion",1,"inv_potion_73"},
    [6335]={"\208\161\208\181\209\128\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Grizzled Boots",2,"inv_boots_03"},
    [6414]={"\208\159\208\181\209\135\208\176\209\130\209\140 \208\161\208\184\208\187\209\140\208\178\208\176\208\189\209\139","Seal of Sylvanas",3,"inv_jewelry_ring_15"},
    [6476]={"\208\146\209\139\208\186\209\128\208\190\208\185\208\186\208\176: \208\191\208\190\209\143\209\129 \208\184\208\183 \208\184\209\129\208\186\208\176\208\182\208\181\208\189\208\189\208\190\208\185 \209\135\208\181\209\136\209\131\208\184","Pattern: Deviate Scale Belt",2,"inv_scroll_06"},
    [6480]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\184\208\183 \208\184\209\129\208\186\208\176\208\182\208\181\208\189\208\189\208\190\208\185 \209\135\208\181\209\136\209\131\208\184","Slick Deviate Leggings",2,"inv_pants_02"},
    [6481]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\147\209\128\209\143\208\183\208\189\208\190\209\130\208\190\208\191\208\184","Dagmire Gauntlets",2,"inv_gauntlets_05"},
    [6504]={"\208\154\209\128\209\139\208\187\208\190-\208\186\208\187\208\184\208\189\208\190\208\186","Wingblade",3,"inv_sword_16"},
    [6505]={"\208\159\208\190\209\129\208\190\209\133 \208\159\208\190\208\187\209\131\208\188\208\181\209\129\209\143\209\134\208\176","Crescent Staff",3,"inv_staff_04"},
    [6723]={"\208\156\208\181\208\180\208\176\208\187\209\140 \208\183\208\176 \208\190\209\130\208\178\208\176\208\179\209\131","Medal of Courage",2,"inv_jewelry_amulet_03"},
    [6725]={"\208\163\208\186\209\128\208\176\209\136\208\181\208\189\208\189\209\139\208\185 \208\188\209\128\208\176\208\188\208\190\209\128\208\190\208\188 \208\186\209\131\208\187\208\176\209\135\208\189\209\139\208\185 \209\137\208\184\209\130","Marbled Buckler",3,"inv_shield_10"},
    [6742]={"\208\160\208\181\208\188\208\181\208\189\209\140 \208\154\208\176\208\188\208\181\208\189\208\189\208\190\208\179\208\190 \208\154\209\131\208\187\208\176\208\186\208\176","Stonefist Girdle",3,"inv_belt_35"},
    [6743]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\178\208\190\208\190\208\180\209\131\209\136\208\181\208\178\208\187\208\181\208\189\208\184\209\143","Sustaining Ring",2,"inv_jewelry_ring_08"},
    [6748]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\158\208\177\208\181\208\183\209\140\209\143\208\189\209\139","Monkey Ring",2,"inv_jewelry_ring_14"},
    [6749]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\162\208\184\208\179\209\128\208\176","Tiger Band",2,"inv_jewelry_ring_13"},
    [6750]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\151\208\188\208\181\208\184","Snake Hoop",2,"inv_jewelry_ring_06"},
    [6751]={"\208\162\209\128\208\176\209\131\209\128\208\189\208\176\209\143 \209\136\208\176\208\187\209\140","Mourning Shawl",2,"inv_misc_cape_11"},
    [6752]={"\208\163\208\187\208\176\208\189\209\129\208\186\208\184\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Lancer Boots",2,"inv_boots_03"},
    [6755]={"\208\156\208\176\208\187\208\181\208\189\209\140\208\186\208\176\209\143 \209\136\208\186\208\176\209\130\209\131\208\187\208\186\208\176 \209\129 \209\129\208\176\208\188\208\190\209\134\208\178\208\181\209\130\208\176\208\188\208\184","A Small Container of Gems",1,"inv_misc_ornatebox"},
    [6802]={"\208\156\208\181\209\135 \208\158\208\188\208\181\208\189\208\176","Sword of Omen",3,"inv_sword_19"},
    [6803]={"\208\159\209\128\208\190\209\128\208\190\209\135\208\181\209\129\208\186\208\176\209\143 \208\191\208\176\208\187\208\186\208\176","Prophetic Cane",3,"inv_staff_01"},
    [6829]={"\208\156\208\181\209\135 \208\177\208\181\208\183\208\188\209\143\209\130\208\181\208\182\208\189\208\190\209\129\209\130\208\184","Sword of Serenity",3,"inv_sword_27"},
    [6830]={"\208\154\208\190\209\129\209\130\208\181\208\186\209\131\209\129","Bonebiter",3,"inv_axe_04"},
    [6831]={"\208\167\208\181\209\128\208\189\208\176\209\143 \209\131\208\179\209\128\208\190\208\183\208\176","Black Menace",3,"inv_sword_13"},
    [6998]={"\208\158\209\128\208\181\208\190\208\187\209\140\208\189\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Nimbus Boots",2,"inv_boots_05"},
    [7000]={"\208\160\208\181\208\188\208\181\208\189\209\140 \208\161\208\181\209\128\208\180\209\134\208\176 \208\148\209\128\208\181\208\178\208\176","Heartwood Girdle",2,"inv_belt_04"},
    [7001]={"\208\157\208\176\208\180\208\179\209\128\208\190\208\177\208\189\209\139\208\185 \209\129\208\186\208\184\208\191\208\181\209\130\209\128","Gravestone Scepter",3,"inv_wand_04"},
    [7002]={"\208\144\209\128\208\186\209\130\208\184\209\135\208\181\209\129\208\186\208\184\208\185 \208\186\209\131\208\187\208\176\209\135\208\189\209\139\208\185 \209\137\208\184\209\130","Arctic Buckler",3,"inv_shield_02"},
    [7003]={"\208\150\209\131\209\135\208\184\208\189\209\139\208\181 \208\183\208\176\209\129\209\130\208\181\208\182\208\186\208\184","Beetle Clasps",2,"inv_bracer_06"},
    [7004]={"\208\157\208\176\208\186\208\184\208\180\208\186\208\176 \208\191\209\128\208\181\208\187\208\176\209\130\208\176","Prelacy Cape",2,"inv_misc_cape_18"},
    [7606]={"\208\161\208\189\208\181\208\182\208\189\209\139\208\181 \209\128\209\131\208\186\208\176\208\178\208\184\209\134\209\139","Polar Gauntlets",2,"inv_gauntlets_04"},
    [7607]={"\208\161\208\190\208\177\208\190\208\187\208\184\208\185 \208\182\208\181\208\183\208\187","Sable Wand",2,"inv_staff_02"},
    [7673]={"\208\158\208\182\208\181\209\128\208\181\208\187\209\140\208\181 \208\163\209\129\208\184\208\187\208\181\208\189\208\184\209\143 \208\162\208\176\208\187\208\178\208\176\209\136","Talvash's Enhancing Necklace",3,"inv_jewelry_necklace_02"},
    [7746]={"\208\144\208\188\209\131\208\187\208\181\209\130 \208\155\208\184\208\179\208\184 \208\152\209\129\209\129\208\187\208\181\208\180\208\190\208\178\208\176\209\130\208\181\208\187\208\181\208\185","Explorers' League Commendation",2,"inv_jewelry_talisman_01"},
    [7747]={"\208\159\208\190\208\179\208\184\208\177\208\181\208\187\209\140\208\189\208\176\209\143 \208\183\208\176\209\137\208\184\209\130\208\176","Vile Protector",2,"inv_shield_02"},
    [7749]={"\208\161\209\132\208\181\209\128\208\176 \208\158\208\188\208\181\208\179\208\184","Omega Orb",2,"inv_misc_orb_03"},
    [7750]={"\208\158\208\191\208\187\208\181\209\135\209\140\208\181 \208\179\208\190\209\128\209\143","Mantle of Woe",2,"inv_shoulder_23"},
    [7751]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\146\208\190\209\128\209\128\208\181\208\187\208\176","Vorrel's Boots",2,"inv_boots_03"},
    [7888]={"\208\158\208\182\208\181\209\128\208\181\208\187\209\140\208\181 \208\163\209\129\208\184\208\187\208\181\208\189\208\184\209\143 \208\148\208\182\208\176\209\128\208\186\208\176\208\187\208\176","Jarkal's Enhancing Necklace",3,"inv_jewelry_necklace_02"},
    [8071]={"\208\168\208\184\208\191\209\143\209\137\208\181\208\181 \208\180\209\128\208\181\208\178\208\186\208\190","Sizzle Stick",2,"inv_staff_02"},
    [9030]={"\208\159\209\128\208\184\208\178\208\190\208\180\209\143\209\137\208\181\208\181 \208\178 \209\129\208\190\208\183\208\189\208\176\208\189\208\184\208\181 \208\183\208\181\208\187\209\140\208\181","Restorative Potion",1,"inv_potion_01"},
    [9173]={"\208\147\208\190\208\177\208\187\208\184\208\189\209\129\208\186\208\184\208\185 \208\184\208\188\208\191\209\131\208\187\209\140\209\129\208\189\209\139\208\185 \208\191\208\190\208\178\209\130\208\190\209\128\208\184\209\130\208\181\208\187\209\140","Goblin Transponder",1,"inv_battery_01"},
    [9224]={"\208\173\208\187\208\184\208\186\209\129\208\184\209\128 \209\131\208\177\208\184\208\185\209\129\209\130\208\178\208\176 \208\180\208\181\208\188\208\190\208\189\208\190\208\178","Elixir of Demonslaying",1,"inv_potion_27"},
    [9363]={"\208\154\208\190\209\128\208\190\208\177\208\186\208\176, \209\131\208\191\208\176\208\186\208\190\208\178\208\176\208\189\208\189\208\176\209\143 \34\208\167\208\184\209\129\209\130\208\181\209\128\208\190\208\188\34","Sparklematic-Wrapped Box",1,"inv_misc_gift_01"},
    [9522]={"\208\173\208\189\208\181\209\128\208\179\208\181\209\130\208\184\209\135\208\181\209\129\208\186\208\184\208\185 \208\186\208\176\208\188\208\181\208\189\208\189\209\139\208\185 \208\190\208\177\209\128\209\131\209\135","Energized Stone Circle",2,"inv_shield_10"},
    [9527]={"\208\150\208\181\208\183\208\187 \208\161\208\188\208\181\208\189\209\139 \208\183\208\176\208\186\208\187\209\143\209\130\208\184\208\185","Spellshifter Rod",2,"inv_wand_11"},
    [9531]={"\208\157\208\176\208\191\208\187\208\181\209\135\209\140\208\181 \208\148\209\128\208\176\208\179\208\190\209\134\208\181\208\189\208\189\208\190\208\185 \209\129\208\186\208\190\209\128\208\187\209\131\208\191\209\139","Gemshale Pauldrons",2,"inv_shoulder_23"},
    [9533]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\156\208\176\209\129\208\190\208\189\209\129\208\186\208\190\208\179\208\190 \208\177\209\128\208\176\209\130\209\129\209\130\208\178\208\176","Masons Fraternity Ring",3,"inv_jewelry_ring_03"},
    [9534]={"\208\147\208\190\208\187\208\190\208\178\208\189\208\190\208\185 \209\131\208\177\208\190\209\128 \208\147\208\184\208\187\209\140\208\180\208\184\208\185","Engineer's Guild Headpiece",3,"inv_helmet_33"},
    [9535]={"\208\158\208\179\208\189\208\181\209\129\208\178\208\176\209\128\208\189\209\139\208\181 \208\189\208\176\209\128\209\131\209\135\208\184","Fire-welded Bracers",2,"inv_bracer_02"},
    [9536]={"\208\146\208\190\208\187\209\136\208\181\208\177\208\189\208\190\208\186\209\128\209\139\208\187\208\190\208\181 \208\190\208\191\208\187\208\181\209\135\209\140\208\181","Fairywing Mantle",2,"inv_shoulder_02"},
    [9587]={"\208\161\209\131\208\188\208\176 \208\184\208\183 \208\188\209\143\208\179\208\186\208\190\208\185 \208\186\208\190\208\182\208\184","Thawpelt Sack",1,"inv_misc_bag_17"},
    [9604]={"\208\162\209\128\209\131\208\177\208\190\208\188\208\190\208\187\208\190\209\130 \208\188\208\176\209\133\208\189\208\184\208\186\208\176","Mechanic's Pipehammer",2,"inv_mace_04"},
    [9605]={"\208\157\208\176\208\186\208\184\208\180\208\186\208\176 \209\128\208\181\208\188\208\190\208\189\209\130\208\189\208\184\208\186\208\176","Repairman's Cape",2,"inv_misc_cape_06"},
    [9608]={"\208\158\208\177\208\181\208\183\208\190\209\128\209\131\208\182\208\184\208\178\208\176\209\142\209\137\208\184\208\185 \208\184\208\189\209\129\209\130\209\128\209\131\208\188\208\181\208\189\209\130 \208\168\208\190\208\189\208\184","Shoni's Disarming Tool",2,"inv_misc_wrench_01"},
    [9609]={"\208\159\208\190\208\187\209\131\208\191\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\157\208\181\209\128\208\181\209\136\208\184\209\130\208\181\208\187\209\140\208\189\208\190\209\129\209\130\208\184","Shilly Mitts",2,"inv_gauntlets_27"},
    [9623]={"\208\158\208\180\208\181\209\143\208\189\208\184\209\143 \208\161\208\184\208\178\208\184\208\189\208\176\208\180\208\176","Civinad Robes",3,"inv_chest_cloth_18"},
    [9624]={"\208\168\208\176\209\128\208\190\208\178\208\176\209\128\209\139 \208\177\208\181\208\179\209\131\208\189\208\176","Triprunner Dungarees",3,"inv_pants_08"},
    [9625]={"\208\148\208\178\208\190\208\185\208\189\209\139\208\181 \209\131\209\129\208\184\208\187\208\181\208\189\208\189\209\139\208\181 \208\191\208\190\208\189\208\190\208\182\208\184","Dual Reinforced Leggings",3,"inv_pants_03"},
    [9626]={"\208\148\208\178\208\190\209\128\209\132\208\184\208\185\209\129\208\186\208\184\208\185 \208\189\208\176\209\130\208\184\209\129\208\186","Dwarven Charge",2,"inv_axe_09"},
    [9627]={"\208\159\209\131\209\130\208\181\208\178\208\190\208\180\208\189\208\176\209\143 \208\183\208\178\208\181\208\183\208\180\208\176 \208\155\208\184\208\179\208\184 \208\184\209\129\209\129\208\187\208\181\208\180\208\190\208\178\208\176\209\130\208\181\208\187\208\181\208\185","Explorer's League Lodestar",2,"inv_misc_lantern_01"},
    [10358]={"\208\148\209\142\209\128\208\176\209\134\208\184\208\189\208\190\208\178\209\139\208\181 \208\189\208\176\209\128\209\131\209\135\208\184","Duracin Bracers",2,"inv_bracer_04"},
    [10359]={"\208\148\208\190\208\187\208\179\208\190\208\178\208\181\209\135\208\189\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Everlast Boots",2,"inv_boots_07"},
    [10455]={"\208\161\208\186\208\190\208\178\208\176\208\189\208\189\208\176\209\143 \208\161\209\131\209\137\208\189\208\190\209\129\209\130\209\140 \208\173\209\128\208\176\208\189\208\184\208\186\209\131\209\129\208\176","Chained Essence of Eranikus",2,"inv_stone_03"},
    [10515]={"\208\164\208\176\208\186\208\181\208\187 \208\146\208\190\208\183\208\180\208\176\209\143\208\189\208\184\209\143","Torch of Retribution",1,"inv_wand_04"},
    [10569]={"\208\161\208\190\208\186\209\128\208\190\208\178\208\184\209\137\208\189\208\184\209\134\208\176 \209\135\208\181\209\128\208\189\209\139\209\133 \208\180\209\128\208\176\208\186\208\190\208\189\208\190\208\178","Hoard of the Black Dragonflight",1,"inv_box_02"},
    [10710]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\148\209\128\208\176\208\186\208\190\208\189\209\140\208\181\208\179\208\190 \208\186\208\190\208\179\209\130\209\143","Dragonclaw Ring",3,"inv_jewelry_ring_04"},
    [10711]={"\208\158\208\182\208\181\209\128\208\181\208\187\209\140\208\181 \208\148\209\128\208\176\208\186\208\190\208\189\209\140\208\181\208\185 \208\154\209\128\208\190\208\178\208\184","Dragon's Blood Necklace",3,"inv_jewelry_necklace_02"},
    [10742]={"\208\148\209\128\208\176\208\186\208\190\208\189\209\140\208\184 \208\191\208\190\208\189\208\190\208\182\208\184","Dragonflight Leggings",2,"inv_pants_05"},
    [10743]={"\208\168\208\187\208\181\208\188 \208\159\208\187\208\176\208\188\208\181\208\189\208\184 \208\180\209\128\208\176\208\186\208\190\208\189\208\176","Drakefire Headguard",2,"inv_helmet_17"},
    [10744]={"\208\162\208\190\208\191\208\190\209\128 \208\173\208\177\208\181\208\189\208\190\208\178\208\190\208\179\208\190 \208\180\209\128\208\176\208\186\208\190\208\189\208\176","Axe of the Ebon Drake",2,"inv_axe_12"},
    [10749]={"\208\168\208\187\208\181\208\188 \208\144\208\178\208\176\208\189\208\179\208\176\209\128\208\180\208\176","Avenguard Helm",3,"inv_helmet_22"},
    [10750]={"\208\154\208\190\209\128\209\130\208\184\208\186 \208\150\208\184\208\183\208\189\208\181\209\129\208\184\208\187\209\139","Lifeforce Dirk",3,"inv_sword_21"},
    [10751]={"\208\148\209\128\208\176\208\179\208\190\209\134\208\181\208\189\208\189\209\139\208\185 \208\178\208\181\208\189\208\181\209\134","Gemburst Circlet",3,"inv_crown_01"},
    [10773]={"\208\163\209\128\208\189\208\176 \208\165\208\176\208\186\208\186\208\176\209\128\208\184","Hakkari Urn",2,"inv_box_01"},
    [10823]={"\208\156\208\181\209\135 \208\159\208\190\208\186\208\190\209\128\208\184\209\130\208\181\208\187\209\143","Vanquisher's Sword",3,"inv_sword_35"},
    [10824]={"\208\162\208\176\208\187\208\184\209\129\208\188\208\176\208\189 \208\175\208\189\209\130\208\176\209\128\208\189\208\190\208\179\208\190 \209\129\208\178\208\181\209\130\208\176","Amberglow Talisman",3,"inv_jewelry_necklace_07"},
    [10919]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\176\208\191\209\130\208\181\208\186\208\176\209\128\209\143","Apothecary Gloves",2,"inv_gauntlets_06"},
    [11000]={"\208\154\208\187\209\142\209\135 \208\154\209\131\208\183\208\189\208\184 \208\162\208\181\208\189\208\181\208\185","Shadowforge Key",1,"inv_misc_key_08"},
    [11122]={"\208\156\208\190\209\128\208\186\208\190\208\178\208\186\208\176 \208\189\208\176 \208\191\208\176\208\187\208\190\209\135\208\186\208\181","Carrot on a Stick",2,"inv_misc_food_54"},
    [11123]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\161\209\130\209\128\208\176\208\189\208\189\208\184\208\186\208\176 \208\180\208\190\208\182\208\180\209\143","Rainstrider Leggings",3,"inv_pants_08"},
    [11124]={"\208\168\208\187\208\181\208\188 \208\152\208\183\208\179\208\189\208\176\208\189\208\184\209\143","Helm of Exile",3,"inv_helmet_21"},
    [11262]={"\208\161\209\132\208\181\209\128\208\176 \208\155\208\190\209\128\208\184\208\186\208\184","Orb of Lorica",3,"inv_misc_orb_01"},
    [11865]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\158\208\183\208\187\208\190\208\177\208\187\208\181\208\189\208\184\209\143","Rancor Boots",2,"inv_boots_02"},
    [11866]={"\208\159\208\190\209\143\209\129-\209\133\208\187\209\139\209\129\209\130 \208\157\208\176\208\179\208\188\208\176\209\128\209\139","Nagmara's Whipping Belt",3,"inv_belt_11"},
    [11883]={"\208\151\208\176\208\186\208\190\208\191\209\135\208\181\208\189\208\189\208\176\209\143 \209\129\209\131\208\188\208\176-\208\182\208\181\209\129\209\130\209\143\208\189\208\186\208\176","A Dingy Fanny Pack",1,"inv_misc_bag_09_black"},
    [11962]={"\208\154\208\176\208\189\208\180\208\176\208\187\209\139","Manacle Cuffs",3,"inv_bracer_13"},
    [11963]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\186\208\176\209\128\209\139","Penance Spaulders",2,"inv_shoulder_25"},
    [11964]={"\208\159\208\176\208\187\208\186\208\176 \208\188\208\190\208\187\208\189\208\184\208\181\208\189\208\190\209\129\208\189\208\190\208\179\208\190 \209\131\208\180\208\176\209\128\208\176","Swiftstrike Cudgel",2,"inv_mace_08"},
    [12000]={"\208\154\208\190\208\187\209\131\208\189 \208\186\208\190\208\189\208\181\209\135\208\189\208\190\209\129\209\130\208\181\208\185","Limb Cleaver",2,"inv_axe_02"},
    [12003]={"\208\162\208\181\208\188\208\189\208\190\208\181 \208\180\208\178\208\190\209\128\209\132\208\184\208\185\209\129\208\186\208\190\208\181 \208\191\208\184\208\178\208\190","Dark Dwarven Lager",1,"inv_drink_05"},
    [12018]={"\208\168\208\187\208\181\208\188 \208\158\209\133\209\128\208\176\208\189\208\184\209\130\208\181\208\187\209\143","Conservator Helm",2,"inv_helmet_01"},
    [12021]={"\208\169\208\184\209\130\208\190\208\187\208\176\209\130\208\189\209\139\208\181 \208\177\208\176\209\136\208\188\208\176\208\186\208\184","Shieldplate Sabatons",2,"inv_boots_plate_01"},
    [12038]={"\208\159\208\181\209\135\208\176\209\130\209\140 \208\155\208\176\208\179\209\128\208\176\208\178\208\176","Lagrave's Seal",2,"inv_jewelry_ring_03"},
    [12041]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\146\208\181\209\130\209\128\208\190\209\128\208\181\208\183\208\190\208\178","Windshear Leggings",2,"inv_pants_13"},
    [12049]={"\208\161\209\130\208\176\208\187\209\140\208\189\208\190\208\190\209\129\208\186\208\190\208\187\208\190\209\135\208\189\208\176\209\143 \208\177\209\128\208\190\208\189\209\143","Splintsteel Armor",2,"inv_chest_chain_16"},
    [12059]={"\208\156\208\181\208\180\208\176\208\187\209\140\208\190\208\189 \208\151\208\176\208\178\208\190\208\181\208\178\208\176\209\130\208\181\208\187\209\143","Conqueror's Medallion",3,"inv_jewelry_amulet_03"},
    [12061]={"\208\154\208\187\208\184\208\189\208\190\208\186 \208\160\208\176\209\129\209\135\208\181\209\130\208\190\208\178","Blade of Reckoning",2,"inv_sword_26"},
    [12062]={"\208\154\208\178\208\176\208\187\208\184\209\132\208\184\209\134\208\184\209\128\208\190\208\178\208\176\208\189\208\189\209\139\208\185 \208\177\208\190\208\181\208\178\208\190\208\185 \208\186\208\187\208\184\208\189\208\190\208\186","Skilled Fighting Blade",2,"inv_sword_21"},
    [12065]={"\208\158\208\177\208\181\209\128\208\181\208\179 \208\161\209\130\208\184\209\133\208\184\208\185","Ward of the Elements",2,"inv_jewelry_talisman_02"},
    [12066]={"\208\157\208\176\208\186\208\184\208\180\208\186\208\176 \208\147\208\187\208\184\208\189\208\184\209\129\209\130\208\190\208\185 \208\186\208\190\208\182\208\184","Shaleskin Cape",2,"inv_misc_cape_02"},
    [12082]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\184\208\183 \209\136\208\186\209\131\209\128\209\139 \208\183\208\188\208\181\209\143","Wyrmhide Spaulders",2,"inv_shoulder_16"},
    [12083]={"\208\146\208\176\208\187\209\140\208\186\208\190\208\189\208\184\208\185\209\129\208\186\208\184\208\185 \208\186\209\131\209\136\208\176\208\186","Valconian Sash",2,"inv_belt_11"},
    [12102]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\144\209\128\208\184\209\129\209\130\208\190\208\186\209\128\208\176\209\130\208\176","Ring of the Aristocrat",2,"inv_jewelry_ring_15"},
    [12108]={"\208\145\208\176\208\183\208\176\208\187\209\140\209\130\208\190\208\178\208\176\209\143 \209\135\208\181\209\136\209\131\208\185\209\135\208\176\209\130\208\176\209\143 \208\177\209\128\208\190\208\189\209\143","Basaltscale Armor",2,"inv_chest_chain_16"},
    [12109]={"\208\155\208\176\208\183\209\131\209\128\208\189\209\139\208\185 \208\187\209\131\208\189\208\189\209\139\208\185 \208\189\208\176\209\128\208\176\208\188\208\189\208\184\208\186","Azure Moon Amice",2,"inv_shoulder_02"},
    [12110]={"\208\159\208\181\208\187\208\181\209\128\208\184\208\189\208\176 \208\151\208\176\208\186\208\187\208\184\208\189\208\176\209\130\208\181\208\187\209\143 \208\148\208\190\208\182\208\180\209\143","Raincaster Drape",2,"inv_misc_cape_16"},
    [12111]={"\208\155\208\176\208\178\208\190\208\178\209\139\208\181 \209\128\209\131\208\186\208\176\208\178\208\184\209\134\209\139","Lavaplate Gauntlets",2,"inv_gauntlets_26"},
    [12112]={"\208\157\208\176\209\128\209\131\209\135\208\184 \209\129\208\186\208\187\208\181\208\191\208\189\208\190\208\179\208\190 \208\180\208\181\208\188\208\190\208\189\208\176","Crypt Demon Bracers",2,"inv_bracer_17"},
    [12113]={"\208\161\208\190\208\187\208\189\208\181\209\135\208\189\208\176\209\143 \208\189\208\176\208\186\208\184\208\180\208\186\208\176","Sunborne Cape",2,"inv_misc_cape_08"},
    [12114]={"\208\161\209\131\208\188\209\128\208\176\209\135\208\189\209\139\208\181 \208\191\208\181\209\128\209\135\208\176\209\130\208\186\208\184","Nightfall Gloves",2,"inv_gauntlets_17"},
    [12115]={"\208\161\209\130\208\190\208\185\208\186\208\184\208\185 \208\191\208\190\209\143\209\129\208\190\208\186","Stalwart Clutch",2,"inv_belt_34"},
    [12144]={"\208\175\208\185\209\134\208\181\209\133\208\187\208\176\208\180\208\190\209\129\208\186\208\190\208\191","Eggscilloscope",1,"inv_gizmo_09"},
    [12264]={"\208\159\208\181\209\128\208\181\208\189\208\190\209\129\208\186\208\176 \208\180\208\187\209\143 \208\178\208\190\209\128\208\179\208\176","Worg Carrier",1,"inv_box_petcarrier_01"},
    [12344]={"\208\159\208\181\209\135\208\176\209\130\209\140 \208\146\208\190\208\183\208\189\208\181\209\129\208\181\208\189\208\184\209\143","Seal of Ascension",3,"inv_jewelry_ring_01"},
    [12529]={"\208\154\208\187\208\181\209\130\208\186\208\176 \208\158\208\179\208\189\208\181\208\191\208\176\209\131\209\130\208\184\208\189\208\186\208\184","Smolderweb Carrier",1,"inv_box_birdcage_01"},
    [12543]={"\208\159\208\190\209\142\209\137\208\184\208\185 \208\186\208\176\208\188\208\181\208\189\209\140 \208\161\209\130\208\176\208\187\209\140\208\179\208\190\209\128\208\189\208\176","Songstone of Ironforge",3,"inv_jewelry_ring_05"},
    [12544]={"\208\160\208\181\209\136\208\184\208\188\208\190\209\129\209\130\209\140 \208\162\209\128\208\176\208\187\208\187\208\176","Thrall's Resolve",3,"inv_jewelry_ring_05"},
    [12545]={"\208\158\208\186\208\190 \208\158\209\128\208\179\209\128\208\184\208\188\208\188\208\176\209\128\208\176","Eye of Orgrimmar",3,"inv_jewelry_ring_05"},
    [12548]={"\208\146\208\190\208\187\209\143 \208\156\208\176\208\179\208\189\208\184","Magni's Will",3,"inv_jewelry_ring_05"},
    [12696]={"\208\167\208\181\209\128\209\130\208\181\208\182: \208\178\209\139\208\186\208\190\208\178\208\176\208\189\208\189\208\176\209\143 \208\180\208\181\208\188\208\190\208\189\208\190\208\188 \208\186\208\184\209\128\208\176\209\129\208\176","Plans: Demon Forged Breastplate",3,"inv_scroll_03"},
    [12849]={"\208\161\209\131\208\188\208\186\208\176 \208\159\208\190\209\134\208\181\208\187\209\131\209\143 \208\180\208\181\208\188\208\190\208\189\208\176","Demon Kissed Sack",2,"inv_misc_bag_13"},
    [13171]={"\208\146\208\190\209\129\208\191\208\187\208\176\208\188\208\181\208\189\208\184\209\130\208\181\208\187\209\140 \208\148\209\139\208\188\208\186\208\176","Smokey's Lighter",2,"spell_fire_searingtotem"},
    [13209]={"\208\159\208\181\209\135\208\176\209\130\209\140 \208\160\208\176\209\129\209\129\208\178\208\181\209\130\208\176","Seal of the Dawn",3,"inv_misc_armorkit_18"},
    [13216]={"\208\154\208\190\209\128\208\190\208\189\208\176 \208\159\208\190\208\186\208\176\209\143\208\189\208\184\209\143","Crown of the Penitent",2,"inv_helmet_06"},
    [13217]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\159\208\190\208\186\208\176\209\143\208\189\208\184\209\143","Band of the Penitent",2,"inv_jewelry_ring_30"},
    [13315]={"\208\151\208\176\208\178\208\181\209\137\208\176\208\189\208\184\208\181 \208\189\208\176\208\180\208\181\208\182\208\180\209\139","Testament of Hope",2,"inv_misc_book_06"},
    [13544]={"\208\161\209\131\209\137\208\189\208\190\209\129\209\130\209\140 \208\191\209\128\208\184\208\178\208\184\208\180\208\181\208\189\208\184\209\143","Spectral Essence",2,"inv_misc_orb_05"},
    [13958]={"\208\158\208\186\208\190\208\178\209\139 \208\146\209\131\209\128\208\188\209\130\208\176\208\187\208\176\208\186\208\176","Wyrmthalak's Shackles",3,"inv_bracer_04"},
    [13959]={"\208\162\208\181\209\129\209\140\208\188\208\176-\209\132\208\184\208\186\209\129\208\176\209\130\208\190\209\128 \208\158\208\188\208\190\208\186\208\186\208\176","Omokk's Girth Restrainer",3,"inv_belt_13"},
    [13961]={"\208\157\208\176\208\188\208\190\209\128\208\180\208\189\208\184\208\186 \208\165\208\176\208\187\208\184\208\186\208\190\208\189","Halycon's Muzzle",3,"inv_shoulder_24"},
    [13962]={"\208\159\208\190\209\143\209\129 \208\146\208\190\209\129'\208\179\208\176\208\180\208\182\208\184\208\189","Vosh'gajin's Strand",3,"inv_belt_15"},
    [13963]={"\208\159\208\190\208\179\208\176\208\189\209\139\208\181 \208\183\208\176\209\133\208\178\208\176\209\130\209\139 \208\146\209\131\208\189\208\176","Voone's Vice Grips",3,"inv_gauntlets_15"},
    [13965]={"\208\159\208\187\208\176\209\129\209\130\208\184\209\130\208\176 \208\167\208\181\209\128\208\189\208\190\209\128\209\131\208\186\208\176","Blackhand's Breadth",3,"inv_misc_armorkit_09"},
    [13966]={"\208\151\208\189\208\176\208\186 \208\162\208\184\209\128\208\176\208\189\208\184\208\184","Mark of Tyranny",3,"inv_jewelry_talisman_09"},
    [13968]={"\208\147\208\187\208\176\208\183 \208\151\208\178\208\181\209\128\209\143","Eye of the Beast",3,"inv_jewelry_talisman_08"},
    [13982]={"\208\145\208\190\208\181\208\178\208\190\208\185 \208\186\208\187\208\184\208\189\208\190\208\186 \208\154\208\176\209\141\209\128 \208\148\208\176\209\128\209\128\208\190\209\131","Warblade of Caer Darrow",3,"inv_sword_39"},
    [13984]={"\208\159\208\184\208\186\208\176 \208\148\209\141\209\128\209\128\208\190\209\131","Darrowspike",3,"inv_weapon_shortblade_21"},
    [13986]={"\208\154\208\190\209\128\208\190\208\189\208\176 \208\154\208\176\209\141\209\128 \208\148\208\176\209\128\209\128\208\190\209\131","Crown of Caer Darrow",3,"inv_crown_01"},
    [14002]={"\208\161\208\184\208\187\209\140\208\189\208\190\209\129\209\130\209\128\208\176\208\182 \208\148\208\176\209\128\209\128\208\190\209\131\209\136\208\184\209\128\208\176","Darrowshire Strongguard",3,"inv_shield_05"},
    [15449]={"\208\156\208\181\209\128\209\130\208\178\208\181\208\189\208\189\209\139\208\181 \208\177\209\128\209\142\208\186\208\184","Ghastly Trousers",2,"inv_pants_14"},
    [15450]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\177\208\190\208\187\208\190\209\130\208\189\208\190\208\179\208\190 \209\135\208\181\209\128\208\191\208\176\209\130\208\181\208\187\209\143","Dredgemire Leggings",2,"inv_pants_07"},
    [15451]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\179\208\190\209\128\208\179\209\131\208\187\209\140\208\184","Gargoyle Leggings",2,"inv_pants_03"},
    [15452]={"\208\159\208\181\209\128\208\190\208\177\208\184\209\129\208\181\209\128\208\189\209\139\208\181 \208\189\208\176\209\128\209\131\209\135\208\184","Featherbead Bracers",2,"inv_bracer_08"},
    [15453]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\161\208\176\208\178\208\176\208\189\208\189\209\139","Savannah Bracers",2,"inv_bracer_07"},
    [15805]={"\208\160\208\190\208\183\208\176 \208\159\208\181\208\189\208\181\208\187\208\190\208\191\209\139","Penelope's Rose",3,"inv_misc_flower_04"},
    [15806]={"\208\159\208\181\209\129\208\189\209\143 \208\156\208\184\209\128\208\176\209\133\208\176","Mirah's Song",3,"inv_sword_34"},
    [15824]={"\208\144\209\129\209\130\208\190\209\128\208\184\208\185\209\129\208\186\208\184\208\181 \208\190\208\180\208\181\209\143\208\189\208\184\209\143","Astoria Robes",2,"inv_chest_cloth_07"},
    [15825]={"\208\151\208\178\208\181\209\128\208\190\208\187\208\190\208\178\208\181\209\134\208\186\208\184\208\185 \208\182\208\176\208\186\208\181\209\130","Traphook Jerkin",2,"inv_chest_plate06"},
    [15827]={"\208\154\208\184\209\128\208\176\209\129\208\176 \208\184\208\183 \208\189\208\181\209\132\209\128\208\184\209\130\208\190\208\178\208\190\208\185 \209\135\208\181\209\136\209\131\208\184","Jadescale Breastplate",2,"inv_chest_chain_04"},
    [15853]={"\208\146\208\181\209\130\209\128\208\190\208\182\208\189\208\181\209\134","Windreaper",3,"inv_axe_08"},
    [15854]={"\208\162\208\176\208\189\209\134\209\131\209\142\209\137\208\181\208\181 \209\129\208\181\209\128\208\181\208\177\209\128\208\190","Dancing Sliver",3,"inv_staff_07"},
    [15858]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\146\208\190\208\187\209\140\208\189\208\190\208\179\208\190 \208\178\208\181\209\130\209\128\208\176","Freewind Gloves",2,"inv_gauntlets_16"},
    [15859]={"\208\160\208\181\208\188\208\181\208\189\209\140 \208\188\208\190\209\128\209\129\208\186\208\190\208\185 \208\183\208\176\209\129\209\130\208\176\208\178\209\139","Seapost Girdle",2,"inv_belt_23"},
    [15860]={"\208\145\208\190\208\181\208\178\209\139\208\181 \208\189\208\176\209\128\209\131\209\135\208\184 \208\188\208\179\208\189\208\190\208\178\208\181\208\189\208\189\208\190\208\179\208\190 \209\131\208\180\208\176\209\128\208\176","Blinkstrike Armguards",2,"inv_bracer_17"},
    [15861]={"\208\145\209\139\209\129\209\130\209\128\208\190\209\129\209\130\209\131\208\191\208\189\209\139\208\181 \208\177\208\190\209\130\209\132\208\190\209\128\209\130\209\139","Swiftfoot Treads",2,"inv_boots_07"},
    [15862]={"\208\156\208\190\208\187\208\189\208\184\208\181\208\189\208\190\209\129\208\189\209\139\208\185 \208\186\208\190\208\187\209\131\208\189","Blitzcleaver",2,"inv_weapon_halberd_06"},
    [15863]={"\208\156\208\190\208\179\208\184\208\187\209\140\208\189\209\139\208\185 \209\129\208\186\208\184\208\191\208\181\209\130\209\128","Grave Scepter",2,"inv_mace_07"},
    [15867]={"\208\158\208\177\208\181\209\128\208\181\208\179-\208\191\209\128\208\184\208\183\208\188\208\176","Prismcharm",2,"inv_misc_gem_variety_02"},
    [15873]={"\208\157\208\181\209\131\208\191\208\184\208\178\208\176\208\181\208\188\208\176\209\143 \209\135\208\176\209\136\208\176 \208\148\208\182\208\190\208\189\208\176-\208\158\208\177\208\190\209\128\208\178\208\176\208\189\209\134\208\176","Ragged John's Neverending Cup",3,"inv_drink_03"},
    [16309]={"\208\144\208\188\209\131\208\187\208\181\209\130 \208\159\208\187\208\176\208\188\208\181\208\189\208\184 \208\180\209\128\208\176\208\186\208\190\208\189\208\176","Drakefire Amulet",3,"inv_jewelry_talisman_11"},
    [16886]={"\208\161\208\176\208\177\208\187\209\143 \208\177\208\181\208\183\208\183\208\176\208\186\208\190\208\189\208\189\208\184\208\186\208\176","Outlaw Sabre",3,"inv_sword_33"},
    [16887]={"\208\146\208\181\208\180\209\140\208\188\208\184\208\189 \208\191\208\176\208\187\208\181\209\134","Witch's Finger",3,"inv_wand_12"},
    [16994]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\162\208\181\208\189\208\181\208\186\209\128\209\139\208\187\208\176","Duskwing Gloves",2,"inv_gauntlets_02"},
    [16995]={"\208\162\208\181\208\189\208\181\208\186\209\128\209\139\208\187\209\139\208\181 \208\190\208\191\208\187\208\181\209\135\209\140\208\181","Duskwing Mantle",2,"inv_shoulder_19"},
    [17001]={"\208\158\208\177\209\128\209\131\209\135 \208\161\209\130\208\184\209\133\208\184\208\185","Elemental Circle",2,"inv_jewelry_ring_29"},
    [17002]={"\208\160\208\176\208\183\208\177\209\128\209\139\208\183\208\179\208\184\208\178\208\176\209\130\208\181\208\187\209\140 \208\187\208\184\208\188\209\132\209\139","Ichor Spitter",2,"inv_weapon_halberd_05"},
    [17003]={"\208\156\208\190\208\187\208\190\209\130 \208\154\208\176\208\188\208\181\208\189\208\189\208\190\208\179\208\190 \209\135\208\181\209\128\208\181\208\191\208\176","Skullstone Hammer",2,"inv_misc_bone_orcskull_01"},
    [17004]={"\208\160\209\131\208\186\208\190\208\178\208\190\208\180\209\129\209\130\208\178\208\190 \208\161\208\176\209\128\209\139","Sarah's Guide",2,"inv_staff_10"},
    [17039]={"\208\159\209\128\208\190\208\177\208\184\208\178\208\176\209\130\208\181\208\187\209\140 \209\135\208\181\209\128\208\181\208\191\208\190\208\178","Skullbreaker",2,"inv_misc_bone_dwarfskull_01"},
    [17042]={"\208\147\208\178\208\190\208\183\208\180\208\190\208\188\208\181\209\130","Nail Spitter",2,"inv_weapon_rifle_01"},
    [17043]={"\208\158\208\180\208\181\209\143\208\189\208\184\208\181 \209\132\208\176\208\189\208\176\209\130\208\184\208\186\208\176","Zealot's Robe",2,"inv_chest_cloth_06"},
    [17044]={"\208\146\208\190\208\187\209\143 \208\156\209\131\209\135\208\181\208\189\208\184\208\186\208\176","Will of the Martyr",3,"inv_jewelry_talisman_07"},
    [17045]={"\208\154\209\128\208\190\208\178\209\140 \208\156\209\131\209\135\208\181\208\189\208\184\208\186\208\176","Blood of the Martyr",3,"inv_jewelry_ring_25"},
    [17191]={"\208\161\208\186\208\184\208\191\208\181\209\130\209\128 \208\154\208\181\208\187\208\181\208\177\209\128\208\176\209\129\208\176","Scepter of Celebras",3,"inv_staff_16"},
    [17508]={"\208\154\209\131\208\187\208\176\209\135\208\189\209\139\208\185 \209\137\208\184\209\130 \208\154\208\176\208\188\208\189\208\181\209\129\208\184\208\187\209\139","Forcestone Buckler",2,"inv_shield_02"},
    [17694]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\154\209\131\208\187\208\176\208\186\208\176","Band of the Fist",2,"inv_jewelry_ring_02"},
    [17695]={"\208\158\208\191\208\187\208\181\209\135\209\140\208\181 \208\147\208\189\208\181\208\180\208\190\208\179\208\190","Chestnut Mantle",2,"inv_shoulder_09"},
    [17705]={"\208\156\208\190\208\187\208\190\209\130\209\143\209\137\208\184\208\185 \208\186\208\187\208\184\208\189\208\190\208\186","Thrash Blade",3,"inv_sword_36"},
    [17743]={"\208\150\208\181\208\183\208\187 \208\146\208\190\208\183\209\128\208\190\208\182\208\180\208\181\208\189\208\184\209\143","Resurgence Rod",3,"inv_staff_goldfeathered_01"},
    [17753]={"\208\166\208\181\208\187\209\140 \208\151\208\181\208\187\208\181\208\189\208\190\208\179\208\190 \209\133\209\128\208\176\208\189\208\184\209\130\208\181\208\187\209\143","Verdant Keeper's Aim",3,"inv_weapon_bow_03"},
    [17768]={"\208\154\208\190\208\187\209\140\209\134\208\190 \208\155\208\181\209\129\208\189\209\139\209\133 \208\161\208\181\208\188\209\143\208\189","Woodseed Hoop",2,"inv_jewelry_ring_18"},
    [17770]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\154\208\190\208\179\209\130\208\184\209\129\209\130\208\190\208\185 \208\178\208\181\209\130\208\178\208\184","Branchclaw Gauntlets",2,"inv_gauntlets_30"},
    [17772]={"\208\156\208\190\208\179\209\131\209\135\208\176\209\143 \208\191\208\190\208\180\208\178\208\181\209\129\208\186\208\176 \208\158\209\129\208\186\208\190\208\187\208\186\208\190\208\178 \208\161\209\131\208\188\209\128\208\176\208\186\208\176","Zealous Shadowshard Pendant",2,"inv_jewelry_necklace_06"},
    [17773]={"\208\167\209\131\208\180\208\181\209\129\208\189\208\176\209\143 \208\191\208\190\208\180\208\178\208\181\209\129\208\186\208\176 \208\158\209\129\208\186\208\190\208\187\208\186\208\190\208\178 \208\161\209\131\208\188\209\128\208\176\208\186\208\176","Prodigious Shadowshard Pendant",2,"inv_jewelry_necklace_06"},
    [17774]={"\208\151\208\189\208\176\208\186 \208\152\208\183\208\177\209\128\208\176\208\189\208\189\208\190\208\179\208\190","Mark of the Chosen",2,"inv_jewelry_talisman_08"},
    [17775]={"\208\159\209\128\208\190\208\189\208\184\209\134\208\176\209\130\208\181\208\187\209\140\208\189\209\139\208\181 \208\190\208\180\208\181\209\143\208\189\208\184\209\143","Acumen Robes",2,"inv_chest_cloth_49"},
    [17776]={"\208\168\208\187\208\181\208\188 \208\154\208\190\208\187\209\140\209\134\208\176 \208\180\209\131\209\133\208\190\208\178","Sprightring Helm",2,"inv_helmet_35"},
    [17777]={"\208\145\208\181\209\129\208\191\208\190\209\137\208\176\208\180\208\189\208\176\209\143 \208\186\208\190\208\187\209\140\209\135\209\131\208\179\208\176","Relentless Chain",2,"inv_chest_chain_07"},
    [17778]={"\208\159\208\190\208\187\209\139\208\189\208\189\209\139\208\185 \209\128\208\181\208\188\208\181\208\189\209\140","Sagebrush Girdle",2,"inv_belt_25"},
    [17779]={"\208\157\208\176\208\191\208\187\208\181\209\135\209\140\208\181 \208\188\208\181\208\179\208\176\208\186\208\176\208\188\208\189\209\143","Hulkstone Pauldrons",2,"inv_shoulder_23"},
    [18022]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\144\208\187\208\181\208\186\209\129\208\184\209\129\208\176","Royal Seal of Alexis",3,"inv_jewelry_ring_30"},
    [18258]={"\208\145\209\128\208\190\208\189\209\143 \208\190\208\179\209\128\208\190\208\178 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok Ogre Suit",2,"inv_chest_chain_14"},
    [18269]={"\208\151\208\181\208\187\208\181\208\189\209\139\208\185 \208\179\209\128\208\190\208\179 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok Green Grog",2,"inv_drink_03"},
    [18284]={"\208\163\208\177\208\190\208\185\208\189\208\190\208\181 \208\191\208\190\208\185\208\187\208\190 \208\154\209\128\208\184\208\179\208\176","Kreeg's Stout Beatdown",2,"inv_drink_05"},
    [18366]={"\208\145\208\190\208\181\208\178\209\139\208\181 \209\128\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok's Handguards",3,"inv_gauntlets_09"},
    [18367]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok's Gauntlets",3,"inv_gauntlets_09"},
    [18368]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok's Gloves",3,"inv_gauntlets_01"},
    [18369]={"\208\159\208\190\208\178\209\143\208\183\208\186\208\184 \208\147\208\190\209\128\208\180\208\190\208\186\208\176","Gordok's Handwraps",3,"inv_gauntlets_06"},
    [18410]={"\208\156\208\181\209\135 \209\129\208\191\209\128\208\184\208\189\209\130\208\181\209\128\208\176","Sprinter's Sword",2,"inv_sword_28"},
    [18411]={"\208\159\208\190\208\180\208\178\208\184\208\182\208\189\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Spry Boots",2,"inv_boots_06"},
    [18420]={"\208\154\208\190\209\129\209\130\208\181\208\186\209\128\209\131\209\136\208\184\209\130\208\181\208\187\209\140","Bonecrusher",3,"inv_mace_02"},
    [18421]={"\208\168\208\187\208\181\208\188 \208\151\208\176\208\180\208\189\208\181\208\187\208\181\209\129\208\176","Backwood Helm",3,"inv_helmet_19"},
    [18424]={"\208\158\209\129\208\190\208\186\208\190\208\178\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184","Sedge Boots",3,"inv_boots_05"},
    [18465]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18466]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18467]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18468]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18469]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18470]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18471]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18472]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18473]={"\208\154\208\190\209\128\208\190\208\187\208\181\208\178\209\129\208\186\208\176\209\143 \208\191\208\181\209\135\208\176\209\130\209\140 \208\173\208\187\209\140\208\180\209\128\208\181'\208\162\208\176\208\187\208\176\209\129\208\176","Royal Seal of Eldre'Thalas",3,"inv_jewelry_talisman_10"},
    [18491]={"\208\156\208\176\209\129\209\130\208\181\209\128-\208\191\209\128\209\143\208\180\208\184\208\187\209\140\209\137\208\184\208\186","Lorespinner",3,"inv_weapon_shortblade_21"},
    [18592]={"\208\167\208\181\209\128\209\130\208\181\208\182: \209\129\209\131\208\187\209\140\209\132\209\131\209\128\208\190\208\189\209\129\208\186\208\184\208\185 \208\188\208\190\208\187\208\190\209\130","Plans: Sulfuron Hammer",4,"inv_scroll_03"},
    [19812]={"\208\160\209\131\208\189\208\176 \208\160\208\176\209\129\209\129\208\178\208\181\209\130\208\176","Rune of the Dawn",3,"inv_misc_rune_06"},
    [20403]={"\208\148\208\190\208\178\208\181\209\128\208\181\208\189\208\189\209\139\208\185 \208\157\208\190\208\183\208\180\208\190\209\128\208\188\209\131","Proxy of Nozdormu",2,"spell_holy_sealofwrath"},
    [21994]={"\208\159\208\190\209\143\209\129 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Belt of Heroism",3,"inv_belt_34"},
    [21995]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Boots of Heroism",4,"inv_boots_plate_03"},
    [21996]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Bracers of Heroism",3,"inv_bracer_18"},
    [21998]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Gauntlets of Heroism",4,"inv_gauntlets_26"},
    [22000]={"\208\157\208\190\208\182\208\189\209\139\208\181 \208\187\208\176\209\130\209\139 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Legplates of Heroism",3,"inv_pants_04"},
    [22001]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\147\208\181\209\128\208\190\208\184\208\183\208\188\208\176","Spaulders of Heroism",3,"inv_shoulder_30"},
    [22002]={"\208\159\208\190\209\143\209\129 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \208\162\209\140\208\188\209\139","Darkmantle Belt",3,"inv_belt_03"},
    [22003]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \208\162\209\140\208\188\209\139","Darkmantle Boots",4,"inv_boots_08"},
    [22004]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \209\130\209\140\208\188\209\139","Darkmantle Bracers",3,"inv_bracer_07"},
    [22006]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \208\162\209\140\208\188\209\139","Darkmantle Gloves",4,"inv_gauntlets_24"},
    [22007]={"\208\168\209\130\208\176\208\189\209\139 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \208\162\209\140\208\188\209\139","Darkmantle Pants",3,"inv_pants_02"},
    [22008]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\159\208\190\208\186\209\128\208\190\208\178\208\176 \208\162\209\140\208\188\209\139","Darkmantle Spaulders",3,"inv_shoulder_07"},
    [22010]={"\208\159\208\190\209\143\209\129 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Belt",3,"inv_belt_28"},
    [22011]={"\208\157\208\176\209\128\209\131\209\135\208\189\208\184\208\186\208\184 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Bindings",3,"inv_bracer_17"},
    [22015]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Gloves",4,"inv_gauntlets_10"},
    [22016]={"\208\158\208\191\208\187\208\181\209\135\209\140\208\181 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Mantle",3,"inv_shoulder_10"},
    [22017]={"\208\168\209\130\208\176\208\189\209\139 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Pants",3,"inv_pants_03"},
    [22061]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\159\208\190\208\178\208\181\208\187\208\184\209\130\208\181\208\187\209\143 \208\151\208\178\208\181\209\128\208\181\208\185","Beastmaster's Boots",4,"inv_boots_plate_07"},
    [22062]={"\208\159\208\190\209\143\209\129 \208\188\208\176\208\179\208\176","Sorcerer's Belt",3,"inv_belt_08"},
    [22063]={"\208\157\208\176\209\128\209\131\209\135\208\189\208\184\208\186\208\184 \208\178\208\190\208\187\209\136\208\181\208\177\208\189\208\184\208\186\208\176","Sorcerer's Bindings",3,"inv_jewelry_ring_23"},
    [22064]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\178\208\190\208\187\209\136\208\181\208\177\208\189\208\184\208\186\208\176","Sorcerer's Boots",4,"inv_boots_02"},
    [22066]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\178\208\190\208\187\209\136\208\181\208\177\208\189\208\184\208\186\208\176","Sorcerer's Gloves",4,"inv_gauntlets_17"},
    [22067]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\178\208\190\208\187\209\136\208\181\208\177\208\189\208\184\208\186\208\176","Sorcerer's Leggings",3,"inv_pants_06"},
    [22068]={"\208\156\208\176\208\189\209\130\208\184\209\143 \208\178\208\190\208\187\209\136\208\181\208\177\208\189\208\184\208\186\208\176","Sorcerer's Mantle",3,"inv_shoulder_23"},
    [22070]={"\208\159\208\190\209\143\209\129 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Belt",3,"inv_belt_12"},
    [22071]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Bracers",3,"inv_bracer_13"},
    [22072]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Leggings",3,"inv_pants_08"},
    [22073]={"\208\158\208\191\208\187\208\181\209\135\209\140\208\181 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Mantle",3,"inv_misc_bone_taurenskull_01"},
    [22076]={"\208\161\208\176\208\189\208\180\208\176\208\187\208\184\208\184 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Sandals",4,"inv_boots_05"},
    [22077]={"\208\159\208\190\208\178\209\143\208\183\208\186\208\184 \208\162\209\131\208\188\208\176\208\189\208\176 \209\129\208\188\208\181\209\128\209\130\208\184","Deathmist Wraps",4,"inv_gauntlets_32"},
    [22078]={"\208\159\208\190\209\143\209\129 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Belt",3,"inv_belt_10"},
    [22079]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Bracers",3,"inv_belt_31"},
    [22081]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Gloves",4,"inv_gauntlets_14"},
    [22082]={"\208\158\208\191\208\187\208\181\209\135\209\140\208\181 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Mantle",3,"inv_shoulder_02"},
    [22084]={"\208\161\208\176\208\189\208\180\208\176\208\187\208\184\208\184 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Sandals",4,"inv_boots_05"},
    [22085]={"\208\174\208\177\208\186\208\176 \208\148\208\190\208\177\209\128\208\190\208\180\208\181\209\130\208\181\208\187\208\184","Virtuous Skirt",3,"inv_pants_08"},
    [22086]={"\208\159\208\190\209\143\209\129 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Belt",3,"inv_belt_11"},
    [22087]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Boots",4,"inv_boots_plate_03"},
    [22088]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Bracers",3,"inv_bracer_14"},
    [22090]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Gauntlets",4,"inv_gauntlets_19"},
    [22092]={"\208\157\208\190\208\182\208\189\209\139\208\181 \208\187\208\176\209\130\209\139 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Legplates",3,"inv_pants_04"},
    [22093]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\151\208\176\208\186\208\176\208\187\208\181\208\189\208\189\208\190\208\179\208\190 \208\180\209\131\209\133\208\176","Soulforge Spaulders",3,"inv_shoulder_10"},
    [22095]={"\208\157\208\176\209\128\209\131\209\135\208\189\208\184\208\186\208\184 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Bindings of The Five Thunders",3,"inv_bracer_02"},
    [22096]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Boots of The Five Thunders",4,"inv_boots_wolf"},
    [22098]={"\208\168\208\189\209\131\209\128\208\190\208\178\208\176\208\189\208\189\209\139\208\185 \209\128\208\181\208\188\208\181\208\189\209\140 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Cord of The Five Thunders",3,"inv_belt_16"},
    [22099]={"\208\160\209\131\208\186\208\176\208\178\208\184\209\134\209\139 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Gauntlets of The Five Thunders",4,"inv_gauntlets_11"},
    [22100]={"\208\154\208\184\208\187\209\130 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Kilt of The Five Thunders",3,"inv_pants_03"},
    [22101]={"\208\157\208\176\208\191\208\187\208\181\209\135\209\140\208\181 \208\159\209\143\209\130\208\184 \208\147\209\128\208\190\208\188\208\190\208\178","Pauldrons of The Five Thunders",3,"inv_shoulder_29"},
    [22106]={"\208\159\208\190\209\143\209\129 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Belt",3,"inv_belt_15"},
    [22107]={"\208\161\208\176\208\191\208\190\208\179\208\184 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Boots",4,"inv_boots_08"},
    [22108]={"\208\157\208\176\209\128\209\131\209\135\208\184 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Bracers",3,"inv_bracer_09"},
    [22110]={"\208\159\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Gloves",4,"inv_gauntlets_17"},
    [22111]={"\208\154\208\184\208\187\209\130 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Kilt",3,"inv_pants_08"},
    [22112]={"\208\157\208\176\208\191\208\187\208\181\209\135 \208\150\208\181\209\129\209\130\208\190\208\186\208\190\208\179\208\190 \209\129\208\181\209\128\208\180\209\134\208\176","Feralheart Spaulders",3,"inv_shoulder_01"},
    [22137]={"\208\161\209\131\208\188\208\186\208\176 \208\152\209\129\208\184\208\180\209\139","Ysida's Satchel",1,"inv_misc_bag_20"},
    [22149]={"\208\145\209\131\209\129\209\139 \208\158\208\179\209\128\209\129\208\186\208\190\208\179\208\190 \208\154\208\190\208\187\208\180\208\190\208\178\209\129\209\130\208\178\208\176","Beads of Ogre Mojo",3,"inv_jewelry_amulet_05"},
    [22150]={"\208\145\209\131\209\129\209\139 \208\158\208\179\209\128\209\129\208\186\208\190\208\185 \208\156\208\190\209\137\208\184","Beads of Ogre Might",3,"inv_jewelry_amulet_05"},
    [22192]={"\208\173\208\187\208\184\208\186\209\129\208\184\209\128 \208\189\208\176\208\187\208\190\208\182\208\181\208\189\208\184\209\143 \209\135\208\176\209\128","Bloodkelp Elixir of Dodging",1,"inv_potion_52"},
    [22193]={"\208\173\208\187\208\184\208\186\209\129\208\184\209\128 \209\131\209\129\209\130\208\190\208\185\209\135\208\184\208\178\208\190\209\129\209\130\208\184","Bloodkelp Elixir of Resistance",1,"inv_potion_21"},
    [22320]={"\208\154\208\176\209\135\208\181\209\129\209\130\208\178\208\181\208\189\208\189\209\139\208\181 \209\130\208\190\208\178\208\176\209\128\209\139 \208\156\209\131\208\186\209\129\208\176","Mux's Quality Goods",1,"inv_misc_bag_12"},
    [250947]={"\208\161\208\184\208\187\209\140\208\189\208\190\208\181 \208\183\208\181\208\187\209\140\208\181 \209\134\208\181\208\187\208\184\209\130\208\181\208\187\209\143","Greater Mender's Potion",1,"inv_potionf_3"},
    [270005]={"\208\156\208\190\208\187\208\190\209\130 \208\188\208\190\208\189\208\176\209\133\208\176","Monastic Hammer",2,"inv_hammer_11"},
    [270007]={"\208\159\208\190\209\130\208\181\209\128\209\130\209\139\208\185 \209\136\208\189\209\131\209\128\208\190\208\178\208\176\208\189\208\189\209\139\208\185 \209\128\208\181\208\188\208\181\208\189\209\140 \209\136\208\176\209\133\209\130\208\181\209\128\208\176","Worn Miner's Waistcord",2,"inv_belt_22"},
    [270012]={"\208\160\208\176\208\177\208\190\209\135\208\184\208\181 \208\191\208\181\209\128\209\135\208\176\209\130\208\186\208\184 \208\179\208\190\209\128\208\189\209\143\208\186\208\176","Miner's Workgloves",2,"inv_gauntlets_16"},
    [270013]={"\208\160\208\176\208\177\208\190\209\135\208\184\208\181 \208\177\208\190\209\130\208\184\208\189\208\186\208\184 \208\179\208\190\209\128\208\189\209\143\208\186\208\176","Miner's Workboots",2,"inv_boots_05"},
    [270015]={"\208\159\208\190\209\128\209\131\209\135\208\184 \208\179\208\190\208\187\208\190\208\178\208\190\209\128\208\181\208\183\208\176","Bravo's Armbands",2,"inv_bracer_07"},
    [270016]={"\208\159\208\190\208\189\208\190\208\182\208\184 \208\180\209\128\208\181\208\188\208\187\209\142\209\137\208\181\208\179\208\190","Dreamer's Leggings",2,"inv_pants_06"},
    [270018]={"\208\154\208\190\209\129\209\130\208\181\208\188\208\190\208\187\208\190\209\130","Hammerbone",3,"inv_hammer_15"},
    [270023]={"\208\148\209\131\208\177\208\187\208\181\208\189\209\139\208\181 \208\189\208\176\208\191\208\187\208\181\209\135\208\189\209\139\208\181 \208\191\208\187\208\176\209\129\209\130\208\184\208\189\209\139","Tanned Shoulderpads",2,"inv_shoulder_27"},
    [270024]={"\208\158\209\130\208\180\208\181\208\187\208\176\208\189\208\189\209\139\208\181 \208\177\209\128\208\190\208\189\208\183\208\190\208\185 \208\189\208\176\208\191\208\187\208\181\209\135\208\189\209\139\208\181 \209\137\208\184\209\130\208\186\208\184","Bronzed Shoulderguards",2,"inv_shoulder_27"},
    [270025]={"\208\159\208\190\209\129\208\181\209\128\208\181\208\177\209\128\208\181\208\189\208\189\209\139\208\181 \209\128\209\131\208\186\208\176\208\178\208\184\209\134\209\139","Silvered Gauntlets",2,"inv_gauntlets_21"},
    [270027]={nil,"Ursine Hammer",2,"inv_hammer_16"},
    [270029]={nil,"Town Clerk's Mittens",2,"inv_gauntlets_27"},
    [270030]={"\208\160\208\178\208\176\208\189\209\139\208\181 \208\191\208\190\208\187\209\131\208\191\208\181\209\128\209\135\208\176\209\130\208\186\208\184","Tattered Mittens",2,"inv_gauntlets_27"},
    [270031]={"\208\159\208\190\208\189\208\190\208\182\208\184 \209\130\208\181\208\188\208\189\208\190\208\179\208\190 \209\128\208\184\209\130\209\131\208\176\208\187\208\176","Dark Ritual Leggings",3,"inv_pants_02"},
    [270032]={"\208\145\208\190\208\181\208\178\209\139\208\181 \208\189\208\176\209\128\209\131\209\135\208\184 \209\129\208\181\208\186\209\130\208\176\208\189\209\130\208\176","Cultist's Armguards",3,"inv_bracer_12"},
    [270036]={nil,"Magistrate's Pantaloons",3,"inv_pants_14"},
    [270042]={"\208\157\208\176\209\128\209\131\209\135\208\184 \209\130\208\181\209\133\208\189\208\184\208\186\208\176","Technician's Bracers",2,"inv_bracer_02"},
    [270043]={nil,"Dreamer's Chestguard",3,"inv_chest_leather_01"},
    [270055]={nil,"Charged Leather Bracers",2,"inv_bracer_08"},
    [270059]={nil,"Restorer's Fine Gloves",2,"inv_gauntlets_21"},
    [270060]={nil,"Excavator Gauntlets",2,"inv_gauntlets_28"},
    [270074]={nil,"Doomcaller's Pants",2,"inv_pants_14"},
    [270075]={nil,"Fists of Impending Doom",2,"inv_gauntlets_12"},
    [270081]={nil,"Purified Ring",3,"inv_jewelry_ring_01"},
    [270099]={nil,"Magister Cowl",3,"inv_helmet_13"},
    [270125]={nil,"Satyrhide Armbands",3,"inv_bracer_18"},
    [274041]={"\208\175\209\137\208\184\208\186 \209\129 \208\180\208\190\208\186\209\131\208\188\208\181\208\189\209\130\208\176\208\188\208\184","Document Box",1,"inv_misc_treasurechest01b"},
    [274078]={nil,"Boar Signet",2,"inv_jewelry_ring_26"},
    [279448]={nil,"Bloodsplattered Bandana",2,"inv_misc_bandana_03"},
    [279450]={"\208\160\208\176\209\129\208\186\208\190\208\187\208\190\209\130\209\139\208\185 \208\183\208\189\208\176\208\186 \209\128\208\176\208\183\208\187\208\184\209\135\208\184\209\143","Fractured Insignia",2,"inv_misc_armorkit_04"},
    [279473]={nil,"Makeshift Belt",2,"inv_misc_clothscrap_02"},
    [279474]={nil,"Dustwallow Dirk",3,"inv_sword_13"},
    [279824]={nil,"Kor'kron Battle Gauntlets",2,"inv_gauntlets_03"},
    [279825]={nil,"Theramore Defender's Gauntlets",2,"inv_gauntlets_03"},
    [279826]={nil,"Marshdweller's Pants",2,"inv_pants_10"},
    [279829]={nil,"Naga Scale Spaulders",2,"inv_shoulder_07"},
    [279831]={nil,"Fatebound Buckler",3,"inv_shield_02"},
    [279833]={nil,"Courier's Clasp",3,"inv_jewelry_necklace_15"},
    [279901]={nil,"Expeditionary Legplates",3,"inv_pants_04"},
    [279902]={nil,"Reinforced Muck Protectors",3,"inv_pants_04"},
    [279903]={nil,"Diemetradon Scale Spaulders",3,"inv_shoulder_28"},
    [279904]={nil,"Crystalline Pauldrons",3,"inv_shoulder_26"},
    [279905]={nil,"Ravasaur Hide Footpads",3,"inv_boots_05"},
    [279906]={nil,"Potent Treads",3,"inv_boots_05"},
    [279908]={nil,"Crystal-Infused Cleaver",3,"inv_axe_21"},
    [279910]={nil,"Beastslayer's Trident",3,"inv_spear_04"},
    [279912]={nil,"Faintly Glowing Orb",3,"inv_misc_orb_01"},
    [279931]={nil,"Lost Researcher's Hood",3,"inv_helmet_29"},
    [279932]={nil,"Slime-Resistant Shroud",3,"inv_helmet_29"},
}
-- END REWARDS
