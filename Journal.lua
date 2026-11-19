local _, P = ...
local L = P.L or function(s) return s end
local atlas = P.Core
local title = "Dungeon Quest Forever"
local db, tracker, catalog, selected, result
local headNote      -- "взято K из N" for the heading of the section, in the look of the game's quests
local unfolded      -- the quest unfolded on the panel: the goal of its chain, or itself
local browsing, pending = false, false
local first, catalogFirst, displayed = 1, 1, 0
local limit = 8 -- dungeons per page of the catalogue; a dungeon page shows every row
local visible, progress, history = {}, {}, {}
local detailRows, readStep = {}, {}
local routeExpanded = false
local countsDirty = true
local focus, lastTracked, compact, detailPage, bossTarget, autoBoss
local nameRetries = 0
local probing, cleaned, planGuide
-- The moment the arrow was last set on the door unasked: "KEY" or "KEY:ghost".
local led
-- By dungeon: whether at the last refresh everything outside was taken (nil: not seen yet).
local readyWas = {}
-- By dungeon: whether at the last refresh the chains were done and quests to ask for left.
local shareWas = {}
-- Whether the last refresh found the player inside the dungeon of the page; nil at first.
local wasInside

-- The atlas addon may still be switched on, holding the points this addon gave it before
-- it stood on its own ground. Its arrow would hang there with "no navigation" to say.
-- Those points are taken back once.
local function clearAtlasLeftovers()
    local old = _G.DungeonQuestAtlas
    if not (db and old and old ~= atlas and old.ClearMarkers) or db.atlasCleared then return end
    if pcall(old.ClearMarkers) then db.atlasCleared = true end
end

-- Arrows this addon used to set by itself to a far dungeon door.
local function dropStaleArrows()
    if cleaned or not atlas.Markers or not atlas.RemoveMarker then return end
    cleaned = true
    local list = atlas.Markers()
    for i = #list, 1, -1 do
        local marker = list[i]
        if marker.kind == "entrance" and type(marker.title) == "string" and marker.title:find(L"^Вход • внутри") then
            atlas.RemoveMarker(marker)
        end
    end
end

-- "Wing • Dungeon": the part that tells wings apart survives a narrow header.
local function shortName(d)
    local full = atlas.DungeonName(d)
    local base, part = full:match("^(.-)%s*%((.+)%)$")
    if d.part and base and part then return part .. " • " .. base end
    -- Inside a wing of it: "Library • Scarlet Monastery".
    local wing = P.WingHere and P.WingHere(d)
    if wing then return wing .. " • " .. full end
    return full
end

-- The point on the world map: a gold pin with its tip on the spot, in place of the
-- atlas gem. Where a quest is turned in the game's own "?" stays.
local PIN = "Interface\\AddOns\\ForeverDungeonPrep\\pin"
local pinReady
local function pinArt()
    -- A file added while the game runs is not there until the client restarts.
    if pinReady == nil then
        local probe = UIParent:CreateTexture()
        probe:SetTexture(PIN)
        local got = probe:GetTexture()
        pinReady = got ~= nil and got ~= 0 and got ~= ""
        probe:Hide()
    end
    return pinReady
end

function P.StylePin(pin, marker)
    local gem = pin.Gem
    if not gem then return end
    gem:ClearAllPoints()
    if marker.kind == "end" or not pinArt() then
        gem:SetAllPoints(pin)
        return
    end
    local size = 30
    gem:SetTexture(PIN)
    gem:SetTexCoord(0, 1, 0, 1)
    gem:SetSize(size, size)
    -- The tip of the drawing sits 4 of 64 pixels above its lower edge.
    gem:SetPoint("BOTTOM", pin, "CENTER", 0, -size*4/64)
    if pin.Glow then
        pin.Glow:SetTexture(PIN)
        pin.Glow:ClearAllPoints()
        pin.Glow:SetPoint("CENTER", gem, "CENTER")
        pin.Glow:SetSize(size*1.5, size*1.5)
    end
end

local function restylePins()
    local mixin = _G.DungeonQuestAtlasPinMixin
    if not mixin or mixin.dqfStyled or not mixin.OnAcquired then return end
    mixin.dqfStyled = true
    hooksecurefunc(mixin, "OnAcquired", P.StylePin)
end

-- The arrow of the atlas shows the name and the distance. Two things are added to it:
-- a button to put it away, and plain words when the place is on another continent.
local function dressArrow(arrow)
    if arrow.dqfClose or InCombatLockdown() then return end
    local close = CreateFrame("Button", nil, arrow, "UIPanelCloseButton")
    arrow.dqfClose = close
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", arrow, "TOPRIGHT", 14, 8)
    close:SetScript("OnClick", function()
        db.arrowOff = true
        P.TidyArrow()
    end)
    close:SetScript("OnEnter", function()
        GameTooltip:SetOwner(close, "ANCHOR_LEFT")
        GameTooltip:SetText(L"Убрать стрелку", 1, .83, .35, 1, true)   -- (text, r, g, b, alpha, wrap): "true" as the alpha was an error at every hover
        GameTooltip:AddLine(L"Точка на карте останется. Щелчок по любой строке трекера вернёт стрелку.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A mage does not need an arrow across the sea: the teleport itself stands where the
-- arrow would be, and a click casts it. A secure button: it can be created, shown,
-- hidden and re-aimed only out of combat.
local teleport
local function teleportIcon(spell)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
    if not icon and GetSpellTexture then icon = GetSpellTexture(spell) end
    return icon or "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar"
end

local function showTeleport(hop, target)
    -- The icon is a button of the protected kind: in a fight the game lets an addon neither
    -- show nor hide it. Seen in the game: a teleport chosen in a fight, the page saying
    -- "press the icon", and no icon. So in a fight: an icon already up for this very spell
    -- stays; one that is not wanted any more is made unseen (it cannot be hidden) until the
    -- fight ends; one that is wanted and not up waits for the end of the fight, and the
    -- arrow and the page say so meanwhile.
    if InCombatLockdown() then
        local wanted = hop and hop.spell
        if teleport and teleport:IsShown() then
            if wanted and teleport.spell == hop.spell and not teleport.unseen then return true end
            if teleport.SetAlpha then teleport:SetAlpha(0) end
            teleport.unseen = true
        end
        P.teleportWaits = wanted and true or nil
        return false
    end
    P.teleportWaits = nil
    if teleport then
        teleport.unseen = nil
        if teleport.SetAlpha then teleport:SetAlpha(1) end
    end
    if not (hop and hop.spell) then
        if teleport then teleport:Hide() end
        return false
    end
    if not teleport then
        teleport = CreateFrame("Button", "DungeonQuestForeverTeleport", UIParent, "SecureActionButtonTemplate")
        teleport:SetSize(44, 44)
        teleport:SetFrameStrata("MEDIUM")
        teleport:RegisterForClicks("LeftButtonUp")
        teleport:SetAttribute("useOnKeyDown", false)
        teleport:SetAttribute("type", "spell")
        teleport.icon = teleport:CreateTexture(nil, "ARTWORK")
        teleport.icon:SetAllPoints()
        teleport:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        teleport.title = teleport:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        teleport.title:SetPoint("TOP", teleport, "BOTTOM", 0, -3)
        teleport.note = teleport:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        teleport.note:SetPoint("TOP", teleport.title, "BOTTOM", 0, -2)
        teleport:HookScript("PostClick", function() if P.Track then P.Track("TeleportUsed") end end)
        teleport:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            if self.spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.spell) end
            GameTooltip:AddLine(L"Щелчок читает заклинание. После телепорта стрелка поведёт дальше.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        teleport:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local close = CreateFrame("Button", nil, teleport, "UIPanelCloseButton")
        teleport.close = close
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", teleport, "TOPRIGHT", 14, 10)
        -- The owner: "the teleport is not knocked off by the cross, and the arrow does not
        -- come on." The cross used to switch all leading off. Now it means "not by
        -- teleport": the way to the same goal is counted again without a cast, and the
        -- arrow leads it. Asking for the goal anew offers the teleport again.
        close:SetScript("OnClick", function()
            if db.goal then db.goal.noCast = true end
            db.arrowOff = nil
            if InCombatLockdown() then
                if teleport.SetAlpha then teleport:SetAlpha(0) end
                teleport.unseen = true
            end
            if P.Refresh then P.Refresh() else P.TidyArrow() end
        end)
        close:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L"Без телепорта", 1, .83, .35)
            GameTooltip:AddLine(L"Дорога к той же цели пересчитается без заклинания, и её поведёт стрелка.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        close:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if teleport.spell ~= hop.spell then
        teleport.spell = hop.spell
        teleport:SetAttribute("spell", hop.spell)
        teleport.icon:SetTexture(teleportIcon(hop.spell))
    end
    teleport.title:SetText(L"Телепорт: " .. hop.city)
    -- All of the way under the icon: the ride after the cast, then the place itself.
    local after = {}
    for i, leg in ipairs(hop.legs or {hop, hop.next}) do
        if i > 1 and leg.ride then after[#after+1] = L"затем: " .. leg.ride end
    end
    if target and target.title then after[#after+1] = L"затем: " .. target.title end
    teleport.note:SetText(table.concat(after, "\n"))
    -- Where the arrow stands; not anchored to it, or the arrow would become protected.
    local pos = atlas.db and atlas.db.arrow or {}
    teleport:ClearAllPoints()
    teleport:SetPoint(pos.point or "TOP", UIParent, pos.relPoint or "TOP", pos.x or 0, pos.y or -140)
    teleport:Show()
    return true
end

-- Inside an instance the client gives no position: the atlas arrow can only say
-- "no navigation here". Keep it out of the way until the player is outside again.
local arrowHidden
function P.TidyArrow()
    local arrow = atlas.Arrow and atlas.Arrow()
    if not arrow or not atlas.Target then return end
    if InCombatLockdown() and arrow.IsProtected and arrow:IsProtected() then return end
    dressArrow(arrow)
    local target = atlas.Target()
    -- What the arrow says when it cannot give a distance: the way over, not "no navigation".
    -- The way to the goal the player asked for; a teleport on it stands in place of the arrow.
    local goal = db and db.goal
    local hop = target and goal and P.Plan and P.Plan(goal)
    if atlas.L and atlas.L.NO_GUIDANCE then
        atlas.L.NO_GUIDANCE = hop and (L"Другой континент • " .. hop.text) or (L"Другой континент")
    end
    local inside = IsInInstance and IsInInstance()
    local off = db and db.arrowOff
    local jumping = showTeleport(not inside and not off and hop or nil, goal and {title=goal.label} or target)
    local useless = target and inside and not atlas.NavigationVector(target)
    if useless or off or jumping then
        if arrow:IsShown() then arrow:Hide(); arrowHidden = true end
    elseif arrowHidden then
        arrowHidden = nil
        if target then arrow:Show() end
    end
end

local function isClosed(count)
    return count.total > 0 and count.finished == count.total
end

local function included(d, count)
    if db.fullCatalog then return true end
    -- (Forever's new dungeons are listed though the database has no quests of them yet: the
    -- way in and the level are worth having.)
    return (count.total > 0 or d.forever) and not db.hidden[d.key] and not (db.hideDone and isClosed(count))
end

-- The list goes by what the character can do with a dungeon now: the ones of its level
-- first, then the ones outgrown, the ones a level or three away, and the rest. Each
-- group is a label with a count that folds on a click. fits[key] is the group of a dungeon.
local fits = {}
local groups = {
    {key="now", label=L"По твоему уровню", about=L"Подземелья твоего уровня."},
    {key="low", label=L"Ниже твоего уровня", about=L"Ты перерос эти подземелья, но задания в них остались."},
    {key="soon", label=L"Скоро", about=L"До этих подземелий осталось не больше трёх уровней."},
    {key="later", label=L"Позже", about=L"Эти подземелья пока далеко по уровню."},
}
local function rebuildList()
    local shown = {}
    for _, d in ipairs(catalog) do
        if countsDirty then
            local finished, total, taken, ready = P.Progress(d)
            progress[d.key] = {finished=finished, total=total, taken=taken, ready=ready or 0}
        end
        local count = progress[d.key]
        if included(d, count) then
            shown[#shown+1] = d
        end
    end
    countsDirty = false
    local level = UnitLevel and UnitLevel("player") or 0
    local lists = {now={}, low={}, soon={}, later={}}
    for _, d in ipairs(shown) do
        local key = d.maxLevel < level and "low" or d.minLevel <= level and "now" or d.minLevel - level <= 3 and "soon" or "later"
        fits[d.key] = key
        table.insert(lists[key], d)
    end
    visible = {}
    local fold = db and db.fold or {}
    for _, group in ipairs(groups) do
        local list = lists[group.key]
        if #list > 0 then
            visible[#visible+1] = {group=group.key, section=(fold[group.key] and "+ " or "– ") .. group.label .. " • " .. #list,
                about=group.about .. L" Щелчок сворачивает и разворачивает группу."}
            if not fold[group.key] then
                for _, d in ipairs(list) do visible[#visible+1] = d end
            end
        end
    end
end

-- One accent for the section labels; titles keep the tracker's own colour, and grey
-- is for what cannot be done yet.
-- Quests whose place in the run is said under a boss of the page inside.
local runTold = {}
local LABEL, DIM = "|cff6cc4ff", "|cff999999"

-- The chain of a quest by steps: the lines, the step to do now, how many there are.
local function chainOf(id)
    if P.ChainLines then return P.ChainLines(id) end
end

-- Seen beside the mock-up in the game, the first try was a pale small copy of it: the
-- game's own tracker font at its own size, labels one point up. The sizes are now taken
-- off the mock-up (its panel is the width of this column): rows 14, the lines under them
-- 13, labels 15, the thing to do now and the boss 16, buttons 12. The typeface is the
-- game's, so every Russian letter is there.
local fonts
-- The owner, with the panel in the game's column: "my window still differs from an
-- ordinary quest. See how handy the quests are made; it should be made alike." So the
-- panel wears the look of the game's own quests: the game's fonts at the game's sizes
-- (read off a block of the column itself where that can be done), no cards, the round
-- sign of a quest on the left, the lines under a name with a dash, the name in the
-- colour of the quest's difficulty. /dq cards puts the cards back.
local nativeFonts
local function nativeLook()
    return not (db and db.boardCards)
end
local ownFontsRaw
local function ownFonts()
    local own = ownFontsRaw()
    if not nativeLook() then return own end
    local got = nativeFonts or {}
    local row = got.row or _G.ObjectiveTrackerHeaderFont or _G.ObjectiveFont or GameFontNormal
    local sub = got.sub or _G.ObjectiveTrackerLineFont or _G.ObjectiveFont or GameFontHighlight
    return {label=row, big=row, row=row, sub=sub, button=own.button, head=got.head}
end
function ownFontsRaw()
    if fonts then return fonts end
    fonts = {}
    if not (CreateFont and GameFontNormal and GameFontNormal.GetFont) then return fonts end
    local function make(name, base, size)
        local ok, font = pcall(function()
            local f = CreateFont(name)
            f:SetFontObject(base)
            local path, _, flags = base:GetFont()
            f:SetFont(path, size, flags or "")
            return f
        end)
        return ok and font or nil
    end
    fonts.label = make("DungeonQuestForeverLabelFont", GameFontNormal, 15)
    fonts.big = make("DungeonQuestForeverBigFont", GameFontNormal, 16)
    fonts.row = make("DungeonQuestForeverRowFont", GameFontNormal, 14)
    fonts.sub = make("DungeonQuestForeverSubFont", GameFontHighlight or GameFontNormal, 13)
    fonts.button = make("DungeonQuestForeverButtonFont", GameFontNormal, 12)
    return fonts
end


-- Yards to a place, when the game can tell: outdoors, on this continent.
function P.Distance(place)
    if not (place and place.mapID and place.x and place.y and atlas.NavigationVector) then return end
    local ok, _, _, distance = pcall(atlas.NavigationVector, place)
    return ok and distance or nil
end

function P.DistanceText(place)
    local distance = P.Distance(place)
    if not distance then return end
    if distance >= 1000 then return (L"%.1f км"):format(distance / 1000) end
    return (L"%d м"):format(math.floor(distance / 10 + .5) * 10)
end

-- Near or not: the distance where the game can count one, else a plain word that the
-- place is across the sea. Every row with a place answers this.
function P.Reach(place)
    local far = P.DistanceText(place)
    if far then
        -- A long way on foot with a flight that shortens it: said at once, before any click.
        local yards = P.Distance(place)
        if yards and yards >= 1500 and P.Plan then
            local ok, plan = pcall(P.Plan, place)
            if ok and plan and plan.fly then far = far .. L", перелётом быстрее"
            elseif ok and plan and plan.onFoot and plan.walk then
                -- Not the straight line through the mountains: the walk by the passes.
                far = (plan.walk >= 1000 and (L"%.1f км"):format(plan.walk / 1000) or (L"%d м"):format(math.floor(plan.walk / 10 + .5) * 10)) .. L" через проход"
            end
        end
        return far
    end
    if place and place.mapID and P.Overseas and P.Overseas(place) then return (L"за морем") end
end

-- The arrow follows the quest log, not the feet: a step to take a quest is over when
-- the quest is in the log, a step to hand it in when it is handed in. Standing next to
-- the giver settles nothing.
-- The goals of the quest the arrow led to are met, the quest still in the log: the arrow
-- goes on to whom it is handed in. (The owner in Riverglades, 19.11.2026, the priests and
-- scouts of "Show Them How It's Done" killed: the arrow was taken off the goal and nothing
-- put in its place, and the empty arrow was sent to the door of Krol'dok.) Not in a fight:
-- the arrow is set when it is over.
local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffedc36f" .. title .. "|r • " .. message)
end

local handInNext
local function leadToHandIn(id)
    if not (id and P.Mark and atlas.QuestPlaces) then return end
    if not (P.IsActive(id) and C_QuestLog.IsComplete(id)) then handInNext = nil return end
    if InCombatLockdown and InCombatLockdown() then handInNext = id return end
    handInNext = nil
    local ok, list = pcall(atlas.QuestPlaces, id, "ends")
    if not (ok and type(list) == "table") then return end
    for _, place in ipairs(list) do
        if place.mapID and place.x and place.y and not place.inside then
            local name = atlas.PlaceName(place) or P.Title(id)
            P.Mark(place, name, "end", id)
            say(L"Цели выполнены. Стрелка ведёт сдавать: " .. name .. " • «" .. P.Title(id) .. "»")
            return true
        end
    end
end

local function settleMark()
    local target = atlas.Target and atlas.Target()
    if handInNext and not target then leadToHandIn(handInNext) return end
    if not target or not atlas.RemoveMarker then return end
    local id, kind = target.questID, target.kind
    local over
    if kind == "entrance" then
        over = IsInInstance and IsInInstance()
    elseif id and kind == "start" then
        over = P.IsActive(id) or C_QuestLog.IsQuestFlaggedCompleted(id)
    elseif id and kind == "end" then
        over = C_QuestLog.IsQuestFlaggedCompleted(id) or not P.IsActive(id)
    elseif id and kind == "objective" then
        over = C_QuestLog.IsComplete(id) or not P.IsActive(id)
    end
    if over then
        atlas.RemoveMarker(target)
        if db then db.goal = nil end
        if id and kind == "objective" then leadToHandIn(id) end
    end
end

-- Which shelf of the page a quest row belongs on.
local function shelf(row)
    if row.turnIn then return "turnin" end
    if row.state == "active" then return row.work and "before" or "taken" end
    if row.levelLocked or row.unknown then return "later" end
    if row.zone == "inside" then return "inside" end
    return "before"
end

-- One goal of a quest done and others left (the owner in the Badlands, 15.11.2026: the
-- shards gathered, the fangs and the stomachs still wanted, "the arrow leads me on"): the
-- arrow goes on to the nearest goal left, by itself. Only when the goal it leads to is
-- done: between two goals left it does not switch as the player walks.
local function nextObjective(d)
    if not (d and atlas.QuestWork and P.Mark) or InCombatLockdown() then return end
    local target = atlas.Target and atlas.Target()
    local goal = db and db.goal
    local id, current
    if target and target.kind == "objective" and target.questID then id, current = target.questID, target.title
    elseif goal and goal.kind == "objective" and goal.id then id, current = goal.id, goal.label end
    if not id or not current or C_QuestLog.IsComplete(id) or not P.IsActive(id) then return end
    local ok, left = pcall(atlas.QuestWork, id, d)
    if not (ok and type(left) == "table" and left[1]) then return end
    for _, spot in ipairs(left) do
        if spot.name == current then return end
    end
    local nextOne = left[1]
    if not (nextOne.mapID and nextOne.x and nextOne.y and nextOne.name) then return end
    P.Mark(nextOne, nextOne.name, "objective", id)
    say(L"Цель выполнена. Стрелка ведёт дальше: " .. nextOne.name .. (nextOne.text and (" • " .. nextOne.text) or ""))
end

local function tip(owner, title, note)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, .83, .35, 1, true)   -- (text, r, g, b, alpha, wrap): "true" as the alpha was an error at every hover
    if note then GameTooltip:AddLine(note, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function summary()
    if not result then return end
    local msg = (L"В журнале %d  •  Сдано %d  •  Всего %d"):format(result.taken, result.finished, #result.rows)
    if result.gate then return msg .. "\n" .. result.gate end
    if result.ready then return msg .. L"\nЗадания для входа готовы" end
    return msg
end

local function choose(d, navigating)
    P.Track("DungeonChosen")
    routeExpanded, readStep, nameRetries = false, {}, 0
    db.browsing = false
    selected, db.key, browsing, first, history = d, d.key, false, 1, {}
    P.Refresh()
    if not navigating then P.PlanPartyTip(d.key) end
end

local function browse()
    db.browsing = true
    countsDirty = true
    rebuildList()
    browsing, history = true, {}
    first = math.min(catalogFirst, math.max(1, #visible))
    for i, d in ipairs(visible) do
        if d == selected and (i < first or i >= first + limit) then first = i - (i-1) % limit end
    end
    catalogFirst = first
    tracker:MarkDirty()
end

local function headerButton(name, icon, anchor, onClick)
    local b = CreateFrame("Button", nil, tracker.Header)
    b:SetSize(18, 18)
    b:SetNormalTexture(icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function() tip(b, name) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function move(direction)
    local entries = browsing and visible or detailRows
    if direction > 0 then
        history[#history+1] = first
        first = math.min(#entries, first + math.max(displayed, 1))
    else
        first = table.remove(history) or math.max(1, first - limit)
    end
    if browsing then catalogFirst = first end
    tracker:MarkDirty()
end

-- Use the same screen coordinates even when Bartender bars have their own scale.
local function barMargin(self)
    local parent = ObjectiveTrackerFrame
    local left, top = parent:GetLeft(), parent:GetTop()
    if not left or not top then return 0 end
    local scale = parent:GetEffectiveScale()
    local right = left + ((self.isBoard and parent.GetWidth and parent:GetWidth()) or self:GetWidth())
    local bottom = parent:GetBottom() or 0
    local edge = right
    for id = 1, 15 do
        local bar = _G["BT4Bar" .. id]
        if bar and bar:IsVisible() and bar:GetHeight() > bar:GetWidth() then
            local x, y = bar:GetLeft(), bar:GetBottom()
            if x and y then
                local ratio = bar:GetEffectiveScale() / scale
                if bar:GetRight()*ratio > left and x*ratio < right and y*ratio < top and bar:GetTop()*ratio > bottom then
                    edge = math.min(edge, x*ratio - 8)
                end
            end
        end
    end
    return math.max(-left, edge - right)
end

-- The whole column of tasks steps out from under the action bars, and with it the list
-- of this addon stays flush with "All objectives" and the game's own quests: one column,
-- none of it behind the skills. Seen in the game: the column stood where it was and the
-- list of this addon alone had stepped aside, crooked against the rest. The game puts
-- the column back by its own anchor whenever it lays the screen out, so: the frame is
-- moved by its plain methods where it has them (the ones the layout editor keeps for
-- itself), every anchor the game sets afterwards is pushed by the same distance, and a
-- move that did not take is said once in the chat with its reason. Out of a fight only.
-- /dq column switches the moving off and puts the column back.
local wanted, pushing, hooked, faultSaid = 0, false, false, false
local function pushColumn(dx, only)
    local frame = ObjectiveTrackerFrame
    -- The layout editor keeps the plain methods as fields of the frame itself.
    local set = rawget(frame, "SetPointBase") or frame.SetPoint
    local clear = rawget(frame, "ClearAllPointsBase") or frame.ClearAllPoints
    local count = frame:GetNumPoints()
    if not count or count < 1 then error(L"у столбца нет точки привязки") end
    local points = {}
    for i = 1, count do
        points[i] = {frame:GetPoint(i)}
        if not points[i][1] then error(L"точка привязки не читается") end
    end
    pushing = true
    local ok, err = pcall(function()
        if only then
            for _, p in ipairs(points) do
                if p[1] == only then set(frame, p[1], p[2], p[3], (p[4] or 0) + dx, p[5] or 0) end
            end
        else
            clear(frame)
            for _, p in ipairs(points) do set(frame, p[1], p[2], p[3], (p[4] or 0) + dx, p[5] or 0) end
        end
    end)
    pushing = false
    if not ok then error(err, 0) end
end

local function columnFault(reason)
    if db then db.columnFault = tostring(reason) end
    if not faultSaid and DEFAULT_CHAT_FRAME then
        faultSaid = true
        DEFAULT_CHAT_FRAME:AddMessage(L"|cffedc36fDungeon Quest|r • столбец заданий не отодвинулся от панелей: " .. tostring(reason))
    end
end

-- Seen in the game a minute after the first try: in a fight the game set the column's
-- anchor again, this addon would not touch it in a fight, and the whole column with the
-- dark panel stood under the skills until the fight was over. The column is out of
-- bounds in a fight only while it holds something protected (a quest item button); the
-- rest of the time it may be moved, and is. Where it may not, the list of this addon at
-- least steps aside by itself, at once.
local function columnLocked()
    if not InCombatLockdown() then return false end
    local frame = ObjectiveTrackerFrame
    if frame.IsProtected then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok and not protected then return false end
    end
    return true
end

-- The game has just set an anchor of the column: it goes as far aside as the column was.
function P.ColumnReset(point)
    if pushing or wanted == 0 or (db and db.columnFixed) then return end
    if columnLocked() then
        -- Not now: this list alone steps aside on the next frame.
        if C_Timer and C_Timer.After and tracker and tracker.MarkDirty then C_Timer.After(0, function() tracker:MarkDirty() end) end
        return
    end
    pcall(pushColumn, wanted, point)
end

local function stepAside(self)
    local frame = ObjectiveTrackerFrame
    local now = barMargin(self)
    if db and db.columnFixed then
        if wanted ~= 0 and not columnLocked() and frame.GetNumPoints then
            if pcall(pushColumn, -wanted) then wanted = 0 end
        end
        return barMargin(self)
    end
    if not frame.GetNumPoints or columnLocked() then return now end
    if not hooked and hooksecurefunc then
        hooked = true
        -- Whatever anchor the game sets from now on is pushed as far as the column was.
        pcall(hooksecurefunc, frame, "SetPoint", function(_, point) P.ColumnReset(point) end)
    end
    if now >= -4 then
        if db then db.columnFault = nil end
        return now
    end
    -- Under the bars where it stands. As far under as it was ever pushed: the game has
    -- put it back, and the push starts over; less: a bar has grown, and it adds up.
    local total = (wanted ~= 0 and now <= wanted + 4) and now or (wanted + now)
    local ok, err = pcall(pushColumn, now)
    if ok then wanted = total end
    local left = barMargin(self)
    if left < -4 then
        columnFault(ok and (L"игра вернула его на место") or err)
        return left
    end
    if db then db.columnFault = nil end
    return math.min(0, left)
end

-- A click on a step does not throw the whole world map over the screen. A small card
-- beside the tracker says what the step is and where, and carries the buttons: the map,
-- the quest log, the arrow on and off.
local card
local function showCard(info)
    if not card then
        card = CreateFrame("Frame", "DungeonQuestForeverCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        card:SetFrameStrata("MEDIUM")
        card:SetWidth(290)
        card:SetClampedToScreen(true)
        card:EnableMouse(true)
        if card.SetBackdrop then
            card:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
            card:SetBackdropColor(.05, .05, .06, .94)
            card:SetBackdropBorderColor(.62, .52, .32, 1)
        end
        card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.title:SetPoint("TOPLEFT", 12, -11)
        card.title:SetWidth(244)
        card.title:SetJustifyH("LEFT")
        card.body = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        card.body:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
        card.body:SetWidth(266)
        card.body:SetJustifyH("LEFT")
        card.body:SetSpacing(2)
        local close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
        card.close = close
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() card:Hide() end)
        card.buttons = {}
        for i = 1, 3 do
            local button = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            button:SetSize(86, 22)
            card.buttons[i] = button
        end
        table.insert(UISpecialFrames, "DungeonQuestForeverCard")
    end
    card.info = info
    card.title:SetText(info.title)
    card.body:SetText(table.concat(info.lines, "\n"))
    local shown = 0
    for i, button in ipairs(card.buttons) do
        local action = info.actions[i]
        if action then
            shown = shown + 1
            button:SetText(action.text)
            button:SetScript("OnClick", action.run)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 11 + (i-1)*90, 10)
            button:Show()
        else
            button:Hide()
        end
    end
    card:SetHeight(11 + (card.title:GetStringHeight() or 14) + 6 + (card.body:GetStringHeight() or 14) + (shown > 0 and 42 or 12))
    card:ClearAllPoints()
    if tracker and tracker.Header then card:SetPoint("TOPRIGHT", tracker.Header, "TOPLEFT", -30, 0)
    else card:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
    card:Show()
end

-- The buttons under a step: the map, the quest log when the quest is in it, the arrow.
local function cardActions(place, questID, again)
    local actions = {}
    if place and place.mapID then
        actions[#actions+1] = {text=L"Карта", run=function()
            atlas.OpenMapAt(place.mapID)
        end}
    end
    if questID and P.IsActive(questID) then
        actions[#actions+1] = {text=L"Журнал", run=function() P.ShowQuest(questID) end}
    end
    if place then
        actions[#actions+1] = {text=db.arrowOff and (L"Стрелка") or (L"Без стрелки"), run=function()
            db.arrowOff = not db.arrowOff or nil
            P.TidyArrow()
            again()
        end}
    end
    return actions
end

local function openRoute(entry, noCard)
    P.Track("RouteRequested")
    if entry.boss then
        if db then db.planOff = nil end
        P.UpdatePlan(entry)
        return
    end
    -- Every step asked for brings the arrow back, even after it was put away.
    db.arrowOff = nil
    -- Another continent: the way as steps, the first of them where the arrow leads now,
    -- and what was weighed against it.
    local function far(yards)
        if not yards then return end
        if yards >= 1000 then return (L"%.1f км"):format(yards / 1000) end
        return (L"%d м"):format(math.floor(yards / 10 + .5) * 10)
    end
    local function crossing(lines, place, label)
        local hop = place and P.Plan and P.Plan(place)
        if not hop then return end
        -- The shortest way and nothing else: what to press, which platform, how far.
        lines[#lines+1] = hop.onFoot and (L"Дорога пешком (по прямой не пройти):") or (L"Короткий путь:")
        local n = 0
        local function step(text) n = n + 1; lines[#lines+1] = n .. ". " .. text end
        local function board(ride)
            local at
            if ride.pass then at = ""
            elseif ride.fly then at = " — " .. ride.point.from
            elseif ride.keeper then at = L" — платформа" .. (ride.up and (L" наверху вышки") or "") .. L", где " .. ride.keeper
            else at = " — " .. ride.point.from end
            step(ride.title .. at .. (ride.start and (", " .. far(ride.start)) or "")
                .. (ride.unsure and (L" (если эта точка у тебя открыта)") or ""))
        end
        if hop.legs then
            -- Every leg of the way in its order: a cast, a flight, a zeppelin.
            for _, leg in ipairs(hop.legs) do
                if leg.kind == "teleport" then step(L"Телепорт: " .. leg.city) else board(leg) end
            end
        else
            local ride = hop
            if hop.spell then
                step(L"Телепорт: " .. hop.city)
                ride = hop.next
            end
            if ride and ride.point then board(ride)
            elseif not hop.spell then step(hop.text) end
        end
        step((label or (L"цель")) .. (hop.rest and (", " .. far(hop.rest)) or ""))
    end
    if entry.entrance then
        -- The line clicked is the point wanted, whichever the arrow would take by itself.
        if entry.option and P.PickDoor then P.PickDoor(selected, entry.option.id); if P.Track then P.Track("DoorPicked") end end
        local point = P.Door(selected)
        if point then
            local name = P.DoorLabel(selected)
            P.Mark(point, name, "entrance")
            local function draw()
                local lines = {(point.label and (point.label .. " — ") or "") .. atlas.ZoneName(point.mapID) .. (" (%.0f, %.0f)"):format(point.x, point.y)}
                local way = P.Way and P.Way(selected)
                if way then lines[#lines+1] = way end
                crossing(lines, point, name)
                showCard({title=name, lines=lines, actions=cardActions(atlas.Target and atlas.Target() or point, nil, function() draw() end)})
            end
            draw()
        end
        P.Refresh()
        return
    end
    if bossTarget then
        db.bossTargets[selected.key] = nil
        P.Refresh()
    end
    if entry.secret then
        P.SecretRoute(entry)
    elseif P.InDungeon(selected) then
        -- Inside, a step opens the plan of the floor.
        say(P.Route(selected, entry))
    else
        local text, _, place = P.Route(selected, entry, false, true)
        local step = entry.step or entry.id
        local function draw()
            local lines = {}
            if entry.work then
                lines[1] = L"Сделать сейчас: " .. (entry.work.text or entry.note)
                lines[2] = entry.work.name .. " — " .. atlas.ZoneName(entry.work.mapID) .. (" (%.0f, %.0f)"):format(entry.work.x, entry.work.y)
            elseif entry.state == "active" and not entry.turnIn then
                lines[1] = L"В журнале: " .. entry.note
                if place then lines[2] = L"Цели в подземелье. Стрелка ведёт ко входу." end
            elseif entry.zone == "inside" then
                lines[1] = entry.note
                if place then lines[2] = L"Стрелка ведёт ко входу." end
            else
                lines[1] = place and (entry.detail or entry.note) or text
            end
            if entry.step ~= entry.id then lines[#lines+1] = L"Шаг цепочки к «" .. P.Title(entry.id) .. "»." end
            -- The chain whole, by steps, as in the quest book the owner likes.
            local chain, at, total = chainOf(entry.step ~= entry.id and entry.id or entry.leads or entry.id)
            if chain then
                lines[#lines+1] = L"Цепочка заданий (шаг " .. at .. L" из " .. total .. "):"
                for _, line in ipairs(chain) do lines[#lines+1] = line end
            end
            if entry.share and entry.state == "missing" and entry.step == entry.id then
                lines[#lines+1] = L"Заданием может поделиться участник группы."
            end
            crossing(lines, place, place and atlas.PlaceName(place))
            -- The map opens where the arrow leads now: the tower first, the place after.
            showCard({title=P.Title(step), lines=lines, actions=cardActions(atlas.Target and atlas.Target() or place, step, function() draw() end)})
        end
        -- Unfolded on the panel itself, the quest needs no window apart.
        if noCard then
            if card then card:Hide() end
        else
            draw()
        end
    end
    -- The page shows the leg under way, and the arrow follows the new point.
    P.Refresh()
end

-- The junk of the quest log, shown before anything is thrown away: the list, and two
-- buttons. Nothing is abandoned without the click.
function P.ShowJunk()
    local list = P.JunkQuests and P.JunkQuests() or {}
    if #list == 0 then
        showCard({title=L"Мусорных заданий нет", actions={},
            lines={L"Мусор — это серое по уровню задание, которое ты не начинал и которое не входит ни в какую цепочку.", L"Таких в журнале сейчас нет."}})
        return list
    end
    local lines = {L"Серые по уровню, не начаты, без цепочек, не из подземелий:"}
    for i, quest in ipairs(list) do
        if i <= 14 then lines[#lines+1] = ("|cff9d9d9d[%d]|r %s"):format(quest.level, quest.title) end
    end
    if #list > 14 then lines[#lines+1] = L"и ещё " .. (#list - 14) end
    lines[#lines+1] = L"|cffffa64dУбранное задание можно взять снова у того, кто его давал.|r"
    showCard({title=L"Мусорные задания: " .. #list, lines=lines, actions={
        {text=L"Убрать все", run=function()
            P.AbandonQuests(list)
            if card then card:Hide() end
            local function report()
                local left = P.StillInLog(list)
                local names = {}
                for _, quest in ipairs(list) do names[#names+1] = quest.title end
                if #left == 0 then say(L"Убрано заданий: " .. #list .. " — " .. table.concat(names, ", ") .. ".")
                elseif #left == #list then say(L"Игра не дала аддону убрать задания. Их придётся убрать руками в журнале: " .. table.concat(names, ", ") .. ".")
                else say(L"Убрано заданий: " .. (#list - #left) .. L" из " .. #list .. L". Остались: " .. #left .. ".") end
                if P.JunkChanged then P.JunkChanged() end
                P.Refresh()
            end
            if C_Timer and C_Timer.After then C_Timer.After(1.5, report) else report() end
        end},
        {text=L"Отмена", run=function() if card then card:Hide() end end},
    }})
    return list
end

-- The owner, getting the addon ready to be given to others: "make a first page of welcome,
-- for when a person installs it." Drawn for him as a mock-up, built here of the game's own
-- frame, icons and buttons: what the addon is for in a line, what it does in four, where to
-- begin in three steps, the author's address to copy when there is one, the switch of the
-- quests taken and handed in by themselves, and "Begin". Shown once to a character; /dq
-- welcome brings it back.
local AUTHOR_LINK = "github.com/localhost1989/DungeonQuestForever"      -- the page of the addon; the line is not shown when this is empty
local welcome
function P.ShowWelcome()
    if P.Track then P.Track("WelcomeShown") end
    if not welcome then
        local W, H = 560, 440
        local ok, frame = pcall(CreateFrame, "Frame", "DungeonQuestForeverWelcome", UIParent, "BasicFrameTemplateWithInset")
        if not (ok and frame) then frame = CreateFrame("Frame", "DungeonQuestForeverWelcome", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil) end
        welcome = frame
        frame:SetSize(W, H)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        if frame.SetBackdrop and not frame.TitleText and not frame.Inset then
            frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
            frame:SetBackdropColor(.05, .04, .03, .96)
        end
        local head = (type(frame.TitleText) == "table" and frame.TitleText.SetText and frame.TitleText) or frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if head ~= frame.TitleText then head:SetPoint("TOP", frame, "TOP", 0, -8) end
        head:SetText(title)
        frame.head = head
        local why = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        why:SetPoint("TOP", frame, "TOP", 0, -38)
        why:SetWidth(W - 60)
        why:SetText(L"Готовит тебя к подземелью прямо в колонке заданий.")
        frame.why = why
        -- What it does: four lines, each with an icon of the game.
        local does = {
            {"Interface\\Icons\\INV_Misc_Note_01", L"Показывает, какие задания взять перед подземельем, и ведёт по цепочкам."},
            {"Interface\\Icons\\INV_Misc_Map_01", L"Стрелка ведёт короткой дорогой: перелёты, дирижабли, телепорты и проходы между зонами."},
            {"Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", L"Внутри подземелья — боссы по порядку и их добыча с пометкой лучшего для твоего класса."},
            {"Interface\\Icons\\INV_Misc_Gear_01", L"Сам принимает и сдаёт задания и убирает мусорные."},
        }
        frame.lines = {}
        for i, item in ipairs(does) do
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(26, 26)
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -66 - (i - 1) * 36)
            icon:SetTexture(item[1])
            local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", icon, "RIGHT", 12, 0)
            text:SetWidth(W - 100)
            text:SetJustifyH("LEFT")
            text:SetText(item[2])
            frame.lines[i] = text
        end
        -- Where to begin: three steps in a frame of their own.
        local box = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -216)
        box:SetSize(W - 48, 108)
        if box.SetBackdrop then
            box:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=14, insets={left=3, right=3, top=3, bottom=3}})
            box:SetBackdropColor(.12, .09, .04, .9)
            box:SetBackdropBorderColor(.85, .68, .3, 1)
        end
        local begin = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        begin:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -10)
        begin:SetText(L"С чего начать")
        frame.begin = begin
        local steps = {
            L"В заголовке панели нажми ••• и выбери подземелье.",
            L"Щёлкни по заданию — оно раскроется и поставит стрелку.",
            L"Нажми «Журнал» — откроется книга с боссами и добычей.",
        }
        frame.steps = {}
        for i, text in ipairs(steps) do
            local line = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            line:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -34 - (i - 1) * 22)
            line:SetWidth(W - 84)
            line:SetJustifyH("LEFT")
            line:SetText("|cffffd100" .. i .. ".|r " .. text)
            frame.steps[i] = line
        end
        -- The author's address, in a box to copy from.
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -340)
        label:SetText(L"Страница аддона:")
        local link = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        link:SetSize(W - 190, 22)
        link:SetPoint("LEFT", label, "RIGHT", 14, 0)
        if link.SetAutoFocus then link:SetAutoFocus(false) end
        link:SetScript("OnEditFocusGained", function(self) if self.HighlightText then self:HighlightText() end end)
        link:SetScript("OnTextChanged", function(self) if self.address and self.GetText and self:GetText() ~= self.address then self:SetText(self.address) end end)
        link:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
        frame.siteLabel, frame.site = label, link
        -- The quests by themselves, on or off.
        local auto = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        auto:SetSize(26, 26)
        auto:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
        auto.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        auto.label:SetPoint("LEFT", auto, "RIGHT", 4, 0)
        auto.label:SetText(L"Принимать и сдавать задания самому")
        auto:SetScript("OnClick", function(self)
            local on = self.GetChecked and self:GetChecked()
            db.noAuto = (not on) or nil
        end)
        frame.auto = auto
        local go = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        go:SetSize(130, 26)
        go:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 18)
        go:SetText(L"Начать")
        go:SetScript("OnClick", function() frame:Hide() end)
        frame.go = go
        frame:SetScript("OnHide", function() if db then db.welcomed = true end end)
        frame.bug = P.BugButton(frame)
        frame.bug:SetPoint("RIGHT", go, "LEFT", -10, 0)
        table.insert(UISpecialFrames, "DungeonQuestForeverWelcome")
    end
    local address = AUTHOR_LINK ~= "" and AUTHOR_LINK or (db and type(db.authorLink) == "string" and db.authorLink ~= "" and db.authorLink) or nil
    welcome.site.address = address
    welcome.site:SetText(address or "")
    welcome.site:SetShown(address ~= nil)
    welcome.siteLabel:SetShown(address ~= nil)
    if welcome.auto.SetChecked then welcome.auto:SetChecked(not (db and db.noAuto)) end
    welcome.auto.checked = not (db and db.noAuto)
    welcome:Show()
    return welcome
end

-- The owner, with the addon about to go out to others: "people may want to write; one can
-- report a bug - add some bug, so that people can report it." An addon cannot open a page
-- or send anything, so: a window with the address to write to, to copy, and under it a
-- few lines about the game and the addon as they are now, to copy into the report. Behind
-- the little bug on the page of welcome, the last line of the menu behind the three dots,
-- and /dq bug.
local bugs
function P.BugLines()
    local function meta(field)
        local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ok, value = pcall(read or function() end, "ForeverDungeonPrep", field)
        return ok and value or "?"
    end
    local build = "?"
    if GetBuildInfo then
        local version, number, _, interface = GetBuildInfo()
        build = tostring(version) .. " (" .. tostring(number) .. ", " .. tostring(interface) .. ")"
    end
    local class = (UnitClassBase and UnitClassBase("player")) or (UnitClass and select(2, UnitClass("player"))) or "?"
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local lines = {
        "Dungeon Quest Forever " .. tostring(meta("Version")) .. " | game " .. build .. " | " .. tostring(GetLocale and GetLocale() or "?"),
        tostring(UnitFactionGroup and UnitFactionGroup("player") or "?") .. " " .. tostring(class) .. " " .. tostring(UnitLevel and UnitLevel("player") or "?")
            .. " | map " .. tostring(here) .. (IsInInstance and IsInInstance() and " (inside)" or "")
            .. " | dungeon " .. tostring(selected and selected.key or "-") .. (browsing and " (list)" or ""),
        "panel: " .. (nativeLook() and "quests look" or "cards") .. (tracker and tracker.docked and ", in the tracker" or ", free")
            .. (db and db.dockFault and (" | dock fault: " .. tostring(db.dockFault)) or "")
            .. " | auto quests " .. ((db and db.noAuto) and "off" or "on"),
    }
    -- The last steps of the hands that take and hand in quests, where the report is about them.
    local log = db and type(db.handsLog) == "table" and db.handsLog or {}
    for i = math.max(1, #log - 3), #log do lines[#lines+1] = "hands: " .. tostring(log[i]) end
    return lines
end
function P.ShowBugReport()
    if not bugs then
        local W = 520
        local ok, frame = pcall(CreateFrame, "Frame", "DungeonQuestForeverBug", UIParent, "BasicFrameTemplateWithInset")
        if not (ok and frame) then frame = CreateFrame("Frame", "DungeonQuestForeverBug", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil) end
        bugs = frame
        frame:SetSize(W, 300)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        if frame.SetBackdrop and not frame.TitleText and not frame.Inset then
            frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
            frame:SetBackdropColor(.05, .04, .03, .96)
        end
        local head = (type(frame.TitleText) == "table" and frame.TitleText.SetText and frame.TitleText) or frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if head ~= frame.TitleText then head:SetPoint("TOP", frame, "TOP", 0, -8) end
        head:SetText(L"Сообщить об ошибке")
        frame.head = head
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -36)
        icon:SetTexture("Interface\\HelpFrame\\HelpIcon-Bug")
        local say1 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        say1:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
        say1:SetWidth(W - 90)
        say1:SetJustifyH("LEFT")
        say1:SetText(L"Что-то работает не так или есть идея? Напиши на странице аддона. Адрес можно выделить и скопировать (Ctrl+C):")
        frame.say = say1
        local function box(height)
            local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            edit:SetSize(W - 56, height)
            if edit.SetAutoFocus then edit:SetAutoFocus(false) end
            edit:SetScript("OnEditFocusGained", function(self) if self.HighlightText then self:HighlightText() end end)
            edit:SetScript("OnTextChanged", function(self) if self.keep and self.GetText and self:GetText() ~= self.keep then self:SetText(self.keep) end end)
            edit:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
            return edit
        end
        frame.link = box(22)
        frame.link:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -84)
        local say2 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        say2:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -118)
        say2:SetWidth(W - 48)
        say2:SetJustifyH("LEFT")
        say2:SetText(L"И приложи эти строки — по ним видно, что у тебя за игра и что делал аддон:")
        frame.say2 = say2
        frame.report = box(22)
        frame.report:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -144)
        frame.preview = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        frame.preview:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -174)
        frame.preview:SetWidth(W - 52)
        frame.preview:SetJustifyH("LEFT")
        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(120, 24)
        close:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
        close:SetText(L"Закрыть")
        close:SetScript("OnClick", function() frame:Hide() end)
        frame.close = close
        table.insert(UISpecialFrames, "DungeonQuestForeverBug")
    end
    local lines = P.BugLines()
    if not bugs:IsShown() or not bugs.opened then P.Track("ReportOpened") end
    bugs.opened = true
    bugs.link.keep = "https://" .. AUTHOR_LINK .. "/issues/new"
    bugs.link:SetText(bugs.link.keep)
    -- One line to copy (a box of the game holds one line); the same below, to read.
    bugs.report.keep = table.concat(lines, " || ")
    bugs.report:SetText(bugs.report.keep)
    bugs.preview:SetText(table.concat(lines, "\n"))
    bugs:Show()
    return bugs
end
-- The little bug: a button that opens that window, for a corner of a window of the addon.
function P.BugButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetNormalTexture("Interface\\HelpFrame\\HelpIcon-Bug")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function() P.ShowBugReport() end)
    b:SetScript("OnEnter", function() tip(b, L"Сообщить об ошибке", L"Откроет окно с адресом, куда написать, и строками для отчёта.") end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- The owner: "make a little circle on the minimap for our addon, to open the settings."
-- A round button on the rim of the minimap, as other addons have: the hand of the
-- character's faction in the game's round frame. A click opens the settings as a menu
-- of the game; the right button opens the journal; dragged, it goes round the rim and
-- stays where it is left. /dq minimap hides it and brings it back.
local minimapButton
local function settingsMenu(owner, menu)
    if not db then return end
    local function slash(word) return function() SlashCmdList.FOREVERDUNGEONPREP(word) end end
    if menu.CreateTitle then menu:CreateTitle(title) end
    menu:CreateButton(L"Журнал: задания, боссы, добыча", function() if P.ToggleBook then P.ToggleBook(not browsing and selected or nil) end end)
    menu:CreateButton(L"Список подземелий", slash(""))
    menu:CreateButton(L"Лучшие вещи для класса", function() if P.ToggleGear then P.ToggleGear() end end)
    if menu.CreateDivider then menu:CreateDivider() end
    if menu.CreateTitle then menu:CreateTitle(L"Настройки") end
    menu:CreateCheckbox(L"Принимать и сдавать задания самому", function() return not db.noAuto end, slash("auto"))
    menu:CreateCheckbox(L"Панель в колонке заданий", function() return not db.boardFree end, slash("dock"))
    menu:CreateCheckbox(L"Вид как у заданий игры", function() return not db.boardCards end, slash("cards"))
    menu:CreateCheckbox(L"Тёмный фон панели", function() return db.boardBack == true end, slash("back"))
    menu:CreateCheckbox(L"Сигнал при входе в зал", function() return not db.noPing end, slash("ping"))
    menu:CreateCheckbox(L"Подсвечивать предметы для заданий", function() return not db.noGlow end, slash("glow"))
    menu:CreateCheckbox(L"Рассказывать группе и рейду об аддоне", function() return not db.noShare end, slash("share"))
    menu:CreateCheckbox(L"Вести стрелку по дорогам, в обход гор", function() return not db.noPaths end, slash("paths"))
    menu:CreateCheckbox(L"Метка над нужным персонажем", function() return not db.noSign end, slash("sign"))
    menu:CreateCheckbox(L"Кнопка у миникарты", function() return not db.minimapHidden end, slash("minimap"))
    if menu.CreateDivider then menu:CreateDivider() end
    menu:CreateButton(L"Убрать мусорные задания", slash("junk"))
    menu:CreateButton(L"Страница приветствия", slash("welcome"))
    menu:CreateButton("|TInterface\\HelpFrame\\HelpIcon-Bug:16|t " .. L"Сообщить об ошибке", slash("bug"))
end
P.SettingsMenu = settingsMenu

local function placeMinimapButton()
    if not (minimapButton and Minimap) then return end
    local angle = math.rad(tonumber(db and db.minimapAngle) or 200)
    local width = Minimap.GetWidth and Minimap:GetWidth() or 140
    local radius = (type(width) == "number" and width or 140) / 2 + 6
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function P.MinimapButton()
    if not (Minimap and CreateFrame) then return end
    if not minimapButton then
        local b = CreateFrame("Button", "DungeonQuestForeverMinimapButton", Minimap)
        minimapButton = b
        b:SetSize(31, 31)
        b:SetFrameStrata("MEDIUM")
        if b.SetFrameLevel and Minimap.GetFrameLevel then b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8) end
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b.back = b:CreateTexture(nil, "BACKGROUND")
        b.back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        b.back:SetSize(20, 20)
        b.back:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        local hand = faction == "Horde" and "hand_horde" or "hand_alliance"
        b.icon:SetTexture("Interface\\AddOns\\ForeverDungeonPrep\\" .. hand)
        local got = b.icon:GetTexture()
        if not (got ~= nil and got ~= 0 and got ~= "") then b.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09") end
        b.iconFile = b.icon.GetTexture and b.icon:GetTexture()
        b.border = b:CreateTexture(nil, "OVERLAY")
        b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        b.border:SetSize(53, 53)
        b.border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
        b.openMenu = settingsMenu
        b:SetScript("OnClick", function(self, mouse)
            GameTooltip:Hide()
            if mouse == "RightButton" then
                if P.ToggleBook then P.ToggleBook(not browsing and selected or nil) end
            elseif MenuUtil and MenuUtil.CreateContextMenu then
                if P.Track then P.Track("SettingsMenuOpened") end
                MenuUtil.CreateContextMenu(self, settingsMenu)
            else
                SlashCmdList.FOREVERDUNGEONPREP("")
            end
        end)
        b:SetScript("OnEnter", function(self)
            tip(self, title, L"Щелчок — настройки.\nПравая кнопка — журнал.\nТащи, чтобы переставить вокруг миникарты.")
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Dragged round the rim: the angle of the cursor from the centre of the minimap.
        local function follow()
            local cx, cy = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            if not (cx and x and scale) then return end
            db.minimapAngle = math.floor(math.deg(math.atan2 and math.atan2(y / scale - cy, x / scale - cx) or math.atan(y / scale - cy, x / scale - cx)) + .5)
            placeMinimapButton()
        end
        b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
        b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    end
    placeMinimapButton()
    minimapButton:SetShown(not (db and db.minimapHidden))
    return minimapButton
end

-- And when what the game lights is a thing a quest in the log asks for, it is said: a
-- sound, and a line in the middle of the screen with the quest. Known for the quests the
-- addon has data of (the dungeons' and their chains').
-- The quests in the log not done yet, by id.
local function openQuests()
    local open = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return open end
    local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
    for i = 1, ok and tonumber(count) or 0 do
        local okInfo, info = pcall(C_QuestLog.GetInfo, i)
        local id = okInfo and type(info) == "table" and not info.isHeader and info.questID
        if id and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) then open[id] = true end
    end
    return open
end
-- The quest in the log an object is wanted for: by the index of every quest of the
-- database (P.ObjectUses: the object asked for, or the one an asked-for item comes out
-- of), and by the quests of the dungeons besides.
local function wantedFor(object)
    local open = openQuests()
    for _, quest in ipairs(P.ObjectUses and P.ObjectUses[object] or {}) do
        if open[quest] then return quest end
    end
    for quest in pairs(open) do
        local objectives = P.QuestDB and P.QuestDB.Get(quest, "objectives")
        if type(objectives) == "table" then
            for _, o in ipairs(objectives[2] or {}) do if o[1] == object then return quest end end
            for _, item in ipairs(objectives[3] or {}) do
                for _, o in ipairs(P.ItemDB.Get(item[1], "objectDrops") or {}) do if o == object then return quest end end
            end
        end
    end
end
P.WantedFor = wantedFor
local glowSaid = {}
function P.SoftTargetChanged(guid)
    if not db or db.noGlow then return end
    local raw = guid or (UnitGUID and UnitGUID("softinteract"))
    local id = atlas.ObjectIDFromGUID(raw)
    -- Inside a dungeon the game may not tell an addon which thing is in sight (its number
    -- is a "secret"), and the things there are mostly the run's own: the game's icon goes
    -- over every one. (The owner, at the quest's book in the Library: "I did not see the
    -- light.")
    local inside = IsInInstance and IsInInstance()
    local secret = raw ~= nil and issecretvalue and issecretvalue(raw)
    if inside and raw ~= nil and (secret or id) then
        if atlas.QuestObjectIcon then atlas.QuestObjectIcon(true) end
        if secret then
            -- The owner, at the gong that calls Tuten'kash out: "the gong does not light up; I
            -- told you to light the quest things." What it is goes untold in here, and what
            -- can be used in a dungeon is mostly the run's (a gong, a chest, a quest thing):
            -- the hand hangs over it. Not over a creature: "the hand comes when I loot a mob,
            -- that is not right; only over things to pick up." A creature, alive or dead, has
            -- a kind or is dead (told or secret, the answer is there); a thing has neither.
            local creature = false
            for _, ask in ipairs({UnitCreatureType, UnitIsDead, UnitIsPlayer}) do
                local ok, said = pcall(ask, "softinteract")
                if ok and said ~= nil and said ~= false then creature = true break end
            end
            if atlas.ObjectSign then atlas.ObjectSign(not creature, creature and "inside, a creature" or "inside, the thing not told") end
            return
        end
    end
    local quest = id and wantedFor(id)
    -- The game's icon over it only if a quest wants it: not over chairs and mailboxes;
    -- and the hand over it, as over a boss.
    if atlas.QuestObjectIcon then atlas.QuestObjectIcon(quest ~= nil or (inside and id ~= nil)) end
    if atlas.ObjectSign then atlas.ObjectSign(quest ~= nil or (inside and id ~= nil), id and ("object " .. id .. " quest " .. tostring(quest or "-")) or nil) end
    if not quest then return end
    local now = GetTime and GetTime() or 0
    if glowSaid[id] and now - glowSaid[id] < 30 then return end
    glowSaid[id] = now
    local name = (P.ObjectDB and P.ObjectDB.Get(id, "name")) or (UnitName and UnitName("softinteract")) or "?"
    local title = P.Title(quest) or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(quest)) or "?"
    local text = L"Вот оно: " .. name .. L" — для «" .. title .. "»"
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or {r=1, g=.82, b=.3})
    end
    P.lastGlow = text
    return text
end
if CreateFrame and UIParent then
    local soft = CreateFrame("Frame", "DungeonQuestForeverGlow", UIParent)
    pcall(soft.RegisterEvent, soft, "PLAYER_SOFT_INTERACT_CHANGED")
    -- A quest taken or done while the object is in sight: weighed again (the sound is not
    -- rung twice in half a minute).
    pcall(soft.RegisterEvent, soft, "QUEST_LOG_UPDATE")
    -- (The switches wait out a fight: weighed again at its end.)
    pcall(soft.RegisterEvent, soft, "PLAYER_REGEN_ENABLED")
    soft:SetScript("OnEvent", function(_, event, _, newTarget)
        if event == "PLAYER_SOFT_INTERACT_CHANGED" then pcall(P.SoftTargetChanged, newTarget) else pcall(P.SoftTargetChanged) end
    end)
end

-- A room walked into where a quest taken wants something: said in the middle of the screen.
if CreateFrame and UIParent then
    local rooms = CreateFrame("Frame", "DungeonQuestForeverRooms", UIParent)
    pcall(rooms.RegisterEvent, rooms, "ZONE_CHANGED_INDOORS")
    pcall(rooms.RegisterEvent, rooms, "ZONE_CHANGED")
    pcall(rooms.RegisterEvent, rooms, "ZONE_CHANGED_NEW_AREA")
    rooms:SetScript("OnEvent", function(_, event)
        if event == "ZONE_CHANGED_NEW_AREA" and P.RoomNewsReset then P.RoomNewsReset() end
        local d = atlas.CurrentDungeon and atlas.CurrentDungeon()
        if d and P.RoomNews then pcall(P.RoomNews, d) end
        if d and P.Refresh then pcall(P.Refresh) end
    end)
end

function P.Selected() return selected, result end
function P.OpenRow(row) openRoute(row) end
function P.Choose(d) choose(d) end
-- The dungeon on the panel put away (the owner, 16.11.2026: "hide the dungeons I do not want
-- to finish any more", by the right button in the journal or in the menu behind the dots):
-- the panel goes on to the best one left, as on coming in, or to the list when none is.
function P.LeaveHidden()
    if not (db and db.hidden and selected and db.hidden[selected.key]) then return end
    countsDirty = true
    rebuildList()
    local level = UnitLevel and UnitLevel("player") or 1
    local best, bestScore
    for _, d in ipairs(visible) do
        if d.key and not db.hidden[d.key] then
            local score = -math.max(0, (d.minLevel or level) - level, level - (d.maxLevel or level))
            for _, id in ipairs(d.quests or {}) do
                local idx = C_QuestLog.GetLogIndexForQuestID(id)
                if idx and idx > 0 then score = score + 100 end
            end
            if not best or score > bestScore then best, bestScore = d, score end
        end
    end
    if best then choose(best) else browse() end
end

local SHORT_DOOR = {[L"Ко входу"]=L"Вход", [L"К порталу"]=L"Портал", [L"К телепорту"]=L"Телепорт", [L"К выходу"]=L"Выход"}
local DOOR_ICON = {Horde="Interface\\Icons\\INV_Misc_Map_01", Alliance="Interface\\Icons\\INV_Misc_Map_01"}   -- (ChatGPT's choice: the map of the way)

-- The way in, in the header: a strip of buttons under the name of the dungeon, one for
-- each point of the road with the distance to it. The one the arrow leads to is gold.
-- A click sets the arrow on that point.
local function navButton(nav, i)
    local button = nav.buttons[i]
    if button then return button end
    -- Seen in the game as two words in a row, they did not read as buttons: each gets a
    -- dark plate with a thin border, gold on the one in force.
    button = CreateFrame("Button", nil, nav, BackdropTemplateMixin and "BackdropTemplate" or nil)
    nav.buttons[i] = button
    button:SetHeight(22)
    if button.SetBackdrop then
        button:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=8, edgeSize=10, insets={left=2, right=2, top=2, bottom=2}})
        button:SetBackdropColor(0, 0, 0, .8)
    end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if ownFonts().button then pcall(button.label.SetFontObject, button.label, ownFonts().button) end
    button.label:SetPoint("LEFT", 8, 0)
    function button:Plate(on)
        if self.SetBackdropBorderColor then
            if on then self:SetBackdropBorderColor(1, .82, .3, 1) else self:SetBackdropBorderColor(.45, .45, .45, .8) end
        end
    end
    -- In the look of the game's quests a button is a word in a row of words: no plate.
    function button:Plain(on)
        if self.icon then self.icon:Hide() end
        if self.pill then
            self.pillOn = nil
            local glow = self.GetHighlightTexture and self:GetHighlightTexture()
            if glow and glow.SetAlpha then glow:SetAlpha(1) end
            for _, t in pairs({self.pill.outer, self.pill.fill, self.pill.shine, self.pill.shade, self.pill.iconFrame, self.pill.iconBack}) do t:Hide() end
            for _, t in ipairs(self.pill.inner) do t:Hide() end
        end
        if self.SetBackdrop and self.pillBackdrop ~= false then
            self:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=8, edgeSize=10, insets={left=2, right=2, top=2, bottom=2}})
        end
        if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, on and 0 or .8) end
        if on and self.SetBackdropBorderColor then self:SetBackdropBorderColor(0, 0, 0, 0) end
        local font = on and ownFonts().sub or ownFonts().button
        if font then pcall(self.label.SetFontObject, self.label, font) end
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", on and 0 or 8, 0)
        self:SetHeight(on and 16 or 22)
        if not on then self.link, self.linkTip = nil, nil end
    end
    -- The layout of 15.11.2026 (ChatGPT's, variant A, approved), by its code: three
    -- equal buttons 84 x 28 across the column, 4 apart; a ground going from dark red down
    -- to near black, an outer rim of gold, an inner one darker, a light line on top; the
    -- picture 20 x 20 in a frame of its own, then the word, the pair in the middle.
    -- (art/код-макет-14.11/кнопки-заголовка-размеры-и-цвета.txt)
    local function rgb(h) return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 end
    function button:PillLook(hot)
        local p = self.pill
        if not p then return end
        local top, bottom = hot and "81381F" or "522719", hot and "2E110B" or "1C0B08"
        local done = false
        if p.fill.SetGradient and CreateColor then
            local r1, g1, b1 = rgb(bottom)
            local r2, g2, b2 = rgb(top)
            p.fill:SetColorTexture(1, 1, 1, 1)
            done = pcall(p.fill.SetGradient, p.fill, "VERTICAL", CreateColor(r1, g1, b1, 1), CreateColor(r2, g2, b2, 1))
        end
        if not done then p.fill:SetColorTexture(rgb(hot and "592210" or "3B180E")) end
        p.outer:SetColorTexture(rgb(hot and "FFE0A0" or "B28B50"))
        p.iconFrame:SetColorTexture(rgb(hot and "FFE0A0" or "99703B"))
        local r, g, b = rgb((hot or self.leads) and "FFF3CE" or "F5CE72")
        self.label:SetTextColor(r, g, b)
    end
    function button:Pill(icon)
        if not self.pill then
            local p = {}
            local function tex(layer, sub) return self:CreateTexture(nil, layer, nil, sub) end
            p.outer = tex("BACKGROUND", 1)
            p.outer:SetAllPoints()
            p.fill = tex("BACKGROUND", 2)
            p.fill:SetPoint("TOPLEFT", 1, -1)
            p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
            p.inner = {}
            for k = 1, 4 do p.inner[k] = tex("BORDER", 1); p.inner[k]:SetColorTexture(rgb(k == 1 and "8F6137" or "674222")) end
            p.inner[1]:SetPoint("TOPLEFT", 2, -2); p.inner[1]:SetPoint("TOPRIGHT", -2, -2); p.inner[1]:SetHeight(1)
            p.inner[2]:SetPoint("BOTTOMLEFT", 2, 2); p.inner[2]:SetPoint("BOTTOMRIGHT", -2, 2); p.inner[2]:SetHeight(1)
            p.inner[3]:SetPoint("TOPLEFT", 2, -2); p.inner[3]:SetPoint("BOTTOMLEFT", 2, 2); p.inner[3]:SetWidth(1)
            p.inner[4]:SetPoint("TOPRIGHT", -2, -2); p.inner[4]:SetPoint("BOTTOMRIGHT", -2, 2); p.inner[4]:SetWidth(1)
            p.shine = tex("BORDER", 2)
            p.shine:SetColorTexture(rgb("E2B96E"))
            p.shine:SetPoint("TOPLEFT", 1, -1); p.shine:SetPoint("TOPRIGHT", -1, -1); p.shine:SetHeight(1)
            p.shade = tex("BORDER", 2)
            p.shade:SetColorTexture(rgb("130805"))
            p.shade:SetPoint("BOTTOMLEFT", 1, 1); p.shade:SetPoint("BOTTOMRIGHT", -1, 1); p.shade:SetHeight(1)
            p.iconFrame = tex("ARTWORK", 1)
            p.iconFrame:SetSize(20, 20)
            p.iconBack = tex("ARTWORK", 2)
            p.iconBack:SetColorTexture(rgb("130B08"))
            p.iconBack:SetPoint("TOPLEFT", p.iconFrame, "TOPLEFT", 1, -1)
            p.iconBack:SetPoint("BOTTOMRIGHT", p.iconFrame, "BOTTOMRIGHT", -1, 1)
            self.icon = tex("ARTWORK", 3)
            self.icon:SetPoint("TOPLEFT", p.iconFrame, "TOPLEFT", 1, -1)
            self.icon:SetPoint("BOTTOMRIGHT", p.iconFrame, "BOTTOMRIGHT", -1, 1)
            if self.icon.SetTexCoord then self.icon:SetTexCoord(.08, .92, .08, .92) end
            self.pill = p
            self:HookScript("OnEnter", function(b) if b.pillOn then b:PillLook(true) end end)
            self:HookScript("OnLeave", function(b) if b.pillOn then b:PillLook(false) end end)
        end
        local p = self.pill
        if self.SetBackdrop then self:SetBackdrop(nil) end
        for _, t in pairs({p.outer, p.fill, p.shine, p.shade, p.iconFrame, p.iconBack}) do t:Show() end
        for _, t in ipairs(p.inner) do t:Show() end
        self.pillOn = true
        -- (Hovered, it lights by its own colours, not the square glow of the game.)
        local glow = self.GetHighlightTexture and self:GetHighlightTexture()
        if glow and glow.SetAlpha then glow:SetAlpha(0) end
        local font = ownFonts().button
        if font then pcall(self.label.SetFontObject, self.label, font) end
        if self.label.SetShadowOffset then self.label:SetShadowOffset(1, -1) end
        self.icon:SetTexture(icon)
        self.icon:SetShown(icon ~= nil)
        p.iconFrame:SetShown(icon ~= nil)
        p.iconBack:SetShown(icon ~= nil)
        self:SetHeight(28)
        self:PillLook(false)
    end
    -- The icon and the word stand together in the middle of the button.
    function button:PillCentre()
        local p = self.pill
        if not p then return end
        local words = tonumber(self.label:GetStringWidth()) or 40
        local whole = (self.icon:IsShown() and (20 + 4) or 0) + words
        local left = math.max(4, ((tonumber(self:GetWidth()) or 84) - whole) / 2)
        p.iconFrame:ClearAllPoints()
        p.iconFrame:SetPoint("LEFT", self, "LEFT", left, 0)
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", self, "LEFT", left + (self.icon:IsShown() and 24 or 0), 0)
    end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", function()
        if button.link then
            button.link()
        elseif button.choice then
            button.choice.set()
            if button.choice.page then P.Refresh() elseif P.RefreshFilters then P.RefreshFilters() end
        elseif button.option and tracker then
            tracker:OnBlockHeaderClick({entry={entrance=true, option=button.option}}, "LeftButton")
        end
    end)
    button:SetScript("OnEnter", function()
        local self = button
        if self.link then tip(self, self.text, self.linkTip) return end
        if self.choice then tip(self, self.choice.text, self.choice.note) return end
        local option = self.option
        if not option then return end
        local notes = {}
        local under = option.point.todo or option.point.note or option.point.hint
        if under then notes[#notes+1] = under end
        local way = P.Way and P.Way(selected)
        if way then notes[#notes+1] = way end
        notes[#notes+1] = L"Щелчок ставит стрелку на эту точку."
        tip(self, option.label or option.title or (L"Вход"), table.concat(notes, "\n"))
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- The owner asked for the look of the game's own quests, and the mock-up drawn for him
-- has, under the heading of the section, one row of words: "• Ко входу • К порталу •
-- Журнал • Список". Each is a click: the doors set the arrow, the journal opens the book,
-- the list goes back to the dungeons. The one the arrow leads to is white.
local function linkRow(self, items)
    local nav = self.nav
    -- Three to a row across the column, 4 apart (84 x 28 in a column of 260); a long word
    -- ("Поделиться") takes the room it needs and the others share the rest.
    local room = (tonumber(self.GetWidth and self:GetWidth()) or 260) - 4
    local rows = {}
    -- Three to a row; four or more that do not fit one row are shared out evenly (2 + 2).
    local perRow = math.ceil(#items / math.max(1, math.ceil(#items / 3)))
    local naturalSum = 0
    for i, item in ipairs(items) do
        local button = navButton(nav, i)
        button:Plain(false)
        button.option, button.choice, button.link, button.linkTip = item.option, nil, item.link, item.tip
        button.text, button.leads = item.text, item.lit and true or false
        button:Pill(item.icon)
        button.label:SetText(item.text)
        button.natural = (tonumber(button.label:GetStringWidth()) or 50) + (item.icon and 24 or 0) + 12
        naturalSum = naturalSum + button.natural
    end
    if naturalSum + 4 * (#items - 1) <= room then perRow = math.max(1, #items) end
    if #items == 4 and naturalSum + 12 > room then perRow = 2 end
    for i = 1, #items do
        local r = math.floor((i - 1) / perRow) + 1
        rows[r] = rows[r] or {}
        table.insert(rows[r], nav.buttons[i])
    end
    for r, list in ipairs(rows) do
        local sum = 0
        for _, b in ipairs(list) do sum = sum + b.natural end
        local free = room - 4 * (#list - 1)
        local left = 0
        for _, b in ipairs(list) do
            local w = (sum <= free) and (b.natural + (free - sum) / #list) or (b.natural * free / sum)
            w = math.floor(w)
            b:SetWidth(w)
            b:PillCentre()
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", nav, "TOPLEFT", left, -(r - 1) * 32)
            b:Show()
            left = left + w + 4
        end
    end
    for i = #items + 1, #nav.buttons do nav.buttons[i]:Hide() end
    nav:SetShown(#items > 0)
    local rows = #rows
    nav.rows = rows
    self.fromHeaderOffsetY = #items > 0 and -(12 + (rows - 1) * 32 + 28) or -6
end

local function drawNav(self, options)
    local nav = self.nav
    if not nav then return end
    local target = atlas.Target and atlas.Target()
    if self.isBoard and nativeLook() then
        local items = {}
        for _, option in ipairs(options) do
            local point = option.point
            local leads = target and target.mapID == point.mapID and target.x == point.x and target.y == point.y
            -- The doors by one word on the button: "Вход", "Портал", "Телепорт", "Выход".
            local word = option.short or (L"Ко входу")
            word = SHORT_DOOR[word] or word
            items[#items+1] = {text=word, option=option, lit=leads, icon=DOOR_ICON[UnitFactionGroup and UnitFactionGroup("player") or ""] or DOOR_ICON.Horde}
        end
        if not browsing and selected and not self:IsCollapsed() and not compact then
            items[#items+1] = {text=L"Журнал", tip=L"Книга: все задания и боссы подземелья, добыча боссов.", icon="Interface\\Icons\\INV_Misc_Book_07",
                link=function() if P.ToggleBook then P.ToggleBook(selected) end end}
            -- The owner: "one button on top: share all the quests with the group, and ask
            -- them to share the ones missing; and our addon's word goes in there."
            -- (Always shown: alone it was nowhere to be found; out of a group it says so.)
            if P.ShareWithGroup then
                -- The owner: "it says Group; share - where is the sign of sharing?" The word
                -- says what it does, the scroll of a quest by it.
                items[#items+1] = {text=L"Поделиться", tip=L"Поделиться с группой всеми заданиями этого подземелья, что у тебя в журнале, и попросить в чате группы недостающие. Аддон у других поделится ими сам.",
                    icon="Interface\\Icons\\INV_Scroll_03", link=function() P.ShareWithGroup() end}
            end
            -- The owner: "a button in sight, and by it the best things for my class." The
            -- window of them, as ChatGPT drew it: the fourth word of the row.
            if P.ToggleGear then
                items[#items+1] = {text=L"Вещи", tip=L"Лучшие вещи для твоего класса и ветки талантов на твоём уровне и дальше: где каждая падает или за какое задание даётся.",
                    icon="Interface\\Icons\\INV_Chest_Cloth_17", link=function() P.ToggleGear() end}
            end
        end
        -- The junk in the quest log, when there is any: a word that opens the list of it.
        local junk = not compact and not self:IsCollapsed() and P.JunkCount and P.JunkCount() or 0
        if junk > 0 then
            items[#items+1] = {text=L"Мусор: " .. junk, tip=L"Серые неначатые задания без цепочек. Щелчок покажет список и спросит, убрать ли их.",
                icon="Interface\\Icons\\INV_Misc_Bag_10", link=function() if P.ShowJunk then P.ShowJunk() end end}
        end
        linkRow(self, items)
        return
    end
    for _, button in ipairs(nav.buttons) do button:Plain(false) end
    local room = (self.GetWidth and self:GetWidth() or 260) - 6
    -- Drawn with the distances; should the strip run past the column, drawn again with
    -- the distance on the one the arrow leads to alone.
    for pass = 1, 2 do
        local left, any = 0, false
        for i, option in ipairs(options) do
            local button = navButton(nav, i)
            button.option = option
            local point = option.point
            local leads = target and target.mapID == point.mapID and target.x == point.x and target.y == point.y
            any = any or leads
            -- A distance stands beside the word; "another continent" is not a distance and
            -- would read as part of the name, so the word stands alone then.
            local far = P.DistanceText and P.DistanceText(point)
            if pass == 2 and not leads and (any or i > 1) then far = nil end
            button.text = (option.short or (L"Ко входу")) .. (far and (" " .. far) or "")
            button.leads = leads and true or false
            button.label:SetText((leads and "|cffffd34d" or LABEL) .. button.text .. "|r")
            button:Plate(leads)
            local width = (button.label:GetStringWidth() or 60) + 16
            button:SetWidth(width)
            button:ClearAllPoints()
            button:SetPoint("LEFT", nav, "LEFT", left, 0)
            button:Show()
            left = left + width + 4
        end
        if left - 4 <= room then break end
    end
    for i = #options + 1, #nav.buttons do nav.buttons[i]:Hide() end
    nav:SetShown(#options > 0)
    -- The rows start under the strip.
    self.fromHeaderOffsetY = #options > 0 and -32 or -6
end

-- In the list of dungeons the strip is the filter: the dungeons that still have something
-- to do, or all of them. The same two as in the menu behind the three dots, in sight.
local function drawFilters(self, inside)
    local nav = self.nav
    if not nav then return end
    -- Inside it is one switch that says what a click will do; the list of the dead
    -- below folds by the same switch.
    local choices = inside and {
        {text=db.showDead and (L"Скрыть убитых") or (L"Показать убитых"), on=false, set=function() db.showDead = not db.showDead or nil end, page=true,
            note=db.showDead and (L"Свернуть убитых боссов в одну строку.") or (L"Показать убитых боссов списком.")},
    } or {
        {text=L"Скрыть сданные", on=db.hideDone and not db.fullCatalog, set=function() db.hideDone, db.fullCatalog = true, false end,
            note=L"В списке только подземелья, где ещё есть что делать. Сданные и скрытые тобой не показываются."},
        {text=L"Показать все", on=db.fullCatalog and true or false, set=function() db.fullCatalog = true end,
            note=L"Все подземелья, со сданными и скрытыми. ПКМ по подземелью скрывает его из списка или возвращает."},
    }
    local left = 0
    for i, choice in ipairs(choices) do
        local button = navButton(nav, i)
        button:Plain(false)
        button.option, button.choice = nil, choice
        button.text, button.leads = choice.text, choice.on and true or false
        button.label:SetText((choice.on and "|cffffd34d" or LABEL) .. choice.text .. "|r")
        button:Plate(choice.on)
        local width = (button.label:GetStringWidth() or 60) + 16
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("LEFT", nav, "LEFT", left, 0)
        button:Show()
        left = left + width + 4
    end
    for i = #choices + 1, #nav.buttons do nav.buttons[i]:Hide() end
    nav:SetShown(true)
    self.fromHeaderOffsetY = -32
end

-- The owner, on seeing it in the game: small, and a mush. The mock-up he approved has a
-- dark panel behind the list, the labels of the sections a size up with a thin rule over
-- each, and the one thing to do set larger. Plain colour and the game's own fonts: no
-- picture is drawn here.
-- The plates of the status, from the layout's numbers (background, bar, text; 0..1).
local function hex(h, a)
    return {tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1}
end
local PLATE = {
    gold = {bg=hex("4A3414", .88), bar=hex("D3A13A"), text="ffe8a3"},
    blue = {bg=hex("16354F", .88), bar=hex("4FA9E8"), text="d9f1ff"},
    green = {bg=hex("173A24", .88), bar=hex("4EE07A"), text="d8ffe2"},
    grey = {bg=hex("2D3138", .88), bar=hex("A7AFBC"), text="f1f3f6"},
    red = {bg=hex("4A1F1F", .88), bar=hex("E04E4E"), text="ffd7d7"},
}
-- The gold frame of a boss row: his loot open beside it, or a best-in-slot thing in it.
-- (ChatGPT's code layout: fill #624617B8, rim 2 px #E1B03F. A boss with a best-in-slot thing
-- is told by the gold dot and the words after his name, as on the layout.)
local GILD = {
    open = {fill=hex("624617", .72), edge=hex("E1B03F"), size=2},
}
local function fontOf(entry)
    local own = ownFonts()
    if entry.section or entry.group or entry.routeCount then return own.label or GameFontNormalMed2 or GameFontNormal end
    if entry.now or entry.status or entry.big or entry.heading or (entry.prep and entry.lead) then return own.big or GameFontNormalMed3 or GameFontNormalLarge end
    return own.row
end

-- A line under a row: no dash before it, and a size of its own. The tracker sizes the
-- line as it adds it, so the height is measured again here and the block told of it.
local function addLine(block, key, text, single)
    -- Seen in the game: the dash stayed. The style has gone by two names over the years,
    -- and by the number two under both; and the dash is hidden by hand besides.
    local hide = (ObjectiveTrackerDashStyle and ObjectiveTrackerDashStyle.Hide) or OBJECTIVE_DASH_STYLE_HIDE or 2
    local line = block:AddObjective(key, text, nil, true, hide)
    if type(line) == "table" and type(line.Dash) == "table" and line.Dash.Hide then pcall(line.Dash.Hide, line.Dash) end
    -- A line lent before to a goal with a sight keeps no sight.
    if type(line) == "table" then line.targetName = nil end
    -- A line lent before to a step of a chain keeps no click of it.
    if type(line) == "table" and line.stepOf then
        line.stepOf, line.rowOf = nil, nil
        pcall(function()
            line:SetScript("OnMouseUp", nil); line:SetScript("OnEnter", nil); line:SetScript("OnLeave", nil)
            if line.EnableMouse then line:EnableMouse(false) end
        end)
    end
    local font = ownFonts().sub
    if type(line) == "table" and type(line.Text) == "table" and line.Text.SetFontObject and (font or single or line.Text.cut) then
        pcall(function()
            local old = line:GetHeight()
            if font then line.Text:SetFontObject(font) end
            -- A line struck through stays one line, cut short with dots if it must: wrapped,
            -- the stroke fell between the two (seen in the game, 15.11.2026). The lines are
            -- lent from one row to another, so every other one is let wrap again.
            if line.Text.SetWordWrap then line.Text:SetWordWrap(not single) end
            line.Text.cut = single or nil
            line.Text:SetHeight(0)
            local new = line.Text:GetHeight()
            if old and new and new > 0 and new ~= old then
                line:SetHeight(new)
                if type(block.height) == "number" then block.height = block.height + (new - old) end
            end
        end)
    end
    return line
end

-- The owner by the Razorfen (16.11.2026): "I can't find Malcin. On a quest with one elite
-- mob, a small button that takes him as the target." As ChatGPT drew it and the owner
-- approved: a small gold sight at the end of the goal's line, and over it "Take as target:
-- Ambassador Malcin. Works when he is near." A click is /target with his name. Only the
-- game's secure buttons may target, and they may not be shown, hidden or moved in a fight:
-- the sights stand on the screen by themselves (not on the panel, which a fight redraws),
-- are put beside their lines out of a fight, and stay where they are in one.
local targetLines = setmetatable({}, {__mode="k"})
local targetPool = {}
local function targetLine(block, line, name)
    if not (type(line) == "table" and type(line.Text) == "table" and type(name) == "string" and name ~= "") then return end
    -- The words make room for the sight on the right.
    pcall(function()
        local width = line.Text:GetWidth()
        if type(width) == "number" and width > 80 then
            local old = line:GetHeight()
            line.Text:SetWidth(width - 20)
            line.Text:SetHeight(0)
            local new = line.Text:GetHeight()
            if old and new and new > 0 and new ~= old then
                line:SetHeight(new)
                if type(block.height) == "number" then block.height = block.height + (new - old) end
            end
        end
    end)
    line.targetName = name
    targetLines[line] = true
end
local function targetButton(i)
    if targetPool[i] then return targetPool[i] end
    local ok, b = pcall(CreateFrame, "Button", "DungeonQuestForeverTarget" .. i, UIParent, "SecureActionButtonTemplate")
    if not ok or not b then return end
    b:SetSize(16, 16)
    b:SetFrameStrata("HIGH")
    pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetAllPoints(b)
    if b.back.SetColorTexture then b.back:SetColorTexture(.08, .06, .04, .9) end
    b.rim = {}
    for k, edge in ipairs({{"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"}, {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"}}) do
        local t = b:CreateTexture(nil, "BORDER")
        t:SetPoint(edge[1], b, edge[1], 0, 0)
        t:SetPoint(edge[2], b, edge[2], 0, 0)
        if k <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        if t.SetColorTexture then t:SetColorTexture(.85, .68, .25, 1) end
        b.rim[k] = t
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexture("Interface\\CURSOR\\Crosshairs")
    if b.icon.SetVertexColor then b.icon:SetVertexColor(1, .82, .3) end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((L"Взять в цель: %s"):format(self.who or ""), 1, .82, .25)
        GameTooltip:AddLine(L"Работает, когда он рядом.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    targetPool[i] = b
    return b
end
-- Each sight beside its line, out of a fight; the ones no line asks for, hidden.
local function placeTargets()
    if InCombatLockdown and InCombatLockdown() then return end
    local used = 0
    for line in pairs(targetLines) do
        if not line.targetName then
            targetLines[line] = nil
        elseif line.IsVisible and line:IsVisible() and type(line.Text) == "table" then
            local right, top = line.Text:GetRight(), line:GetTop()
            local b = right and top and targetButton(used + 1)
            if b then
                used = used + 1
                local mine, theirs = line:GetEffectiveScale(), UIParent:GetEffectiveScale()
                if mine and theirs and theirs > 0 then b:SetScale(mine / theirs) end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 4, top)
                if b.who ~= line.targetName then
                    b.who = line.targetName
                    b:SetAttribute("macrotext", "/target " .. line.targetName)
                end
                b:Show()
            end
        end
    end
    for i = used + 1, #targetPool do targetPool[i]:Hide() end
end
P.PlaceTargets = placeTargets
do
    local keeper = CreateFrame and CreateFrame("Frame")
    local wait = 0
    if keeper then
        keeper:SetScript("OnUpdate", function(_, elapsed)
            wait = wait - (elapsed or 0)
            if wait > 0 then return end
            wait = .25
            placeTargets()
        end)
    end
end

-- A line struck through: a step of a chain that is done. (The owner: "the task is struck
-- out, without any 'handed in'. Done - struck out, on to the next.") The game's font has
-- no struck letters, so a thin line is laid over the words.
local function addStruck(block, key, text)
    local line = addLine(block, key, text, true)
    block.struck = block.struck or {}
    block.struck[key] = true
    if type(line) == "table" and type(line.Text) == "table" and line.CreateTexture then
        pcall(function()
            if not line.strike then
                line.strike = line:CreateTexture(nil, "OVERLAY")
                if line.strike.SetColorTexture then line.strike:SetColorTexture(.7, .7, .7, .85) end
                line.strike:SetHeight(1)
            end
            local width = line.Text:GetStringWidth()
            local room = line.Text:GetWidth()
            if type(width) ~= "number" then width = 120 end
            if type(room) == "number" and room > 0 and width > room then width = room end
            line.strike:ClearAllPoints()
            line.strike:SetPoint("LEFT", line.Text, "LEFT", 0, 0)
            line.strike:SetWidth(math.max(1, width))
            line.strike:Show()
        end)
    end
    return line
end

-- The steps of a chain under the quest, each a line with a dash, as the goals of a quest
-- are (the owner, 15.11.2026: "the chain quests the same as with the mobs: a dash and the
-- task of the chain, number 1, 2, 3, 4; done ones done; and each can be clicked to see what
-- to do now"). Done: struck; the one under way: bright; the ones ahead: grey. A click on a
-- step: the arrow and what to do, as a click on the quest does; ahead, what it waits for.
local stepClick
local function chainSteps(block, entry, links, now, from, to)
    local total = #links
    local function title(i) return P.Title(links[i]) or "?" end
    local function clickable(line, i)
        if type(line) ~= "table" then return end
        line.stepOf, line.rowOf, line.stepAt, line.stepLinks = links[i], entry, i, links
        pcall(function()
            if line.EnableMouse then line:EnableMouse(true) end
            line:SetScript("OnMouseUp", function(self) if stepClick then stepClick(self) end end)
            line:SetScript("OnEnter", function(self)
                local id = self.stepOf
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(self.stepAt .. ". " .. (P.Title(id) or "?"), 1, .83, .35, 1, true)
                local state = C_QuestLog.IsQuestFlaggedCompleted(id) and (L"сдано")
                    or P.IsActive(id) and ((C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and (L"готово — сдай") or (L"в журнале"))
                    or (self.stepAt > (now or 0)) and (L"впереди: откроется после предыдущего шага") or (L"не взято")
                GameTooltip:AddLine(state, 1, 1, 1, true)
                local left = P.IsActive(id) and P.Objectives and P.Objectives(id)
                if left then GameTooltip:AddLine(left, .8, .8, .8, true) end
                GameTooltip:AddLine(L"Щелчок — стрелка и что делать на этом шаге.", .6, .6, .6, true)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end)
    end
    for i = from, math.min(to, total) do
        local text = "- " .. i .. ". " .. title(i)
        if i < (now or 1) then
            -- A long chain: the steps done in one struck line.
            if total > 6 and now - 1 > 2 then
                if i == 1 then clickable(addStruck(block, "chain1", "|cff8e8c87- 1–" .. (now - 1) .. ". " .. title(1) .. " … " .. title(now - 1) .. "|r"), now - 1) end
            else
                clickable(addStruck(block, "chain" .. i, "|cff8e8c87" .. text .. "|r"), i)
            end
        elseif i == now then
            clickable(addLine(block, "chain" .. i, "|cffffffff" .. text .. "|r"), i)
        else
            if total > 6 and i > now + 2 then
                addLine(block, "chainRest", "|cff8e8c87- " .. L"ещё шагов: " .. (total - now - 2) .. "|r")
                break
            end
            clickable(addLine(block, "chain" .. i, "|cff9a9a9a" .. text .. "|r"), i)
        end
    end
end

-- What to do now about a quest, in one line: to take it, to finish it, to hand it in.
function P.NowText(entry)
    local id = entry.step or entry.id
    local title = "«" .. (P.Title(id) or "?") .. "»"
    local okChain, list, at = pcall(P.Chain, ((entry.step ~= entry.id and entry.id) or entry.leads) or entry.id)
    local head = (okChain and type(list) == "table" and #list > 1 and at) and (L"Сейчас, шаг " .. at .. L" из " .. #list .. ": ") or (L"Сейчас: ")
    local active = P.IsActive(id)
    if entry.handin or (entry.stepActive and entry.act == "turnin") or (active and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) then
        local to = P.Where(id, "ends")
        return head .. L"сдай " .. title .. (to and (" — " .. to) or "")
    end
    if entry.work and entry.work.text then
        return head .. title .. ": " .. entry.work.text .. (entry.work.name and (" — " .. entry.work.name) or "")
    end
    if active then
        local left = P.Objectives and P.Objectives(id)
        return head .. title .. (left and (": " .. left:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or "") .. ((entry.zone == "inside" or entry.state == "active") and (L" — делается внутри") or "")
    end
    local from = P.Where(id, "starts")
    return head .. L"возьми " .. title .. (from and (" — " .. from) or "")
end

stepClick = function(line)
    local id, entry = line.stepOf, line.rowOf
    if not (id and entry) then return end
    if P.Track then P.Track("StepClicked") end
    local current = entry.step or entry.id
    if id == current then openRoute(entry) return end
    if C_QuestLog.IsQuestFlaggedCompleted(id) then
        say(L"Шаг «" .. (P.Title(id) or "?") .. L"» уже сдан.")
        return
    end
    if P.IsActive(id) then
        local ok, list = pcall(atlas.QuestWork, id, selected)
        local work = ok and type(list) == "table" and list[1] or nil
        openRoute({id=id, step=id, state="active", note=(P.Objectives and P.Objectives(id)) or "", work=work, place=work,
            turnIn=(C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) or nil})
        return
    end
    say(L"Шаг «" .. (P.Title(id) or "?") .. L"» откроется после «" .. (P.Title(current) or "?") .. "».")
end

-- The goals of a quest in the log, each a line with a dash under the quest, as the game's
-- own tracker writes them (the owner, 15.11.2026: "the quest yellow, and under it the
-- sub-quests, with dashes, as done below"). Done ones struck out and dim; the one the
-- arrow leads to bright; the rest grey. Only for two goals or more: one goal is said in
-- the line above. Returns whether the lines were written.
local function goalsOf(id)
    local list = id and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
    if type(list) ~= "table" then return end
    local goals = {}
    for _, objective in ipairs(list) do
        local text = objective.text
        if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text ~= "" then
            goals[#goals+1] = {text=text, done=objective.finished and true or false}
        end
    end
    return #goals >= 2 and goals or nil
end

-- The goal the arrow leads to, by its text: the arrow keeps its goal until it is done,
-- while the nearest one may change as the player walks.
local function ledGoal(id)
    local target = atlas.Target and atlas.Target()
    local goal = db and db.goal
    local title = (target and target.kind == "objective" and target.questID == id and target.title)
        or (goal and goal.kind == "objective" and goal.id == id and goal.label) or nil
    if not (title and atlas.QuestWork) then return end
    local ok, left = pcall(atlas.QuestWork, id, selected)
    for _, spot in ipairs(ok and left or {}) do
        if spot.name == title then return spot.text end
    end
end

-- How to find it, where the arrow alone is not enough (P.QuestHints, BossRoute.lua): a
-- line in light blue under the quest while it is to be done out here.
local function hintLine(block, entry)
    local id = entry.step or entry.id
    local hint = P.QuestHints and P.QuestHints[id]
    if not hint or not (entry.working or entry.stepActive or entry.state == "active") then return end
    if C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then return end
    -- (Not blue and not under every card: the owner, "all blue, it looks wretched". In the
    -- unfolded card only, labelled like "куда:", and in the tip of the quest.)
    addLine(block, "hint", "|cffffd34d" .. L"как найти:" .. "|r |cffbcb7ab" .. hint .. "|r")
end

-- The other quests a step waits for beside the chain (a group of forerunners): each on a
-- line, what is left of it or where to take it.
local function alsoLines(block, entry)
    for i, id in ipairs(entry.also or {}) do
        if i > 2 then break end
        if not (C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)) then
            local title = "«" .. (P.Title(id) or "?") .. "»"
            local text
            if P.IsActive(id) then
                if C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then
                    local to = P.Where(id, "ends")
                    text = "|cff71c886" .. L"Сдай" .. "|r|cffe6e0d2 " .. title .. (to and (": " .. to) or "") .. "|r"
                else
                    local left = P.Objectives and P.Objectives(id)
                    text = "|cffe6e0d2" .. title .. (left and (": " .. left) or "") .. "|r"
                end
            else
                local from = P.Where(id, "starts")
                text = "|cffe6e0d2" .. L"взять" .. " " .. title .. (from and (": " .. from) or "") .. "|r"
            end
            addLine(block, "also" .. i, "|cffffd34d" .. L"и ещё:" .. "|r " .. text)
        end
    end
end

local function goalLines(block, id, fallback)
    local goals = goalsOf(id)
    if not goals then return end
    local current = ledGoal(id) or fallback
    -- The goals that are one creature: his name, for the sight.
    local whom = {}
    if atlas.QuestWork then
        local ok, spots = pcall(atlas.QuestWork, id, selected)
        for _, spot in ipairs(ok and spots or {}) do
            if spot.target and spot.text then whom[spot.text] = spot.target end
        end
    end
    for i, goal in ipairs(goals) do
        -- Done: struck out, without the count ("5/5" said nothing the stroke does not).
        if goal.done then addStruck(block, "goal" .. i, "|cff8e8c87- " .. (goal.text:gsub(":%s*%d+%s*/%s*%d+%s*$", "")) .. "|r")
        else
            local line = addLine(block, "goal" .. i, (goal.text == current and "|cffffffff- " or "|cffbcb7ab- ") .. goal.text .. "|r")
            if whom[goal.text] then targetLine(block, line, whom[goal.text]) end
        end
    end
    return true
end


-- The signs of a row's state: the game's own pictures.
local SIGN = {
    take = "Interface\\GossipFrame\\AvailableQuestIcon",
    log = "Interface\\GossipFrame\\IncompleteQuestIcon",
    ready = "Interface\\GossipFrame\\ActiveQuestIcon",
    done = "Interface\\RaidFrame\\ReadyCheck-Ready",
    dead = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    boss = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    lock = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK",
    book = "Interface\\Icons\\INV_Misc_Book_09",
}

local function isLabel(entry)
    return (entry.section or entry.group or entry.routeCount) and true or false
end

local function drawPanel(self)
    if self.isBoard then return end
    local panel = self.panel
    if not panel then
        panel = CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate" or nil)
        self.panel = panel
        if panel.SetFrameLevel and self.GetFrameLevel then panel:SetFrameLevel(math.max(0, (self:GetFrameLevel() or 1) - 1)) end
        if panel.SetBackdrop then
            panel:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=14, insets={left=3, right=3, top=3, bottom=3}})
            panel:SetBackdropColor(.04, .04, .06, .88)
            panel:SetBackdropBorderColor(.72, .6, .36, 1)
        end
    end
    local shift = self.leftMargin or 0
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", self, "TOPLEFT", shift - 18, 6)
    panel:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", shift + 4, -10)
    panel:Show()
end

-- The owner: "can you make pings? The game gives no place in there, but there are the
-- marks of the halls; in those halls one could ping where to go." There is no place to
-- put a mark on the screen at: the game tells neither where the player stands nor which
-- way he faces. What it does tell is the hall, the moment he walks into it. So that
-- moment gets the ping: the sound of one, and a line in the middle of the screen with
-- the hall and the way on to the boss. /dq ping switches it off.
local pinged
local function roomPing(d, room, stop)
    if not (room and stop and db) or db.noPing then return end
    local mark = d.key .. "|" .. room .. "|" .. tostring(stop.name)
    if pinged == mark then return end
    pinged = mark
    local text
    if stop.inRoom then
        text = "«" .. room .. L"»: ты в зале босса " .. stop.name
    else
        local steps = {}
        for i = 1, math.min(stop.front or 0, 2) do
            local line = stop.lines[i]
            if line then steps[#steps+1] = (line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
        end
        text = "«" .. room .. L"». К боссу " .. stop.name .. (#steps > 0 and (": " .. table.concat(steps, ", ")) or "")
    end
    P.lastPing = text
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or {r=1, g=.82, b=.3})
    end
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
end

-- The owner: a list of the bosses on every page, all of them, and one killed stays in
-- it struck out. No folds: who is dead, who is next, who is left, at a glance.
local function bossRows(d, rows, inside)
    local stops = P.Run and d and P.Run(d, rows or {}, "all")
    if not stops then return {} end
    local list, total, dead = {}, 0, 0
    for _, stop in ipairs(stops) do
        if stop.dim then
            list[#list+1] = {stop=true, dim=true, wing=stop.wing, name=stop.name, lines={}}
        elseif not stop.wingRow then
            total = total + 1
            if stop.dead then dead = dead + 1 end
            -- What he drops for the character: the best of a slot, better than the worn,
            -- or, while nothing is weighed yet, simply of a kind the class wears.
            local mine, best, better, weighed = 0, 0, 0, false
            if P.LootFor and stop.npc then
                local loot
                loot, mine, best, better = P.LootFor(stop.npc)
                for _, thing in ipairs(loot) do weighed = weighed or thing.worth.known end
            end
            local entry = {stop=true, listed=true, npc=stop.npc, name=stop.name, dead=stop.dead and true or false,
                next=inside and stop.next or nil, optional=stop.optional, mine=(not weighed) and mine or 0, best=best, better=better, lines={}}
            -- The owner (16.11.2026), as ChatGPT drew it: under a boss who drops a thing of the
            -- window of the best gear, "your best item" with its picture and name; under the
            -- boss the group goes to next, what to do so as not to die.
            if not entry.dead then
                local own = P.GearFromBoss and stop.npc and P.GearFromBoss(stop.npc) or {}
                if #own > 0 then
                    local named = {}
                    for i, id in ipairs(own) do if i <= 2 then named[#named+1] = P.GearItemText(id) end end
                    entry.lines[#entry.lines+1] = "|cff9d9d9d• " .. L"твоя лучшая вещь:" .. "|r " .. table.concat(named, ", ")
                    entry.bis = #own
                end
                local tip = entry.next and P.BossTips and stop.npc and P.BossTips[stop.npc]
                if tip then entry.lines[#entry.lines+1] = "|cff71c886" .. L"совет:" .. " " .. tip .. "|r" end
            end
            list[#list+1] = entry
        end
    end
    if total == 0 then return {} end
    -- The owner: "the parts Bosses and Quests have to fold" (the layout of ChatGPT, approved).
    local head = {section=L"Боссы • убито " .. dead .. L" из " .. total, fold="bosses",
        about=L"Все боссы подземелья по порядку. Щелчок по боссу — его добыча. ПКМ — отметить убитым или вернуть. Щелчок по заголовку сворачивает список."}
    if db and db.folds and db.folds.bosses then return {head} end
    table.insert(list, 1, head)
    return list
end

local function deadCount()
    local n = 0
    for _, stop in ipairs(P.Run and selected and P.Run(selected, {}, true) or {}) do
        if stop.dead and not stop.dim then n = n + 1 end
    end
    return n
end

local function layout(self)
    if not catalog or (not browsing and not result) then return end
    -- The words over a part of the page: blue on the cards, gold in the look of the game's quests.
    local native = self.isBoard and nativeLook()
    local labelTone = native and "|cffffd100" or LABEL
    if browsing and not self:IsCollapsed() then
        drawFilters(self)
    else
        for _, button in ipairs(self.nav and self.nav.buttons or {}) do button.choice = nil end
        drawNav(self, (not browsing and selected and P.Doors and not self:IsCollapsed() and not P.InDungeon(selected)) and P.Doors(selected) or {})
    end
    self.leftMargin = stepAside(self)
    local entries = browsing and visible or detailRows
    first = math.max(1, math.min(first, #entries))
    self.bossMenu:SetShown(not browsing and not self:IsCollapsed() and P.InDungeon(selected) and #P.BossChoices(selected) > 0)
    self.filterMenu:SetShown(browsing and not self:IsCollapsed())
    -- The three dots that choose the dungeon: on the page of a dungeon, in the look of the game's quests.
    if self.pickMenu then self.pickMenu:SetShown(not browsing and not compact and not self:IsCollapsed() and self.isBoard and nativeLook()) end
    if #entries == 0 then
        local empty = self:GetBlock(1)
        empty.entry = nil
        empty.JournalButton:SetShown(false)
        empty.RouteButton:Hide()
        empty:SetHeader(browsing and (L"Все подземелья скрыты фильтрами") or (L"В базе нет заданий для персонажа"))
        self:LayoutBlock(empty)
    end
    displayed = 0
    local last = browsing and math.min(#entries, first + limit - 1) or #entries
    for i = first, last do
        local entry = entries[i]
        local block = self:GetBlock(i)
        block.entry = entry
        -- The game's quests carry no button of their own on the right: nor do these.
        local journal = not browsing and entry.step and P.IsActive(entry.step) and not (self.isBoard and nativeLook())
        block.JournalButton:SetShown(journal or false)
        block.RouteButton:SetScript("OnUpdate", nil)
        if block.RouteButton.bossIcon then
            block.RouteButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
            block.RouteButton:GetNormalTexture():SetRotation(0)
            block.RouteButton.bossIcon = nil
        end
        local route = entry.boss or entry.entrance or (entry.secret and entry.point) or (entry.id and entry.state ~= "done" and not entry.unknown)
        block.RouteButton:SetShown(not not (entry.boss or (entry.secret and entry.point)))
        block.RouteButton:ClearAllPoints()
        block.RouteButton:SetPoint("TOPRIGHT", block, "TOPLEFT", -2, 0)
        block.rightEdgeOffset = journal and -22 or 0
        if route then
            block.RouteButton:SetScript("OnClick", function()
                if entry.boss then P.TogglePlan(entry) else openRoute(entry) end
            end)
            block.RouteButton:SetScript("OnEnter", function(b)
                if entry.boss then tip(b, L"План этажа", L"Показать или убрать маленький план рядом с трекером.")
                else tip(b, L"Показать маршрут", entry.action or entry.note) end
            end)
            block.RouteButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if journal then
            block.JournalButton:SetScript("OnClick", function() P.ShowQuest(entry.step) end)
            block.JournalButton:SetScript("OnEnter", function(b) tip(b, L"Открыть в журнале", P.Title(entry.step)) end)
            block.JournalButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        -- The font says what a row is: a label, the thing to do now, or a plain line.
        local label = isLabel(entry)
        if type(block.HeaderText) == "table" and block.HeaderText.GetFontObject then
            block.plainFont = block.plainFont or block.HeaderText:GetFontObject()
            local font = fontOf(entry) or block.plainFont
            if font then pcall(block.HeaderText.SetFontObject, block.HeaderText, font) end
        end
        -- A thin rule under the label of a section, as on the layout of 14.11.2026.
        if block.CreateTexture then
            if label and not block.rule then
                block.rule = block:CreateTexture(nil, "ARTWORK")
                if block.rule.SetColorTexture then block.rule:SetColorTexture(.608, .490, .310, .6) end   -- #9B7D4F99
                block.rule:SetHeight(1)
                block.rule:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", 0, -3)
                block.rule:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 0, -3)
            end
            if block.rule then block.rule:SetShown(label and true or false) end
        end
        -- Dressed as a card with the sign of its state, where the panel can do it.
        local sign
        if not label then
            if browsing and entry.key then
                local c = progress[entry.key]
                sign = (c.total == 0 or db.hidden[entry.key]) and SIGN.lock or isClosed(c) and SIGN.done or c.taken > 0 and SIGN.log or SIGN.take
            elseif entry.stop then
                sign = (not entry.wing and not entry.dim) and (entry.dead and SIGN.dead or SIGN.boss) or nil
            elseif entry.now then
                sign = entry.row.handin and SIGN.ready or entry.row.working and SIGN.log or SIGN.take
            elseif entry.task then
                sign = entry.task == L"готово" and SIGN.ready or entry.task == L"взято" and SIGN.log or SIGN.take
            elseif entry.plain then
                sign = entry.todo and SIGN.take or entry.book and SIGN.book or nil
            elseif entry.flight then
                sign = entry.sign
            elseif entry.status and (entry.plate or entry.ready or entry.muted) then
                local kind = entry.plate or (entry.ready and "green") or "grey"
                sign = kind == "gold" and SIGN.take or kind == "blue" and SIGN.ready or kind == "red" and SIGN.boss or SIGN.done
            elseif entry.status or entry.via or entry.entrance or entry.secret or entry.boss then
                sign = true
            elseif entry.prep then
                -- The card of a dungeon quest wears the state of that quest, so the taken
                -- and the not taken are told apart at a glance: a lock, a yellow "?" to hand
                -- in, a grey "?" taken and not done yet, a yellow "!" not taken yet. (A tick
                -- stood for "taken, nothing left outside"; the owner: "how does it differ
                -- from the question mark? I have not done that quest either." A tick is for
                -- what is done, so it is not used here.)
                local taken = entry.state == "active"
                sign = (entry.levelLocked or entry.unknown) and SIGN.lock or entry.handin and SIGN.ready
                    or taken and SIGN.log or (entry.askGroup and nativeLook() and "Interface\\Icons\\INV_Misc_GroupNeedMore") or SIGN.take
            elseif entry.id then
                local id = entry.step or entry.id
                sign = (entry.levelLocked or entry.unknown) and SIGN.lock or entry.handin and SIGN.ready
                    or P.IsActive(id) and ((C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and SIGN.ready or SIGN.log) or SIGN.take
            end
        end
        if block.Dress then block:Dress(sign) end
        if block.Gild then block:Gild(nil) end
        if block.FoldSign then block:FoldSign(nil) end
        if block.Distance then block:Distance(nil) end
        self.fromBlockOffsetY = (label and i > first) and -13 or (sign and block.Dress and (nativeLook() and -6 or -9) or -4)
        if browsing and entry.group then
            block:SetHeader(labelTone .. entry.section .. "|r")
        elseif browsing then
            -- A dungeon: its name, and under it the level and what is left, in words.
            local c = progress[entry.key]
            local closed, hidden = isClosed(c), db.hidden[entry.key]
            local color = closed and "|cff71c886" or (hidden or c.total == 0) and "|cffaaaaaa" or fits[entry.key] == "now" and "|cffffd34d" or ""
            block:SetHeader("  " .. color .. atlas.DungeonName(entry) .. (color ~= "" and "|r" or "") .. (hidden and (DIM .. L" • скрыто|r") or ""))
            local parts = {(L"ур. %d–%d"):format(entry.minLevel, entry.maxLevel)}
            if c.total == 0 then
                parts[#parts+1] = L"заданий нет"
            elseif closed then
                parts[#parts+1] = L"всё сдано"
            elseif c.taken > 0 then
                parts[#parts+1] = L"в журнале " .. c.taken
                parts[#parts+1] = L"осталось " .. (c.total - c.finished)
            else
                parts[#parts+1] = L"заданий осталось: " .. (c.total - c.finished)
            end
            addLine(block, "count", table.concat(parts, " • "))
        elseif entry.plain then
            block:SetHeader("  " .. entry.plain)
            if entry.under then addLine(block, "under", entry.under) end
        elseif entry.now then
            -- The one thing to do now, in full: what, with whom, where and how far.
            local row = entry.row
            local verb = row.handin and (L"Сдай") or row.working and (L"Сделай") or (L"Возьми")
            block:SetHeader("  |cffffd34d" .. verb .. " «" .. P.Title(row.step) .. "»|r")
            local who = row.place and atlas.PlaceName(row.place)
            local zone = row.place and row.place.mapID and atlas.ZoneName(row.place.mapID)
            local far = P.Reach(row.place)
            local where = {}
            if who then where[#where+1] = who end
            if zone and zone ~= who then where[#where+1] = zone end
            if far then where[#where+1] = far end
            local joined = #where > 0 and table.concat(where, " • ") or (L"место неизвестно")
            if who and #where > 1 and select(2, joined:gsub("[^\128-\191]", "")) > 38 then
                -- Too long for one line: the name, and under it the place and how far.
                table.remove(where, 1)
                addLine(block, "who", who)
                joined = table.concat(where, " • ")
            end
            addLine(block, "where", joined)
            if row.working and row.work and row.work.text then addLine(block, "work", row.work.text) end
            local goal = row.step ~= row.id and row.id or row.leads
            if goal then addLine(block, "chain", L"цепочка к «" .. P.Title(goal) .. "»") end
            local _, at, total = chainOf(goal or row.id)
            if total then addLine(block, "steps", L"шаг " .. at .. L" из " .. total) end
        elseif entry.stop then
            if entry.wing then
                -- The name of a wing over its bosses.
                block:SetHeader("|cffc8b27a" .. entry.name .. "|r")
            elseif entry.dim then
                block:SetHeader("  " .. DIM .. entry.name .. "|r")
            elseif entry.dead then
                block:SetHeader("  " .. DIM .. entry.name .. L" • убит|r")
                if block.Strike then block:Strike(true) end
            else
                local near = atlas.Sighted and atlas.Sighted()
                near = near ~= nil and (near == entry.npc or near == entry.name)
                if entry.heading then
                    -- The short page of a fight: "Boss  name", as "Next  quest" above it.
                    block:SetHeader(labelTone .. (near and (L"Босс рядом") or (L"Следующий босс")) .. "|r  " .. entry.name)
                elseif entry.big then
                    block:SetHeader("  |cff" .. PLATE.red.text .. L"Следующий босс: " .. entry.name .. "|r" .. (near and (L"|cff71c886 • рядом, метка над ним|r") or ""))
                else
                    local open = P.LootOpenFor and P.LootOpenFor() == entry.npc
                    if block.Gild then block:Gild(open and "open" or nil) end
                    if open and P.AnchorLoot then P.AnchorLoot(block) end
                    -- (The counts "best in slot: 1" are gone: the owner did not understand them. The
                    -- best item stands under the boss by name; his click opens all his loot.)
                    block:SetHeader("  " .. entry.name .. (near and (L"|cff71c886 • рядом, метка над ним|r") or entry.next and (L"|cffffd34d • следующий|r")
                        or entry.optional and (DIM .. L" • по желанию|r") or ""))
                end
            end
            for i, line in ipairs(entry.lines) do
                -- A fight leaves room for two lines; the red plate, for four.
                if entry.heading and i > 2 then break end
                if entry.big and i > 4 then break end
                addLine(block, "line" .. i, line)
            end
            if entry.big and not entry.heading then
                local npc = entry.npc
                -- The owner, two maps open at once: "no telling why the hell two maps opened."
                -- The button shows the small plan only; the big one is behind its right button.
                block:Ready("red", (npc and P.HasPlan and P.HasPlan(npc)) and function()
                    if db then db.floorOff = nil end
                    P.Refresh()
                    if P.FlashFloor then P.FlashFloor() end
                end or nil, L"Путь к боссу", L"План этажа с путём к этому боссу.")
            end
        elseif entry.status then
            -- The status on top: its colour says which; under it at most two short lines
            -- and the button of what to do.
            local kind = entry.plate or (entry.ready and "green") or (entry.muted and "grey") or nil
            local look = kind and PLATE[kind]
            block:SetHeader("  " .. (look and ("|cff" .. look.text) or entry.good and "|cff71c886" or "|cffffd34d") .. entry.status .. "|r")
            local lines = entry.lines or {entry.order, entry.hint, entry.note}
            local n = 0
            for i = 1, 4 do
                local line = lines[i]
                if line and n < 3 then n = n + 1; addLine(block, "line" .. n, "|cffbcb7ab" .. line .. "|r") end
            end
            local go = entry.go or (entry.door and function() openRoute({entrance=true}) end)
            if kind then block:Ready(kind, go, entry.goText, entry.goNote) end
        elseif entry.section then
            block:SetHeader(labelTone .. entry.section .. "|r")
            if entry.under then addLine(block, "under", DIM .. entry.under .. "|r") end
            if entry.fold and block.FoldSign then block:FoldSign((db.folds and db.folds[entry.fold]) and "folded" or "open") end
        elseif entry.via then
            local far = entry.place and P.DistanceText(entry.place)
            block:SetHeader("  " .. entry.title .. (far and (DIM .. " • " .. far .. "|r") or ""))
            if entry.cast then
                -- (Asked of the icon itself: the page is drawn before the arrow is tidied.)
                local waits = InCombatLockdown() and not (teleport and teleport:IsShown() and not teleport.unseen)
                addLine(block, "cast", waits and (L"иконка телепорта появится после боя: в бою игра не даёт её показать")
                    or (L"нажми иконку телепорта на месте стрелки; крестик на ней — идти без телепорта"))
            end
            if entry.pass then
                local lift = entry.place and entry.place.hint
                addLine(block, "keeper", (lift and lift ~= L"проход между зонами") and lift or (L"пешком через проход между зонами: по прямой там не пройти"))
            elseif entry.fly then
                addLine(block, "keeper", L"распорядитель полётов: " .. (entry.keeper or "?"))
                if entry.unsure then addLine(block, "unsure", DIM .. L"если эта точка у тебя открыта; открой карту полётов, и я запомню твои точки|r") end
            elseif entry.keeper then
                addLine(block, "keeper", L"платформа" .. (entry.up and (L" наверху вышки") or "") .. L", где " .. entry.keeper)
            end
            if entry.ride then addLine(block, "ride", L"затем " .. entry.ride) end
            addLine(block, "status", L"потом к цели: " .. (entry.onward or (L"цель")))
        elseif entry.entrance then
            local point = entry.option and entry.option.point or P.Door(selected)
            local label = entry.option and entry.option.label or point.label
            local far = P.Reach(point)
            block:SetHeader("  " .. (label or (atlas.ZoneName(point.mapID) .. (" (%.0f, %.0f)"):format(point.x, point.y)))
                .. (far and (DIM .. " • " .. far .. "|r") or ""))
            -- A way in that is not a door says what to do with it.
            local under = point.note or point.hint
            if under then addLine(block, "todo", under) end
        elseif entry.boss then
            P.BossButton(block.RouteButton, entry)
            local leg, step, steps = P.BossLeg(entry)
            local name = atlas.BossName(entry.boss, selected)
            block:SetHeader((entry == bossTarget and (labelTone .. L"Босс|r  ") or "  ") .. name .. (steps > 1 and ("  |cffaaaaaa%d/%d|r"):format(step, steps) or ""))
            local hint = leg and P.LegText(leg) or entry.note
            if P.BossInSight() then hint = L"|cff9bd8eaВ поле зрения|r • стрелка над полоской здоровья" end
            addLine(block, "location", hint)
            if not compact and steps > 1 then
                local following = entry.legs[step+1]
                addLine(block, "next", following and (L"|cffaaaaaaЗатем • " .. P.LegText(following) .. "|r")
                    or (L"|cffaaaaaaЩелчок по строке — снова первый шаг|r"))
            end
        elseif entry.routeCount then
            block:SetHeader(labelTone .. (routeExpanded and "– " or "+ ") .. L"Советы • " .. entry.routeCount .. "|r")
        elseif entry.secret then
            local note = entry.secret
            local step = readStep[note]
            local suffix = step and ("  %d/%d"):format(step, #note) or ""
            block:SetHeader("  " .. note.title .. suffix)
            addLine(block, "action", step and note[step] or entry.action)
        else
            local title = P.Title(entry.id)
            if entry == focus and not entry.task then
                -- The quest under way is called by its state, as everywhere on the page.
                local id = entry.step or entry.id
                local word = entry.state ~= "active" and (L"Не взято") or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and (L"Сдать") or (L"Задание")
                block:SetHeader(labelTone .. word .. "|r  " .. title)
                -- In a fight the line is short: what is left, not the text of the quest.
                local short = compact and entry.state ~= "active" and P.InsideSource and P.InsideSource(entry)
                addLine(block, "status", short or (compact and P.ShortHint and P.ShortHint(selected, entry)) or P.StepHint(selected, entry))
                if compact and entry.nearBoss then addLine(block, "by", L"у босса: " .. entry.nearBoss) end
            elseif entry.task then
                -- A quest of the run in three words: not taken, taken, ready; and the one
                -- thing worth knowing about it.
                local tone = entry.task == L"готово" and "|cff71c886" or entry.task == L"взято" and "|cffffd34d" or "|cffffffff"
                local hint = P.TaskHint and P.TaskHint(entry)
                if entry.task == L"не взято" and entry.givenOutside then
                    local who = entry.place and atlas.PlaceName(entry.place)
                    local zone = entry.place and entry.place.mapID and atlas.ZoneName(entry.place.mapID)
                    hint = L"снаружи" .. (who and (": " .. who) or "") .. ((zone and zone ~= who) and (" • " .. zone) or "")
                end
                -- The hint goes under the name: beside it the line ran over the column.
                block:SetHeader("  " .. tone .. entry.task .. ":|r «" .. title .. "»")
                if hint then addLine(block, "left", hint) end
                -- Where in here (the owner, 17.11.2026: "nothing is clear in the dungeons").
                local where = entry.task == L"взято" and P.WhereInside and P.WhereInside(entry)
                if where then addLine(block, "where", where) end
                if entry.task == L"не взято" and entry.byBoss then addLine(block, "by", L"у босса: " .. entry.byBoss) end
            elseif entry.prep then
                -- The quest under its own name; under it, what to do about it and where.
                local goal = (entry.step ~= entry.id and entry.id) or entry.leads
                local step = P.Title(entry.step) or title
                -- The chain it belongs to, whatever its steps are called.
                local chainGoal = goal
                -- A quest that only repeats itself is no chain to speak of.
                if goal and P.Title(goal) == step then goal = nil end
                local locked = entry.levelLocked or entry.unknown
                -- Accents: the card to do first in gold, the rest pale; the step of a chain
                -- in orange; the word of what to do in its own colour; the distance in gold.
                local GOLD, GREEN, BLUE, ORANGE, PALE = "|cffffd34d", "|cff71c886", "|cff7fd4ff", "|cffffa64d", "|cffe8dcc0"
                -- In the look of the game's quests the name wears the colour of the quest's
                -- difficulty, as theirs do.
                local tone = locked and DIM or entry.lead and GOLD or PALE
                if nativeLook() and not locked and GetQuestDifficultyColor and P.QuestInfo then
                    local info = P.QuestInfo(goal or entry.id)
                    local c = info and info.level and info.level > 0 and GetQuestDifficultyColor(info.level)
                    if type(c) == "table" and c.r then tone = ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
                end
                local chain = ""
                if goal then
                    local _, at, total = chainOf(goal)
                    chain = ORANGE .. (total and (L"шаг " .. at .. L" из " .. total .. ":") or (L"шаг цепочки:")) .. "|r "
                end
                local named = goal and (" «" .. step .. "»") or ""
                local native = nativeLook()
                -- In the look of the game's quests the step is counted even where every
                -- step of the chain bears one name ("Испытание знаний", eight times).
                local links, linkNow
                if native and not locked and P.Chain then
                    -- The last quest of a chain is a step of it too: the steps before it count.
                    local ok, list, at = pcall(P.Chain, chainGoal or entry.id)
                    if ok and type(list) == "table" and #list > 1 then
                        links, linkNow = list, at
                        if chain == "" then chain = ORANGE .. L"шаг " .. at .. L" из " .. #list .. ":|r " end
                    end
                end
                local taken = entry.state == "active"
                -- The layout of 14.11.2026: the name in gold (grey when it is not to be had
                -- yet), nothing beside it; "chain" and "shared" are said in the lines under it.
                if native then tone = locked and "|cff8e8c87" or "|cfff5cb66" end
                -- The step of a chain stands in the gold line, by the name (the owner,
                -- 15.11.2026: "put 2 of 4 in the yellow part: it all runs together and it is not
                -- clear what to do next in the chain"); the line under it begins with the step.
                local chainAt, chainTotal = linkNow, links and #links
                if native and not chainTotal and goal then
                    local _, a, t = chainOf(goal)
                    chainAt, chainTotal = a, t
                end
                local count = (native and chainAt and chainTotal and chainTotal > 1) and ("  |cffffffff" .. chainAt .. "/" .. chainTotal .. "|r") or ""
                -- The distance at the right is placed before the name is written: the name is
                -- laid out in the room left to it, and a second line of it pushes the lines
                -- under it down. (Placed after, a long name went onto a second line over the
                -- line under it: "Идол древней империи Гурубаши" with "за морем", 15.11.2026.)
                local openEarly = native and unfolded ~= nil and unfolded == (chainGoal or entry.id)
                if native and not openEarly and block.Distance and entry.place and not locked then
                    local whoEarly = atlas.PlaceName(entry.place)
                    local someone = whoEarly and (entry.handin or (entry.stepActive and entry.act == "turnin")
                        or (not entry.working and not taken and not entry.begins and not entry.stepActive))
                    local outHere = entry.working and not (entry.work and entry.work.dungeon) and entry.place.mapID
                    local farEarly = (someone or outHere) and P.Reach(entry.place)
                    if farEarly then
                        local main, rest = farEarly:match("^([%d%.]+ %S+)[,%s]*(.*)$")
                        block:Distance(main or farEarly, (rest ~= "" and rest) or nil)
                    end
                end
                block:SetHeader("  " .. tone .. (P.Title(goal or entry.id) or title) .. "|r" .. count)
                local act, said
                if locked then
                    act = entry.note or (L"пока недоступно")
                    said = true
                elseif entry.handin then
                    act = chain .. GREEN .. L"сдать|r" .. named
                elseif entry.working then
                    -- The owner: "I have taken quests, and I do not understand where they are
                    -- done: in the dungeon, or now?" Out here, and it says so.
                    -- (Work in another dungeon keeps "do": the line of the place says its door.)
                    -- (The owner, 15.11.2026: "take away the stupid 'do out here' over every quest:
                    -- 'Do before going in' is written above it already." The part says the deed;
                    -- the line says what and where. Work in another dungeon keeps "do".)
                    local what = entry.work and entry.work.text and not goalsOf(entry.step or entry.id) and entry.work.text or nil
                    local verb = (entry.work and entry.work.dungeon) and (BLUE .. L"сделать|r") or ""
                    act = chain .. verb .. named .. (what and (((verb ~= "" or named ~= "") and ": " or "") .. what) or "")
                elseif taken then
                    act = entry.handInside and (chain .. GREEN .. L"сдать внутри|r" .. named .. (type(entry.handInside) == "string" and (": " .. entry.handInside) or ""))
                        or (goal and (chain .. GREEN .. L"в журнале|r" .. named .. DIM .. L", делается внутри|r") or (GREEN .. L"в журнале|r" .. DIM .. L", делается внутри|r"))
                    said = true
                elseif entry.stepActive then
                    -- A step of the chain that is in the log: to hand in, or to finish - and
                    -- what is left of it, from the quest log (the owner, 15.11.2026: "сейчас:
                    -- доделать" and nothing more on "In Search of the Lost City").
                    local left
                    if entry.act ~= "turnin" and not (entry.work and entry.work.text) then
                        local list = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(entry.step)
                        if type(list) == "table" and #list > 0 then
                            local open = {}
                            for _, o in ipairs(list) do
                                if not o.finished and type(o.text) == "string" and o.text ~= "" and not (issecretvalue and issecretvalue(o.text)) then open[#open+1] = o.text end
                            end
                            left = #open > 0 and table.concat(open, ", ") or nil
                        elseif P.Objectives then
                            left = P.Objectives(entry.step)
                        end
                    end
                    act = chain .. (entry.act == "turnin" and (GREEN .. L"сдать|r") or (BLUE .. L"доделать|r")) .. named
                        .. (left and (": " .. left) or "")
                elseif entry.begins then
                    -- From whom, with what, or by what it begins in there.
                    local source = P.InsideSource and P.InsideSource(entry)
                    if source == L"начнётся с предмета" then
                        act = chain .. DIM .. L"начнётся внутри с найденного предмета|r" .. (goal and (":" .. named) or "")
                    else
                        act = chain .. DIM .. L"взять внутри|r" .. named .. (source and (": " .. (source:gsub(L"^выдаёт ", ""))) or "")
                    end
                    said = true
                else
                    act = chain .. GOLD .. L"взять|r" .. named
                    said = not goal
                end
                -- The owner: "can we not bring it all into one? I click the quest and it
                -- unfolds; a task done is struck out, without any 'handed in', and the next
                -- comes. There is a lot of everything now." So in the look of the game's
                -- quests a quest is two lines, what to do and where; clicked, it unfolds in
                -- place: the steps of its chain, the done ones struck out, the one under way
                -- in gold with what to do and where under it, the way there if it is not a
                -- straight walk. No window apart.
                local open = native and unfolded ~= nil and unfolded == (chainGoal or entry.id)
                block.unfolded = open or nil
                -- Where: who, the zone, how far.
                local function whereLine(deep)
                    if entry.place and not locked then
                        local who = atlas.PlaceName(entry.place)
                        local zone = entry.place.mapID and atlas.ZoneName(entry.place.mapID)
                        local far = P.Reach(entry.place)
                        local where = {}
                        if who then where[#where+1] = who end
                        if zone and zone ~= who then where[#where+1] = DIM .. zone .. "|r" end
                        if far then where[#where+1] = GOLD .. far .. "|r" end
                        if #where > 0 then addLine(block, "where", (deep and "\t" or "") .. table.concat(where, DIM .. " • |r")) end
                    elseif entry.line and not locked then
                        addLine(block, "where", (deep and "\t" or "") .. DIM .. L"место неизвестно|r")
                    end
                end
                -- The round sign already says taken or not: no line for it in this look.
                if native then said = true end
                -- Who to go to is part of what to do when the deed is to take or to hand in.
                local who = entry.place and not locked and atlas.PlaceName(entry.place)
                local toSomeone = who and (entry.handin or (entry.stepActive and entry.act == "turnin")
                    or (not entry.working and not taken and not entry.begins and not entry.stepActive))
                if open then
                    -- Seen in the game with eight steps listed first: "the goal is somewhere
                    -- at the very bottom, out of sight." And the mock-up drawn for it: what
                    -- to do now, where, through what; then the chain in three lines - the
                    -- steps done struck out in one, the one under way in gold, the rest.
                    local core = (chain ~= "" and act:sub(1, #chain) == chain) and act:sub(#chain + 1) or act
                    if links and named ~= "" then
                        local from, to = core:find(named, 1, true)
                        if from then core = core:sub(1, from - 1) .. core:sub(to + 1) end
                    end
                    if core:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("%S") or toSomeone then
                        addLine(block, "act", GOLD .. L"сейчас:|r " .. core .. (toSomeone and (" — " .. who) or ""))
                    end
                    if entry.working then goalLines(block, entry.step or entry.id, entry.work and entry.work.text) end
                    hintLine(block, entry)
                    alsoLines(block, entry)
                    if entry.place and not locked then
                        local zone = entry.place.mapID and atlas.ZoneName(entry.place.mapID)
                        local far = P.Reach(entry.place)
                        local where = {}
                        if who and not toSomeone then where[#where+1] = who end
                        if zone and zone ~= who then where[#where+1] = zone end
                        if far then where[#where+1] = GOLD .. far .. "|r" end
                        if #where > 0 then addLine(block, "where", GOLD .. L"куда:|r " .. table.concat(where, DIM .. " • |r")) end
                        if P.Plan then
                            local ok, plan = pcall(P.Plan, entry.place)
                            if ok and plan and plan.text then
                                local first = plan.legs and plan.legs[1]
                                local lead = (plan.spell and plan.city and (L"телепорт: " .. plan.city)) or (first and (first.ride or first.text)) or plan.text
                                local far = plan.start and (plan.start >= 1000 and (L"%.1f км"):format(plan.start / 1000)
                                    or (L"%d м"):format(math.floor(plan.start / 10 + .5) * 10))
                                addLine(block, "road", GOLD .. L"через|r " .. lead .. (far and (DIM .. " • |r" .. far) or ""))
                            end
                        end
                    elseif entry.line and not locked then
                        addLine(block, "where", DIM .. L"место неизвестно|r")
                    end
                    if links then
                        local past, total = linkNow - 1, #links
                        local function name(i) return P.Title(links[i]) or "?" end
                        if past == 1 then
                            addStruck(block, "past", DIM .. "1. " .. name(1) .. "|r")
                        elseif past > 1 then
                            addStruck(block, "past", DIM .. "1–" .. past .. ". " .. (name(1) == name(past) and name(1) or (name(1) .. " – " .. name(past))) .. "|r")
                        end
                        addLine(block, "step", GOLD .. linkNow .. ". " .. name(linkNow) .. "|r" .. DIM .. L" • шаг " .. linkNow .. L" из " .. total .. "|r")
                        if linkNow + 1 == total then
                            addLine(block, "rest", DIM .. total .. ". " .. name(total) .. "|r")
                        elseif linkNow < total then
                            addLine(block, "rest", DIM .. (linkNow + 1) .. "–" .. total .. L": далее по цепочке|r")
                        end
                    end
                elseif native then
                    -- Folded, as the layout of 14.11.2026 draws a card: under the name one
                    -- line in cream, what to do, with whom, where, how far ("chain 1/3 •" in
                    -- front for a chain); under it, dim, the one thing worth knowing.
                    local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
                    local core = (chain ~= "" and act:sub(1, #chain) == chain) and act:sub(#chain + 1) or act
                    local at, total = linkNow, links and #links
                    if not total and goal then
                        local _, a, t = chainOf(goal)
                        at, total = a, t
                    end
                    local tail, far = "", nil
                    if toSomeone then
                        local zone = entry.place.mapID and atlas.ZoneName(entry.place.mapID)
                        far = P.Reach(entry.place)
                        tail = ": " .. who .. ((zone and zone ~= who) and (" • " .. zone) or "")
                    elseif entry.working and not (entry.work and entry.work.dungeon) and entry.place and entry.place.mapID and not locked then
                        -- Work out here: from whom or from what, and where; how far stands at the
                        -- right. (The owner, 15.11.2026: "The Third Troll Legend • Stranglethorn":
                        -- nothing said it is taken from the tablet "Fall of Gurubashi".)
                        local zone = atlas.ZoneName(entry.place.mapID)
                        local from = entry.work and entry.work.name
                        far = P.Reach(entry.place)
                        tail = ((type(from) == "string" and from ~= "") and (" • " .. from) or "") .. (zone and (" • " .. zone) or "")
                    end
                    if far and block.Distance then
                        -- "10.8 км через проход": the figure at the right, the rest under it.
                        local main, rest = far:match("^([%d%.]+ %S+)[,%s]*(.*)$")
                        block:Distance(main or far, (rest ~= "" and rest) or nil)
                    end
                    -- In the part "the group shares" the line says where to run if nobody does
                    -- (the layout of 15.11.2026); the part's name says the rest.
                    local steps = links and #links > 1 and not locked and linkNow
                    if steps then chainSteps(block, entry, links, linkNow, 1, linkNow) end
                    if entry.askGroup and not taken and toSomeone then
                        addLine(block, "act", "|cffe6e0d2" .. L"если не поделятся" .. plain(tail) .. "|r")
                    else
                        local line = (plain(core) .. plain(tail)):gsub("^%s*•%s*", "")
                        -- To hand in: the deed in green at the front (the owner, 15.11.2026, with the
                        -- tablet in his bag: "I don't understand what to do next").
                        local give = L"сдать"
                        local after = line:sub(#give + 1, #give + 1)
                        if line:sub(1, #give) == give and (after == "" or after == " " or after == ":") then
                            addLine(block, "act", "|cff71c886" .. L"Сдай" .. "|r|cffe6e0d2" .. line:sub(#give + 1) .. "|r")
                        else
                            local said = addLine(block, "act", "|cffe6e0d2" .. line .. "|r")
                            -- One creature to find: the sight at the end of the line.
                            local whom = entry.working and entry.work and entry.work.target
                            if whom and not goalsOf(entry.step or entry.id) then targetLine(block, said, whom) end
                        end
                    end
                    if entry.working then goalLines(block, entry.step or entry.id, entry.work and entry.work.text) end
                    if steps then chainSteps(block, entry, links, linkNow, linkNow + 1, #links) end
                    alsoLines(block, entry)
                    local note
                    if entry.atDoor and not taken then note = L"у входа — возьми по дороге в подземелье"
                    elseif entry.askGroup and not taken then note = nil
                    elseif entry.share and not taken and not total and not locked then note = L"может поделиться группа" end
                    -- The owner: "the shareable quests are not marked well." A quest the group can
                    -- give wears the group's picture and the light blue of the layout.
                    if note and (entry.askGroup or (entry.share and not entry.atDoor)) and not taken then
                        addLine(block, "note", "|TInterface\\Icons\\INV_Misc_GroupNeedMore:13:13|t |cff8bc7f2" .. note .. "|r")
                    elseif note then
                        addLine(block, "note", "|cff8e8c87" .. note .. "|r")
                    end
                else
                    -- Taken or not, in a word, where the line below does not say it itself:
                    -- the same word as in the count over the list.
                    if not said then
                        addLine(block, "state", taken and (GREEN .. L"взято|r") or (ORANGE .. L"не взято|r" .. (goal and (DIM .. L" • сначала цепочка|r") or "")))
                    end
                    addLine(block, "act", act)
                    whereLine(false)
                end
                if entry.atDoor and not taken and not native then addLine(block, "door", BLUE .. L"у входа: возьми по дороге в подземелье|r") end
                if entry.shared and not locked and not native then
                    addLine(block, "shared", entry.askGroup and (L"попроси группу поделиться — бежать не нужно") or (L"может поделиться группа"))
                end
            elseif entry.line then
                -- An errand in a list: its quest and how far its giver is.
                local far = P.Reach(entry.place)
                block:SetHeader("  " .. P.Title(entry.step)
                    .. (far and (DIM .. " • " .. far .. "|r") or (entry.place and "" or (DIM .. L" • место неизвестно|r"))))
                if entry.shared then addLine(block, "shared", L"им может поделиться группа") end
                -- A step of a chain says of which chain and which step it is.
                local goal = entry.step ~= entry.id and entry.id or entry.leads
                if goal then
                    local _, at, total = chainOf(goal)
                    addLine(block, "chain", (total and (L"цепочка " .. at .. "/" .. total .. L" к «") or (L"цепочка к «")) .. P.Title(goal) .. "»")
                end
            elseif entry.errand then
                -- An errand outside: who to go to and how far, then what to do there.
                local quest = "«" .. P.Title(entry.step) .. "»"
                local who = entry.place and atlas.PlaceName(entry.place)
                local far = P.Reach(entry.place)
                block:SetHeader("  " .. (who or quest) .. (far and (DIM .. " • " .. far .. "|r") or ""))
                local line = (entry.handin and (L"сдать ") or entry.working and (L"сделать ") or (L"взять ")) .. quest
                if entry.working and entry.work.text then line = line .. ": " .. entry.work.text end
                local goal = entry.step ~= entry.id and entry.id or entry.leads
                if goal then line = line .. L", цепочка к «" .. P.Title(goal) .. "»" end
                if entry.shared then line = line .. L" • делится" end
                if not who then line = line .. L" • место неизвестно" end
                addLine(block, "status", line)
            else
                if entry.chain then title = P.Title(entry.step) .. DIM .. L" • к «" .. title .. "»|r" end
                -- Among the quests of the run, the ones still to be picked up in there.
                block:SetHeader("  " .. ((entry.levelLocked or entry.unknown) and (DIM .. title .. "|r") or title))
                if not entry.brief then
                    addLine(block, "status", entry.short or entry.note)
                elseif selected and P.InDungeon(selected) and P.InsideHint then
                    -- Inside, a title alone is no help: under it, from whom and out of what.
                    local hint = not (runTold[entry.id] or runTold[entry.step]) and P.InsideHint(entry)
                    if hint then addLine(block, "status", hint) end
                elseif entry.begins and P.InsideSource then
                    local hint = P.InsideSource(entry)
                    addLine(block, "status", hint and (L"внутри: " .. hint) or (L"внутри"))
                end
            end
        end
        if displayed > 0 and not self:CanFitBlock(block) then break end
        if not self:LayoutBlock(block) then break end
        displayed = displayed + 1
    end
    self.fromBlockOffsetY = -4
    pcall(drawPanel, self)
    if browsing then
        self:SetHeader(L"Подземелья • уровень " .. (UnitLevel and UnitLevel("player") or "?"))
    else
        self:SetHeader(shortName(selected))
    end
    self.back:SetShown(not browsing and not compact and not self:IsCollapsed() and not native)
    if self.bookButton then self.bookButton:SetShown(not native) end
    self.prev:SetShown(first > 1 and not self:IsCollapsed())
    self.nextPage:SetShown(first + displayed <= #entries and not self:IsCollapsed())
    -- The page arrows appear only when the rows do not fit the screen.
    local pager = self.prev:IsShown() or self.nextPage:IsShown()
    self.back:ClearAllPoints()
    self.back:SetPoint("RIGHT", pager and self.prev or self.Header.MinimizeButton, "LEFT", -2, 0)
    if self.pickMenu then
        self.pickMenu:ClearAllPoints()
        self.pickMenu:SetPoint("RIGHT", pager and self.prev or self.Header.MinimizeButton, "LEFT", -2, 0)
    end
    if self.isBoard then
        -- Seen in the game: "Монастырь Алого орде" cut by the button of the book. The
        -- name gets what is left of the header beside the buttons, at the size of a row.
        self.Header.Text:SetWidth(native and (pager and 170 or 210) or (pager and 134 or 174))
        self.Header.Text:SetFontObject(nativeLook() and ownFonts().head or ownFonts().row or GameFontNormal)
    else
        self.Header.Text:SetWidth(browsing and 168 or (pager and 96 or (self.bossMenu:IsShown() and 136 or 184)))
        self.Header.Text:SetFontObject(browsing and GameFontNormal or ownFonts().row or GameFontNormal)
    end
end

local function refreshFilters()
    first, catalogFirst, history = 1, 1, {}
    countsDirty = true
    rebuildList()
    tracker:MarkDirty()
end
P.RefreshFilters = refreshFilters

local function createFilterMenu()
    local button = CreateFrame("DropdownButton", nil, tracker.Header)
    button:SetSize(24, 19)
    button:SetPoint("RIGHT", tracker.prev, "LEFT", -2, 0)
    local dots = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dots:SetPoint("CENTER")
    dots:SetText("•••")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:HookScript("OnEnter", function() tip(button, L"Фильтры подземелий") end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetupMenu(function(_, menu)
        menu:CreateCheckbox(L"Подсказки в пати", function() return db.partyTips ~= false end, function()
            db.partyTips = db.partyTips == false
        end)
        menu:CreateCheckbox(L"Скрыть сданные", function() return db.hideDone and not db.fullCatalog end, function()
            db.hideDone = db.fullCatalog or not db.hideDone
            db.fullCatalog = false
            refreshFilters()
        end)
        menu:CreateCheckbox(L"Показать все", function() return db.fullCatalog end, function()
            db.fullCatalog = not db.fullCatalog
            refreshFilters()
        end)
    end)
    return button
end

-- The owner: "it is not clear how to choose the dungeon. It could be three dots: a menu
-- comes out and one picks the dungeon, as in the group finder; and there one can mark what
-- is passed and what is not, and see how many quests are done." So: three dots in the
-- heading. The menu lists the dungeons that have quests for the character, by level, each
-- with its levels and how many quests are handed in and taken; the passed ones below; a
-- click picks; beside each, "put away with the passed" or "bring back"; the passed can be
-- hidden by the line that heads them; the ones not for the character's level yet stand
-- behind one line of their own.
local function dungeonMenu(owner, menu)
    if not (catalog and db) then return end
    local level = UnitLevel and UnitLevel("player") or 60
    -- Counted anew each time the menu comes out: the numbers kept for the list of dungeons
    -- are only as fresh as the last look at that list.
    local fresh = {}
    local function count(d)
        if not fresh[d.key] then
            local ok, finished, total, taken, ready = pcall(P.Progress, d)
            fresh[d.key] = ok and {finished=finished, total=total, taken=taken, ready=ready or 0}
                or progress[d.key] or {finished=0, total=0, taken=0, ready=0}
        end
        return fresh[d.key]
    end
    local function passed(d) return db.hidden[d.key] or isClosed(count(d)) end
    -- Not for this level yet: the lowest level it is meant for is well above the character's.
    local function tooHigh(d) return type(d.minLevel) == "number" and d.minLevel > level + 2 end
    local function line(d)
        local c = count(d)
        local tone = db.hidden[d.key] and "|cff808080" or isClosed(c) and "|cff40c040" or "|cffffffff"
        -- Handed in; then, of those in the log, the ones done and waiting to be handed in,
        -- and the ones still to do. (Seen by the owner as "three taken, and they are done".)
        local ready = c.ready or 0
        local doing = c.taken - ready
        return tone .. atlas.DungeonName(d) .. "|r  |cff9d9d9d" .. (d.minLevel or "?") .. "–" .. (d.maxLevel or "?")
            .. L" • сдано " .. c.finished .. L" из " .. c.total .. "|r"
            .. (ready > 0 and (L"|cffffd34d • к сдаче " .. ready .. "|r") or "")
            .. (doing > 0 and (L"|cff9d9d9d • в работе " .. doing .. "|r") or "")
    end
    -- The menu shows what was true when it came out; what changes its lines closes it and
    -- calls it up again at once. (Seen in the game: "hide the passed" ticked, and the
    -- passed still there.)
    local function again()
        if MenuUtil and MenuUtil.CreateContextMenu and C_Timer and C_Timer.After and owner then
            C_Timer.After(0, function() MenuUtil.CreateContextMenu(owner, dungeonMenu) end)
        end
        return MenuResponse and MenuResponse.CloseAll or nil
    end
    local function pick(d)
        return function()
            if P.Choose then P.Choose(d) end
            -- A dungeon picked: the menu is done with.
            return MenuResponse and MenuResponse.CloseAll or nil
        end
    end
    local function move(d)
        return function()
            db.hidden[d.key] = not db.hidden[d.key] or nil
            P.LeaveHidden()
            P.Refresh()
            return again()
        end
    end
    -- A dungeon: a click picks it; beside it, "open" and "put away" (or "bring back").
    local function row(to, d)
        local item
        if to.CreateRadio then item = to:CreateRadio(line(d), function() return selected == d and not browsing end, pick(d))
        else item = to:CreateButton(line(d), pick(d)) end
        if type(item) == "table" and item.CreateButton then
            item:CreateButton(L"Открыть", pick(d))
            if db.hidden[d.key] then item:CreateButton(L"Вернуть в список", move(d))
            elseif not isClosed(count(d)) then item:CreateButton(L"Убрать в пройденные", move(d)) end
        end
    end
    local open, closed, high = {}, {}, {}
    for _, d in ipairs(catalog) do
        if count(d).total > 0 then
            if passed(d) then closed[#closed+1] = d
            elseif tooHigh(d) then high[#high+1] = d
            else open[#open+1] = d end
        end
    end
    if menu.CreateTitle then menu:CreateTitle(L"Подземелья • уровень " .. level) end
    for _, d in ipairs(open) do row(menu, d) end
    -- The owner: "the button did not work, the passed stayed; and it should stand by the
    -- passed. And the ones I am not going to do - let me throw them in with the passed."
    if #closed > 0 then
        if menu.CreateDivider then menu:CreateDivider() end
        menu:CreateButton(L"|cffffd100Пройдено и убрано: " .. #closed .. (db.menuNoPassed and (L" — показать|r") or (L" — скрыть|r")), function()
            db.menuNoPassed = not db.menuNoPassed or nil
            return again()
        end)
        if not db.menuNoPassed then
            for _, d in ipairs(closed) do row(menu, d) end
        end
    end
    -- "The high-level ones we cannot do, we are not going there": out of the list above,
    -- behind one line.
    if #high > 0 then
        if menu.CreateDivider then menu:CreateDivider() end
        local later = menu:CreateButton(L"|cff9d9d9dНе по уровню: " .. #high .. "|r")
        if type(later) == "table" and later.CreateButton then
            for _, d in ipairs(high) do row(later, d) end
        end
    end
    if menu.CreateDivider then menu:CreateDivider() end
    menu:CreateButton(L"Весь список подземелий", function() if tracker and tracker.goBack then tracker.goBack() end end)
    menu:CreateButton("|TInterface\\HelpFrame\\HelpIcon-Bug:16|t " .. L"Сообщить об ошибке", function() if P.ShowBugReport then P.ShowBugReport() end end)
end
P.DungeonMenu = dungeonMenu

local function createPickMenu()
    -- Seen in the game: the menu came out once and not the second time. A button of the
    -- drop-down kind keeps its own count of open and shut; a plain button that calls the
    -- menu up at every click keeps none.
    -- The owner: "these three dots should open the journal of the quests." The left click
    -- opens the book of the dungeon; the menu of the dungeons is the right click.
    local plain = MenuUtil and MenuUtil.CreateContextMenu and true or false
    local button = CreateFrame("Button", nil, tracker.Header)
    button:SetSize(24, 19)
    button:SetPoint("RIGHT", tracker.Header.MinimizeButton, "LEFT", -2, 0)
    local dots = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dots:SetPoint("CENTER")
    dots:SetText("•••")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:HookScript("OnEnter", function() tip(button, L"Журнал заданий", L"Все задания и боссы этого подземелья. Правый щелчок — меню: другое подземелье, скрыть пройденные.") end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouse)
        GameTooltip:Hide()
        if mouse == "RightButton" then
            if plain then if P.Track then P.Track("DungeonMenuOpened") end; MenuUtil.CreateContextMenu(self, dungeonMenu) end
            return
        end
        if P.OpenBook then P.OpenBook(selected) end
    end)
    button.openMenu = dungeonMenu
    return button
end

-- The owner, having seen the list twice inside the game's own column of tasks: nothing
-- like the mock-up, a narrow strip of small print. That column is as wide as the game
-- makes it and its print is the game's. So the list leaves it: a panel of its own, as
-- on the mock-up, wider and half as large again, standing to the left of the column of
-- tasks, dragged by its header, folded by its button. It answers to the same few calls
-- the game's column answered to, so the pages are built as before.
local BOARD_W, BOARD_HEAD, PAD_L, PAD_R, INDENT = 300, 30, 26, 12, 12

-- The owner, with the panel standing beside the game's column of tasks: "let us build it
-- back in under All Quests, in the same look." So the panel keeps its own look and takes
-- a place in the game's column: a section of the column that is nothing but room, as
-- tall as the panel, first under the column's header; the game lays its own sections
-- out below it, and the panel stands on that room. /dq dock lets it loose again, to be
-- dragged where one likes.
local slot, slotFault
local function dock(board)
    if slotFault or (db and db.boardFree) then return end
    if not (ObjectiveTrackerManager and ObjectiveTrackerFrame and QuestObjectiveTracker and ObjectiveTrackerManager.SetModuleContainer) then return end
    local containers = ObjectiveTrackerManager.containers
    if not (type(containers) == "table" and containers[ObjectiveTrackerFrame]) then return end
    if not slot then
        local ok, frame = pcall(CreateFrame, "Frame", "DungeonQuestForeverSlot", ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
        if not (ok and frame) then return end
        slot = frame
        slot.isSlot = true
        slot.uiOrder = (QuestObjectiveTracker.uiOrder or 4) - .5
        slot.blockTemplate = "ForeverDungeonPrepRowTemplate"
        slot.fromBlockOffsetY, slot.fromHeaderOffsetY = 0, 0
        local function room(self)
            if not board.docked then return end
            -- The room is counted in the column's own measure: the two may be scaled apart.
            local head = self.Header and self.Header.GetHeight and self.Header:GetHeight()
            head = type(head) == "number" and head or 25
            local mine = board.GetEffectiveScale and board:GetEffectiveScale()
            local its = self.GetEffectiveScale and self:GetEffectiveScale()
            local ratio = (type(mine) == "number" and type(its) == "number" and its > 0) and mine / its or 1
            local height = board.GetHeight and board:GetHeight()
            local tall = math.max(1, (type(height) == "number" and height or BOARD_HEAD) * ratio - head + 8)
            if self.SetHeader then self:SetHeader(" ") end
            local block = self:GetBlock("room")
            if not block then return end
            block:SetHeader(" ")
            -- The fonts of the game's own rows, read off this block of the column once.
            if not nativeFonts then
                local got = {}
                pcall(function()
                    got.row = block.HeaderText:GetFontObject()
                    local line = block:AddObjective("probe", " ", nil, true)
                    got.sub = line.Text:GetFontObject()
                end)
                pcall(function() got.head = self.Header.Text:GetFontObject() end)
                if type(got.row) == "table" or type(got.sub) == "table" then
                    nativeFonts = {row=type(got.row) == "table" and got.row or nil, sub=type(got.sub) == "table" and got.sub or nil,
                        head=type(got.head) == "table" and got.head or nil}
                    if C_Timer and C_Timer.After then C_Timer.After(0, function() board:MarkDirty() end) end
                end
            end
            block.height = tall
            if block.SetHeight then block:SetHeight(tall) end
            -- Nothing of the room takes the mouse: the panel stands on it.
            if block.EnableMouse then block:EnableMouse(false) end
            if block.HeaderButton and block.HeaderButton.EnableMouse then block.HeaderButton:EnableMouse(false) end
            self.room = tall
            self:LayoutBlock(block)
        end
        -- Whatever goes wrong in the room must not break the game's own column: the panel
        -- then stands free, as it did, for the rest of the sitting.
        slot.LayoutContents = function(self)
            local ok, err = pcall(room, self)
            if ok then return end
            slotFault = tostring(err)
            board.docked = false
            if db then db.dockFault = slotFault end
            if C_Timer and C_Timer.After then C_Timer.After(0, function() board:Place() end) else board:Place() end
        end
    end
    -- The section has no heading of its own to show: the panel's heading stands there.
    if slot.Header then
        if slot.Header.SetAlpha then slot.Header:SetAlpha(0) end
        if slot.Header.EnableMouse then slot.Header:EnableMouse(false) end
        local fold = slot.Header.MinimizeButton
        if fold and fold.EnableMouse then fold:EnableMouse(false) end
    end
    if slot.EnableMouse then slot:EnableMouse(false) end
    if not (ObjectiveTrackerFrame.HasModule and ObjectiveTrackerFrame:HasModule(slot)) then
        ObjectiveTrackerManager:SetModuleContainer(slot, ObjectiveTrackerFrame)
    end
    board.docked = true
    return slot
end

local function newBoard()
    local board = CreateFrame("Frame", "DungeonQuestForeverBoard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    board.isBoard = true
    board:SetSize(BOARD_W, BOARD_HEAD)
    board:SetFrameStrata("LOW")
    board:SetClampedToScreen(true)
    board:SetMovable(true)
    board:EnableMouse(true)
    -- The owner, of the black panel: "can you take this black background away? Something
    -- more like the original." The original is the game's own list of tasks: no box, the
    -- text over the world with its shadow. So no background and no frame by default; a
    -- card keeps a faint shade under it, enough to read on a bright ground. /dq back
    -- puts the dark box back for those who want it.
    -- The layout of 14.11.2026 drew the panel on a dark ground; seen in the game the owner
    -- said "why the black background? make it native, as it was, so that it is not apart
    -- from the quests". So no ground by default, as the game's own list; /dq back gives it.
    function board:Skin()
        local dark = db and db.boardBack == true
        if self.SetBackdrop then
            self:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=14, insets={left=3, right=3, top=3, bottom=3}})
            self:SetBackdropColor(.067, .075, .094, dark and .9 or 0)
            self:SetBackdropBorderColor(.30, .25, .18, dark and .8 or 0)
        end
        self.dark = dark and true or false
    end
    board:Skin()
    local scale = db and tonumber(db.boardScale) or 1
    board:SetScale(math.max(.8, math.min(2, scale)))
    local blockWidth = BOARD_W - PAD_L - PAD_R

    local header = CreateFrame("Frame", nil, board)
    board.Header = header
    header:SetPoint("TOPLEFT", board, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", board, "TOPRIGHT", 0, 0)
    header:SetHeight(BOARD_HEAD)
    header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.Text:SetPoint("LEFT", header, "LEFT", 14, -2)
    header.Text:SetJustifyH("LEFT")
    header.Text:SetWordWrap(false)
    local minimize = CreateFrame("Button", nil, header)
    header.MinimizeButton = minimize
    minimize:SetSize(18, 18)
    minimize:SetPoint("RIGHT", header, "RIGHT", -10, -2)
    minimize:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    minimize:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    minimize:SetScript("OnClick", function() if not board:IsCollapsed() then if P.Track then P.Track("PanelCollapsed") end end board:SetCollapsed(not board:IsCollapsed()) end)
    minimize:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimize, "ANCHOR_LEFT")
        GameTooltip:SetText(board:IsCollapsed() and (L"Развернуть панель") or (L"Свернуть панель"), 1, .83, .35)
        GameTooltip:Show()
    end)
    minimize:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local underline = header:CreateTexture(nil, "ARTWORK")
    if underline.SetColorTexture then underline:SetColorTexture(.72, .6, .36, .55) end
    underline:SetHeight(1)
    underline:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 0)
    underline:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 0)
    -- Dragged by the header; where it is left is remembered.
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not board.docked then board:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        if board.docked then return end
        board:StopMovingOrSizing()
        local point, _, relPoint, x, y = board:GetPoint(1)
        if db and point then db.board = {point, relPoint, x, y} end
    end)

    function board:Place()
        self:ClearAllPoints()
        local pos = db and db.board
        if self.docked and slot then
            -- In the game's column, on the room kept for it, right edges together; and
            -- as wide as the column, so that the signs stand under one another.
            local wide = slot.GetWidth and slot:GetWidth()
            local mine, its = self.GetEffectiveScale and self:GetEffectiveScale(), slot.GetEffectiveScale and slot:GetEffectiveScale()
            if type(wide) == "number" and wide > 150 and type(mine) == "number" and type(its) == "number" and mine > 0 then
                wide = wide * its / mine
                self:SetWidth(wide + PAD_L - 4)
                blockWidth = wide - 4 - PAD_R
            end
            self:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)
        elseif pos and pos[1] then
            self:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
        elseif ObjectiveTrackerFrame then
            -- To the left of the column of tasks, level with its top, wherever it stands.
            self:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPLEFT", -12, 0)
        else
            self:SetPoint("RIGHT", UIParent, "RIGHT", -320, 120)
        end
    end
    board:Place()

    board.blocks, board.pool = {}, {}
    function board:SetHeader(text)
        self.text = text
        self.Header.Text:SetText(text .. (self.collapsed and (L"|cff999999 • свёрнуто|r") or ""))
    end
    function board:IsCollapsed() return self.collapsed and true or false end
    function board:SetCollapsed(value)
        self.collapsed = value and true or false
        minimize:SetNormalTexture(self.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        if self.text then self:SetHeader(self.text) end
        self:MarkDirty()
    end
    -- As tall as the screen leaves it below its top; the pages turn past that.
    function board:Room()
        local top = self.GetTop and self:GetTop()
        if type(top) ~= "number" then return math.huge end
        return math.max(260, top - 96)
    end
    function board:Flush()
        if not self.LayoutContents then return end
        self.flushing = true
        self.blocks = {}
        for _, block in pairs(self.pool) do block.laid = false end
        self.lastBlock, self.used = nil, BOARD_HEAD
        local ok, err = pcall(self.LayoutContents, self)
        for _, block in pairs(self.pool) do
            if not block.laid then block:Hide() end
        end
        self:SetHeight(self:IsCollapsed() and BOARD_HEAD or (self.used + 12))
        self.flushing = false
        -- The room in the game's column follows the height of the panel.
        if self.docked and slot and slot.MarkDirty then pcall(slot.MarkDirty, slot) end
        if not ok then error(err, 0) end
    end
    -- Into the game's column, or out of it.
    function board:Dock(on)
        self.docked = false
        if on then
            dock(self)
        elseif slot then
            if slot.MarkDirty then pcall(slot.MarkDirty, slot) end
        end
        self:Place()
        self:MarkDirty()
        return self.docked
    end
    -- Laid out at once: the pages are small, and whoever asked reads the result next.
    function board:MarkDirty()
        if self.flushing then self.again = true return end
        self:Flush()
        if self.again then self.again = nil; self:Flush() end
    end

    local function newBlock()
        local block = CreateFrame("Frame", nil, board)
        block:SetSize(blockWidth, 14)
        block.HeaderText = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        block.HeaderText:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        block.HeaderText:SetJustifyH("LEFT")
        block.HeaderText:SetJustifyV("TOP")
        block.HeaderText:SetWordWrap(true)
        local glow = block:CreateTexture(nil, "BORDER")
        if glow.SetColorTexture then glow:SetColorTexture(1, 1, 1, .07) end
        glow:SetPoint("TOPLEFT", block, "TOPLEFT", -6, 2)
        glow:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 4, -2)
        glow:Hide()
        local button = CreateFrame("Button", nil, block)
        block.HeaderButton = button
        button:SetAllPoints(block)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouse) if board.OnBlockHeaderClick then board:OnBlockHeaderClick(block, mouse) end end)
        button:SetScript("OnEnter", function()
            glow:Show()
            if board.OnBlockHeaderEnter then board:OnBlockHeaderEnter(block) end
        end)
        button:SetScript("OnLeave", function()
            glow:Hide()
            if board.OnBlockHeaderLeave then board:OnBlockHeaderLeave(block) end
        end)
        local function small(icon)
            local b = CreateFrame("Button", nil, block)
            b:SetSize(18, 18)
            b:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
            b:SetNormalTexture(icon)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            if b.SetFrameLevel and button.GetFrameLevel then b:SetFrameLevel((button:GetFrameLevel() or 1) + 2) end
            b:Hide()
            return b
        end
        block.RouteButton = small("Interface\\Icons\\INV_Misc_Map_01")
        block.JournalButton = small("Interface\\Icons\\INV_Misc_Book_09")
        block.lines = {}
        -- The owner showed a page of the atlas's quest book: "see how pleasant it looks".
        -- What is pleasant there: every quest is a dark card of its own, with a sign of
        -- its state on the left (to take, in the log, to hand in, done, locked), its
        -- name, and a small grey line under it. A row here is dressed the same way, with
        -- the game's own signs: nothing is drawn.
        local plate = block:CreateTexture(nil, "BACKGROUND")
        if plate.SetColorTexture then plate:SetColorTexture(.16, .12, .09, .95) end
        plate:SetPoint("TOPLEFT", block, "TOPLEFT", -6, 3)
        plate:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 4, -3)
        plate:Hide()
        local sign = block:CreateTexture(nil, "ARTWORK")
        sign:SetSize(16, 16)
        sign:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        sign:Hide()
        block.plate, block.sign, block.inset = plate, sign, 0
        -- The round sign the game puts by its own quests: three dots for one under way,
        -- a "?" for one to hand in. It is the game's own button, made from its template
        -- and left deaf to the mouse; where the client has none, the plain sign stays.
        local function round(self, done)
            if not (POIButtonUtil and POIButtonUtil.Style) then return false end
            if self.poi == nil then
                local ok, made = pcall(CreateFrame, "Button", nil, self, "POIButtonTemplate")
                self.poi = ok and made or false
                if self.poi then
                    self.poi:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 3)
                    if self.poi.EnableMouse then self.poi:EnableMouse(false) end
                end
            end
            if not self.poi then return false end
            local style = done and POIButtonUtil.Style.QuestComplete or POIButtonUtil.Style.QuestInProgress
            local ok = pcall(function()
                self.poi:SetStyle(style)
                self.poi:UpdateButtonStyle()
            end)
            self.poi:SetShown(ok)
            return ok
        end
        function block:Dress(icon)
            self.dressed = icon and true or false
            local native = nativeLook()
            if self.plate.SetColorTexture then
                if board.dark then self.plate:SetColorTexture(.16, .12, .09, .95) else self.plate:SetColorTexture(0, 0, 0, .3) end
            end
            self.plate:SetShown(self.dressed and not native)
            local picture = type(icon) == "string" and icon or nil
            self.signFile = picture
            if picture then self.sign:SetTexture(picture) end
            local asGame = native and (picture == SIGN.ready or picture == SIGN.log) and round(self, picture == SIGN.ready)
            if self.poi and not asGame then self.poi:Hide() end
            self.sign:SetShown(picture ~= nil and not asGame)
            self.native = native
            self.inset = picture and (native and 24 or 20) or 0
            self.HeaderText:ClearAllPoints()
            self.HeaderText:SetPoint("TOPLEFT", self, "TOPLEFT", self.inset, 0)
        end
        -- The status on top of a page, as the layout of 14.11.2026 draws it (ChatGPT's
        -- code, approved by the owner): a plate in one of five colours with a bar on the
        -- left, and a button of the game's own under its lines. kind: "gold" (to take),
        -- "blue" (to hand in), "green" (all taken), "grey" (been inside), "red" (the boss).
        function block:Ready(kind, onClick, label, note)
            if kind == true then kind = "green" end
            local look = kind and PLATE[kind]
            if not look then
                if self.readyTint then self.readyTint:Hide() self.readyEdge:Hide() end
                if self.goButton then self.goButton:Hide() end
                return
            end
            if not self.readyTint then
                self.readyTint = self:CreateTexture(nil, "BACKGROUND", nil, 2)
                self.readyTint:SetPoint("TOPLEFT", self, "TOPLEFT", -6, 5)
                self.readyTint:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 4, -5)
                self.readyEdge = self:CreateTexture(nil, "ARTWORK")
                self.readyEdge:SetWidth(4)
                self.readyEdge:SetPoint("TOPLEFT", self, "TOPLEFT", -6, 5)
                self.readyEdge:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -6, -5)
            end
            if self.readyTint.SetColorTexture then self.readyTint:SetColorTexture(look.bg[1], look.bg[2], look.bg[3], look.bg[4]) end
            if self.readyEdge.SetColorTexture then self.readyEdge:SetColorTexture(look.bar[1], look.bar[2], look.bar[3], look.bar[4]) end
            self.readyTint:Show()
            self.readyEdge:Show()
            if not onClick then
                if self.goButton then self.goButton:Hide() end
                return
            end
            if not self.goButton then
                local ok, made = pcall(CreateFrame, "Button", nil, self, "UIPanelButtonTemplate")
                self.goButton = ok and made or CreateFrame("Button", nil, self)
                if self.goButton.SetFrameLevel and button.GetFrameLevel then self.goButton:SetFrameLevel((button:GetFrameLevel() or 1) + 3) end
                self.goButton:SetScript("OnEnter", function(b) tip(b, b.label or "", b.note) end)
                self.goButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            local go = self.goButton
            go.label, go.note = label or (L"Кратчайший путь ко входу"),
                note or (L"Стрелка поведёт самым быстрым путём: телепорт, перелёт или проход между зонами — что короче. Откроется карточка с шагами.")
            go:SetText(go.label)
            local text = go.GetFontString and go:GetFontString()
            local width = text and text.GetStringWidth and text:GetStringWidth() or 0
            go:SetSize(math.max(170, (tonumber(width) or 0) + 28), 24)
            go:ClearAllPoints()
            go:SetPoint("TOPLEFT", self, "TOPLEFT", (self.inset or 0) + 4, -((self.height or 0) + 6))
            go:SetScript("OnClick", onClick)
            go:Show()
            self.height = (self.height or 0) + 34
        end
        -- The owner: "the mileage has to be put somewhere: it sits badly, it draws no eye."
        -- The layout of 15.11.2026 (ChatGPT's, variant 1, approved): how far, in gold, at the
        -- right of the quest's name; under it, small, how ("via the pass", "by flight").
        function block:Distance(main, note)
            if not main then
                if self.farText then self.farText:Hide(); self.farNote:Hide() end
                self.reserve = nil
                return
            end
            if not self.farText then
                self.farText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                self.farText:SetJustifyH("RIGHT")
                if self.farText.SetTextColor then self.farText:SetTextColor(1, .82, 0) end
                self.farNote = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                self.farNote:SetJustifyH("RIGHT")
                if self.farNote.SetTextColor then self.farNote:SetTextColor(.66, .64, .6) end
            end
            self.farText:ClearAllPoints()
            self.farText:SetPoint("TOPRIGHT", self, "TOPRIGHT", (self.rightEdgeOffset or 0) - 2, 0)
            self.farText:SetText(main)
            self.farText:Show()
            self.farNote:ClearAllPoints()
            self.farNote:SetPoint("TOPRIGHT", self.farText, "BOTTOMRIGHT", 0, -2)
            self.farNote:SetText(note or "")
            self.farNote:SetShown(note ~= nil and note ~= "")
            local w1 = tonumber(self.farText.GetStringWidth and self.farText:GetStringWidth()) or 40
            local w2 = (note and note ~= "") and (tonumber(self.farNote.GetStringWidth and self.farNote:GetStringWidth()) or 60) or 0
            self.reserve = {title=w1 + 8, line=(w2 > 0) and (w2 + 8) or nil}
            -- Narrowed, a long name goes on a second line: the block is told how much taller
            -- it is, or the line under it is drawn over it (seen 15.11.2026 on "Идол древней
            -- империи Гурубаши" with "за морем" at the right).
            local text = self.HeaderText
            local old = tonumber(text.GetStringHeight and text:GetStringHeight()) or 0
            text:SetWidth(math.max(40, blockWidth + (self.rightEdgeOffset or 0) - (self.inset or 0) - self.reserve.title))
            -- (Set again, so that it is laid out in the new width at once and measured so.)
            if text.GetText and text:GetText() then text:SetText(text:GetText()) end
            pcall(function()
                local new = tonumber(text:GetStringHeight())
                if new and new > old + 1 then
                    text:SetHeight(new)
                    if type(self.height) == "number" then self.height = self.height + (new - old) end
                    if self.HeaderButton and self.HeaderButton.SetHeight then self.HeaderButton:SetHeight(new) end
                end
            end)
        end
        -- The gold frame of a boss row (the layout of ChatGPT, approved 14.11.2026): "open"
        -- while his loot window stands beside it, "bis" (softer) while he drops a thing that
        -- is the best for its slot; nil, none.
        function block:Gild(mode)
            if not mode then
                if self.gild then self.gild:Hide() end
                return
            end
            if not self.gild then
                local g = CreateFrame("Frame", nil, self)
                g:SetPoint("TOPLEFT", self, "TOPLEFT", -4, 4)
                g:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 4, -4)
                g.fill = g:CreateTexture(nil, "BACKGROUND")
                g.fill:SetAllPoints()
                g.edges = {}
                for i = 1, 4 do g.edges[i] = g:CreateTexture(nil, "BORDER") end
                g.edges[1]:SetPoint("TOPLEFT"); g.edges[1]:SetPoint("TOPRIGHT")
                g.edges[2]:SetPoint("BOTTOMLEFT"); g.edges[2]:SetPoint("BOTTOMRIGHT")
                g.edges[3]:SetPoint("TOPLEFT"); g.edges[3]:SetPoint("BOTTOMLEFT")
                g.edges[4]:SetPoint("TOPRIGHT"); g.edges[4]:SetPoint("BOTTOMRIGHT")
                if g.EnableMouse then g:EnableMouse(false) end
                self.gild = g
            end
            local g, look = self.gild, GILD[mode] or GILD.open
            if g.fill.SetColorTexture then g.fill:SetColorTexture(look.fill[1], look.fill[2], look.fill[3], look.fill[4]) end
            for i, edge in ipairs(g.edges) do
                if edge.SetColorTexture then edge:SetColorTexture(look.edge[1], look.edge[2], look.edge[3], look.edge[4]) end
                if i <= 2 then edge:SetHeight(look.size) else edge:SetWidth(look.size) end
            end
            if g.SetFrameLevel and self.GetFrameLevel then g:SetFrameLevel(math.max(0, (self:GetFrameLevel() or 1) - 1)) end
            g:Show()
        end
        -- The sign of a part that folds, at the right of its label (ChatGPT's code layout:
        -- 19 x 19, ground #291E18, rim #A98851, the sign #F9CB5C): a minus open, a plus folded.
        function block:FoldSign(state)
            if state == nil then
                if self.foldSign then self.foldSign:Hide() end
                return
            end
            if not self.foldSign then
                local f = CreateFrame("Frame", nil, self)
                f:SetSize(19, 19)
                f:SetPoint("TOPRIGHT", self, "TOPRIGHT", (self.rightEdgeOffset or 0) - 2, 2)
                if f.EnableMouse then f:EnableMouse(false) end
                local function tex(layer, sub) return f:CreateTexture(nil, layer, nil, sub) end
                f.rim, f.ground, f.across, f.down = tex("BACKGROUND", 1), tex("BACKGROUND", 2), tex("ARTWORK"), tex("ARTWORK")
                f.rim:SetAllPoints()
                f.ground:SetPoint("TOPLEFT", 1, -1)
                f.ground:SetPoint("BOTTOMRIGHT", -1, 1)
                f.across:SetSize(9, 2)
                f.across:SetPoint("CENTER")
                f.down:SetSize(2, 9)
                f.down:SetPoint("CENTER")
                local function paint(t, h)
                    if t.SetColorTexture then t:SetColorTexture(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1) end
                end
                paint(f.rim, "A98851"); paint(f.ground, "291E18"); paint(f.across, "F9CB5C"); paint(f.down, "F9CB5C")
                self.foldSign = f
            end
            self.foldSign.down:SetShown(state == "folded")
            self.foldSign:Show()
        end
        -- A line through the name: a boss that is dead.
        function block:Strike(on)
            if not on then
                if self.strike then self.strike:Hide() end
                return
            end
            if not self.strike then
                self.strike = self:CreateTexture(nil, "OVERLAY")
                if self.strike.SetColorTexture then self.strike:SetColorTexture(.75, .75, .75, .8) end
                self.strike:SetHeight(1)
            end
            local width = self.HeaderText:GetStringWidth() or 0
            self.strike:ClearAllPoints()
            self.strike:SetPoint("LEFT", self.HeaderText, "LEFT", 5, 0)   -- past the two spaces a row begins with
            self.strike:SetWidth(math.max(1, math.min(width, blockWidth) - 5))
            self.strike:Show()
        end
        function block:SetHeader(text)
            self.text = text
            self.objectives, self.order = nil, nil
            self.struck = nil
            for _, line in ipairs(self.lines) do line:Hide() end
            self.count = 0
            -- (The room of the distance at the right, if it is placed already, is left before
            -- the text is set: the height is then measured as the name will be drawn. Narrowed
            -- after, the name went onto a second line over the line under it.)
            local reserve = self.reserve and self.reserve.title or 0
            self.HeaderText:SetWidth(math.max(40, blockWidth + (self.rightEdgeOffset or 0) - (self.inset or 0) - reserve))
            self.HeaderText:SetText(text)
            self.height = self.HeaderText:GetStringHeight() or 14
        end
        function block:AddObjective(key, text)
            self.objectives, self.order = self.objectives or {}, self.order or {}
            -- (The keys in the order the lines stand, for reading them back.)
            if self.objectives[key] == nil then self.order[#self.order+1] = key end
            self.objectives[key] = text
            self.count = (self.count or 0) + 1
            local line = self.lines[self.count]
            if not line then
                line = CreateFrame("Frame", nil, self)
                line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
                line.Text:SetJustifyH("LEFT")
                line.Text:SetJustifyV("TOP")
                line.Text:SetWordWrap(true)
                self.lines[self.count] = line
            end
            local font = ownFonts().sub
            if font then line.Text:SetFontObject(font) end
            if line.strike then line.strike:Hide() end
            -- A line that begins with a tab hangs under the line before it: no dash, further in.
            local deep = type(text) == "string" and text:sub(1, 1) == "\t"
            if deep then
                text = text:sub(2)
                self.objectives[key] = text
            end
            local native = self.native
            -- As under a quest of the game: a dash, then the line, in light grey, right
            -- under the name.
            if native and not line.dash then
                line.dash = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                line.dash:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
                line.dash:SetText("-")
            end
            if line.dash then
                -- The layout of 14.11.2026 has no dashes: the lines stand under the name.
                line.dash:SetShown(false)
                if native and font then line.dash:SetFontObject(font) end
                if native and line.dash.SetTextColor then line.dash:SetTextColor(.8, .8, .8) end
            end
            if native and line.Text.SetTextColor then line.Text:SetTextColor(.8, .8, .8) end
            local lead = native and (deep and 8 or 0) or 0
            line.Text:ClearAllPoints()
            line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", lead, 0)
            local indent = native and ((self.inset or 0) > 0 and (self.inset + 6) or INDENT)
                or ((self.inset or 0) > 0 and (self.inset + 6) or INDENT)
            local width = blockWidth - indent + (self.rightEdgeOffset or 0)
            local spare = (self.count == 1 and self.reserve and self.reserve.line) or 0
            line.Text:SetWidth(width - lead - spare)
            line.Text:SetText(text)
            local height = line.Text:GetStringHeight() or 13
            line:SetSize(width, height)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", self, "TOPLEFT", indent, -((self.height or 0) + 3))
            line:Show()
            self.height = (self.height or 0) + height + 3
            return line
        end
        return block
    end
    function board:GetBlock(i)
        local block = self.pool[i]
        if not block then
            block = newBlock()
            self.pool[i] = block
        end
        self.blocks[i] = block
        block.laid, block.rightEdgeOffset, block.height = false, 0, 0
        block:Strike(false)
        block:Ready(false)
        block:Dress(nil)
        return block
    end
    function board:Gap()
        return -((self.lastBlock and self.fromBlockOffsetY or self.fromHeaderOffsetY) or -4)
    end
    function board:CanFitBlock(block)
        return (self.used or BOARD_HEAD) + self:Gap() + (block.height or 0) <= self:Room()
    end
    function board:LayoutBlock(block)
        if self:IsCollapsed() then
            block:Hide()
            return true
        end
        local y = (self.used or BOARD_HEAD) + self:Gap()
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT", self, "TOPLEFT", PAD_L, -y)
        block:SetHeight(math.max(1, block.height or 1))
        block:Show()
        block.laid = true
        self.used = y + (block.height or 0)
        self.lastBlock = block
        return true
    end
    return board
end

local function attach()
    if not UIParent then return end
    if not tracker then
        tracker = newBoard()
        P.Board = tracker
        if dock(tracker) then
            tracker:Place()
            -- Where the game gave the room no place after all, the panel stands free.
            if C_Timer and C_Timer.After and slot.GetNumPoints then
                C_Timer.After(3, function()
                    local points = slot:GetNumPoints()
                    if tracker.docked and type(points) == "number" and points == 0 then tracker:Dock(false) end
                end)
            end
        end
        tracker.fromBlockOffsetY, tracker.fromHeaderOffsetY = -4, -6
        tracker.LayoutContents = layout
        tracker.OnBlockHeaderClick = function(_, block, mouse)
            local entry = block.entry
            if not entry then return end
            if entry.stop and mouse == "RightButton" then
                -- Struck off, or put back, by hand.
                if not entry.dim and not entry.wingRow and P.ToggleKilled and P.ToggleKilled(selected, entry.npc, entry.name) then P.Refresh() end
                return
            end
            if entry.stop then
                -- The owner: "a left click on a boss in the list, and all he drops can be
                -- seen". The window of his loot beside the row; a second click puts it away.
                if entry.npc and not entry.dim and not entry.wing and P.ToggleLoot then P.ToggleLoot(entry, block) end
                return
            end
            if entry.book then
                if P.OpenBook then P.OpenBook(selected) end
                return
            end
            if entry.status and entry.door then openRoute({entrance=true}) return end
            if entry.flight then
                local point = entry.flight
                local spot = {mapID=point.place.mapID, x=point.place.x, y=point.place.y, npcID=point.npc, name=point.keeper}
                if P.Mark then P.Mark(spot, L"Распорядитель полётов: " .. point.name, "start") end
                return
            end
            if entry.status or entry.plain then return end
            if entry.now then openRoute(entry.row) return end
            if entry.laterToggle then
                db.showLater = not db.showLater or nil
                P.Refresh()
                return
            end
            if entry.deadToggle then
                db.showDead = not db.showDead or nil
                P.Refresh()
                return
            end
            if entry.group then
                -- A group of the list folds and unfolds.
                db.fold = db.fold or {}
                db.fold[entry.group] = not db.fold[entry.group] or nil
                rebuildList()
                first = math.max(1, math.min(first, #visible))
                tracker:MarkDirty()
                return
            end
            if entry.section then
                if entry.fold then
                    db.folds = db.folds or {}
                    db.folds[entry.fold] = not db.folds[entry.fold] or nil
                    if entry.fold == "bosses" and db.folds.bosses and P.HideLoot then P.HideLoot() end
                    P.Refresh()
                    return
                end
                if entry.rows and entry.rows[1] then openRoute(entry.rows[1]) end
                return
            end
            if entry.via then
                if entry.place then atlas.OpenMapAt(entry.place.mapID) end
                return
            end
            if browsing and mouse == "RightButton" then
                if not entry.key or progress[entry.key].finished == progress[entry.key].total then return end
                db.hidden[entry.key] = not db.hidden[entry.key] or nil
                rebuildList()
                tracker:MarkDirty()
            elseif browsing then choose(entry)
            elseif entry.boss then
                if mouse == "RightButton" then
                    -- The small plan, not the atlas's big window (that is behind the plan's right button).
                    if db then db.planOff = nil end
                    P.UpdatePlan(entry)
                elseif P.AdvanceBossLeg(entry) then
                    tracker:MarkDirty()
                    P.UpdatePlan(entry)
                else
                    P.TogglePlan(entry)
                end
            elseif entry.routeCount then
                routeExpanded = not routeExpanded
                P.Refresh()
            elseif entry.secret then
                local step = readStep[entry.secret] or (entry.action == entry.secret[1] and 1 or 0)
                readStep[entry.secret] = step < #entry.secret and step + 1 or nil
                tracker:MarkDirty()
            elseif entry.prep and tracker.isBoard and nativeLook() and mouse == "RightButton" then
                -- The owner: "how do we get to the journal? a right click on the quest, and
                -- the black window it opened is not needed any more." The book opens on it.
                if P.OpenBook then P.OpenBook(selected, entry.step ~= entry.id and entry.step or entry.id) end
            elseif entry.prep and tracker.isBoard and nativeLook() then
                -- In the look of the game's quests a click unfolds the quest in place and
                -- sets the arrow; a click on the unfolded one folds it again.
                local key = ((entry.step ~= entry.id and entry.id) or entry.leads) or entry.id
                -- A chain stands unfolded already, step by step: a click on it unfolds nothing
                -- more, it says what to do now and sets the arrow (the owner, 15.11.2026: "it is
                -- not clear how it unfolds and folds; I want to click and know what to do in
                -- this chain right now").
                local okChain, chainList = pcall(P.Chain, key)
                if unfolded ~= key and okChain and type(chainList) == "table" and #chainList > 1 then
                    unfolded = nil
                    openRoute(entry, true)
                    local now = P.NowText and P.NowText(entry)
                    if now then
                        say(now)
                        if RaidNotice_AddMessage and RaidWarningFrame then pcall(RaidNotice_AddMessage, RaidWarningFrame, now, {r=1, g=.86, b=.4}) end
                    end
                elseif unfolded == key then
                    unfolded = nil
                    P.Refresh()
                else
                    unfolded = key
                    openRoute(entry, true)
                end
            else openRoute(entry) end
        end
        tracker.OnBlockHeaderEnter = function(_, block)
            local e = block.entry
            if not e then return end
            if e.stop and e.npc and P.HasPlan and P.HasPlan(e.npc) then tip(block.HeaderButton, e.name, L"Щелчок: маленький план этажа, босс подсвечен. Большой — ПКМ по плану.\nПКМ: отметить убитым или вернуть живым, если аддон сам не заметил.") return end
            if e.stop then tip(block.HeaderButton, e.name, e.dead and (L"Этот босс убит. ПКМ вернёт его в живые.") or (e.npc and P.HasPlan and P.HasPlan(e.npc) and (L"Щелчок: карта атласа с этим боссом и маленький план этажа.\n") or "") .. L"ПКМ: отметить убитым, если аддон сам не заметил.\n" .. L"Места внутри подземелья аддон не знает: игра не сообщает там положение. Порядок боссов взят из классической версии.") return end
            if e.book then tip(block.HeaderButton, L"Журнал подземелья", L"Все задания с подробностями и цепочками по шагам и все боссы. То же делает значок книжки в заголовке и команда /dq book.") return end
            if e.plain then return end
            if e.now then tip(block.HeaderButton, L"Сейчас", L"Щелчок ставит стрелку и показывает карточку этого шага.") return end
            if e.flight then tip(block.HeaderButton, e.status, L"Точка полёта, которой у тебя ещё нет: открой её у распорядителя, потом сюда можно будет прилететь. Щелчок ставит стрелку к нему.") return end
            if e.status then tip(block.HeaderButton, e.status, e.door and (L"Брать больше нечего. Щелчок ставит стрелку ко входу.") or (L"Зелёная строка: брать больше нечего. Золотая: ниже написано, что и где осталось.")) return end
            if e.section then tip(block.HeaderButton, e.section, e.about) return end
            if e.via then tip(block.HeaderButton, e.title, L"Сначала сюда, затем: " .. (e.onward or (L"цель")) .. L". Щелчок открывает карту.") return end
            if browsing then
                local c = progress[e.key]
                local note = (L"Сдано заданий: %d из %d"):format(c.finished, c.total)
                if c.total == 0 then note = L"В каталоге нет заданий для этого персонажа" end
                if isClosed(c) then note = note .. L" • Закрыто" end
                if db.hidden[e.key] then note = note .. L" • Скрыто" end
                if c.finished < c.total then
                    note = note .. (db.hidden[e.key] and (L"\nПКМ — вернуть в работу") or (L"\nПКМ — скрыть. Чтобы вернуть, выбери «Показать все»."))
                end
                tip(block.HeaderButton, atlas.DungeonName(e), note)
            elseif e.entrance then
                local way = P.Way and P.Way(selected)
                tip(block.HeaderButton, L"Вход • " .. atlas.DungeonName(selected), (way and (way .. "\n") or "") .. L"Нажми, чтобы отметить вход на карте и включить стрелку.")
            elseif e.boss then
                local _, step, steps = P.BossLeg(e)
                local lines = {}
                for i, leg in ipairs(e.legs or {}) do
                    lines[#lines+1] = (i == step and "|cffffd34d" or "|cffaaaaaa") .. i .. ". " .. P.LegText(leg) .. "|r"
                end
                if #lines == 0 then lines[1] = e.note end
                lines[#lines+1] = steps > 1 and (L"Щелчок — следующий шаг, когда дошёл до перехода. ПКМ — маленький план.")
                    or (L"Щелчок — маленький план рядом с трекером. ПКМ — показать его снова.")
                tip(block.HeaderButton, atlas.BossName(e.boss, selected), table.concat(lines, "\n"))
            elseif e.routeCount then
                tip(block.HeaderButton, L"Советы", L"Секреты, ключи и редкие боссы этого подземелья. Нажми, чтобы раскрыть или свернуть.")
            elseif e.secret then
                tip(block.HeaderButton, e.secret.kind, #e.secret > 1 and (L"Нажми на строку, чтобы увидеть следующий шаг.") or e.action)
            else
                local chain, at, total = chainOf(e.step ~= e.id and e.id or e.leads or e.id)
                local hint = P.QuestHints and P.QuestHints[e.step or e.id]
                if hint and C_QuestLog.IsComplete and C_QuestLog.IsComplete(e.step or e.id) then hint = nil end
                tip(block.HeaderButton, P.Title(e.id), (e.detail or e.note or "")
                    .. (hint and ("\n\n|cffffd34d" .. L"Как найти:" .. "|r " .. hint) or "")
                    .. (e.share and e.state == "missing" and (L"\nЗаданием может поделиться участник группы.") or "")
                    .. (chain and (L"\n\nЦепочка заданий (шаг " .. at .. L" из " .. total .. "):\n" .. table.concat(chain, "\n")) or "")
                    .. ((e.prep and tracker.isBoard and nativeLook()) and (L"\nЩелчок — раскрыть или свернуть. Правая кнопка — журнал этого задания.")
                        or (L"\nНажми, чтобы показать место на карте.")))
            end
        end
        tracker.OnBlockHeaderLeave = function() GameTooltip:Hide() end
        tracker.nextPage = headerButton(L"Дальше", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", tracker.Header.MinimizeButton, function() move(1) end)
        tracker.prev = headerButton(L"Предыдущая страница", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", tracker.nextPage, function() move(-1) end)
        local back = CreateFrame("Button", nil, tracker.Header)
        tracker.back = back
        back:SetSize(56, 18)
        local backLabel = back:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        backLabel:SetPoint("CENTER")
        backLabel:SetText(L"Список")
        back:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        back:SetPoint("RIGHT", tracker.prev, "LEFT", -2, 0)
        back:SetScript("OnClick", browse)
        tracker.goBack = browse
        tracker.bookButton = headerButton(L"Книга заданий", "Interface\\Icons\\INV_Misc_Book_09", back, function()
            if P.ToggleBook then P.ToggleBook(not browsing and selected or nil) end
        end)
        back:SetScript("OnEnter", function() tip(back, L"К списку подземелий") end)
        back:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local nav = CreateFrame("Frame", nil, tracker.Header)
        tracker.nav = nav
        nav.buttons = {}
        nav:SetSize(250, 22)
        nav:SetPoint("TOPLEFT", tracker.Header.Text, "BOTTOMLEFT", -3, -7)
        nav:Hide()
        tracker.filterMenu = createFilterMenu()
        tracker.pickMenu = createPickMenu()
        local bossMenu = CreateFrame("DropdownButton", nil, tracker.Header)
        tracker.bossMenu = bossMenu
        bossMenu:SetSize(46,18)
        bossMenu:SetPoint("RIGHT", tracker.back, "LEFT", -2, 0)
        local label = bossMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText(L"Босс |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-3|t")
        bossMenu:HookScript("OnEnter", function() tip(bossMenu, L"Выбрать босса", L"Трекер покажет путь к нему по шагам. «Вернуться к квестам» — в этом же меню.") end)
        bossMenu:HookScript("OnLeave", function() GameTooltip:Hide() end)
        bossMenu:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        bossMenu:SetupMenu(function(_, menu)
            if not selected then return end
            local function setBoss(choice)
                browsing, db.browsing = false, false
                P.ResetBossLeg()
                db.bossTargets[selected.key] = choice and choice.boss.name or nil
                first, history, detailPage = 1, {}, nil
                if choice and atlas.Target and atlas.Target() then atlas.SetTarget(nil) end
                if choice and lastTracked and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                    C_SuperTrack.SetSuperTrackedQuestID(0)
                end
                P.Refresh()
                -- A boss picked by hand brings the small plan up, not the atlas window.
                if choice and bossTarget then
                    db.planOff = nil
                    P.UpdatePlan(bossTarget, compact)
                end
            end
            menu:CreateRadio(L"Вернуться к квестам", function() return not bossTarget end, function() setBoss(nil) end)
            for _, choice in ipairs(P.BossChoices(selected)) do
                local boss = choice.boss
                local name = atlas.BossName(boss, selected)
                if atlas.IsBossKilled(selected, boss) then name = name .. L" (убит)" end
                menu:CreateRadio(name, function() return db.bossTargets[selected.key] == boss.name end, function() setBoss(choice) end)
            end
        end)
        tracker.Header:EnableMouse(true)
        tracker.Header:SetScript("OnEnter", function(h)
            if not browsing and selected then tip(h, atlas.DungeonName(selected), summary()) end
        end)
        tracker.Header:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- The distances on the page are kept fresh while the player moves.
        if C_Timer.NewTicker then
            local shown
            C_Timer.NewTicker(2, function()
                if browsing or not selected or tracker:IsCollapsed() or P.InDungeon(selected) then return end
                local now = {}
                for _, entry in ipairs(detailRows) do
                    if entry.brief and entry.place then now[#now+1] = P.DistanceText(entry.place) or "-" end
                    if entry.entrance then now[#now+1] = P.DistanceText(entry.option and entry.option.point or P.Door(selected)) or "-" end
                end
                for _, option in ipairs(P.Doors and P.Doors(selected) or {}) do now[#now+1] = P.DistanceText(option.point) or "-" end
                now = table.concat(now, " ")
                if now ~= shown then
                    shown = now
                    tracker:MarkDirty()
                end
            end)
        end
        -- The owner, after a reload: "the addon is gone". It was there, folded to its
        -- header, as he had left it before the reload. Folding is for the moment: after
        -- a reload or a login the panel is open, and folded it says so.
        db.collapsed = nil
        tracker:SetCollapsed(false)
        if atlas.OnMarkersChanged then hooksecurefunc(atlas, "OnMarkersChanged", P.TidyArrow) end
    end
    tracker:Show()
end

local function initialize()
    db = ForeverDungeonPrepChar or {}
    ForeverDungeonPrepChar = db
    P.char = db
    if P.TrackSettings then pcall(P.TrackSettings, db) end
    -- The addon's own ground: dungeons and quests are read from QuestieDB here.
    if atlas.Init then atlas.Init(db) end
    if P.SeedEver then P.SeedEver() end
    pcall(P.MinimapButton)
    -- The game's own light over usable things near the player, unless switched off.
    if not db.noGlow and atlas.ObjectGlow then pcall(atlas.ObjectGlow, true) end
    -- The page of welcome: once to a character, a few seconds after coming in, not in a fight.
    if not db.welcomed and C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if not db.welcomed and not InCombatLockdown() then pcall(P.ShowWelcome) end
        end)
    end
    -- What is new, once after an update (the owner, 15.11.2026: "let those who have the
    -- addon know there is an update and what is new"): a few lines in the chat, seconds
    -- after coming in. Not to a character new to the addon: the welcome page is for him.
    local NEWS = "3.51.0"
    if not db.welcomed then
        db.newsSeen = NEWS
    elseif db.newsSeen ~= NEWS and C_Timer and C_Timer.After then
        C_Timer.After(8, function()
            if db.newsSeen == NEWS then return end
            db.newsSeen = NEWS
            say(L"обновление " .. NEWS .. L", что нового:")
            for _, line in ipairs({
                L"• внутри подземелья: как дойти до каждого босса",
                L"• в журнале: награда за каждое задание",
                L"• в новом заходе убитые боссы сбрасываются сами",
            }) do
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe8dcc0" .. line .. "|r") end
            end
        end)
    end
    -- What this client gives an addon of its pings and of the figures of a thing: looked
    -- up once after login and kept with the settings, to be read from disk. The owner
    -- asked for the game's pings and for things weighed by their figures; neither can be
    -- built on a guess at what Forever's client has.
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            -- Each fact by itself: one that fails says why and does not take the rest with it.
            local facts = {at=GetServerTime and GetServerTime() or 0, ping={}, kinds={}, stats={}, worn={}, errors={}}
            db.facts = facts
            local function try(name, f)
                local ok, err = pcall(f)
                if not ok then facts.errors[#facts.errors+1] = name .. ": " .. tostring(err) end
            end
            try("ping", function()
                facts.hasPing = C_Ping ~= nil
                for name, value in pairs(C_Ping or {}) do facts.ping[#facts.ping+1] = name .. ":" .. type(value) end
                table.sort(facts.ping)
            end)
            try("kinds", function()
                for name, value in pairs(Enum and Enum.PingSubjectType or {}) do facts.kinds[#facts.kinds+1] = name .. "=" .. tostring(value) end
            end)
            try("slash", function()
                facts.slash = SlashCmdList and SlashCmdList["PING"] ~= nil or false
                facts.minimapPing = Minimap and Minimap.PingLocation ~= nil or false
            end)
            local read = (C_Item and C_Item.GetItemStats) or GetItemStats
            facts.hasStats = read ~= nil
            try("worn", function()
                local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
                facts.link = link and (link:gsub("|", "!")) or "none"
                if read and link then
                    for name, value in pairs(read(link) or {}) do facts.worn[#facts.worn+1] = name .. "=" .. tostring(value) end
                end
            end)
            try("stats", function()
                if read then
                    for name, value in pairs(read("item:7714") or {}) do facts.stats[#facts.stats+1] = name .. "=" .. tostring(value) end
                end
            end)
            try("taxi", function()
                facts.taxi = {}
                facts.hasTaxi = C_TaxiMap ~= nil
                for name, value in pairs(C_TaxiMap or {}) do facts.taxi[#facts.taxi+1] = name .. ":" .. type(value) end
                table.sort(facts.taxi)
                local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                facts.taxiHere = here
                facts.nodes = {}
                local nodes = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and here and C_TaxiMap.GetTaxiNodesForMap(here) or {}
                for i, node in ipairs(nodes) do
                    if i <= 6 then
                        local parts = {}
                        for key, value in pairs(node) do
                            if type(value) ~= "table" then parts[#parts+1] = key .. "=" .. tostring(value) end
                        end
                        facts.nodes[#facts.nodes+1] = table.concat(parts, ",")
                    end
                end
                facts.nodeCount = #nodes
            end)
            -- Whether the client has a road sense of its own: waypoints of quests, links
            -- between maps, the pointer in the world. And how the map stood on is nested.
            try("nav", function()
                facts.nav = {}
                local function has(label, value) facts.nav[#facts.nav+1] = label .. ":" .. type(value) end
                has("NextWaypoint", C_QuestLog and C_QuestLog.GetNextWaypoint)
                has("NextWaypointForMap", C_QuestLog and C_QuestLog.GetNextWaypointForMap)
                has("C_Navigation", C_Navigation)
                has("C_SuperTrack", C_SuperTrack)
                has("MapLinks", C_Map and C_Map.GetMapLinksForMap)
                local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                local links = here and C_Map.GetMapLinksForMap and C_Map.GetMapLinksForMap(here)
                facts.nav[#facts.nav+1] = "links=" .. tostring(type(links) == "table" and #links or links)
                local chain, map, guard = {}, here, 0
                while map and map ~= 0 and guard < 6 do
                    local info = C_Map.GetMapInfo(map)
                    if not info then break end
                    chain[#chain+1] = map .. "/" .. tostring(info.mapType)
                    map, guard = info.parentMapID, guard + 1
                end
                facts.mapChain = table.concat(chain, ">")
            end)
            -- Whether the mark "undiscovered" on a flight point means anything here, and
            -- whether the game knows a way to the quests in the log.
            try("closed", function()
                local here = C_Map.GetBestMapForUnit("player")
                local continent = atlas.ContinentOf and atlas.ContinentOf(here)
                local nodes = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and continent and C_TaxiMap.GetTaxiNodesForMap(continent) or {}
                local closed = {}
                for _, node in ipairs(nodes) do
                    if node.isUndiscovered then closed[#closed+1] = tostring(node.name) end
                end
                local first = nodes[1] and nodes[1].position
                facts.closed = #closed .. L" из " .. #nodes .. (closed[1] and (": " .. table.concat(closed, "; ", 1, math.min(#closed, 6))) or "")
                    .. L" | место первой: " .. tostring(first and first.x) .. "," .. tostring(first and first.y)
            end)
            try("waypoints", function()
                local got, asked, sample = 0, 0, nil
                local count = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
                for i = 1, math.min(count, 40) do
                    local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
                    local id = info and not info.isHeader and info.questID
                    if id and C_QuestLog.GetNextWaypoint then
                        asked = asked + 1
                        local map, x, y = C_QuestLog.GetNextWaypoint(id)
                        if map then
                            got = got + 1
                            sample = sample or (id .. "@" .. tostring(map) .. ":" .. tostring(x) .. "," .. tostring(y))
                        end
                    end
                end
                facts.waypoints = got .. L" из " .. asked .. (sample and (" | " .. sample) or "")
            end)
            try("self", function()
                facts.spell = GetSpellBonusDamage and GetSpellBonusDamage(5) or "none"
                facts.crit = GetSpellCritChance and GetSpellCritChance(5) or "none"
                facts.int = UnitStat and select(2, UnitStat("player", 4)) or "none"
            end)
            -- Said once in the chat too, to be read off the screen without a second reload.
            -- (What was found is kept with the settings, in db.facts; nothing is said in the chat.)
        end)
    end
    db.ready = db.ready or {}
    db.bossTargets = db.bossTargets or {}
    db.hidden = db.hidden or {}
    if db.hideDone == nil then db.hideDone = true end
    if db.fullCatalog == nil then db.fullCatalog = db.hideEmpty == false and not db.hideDone end
    db.hideEmpty = nil
    db.showAll = nil
    catalog = P.Catalog()
    -- The plan tiles of the client can be missing (a black plan); the atlas ships every one.
    for _, floors in pairs(atlas.Maps or {}) do
        for _, floor in ipairs(floors) do floor.tex = nil end
    end
    rebuildList()
    local instance = select(8, GetInstanceInfo())
    local bestScore, bestIndex = -math.huge, 1
    for i, d in ipairs(visible) do
        if d.key and not visible[bestIndex].key then bestIndex = i end      -- the first dungeon, past the label of its group
        if d.key then
            local score = -math.max(0, d.minLevel - UnitLevel("player"), UnitLevel("player") - d.maxLevel)
            for _, id in ipairs(d.quests) do
                local idx = C_QuestLog.GetLogIndexForQuestID(id)
                if idx and idx > 0 then score = score + 100 end
            end
            if instance and instance == d.instanceID then score = score + 10000 end
            if d.key == db.key then bestIndex = i break end
            if score > bestScore then bestScore, bestIndex = score, i end
        end
    end
    selected = db.key and db.bossTargets[db.key] and atlas.DungeonByKey[db.key] or (visible[bestIndex] and visible[bestIndex].key and visible[bestIndex]) or nil
    catalogFirst = bestIndex - (bestIndex-1) % limit
    browsing = db.browsing or not (selected and (db.key == selected.key or bestScore > 0))
    first = browsing and catalogFirst or 1
end

function P.Refresh()
    if not db or not atlas.char then return end
    if selected then
        -- Wings of one instance: show the wing the player is actually in.
        if P.InDungeon(selected) then
            local wing = P.Wing(selected)
            if wing ~= selected then
                selected, db.key = wing, wing.key
                first, history, routeExpanded, readStep, detailPage, nameRetries = 1, {}, false, {}, nil, 0
            end
        else
            P.ForgetWing()
        end
        result = P.Build(selected)
        local inDungeon = P.InDungeon(selected)
        -- Been inside: kept, so that "go in" is not said after the run.
        if inDungeon then
            db.ranAt = type(db.ranAt) == "table" and db.ranAt or {}
            db.ranAt[selected.key] = GetServerTime and GetServerTime() or 0
        end
        if P.WatchNeeds then P.WatchNeeds(result.rows, inDungeon) end
        if inDungeon and P.InferKills then P.InferKills(selected, result.rows) end
        -- Walking in is the start of a run, unless the last boss fell a moment ago. The
        -- first look after a /reload inside counts the same: old marks do not outlive it.
        if inDungeon and wasInside ~= true and P.EnterRun then
            P.EnterRun(selected)
            if P.Track then P.Track("EnteredDungeon") end
            -- The owner (17.11.2026): in a new copy the bosses of the last one hung on as
            -- killed. The creatures in sight say which copy this is, now and a moment later.
            if P.LookForCopy then
                P.LookForCopy(selected)
                if C_Timer and C_Timer.After then
                    local d = selected
                    for _, delay in ipairs({2, 5}) do
                        C_Timer.After(delay, function()
                            if P.InDungeon(d) and P.LookForCopy(d) and P.Refresh then P.Refresh() end
                        end)
                    end
                end
            end
        end
        wasInside = inDungeon and true or false
        bossTarget = nil
        if inDungeon and db.bossTargets[selected.key] then
            for _, choice in ipairs(P.BossChoices(selected)) do
                if choice.boss.name == db.bossTargets[selected.key] then
                    bossTarget = choice
                    break
                end
            end
            -- A killed boss needs no way to it: back to the quests.
            if bossTarget and atlas.IsBossKilled(selected, bossTarget.boss) then
                db.bossTargets[selected.key], bossTarget = nil, nil
            end
        end
        -- Without a choice by hand the run leads to the next boss alive, starting from
        -- the place of the last fight.
        autoBoss = inDungeon and not bossTarget and P.NextBoss(selected) or nil
        local guide = bossTarget or autoBoss
        if guide then
            guide.from = P.LastKill(selected)
            guide.note = P.BossDestination(guide)
        end
        dropStaleArrows()
        clearAtlasLeftovers()
        restylePins()
        settleMark()
        nextObjective(selected)
        local onward = P.Replan and P.Replan()
        if onward then say(L"Дальше пешком. Стрелка ведёт к цели: " .. onward) end
        P.WatchBoss(inDungeon and guide or nil)
        -- The living bosses of the run are looked for by their name bars.
        if atlas.Seek then atlas.Seek(inDungeon and P.RunBosses and P.RunBosses(selected) or nil) end
        planGuide = inDungeon and guide or nil
        if inDungeon then P.NoteZone(selected) end
        -- Measure what position data the client gives in here, a sample every few seconds.
        if inDungeon and not probing and C_Timer.NewTicker then
            probing = C_Timer.NewTicker(3, function() P.Probe() end)
        end
        if inDungeon then P.Probe() end
        local nextStep = not bossTarget and inDungeon and P.NextSteps(selected, result.rows)[1]
        focus = nextStep and nextStep.row or nil
        local wasCompact = compact
        -- The owner: "the addon folds in a fight, no telling why, it maddens." The page
        -- stays whole in a fight.
        compact = false
        if compact and not wasCompact then
            detailPage = {first=first, history=history, key=selected.key}
        elseif wasCompact and not compact and detailPage then
            if not browsing and selected.key == detailPage.key then first, history = detailPage.first, detailPage.history end
            detailPage = nil
        end
        if focus and not browsing and inDungeon then
            local key = selected.key .. ":" .. focus.step .. ":" .. focus.state .. ":" .. tostring(C_QuestLog.IsComplete(focus.step))
            if not InCombatLockdown() and key ~= lastTracked then
                lastTracked = key
                P.TrackStep(focus)
                P.Route(selected, focus, true)
            end
        else
            lastTracked = nil
        end
        -- What is left to do, one row each: the next step, the other quests, the door,
        -- and the tips folded into a single line. Turned-in quests are simply gone.
        detailRows = {}
        headNote = nil
        -- On the way to another continent: the leg under way stands on top of the page.
        local goal, heading = db.goal, atlas.Target and atlas.Target()
        local way = goal and heading and not inDungeon and P.Plan(goal)
        -- Seen in the game: the way written twice, in a part of its own on top and again
        -- inside the unfolded quest. Where the quest the arrow serves is unfolded, the way
        -- stands there, under "what to do now", and not here. (A teleport stays: it is a
        -- button to press.)
        if way and not way.spell and nativeLook() and unfolded ~= nil and goal.id and result then
            for _, row in ipairs(result.rows or {}) do
                if (row.step == goal.id or row.id == goal.id) and unfolded == (((row.step ~= row.id and row.id) or row.leads) or row.id) then
                    way = nil
                    break
                end
            end
        end
        if way and way.spell then
            table.insert(detailRows, {section=L"Дорога к цели", about=L"Кратчайший путь к выбранной цели начинается с телепорта."})
            table.insert(detailRows, {via=true, title=L"Телепорт: " .. way.city, cast=true, onward=goal.label, ride=way.next and way.next.ride})
        elseif way and way.point then
            table.insert(detailRows, {section=L"Дорога к цели", about=L"Сначала сюда, потом к цели. Щелчок по строке ниже открывает карту этого места."})
            local after = way.legs and way.legs[2]
            table.insert(detailRows, {via=true, brief=true, place=heading, title=heading.title, onward=goal.label, keeper=way.keeper, up=way.up,
                fly=way.fly, unsure=way.unsure, pass=way.pass, ride=after and (after.ride or after.text)})
        end
        -- An undiscovered flight point by the way or by the goal: a gold plate under the
        -- way (the mock of 15.11.2026). A click sets the arrow to its master.
        if goal and heading and not inDungeon and not compact and P.FlightOnWay then
            local ok, point, where = pcall(P.FlightOnWay, goal)
            if ok and point then
                local far = P.DistanceText(point.place)
                local zone = atlas.ZoneName(point.place.mapID)
                table.insert(detailRows, {status=(where == "goal" and (L"Точка полёта у цели: ") or (L"Точка полёта по пути: ")) .. point.name,
                    plate="gold", flight=point,
                    sign=UnitFactionGroup("player") == "Alliance" and "Interface\\Icons\\Ability_Mount_Gryphon_01" or "Interface\\Icons\\Ability_Mount_Wyvern_01",
                    lines={(zone or "") .. (far and ((zone and " • " or "") .. far) or ""), L"открой у распорядителя полётов"}})
            end
        end
        -- The quest to do next stands on top in a fight, and where no run of bosses is
        -- known to lead the page; with a run, the boss leads and the quest is in the tasks.
        local focusOnTop = focus and (compact or not (P.Run and P.Run(selected, result.rows, true))) or false
        -- In a fight the page is two rows: the boss the run is heading for, and under
        -- him the one quest not to forget. The boss comes first: a dungeon is mostly
        -- fights, and "who is next" is the question asked in them.
        if compact and P.Run and not bossTarget then
            for _, stop in ipairs(P.Run(selected, result.rows) or {}) do
                if stop.next then
                    stop.heading = true
                    table.insert(detailRows, stop)
                    break
                end
            end
        end
        if focus then
            -- Which boss the quest under way belongs to, for the short page.
            focus.nearBoss = nil
            if compact and P.Run then
                for _, stop in ipairs(P.Run(selected, result.rows, true) or {}) do
                    if not stop.dim and not stop.wingRow and stop.told and stop.told[focus.id] then focus.nearBoss = focus.nearBoss or stop.name end
                end
            end
        end
        if bossTarget or focusOnTop then table.insert(detailRows, bossTarget or focus) end
        if autoBoss and compact and not focus then table.insert(detailRows, autoBoss) end
        if autoBoss and not compact then
            table.insert(detailRows, {section=L"Следующий босс", about=L"Первый живой босс по порядку подземелья. Другого можно выбрать кнопкой «Босс» в заголовке."})
            table.insert(detailRows, autoBoss)
        end
        if not compact then
            -- A follow-up of a quest listed here appears once that quest is turned in.
            local listed = {}
            for _, row in ipairs(result.rows) do
                if row.state ~= "done" then listed[row.id] = true end
            end
            local shelves = {turnin={}, before={}, taken={}, inside={}, later={}}
            local byId = {}
            for _, row in ipairs(result.rows) do byId[row.id] = row end
            for _, row in ipairs(result.rows) do
                local later = row.step ~= row.id and listed[row.step]
                -- The quest it waits for is on the page: that one says where the chain leads.
                if later and byId[row.step] and not byId[row.step].leads then byId[row.step].leads = row.id end
            end
            for _, row in ipairs(result.rows) do
                local later = row.step ~= row.id and listed[row.step]
                if row ~= focus and row.state ~= "done" and not later then table.insert(shelves[shelf(row)], row) end
            end
            -- A labelled shelf; brief rows are a title only, the label says the rest.
            local function put(label, about, brief, ...)
                local started
                for _, rows in ipairs({...}) do
                    for _, row in ipairs(rows) do
                        if not started then
                            started = true
                            table.insert(detailRows, {section=label, about=about})
                        end
                        row.brief = brief
                        table.insert(detailRows, row)
                    end
                end
            end
            -- The first line of the page answers the one question asked before a run:
            -- is everything taken? Green when nothing is left to take, gold when something is.
            local inLog = 0
            for _, row in ipairs(result.rows) do
                if row.state == "active" and not (row.step ~= row.id and listed[row.step]) then inLog = inLog + 1 end
            end
            if inDungeon then
                led = nil
                runTold = {}
                -- Inside, as the owner approved it on a mock-up: where the player is, the
                -- boss the run is heading for and the way to him, the ones after, the dead
                -- folded into a line, and the quests in three words: not taken, taken, ready.
                local room = P.Room and P.Room()
                if room == atlas.DungeonName(selected) then room = nil end
                local stops = P.Run and P.Run(selected, result.rows, "all")
                local leading = false
                for _, stop in ipairs(stops or {}) do leading = leading or (stop.next and not stop.dim and not stop.wingRow) end
                if room and not leading then
                    -- No boss to hang the hall on: it stands alone.
                    table.insert(detailRows, {section=L"Локация", about=L"Зал, в котором ты стоишь. Положение внутри подземелья игра не сообщает, только название зала."})
                    table.insert(detailRows, {plain=room})
                end
                local folded = bossRows(selected, result.rows, true)
                local beside = {}
                if stops then
                    local heading
                    for _, stop in ipairs(stops) do
                        for id in pairs(stop.told or {}) do runTold[id] = true end
                        if stop.next and not stop.dim and not stop.wingRow and not heading then heading = stop end
                    end
                    if heading then
                        roomPing(selected, room, heading)
                        -- The layout of 14.11.2026: the boss is the status of the page, a
                        -- red plate on top with the button to his plan; no label over it.
                        heading.big = true
                        -- What is done beside him is not a line under his name: it is a
                        -- thing to do, and stands in white right after him.
                        local asks, lines = {}, {}
                        for _, line in ipairs(heading.asks or {}) do asks[line] = true end
                        for _, line in ipairs(heading.lines) do
                            if not asks[line] then lines[#lines+1] = line end
                        end
                        if room and not heading.inRoom then table.insert(lines, 1, L"ты здесь: «" .. room .. "»") end
                        -- (The plan closed by its cross comes back by the button "Way to the
                        -- boss" of the red plate: no line for it.)
                        -- The red plate holds four lines: three of where he is, one of his loot.
                        while #lines > 3 do table.remove(lines) end
                        if P.LootFor and heading.npc then
                            local loot, mine, best, better = P.LootFor(heading.npc)
                            local weighed = false
                            for _, thing in ipairs(loot) do weighed = weighed or thing.worth.known end
                            local names = {}
                            -- The owner: "it is very hard to find the loot of the bosses." Each
                            -- thing under its picture, as in the bags.
                            local function pic(thing)
                                local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(thing.id)) or (GetItemIcon and GetItemIcon(thing.id))
                                return (icon and ("|T" .. icon .. ":16:16|t ") or "") .. (thing.name or "?")
                            end
                            if best > 0 then
                                -- The very good first, in gold: this boss is worth the fight.
                                for _, thing in ipairs(loot) do
                                    if thing.worth.best and #names < 2 then names[#names+1] = pic(thing) end
                                end
                                lines[#lines+1] = L"|cffffd34dлучшее в слот: " .. table.concat(names, ", ") .. (best > 2 and (L" и ещё " .. (best - 2)) or "") .. "|r"
                            elseif better > 0 then
                                for _, thing in ipairs(loot) do
                                    if thing.worth.known and thing.worth.gain > 0 and not thing.worth.worn and not thing.worth.later and #names < 2 then
                                        names[#names+1] = pic(thing) .. (" (+%.0f)"):format(thing.worth.gain)
                                    end
                                end
                                lines[#lines+1] = L"|cff40e040лучше надетого: " .. table.concat(names, ", ") .. (better > 2 and (L" и ещё " .. (better - 2)) or "") .. "|r"
                            elseif mine > 0 and not weighed then
                                for _, thing in ipairs(loot) do
                                    if thing.mine and #names < 2 then names[#names+1] = pic(thing) end
                                end
                                lines[#lines+1] = L"|cff40e040добыча для тебя: " .. table.concat(names, ", ") .. (mine > 2 and (L" и ещё " .. (mine - 2)) or "") .. "|r"
                            end
                        end
                        heading.lines = lines
                        table.insert(detailRows, heading)
                        if #(heading.todo or {}) > 0 then
                            table.insert(detailRows, {section=L"Что сделать у босса", about=L"То, что из твоих заданий делается рядом с этим боссом. Пройдёшь мимо — придётся возвращаться."})
                            for _, todo in ipairs(heading.todo) do table.insert(detailRows, {plain=todo.text, under=todo.sub, todo=true}) end
                            for id in pairs(heading.told or {}) do beside[id] = true end
                        end
                    end
                    -- A quest in the log says which boss it is done at.
                    -- One not taken, whose boss is already dead, says by which boss it was.
                    for _, row in ipairs(result.rows) do row.atBoss, row.byBoss = nil, nil end
                    for _, stop in ipairs(stops) do
                        if not stop.dim and not stop.wingRow then
                            for id in pairs(stop.told or {}) do
                                for _, row in ipairs(result.rows) do
                                    if row.id == id then
                                        if stop.dead then row.byBoss = row.byBoss or stop.name
                                        elseif not row.atBoss then row.atBoss = stop.name end
                                    end
                                end
                            end
                        end
                    end
                end
                local tasks, twins = {{}, {}, {}}, {}
                for _, row in ipairs(result.rows) do
                    local follow = row.step ~= row.id and listed[row.step]
                    if row.state ~= "done" and not follow and not (focusOnTop and row == focus) and not beside[row.id] then
                        local place = shelf(row)
                        if place == "turnin" or (row.state == "active" and row.handInside) then
                            row.task = L"готово"
                            table.insert(tasks[3], row)
                        elseif row.state == "active" then
                            row.task = L"взято"
                            table.insert(tasks[2], row)
                        elseif place == "inside" then
                            row.task = L"не взято"
                            table.insert(tasks[1], row)
                        elseif place == "before" then
                            -- Given outside: it cannot be taken in here, but it is not
                            -- taken, and a member of the group may share it. Variants of
                            -- one quest from one giver are one line.
                            local key = (P.Title(row.step) or "") .. "|" .. tostring(row.place and atlas.PlaceName(row.place))
                            if not twins[key] then
                                twins[key] = true
                                row.task, row.givenOutside = L"не взято", true
                                table.insert(tasks[1], row)
                            end
                        end
                    end
                end
                -- The bosses before the quests, as on the layout.
                for _, row in ipairs(folded) do table.insert(detailRows, row) end
                if #tasks[1] + #tasks[2] + #tasks[3] > 0 then
                    table.insert(detailRows, {section=L"Задания", fold="tasks", about=L"Задания этого похода: что ещё надо взять внутри, что в журнале, что готово к сдаче. Щелчок по заголовку сворачивает список."})
                    if not (db.folds and db.folds.tasks) then
                        for _, list in ipairs(tasks) do
                            for _, row in ipairs(list) do
                                row.brief = true
                                table.insert(detailRows, row)
                            end
                        end
                    end
                end
            else
                -- Errands outside are weighed as before: a place with a chain to start or
                -- work to do comes first, then the nearest. But the page says them as the
                -- owner approved on a mock-up: one thing to do now, in full; then short
                -- lists of what is not taken, what is to be done and handed in out here.
                local ranks = {work=1, chain=1, chainturnin=1, take=2, turnin=3}
                local places, order, doing = {}, {}, {}
                local function join(row, kind)
                    local place = row.place
                    local zone = place and place.mapID and atlas.ZoneName(place.mapID) or (L"место неизвестно")
                    local group = places[zone]
                    if not group then
                        group = {zone=zone, tier=2, rows={}, index=#order+1, take=0, work=0, hand=0}
                        places[zone] = group
                        order[#order+1] = group
                    end
                    local distance = P.Distance(place)
                    if distance and (not group.distance or distance < group.distance) then group.distance = distance end
                    row.brief, row.errand, row.chain = true, true, row.step ~= row.id or row.leads ~= nil
                    row.shared = kind == "take" and row.share
                    -- The owner, in the Razorfen Downs: "the first quest was the one taken by
                    -- the instance; mark it as taken on the way into the dungeon; first we
                    -- have to do all the chains." A quest given within a few hundred yards of
                    -- the way in is taken on the way: it goes last, and says so.
                    row.atDoor = nil
                    if kind == "take" and place and atlas.Span then
                        for _, door in ipairs({P.Door and P.Door(selected), atlas.Entrance and atlas.Entrance(selected)}) do
                            local ok, yards = pcall(atlas.Span, place, door)
                            if ok and yards and yards <= 300 then row.atDoor = true end
                        end
                    end
                    -- The owner: "why run there apart, when I will get them on the spot?" A
                    -- quest a member of the group can share, given neither inside nor at the
                    -- way in and no step of a chain, is asked of the group: no errand to run.
                    row.askGroup = nil
                    if kind == "take" and row.share and not row.atDoor and row.step == row.id and not row.leads then
                        local ok, steps = pcall(P.Chain, row.id)
                        if not (ok and type(steps) == "table" and #steps > 1) then row.askGroup = true end
                    end
                    row.handin = kind == "turnin" or kind == "chainturnin"
                    row.working = kind == "work"
                    row.rank, row.index = ranks[kind], #group.rows + 1
                    local count = row.working and "work" or row.handin and "hand" or "take"
                    group[count] = group[count] + 1
                    if row.rank == 1 then group.tier = 1 end
                    table.insert(group.rows, row)
                end
                for _, row in ipairs(shelves.turnin) do join(row, "turnin") end
                for _, row in ipairs(shelves.before) do
                    local chained = row.step ~= row.id or row.leads ~= nil
                    if row.work then
                        -- In the log, and a goal of it is out here: that is an errand now.
                        join(row, "work")
                    elseif row.act == "doing" then
                        row.chain = true
                        table.insert(doing, row)
                    elseif chained then
                        join(row, row.act == "turnin" and "chainturnin" or "chain")
                    else
                        join(row, "take")
                    end
                end
                table.sort(order, function(a, b)
                    if a.tier ~= b.tier then return a.tier < b.tier end
                    if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
                    if a.distance and a.distance ~= b.distance then return a.distance < b.distance end
                    return a.index < b.index
                end)
                local errands, take, work, hand = {}, {}, {}, {}
                for _, group in ipairs(order) do
                    table.sort(group.rows, function(a, b)
                        if a.rank ~= b.rank then return a.rank < b.rank end
                        return a.index < b.index
                    end)
                    for _, row in ipairs(group.rows) do
                        if not row.atDoor and not row.askGroup then
                            errands[#errands+1] = row
                            row.line = true
                            local list = row.working and work or row.handin and hand or take
                            list[#list+1] = row
                        end
                    end
                end
                -- The order of the getting ready, in the owner's words: "first get ready for the
                -- dungeon: the quests one cannot go in without, taken somewhere outside or
                -- shared by the group; what is by the way in is done on arriving" (he was led
                -- first to a quest by the door). Three stages: (1) far from the dungeon, to be
                -- run to, the farthest first; (2) to ask of the group; (3) by the dungeon - at
                -- the way in or within its neighbourhood - the farthest of them first, so the
                -- road ends at the door. (Another continent is the farthest of all.)
                for _, which in ipairs({"atDoor", "askGroup"}) do
                    for _, group in ipairs(order) do
                        for _, row in ipairs(group.rows) do
                            if row[which] and (which == "atDoor" or not row.atDoor) then
                                errands[#errands+1] = row
                                row.line = true
                                take[#take+1] = row
                            end
                        end
                    end
                end
                do
                    local NEARBY = 1500
                    local doors = {P.Door and P.Door(selected), atlas.Entrance and atlas.Entrance(selected)}
                    local function fromDungeon(row)
                        if not row.place then return -1 end
                        local best
                        for _, door in ipairs(doors) do
                            local ok, yards = pcall(atlas.Span, row.place, door)
                            if ok and yards and (not best or yards < best) then best = yards end
                        end
                        return best or 1e9
                    end
                    for i, row in ipairs(errands) do
                        row.fromDungeon, row.index2 = fromDungeon(row), i
                        row.nearDungeon = row.atDoor or (row.fromDungeon >= 0 and row.fromDungeon <= NEARBY) or nil
                        row.stage = row.askGroup and 2 or row.nearDungeon and 3 or 1
                    end
                    table.sort(errands, function(a, b)
                        if a.stage ~= b.stage then return a.stage < b.stage end
                        if a.fromDungeon ~= b.fromDungeon then return a.fromDungeon > b.fromDungeon end
                        return a.index2 < b.index2
                    end)
                end
                -- The owner: "when all the chains are done, a notice: you have taken all the
                -- quests, but these ask to be shared." No chain left out here, and quests
                -- left that a member of the group can share: said on top, and once in the
                -- middle of the screen when it comes to that.
                local chainsLeft, askFor = #doing > 0, {}
                local function chained(row)
                    if row.chain then return true end
                    local ok, steps = pcall(P.Chain, row.id)
                    return ok and type(steps) == "table" and #steps > 1
                end
                for _, row in ipairs(errands) do
                    -- (Seen in the game: "chains done" with the last step of a chain still
                    -- to do out here - a last step was not counted as a chain.)
                    if chained(row) or row.working or row.stepActive then chainsLeft = true end
                    if row.share and not chained(row) and not row.working and not row.handin then askFor[#askFor+1] = row end
                end
                local askNow = not chainsLeft and #askFor > 0
                if askNow then
                    local names = {}
                    for _, row in ipairs(askFor) do names[#names+1] = "«" .. P.Title(row.step or row.id) .. "»" end
                    local farLeft = false
                    for _, row in ipairs(errands) do if row.stage == 1 then farLeft = true end end
                    if shareWas[selected.key] == false and farLeft then
                        local text = atlas.DungeonName(selected) .. (L": цепочки сделаны. Попроси группу поделиться: ") .. table.concat(names, ", ")
                        say(text)
                        if RaidNotice_AddMessage and RaidWarningFrame then pcall(RaidNotice_AddMessage, RaidWarningFrame, text, {r=.5, g=.83, b=1}) end
                        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.READY_CHECK or 8960) end
                    end
                end
                shareWas[selected.key] = askNow
                local toTake, toDo = #take, #work + #hand + #doing
                local any = toTake + toDo + inLog + #shelves.inside > 0
                -- The owner, of five sections by the kind of errand, one quest in two of
                -- them and the quest he asked about a small line under another's name:
                -- "can you make this clearer?" One list now, a card for each quest of the
                -- dungeon under its own name, as in the book: the sign of its state, and
                -- under the name what to do about it and where. What can be done out
                -- here comes first, the nearest on top.
                for _, row in ipairs(shelves.inside) do row.begins = true end
                local prep = {}
                for _, list in ipairs({errands, doing, shelves.inside, shelves.taken, shelves.later}) do
                    for _, row in ipairs(list) do
                        row.prep, row.brief = true, true
                        prep[#prep+1] = row
                    end
                end
                -- Been through this dungeon: inside within a day and its last boss dead (a
                -- step out of the portal halfway is not the end of a run); or, longer ago,
                -- a quest of it that begins inside is done already.
                local beenInside = false
                local ran = type(db.ranAt) == "table" and db.ranAt[selected.key]
                if ran and GetServerTime and GetServerTime() - ran < 86400 then
                    beenInside = P.RunDone and P.RunDone(selected) or false
                else
                    for _, row in ipairs(result.rows) do
                        if not beenInside and row.state == "done" and atlas.StartsInside and atlas.StartsInside(row.id) then beenInside = true end
                    end
                end
                -- The owner, the quests shared in Orgrimmar and two of them to be done by the
                -- dungeon itself: "there is no state 'all ready, go in' and the shortest
                -- way." What is left only by the dungeon (stage 3) is done on the way in: ready.
                -- (The owner at Uldaman, 15.11.2026, with two chests in the tunnels before the
                -- portal and one quest the group could share: "this is the moment to tell the
                -- player he can go now and do the rest by the dungeon." A quest to ask of the
                -- group does not keep him outside: it is asked for on the same plate.)
                local nearOnly = true
                local byTheWay, asking = {}, {}
                -- A quest to hand in or finish out here, not at the very door: "by the dungeon"
                -- reaches 1500 yards, and a new dungeon of Forever stands in the middle of a
                -- quest zone (Krol'dok in Riverglades). The arrow is not sent to the door unasked
                -- while there is one (the owner, 19.11.2026: "why did it start pointing at the
                -- entrance").
                local errandOut = false
                for _, row in ipairs(errands) do
                    if row.stage == 1 then nearOnly = false end
                    if (row.handin or row.working or row.stepActive)
                        and not (row.fromDungeon and row.fromDungeon >= 0 and row.fromDungeon <= 600) then errandOut = true end
                    if row.stage == 3 and #byTheWay < 3 then
                        local verb = row.handin and (L"сдать") or row.working and (L"доделать") or (L"взять")
                        byTheWay[#byTheWay+1] = verb .. " «" .. P.Title(row.step or row.id) .. "»"
                    elseif row.stage == 2 and #asking < 3 then
                        asking[#asking+1] = "«" .. P.Title(row.step or row.id) .. "»"
                    end
                end
                if any and nearOnly and #doing == 0 then
                    -- Nothing left outside: the one thing to do is go in, and the line
                    -- under the green one says through which door and how far it is.
                    -- The owner, on the green row in the game: "the shortest way is a good button,
                    -- but what I want is the status itself: all the quests are taken, one can go
                    -- into the instance." So it is the first thing on the page, over the way,
                    -- with the game's own ready sign, and the button under it.
                    local option = P.DoorOption and P.DoorOption(selected)
                    local taken = inLog > 0 and (L"в журнале: " .. inLog .. (inLog == 1 and (L" — делается внутри") or (L" — делаются внутри"))) or (L"снаружи брать нечего")
                    local head = #asking > 0 and (L"Можно идти в подземелье")
                        or inLog > 0 and (L"Все задания взяты — можно идти в подземелье") or (L"Брать нечего — можно идти в подземелье")
                    if #byTheWay > 0 then taken = L"по дороге: " .. table.concat(byTheWay, ", ") end
                    local ask = #asking > 0 and (L"попроси группу: " .. table.concat(asking, ", ")) or nil
                    -- The owner, back from Gnomeregan with its quests handed in: "it says all is
                    -- taken and I can go, but I have been through it already; one quest is left,
                    -- and maybe I will not do it." After a run the page says so, quietly: what
                    -- is left inside, without the green, the sound or the arrow to the door.
                    if beenInside then
                        local left = {}
                        for _, row in ipairs(shelves.taken or {}) do left[#left+1] = "«" .. P.Title(row.step or row.id) .. "»" end
                        for _, row in ipairs(doing) do left[#left+1] = "«" .. P.Title(row.step or row.id) .. "»" end
                        head = L"Ты уже был внутри"
                        taken = #left > 0 and (L"там осталось: " .. table.concat(left, ", ")) or taken
                    end
                    if option and option.point then
                        local metres = P.Distance and P.Distance(option.point)
                        local reach = P.Reach(option.point)
                        -- At the door the order is what to do with it; on the way, to walk to it.
                        local order = (metres and metres < 20 and option.near) or ((option.act or (L"Иди ко входу")) .. (reach and (" • " .. reach) or ""))
                        table.insert(detailRows, 1, {status=head, ready=not beenInside or nil, muted=beenInside or nil, good=true, door=true, order=order, note=taken, hint=option.point.hint,
                            lines=(ask and not beenInside) and {order, taken, ask} or nil})
                    else
                        table.insert(detailRows, 1, {status=head, ready=not beenInside or nil, muted=beenInside or nil, good=true, note=taken,
                            lines=(ask and not beenInside) and {taken, ask} or nil})
                    end
                end
                if #prep > 0 then
                    local inHand = 0
                    for _, row in ipairs(prep) do
                        if row.state == "active" then inHand = inHand + 1 end
                    end
                    if errands[1] then errands[1].lead = true end
                    headNote = inHand .. "/" .. #prep
                    -- The layout of 14.11.2026 (ChatGPT's, approved by the owner): two
                    -- sections, what to take and what is taken, each with its count; the
                    -- status over them says the one thing to do now.
                    local toGet, have = {}, {}
                    for _, row in ipairs(prep) do
                        if row.state == "active" or row.working or row.handin or row.stepActive then have[#have+1] = row else toGet[#toGet+1] = row end
                    end
                    -- The owner: "see how awkward it all is; why not parts: the chains, what can
                    -- be taken, what can be shared?" The layout of 15.11.2026 (ChatGPT's,
                    -- approved): what is not taken in parts, each with its count and folding:
                    -- chains, what the group can share, what to take oneself, what comes later;
                    -- then what is taken. Within a part the order is the order of the errands.
                    local parts = {chains={}, group={}, self={}, later={}}
                    for _, row in ipairs(toGet) do
                        local chained = (row.step ~= row.id) or row.leads
                        -- (What begins inside the dungeon cannot be taken out here: it waits under "later".)
                        local key = (row.levelLocked or row.unknown or row.begins) and "later" or row.askGroup and "group" or chained and "chain" or "self"
                        table.insert(parts[key == "chain" and "chains" or key], row)
                    end
                    local function part(key, title, about, rows)
                        if #rows == 0 then return end
                        table.insert(detailRows, {prepSection=true, fold="prep_" .. key, section=title .. " • " .. #rows, about=about})
                        if db.folds and db.folds["prep_" .. key] then return end
                        for _, row in ipairs(rows) do table.insert(detailRows, row) end
                    end
                    -- The owner, 15.11.2026: "split the taken quests to be done before the dungeon
                    -- from the ones done inside." What is to be finished or handed in out here comes
                    -- first: it is what to do now.
                    -- And then: "split off the ones done by the entrance, on the elites before
                    -- the instance: do at the entrance." What is in the cave before the portal,
                    -- or within six hundred yards of the way in, is a part of its own, last
                    -- before the dungeon: it is done on the way in, best with the group.
                    local outside, atEntrance, inside = {}, {}, {}
                    local function byTheDoor(row)
                        if row.work and row.work.cave then return true end
                        return row.fromDungeon and row.fromDungeon >= 0 and row.fromDungeon <= 600
                    end
                    for _, row in ipairs(have) do
                        -- (As the card says it: "сдать", "сделать снаружи", "доделать" are out here;
                        -- "в журнале" and "сдать внутри" are inside.)
                        if row.handin or row.working or (row.stepActive and row.state ~= "active") then
                            table.insert(byTheDoor(row) and atEntrance or outside, row)
                        else inside[#inside+1] = row end
                    end
                    -- The nearest first (the owner, 15.11.2026: "sort the hand-ins by who is
                    -- nearer, not at the top; the nearest is the goal to take first").
                    local function yards(row)
                        if row.nearYards == nil then row.nearYards = (row.place and P.Distance and P.Distance(row.place)) or false end
                        return row.nearYards or math.huge
                    end
                    for _, list in ipairs({outside, atEntrance}) do
                        for i, row in ipairs(list) do row.nearOrder, row.nearYards = i, nil end
                        table.sort(list, function(a, b)
                            local ya, yb = yards(a), yards(b)
                            if ya ~= yb then return ya < yb end
                            return a.nearOrder < b.nearOrder
                        end)
                    end
                    part("outside", L"Сделать до входа", L"Взятые задания, которые делаются снаружи: доделать или сдать до входа в подземелье. Щелчок по заданию раскрывает его и ставит стрелку. Щелчок по заголовку сворачивает список.", outside)
                    part("chains", L"Цепочки", L"Задания цепочек: какой шаг взять сейчас, у кого и где. Щелчок ставит стрелку. Щелчок по заголовку сворачивает список.", parts.chains)
                    part("group", L"Раздаст группа", L"Этими заданиями может поделиться участник группы — бежать не нужно. Под каждым — куда идти, если не поделятся. Щелчок по заголовку сворачивает список.", parts.group)
                    part("self", L"Взять самому", L"Задания, которые надо взять самому: у кого, где и далеко ли. Сверху — дальние от подземелья, внизу — у самого входа. Щелчок по заголовку сворачивает список.", parts.self)
                    part("entrance", L"Сделать у входа", L"Взятые задания, которые делаются у самого подземелья: в пещере перед порталом или рядом со входом. Их делают по дороге внутрь, лучше группой. Щелчок по заданию раскрывает его и ставит стрелку.", atEntrance)
                    part("have", L"Взято, делается внутри", L"Задания в журнале, которые выполняются внутри подземелья: снаружи с ними делать нечего. Щелчок по заголовку сворачивает список.", inside)
                    -- The owner: "the quest for later, put it at the very bottom: why is it in
                    -- the middle of the list now?"
                    part("later", L"Позже", L"Задания, которые здесь пока не взять: с какого уровня, что нужно сначала или что берётся внутри подземелья. Щелчок по заголовку сворачивает список.", parts.later)
                    -- The status of the page when there is something to do out here.
                    -- The owner: "I do not see the point of this hint, Ask the group to share: it can
                    -- go." What the group can share has its part in the list and the button "Группа"
                    -- in the header; the plate leads to the first errand one has to run for.
                    -- The plate leads to the nearest thing to run for out here (the owner: "the
                    -- nearest is the goal to take first"); the stages as before where none is.
                    -- (The owner, 16.11.2026, by the Razorfen with two to hand in: the plate sent
                    -- him over the sea to Undercity while the other, 170 yards off, stood by the
                    -- door and was passed over as "by the dungeon". While something far is left, a
                    -- hand-in is a hand-in: the nearest one leads, wherever it stands. With nothing
                    -- far left, the plate says "go in" and the hand-in by the door is "on the way".)
                    local farLeft = false
                    for _, row in ipairs(errands) do farLeft = farLeft or row.stage == 1 end
                    local lead, leadYards
                    for _, row in ipairs(errands) do
                        if row.stage == 1 or (farLeft and row.handin and row.stage == 3) then
                            local y = (row.place and P.Distance and P.Distance(row.place)) or math.huge
                            if not lead or y < leadYards then lead, leadYards = row, y end
                        end
                    end
                    if not lead then
                        for _, row in ipairs(errands) do
                            if row.stage ~= 2 then lead = row break end
                        end
                    end
                    if lead and (lead.stage ~= 3 or (lead.handin and farLeft)) then
                        local who = lead.place and atlas.PlaceName(lead.place)
                        local zone = lead.place and lead.place.mapID and atlas.ZoneName(lead.place.mapID)
                        local far = P.Reach(lead.place)
                        local function plural(n, one, few, many)
                            local m10, m100 = n % 10, n % 100
                            return (m10 == 1 and m100 ~= 11) and one or (m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14)) and few or many
                        end
                        local status
                        if lead.handin then
                            local hands = 0
                            for _, row in ipairs(errands) do if row.handin then hands = hands + 1 end end
                            status = {status=L"Сдай " .. hands .. " " .. plural(hands, L"задание", L"задания", L"заданий"), plate="blue",
                                lines={who and (L"Кому: " .. who) or nil, (zone or far) and (L"Где: " .. (zone or "") .. (far and ((zone and " • " or "") .. far) or "")) or nil},
                                goText=L"Путь к сдаче", goNote=L"Стрелка поведёт к тому, кому сдавать, самым быстрым путём."}
                        else
                            local left = 0
                            for _, row in ipairs(toGet) do if not (row.levelLocked or row.unknown or row.begins or row.askGroup) then left = left + 1 end end
                            local parts = {P.Title(lead.step or lead.id)}
                            if who then parts[#parts+1] = who end
                            if zone and zone ~= who then parts[#parts+1] = zone end
                            if far then parts[#parts+1] = far end
                            status = {status=lead.stage == 3 and (L"У входа: " .. (lead.handin and (L"сдать") or lead.working and (L"доделать") or (L"взять")) .. " «" .. P.Title(lead.step or lead.id) .. "»")
                                or left > 0 and (L"Возьми ещё " .. left .. " " .. plural(left, L"задание", L"задания", L"заданий") .. L" из " .. #prep)
                                or (L"Доделай снаружи: " .. #work), plate="gold",
                                lines={L"Начни с: " .. table.concat(parts, " • ")},
                                goText=L"Путь к первому", goNote=L"Стрелка поведёт к первому делу самым быстрым путём: сначала дальние от подземелья, у входа — последними."}
                        end
                        status.go = function() openRoute(lead) end
                        table.insert(detailRows, 1, status)
                    end
                end
                -- What the side can take and the character cannot (another's book showed the
                -- Compendium open to him): only in the tip of the heading of the quests. As a
                -- row of its own the owner asked what it was doing there.
                local notMine = {}
                for _, other in ipairs(P.NotForMe and P.NotForMe(selected) or {}) do
                    notMine[#notMine+1] = "«" .. ((P.Title(other.id) or "?"):gsub('^"(.*)"$', "%1")) .. "» — " .. other.why
                end
                if #notMine > 0 then
                    for _, row in ipairs(detailRows) do
                        if row.section and row.about and row.prepSection then
                            row.about = row.about .. "\n\n" .. L"Не для тебя:" .. "\n" .. table.concat(notMine, "\n")
                            break
                        end
                    end
                end
                -- Near the dungeon with nothing left to do outside, the next thing is the
                -- door, and the arrow leads to it unasked: the way into the place, then the
                -- portal; after a finished run, the way out. A ghost is led whatever is left.
                -- Once for each such moment: taken off by hand, the arrow stays off.
                local ghost = UnitIsGhost and UnitIsGhost("player") and true or false
                local clear = any and nearOnly and #doing == 0
                -- Only when it turns so before his eyes (the last quest out here taken or
                -- handed in), not at every login: then a sound and a line in the middle.
                local nowReady = clear and not beenInside
                if readyWas[selected.key] == false and nowReady then
                    local text = atlas.DungeonName(selected) .. ((#byTheWay > 0 or #asking > 0) and (L": можно идти в подземелье.") or (L": все задания взяты — можно идти в подземелье. Кнопка пути — на панели."))
                        .. (#byTheWay > 0 and (L" По дороге: " .. table.concat(byTheWay, ", ") .. ".") or "")
                        .. (#asking > 0 and (L" Попроси группу: " .. table.concat(asking, ", ") .. ".") or "")
                    say(text)
                    if RaidNotice_AddMessage and RaidWarningFrame then
                        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, {r=.45, g=1, b=.55})
                    end
                    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.READY_CHECK or 8960) end
                end
                readyWas[selected.key] = nowReady
                -- (Been inside, and quests of it still in the log: the way in is still the next
                -- thing - the owner, 15.11.2026: "all the quests are taken: send me inside".)
                local leftInside = #(shelves.taken or {}) + #doing > 0
                local moment = (ghost or (clear and not errandOut and not handInNext and (not beenInside or leftInside))) and (selected.key .. (ghost and ":ghost" or "")) or nil
                if not moment then
                    led = nil
                elseif led ~= moment and P.Door(selected) and not (atlas.Target and atlas.Target()) then
                    local door = P.Door(selected)
                    local far = P.Distance and P.Distance(door)
                    if far and far < 4000 then
                        led = moment
                        P.Mark(door, P.DoorLabel(selected), "entrance")
                    end
                end
                if not P.Doors and P.Door(selected) then table.insert(detailRows, {entrance=true}) end
                -- What waits for the run itself: quests in the log whose goals are inside,
                -- and quests given inside. Nothing to do about them beforehand.
                -- The owner: before the dungeon the panel is the preparation, every quest
                -- of it; the bosses are for the table inside, and for the book.
            end
            -- The tips ("+ Советы • N") are not on the panel any more: the owner, "it looks
            -- poor, and are these tips of any worth?"; the layout of 14.11.2026 has none. The
            -- ones that matter are said at their moment (watchNeeds, roomPing).
        end
        -- The owner missed the line that opened the book: "it was handy, to open our journal
        -- and look at all the quests". It is back, and on top this time, where he looks
        -- first; not in a fight, where the page is two rows.
        -- On the pages that are tables of sections; a page led by one quest or one boss
        -- under way keeps that on top.
        -- (In the look of the game's quests the journal is a word in the row under the heading.)
        if not compact and not bossTarget and detailRows[1] and (detailRows[1].section or detailRows[1].status or detailRows[1].big) and not nativeLook() then
            -- (Under the status, or the next boss, which is first.)
            table.insert(detailRows, (detailRows[1].status or detailRows[1].big) and 2 or 1, {book=true, plain=L"Открыть журнал: все задания и боссы"})
        end
        if compact then first, history = 1, {} end
        if result.ready and not db.ready[selected.key] then
            say(atlas.DungeonName(selected) .. L" — задания для входа готовы. У группы: " .. result.group .. L" • Внутри: " .. result.inside)
        end
        db.ready[selected.key] = result.ready or nil
    end
    if not browsing and not bossTarget and result and not included(selected, {total=#result.rows, finished=result.finished}) then
        db.browsing = true
        browsing, first, history, countsDirty = true, catalogFirst, {}, true
    end
    if browsing and countsDirty then rebuildList() end
    attach()
    if tracker then tracker:MarkDirty() end
    if card and (browsing or compact) then card:Hide() end
    -- The small plan follows the boss the run is heading for; it steps aside in a fight.
    if P.UpdatePlan then P.UpdatePlan(not browsing and planGuide or nil, compact) end
    -- The floor of the next boss, drawn by the atlas where the player has it; it steps
    -- aside in a fight and outside the dungeon.
    if P.Floor then
        local heading
        if selected and result and not browsing and P.InDungeon(selected) and P.Run then
            for _, stop in ipairs(P.Run(selected, result.rows) or {}) do
                if stop.next then heading = stop; break end
            end
        end
        P.Floor(heading, compact)
    end
    P.TidyArrow()
    if P.RefreshBook then P.RefreshBook() end
    -- Names the client had not loaded yet come in its own language a moment later.
    if P.namesPending and nameRetries < 4 then
        P.namesPending = false
        nameRetries = nameRetries + 1
        C_Timer.After(2, function() if not pending then P.Refresh() end end)
    end
end

function P.Redraw()
    if tracker then tracker:MarkDirty() end
end

local advance
local events = CreateFrame("Frame", "DungeonQuestForeverEvents")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS"}) do
    events:RegisterEvent(event)
end
for _, event in ipairs({"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "BOSS_KILL", "ENCOUNTER_END", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "LOOT_OPENED", "START_LOOT_ROLL"}) do
    pcall(events.RegisterEvent, events, event)
end
local sightings = {PLAYER_TARGET_CHANGED="target", UPDATE_MOUSEOVER_UNIT="mouseover"}
-- A goal of a quest met inside while others are left: said at once, in the chat and in
-- the middle of the screen, with where the next thing is. This is the moment the owner
-- needed it: the code looted off the boss, the blueprints still in the safe beside him.
local needsSeen = {}
local function nudge(text)
    say(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or {r=1, g=.82, b=.3})
    end
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
end
-- The owner: "it is very hard to find the loot of the bosses." A thing that drops (in the
-- window or put up for a roll) and is the best for its slot, or better than the one worn,
-- is said in the middle with its picture; once a minute for each thing.
local lootSaid = {}
function P.LootAlert(link, roll)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if not (id and P.Worth) then return end
    local worth = P.Worth(id)
    local good = worth.known and (worth.best or (worth.gain > 0 and not worth.worn and not worth.later))
    if not good then return end
    local now = GetTime and GetTime() or 0
    if lootSaid[id] and now - lootSaid[id] < 60 then return end
    lootSaid[id] = now
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
    local why = worth.best and (L"лучшее в слот") or (L"лучше надетого") .. (" +%.0f"):format(worth.gain)
    local text = (icon and ("|T" .. icon .. ":20:20|t ") or "") .. link .. " — " .. why .. (roll and (L": жми «Нужно»") or "")
    nudge(text)
    return text
end
local function watchNeeds(rows, inside)
    if not (P.Needs and inside) then needsSeen = {} return end
    local seen = {}
    for _, row in ipairs(rows or {}) do
        if row.state == "active" then
            local id = row.step or row.id
            local needs = P.Needs(id)
            local before = needsSeen[id]
            seen[id] = #needs
            if before and #needs < before then
                if #needs > 0 then
                    nudge("«" .. P.Title(id) .. L"»: осталось " .. P.NeedText(needs[1]))
                else
                    nudge("«" .. P.Title(id) .. L"»: всё собрано")
                end
            end
        end
    end
    needsSeen = seen
end
P.WatchNeeds = watchNeeds

-- A boss of the run seen dead: by the game's own word, or by its body under the cursor
-- or in the target frame.
local function seenDead(unit)
    if not (db and unit and P.Killed and UnitIsDead and UnitGUID) or (issecretvalue and issecretvalue(unit)) then return false end
    local d = atlas.CurrentDungeon and atlas.CurrentDungeon()
    if not d then return false end
    local ok, gone = pcall(UnitIsDead, unit)
    if not ok or (issecretvalue and issecretvalue(gone)) then return false end
    -- (The owner in the Drowned City, 15.11.2026: a groupmate died, was "killed" as a boss,
    -- was raised, and her being alive again was taken for a new run: every mark was gone.
    -- A player is never a boss; and where no run is written only the game's own word of a
    -- boss's death, BOSS_KILL, makes one, not any body under the cursor.)
    if UnitIsPlayer and UnitIsPlayer(unit) then return false end
    local npc, name = atlas.NpcIDFromGUID(atlas.PlainText(UnitGUID(unit))), UnitName and atlas.PlainText(UnitName(unit))
    if not npc then return false end
    if P.HasRun and not P.HasRun(d) then return false end
    -- Dead: struck off. Marked dead and standing there alive: the marks are another run's.
    if gone then return P.Killed(d, npc, name) end
    return P.Revived ~= nil and P.Revived(d, npc, name)
end

-- A boss came into sight, or went out of it: his room is noted and the page says so.
atlas.OnSight = function(who)
    local d = atlas.CurrentDungeon and atlas.CurrentDungeon()
    if who and d and P.SawBoss then P.SawBoss(d, who) end
    if db and not pending and P.Refresh then P.Refresh() end
end

events:SetScript("OnEvent", function(_, event, id, name, _, _, success)
    -- Whatever happened may have changed what in the quest log is junk.
    if P.JunkChanged then P.JunkChanged() end
    if event == "START_LOOT_ROLL" then
        local ok, link = pcall(GetLootRollItemLink, id)   -- (rollID, rollTime)
        if ok and link then P.LootAlert(link, true) end
        return
    end
    if event == "LOOT_OPENED" then
        -- What in the window is good for the character is said at once.
        if GetNumLootItems and GetLootSlotLink then
            pcall(function()
                for slot = 1, GetNumLootItems() do
                    local link = GetLootSlotLink(slot)
                    if link then P.LootAlert(link, false) end
                end
            end)
        end
        -- A body being looted is a dead one: its number is on every thing in the window.
        local d = db and atlas.CurrentDungeon and atlas.CurrentDungeon()
        if d and P.Killed and GetNumLootItems and GetLootSourceInfo then
            local news = false
            pcall(function()
                for slot = 1, GetNumLootItems() do
                    local guid = GetLootSourceInfo(slot)
                    if P.SeenCopy and P.SeenCopy(d, guid) then news = true end
                    local npc = atlas.NpcIDFromGUID(atlas.PlainText(guid))
                    if npc and P.Killed(d, npc) then news = true end
                end
            end)
            if news and not pending then P.Refresh() end
        end
        return
    end
    if event == "BOSS_KILL" or event == "ENCOUNTER_END" then
        local d = db and atlas.CurrentDungeon and atlas.CurrentDungeon()
        local won = event == "BOSS_KILL" or success == 1 or success == true
        if d and won and P.Killed and type(name) == "string" and P.Killed(d, nil, name) and not pending then P.Refresh() end
        if d and won and P.TellGroup then
            if C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(P.TellGroup) end) else pcall(P.TellGroup) end
        end
        return
    end
    if sightings[event] or event == "NAME_PLATE_UNIT_ADDED" then
        if db then
            local unit = sightings[event] or id
            P.SeenUnit(unit)
            -- Every creature inside tells the copy of the dungeon the group is in: the marks of
            -- the dead belong to one copy (P.SeenCopy).
            local d = P.SeenCopy and UnitGUID and unit and not (issecretvalue and issecretvalue(unit)) and atlas.CurrentDungeon and atlas.CurrentDungeon()
            if d and not (UnitIsPlayer and UnitIsPlayer(unit)) then
                local ok, guid = pcall(UnitGUID, unit)
                if ok and guid and not (issecretvalue and issecretvalue(guid)) and P.SeenCopy(d, guid) and not pending then P.Refresh() end
            end
            if seenDead(unit) and not pending then P.Refresh() end
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and seenDead("target") then countsDirty = true end
    if event == "PLAYER_LOGIN" then initialize() end
    if (event == "QUEST_TURNED_IN" or event == "QUEST_ACCEPTED") and id and selected and result then
        for _, row in ipairs(result.rows) do
            if row.step == id or row.id == id then
                -- goal: the quest of the row; leads: the quest that row is a step towards;
                -- took: the quest just accepted. By any of them the same line of quests is
                -- found again once the page is built anew.
                advance = {dungeon=selected.key, id=event == "QUEST_TURNED_IN" and id or nil, goal=row.id, leads=row.leads,
                    took=event == "QUEST_ACCEPTED" and id or nil}
                if row.id ~= id then break end
            end
        end
    end
    if event ~= "QUEST_DATA_LOAD_RESULT" and event ~= "BAG_UPDATE_DELAYED" and event ~= "ZONE_CHANGED" and event ~= "ZONE_CHANGED_INDOORS" then countsDirty = true end
    if not db or pending then return end
    pending = true
    -- A quest taken, handed in or dropped is shown at once; the rest (the log touched, the
    -- bags, a new hall) is gathered for a second: the page was built anew four times a
    -- second while walking and looting. (The owner: "take the lags away.")
    local soon = event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED"
        or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP"
    C_Timer.After(soon and .25 or 1, function()
        pending = false
        P.Refresh()
        if advance and selected and not bossTarget and selected.key == advance.dungeon and not P.InDungeon(selected) then
            -- The owner, going down a chain: "after I hand a quest in the navigation does
            -- not go on, I have to set it by hand." It led on only to the nearest errand
            -- within reach, and offered nothing across the sea unasked. A chain under way
            -- is asked for already: the next step of the same quest gets the arrow, by the
            -- whole way (a flight, a teleport, a zeppelin), wherever it is.
            local onward
            for _, entry in ipairs(detailRows) do
                local row = entry.now and entry.row or entry
                local same = row.id and (row.id == advance.goal or row.id == advance.leads or row.id == advance.took or row.step == advance.took
                    or (row.leads and (row.leads == advance.goal or row.leads == advance.leads)))
                if same and not onward and row.place and row.state ~= "done" and not row.levelLocked and not row.unknown then onward = row end
            end
            local target = atlas.Target and atlas.Target()
            local stale = target and target.questID and (target.questID == advance.id or (onward and (target.questID == onward.step or target.questID == onward.id)))
            if onward and (not target or stale) then
                local ok, text = pcall(P.Route, selected, onward, false, true)
                if ok and type(text) == "string" then say(L"Дальше по цепочке • " .. text) end
                -- The chain followed is the one unfolded on the panel.
                if nativeLook() then
                    unfolded = ((onward.step ~= onward.id and onward.id) or onward.leads) or onward.id
                    P.Refresh()
                end
            elseif atlas.NavigationVector then
                -- A quest was just taken or handed in: lead on to the nearest errand left,
                -- and only to one within reach. Nothing across the sea is offered unasked.
                local nearest, range
                for _, entry in ipairs(detailRows) do
                    -- The errand said in "Now" counts with the ones in the lists.
                    local row = entry.now and entry.row or entry
                    if row.id and entry.brief and row.place and row.step ~= advance.id and row.id ~= advance.id then
                        local distance = P.Distance(row.place)
                        if distance and (not range or distance < range) then nearest, range = row, distance end
                    end
                end
                if nearest and not (atlas.Target and atlas.Target()) then P.Route(selected, nearest, true) end
            else
                local label = P.NextPickup(selected, result.rows, advance.id, advance.goal)
                if label then say(label) end
            end
        end
        advance = nil
    end)
end)
SLASH_FOREVERDUNGEONPREP1 = "/dq"
SLASH_FOREVERDUNGEONPREP2 = "/dprep"
SlashCmdList.FOREVERDUNGEONPREP = function(msg)
    if not db then return end
    if P.Track then P.Track("Command", msg) end
    P.Refresh()
    if msg and msg:match("^%s*run%s*$") then
        if P.NewRun then P.NewRun() end
        if P.Track then P.Track("NewRun") end
        P.Refresh()
        say(L"Новый заход: отметки убитых боссов сброшены.")
        return
    end
    -- /dq size 1.5 makes the panel larger or smaller; /dq place puts it back beside the
    -- column of tasks.
    if msg and msg:match("^%s*book%s*$") then
        if P.ToggleBook then P.ToggleBook(not browsing and selected or nil) end
        return
    end
    if msg and msg:match("^%s*gear%s*$") then
        if P.ToggleGear then P.ToggleGear() end
        return
    end
    local size = msg and msg:match("^%s*size%s*([%d%.,]*)%s*$")
    if size then
        local value = tonumber((size:gsub(",", ".")))
        if not value then
            say(L"Размер панели сейчас " .. (db.boardScale or 1) .. L". Набери, например, /dq size 1.3 (от 0.8 до 2).")
            return
        end
        value = math.max(.8, math.min(2, value))
        db.boardScale = value
        if tracker and tracker.SetScale then
            tracker:SetScale(value)
            tracker:MarkDirty()
        end
        say(L"Размер панели: " .. value .. ".")
        return
    end
    -- The owner: "try it - go in and put a point somewhere". Tried in the game on
    -- 13.11.2026 with C_Ping.SendMacroPing, with no target and on the player: the game
    -- answered ADDON_ACTION_FORBIDDEN both times. A ping can be sent by the player's own
    -- key alone; the try is taken out so that nobody trips the game's warning again.
    if msg and msg:match("^%s*ping%s*$") then
        db.noPing = not db.noPing or nil
        say(db.noPing and (L"Сигнал при входе в зал выключен.") or (L"При входе в новый зал подземелья: звук и строка по центру экрана, куда дальше."))
        return
    end
    if msg and msg:match("^%s*back%s*$") then
        db.boardBack = not db.boardBack or nil
        if tracker and tracker.Skin then
            tracker:Skin()
            tracker:MarkDirty()
        end
        say(db.boardBack and (L"У панели снова тёмный фон.") or (L"Фон панели убран: как у списка заданий игры."))
        return
    end
    if msg and msg:match("^%s*glow%s*$") then
        db.noGlow = not db.noGlow or nil
        local done = atlas.ObjectGlow and atlas.ObjectGlow(not db.noGlow)
        if db.noGlow then say(L"Подсветка предметов и объектов выключена, настройки игры возвращены как были.")
        elseif done then say(L"Над предметами и объектами рядом, нужными для заданий из журнала, игра покажет значок, и прозвучит сигнал. Над стульями и прочим значка не будет.")
        else say(L"Этот клиент не умеет подсвечивать объекты.") end
        return
    end
    if msg and msg:match("^%s*share%s*$") then
        db.noShare = not db.noShare or nil
        say(db.noShare and (L"Группе и рейду об аддоне больше не рассказываю.")
            or (L"После первого босса расскажу группе или рейду об аддоне одной строкой — если там есть кто-то без него, и не чаще раза в два часа."))
        return
    end
    if msg and msg:match("^%s*paths%s*$") then
        db.noPaths = not db.noPaths or nil
        if P.WalkReset then P.WalkReset() end
        say(db.noPaths and (L"Стрелка снова показывает на цель напрямую.") or (L"Стрелка ведёт по проходимым дорогам, в обход гор и обрывов."))
        return
    end
    if msg and msg:match("^%s*minimap%s*$") then
        db.minimapHidden = not db.minimapHidden or nil
        P.MinimapButton()
        say(db.minimapHidden and (L"Кнопка у миникарты спрятана. /dq minimap вернёт её.") or (L"Кнопка у миникарты снова на месте."))
        return
    end
    if msg and msg:match("^%s*bug%s*$") then
        P.ShowBugReport()
        return
    end
    if msg and msg:match("^%s*welcome%s*$") then
        P.ShowWelcome()
        return
    end
    if msg and msg:match("^%s*junk%s*$") then
        P.ShowJunk()
        return
    end
    if msg and msg:match("^%s*auto%s*$") then
        db.noAuto = not db.noAuto or nil
        say(db.noAuto and (L"Задания больше не принимаются и не сдаются сами. /dq auto вернёт.")
            or (L"Задания принимаются и сдаются сами. Серые и повторяемые остаются тебе, выбор награды тоже; с зажатым Shift — всё вручную."))
        return
    end
    if msg and msg:match("^%s*cards%s*$") then
        db.boardCards = not db.boardCards or nil
        -- The page itself differs between the two looks: it is built again.
        if P.Refresh then P.Refresh() elseif tracker then tracker:MarkDirty() end
        say(db.boardCards and (L"Панель снова карточками, крупнее.") or (L"Панель в виде заданий игры: её шрифты, круглые значки, строки с тире."))
        return
    end
    if msg and msg:match("^%s*dock%s*$") then
        db.boardFree = not db.boardFree or nil
        local docked = tracker and tracker.Dock and tracker:Dock(not db.boardFree)
        say(db.boardFree and (L"Панель отпущена: её можно тащить за заголовок. /dq dock вернёт её в колонку заданий.")
            or docked and (L"Панель снова в колонке заданий, под «Все задания».")
            or (L"Встроить панель в колонку заданий здесь не вышло: она стоит отдельно."))
        return
    end
    if msg and msg:match("^%s*place%s*$") then
        db.board = nil
        if tracker and tracker.Place then tracker:Place() end
        say(L"Панель возвращена на место рядом со списком заданий.")
        return
    end
    if msg and msg:match("^%s*column%s*$") then
        db.columnFixed = not db.columnFixed or nil
        if tracker then tracker:MarkDirty() end
        say(db.columnFixed and (L"Столбец задач больше не сдвигается и возвращён на место. Из-под панелей уходит только список этого аддона.")
            or (L"Весь столбец задач сдвигается из-под панелей способностей."))
        return
    end
    if msg and msg:match("^%s*sign%s*$") then
        -- The sign over the head needs the name bars of friendly characters; this is the
        -- switch for those who would rather not have them come on.
        db.noSign = not db.noSign or nil
        if db.noSign and atlas.Friendly then atlas.Friendly(false) end
        say(db.noSign and (L"Полоски имён рядом с целью больше не включаются. Метка над головой видна, только если полоски включены тобой.")
            or (L"Рядом с целью полоски имён включаются сами, над нужным персонажем встаёт метка."))
        return
    end
    if msg and msg:match("^%s*boss%s*$") and tracker then
        local d = selected
        if not P.InDungeon(d) then
            local current = atlas.CurrentDungeon and atlas.CurrentDungeon()
            if current then d = current end
        end
        if not d then say(L"Сначала выбери подземелье в /dq.") return end
        if not P.InDungeon(d) then say(L"Босса выбирают внутри подземелья. Зайди и набери /dq boss.") return end
        if #P.BossChoices(d) == 0 then say(L"Для этого подземелья в атласе нет боссов.") return end
        tracker:SetCollapsed(false)
        choose(d, true)
        tracker.bossMenu:Show()
        tracker.bossMenu:OpenMenu()
        return
    end
    if msg and msg:match("^%s*where%s*$") then say(P.WhereAmI()) return end
    if msg and msg:match("^%s*next%s*$") then
        local dungeon = selected
        if browsing and not P.InDungeon(dungeon) then
            for _, d in ipairs(catalog) do
                if P.InDungeon(d) then dungeon = d break end
            end
        end
        if not dungeon then say(L"Выбери подземелье в /dq.") return end
        if bossTarget and bossTarget.dungeon == dungeon then P.OpenBoss(bossTarget) return end
        say(P.NextPickup(dungeon, P.Build(dungeon).rows, nil, nil, true) or (L"Доступных целей с известным маршрутом сейчас нет."))
        return
    end
    if tracker then
        tracker:SetCollapsed(false)
        browse()
    end
end

-- ------------------------------------------
-- The addons of the other players: versions, and a word to the group
-- ------------------------------------------
-- The owner: "how will people update - can they be made to?" They cannot: an addon has
-- no way to fetch a file. But the addons of a group or a guild tell each other their
-- version, unseen, and one older than another's says so in its chat once.
-- And: "the addon has to make itself known: at some moment a line with the link to it,
-- and a short word of what it is." After the first boss of a run, out of combat, in the
-- chat of the group or the raid: once in two hours at most, and only when someone there
-- has no addon of ours. In English: the groups are of every tongue. /dq share, or the menu, stops it.
do
    local PREFIX = "DQForever"
    -- (No web address: a link in the chat cannot be copied; the name is searched for.)
    -- 3.51.0: the owner asked for more of it, leading with the way to the bosses.
    local AD = "Dungeon Quest Forever (addon, on CurseForge and Wago): the way to every boss inside, "
        .. "what each drops for your class, and every quest of the dungeon before you go."
    -- Told once to each new group mate without the addon (again after two hours), and not
    -- more often than every 20 minutes.
    local peers, newsSaid, lastHello, waiting, told = {}, false, {}, false, {}
    local function mine()
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ok, v = pcall(get, "ForeverDungeonPrep", "Version")
        return ok and type(v) == "string" and v or "0"
    end
    -- Whether version a is later than b ("3.40.0" > "3.39.12").
    local function later(a, b)
        local x, y = {}, {}
        for n in tostring(a):gmatch("%d+") do x[#x+1] = tonumber(n) end
        for n in tostring(b):gmatch("%d+") do y[#y+1] = tonumber(n) end
        for i = 1, math.max(#x, #y) do
            if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
        end
        return false
    end
    P.LaterVersion = later
    local function hello(channel)
        local now = GetTime and GetTime() or 0
        if lastHello[channel] and now - lastHello[channel] < 60 then return end
        lastHello[channel] = now
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V:" .. mine(), channel) end
    end
    local function groupChannel()
        if not (IsInGroup and IsInGroup()) then return end
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and not IsInGroup(LE_PARTY_CATEGORY_HOME or 1) then return "INSTANCE_CHAT" end
        return (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
    end
    local function helloAll()
        local channel = groupChannel()
        if channel then hello(channel) end
        if IsInGuild and IsInGuild() then hello("GUILD") end
    end
    -- Shared from the log: a quest at a time (the game takes one), a second apart.
    local function push(id, delay)
        local function go()
            pcall(function()
                if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id)
                elseif SelectQuestLogEntry and GetQuestLogIndexByID then SelectQuestLogEntry(GetQuestLogIndexByID(id)) end
                if QuestLogPushQuest then QuestLogPushQuest() end
            end)
        end
        if delay > 0 and C_Timer and C_Timer.After then C_Timer.After(delay, go) else go() end
    end
    function P.HeardAddon(prefix, text, channel, sender)
        if prefix ~= PREFIX or type(text) ~= "string" then return end
        local asked = text:match("^ASK:(.+)$")
        if asked then
            local me = UnitName and UnitName("player")
            local from = type(sender) == "string" and ((Ambiguate and Ambiguate(sender, "none")) or sender:match("^[^-]+")) or nil
            if from and me and from == me then return end
            local n = 0
            for id in asked:gmatch("%d+") do
                id = tonumber(id)
                if id and P.IsActive and P.IsActive(id) then
                    push(id, n * 1.2)
                    n = n + 1
                end
            end
            return n
        end
        local v = text:match("^V:(.+)$")
        if not v then return end
        local name = type(sender) == "string" and ((Ambiguate and Ambiguate(sender, "none")) or sender:match("^[^-]+")) or nil
        if name then
            if not peers[name] then if P.Track then P.Track("MetAddonUser") end end
            peers[name] = v
        end
        if later(v, mine()) and not newsSaid then
            newsSaid = true
            say(L"Вышла новая версия Dungeon Quest Forever: " .. v .. L" (у тебя " .. mine() .. L"). Обнови её через приложение CurseForge или Wago, или скачай с их страниц.")
        end
        -- Answered, so that the other learns of ours too (not more than once a minute).
        if channel then hello(channel) end
        return v
    end
    -- One click: the quests of this dungeon in the log shared with the group, the missing
    -- ones asked for in its chat (with the addon's word), and asked of the addons there.
    function P.ShareWithGroup()
        if not (selected and result) then return end
        if P.Track then P.Track("SharedWithGroup") end
        local channel = groupChannel()
        if not channel then say(L"Ты не в группе: делиться не с кем. Вступи в группу — тогда кнопка поделится твоими заданиями и попросит недостающие.") return end
        -- The owner: "it writes Russian into an English chat; such links nobody can copy;
        -- the button should share my quests and ask them to share theirs." So: ours pushed,
        -- one line in English with the English names, the addon named to be searched for.
        local mineIds, want, names = {}, {}, {}
        for _, row in ipairs(result.rows) do
            local id = row.step or row.id
            if row.state == "active" and row.share then
                mineIds[#mineIds+1] = id
            elseif row.state ~= "done" and row.state ~= "active" and row.share and row.step == row.id and not (row.levelLocked or row.unknown) then
                want[#want+1] = id
                names[#names+1] = (P.QuestDB and P.QuestDB.GetEn and P.QuestDB.GetEn(id)) or tostring(id)
            end
        end
        for i, id in ipairs(mineIds) do push(id, (i - 1) * 1.2) end
        if C_ChatInfo and C_ChatInfo.SendAddonMessage and #want > 0 then
            pcall(C_ChatInfo.SendAddonMessage, PREFIX, "ASK:" .. table.concat(want, ","), channel)
        end
        if #mineIds + #want > 0 then
            local place = selected.nameEn or atlas.DungeonName(selected)
            local tail = " (Dungeon Quest Forever addon - find it on CurseForge)"
            local line
            if #want > 0 then
                local list = table.concat(names, ", ")
                local head = (#mineIds > 0 and ("Sharing my " .. place .. " quests - ") or "") .. "please share yours: "
                if #head + #list + #tail > 250 then list = list:sub(1, 250 - #head - #tail - 3) .. "..." end
                line = head .. list .. tail
            else
                line = "Sharing my " .. place .. " quests - share yours too!" .. tail
            end
            if SendChatMessage then pcall(SendChatMessage, line, channel) end
            if db then db.toldAt = GetServerTime and GetServerTime() or 0 end
        end
        say(L"Поделился с группой: " .. #mineIds .. L", попросил у группы: " .. #want .. ".")
        return #mineIds, #want
    end
    function P.TellGroup()
        if not db or db.noShare then return end
        local channel = groupChannel()
        -- (In a raid too, since 15.11.2026: the owner asked for it.)
        if not channel then return end
        if not (IsInInstance and IsInInstance()) then return end
        local now = GetServerTime and GetServerTime() or 0
        if db.toldAt and now - db.toldAt < 1200 then return end
        local without, names = false, {}
        -- In a party the others are party1..4; in a raid raid1..40, the player among them.
        local raid = channel == "RAID"
        local count = GetNumGroupMembers and GetNumGroupMembers() or 1
        for i = 1, raid and count or count - 1 do
            local unit = (raid and "raid" or "party") .. i
            local me = raid and UnitIsUnit and UnitIsUnit(unit, "player")
            if not me then
                local ok, name = pcall(UnitName, unit)
                local plain = ok and type(name) == "string" and not (issecretvalue and issecretvalue(name))
                if plain then names[#names + 1] = name end
                if not (plain and peers[name]) and not (plain and told[name] and now - told[name] < 7200) then without = true end
            end
        end
        if not without then return end
        if InCombatLockdown and InCombatLockdown() then waiting = true return end
        waiting = false
        db.toldAt = now
        for _, name in ipairs(names) do told[name] = now end
        if SendChatMessage then pcall(SendChatMessage, AD, channel) end
        if P.Track then P.Track("ToldGroup") end
        return AD
    end
    if CreateFrame and UIParent then
        local word = CreateFrame("Frame", "DungeonQuestForeverWord", UIParent)
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
        for _, event in ipairs({"CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do
            pcall(word.RegisterEvent, word, event)
        end
        word:SetScript("OnEvent", function(_, event, ...)
            if event == "CHAT_MSG_ADDON" then
                pcall(P.HeardAddon, ...)
            elseif event == "PLAYER_REGEN_ENABLED" then
                if waiting then pcall(P.TellGroup) end
            elseif C_Timer and C_Timer.After then
                C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 10 or 3, function() pcall(helloAll) end)
            end
        end)
    end
end
