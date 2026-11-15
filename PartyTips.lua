local _, P = ...
local L = P.L or function(s) return s end
local atlas = P.Core
local signature = "[Dungeon Quest Forever] "
-- Short group instructions fit in one chat message, including on ruRU clients.
local tips = {
    ALCAZ={L"В Алказе заберите связку у надзирателя Рекса. Она открывает нижний этаж.", "In Alcaz Prison, loot Overseer Wrex's keyring for the lower floor."},
    BFD={L"В Пучине за Келрисом зажигайте огни по одному. Каждый выпускает свою волну.", "In Blackfathom Deeps, light the four fires after Kelris one at a time. Each starts a wave."},
    BLACKMAW={L"В Оплоте Чёрной Пасти проверьте, появился ли Moontouched Wanderer. Это редкий зверь с отдельной добычей.", "In Blackmaw Hold, look for Moontouched Wanderer, a rare beast with its own loot."},
    BRD={L"В Глубинах Чёрной горы прочитайте табличку у портрета в банке: она укажет, какой хранитель несёт ключ.", "In Blackrock Depths, read the vault portrait's plaque to find the keeper carrying the Dark Coffer Key."},
    DALARAN={L"На Лин в Даларане нужен том. Возьмите книгу со стола Аругала в Крепости Тёмного Клыка и зарядите её в Янтарной Мельнице.", "For Lyn in Dalaran, loot the book behind Arugal in Shadowfang Keep and charge it at Ambermill before the run."},
    DM_E={L"В восточном Забытом Городе поговорите с Пузиллином у входа и догоняйте его на остановках ради ключа.", "In Dire Maul East, speak to Pusillin at the entrance and follow him at each stop for the Crescent Key."},
    DM_N={L"Идёте за полной данью огров? Подготовьте костюм огра, морозное масло и ториевое устройство и пощадите стражей.", "For a Dire Maul North tribute run, bring an ogre suit, Frost Oil and a Thorium Widget. Spare the guards."},
    DM_W={L"В западном Забытом Городе чернокнижник с предметами для ритуала скакуна может призвать Хел’нурата после Бессмер’тера.", "In Dire Maul West, a warlock on the Dreadsteed ritual can summon Lord Hel'nurath after Immol'thar."},
    EXCAVATION={L"На раскопках в Болотине после боя со стражем подберите реликвию титанов и проверьте её в сумке.", "At the Wetlands excavation, loot the Titan Relic from the Relic Guardian and inspect it in your bags."},
    GNOMER={L"В Гномрегане оставьте покрытые грязью предметы для автомата в Чистой зоне. Приготовьте по 3 серебряных.", "In Gnomeregan, save Grime-Encrusted Objects and 3 silver per use for the Sparklematic in the Clean Zone."},
    THANES={L"В Чертогах Танов игроки Альянса могут взять задание с таблички в хранилище за последним боссом.", "In the Hall of Thanes, Alliance players can start a quest from the tablet in the vault past the final boss."},
    KROLDOK={L"В Крол’доке после деревянного моста проверьте площадку с шаманами. Там стоит Bossman Toof.", "In Krol'dok, check the platform with shamans after the wooden bridge for Bossman Toof."},
    LBRS={L"На нижнем пике сохраните голову Омокка и копьё Roughshod Pike. Они нужны у груды подношений для вызова Урока.", "In Lower Blackrock Spire, keep Omokk's Head and the Roughshod Pike for Urok's tribute pile."},
    MARA={L"Для скипетра Мародона возьмите задание у Кавиндры до портала. Детали падают в оранжевом и фиолетовом крыльях.", "For the Maraudon scepter, see Cavindra before zoning in. The two pieces come from the orange and purple wings."},
    RFC={L"В Огненной пропасти перед Джергошем поднимитесь направо к Баззалану. По нижнему пути его легко пропустить.", "In Ragefire Chasm, take the right-hand rise before Jergosh to find Bazzalan."},
    RFD={L"В Курганах Иглошкурых бейте в паучий гонг после каждой волны. Третий удар вызывает Тутен’каша.", "In Razorfen Downs, hit the spider gong after each wave. The third strike calls Tuten'kash."},
    RFK={L"В Лабиринтах Иглошкурых загляните в дальний конец пещеры летучих мышей за Агафелосом: там бывает Слепой охотник.", "In Razorfen Kraul, check the back of the bat cave beyond Agathelos for the rare Blind Hunter."},
    LORDAERON={L"В Руинах Лордерона соберитесь у камина в сгоревшем доме на юго-западе. Нажатие запускает волны и бой с Виктором.", "In the Ruins of Lordaeron, gather at the fireplace in the southwestern burned house to start Viktor's event."},
    SM_ARM={L"Для Оружейной проверьте Алый ключ у группы. Свой можно взять в сундуке за Доаном в библиотеке.", "For the Scarlet Armory, check who has the Scarlet Key. Doan's chest in the Library holds a copy."},
    SM_CATH={L"В Соборе Алого ордена нажмите факел в комнате справа от алтаря: за стеной спрятан Фэйрбанкс.", "In Scarlet Cathedral, use the torch in the room to the right of the altar to find Fairbanks."},
    SM_GY={L"На кладбище Алого ордена проверьте могилы сбоку от дорожки. Там могут появиться три редких противника.", "In Scarlet Graveyard, check the rows of graves beside the path for three possible rares."},
    SM_LIB={L"В библиотеке Алого ордена после Доана обыщите сундук за ним. Там ключ к Оружейной и Собору.", "In Scarlet Library, loot the chest behind Doan for the key to the Armory and Cathedral."},
    SCHOLO={L"Для призыва Киртоноса в Некроситете возьмите Кровь невинных по цепочке Евы Саркофф в Каэр Дарроу.", "For Kirtonos in Scholomance, bring Blood of Innocents from Eva Sarkhoff's chain at Caer Darrow."},
    SFK={L"В Крепости Тёмного Клыка после Аругала заберите чёрный том со стола. Он нужен для секретного босса Даларана.", "After Arugal in Shadowfang Keep, loot the Black Tome from his table for Dalaran's hidden boss."},
    SHAPERS={L"Перед походом на Террасу Создателя соберите силовые кристаллы в кратере Ун’Горо для консолей внутри.", "Bring Un'Goro power crystals to the Shaper's Terrace for the consoles inside."},
    STRAT_LIVE={L"В жилом квартале Стратхольма заберите ключи у курьера. Третий почтовый ящик вызывает почтальона Мэлоуна.", "On Stratholme's living side, loot the courier's keys. The third mailbox summons Postmaster Malown."},
    STRAT_UD={L"Для спасения Изиды в Стратхольме соберите группу до открытия внутренних ворот: от них идёт отсчёт 45 минут.", "For Ysida's rescue in Stratholme, regroup before the inner gauntlet gate. Opening it starts the 45-minute timer."},
    ST={L"Статуи в Затонувшем храме: юг, север, юго-запад, юго-восток, северо-запад, северо-восток. Затем спускайтесь к бассейну.", "Sunken Temple statues: south, north, southwest, southeast, northwest, northeast. Then head down to the pool."},
    DM={L"В Мёртвых копях после Рак’Зора проверьте боковую шахту по пути к Сниду. Там бывает Рудокоп Джонсон.", "In the Deadmines, check the side tunnel after Rhahk'Zor on the way to Sneed for Miner Johnson."},
    DROWNED={L"В Затонувшем городе, в Глубинных архивах, сверните направо и ныряйте в тоннель: он ведёт в подводную комнату элементаля.", "In the Drowned City's Deep Archives, swim through the right-hand tunnel for the Primeval Elemental."},
    STOCKS={L"В Тюрьме Штормграда проверьте боковые камеры: в одной из них бывает редкий заключённый Bruegal Ironknuckle.", "Check the side cells in the Stockade for the rare prisoner Bruegal Ironknuckle."},
    ULDA={L"В Ульдамане отдайте жезл Ревелоша и медальон из сундука Бейлога одному игроку. Собранный посох открывает Иронайю.", "In Uldaman, give Revelosh's shaft and the medallion from Baelog's chest to one player. The staff opens Ironaya's chamber."},
    UBRS={L"На верхнем пике Чёрной горы осмотрите алтарь у левой стены инкубатора. Соберитесь до активации волн Солакар.", "In Upper Blackrock Spire, find the Father Flame altar on the left side of the Rookery. Regroup before starting Solakar's waves."},
    WC={L"В Пещерах Стенаний после четырёх предводителей Клыка вернитесь к ученику у входа. Сопроводите его ради Мутануса.", "In Wailing Caverns, return to the disciple at the entrance after all four Fanglords. His escort leads to Mutanus."},
    ZF={L"Для Газ’риллы в Зул’Фарраке захватите молот из Внутренних земель. Им бьют в гонг у бассейна.", "Bring the Mallet of Zul'Farrak from the Hinterlands to summon Gahz'rilla at the pool gong."},
}

local planned, plannedAt, generation, lastSent = nil, nil, 0, nil
local messages = {}
for key, pair in pairs(tips) do
    for _, body in ipairs(pair) do messages[signature .. body] = key end
end

local function party()
    return IsInGroup() and not IsInRaid()
end

local function channel()
    return LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
end

local function destination()
    local name, kind, _, _, _, _, _, instance = GetInstanceInfo()
    if kind == "none" then return plannedAt and GetTime() - plannedAt < 1800 and planned or nil end
    if kind ~= "party" then return end
    local match
    for _, d in ipairs(atlas.Dungeons) do
        if d.instanceID == instance or (not d.instanceID and (name == d.name or name == atlas.DungeonName(d))) then
            if d.key == planned then return planned end
            if match then match = false elseif match == nil then match = d.key end
        end
    end
    return match or nil
end

local function canSend(db, key)
    local last = db and db.partyTipsSeen and db.partyTipsSeen[key]
    return db and db.partyTips ~= false and party() and tips[key] and not InCombatLockdown()
        and (not last or GetServerTime() - last >= 7200)
        and (not lastSent or GetTime() - lastSent >= 120)
end

local function remember(db, key)
    db.partyTipsSeen = db.partyTipsSeen or {}
    db.partyTipsSeen[key] = GetServerTime()
    lastSent = GetTime()
end

local function schedule()
    generation = generation + 1
    local token, db = generation, ForeverDungeonPrepChar
    if not db or not party() or InCombatLockdown() then return end
    local key = destination()
    if not canSend(db, key) then return end
    -- Order the party, even when only some members run DQ. Later slots
    -- hear the first public tip and cancel without requiring addon traffic.
    local mine = GetUnitName("player", true)
    if not mine or (issecretvalue and issecretvalue(mine)) then return end
    local slot = 0
    for i = 1, GetNumSubgroupMembers() do
        local name = GetUnitName("party" .. i, true)
        if not name or (issecretvalue and issecretvalue(name)) then return end
        if name < mine then slot = slot + 1 end
    end
    C_Timer.After(5 + slot * 2.5, function()
        if token ~= generation or not canSend(db, key) or destination() ~= key then return end
        local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        if not send then return end
        -- In English always: the groups are of every tongue (the owner, 15.11.2026, his tip of
        -- the Drowned City in Russian to an English group: "russia eh").
        local body = tips[key][2]
        local ok, result = pcall(send, signature .. body, channel())
        if ok and (result == nil or result == 0 or result == true) then remember(db, key) end
    end)
end

function P.PlanPartyTip(key)
    planned, plannedAt = key, GetTime()
    schedule()
end

local events = CreateFrame("Frame")
for _, event in ipairs({"GROUP_LEFT", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, message)
    local db = ForeverDungeonPrepChar
    if event:match("^CHAT_MSG_") then
        if db and party() and type(message) == "string" and not (issecretvalue and issecretvalue(message)) then
            local key = messages[message]
            if key then remember(db, key) end
        end
    elseif event == "GROUP_LEFT" or not party() then
        generation = generation + 1
        lastSent = nil
        if db then db.partyTipsSeen = nil end
    else
        schedule()
    end
end)
