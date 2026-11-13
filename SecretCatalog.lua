local _, P = ...
local L = P.L or function(s) return s end
local catalog = {}
P.SecretCatalog = catalog

-- A multi-dungeon discovery has the same instructions at each relevant stop.
local function add(keys, note)
    for key in keys:gmatch("%S+") do
        catalog[key] = catalog[key] or {}
        table.insert(catalog[key], note)
    end
end

add("SFK DALARAN", {
    kind = L"Скрытый босс",
    title = L"Книга Аругала и Lyn the Ignored",
    plan = "lyn",
    sources = {
        "https://www.wowhead.com/forever/news/how-to-find-the-secret-boss-in-the-city-of-dalaran-dungeon-in-wow-forever-383366",
        "https://www.wowhead.com/forever/item=276561/black-tome",
    },
    L"После победы над Аругалом в Крепости Тёмного Клыка нажми на книгу в глубине комнаты. Забери Black Tome.",
    L"В Серебряном бору используй книгу рядом с Ambermill Leyline Focus в крепости Янтарной Мельницы. Получишь Tome of Dalaran. Фокус стоит в ратуше (63.4, 64.3).",
    L"В данже Даларана после первого босса иди по канализации прямо мимо поворота направо к поверхности. Используй том у фиолетовой руны в конце тоннеля.",
})

add("SFK", {
    kind = L"Для мага",
    title = L"Coldflame Saber из клинка Сильверлейна",
    class = "MAGE",
    sources = {
        "https://warcraft.wiki.gg/wiki/Scroll_of_the_Saber",
        "https://warcraft.wiki.gg/wiki/Coldflame_Saber",
    },
    L"Сохрани Blade of Silverlaine из крепости. При расшифровке магических свитков можно получить Scroll of the Saber.",
    L"Используй Scroll of the Saber на клинке. Получится меч мага Coldflame Saber.",
})

add("SFK", {
    kind = L"Редкая встреча",
    title = L"Капитан служителей Смерти",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/shadowfang-keep/deathsworn-captain-rare",
    },
    L"В крепости может появиться дополнительный капитан-призрак. Ищи его командой /targetexact Капитан служителей Смерти. Встреча случайная.",
})

add("DM BFD SFK", {
    kind = L"Классовая цепочка",
    title = L"Три данжа для оружия паладина-отрекшегося",
    class = "PALADIN",
    race = "Scourge",
    prep = L"Сначала спаси Lumina Windsinger на острове Фенрис и возьми задание на материалы.",
    sources = {
        "https://azeroth.wiki/news/wow-forever-wolfs-bane",
    },
    L"После спасения «Люмина Виндсингер» на острове Фенрис пройди к заданию на три материала. В Мёртвых копях нужен «Древесина белокаменного дуба», в Крепости Тёмного Клыка — Enchanted Silver Ingot.",
    L"Для «Очищенный самоцвет Кора» сначала обратись к Olric Frostvale в Ясеневом лесу, затем иди в Непроглядную Пучину. Собранные материалы отнеси кузнецу Orrt в Мельницу Таррен.",
})

add("LORDAERON", {
    kind = L"Скрытый босс",
    title = L"Камин в сгоревшем доме",
    sources = {
        "https://www.method.gg/wow-forever/dungeons/ruins-of-lordaeron",
    },
    L"Соберись с группой у камина в сгоревшем доме на юго-западе руин. Восстановите ману и нажмите на огонь.",
    L"Отбейте пять волн нежити. На шестой появляется Viktor the Vile.",
})

add("LORDAERON", {
    kind = L"Скрытый босс",
    title = L"Статуя на Рыночной площади",
    sources = {
        "https://wowforeverinfo.com/guides/ruins-of-lordaeron/",
    },
    L"Пройдите мимо кладбища во двор и подойдите к статуе со светящимися глазами.",
    L"После трёх волн нежити из коридоров появится The Abandoned.",
})

add("LORDAERON", {
    kind = L"Тайник",
    title = L"Пять мест для герба Лордерона",
    sources = {
        "https://www.zockify.com/forever/dungeons/ruins-of-lordaeron/",
    },
    L"У пауков проверь дверь у фонтана (за ней банши и стена) и наружную стену наверху башни.",
    L"На маршруте Бьорка осмотри пол под лестницей башни и заднюю стену павильона за его патрулём. Пятое место — наружная стена наверху башни у The Abandoned. Место меняется между заходами.",
})

add("WC", {
    kind = L"Событие",
    title = L"Ритуал Наралекса и Мутанус",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/wailing-caverns/mutanus-the-devourer",
    },
    L"Победи Анакондру, Кобрана, Питонаса и Серпентиса. Вернись к ученику Наралекса у входа и поговори с ним.",
    L"Сопроводи ученика и защити его у спящего Наралекса. В конце ритуала появляется Мутанус.",
})

add("WC", {
    kind = L"Для друида",
    title = L"Скрытая форма змея",
    class = "DRUID",
    sources = {
        "https://www.wowhead.com/news/wailing-caverns-set-bonus-turns-players-into-a-snake-in-forever-383046",
    },
    L"Собери и надень все пять кожаных вещей комплекта Embrace of the Viper из Пещер Стенаний. Прими облик кошки. Полный комплект меняет её вид на змею.",
})

add("WC", {
    kind = L"Редкая встреча",
    title = L"Загадочный волшебный дракон",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/wailing-caverns",
    },
    L"Осматривай пещеры по пути к предводителям Клыка. В некоторых копиях появляется дополнительный волшебный дракон. Для ритуала Наралекса он не нужен.",
})

add("RFK", {
    kind = L"Редкая встреча",
    title = L"Два редких противника Иглошкурых",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/razorfen-kraul",
        "https://1mw.io/en/dungeons/razorfen-kraul/loot",
    },
    L"После Агафелоса проверь дальний конец пещеры летучих мышей — там бывает «Слепой охотник».",
    L"Проверь площадку за «Властитель Таранный Клык». Там может появиться «Заклинательница земли Халмгар» с элементалем.",
})

add("RFD", {
    kind = L"Событие",
    title = L"Три удара в паучий гонг",
    sources = {
        "https://www.wowhead.com/forever/guide/razorfen-downs-dungeon-overview-location-rewards",
    },
    L"Ударь в гонг в зале пауков и уничтожь первую волну. Ударь ещё раз и отбей вторую. Третий удар призывает «Тутен'каш».",
})

add("RFD", {
    kind = L"Событие",
    title = L"Ритуал Бельнистраза",
    sources = {
        "https://www.wowhead.com/forever/guide/razorfen-downs-dungeon-overview-location-rewards",
    },
    L"Пусть все, кому нужно задание, поговорят с Бельнистразом и завершат «Плеть в холмах». Затем запусти сопровождение «Уничтожить идола».",
    L"Защищай его во время ритуала у идола. В конце появится «Чумобрюх Гнилой».",
})

add("BFD", {
    kind = L"Призыв • Орда",
    title = L"Барон Акванис и сфера Орды",
    faction = "Horde",
    prep = L"В Зорам’гаре возьми «Среди руин» у Дженё, чтобы вызвать барона Акваниса.",
    quest = 6921,
    sources = {
        "https://warcraft.wiki.gg/wiki/Baron_Aquanis",
        "https://www.icy-veins.com/wow-forever/blackfathom-deeps-quests",
    },
    L"Игрок Орды с заданием «Среди руин» должен нырнуть к «Глубинный Камень» в руинах святилища и взаимодействовать с ним. Появится «Барон Акванис».",
    L"Подбери «Странная водяная сфера». После сдачи добычи поговори с Дженё в Зорам’гаре ещё раз, чтобы забрать «Оскверненная водяная сфера».",
})

add("BFD", {
    kind = L"Секрет Forever",
    title = L"Если осквернённая сфера осталась в сумке",
    after = true,
    sources = {
        "https://www.wowhead.com/forever/guide/dawn-waker-secret-walkthrough",
    },
    L"Для следующего разговора нужны сфера в сумке и надетое кольцо Ancient Heirloom. Кольцо можно подобрать на верхнем этаже башни на острове Зефрас (41.7, 23.4).",
    L"На Зорамском взморье найди духа в точке 15.7, 19.3. Затем убей Нарассина наверху башни Алталакса в Тёмных берегах и открой его ключом ящик за ним. Верни книгу духу.",
})

add("BFD", {
    kind = L"Продолжение цепочки",
    title = L"Очищение сферы в Хиджале",
    after = true,
    sources = {
        "https://www.wowhead.com/forever/guide/dawn-waker-secret-walkthrough",
    },
    L"Получи Ancient Hilt с помощью Night Watchman’s Torch в руинах Ban’aethal на Зефрасе (58.1, 24.1). Иди к «Эалана Летучий Ореол» (65.9, 74.4), найди для неё Ancient Skyborne Blade и получи Eluvi’ana. Отнеси рукоять, Eluvi’ana и книгу Нарассина к Mordent Evenshade в Шен’дралар.",
    L"В южном Фераласе наденьте кольца. Четыре игрока одновременно нажимают древние переключатели, пятый берёт Star of Elune из сундука (58.5, 71.6). Для Abyssal Mote заверши цепочку «Кирит» до «Азшарит» и открой подводный сундук в Азшаре (66.0, 54.1).",
    L"После разговора с Мордентом собери 20 Tears of Anguish с призраков у озера Кел’Терил в Зимних Ключах. Вернись к нему, затем используй сферу с реагентами у Shrine of Coalescence в Хиджале (72.7, 37.2).",
})

add("BFD", {
    kind = L"Скрытый проход",
    title = L"Святилище Гелихаста и подводный босс",
    sources = {
        "https://www.wowforeverinfo.com/guides/blackfathom-deeps/",
    },
    L"После Гелихаста нажми на святилище за ним для подводного дыхания. Нырни под святилище в глубине подземелья. Там скрывается «Старина Серракис».",
})

add("BFD", {
    kind = L"Механизм",
    title = L"Четыре огня за Келрисом",
    sources = {
        "https://www.wowforeverinfo.com/guides/blackfathom-deeps/",
    },
    L"Каждый из четырёх малых огней запускает отдельную волну. Зажигайте по одному и добивайте волну перед следующим. После четырёх откроется путь к Аку’май.",
})

add("DM", {
    kind = L"Редкая встреча",
    title = L"Боковая шахта Рудокопа Джонсона",
    sources = {
        "https://www.wowforeverinfo.com/guides/deadmines/",
    },
    L"После Рак’Зора, по дороге к Сниду, загляни в тупиковое ответвление шахты. Там может появиться «Шахтер Джонсон».",
})

add("DM", {
    kind = L"Особый предмет",
    title = L"Топор, которым добывают руду",
    sources = {
        "https://wow.gg/guides/deadmines",
        "https://forg.gg/en/forever/dungeons/deadmines",
    },
    L"С Рак’Зора может выпасть «Камнерез». Его активный эффект добывает медь, олово, серебро и железо даже без горного дела.",
})

add("DM", {
    kind = L"Зацепка",
    title = L"Кольцо первого помощника",
    sources = {
        "https://lostwow.com/ForeverSecrets.shtml",
    },
    L"First Mate Band из Мёртвых копей входит в комплект Partners in Crime. Достоверного маршрута ко второму кольцу в проверенных источниках нет.",
})

add("RFC", {
    kind = L"Боковой маршрут",
    title = L"Как найти Баззалана",
    sources = {
        "https://www.wowhead.com/forever/guide/ragefire-chasm-dungeon-overview-location-rewards",
    },
    L"Перед Джергошем сверни направо на подъём. Наверху находится Баззалан с двумя охранниками. По нижнему маршруту его легко пропустить.",
})

add("STOCKS", {
    kind = L"Редкая встреча",
    title = L"Бругал Железный Кулак",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/the-stockade/bruegal-ironknuckle-rare",
    },
    L"Проверь боковые камеры Тюрьмы. В одной из них иногда появляется «Бругал Железный Кулак». Его наличие зависит от копии.",
})

add("STOCKS SM_GY", {
    kind = L"Особый предмет",
    title = L"Лопата для могил",
    faction = "Alliance", -- the shovel drops only in the Stockade
    prepKey = "SM_GY",
    prep = L"Для могил нужна лопата. Сначала добудь её у Декстрена Варда в Тюрьме Штормграда.",
    destination = "STOCKS",
    sources = {
        "https://www.foreverwisp.com/guides/wow-forever-graverobbers-shovel",
    },
    L"С «Декстрен Вард» в Тюрьме может выпасть Graverobber’s Shovel. Примени её на могиле в крыле «Кладбище» Монастыря Алого ордена или на Вороньем холме в Сумеречном лесу.",
    L"У лопаты 20 зарядов. Надёжной таблицы всех находок для этих могил пока нет.",
})

add("EXCAVATION", {
    kind = L"Боковой маршрут",
    title = L"Болотный ужас на северном раскопе",
    faction = "Alliance",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/excavation-site-wetlands",
    },
    L"На севере раскопок ищи Highland Horror среди слизней. Это необязательный противник для задания Альянса. Его можно обойти по основному маршруту.",
})

add("EXCAVATION", {
    kind = L"Спрятанное задание",
    title = L"Реликвия с последнего стража",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/excavation-site-wetlands-quests/",
        "https://mobalytics.gg/wow-forever/dungeons/excavation-site-wetlands-guide",
    },
    L"В конце раскопок нажми на архивную панель возле неподвижного Relic Guardian. После боя возьми Titan Relic с останков и открой её из сумки.",
})

add("THANES", {
    kind = L"Тайник • Альянс",
    title = L"Табличка в последнем хранилище",
    faction = "Alliance",
    sources = {
        "https://www.wofwforever.com/en/guides/wow-forever-hall-of-thanes-guide/",
    },
    L"После Durgen Dirgehammer осмотри хранилище за дверью в последнем зале, прежде чем идти к рычагу выхода. Табличка внутри начинает задание Альянса «Соглашение о взаимопонимании».",
})

add("DROWNED", {
    kind = L"Тайная комната",
    title = L"Подводная комната элементаля",
    sources = {
        "https://mobalytics.gg/wow-forever/profile/fierce-sun-30v6cf/dungeons/drowned-city-complete-dungeon-guide",
        "https://www.wowhead.com/forever/guide/the-drowned-city-dungeon-overview-location-rewards",
    },
    L"В Глубинных архивах поверни направо к затопленным тоннелям. Проплыви до комнаты Primeval Elemental. Ещё один ориентир на подходе — лестница у комнаты Var’taka.",
})

add("ALCAZ", {
    kind = L"Ключ",
    title = L"Связка надзирателя и нижний этаж",
    sources = {
        "https://conquestcapped.com/guides/wow-forever/wow-forever-alcaz-prison-guide/",
    },
    L"На верхнем этаже найди боковую караульную комнату с Overseer Wrex. С него падает Overseer’s Keyring — связка открывает закрытую дверь на нижний этаж.",
})

add("KROLDOK", {
    kind = L"Зацепка",
    title = L"Два разных ключа огров",
    sources = {
        "https://www.zockify.com/forever/dungeons/kroldok-stronghold/",
        "https://conquestcapped.com/guides/wow-forever/wow-forever-kroldok-stronghold-guide/",
    },
    L"Overlord Mugg роняет Krol’dok Ogre Key. Один отчёт группы связывает его с коротким путём под горой, другой гайд оставляет назначение открытым.",
    L"Krol’dok Compound Key получается отдельно через Krol’dok Moulding и Key Ingredients. Точную дверь для него подтвердить не удалось.",
})

add("BLACKMAW", {
    kind = L"Зацепка",
    title = L"Призывает ли ритуальный тотем духа?",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/blackmaw-hold/",
        "https://wowforevertalents.com/dungeons/blackmaw-hold/",
    },
    L"В источниках есть Unbound Spirit и квестовый Blackmaw Ritual Totem. Подтверждения, что тотем призывает босса или открывает тайник, пока нет.",
})

add("SHAPERS", {
    kind = L"Механизм",
    title = L"Зачем брать кристаллы Ун’Горо",
    prep = L"Собери силовые кристаллы в кратере Ун’Горо и возьми их к консолям террасы.",
    sources = {
        "https://worldofwarcraft.blizzard.com/en-us/news/24301455/",
        "https://wowforeverinfo.com/guides/dungeons/",
    },
    L"По дороге собери Power Crystals в кратере Ун’Горо и возьми их внутрь для консолей титанов. Точные комбинации для особой награды или скрытого босса не подтверждены.",
})

add("DALARAN", {
    kind = L"Спрятанное задание • Орда",
    title = L"Книга из библиотеки Даларана",
    faction = "Horde",
    sources = {
        "https://www.icy-veins.com/wow-forever/city-of-dalaran-quests/",
        "https://1mw.io/en/dungeons/city-of-dalaran/quests",
    },
    L"У входа в канализацию возьми у Rexxie Copperclutch задание Opportunistic Education (с 24-го уровня).",
    L"На поверхности пройди через зал порталов в библиотеку святилища Альянса. Книга The Founding of Dalaran стоит у дальней стены.",
})

add("GNOMER", {
    kind = L"Событие",
    title = L"Подрыв тоннеля и Грязнюк",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/gnomeregan/grubbis",
    },
    L"В Зале Чистоты найди подрывницу Эми Короткий Запал у обваленного прохода. Собери группу перед разговором.",
    L"Защищай её от троггов, пока она подрывает тоннели. Под конец появятся Грязнюк и его василиск.",
})

add("GNOMER", {
    kind = L"Особый предмет",
    title = L"Что делать с покрытыми грязью предметами",
    sources = {
        "https://wowforever.gg/en/guides/starter-dungeons-to-level-30/gnomeregan/",
        "https://questcorehq.com/wowdb/forever/quest/4602/the-sparklematic-5200",
    },
    L"Отнеси «Предмет, покрытый грязью» в Чистую зону. Найди там автомат «Чистер 5200».",
    L"Опусти предмет и 3 серебряных. Открой выданную автоматом посылку.",
})

add("SM_GY", {
    kind = L"Редкая встреча",
    title = L"Три редких противника на кладбище",
    sources = {
        "https://www.wowhead.com/forever/guide/scarlet-monastery-graveyard-dungeon-overview-location-rewards",
    },
    L"Во дворе кладбища осмотри надгробия по сторонам главной дорожки. Здесь встречаются Железноспин, Павший воитель и Азшир Неспящий.",
    L"У них несколько возможных мест появления. Если обычные боссы уже убиты, всё равно загляни в боковые ряды.",
})

add("SM_LIB SM_ARM SM_CATH", {
    kind = L"Ключ",
    title = L"Тайник чародея Доана",
    plan = "scarlet",
    sources = {
        "https://www.wowforeverinfo.com/guides/scarlet-monastery/",
        "https://wowforever.gg/en/guides/starter-dungeons-to-level-30/scarlet-monastery-library/",
        "https://azeroth.wiki/forever/dungeons/scarlet-monastery",
    },
    L"После победы над Доаном в конце библиотеки обыщи сундук «Сейф Доана» в его комнате.",
    L"Забери Алый ключ. Он открывает двери в Оружейную и Собор.",
})

add("SM_ARM", {
    kind = L"Особый предмет",
    title = L"Гербовая накидка Алого ордена",
    sources = {
        "https://azeroth.wiki/forever/dungeons/scarlet-monastery/herod",
    },
    L"Убей Герода и дождись, когда по лестнице сбегут послушники из его группы поддержки.",
    L"Накидка «Гербовая накидка Алого ордена» может выпасть с послушников. Осмотри их тела после боя.",
})

add("SM_CATH", {
    kind = L"Тайная комната",
    title = L"Инквизитор Фэйрбанкс за стеной",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/scarlet-monastery-cathedral/high-inquisitor-fairbanks",
    },
    L"Внутри собора зайди в боковую комнату справа от алтаря. Нажми на факел на стене.",
    L"За открывшейся стеной находится инквизитор Фэйрбанкс.",
})

add("ULDA", {
    kind = L"Головоломка",
    title = L"Как открыть зал Иронайи",
    sources = {
        "https://www.wowforeverinfo.com/guides/uldaman/",
        "https://azeroth.wiki/forever/dungeons/uldaman",
    },
    L"Отдай одному игроку Shaft of Tsol с Ревелоша и медальон Gni’kiv из сундука у Бейлога. Соедини их в посох.",
    L"В Зале Карт используй посох на макете города. Дверь к Иронайе откроется.",
})

add("ULDA", {
    kind = L"Тайная комната",
    title = L"Как вызвать учителя чар Аннору",
    prep = L"Для обучения у Анноры возьми материалы для чар. Ближе через задний вход в Бесплодных землях.",
    sources = {
        "https://mobalytics.gg/wow-forever/guides/enchanting-profession-guide",
        "https://www.zockify.com/forever/professions/enchanting/trainers/",
    },
    L"К её пещере короче идти от заднего входа в Ульдаман в Бесплодных землях (66, 43).",
    L"Убей всех скорпидов в её помещении. После зачистки появится Аннора.",
})

add("MARA", {
    kind = L"Сокращение пути",
    title = L"Скипетр и короткий путь к водопаду",
    prep = L"В пещере перед порталом возьми Legends of Maraudon у Кавиндры на оранжевой стороне.",
    sources = {
        "https://www.wowhead.com/forever/guide/maraudon-dungeon-overview-location-rewards",
    },
    L"Возьми «Легенды Мародона». В оранжевом крыле добудь жезл у Ноксиона, в фиолетовом — самоцвет у Вилетонга.",
    L"Победи Келебраса и поговори с его освобождённым духом. Заверши ритуал, получи скипетр и используй его у портала в пещере перед инстом, чтобы попасть к водопаду.",
})

add("MARA", {
    kind = L"Редкая встреча",
    title = L"Мешлок Жнец",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/maraudon",
        "https://www.wowhead.com/forever/guide/maraudon-dungeon-overview-location-rewards",
    },
    L"На пути между крыльями и центральной частью Мародона проверь, появился ли «Мешлок Жнец». Это редкий древень.",
})

add("ST", {
    kind = L"Головоломка",
    title = L"Шесть статуй и Атал’аларион",
    prep = L"Для награды за статуи возьми Secret of the Circle у Марвона в Танарисе.",
    sources = {
        "https://www.wowhead.com/forever/guide/the-temple-of-atalhakkar-dungeon-overview-location-rewards",
    },
    L"На кольцевом ярусе нажми статуи по сторонам света в этом порядке — юг, север, юго-запад, юго-восток, северо-запад, северо-восток.",
    L"Спустись к бассейну и победи Атал’алариона. Если выполняешь «Тайна камня», нажми появившуюся в центре статую змеи.",
})

add("ST", {
    kind = L"Призыв",
    title = L"Аватара Хаккара",
    prep = L"Для призыва возьми у Йе’киньи задание на яйцо Хаккара или принеси его свиток после цепочки.",
    sources = {
        "https://www.wowhead.com/forever/guide/the-temple-of-atalhakkar-dungeon-overview-location-rewards",
    },
    L"Для запуска в святилище нужен участник с яйцом по заданию «Бог Хаккар» или со свитком Йе’киньи за пройденную цепочку.",
    L"Начни ритуал, забирай кровь с хранителей крови и гаси ею четыре жаровни. После этого появится Аватара.",
})

add("ZF", {
    kind = L"Призыв",
    title = L"Молот и гонг Газ’риллы",
    plan = "mallet",
    sources = {
        "https://www.wowhead.com/forever/guide/zulfarrak-dungeon-overview-location-rewards",
        "https://www.wowhead.com/forever/item%3D9240/mallet-of-zulfarrak",
        "https://worstguidesever.com/wow-forever-mallet-of-zulfarrak-guide/",
    },
    L"Во Внутренних землях забери священный молот у «Квиага Хранительница» на Алтаре Зула. Используй его у алтаря на вершине Джинта’Алора. Алтарь Зула — 48.6, 68.2. Вершина Джинта’Алора — 59, 77.",
    L"С готовым молотом Зул’Фаррака ударь в гонг у бассейна внутри инста. Из воды выйдет Газ’рилла.",
})

add("ZF", {
    kind = L"Событие",
    title = L"Пленники на пирамиде и взрыв ворот",
    sources = {
        "https://www.wowhead.com/forever/guide/zulfarrak-dungeon-overview-location-rewards",
        "https://www.wowhead.com/forever/dungeon-journal/zulfarrak/sergeant-bly",
    },
    L"Забери у палача ключ и открой клетки наверху лестницы. Защищай освобождённых от волн троллей.",
    L"Выживший гоблин Вигли может взорвать ворота. Дай ему открыть проход, прежде чем требовать у сержанта Блая жезл по заданию.",
})

add("BRD", {
    kind = L"Скрытый босс",
    title = L"Харли и три бочонка",
    sources = {
        "https://www.wowhead.com/forever/guide/blackrock-depths-dungeon-overview-location-rewards",
    },
    L"В таверне «Угрюмый обжора» найди маленькую кладовую с бочонками громового эля.",
    L"Разбей три бочонка. Сразу после третьего к группе побежит «Харли Пьянодых» со своей компанией.",
})

add("BRD", {
    kind = L"Тайник",
    title = L"Портрет подсказывает, кто несёт ключ",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/blackrock-depths",
        "https://azeroth.wiki/forever/dungeons/blackrock-depths",
    },
    L"В банке открой портрет Хранителя Тьмы (Dark Keeper Portrait) и прочитай табличку — имя и место меняются между заходами.",
    L"Найди указанного хранителя и забери «Ключ темного хранителя». Вернись и открой особый сундук «Черный ящик».",
})

add("DM_E", {
    kind = L"Ключ",
    title = L"Погоня за Пузиллином",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/dire-maul-east-quests/",
        "https://azeroth.wiki/forever/dungeons/dire-maul/pusillin",
    },
    L"У входа в восточное крыло поговори с бесом Пузиллином. Каждый раз, когда он остановится, догоняй и снова говори с ним.",
    L"На последней площадке он вступит в бой. Забери «Серповидный ключ», открывающий другие части Забытого Города.",
})

add("DM_N", {
    kind = L"Особая награда",
    title = L"Дань огров за пощаду стражей",
    prep = L"Для дани возьми Frost Oil, Thorium Widget и костюм огра либо материалы для его пошива.",
    sources = {
        "https://www.wowhead.com/forever/guide/dire-maul-gordoks-commons-north-dungeon-overview-location-rewards",
    },
    L"Для полного сундука дани обойди стражей. Для ловушки Слип’кика возьми «Масло льда» и «Ториевое устройство», для Кромкруша приготовь костюм огра.",
    L"Убей короля Гордока, сохранив в живых советника Чо’Раша и остальных боссов. После боя поговори с «Миззл Умелец» и забери дань.",
})

add("DM_W", {
    kind = L"Классовая цепочка",
    title = L"Призыв лорда Хел’нурата",
    prep = L"Для призыва нужен чернокнижник на этапе ритуала эпического скакуна с ритуальными предметами.",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/dire-maul-west/lord-helnurath",
    },
    L"Нужен чернокнижник на этапе ритуала эпического скакуна с предметами для призыва. Освободи площадку, победив Бессмер’тера.",
    L"Проведи ритуал в его круге, защищая и поддерживая ритуальные предметы. В конце появятся скакун и лорд Хел’нурат.",
})

add("DM_W", {
    kind = L"Продолжение цепочки",
    title = L"Кому показать очищенную сферу",
    prep = L"Сначала очисти сферу в Хиджале и вернись к Морденту. После этого иди к принцу.",
    sources = {
        "https://www.wowhead.com/forever/guide/dawn-waker-secret-walkthrough",
    },
    L"Заверши очищение сферы из Непроглядной Пучины в Хиджале и вернись к Морденту. Следующий собеседник — принц Тортелдрин в западном крыле Забытого Города.",
    L"Подтверждённые шаги до очищения приведены в карточках Непроглядной Пучины.",
})

add("LBRS", {
    kind = L"Призыв",
    title = L"Урок Роковой Вой и груда подношений",
    sources = {
        "https://www.wowhead.com/forever/guide/lower-blackrock-spire-dungeon-overview-location-rewards",
        "https://azeroth.wiki/forever/dungeons/blackrock-spire/urok-doomhowl",
    },
    L"Забери голову вождя Омокка и «Копье грубой силы» со стойки с копьями.",
    L"За Матерью Дымной Паутиной найди груду подношений (Tribute Pile). Используй предметы у груды и отбей огров, пока не появится Урок.",
})

add("LBRS", {
    kind = L"Редкая встреча",
    title = L"Мясник и Баннок",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/lower-blackrock-spire",
        "https://www.wowhead.com/forever/guide/lower-blackrock-spire-dungeon-overview-location-rewards",
    },
    L"В нижней части пика осмотри область огров на предмет «Мясник из клана Черной Вершины». В лагере орков проверь, появился ли «Баннок Люторез».",
})

add("UBRS", {
    kind = L"Призыв",
    title = L"Солакар и Пламя Отца",
    sources = {
        "https://www.wowhead.com/forever/guide/upper-blackrock-spire-dungeon-overview-location-rewards",
    },
    L"В инкубаторе пройди вдоль левой стены до алтаря «Огонь отцов». Поговори с группой перед активацией — сразу начнутся волны.",
    L"Защищай площадку, пока не появится «Солакарский огнечервь».",
})

add("UBRS", {
    kind = L"Спрятанное задание",
    title = L"Гном внутри Зверя",
    prep = L"Чтобы освободить гнома, возьми в группу кожевника, способного снять шкуру со Зверя.",
    sources = {
        "https://www.wowhead.com/forever/guide/upper-blackrock-spire-dungeon-overview-location-rewards",
        "https://www.wowhead.com/forever/npc%3D10430/the-beast",
    },
    L"Возьми с собой опытного кожевника. После убийства Зверя собери добычу и сними с него шкуру.",
    L"Из туши выберется гном. Поговори с ним, пока группа ещё в подземелье.",
})

add("SCHOLO", {
    kind = L"Призыв",
    title = L"Кровь невинных и Киртонос",
    prep = L"Возьми Blood of Innocents у Евы Саркофф на острове Каэр Дарроу после её заданий.",
    sources = {
        "https://azeroth.wiki/forever/dungeons/scholomance",
        "https://www.wowhead.com/forever/guide/scholomance-dungeon-overview-location-rewards",
    },
    L"Пройди задания Евы Саркофф в Каэр Дарроу до получения Blood of Innocents.",
    L"В Некроситете всей группой выйди на балкон и используй кровь на жаровне Вестника. Решётка закроется до прилёта Киртоноса.",
})

add("SCHOLO", {
    kind = L"Событие",
    title = L"Что делать в смотровой комнате",
    prep = L"Возьми устройство Dawn’s Gambit у Бетины в часовне Последней Надежды.",
    sources = {
        "https://forever-tavern.com/quests/world/4771-dawn-s-gambit/",
    },
    L"Возьми задание «Рассветный гамбит» у Бетины Биггльцинк и принеси выданное устройство в Viewing Room.",
    L"Установи его в комнате учеников. После превращения учеников победи Вектуса.",
})

add("STRAT_LIVE", {
    kind = L"Скрытый босс",
    title = L"Три почтовых ящика и почтальон Мэлоун",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/stratholme-living/",
        "https://muchamielwow.github.io/en/mazmorras/stratholme/",
    },
    L"Убей курьера и забери его ключи. Названия ключей указывают, какие почтовые ящики надо найти в городе.",
    L"Открой все три ящика. Будь готов к засадам — у последнего появится почтальон Мэлоун.",
})

add("STRAT_LIVE", {
    kind = L"Скрытый босс",
    title = L"Табачный ящик Фраса Сиаби",
    prep = L"Для табака возьми задание The Great Fras Siabi у Смоки в часовне Последней Надежды.",
    sources = {
        "https://www.wowhead.com/forever/quest%3D5214/the-great-fras-siabi",
        "https://www.wowhead.com/forever/guide/stratholme-live-side-dungeon-overview-location-rewards",
    },
    L"Для задания The Great Fras Siabi найди ящик с табаком у магазина Фраса и нажми на него.",
    L"Появится хозяин. После победы забери табак для задания.",
})

add("STRAT_UD", {
    kind = L"Испытание на время",
    title = L"Спасти Изиду до казни",
    prep = L"Для задания на спасение Изиды возьми прибор Extra-Dimensional Ghost Revealer из цепочки. С ним поговори с призраком Антиона у Стратхольма.",
    sources = {
        "https://wowforever.be/guides/dungeons/stratholme-undead/guide/",
        "https://questing.wiki/wow-forever/dungeons/stratholme-undead-side/quests/",
    },
    L"Если идёшь по заданию «Просьба мертвеца», подготовь группу у внутренних ворот Gauntlet Gate. Когда их откроют, начнётся отсчёт 45 минут.",
    L"Зачисти три зиккурата и прорвись к барону Ривендеру до истечения времени. После боя поговори с Изидой.",
})

add("STRAT_UD", {
    kind = L"Редкая встреча",
    title = L"Каменный Гребень",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/stratholme-undead/stonespine-rare",
    },
    L"В квартале нежити следи за патрулями горгулий. У редкой горгульи «Каменный Гребень» собственная таблица добычи.",
})

add("LORDAERON", {
    kind = L"Редкая встреча",
    title = L"Капитан на западной улице",
    sources = {
        "https://www.reddit.com/r/wow/comments/1wllmou/ruins_of_lordaeron_the_rare_elite_mob_lordaeron/",
        "https://www.icy-veins.com/wow-forever/ruins-of-lordaeron-guide/",
    },
    L"После зачистки проверь улицу от дома с камином к северо-западу. Игроки встретили там Lordaeron Captain. Убийство остальных боссов не гарантирует его появления.",
})

add("DROWNED", {
    kind = L"Редкая встреча",
    title = L"Gill и Umbra",
    sources = {
        "https://www.wowhead.com/forever/guide/the-drowned-city-dungeon-overview-location-rewards",
    },
    L"В Глубинных архивах по дороге к покоям элементаля проверь проход — там бывает Gill с динамитом.",
    L"Ещё одна редкая встреча — Umbra в окружении пяти мурлоков. Их кровотечения складываются, поэтому не цепляйте соседние группы.",
})

add("BLACKMAW", {
    kind = L"Редкая встреча",
    title = L"Зверь с клинком двух лун",
    sources = {
        "https://conquestcapped.com/guides/wow-forever/wow-forever-blackmaw-hold-guide/",
    },
    L"Осматривай зверей по дороге через оплот. Moontouched Wanderer — редкая элита 55-го уровня. Игроки видели с него двуручный меч Claymore of Two Moons.",
})

add("KROLDOK", {
    kind = L"Боковой маршрут",
    title = L"Площадка Босса Туфа",
    sources = {
        "https://conquestcapped.com/guides/wow-forever/wow-forever-kroldok-stronghold-guide/",
    },
    L"После длинного деревянного моста осмотри площадку с шаманами перед подъёмом к Муггу. Здесь стоит Bossman Toof. У него есть собственная добыча — в том числе Toofbreaker и Big-Belly Belt.",
})

add("RFD", {
    kind = L"Профессии",
    title = L"Два рецепта пленника Генри Штерна",
    sources = {
        "https://www.icy-veins.com/wow-forever/cooking/",
        "https://pullwise.gg/forever/dungeons/razorfen-downs",
    },
    L"В загонах освободи Генри Штерна и поговори с ним. Повар может узнать рецепт чая из златошипа, алхимик — рецепт зелья тролльей крови.",
})

add("GNOMER", {
    kind = L"Задание • Альянс",
    title = L"Перфокарты для «Спасения данных»",
    faction = "Alliance", -- the prismatic card is asked for by an Alliance quest alone
    plan = "cards",
    over = 2930,
    sources = {
        "https://warcraft.wiki.gg/wiki/Matrix_Punchograph_3005",
        "https://warcraft.wiki.gg/wiki/White_Punch_Card",
    },
    L"Призматическая перфокарта нужна для задания «Спасение данных» — Чугунотрубз, Стальгорн. Белая карта падает с троггов и лепрогномов в тоннелях перед порталом.",
    L"Перфограф 3005-A стоит в мастерской перед порталом (22, 33): белая карта станет жёлтой.",
    L"Внутри по порядку: 3005-B в спальном блоке — синяя, 3005-C на верхней площадке у Электрошокера 6000 — красная, 3005-D на нижнем ярусе инженерных лабораторий — призматическая.",
})

add("GNOMER", {
    kind = L"Только инженерам",
    title = L"Чертёж у перфографа 3005-D",
    skill = 202,
    skillName = L"Инженерное дело",
    sources = {
        "https://warcraft.wiki.gg/wiki/Matrix_Punchograph_3005-D",
        "https://www.wowhead.com/forever/item=4413/schematic-discombobulator-ray",
    },
    L"Нужны навык инженерного дела 160 и Карта безопасного доступа ДЕЛЬТА. Она падает с механизмов внутри и с Термоштепселя.",
    L"С картой подойди к перфографу 3005-D на нижнем ярусе инженерных лабораторий, западная сторона. Он обучит анти-перенаправляющему лучу. Перфокарты для этого не нужны.",
})

add("ZF", {
    kind = L"Особый предмет",
    title = L"Собрать эпический меч из двух клинков",
    sources = {
        "https://muchamielwow.github.io/en/mazmorras/zulfarrak/",
        "https://www.wowhead.com/forever/guide/zulfarrak-dungeon-overview-location-rewards",
    },
    L"Сохрани оба редких клинка, Jang’thraze и Sang’thraze, с Анту’сула и вождя Укорза. Когда оба будут у одного персонажа, используй эффект объединения, чтобы получить «Кара Суль'траза».",
})

add("DM_N", {
    kind = L"Тайник",
    title = L"Награда за освобождение гоблина",
    sources = {
        "https://www.wowhead.com/forever/guide/dire-maul-gordoks-commons-north-dungeon-overview-location-rewards",
    },
    L"Если с огров выпадет «Ключ от оков клана Гордок», найди пленного «Уззл Наперстяк». До освобождения закончи с ним дела, включая пошив костюма огра.",
    L"Сними его оковы. После побега на месте останется «Тайник Уззла Наперстяка» с материалами и шансом на рецепт.",
})

add("BRD", {
    kind = L"Ключ",
    title = L"Квест, который берут в облике призрака",
    prep = L"По пути в инст поговори с Франклорном в облике призрака в центральной гробнице Чёрной горы.",
    sources = {
        "https://www.wowforeverquests.com/keys",
        "https://www.wowhead.com/forever/guide/blackrock-depths-dungeon-overview-location-rewards",
    },
    L"В облике призрака по пути к инсту зайди в центральную гробницу Чёрной горы. Поговори с Франклорном Искусником и возьми «Наследие Черного Железа».",
    L"Внутри глубин добудь «Железный Друг» у «Точень Темнострой» и отнеси его к статуе Франклорна за ключом Тенегорна.",
})

add("ZF", {
    kind = L"Редкая встреча",
    title = L"Три редких тролля Зул’Фаррака",
    sources = {
        "https://www.warcrafttavern.com/forever/guides/zulfarrak",
        "https://muchamielwow.github.io/en/mazmorras/zulfarrak/",
    },
    L"Во время обхода ищи «Зериллис», «Сандарр Разоритель Барханов» и «Пыльный призрак». Случайное появление каждого означает, что за один заход можно никого не встретить.",
})

add("STRAT_LIVE", {
    kind = L"Редкая встреча",
    title = L"Скул и менестрель",
    sources = {
        "https://www.wowhead.com/forever/guide/stratholme-live-side-dungeon-overview-location-rewards",
    },
    L"На жилых улицах города проверяй боковые проходы. Тут можно встретить редких противников «Череп» и «Певчий Форрестен» — у каждого своя добыча.",
})

add("DM_W", {
    kind = L"Редкая встреча",
    title = L"Тсу’зи в столице садов",
    sources = {
        "https://azeroth.wiki/forever/dungeons/dire-maul",
    },
    L"В западном крыле среди призраков проверь, появилась ли редкая противница «Цу'зи».",
})

add("GNOMER", {
    kind = L"Редкая встреча",
    title = L"Посол Чёрного Железа",
    sources = {
        "https://mobalytics.gg/wow-forever/dungeons/gnomeregan-guide",
    },
    L"Проверь квартал Чёрного Железа. Среди дворфов иногда появляется «Посол из клана Черного Железа».",
})

add("RFD", {
    kind = L"Редкая встреча",
    title = L"Круглорыл",
    sources = {
        "https://www.wowhead.com/forever/guide/razorfen-downs-dungeon-overview-location-rewards",
    },
    L"В Залах Иглошкурых на пути через холм осмотри площадки. Здесь может появиться редкий свинобраз «Круглорыл».",
})

add("BRD", {
    kind = L"Редкая встреча",
    title = L"Пиромант и редкий голем",
    sources = {
        "https://www.wowhead.com/forever/guide/blackrock-depths-dungeon-overview-location-rewards",
    },
    L"Проверь район Святилища Призыва на присутствие «Пироман Зерно Мудрости». В мастерских големов может появиться «Панцер Непобедимый».",
})

add("LBRS", {
    kind = L"Редкая встреча",
    title = L"Другие редкие обитатели нижнего пика",
    sources = {
        "https://www.wowhead.com/forever/dungeon-journal/lower-blackrock-spire",
        "https://www.wowhead.com/forever/guide/lower-blackrock-spire-dungeon-overview-location-rewards",
    },
    L"У огров проверь «Полководец из клана Черной Вершины» и «Лорд-волхв из клана Черной Вершины». Среди пауков может появиться «Хрустальный Клык».",
    L"В перечне редких встреч также есть «Гок Крепкобив» и «Пылающий страж Скверны». Их присутствие в конкретном заходе меняется.",
})

add("UBRS", {
    kind = L"Редкая встреча",
    title = L"Джед Руновед",
    sources = {
        "https://www.wowhead.com/forever/guide/upper-blackrock-spire-dungeon-overview-location-rewards",
    },
    L"В зале пироманта Углевзора проверь, появился ли «Джед Руновед». У Джеда может выпасть аксессуар для заклинателей «Пищик из древесины шиповника».",
})

add("WC", {
    kind = L"Перед входом",
    title = L"Библиотечная книга у Пещер Стенаний",
    prep = L"Подбери Secrets of the Dreamers в пещере у Цветущего оазиса до портала.",
    sources = {
        "https://www.wowhead.com/forever/guide/library-book-locations-and-rewards",
        "https://allthings.how/wow-forever-library-books-all-locations-and-rewards/",
    },
    L"В пещере у Цветущего оазиса до портала инста осмотри свитки. Там лежит «Тайны Дремлющих» для библиотеки. Забрать её можно по пути к группе.",
})
