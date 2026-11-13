local _, P = ...
local L = P.L or function(s) return s end
local atlas = P.Core

local function carrying(id)
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    return count and count(id) > 0
end

local function entrance(key)
    local dungeon = atlas.DungeonByKey[key]
    return dungeon and atlas.Entrance(dungeon)
end

-- Each entry describes the next action for this character, while its full route
-- remains available for planning before the group leaves.
local function stage(d, note)
    if note.plan == "lyn" then
        if carrying(275989) then
            return (L"Том готов"), L"В Даларане после Атрекиса иди прямо к фиолетовой руне.", nil, 2
        elseif carrying(276561) then
            return (L"До входа"), L"Отнеси чёрный том к синему кристаллу в ратуше Янтарной Мельницы (63.4, 64.3).", {mapID=1421, x=63.4, y=64.3}, 1
        elseif d.key == "DALARAN" then
            return (L"До входа"), L"Сначала в Крепость Тёмного Клыка. После Аругала забери чёрный том со стола.", entrance("SFK"), 1
        end
        return (L"Внутри"), L"После Аругала возьми чёрный том со стола для секретного босса Даларана."
    end
    if note.plan == "mallet" then
        if carrying(9240) then return (L"Молот готов"), L"Ударь в гонг у бассейна Газ’риллы.", nil, 2 end
        if carrying(9241) then
            return (L"До входа"), L"Заряди священный молот у алтаря на вершине Джинта’Алора (59, 77).", {mapID=1425, x=59, y=77}, 1
        end
        return (L"До входа"), L"Во Внутренних землях забери священный молот у Киаги на Алтаре Зула (48.6, 68.2).", {mapID=1425, x=48.6, y=68.2}, 1
    end
    if note.plan == "scarlet" and d.key ~= "SM_LIB" then
        if carrying(7146) then return (L"Ключ готов"), L"Алый ключ у тебя. Он открывает дверь этого крыла.", nil, 2 end
        return (L"До входа"), L"Уточни, есть ли у группы Алый ключ. За своим сходи в библиотеку — сундук за Доаном.", entrance("SM_LIB"), 1
    end
    if note.plan == "cards" then
        -- The chain of cards is told by what is in the bags: one line, the next terminal.
        local first = {mapID=1426, x=22.0, y=32.6}
        if carrying(9316) then
            return (L"Карта готова"), L"Призматическая перфокарта у тебя. Отнеси её Чугунотрубзу в Стальгорн — «Спасение данных».", nil, 2
        elseif carrying(9281) then
            return (L"Внутри"), L"Красную карту вставь в перфограф 3005-D — нижний ярус инженерных лабораторий, западная сторона. Он выдаст призматическую."
        elseif carrying(9282) then
            return (L"Внутри"), L"Синюю карту вставь в перфограф 3005-C — верхняя площадка у Электрошокера 6000. Он выдаст красную, с ней иди к 3005-D."
        elseif carrying(9280) then
            return (L"Внутри"), L"Жёлтую карту вставь в перфограф 3005-B — спальный блок недалеко от входа. Он выдаст синюю, дальше 3005-C и 3005-D."
        elseif carrying(9279) then
            return (L"До входа"), L"Белая карта у тебя. Вставь её в перфограф 3005-A в мастерской перед порталом (22, 33) — он выдаст жёлтую.", first, 1
        end
        return (L"До входа"), L"Белая перфокарта падает с троггов и лепрогномов в тоннелях перед порталом. Выбей одну и вставь в перфограф 3005-A там же (22, 33).", first, 1
    end
    if note.quest then
        if C_QuestLog.IsQuestFlaggedCompleted(note.quest) then
            return (L"Внутри"), L"Для повторного вызова Акваниса нужен участник с активным заданием «Среди руин»."
        elseif P.IsActive(note.quest) then
            return (L"Задание взято"), note[1], nil, 2
        end
        return (L"До входа"), note.prep, {mapID=1440, x=11.6, y=34.3}, 1
    end
    if note.prep and (not note.prepKey or note.prepKey == d.key) then
        return (L"До входа"), note.prep, note.destination and entrance(note.destination), 1
    end
    return note.after and (L"После похода") or note.kind == L"Зацепка" and (L"Зацепка") or (L"Внутри"), note[1]
end

-- Whether the character has the trade: true or false, nil when the client will not say.
local function trained(line, name)
    local ok, known = pcall(function()
        if GetProfessions and GetProfessionInfo then
            local slots = {GetProfessions()}
            for i = 1, 6 do
                if slots[i] and select(7, GetProfessionInfo(slots[i])) == line then return true end
            end
            return false
        elseif GetNumSkillLines and GetSkillLineInfo then
            for i = 1, GetNumSkillLines() do
                if GetSkillLineInfo(i) == name then return true end
            end
            return false
        end
    end)
    if ok then return known end
end

local function eligible(note)
    -- A tip for a quest is over once the quest is handed in; a trade tip is for that trade.
    if note.over and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(note.over) then return false end
    if note.skill and trained(note.skill, note.skillName) == false then return false end
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local faction = UnitFactionGroup("player")
    -- An errand into the other faction's dungeon is no errand for this character.
    local errand = note.destination and atlas.DungeonByKey[note.destination]
    if errand and errand.faction and errand.faction ~= "Both" and errand.faction ~= faction then return false end
    return (not note.class or note.class == class)
        and (not note.race or note.race == race)
        and (not note.faction or note.faction == faction)
end

function P.SecretPlan(d)
    local before, inside = {}, {}
    -- Wings behind one door are one dungeon here: their tips come together, each once.
    local notes, taken = {}, {}
    for _, key in ipairs(d.tips or {d.key}) do
        for _, note in ipairs(P.SecretCatalog[key] or {}) do
            if not taken[note] then
                taken[note] = true
                notes[#notes+1] = note
            end
        end
    end
    for _, note in ipairs(notes) do
        if eligible(note) then
            local phase, action, point, priority = stage(d, note)
            local row = {secret=note, phase=phase, action=action, point=point, priority=priority}
            table.insert(priority and before or inside, row)
        end
    end
    -- Pending errands precede equipment already in the bags.
    local ordered = {}
    for _, rank in ipairs({1, 2}) do
        for _, row in ipairs(before) do
            if row.priority == rank then table.insert(ordered, row) end
        end
    end
    return ordered, inside
end

function P.SecretRoute(row)
    if row.point then
        if P.Mark then P.Mark(row.point, row.action, "objective") else atlas.AddMarker(row.point, row.action, "objective") end
        atlas.OpenMapAt(row.point.mapID)
    end
end
