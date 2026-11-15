local _, P = ...
local QuestDB, NpcDB, ObjectDB, ItemDB = P.QuestDB or QuestDB, P.NpcDB or NpcDB, P.ObjectDB or ObjectDB, P.ItemDB or ItemDB
local L = P.L or function(s) return s end
local atlas = P.Core

-- How to walk to the entrance, in words. Classic geography; the new Forever dungeons
-- have no entry and show only the zone and the coordinates.
local ways = {
    RFC = {Horde=L"Оргриммар, Расселина Теней. Вход в пещеру в глубине расселины."},
    WC = {any=L"Степи. От Перекрёстка на юго-запад к оазису, пещера на холме над водой."},
    SFK = {Horde=L"Серебряный бор. От Гробницы по главной дороге на юг до указателя на крепость.",
        any=L"Серебряный бор, юг. Крепость на холме у главной дороги."},
    BFD = {Horde=L"Ясеневый лес. От Заставы Зорам'гар на север вдоль берега до руин, там спуск в пещеру.",
        any=L"Ясеневый лес, северо-западный берег. Руины, спуск в пещеру."},
    DM = {Horde=L"Западный Край, Луноречье. Орде идти из Тернистой долины через Сумеречный лес. Вход через дом в городке, дальше по шахте.",
        any=L"Западный Край, Луноречье. Вход через дом в городке, дальше по шахте."},
    STOCKS = {Alliance=L"Штормград, район каналов."},
    RFK = {Horde=L"Самый юг Степей. От Лагеря Таурахо по дороге на юг, перед Великим подъёмником сверни на запад.",
        any=L"Самый юг Степей, западнее дороги к Великому подъёмнику."},
    RFD = {Horde=L"Самый юг Степей. От Лагеря Таурахо по дороге на юг, перед Великим подъёмником сверни на восток.",
        any=L"Самый юг Степей, восточнее дороги к Великому подъёмнику."},
    SM = {Horde=L"Из Подгорода по дороге на восток через Брилл. У указателя на монастырь сверни на северо-восток и поднимайся в гору.",
        any=L"Северо-восток Тирисфальских лесов, на горе над дорогой."},
    GNOMER = {Horde=L"Орде в Гномреган пешком не попасть. Встань на гоблинскую площадку рядом со Скути в Пиратской Бухте: она перенесёт в тоннели к порталу. Доступ даёт задание «Поехалиии!».",
        any=L"Запад Дун Морога, к западу от Караноса."},
    ULDA = {Horde=L"Бесплодные земли. От Каргата на восток, затем на север к раскопкам у северного края.",
        any=L"Северный край Бесплодных земель, раскопки."},
    ZF = {any=L"Танарис. От Прибамбасска на северо-запад до лестницы в горах."},
    MARA = {Horde=L"Пустоши. От Деревни Ночных Охотников на северо-восток, Долина Копий.",
        any=L"Запад Пустошей, Долина Копий."},
    ST = {Horde=L"Болото Печали. От Каменора на восток до озера. Храм на острове, вниз по лестницам.",
        any=L"Болото Печали, озеро на востоке. Храм на острове, вниз по лестницам."},
    BRD = {Horde=L"Чёрная гора. Орде ближе от Каргата через Тлеющее ущелье.",
        any=L"Чёрная гора между Тлеющим ущельем и Пылающими степями."},
    DMAUL = {Horde=L"Фералас. От Лагеря Мохаче по дороге на запад, затем на север в руины.",
        any=L"Фералас, руины в центре зоны."},
    SCHOLO = {any=L"Западные Чумные земли. Остров Каэр Дарроу на озере, на юге зоны."},
    STRAT = {any=L"Север Восточных Чумных земель."},
}
local alias = {SM_GY="SM", SM_LIB="SM", SM_ARM="SM", SM_CATH="SM", LBRS="BRD", UBRS="BRD", BRS="BRD",
    DM_E="DMAUL", DM_N="DMAUL", DM_W="DMAUL", STRAT_LIVE="STRAT", STRAT_UD="STRAT"}

local sectors = {L"северный", L"северо-восточный", L"восточный", L"юго-восточный", L"южный", L"юго-западный", L"западный", L"северо-западный"}
local counts = {[2]=L"два", [3]=L"три", [4]=L"четыре"}
local atan2 = math.atan2 or math.atan

-- Wings behind one door: which of the portals is this one, by the atlas coordinates.
local function portal(d)
    local own = d.entrance
    if not (own and d.instanceID) then return end
    local n, sx, sy = 0, 0, 0
    for _, other in ipairs(atlas.Dungeons) do
        local e = other.entrance
        if other.instanceID == d.instanceID and e and e.mapID == own.mapID then n, sx, sy = n+1, sx+e.x, sy+e.y end
    end
    if n < 3 then return end
    -- Zone maps are three wide by two high.
    local dx, dy = (own.x - sx/n)*1.5, own.y - sy/n
    if dx*dx + dy*dy < .01 then return end
    local sector = sectors[math.floor(atan2(dx,-dy)/(math.pi/4) + .5) % 8 + 1]
    return (L"Порталов во дворе %s. По карте атласа твой — %s."):format(counts[n] or n, sector)
end

-- Where this faction actually walks in, when that is not the portal itself.
local doors = {
    -- title: what the arrow is called while it leads to the pad, so that nobody reads
    -- "the door of Gnomeregan" over a spot in Booty Bay. hint: said under the arrow.
    -- do: said in the tracker and in the chat. The sign in the world stands over Scooty.
    GNOMER = {Horde={mapID=1434, x=27.4, y=77.4, door="GNOMER", label=L"Телепорт в Пиратской Бухте", short=L"К телепорту", title=L"Телепорт в Гномреган",
        act=L"Иди к телепорту", near=L"Встань на телепорт",
        hint=L"площадка рядом со Скути", note=L"гоблинская площадка рядом со Скути",
        todo=L"встань на гоблинскую площадку рядом со Скути", npcID=7853, who=L"Скути",
        -- The pad on the far side, in the tunnels: the Horde's way back out.
        back={mapID=1426, x=21.4, y=37.1, door="GNOMER", label=L"Телепорт обратно в Бухту", short=L"Назад в Бухту", title=L"Телепорт в Пиратскую Бухту",
            act=L"Иди к телепорту в Бухту", near=L"Встань на телепорт в Бухту",
            hint=L"гоблинская площадка в тоннелях"}}},
}

-- A door of one's own is a way to the real door, not the door itself: the pad in Booty
-- Bay sets the player down inside Gnomeregan, a short walk from the portal. Once there
-- the door is the portal. Told by the zone the player stands in, or by the portal being
-- near and nearer than the pad.
local function own(d)
    return doors[d.key] and doors[d.key][UnitFactionGroup("player")]
end

local function arrived(d)
    local pad, real = own(d), atlas.Entrance(d)
    if not (pad and real) then return false end
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if here and not (issecretvalue and issecretvalue(here)) and here == real.mapID then return true end
    if not atlas.NavigationVector then return false end
    local _, _, near = atlas.NavigationVector(real)
    local _, _, back = atlas.NavigationVector(pad)
    return near ~= nil and near < 1500 and (back == nil or near < back)
end

-- The portal itself. The database gives the mouth of the cave, and at Gnomeregan the
-- portal is a long way in from it: the owner came by the pad, was led to "the door" and
-- found himself at the way out of the cave. The number here stands until the player has
-- walked through the portal once; after that the place he walked in at is used.
local inner = {
    GNOMER = {mapID=1426, x=17.8, y=39.2, hint=L"портал в глубине тоннелей"},
}
local function portalOf(d)
    local seen = P.char and P.char.portals and P.char.portals[d.key]
    local spot = seen or inner[d.key]
    if not spot then return end
    return {mapID=spot.mapID, x=spot.x, y=spot.y, label=L"Портал подземелья", hint=inner[d.key] and inner[d.key].hint, real=true, door=d.key}
end

-- The points of the way in, in the order of the road, and which of them the arrow takes
-- by itself. Outside: the way into the place (the mouth of the cave). Inside the place:
-- the portal of the dungeon. Just out of the dungeon: the way back out. The player may
-- choose another by a click on its line; the choice holds until he arrives.
-- Each: id, point (what the arrow is set on), label (the line), title (the arrow).
-- Out of the dungeon with its last boss dead is out for good. Out of it with the run
-- unfinished (a look outside, a wipe, a way back from the graveyard) is on the way in.
local function cameOut(d)
    local out = P.char and P.char.cameOut
    local now = GetServerTime and GetServerTime() or 0
    if not (out and out.key == d.key and now - (out.at or 0) < 1800) then return false end
    return P.RunDone ~= nil and P.RunDone(d)
end

function P.Doors(d)
    local pad, real = own(d), atlas.Entrance(d)
    local name = atlas.DungeonName(d)
    if pad and not arrived(d) then
        return {{id="pad", point=pad, label=pad.label, short=pad.short or (L"Ко входу"), title=pad.title or (L"Вход • " .. name),
            act=pad.act or (L"Иди ко входу"), near=pad.near}}, 1
    end
    if not real then return {}, nil end
    local deep = portalOf(d)
    local out = cameOut(d)
    local list, auto = {}, 1
    -- Under the open sky of the zone the cave is in, the player is on foot whatever he
    -- came by: a ghost running back from the graveyard, most of all. The tunnels have a
    -- map of their own, so standing on the zone's map means standing outside them.
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if atlas.PlainText then here = atlas.PlainText(here) end
    local outdoors = here ~= nil and here == real.mapID
    if pad and not outdoors then
        list[1] = {id="deep", point=deep or {mapID=real.mapID, x=real.x, y=real.y, label=L"Портал подземелья", real=true, door=d.key},
            label=L"Портал подземелья", short=L"К порталу", title=L"Вход • " .. name, act=L"Иди к порталу", near=L"Войди в портал"}
        if pad.back then
            list[2] = {id="back", point=pad.back, label=pad.back.label, short=pad.back.short or (L"Назад"), title=pad.back.title,
                act=pad.back.act or (L"Иди назад"), near=pad.back.near}
            if out then auto = 2 end
        end
        return list, auto
    end
    -- A cave written in by hand is two points even where the map cannot measure them.
    local apart = deep and (atlas.Span and atlas.Span(real, deep) or (inner[d.key] and 1000))
    if not (deep and apart and apart > 80) then
        -- One door: the portal where it is known, else what the database gives.
        return {{id="deep", point=deep or real, label=deep and deep.label or nil, short=L"Ко входу", title=L"Вход • " .. name,
            act=L"Иди ко входу", near=L"Войди в подземелье"}}, 1
    end
    list[1] = {id="mouth", point=real, label=out and (L"Выход из локации") or (L"Вход в локацию"), short=out and (L"К выходу") or (L"Ко входу"),
        title=(out and (L"Выход из локации") or (L"Вход в локацию")) .. " • " .. name,
        act=out and (L"Иди к выходу из локации") or (L"Иди ко входу в локацию")}
    list[2] = {id="deep", point=deep, label=L"Портал подземелья", short=L"К порталу", title=L"Вход • " .. name, act=L"Иди к порталу", near=L"Войди в портал"}
    if out then return list, 1 end
    -- On foot the mouth of the cave comes first; at it, or past it, the portal.
    if atlas.NavigationVector then
        local _, _, toMouth = atlas.NavigationVector(real)
        local _, _, toPortal = atlas.NavigationVector(deep)
        if toMouth and toPortal and (toMouth < 60 or toPortal < toMouth) then auto = 2 end
        -- In the tunnels already, whichever of the two the map makes nearer.
        if toMouth and toMouth < 1500 and here and not outdoors then auto = 2 end
    end
    return list, auto
end

local function chosen(d)
    local list, auto = P.Doors(d)
    local pick = P.char and P.char.doorPick and P.char.doorPick[d.key]
    for _, option in ipairs(list) do
        if pick and option.id == pick then return option, list, auto end
    end
    return list[auto or 1], list, auto
end

function P.Door(d)
    local option = chosen(d)
    return option and option.point
end

-- The door the arrow would take, whole: the page says what to do with it in words.
function P.DoorOption(d)
    return (chosen(d))
end

-- What the arrow to the door is called: the door, or the pad that takes one to it.
function P.DoorLabel(d)
    local option = chosen(d)
    return option and option.title or (L"Вход • " .. atlas.DungeonName(d))
end

-- A click on a line of the way in: the arrow goes there. The line the arrow would take
-- by itself is no choice at all, and the road goes on as usual after it.
function P.PickDoor(d, id)
    if not P.char then return end
    local list, auto = P.Doors(d)
    P.char.doorPick = P.char.doorPick or {}
    P.char.doorPick[d.key] = (list[auto or 1] and list[auto or 1].id ~= id) and id or nil
end

function P.Way(d)
    -- Past the pad the words about the pad are over.
    if own(d) and arrived(d) then return end
    local entry = ways[alias[d.key] or d.key]
    local text = entry and (entry[UnitFactionGroup("player")] or entry.any)
    local which = portal(d)
    if text and which then return text .. " " .. which end
    return text or which
end

-- ------------------------------------------
-- The run itself
-- ------------------------------------------
-- The bosses in the order a group meets them, and what of the dungeon's quests is done
-- at each. Written by hand from the classic dungeon; the names are read from the quest
-- database by number, the ones here are the fallback. quests: {quest, what is there}.
local runs = {
    -- The Drowned City (Forever, 15.11.2026): the bosses by Warcraft Tavern's guide, their
    -- numbers from QuestieDB 1.1.1; the Russian names the client gave in the owner's run
    -- (Зул'алай, Вар'така, Первородный элементаль, Мин'лот-Змей). The elemental stands in
    -- an underwater room off the Deep Archives.
    DROWNED = {
        {npc=258905, also={270882}, name=L"Зул'алай"},
        {npc=258924, also={270883}, name=L"Вар'така", way={L"зал «Глубинные архивы»"}},
        {npc=263886, also={270887}, name=L"Первородный элементаль", optional=true,
            way={L"в Глубинных архивах направо, в затопленный тоннель", L"плыви до подводной комнаты"}},
        {npc=260042, also={270884}, name="Captain Dreadrise"},
        {npc=260202, also={269586, 270885}, name="Deathless Marrow"},
        {npc=260243, also={260274, 267852, 269466, 270886}, name=L"Мин'лот-Змей"},
    },
    GNOMER = {
        -- way: how to walk to him, in words, from the guides: on the first run nothing
        -- else tells the player where a boss is.
        {npc=7361, name=L"Грязнюк", optional=true, note=L"выходит, когда Взрывник Ими Фитилюшка подорвёт тоннели",
            way={L"от входа по тоннелю в большой зал", L"событие начинается слева"}},
        {npc=7079, name=L"Липкая муть", way={L"от входа по тоннелю в большой зал", L"спрыгни в комнату под залом"}, quests={
            {2904, L"Возьми «Катавасия» у Керноби", taken=L"«Катавасия»: проводи Керноби к выходу"},
            {2951, L"«Чистер 5200!»: автомат рядом", sub=L"нужен «Предмет, покрытый грязью»"},
        }},
        {npc=6235, name=L"Электрошокер 6000", way={L"дальше по тоннелям", L"он на верхней площадке большого зала"}},
        {npc=6229, name=L"Толпогон 9-60", way={L"иди мимо лифта дальше", L"на лифт не садись"}},
        {npc=7800, name=L"Мекжинер Термоштепсель", way={L"вернись к лифту, который прошёл", L"спустись на нём"}, quests={
            {2841, L"«Техновойны»: забери код с босса", sub=L"чертежи лежат в его сейфе рядом"},
        }},
    },
    RFC = {
        {npc=11517, name=L"Огглфлинт"},
        {npc=11520, name=L"Тарагаман Ненасытный"},
        {npc=11518, name=L"Жергош Призыватель Духов"},
        {npc=11519, name=L"Баззалан"},
    },
    WC = {
        {npc=3671, name=L"Повелительница Анакондра"},
        {npc=3669, name=L"Лорд Кобран"},
        {npc=3653, name=L"Криг", optional=true},
        {npc=3670, name=L"Лорд Питонас"},
        {npc=3674, name=L"Шкам"},
        {npc=3673, name=L"Лорд Серпентис"},
        {npc=5775, name=L"Вердан Бессмертный"},
        {npc=3654, name=L"Мутанус Пожиратель", note=L"выходит после ритуала Ученика Наралекса, когда убиты четыре повелителя змей"},
        {npc=5912, name=L"Загадочный волшебный дракон", optional=true},
    },
    DM = {
        {npc=644, name=L"Рак'Зор"},
        {npc=3586, name=L"Шахтер Джонсон", optional=true},
        {npc=643, name=L"Снид"},
        {npc=1763, name=L"Гилнид"},
        {npc=646, name=L"Мистер Каюк"},
        {npc=647, name=L"Капитан Зеленямс"},
        {npc=639, name=L"Эдвин ван Клиф"},
        {npc=645, name=L"Пирожок", optional=true},
    },
    SFK = {
        {npc=3914, name=L"Ретилгор"},
        {npc=3886, name=L"Остроклык Мясник"},
        {npc=3887, name=L"Барон Сребролен"},
        {npc=4278, name=L"Командир Ручьедол"},
        {npc=4279, name=L"Одо Слепой Страж"},
        {npc=3872, name=L"Капитан служителей Смерти", optional=true},
        {npc=4274, name=L"Фенрус Пожиратель"},
        {npc=3927, name=L"Командир воргенов Нандос"},
        {npc=4275, name=L"Верховный маг Аругал"},
    },
    BFD = {
        {npc=4887, name=L"Гхаму-ра"},
        {npc=4831, name=L"Леди Саревесс"},
        {npc=6243, name=L"Гелихаст"},
        {npc=12902, name=L"Лоргус Джетт", optional=true},
        {npc=12876, name=L"Барон Акванис", optional=true, faction="Horde", note=L"вызывается по заданию «Среди руин»"},
        {npc=4832, name=L"Повелитель сумрака Келрис"},
        {npc=4830, name=L"Старина Серракис", optional=true},
        {npc=4829, name=L"Аку'май"},
    },
    STOCKS = {
        {npc=1696, name=L"Таргорр Ужасный"},
        {npc=1666, name=L"Кам Гневливый"},
        {npc=1717, name=L"Хрупконог"},
        {npc=1716, name=L"Базиль Тредд"},
        {npc=1663, name=L"Декстрен Вард"},
        {npc=1720, name=L"Бругал Железный Кулак", optional=true},
    },
    RFK = {
        {npc=6168, name=L"Ругуг"},
        {npc=4424, name=L"Аггем Терновое Проклятие"},
        {npc=4428, name=L"Вестник смерти Джаргба"},
        {npc=4420, name=L"Властитель Таранный Клык"},
        {npc=4422, name=L"Агателос Свирепый"},
        {npc=4425, name=L"Слепой охотник", optional=true},
        {npc=4842, name=L"Заклинательница земли Халмгар", optional=true},
        {npc=4421, name=L"Чарлга Остробок"},
    },
    SM = {
        {wing=L"Кладбище"},
        {npc=3983, name=L"Дознаватель Вишас"},
        {npc=4543, name=L"Волшебник Крови Талнос"},
        {wing=L"Библиотека"},
        {npc=3974, name=L"Псарь Локси"},
        {npc=6487, name=L"Чародей Доан"},
        {wing=L"Оружейная"},
        {npc=3975, name=L"Герод"},
        {wing=L"Собор"},
        {npc=4542, name=L"Верховный инквизитор Фэйрбанкс", optional=true},
        {npc=3976, name=L"Командир Могрейн из Алого ордена"},
        {npc=3977, name=L"Верховный инквизитор Вайтмейн"},
    },
    RFD = {
        {npc=7355, name=L"Тутен'каш", note=L"выходит после удара в гонг"},
        {npc=7357, name=L"Мордреш Огненный Глаз"},
        {npc=8567, name=L"Обжора"},
        {npc=7356, name=L"Чумобрюх Гнилой"},
        {npc=7354, name=L"Круглорыл", optional=true},
        {npc=7358, name=L"Амненнар Хладовей"},
    },
    ULDA = {
        {npc=6910, name=L"Ревелош"},
        {npc=6906, name=L"Бейлог", faction="Horde"},
        {npc=7228, name=L"Иронайа"},
        {npc=7023, name=L"Обсидиановый часовой", optional=true},
        {npc=7206, name=L"Древний Хранитель Камня"},
        {npc=7291, name=L"Галганн Огнемолот"},
        {npc=4854, name=L"Гримлок"},
        {npc=2748, name=L"Аркедас"},
    },
    MARA = {
        {npc=13282, name=L"Ноксион"},
        {npc=12258, name=L"Бритвохлест"},
        {npc=12236, name=L"Лорд Злоязыкий"},
        {npc=12237, name=L"Мешлок Жнец", optional=true},
        {npc=12225, name=L"Селебрас Проклятый"},
        {npc=12203, name=L"Сель"},
        {npc=13601, name=L"Ремонтник Гизлок"},
        {npc=13596, name=L"Гнилопасть"},
        {npc=12201, name=L"Принцесса Терадрас"},
    },
    ZF = {
        {npc=8127, name=L"Анту'сул"},
        {npc=7272, name=L"Тека Мученик"},
        {npc=7271, name=L"Знахарь Зум'рах"},
        {npc=7796, name=L"Некрум Кишкожуй"},
        {npc=7275, name=L"Темный жрец Шезз'зиз"},
        {npc=7604, name=L"Сержант Блай", optional=true},
        {npc=7795, name=L"Гидромант Велрата"},
        {npc=7273, name=L"Газ'рилла", optional=true, note=L"вызывается молотом Зул'Фаррака у гонга"},
        {npc=7797, name=L"Руузлу"},
        {npc=7267, name=L"Вождь Укорз Песчаная Плешь"},
    },
    ST = {
        {npc=8580, name=L"Атал'аларион", optional=true, note=L"появляется после шести статуй"},
        {npc=5721, name=L"Жнец Снов"},
        {npc=5720, name=L"Ткачик"},
        {npc=5710, name=L"Джаммал'ан Пророк", note=L"его щит снимают шесть троллей на балконах"},
        {npc=5711, name=L"Огом Презренный"},
        {npc=5719, name=L"Морфаз"},
        {npc=5722, name=L"Хаззас"},
        {npc=8443, name=L"Аватара Хаккара", optional=true},
        {npc=5709, name=L"Тень Эраникуса"},
    },
    BRD = {
        {npc=9018, name=L"Верховный дознаватель Герштан"},
        {npc=9025, name=L"Лорд Роккор", optional=true},
        {npc=9319, name=L"Псарь Гребмар", optional=true},
        {npc=9027, name=L"Горош Дервиш", title=L"Кольцо Закона: один из шести", also={9028, 9029, 9030, 9031, 9032}},
        {npc=9024, name=L"Пироман Зерно Мудрости", optional=true},
        {npc=9017, name=L"Лорд Опалитель"},
        {npc=9041, name=L"Тюремщик Стилгисс", optional=true},
        {npc=9056, name=L"Точень Темнострой"},
        {npc=9016, name=L"Бейл'Гор"},
        {npc=9033, name=L"Генерал Кузня Гнева"},
        {npc=8983, name=L"Повелитель големов Аргелмах"},
        {npc=9537, name=L"Харли Пьянодых", optional=true},
        {npc=9543, name=L"Риббли Крутипроб", optional=true},
        {npc=9499, name=L"Штоппор Наливалс", optional=true},
        {npc=9502, name=L"Фаланкс"},
        {npc=9156, name=L"Посол Огнехлыст"},
        {npc=9039, name=L"Рок'рел", title=L"Семеро дворфов"},
        {npc=9938, name=L"Магмус"},
        {npc=9019, name=L"Император Дагран Тауриссан"},
    },
    BRS = {
        {wing=L"Нижняя часть"},
        {npc=9196, name=L"Вождь Омокк"},
        {npc=9236, name=L"Темная охотница Вос'гаджин"},
        {npc=9237, name=L"Воевода Вун"},
        {npc=10596, name=L"Мать Дымная Паутина"},
        {npc=10584, name=L"Аррок Смертный Вопль", optional=true},
        {npc=9736, name=L"Интендант Зигрис"},
        {npc=10220, name=L"Халикон"},
        {npc=10268, name=L"Гизрул Поработитель"},
        {npc=9568, name=L"Властитель Змейталак"},
        {wing=L"Верхняя часть"},
        {npc=9816, name=L"Пиростраж Созерцатель Углей"},
        {npc=10264, name=L"Солакарский огнечервь"},
        {npc=10509, name=L"Джед Руновед", optional=true},
        {npc=10429, name=L"Вождь Ренд Чернорук", also={10339}},
        {npc=10430, name=L"Зверь"},
        {npc=10363, name=L"Генерал Драккисат"},
    },
    DMAUL = {
        {wing=L"Восток"},
        {npc=14354, name=L"Пузиллин", optional=true},
        {npc=11490, name=L"Зеврим Терновое Копыто"},
        {npc=13280, name=L"Гидротварь"},
        {npc=14327, name=L"Лефтендрис"},
        {npc=11492, name=L"Алззин Перевертень"},
        {wing=L"Запад"},
        {npc=11489, name=L"Тендрис Криводрев"},
        {npc=11488, name=L"Иллиана Воронья Ольха"},
        {npc=11487, name=L"Магистр Календрис"},
        {npc=11496, name=L"Бессмер'тер"},
        {npc=11486, name=L"Принц Тортелдрин"},
        {wing=L"Север"},
        {npc=14326, name=L"Стражник Мол'дар"},
        {npc=14322, name=L"Топотун Криг"},
        {npc=14321, name=L"Стражник Фенгус"},
        {npc=14323, name=L"Стражник Слип'кик"},
        {npc=14325, name=L"Капитан Давигром"},
        {npc=14324, name=L"Чо'Раш Наблюдатель"},
        {npc=11501, name=L"Король Гордок"},
    },
    SCHOLO = {
        {npc=10506, name=L"Киртонос Глашатай", optional=true, note=L"вызывается Кровью невинных"},
        {npc=10503, name=L"Джандис Баров"},
        {npc=11622, name=L"Громоклин"},
        {npc=10433, name=L"Мардук Блэкпул", optional=true},
        {npc=10432, name=L"Вектус", optional=true},
        {npc=10508, name=L"Рас Снегошепот"},
        {npc=10505, name=L"Инструктор Коварница"},
        {npc=11261, name=L"Доктор Теолен Крастинов"},
        {npc=10901, name=L"Сказитель Полкелт"},
        {npc=10507, name=L"Равениан"},
        {npc=10504, name=L"Лорд Алексей Баров"},
        {npc=10502, name=L"Леди Иллюсия Баров"},
        {npc=1853, name=L"Темный магистр Гандлинг", note=L"выходит после шести боссов в боковых комнатах"},
    },
    STRAT = {
        {wing=L"Живая сторона"},
        {npc=10393, name=L"Череп", optional=true},
        {npc=10558, name=L"Певчий Форрестен", optional=true},
        {npc=10516, name=L"Непрощенный"},
        {npc=10808, name=L"Тайлер"},
        {npc=11032, name=L"Малор Ревностный"},
        {npc=10997, name=L"Мастер-канонир Вилли"},
        {npc=10811, name=L"Архивариус Галфорд"},
        {npc=10813, name=L"Балназзар"},
        {wing=L"Мёртвая сторона"},
        {npc=10435, name=L"Мировой судья Бартилас"},
        {npc=10437, name=L"Неруб'энкан"},
        {npc=10436, name=L"Баронесса Анастари"},
        {npc=10438, name=L"Малекай Бледный"},
        {npc=10439, name=L"Рамштайн Ненасытный"},
        {npc=10440, name=L"Барон Ривендер"},
    },
}

-- Rooms. Inside a dungeon the game gives no position, but it names the room the player
-- stands in. A boss is found by that: the room he was seen or killed in is remembered,
-- and so is the order the rooms were first walked in. From the second run on the page
-- says which room the next boss is in, and which room lies on the way to it.
function P.Room()
    local function read(fn)
        if not fn then return end
        local ok, text = pcall(fn)
        text = ok and (atlas.PlainText and atlas.PlainText(text) or (not atlas.PlainText and text)) or nil
        return type(text) == "string" and text ~= "" and text or nil
    end
    return read(GetSubZoneText) or read(GetMinimapZoneText)
end

local function walked(d)
    local room = P.Room()
    if not (room and P.char) then return room, {} end
    P.char.path = P.char.path or {}
    local path = P.char.path[d.key] or {}
    P.char.path[d.key] = path
    for _, other in ipairs(path) do
        if other == room then return room, path end
    end
    path[#path+1] = room
    return room, path
end

local function remember(d, who, firm)
    local room = P.Room()
    if not (room and who and P.char) then return end
    P.char.rooms = P.char.rooms or {}
    local rooms = P.char.rooms[d.key] or {}
    P.char.rooms[d.key] = rooms
    -- Seen from the next room is a guess; killed in it is the place.
    if firm or not rooms[who] then rooms[who] = room end
end

-- A boss of the run came into sight: his room is noted.
function P.SawBoss(d, who)
    if d and who then remember(d, who, false) end
end

local function roomLine(d, who, here, path)
    local room = P.char and P.char.rooms and P.char.rooms[d.key] and P.char.rooms[d.key][who]
    if not room or room == atlas.DungeonName(d) then return end
    if room == here then return {L"|cff71c886ты в его зале|r"}, room end
    local i, j
    for index, other in ipairs(path) do
        if other == here then i = index end
        if other == room then j = index end
    end
    -- The names are the ones the game writes over the minimap: in quotes, so that a
    -- hall called after a machine is not read as the machine.
    local lines = {}
    if i and j and j > i + 1 then lines[#lines+1] = L"сначала через «" .. path[i + 1] .. "»" end
    lines[#lines+1] = ((i and j and j < i) and (L"его зал позади: «") or (L"его зал: «")) .. room .. "»"
    return lines, room
end

-- Bosses seen dead in this run. A run is forgotten after four hours or in another dungeon.
-- The owner, in the Library: "why the Scarlet Monastery when we are in the Library and see
-- the other bosses?" A wing is known by the hall one stands in, as the game names it:
-- written here for the halls known (Russian and English), learnt for the rest (the halls a
-- boss of the wing was seen or killed in, and those walked once the wing is known). Once
-- known inside, it is kept until the instance is left: the hall by the door may bear the
-- dungeon's own name.
local WING_HALLS = {
    SM = {
        [L"Кладбище"] = {"Чертог Искупления", "Покинутый двор", "Гробница Доблести", "Chamber of Atonement", "Forlorn Cloister", "Honor's Tomb"},
        [L"Библиотека"] = {"Двор охотника", "Сокровищница", "Читальня", "Huntsman's Cloister", "Gallery of Treasures", "Athenaeum"},
        [L"Оружейная"] = {"Training Grounds", "Footman's Armory", "Crusader's Armory", "Hall of Champions"},
        [L"Собор"] = {"Chapel Gardens", "Crusader's Chapel"},
    },
}
local wingNow  -- {key, name}: the wing the player is in, while inside
local function wingHere(d, wings)
    if not (d and P.InDungeon and P.InDungeon(d)) then wingNow = nil return end
    local room = P.Room and P.Room()
    if room == atlas.DungeonName(d) then room = nil end
    local name
    if room then
        local learnt = P.char and P.char.wingHalls and P.char.wingHalls[d.key]
        name = learnt and learnt[room]
        for wing, halls in pairs(not name and WING_HALLS[d.key] or {}) do
            for _, hall in ipairs(halls) do if hall == room then name = wing end end
        end
        local seen = not name and P.char and P.char.rooms and P.char.rooms[d.key]
        for npc, hall in pairs(seen or {}) do
            if hall == room then
                for _, part in ipairs(wings) do
                    for _, entry in ipairs(part.stops) do if entry.npc == npc then name = part.name end end
                end
            end
        end
    end
    if name then wingNow = {key=d.key, name=name}
    elseif wingNow and wingNow.key ~= d.key then wingNow = nil end
    name = wingNow and wingNow.name
    for _, part in ipairs(wings) do
        if part.name == name then
            -- A hall walked in it is the wing's from now on.
            if room and P.char then
                P.char.wingHalls = P.char.wingHalls or {}
                P.char.wingHalls[d.key] = P.char.wingHalls[d.key] or {}
                P.char.wingHalls[d.key][room] = part.name
            end
            return part
        end
    end
end
-- The name of the wing the player is in, for the heading of the page.
function P.WingHere(d)
    if not (d and P.InDungeon and P.InDungeon(d)) then wingNow = nil return end
    if P.Run then P.Run(d, {}, "all") end
    return wingNow and wingNow.key == d.key and wingNow.name or nil
end

local function fallen(d)
    local db = P.char
    if not db then return {} end
    local now = GetServerTime and GetServerTime() or 0
    if db.kills and (db.kills.key ~= d.key or now - (db.kills.at or 0) > 14400) then db.kills = nil end
    return db.kills or {}
end

local function bossName(stop)
    if stop.title then return stop.title end
    local heard = P.char and P.char.bossNames and P.char.bossNames[stop.npc]
    if type(heard) == "string" and heard ~= "" then return heard end
    local ok, name = pcall(function() return NpcDB and NpcDB.Get and NpcDB.Get(stop.npc, "name") end)
    -- (The new bosses of Forever have only their English names in the database: on a
    -- Russian client the name written here, "Вар'така", goes before "Var'Taka".)
    if ok and type(name) == "string" and GetLocale and GetLocale() == "ruRU" and not name:find("[\208\209]")
        and tostring(stop.name):find("[\208\209]") then return stop.name end
    return ok and type(name) == "string" and name ~= "" and name or stop.name
end

local function isBoss(stop, npc)
    if stop.npc == npc then return true end
    for _, other in ipairs(stop.also or {}) do
        if other == npc then return true end
    end
    return false
end

-- Which bosses a quest asks for: the ones to kill and the ones its things drop from.
-- Read from the database once for each quest.
local asked = {}
local function bossesOf(quest)
    if asked[quest] then return asked[quest] end
    local found = {kill={}, drops={}}
    pcall(function()
        local objectives = QuestDB.Get(quest, "objectives") or {}
        for _, creature in ipairs(objectives[1] or {}) do found.kill[creature[1]] = true end
        for _, item in ipairs(objectives[3] or {}) do
            local droppers = ItemDB and ItemDB.Get(item[1], "npcDrops") or {}
            if #droppers > 0 then found.drops[#found.drops+1] = droppers end
        end
    end)
    asked[quest] = found
    return found
end

-- The stops of the run for the page. A short run is shown whole. A long one is shown as
-- a window: how many are dead, the next few, the later ones a quest asks for, and how
-- many are left. A dungeon of several wings shows the wing the group is in, known by its
-- first dead boss; before that, each wing with the boss it starts with.
function P.Run(d, rows, whole)
    local run = d and runs[d.key]
    if d and not run then
        -- A dungeon nobody has written a run for, the new ones of Forever among them:
        -- the bosses the player has killed there before, in the order they fell.
        local learnt = P.char and P.char.learnt and P.char.learnt[d.key]
        if not learnt or #learnt == 0 then return end
        local dead, list = fallen(d), {}
        for _, name in ipairs(learnt) do
            list[#list+1] = {stop=true, name=name, dead=dead[name] and true or false, lines={}, told={}}
        end
        for i, entry in ipairs(list) do
            if not entry.dead then
                local later = false
                for j = i + 1, #list do later = later or list[j].dead end
                if not later then entry.next = true; break end
            end
        end
        local here, path = walked(d)
        for _, entry in ipairs(list) do
            local lines, room = roomLine(d, entry.name, here, path)
            if lines and not entry.dead and (entry.next or room == here) then
                for i, line in ipairs(lines) do table.insert(entry.lines, i, line) end
                entry.inRoom = room == here or nil
            end
        end
        return list
    end
    if not run then return end
    local faction = UnitFactionGroup("player")
    local open = {}
    for _, row in ipairs(rows or {}) do
        if row.state ~= "done" then open[#open+1] = row end
    end
    local dead = fallen(d)
    local bossIDs = {}
    for _, stop in ipairs(run) do
        if stop.npc then bossIDs[stop.npc] = true end
        for _, other in ipairs(stop.also or {}) do bossIDs[other] = true end
    end
    local all, wings, wing = {}, {}, nil
    for _, stop in ipairs(run) do
        if stop.wing then
            wing = {name=stop.wing, stops={}}
            wings[#wings+1] = wing
        elseif not stop.faction or stop.faction == faction then
            local entry = {stop=true, npc=stop.npc, name=bossName(stop), optional=stop.optional, lines={}, told={}, asks={}, todo={}, way=stop.way}
            entry.dead = dead[stop.npc] and true or false
            if stop.note and not entry.dead then entry.lines[#entry.lines+1] = stop.note end
            local written = {}
            for _, at in ipairs(stop.quests or {}) do written[at[1]] = at end
            for _, row in ipairs(open) do
                local quest = row.step or row.id
                -- Written by hand: what to do beside this boss, and once the quest is in
                -- the log, what is left of it there.
                local at = written[row.id] or written[quest]
                local line, sub = at and at[2], at and at.sub
                if at and at.taken and row.state == "active" then line, sub = at.taken, nil end
                if not line and not entry.dead then
                    local why
                    local wanted = bossesOf(quest)
                    for npc in pairs(wanted.kill) do
                        if isBoss(stop, npc) then why = L"убить" end
                    end
                    -- A thing the trash drops too is not a reason to name a boss: it has
                    -- to come from the bosses of the run alone.
                    for _, droppers in ipairs(wanted.drops) do
                        local his, others = false, false
                        for _, npc in ipairs(droppers) do
                            if isBoss(stop, npc) then his = true elseif not bossIDs[npc] then others = true end
                        end
                        if his and not others then why = why or (L"добыча с него") end
                    end
                    line = why and ("«" .. P.Title(quest) .. "»: " .. why)
                end
                if line then
                    -- Two quests at one machine are one line.
                    local said = false
                    for _, other in ipairs(entry.lines) do said = said or other == line end
                    if not said then
                        entry.lines[#entry.lines+1] = line
                        entry.asks[#entry.asks+1] = line
                        entry.todo[#entry.todo+1] = {text=line, sub=sub}
                    end
                    entry.told[row.id] = true
                end
            end
            entry.asked = next(entry.told) ~= nil
            all[#all+1] = entry
            if wing then wing.stops[#wing.stops+1] = entry; if entry.dead then wing.begun = true end end
        end
    end
    local function mark(list)
        local last = 0
        for i, entry in ipairs(list) do if entry.dead then last = i end end
        for i = last + 1, #list do
            if not list[i].dead and not list[i].optional then list[i].next = true; break end
        end
    end
    local here, path = walked(d)
    local function place(list)
        for _, entry in ipairs(list) do
            if entry.npc and not entry.dead then
                -- Up front: the halls the player has learnt by walking, which he can check
                -- against the name over the minimap; then the way in words, a step a line,
                -- until he stands in the boss's hall.
                local lines, room = roomLine(d, entry.npc, here, path)
                local front = {}
                if lines and (entry.next or room == here) then
                    for _, line in ipairs(lines) do front[#front+1] = line end
                    entry.inRoom = room == here or nil
                end
                if entry.next and entry.way and not (lines and room == here) then
                    for _, line in ipairs(type(entry.way) == "table" and entry.way or {entry.way}) do front[#front+1] = line end
                end
                entry.front = #front
                for i, line in ipairs(front) do table.insert(entry.lines, i, line) end
            end
        end
    end
    local shown = {}
    -- Inside a wing known: its bosses alone, the next one marked.
    local inWing = #wings > 0 and wingHere(d, wings)
    if inWing then
        mark(inWing.stops)
        place(inWing.stops)
        shown[#shown+1] = {stop=true, dim=true, wing=whole == "all" or nil, name=inWing.name, lines={}}
        for _, entry in ipairs(inWing.stops) do shown[#shown+1] = entry end
        return shown
    end
    if #wings > 0 and whole == "all" then
        -- The whole dungeon for the list of bosses: every wing under its name, the dead
        -- with the living. The next boss is marked in the wing the group has begun.
        for _, part in ipairs(wings) do
            if part.begun then
                mark(part.stops)
                place(part.stops)
            end
            shown[#shown+1] = {stop=true, dim=true, wing=true, name=part.name, lines={}}
            for _, entry in ipairs(part.stops) do shown[#shown+1] = entry end
        end
        return shown
    end
    if #wings > 0 then
        local begun = false
        for _, part in ipairs(wings) do begun = begun or part.begun end
        for _, part in ipairs(wings) do
            if begun and part.begun then
                mark(part.stops)
                place(part.stops)
                shown[#shown+1] = {stop=true, dim=true, name=part.name, lines={}}
                for _, entry in ipairs(part.stops) do shown[#shown+1] = entry end
            elseif not begun then
                local first = part.stops[1]
                for _, entry in ipairs(part.stops) do if not entry.optional then first = entry; break end end
                local lines = {L"первый босс: " .. (first and first.name or "?")}
                local told = {}
                for _, entry in ipairs(part.stops) do
                    -- A boss a quest asks for is named even before the wing is begun.
                    for id in pairs(entry.told) do told[id] = true end
                    -- The quest, once: which of the wing's bosses it asks for is said when
                    -- the group is in the wing. With the names the line ran to three.
                    for _, line in ipairs(entry.asks) do
                        local said = false
                        for _, other in ipairs(lines) do said = said or other == line end
                        if not said then lines[#lines+1] = line end
                    end
                end
                shown[#shown+1] = {stop=true, wingRow=true, name=part.name .. L" • боссов: " .. #part.stops, lines=lines, told=told}
            end
        end
        return shown
    end
    mark(all)
    place(all)
    if whole or #all <= 9 then return all end
    local gone, ahead, hidden = 0, 0, 0
    for _, entry in ipairs(all) do
        if entry.dead then
            gone = gone + 1
        elseif ahead < 5 or entry.asked then
            ahead = ahead + 1
            shown[#shown+1] = entry
        else
            hidden = hidden + 1
        end
    end
    if gone > 0 then table.insert(shown, 1, {stop=true, dim=true, name=L"убито боссов: " .. gone, lines={}}) end
    if hidden > 0 then shown[#shown+1] = {stop=true, dim=true, name=L"и ещё боссов: " .. hidden, lines={}} end
    return shown
end

-- The marks of the dead belong to one run. The owner came back two hours later with
-- another group, to a dungeon reset, and was led past two bosses that stood alive: the
-- group asked "do we jump" and the page had hidden the boss below. So: walking in with
-- marks older than three quarters of an hour is a new run; a boss marked dead and seen
-- alive is a new run; and /dq run says so by hand.
function P.HasRun(d) return d and runs[d.key] ~= nil end

function P.NewRun()
    if P.char then P.char.kills = nil end
end

function P.EnterRun(d)
    local kills = P.char and P.char.kills
    if not (d and kills) then return false end
    local now = GetServerTime and GetServerTime() or 0
    if kills.key ~= d.key or now - (kills.at or 0) > 2700 then
        P.char.kills = nil
        return true
    end
    return false
end

function P.Revived(d, npc, name)
    local kills = d and P.char and P.char.kills
    if not kills or kills.key ~= d.key then return false end
    local run = runs[d.key]
    if run then
        for _, stop in ipairs(run) do
            if stop.npc and kills[stop.npc] and ((npc and stop.npc == npc) or (not npc and name and (name == stop.name or name == bossName(stop)))) then
                P.char.kills = nil
                return true
            end
        end
    elseif name and kills[name] then
        P.char.kills = nil
        return true
    end
    return false
end

-- A boss struck off or put back by hand: the right button on his line. The game does not
-- always tell an addon that a boss is dead.
function P.ToggleKilled(d, npc, name)
    if not (d and P.char) then return end
    local key = npc or name
    if not key then return end
    local dead = fallen(d)
    P.char.kills = P.char.kills or {}
    P.char.kills.key = d.key
    if dead[key] then
        P.char.kills[key] = nil
    else
        P.char.kills[key] = true
        P.char.kills.at = GetServerTime and GetServerTime() or 0
    end
    return true
end

-- A boss is dead when the thing only he drops is in the bags: no event is needed for
-- that. Looked at for the quests of the page.
function P.InferKills(d, rows)
    local run = d and runs[d.key]
    if not (run and P.char and ItemDB and ItemDB.Get) then return false end
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    if not count then return false end
    local news = false
    pcall(function()
        for _, row in ipairs(rows or {}) do
            if row.state == "active" then
                local objectives = QuestDB.Get(row.step or row.id, "objectives") or {}
                for _, item in ipairs(objectives[3] or {}) do
                    if (count(item[1]) or 0) > 0 then
                        local his
                        for _, npc in ipairs(ItemDB.Get(item[1], "npcDrops") or {}) do
                            for _, stop in ipairs(run) do
                                if stop.npc == npc then his = his == nil and npc or false end
                            end
                        end
                        if his and P.Killed(d, his) then news = true end
                    end
                end
            end
        end
    end)
    return news
end

-- The living bosses of the run, for the sign over the head: by number where a run is
-- written, by name where it was learnt.
-- What the run says of a boss, by his number: how he comes out, where he stands.
function P.StopNote(npc)
    if not npc then return end
    for _, run in pairs(runs) do
        for _, stop in ipairs(run) do
            if stop.npc == npc or (stop.also and tContains and tContains(stop.also, npc)) then return stop.note, stop.way end
        end
    end
end

function P.RunBosses(d)
    if not d then return end
    local dead = fallen(d)
    local list = {ids={}, names={}}
    local run = runs[d.key]
    if run then
        for _, stop in ipairs(run) do
            if stop.npc and not dead[stop.npc] then
                list.ids[stop.npc] = stop.npc
                for _, other in ipairs(stop.also or {}) do list.ids[other] = stop.npc end
            end
        end
    else
        for _, name in ipairs(P.char and P.char.learnt and P.char.learnt[d.key] or {}) do
            if not dead[name] then list.names[name] = true end
        end
    end
    if next(list.ids) == nil and next(list.names) == nil then return end
    return list
end

-- Whether the run is over: the last boss that has to be killed is dead. In a dungeon
-- of several wings, the last one of a wing.
function P.RunDone(d)
    local run = d and runs[d.key]
    if not run then return false end
    local dead = fallen(d)
    local last
    local function over() return last ~= nil and dead[last] == true end
    for _, stop in ipairs(run) do
        if stop.wing then
            if over() then return true end
            last = nil
        elseif stop.npc and not stop.optional then
            last = stop.npc
        end
    end
    return over()
end

-- A boss of the run seen dead, by number or by name. True when that is news.
-- The owner, at "killed 0 of 8" on a dungeon he had just been through: "I have killed
-- bosses already". The marks of a run are for the run and go with it; that a boss was
-- ever killed is kept for good, and the book says it outside a run.
local function everMark(d, who)
    if not (d and who and P.char) then return end
    P.char.ever = P.char.ever or {}
    P.char.ever[d.key] = P.char.ever[d.key] or {}
    P.char.ever[d.key][who] = true
end

function P.EverKilled(d, npc, name)
    local known = d and P.char and P.char.ever and P.char.ever[d.key]
    if not known then return false end
    return (npc and known[npc] or name and known[name]) and true or false
end

-- Once: what was known before this was kept. The halls of the bosses were noted as
-- they were met and killed, and the marks of a run under way are kills.
function P.SeedEver()
    local db = P.char
    if not db or db.everSeeded then return end
    db.everSeeded = true
    for key, halls in pairs(db.rooms or {}) do
        for who in pairs(halls) do everMark({key=key}, who) end
    end
    if db.kills and db.kills.key then
        for who, on in pairs(db.kills) do
            if on == true then everMark({key=db.kills.key}, who) end
        end
    end
end

function P.Killed(d, npc, name)
    local run = d and runs[d.key]
    if d and not run and P.char and name then
        -- No run written: the kill is learnt, by the name the game gives it. Two events
        -- can tell of one kill under two names; the second within moments is the same kill.
        local now = GetServerTime and GetServerTime() or 0
        local dead = fallen(d)
        if dead[name] then return false end
        P.char.learnt = P.char.learnt or {}
        local learnt = P.char.learnt[d.key] or {}
        P.char.learnt[d.key] = learnt
        local known = false
        for _, other in ipairs(learnt) do known = known or other == name end
        if not known then
            if P.char.learntAt and now - P.char.learntAt < 15 then return false end
            learnt[#learnt+1] = name
        end
        P.char.learntAt = now
        P.char.kills = P.char.kills or {}
        P.char.kills.key, P.char.kills.at = d.key, now
        P.char.kills[name] = true
        everMark(d, name)
        remember(d, name, true)
        return true
    end
    if not (run and P.char) then return false end
    for _, stop in ipairs(run) do
        if stop.npc and ((npc and isBoss(stop, npc)) or (name and (name == stop.name or name == bossName(stop)))) then
            -- (The name the client gives him, kept: the new bosses are written with the
            -- English names where the Russian ones were not known.)
            if npc and name and name ~= stop.name and GetLocale and GetLocale() == "ruRU" and not tostring(stop.name):find("[\208\209]") then
                P.char.bossNames = P.char.bossNames or {}
                P.char.bossNames[stop.npc] = name
            end
            local dead = fallen(d)
            if dead[stop.npc] then return false end
            P.char.kills = P.char.kills or {}
            P.char.kills.key, P.char.kills.at = d.key, GetServerTime and GetServerTime() or 0
            P.char.kills[stop.npc] = true
            everMark(d, stop.npc)
            remember(d, stop.npc, true)
            return true
        end
    end
    return false
end

-- ------------------------------------------
-- Another continent
-- ------------------------------------------
-- An arrow cannot point across the sea. The shortest way over is named instead: the
-- mage's own teleport when it is known, otherwise the nearest zeppelin or ship, and the
-- arrow leads there. Once the player is on the right continent the arrow moves on to
-- the place itself. Classic transport; the points are the towers and the docks.
local cities = {
    Horde = {
        {spell=3567, mapID=1454, name=L"Оргриммар"},
        {spell=3566, mapID=1456, name=L"Громовой Утёс"},
        {spell=3563, mapID=1458, name=L"Подгород"},
    },
    Alliance = {
        {spell=3561, mapID=1453, name=L"Штормград"},
        {spell=3562, mapID=1455, name=L"Стальгорн"},
        {spell=3565, mapID=1457, name=L"Дарнас"},
    },
}
-- A zeppelin tower has a platform for each zeppelin, and on each stands its master.
-- The arrow leads to the master of the zeppelin wanted, so the platform cannot be mistaken:
-- npc is that master (place and name are read from the quest database, the numbers here
-- are only the fallback). ride: what to board. land and arrive: where it sets down.
local hops = {
    Horde = {
        {npc=9566, mapID=1420, x=60.7, y=58.9, from=L"вышка у Подгорода", up=true, ride=L"дирижабль в Оргриммар",
            land=L"вышка у ворот Оргриммара", arrive={mapID=1411, x=50.8, y=13.5}},
        {npc=3150, mapID=1420, x=61.8, y=59.2, from=L"вышка у Подгорода", up=true, ride=L"дирижабль в Гром'гол",
            land=L"лагерь Гром'гол, север Тернистой долины", arrive={mapID=1434, x=31.5, y=29.6}},
        {npc=3149, mapID=1434, x=31.4, y=29.9, from=L"вышка в Гром'голе", up=true, ride=L"дирижабль в Оргриммар",
            land=L"вышка у ворот Оргриммара", arrive={mapID=1411, x=50.8, y=13.5}},
        {npc=12137, mapID=1434, x=31.5, y=29.4, from=L"вышка в Гром'голе", up=true, ride=L"дирижабль в Подгород",
            land=L"вышка у Подгорода", arrive={mapID=1420, x=60.7, y=58.9}},
        {npc=9564, mapID=1411, x=50.8, y=13.5, from=L"вышка у Оргриммара", up=true, ride=L"дирижабль в Подгород",
            land=L"вышка у Подгорода", arrive={mapID=1420, x=60.7, y=58.9}},
        {npc=12136, mapID=1411, x=50.7, y=12.9, from=L"вышка у Оргриммара", up=true, ride=L"дирижабль в Гром'гол",
            land=L"лагерь Гром'гол, север Тернистой долины", arrive={mapID=1434, x=31.5, y=29.6}},
        {npc=9559, mapID=1434, x=26.1, y=73.3, from=L"причал в Пиратской Бухте", ride=L"корабль в Кабестан",
            land=L"Кабестан, Степи", arrive={mapID=1413, x=63.7, y=38.6}},
        {mapID=1413, x=63.7, y=38.6, from=L"причал в Кабестане", ride=L"корабль в Пиратскую Бухту",
            land=L"Пиратская Бухта", arrive={mapID=1434, x=26.1, y=73.3}},
    },
    Alliance = {
        {mapID=1437, x=4.8, y=60.0, from=L"причал в Гавани Менетилов", ride=L"корабль в Терамор",
            land=L"остров Терамор", arrive={mapID=1445, x=71.5, y=56.4}},
        {mapID=1437, x=4.8, y=60.0, from=L"причал в Гавани Менетилов", ride=L"корабль в Аубердин",
            land=L"Аубердин", arrive={mapID=1439, x=32.4, y=43.8}},
        {npc=9559, mapID=1434, x=26.1, y=73.3, from=L"причал в Пиратской Бухте", ride=L"корабль в Кабестан",
            land=L"Кабестан, Степи", arrive={mapID=1413, x=63.7, y=38.6}},
        {mapID=1445, x=71.5, y=56.4, from=L"причал в Тераморе", ride=L"корабль в Гавань Менетилов",
            land=L"Гавань Менетилов", arrive={mapID=1437, x=4.8, y=60.0}},
        {mapID=1439, x=32.4, y=43.8, from=L"причал в Аубердине", ride=L"корабль в Гавань Менетилов",
            land=L"Гавань Менетилов", arrive={mapID=1437, x=4.8, y=60.0}},
        {mapID=1413, x=63.7, y=38.6, from=L"причал в Кабестане", ride=L"корабль в Пиратскую Бухту",
            land=L"Пиратская Бухта", arrive={mapID=1434, x=26.1, y=73.3}},
    },
}

-- Once: the master's own place and name from the database, and the name of the point.
local settled
local function settle()
    if settled then return end
    settled = true
    for _, list in pairs(hops) do
        for _, point in ipairs(list) do
            local keeper = point.npc and atlas.Places and atlas.Places["npc:" .. point.npc]
            if keeper and keeper.mapID == point.mapID and keeper.x and keeper.y then
                point.x, point.y, point.keeper = keeper.x, keeper.y, keeper.name
            end
            -- The sign over the head is hung on the master by this number.
            point.npcID = point.npc
            point.title = point.ride:sub(1, 2):gsub(L"^д", L"Д"):gsub(L"^к", L"К") .. point.ride:sub(3)
        end
    end
end

-- The platforms and docks on one map, for labels on the world map.
function P.Landmarks(mapID)
    settle()
    local list = {}
    for _, point in ipairs(hops[UnitFactionGroup("player")] or {}) do
        if point.mapID == mapID then list[#list+1] = {x=point.x, y=point.y, text=point.ride} end
    end
    return list
end

local function knows(spell)
    local checks = {}
    if C_SpellBook and C_SpellBook.IsSpellKnown then checks[#checks+1] = C_SpellBook.IsSpellKnown end
    if IsPlayerSpell then checks[#checks+1] = IsPlayerSpell end
    if IsSpellKnown then checks[#checks+1] = IsSpellKnown end
    for _, check in ipairs(checks) do
        local ok, known = pcall(check, spell)
        if ok and known and not (issecretvalue and issecretvalue(known)) then return true end
    end
    return false
end

local function continentOf(mapID)
    if not (mapID and atlas.ContinentOf and C_Map and C_Map.GetMapInfo) then return end
    local ok, continent = pcall(atlas.ContinentOf, mapID)
    return ok and continent or nil
end

function P.PlayerContinent()
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not here or (issecretvalue and issecretvalue(here)) then return end
    return continentOf(here)
end

function P.Overseas(place)
    local from, to = P.PlayerContinent(), continentOf(place and place.mapID)
    return from ~= nil and to ~= nil and from ~= to
end

-- The shortest way to a place, counted in what is left to walk. Weighed against each
-- other: walking straight there, every teleport the mage knows, every zeppelin and ship,
-- and a teleport followed by one of those. nil when walking straight is best.
-- Otherwise: spell and city when the way starts with a teleport; point, title, ride and
-- land when it starts with a run to a tower or a dock (after a teleport that leg is
-- under .next); rest is the walk at the far end, walk the whole of it.
-- A cast, a rune and the way out of a city are worth this much walking. A teleport has
-- to save more than that to be worth a step of its own on the way.
local TELEPORT = 300

local function blindPlan(place)
    -- A ghost casts nothing and boards nothing: it runs.
    if UnitIsGhost and UnitIsGhost("player") then return end
    local from, to = P.PlayerContinent(), continentOf(place and place.mapID)
    if not from or not to then return end
    settle()
    local faction = UnitFactionGroup("player")
    local here = C_Map.GetBestMapForUnit("player")
    local span = atlas.Span or function() end

    -- The best zeppelin or ship from one continent to another, starting at a point
    -- (nil is where the player stands).
    local function rides(origin, continent, list)
        for _, point in ipairs(hops[faction] or {}) do
            if continentOf(point.mapID) == continent and continentOf(point.arrive.mapID) == to then
                local start
                if origin then start = span(origin, point)
                else local _, _, distance = atlas.NavigationVector(point); start = distance end
                local rest = span(point.arrive, place)
                list[#list+1] = {point=point, title=point.title, text=point.ride .. ", " .. point.from, ride=point.ride, land=point.land,
                    keeper=point.keeper, up=point.up, start=start, rest=rest, walk=start and rest and (start + rest)}
            end
        end
        return list
    end
    local function order(list)
        for i, way in ipairs(list) do way.order = i; way.cost = way.walk and (way.walk + (way.spell and TELEPORT or 0)) end
        table.sort(list, function(a, b)
            if (a.cost ~= nil) ~= (b.cost ~= nil) then return a.cost ~= nil end
            if a.cost and a.cost ~= b.cost then return a.cost < b.cost end
            -- No map to measure by: a teleport first, then the nearest start.
            if (a.spell ~= nil) ~= (b.spell ~= nil) then return a.spell ~= nil end
            if a.start and b.start and a.start ~= b.start then return a.start < b.start end
            return a.order < b.order
        end)
        return list
    end

    local ways = {}
    local direct
    if from == to then
        -- In the zone of the place itself there is nothing to weigh: walk.
        if here == place.mapID then return end
        local _, _, distance = atlas.NavigationVector(place)
        -- Without a distance to weigh against there is no saying a teleport is shorter.
        if not distance then return end
        direct = {direct=true, text=L"пешком напрямую", walk=distance}
        ways[1] = direct
    end
    -- A zeppelin can shorten a way within one continent too: Undercity to Grom'gol.
    rides(nil, from, ways)
    for _, c in ipairs(cities[faction] or {}) do
        if not place.noCast and here ~= c.mapID and knows(c.spell) then
            local continent, centre = continentOf(c.mapID), {mapID=c.mapID, x=50, y=50}
            if continent == to then
                -- Measured from the middle of the city; with no map to measure by, a place
                -- in the city itself still counts as next door.
                local rest = span(centre, place) or (c.mapID == place.mapID and 0 or nil)
                ways[#ways+1] = {text=L"телепорт: " .. c.name, spell=c.spell, city=c.name, rest=rest, walk=rest}
            end
            if continent then
                local onward = order(rides(centre, continent, {}))[1]
                if onward and onward.walk then
                    ways[#ways+1] = {text=L"телепорт: " .. c.name .. L", затем " .. onward.ride, spell=c.spell, city=c.name, next=onward,
                        rest=onward.rest, walk=onward.walk}
                end
            end
        end
    end
    order(ways)
    local best = ways[1]
    if not best then return from ~= to and {to=to, text=L"нужен транспорт на другой континент", others={}} or nil end
    if best.direct then return end
    -- On one continent a teleport or a zeppelin is a detour: it is named only when it
    -- at least halves the walk. Anything closer than that is walked.
    if direct and (not best.cost or best.cost > direct.walk / 2) then return end
    local plan = {to=to, text=best.text, spell=best.spell, city=best.city, point=best.point, title=best.title, ride=best.ride, land=best.land,
        keeper=best.keeper, up=best.up,
        start=best.start, rest=best.rest, walk=best.walk, next=best.next, direct=direct and direct.walk, others={}}
    for i = 2, #ways do plan.others[#plan.others+1] = {text=ways[i].text, walk=ways[i].walk} end
    return plan
end

-- ------------------------------------------
-- Flight masters
-- ------------------------------------------
-- Every flight master of the old world by his number; where each stands and what he is
-- called is read from the quest database. Both lists hold the neutral ones.
local masters = {
    Horde = {1387, 2226, 2389, 2851, 2858, 2861, 2995, 3305, 3310, 3615, 4312, 4314, 4317, 4551, 6026, 6726, 7824, 8020, 8610,
        10378, 10583, 11139, 11899, 11900, 11901, 12616, 12636, 12740, 13177, 15178, 16227},
    Alliance = {352, 523, 931, 1571, 1572, 1573, 2299, 2409, 2432, 2835, 2859, 2941, 3838, 3841, 4267, 4319, 4321, 4407, 6706,
        7823, 8018, 8019, 8609, 10583, 10897, 11138, 12577, 12578, 12596, 12617, 15177, 16227},
}
-- The town, where the zone alone does not say which point is meant. Used until the
-- game's own name of the point is learnt from the flight map.
local towns = {
    [3615]=L"Перекрёсток", [10378]=L"Лагерь Таурахо", [16227]=L"Кабестан", [1387]=L"Гром'гол", [2858]=L"Пиратская Бухта", [2859]=L"Пиратская Бухта",
    [11901]=L"застава Зорам'гар", [12616]=L"застава Расщепленного Дерева", [2389]=L"Мельница Таррен", [2861]=L"Каргат",
}

-- A cast, a rune and the way out of a city are worth TELEPORT yards of running (above).
-- A zeppelin or a ship is waited for and sailed: RIDE. A flight: the talk and the take-off,
-- and then the wings are WINGS times faster than the feet.
local RIDE, TAKEOFF, WINGS = 600, 100, 4.3
local sqrt, floor = math.sqrt, math.floor

-- Every point a way can pass through, measured once: city centres, docks and towers with
-- their landings, flight masters.
-- ------------------------------------------
-- Passes between zones
-- ------------------------------------------
-- The game tells an addon nothing of the ground: no hills, no cliffs, no roads. What can
-- be known is where one zone opens into the next: the road through the pass, the bridge,
-- the tunnel, the lift. A walk into another zone is led through those, not straight over
-- the mountains between. Each is two spots, one on either side of the border, on the maps
-- of the two zones. The table is filled from what is written of the old world; a pass the
-- player walks through is learnt from the feet (db.passes) and stands above the table.
-- PASSES BEGIN
local passes = {
    {a=1411, ax=45.5, ay=12.2, b=1454, bx=52.5, by=84.4},   -- главные ворота Оргриммара
    {a=1454, ax=18.0, ay=60.5, b=1413, bx=63.9, by=0.0},   -- западный выход Оргриммара
    {a=1411, ax=34.7, ay=42.3, b=1413, bx=62.2, by=19.4},   -- мост через Южную Ярость
    {a=1413, ax=48.9, ay=5.5, b=1440, bx=69.1, by=86.9},   -- дорога у Вала Мор'шан
    {a=1413, ax=35.2, ay=27.8, b=1442, bx=82.5, by=98.5},   -- тропа в гору к Малака'джину
    {a=1413, ax=41.9, ay=58.6, b=1412, bx=68.6, by=60.6},   -- перевал западнее Лагеря Таурахо
    {a=1413, ax=44.2, ay=91.3, b=1441, bx=31.9, by=24.2},   -- Великий Подъёмник
    {a=1413, ax=50.5, ay=78.7, b=1445, bx=29.9, by=47.3},   -- дорога в Пылевые топи
    {a=1440, ax=42.3, ay=71.0, b=1442, bx=78.2, by=42.9},   -- туннель Глубинный путь
    {a=1440, ax=29.2, ay=15.0, b=1439, bx=43.7, by=94.7},   -- дорога на север
    {a=1440, ax=55.9, ay=31.7, b=1448, bx=54.9, by=92.7},   -- дорога на север мимо Приюта
    {a=1440, ax=94.6, ay=47.6, b=1447, bx=10.7, by=75.3},   -- дорога на восток
    {a=1448, ax=65.0, ay=8.4, b=1452, bx=28.0, by=34.6},   -- туннель Крепости Древобрюхов
    {a=1448, ax=65.0, ay=8.4, b=1450, bx=35.8, by=72.2},   -- туннель Крепости Древобрюхов, ветка в Лунную поляну
    {a=1443, ax=53.4, ay=5.6, b=1442, bx=30.2, by=75.6},   -- дорога на север
    {a=1443, ax=41.0, ay=90.5, b=1444, bx=45.5, by=2.9},   -- дорога на юг
    {a=1444, ax=89.1, ay=41.1, b=1441, bx=8.0, by=10.9},   -- дорога на восток
    {a=1441, ax=74.1, ay=92.5, b=1446, bx=50.7, by=24.3},   -- каньон на юг от гоночной трассы
    {a=1446, ax=27.1, ay=57.2, b=1449, bx=71.4, by=77.2},   -- спуск в кратер
    {a=1449, ax=29.3, ay=22.3, b=1451, bx=83.7, by=14.3},   -- северный подъём из кратера
    {a=1412, ax=37.6, ay=33.0, b=1456, bx=35.7, by=63.1},   -- южные подъёмники Громового Утёса
    {a=1412, ax=42.1, ay=20.2, b=1456, bx=51.2, by=31.5},   -- северные подъёмники Громового Утёса
    {a=1438, ax=36.3, ay=54.4, b=1457, bx=85.7, by=35.9},   -- ворота Дарнаса
    {a=1429, ax=32.3, ay=49.9, b=1453, bx=73.3, by=90.7},   -- ворота Штормграда
    {a=1429, ax=22.3, ay=78.2, b=1436, bx=60.9, by=19.0},   -- мост на дороге
    {a=1429, ax=93.2, ay=72.3, b=1433, bx=9.0, by=71.9},   -- дорога на восток
    {a=1431, ax=93.8, ay=11.4, b=1433, bx=7.1, by=89.3},   -- дорога у Трёх Углов
    {a=1431, ax=10.6, ay=63.8, b=1436, bx=68.9, by=63.0},   -- дорога
    {a=1431, ax=44.5, ay=87.6, b=1434, bx=40.7, by=3.8},   -- дорога на юг
    {a=1431, ax=89.9, ay=41.3, b=1430, bx=33.1, by=36.0},   -- дорога на восток
    {a=1430, ax=58.3, ay=41.4, b=1435, bx=5.8, by=60.8},   -- дорога на восток
    {a=1435, ax=33.9, ay=66.0, b=1419, bx=52.0, by=5.6},   -- дорога на юг
    {a=1433, ax=46.5, ay=8.6, b=1428, bx=78.9, by=82.5},   -- перевал Чёрной горы
    {a=1427, ax=76.6, ay=56.7, b=1418, bx=1.1, by=62.9},   -- горная тропа
    {a=1432, ax=47.2, ay=80.8, b=1418, bx=49.4, by=8.0},   -- дорога на юг
    {a=1432, ax=19.6, ay=62.8, b=1426, bx=86.1, by=51.2},   -- туннель Южных врат
    {a=1432, ax=19.2, ay=17.2, b=1426, bx=84.4, by=31.1},   -- туннель Северных врат
    {a=1432, ax=25.4, ay=10.6, b=1437, bx=53.9, by=70.3},   -- перевал Дун Альгаз
    {a=1426, ax=53.4, ay=35.0, b=1455, bx=21.6, by=77.8},   -- ворота Стальгорна
    {a=1437, ax=51.1, ay=11.8, b=1417, bx=45.4, by=89.1},   -- мост Тандол
    {a=1417, ax=20.2, ay=29.7, b=1424, bx=82.0, by=56.9},   -- ворота Стены Торадина
    {a=1424, ax=14.4, ay=46.3, b=1421, bx=66.5, by=79.6},   -- дорога
    {a=1424, ax=55.5, ay=16.6, b=1416, bx=51.2, by=65.6},   -- дорога на север
    {a=1424, ax=84.6, ay=31.6, b=1425, bx=9.7, by=55.8},   -- горная тропа у Дарнхольда
    {a=1421, ax=67.2, ay=5.3, b=1420, bx=54.1, by=75.8},   -- дорога
    {a=1420, ax=61.9, ay=65.0, b=1458, bx=66.0, by=36.9},   -- ворота руин Лордерона и лифты
    {a=1420, ax=51.1, ay=71.5, b=1458, bx=21.9, by=43.4},   -- выход через стоки
    {a=1420, ax=84.1, ay=70.5, b=1422, bx=28.6, by=57.5},   -- Бастион
    {a=1416, ax=80.7, ay=36.4, b=1422, bx=44.0, by=86.2},   -- дорога
    {a=1422, ax=69.7, ay=50.2, b=1423, bx=8.8, by=66.2},   -- дорога через реку
}
-- PASSES END
P.Passes = passes

-- The zone a map belongs to: a cave or a building counts as the zone around it.
local function zoneOf(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local guard = 0
    while info and info.mapType and info.mapType > 3 and info.parentMapID and info.parentMapID ~= 0 and guard < 5 do
        mapID = info.parentMapID
        info = C_Map.GetMapInfo(mapID)
        guard = guard + 1
    end
    return mapID
end

-- The lifts between a city and its zone: Thunder Bluff is on a mesa (down to Mulgore), the
-- Undercity under the ground (up to Tirisfal).
local LIFTS = {[1456]={zone=1412, dir="down"}, [1458]={zone=1420, dir="up"}}
local nets, joined, gameNodes = {}, {}, {}
local function net(faction)
    if nets[faction] then return nets[faction] end
    settle()
    local list, found = {}, 0
    local function add(node)
        local ok, c, X, Y = pcall(atlas.Yards, node.place)
        if not (ok and c and X and Y) then return end
        node.c, node.X, node.Y = c, X, Y
        node.zone = zoneOf(node.place.mapID)
        list[#list+1] = node
        return node
    end
    -- The passes: the ones walked through first, then the table where no walked one of the
    -- same two zones lies within two hundred yards. Zones joined by passes, however many
    -- on the way, share a number in "joined": between those nobody walks straight.
    local group = {}
    local function root(zone)
        while group[zone] and group[zone] ~= zone do zone = group[zone] end
        return zone
    end
    local kept = {}
    local function pass(entry, learnt)
        local a = {kind="pass", learnt=learnt, place={mapID=entry.a, x=entry.ax, y=entry.ay}}
        local b = {kind="pass", learnt=learnt, place={mapID=entry.b, x=entry.bx, y=entry.by}}
        local okA, cA, aX, aY = pcall(atlas.Yards, a.place)
        local okB, cB, bX, bY = pcall(atlas.Yards, b.place)
        if not (okA and okB and cA and cB and aX and bX and cA == cB) then return end
        local zoneA, zoneB = zoneOf(entry.a), zoneOf(entry.b)
        if zoneA == zoneB then return end
        for _, other in ipairs(kept) do
            -- Side by side: each end measured against the end in the same zone.
            local dx, dy
            if other.za == zoneA and other.zb == zoneB then dx, dy = other.X - aX, other.Y - aY
            elseif other.za == zoneB and other.zb == zoneA then dx, dy = other.X - bX, other.Y - bY end
            if dx and dx*dx + dy*dy < 200*200 then return end
        end
        kept[#kept+1] = {za=zoneA, zb=zoneB, X=aX, Y=aY}
        add(a); add(b)
        a.pair, b.pair = b, a
        -- A city on a mesa or under the ground is left by its lift (the owner on the lift of
        -- Thunder Bluff, 15.11.2026: "it hangs on 'pass between zones'; I stand still and it
        -- walks"): said as the lift it is.
        local lift = LIFTS[entry.a] and LIFTS[entry.a].zone == entry.b and {city=entry.a, dir=LIFTS[entry.a].dir}
            or LIFTS[entry.b] and LIFTS[entry.b].zone == entry.a and {city=entry.b, dir=LIFTS[entry.b].dir}
        for _, side in ipairs({a, b}) do
            local far = side.pair
            local hint = L"проход между зонами"
            if lift then
                local fromCity = side.place.mapID == lift.city
                local down = (lift.dir == "down") == fromCity
                hint = down and L"спустись на подъёмнике" or L"поднимись на подъёмнике"
            end
            side.point = {mapID=side.place.mapID, x=side.place.x, y=side.place.y, hint=hint}
            side.title = L"Проход: " .. atlas.ZoneName(far.zone)
        end
        group[zoneA], group[zoneB] = group[zoneA] or zoneA, group[zoneB] or zoneB
        group[root(zoneA)] = root(zoneB)
    end
    for _, entry in ipairs(P.char and type(P.char.passes) == "table" and P.char.passes or {}) do pass(entry, true) end
    for _, entry in ipairs(P.Passes or {}) do pass(entry) end
    joined = {}
    for zone in pairs(group) do joined[zone] = root(zone) end
    for _, c in ipairs(cities[faction] or {}) do add({kind="city", city=c, place={mapID=c.mapID, x=50, y=50}}) end
    for _, point in ipairs(hops[faction] or {}) do
        local land = add({kind="land", place=point.arrive})
        if land then add({kind="dock", hop=point, place=point, land=land}) end
    end
    for _, npc in ipairs(masters[faction] or {}) do
        local place = atlas.Places and atlas.Places["npc:" .. npc]
        if place and place.mapID and place.x and place.y then
            local node = add({kind="master", npc=npc, place=place})
            if node then
                found = found + 1
                node.point = {mapID=place.mapID, x=place.x, y=place.y, npc=npc, npcID=npc, name=place.name, keeper=place.name,
                    from=L"распорядитель полётов " .. place.name}
            end
        end
    end
    -- Before the database is read there are no masters: count again next time.
    if found > 0 then nets[faction] = list end
    return list
end

-- The world measured anew: the points are counted again at the next way asked for.
function P.Remeasure()
    nets, joined = {}, {}
    for key in pairs(gameNodes) do gameNodes[key] = nil end
end

-- The flight points this character has, by continent, learnt each time the flight map
-- opens. Before that nothing is known and every point is taken as open.
local function seenOn(continent)
    local taxi = P.char and P.char.taxi
    local seen = taxi and taxi[continent]
    return type(seen) == "table" and type(seen.known) == "table" and seen or nil
end

-- What the game itself says of the flight points of a continent, without the flight map
-- open (seen on Forever: C_TaxiMap.GetTaxiNodesForMap gives every point with its name, its
-- place, its faction and isUndiscovered). Each master is given the point of his faction
-- nearest to him: names[npc], and open[npc] for the points not marked undiscovered. Where
-- not one point of the continent is marked so, the mark is not trusted and open is nil.
local function gameSays(continent)
    local kept = gameNodes[continent]
    local now = GetTime and GetTime() or 0
    if kept and now - kept.at < 30 then return kept.found end
    local found = false
    if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_Map and C_Map.GetMapWorldSize then
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, continent)
        local width, height = C_Map.GetMapWorldSize(continent)
        local faction = UnitFactionGroup("player")
        local own = faction == "Horde" and 1 or faction == "Alliance" and 2 or 0
        if ok and type(nodes) == "table" and #nodes > 0 and width and height then
            local names, open, closed = {}, {}, 0
            for _, master in ipairs(nets[faction] or {}) do
                if master.kind == "master" and master.c == continent then
                    local best, near
                    for _, node in ipairs(nodes) do
                        local pos = node.position
                        local x, y
                        if type(pos) == "table" then
                            x, y = pos.x, pos.y
                            if pos.GetXY then x, y = pos:GetXY() end
                        end
                        local theirs = node.faction == nil or node.faction == 0 or node.faction == own
                        if theirs and type(x) == "number" and type(y) == "number" and type(node.name) == "string" then
                            local dx, dy = x*width - master.X, y*height - master.Y
                            local gap = dx*dx + dy*dy
                            if not near or gap < near then best, near = node, gap end
                        end
                    end
                    if best and near <= 250*250 then
                        names[master.npc] = best.name
                        if best.isUndiscovered == true then closed = closed + 1 else open[master.npc] = true end
                    end
                end
            end
            found = {names=names, open=closed > 0 and open or nil}
        end
    end
    gameNodes[continent] = {at=now, found=found}
    return found
end

-- Whether a point can be flown to: by the flight map last opened; else by what the game
-- says; else, nothing known, yes.
local function flownTo(node)
    local seen = seenOn(node.c)
    if seen then return seen.known[node.npc] ~= nil end
    local game = gameSays(node.c)
    if game and game.open then return game.open[node.npc] == true end
    return true
end

-- What a point is called, and whether it is known to be open.
local function flightName(node)
    local seen = seenOn(node.c)
    local learnt = seen and seen.known[node.npc]
    if type(learnt) == "string" then return learnt, true end
    local game = gameSays(node.c)
    if game and game.names[node.npc] then return game.names[node.npc], game.open ~= nil end
    local zone = atlas.ZoneName(node.place.mapID)
    local town = towns[node.npc]
    return (town and town ~= zone) and (town .. ", " .. zone) or zone, false
end

-- The flight points of the player's faction on one continent, for the world map, the
-- undiscovered ones too (the owner: "I want to see them even under the fog of war").
-- Each: npc, place, name (the town alone), full (the game's whole name), keeper (the
-- master), open: true, false, or nil where nothing is known yet.
function P.FlightPoints(continent)
    local list = {}
    if not continent then return list end
    local seen = seenOn(continent)
    local game = not seen and gameSays(continent) or nil
    for _, node in ipairs(net(UnitFactionGroup("player"))) do
        if node.kind == "master" and node.c == continent then
            local full = flightName(node)
            local open
            if seen then open = seen.known[node.npc] ~= nil
            elseif game and game.open then open = game.open[node.npc] == true end
            list[#list+1] = {npc=node.npc, place=node.place, full=full, name=full:match("^(.-),") or full,
                keeper=node.place.name, open=open, X=node.X, Y=node.Y}
        end
    end
    return list
end

-- An undiscovered flight point the walk passes by, or one beside the goal: worth the few
-- steps to open it (the mock of 15.11.2026: "Flight point on the way: Kargath"). The
-- goal on the continent the player stands on; a point counts when going by it costs at
-- most a fifth of the straight walk (and four hundred yards), or it stands within three
-- hundred yards of the player or of the goal. Returns the point and "way" or "goal".
function P.FlightOnWay(goal)
    if not (goal and goal.mapID) then return end
    local okHere, sc, sX, sY = pcall(atlas.PlayerYards)
    if not (okHere and sc and sX and sY) then return end
    local okGoal, gc, gX, gY = pcall(atlas.Yards, goal)
    local onGoal = okGoal and gc == sc and gX and gY
    local direct = onGoal and sqrt((gX - sX)^2 + (gY - sY)^2) or nil
    local best, bestCost, where
    for _, point in ipairs(P.FlightPoints(sc)) do
        if point.open == false and point.X and point.Y then
            local mine = sqrt((point.X - sX)^2 + (point.Y - sY)^2)
            local theirs = onGoal and sqrt((point.X - gX)^2 + (point.Y - gY)^2) or nil
            local detour = direct and (mine + theirs - direct) or nil
            local kind = (theirs and theirs <= 300) and "goal"
                or (mine <= 300 or (detour and detour <= math.min(400, direct * .2 + 100))) and "way" or nil
            local cost = detour or mine
            if kind and (not bestCost or cost < bestCost) then best, bestCost, where = point, cost, kind end
        end
    end
    return best, where
end

-- The quickest way by the map: every leg weighed in yards of running. nil when the game
-- gives no place to measure from. Returns the quickest way of all, the quickest on foot
-- alone, and the straight line.
local function route(place, here)
    if not (atlas.Yards and atlas.PlayerYards) then return end
    local okGoal, gc, gX, gY = pcall(atlas.Yards, place)
    if not (okGoal and gc and gX and gY) then return end
    local okHere, sc, sX, sY = pcall(atlas.PlayerYards)
    if not (okHere and sc and sX and sY) then return end
    local nodes = {{kind="start", c=sc, X=sX, Y=sY, zone=zoneOf(here)}, {kind="goal", c=gc, X=gX, Y=gY, zone=zoneOf(place.mapID)}}
    -- Only the points of the two continents in question are looked at.
    for _, node in ipairs(net(UnitFactionGroup("player"))) do
        if node.c == sc or node.c == gc then nodes[#nodes+1] = node end
    end
    local count = #nodes
    local function span(a, b)
        if a.c ~= b.c then return end
        local dx, dy = a.X - b.X, a.Y - b.Y
        return sqrt(dx*dx + dy*dy)
    end
    -- On foot: straight within a zone; into another zone straight only where no chain of
    -- passes joins the two (then nothing better is known).
    local function walk(a, b)
        if a.c ~= b.c then return end
        if a.zone ~= b.zone then
            local ja, jb = joined[a.zone], joined[b.zone]
            if ja and jb and ja == jb then return end
        end
        return span(a, b)
    end
    local spells = {}
    local function cast(city)
        -- (noCast: the player put the teleport away by its cross; the way is counted without a cast.)
        if spells[city] == nil then spells[city] = not place.noCast and here ~= city.mapID and knows(city.spell) end
        return spells[city]
    end
    local function search(feet)
        local dist, prev, via, done = {0}, {}, {}, {}
        local function relax(u, v, cost, kind)
            if cost and (not dist[v] or dist[u] + cost < dist[v]) then dist[v], prev[v], via[v] = dist[u] + cost, u, kind end
        end
        while true do
            local u
            for i = 1, count do
                if dist[i] and not done[i] and (not u or dist[i] < dist[u]) then u = i end
            end
            if not u or u == 2 then break end
            done[u] = true
            local a = nodes[u]
            for v = 2, count do
                if not done[v] then
                    local b = nodes[v]
                    if a.kind == "pass" and b == a.pair then
                        relax(u, v, span(a, b), "pass")
                    elseif b.kind == "city" then
                        if not feet and u == 1 and cast(b.city) then relax(u, v, TELEPORT, "teleport") end
                    elseif a.kind == "dock" then
                        if not feet and b == a.land then relax(u, v, RIDE, "ride") end
                    elseif b.kind == "pass" or not feet or v == 2 then
                        if b.kind ~= "land" then
                            relax(u, v, walk(a, b), "walk")
                            -- A master not opened yet can still be flown from: he is opened by
                            -- the talk. The point flown to has to be open.
                            if not feet and a.kind == "master" and b.kind == "master" and a.c == b.c then
                                if flownTo(b) then relax(u, v, TAKEOFF + span(a, b) / WINGS, "fly") end
                            end
                        end
                    end
                end
            end
        end
        if not dist[2] then return end
        local chain, v = {}, 2
        while v ~= 1 do table.insert(chain, 1, v); v = prev[v] end
        local legs, pending, total, at, wheels, ship = {}, 0, 0, 1, false, false
        for _, index in ipairs(chain) do
            local a, b, kind = nodes[at], nodes[index], via[index]
            if kind == "walk" then
                local yards = span(a, b)
                pending, total = pending + yards, total + yards
            elseif kind == "pass" then
                local yards = span(a, b)
                -- Standing at the mouth of the pass, the way is its far side.
                local near = #legs == 0 and pending <= 60
                legs[#legs+1] = {kind="pass", pass=true, point=near and b.point or a.point, title=a.title, text=L"проход: " .. atlas.ZoneName(b.zone),
                    start=near and pending + yards or pending, learnt=a.learnt}
                pending, total = near and 0 or yards, total + yards
            elseif kind == "teleport" then
                legs[#legs+1] = {kind="teleport", spell=b.city.spell, city=b.city.name, text=L"телепорт: " .. b.city.name}
                pending, wheels = 0, true
            elseif kind == "ride" then
                local point = a.hop
                legs[#legs+1] = {kind="ride", point=point, title=point.title, text=point.ride .. ", " .. point.from, ride=point.ride, land=point.land,
                    keeper=point.keeper, up=point.up, start=pending}
                pending, wheels, ship = 0, true, true
            else
                local name, sure = flightName(b)
                legs[#legs+1] = {kind="fly", fly=true, point=a.point, title=L"Перелёт: " .. name, ride=L"перелёт: " .. name, land=name,
                    text=L"перелёт: " .. name .. " (" .. a.point.from .. ")", keeper=a.place.name, start=pending, unsure=not sure or nil}
                pending = 0
            end
            at = index
        end
        return {to=gc, legs=legs, rest=pending, walk=total, cost=dist[2], wheels=wheels, ship=ship}
    end
    return search(false), sc == gc and search(true) or nil, sc == gc and span(nodes[1], nodes[2]) or nil
end

-- The ways of the last counts, by place, kept for the time in the air: over the land
-- below nothing is weighed again until the wings set down. But the flight itself is
-- under way then, so the way is what comes after it. (The owner, on the wyvern, with
-- the arrow still on the flight master behind him: "I have flown off already, and it
-- still leads me back.")
local aloft = {}
local function spotKey(place)
    return place.mapID .. ":" .. tostring(place.x) .. ":" .. tostring(place.y)
end

function P.Plan(place)
    if UnitIsGhost and UnitIsGhost("player") then return end
    if not (place and place.mapID) then return blindPlan(place) end
    if UnitOnTaxi and UnitOnTaxi("player") then
        local kept = aloft[spotKey(place)]
        if not (kept and kept.legs) then return end
        -- The flight taken is the first flight of the way: what is left begins after it.
        local from
        for i, leg in ipairs(kept.legs) do
            if leg.fly then from = i + 1 break end
        end
        local first = from and kept.legs[from]
        -- Nothing after the flight but the walk: the place itself.
        if not first then return end
        if not kept.after then
            local legs, texts = {}, {}
            for i = from, #kept.legs do
                legs[#legs+1] = kept.legs[i]
                texts[#texts+1] = #legs == 1 and kept.legs[i].text or kept.legs[i].ride or kept.legs[i].text
            end
            kept.after = {to=kept.to, legs=legs, rest=kept.rest, others={}, text=table.concat(texts, L", затем "),
                point=first.point, title=first.title, ride=first.ride, land=first.land, keeper=first.keeper, up=first.up,
                fly=first.fly, unsure=first.unsure, pass=first.pass, inFlight=true}
        end
        return kept.after
    end
    -- A goal in a cave near a dungeon (the Garrett chest in the Uldaman tunnels): outside,
    -- the way leads to the mouth of the cave; in it, straight to the place.
    if place.cave then
        if IsIndoors and IsIndoors() then return end
        local d = atlas.DungeonByKey and atlas.DungeonByKey[place.cave]
        local mouth = d and atlas.Entrance and atlas.Entrance(d)
        if not (mouth and mouth.mapID) then return end
        local spot = {mapID=mouth.mapID, x=mouth.x, y=mouth.y}
        local onward = P.Plan(spot)
        if onward then return onward end
        local _, _, far = atlas.NavigationVector(spot)
        if far and far > 30 then
            local title = L"Вход в пещеру: " .. atlas.DungeonName(d)
            spot.hint = L"дальше внутри пещеры"
            return {point=spot, title=title, legs={{point=spot, title=title, text=title}}, text=title, onFoot=true, cave=true, others={}}
        end
        return
    end
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local found, feet, straight = route(place, here)
    -- No map to measure by, or no way found on it: the old count by what is known.
    if not found then return blindPlan(place) end
    local key = spotKey(place)
    aloft[key] = nil
    -- Next door in the zone of the place itself nothing is weighed: walk.
    if straight and here == place.mapID and straight < 1500 then return end
    -- A way round by the passes three times the straight line is a table gone wrong
    -- rather than a mountain: the straight line stands.
    if feet and straight and feet.cost > straight * 3 + 300 then feet = {legs={}, rest=straight, walk=straight, cost=straight} end
    local ridden
    for _, leg in ipairs(found.legs) do if not leg.pass then ridden = true end end
    if ridden and feet then
        -- On one continent anything but the feet is a detour. A teleport or a flight is
        -- named when it saves a fifth of the way on foot and three hundred yards at least.
        -- (It was half for a teleport once, and the owner, a mage in Strahnbrad bound for
        -- the Monastery, was sent three kilometres through the Plaguelands with the
        -- Undercity teleport a third shorter.) A zeppelin or a boat, waited for at the
        -- tower, still has to halve it.
        if found.cost > feet.cost * (found.ship and .5 or .8) or feet.cost - found.cost < 300 then ridden = false end
    end
    if not ridden then
        if not feet then return end
        found = feet
    end
    local first = found.legs[1]
    if not first then return end
    local plan = {to=found.to, legs=found.legs, rest=found.rest, walk=found.walk, cost=found.cost, direct=feet and feet.cost or nil,
        straight=straight, onFoot=not ridden or nil, others={}}
    local texts = {}
    for i, leg in ipairs(found.legs) do texts[#texts+1] = i == 1 and leg.text or leg.ride or leg.text end
    plan.text = table.concat(texts, L", затем ")
    if first.kind == "teleport" then
        plan.spell, plan.city = first.spell, first.city
        plan.next = found.legs[2]
        if plan.next then plan.next.rest, plan.next.walk = found.rest, found.walk end
    else
        plan.point, plan.title, plan.ride, plan.land, plan.keeper, plan.up = first.point, first.title, first.ride, first.land, first.keeper, first.up
        plan.start, plan.fly, plan.unsure, plan.pass = first.start, first.fly, first.unsure, first.pass
    end
    aloft[key] = plan
    return plan
end

-- A pass walked through is learnt: the last spot stood on in one zone and the first in
-- the next, a second apart. A jump (a teleport, a hearthstone, a zeppelin) teaches nothing,
-- nor does a flight.
local trail
local function learnPass(before, now)
    if not P.char then return end
    P.char.passes = type(P.char.passes) == "table" and P.char.passes or {}
    for _, known in ipairs(P.char.passes) do
        local same = (known.a == before.zone and known.b == now.zone) or (known.a == now.zone and known.b == before.zone)
        if same then
            local spot = known.a == before.zone and before or now
            local dx, dy = (known.ax - spot.x), (known.ay - spot.y)
            -- Map hundredths, not yards: three of them is the same pass.
            if dx*dx + dy*dy < 9 then return end
        end
    end
    if #P.char.passes >= 300 then return end
    local function round(v) return floor(v * 100 + .5) / 100 end
    table.insert(P.char.passes, {a=before.zone, ax=round(before.x), ay=round(before.y), b=now.zone, bx=round(now.x), by=round(now.y),
        at=GetServerTime and GetServerTime() or 0})
    P.Remeasure()
end

function P.Footstep()
    if (UnitOnTaxi and UnitOnTaxi("player")) or (IsInInstance and IsInInstance()) then trail = nil return end
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not here or (issecretvalue and issecretvalue(here)) then trail = nil return end
    local zone = zoneOf(here)
    local ok, c, X, Y = pcall(atlas.PlayerYards)
    local pos = ok and c and C_Map.GetPlayerMapPosition(zone, "player")
    if not pos then trail = nil return end
    local x, y = pos:GetXY()
    if not x or not y or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then trail = nil return end
    local now = {zone=zone, c=c, X=X, Y=Y, x=x*100, y=y*100}
    local before = trail
    trail = now
    if before and before.zone ~= zone and before.c == c then
        local dx, dy = before.X - X, before.Y - Y
        if dx*dx + dy*dy <= 120*120 then learnPass(before, now) end
    end
end

-- The flight map is open: read which points this character has. A point is matched to
-- its master by the master stood next to, then by the zone or city in its name, then by
-- its place on the flight map, fitted to the points already matched.
local function taxiNodes()
    local nodes = {}
    if NumTaxiNodes and TaxiNodeName and TaxiNodeGetType then
        local ok, count = pcall(NumTaxiNodes)
        for i = 1, ok and tonumber(count) or 0 do
            local okKind, kind = pcall(TaxiNodeGetType, i)
            local okName, name = pcall(TaxiNodeName, i)
            local okPlace, x, y
            if TaxiNodePosition then okPlace, x, y = pcall(TaxiNodePosition, i) end
            if okKind and okName and type(name) == "string" and (kind == "CURRENT" or kind == "REACHABLE") then
                nodes[#nodes+1] = {name=name, x=okPlace and tonumber(x) or nil, y=okPlace and tonumber(y) or nil, here=kind == "CURRENT"}
            end
        end
        if #nodes > 0 then return nodes, "old" end
    end
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        local okMap, map = pcall(GetTaxiMapID or function() end)
        local ok, all = pcall(C_TaxiMap.GetAllTaxiNodes, okMap and map or nil)
        local states = Enum and Enum.FlightPathState or {}
        local current, reachable = states.Current or 0, states.Reachable or 1
        for _, node in ipairs(ok and type(all) == "table" and all or {}) do
            if type(node.name) == "string" and (node.state == current or node.state == reachable) then
                local x, y
                if type(node.position) == "table" and node.position.GetXY then x, y = node.position:GetXY() end
                nodes[#nodes+1] = {name=node.name, x=tonumber(x), y=tonumber(y), here=node.state == current}
            end
        end
    end
    return nodes, "new"
end

function P.LearnFlights()
    if not P.char then return end
    local nodes, api = taxiNodes()
    if #nodes == 0 then return end
    if atlas.ForgetNearbyFlights then atlas.ForgetNearbyFlights() end
    local ok, c, pX, pY = pcall(atlas.PlayerYards)
    if not (ok and c and pX and pY) then return end
    local list = {}
    for _, node in ipairs(net(UnitFactionGroup("player"))) do
        if node.kind == "master" and node.c == c then list[#list+1] = node end
    end
    local known, taken, matched = {}, {}, 0
    local function match(node, master)
        known[master.npc], taken[master], node.master = node.name, true, master
        matched = matched + 1
    end
    for _, node in ipairs(nodes) do
        if node.here then
            local best, far
            for _, master in ipairs(list) do
                local dx, dy = master.X - pX, master.Y - pY
                local yards = sqrt(dx*dx + dy*dy)
                if not far or yards < far then best, far = master, yards end
            end
            if best and far <= 200 then match(node, best) end
        end
    end
    local wanted = {}
    for _, node in ipairs(nodes) do
        if not node.master then
            local town, zone = node.name:match("^(.-),%s*(.+)$")
            town = town or node.name
            node.options = {}
            for _, master in ipairs(list) do
                local name = atlas.ZoneName(master.place.mapID)
                if not taken[master] and (name == zone or name == town) then
                    node.options[#node.options+1] = master
                    wanted[master] = (wanted[master] or 0) + 1
                end
            end
        end
    end
    for _, node in ipairs(nodes) do
        local only = not node.master and #node.options == 1 and node.options[1]
        if only and wanted[only] == 1 and not taken[only] then match(node, only) end
    end
    local function fit(axis, coord)
        local n, sw, st, sww, swt = 0, 0, 0, 0, 0
        for _, node in ipairs(nodes) do
            if node.master and node[axis] then
                local w, t = node.master[coord], node[axis]
                n, sw, st, sww, swt = n + 1, sw + w, st + t, sww + w*w, swt + w*t
            end
        end
        local spread = n*sww - sw*sw
        -- The matched points have to stand well apart, or the fit says nothing.
        if n < 2 or spread / (n*n) < 250000 then return end
        local a = (n*swt - sw*st) / spread
        return a, (st - a*sw) / n
    end
    local ax, bx = fit("x", "X")
    local ay, by = fit("y", "Y")
    if ax and ay then
        for _, node in ipairs(nodes) do
            if not node.master and node.x and node.y then
                local best, near, second
                for _, master in ipairs(list) do
                    if not taken[master] then
                        local dx, dy = ax*master.X + bx - node.x, ay*master.Y + by - node.y
                        local gap = sqrt(dx*dx + dy*dy)
                        if not near or gap < near then best, second, near = master, near, gap
                        elseif not second or gap < second then second = gap end
                    end
                end
                if best and near < .04 and (not second or near < second * .5) then match(node, best) end
            end
        end
    end
    local extra, raw = {}, {}
    for i, node in ipairs(nodes) do
        if not node.master then extra[#extra+1] = node.name end
        if i <= 60 then raw[i] = {name=node.name, x=node.x, y=node.y, here=node.here or nil, npc=node.master and node.master.npc or nil} end
    end
    -- What was read, as it was read: to check the matching by.
    P.char.taxiRaw = {api=api, continent=c, nodes=raw}
    P.char.taxi = type(P.char.taxi) == "table" and P.char.taxi or {}
    local before = seenOn(c)
    -- Fewer than half of the points matched: the names here are not what was expected.
    -- Better to know nothing than to rule out the points that are open.
    if matched * 2 < #nodes then
        P.char.taxi[c] = nil
        return
    end
    P.char.taxi[c] = {at=GetServerTime and GetServerTime() or 0, known=known, extra=extra, count=#nodes}
    if (not before or before.count ~= #nodes) and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(L"|cffedc36fDungeon Quest Forever|r • запомнил твои точки перелётов: " .. matched .. L" из " .. #nodes
            .. L". Теперь дорога считается с ними.")
    end
    -- The owner, at the flight master of Undercity: "I have no flight there." The way had
    -- been counted before his points were known, and flew to Kargath. Now they are: the way
    -- to the goal is counted again and the arrow set anew where it differs.
    local goal, target = P.char.goal, atlas.Target and atlas.Target()
    if goal and target and goal.mapID then
        local plan = P.Plan(goal)
        if plan and plan.point then
            if target.title ~= plan.title or target.mapID ~= plan.point.mapID or target.x ~= plan.point.x or target.y ~= plan.point.y then
                atlas.AddMarker(plan.point, plan.title, "entrance")
            end
        elseif not plan and (target.mapID ~= goal.mapID or target.x ~= goal.x or target.y ~= goal.y) then
            atlas.AddMarker(goal, goal.label, goal.kind, goal.id)
        end
    end
    if P.Refresh then pcall(P.Refresh) end
end

-- The owner, at the flight master the way led to: "can we light up on the flight map
-- where we have to fly?" The point the way flies to gets a light and the pointing hand on
-- the game's flight map, and its name is said once.
local taxiMark
local function flightWanted()
    -- Seen in the game: the panel and the arrow said "Flight: Freewind Post", the hand on
    -- the flight map stood on Brackenwall. The point lit is the one the arrow and the panel
    -- show; a way counted again only where they show no flight.
    local heading = atlas.Target and atlas.Target()
    local prefix = L"Перелёт: "
    local title = heading and type(heading.title) == "string" and heading.title
    if title and title:sub(1, #prefix) == prefix and #title > #prefix then return title:sub(#prefix + 1) end
    local goal = P.char and P.char.goal
    local plan = goal and P.Plan(goal)
    for _, leg in ipairs(plan and plan.legs or {}) do
        if leg.fly then return leg.land end
    end
    return plan and plan.fly and plan.land or nil
end
function P.MarkFlight()
    if taxiMark then taxiMark:Hide() end
    local land = flightWanted()
    if not (land and NumTaxiNodes and TaxiNodeName) then return end
    -- The name as it stands first; else the town before the comma, the same on both sides
    -- (a name found inside another, or an empty one, once lit the wrong point).
    local function town(name) return (name:match("^(.-),") or name):gsub("^%s+", ""):gsub("%s+$", "") end
    local ok, count = pcall(NumTaxiNodes)
    local shown = {}
    for i = 1, ok and tonumber(count) or 0 do
        local okName, name = pcall(TaxiNodeName, i)
        local button = _G["TaxiButton" .. i]
        if okName and type(name) == "string" and name ~= "" and button and button.IsShown and button:IsShown() then
            shown[#shown+1] = {name=name, button=button}
        end
    end
    local pick
    for _, node in ipairs(shown) do if node.name == land then pick = node break end end
    if not pick and town(land) ~= "" then
        for _, node in ipairs(shown) do if town(node.name) == town(land) then pick = node break end end
    end
    if P.char then
        P.char.flightLog = {land=land, lit=pick and pick.name or false, shown=#shown,
            at=GetServerTime and GetServerTime() or 0}
    end
    if pick then
        local name, button = pick.name, pick.button
        do
            if not taxiMark then
                taxiMark = CreateFrame("Frame", "DungeonQuestForeverTaxiMark", UIParent)
                taxiMark:SetSize(40, 40)
                taxiMark:SetFrameStrata("DIALOG")
                taxiMark:EnableMouse(false)
                taxiMark.glow = taxiMark:CreateTexture(nil, "BACKGROUND")
                taxiMark.glow:SetTexture("Interface\\Cooldown\\star4")
                taxiMark.glow:SetBlendMode("ADD")
                taxiMark.glow:SetVertexColor(.4, 1, .45)
                taxiMark.glow:SetSize(72, 72)
                taxiMark.glow:SetPoint("CENTER")
                taxiMark.hand = taxiMark:CreateTexture(nil, "OVERLAY")
                taxiMark.hand:SetSize(30, 30)
                taxiMark.hand:SetPoint("BOTTOM", taxiMark, "TOP", 0, -6)
                local faction = UnitFactionGroup and UnitFactionGroup("player")
                local hand = faction == "Horde" and "hand_horde" or faction == "Alliance" and "hand_alliance" or "arrow"
                taxiMark.hand:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\" .. hand)
                if taxiMark.hand.SetRotation then taxiMark.hand:SetRotation(math.pi) end
                pcall(function()
                    local pulse = taxiMark.glow:CreateAnimationGroup()
                    pulse:SetLooping("BOUNCE")
                    local fade = pulse:CreateAnimation("Alpha")
                    fade:SetFromAlpha(.35)
                    fade:SetToAlpha(1)
                    fade:SetDuration(.6)
                    taxiMark.pulse = pulse
                end)
            end
            taxiMark:SetParent(button:GetParent() or UIParent)
            taxiMark:SetFrameStrata("DIALOG")
            taxiMark:ClearAllPoints()
            taxiMark:SetPoint("CENTER", button, "CENTER")
            taxiMark:Show()
            if taxiMark.pulse then taxiMark.pulse:Play() end
            taxiMark.name = name
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(L"|cffedc36fDungeon Quest Forever|r • лети в: " .. name) end
            return name
        end
    end
end

do
    local watch = CreateFrame and CreateFrame("Frame", "DungeonQuestForeverFlights", UIParent)
    if watch and watch.RegisterEvent then
        pcall(watch.RegisterEvent, watch, "TAXIMAP_OPENED")
        pcall(watch.RegisterEvent, watch, "TAXIMAP_CLOSED")
        watch:SetScript("OnEvent", function(_, event)
            if event == "TAXIMAP_CLOSED" then
                if taxiMark then taxiMark:Hide() end
                return
            end
            -- The game fills the map a moment after it opens.
            local function opened() pcall(P.LearnFlights); pcall(P.MarkFlight) end
            if C_Timer and C_Timer.After then C_Timer.After(.3, opened) else opened() end
        end)
        local since = 0
        watch:SetScript("OnUpdate", function(_, elapsed)
            since = since + (elapsed or 0)
            if since < 1 then return end
            since = 0
            pcall(P.Footstep)
        end)
    end
end

P.Crossing = P.Plan

-- Set the arrow for a step the player asked for, by the shortest way. The goal is kept;
-- the way to it is counted again as the player moves, so each leg hands over to the next.
function P.Mark(place, label, kind, id)
    local plan = P.Plan(place)
    if P.char then
        P.char.goal = (plan or place.cave) and {mapID=place.mapID, x=place.x, y=place.y, npcID=place.npcID, name=place.name, label=label, kind=kind, id=id, cave=place.cave,
            at=GetServerTime and GetServerTime() or 0} or nil
    end
    if plan and plan.point then atlas.AddMarker(plan.point, plan.title, "entrance")
    else atlas.AddMarker(place, label, kind, id) end
    return plan
end

-- Called as the player moves about: a leg done (a teleport cast, a zeppelin ridden) and
-- the arrow turns to the next. Returns the name of the goal when only the walk is left.
function P.Replan()
    local goal = P.char and P.char.goal
    local target = atlas.Target and atlas.Target()
    -- A goal in a cave set before the cave was known (kept over a /reload): set again, so
    -- that the way leads to the mouth (the owner, 15.11.2026: "the spot is the same as before").
    local cave = P.QuestCave and target and target.kind == "objective" and target.questID and P.QuestCave[target.questID]
    if cave and not target.cave then
        local place = {mapID=target.mapID, x=target.x, y=target.y, npcID=target.npcID, name=target.who, cave=cave}
        P.Mark(place, target.title, "objective", target.questID)
        return
    end
    if goal and goal.kind == "objective" and goal.id and not goal.cave and P.QuestCave and P.QuestCave[goal.id] then
        local place = {mapID=goal.mapID, x=goal.x, y=goal.y, npcID=goal.npcID, name=goal.name, cave=P.QuestCave[goal.id]}
        P.Mark(place, goal.label, "objective", goal.id)
        return
    end
    -- In the air the flight master is behind: the arrow goes on to what comes after the
    -- flight, the next leg or the place itself. The goal is kept, to be counted again
    -- where the wings set down.
    if UnitOnTaxi and UnitOnTaxi("player") then
        if not (goal and target) then return end
        local plan = P.Plan(goal)
        local want = plan and plan.point or goal
        if target.mapID ~= want.mapID or target.x ~= want.x or target.y ~= want.y then
            if plan and plan.point then atlas.AddMarker(plan.point, plan.title, "entrance")
            else atlas.AddMarker(goal, goal.label, goal.kind, goal.id) end
        end
        return
    end
    -- The pad taken: a point left on it, and a goal behind it, move on to the portal.
    local function same(a, b) return a and a.mapID == b.mapID and a.x == b.x and a.y == b.y end
    local known = {}
    for key in pairs(doors) do known[key] = true end
    for key in pairs(inner) do known[key] = true end
    for key in pairs(P.char and P.char.portals or {}) do known[key] = true end
    for key in pairs(P.char and P.char.doorPick or {}) do known[key] = true end
    if P.char and P.char.cameOut then known[P.char.cameOut.key] = true end
    local inside = IsInInstance and IsInInstance()
    for key in pairs(known) do
        local d = atlas.DungeonByKey and atlas.DungeonByKey[key]
        local pad = d and own(d)
        -- A point the player chose, or the way out after a run, is done with on arrival:
        -- the arrow goes, and the road is the usual one again.
        local pick = P.char and P.char.doorPick and P.char.doorPick[key]
        if d and inside and pick then P.char.doorPick[key] = nil; pick = nil end
        if d and not inside and (pick or cameOut(d)) and atlas.NavigationVector then
            local spot = P.Door(d)
            local _, _, far = atlas.NavigationVector(spot)
            if far and far <= 15 then
                if P.char.doorPick then P.char.doorPick[key] = nil end
                if P.char.cameOut and P.char.cameOut.key == key then P.char.cameOut = nil end
                if target and target.kind == "entrance" and same(target, spot) then
                    atlas.RemoveMarker(target)
                    target = nil
                    if goal and same(goal, spot) then P.char.goal = nil; goal = nil end
                end
            end
        end
        if pad and (same(goal, pad) or (target and target.kind == "entrance" and same(target, pad))) and arrived(d) then
            local real = P.Door(d)
            local label = P.DoorLabel(d)
            if goal and same(goal, pad) then P.char.goal = nil; goal = nil end
            atlas.AddMarker(real, label, "entrance")
            return label
        end
        -- A point on the mouth of the cave, when the door is the portal by now, moves on.
        local door, mouth = d and P.Door(d), d and atlas.Entrance(d)
        if door and target and target.kind == "entrance" and not same(target, door)
            and (target.door == key or (mouth and same(target, mouth))) and not (pad and same(target, pad)) then
            atlas.AddMarker(door, P.DoorLabel(d), "entrance")
            target = atlas.Target()
        end
        -- A point set on the pad under its old name, "the door", is given its own name.
        if pad and pad.title then
            if same(goal, pad) then goal.label = pad.title end
            if target and target.kind == "entrance" and same(target, pad) and target.title ~= pad.title then
                atlas.AddMarker(pad, pad.title, "entrance")
                target = atlas.Target()
            end
        end
    end
    if not goal then return end
    if not target then
        P.char.goal = nil       -- the point was taken off by hand, or its step is over
        return
    end
    local plan = P.Plan(goal)
    local want = plan and plan.point or goal
    local moved = target.mapID ~= want.mapID or target.x ~= want.x or target.y ~= want.y
    if moved then
        if plan and plan.point then atlas.AddMarker(plan.point, plan.title, "entrance")
        else atlas.AddMarker(goal, goal.label, goal.kind, goal.id) end
    end
    -- (A goal in a cave is kept: leave the cave and the way to its mouth is set again.)
    if not plan and not goal.cave then
        P.char.goal = nil
        return moved and goal.label or nil
    end
end
