local _, P = ...

-- The words of the addon are written in Russian, the language of its first owner. For
-- every other client they are said in English: L"..." gives the English of a Russian
-- line from the table below (made by dungeon-quest-handoff/make-locale.py; not edited by
-- hand), or the line itself where the client is Russian or the table has nothing.
-- LOCALE BEGIN
local EN = {
    ["Другой континент"] = "Another continent",
    ["Затонувший город"] = "The Drowned City",
    ["Затопленный город"] = "The Drowned City",
    ["вход под водой, к западу от Гром'гола"] = "the way in is under water, west of Grom'gol",
    ["Крепость Крол'док"] = "Krol'dok Stronghold",
    ["пещера у камня встреч"] = "a cave by the meeting stone",
    ["Тюрьма Альказа"] = "Alcaz Prison",
    ["в подвале старой башни на острове"] = "in the basement of the old tower on the island",
    ["Цитадель Чернопасти"] = "Blackmaw Hold",
    ["туннель фурболгов, портал в глубине"] = "a furbolg tunnel, the portal deep inside",
    ["Терраса ваятеля"] = "Shaper's Terrace",
    ["вверх по лестнице от Укрытия Маршала"] = "up the stairs from Marshal's Refuge",
    ["объект «%s»"] = "object '%s'",
    ["Вход: "] = "Entrance: ",
    ["Не открыта"] = "Not discovered",
    ["Распорядитель полётов: "] = "Flight master: ",
    ["Щелчок: стрелка к распорядителю"] = "Click: arrow to the flight master",
    ["Твоё тело"] = "Your body",
    ["Ты на месте: "] = "You have arrived: ",
    ["%d м"] = "%d yd",
    [" • наверху вышки"] = " • at the top of the tower",
    ["Стрелка к точке"] = "Arrow to the point",
    ["Потяни, чтобы переставить. ПКМ снимает точку."] = "Drag to move. Right-click removes the point.",
    ["Человек"] = "Human",
    ["Орк"] = "Orc",
    ["Дворф"] = "Dwarf",
    ["Ночной эльф"] = "Night Elf",
    ["Нежить"] = "Undead",
    ["Таурен"] = "Tauren",
    ["Гном"] = "Gnome",
    ["Тролль"] = "Troll",
    ["только для рас: "] = "only for: ",
    ["Не удалось проверить цепочку"] = "Could not check the chain",
    ["Нет доступной ветки цепочки"] = "No available branch of the chain",
    ["В базе нет начала цепочки"] = "The start of the chain is not in the database",
    ["Предыдущий шаг не указан в базе"] = "The previous step is not in the database",
    [" — сдано|r"] = " — turned in|r",
    [" — в журнале"] = " — in log",
    [" — сейчас"] = " — now",
    ["Сдано"] = "Turned in",
    ["Сдать внутри"] = "Turn in inside",
    ["Сдать: "] = "Turn in: ",
    ["Готово к сдаче"] = "Ready to turn in",
    ["Цели в подземелье"] = "Objectives in the dungeon",
    ["С уровня "] = "From level ",
    ["Сначала сдай "] = "First turn in ",
    ["Сначала выполни "] = "First complete ",
    ["Сначала "] = "First ",
    [" — взять: "] = " — pick up: ",
    ["Начинается с предмета, выпадает внутри"] = "Starts from an item that drops inside",
    ["Взять внутри"] = "Pick up inside",
    ["Взять: "] = "Pick up: ",
    ["Нужно взять"] = "Needs to be picked up",
    ["Нужна цепочка ключа"] = "Needs the key chain",
    [" и другие"] = " and others",
    ["выполнено, сдать здесь"] = "complete, turn in here",
    ["выполнено, сдать после выхода"] = "complete, turn in after leaving",
    ["нужны: "] = "needed: ",
    ["начнётся с предмета"] = "starts from an item",
    ["; падает с: "] = "; drops from: ",
    ["взять у: "] = "pick up from: ",
    ["взять: "] = "pick up: ",
    ["; нужен «"] = "; needs «",
    ["осталось: "] = "left: ",
    [" и ещё "] = " plus ",
    ["взято"] = "taken",
    ["босс: "] = "boss: ",
    ["готово"] = "ready",
    ["сдать здесь"] = "turn in here",
    ["сдать после выхода"] = "turn in after leaving",
    ["не взято"] = "not taken",
    ["выдаёт "] = "given by ",
    ["нужен «"] = "needs «",
    ["Клоака • победи Атрексиса"] = "Underbelly • defeat Atrexis",
    ["Поднимись в город. Святилище Альянса, за ним зал порталов, дальняя стена библиотеки."] = "Go up into the city. The Alliance sanctuary, then the portal hall behind it, the far wall of the library.",
    ["Собери шесть треснувших сердечников с часовых."] = "Collect six cracked cores from the sentries.",
    ["Верхний этаж • тень верховного мага"] = "Top floor • the archmage's shade",
    ["Подъём к библиотеке"] = "Way up to the library",
    ["Это задание уже сдано."] = "This quest is already turned in.",
    ["Это снаружи, в пещере перед порталом: "] = "This is outside, in the cave before the portal: ",
    ["Это снаружи: "] = "This is outside: ",
    [". Сделай на выходе."] = ". Do it on the way out.",
    ["Цель на плане этажа • "] = "Objective on the floor plan • ",
    ["Вход • "] = "Entrance • ",
    ["Добыча с босса: "] = "Boss loot: ",
    ["Место на плане этажа • "] = "Spot on the floor plan • ",
    ["Место на плане: "] = "Spot on the plan: ",
    ["Ты уже внутри. "] = "You are already inside. ",
    [" — точка на этаже неизвестна."] = " — point on the floor unknown.",
    [". Точных координат в базе нет."] = ". No exact coordinates in the database.",
    [". Другой континент, ближайший путь: "] = ". Another continent, nearest route: ",
    [". По прямой не пройти, идти так: "] = ". No straight path, go this way: ",
    [". Быстрее так: "] = ". Faster this way: ",
    [". Стрелка ведёт туда."] = ". The arrow leads there.",
    [". Нажми иконку телепорта на месте стрелки."] = ". Click the teleport icon at the arrow's spot.",
    ["Следующее задание • "] = "Next quest • ",
    ["нет в базе"] = "not in database",
    ["не серое"] = "not grey",
    ["готово к сдаче"] = "ready to turn in",
    ["начато"] = "started",
    ["цепочка"] = "chain",
    ["классовое или профессии"] = "class or profession",
    ["задание подземелья"] = "dungeon quest",
    ["ничего"] = "nothing",
    [" ОШИБКА "] = " ERROR ",
    [" (повтор)"] = " (repeat)",
    ["Скрытый босс"] = "Hidden boss",
    ["Книга Аругала и Lyn the Ignored"] = "Arugal's book and Lyn the Ignored",
    ["После победы над Аругалом в Крепости Тёмного Клыка нажми на книгу в глубине комнаты. Забери Black Tome."] = "After defeating Arugal in Shadowfang Keep, click the book at the back of the room. Take the Black Tome.",
    ["В Серебряном бору используй книгу рядом с Ambermill Leyline Focus в крепости Янтарной Мельницы. Получишь Tome of Dalaran. Фокус стоит в ратуше (63.4, 64.3)."] = "In Silverpine Forest, use the book next to the Ambermill Leyline Focus in the Ambermill keep. You get the Tome of Dalaran. The focus stands in the town hall (63.4, 64.3).",
    ["В данже Даларана после первого босса иди по канализации прямо мимо поворота направо к поверхности. Используй том у фиолетовой руны в конце тоннеля."] = "In the Dalaran dungeon, after the first boss follow the sewers straight past the right turn to the surface. Use the tome at the purple rune at the end of the tunnel.",
    ["Для мага"] = "For mages",
    ["Coldflame Saber из клинка Сильверлейна"] = "Coldflame Saber from Silverlaine's blade",
    ["Сохрани Blade of Silverlaine из крепости. При расшифровке магических свитков можно получить Scroll of the Saber."] = "Keep the Blade of Silverlaine from the keep. Deciphering magic scrolls can give you the Scroll of the Saber.",
    ["Используй Scroll of the Saber на клинке. Получится меч мага Coldflame Saber."] = "Use the Scroll of the Saber on the blade. It becomes the mage sword Coldflame Saber.",
    ["Редкая встреча"] = "Rare encounter",
    ["Капитан служителей Смерти"] = "Deathsworn Captain",
    ["В крепости может появиться дополнительный капитан-призрак. Ищи его командой /targetexact Капитан служителей Смерти. Встреча случайная."] = "An extra ghost captain can appear in the keep. Look for him with /targetexact Deathsworn Captain. The encounter is random.",
    ["Классовая цепочка"] = "Class chain",
    ["Три данжа для оружия паладина-отрекшегося"] = "Three dungeons for a Forsaken paladin's weapon",
    ["Сначала спаси Lumina Windsinger на острове Фенрис и возьми задание на материалы."] = "First rescue Lumina Windsinger on Fenris Isle and pick up the quest for the materials.",
    ["После спасения «Люмина Виндсингер» на острове Фенрис пройди к заданию на три материала. В Мёртвых копях нужен «Древесина белокаменного дуба», в Крепости Тёмного Клыка — Enchanted Silver Ingot."] = "After rescuing Lumina Windsinger on Fenris Isle, go on to the quest for three materials. The Deadmines give the Whitestone Oak Lumber, Shadowfang Keep the Enchanted Silver Ingot.",
    ["Для «Очищенный самоцвет Кора» сначала обратись к Olric Frostvale в Ясеневом лесу, затем иди в Непроглядную Пучину. Собранные материалы отнеси кузнецу Orrt в Мельницу Таррен."] = "For the Purified Kor Gem, first speak to Olric Frostvale in Ashenvale, then go to Blackfathom Deeps. Bring the collected materials to the blacksmith Orrt in Tarren Mill.",
    ["Камин в сгоревшем доме"] = "Fireplace in the burned house",
    ["Соберись с группой у камина в сгоревшем доме на юго-западе руин. Восстановите ману и нажмите на огонь."] = "Gather your party at the fireplace in the burned house in the southwest of the ruins. Restore mana and click the fire.",
    ["Отбейте пять волн нежити. На шестой появляется Viktor the Vile."] = "Hold off five waves of undead. Viktor the Vile appears on the sixth.",
    ["Статуя на Рыночной площади"] = "Statue on Market Row",
    ["Пройдите мимо кладбища во двор и подойдите к статуе со светящимися глазами."] = "Go past the graveyard into the courtyard and approach the statue with glowing eyes.",
    ["После трёх волн нежити из коридоров появится The Abandoned."] = "After three waves of undead, The Abandoned comes out of the corridors.",
    ["Тайник"] = "Cache",
    ["Пять мест для герба Лордерона"] = "Five spots for the Lordaeron crest",
    ["У пауков проверь дверь у фонтана (за ней банши и стена) и наружную стену наверху башни."] = "By the spiders, check the door at the fountain (a banshee and a wall behind it) and the outer wall at the top of the tower.",
    ["На маршруте Бьорка осмотри пол под лестницей башни и заднюю стену павильона за его патрулём. Пятое место — наружная стена наверху башни у The Abandoned. Место меняется между заходами."] = "On Bjork's route, search the floor under the tower stairs and the back wall of the pavilion behind his patrol. The fifth spot is the outer wall at the top of the tower near The Abandoned. The spot changes between runs.",
    ["Событие"] = "Event",
    ["Ритуал Наралекса и Мутанус"] = "Naralex's ritual and Mutanus",
    ["Победи Анакондру, Кобрана, Питонаса и Серпентиса. Вернись к ученику Наралекса у входа и поговори с ним."] = "Defeat Anacondra, Cobrahn, Pythas and Serpentis. Return to the Disciple of Naralex at the entrance and talk to him.",
    ["Сопроводи ученика и защити его у спящего Наралекса. В конце ритуала появляется Мутанус."] = "Escort the disciple and protect him at the sleeping Naralex. At the end of the ritual Mutanus appears.",
    ["Для друида"] = "For druids",
    ["Скрытая форма змея"] = "Hidden serpent form",
    ["Собери и надень все пять кожаных вещей комплекта Embrace of the Viper из Пещер Стенаний. Прими облик кошки. Полный комплект меняет её вид на змею."] = "Collect and equip all five leather pieces of the Embrace of the Viper set from Wailing Caverns. Take Cat Form. The full set turns the cat into a serpent.",
    ["Загадочный волшебный дракон"] = "Mysterious faerie dragon",
    ["Осматривай пещеры по пути к предводителям Клыка. В некоторых копиях появляется дополнительный волшебный дракон. Для ритуала Наралекса он не нужен."] = "Search the caves on the way to the Fanglords. In some instances an extra faerie dragon appears. It is not needed for Naralex's ritual.",
    ["Два редких противника Иглошкурых"] = "Two rare Razorfen enemies",
    ["После Агафелоса проверь дальний конец пещеры летучих мышей — там бывает «Слепой охотник»."] = "After Agathelos, check the far end of the bat cave. Blind Hunter can be there.",
    ["Проверь площадку за «Властитель Таранный Клык». Там может появиться «Заклинательница земли Халмгар» с элементалем."] = "Check the platform behind Overlord Ramtusk. Earthcaller Halmgar can appear there with an elemental.",
    ["Три удара в паучий гонг"] = "Three strikes on the spider gong",
    ["Ударь в гонг в зале пауков и уничтожь первую волну. Ударь ещё раз и отбей вторую. Третий удар призывает «Тутен'каш»."] = "Strike the gong in the spider hall and destroy the first wave. Strike it again and hold off the second. The third strike summons Tuten'kash.",
    ["Ритуал Бельнистраза"] = "Belnistrasz's ritual",
    ["Пусть все, кому нужно задание, поговорят с Бельнистразом и завершат «Плеть в холмах». Затем запусти сопровождение «Уничтожить идола»."] = "Have everyone who needs the quest talk to Belnistrasz and complete Scourge of the Downs. Then start the escort Extinguishing the Idol.",
    ["Защищай его во время ритуала у идола. В конце появится «Чумобрюх Гнилой»."] = "Protect him during the ritual at the idol. At the end Plaguemaw the Rotting appears.",
    ["Призыв • Орда"] = "Summon • Horde",
    ["Барон Акванис и сфера Орды"] = "Baron Aquanis and the Horde globe",
    ["В Зорам’гаре возьми «Среди руин» у Дженё, чтобы вызвать барона Акваниса."] = "In Zoram'gar Outpost, pick up Amongst the Ruins from Je'neu to summon Baron Aquanis.",
    ["Игрок Орды с заданием «Среди руин» должен нырнуть к «Глубинный Камень» в руинах святилища и взаимодействовать с ним. Появится «Барон Акванис»."] = "A Horde player with the quest Amongst the Ruins must dive to the Fathom Stone in the ruins of the shrine and interact with it. Baron Aquanis appears.",
    ["Подбери «Странная водяная сфера». После сдачи добычи поговори с Дженё в Зорам’гаре ещё раз, чтобы забрать «Оскверненная водяная сфера»."] = "Pick up the Strange Water Globe. After turning in the loot, talk to Je'neu in Zoram'gar Outpost again to get the Corrupted Water Globe.",
    ["Секрет Forever"] = "Forever secret",
    ["Если осквернённая сфера осталась в сумке"] = "If the corrupted globe is still in your bag",
    ["Для следующего разговора нужны сфера в сумке и надетое кольцо Ancient Heirloom. Кольцо можно подобрать на верхнем этаже башни на острове Зефрас (41.7, 23.4)."] = "The next conversation needs the globe in your bag and the Ancient Heirloom ring equipped. The ring can be picked up on the top floor of the tower on Zephras Isle (41.7, 23.4).",
    ["На Зорамском взморье найди духа в точке 15.7, 19.3. Затем убей Нарассина наверху башни Алталакса в Тёмных берегах и открой его ключом ящик за ним. Верни книгу духу."] = "On Zoram Strand, find the spirit at 15.7, 19.3. Then kill Narassin at the top of the Tower of Althalaxx in Darkshore and open the chest behind him with his key. Bring the book back to the spirit.",
    ["Продолжение цепочки"] = "Chain continues",
    ["Очищение сферы в Хиджале"] = "Purifying the globe in Hyjal",
    ["Получи Ancient Hilt с помощью Night Watchman’s Torch в руинах Ban’aethal на Зефрасе (58.1, 24.1). Иди к «Эалана Летучий Ореол» (65.9, 74.4), найди для неё Ancient Skyborne Blade и получи Eluvi’ana. Отнеси рукоять, Eluvi’ana и книгу Нарассина к Mordent Evenshade в Шен’дралар."] = "Get the Ancient Hilt using the Night Watchman’s Torch in the ruins of Ban’aethal on Zephras (58.1, 24.1). Go to Ealana Skyhalo (65.9, 74.4), find the Ancient Skyborne Blade for her and get Eluvi’ana. Bring the hilt, Eluvi’ana and Narassin's book to Mordent Evenshade in Shen’dralar.",
    ["В южном Фераласе наденьте кольца. Четыре игрока одновременно нажимают древние переключатели, пятый берёт Star of Elune из сундука (58.5, 71.6). Для Abyssal Mote заверши цепочку «Кирит» до «Азшарит» и открой подводный сундук в Азшаре (66.0, 54.1)."] = "In southern Feralas, put on the rings. Four players press the ancient switches at the same time, the fifth takes the Star of Elune from the chest (58.5, 71.6). For the Abyssal Mote, finish the Kyrite chain up to Azsharite and open the underwater chest in Azshara (66.0, 54.1).",
    ["После разговора с Мордентом собери 20 Tears of Anguish с призраков у озера Кел’Терил в Зимних Ключах. Вернись к нему, затем используй сферу с реагентами у Shrine of Coalescence в Хиджале (72.7, 37.2)."] = "After talking to Mordent, collect 20 Tears of Anguish from the ghosts at Lake Kel’Theril in Winterspring. Return to him, then use the globe with the reagents at the Shrine of Coalescence in Hyjal (72.7, 37.2).",
    ["Скрытый проход"] = "Hidden passage",
    ["Святилище Гелихаста и подводный босс"] = "Gelihast's shrine and the underwater boss",
    ["После Гелихаста нажми на святилище за ним для подводного дыхания. Нырни под святилище в глубине подземелья. Там скрывается «Старина Серракис»."] = "After Gelihast, click the shrine behind him for underwater breathing. Dive under the shrine deep in the dungeon. Old Serra'kis hides there.",
    ["Механизм"] = "Mechanism",
    ["Четыре огня за Келрисом"] = "Four fires past Kelris",
    ["Каждый из четырёх малых огней запускает отдельную волну. Зажигайте по одному и добивайте волну перед следующим. После четырёх откроется путь к Аку’май."] = "Each of the four small fires starts a separate wave. Light them one at a time and finish each wave before the next. After all four, the way to Aku’mai opens.",
    ["Боковая шахта Рудокопа Джонсона"] = "Miner Johnson's side shaft",
    ["После Рак’Зора, по дороге к Сниду, загляни в тупиковое ответвление шахты. Там может появиться «Шахтер Джонсон»."] = "After Rhahk’Zor, on the way to Sneed, look into the dead-end branch of the mine. Miner Johnson can appear there.",
    ["Особый предмет"] = "Special item",
    ["Топор, которым добывают руду"] = "An axe that mines ore",
    ["С Рак’Зора может выпасть «Камнерез». Его активный эффект добывает медь, олово, серебро и железо даже без горного дела."] = "Rhahk’Zor can drop Stonecutter. Its use effect mines copper, tin, silver and iron even without Mining.",
    ["Зацепка"] = "Lead",
    ["Кольцо первого помощника"] = "First mate's ring",
    ["First Mate Band из Мёртвых копей входит в комплект Partners in Crime. Достоверного маршрута ко второму кольцу в проверенных источниках нет."] = "First Mate Band from The Deadmines is part of the Partners in Crime set. Verified sources give no reliable route to the second ring.",
    ["Боковой маршрут"] = "Side route",
    ["Как найти Баззалана"] = "How to find Bazzalan",
    ["Перед Джергошем сверни направо на подъём. Наверху находится Баззалан с двумя охранниками. По нижнему маршруту его легко пропустить."] = "Before Jergosh, turn right up the slope. Bazzalan is at the top with two guards. On the lower route he is easy to miss.",
    ["Бругал Железный Кулак"] = "Bruegal Ironknuckle",
    ["Проверь боковые камеры Тюрьмы. В одной из них иногда появляется «Бругал Железный Кулак». Его наличие зависит от копии."] = "Check the side cells of The Stockade. Bruegal Ironknuckle sometimes appears in one of them. Whether he is there depends on the instance.",
    ["Лопата для могил"] = "Shovel for the graves",
    ["Для могил нужна лопата. Сначала добудь её у Декстрена Варда в Тюрьме Штормграда."] = "The graves need a shovel. First get it from Dextren Ward in the Stormwind Stockade.",
    ["С «Декстрен Вард» в Тюрьме может выпасть Graverobber’s Shovel. Примени её на могиле в крыле «Кладбище» Монастыря Алого ордена или на Вороньем холме в Сумеречном лесу."] = "Dextren Ward in The Stockade can drop the Graverobber’s Shovel. Use it on a grave in the Graveyard wing of Scarlet Monastery or on Raven Hill in Duskwood.",
    ["У лопаты 20 зарядов. Надёжной таблицы всех находок для этих могил пока нет."] = "The shovel has 20 charges. There is no reliable table of everything these graves can give yet.",
    ["Болотный ужас на северном раскопе"] = "Swamp horror at the northern dig",
    ["На севере раскопок ищи Highland Horror среди слизней. Это необязательный противник для задания Альянса. Его можно обойти по основному маршруту."] = "In the north of the excavation, look for Highland Horror among the oozes. It is an optional enemy for an Alliance quest. The main route goes around it.",
    ["Спрятанное задание"] = "Hidden quest",
    ["Реликвия с последнего стража"] = "Relic from the last guardian",
    ["В конце раскопок нажми на архивную панель возле неподвижного Relic Guardian. После боя возьми Titan Relic с останков и открой её из сумки."] = "At the end of the excavation, click the archive panel near the motionless Relic Guardian. After the fight, take the Titan Relic from the remains and open it from your bag.",
    ["Тайник • Альянс"] = "Cache • Alliance",
    ["Табличка в последнем хранилище"] = "Tablet in the last vault",
    ["После Durgen Dirgehammer осмотри хранилище за дверью в последнем зале, прежде чем идти к рычагу выхода. Табличка внутри начинает задание Альянса «Соглашение о взаимопонимании»."] = "After Durgen Dirgehammer, search the vault behind the door in the last hall before going to the exit lever. The tablet inside starts the Alliance quest Memorandum of Understanding.",
    ["Тайная комната"] = "Secret room",
    ["Подводная комната элементаля"] = "Underwater elemental room",
    ["Дойди до Глубинных архивов и сверни направо: там вход в затопленные тоннели."] = "Reach the Deep Archives and turn right: that is the way into the flooded tunnels.",
    ["Ныряй и плыви по тоннелю до конца. Видишь лестницу у комнаты Вар'таки (Var'Taka) — плывёшь правильно."] = "Dive and swim to the end of the tunnel. If you see the stairs by Var'Taka's room, you are on the right way.",
    ["В конце тоннеля — подводная комната с элементалем (Primeval Elemental): там бой."] = "At the end of the tunnel is the underwater room of the Primeval Elemental: a fight there.",
    ["Ключ"] = "Key",
    ["Связка надзирателя и нижний этаж"] = "Overseer's keyring and the lower floor",
    ["На верхнем этаже найди боковую караульную: там надзиратель Рекс (Overseer Wrex)."] = "On the upper floor find the side guard room: Overseer Wrex is there.",
    ["Убей его — выпадет связка ключей надзирателя (Overseer’s Keyring)."] = "Kill him: he drops the Overseer's Keyring.",
    ["Связка открывает запертую дверь вниз, на нижний этаж."] = "The keyring opens the locked door down to the lower floor.",
    ["Два разных ключа огров"] = "Two different ogre keys",
    ["С владыки Магга (Overlord Mugg) падает ключ огров (Krol’dok Ogre Key). По одному отчёту он открывает короткий путь под горой — точно не проверено."] = "Overlord Mugg drops the Krol'dok Ogre Key. One group's report ties it to a shortcut under the mountain; not confirmed.",
    ["Второй ключ (Krol’dok Compound Key) делается по заданию «Крол'докская форма» из ингредиентов. Какую дверь он открывает — пока неизвестно."] = "The second key, the Krol'dok Compound Key, is made through the quest Krol'dok Moulding from its ingredients. Which door it opens is not known yet.",
    ["Призывает ли ритуальный тотем духа?"] = "Does the ritual totem summon a spirit?",
    ["В источниках есть Unbound Spirit и квестовый Blackmaw Ritual Totem. Подтверждения, что тотем призывает босса или открывает тайник, пока нет."] = "Sources mention Unbound Spirit and the quest item Blackmaw Ritual Totem. There is no confirmation yet that the totem summons a boss or opens a cache.",
    ["Зачем брать кристаллы Ун’Горо"] = "Why bring Un’Goro crystals",
    ["Собери силовые кристаллы в кратере Ун’Горо и возьми их к консолям террасы."] = "Collect power crystals in Un’Goro Crater and bring them to the terrace consoles.",
    ["По дороге собери Power Crystals в кратере Ун’Горо и возьми их внутрь для консолей титанов. Точные комбинации для особой награды или скрытого босса не подтверждены."] = "On the way, collect Power Crystals in Un’Goro Crater and bring them inside for the titan consoles. Exact combinations for a special reward or a hidden boss are not confirmed.",
    ["Спрятанное задание • Орда"] = "Hidden quest • Horde",
    ["Книга из библиотеки Даларана"] = "A book from the Dalaran library",
    ["У входа в канализацию возьми у Rexxie Copperclutch задание Opportunistic Education (с 24-го уровня)."] = "At the sewer entrance, pick up the quest Opportunistic Education from Rexxie Copperclutch (level 24+).",
    ["На поверхности пройди через зал порталов в библиотеку святилища Альянса. Книга The Founding of Dalaran стоит у дальней стены."] = "On the surface, go through the portal hall to the library of the Alliance sanctuary. The book The Founding of Dalaran stands by the far wall.",
    ["Подрыв тоннеля и Грязнюк"] = "Tunnel blasting and Grubbis",
    ["В Зале Чистоты найди подрывницу Эми Короткий Запал у обваленного прохода. Собери группу перед разговором."] = "In the Clean Room, find the demolitionist Emi Shortfuse at the collapsed passage. Gather your party before talking to her.",
    ["Защищай её от троггов, пока она подрывает тоннели. Под конец появятся Грязнюк и его василиск."] = "Protect her from the troggs while she blows up the tunnels. Near the end Grubbis and his basilisk appear.",
    ["Что делать с покрытыми грязью предметами"] = "What to do with grime-encrusted items",
    ["Отнеси «Предмет, покрытый грязью» в Чистую зону. Найди там автомат «Чистер 5200»."] = "Take the Grime-Encrusted Item to The Clean Zone. Find the Sparklematic 5200 machine there.",
    ["Опусти предмет и 3 серебряных. Открой выданную автоматом посылку."] = "Insert the item and 3 silver. Open the package the machine gives you.",
    ["Три редких противника на кладбище"] = "Three rare enemies in the Graveyard",
    ["Во дворе кладбища осмотри надгробия по сторонам главной дорожки. Здесь встречаются Железноспин, Павший воитель и Азшир Неспящий."] = "In the Graveyard courtyard, search the gravestones along both sides of the main path. Ironspine, Fallen Champion and Azshir the Sleepless appear here.",
    ["У них несколько возможных мест появления. Если обычные боссы уже убиты, всё равно загляни в боковые ряды."] = "They have several possible spawn points. Even if the regular bosses are dead, still look into the side rows.",
    ["Тайник чародея Доана"] = "Arcanist Doan's cache",
    ["После победы над Доаном в конце библиотеки обыщи сундук «Сейф Доана» в его комнате."] = "After defeating Doan at the end of the Library, loot the chest Doan's Strongbox in his room.",
    ["Забери Алый ключ. Он открывает двери в Оружейную и Собор."] = "Take The Scarlet Key. It opens the doors to the Armory and the Cathedral.",
    ["Гербовая накидка Алого ордена"] = "Tabard of the Scarlet Crusade",
    ["Убей Герода и дождись, когда по лестнице сбегут послушники из его группы поддержки."] = "Kill Herod and wait for the trainees of his support group to run down the stairs.",
    ["Накидка «Гербовая накидка Алого ордена» может выпасть с послушников. Осмотри их тела после боя."] = "The Tabard of the Scarlet Crusade can drop from the trainees. Search their bodies after the fight.",
    ["Инквизитор Фэйрбанкс за стеной"] = "Inquisitor Fairbanks behind the wall",
    ["Внутри собора зайди в боковую комнату справа от алтаря. Нажми на факел на стене."] = "Inside the Cathedral, go into the side room to the right of the altar. Click the torch on the wall.",
    ["За открывшейся стеной находится инквизитор Фэйрбанкс."] = "High Inquisitor Fairbanks is behind the opened wall.",
    ["Головоломка"] = "Puzzle",
    ["Как открыть зал Иронайи"] = "How to open Ironaya's chamber",
    ["Отдай одному игроку Shaft of Tsol с Ревелоша и медальон Gni’kiv из сундука у Бейлога. Соедини их в посох."] = "Give one player the Shaft of Tsol from Revelosh and the Gni’kiv Medallion from the chest by Baelog. Combine them into the staff.",
    ["В Зале Карт используй посох на макете города. Дверь к Иронайе откроется."] = "In the Map Chamber, use the staff on the model of the city. The door to Ironaya opens.",
    ["Как вызвать учителя чар Аннору"] = "How to call on the enchanting trainer Annora",
    ["Для обучения у Анноры возьми материалы для чар. Ближе через задний вход в Бесплодных землях."] = "To train with Annora, bring enchanting materials. It is closer via the back entrance in the Badlands.",
    ["К её пещере короче идти от заднего входа в Ульдаман в Бесплодных землях (66, 43)."] = "The shortest way to her cave is from the back entrance to Uldaman in the Badlands (66, 43).",
    ["Убей всех скорпидов в её помещении. После зачистки появится Аннора."] = "Kill all the scorpids in her room. Annora appears once it is cleared.",
    ["Сокращение пути"] = "Shortcut",
    ["Скипетр и короткий путь к водопаду"] = "Scepter and the shortcut to the waterfall",
    ["В пещере перед порталом возьми Legends of Maraudon у Кавиндры на оранжевой стороне."] = "In the cave before the portal, pick up Legends of Maraudon from Cavindra on the orange side.",
    ["Возьми «Легенды Мародона». В оранжевом крыле добудь жезл у Ноксиона, в фиолетовом — самоцвет у Вилетонга."] = "Pick up Legends of Maraudon. In the orange wing get the rod from Noxxion, in the purple wing the diamond from Lord Vyletongue.",
    ["Победи Келебраса и поговори с его освобождённым духом. Заверши ритуал, получи скипетр и используй его у портала в пещере перед инстом, чтобы попасть к водопаду."] = "Defeat Celebras and talk to his freed spirit. Complete the ritual, get the scepter and use it at the portal in the cave before the instance to reach the waterfall.",
    ["Мешлок Жнец"] = "Meshlok the Harvester",
    ["На пути между крыльями и центральной частью Мародона проверь, появился ли «Мешлок Жнец». Это редкий древень."] = "On the way between the wings and the central part of Maraudon, check whether Meshlok the Harvester has spawned. He is a rare ancient.",
    ["Шесть статуй и Атал’аларион"] = "Six statues and Atal'alarion",
    ["Для награды за статуи возьми Secret of the Circle у Марвона в Танарисе."] = "For the statue reward, pick up Secret of the Circle from Marvon in Tanaris.",
    ["На кольцевом ярусе нажми статуи по сторонам света в этом порядке — юг, север, юго-запад, юго-восток, северо-запад, северо-восток."] = "On the circular level, click the statues by compass point in this order — south, north, southwest, southeast, northwest, northeast.",
    ["Спустись к бассейну и победи Атал’алариона. Если выполняешь «Тайна камня», нажми появившуюся в центре статую змеи."] = "Go down to the pool and defeat Atal'alarion. If you are on Secret of the Circle, click the serpent statue that appears in the center.",
    ["Призыв"] = "Summoning",
    ["Аватара Хаккара"] = "Avatar of Hakkar",
    ["Для призыва возьми у Йе’киньи задание на яйцо Хаккара или принеси его свиток после цепочки."] = "To summon, pick up the Egg of Hakkar quest from Yeh'kinya or bring Yeh'kinya's Scroll after the chain.",
    ["Для запуска в святилище нужен участник с яйцом по заданию «Бог Хаккар» или со свитком Йе’киньи за пройденную цепочку."] = "To start it in the sanctum you need a party member with the egg from The God Hakkar or with Yeh'kinya's Scroll for the finished chain.",
    ["Начни ритуал, забирай кровь с хранителей крови и гаси ею четыре жаровни. После этого появится Аватара."] = "Start the ritual, take blood from the Bloodkeepers and use it to put out the four braziers. Then the Avatar appears.",
    ["Молот и гонг Газ’риллы"] = "Gahz'rilla's mallet and gong",
    ["Во Внутренних землях забери священный молот у «Квиага Хранительница» на Алтаре Зула. Используй его у алтаря на вершине Джинта’Алора. Алтарь Зула — 48.6, 68.2. Вершина Джинта’Алора — 59, 77."] = "In The Hinterlands, take the Sacred Mallet from Qiaga the Keeper at the Altar of Zul. Use it at the altar on top of Jintha'Alor. Altar of Zul — 48.6, 68.2. Top of Jintha'Alor — 59, 77.",
    ["С готовым молотом Зул’Фаррака ударь в гонг у бассейна внутри инста. Из воды выйдет Газ’рилла."] = "With the finished Mallet of Zul'Farrak, strike the gong by the pool inside the instance. Gahz'rilla rises from the water.",
    ["Пленники на пирамиде и взрыв ворот"] = "Prisoners on the pyramid and blowing the gate",
    ["Забери у палача ключ и открой клетки наверху лестницы. Защищай освобождённых от волн троллей."] = "Take the key from the executioner and open the cages at the top of the stairs. Protect the freed prisoners from waves of trolls.",
    ["Выживший гоблин Вигли может взорвать ворота. Дай ему открыть проход, прежде чем требовать у сержанта Блая жезл по заданию."] = "Weegli Blastfuse, the surviving goblin, can blow up the gate. Let him open the way before you demand the rod from Sergeant Bly for the quest.",
    ["Харли и три бочонка"] = "Hurley and the three kegs",
    ["В таверне «Угрюмый обжора» найди маленькую кладовую с бочонками громового эля."] = "In The Grim Guzzler, find the small storeroom with the Thunderbrew Lager kegs.",
    ["Разбей три бочонка. Сразу после третьего к группе побежит «Харли Пьянодых» со своей компанией."] = "Break three kegs. Right after the third, Hurley Blackbreath and his crew run at the party.",
    ["Портрет подсказывает, кто несёт ключ"] = "The portrait shows who carries the key",
    ["В банке открой портрет Хранителя Тьмы (Dark Keeper Portrait) и прочитай табличку — имя и место меняются между заходами."] = "In the Vault, click the Dark Keeper Portrait and read the plaque — the name and place change between runs.",
    ["Найди указанного хранителя и забери «Ключ темного хранителя». Вернись и открой особый сундук «Черный ящик»."] = "Find the named keeper and take the Dark Keeper Key. Go back and open the special chest, the Secret Safe.",
    ["Погоня за Пузиллином"] = "Chasing Pusillin",
    ["У входа в восточное крыло поговори с бесом Пузиллином. Каждый раз, когда он остановится, догоняй и снова говори с ним."] = "At the entrance to the east wing, talk to Pusillin the imp. Each time he stops, catch up and talk to him again.",
    ["На последней площадке он вступит в бой. Забери «Серповидный ключ», открывающий другие части Забытого Города."] = "At the last spot he enters combat. Take the Crescent Key, which opens other parts of Dire Maul.",
    ["Особая награда"] = "Special reward",
    ["Дань огров за пощаду стражей"] = "Ogre tribute for sparing the guards",
    ["Для дани возьми Frost Oil, Thorium Widget и костюм огра либо материалы для его пошива."] = "For the tribute, bring Frost Oil, a Thorium Widget and an ogre suit or the materials to make one.",
    ["Для полного сундука дани обойди стражей. Для ловушки Слип’кика возьми «Масло льда» и «Ториевое устройство», для Кромкруша приготовь костюм огра."] = "For the full tribute chest, get past the guards. For Slip'kik's trap bring Frost Oil and a Thorium Widget, for Kromcrush prepare an ogre suit.",
    ["Убей короля Гордока, сохранив в живых советника Чо’Раша и остальных боссов. После боя поговори с «Миззл Умелец» и забери дань."] = "Kill King Gordok while keeping Cho'Rush the Observer and the other bosses alive. After the fight, talk to Mizzle the Crafty and take the tribute.",
    ["Призыв лорда Хел’нурата"] = "Summoning Lord Hel'nurath",
    ["Для призыва нужен чернокнижник на этапе ритуала эпического скакуна с ритуальными предметами."] = "Summoning requires a warlock at the epic mount ritual stage with the ritual items.",
    ["Нужен чернокнижник на этапе ритуала эпического скакуна с предметами для призыва. Освободи площадку, победив Бессмер’тера."] = "Requires a warlock at the epic mount ritual stage with the summoning items. Clear the area by defeating Immol'thar.",
    ["Проведи ритуал в его круге, защищая и поддерживая ритуальные предметы. В конце появятся скакун и лорд Хел’нурат."] = "Perform the ritual in its circle, protecting and maintaining the ritual items. At the end the steed and Lord Hel'nurath appear.",
    ["Кому показать очищенную сферу"] = "Who to show the cleansed orb to",
    ["Сначала очисти сферу в Хиджале и вернись к Морденту. После этого иди к принцу."] = "First cleanse the orb in Hyjal and return to Mordent. Then go to the prince.",
    ["Заверши очищение сферы из Непроглядной Пучины в Хиджале и вернись к Морденту. Следующий собеседник — принц Тортелдрин в западном крыле Забытого Города."] = "Finish cleansing the orb from Blackfathom Deeps in Hyjal and return to Mordent. Next, talk to Prince Tortheldrin in the west wing of Dire Maul.",
    ["Подтверждённые шаги до очищения приведены в карточках Непроглядной Пучины."] = "The confirmed steps up to the cleansing are on the Blackfathom Deeps cards.",
    ["Урок Роковой Вой и груда подношений"] = "Urok Doomhowl and the Tribute Pile",
    ["Забери голову вождя Омокка и «Копье грубой силы» со стойки с копьями."] = "Take Omokk's Head from Highlord Omokk and the Roughshod Pike from the spear rack.",
    ["За Матерью Дымной Паутиной найди груду подношений (Tribute Pile). Используй предметы у груды и отбей огров, пока не появится Урок."] = "Behind Mother Smolderweb, find the Tribute Pile. Use the items at the pile and fight off the ogres until Urok appears.",
    ["Мясник и Баннок"] = "Butcher and Bannok",
    ["В нижней части пика осмотри область огров на предмет «Мясник из клана Черной Вершины». В лагере орков проверь, появился ли «Баннок Люторез»."] = "In the lower part of the Spire, check the ogre area for the Spirestone Butcher. In the orc camp, check whether Bannok Grimaxe has spawned.",
    ["Солакар и Пламя Отца"] = "Solakar and the Father Flame",
    ["В инкубаторе пройди вдоль левой стены до алтаря «Огонь отцов». Поговори с группой перед активацией — сразу начнутся волны."] = "In the Rookery, walk along the left wall to the Father Flame altar. Talk to your party before activating it — the waves start at once.",
    ["Защищай площадку, пока не появится «Солакарский огнечервь»."] = "Defend the platform until Solakar Flamewreath appears.",
    ["Гном внутри Зверя"] = "The gnome inside The Beast",
    ["Чтобы освободить гнома, возьми в группу кожевника, способного снять шкуру со Зверя."] = "To free the gnome, bring a skinner into the party who can skin The Beast.",
    ["Возьми с собой опытного кожевника. После убийства Зверя собери добычу и сними с него шкуру."] = "Bring an experienced skinner. After killing The Beast, loot it and skin it.",
    ["Из туши выберется гном. Поговори с ним, пока группа ещё в подземелье."] = "A gnome climbs out of the carcass. Talk to him while the party is still in the dungeon.",
    ["Кровь невинных и Киртонос"] = "Blood of Innocents and Kirtonos",
    ["Возьми Blood of Innocents у Евы Саркофф на острове Каэр Дарроу после её заданий."] = "Pick up Blood of Innocents from Eva Sarkhoff on Caer Darrow island after her quests.",
    ["Пройди задания Евы Саркофф в Каэр Дарроу до получения Blood of Innocents."] = "Do Eva Sarkhoff's quests in Caer Darrow until you get Blood of Innocents.",
    ["В Некроситете всей группой выйди на балкон и используй кровь на жаровне Вестника. Решётка закроется до прилёта Киртоноса."] = "In Scholomance, take the whole party onto the balcony and use the blood on the Brazier of the Herald. The gate closes before Kirtonos arrives.",
    ["Что делать в смотровой комнате"] = "What to do in the Viewing Room",
    ["Возьми устройство Dawn’s Gambit у Бетины в часовне Последней Надежды."] = "Pick up the Dawn's Gambit device from Betina in Light's Hope Chapel.",
    ["Возьми задание «Рассветный гамбит» у Бетины Биггльцинк и принеси выданное устройство в Viewing Room."] = "Pick up the quest Dawn's Gambit from Betina Bigglezink and bring the device she gives you to the Viewing Room.",
    ["Установи его в комнате учеников. После превращения учеников победи Вектуса."] = "Set it up in the students' room. After the students transform, defeat Vectus.",
    ["Три почтовых ящика и почтальон Мэлоун"] = "Three postboxes and Postmaster Malown",
    ["Убей курьера и забери его ключи. Названия ключей указывают, какие почтовые ящики надо найти в городе."] = "Kill the courier and take his keys. The key names show which postboxes to find in the city.",
    ["Открой все три ящика. Будь готов к засадам — у последнего появится почтальон Мэлоун."] = "Open all three boxes. Be ready for ambushes — Postmaster Malown appears at the last one.",
    ["Табачный ящик Фраса Сиаби"] = "Fras Siabi's tobacco box",
    ["Для табака возьми задание The Great Fras Siabi у Смоки в часовне Последней Надежды."] = "For the tobacco, pick up the quest The Great Fras Siabi from Smokey in Light's Hope Chapel.",
    ["Для задания The Great Fras Siabi найди ящик с табаком у магазина Фраса и нажми на него."] = "For the quest The Great Fras Siabi, find the tobacco box by Fras's shop and click it.",
    ["Появится хозяин. После победы забери табак для задания."] = "The owner appears. After defeating him, take the tobacco for the quest.",
    ["Испытание на время"] = "Timed challenge",
    ["Спасти Изиду до казни"] = "Save Ysida before the execution",
    ["Для задания на спасение Изиды возьми прибор Extra-Dimensional Ghost Revealer из цепочки. С ним поговори с призраком Антиона у Стратхольма."] = "For the Ysida rescue quest, get the Extra-Dimensional Ghost Revealer from the chain. With it, talk to Anthion's ghost near Stratholme.",
    ["Если идёшь по заданию «Просьба мертвеца», подготовь группу у внутренних ворот Gauntlet Gate. Когда их откроют, начнётся отсчёт 45 минут."] = "If you are on Dead Man's Plea, gather the party at the inner Gauntlet Gate. Once it opens, a 45-minute countdown starts.",
    ["Зачисти три зиккурата и прорвись к барону Ривендеру до истечения времени. После боя поговори с Изидой."] = "Clear the three ziggurats and break through to Baron Rivendare before time runs out. After the fight, talk to Ysida.",
    ["Каменный Гребень"] = "Stonespine",
    ["В квартале нежити следи за патрулями горгулий. У редкой горгульи «Каменный Гребень» собственная таблица добычи."] = "In the undead quarter, watch the gargoyle patrols. The rare gargoyle Stonespine has its own loot table.",
    ["Капитан на западной улице"] = "The captain on the west street",
    ["После зачистки проверь улицу от дома с камином к северо-западу. Игроки встретили там Lordaeron Captain. Убийство остальных боссов не гарантирует его появления."] = "After clearing, check the street northwest of the house with the fireplace. Players have met the Lordaeron Captain there. Killing the other bosses does not guarantee he spawns.",
    ["Gill и Umbra"] = "Gill and Umbra",
    ["В проходе Глубинных архивов, по дороге к элементалю, иногда стоит Гилл (Gill). Он кидает динамит — не стойте кучей."] = "In the passage of the Deep Archives, on the way to the elemental, Gill is sometimes there. He throws dynamite: don't stand bunched up.",
    ["Ещё одна редкая встреча — Умбра (Umbra) с пятью мурлоками. Их кровотечения складываются: бейте одну группу, соседние не задевайте."] = "Another rare encounter: Umbra with five murlocs. Their bleeds stack: fight one group and leave the next ones alone.",
    ["Зверь с клинком двух лун"] = "The beast with the Claymore of Two Moons",
    ["Осматривай зверей по дороге через оплот. Moontouched Wanderer — редкая элита 55-го уровня. Игроки видели с него двуручный меч Claymore of Two Moons."] = "Check the beasts on the way through the stronghold. Moontouched Wanderer is a level 55 rare elite. Players have seen it drop the two-handed sword Claymore of Two Moons.",
    ["Площадка Босса Туфа"] = "Bossman Toof's platform",
    ["Пройди длинный деревянный мост."] = "Cross the long wooden bridge.",
    ["Перед подъёмом к Маггу есть площадка с шаманами — там стоит Босс Туф (Bossman Toof)."] = "Before the climb to Mugg there is a platform with shamans: Bossman Toof stands there.",
    ["С него своя добыча, в том числе Toofbreaker и Big-Belly Belt."] = "He has his own loot, Toofbreaker and the Big-Belly Belt among it.",
    ["Профессии"] = "Professions",
    ["Два рецепта пленника Генри Штерна"] = "Two recipes from the prisoner Henry Stern",
    ["В загонах освободи Генри Штерна и поговори с ним. Повар может узнать рецепт чая из златошипа, алхимик — рецепт зелья тролльей крови."] = "In the pens, free Henry Stern and talk to him. A cook can learn the Goldthorn Tea recipe, an alchemist the Mighty Troll's Blood Potion recipe.",
    ["Задание • Альянс"] = "Quest • Alliance",
    ["Перфокарты для «Спасения данных»"] = "Punch cards for Data Rescue",
    ["Призматическая перфокарта нужна для задания «Спасение данных» — Чугунотрубз, Стальгорн. Белая карта падает с троггов и лепрогномов в тоннелях перед порталом."] = "The Prismatic Punch Card is needed for the quest Data Rescue — Master Mechanic Castpipe, Ironforge. The White Punch Card drops from troggs and leper gnomes in the tunnels before the portal.",
    ["Перфограф 3005-A стоит в мастерской перед порталом (22, 33): белая карта станет жёлтой."] = "Matrix Punchograph 3005-A is in the workshop before the portal (22, 33): the white card becomes yellow.",
    ["Внутри по порядку: 3005-B в спальном блоке — синяя, 3005-C на верхней площадке у Электрошокера 6000 — красная, 3005-D на нижнем ярусе инженерных лабораторий — призматическая."] = "Inside, in order: 3005-B in The Dormitory — blue, 3005-C on the upper platform by Electrocutioner 6000 — red, 3005-D on the lower level of the Engineering Labs — prismatic.",
    ["Только инженерам"] = "Engineers only",
    ["Чертёж у перфографа 3005-D"] = "Schematic at Punchograph 3005-D",
    ["Инженерное дело"] = "Engineering",
    ["Нужны навык инженерного дела 160 и Карта безопасного доступа ДЕЛЬТА. Она падает с механизмов внутри и с Термоштепселя."] = "Requires Engineering skill 160 and the Security DELTA Data Access Card. It drops from mechanical units inside and from Thermaplugg.",
    ["С картой подойди к перфографу 3005-D на нижнем ярусе инженерных лабораторий, западная сторона. Он обучит анти-перенаправляющему лучу. Перфокарты для этого не нужны."] = "With the card, go to Punchograph 3005-D on the lower level of the Engineering Labs, west side. It teaches the anti-redirection ray. No punch cards are needed for this.",
    ["Собрать эпический меч из двух клинков"] = "Assemble an epic sword from two blades",
    ["Сохрани оба редких клинка, Jang’thraze и Sang’thraze, с Анту’сула и вождя Укорза. Когда оба будут у одного персонажа, используй эффект объединения, чтобы получить «Кара Суль'траза»."] = "Keep both rare blades, Jang'thraze and Sang'thraze, from Antu'sul and Chief Ukorz Sandscalp. When one character has both, use the combine effect to get Sul'thraze the Lasher.",
    ["Награда за освобождение гоблина"] = "Reward for freeing the goblin",
    ["Если с огров выпадет «Ключ от оков клана Гордок», найди пленного «Уззл Наперстяк». До освобождения закончи с ним дела, включая пошив костюма огра."] = "If the ogres drop the Gordok Shackle Key, find the captive Knot Thimblejack. Before freeing him, finish your business with him, including tailoring the ogre suit.",
    ["Сними его оковы. После побега на месте останется «Тайник Уззла Наперстяка» с материалами и шансом на рецепт."] = "Remove his shackles. After he escapes, Knot Thimblejack's Cache stays behind with materials and a chance at a recipe.",
    ["Квест, который берут в облике призрака"] = "A quest picked up as a ghost",
    ["По пути в инст поговори с Франклорном в облике призрака в центральной гробнице Чёрной горы."] = "On the way to the instance, talk to Franclorn as a ghost in the central tomb of Blackrock Mountain.",
    ["В облике призрака по пути к инсту зайди в центральную гробницу Чёрной горы. Поговори с Франклорном Искусником и возьми «Наследие Черного Железа»."] = "As a ghost, on the way to the instance, enter the central tomb of Blackrock Mountain. Talk to Franclorn Forgewright and pick up Dark Iron Legacy.",
    ["Внутри глубин добудь «Железный Друг» у «Точень Темнострой» и отнеси его к статуе Франклорна за ключом Тенегорна."] = "Inside the Depths, get Ironfel from Fineous Darkvire and take it to Franclorn's statue for the Shadowforge Key.",
    ["Три редких тролля Зул’Фаррака"] = "Three rare trolls of Zul'Farrak",
    ["Во время обхода ищи «Зериллис», «Сандарр Разоритель Барханов» и «Пыльный призрак». Случайное появление каждого означает, что за один заход можно никого не встретить."] = "While clearing, look for Zerillis, Sandarr Dunereaver and Dustwraith. Each spawns at random, so you may meet none of them in a single run.",
    ["Скул и менестрель"] = "Skul and the minstrel",
    ["На жилых улицах города проверяй боковые проходы. Тут можно встретить редких противников «Череп» и «Певчий Форрестен» — у каждого своя добыча."] = "Check the side passages on the city's residential streets. You can meet the rares Skul and Hearthsinger Forresten here — each has its own loot.",
    ["Тсу’зи в столице садов"] = "Tsu'zee in the Capital Gardens",
    ["В западном крыле среди призраков проверь, появилась ли редкая противница «Цу'зи»."] = "In the west wing, check among the ghosts whether the rare Tsu'zee has spawned.",
    ["Посол Чёрного Железа"] = "Dark Iron Ambassador",
    ["Проверь квартал Чёрного Железа. Среди дворфов иногда появляется «Посол из клана Черного Железа»."] = "Check the Dark Iron quarter. The Dark Iron Ambassador sometimes appears among the dwarves.",
    ["Круглорыл"] = "Ragglesnout",
    ["В Залах Иглошкурых на пути через холм осмотри площадки. Здесь может появиться редкий свинобраз «Круглорыл»."] = "In Razorfen Downs, check the platforms on the way over the hill. The rare quilboar Ragglesnout can spawn here.",
    ["Пиромант и редкий голем"] = "The pyromancer and the rare golem",
    ["Проверь район Святилища Призыва на присутствие «Пироман Зерно Мудрости». В мастерских големов может появиться «Панцер Непобедимый»."] = "Check the Summoners' Tomb area for Pyromancer Loregrain. Panzor the Invincible can spawn in the golem workshops.",
    ["Другие редкие обитатели нижнего пика"] = "Other rares of the lower Spire",
    ["У огров проверь «Полководец из клана Черной Вершины» и «Лорд-волхв из клана Черной Вершины». Среди пауков может появиться «Хрустальный Клык»."] = "Among the ogres, check for the Spirestone Battle Lord and the Spirestone Lord Magus. Crystal Fang can spawn among the spiders.",
    ["В перечне редких встреч также есть «Гок Крепкобив» и «Пылающий страж Скверны». Их присутствие в конкретном заходе меняется."] = "The rare list also includes Ghok Bashguud and Burning Felguard. Whether they appear changes from run to run.",
    ["Джед Руновед"] = "Jed Runewatcher",
    ["В зале пироманта Углевзора проверь, появился ли «Джед Руновед». У Джеда может выпасть аксессуар для заклинателей «Пищик из древесины шиповника»."] = "In Pyroguard Emberseer's hall, check whether Jed Runewatcher has spawned. Jed can drop Briarwood Reed, a trinket for casters.",
    ["Перед входом"] = "Before the entrance",
    ["Библиотечная книга у Пещер Стенаний"] = "Library book by the Wailing Caverns",
    ["Подбери Secrets of the Dreamers в пещере у Цветущего оазиса до портала."] = "Pick up Secrets of the Dreamers in the cave by Lushwater Oasis before the portal.",
    ["В пещере у Цветущего оазиса до портала инста осмотри свитки. Там лежит «Тайны Дремлющих» для библиотеки. Забрать её можно по пути к группе."] = "In the cave by Lushwater Oasis, before the instance portal, check the scrolls. Secrets of the Dreamers lies there for the library. You can grab it on the way to the party.",
    ["В Алказе заберите связку у надзирателя Рекса. Она открывает нижний этаж."] = "In Alcaz Prison, take the keyring from Overseer Wrex. It opens the lower floor.",
    ["В Пучине за Келрисом зажигайте огни по одному. Каждый выпускает свою волну."] = "In Blackfathom Deeps, past Kelris, light the fires one at a time. Each one releases its own wave.",
    ["В Оплоте Чёрной Пасти проверьте, появился ли Moontouched Wanderer. Это редкий зверь с отдельной добычей."] = "In Blackmaw Hold, check whether Moontouched Wanderer has appeared. It is a rare beast with its own loot.",
    ["В Глубинах Чёрной горы прочитайте табличку у портрета в банке: она укажет, какой хранитель несёт ключ."] = "In Blackrock Depths, read the plaque by the portrait in the vault: it tells which keeper carries the key.",
    ["На Лин в Даларане нужен том. Возьмите книгу со стола Аругала в Крепости Тёмного Клыка и зарядите её в Янтарной Мельнице."] = "Lyn in Dalaran needs a tome. Take the book from Arugal's table in Shadowfang Keep and charge it at Ambermill.",
    ["В восточном Забытом Городе поговорите с Пузиллином у входа и догоняйте его на остановках ради ключа."] = "In Dire Maul East, speak to Pusillin at the entrance and catch him at each stop for the key.",
    ["Идёте за полной данью огров? Подготовьте костюм огра, морозное масло и ториевое устройство и пощадите стражей."] = "Going for the full ogre tribute? Bring an ogre suit, Frost Oil and a Thorium Widget, and spare the guards.",
    ["В западном Забытом Городе чернокнижник с предметами для ритуала скакуна может призвать Хел’нурата после Бессмер’тера."] = "In Dire Maul West, a warlock with the Dreadsteed ritual items can summon Lord Hel'nurath after Immol'thar.",
    ["На раскопках в Болотине после боя со стражем подберите реликвию титанов и проверьте её в сумке."] = "At the Wetlands excavation, after the fight with the guardian, pick up the Titan Relic and inspect it in your bags.",
    ["В Гномрегане оставьте покрытые грязью предметы для автомата в Чистой зоне. Приготовьте по 3 серебряных."] = "In Gnomeregan, keep Grime-Encrusted Objects for the Sparklematic in the Clean Zone. Have 3 silver for each.",
    ["В Чертогах Танов игроки Альянса могут взять задание с таблички в хранилище за последним боссом."] = "In the Hall of Thanes, Alliance players can pick up a quest from the tablet in the vault past the last boss.",
    ["В Крол’доке после деревянного моста проверьте площадку с шаманами. Там стоит Bossman Toof."] = "In Krol'dok, after the wooden bridge, check the platform with the shamans. Bossman Toof stands there.",
    ["На нижнем пике сохраните голову Омокка и копьё Roughshod Pike. Они нужны у груды подношений для вызова Урока."] = "In Lower Blackrock Spire, keep Omokk's Head and the Roughshod Pike. They are needed at the tribute pile to summon Urok.",
    ["Для скипетра Мародона возьмите задание у Кавиндры до портала. Детали падают в оранжевом и фиолетовом крыльях."] = "For the Maraudon scepter, pick up the quest from Cavindra before the portal. The pieces drop in the orange and purple wings.",
    ["В Огненной пропасти перед Джергошем поднимитесь направо к Баззалану. По нижнему пути его легко пропустить."] = "In Ragefire Chasm, before Jergosh, go up to the right to Bazzalan. He is easy to miss on the lower path.",
    ["В Курганах Иглошкурых бейте в паучий гонг после каждой волны. Третий удар вызывает Тутен’каша."] = "In Razorfen Downs, strike the spider gong after each wave. The third strike summons Tuten'kash.",
    ["В Лабиринтах Иглошкурых загляните в дальний конец пещеры летучих мышей за Агафелосом: там бывает Слепой охотник."] = "In Razorfen Kraul, check the far end of the bat cave past Agathelos: the Blind Hunter can appear there.",
    ["В Руинах Лордерона соберитесь у камина в сгоревшем доме на юго-западе. Нажатие запускает волны и бой с Виктором."] = "In the Ruins of Lordaeron, gather at the fireplace in the burned house in the southwest. Using it starts the waves and the fight with Viktor.",
    ["Для Оружейной проверьте Алый ключ у группы. Свой можно взять в сундуке за Доаном в библиотеке."] = "For the Armory, check who in the party has the Scarlet Key. You can get your own from the chest behind Doan in the Library.",
    ["В Соборе Алого ордена нажмите факел в комнате справа от алтаря: за стеной спрятан Фэйрбанкс."] = "In the Scarlet Cathedral, use the torch in the room to the right of the altar: Fairbanks is hidden behind the wall.",
    ["На кладбище Алого ордена проверьте могилы сбоку от дорожки. Там могут появиться три редких противника."] = "In the Scarlet Graveyard, check the graves beside the path. Three rare enemies can appear there.",
    ["В библиотеке Алого ордена после Доана обыщите сундук за ним. Там ключ к Оружейной и Собору."] = "In the Scarlet Library, after Doan, search the chest behind him. It holds the key to the Armory and the Cathedral.",
    ["Для призыва Киртоноса в Некроситете возьмите Кровь невинных по цепочке Евы Саркофф в Каэр Дарроу."] = "To summon Kirtonos in Scholomance, get the Blood of Innocents through Eva Sarkhoff's chain at Caer Darrow.",
    ["В Крепости Тёмного Клыка после Аругала заберите чёрный том со стола. Он нужен для секретного босса Даларана."] = "In Shadowfang Keep, after Arugal, take the black tome from the table. It is needed for Dalaran's secret boss.",
    ["Перед походом на Террасу Создателя соберите силовые кристаллы в кратере Ун’Горо для консолей внутри."] = "Before heading to the Shaper's Terrace, collect power crystals in Un'Goro Crater for the consoles inside.",
    ["В жилом квартале Стратхольма заберите ключи у курьера. Третий почтовый ящик вызывает почтальона Мэлоуна."] = "On Stratholme's living side, take the keys from the courier. The third mailbox summons Postmaster Malown.",
    ["Для спасения Изиды в Стратхольме соберите группу до открытия внутренних ворот: от них идёт отсчёт 45 минут."] = "To save Ysida in Stratholme, gather the party before the inner gates open: they start a 45-minute countdown.",
    ["Статуи в Затонувшем храме: юг, север, юго-запад, юго-восток, северо-запад, северо-восток. Затем спускайтесь к бассейну."] = "Statues in the Sunken Temple: south, north, southwest, southeast, northwest, northeast. Then go down to the pool.",
    ["В Мёртвых копях после Рак’Зора проверьте боковую шахту по пути к Сниду. Там бывает Рудокоп Джонсон."] = "In the Deadmines, after Rhahk'Zor, check the side tunnel on the way to Sneed. Miner Johnson can appear there.",
    ["В Затонувшем городе, в Глубинных архивах, сверните направо и ныряйте в тоннель: он ведёт в подводную комнату элементаля."] = "In the Drowned City's Deep Archives, turn right and dive into the tunnel: it leads to the elemental's underwater room.",
    ["В Тюрьме Штормграда проверьте боковые камеры: в одной из них бывает редкий заключённый Bruegal Ironknuckle."] = "In the Stockade, check the side cells: the rare prisoner Bruegal Ironknuckle can appear in one of them.",
    ["В Ульдамане отдайте жезл Ревелоша и медальон из сундука Бейлога одному игроку. Собранный посох открывает Иронайю."] = "In Uldaman, give the Shaft of Tsol from Revelosh and the medallion from Baelog's chest to one player. The assembled staff opens Ironaya's chamber.",
    ["На верхнем пике Чёрной горы осмотрите алтарь у левой стены инкубатора. Соберитесь до активации волн Солакар."] = "In Upper Blackrock Spire, inspect the altar by the left wall of the Rookery. Gather before starting Solakar's waves.",
    ["В Пещерах Стенаний после четырёх предводителей Клыка вернитесь к ученику у входа. Сопроводите его ради Мутануса."] = "In Wailing Caverns, after the four Fanglords, return to the disciple at the entrance. Escort him for Mutanus.",
    ["Для Газ’риллы в Зул’Фарраке захватите молот из Внутренних земель. Им бьют в гонг у бассейна."] = "For Gahz'rilla in Zul'Farrak, bring the mallet from the Hinterlands. It is used to strike the gong at the pool.",
    ["север"] = "north",
    ["северо-восток"] = "northeast",
    ["восток"] = "east",
    ["юго-восток"] = "southeast",
    ["юг"] = "south",
    ["юго-запад"] = "southwest",
    ["запад"] = "west",
    ["северо-запад"] = "northwest",
    ["Клоака"] = "Underbelly",
    ["Город"] = "City",
    ["Этаж "] = "Floor ",
    ["в "] = "to ",
    ["на этаж "] = "to floor ",
    ["от входа"] = "from the entrance",
    ["от подъёма"] = "from the way up",
    ["от спуска"] = "from the way down",
    ["от перехода"] = "from the passage",
    ["от прошлого босса"] = "from the last boss",
    ["От входа"] = "From the entrance",
    ["От подъёма"] = "From the way up",
    ["От спуска"] = "From the way down",
    ["От перехода"] = "From the passage",
    ["От прошлого босса"] = "From the last boss",
    ["подъём"] = "way up",
    ["спуск"] = "way down",
    ["переход"] = "passage",
    ["подъёма"] = "the way up",
    ["спуска"] = "the way down",
    ["перехода"] = "the passage",
    ["босс"] = "boss",
    ["босса"] = "the boss",
    [" на "] = " heading ",
    [" до "] = " to ",
    ["босс отмечен на плане"] = "boss marked on the plan",
    ["Босс отмечен на плане"] = "Boss marked on the plan",
    [" отмечен на плане"] = " marked on the plan",
    ["Место на плане пока неизвестно"] = "Spot on the plan not known yet",
    ["Клоак"] = "Underbelly",
    ["Двор охотника"] = "Huntsman's Cloister",
    ["Сокровищница"] = "Gallery of Treasures",
    ["Читальня"] = "Athenaeum",
    ["нет"] = "none",
    ["скрыто"] = "hidden",
    ["%s (%s, instance %s) • зона: %s • подзона: %s • миникарта: %s • карта: %s • позиция: %s • мир: %s • направление: %s"] = "%s (%s, instance %s) • zone: %s • subzone: %s • minimap: %s • map: %s • position: %s • world: %s • facing: %s",
    ["%.0f град."] = "%.0f deg.",
    ["План этажа"] = "Floor plan",
    ["Щелчок: другой этаж. "] = "Click: another floor. ",
    ["ПКМ: большой план атласа. Потяни, чтобы переставить."] = "Right-click: large atlas plan. Drag to move.",
    ["Следующий босс"] = "Next boss",
    ["Убит"] = "Dead",
    ["Вход"] = "Entrance",
    ["Подъём "] = "Way up ",
    ["Спуск "] = "Way down ",
    ["Переход "] = "Passage ",
    [" • на другом этаже"] = " • on another floor",
    ["ПКМ: большой план в атласе. Потяни, чтобы переставить. Крестик убирает план; щелчок по боссу в трекере возвращает."] = "Right-click: large plan in the atlas. Drag to move. The cross hides the plan; clicking a boss in the tracker brings it back.",
    ["убит"] = "killed",
    ["следующий"] = "next",
    ["уровень %d"] = "level %d",
    ["Добыча"] = "Loot",
    [" |cffffd34d• лучшее в слот|r"] = " |cffffd34d• best in slot|r",
    ["ПКМ — большой план в атласе."] = "Right-click — the large atlas plan.",
    [" • этаж %d/%d"] = " • floor %d/%d",
    [" • он на другом этаже"] = " • it is on another floor",
    [" • ты в «"] = " • you are in «",
    ["где: снаружи, перед порталом"] = "where: outside, before the portal",
    ["где: снаружи"] = "where: outside",
    ["где: здесь, в «"] = "where: here, in «",
    ["где: по всему подземелью"] = "where: all over the dungeon",
    ["где: "] = "where: ",
    ["рядом босс "] = "near boss ",
    ["От босса "] = "From boss ",
    [" до точки"] = " to the spot",
    ["Рядом босс "] = "Near boss ",
    [" • цель на другом этаже"] = " • the goal is on another floor",
    ["Здесь: "] = "Here: ",
    [" — для «"] = " — for «",
    ["Когда здоровье падает, он зовёт помощников: переключитесь на них или возьмите под контроль."] = "As his health drops he calls helpers: switch to them or crowd-control them.",
    ["Сначала разбейте его машину, затем убейте выпрыгнувшего Снида. Машина пугает."] = "Break his shredder first, then kill Sneed when he jumps out. The shredder can fear.",
    ["На 66% и 33% он оглушает всех рядом и меняет оружие: лекарь стоит в стороне."] = "At 66% and 33% he stuns everyone nearby and swaps weapons: healer stays out of range.",
    ["Танк разворачивает его спиной к группе — рассекающий удар. Снимайте яд."] = "Tank turns him away from the group: he cleaves. Cure the poison.",
    ["Его крик пугает всех рядом — не деритесь возле других врагов."] = "His shout fears everyone nearby: don't fight next to other enemies.",
    ["На низком здоровье впадает в ярость — добивайте быстро."] = "At low health he enrages: finish him fast.",
    ["Не стойте кучей: цепная молния."] = "Don't stand together: chain lightning.",
    ["Он переносит игроков в комнаты с нежитью: держитесь, пока не откроется дверь, и бегите назад."] = "He teleports players into rooms with undead: survive until the door opens, then run back.",
    ["Он оживляет статуи по залу: танк их подбирает, а группа бьёт самого босса."] = "He wakes statues around the room: the tank picks them up, the group kills the boss.",
    ["Его сон, страх и оглушение бьют тех, кто рядом: лекарь держится на расстоянии."] = "His sleep, fear and stun hit those near him: healer keeps distance.",
    ["Прерывайте исцеление и Сон. Позже он станет змеем — снимайте яд."] = "Interrupt his heals and Sleep. Later he turns into a snake: cure the poison.",
    ["Прерывайте его исцеление и Сон."] = "Interrupt his heals and Sleep.",
    ["Прерывайте её исцеление. Снимайте Сон с танка."] = "Interrupt her heals. Dispel Sleep from the tank.",
    ["Не стойте кучей: его молния перескакивает на соседей."] = "Don't stand together: his lightning jumps to nearby players.",
    ["Танк держит его спиной к группе."] = "Tank faces him away from the group.",
    ["Снимайте с танка проклятие — оно сильно режет лечение."] = "Remove the curse on the tank: it cuts healing received.",
    ["С ним прибегают волки: танк собирает их, сначала убейте волков."] = "Wolves come with him: the tank gathers them, kill the wolves first.",
    ["С ним прибегают псы: танк собирает их, бейте областью."] = "His dogs come with him: the tank gathers them, use area damage.",
    ["Когда он крутится Вихрем, все кроме танка отбегают. После его смерти набегут ученики."] = "When he starts Whirlwind, everyone but the tank runs out. After he dies, a wave of trainees rushes in.",
    ["Вайтмейн скоро его воскресит — оставьте ману и силы на второй бой."] = "Whitemane will soon raise him: keep mana and cooldowns for round two.",
    ["На половине здоровья усыпит всех и воскресит Могрейна. Прерывайте её лечение."] = "At half health she puts everyone to sleep and raises Mograine. Interrupt her heals.",
    ["Снимайте с танка Слово Тьмы: Боль."] = "Dispel Shadow Word: Pain from the tank.",
    ["Снимайте яд с танка."] = "Cure the poison on the tank.",
    ["Он прыгает по залу — бегите к нему. Снимите проклятие с того, кого он превратил в воргена."] = "He teleports around the room: run to him. Decurse anyone he turns into a worgen.",
    ["Прерывайте его Свет небес — он лечится."] = "Interrupt his Holy Light, he heals himself.",
    ["С потерей здоровья бьёт всё сильнее — добивайте быстро."] = "He hits harder as his health drops: burn him fast.",
    ["Прерывайте её лечение; не стойте кучей — цепная молния."] = "Interrupt her heals; don't stand together, she casts chain lightning.",
    ["На низком здоровье он звереет — держите сильные заклинания на конец."] = "At low health he enrages: save your big cooldowns for the end.",
    ["Прерывайте его лечение; призванного кабана танк забирает на себя."] = "Interrupt his heals; the tank picks up the boar spirit he summons.",
    ["Он берёт игрока под контроль: обездвижьте его, а не убивайте."] = "He mind-controls a player: crowd-control them, don't kill them.",
    ["Отходите от огня под ногами; прерывайте Стрелу Тьмы."] = "Step out of fire on the ground; interrupt his Shadow Bolt.",
    ["Выходите из ядовитого облака. На низком здоровье он звереет — держите силы на конец."] = "Move out of the poison cloud. At low health he frenzies: save cooldowns for the end.",
    ["Танк держит её спиной к группе: её молния бьёт конусом вперёд."] = "Tank faces her away from the group: her forked lightning hits in a cone.",
    ["Прерывайте его Взрыв разума; снимайте Сон с танка."] = "Interrupt his Mind Blast; dispel Sleep from the tank.",
    ["Прерывайте его молнии; снимайте с танка уменьшение."] = "Interrupt his lightning; dispel Shrink from the tank.",
    ["Танк держит его мордой от группы; лекарь стоит вдали — он усыпляет всех рядом."] = "Tank faces him away from the group; healer stays far, he puts nearby players to sleep.",
    ["Прерывайте его исцеление; подчинённого им игрока обездвижьте, а не убивайте."] = "Interrupt his heals; crowd-control the player he charms, don't kill them.",
    ["Снимайте с игроков проклятие; прерывайте Стрелу Тьмы."] = "Remove the curse from players; interrupt his Shadow Bolt.",
    ["Танк держит дракона мордой от группы: дыхание кислотой."] = "Tank faces the dragon away from the group: acid breath.",
    ["Его лозы сбивают с ног всех рядом — лекарь стоит подальше."] = "His vines knock down everyone near him: healer stays back.",
    ["Ближний бой, следите за здоровьем: его удар по площади бьёт и отбрасывает всех рядом."] = "Melee, watch your health: his ground pound hits and knocks back everyone near him.",
    ["Не стойте кучей: его цепная молния перескакивает между игроками."] = "Don't stand together: his chain lightning jumps between players.",
    ["Когда он окружает себя пузырём, все отбегают подальше — следом будет взрыв."] = "When he wraps himself in a bubble, everyone runs away: a big explosion follows.",
    ["Три дворфа дерутся вместе: разберите цели, одного возьмите под контроль."] = "Three dwarves fight together: split the targets and crowd-control one.",
    ["Прерывайте его молнии; не стойте кучей."] = "Interrupt his lightning; don't stand together.",
    ["От ударов он рассыпается на осколки — танк их собирает, бейте областью."] = "He breaks into shards as you hit him: the tank gathers them, use area damage.",
    ["Уклоняйтесь от песчаных смерчей — они ходят по залу."] = "Dodge the sand tornadoes moving around the room.",
    ["Танк держит её спиной к группе: её удар бьёт по дуге."] = "Tank faces her away from the group: her smash hits in an arc.",
    ["Танк держит его спиной к группе: он бьёт рассекающим ударом."] = "Tank faces him away from the group: he cleaves.",
    ["Убейте его тотем первым; зомби из могил держите на танке."] = "Kill his ward first; the tank holds the zombies rising from the graves.",
    ["Её удар подбрасывает всех рядом — лекарь стоит подальше."] = "Her slam knocks up everyone nearby: healer stands back.",
    ["Прерывайте его исцеление; будьте готовы к страху."] = "Interrupt his heals; expect a fear.",
    ["Его огненный взрыв бьёт всех рядом — лекарь стоит подальше."] = "His fire nova hits everyone nearby: healer stands back.",
    ["Снимайте яд и проклятие с танка."] = "Cure the poison and remove the curse from the tank.",
    ["Прерывайте его Огненный шар."] = "Interrupt his Fireball.",
    ["На половине здоровья появятся призраки — бейте их областью. Ближний бой, бойтесь Кольца льда."] = "At half health spectres appear: kill them with area damage. Melee, watch for Frost Nova.",
    ["Защищайте Ими от волн троггов: если она погибнет, событие сорвётся."] = "Protect Emi from the trogg waves: if she dies, the event fails.",
    ["В бою у пирамиды держитесь наверху лестницы и бейте волны областью."] = "During the pyramid event, hold the top of the stairs and use area damage on the waves.",
    ["Прерывайте её исцеление."] = "Interrupt her heals.",
    ["Жмите кнопки у стен, откуда идут бомбы, а прорвавшиеся бомбы убивайте сразу."] = "Press the wall buttons to stop the bombs, and kill any bomb that gets through at once.",
    ["При потере здоровья зовёт василисков; его лечащий тотем убейте сразу."] = "As his health drops basilisks join; kill his healing ward at once.",
    ["Сошедшего с ума игрока обездвижьте, а не убивайте; снимайте проклятия."] = "Crowd-control the maddened player, don't kill them; remove curses.",
    ["На низком здоровье он звереет — держите силы на конец."] = "At low health he frenzies: save cooldowns for the end.",
    ["Он отбрасывает всех рядом — лекарь и дальний бой стоят подальше."] = "He knocks back everyone near him: healer and ranged stand back.",
    ["Зачистите големов в зале до боя — он их оживляет."] = "Clear the golems in the room first: he activates them.",
    ["Снимайте проклятие; он отбрасывает — танк стоит спиной к стене."] = "Remove his curse; he knocks the tank back, so tank with your back to a wall.",
    ["Её крик вызывает страх — не деритесь возле других групп врагов."] = "Her scream fears: fight away from other enemy packs.",
    ["Прерывайте лечение принцессы Мойры, иначе бой затянется."] = "Interrupt Princess Moira's heals, or the fight drags on.",
    ["Убейте его тотемы первыми."] = "Kill his totems first.",
    ["Его топот оглушает всех рядом — лекарь держится подальше."] = "His stomp stuns everyone nearby: healer stays back.",
    ["Сначала две волны врагов, потом случайный босс арены — берегите ману до него."] = "Two waves of enemies first, then a random arena boss: save mana for him.",
    ["На низком здоровье зовёт подмогу — добивайте его быстро."] = "At low health he calls reinforcements: finish him fast.",
    ["Дворфы выходят по одному, после смерти предыдущего — следите за маной лекаря."] = "The dwarves come one at a time as each dies: watch the healer's mana.",
    ["Убивайте огненных духов, пока они не дошли до него, иначе он усилится."] = "Kill the burning spirits before they reach him, or he grows stronger.",
    ["Танк держит его спиной к стене и к группе: он отбрасывает и рассекает."] = "Tank him back to a wall, facing away: he knocks back and cleaves.",
    ["Снимайте с игроков проклятие и сглаз."] = "Remove the curse and hex from players.",
    ["На половине здоровья зовёт двух помощников — возьмите их под контроль."] = "At half health he calls two helpers: crowd-control them.",
    ["Его огненная волна бьёт всех рядом — дальний бой держится подальше."] = "His fire nova hits everyone nearby: ranged stays back.",
    ["Не стойте на пути огня из статуй в зале."] = "Stay out of the fire the statues shoot in the hall.",
    ["Сразу после неё выйдет Гизрул — не тратьте все силы."] = "Gizrul comes right after her: don't spend all your cooldowns.",
    ["Держитесь вместе у входа и не бегайте по яйцам — из них вылупятся драконы."] = "Stay together by the entrance and don't run over the eggs: they hatch whelps.",
    ["На низком здоровье звереет — добивайте быстро."] = "At low health he frenzies: finish him fast.",
    ["Сначала уведите или убейте двух стражей. Не стойте в огне на полу."] = "Pull away or kill his two guards first. Stay out of fire on the floor.",
    ["Сначала много волн у ворот — держитесь у входа. Танк держит Гита мордой от группы."] = "First many waves come at the gate: hold by the entrance. Tank faces Gyth away from the group.",
    ["Танк держит его у стены мордой от группы: он пугает и отбрасывает."] = "Tank him at a wall facing away: he fears and knocks back.",
    ["Не стойте в огне на полу."] = "Stay out of fire on the floor.",
    ["Когда она вселяется в игрока, обездвижьте его, а не убивайте."] = "When she possesses a player, crowd-control them, don't kill them.",
    ["Бейте его скарабеев областью; снимайте яд."] = "Kill his scarabs with area damage; cure poison.",
    ["Прерывайте его Ледяную стрелу и Похищение жизни."] = "Interrupt his Frostbolt and Drain Life.",
    ["После его смерти хлынет волна нежити — восстановитесь и держитесь вместе."] = "After he dies a wave of undead floods in: recover and stay together.",
    ["Он поднимает скелетов — бейте их областью; танк держит его спиной к группе."] = "He raises skeletons: kill them with area damage; tank faces him away from the group.",
    ["Ждите страх и подчинение: подчинённого игрока обездвижьте, а не убивайте."] = "Expect fear and mind control: crowd-control the charmed player, don't kill them.",
    ["Она делится на иллюзии — бейте их областью, затем добейте настоящую."] = "She splits into illusions: kill them with area damage, then finish the real one.",
    ["Прерывайте её лечение."] = "Interrupt her heals.",
    ["Снимайте проклятия; игрока под его контролем обездвижьте, а не убивайте."] = "Remove curses; crowd-control the player he mind-controls, don't kill them.",
    ["Танк держит его спиной к группе: рассекает и топчет."] = "Tank faces him away from the group: he cleaves and tramples.",
    ["Прерывайте его Ледяную стрелу; ближний бой, бойтесь Кольца льда."] = "Interrupt his Frostbolt; melee, watch for Frost Nova.",
    ["Подчинённого им игрока обездвижьте; ждите страх и сон."] = "Crowd-control the player he mind-controls; expect fear and sleep.",
    ["Снимайте болезни, особенно с танка."] = "Cure diseases, especially on the tank.",
    ["Убивайте стрелков, которых он зовёт, или танк забирает их на себя."] = "Kill the riflemen he calls, or the tank picks them up.",
    ["Ближний бой, отходите, когда он крутится вихрем."] = "Melee, step away when he whirlwinds.",
    ["Лечите игрока, которого он приносит в жертву."] = "Heal the player he sacrifices.",
    ["Сначала отключите пять пилонов. В бою он зовёт глаза — убивайте их."] = "Shut down the five pylons first. In the fight he calls eyes: kill them.",
    ["Прерывайте его Жертвенный огонь и снимайте проклятие с танка."] = "Interrupt his Immolate and remove the curse from the tank.",
    ["Он бьёт огнём по всем рядом: лекарь и дальний бой стоят подальше."] = "His fire nova hits everyone near him: healer and ranged stand back.",
    ["Её пылевое облако бьёт всех рядом — лекарь и дальний бой стоят подальше."] = "Her dust field hits everyone near her: healer and ranged stand back.",
    ["Он отбрасывает танка — танкуйте спиной к стене."] = "He knocks the tank away: tank him with your back to a wall.",
    ["Убейте его тотемы первыми; прерывайте молнию."] = "Kill his totems first; interrupt his Lightning Bolt.",
    ["В бою появляются мелкие водные отродья — убивайте их."] = "Small water spawns appear in the fight: kill them.",
    ["Когда он исчезает, появляются его отродья — бейте их областью. Снимайте яд."] = "When he vanishes his spawns appear: kill them with area damage. Cure poison.",
    ["Не стойте перед ним: огнемёт бьёт конусом."] = "Don't stand in front of him: his flamethrower hits in a cone.",
    ["Он зовёт двух помощников и пугает криком."] = "He calls two helpers and fears with a shout.",
    ["Прерывайте её залп Стрел Тьмы."] = "Interrupt her Shadow Bolt Volley.",
    ["Бегите за ним по коридорам, пока он не начнёт драться; его бесов бейте областью."] = "Chase him through the halls until he fights; kill his imps with area damage.",
    ["Не стойте рядом, когда он бьёт по земле — оглушает. На 30% лечится и ускоряется: добейте быстро."] = "Stay out of range of his stunning slam. At 30% he heals and speeds up: save cooldowns and burn him.",
    ["Сначала убейте или возьмите под контроль двух жриц — они его лечат. Танк держит его спиной к группе."] = "Kill or crowd-control the two priestesses first, they heal him. Tank faces him away from the group.",
    ["Когда союзника запирает в водяной пузырь, все бьют пузырь. Прерывайте залп водяных стрел."] = "When a player is trapped in a water bubble, everyone breaks it. Interrupt his waterbolt volley.",
    ["Убивайте его прислужников: каждый даёт +20% урона по боссу. Первыми — стражей, они оглушают."] = "Kill his adds: each one makes the boss take 20% more damage. Guardians first, they stun.",
    ["Танк держит его спиной к группе. Когда он станет змеем, снимайте яд и будьте готовы к страху."] = "Tank faces him away from the group. Once he turns into a serpent, cleanse poison and expect a fear.",
    ["Возьмите подводное дыхание. Прерывайте его заклинание по площади — оно замедляет группу."] = "Bring water breathing. Interrupt his area spell, it slows the group.",
    ["Оргриммар, Расселина Теней. Вход в пещеру в глубине расселины."] = "Orgrimmar, Cleft of Shadow. The cave entrance is at the back of the cleft.",
    ["Степи. От Перекрёстка на юго-запад к оазису, пещера на холме над водой."] = "The Barrens. From the Crossroads go southwest to the oasis; the cave is on the hill above the water.",
    ["Серебряный бор. От Гробницы по главной дороге на юг до указателя на крепость."] = "Silverpine Forest. From the Sepulcher take the main road south to the signpost for the keep.",
    ["Серебряный бор, юг. Крепость на холме у главной дороги."] = "Silverpine Forest, south. The keep is on the hill by the main road.",
    ["Ясеневый лес. От Заставы Зорам'гар на север вдоль берега до руин, там спуск в пещеру."] = "Ashenvale. From Zoram'gar Outpost go north along the shore to the ruins; the way down into the cave is there.",
    ["Ясеневый лес, северо-западный берег. Руины, спуск в пещеру."] = "Ashenvale, northwest shore. Ruins, way down into the cave.",
    ["Западный Край, Луноречье. Орде идти из Тернистой долины через Сумеречный лес. Вход через дом в городке, дальше по шахте."] = "Westfall, Moonbrook. Horde comes from Stranglethorn Vale via Duskwood. Enter through a house in the town, then on through the mine.",
    ["Западный Край, Луноречье. Вход через дом в городке, дальше по шахте."] = "Westfall, Moonbrook. Enter through a house in the town, then on through the mine.",
    ["Штормград, район каналов."] = "Stormwind, canal district.",
    ["Самый юг Степей. От Лагеря Таурахо по дороге на юг, перед Великим подъёмником сверни на запад."] = "Far south of The Barrens. From Camp Taurajo take the road south; before the Great Lift turn west.",
    ["Самый юг Степей, западнее дороги к Великому подъёмнику."] = "Far south of The Barrens, west of the road to the Great Lift.",
    ["Самый юг Степей. От Лагеря Таурахо по дороге на юг, перед Великим подъёмником сверни на восток."] = "Far south of The Barrens. From Camp Taurajo take the road south; before the Great Lift turn east.",
    ["Самый юг Степей, восточнее дороги к Великому подъёмнику."] = "Far south of The Barrens, east of the road to the Great Lift.",
    ["Из Подгорода по дороге на восток через Брилл. У указателя на монастырь сверни на северо-восток и поднимайся в гору."] = "From Undercity take the road east via Brill. At the signpost for the monastery turn northeast and climb the hill.",
    ["Северо-восток Тирисфальских лесов, на горе над дорогой."] = "Northeast Tirisfal Glades, on the hill above the road.",
    ["Орде в Гномреган пешком не попасть. Встань на гоблинскую площадку рядом со Скути в Пиратской Бухте: она перенесёт в тоннели к порталу. Доступ даёт задание «Поехалиии!»."] = "Horde cannot reach Gnomeregan on foot. Stand on the goblin pad next to Scooty in Booty Bay: it takes you to the tunnels near the portal. Access comes from the quest \"Wheee!\".",
    ["Запад Дун Морога, к западу от Караноса."] = "West Dun Morogh, west of Kharanos.",
    ["Бесплодные земли. От Каргата на восток, затем на север к раскопкам у северного края."] = "Badlands. From Kargath go east, then north to the dig site at the northern edge.",
    ["Северный край Бесплодных земель, раскопки."] = "Northern edge of the Badlands, dig site.",
    ["Танарис. От Прибамбасска на северо-запад до лестницы в горах."] = "Tanaris. From Gadgetzan go northwest to the stairs in the mountains.",
    ["Пустоши. От Деревни Ночных Охотников на северо-восток, Долина Копий."] = "Desolace. From Shadowprey Village go northeast, Valley of Spears.",
    ["Запад Пустошей, Долина Копий."] = "West Desolace, Valley of Spears.",
    ["Болото Печали. От Каменора на восток до озера. Храм на острове, вниз по лестницам."] = "Swamp of Sorrows. From Stonard go east to the lake. The temple is on the island, down the stairs.",
    ["Болото Печали, озеро на востоке. Храм на острове, вниз по лестницам."] = "Swamp of Sorrows, lake in the east. The temple is on the island, down the stairs.",
    ["Чёрная гора. Орде ближе от Каргата через Тлеющее ущелье."] = "Blackrock Mountain. For Horde it is closer from Kargath via Searing Gorge.",
    ["Чёрная гора между Тлеющим ущельем и Пылающими степями."] = "Blackrock Mountain, between Searing Gorge and Burning Steppes.",
    ["Фералас. От Лагеря Мохаче по дороге на запад, затем на север в руины."] = "Feralas. From Camp Mojache take the road west, then north into the ruins.",
    ["Фералас, руины в центре зоны."] = "Feralas, ruins in the middle of the zone.",
    ["Западные Чумные земли. Остров Каэр Дарроу на озере, на юге зоны."] = "Western Plaguelands. Caer Darrow island on the lake, in the south of the zone.",
    ["Север Восточных Чумных земель."] = "North of the Eastern Plaguelands.",
    ["северный"] = "north",
    ["северо-восточный"] = "northeast",
    ["восточный"] = "east",
    ["юго-восточный"] = "southeast",
    ["южный"] = "south",
    ["юго-западный"] = "southwest",
    ["западный"] = "west",
    ["северо-западный"] = "northwest",
    ["два"] = "two",
    ["три"] = "three",
    ["четыре"] = "four",
    ["Порталов во дворе %s. По карте атласа твой — %s."] = "There are %s portals in the courtyard. By the atlas map yours is the %s one.",
    ["Телепорт в Пиратской Бухте"] = "Teleport in Booty Bay",
    ["К телепорту"] = "To the teleport",
    ["Телепорт в Гномреган"] = "Teleport to Gnomeregan",
    ["Иди к телепорту"] = "Go to the teleport",
    ["Встань на телепорт"] = "Stand on the teleport",
    ["площадка рядом со Скути"] = "pad next to Scooty",
    ["гоблинская площадка рядом со Скути"] = "goblin pad next to Scooty",
    ["встань на гоблинскую площадку рядом со Скути"] = "stand on the goblin pad next to Scooty",
    ["Скути"] = "Scooty",
    ["Телепорт обратно в Бухту"] = "Teleport back to the Bay",
    ["Назад в Бухту"] = "Back to the Bay",
    ["Телепорт в Пиратскую Бухту"] = "Teleport to Booty Bay",
    ["Иди к телепорту в Бухту"] = "Go to the teleport to the Bay",
    ["Встань на телепорт в Бухту"] = "Stand on the teleport to the Bay",
    ["гоблинская площадка в тоннелях"] = "goblin pad in the tunnels",
    ["портал в глубине тоннелей"] = "portal deep in the tunnels",
    ["Портал подземелья"] = "Dungeon portal",
    ["Ко входу"] = "To the entrance",
    ["Иди ко входу"] = "Go to the entrance",
    ["К порталу"] = "To the portal",
    ["Иди к порталу"] = "Go to the portal",
    ["Войди в портал"] = "Enter the portal",
    ["Назад"] = "Back",
    ["Иди назад"] = "Go back",
    ["Войди в подземелье"] = "Enter the dungeon",
    ["Выход из локации"] = "Zone exit",
    ["Вход в локацию"] = "Zone entrance",
    ["К выходу"] = "To the exit",
    ["Иди к выходу из локации"] = "Go to the zone exit",
    ["Иди ко входу в локацию"] = "Go to the zone entrance",
    ["Зул'алай"] = "Zul'Alai",
    ["Вар'така"] = "Var'Taka",
    ["зал «Глубинные архивы»"] = "the hall of the Deep Archives",
    ["Первородный элементаль"] = "Primeval Elemental",
    ["в Глубинных архивах направо, в затопленный тоннель"] = "in the Deep Archives, right into the flooded tunnel",
    ["плыви до подводной комнаты"] = "swim to the underwater room",
    ["Мин'лот-Змей"] = "Min'loth the Serpent",
    ["Грязнюк"] = "Grubbis",
    ["выходит, когда Взрывник Ими Фитилюшка подорвёт тоннели"] = "comes out when Blastmaster Emi Shortfuse blows up the tunnels",
    ["от входа по тоннелю в большой зал"] = "from the entrance through the tunnel to the big hall",
    ["событие начинается слева"] = "the event starts on the left",
    ["Липкая муть"] = "Viscous Fallout",
    ["спрыгни в комнату под залом"] = "jump down into the room under the hall",
    ["Возьми «Катавасия» у Керноби"] = "Pick up \"A Fine Mess\" from Kernobee",
    ["«Катавасия»: проводи Керноби к выходу"] = "\"A Fine Mess\": escort Kernobee to the exit",
    ["«Чистер 5200!»: автомат рядом"] = "\"The Sparklematic 5200!\": the machine is nearby",
    ["нужен «Предмет, покрытый грязью»"] = "needs a \"Grime-Encrusted Object\"",
    ["Электрошокер 6000"] = "Electrocutioner 6000",
    ["дальше по тоннелям"] = "on through the tunnels",
    ["он на верхней площадке большого зала"] = "he is on the upper platform of the big hall",
    ["Толпогон 9-60"] = "Crowd Pummeler 9-60",
    ["иди мимо лифта дальше"] = "go on past the lift",
    ["на лифт не садись"] = "do not take the lift",
    ["Мекжинер Термоштепсель"] = "Mekgineer Thermaplugg",
    ["вернись к лифту, который прошёл"] = "go back to the lift you passed",
    ["спустись на нём"] = "take it down",
    ["«Техновойны»: забери код с босса"] = "\"Rig Wars\": take the code from the boss",
    ["чертежи лежат в его сейфе рядом"] = "the blueprints are in his safe nearby",
    ["Огглфлинт"] = "Oggleflint",
    ["от входа вниз, первый поворот направо"] = "from the entrance go down, take the first right turn",
    ["он в маленькой пещере в конце прохода"] = "he is in a small cave at the end of that path",
    ["Тарагаман Ненасытный"] = "Taragaman the Hungerer",
    ["вернись на главный путь и иди вниз"] = "go back to the main path and keep going down",
    ["он на площадке посреди озера лавы"] = "he is on the platform in the middle of the lava lake",
    ["Жергош Призыватель Духов"] = "Jergosh the Invoker",
    ["дальше за озером лавы, мимо стражи"] = "go on past the lava lake and its guards",
    ["он чуть впереди места прошлого боя"] = "he is just ahead of the last fight",
    ["Баззалан"] = "Bazzalan",
    ["поднимись по соседнему проходу"] = "walk up the walkway next to it",
    ["он в самом конце, на верхнем ярусе"] = "he is at the very end, on the upper level",
    ["Повелительница Анакондра"] = "Lady Anacondra",
    ["от входа в большую центральную пещеру"] = "from the entrance into the big central cave",
    ["она на верхних уступах, зал «Овраг Воплей»"] = "she is on the upper ledges, hall «Screaming Gully»",
    ["Лорд Кобран"] = "Lord Cobrahn",
    ["из пещеры налево, в зал «Змеиная яма»"] = "from the cave go left, into the hall «Pit of Fangs»",
    ["поднимись наверх по извилистой тропе"] = "climb up the winding path",
    ["Криг"] = "Kresh",
    ["черепаха плавает по ручью"] = "a turtle swimming along the stream",
    ["по пути через центральную пещеру"] = "on the way through the central cave",
    ["Лорд Питонас"] = "Lord Pythas",
    ["спрыгни вниз, вернись в центральную пещеру"] = "jump down and go back to the central cave",
    ["оттуда в зал «Извилистая расщелина»"] = "from there into the hall «Winding Chasm»",
    ["Шкам"] = "Skum",
    ["дальше по той же расщелине"] = "further along the same chasm",
    ["Лорд Серпентис"] = "Lord Serpentis",
    ["дальше по пути в зал «Утес Вечноживущего»"] = "go on into the hall «Crag of the Everliving»",
    ["Вердан Бессмертный"] = "Verdan the Everliving",
    ["там же, дальше к водопаду"] = "in the same place, on towards the waterfall",
    ["он стоит у водопада"] = "he stands by the waterfall",
    ["Мутанус Пожиратель"] = "Mutanus the Devourer",
    ["прыгни в пруд позади: он ведёт к входу"] = "jump into the pool behind: it leads to the entrance",
    ["проводи ученика Наралекса в центр пещер"] = "escort the Disciple of Naralex to the middle of the caves",
    ["выходит после ритуала Ученика Наралекса, когда убиты четыре повелителя змей"] = "comes out after the Disciple of Naralex's ritual, once the four Fanglords are dead",
    ["редкий; может быть в «Извилистая расщелина»"] = "rare; may be in the «Winding Chasm»",
    ["Рак'Зор"] = "Rhahk'Zor",
    ["от входа по шахте мимо кобольдов"] = "from the entrance through the mine past the kobolds",
    ["он стоит у первой большой двери"] = "he stands by the first big door",
    ["Шахтер Джонсон"] = "Miner Johnson",
    ["редкий; может бродить в шахте за дверью"] = "rare; may wander in the mine past the door",
    ["Снид"] = "Sneed",
    ["дальше по шахте в зал «Мачтовая мастерская»"] = "further through the mine into the hall «Mast Room»",
    ["он в шреддере, потом вылезет сам"] = "he is in the shredder, then comes out himself",
    ["Гилнид"] = "Gilnid",
    ["дальше в зал «Гоблинский цех»"] = "go on into the hall «Goblin Foundry»",
    ["после него откроется дверь дальше"] = "killing him opens the next door",
    ["Мистер Каюк"] = "Mr. Smite",
    ["возьми порох в нише за цехом, заряди пушку"] = "take the gunpowder in the alcove past the foundry, load the cannon",
    ["за дверью бухта, он у трапа на корабль"] = "past the door is the cove; he is by the ship's ramp",
    ["Капитан Зеленямс"] = "Captain Greenskin",
    ["поднимись по трапу на корабль"] = "walk up the ramp onto the ship",
    ["он на верхней палубе"] = "he is on the upper deck",
    ["Эдвин ван Клиф"] = "Edwin VanCleef",
    ["по лестнице корабля на самый верх"] = "take the ship's stairs to the very top",
    ["он в каюте на верху корабля"] = "he is in the cabin at the top of the ship",
    ["Пирожок"] = "Cookie",
    ["он внизу, по другую сторону корабля"] = "he is down below, on the other side of the ship",
    ["Ретилгор"] = "Rethilgore",
    ["от входа в тюремные камеры"] = "from the entrance to the prison cells",
    ["он у клеток с пленниками"] = "he is by the cells with the prisoners",
    ["Остроклык Мясник"] = "Razorclaw the Butcher",
    ["после прошлого боя откроется двор"] = "the courtyard opens after the last fight",
    ["через двор в здание, он на кухне"] = "across the courtyard into the building, he is in the kitchen",
    ["Барон Сребролен"] = "Baron Silverlaine",
    ["из кухни дальше в обеденный зал"] = "from the kitchen on into the dining hall",
    ["Командир Ручьедол"] = "Commander Springvale",
    ["из зала вверх по лестнице"] = "from the hall go up the stairs",
    ["он в комнате наверху"] = "he is in the room upstairs",
    ["Одо Слепой Страж"] = "Odo the Blindwatcher",
    ["выйди на крепостную стену"] = "go out onto the castle wall",
    ["он там со стаей летучих мышей"] = "he is there with a pack of bats",
    ["Фенрус Пожиратель"] = "Fenrus the Devourer",
    ["по стене дальше, он в следующей комнате"] = "on along the wall, he is in the next room",
    ["Командир воргенов Нандос"] = "Wolf Master Nandos",
    ["дальше, он у двери в покои мага"] = "further on, he is by the door to the archmage's rooms",
    ["Верховный маг Аругал"] = "Archmage Arugal",
    ["за дверью наверх, он в последнем зале"] = "through the door and up, he is in the last hall",
    ["Гхаму-ра"] = "Ghamoo-ra",
    ["от входа к большому пруду"] = "from the entrance to the big pool",
    ["черепаха в зале «Пруд Аск'ара»"] = "the turtle is in the hall «The Pool of Ask'ar»",
    ["Леди Саревесс"] = "Lady Sarevess",
    ["в боковой пещере у того же пруда"] = "in a side cave by the same pool",
    ["Гелихаст"] = "Gelihast",
    ["дальше по тоннелю к святилищу мурлоков"] = "further through the tunnel to the murloc shrine",
    ["он в зале с мурлоками"] = "he is in the hall with the murlocs",
    ["Лоргус Джетт"] = "Lorgus Jett",
    ["бродит в тоннелях дальше по пути"] = "wanders in the tunnels further along the way",
    ["Барон Акванис"] = "Baron Aquanis",
    ["камень в зале «Руины святилища Луны»"] = "the stone is in the hall «Moonshrine Ruins»",
    ["вызывается по заданию «Среди руин»"] = "summoned by the quest \"Amongst the Ruins\"",
    ["Повелитель сумрака Келрис"] = "Twilight Lord Kelris",
    ["через руины в зал «Алтарь святилища Луны»"] = "through the ruins into the hall «Moonshrine Sanctum»",
    ["он там, у алтаря с культистами"] = "he is there, by the altar with the cultists",
    ["Старина Серракис"] = "Old Serra'kis",
    ["плавает под водой в зале «Забытый пруд»"] = "swims underwater in the hall «The Forgotten Pool»",
    ["Аку'май"] = "Aku'mai",
    ["зажги огни на алтаре: откроется большая дверь"] = "light the fires on the altar: the big door opens",
    ["за ней зал «Логово Аку'май»"] = "behind it is the hall «Aku'mai's Lair»",
    ["Таргорр Ужасный"] = "Targorr the Dread",
    ["от входа по коридору до развилки"] = "from the entrance along the corridor to the fork",
    ["он в одной из боковых камер"] = "he is in one of the side cells",
    ["Кам Гневливый"] = "Kam Deepfury",
    ["на развилке направо"] = "at the fork turn right",
    ["он в боковой камере этого коридора"] = "he is in a side cell of that corridor",
    ["Хрупконог"] = "Hamhock",
    ["дальше до конца правого коридора"] = "on to the end of the right corridor",
    ["он охраняет последнюю комнату"] = "he guards the last room",
    ["Базиль Тредд"] = "Bazil Thredd",
    ["он в той же последней комнате"] = "he is in the same last room",
    ["Декстрен Вард"] = "Dextren Ward",
    ["вернись на развилку и иди налево"] = "go back to the fork and turn left",
    ["он в дальнем углу левого коридора"] = "he is in the far corner of the left corridor",
    ["редкий; может быть в левом коридоре"] = "rare; may be in the left corridor",
    ["Ругуг"] = "Roogug",
    ["от входа вперёд по колючей тропе"] = "from the entrance forward along the thorny path",
    ["он первый босс на этом пути"] = "he is the first boss on that path",
    ["Аггем Терновое Проклятие"] = "Aggem Thorncurse",
    ["Вестник смерти Джаргба"] = "Death Speaker Jargba",
    ["Властитель Таранный Клык"] = "Overlord Ramtusk",
    ["Агателос Свирепый"] = "Agathelos the Raging",
    ["он заперт: сначала убей стражу вокруг"] = "he is sealed in: first kill the guards around him",
    ["Слепой охотник"] = "Blind Hunter",
    ["редкий; может быть в конце пещер"] = "rare; may be at the end of the caves",
    ["Заклинательница земли Халмгар"] = "Earthcaller Halmgar",
    ["редкий; может стоять на одном из плато"] = "rare; may stand on one of the plateaus",
    ["Чарлга Остробок"] = "Charlga Razorflank",
    ["в самом конце, на пандусе у её хижины"] = "at the very end, on the ramp by her hut",
    ["Кладбище"] = "Graveyard",
    ["Дознаватель Вишас"] = "Interrogator Vishas",
    ["от входа прямо по коридору"] = "from the entrance straight along the corridor",
    ["он в зале «Чертог Искупления»"] = "he is in the hall «Chamber of Atonement»",
    ["Волшебник Крови Талнос"] = "Bloodmage Thalnos",
    ["дальше через двор «Покинутый двор»"] = "on through the yard «Forlorn Cloister»",
    ["он в склепе в конце, «Гробница Доблести»"] = "he is in the crypt at the end, «Honor's Tomb»",
    ["Библиотека"] = "Library",
    ["Псарь Локси"] = "Houndmaster Loksey",
    ["от входа по коридору во двор с собаками"] = "from the entrance along the corridor to the yard with dogs",
    ["он в зале «Скит Охотника»"] = "he is in the hall «Huntsman's Cloister»",
    ["Чародей Доан"] = "Arcanist Doan",
    ["дальше через зал «Сокровищница»"] = "on through the hall «Gallery of Treasures»",
    ["он в большом зале «Читальня»"] = "he is in the big hall «Athenaeum»",
    ["Оружейная"] = "Armory",
    ["Герод"] = "Herod",
    ["через тренировочный двор и оружейные"] = "through the training yard and the armories",
    ["он в конце, зал «Чертог Защитников»"] = "he is at the end, hall «Hall of Champions»",
    ["Собор"] = "Cathedral",
    ["Верховный инквизитор Фэйрбанкс"] = "High Inquisitor Fairbanks",
    ["Командир Могрейн из Алого ордена"] = "Scarlet Commander Mograine",
    ["через «Церковные сады» в собор"] = "through the «Chapel Gardens» into the cathedral",
    ["он у алтаря, зал «Часовня Ордена»"] = "he is by the altar, hall «Crusader's Chapel»",
    ["Верховный инквизитор Вайтмейн"] = "High Inquisitor Whitemane",
    ["она выйдет после него из двери сзади"] = "she comes out of the door behind after he falls",
    ["Тутен'каш"] = "Tuten'kash",
    ["гонг в зале «Зал Призыва»"] = "the gong is in the hall «The Caller's Chamber»",
    ["выходит после удара в гонг"] = "comes out after the gong is struck",
    ["Мордреш Огненный Глаз"] = "Mordresh Fire Eye",
    ["он на куче костей, зал «Груда костей»"] = "he is on a heap of bones, hall «The Bone Pile»",
    ["Обжора"] = "Glutton",
    ["ходит в начале «Тернистый серпантин»"] = "walks at the start of the «Spiral of Thorns»",
    ["Чумобрюх Гнилой"] = "Plaguemaw the Rotting",
    ["он в зале «Камеры обреченных»"] = "he is in the hall «The Murder Pens»",
    ["Амненнар Хладовей"] = "Amnennar the Coldbringer",
    ["по «Тернистый серпантин» до самого верха"] = "up the «Spiral of Thorns» to the very top",
    ["Ревелош"] = "Revelosh",
    ["Бейлог"] = "Baelog",
    ["Иронайа"] = "Ironaya",
    ["Обсидиановый часовой"] = "Obsidian Sentinel",
    ["Древний Хранитель Камня"] = "Ancient Stone Keeper",
    ["Галганн Огнемолот"] = "Galgann Firehammer",
    ["Гримлок"] = "Grimlok",
    ["он в зале «Каменный свод»"] = "he is in the hall «The Stone Vault»",
    ["Аркедас"] = "Archaedas",
    ["в самом конце, зал «Трон Каз'горота»"] = "at the very end, hall «Khaz'goroth's Seat»",
    ["Ноксион"] = "Noxxion",
    ["на развилке направо, путь с оранжевыми кристаллами"] = "at the fork go right, the path with orange crystals",
    ["он в воде, зал «Ядовитая низина»"] = "he is in the water, hall «The Noxious Hollow»",
    ["Бритвохлест"] = "Razorlash",
    ["дальше по оранжевому пути"] = "further along the orange path",
    ["он в зале «Зловонная пещера»"] = "he is in the hall «Foulspore Cavern»",
    ["Лорд Злоязыкий"] = "Lord Vyletongue",
    ["к развилке, налево по фиолетовому пути"] = "back to the fork, left along the purple path",
    ["он в зале «Палата Злоязыкого»"] = "he is in the hall «Vyletongue Seat»",
    ["бродит наверху ядовитого водопада, «Ядопады»"] = "walks at the top of the poison waterfall, «Poison Falls»",
    ["Селебрас Проклятый"] = "Celebras the Cursed",
    ["дальше вниз за ядовитым водопадом"] = "further down past the poison waterfall",
    ["он в конце передней части подземелья"] = "he is at the end of the front part of the dungeon",
    ["Сель"] = "Landslide",
    ["в зале «Поющие водопады» на развилке направо"] = "in the hall «Earth Song Falls» turn right at the fork",
    ["он наверху спирального пандуса"] = "he is at the top of the spiral ramp",
    ["Ремонтник Гизлок"] = "Tinkerer Gizlock",
    ["вниз по пандусу и дальше"] = "down the ramp and on",
    ["он в зале перед площадкой принцессы"] = "he is in the hall before the princess's platform",
    ["Гнилопасть"] = "Rotgrip",
    ["он в воде под площадкой принцессы"] = "he is in the water under the princess's platform",
    ["Принцесса Терадрас"] = "Princess Theradras",
    ["она на площадке над водой, «Могила Зейтара»"] = "she is on the platform above the water, «Zaetar's Grave»",
    ["Анту'сул"] = "Antu'sul",
    ["от входа первый поворот налево, к могилам"] = "from the entrance take the first left, to the graves",
    ["справа в зале щель в стене, он за ней"] = "on the right of that hall is a crack in the wall, he is behind it",
    ["Тека Мученик"] = "Theka the Martyr",
    ["вернись в зал с могилами"] = "go back to the hall with the graves",
    ["он ходит вокруг могил"] = "he walks around the graves",
    ["Знахарь Зум'рах"] = "Witch Doctor Zum'rah",
    ["из зала с могилами в следующий зал"] = "from the hall with the graves into the next hall",
    ["он у котла; нападёт, когда войдёшь"] = "he is by the cauldron; he attacks when you walk in",
    ["Некрум Кишкожуй"] = "Nekrum Gutchewer",
    ["к большой пирамиде, наверх к клеткам"] = "to the big pyramid, up to the cages",
    ["открой клетки: он придёт с последней волной"] = "open the cages: he comes with the last wave",
    ["Темный жрец Шезз'зиз"] = "Shadowpriest Sezz'ziz",
    ["он внизу лестницы, когда кончатся волны"] = "he is at the bottom of the stairs when the waves end",
    ["Сержант Блай"] = "Sergeant Bly",
    ["он у клеток на вершине пирамиды"] = "he is by the cages at the top of the pyramid",
    ["Гидромант Велрата"] = "Hydromancer Velratha",
    ["иди к пруду с гонгом"] = "go to the pool with the gong",
    ["она за углом у входа в тот двор"] = "she is around the corner by the entrance of that yard",
    ["Газ'рилла"] = "Gahz'rilla",
    ["гонг стоит у того же пруда"] = "the gong stands by the same pool",
    ["вызывается молотом Зул'Фаррака у гонга"] = "summoned with the Mallet of Zul'Farrak at the gong",
    ["Руузлу"] = "Ruuzlu",
    ["за дверью, что взорвал гоблин из клеток"] = "behind the door the goblin from the cages blew up",
    ["он стоит рядом с вождём"] = "he stands next to the chief",
    ["Вождь Укорз Песчаная Плешь"] = "Chief Ukorz Sandscalp",
    ["он там же, за той же дверью"] = "he is in the same place, behind the same door",
    ["Атал'аларион"] = "Atal'alarion",
    ["от входа направо, вниз в «Мусорная яма»"] = "from the entrance go right, down into «The Pit of Refuse»",
    ["он появится в центре зала"] = "he appears in the middle of the hall",
    ["появляется после шести статуй"] = "appears after the six statues",
    ["Джаммал'ан Пророк"] = "Jammal'an the Prophet",
    ["шесть троллей на балконах верхнего кольца"] = "six trolls on the balconies of the upper ring",
    ["потом спрыгни вниз, в «Обитель Избранного»"] = "then jump down, into «Lair of the Chosen»",
    ["его щит снимают шесть троллей на балконах"] = "his shield is removed by the six trolls on the balconies",
    ["Огом Презренный"] = "Ogom the Wretched",
    ["он в том же зале, рядом с прошлым"] = "he is in the same hall, next to the last one",
    ["Жнец Снов"] = "Dreamscythe",
    ["летает над залом «Жертвенный колодец»"] = "flies over the hall «The Pit of Sacrifice»",
    ["прилетит после боя в «Обитель Избранного»"] = "comes after the fight in «Lair of the Chosen»",
    ["Ткачик"] = "Weaver",
    ["летает там же, рядом с прошлым"] = "flies in the same place, next to the last one",
    ["Морфаз"] = "Morphaz",
    ["из центра иди в южный тоннель"] = "from the middle go into the south tunnel",
    ["он летает там с другим драконом"] = "he flies there with another dragon",
    ["Хаззас"] = "Hazzas",
    ["его вызывают в комнате к западу от центра"] = "he is summoned in the room west of the middle",
    ["Тень Эраникуса"] = "Shade of Eranikus",
    ["дальше по южному коридору"] = "on along the south hallway",
    ["он там с двумя большими драконами"] = "he is there with two big dragons",
    ["Верховный дознаватель Герштан"] = "High Interrogator Gerstahn",
    ["от входа вниз в «Тюремный блок»"] = "from the entrance down into the «Detention Block»",
    ["он в самой южной комнате"] = "he is in the southernmost room",
    ["Лорд Роккор"] = "Lord Roccor",
    ["ходит по северному кольцу тюрьмы"] = "walks the northern ring of the prison",
    ["Псарь Гребмар"] = "Houndmaster Grebmar",
    ["по коридору вниз, в самую низкую точку"] = "along the hallway down, to its lowest point",
    ["Горош Дервиш"] = "Gorosh the Dervish",
    ["через открытые ворота на восточной стороне"] = "through the open gate on the east side",
    ["на арену «Зал Правосудия», в её центр"] = "onto the arena «Ring of the Law», to its middle",
    ["Кольцо Закона: один из шести"] = "Ring of Law: one of six",
    ["Пироман Зерно Мудрости"] = "Pyromancer Loregrain",
    ["в «Святилище Тауриссана», в конце коридора"] = "into the «Shrine of Thaurissan», at the end of the hallway",
    ["он на коленях у статуи"] = "he kneels by the statue",
    ["Лорд Опалитель"] = "Lord Incendius",
    ["в город «Тенегорн», к наковальне"] = "into the city «Shadowforge City», to the anvil",
    ["он на мосту в центре, над лавой"] = "he is on the bridge in the middle, over the lava",
    ["Тюремщик Стилгисс"] = "Warder Stilgiss",
    ["с балкона «Зал Ремесла» в «Черное Хранилище»"] = "from the balcony of the «Hall of Crafting» into «The Black Vault»",
    ["Точень Темнострой"] = "Fineous Darkvire",
    ["ходит по пандусу в «Зал Ремесла»"] = "walks the ramp in the «Hall of Crafting»",
    ["Бейл'Гор"] = "Bael'Gar",
    ["через ворота в северном коридоре тюрьмы"] = "through the gate in the north hallway of the prison",
    ["он в западном конце «Тракт Черного Железа»"] = "he is at the west end of the «Dark Iron Highway»",
    ["Генерал Кузня Гнева"] = "General Angerforge",
    ["в «Западный гарнизон», по левой лестнице"] = "into the «West Garrison», up the left stairs",
    ["он единственный босс там"] = "he is the only boss there",
    ["Повелитель големов Аргелмах"] = "Golem Lord Argelmach",
    ["с правой лестницы прямо в «Фабрика»"] = "from the right stairs straight on into «The Manufactory»",
    ["Харли Пьянодых"] = "Hurley Blackbreath",
    ["его вызывают: разбей три бочки в трактире"] = "he is called out: break the three kegs in the tavern",
    ["Риббли Крутипроб"] = "Ribbly Screwspigot",
    ["гоблин в трактире; станет врагом в разговоре"] = "a goblin in the tavern; he turns hostile in a talk",
    ["Штоппор Наливалс"] = "Plugger Spazzring",
    ["он стоит за стойкой трактира"] = "he stands behind the tavern's bar",
    ["Фаланкс"] = "Phalanx",
    ["из фабрики по мосту в трактир"] = "from the manufactory over the bridge into the tavern",
    ["он наверху, напротив стойки"] = "he is on the upper level, across from the bar",
    ["Посол Огнехлыст"] = "Ambassador Flamelash",
    ["за дверью трактира на балкон, налево"] = "through the tavern door onto the balcony, then left",
    ["он в зале «Колдовской чертог»"] = "he is in the hall «Chamber of Enchantment»",
    ["Рок'рел"] = "Doom'rel",
    ["через «Литейная» в «Гробница Заклинателей»"] = "through the «Mold Foundry» into the «Summoners' Tomb»",
    ["бой начнётся после разговора с ним"] = "the fight starts after you talk to him",
    ["Семеро дворфов"] = "The Seven",
    ["Магмус"] = "Magmus",
    ["дальше в «Лекторий»: зажги две жаровни"] = "on into «The Lyceum»: light the two braziers",
    ["он в конце зала «Железный зал»"] = "he is at the back of «The Iron Hall»",
    ["Император Дагран Тауриссан"] = "Emperor Dagran Thaurissan",
    ["в двери за ним, зал «Императорский Трон»"] = "through the doors behind him, hall «The Imperial Seat»",
    ["Нижняя часть"] = "Lower Spire",
    ["Вождь Омокк"] = "Highlord Omokk",
    ["от входа через большой зал с орками"] = "from the entrance through the big hall with orcs",
    ["он в зале «Мок'Дум»"] = "he is in the hall «Mok'Doom»",
    ["Темная охотница Вос'гаджин"] = "Shadow Hunter Vosh'gajin",
    ["дальше в зал троллей «Тазз'Алаор»"] = "on into the trolls' hall «Tazz'Alaor»",
    ["Воевода Вун"] = "War Master Voone",
    ["вниз по большому пандусу"] = "down the big ramp",
    ["он в конце длинного зала с троллями"] = "he is at the end of the long hall with trolls",
    ["Мать Дымная Паутина"] = "Mother Smolderweb",
    ["дальше в «Паучий лабиринт»"] = "on into the «Skitterweb Tunnels»",
    ["она наверху, в паутине"] = "she is at the top, in the webs",
    ["Аррок Смертный Вопль"] = "Urok Doomhowl",
    ["его вызывают у кучи даров в зале огров"] = "he is called at the tribute pile in the ogres' hall",
    ["Интендант Зигрис"] = "Quartermaster Zigris",
    ["за залом огров, зал «Кладовая»"] = "past the ogres' hall, hall «The Storehouse»",
    ["Халикон"] = "Halycon",
    ["дальше в зал «Логово Халикон»"] = "on into the hall «Halycon's Lair»",
    ["Гизрул Поработитель"] = "Gizrul the Slavener",
    ["прибежит в тот же зал после прошлого боя"] = "runs into the same hall after the last fight",
    ["Властитель Змейталак"] = "Overlord Wyrmthalak",
    ["дальше в зал «Чертог Битвы»"] = "on into the hall «Chamber of Battle»",
    ["он в конце нижней части"] = "he is at the end of the lower part",
    ["Верхняя часть"] = "Upper Spire",
    ["Пиростраж Созерцатель Углей"] = "Pyroguard Emberseer",
    ["от входа наверх, в дверь слева"] = "from the entrance go up, through the door on the left",
    ["он в зале «Зал Оков»"] = "he is in the hall «Hall of Binding»",
    ["Солакарский огнечервь"] = "Solakar Flamewreath",
    ["дальше в зал «Гнездовье» с яйцами драконов"] = "on into the hall «The Rookery» with the dragon eggs",
    ["редкий; ходит в зале «Зал Чернорука»"] = "rare; walks in the hall «Hall of Blackhand»",
    ["Вождь Ренд Чернорук"] = "Warchief Rend Blackhand",
    ["дальше на арену «Стадион Черной горы»"] = "on into the arena «Blackrock Stadium»",
    ["он выйдет после волн драконов"] = "he comes out after the waves of dragons",
    ["Зверь"] = "The Beast",
    ["дальше в зал «Горн»"] = "on into the hall «The Furnace»",
    ["Генерал Драккисат"] = "General Drakkisath",
    ["дальше в зал «Верховный трон»"] = "on into the hall «Spire Throne»",
    ["он в конце, с двумя стражами"] = "he is at the end, with two guards",
    ["Восток"] = "East",
    ["Пузиллин"] = "Pusillin",
    ["бес бегает в «Квартал Криводревов»"] = "the imp runs about in the «Warpwood Quarter»",
    ["говори с ним и беги следом"] = "talk to him and run after him",
    ["Зеврим Терновое Копыто"] = "Zevrim Thornhoof",
    ["Гидротварь"] = "Hydrospawn",
    ["уровнем ниже, у пруда с фонтаном"] = "one level lower, by the pool with the fountain",
    ["Лефтендрис"] = "Lethtendris",
    ["Алззин Перевертень"] = "Alzzin the Wildshaper",
    ["древень у двери откроет её для группы"] = "the treant by the door opens it for the group",
    ["за ней вниз по пандусу, он в конце"] = "past it go down the ramp, he is at the end",
    ["Запад"] = "West",
    ["Тендрис Криводрев"] = "Tendris Warpwood",
    ["от входа в сад «Центральный сад»"] = "from the entrance into the garden «Capital Gardens»",
    ["сначала убей древней, что бродят в саду"] = "first kill the ancients walking in the garden",
    ["Иллиана Воронья Ольха"] = "Illyanna Ravenoak",
    ["наверх по пандусам «Двор Высокорожденных»"] = "up the ramps of the «Court of the Highborne»",
    ["она над садом прошлого боя"] = "she is above the garden of the last fight",
    ["Магистр Календрис"] = "Magister Kalendris",
    ["он внизу, у подножия пандусов"] = "he is down below, at the foot of the ramps",
    ["Бессмер'тер"] = "Immol'thar",
    ["погаси пять кристаллов, иди в «Тюрьма Пламе'тара»"] = "shut down the five crystals, go into the «Prison of Immol'thar»",
    ["он почти в центре зала"] = "he is near the middle of the hall",
    ["Принц Тортелдрин"] = "Prince Tortheldrin",
    ["из тюрьмы по малому тоннелю в «Читальня»"] = "from the prison through a small tunnel into «The Athenaeum»",
    ["Север"] = "North",
    ["Стражник Мол'дар"] = "Guard Mol'dar",
    ["от входа на верхний ярус большого зала"] = "from the entrance onto the upper level of the big hall",
    ["Топотун Криг"] = "Stomper Kreeg",
    ["он в том же большом зале"] = "he is in the same big hall",
    ["Стражник Фенгус"] = "Guard Fengus",
    ["он ходит в центре своего зала, у сундука"] = "he walks in the middle of his hall, by the chest",
    ["Стражник Слип'кик"] = "Guard Slip'kik",
    ["ниже, на проходе под пандусами"] = "lower down, on the walkway under the ramps",
    ["зал «Гибельные залы»"] = "hall «Halls of Destruction»",
    ["Капитан Давигром"] = "Captain Kromcrush",
    ["вверх по пандусам"] = "up the ramps",
    ["он за комнатой с корзинами"] = "he is past the room with the baskets",
    ["Чо'Раш Наблюдатель"] = "Cho'Rush the Observer",
    ["в последнем зале «Трон Гордока»"] = "in the last hall «Gordok's Seat»",
    ["Король Гордок"] = "King Gordok",
    ["он в том же зале, на троне"] = "he is in the same hall, on the throne",
    ["Киртонос Глашатай"] = "Kirtonos the Herald",
    ["вызывается Кровью невинных"] = "summoned with the Blood of Innocents",
    ["Джандис Баров"] = "Jandice Barov",
    ["вниз под комнату с чумными дракончиками"] = "down below the room with the plagued whelps",
    ["дверь откроет факел у стены"] = "a torch on the wall opens the door",
    ["Громоклин"] = "Rattlegore",
    ["дальше вниз в зал «Великий оссуарий»"] = "further down into the hall «The Great Ossuary»",
    ["он в самом низу"] = "he is at the very bottom",
    ["Мардук Блэкпул"] = "Marduk Blackpool",
    ["в углу зала «Демонстрационная комната»"] = "in a corner of the hall «The Viewing Room»",
    ["Вектус"] = "Vectus",
    ["в зале «Демонстрационная комната»"] = "in the hall «The Viewing Room»",
    ["Рас Снегошепот"] = "Ras Frostwhisper",
    ["дальше в зал «Лаборатория»"] = "on into the hall «The Laboratory»",
    ["Инструктор Коварница"] = "Instructor Malicia",
    ["в большом зале шесть дверей на двух ярусах"] = "the big hall has six doors on two levels",
    ["она наверху, зал «Ведьмин зал»"] = "she is upstairs, hall «The Coven»",
    ["Доктор Теолен Крастинов"] = "Doctor Theolen Krastinov",
    ["верхний ярус, зал «Зал Проклятых»"] = "upper level, hall «Hall of the Damned»",
    ["Сказитель Полкелт"] = "Lorekeeper Polkelt",
    ["верхний ярус, зал «Зал Тайн»"] = "upper level, hall «Hall of Secrets»",
    ["Равениан"] = "The Ravenian",
    ["нижний ярус, зал «Склеп Равениана»"] = "lower level, hall «Vault of the Ravenian»",
    ["Лорд Алексей Баров"] = "Lord Alexei Barov",
    ["нижний ярус, «Семейный склеп Баровых»"] = "lower level, «Barov Family Vault»",
    ["Леди Иллюсия Баров"] = "Lady Illucia Barov",
    ["нижний ярус, зал «Мрачный Свод»"] = "lower level, hall «The Shadow Vault»",
    ["Темный магистр Гандлинг"] = "Darkmaster Gandling",
    ["он появится в центре зала с шестью дверями"] = "he appears in the middle of the hall with six doors",
    ["выходит после шести боссов в боковых комнатах"] = "comes out after the six bosses in the side rooms",
    ["Живая сторона"] = "Living side",
    ["Череп"] = "Skul",
    ["Певчий Форрестен"] = "Hearthsinger Forresten",
    ["может стоять на улице «Праздничная улица»"] = "may stand on the street «Festival Lane»",
    ["Непрощенный"] = "The Unforgiven",
    ["от входа через площадь в «Торговый ряд»"] = "from the entrance across the square into «Market Row»",
    ["он там, среди призраков"] = "he is there, among the ghosts",
    ["Тайлер"] = "Timmy the Cruel",
    ["дальше на «Площадь рыцарей»"] = "on to «Crusaders' Square»",
    ["он выйдет, когда очистишь площадь"] = "he comes out once the square is cleared",
    ["Малор Ревностный"] = "Malor the Zealous",
    ["войди в «Бастион Алого ордена»"] = "go into «The Scarlet Bastion»",
    ["Мастер-канонир Вилли"] = "Cannon Master Willey",
    ["он во дворе «Арсенал»"] = "he is in the yard «The Hoard»",
    ["Архивариус Галфорд"] = "Archivist Galford",
    ["он в архиве внутри бастиона"] = "he is in the archive inside the bastion",
    ["Балназзар"] = "Balnazzar",
    ["в конце бастиона, зал «Кровавый трон»"] = "at the end of the bastion, hall «The Crimson Throne»",
    ["Мёртвая сторона"] = "Undead side",
    ["Мировой судья Бартилас"] = "Magistrate Barthilas",
    ["он на «Площадь Старейшин»"] = "he is on «Elders' Square»",
    ["Неруб'энкан"] = "Nerub'enkan",
    ["дальше на «Улица Испытаний»"] = "on to «The Gauntlet»",
    ["вдоль неё три башни; он в одной из них"] = "three towers stand along it; he is in one of them",
    ["Баронесса Анастари"] = "Baroness Anastari",
    ["она в другой башне той же улицы"] = "she is in another tower on the same street",
    ["Малекай Бледный"] = "Maleki the Pallid",
    ["он в третьей башне"] = "he is in the third tower",
    ["Рамштайн Ненасытный"] = "Ramstein the Gorger",
    ["в конце улицы «Площадь Живодерни»"] = "at the end of the street, «Slaughter Square»",
    ["ворота откроются после трёх башен"] = "the gate opens after the three towers",
    ["Барон Ривендер"] = "Baron Rivendare",
    ["за площадью вход в «Живодерня»"] = "past the square is the entrance to «The Slaughter House»",
    ["он внутри"] = "he is inside",
    ["|cff71c886ты в его зале|r"] = "|cff71c886you are in his room|r",
    ["сначала через «"] = "first via «",
    ["его зал позади: «"] = "his room is behind you: «",
    ["его зал: «"] = "his room: «",
    ["Чертог Искупления"] = "Chamber of Atonement",
    ["Покинутый двор"] = "Forlorn Cloister",
    ["Гробница Доблести"] = "Honor's Tomb",
    ["убить"] = "kill",
    ["добыча с него"] = "loot from him",
    ["первый босс: "] = "first boss: ",
    [" • боссов: "] = " • bosses: ",
    ["убито боссов: "] = "bosses dead: ",
    ["и ещё боссов: "] = "and more bosses: ",
    ["Оргриммар"] = "Orgrimmar",
    ["Громовой Утёс"] = "Thunder Bluff",
    ["Подгород"] = "Undercity",
    ["Штормград"] = "Stormwind",
    ["Стальгорн"] = "Ironforge",
    ["Дарнас"] = "Darnassus",
    ["вышка у Подгорода"] = "tower near Undercity",
    ["дирижабль в Оргриммар"] = "zeppelin to Orgrimmar",
    ["вышка у ворот Оргриммара"] = "tower by the gates of Orgrimmar",
    ["дирижабль в Гром'гол"] = "zeppelin to Grom'gol",
    ["лагерь Гром'гол, север Тернистой долины"] = "Grom'gol Base Camp, north Stranglethorn Vale",
    ["вышка в Гром'голе"] = "tower in Grom'gol",
    ["дирижабль в Подгород"] = "zeppelin to Undercity",
    ["вышка у Оргриммара"] = "tower near Orgrimmar",
    ["причал в Пиратской Бухте"] = "dock in Booty Bay",
    ["корабль в Кабестан"] = "ship to Ratchet",
    ["Кабестан, Степи"] = "Ratchet, The Barrens",
    ["причал в Кабестане"] = "dock in Ratchet",
    ["корабль в Пиратскую Бухту"] = "ship to Booty Bay",
    ["Пиратская Бухта"] = "Booty Bay",
    ["причал в Гавани Менетилов"] = "dock in Menethil Harbor",
    ["корабль в Терамор"] = "ship to Theramore",
    ["остров Терамор"] = "Theramore Isle",
    ["корабль в Аубердин"] = "ship to Auberdine",
    ["Аубердин"] = "Auberdine",
    ["причал в Тераморе"] = "dock in Theramore",
    ["корабль в Гавань Менетилов"] = "ship to Menethil Harbor",
    ["Гавань Менетилов"] = "Menethil Harbor",
    ["причал в Аубердине"] = "dock in Auberdine",
    ["^д"] = "^z",
    ["Д"] = "Z",
    ["^к"] = "^s",
    ["К"] = "S",
    ["пешком напрямую"] = "on foot directly",
    ["телепорт: "] = "teleport: ",
    [", затем "] = ", then ",
    ["нужен транспорт на другой континент"] = "needs transport to another continent",
    ["Перекрёсток"] = "Crossroads",
    ["Лагерь Таурахо"] = "Camp Taurajo",
    ["Кабестан"] = "Ratchet",
    ["Гром'гол"] = "Grom'gol",
    ["застава Зорам'гар"] = "Zoram'gar Outpost",
    ["застава Расщепленного Дерева"] = "Splintertree Post",
    ["Мельница Таррен"] = "Tarren Mill",
    ["Каргат"] = "Kargath",
    ["проход между зонами"] = "pass between zones",
    ["спустись на подъёмнике"] = "take the lift down",
    ["поднимись на подъёмнике"] = "take the lift up",
    ["Проход: "] = "Pass: ",
    ["распорядитель полётов "] = "flight master ",
    ["проход: "] = "pass: ",
    ["Перелёт: "] = "Flight: ",
    ["перелёт: "] = "flight: ",
    ["Вход в пещеру: "] = "Cave entrance: ",
    ["дальше внутри пещеры"] = "then inside the cave",
    ["|cffedc36fDungeon Quest Forever|r • запомнил твои точки перелётов: "] = "|cffedc36fDungeon Quest Forever|r • saved your flight points: ",
    [" из "] = " of ",
    [". Теперь дорога считается с ними."] = ". Routes now take them into account.",
    ["|cffedc36fDungeon Quest Forever|r • лети в: "] = "|cffedc36fDungeon Quest Forever|r • fly to: ",
    ["Том готов"] = "Tome ready",
    ["В Даларане после Атрекиса иди прямо к фиолетовой руне."] = "In Dalaran, after Atrexis, go straight to the purple rune.",
    ["До входа"] = "Before entering",
    ["Отнеси чёрный том к синему кристаллу в ратуше Янтарной Мельницы (63.4, 64.3)."] = "Take the black tome to the blue crystal in the Ambermill town hall (63.4, 64.3).",
    ["Сначала в Крепость Тёмного Клыка. После Аругала забери чёрный том со стола."] = "First go to Shadowfang Keep. After Arugal, take the black tome from the table.",
    ["Внутри"] = "Inside",
    ["После Аругала возьми чёрный том со стола для секретного босса Даларана."] = "After Arugal, take the black tome from the table for Dalaran's secret boss.",
    ["Молот готов"] = "Mallet ready",
    ["Ударь в гонг у бассейна Газ’риллы."] = "Strike the gong at Gahz'rilla's pool.",
    ["Заряди священный молот у алтаря на вершине Джинта’Алора (59, 77)."] = "Charge the Sacred Mallet at the altar atop Jintha'Alor (59, 77).",
    ["Во Внутренних землях забери священный молот у Киаги на Алтаре Зула (48.6, 68.2)."] = "In the Hinterlands, take the Sacred Mallet from Qiaga at the Altar of Zul (48.6, 68.2).",
    ["Ключ готов"] = "Key ready",
    ["Алый ключ у тебя. Он открывает дверь этого крыла."] = "You have the Scarlet Key. It opens this wing's door.",
    ["Уточни, есть ли у группы Алый ключ. За своим сходи в библиотеку — сундук за Доаном."] = "Check whether the party has the Scarlet Key. For your own, go to the Library — the chest behind Doan.",
    ["Карта готова"] = "Card ready",
    ["Призматическая перфокарта у тебя. Отнеси её Чугунотрубзу в Стальгорн — «Спасение данных»."] = "You have the Prismatic Punch Card. Take it to Master Mechanic Castpipe in Ironforge — \"Data Rescue\".",
    ["Красную карту вставь в перфограф 3005-D — нижний ярус инженерных лабораторий, западная сторона. Он выдаст призматическую."] = "Insert the red card into Matrix Punchograph 3005-D — lower level of the engineering labs, west side. It gives the prismatic one.",
    ["Синюю карту вставь в перфограф 3005-C — верхняя площадка у Электрошокера 6000. Он выдаст красную, с ней иди к 3005-D."] = "Insert the blue card into Matrix Punchograph 3005-C — the upper platform by Electrocutioner 6000. It gives the red one; take it to 3005-D.",
    ["Жёлтую карту вставь в перфограф 3005-B — спальный блок недалеко от входа. Он выдаст синюю, дальше 3005-C и 3005-D."] = "Insert the yellow card into Matrix Punchograph 3005-B — the dormitory near the entrance. It gives the blue one, then 3005-C and 3005-D.",
    ["Белая карта у тебя. Вставь её в перфограф 3005-A в мастерской перед порталом (22, 33) — он выдаст жёлтую."] = "You have the white card. Insert it into Matrix Punchograph 3005-A in the workshop before the portal (22, 33) — it gives the yellow one.",
    ["Белая перфокарта падает с троггов и лепрогномов в тоннелях перед порталом. Выбей одну и вставь в перфограф 3005-A там же (22, 33)."] = "White Punch Cards drop from troggs and leper gnomes in the tunnels before the portal. Get one and insert it into Matrix Punchograph 3005-A there (22, 33).",
    ["Для повторного вызова Акваниса нужен участник с активным заданием «Среди руин»."] = "To summon Aquanis again, a party member needs the active quest \"Amongst the Ruins\".",
    ["Задание взято"] = "Quest taken",
    ["После похода"] = "After the run",
    ["^Вход • внутри"] = "^Entrance • inside",
    ["Убрать стрелку"] = "Remove the arrow",
    ["Точка на карте останется. Щелчок по любой строке трекера вернёт стрелку."] = "The map point stays. Clicking any tracker line brings the arrow back.",
    ["Щелчок читает заклинание. После телепорта стрелка поведёт дальше."] = "Click casts the spell. After the teleport the arrow leads on.",
    ["Без телепорта"] = "Without teleport",
    ["Дорога к той же цели пересчитается без заклинания, и её поведёт стрелка."] = "The route to the same goal is recalculated without the spell, and the arrow will lead it.",
    ["Телепорт: "] = "Teleport: ",
    ["затем: "] = "then: ",
    ["Другой континент • "] = "Another continent • ",
    ["По твоему уровню"] = "For your level",
    ["Подземелья твоего уровня."] = "Dungeons for your level.",
    ["Ниже твоего уровня"] = "Below your level",
    ["Ты перерос эти подземелья, но задания в них остались."] = "You have outlevelled these dungeons, but their quests remain.",
    ["Скоро"] = "Soon",
    ["До этих подземелий осталось не больше трёх уровней."] = "These dungeons are no more than three levels away.",
    ["Позже"] = "Later",
    ["Эти подземелья пока далеко по уровню."] = "These dungeons are still far above your level.",
    [" Щелчок сворачивает и разворачивает группу."] = " Click collapses and expands the group.",
    ["%.1f км"] = "%.1f km",
    [", перелётом быстрее"] = ", faster by flight",
    [" через проход"] = " via the pass",
    ["за морем"] = "overseas",
    ["Цели выполнены. Стрелка ведёт сдавать: "] = "Goals done. The arrow leads to hand it in: ",
    ["Цель выполнена. Стрелка ведёт дальше: "] = "Goal done. The arrow leads on to: ",
    ["В журнале %d  •  Сдано %d  •  Всего %d"] = "In log %d  •  Turned in %d  •  Total %d",
    ["\nЗадания для входа готовы"] = "\nEntrance quests ready",
    ["у столбца нет точки привязки"] = "the column has no anchor point",
    ["точка привязки не читается"] = "anchor point cannot be read",
    ["|cffedc36fDungeon Quest|r • столбец заданий не отодвинулся от панелей: "] = "|cffedc36fDungeon Quest|r • the quest column did not move away from the bars: ",
    ["игра вернула его на место"] = "the game moved it back",
    ["Карта"] = "Map",
    ["Журнал"] = "Journal",
    ["Стрелка"] = "Arrow",
    ["Без стрелки"] = "No arrow",
    ["Дорога пешком (по прямой не пройти):"] = "On foot (no straight path):",
    ["Короткий путь:"] = "Shortest path:",
    [" — платформа"] = " — platform",
    [" наверху вышки"] = " at the top of the tower",
    [", где "] = ", with ",
    [" (если эта точка у тебя открыта)"] = " (if you know this flight point)",
    ["цель"] = "goal",
    ["Сделать сейчас: "] = "Do now: ",
    ["В журнале: "] = "In log: ",
    ["Цели в подземелье. Стрелка ведёт ко входу."] = "Objectives in the dungeon. The arrow leads to the entrance.",
    ["Стрелка ведёт ко входу."] = "The arrow leads to the entrance.",
    ["Шаг цепочки к «"] = "Chain step toward «",
    ["Цепочка заданий (шаг "] = "Quest chain (step ",
    ["Заданием может поделиться участник группы."] = "A party member can share this quest.",
    ["Мусорных заданий нет"] = "No junk quests",
    ["Мусор — это серое по уровню задание, которое ты не начинал и которое не входит ни в какую цепочку."] = "Junk is a grey quest you have not started and that is not part of any chain.",
    ["Таких в журнале сейчас нет."] = "There are none in your log now.",
    ["Серые по уровню, не начаты, без цепочек, не из подземелий:"] = "Grey, not started, no chain, not from dungeons:",
    ["и ещё "] = "plus ",
    ["|cffffa64dУбранное задание можно взять снова у того, кто его давал.|r"] = "|cffffa64dAn abandoned quest can be picked up again from whoever gave it.|r",
    ["Мусорные задания: "] = "Junk quests: ",
    ["Убрать все"] = "Abandon all",
    ["Убрано заданий: "] = "Quests abandoned: ",
    ["Игра не дала аддону убрать задания. Их придётся убрать руками в журнале: "] = "The game did not let the addon abandon the quests. Abandon them by hand in the quest log: ",
    [". Остались: "] = ". Remaining: ",
    ["Отмена"] = "Cancel",
    ["Готовит тебя к подземелью прямо в колонке заданий."] = "Gets you ready for a dungeon right in the quest tracker.",
    ["Показывает, какие задания взять перед подземельем, и ведёт по цепочкам."] = "Shows which quests to pick up before a dungeon and leads you through their chains.",
    ["Стрелка ведёт короткой дорогой: перелёты, дирижабли, телепорты и проходы между зонами."] = "The arrow takes the short way: flights, zeppelins, teleports and the passes between zones.",
    ["Внутри подземелья — боссы по порядку и их добыча с пометкой лучшего для твоего класса."] = "Inside a dungeon: the bosses in order and their loot, with the best for your class marked.",
    ["Сам принимает и сдаёт задания и убирает мусорные."] = "Picks up and turns in quests by itself and clears out junk quests.",
    ["С чего начать"] = "Where to begin",
    ["В заголовке панели нажми ••• и выбери подземелье."] = "Press ••• in the panel's heading and choose a dungeon.",
    ["Щёлкни по заданию — оно раскроется и поставит стрелку."] = "Click a quest: it unfolds and sets the arrow.",
    ["Нажми «Журнал» — откроется книга с боссами и добычей."] = "Press Journal: the book with bosses and loot opens.",
    ["Страница аддона:"] = "Addon page:",
    ["Принимать и сдавать задания самому"] = "Pick up and turn in quests automatically",
    ["Начать"] = "Begin",
    ["Сообщить об ошибке"] = "Report a bug",
    ["Что-то работает не так или есть идея? Напиши на странице аддона. Адрес можно выделить и скопировать (Ctrl+C):"] = "Something not working, or an idea? Write on the addon's page. The address can be selected and copied (Ctrl+C):",
    ["И приложи эти строки — по ним видно, что у тебя за игра и что делал аддон:"] = "And add these lines: they show what your game is and what the addon was doing:",
    ["Закрыть"] = "Close",
    ["Откроет окно с адресом, куда написать, и строками для отчёта."] = "Opens a window with the address to write to and the lines for the report.",
    ["Журнал: задания, боссы, добыча"] = "Journal: quests, bosses, loot",
    ["Список подземелий"] = "List of dungeons",
    ["Лучшие вещи для класса"] = "Best gear for your class",
    ["Настройки"] = "Settings",
    ["Панель в колонке заданий"] = "Panel in the quest tracker",
    ["Вид как у заданий игры"] = "Look like the game's quests",
    ["Тёмный фон панели"] = "Dark panel background",
    ["Звук при входе в новый зал подземелья"] = "Sound on entering a new hall of the dungeon",
    ["Подсвечивать предметы для заданий"] = "Highlight quest objects",
    ["Рассказывать группе и рейду об аддоне"] = "Tell the group and the raid about the addon",
    ["Вести стрелку по дорогам, в обход гор"] = "Lead the arrow along paths, around mountains",
    ["Метка над нужным персонажем (включает полоски имён)"] = "Marker over the NPC you need (turns on name plates)",
    ["Кнопка у миникарты"] = "Minimap button",
    ["Убрать мусорные задания"] = "Clear junk quests",
    ["Страница приветствия"] = "Welcome page",
    ["Щелчок — настройки.\nПравая кнопка — журнал.\nТащи, чтобы переставить вокруг миникарты."] = "Click: settings.\nRight-click: journal.\nDrag to move it around the minimap.",
    ["Вот оно: "] = "Here it is: ",
    ["Портал"] = "Portal",
    ["Телепорт"] = "Teleport",
    ["Выход"] = "Exit",
    ["Щелчок ставит стрелку на эту точку."] = "Click sets the arrow to this point.",
    ["Книга: все задания и боссы подземелья, добыча боссов."] = "Book: all quests and bosses of the dungeon, boss loot.",
    ["Поделиться"] = "Share",
    ["Поделиться с группой всеми заданиями этого подземелья, что у тебя в журнале, и попросить в чате группы недостающие. Аддон у других поделится ими сам."] = "Share every quest of this dungeon in your log with the group, and ask in the group chat for the ones you lack. Others with the addon share them by themselves.",
    ["Вещи"] = "Gear",
    ["Лучшие вещи для твоего класса и ветки талантов на твоём уровне и дальше: где каждая падает или за какое задание даётся."] = "The best gear for your class and talent tree at your level and beyond: which boss drops each piece or which quest gives it.",
    ["Мусор: "] = "Junk: ",
    ["Серые неначатые задания без цепочек. Щелчок покажет список и спросит, убрать ли их."] = "Grey unstarted quests with no chain. Click shows the list and asks whether to abandon them.",
    ["Скрыть убитых"] = "Hide dead",
    ["Показать убитых"] = "Show dead",
    ["Свернуть убитых боссов в одну строку."] = "Collapse dead bosses into one line.",
    ["Показать убитых боссов списком."] = "Show dead bosses as a list.",
    ["Скрыть сданные"] = "Hide turned in",
    ["В списке только подземелья, где ещё есть что делать. Сданные и скрытые тобой не показываются."] = "Only dungeons with something left to do are listed. Turned in and ones you hid are not shown.",
    ["Показать все"] = "Show all",
    ["Все подземелья, со сданными и скрытыми. ПКМ по подземелью скрывает его из списка или возвращает."] = "All dungeons, including turned in and hidden. Right-click a dungeon to hide it from the list or bring it back.",
    ["Взять в цель: %s"] = "Target: %s",
    ["Работает, когда он рядом."] = "Works when it is nearby.",
    ["сдано"] = "handed in",
    ["готово — сдай"] = "done: hand it in",
    ["в журнале"] = "in your log",
    ["впереди: откроется после предыдущего шага"] = "ahead: opens after the step before",
    ["Щелчок — стрелка и что делать на этом шаге."] = "Click: the arrow and what to do at this step.",
    ["ещё шагов: "] = "steps more: ",
    ["Сейчас, шаг "] = "Now, step ",
    ["Сейчас: "] = "Now: ",
    ["сдай "] = "hand in ",
    [" — делается внутри"] = " — done inside",
    ["возьми "] = "take ",
    ["Шаг «"] = "The step '",
    ["» уже сдан."] = "' is handed in already.",
    ["» откроется после «"] = "' opens after '",
    ["как найти:"] = "how to find:",
    ["Сдай"] = "Hand in",
    ["взять"] = "take",
    ["и ещё:"] = "and also:",
    ["»: ты в зале босса "] = "»: you are in the room of boss ",
    ["». К боссу "] = "». To boss ",
    ["твоя лучшая вещь:"] = "your best item:",
    ["совет:"] = "tip:",
    ["Боссы • убито "] = "Bosses • dead ",
    ["Все боссы подземелья по порядку. Щелчок по боссу — его добыча. ПКМ — отметить убитым или вернуть. Щелчок по заголовку сворачивает список."] = "Every boss of the dungeon in order. Click a boss for his loot. Right-click: mark killed or alive again. Click the heading to fold the list.",
    ["Все подземелья скрыты фильтрами"] = "All dungeons hidden by filters",
    ["В базе нет заданий для персонажа"] = "No quests in the database for this character",
    ["Показать или убрать маленький план рядом с трекером."] = "Show or remove the small floor plan next to the tracker.",
    ["Показать маршрут"] = "Show route",
    ["Открыть в журнале"] = "Open in journal",
    [" • скрыто|r"] = " • hidden|r",
    ["ур. %d–%d"] = "lvl %d–%d",
    ["заданий нет"] = "no quests",
    ["всё сдано"] = "all turned in",
    ["в журнале "] = "in log ",
    ["осталось "] = "remaining ",
    ["заданий осталось: "] = "quests remaining: ",
    ["Сделай"] = "Do",
    ["Возьми"] = "Pick up",
    ["место неизвестно"] = "location unknown",
    ["цепочка к «"] = "chain to «",
    ["шаг "] = "step ",
    [" • убит|r"] = " • dead|r",
    ["Босс рядом"] = "Boss nearby",
    ["Следующий босс: "] = "Next boss: ",
    ["|cff71c886 • рядом, метка над ним|r"] = "|cff71c886 • nearby, marked above it|r",
    ["|cffffd34d • следующий|r"] = "|cffffd34d • next|r",
    [" • по желанию|r"] = " • optional|r",
    ["Путь к боссу"] = "Way to the boss",
    ["План этажа с путём к этому боссу."] = "The floor plan with the way to this boss.",
    ["иконка телепорта появится после боя: в бою игра не даёт её показать"] = "the teleport icon will appear after combat: the game does not allow showing it in combat",
    ["нажми иконку телепорта на месте стрелки; крестик на ней — идти без телепорта"] = "click the teleport icon in place of the arrow; the cross on it means go without teleport",
    ["пешком через проход между зонами: по прямой там не пройти"] = "on foot via the pass between zones: no straight path there",
    ["распорядитель полётов: "] = "flight master: ",
    ["если эта точка у тебя открыта; открой карту полётов, и я запомню твои точки|r"] = "if you know this flight point; open the flight map and I will remember your points|r",
    ["платформа"] = "platform",
    ["затем "] = "then ",
    ["потом к цели: "] = "then to the goal: ",
    ["Босс|r  "] = "Boss|r  ",
    ["|cff9bd8eaВ поле зрения|r • стрелка над полоской здоровья"] = "|cff9bd8eaIn sight|r • arrow above the health bar",
    ["|cffaaaaaaЗатем • "] = "|cffaaaaaaThen • ",
    ["|cffaaaaaaЩелчок по строке — снова первый шаг|r"] = "|cffaaaaaaClick the line to return to the first step|r",
    ["Советы • "] = "Tips • ",
    ["Не взято"] = "Not taken",
    ["Сдать"] = "Turn in",
    ["Задание"] = "Quest",
    ["у босса: "] = "at boss: ",
    ["снаружи"] = "outside",
    ["шаг цепочки:"] = "chain step:",
    ["пока недоступно"] = "not available yet",
    ["сдать|r"] = "turn in|r",
    ["сделать|r"] = "do|r",
    ["сдать внутри|r"] = "turn in inside|r",
    ["в журнале|r"] = "in log|r",
    [", делается внутри|r"] = ", done inside|r",
    ["доделать|r"] = "finish|r",
    ["начнётся внутри с найденного предмета|r"] = "starts inside from an item you find|r",
    ["предмет падает внутри|r"] = "the item drops inside|r",
    ["Рабомучитель Грокс"] = "Slavecrusher Grox",
    ["Сумеречный командир Зармок"] = "Twilight Commander Zarmok",
    ["Укротительница Ашка"] = "War Handler Ashka",
    ["Нар'гурк"] = "Nar'gurk",
    ["Босс Туф"] = "Bossman Toof",
    ["Владыка Магг"] = "Overlord Mugg",
    ["Фальдрим Анвилмар"] = "Faldrim Anvilmar",
    ["Магматус"] = "Magmatus",
    ["Грабеж"] = "Plunder",
    ["Дюрген Погребальный Молот"] = "Durgen Dirgehammer",
    ["Сухоклык"] = "Witherfang",
    ["Барон"] = "The Baron",
    ["Виктор Мерзкий"] = "Viktor the Vile",
    ["Покинутый"] = "The Abandoned",
    ["Бьорк"] = "Bjork",
    ["Рат'маэль"] = "Rath'mael",
    ["событие: щёлкни камин, он выйдет на шестой волне"] = "event: click the fireplace, he comes on the sixth wave",
    ["событие: щёлкни статую, он выйдет после трёх волн"] = "event: click the statue, he comes after three waves",
    ["Соленый Хребет"] = "Saltspine",
    ["Тенеклык"] = "Shadetooth",
    ["Ужас высокогорья"] = "Highland Horror",
    ["Страж реликвий"] = "Relic Guardian",
    ["выходит, когда щёлкнешь панель титанов рядом"] = "comes when you click the titan panel next to him",
    ["Атрексис Рыцарь Могил"] = "Atrexis the Grave Knight",
    ["Лин Пренебрегаемый"] = "Lyn the Ignored",
    ["Магическая аномалия"] = "Arcane Anomaly",
    ["Маговая Загадка"] = "Arcanic Enigma",
    ["Нестабильный страж"] = "Unstable Sentinel",
    ["Сквернодревень"] = "Fel Ancient",
    ["Пожиратель маны"] = "Mana Devourer",
    ["Тень верховного мага"] = "Shade of the Archmage",
    ["тайный босс: его вызывает Фолиант Даларана"] = "secret boss: summoned with the Tome of Dalaran",
    ["барьер снимается после разговора с магом рядом"] = "the barrier opens after you talk to the mage nearby",
    ["к нему ведёт портал архимага Модеры"] = "Archmage Modera's portal leads to him",
    ["с него падает связка ключей: открывает правое крыло"] = "drops the keyring that opens the right wing",
    ["за запертой дверью у входа; для заданий его бьют последним"] = "behind a locked door by the entrance; for the quests, kill him last",
    ["пока живы четыре ритуалиста, получает меньше урона"] = "takes less damage while the four ritualists live",
    ["выходит после разговора со старейшиной Bramblesnap"] = "comes after you talk to Elder Bramblesnap",
    ["вызов: 15 красных кристаллов силы у панели"] = "summon: 15 red power crystals at the panel",
    ["вызов: 15 синих кристаллов силы у панели"] = "summon: 15 blue power crystals at the panel",
    ["вызов: 15 зелёных кристаллов силы у панели"] = "summon: 15 green power crystals at the panel",
    ["вызов: 15 жёлтых кристаллов силы у панели"] = "summon: 15 yellow power crystals at the panel",
    ["панель титанов на Столпе ассимиляции, когда горят все четыре панели"] = "the titan panel on the Pillar of Assimilation, once all four panels are lit",
    ["кузница за загоном с волками Ашки, где дорога сворачивает налево"] = "a forge behind Ashka's wolf pen, where the road bends left",
    ["Писать о выполненном задании в группу или криком"] = "Tell the group when a quest is done, or yell when alone",
    ["О выполненных заданиях больше не пишу."] = "No more lines about quests done.",
    ["Когда задание выполнено, напишу об этом в группу, а без группы — криком."] = "When a quest is done, I will say so to the group, or yell it when you are alone.",
    ["Писать в группу после босса, кто следующий и что с него падает"] = "After a boss, tell the group the next one and what it drops",
    ["Что падает с боссов, больше не пишу."] = "No more lines about what bosses drop.",
    ["Не нашёл следующего босса для проверки."] = "No next boss found to test with.",
    ["где: в другом крыле — «%s». Выйди и зайди в его вход"] = "where: in another wing, %s. Go out and in through its door",
    ["После каждого босса напишу в группу, кто следующий, что с него падает и кому из вас это лучшая вещь."] = "After each boss I will tell the group the next one, what it drops and whose best item that is.",
    ["взять внутри|r"] = "pick up inside|r",
    ["^выдаёт "] = "^given by ",
    ["взять|r"] = "pick up|r",
    ["место неизвестно|r"] = "location unknown|r",
    ["сейчас:|r "] = "now:|r ",
    ["куда:|r "] = "where:|r ",
    ["через|r "] = "via|r ",
    [" • шаг "] = " • step ",
    [": далее по цепочке|r"] = ": rest of the chain|r",
    ["если не поделятся"] = "if nobody shares",
    ["сдать"] = "hand in",
    ["у входа — возьми по дороге в подземелье"] = "at the entrance: take it on the way in",
    ["может поделиться группа"] = "a group member can share it",
    ["взято|r"] = "taken|r",
    ["не взято|r"] = "not taken|r",
    [" • сначала цепочка|r"] = " • chain first|r",
    ["у входа: возьми по дороге в подземелье|r"] = "at the entrance: take it on the way in|r",
    ["попроси группу поделиться — бежать не нужно"] = "ask the group to share it: no need to run there",
    [" • место неизвестно|r"] = " • location unknown|r",
    ["им может поделиться группа"] = "a party member can share it",
    ["цепочка "] = "chain ",
    [" к «"] = " to «",
    ["сдать "] = "turn in ",
    ["сделать "] = "do ",
    ["взять "] = "pick up ",
    [", цепочка к «"] = ", chain to «",
    [" • делится"] = " • shareable",
    [" • место неизвестно"] = " • location unknown",
    [" • к «"] = " • to «",
    ["внутри: "] = "inside: ",
    ["внутри"] = "inside",
    ["Подземелья • уровень "] = "Dungeons • level ",
    ["Фильтры подземелий"] = "Dungeon filters",
    ["Подсказки в пати"] = "Party tips",
    [" • сдано "] = " • turned in ",
    ["|cffffd34d • к сдаче "] = "|cffffd34d • to turn in ",
    ["|cff9d9d9d • в работе "] = "|cff9d9d9d • in progress ",
    ["Открыть"] = "Open",
    ["Вернуть в список"] = "Return to list",
    ["Убрать в пройденные"] = "Move to cleared",
    ["|cffffd100Пройдено и убрано: "] = "|cffffd100Cleared and set aside: ",
    [" — показать|r"] = " — show|r",
    [" — скрыть|r"] = " — hide|r",
    ["|cff9d9d9dНе по уровню: "] = "|cff9d9d9dNot your level: ",
    ["Весь список подземелий"] = "Full dungeon list",
    ["Журнал заданий"] = "Quest journal",
    ["Все задания и боссы этого подземелья. Правый щелчок — меню: другое подземелье, скрыть пройденные."] = "All the quests and bosses of this dungeon. Right-click for the menu: another dungeon, hide cleared ones.",
    ["Развернуть панель"] = "Expand panel",
    ["Свернуть панель"] = "Collapse panel",
    ["|cff999999 • свёрнуто|r"] = "|cff999999 • collapsed|r",
    ["Кратчайший путь ко входу"] = "Shortest way to the entrance",
    ["Стрелка поведёт самым быстрым путём: телепорт, перелёт или проход между зонами — что короче. Откроется карточка с шагами."] = "The arrow takes the fastest way: a teleport, a flight or a pass between zones, whichever is shorter. A card with the steps opens.",
    ["Щелчок: маленький план этажа, босс подсвечен. Большой — ПКМ по плану.\nПКМ: отметить убитым или вернуть живым, если аддон сам не заметил."] = "Click: small floor plan, boss highlighted. The large one: right-click the plan.\nRight-click: mark killed or alive again, if the addon did not notice.",
    ["Этот босс убит. ПКМ вернёт его в живые."] = "This boss is dead. Right-click brings it back alive.",
    ["Щелчок: карта атласа с этим боссом и маленький план этажа.\n"] = "Click: atlas map with this boss and the small floor plan.\n",
    ["ПКМ: отметить убитым, если аддон сам не заметил.\n"] = "Right-click: mark dead if the addon missed it.\n",
    ["Места внутри подземелья аддон не знает: игра не сообщает там положение. Порядок боссов взят из классической версии."] = "The addon does not know positions inside the dungeon: the game does not report them there. Boss order is taken from the classic version.",
    ["Журнал подземелья"] = "Dungeon journal",
    ["Все задания с подробностями и цепочками по шагам и все боссы. То же делает значок книжки в заголовке и команда /dq book."] = "All quests with details and step-by-step chains, and all bosses. The book icon in the header and the /dq book command do the same.",
    ["Сейчас"] = "Now",
    ["Щелчок ставит стрелку и показывает карточку этого шага."] = "Click sets the arrow and shows the card for this step.",
    ["Точка полёта, которой у тебя ещё нет: открой её у распорядителя, потом сюда можно будет прилететь. Щелчок ставит стрелку к нему."] = "A flight point you don't have yet: talk to its flight master to discover it, then you can fly here. Click to set the arrow to him.",
    ["Брать больше нечего. Щелчок ставит стрелку ко входу."] = "Nothing more to pick up. Click sets the arrow to the entrance.",
    ["Зелёная строка: брать больше нечего. Золотая: ниже написано, что и где осталось."] = "Green line: nothing more to pick up. Gold: below is what is left and where.",
    ["Сначала сюда, затем: "] = "Here first, then: ",
    [". Щелчок открывает карту."] = ". Click opens the map.",
    ["Сдано заданий: %d из %d"] = "Quests turned in: %d of %d",
    ["В каталоге нет заданий для этого персонажа"] = "No quests in the catalogue for this character",
    [" • Закрыто"] = " • Closed",
    [" • Скрыто"] = " • Hidden",
    ["\nПКМ — вернуть в работу"] = "\nRight-click — back to active",
    ["\nПКМ — скрыть. Чтобы вернуть, выбери «Показать все»."] = "\nRight-click — hide. To bring it back, choose \"Show all\".",
    ["Нажми, чтобы отметить вход на карте и включить стрелку."] = "Click to mark the entrance on the map and turn on the arrow.",
    ["Щелчок — следующий шаг, когда дошёл до перехода. ПКМ — маленький план."] = "Click — next step once you reach the passage. Right-click — small floor plan.",
    ["Щелчок — маленький план рядом с трекером. ПКМ — показать его снова."] = "Click — small floor plan next to the tracker. Right-click — show it again.",
    ["Советы"] = "Tips",
    ["Секреты, ключи и редкие боссы этого подземелья. Нажми, чтобы раскрыть или свернуть."] = "Secrets, keys and rare bosses of this dungeon. Click to expand or collapse.",
    ["Нажми на строку, чтобы увидеть следующий шаг."] = "Click the line to see the next step.",
    ["Как найти:"] = "How to find:",
    ["\nЗаданием может поделиться участник группы."] = "\nA party member can share this quest.",
    ["\n\nЦепочка заданий (шаг "] = "\n\nQuest chain (step ",
    ["\nЩелчок — раскрыть или свернуть. Правая кнопка — журнал этого задания."] = "\nClick — expand or collapse. Right-click — this quest in the journal.",
    ["\nНажми, чтобы показать место на карте."] = "\nClick to show the place on the map.",
    ["Дальше"] = "Next",
    ["Предыдущая страница"] = "Previous page",
    ["Список"] = "List",
    ["Книга заданий"] = "Quest book",
    ["К списку подземелий"] = "Back to dungeon list",
    ["Босс |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-3|t"] = "Boss |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-3|t",
    ["Выбрать босса"] = "Choose a boss",
    ["Трекер покажет путь к нему по шагам. «Вернуться к квестам» — в этом же меню."] = "The tracker will show the way to it step by step. \"Back to quests\" is in this same menu.",
    ["Вернуться к квестам"] = "Back to quests",
    [" (убит)"] = " (dead)",
    ["обновление "] = "updated to ",
    [", что нового:"] = ", what's new:",
    ["• внутри подземелья: как дойти до каждого босса"] = "• inside a dungeon: how to walk to every boss",
    ["• в журнале: награда за каждое задание"] = "• in the journal: the reward of every quest",
    ["• в новом заходе убитые боссы сбрасываются сами"] = "• a new run of a dungeon clears the killed bosses by itself",
    [" | место первой: "] = " | first location: ",
    ["Дальше пешком. Стрелка ведёт к цели: "] = "On foot from here. The arrow leads to the goal: ",
    ["Дорога к цели"] = "Route to goal",
    ["Кратчайший путь к выбранной цели начинается с телепорта."] = "The shortest route to the chosen goal starts with a teleport.",
    ["Сначала сюда, потом к цели. Щелчок по строке ниже открывает карту этого места."] = "Here first, then to the goal. Click a line below to open the map of this place.",
    ["Точка полёта у цели: "] = "Flight point by the goal: ",
    ["Точка полёта по пути: "] = "Flight point on the way: ",
    ["открой у распорядителя полётов"] = "discover it at the flight master",
    ["Первый живой босс по порядку подземелья. Другого можно выбрать кнопкой «Босс» в заголовке."] = "The first living boss in dungeon order. Choose another with the \"Boss\" button in the header.",
    ["Локация"] = "Location",
    ["Зал, в котором ты стоишь. Положение внутри подземелья игра не сообщает, только название зала."] = "The room you are standing in. The game does not report position inside a dungeon, only the room name.",
    ["ты здесь: «"] = "you are here: «",
    ["|cffffd34dлучшее в слот: "] = "|cffffd34dbest in slot: ",
    ["|cff40e040лучше надетого: "] = "|cff40e040better than equipped: ",
    ["|cff40e040добыча для тебя: "] = "|cff40e040loot for you: ",
    ["Что сделать у босса"] = "What to do at the boss",
    ["То, что из твоих заданий делается рядом с этим боссом. Пройдёшь мимо — придётся возвращаться."] = "Parts of your quests done near this boss. Walk past and you will have to come back.",
    ["Задания"] = "Quests",
    ["Задания этого похода: что ещё надо взять внутри, что в журнале, что готово к сдаче. Щелчок по заголовку сворачивает список."] = "The quests of this run: what is still to take inside, what is in the log, what is ready to hand in. Click the heading to fold the list.",
    [": цепочки сделаны. Попроси группу поделиться: "] = ": chains done. Ask the group to share: ",
    ["доделать"] = "finish",
    ["в журнале: "] = "in the log: ",
    [" — делаются внутри"] = ", done inside",
    ["снаружи брать нечего"] = "nothing to pick up outside",
    ["Можно идти в подземелье"] = "You can go into the dungeon",
    ["Все задания взяты — можно идти в подземелье"] = "All quests taken: you can go into the dungeon",
    ["Брать нечего — можно идти в подземелье"] = "Nothing to take: you can go into the dungeon",
    ["по дороге: "] = "on the way: ",
    ["попроси группу: "] = "ask the group: ",
    ["Ты уже был внутри"] = "You have been inside already",
    ["Поговори: "] = "Talk to: ",
    ["Это делается снаружи, разговором: %s. Сделай на выходе."] = "This is done outside, by talking: %s. Do it on the way out.",
    ["там осталось: "] = "left there: ",
    ["Сделать до входа"] = "Do before going in",
    ["Взятые задания, которые делаются снаружи: доделать или сдать до входа в подземелье. Щелчок по заданию раскрывает его и ставит стрелку. Щелчок по заголовку сворачивает список."] = "Taken quests done out here: finish or hand them in before you go in. Click a quest to unfold it and set the arrow. Click the heading to fold the list.",
    ["Цепочки"] = "Chains",
    ["Задания цепочек: какой шаг взять сейчас, у кого и где. Щелчок ставит стрелку. Щелчок по заголовку сворачивает список."] = "Quest chains: which step to take now, from whom and where. Click sets the arrow. Click the heading to fold the list.",
    ["Раздаст группа"] = "The group shares",
    ["Этими заданиями может поделиться участник группы — бежать не нужно. Под каждым — куда идти, если не поделятся. Щелчок по заголовку сворачивает список."] = "A group member can share these quests: no need to run. Under each: where to go if nobody shares. Click the heading to fold the list.",
    ["Взять самому"] = "Take yourself",
    ["Задания, которые надо взять самому: у кого, где и далеко ли. Сверху — дальние от подземелья, внизу — у самого входа. Щелчок по заголовку сворачивает список."] = "Quests to take yourself: from whom, where and how far. The far ones on top, those by the entrance at the bottom. Click the heading to fold the list.",
    ["Сделать у входа"] = "Do at the entrance",
    ["Взятые задания, которые делаются у самого подземелья: в пещере перед порталом или рядом со входом. Их делают по дороге внутрь, лучше группой. Щелчок по заданию раскрывает его и ставит стрелку."] = "Taken quests done right by the dungeon: in the cave before the portal or near the way in. Do them on the way in, best with your group. Click a quest to unfold it and set the arrow.",
    ["Взято, делается внутри"] = "Taken, done inside",
    ["Задания в журнале, которые выполняются внутри подземелья: снаружи с ними делать нечего. Щелчок по заголовку сворачивает список."] = "Quests in your log that are done inside the dungeon: nothing to do with them out here. Click the heading to fold the list.",
    ["Задания, которые здесь пока не взять: с какого уровня, что нужно сначала или что берётся внутри подземелья. Щелчок по заголовку сворачивает список."] = "Quests you cannot take out here yet: from which level, what comes first, or what is taken inside the dungeon. Click the heading to fold the list.",
    ["Сдай "] = "Hand in ",
    ["задание"] = "quest",
    ["задания"] = "quests",
    ["заданий"] = "quests",
    ["Кому: "] = "To: ",
    ["Где: "] = "Where: ",
    ["Путь к сдаче"] = "Way to hand in",
    ["Стрелка поведёт к тому, кому сдавать, самым быстрым путём."] = "The arrow leads to the one to hand it to, by the fastest way.",
    ["У входа: "] = "At the entrance: ",
    ["Возьми ещё "] = "Take ",
    ["Доделай снаружи: "] = "Finish outside: ",
    ["Начни с: "] = "Start with: ",
    ["Путь к первому"] = "Way to the first",
    ["Стрелка поведёт к первому делу самым быстрым путём: сначала дальние от подземелья, у входа — последними."] = "The arrow leads to the first errand by the fastest way: the far ones from the dungeon first, those at the entrance last.",
    ["Не для тебя:"] = "Not for you:",
    [": можно идти в подземелье."] = ": you can go into the dungeon.",
    [": все задания взяты — можно идти в подземелье. Кнопка пути — на панели."] = ": all quests taken, you can go into the dungeon. The way button is on the panel.",
    [" По дороге: "] = " On the way: ",
    [" Попроси группу: "] = " Ask the group: ",
    ["Открыть журнал: все задания и боссы"] = "Open journal: all quests and bosses",
    [" — задания для входа готовы. У группы: "] = " — entrance quests ready. Party: ",
    [" • Внутри: "] = " • Inside: ",
    ["лучшее в слот"] = "best in slot",
    ["лучше надетого"] = "better than worn",
    [": жми «Нужно»"] = ": press Need",
    ["»: осталось "] = "»: still need ",
    ["»: всё собрано"] = "»: all collected",
    ["Дальше по цепочке • "] = "Next in chain • ",
    ["Новый заход: отметки убитых боссов сброшены."] = "New run: dead boss marks reset.",
    ["Размер панели сейчас "] = "Panel size is now ",
    [". Набери, например, /dq size 1.3 (от 0.8 до 2)."] = ". Type, for example, /dq size 1.3 (from 0.8 to 2).",
    ["Размер панели: "] = "Panel size: ",
    ["Сигнал при входе в зал выключен."] = "Room entry alert is off.",
    ["При входе в новый зал подземелья: звук и строка по центру экрана, куда дальше."] = "On entering a new dungeon room: a sound and a line in the centre of the screen saying where to go next.",
    ["У панели снова тёмный фон."] = "The panel has a dark background again.",
    ["Фон панели убран: как у списка заданий игры."] = "Panel background removed: like the game's quest list.",
    ["Подсветка предметов и объектов выключена, настройки игры возвращены как были."] = "Object highlighting is off; the game's settings are back as they were.",
    ["Над предметами и объектами рядом, нужными для заданий из журнала, игра покажет значок, и прозвучит сигнал. Над стульями и прочим значка не будет."] = "The game shows an icon, with a sound, over objects near you that a quest in your log needs. Chairs and the like get no icon.",
    ["Этот клиент не умеет подсвечивать объекты."] = "This client cannot highlight objects.",
    ["Группе и рейду об аддоне больше не рассказываю."] = "I no longer tell the group or the raid about the addon.",
    ["После первого босса расскажу группе или рейду об аддоне одной строкой — если там есть кто-то без него, и не чаще раза в два часа."] = "After the first boss I will tell the group or the raid about the addon in one line, if someone there has none, and not more than once in two hours.",
    ["Стрелка снова показывает на цель напрямую."] = "The arrow points straight at the goal again.",
    ["Стрелка ведёт по проходимым дорогам, в обход гор и обрывов."] = "The arrow leads along walkable paths, around mountains and cliffs.",
    ["Кнопка у миникарты спрятана. /dq minimap вернёт её."] = "The minimap button is hidden. /dq minimap brings it back.",
    ["Кнопка у миникарты снова на месте."] = "The minimap button is back.",
    ["Задания больше не принимаются и не сдаются сами. /dq auto вернёт."] = "Quests are no longer accepted and turned in automatically. /dq auto turns it back on.",
    ["Задания принимаются и сдаются сами. Серые и повторяемые остаются тебе, выбор награды тоже; с зажатым Shift — всё вручную."] = "Quests are accepted and turned in automatically. Grey and repeatable ones are left to you, and so is the reward choice; hold Shift to do everything by hand.",
    ["Панель снова карточками, крупнее."] = "Panel uses cards again, larger.",
    ["Панель в виде заданий игры: её шрифты, круглые значки, строки с тире."] = "Panel styled like the game's quests: its fonts, round icons, lines with dashes.",
    ["Панель отпущена: её можно тащить за заголовок. /dq dock вернёт её в колонку заданий."] = "Panel unlocked: drag it by the header. /dq dock puts it back in the quest column.",
    ["Панель снова в колонке заданий, под «Все задания»."] = "Panel is back in the quest column, under \"All Objectives\".",
    ["Встроить панель в колонку заданий здесь не вышло: она стоит отдельно."] = "Could not embed the panel in the quest column here: it stands separately.",
    ["Панель возвращена на место рядом со списком заданий."] = "Panel returned to its place next to the quest list.",
    ["Столбец задач больше не сдвигается и возвращён на место. Из-под панелей уходит только список этого аддона."] = "The objective column no longer moves and is back in place. Only this addon's list moves out from under the bars.",
    ["Весь столбец задач сдвигается из-под панелей способностей."] = "The whole objective column moves out from under the action bars.",
    ["Полоски имён рядом с целью больше не включаются. Метка над головой видна, только если полоски включены тобой."] = "Nameplates near the goal no longer turn on. The mark above the head shows only if you turned nameplates on yourself.",
    ["Рядом с целью полоски имён включаются сами, над нужным персонажем встаёт метка."] = "Near the goal, nameplates turn on automatically and a mark appears above the right character.",
    ["Сначала выбери подземелье в /dq."] = "Choose a dungeon in /dq first.",
    ["Босса выбирают внутри подземелья. Зайди и набери /dq boss."] = "Bosses are chosen inside the dungeon. Go in and type /dq boss.",
    ["Для этого подземелья в атласе нет боссов."] = "The atlas has no bosses for this dungeon.",
    ["Выбери подземелье в /dq."] = "Choose a dungeon in /dq.",
    ["Доступных целей с известным маршрутом сейчас нет."] = "No available goals with a known route right now.",
    ["Вышла новая версия Dungeon Quest Forever: "] = "A new version of Dungeon Quest Forever is out: ",
    [" (у тебя "] = " (yours is ",
    ["). Обнови её через приложение CurseForge или Wago, или скачай с их страниц."] = "). Update it with the CurseForge or Wago app, or download it from their pages.",
    ["Ты не в группе: делиться не с кем. Вступи в группу — тогда кнопка поделится твоими заданиями и попросит недостающие."] = "You are not in a group: no one to share with. Join a group, and the button shares your quests and asks for the missing ones.",
    ["Поделился с группой: "] = "Shared with the group: ",
    [", попросил у группы: "] = ", asked of the group: ",
    ["Доступно"] = "Available",
    ["В процессе"] = "In progress",
    ["Можно сдать"] = "Ready to turn in",
    ["Выполнено"] = "Completed",
    ["Недоступно"] = "Unavailable",
    ["топор"] = "axe",
    ["двуручный топор"] = "two-handed axe",
    ["лук"] = "bow",
    ["ружьё"] = "gun",
    ["булава"] = "mace",
    ["двуручная булава"] = "two-handed mace",
    ["древковое"] = "polearm",
    ["меч"] = "sword",
    ["двуручный меч"] = "two-handed sword",
    ["посох"] = "staff",
    ["кистевое"] = "fist weapon",
    ["кинжал"] = "dagger",
    ["метательное"] = "thrown",
    ["арбалет"] = "crossbow",
    ["жезл"] = "wand",
    ["украшение"] = "miscellaneous",
    ["ткань"] = "cloth",
    ["кожа"] = "leather",
    ["кольчуга"] = "mail",
    ["латы"] = "plate",
    ["щит"] = "shield",
    ["сила закл."] = "spell power",
    ["исцеление"] = "healing",
    ["инт"] = "int",
    ["вын"] = "sta",
    ["дух"] = "spirit",
    ["сила"] = "str",
    ["ловк"] = "agi",
    ["мана за 5 с"] = "mp5",
    ["сила атаки"] = "attack power",
    ["сила атаки дальн."] = "ranged attack power",
    ["крит"] = "crit",
    ["крит закл."] = "spell crit",
    ["меткость"] = "hit",
    ["меткость закл."] = "spell hit",
    ["урон в сек."] = "dps",
    ["броня"] = "armor",
    ["голова"] = "head",
    ["шея"] = "neck",
    ["плечи"] = "shoulder",
    ["грудь"] = "chest",
    ["пояс"] = "waist",
    ["ноги"] = "legs",
    ["ступни"] = "feet",
    ["запястья"] = "wrist",
    ["кисти"] = "hands",
    ["палец"] = "finger",
    ["аксессуар"] = "trinket",
    ["спина"] = "back",
    ["одна рука"] = "one-hand",
    ["правая рука"] = "main hand",
    ["две руки"] = "two-hand",
    ["левая рука"] = "off hand",
    ["дальний бой"] = "ranged",
    ["золотой"] = "gold",
    ["золотых"] = "gold",
    ["серебра"] = "silver",
    ["меди"] = "copper",
    ["Боссы • в этом заходе убито "] = "Bosses • killed this run: ",
    ["Боссы • убивал "] = "Bosses • killed before: ",
    ["мал уровень"] = "level too low",
    [": сначала «"] = ": first «",
    [": не выполнен предыдущий шаг"] = ": previous step not done",
    ["Что делать"] = "What to do",
    ["Твой прогресс: "] = "Your progress: ",
    ["В базе нет описания.|r"] = "No description in the database.|r",
    ["Где"] = "Where",
    ["Начало: "] = "Start: ",
    ["внутри подземелья"] = "inside the dungeon",
    ["Цепочка • шаг "] = "Chain • step ",
    [" — сдано"] = " — turned in",
    [" — можно сдать"] = " — ready to turn in",
    [" — можно взять"] = " — can pick up",
    ["Награда"] = "Reward",
    ["Уровень: "] = "Level: ",
    ["Требуется уровень "] = "Requires level ",
    ["Как найти|r"] = "How to find|r",
    ["Пути к этому боссу в аддоне нет: игра не сообщает положение внутри подземелья.|r"] = "The addon has no path to this boss: the game does not report your position inside a dungeon.|r",
    ["лучшее в слот: "] = "best in slot: ",
    ["лучше надетого: "] = "better than equipped: ",
    ["тебе подходит: "] = "fits you: ",
    ["Правая кнопка по боссу в списке отмечает его убитым или возвращает.|r"] = "Right-click a boss in the list to mark it dead or bring it back.|r",
    ["По желанию"] = "Optional",
    ["Убит в этом заходе"] = "Dead this run",
    ["Убивал раньше"] = "Killed before",
    ["Ещё не убивал"] = "Not killed yet",
    ["Подземелья"] = "Dungeons",
    ["Уровень персонажа: "] = "Character level: ",
    ["  •  ПКМ — отметить пройденным"] = "  •  right-click: mark done",
    ["Уровень: %d–%d    Выполнено: %d/%d"] = "Level: %d–%d    Completed: %d/%d",
    ["Показать пройденные"] = "Show done",
    ["Скрыть пройденные"] = "Hide done",
    [" — убит|r"] = " — dead|r",
    [" — убивал|r"] = " — killed before|r",
    [" — следующий|r"] = " — next|r",
    [" |cff999999• по желанию|r"] = " |cff999999• optional|r",
    [" |cff999999• убивал раньше|r"] = " |cff999999• killed before|r",
    ["Уровень %d–%d  •  выполнено %d/%d"] = "Level %d–%d  •  completed %d/%d",
    ["  •  отмечено пройденным"] = "  •  marked done",
    ["|cff40e040тебе: "] = "|cff40e040for you: ",
    ["колесо мыши листает список"] = "mouse wheel scrolls the list",
    ["конец списка"] = "end of list",
    ["Выбери подземелье"] = "Choose a dungeon",
    ["Щёлкни по подземелью слева: откроются его задания и боссы."] = "Click a dungeon on the left to open its quests and bosses.",
    ["Щёлкни по заданию или боссу слева.\n\nЗадание с цепочкой раскрывается по шагам."] = "Click a quest or boss on the left.\n\nA quest with a chain expands step by step.",
    ["|cff8a8a8aне для твоего класса|r"] = "|cff8a8a8anot for your class|r",
    ["|cff40e040тебе|r\n|cff8a8a8aещё не оценено|r"] = "|cff40e040for you|r\n|cff8a8a8anot rated yet|r",
    ["|cff9a9a9aуже надето|r"] = "|cff9a9a9aalready equipped|r",
    ["|cffffd34dЛУЧШЕЕ В СЛОТ|r\n|cff40e040+"] = "|cffffd34dBEST IN SLOT|r\n|cff40e040+",
    [" к надетому|r"] = " vs equipped|r",
    ["\n|cffffa64dс уровня "] = "\n|cffffa64dfrom level ",
    ["|cff9a9a9aне лучше надетого|r"] = "|cff9a9a9anot better than equipped|r",
    ["вещей "] = "items: ",
    [", колесо мыши листает"] = ", mouse wheel scrolls",
    ["оценено "] = "rated ",
    [" вещей для твоего класса"] = " items for your class",
    ["наведи мышь на вещь: её описание; оценка — сила закл. целиком, инт на треть"] = "hover over an item for its description; score — spell power in full, int at a third",
    ["наведи мышь на вещь: её описание"] = "hover over an item for its description",
    ["На выбор:"] = "Choose one:",
    ["Вы получите:"] = "You will receive:",
    ["Dungeon Quest Forever — книга заданий"] = "Dungeon Quest Forever — quest journal",
    ["Щелчок — задания этого подземелья."] = "Click: the quests of this dungeon.",
    ["ПКМ — вернуть в работу."] = "Right-click: back into the list.",
    ["ПКМ — отметить пройденным, если больше туда не пойдёшь: оно уйдёт из списка. Кнопка «Показать пройденные» вернёт его."] = "Right-click: mark it done if you won't go there again; it leaves the list. The button 'Show done' brings it back.",
    ["Показать путь"] = "Show path",
    [" к надетому"] = " over equipped",
    ["не для мага"] = "not for a mage",
    ["не для жреца"] = "not for a priest",
    ["не для чернокнижника"] = "not for a warlock",
    ["не для воина"] = "not for a warrior",
    ["не для разбойника"] = "not for a rogue",
    ["не для охотника"] = "not for a hunter",
    ["не для друида"] = "not for a druid",
    ["не для шамана"] = "not for a shaman",
    ["не для паладина"] = "not for a paladin",
    ["добыча босса"] = "boss loot",
    ["добычи в базе нет"] = "no loot in the data",
    ["не для твоего класса"] = "not for your class",
    ["лучше надетого +%d"] = "better than equipped +%d",
    ["надето"] = "equipped",
    ["Голова"] = "Head",
    ["Шея"] = "Neck",
    ["Плечи"] = "Shoulder",
    ["Спина"] = "Back",
    ["Грудь"] = "Chest",
    ["Запястья"] = "Wrist",
    ["Кисти рук"] = "Hands",
    ["Пояс"] = "Waist",
    ["Ноги"] = "Legs",
    ["Ступни"] = "Feet",
    ["Кольцо"] = "Finger",
    ["Аксессуар"] = "Trinket",
    ["Правая рука"] = "Main Hand",
    ["Левая рука"] = "Off Hand",
    ["Дальний бой"] = "Ranged",
    ["Жезл"] = "Wand",
    ["Реликвия"] = "Relic",
    ["Тайная магия"] = "Arcane",
    ["Огонь"] = "Fire",
    ["Лёд"] = "Frost",
    ["Послушание"] = "Discipline",
    ["Свет"] = "Holy",
    ["Тьма"] = "Shadow",
    ["Колдовство"] = "Affliction",
    ["Демонология"] = "Demonology",
    ["Разрушение"] = "Destruction",
    ["Баланс"] = "Balance",
    ["Сила зверя"] = "Feral Combat",
    ["Исцеление"] = "Restoration",
    ["Чувство зверя"] = "Beast Mastery",
    ["Стрельба"] = "Marksmanship",
    ["Выживание"] = "Survival",
    ["Защита"] = "Protection",
    ["Возмездие"] = "Retribution",
    ["Ликвидация"] = "Assassination",
    ["Бой"] = "Combat",
    ["Скрытность"] = "Subtlety",
    ["Стихии"] = "Elemental",
    ["Совершенствование"] = "Enhancement",
    ["Оружие"] = "Arms",
    ["Неистовство"] = "Fury",
    ["Кузнечное дело"] = "Blacksmithing",
    ["Наложение чар"] = "Enchanting",
    ["Кожевничество"] = "Leatherworking",
    ["Портняжное дело"] = "Tailoring",
    ["Подземелье «%s», босс: %s"] = "Dungeon: %s, boss: %s",
    ["Задание «%s»"] = "Quest: %s",
    ["ремесло • "] = "crafted • ",
    ["Делается ремеслом: "] = "Crafted with ",
    ["торговец • "] = "vendor • ",
    ["Продаёт %s, %s"] = "Sold by %s, %s",
    ["Падает с «%s», %s"] = "Drops from %s, %s",
    ["Shift+щелчок — ссылка в чат, Ctrl+щелчок — примерить."] = "Shift-click to link in chat, Ctrl-click to try it on.",
    ["Для этой ветки на этом уровне нет вещи заметно лучше обычной."] = "Nothing clearly better for this tree at this level.",
    ["Лучшие вещи"] = "Best Gear",
    ["Уровень:"] = "Level:",
    ["Ветка:"] = "Spec:",
    ["Ты в этих вещах"] = "You in this gear",
    ["Потяни мышью, чтобы повернуть."] = "Drag to turn.",
    ["нужен %d уровень"] = "requires level %d",
}
-- LOCALE END
local russianClient = (GetLocale and GetLocale() or "enUS") == "ruRU"
P.LMissing = {}
local function L(s)
    if russianClient then return s end
    local said = EN[s]
    if said == nil then P.LMissing[s] = true return s end
    return said
end
P.L = L
-- A Russian line in English, whatever the client (for the lines said to a group).
function P.InEnglish(s) return EN[s] or s end
function P.Language(code)
    -- For the tests: say the words as another client would.
    russianClient = code == "ruRU"
end

-- The addon's own ground: dungeons, quests, places, the arrow and the point on the map.
-- The owner: "how do we get rid of the dependency on Questie?" The part of the quest
-- database the addon reads is its own now: Data.lua, made from QuestieDB (GPLv3) by
-- dungeon-quest-handoff/make-data.lua, with names in Russian and in English. It is read
-- through four small stores with the same Get(id, field) as QuestieDB's tables, so the
-- rest of the addon asks as it did; nothing of another addon is needed.
local C = {}
P.Core = C

local D = P.Data or {}
-- The Horde's "Krol'dok Moulding" (94973) has no start in the database; the Alliance's
-- (94980) starts from the mould Tunk drops inside Krol'dok, and so does the Horde's.
do
    local q = D.quests and D.quests[94973]
    if q and not (q.startedBy and q.startedBy[3]) then q.startedBy = {[3]={267138}} end
end
local englishData = (GetLocale and GetLocale() or "enUS") ~= "ruRU"
-- A field that reads differently in the two languages is kept as {__ru=..., __en=...}.
local function pick(value)
    if type(value) == "table" and (value.__ru ~= nil or value.__en ~= nil) then
        if englishData then
            if value.__en ~= nil then return value.__en end
            return value.__ru
        end
        if value.__ru ~= nil then return value.__ru end
        return value.__en
    end
    return value
end
local function store(kind)
    local all = D[kind] or {}
    -- The other language is let go at once (the owner: "make it lighter"): each field read
    -- in two languages becomes the one the game speaks.
    for _, entry in pairs(all) do
        -- The English name is kept beside it: the lines said to the group are in English.
        local name = entry.name
        if type(name) == "table" and name.__en ~= nil then entry.nameEn = name.__en end
        for field, value in pairs(entry) do
            if type(value) == "table" and (value.__ru ~= nil or value.__en ~= nil) then entry[field] = pick(value) end
        end
    end
    local s = {}
    function s.Get(id, field)
        local entry = all[id]
        if entry == nil then return nil end
        return pick(entry[field])
    end
    -- The name in English (for a line to a group of every tongue).
    function s.GetEn(id)
        local entry = all[id]
        return entry and (entry.nameEn or entry.name) or nil
    end
    function s.GetAllIds()
        local ids = {}
        for id in pairs(all) do ids[#ids+1] = id end
        table.sort(ids)
        return ids
    end
    return s
end
local QuestDB, NpcDB, ObjectDB, ItemDB = store("quests"), store("npcs"), store("objects"), store("items")
P.QuestDB, P.NpcDB, P.ObjectDB, P.ItemDB = QuestDB, NpcDB, ObjectDB, ItemDB
-- Every other quest of the database, for telling junk in the quest log: its level times
-- ten plus 0 when it stands alone, 1 when it is a link of a chain, 3 when it is of a
-- class or a craft.
P.JunkData = D.junk or {}
P.ObjectUses = D.uses or {}

C.L = {NO_GUIDANCE = L"Другой континент"}
C.Quests = {}       -- no hand-kept quest table: every field is asked from QuestieDB
C.Dungeons, C.DungeonByKey = {}, {}
C.db = {arrow = {}}

-- The five-player dungeons, by their area id in the quest database. A key names a
-- dungeon for the tips; several wings behind one instance are one dungeon here.
local keys = {
    [2437]="RFC", [718]="WC", [1581]="DM", [209]="SFK", [719]="BFD", [717]="STOCKS", [721]="GNOMER",
    [491]="RFK", [796]="SM", [722]="RFD", [1337]="ULDA", [1176]="ZF", [2100]="MARA", [1477]="ST",
    [1584]="BRD", [1583]="BRS", [2557]="DMAUL", [2057]="SCHOLO", [2017]="STRAT",
    [16544]="DALARAN", [16611]="LORDAERON", [16732]="EXCAVATION", [16919]="THANES",
}
local factions = {[2437]="Horde", [717]="Alliance"}
-- Forever's dungeons the quest database does not know yet (they opened on 4.11.2026; the
-- owner, 15.11.2026: "check every instance of Forever, what is missing"). The way in is
-- the one the guides agree on (Warcraft Tavern, Conquest Capped, WoW Forever Guides,
-- 15.11.2026), the levels Blizzard's. No quests and no bosses until the database has them;
-- inside, the dungeon is known by its name, as its instance number is not known.
local EXTRA = {
    {key="DROWNED", en="The Drowned City", ru=L"Затонувший город", also={L"Затопленный город"}, map=1434, x=21.4, y=27.9, min=35, max=40, hint=L"вход под водой, к западу от Гром'гола",
        quests={95748, 95776, 95789, 95791, 96774, 97130}},
    {key="KROLDOK", en="Krol'dok Stronghold", ru=L"Крепость Крол'док", area=17780, map=2548, x=37.5, y=37.5, min=40, max=45, hint=L"пещера у камня встреч",
        quests={94968, 94969, 94973, 94980, 94982, 94983}},
    -- (Alcaz Prison and Shaper's Terrace: their quests are not in QuestieDB yet; they were read
    -- off Wowhead Forever on 16.11.2026 into Data.lua, P.ForeverQuests.)
    {key="ALCAZ", en="Alcaz Prison", ru=L"Тюрьма Альказа", area=16620, map=1445, x=75.3, y=14.1, min=48, max=53, hint=L"в подвале старой башни на острове",
        quests=P.ForeverQuests and P.ForeverQuests.ALCAZ},
    -- (The tunnel opens in Azshara; the portal itself lies so deep that it is on the map of
    -- Winterspring, 66.6, 84.4: Warcraft Tavern.)
    {key="BLACKMAW", en="Blackmaw Hold", ru=L"Цитадель Чернопасти", area=1216, map=1447, x=38.7, y=33.4, min=55, max=60, hint=L"туннель фурболгов, портал в глубине",
        quests={92065, 96603, 97173, 98477}},
    {key="SHAPERS", en="Shaper's Terrace", ru=L"Терраса ваятеля", area=16985, map=1449, x=48.1, y=6.1, min=58, max=60, hint=L"вверх по лестнице от Укрытия Маршала",
        quests=P.ForeverQuests and P.ForeverQuests.SHAPERS},
}
local tipKeys = {
    SM={"SM_GY", "SM_LIB", "SM_ARM", "SM_CATH"}, BRS={"LBRS", "UBRS"},
    DMAUL={"DM_E", "DM_N", "DM_W"}, STRAT={"STRAT_LIVE", "STRAT_UD"},
}

local areaToMap, areaOwner = {}, {}
local floor, sqrt = math.floor, math.sqrt
local atan2 = math.atan2 or math.atan

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end
C.PlainText = plain

-- ------------------------------------------
-- Dungeons and their quests
-- ------------------------------------------
local function readTable(source)
    if type(source) == "table" then return source end
    if type(source) ~= "string" then return {} end
    local chunk = (loadstring or load)(source)
    local ok, result = pcall(chunk)
    return ok and type(result) == "table" and result or {}
end

function C.Init(db)
    C.char = db
    db.markers = db.markers or {}
    -- A point left over from an earlier sitting is not an errand any more: with it would
    -- hang its arrow and its teleport button.
    -- "Earlier" is counted from when the game was left, so a /reload in the middle of a
    -- long way keeps the way. Without that stamp, from when the point was set.
    local now = GetServerTime and GetServerTime() or 0
    local left = db.left
    db.left = nil
    local function stale(at)
        if left then return now - left > 1800 end
        return not at or now - at > 1800
    end
    for i = #db.markers, 1, -1 do
        if stale(db.markers[i].at) then table.remove(db.markers, i)
        elseif C.Localize then
            -- (A point kept on the continent's map from before 3.48.9: on its zone's map.)
            local m = db.markers[i]
            local placed = C.Localize(m)
            if placed ~= m then m.mapID, m.x, m.y = placed.mapID, placed.x, placed.y end
        end
    end
    db.pending = nil
    if db.goal and (stale(db.goal.at) or #db.markers == 0) then db.goal = nil end
    if not C.leaving and CreateFrame and UIParent then
        C.leaving = CreateFrame("Frame", nil, UIParent)
        pcall(C.leaving.RegisterEvent, C.leaving, "PLAYER_LOGOUT")
        C.leaving:SetScript("OnEvent", function()
            if not C.char then return end
            C.char.left = GetServerTime and GetServerTime() or nil
            if C.Friendly then C.Friendly(false) end
        end)
        -- Where the portal really is. The database knows the mouth of the cave; the portal
        -- can be deep inside it. The last place the player stood before the loading screen
        -- into a dungeon is its portal: it is remembered and the arrow leads there after.
        local stood, waited, wasInside, insideKey = nil, 0, nil, nil
        C.leaving:SetScript("OnUpdate", function(_, elapsed)
            waited = waited + (elapsed or 0)
            if waited < 1 then return end
            waited = 0
            pcall(function()
                local inside = IsInInstance and IsInInstance() and true or false
                if not inside then
                    local here = C_Map and C_Map.GetBestMapForUnit and plain(C_Map.GetBestMapForUnit("player"))
                    local continent = here and C.ContinentOf(here)
                    local pos = continent and C_Map.GetPlayerMapPosition(continent, "player")
                    if pos then
                        local x, y = pos:GetXY()
                        x, y = plain(x), plain(y)
                        if x and y and not (x == 0 and y == 0) then stood = {mapID=continent, x=x*100, y=y*100} end
                    end
                    -- Just out of a dungeon: the way now leads out, not in.
                    -- A ghost is not out of the dungeon: it is on its way back in.
                    if wasInside and insideKey and C.char and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
                        C.char.cameOut = {key=insideKey, at=GetServerTime and GetServerTime() or 0}
                    end
                elseif wasInside == false and stood and C.char then
                    local d = C.CurrentDungeon()
                    local span = d and d.entrance and C.Span(stood, d.entrance)
                    -- Summoned or teleported in from afar: that is not where the portal is.
                    if span and span < 600 then
                        C.char.portals = C.char.portals or {}
                        C.char.portals[d.key] = stood
                    end
                end
                if inside then
                    local d = C.CurrentDungeon()
                    insideKey = d and d.key or insideKey
                    if C.char then C.char.cameOut = nil end
                end
                wasInside = inside
            end)
        end)
    end
    db.arrow = db.arrow or {}
    C.db.arrow = db.arrow
    -- Name bars switched on in a sitting that ended beside the one sought are put back.
    if db.plates and C.Friendly then C.Friendly(false) end
    -- A point kept through a /reload comes back with its arrow; a dropped one takes it away.
    if #db.markers > 0 or (C.Arrow and C.Arrow()) then C.OnMarkersChanged() end
    if C.ready then return true end
    if not (D.dungeons and D.maps) then return false end
    for area, map in pairs(D.maps) do areaToMap[area] = map end
    -- The database leaves out the parts of Dire Maul (its own numbers for the wings): the
    -- folk who stand in there were taken for folk of nowhere, and the arrow had "no exact
    -- place" for Knot Thimblejack (found in the run over every quest, 17.11.2026).
    local WINGS = {[2557] = {10022, 10023, 10024, 10025, 10026, 10027}}
    local instanceOf = {}
    -- Later remakes reuse an area under a higher instance id; the classic one is the lowest.
    for instance, area in pairs(D.instances or {}) do
        if not instanceOf[area] or instance < instanceOf[area] then instanceOf[area] = instance end
    end
    for area, key in pairs(keys) do
        local entry = D.dungeons[area]
        if entry then
            local d = {key=key, name=pick(entry[1]), nameEn=type(entry[1]) == "table" and entry[1].__en or entry[1], areaId=area, instanceID=instanceOf[area], faction=factions[area] or "Both",
                quests={}, tips=tipKeys[key], minLevel=0, maxLevel=0}
            areaOwner[area] = d
            for _, other in ipairs(entry[2] or {}) do areaOwner[other] = d end
            for _, other in ipairs(WINGS[area] or {}) do areaOwner[other] = d end
            local door = entry[4] and entry[4][1]
            local map = door and areaToMap[door[1]]
            if map and map > 0 then d.entrance = {mapID=map, x=door[2], y=door[3]} end
            C.Dungeons[#C.Dungeons+1] = d
            C.DungeonByKey[key] = d
        end
    end
    local russian = (GetLocale and GetLocale() or "enUS") == "ruRU"
    for _, e in ipairs(EXTRA) do
        if not C.DungeonByKey[e.key] then
            local d = {key=e.key, name=russian and e.ru or e.en, nameEn=e.en, also=e.also, areaId=e.area, faction="Both", quests={},
                minLevel=e.min, maxLevel=e.max, forever=true, entrance={mapID=e.map, x=e.x, y=e.y, hint=e.hint}}
            -- Its quests, found by their monsters and names in the database (15.11.2026).
            for _, id in ipairs(e.quests or {}) do
                if QuestDB.Get(id, "name") then d.quests[#d.quests+1] = id end
            end
            -- Its zone is its own: what stands or is done there is inside (Alcaz Prison's
            -- monsters and the quests begun in there, 16.11.2026).
            if e.area and not areaOwner[e.area] then areaOwner[e.area] = d end
            C.Dungeons[#C.Dungeons+1] = d
            C.DungeonByKey[e.key] = d
        end
    end
    -- A quest belongs to the dungeon its sort names. The level span of a dungeon is the
    -- span of its quests: the database has no other word on it.
    for _, id in ipairs(QuestDB.GetAllIds()) do
        local d = areaOwner[QuestDB.Get(id, "zoneOrSort")]
        -- A repeatable hand-in is not something to prepare for a run.
        if d and (QuestDB.Get(id, "specialFlags") or 0) % 2 == 1 then d = nil end
        -- (A quest of Forever's new dungeons is listed by them already.)
        if d and d.forever then
            for _, other in ipairs(d.quests) do if other == id then d = nil break end end
        end
        if d then
            d.quests[#d.quests+1] = id
            local level = QuestDB.Get(id, "questLevel") or 0
            if level > 0 then
                if d.minLevel == 0 or level < d.minLevel then d.minLevel = level end
                if level > d.maxLevel then d.maxLevel = level end
            end
        end
    end
    -- The last step of a dungeon's chain may be sorted under a city: carry a voucher there
    -- for the reward ("Платиновые диски" to Bena Winterhoof in Thunder Bluff). The owner had
    -- it in his log with no line and no road (17.11.2026). A step with nothing to do but
    -- to be handed in, next in the chain of a quest of the dungeon and under its very name,
    -- is of the dungeon too. (Under another name it is a story going on elsewhere: "Мудрость
    -- Эйтригга", "Огнебор" are not steps of a run.)
    local function nothingToDo(id)
        for _, list in pairs(QuestDB.Get(id, "objectives") or {}) do
            if type(list) == "table" and next(list) then return false end
        end
        return true
    end
    local function sameName(a, b)
        local x, y = QuestDB.GetEn(a), QuestDB.GetEn(b)
        return x ~= nil and x == y
    end
    for _, d in ipairs(C.Dungeons) do
        local have = {}
        for _, id in ipairs(d.quests) do have[id] = true end
        for i = 1, #d.quests do
            local after = QuestDB.Get(d.quests[i], "nextQuestInChain")
            if after and after > 0 and not have[after] and QuestDB.Get(after, "name")
                and not areaOwner[QuestDB.Get(after, "zoneOrSort")] and nothingToDo(after)
                and sameName(after, d.quests[i]) then
                for _, before in ipairs(QuestDB.Get(after, "preQuestSingle") or {}) do
                    if before == d.quests[i] then
                        have[after] = true
                        d.quests[#d.quests+1] = after
                        break
                    end
                end
            end
        end
    end
    table.sort(C.Dungeons, function(a, b) return a.key < b.key end)
    C.ready = true
    return true
end

function C.DungeonName(d)
    local name = d.instanceID and GetRealZoneText and plain(GetRealZoneText(d.instanceID))
    if not name or name == "" then
        name = d.areaId and C_Map and C_Map.GetAreaInfo and plain(C_Map.GetAreaInfo(d.areaId))
    end
    if not name or name == "" then name = d.name end
    return name
end

-- A place on the map of a continent, put on the map of the zone it lies in (nil-safe; the
-- place itself where that cannot be told).
function C.Localize(place)
    if not (place and place.mapID and place.x and place.y and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfoAtPosition) then return place end
    local info = C_Map.GetMapInfo(place.mapID)
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    if not (info and info.mapType == continentType) then return place end
    local ok, at = pcall(C_Map.GetMapInfoAtPosition, place.mapID, place.x / 100, place.y / 100)
    if not (ok and type(at) == "table" and at.mapID and at.mapID ~= place.mapID) then return place end
    local zone = at
    while zone and zone.mapType and zone.mapType > 3 and zone.parentMapID and zone.parentMapID ~= 0 do zone = C_Map.GetMapInfo(zone.parentMapID) end
    if not (zone and zone.mapID and zone.mapType == 3) then return place end
    local okR, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, zone.mapID, place.mapID)
    if not (okR and left and right and top and bottom and right ~= left and bottom ~= top) then return place end
    local x, y = (place.x / 100 - left) / (right - left), (place.y / 100 - top) / (bottom - top)
    if x < 0 or x > 1 or y < 0 or y > 1 then return place end
    local out = {}
    for k, v in pairs(place) do out[k] = v end
    out.mapID, out.x, out.y = zone.mapID, x * 100, y * 100
    return out
end

function C.Entrance(d)
    return d and d.entrance
end

function C.CurrentDungeon()
    local here, kind, _, _, _, _, _, instance = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    for _, d in ipairs(C.Dungeons) do
        if d.instanceID == instance then return d end
    end
    -- One of the new ones, whose number is not known: by its name, then by its number.
    -- (The Russian client calls it "Затонувший город"; the guides' translation was not it:
    -- the owner was inside and the addon did not know. A place not known is written down,
    -- C.char.unknownPlaces, to be read from the saved file.)
    here = plain(here)
    if type(here) ~= "string" or here == "" then return end
    for _, d in ipairs(C.Dungeons) do
        local known = here == d.name or here == d.nameEn or here == C.DungeonName(d)
        for _, other in ipairs(d.also or {}) do known = known or here == other end
        if d.forever and known then
            d.instanceID = d.instanceID or instance
            return d
        end
    end
    if C.char then
        C.char.unknownPlaces = type(C.char.unknownPlaces) == "table" and C.char.unknownPlaces or {}
        C.char.unknownPlaces[here] = instance
    end
end

function C.MatchesFaction() return true end   -- QuestieDB's race mask decides
function C.IsMyClass() return true end        -- and its class mask
function C.QuestText() return {} end

function C.QuestTitle(id)
    local live = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if live and live ~= "" then return live end
    return QuestDB and QuestDB.Get(id, "name") or ("#" .. id)
end

function C.ZoneName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or (mapID and ("#" .. mapID)) or "?"
end

function C.NpcIDFromGUID(guid)
    guid = plain(guid)
    if type(guid) ~= "string" then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- ------------------------------------------
-- Places: who gives a quest, who takes it, and where they stand
-- ------------------------------------------
local function spot(spawns)
    local areas = {}
    for area in pairs(spawns or {}) do areas[#areas+1] = area end
    table.sort(areas)
    local inside
    for _, area in ipairs(areas) do
        local first = spawns[area][1]
        if areaOwner[area] then
            inside = true
        elseif first and first[1] and first[1] >= 0 and areaToMap[area] and areaToMap[area] > 0 then
            return areaToMap[area], first[1], first[2]
        end
    end
    return nil, nil, nil, inside
end

local function source(kind, id)
    local db = kind == "npc" and NpcDB or ObjectDB
    if not (db and db.Get) then return end
    local name = db.Get(id, "name")
    if not name then return end
    local place = {name=name}
    place[kind == "npc" and "npcID" or "objectID"] = id
    local inside
    place.mapID, place.x, place.y, inside = spot(db.Get(id, "spawns"))
    place.inside = inside and not place.mapID or nil
    return place
end

C.Places = setmetatable({}, {__index=function(self, key)
    local kind, id = tostring(key):match("^(%a+):(%d+)$")
    local place = (kind == "npc" or kind == "object") and source(kind, tonumber(id)) or false
    rawset(self, key, place)
    return place
end})

function C.QuestPlaces(id, which)
    local by = QuestDB and QuestDB.Get(id, which == "starts" and "startedBy" or "finishedBy") or {}
    local list = {}
    for _, npc in ipairs(by[1] or {}) do
        local place = C.Places["npc:" .. npc]
        if place then list[#list+1] = place end
    end
    for _, object in ipairs(by[2] or {}) do
        local place = C.Places["object:" .. object]
        if place then list[#list+1] = place end
    end
    -- A quest begun by an item: the item drops where the quest belongs.
    for _, item in ipairs(by[3] or {}) do
        list[#list+1] = {itemID=item, name=ItemDB and ItemDB.Get(item, "name") or ("#" .. item),
            inside=areaOwner[QuestDB.Get(id, "zoneOrSort")] ~= nil or nil}
    end
    return list, true
end

function C.PlaceName(place)
    return place and place.name
end

-- Every known giver stands inside a dungeon (or the quest begins from a drop there).
-- Where a quest is handed in stands inside a dungeon: it is done in there, not outside.
function C.EndsInside(id)
    local list = C.QuestPlaces(id, "ends")
    if #list == 0 then return false end
    for _, place in ipairs(list) do
        if not place.inside then return false end
    end
    return true
end

-- A quest of the other faction that the database does not mark as such: every one who
-- gives it stands in a capital closed to this faction, or is no friend of it. "In Search
-- of Thaelrid" is given in Darnassus and carries no race mask; the owner, Horde, had
-- every quest of Blackfathom Deeps handed in and was still shown two left.
local closed = {
    Horde = {[1519]=true, [1537]=true, [1657]=true},       -- Stormwind, Ironforge, Darnassus
    Alliance = {[1637]=true, [1638]=true, [1497]=true},    -- Orgrimmar, Thunder Bluff, Undercity
}
function C.ForeignQuest(id, faction)
    local ok, foreign = pcall(function()
        local by = QuestDB.Get(id, "startedBy") or {}
        local npcs = by[1] or {}
        if #npcs == 0 or (by[2] and #by[2] > 0) or (by[3] and #by[3] > 0) then return false end
        local letter = faction == "Horde" and "H" or faction == "Alliance" and "A"
        if not letter then return false end
        for _, npc in ipairs(npcs) do
            local zone = NpcDB.Get(npc, "zoneID")
            local friendly = NpcDB.Get(npc, "friendlyToFaction")
            local shut = closed[faction][zone] == true
            local hostile = type(friendly) == "string" and friendly ~= "" and not friendly:find(letter, 1, true)
            if not shut and not hostile then return false end
        end
        return true
    end)
    return ok and foreign or false
end

function C.StartsInside(id)
    local list = C.QuestPlaces(id, "starts")
    if #list == 0 then return false end
    for _, place in ipairs(list) do
        if not place.inside then return false end
    end
    return true
end

-- What a quest in the log still asks for outside this dungeon: each goal not yet met
-- whose sources (the creature, the object, whatever drops the item) are nowhere inside
-- it. A goal met only in another dungeon leads to that dungeon's door. An empty list
-- means the quest is done inside, or the database cannot tell otherwise.
function C.QuestWork(id, d)
    local spots = {}
    local objectives = QuestDB and QuestDB.Get(id, "objectives")
    if type(objectives) ~= "table" then return spots end
    local live = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id) or {}
    -- The quest log names the item or the creature in the line of its goal.
    local function status(name)
        if not name then return false end
        for _, objective in ipairs(live) do
            local text = plain(objective.text)
            if type(text) == "string" and text:find(name, 1, true) then return objective.finished and true or false, text, tonumber(objective.numRequired) end
        end
        return false
    end
    -- Seen in the game: the owner stood among the Razorfen battleguards, the arrow led to
    -- the first spawn of the list, 1.4 km off over the cliff. Of the spawns outside the
    -- nearest to the player is taken (the first of the list where there is no position).
    local okMe, myC, myX, myY = pcall(C.PlayerYards)
    if not okMe then myC = nil end
    local function weigh(name, sources)
        local met, text, needed = status(name)
        if met then return end
        -- One creature to kill, or one thing that only one creature drops: his name, for the
        -- small sight that takes him as the target (the owner, 16.11.2026, looking for
        -- Ambassador Malcin by the Razorfen).
        local target
        if needed == 1 and #sources == 1 and sources[1].db == NpcDB then
            local who = NpcDB.Get(sources[1].id, "name")
            if type(who) == "string" and who ~= "" then target = who end
        end
        local here, other, outdoor, range
        local function consider(source, area, spot)
            if not (spot and type(spot[1]) == "number" and type(spot[2]) == "number" and spot[1] >= 0) then return end
            local map = areaToMap[area]
            if not (map and map > 0) then return end
            local candidate = {mapID=map, x=spot[1], y=spot[2]}
            -- A thing in the world, not a creature (the owner, 15.11.2026, at the Vile Reef:
            -- "I was looking for some NPC, not a tablet": the tablet is called "Gri'lek the
            -- Wanderer"). Its name is said as an object's.
            if not outdoor then
                local what = source.db.Get(source.id, "name")
                if source.db == ObjectDB and type(what) == "string" then what = (L"объект «%s»"):format(what) end
                outdoor, candidate.name = candidate, what
            end
            if not myC then return true end
            local okAt, c, X, Y = pcall(C.Yards, candidate)
            if not (okAt and c == myC and X and Y) then return end
            local gap = (X - myX)^2 + (Y - myY)^2
            if not range or gap < range then
                candidate.name = outdoor.name
                outdoor, range = candidate, gap
            end
        end
        for _, source in ipairs(sources) do
            local spawns = source.db.Get(source.id, "spawns") or {}
            local areas = {}
            for area in pairs(spawns) do areas[#areas+1] = area end
            table.sort(areas)
            for _, area in ipairs(areas) do
                local owner = areaOwner[area]
                if owner == d then
                    here = true
                elseif owner then
                    other = other or owner
                elseif type(spawns[area]) == "table" then
                    for i, spot in ipairs(spawns[area]) do
                        if i > 300 or consider(source, area, spot) then break end
                    end
                end
            end
        end
        if here then return end
        if other and other.entrance then
            spots[#spots+1] = {mapID=other.entrance.mapID, x=other.entrance.x, y=other.entrance.y, dungeon=other,
                name=L"Вход: " .. C.DungeonName(other), text=text or name}
        elseif outdoor then
            outdoor.text = text or name
            outdoor.target = target
            spots[#spots+1] = outdoor
        end
    end
    for _, creature in ipairs(objectives[1] or {}) do
        weigh(NpcDB and NpcDB.Get(creature[1], "name"), {{db=NpcDB, id=creature[1]}})
    end
    for _, object in ipairs(objectives[2] or {}) do
        weigh(ObjectDB and ObjectDB.Get(object[1], "name"), {{db=ObjectDB, id=object[1]}})
    end
    for _, item in ipairs(objectives[3] or {}) do
        local sources = {}
        for _, npc in ipairs(ItemDB and ItemDB.Get(item[1], "npcDrops") or {}) do sources[#sources+1] = {db=NpcDB, id=npc} end
        for _, object in ipairs(ItemDB and ItemDB.Get(item[1], "objectDrops") or {}) do sources[#sources+1] = {db=ObjectDB, id=object} end
        weigh(ItemDB and ItemDB.Get(item[1], "name"), sources)
    end
    -- Goals in a cave (P.QuestCave, BossRoute.lua): the way leads to its mouth first, and
    -- inside the arrow points straight: the walkable paths lie over the mountain above.
    local cave = P.QuestCave and P.QuestCave[id]
    if cave then for _, spot in ipairs(spots) do spot.cave = cave end end
    -- The goal nearest to the player first: "A Host of Evil" asks for battleguards (known
    -- only on the cliff above, 1.4 km round) and thornweavers and cultists 200 yards off.
    if myC and #spots > 1 then
        for i, spot in ipairs(spots) do
            local okAt, c, X, Y = pcall(C.Yards, spot)
            spot.order = i
            spot.gap = (okAt and c == myC and X and Y) and ((X - myX)^2 + (Y - myY)^2) or math.huge
        end
        table.sort(spots, function(a, b) if a.gap ~= b.gap then return a.gap < b.gap end return a.order < b.order end)
        for _, spot in ipairs(spots) do spot.gap, spot.order = nil, nil end
    end
    return spots
end

-- ------------------------------------------
-- The point and the arrow
-- ------------------------------------------
-- One point at a time. The arrow turns toward it and counts the distance on the map of
-- the continent, which the game gives outdoors; inside an instance and across the sea
-- there is no distance to give.
local CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local arrow, mapPin, hooked

-- The maps do not move: what they tell is kept (the arrow asked twenty times a second,
-- and each answer was a new table for the game to clear away).
local continentOf, rects = {}, {}
function C.ContinentOf(mapID)
    if mapID and continentOf[mapID] then return continentOf[mapID] end
    local first = mapID
    local info = C_Map.GetMapInfo(mapID)
    while info and info.mapType and info.mapType > CONTINENT and info.parentMapID and info.parentMapID ~= 0 do
        mapID = info.parentMapID
        info = C_Map.GetMapInfo(mapID)
    end
    if first and info then continentOf[first] = mapID end
    return mapID
end

-- (For the tests, whose made-up world gains and loses maps.)
function C.ForgetMaps() continentOf, rects = {}, {} end

local function onto(mapID, x, y, target)
    if mapID == target then return x, y end
    local key = tostring(mapID) .. ">" .. tostring(target)
    local rect = rects[key]
    if not rect then
        local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, mapID, target)
        -- (Only an answer is kept; a map not known yet is asked again.)
        if not (ok and left) then return end
        rect = {left, right, top, bottom}
        rects[key] = rect
    end
    local left, right, top, bottom = rect[1], rect[2], rect[3], rect[4]
    if not left or right == left or bottom == top then return end
    x, y = left + x*(right - left), top + y*(bottom - top)
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    return x, y
end

-- East and south of the player, in yards, and the distance. nil when the game gives none.
function C.NavigationVector(marker)
    if not (marker and marker.mapID and marker.x and marker.y and C_Map and C_Map.GetMapInfo) then return end
    local continent = C.ContinentOf(marker.mapID)
    local tx, ty = onto(marker.mapID, marker.x/100, marker.y/100, continent)
    local pos = tx and C_Map.GetPlayerMapPosition(continent, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    px, py = plain(px), plain(py)
    if not px or not py or (px == 0 and py == 0) then return end
    local width, height = C_Map.GetMapWorldSize(continent)
    if not width or not height then return end
    local dx, dy = (tx - px)*width, (ty - py)*height
    return dx, dy, sqrt(dx*dx + dy*dy)
end

-- Yards between two places of one continent, by the map alone.
function C.Span(a, b)
    if not (a and b and a.mapID and b.mapID and C_Map and C_Map.GetMapInfo) then return end
    local continent = C.ContinentOf(a.mapID)
    if continent ~= C.ContinentOf(b.mapID) then return end
    local ax, ay = onto(a.mapID, a.x/100, a.y/100, continent)
    local bx, by = onto(b.mapID, b.x/100, b.y/100, continent)
    local width, height = C_Map.GetMapWorldSize(continent)
    if not (ax and bx and width and height) then return end
    local dx, dy = (bx - ax)*width, (by - ay)*height
    return sqrt(dx*dx + dy*dy)
end

-- A place on its continent, in yards east and south of the corner: continent, east, south.
function C.Yards(place)
    if not (place and place.mapID and place.x and place.y and C_Map and C_Map.GetMapInfo) then return end
    local continent = C.ContinentOf(place.mapID)
    local x, y = onto(place.mapID, place.x/100, place.y/100, continent)
    local width, height = C_Map.GetMapWorldSize(continent)
    if not (x and width and height) then return end
    return continent, x*width, y*height
end

-- The same for the player. nil where the game gives no position (inside an instance).
function C.PlayerYards()
    local here = C_Map and C_Map.GetBestMapForUnit and plain(C_Map.GetBestMapForUnit("player"))
    if not here then return end
    local continent = C.ContinentOf(here)
    local pos = continent and C_Map.GetPlayerMapPosition(continent, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    x, y = plain(x), plain(y)
    if not x or not y or (x == 0 and y == 0) then return end
    local width, height = C_Map.GetMapWorldSize(continent)
    if not width or not height then return end
    return continent, x*width, y*height
end

function C.Markers()
    return C.char and C.char.markers or {}
end

function C.Target()
    return C.Markers()[1]
end

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffedc36fDungeon Quest Forever|r • " .. text) end
end

-- Small signs on the world map: which zeppelin leaves from which platform, which ship
-- from which dock. They stand on the map of their zone whenever it is open.
local signs = {}
local function placeSigns(canvas, shown)
    for _, sign in ipairs(signs) do sign:Hide() end
    if not (canvas and shown and P.Landmarks) then return end
    local scale = 1 / (canvas:GetScale() or 1)
    for i, mark in ipairs(P.Landmarks(shown)) do
        local sign = signs[i]
        if not sign then
            sign = CreateFrame("Frame", nil, UIParent)
            sign:SetSize(10, 10)
            sign.dot = sign:CreateTexture(nil, "OVERLAY")
            sign.dot:SetAllPoints()
            sign.dot:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\arrow")
            sign.label = sign:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            signs[i] = sign
        end
        sign.label:SetText(mark.text)
        sign.label:ClearAllPoints()
        -- Two platforms of one tower stand a step apart: their names go to either side.
        if i % 2 == 1 then sign.label:SetPoint("RIGHT", sign, "LEFT", -3, 0) else sign.label:SetPoint("LEFT", sign, "RIGHT", 3, 0) end
        sign:SetParent(canvas)
        sign:SetFrameStrata("HIGH")
        sign:SetScale(scale)
        sign:ClearAllPoints()
        sign:SetPoint("CENTER", canvas, "TOPLEFT", mark.x/100*canvas:GetWidth()/scale, -mark.y/100*canvas:GetHeight()/scale)
        sign.text = mark.text
        sign:Show()
    end
end
C.Signs = function() return signs end

-- The flight points of the player's faction not discovered yet, on the world map and on
-- the minimap: the game shows only the ones the character has, and none under the fog
-- of war (the owner, 15.11.2026: "I want to see them even under the fog, points I can
-- pick"; then: "only the ones I have not taken, and on the zoomed map too"). Silver;
-- hovered, what the point is and who keeps it; clicked, the arrow goes to its master.
local flights, nearby = {}, {}
local SILVER = {.82, .86, .93}
local function flightArt(texture)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local atlas = faction == "Alliance" and "TaxiNode_Alliance" or faction == "Horde" and "TaxiNode_Horde" or "TaxiNode_Neutral"
    local has = C_Texture and C_Texture.GetAtlasInfo
    if texture.SetAtlas and has and has(atlas) then texture:SetAtlas(atlas)
    elseif texture.SetAtlas and has and has("FlightMaster") then texture:SetAtlas("FlightMaster")
    else texture:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-White") end
    -- Silver: the picture of the point without its colour.
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    texture:SetVertexColor(SILVER[1], SILVER[2], SILVER[3])
end

local function flightTip(self)
    local point = self.point
    if not (point and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(point.full or point.name, 1, 1, 1)
    GameTooltip:AddLine(L"Не открыта", 1, .35, .3)
    if point.keeper then GameTooltip:AddLine(L"Распорядитель полётов: " .. point.keeper, 1, .82, .35, true) end
    GameTooltip:AddLine(L"Щелчок: стрелка к распорядителю", .6, .6, .6, true)
    GameTooltip:Show()
end

local function flightClick(self)
    if P.Track then P.Track("FlightPointClicked") end
    local point = self.point
    if not (point and point.place) then return end
    local place = point.place
    local spot = {mapID=place.mapID, x=place.x, y=place.y, npcID=point.npc, name=point.keeper}
    local label = L"Распорядитель полётов: " .. point.name
    if P.Mark then P.Mark(spot, label, "start") else C.AddMarker(spot, label, "start") end
end

local function flightPin(size, labelled)
    local pin = CreateFrame("Button", nil, UIParent)
    pin:SetSize(size, size)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    flightArt(pin.icon)
    if pin.SetHighlightTexture then pin:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD") end
    if labelled then
        pin.plate = pin:CreateTexture(nil, "BACKGROUND")
        pin.plate:SetColorTexture(0, 0, 0, .6)
        pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
        pin.label:SetTextColor(SILVER[1], SILVER[2], SILVER[3])
        pin.plate:SetPoint("TOPLEFT", pin.label, "TOPLEFT", -3, 1)
        pin.plate:SetPoint("BOTTOMRIGHT", pin.label, "BOTTOMRIGHT", 3, -1)
    end
    pin:SetScript("OnEnter", flightTip)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    pin:SetScript("OnClick", flightClick)
    return pin
end

-- The closed points of a continent; nothing where it is not known which are closed.
local function closedOn(continent)
    if not (continent and P.FlightPoints) then return {} end
    local ok, list = pcall(P.FlightPoints, continent)
    if not (ok and type(list) == "table") then return {} end
    local closed = {}
    for _, point in ipairs(list) do if point.open == false then closed[#closed+1] = point end end
    return closed
end

local function placeFlights(canvas, shown)
    for _, pin in ipairs(flights) do pin:Hide() end
    if not (canvas and shown) then return end
    local info = C_Map.GetMapInfo(shown)
    -- Not on the map of the whole world: the points of two continents in one heap.
    if not (info and info.mapType and info.mapType >= CONTINENT) then return end
    local scale = 1 / (canvas:GetScale() or 1)
    local n = 0
    for _, point in ipairs(closedOn(C.ContinentOf(shown))) do
        local x, y = onto(point.place.mapID, point.place.x/100, point.place.y/100, shown)
        if x then
            n = n + 1
            local pin = flights[n]
            if not pin then pin = flightPin(20, true); flights[n] = pin end
            pin.point = point
            pin.label:SetText(point.name)
            pin:SetParent(canvas)
            pin:SetFrameStrata("HIGH")
            pin:SetScale(scale)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", x*canvas:GetWidth()/scale, -y*canvas:GetHeight()/scale)
            pin:Show()
        end
    end
end
C.FlightPins = function() return flights end

-- On the minimap: the closed points within its circle; one farther off, up to a mile and
-- a half, waits at its rim on the side where it lies, a little paler. The yards the
-- minimap spans, side to side, at each zoom, as the classic client draws it.
local OUTDOOR = {[0]=466 + 2/3, 400, 333 + 1/3, 266 + 2/3, 200, 133 + 1/3}
local INDOOR = {[0]=300, 240, 180, 120, 80, 50}
local RIM = 1500
local minimapLook, minimapList, minimapAt = nil, nil, -99
local function placeNearby()
    for _, pin in ipairs(nearby) do pin:Hide() end
    if not (Minimap and Minimap.GetZoom) then return end
    if IsInInstance and IsInInstance() then return end
    local okP, c, pX, pY = pcall(C.PlayerYards)
    if not (okP and c and pX and pY) then return end
    local now = GetTime and GetTime() or 0
    if not minimapList or minimapList.c ~= c or now - minimapAt > 5 then
        minimapList, minimapAt = closedOn(c), now
        minimapList.c = c
    end
    if #minimapList == 0 then return end
    local zoom = Minimap:GetZoom() or 0
    local span = ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]
    local width = Minimap:GetWidth() or 140
    local radius = width / 2
    local turn = GetCVar and GetCVar("rotateMinimap") == "1" and plain(GetPlayerFacing and GetPlayerFacing()) or 0
    local cosT, sinT = math.cos(-turn), math.sin(-turn)
    local n = 0
    for _, point in ipairs(minimapList) do
        local east, north = point.X - pX, -(point.Y - pY)
        local yards = sqrt(east*east + north*north)
        if yards <= RIM then
            local x, y = east*cosT - north*sinT, east*sinT + north*cosT
            x, y = x / span * width, y / span * width
            local far = sqrt(x*x + y*y)
            local edge = far > radius - 6
            if edge then x, y = x * (radius - 6) / far, y * (radius - 6) / far end
            n = n + 1
            local pin = nearby[n]
            if not pin then
                pin = flightPin(16)
                pin:SetParent(Minimap)
                pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
                nearby[n] = pin
            end
            pin.point = point
            pin:SetAlpha(edge and .7 or 1)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
            pin:Show()
        end
    end
end
C.NearbyFlightPins = function() return nearby end
C.PlaceNearbyFlights = placeNearby
-- (A new flight point learnt: counted again at once, not in five seconds.)
function C.ForgetNearbyFlights() minimapList = nil end
if CreateFrame and UIParent then
    minimapLook = CreateFrame("Frame", nil, UIParent)
    local since = 0
    minimapLook:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < .1 then return end
        since = 0
        pcall(placeNearby)
    end)
end

local function placePin()
    if not mapPin then return end
    local target = C.Target()
    local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    local shown = canvas and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    placeSigns(canvas, shown)
    placeFlights(canvas, shown)
    local x, y
    if target and shown then x, y = onto(target.mapID, target.x/100, target.y/100, shown) end
    if not x then mapPin:Hide() return end
    -- The canvas grows with the zoom; the pin keeps its size and its tip stays on the spot.
    local scale = 1 / (canvas:GetScale() or 1)
    mapPin:SetParent(canvas)
    mapPin:SetFrameStrata("HIGH")
    -- (Above the flight points: the goal is the one thing to find.)
    if mapPin.SetFrameLevel and canvas.GetFrameLevel then mapPin:SetFrameLevel((canvas:GetFrameLevel() or 0) + 40) end
    mapPin:SetScale(scale)
    mapPin:ClearAllPoints()
    mapPin:SetPoint("BOTTOM", canvas, "TOPLEFT", x*canvas:GetWidth()/scale, -y*canvas:GetHeight()/scale - 2)
    mapPin:Show()
end

-- A picture that moves or turns is drawn between the pixels of the screen, not snapped
-- to them: snapped, it goes in steps and looks as if it shook.
local function soft(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

local elapsedSum = 0
local function turn(self, elapsed)
    elapsedSum = elapsedSum + elapsed
    -- Counted ten times a second (it was twenty); between the counts the hand still turns
    -- with the player every frame.
    if elapsedSum < .1 then
        -- Between the counts the hand still turns with the player, every frame.
        local facing = self.bearing and plain(GetPlayerFacing and GetPlayerFacing())
        if facing then self.image:SetRotation(self.bearing - facing) end
        return
    end
    local dt = elapsedSum
    elapsedSum = 0
    self.dx, self.dy = nil, nil
    local target = C.Target()
    if not target then self:Hide() return end
    -- The owner, a ghost: "the arrow glitches, no telling where to run." Dead, the run is
    -- to the body: the arrow leads there, straight, and goes back to the goal on rising.
    local ghost = UnitIsGhost and UnitIsGhost("player")
    -- Alive again: the mouth gone through as a ghost is forgotten (P.CorpseCave).
    if not ghost and P.CorpseCave then pcall(P.CorpseCave) end
    if ghost and C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
        local map = C_Map.GetBestMapForUnit and plain(C_Map.GetBestMapForUnit("player"))
        local ok, spot = pcall(C_DeathInfo.GetCorpseMapPosition, map)
        if ok and spot and spot.GetXY then
            local cx, cy = spot:GetXY()
            cx, cy = plain(cx), plain(cy)
            if cx and cy and (cx ~= 0 or cy ~= 0) then
                local kept = self.corpseTarget
                if not (kept and kept.mapID == map and kept.x == cx * 100 and kept.y == cy * 100) then
                    kept = {mapID=map, x=cx * 100, y=cy * 100, title=L"Твоё тело", corpse=true}
                    self.corpseTarget = kept
                end
                target = kept
                -- Dead in a cave of its own (the mine under Sunnyglade, 20.11.2026: "the
                -- arrow leads me to my body, not to the entrance"): the way to the body is
                -- through the mouth.
                local okCave, mouth = pcall(P.CorpseCave or function() end, kept)
                if okCave and mouth then target = mouth end
            end
        end
    end
    self.title:SetText(target.title or "")
    local dx, dy, distance = C.NavigationVector(target)
    if not distance then
        self.distance:SetText(C.L.NO_GUIDANCE)
        self.image:SetAlpha(.3)
        return
    end
    -- A plain point is done with on arrival. A point of a quest stays until the quest
    -- log says the step is over; a door stays until the player is through it.
    if distance <= 10 and not target.questID and target.kind ~= "entrance" and not target.corpse then
        say(L"Ты на месте: " .. (target.title or "?"))
        C.RemoveMarker(target)
        return
    end
    -- Along a walkable way where one is known (Walk.lua): the arrow to its next bend, the
    -- distance along it. Without one, straight to the goal, as the crow flies.
    local okWay, wx, wy, along = false, nil, nil, nil
    if P.Steer and not target.corpse then okWay, wx, wy, along = pcall(P.Steer, target) end
    if okWay and wx and along then dx, dy, distance = wx, wy, along end
    local mode = (okWay and wx) and "way" or "straight"
    -- While a way is looked for again (off it, or after a fall), the arrow pointed straight
    -- at the goal for a moment and then back along the way: it swung. It holds where it
    -- pointed until the new way is found.
    -- (15.11.2026, the log after a run in the Badlands: between one way and the next the
    -- arrow pointed straight for a second, 1286 yards west across the mountains, and back.
    -- Three seconds after the last step on a way it holds too, searching or not.)
    local now = GetTime and GetTime() or 0
    local lately = self.wayAt and now - self.wayAt < 3 and distance > 100
    local holding = not (okWay and wx) and self.onWay and ((P.WalkBusy and P.WalkBusy()) or lately) and self.lastDX and self.bearingFor == target
    if holding then dx, dy, mode = self.lastDX, self.lastDY, "hold" else self.onWay = okWay and wx ~= nil or nil end
    if not holding then self.lastDX, self.lastDY = dx, dy end
    if okWay and wx then self.wayAt = now end
    -- What the arrow did, for a look after a /reload (C.char.arrowLog, the last thirty):
    -- a line when the way of leading changes, and one every five seconds.
    if C.char and (mode ~= self.lastMode or now - (self.lastLog or 0) >= 5) then
        self.lastMode, self.lastLog = mode, now
        C.char.arrowLog = type(C.char.arrowLog) == "table" and C.char.arrowLog or {}
        local okP, _, px, py = pcall(C.PlayerYards)
        table.insert(C.char.arrowLog, ("%s %s %s | %d yd | to %.0f,%.0f | at %s,%s"):format(date and date("%H:%M:%S") or "?", mode,
            tostring(target.title or "?"), floor(distance + .5), dx or 0, dy or 0, okP and px and floor(px) or "-", okP and py and floor(py) or "-"))
        while #C.char.arrowLog > 30 do table.remove(C.char.arrowLog, 1) end
    end
    -- The game tells an addon no heights. Where the place is known to be up a tower, say so:
    -- the arrow can only bring the player to its foot.
    self.distance:SetText((L"%d м"):format(floor(distance + .5)) .. (target.hint and (" • " .. target.hint) or target.up and (L" • наверху вышки") or ""))
    -- The owner: "the arrow is glitching, it spins all ways." Where on the ground it points
    -- turns at a bounded speed (a half turn in half a second): a way found again that
    -- leads off for a moment does not throw the hand round and back. A new point is
    -- pointed at at once; the player's own turning is followed every frame, as before.
    local want = atan2(-dx, -dy)
    if not self.bearing or self.bearingFor ~= target then
        self.bearing = want
    else
        local diff = (want - self.bearing + math.pi) % (2 * math.pi) - math.pi
        local most = 6.3 * math.max(dt, .05)
        if diff > most then diff = most elseif diff < -most then diff = -most end
        self.bearing = self.bearing + diff
    end
    self.bearingFor = target
    local facing = plain(GetPlayerFacing and GetPlayerFacing())
    self.image:SetAlpha(facing and 1 or .3)
    if facing then self.image:SetRotation(self.bearing - facing) end
    self.dx, self.dy = dx, dy
end

local function build()
    local pos = C.db.arrow
    arrow = CreateFrame("Button", "DungeonQuestForeverArrow", UIParent)
    arrow:SetSize(56, 56)
    arrow:SetPoint(pos.point or "TOP", UIParent, pos.relPoint or "TOP", pos.x or 0, pos.y or -140)
    arrow:SetClampedToScreen(true)
    arrow:SetMovable(true)
    arrow:EnableMouse(true)
    arrow:RegisterForDrag("LeftButton")
    arrow:RegisterForClicks("RightButtonUp")
    arrow:SetScript("OnDragStart", arrow.StartMoving)
    arrow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
    end)
    arrow:SetScript("OnClick", function()
        if P.Track then P.Track("ArrowRemoved") end
        local target = C.Target()
        if target then C.RemoveMarker(target) end
    end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L"Стрелка к точке", 1, .83, .35, 1, true)   -- (text, r, g, b, alpha, wrap): "true" as the alpha was an error at every hover
        GameTooltip:AddLine(L"Потяни, чтобы переставить. ПКМ снимает точку.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The pointer can be a picture of the character's faction, when one is supplied:
    -- hand_horde.tga or hand_alliance.tga in the addon folder, finger pointing up.
    -- Without the file the plain arrow stays.
    arrow.image = arrow:CreateTexture(nil, "ARTWORK")
    arrow.image:SetPoint("CENTER")
    soft(arrow.image)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local art = faction == "Horde" and "hand_horde" or faction == "Alliance" and "hand_alliance"
    local loaded
    if art then
        arrow.image:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\" .. art)
        local got = arrow.image:GetTexture()
        loaded = got ~= nil and got ~= 0 and got ~= ""
    end
    if not loaded then arrow.image:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\arrow") end
    arrow.image:SetSize(loaded and 54 or 44, loaded and 54 or 44)
    arrow.art = "Interface\\AddOns\\ForeverDungeonPrep\\" .. (loaded and art or "arrow")
    arrow.title = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow.title:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    arrow.distance = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow.distance:SetPoint("TOP", arrow.title, "BOTTOM", 0, -2)
    arrow:SetScript("OnUpdate", turn)

    mapPin = CreateFrame("Frame", "DungeonQuestForeverMapPin", UIParent)
    mapPin:SetSize(30, 30)
    mapPin.art = mapPin:CreateTexture(nil, "OVERLAY")
    mapPin.art:SetAllPoints()
    mapPin.art:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\pin")
    mapPin:Hide()
end

function C.Arrow()
    return arrow
end

-- An addon cannot draw in the world. The game can: its own waypoint stands at a spot
-- in the world itself, seen from afar with the distance to it. The point of the arrow is
-- handed to the game as that waypoint, and taken back when the point goes. A waypoint
-- the player set by hand is never cleared here.
local beacon
local function light()
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    local target = C.Target()
    local spot = target and (target.mapID .. ":" .. target.x .. ":" .. target.y)
    if spot == beacon then return end
    if target and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(target.mapID)) then
        local ok = pcall(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(target.mapID, target.x/100, target.y/100))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        end)
        beacon = ok and spot or nil
    elseif beacon then
        beacon = nil
        if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    end
end

-- ------------------------------------------
-- A sign over the one the arrow leads to
-- ------------------------------------------
-- The game's own ping cannot be used: it goes where the player's cursor is, at the
-- player's key, and the whole group sees it. But an addon may hang a frame on the name
-- bar the game floats over a creature, and that bar is in the world. So when the one the
-- arrow leads to is near, the pointer stands over the head, finger down, bobbing: the
-- right zeppelin master on the right platform, the quest giver in a crowd. Name bars of
-- friendly characters are off by default; they are switched on while the player is near
-- the one sought and put back as they were after. And on coming close a sound rings once.
local NEAR, PING = 30, 15
local sign, signUnit, rung, watch

local function cvar(name, value)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not (get and set) then return end
    if value == nil then
        local ok, now = pcall(get, name)
        return ok and now or nil
    end
    pcall(set, name, value)
end

local function friendly(on)
    local db = C.char
    if not db or (InCombatLockdown and InCombatLockdown()) then return end
    if on and not db.plates then
        if db.noSign then return end
        local keep = {}
        -- Where the client can show the bars of friendly characters without those of
        -- friendly players, only that is switched; otherwise both go together.
        local names = cvar("nameplateShowFriendlyNpcs") ~= nil and {"nameplateShowFriendlyNpcs"}
            or {"nameplateShowFriends", "nameplateShowFriendlyNPCs"}
        for _, name in ipairs(names) do
            local now = cvar(name)
            if now ~= nil then keep[name] = tostring(now) end
        end
        if next(keep) == nil then return end
        db.plates = keep
        for name, was in pairs(keep) do if was ~= "1" then cvar(name, "1") end end
    elseif not on and db.plates then
        for name, was in pairs(db.plates) do if was ~= "1" then cvar(name, was) end end
        db.plates = nil
    end
end
C.Friendly = friendly
C.CVar = cvar

-- The owner: "can you make the items one has to interact with glow?" An addon cannot light
-- a thing in the world. The game can: its soft targeting puts an icon over the object or
-- creature near the player that can be used, picked or talked to; it is off by default.
-- These are its switches. What they were is kept (db.glowKept) and put back when the
-- light is switched off. Where the client has none of them, nothing is done (false).
-- The owner, the light seen in the game: "except for the chairs, of course: the quest
-- ones." The icon over objects is off (SoftTargetIconGameObject 0) and put on only while
-- the object in sight is one a quest in the log asks for (C.QuestObjectIcon).
-- The name plate over the object in sight is off too: on for a quest object, so the hand
-- can hang over it as over a boss (C.ObjectSign).
-- The owner, at the gong of Razorfen Downs: "the gong does not light up." The game marks
-- only what is a few steps off; it is looked for farther (SoftTargetInteractRange, where
-- the client has it; put back with the rest).
-- The owner, 17.11.2026: "the hand shows only when you are right up against it." The game
-- looks for the thing in a narrow cone straight ahead; the widest cone (2) finds it to the
-- side and from farther, as one walks into a room.
local GLOW = {SoftTargetInteract="3", SoftTargetIconGameObject="0", SoftTargetIconInteract="1", SoftTargetNameplateInteract="0",
    SoftTargetInteractRange="25", SoftTargetInteractArc="2"}
function C.ObjectGlow(on)
    local db = C.char
    if not db then return end
    if on then
        if not db.glowKept then
            local keep = {}
            for name in pairs(GLOW) do
                local now = cvar(name)
                if now ~= nil then keep[name] = tostring(now) end
            end
            if next(keep) == nil then return false end
            db.glowKept = keep
        end
        for name, want in pairs(GLOW) do
            -- A switch added in a later version: what it was is kept too.
            if db.glowKept[name] == nil then
                local now = cvar(name)
                if now ~= nil then db.glowKept[name] = tostring(now) end
            end
            if db.glowKept[name] ~= nil and cvar(name) ~= want then cvar(name, want) end
        end
        return true
    elseif db.glowKept then
        for name, was in pairs(db.glowKept) do cvar(name, was) end
        db.glowKept = nil
    end
    return false
end

-- Seen in the game, in a fight inside Razorfen Downs: "Interface action failed because of
-- an AddOn". The switches of the plates and the icons are not touched in a fight; the
-- thing in sight is weighed again when it ends.
local function fighting() return InCombatLockdown and InCombatLockdown() end
function C.QuestObjectIcon(on)
    local db = C.char
    if not (db and db.glowKept and not db.noGlow) or fighting() then return end
    local want = on and "1" or "0"
    if cvar("SoftTargetIconGameObject") ~= want then pcall(cvar, "SoftTargetIconGameObject", want) end
end

function C.ObjectIDFromGUID(guid)
    guid = plain(guid)
    if type(guid) ~= "string" then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "GameObject" then return tonumber(id) end
end

local function chime(key)
    if rung == key then return false end
    rung = key
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
    -- The arrow swells once when the sound rings.
    if arrow and not arrow.pulse then
        pcall(function()
            local pulse = arrow:CreateAnimationGroup()
            local grow = pulse:CreateAnimation("Scale")
            if grow.SetScaleFrom then grow:SetScaleFrom(1.8, 1.8); grow:SetScaleTo(1, 1)
            elseif grow.SetFromScale then grow:SetFromScale(1.8, 1.8); grow:SetToScale(1, 1) end
            grow:SetDuration(.4)
            arrow.pulse = pulse
        end)
    end
    if arrow and arrow.pulse then arrow.pulse:Stop(); arrow.pulse:Play() end
    return true
end

local function ring(target)
    -- Where arriving is not the end of it, what to do there is said once.
    if chime(target.mapID .. ":" .. target.x .. ":" .. target.y) and target.todo then
        say((target.title or "") .. ": " .. target.todo .. ".")
    end
end

-- Inside a dungeon there is no point and no distance, but a boss close enough to have a
-- name bar can be known by it. The ones looked for are given by the page of the run:
-- ids[number] = name, names[name] = true where no number is known. The one in sight is
-- told back through C.OnSight and C.Sighted.
local signWho
function C.Seek(list)
    C.sought = list
    if not list and signWho then
        signWho = nil
        if sign then
            sign:Hide()
            for _, key in ipairs({"bob", "shine", "spin"}) do if sign[key] then sign[key]:Stop() end end
        end
        signUnit = nil
    end
    if list and CreateFrame and UIParent and C.StartWatch then C.StartWatch() end
end
function C.Sighted()
    return signWho
end

-- Whether a unit is the one looked for; for a boss of the run, also who it is.
local function wanted(unit)
    if not unit or (issecretvalue and issecretvalue(unit)) then return false end
    local id = UnitGUID and C.NpcIDFromGUID(UnitGUID(unit))
    local name = UnitName and plain(UnitName(unit))
    local seek = C.sought
    if seek and IsInInstance and IsInInstance() then
        if id and seek.ids and seek.ids[id] then return true, seek.ids[id] end
        if not id and name and seek.names and seek.names[name] then return true, name end
        if name and seek.names and seek.names[name] then return true, name end
    end
    local target = C.Target()
    if not (target and (target.npcID or target.who)) then return false end
    if id and target.npcID then return id == target.npcID end
    return name ~= nil and name == target.who
end

local function unhang()
    if sign then
        sign:Hide()
        for _, key in ipairs({"bob", "shine", "spin"}) do if sign[key] then sign[key]:Stop() end end
    end
    signUnit = nil
    if signWho then
        signWho = nil
        if C.OnSight then pcall(C.OnSight, nil) end
    end
end

-- A pointer: the hand, a light behind it, floating. (Over a boss, and over a quest object.)
local function newSign(name)
    local sign = CreateFrame("Frame", name, UIParent)
    sign:SetSize(52, 52)
    sign:SetFrameStrata("HIGH")
    sign:EnableMouse(false)
    sign.art = sign:CreateTexture(nil, "OVERLAY")
    sign.art:SetAllPoints()
    -- The same pointer as the arrow: the faction's hand where its picture is there.
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local hand = faction == "Horde" and "hand_horde" or faction == "Alliance" and "hand_alliance"
    if hand then sign.art:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\" .. hand) end
    local got = hand and sign.art:GetTexture()
    if not (got ~= nil and got ~= 0 and got ~= "") then sign.art:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\arrow") end
    sign.art:SetRotation(math.pi)
    soft(sign.art)
    -- A light of the game's own behind the hand, breathing and slowly turning: in a
    -- crowd the pointer is seen at once. Where the client has no such picture, no light.
    sign.glow = sign:CreateTexture(nil, "BACKGROUND")
    sign.glow:SetPoint("CENTER", sign, "CENTER", 0, 2)
    sign.glow:SetSize(120, 120)
    sign.glow:SetTexture("Interface\\Cooldown\\star4")
    local lit = sign.glow:GetTexture()
    if lit ~= nil and lit ~= 0 and lit ~= "" then
        sign.glow:SetBlendMode("ADD")
        sign.glow:SetVertexColor(1, .82, .3)
        soft(sign.glow)
        pcall(function()
            local shine = sign.glow:CreateAnimationGroup()
            shine:SetLooping("BOUNCE")
            local fade = shine:CreateAnimation("Alpha")
            fade:SetFromAlpha(.45)
            fade:SetToAlpha(1)
            fade:SetDuration(.8)
            fade:SetSmoothing("IN_OUT")
            local spin = sign.glow:CreateAnimationGroup()
            spin:SetLooping("REPEAT")
            local round = spin:CreateAnimation("Rotation")
            round:SetDegrees(-360)
            round:SetDuration(10)
            sign.shine, sign.spin = shine, spin
        end)
    else
        sign.glow:Hide()
    end
    -- Slow and even, a few pixels: the hand floats, it does not jump.
    pcall(function()
        local bob = sign:CreateAnimationGroup()
        bob:SetLooping("BOUNCE")
        local move = bob:CreateAnimation("Translation")
        move:SetOffset(0, 8)
        move:SetDuration(.8)
        move:SetSmoothing("IN_OUT")
        sign.bob = bob
    end)
    return sign
end

local function hang(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local is, who = wanted(unit)
    if not is then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    if not sign then sign = newSign("DungeonQuestForeverSign") end
    sign:ClearAllPoints()
    sign:SetPoint("BOTTOM", plate, "TOP", 0, 6)
    sign:Show()
    -- An animation under way is left alone: started again, it would jump back to its start.
    for _, key in ipairs({"bob", "shine", "spin"}) do
        local play = sign[key]
        if play and not (play.IsPlaying and play:IsPlaying()) then play:Play() end
    end
    signUnit = unit
    if who then
        -- A boss of the run in sight: one ring for each, and the page is told.
        chime("seek:" .. tostring(who))
        if signWho ~= who then
            signWho = who
            if C.OnSight then pcall(C.OnSight, who) end
        end
    else
        local target = C.Target()
        if target then ring(target) end
    end
end

-- The owner, at the book of a quest in the Library: "I did not see the light. Can you
-- point at it with the finger, as over the bosses?" An object has no plate of its own; the
-- game puts one over the object in sight when SoftTargetNameplateInteract is on. It is
-- switched on while that object is one a quest wants, and the hand hangs over its plate.
-- What happened is kept in db.glowLog (the last twenty), to be read after a /reload.
local objectSign, objectOn
local function objectPlate()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
    if ok and plate and not (plate.IsForbidden and plate:IsForbidden()) then return plate end
end
local function hangOnObject()
    if not objectOn then return false end
    local plate = objectPlate()
    if not plate then return false end
    objectSign = objectSign or newSign("DungeonQuestForeverObjectSign")
    objectSign:ClearAllPoints()
    objectSign:SetPoint("BOTTOM", plate, "TOP", 0, 6)
    objectSign:Show()
    for _, key in ipairs({"bob", "shine", "spin"}) do
        local play = objectSign[key]
        if play and not (play.IsPlaying and play:IsPlaying()) then play:Play() end
    end
    return true
end
function C.ObjectSign(on, note)
    local db = C.char
    objectOn = on and true or nil
    if db and db.glowKept and not db.noGlow and not fighting() then
        local want = on and "1" or "0"
        if cvar("SoftTargetNameplateInteract") ~= want then pcall(cvar, "SoftTargetNameplateInteract", want) end
    end
    local hung = hangOnObject()
    if not hung and objectSign then
        objectSign:Hide()
        for _, key in ipairs({"bob", "shine", "spin"}) do if objectSign[key] then objectSign[key]:Stop() end end
    end
    -- The plate may come a moment after the switch.
    if on and not hung and C_Timer and C_Timer.After then
        for _, wait in ipairs({.1, .3, .7}) do C_Timer.After(wait, function() hangOnObject() end) end
    end
    if db and note then
        db.glowLog = type(db.glowLog) == "table" and db.glowLog or {}
        table.insert(db.glowLog, ("%s %s | icon %s | plateCVar %s | plate %s"):format(date and date("%H:%M:%S") or "?", note,
            tostring(cvar("SoftTargetIconGameObject")), tostring(cvar("SoftTargetNameplateInteract")), hung and "yes" or "no"))
        while #db.glowLog > 20 do table.remove(db.glowLog, 1) end
    end
    return hung
end

-- Looked at a few times a second, and whenever the point changes.
local function look()
    local target = C.Target()
    local who = target and (target.npcID or target.who)
    local distance
    if target then
        local _, _, far = C.NavigationVector(target)
        distance = far
    end
    local inside = IsInInstance and IsInInstance()
    local close = who and distance and distance <= NEAR and not inside
    local seeking = C.sought and inside
    friendly(close and true or false)
    if not close and not seeking then
        unhang()
    elseif signUnit and not wanted(signUnit) then
        unhang()
    elseif not signUnit and C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates() or {}
        for _, plate in ipairs(plates) do
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit and not signUnit and not (plate.IsForbidden and plate:IsForbidden()) then hang(unit) end
        end
        -- The owner, in the Library: "there are no pointers over the bosses." What the
        -- plates told is kept (db.signLog, the last twenty, one in five seconds) to be read
        -- after a /reload: the unit, forbidden or not, and whether its number can be read.
        local db = C.char
        local now = GetTime and GetTime() or 0
        if seeking and not signUnit and db and now - (C.signLogged or -10) >= 5 then
            C.signLogged = now
            local parts = {}
            for i, plate in ipairs(plates) do
                if i > 6 then break end
                local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                local guid = unit and UnitGUID and UnitGUID(unit)
                local secret = issecretvalue and guid ~= nil and issecretvalue(guid)
                parts[#parts+1] = tostring(unit) .. (plate.IsForbidden and plate:IsForbidden() and ":forbidden" or "")
                    .. (secret and ":secret" or (":" .. tostring(C.NpcIDFromGUID(guid))))
            end
            db.signLog = type(db.signLog) == "table" and db.signLog or {}
            table.insert(db.signLog, (date and date("%H:%M:%S") or "?") .. " plates " .. #plates .. " | " .. table.concat(parts, " "))
            while #db.signLog > 20 do table.remove(db.signLog, 1) end
        end
    end
    if target and distance then
        if distance <= PING then ring(target) elseif distance > PING * 3 and not signWho then rung = nil end
    end
end
C.Look = look

local function startWatch()
    if watch then return end
    watch = CreateFrame("Frame", "DungeonQuestForeverSignWatch", UIParent)
    for _, event in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED"}) do
        pcall(watch.RegisterEvent, watch, event)
    end
    watch:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if objectOn then hangOnObject() end
            if not signUnit then
                local target = C.Target()
                local _, _, distance = C.NavigationVector(target)
                if (distance and distance <= NEAR) or (C.sought and IsInInstance and IsInInstance()) then hang(unit) end
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if unit == signUnit then unhang() end
        else
            look()
        end
    end)
    local waited = 0
    watch:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < .3 then return end
        waited = 0
        look()
    end)
end
C.StartWatch = startWatch

function C.OnMarkersChanged()
    light()
    if not arrow then
        if not (CreateFrame and UIParent) then return end
        build()
    end
    if not hooked and WorldMapFrame and WorldMapFrame.HookScript then
        hooked = true
        WorldMapFrame:HookScript("OnShow", placePin)
        if hooksecurefunc and WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", placePin) end
        if hooksecurefunc and WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", placePin) end
    end
    arrow:SetShown(C.Target() ~= nil)
    elapsedSum = 1
    placePin()
    startWatch()
    unhang()
    look()
end

function C.AddMarker(point, title, kind, questID)
    -- (Every point on the map of its zone: one on the continent's map was weighed as a zone.)
    if point and C.Localize then point = C.Localize(point) end
    local list = C.Markers()
    for i = #list, 1, -1 do list[i] = nil end
    local marker = {mapID=point.mapID, x=point.x, y=point.y, title=title, kind=kind, npcID=point.npcID, questID=questID, up=point.up,
        who=point.who or point.keeper or point.name, hint=point.hint, todo=point.todo, door=point.door, cave=point.cave, at=GetServerTime and GetServerTime() or 0}
    list[1] = marker
    C.OnMarkersChanged()
    return marker
end

function C.RemoveMarker(marker)
    local list = C.Markers()
    for i = #list, 1, -1 do
        if list[i] == marker then table.remove(list, i) end
    end
    C.OnMarkersChanged()
end

function C.SetTarget(marker)
    if marker then C.AddMarker(marker, marker.title, marker.kind, marker.questID)
    else C.RemoveMarker(C.Target()) end
end

function C.OpenMapAt(mapID)
    if not (mapID and WorldMapFrame) then return end
    if C_Map and C_Map.OpenWorldMap then
        pcall(C_Map.OpenWorldMap, mapID)
    elseif ShowUIPanel then
        pcall(ShowUIPanel, WorldMapFrame)
        if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
    end
    -- The owner: "the big map opens, I want the small one; who wants the big one opens it."
    -- The small map, not the full-screen one, where the client has both.
    if WorldMapFrame.IsMaximized and WorldMapFrame.Minimize and not (InCombatLockdown and InCombatLockdown()) then
        local ok, big = pcall(WorldMapFrame.IsMaximized, WorldMapFrame)
        if ok and big then pcall(WorldMapFrame.Minimize, WorldMapFrame) end
    end
    placePin()
end
