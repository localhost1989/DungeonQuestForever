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
        GameTooltip:SetText(L"Убрать стрелку", 1, .83, .35, true)
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
    return count.total > 0 and not db.hidden[d.key] and not (db.hideDone and isClosed(count))
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
local function settleMark()
    local target = atlas.Target and atlas.Target()
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

local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffedc36f" .. title .. "|r • " .. message)
end

local function tip(owner, title, note)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, .83, .35, true)
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
            -- The small map, not the full-screen one, where the client has both.
            if WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame.Minimize and not InCombatLockdown() then
                local ok, big = pcall(WorldMapFrame.IsMaximized, WorldMapFrame)
                if ok and big then pcall(WorldMapFrame.Minimize, WorldMapFrame) end
            end
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
    if entry.boss then P.OpenBoss(entry) return end
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
        if entry.option and P.PickDoor then P.PickDoor(selected, entry.option.id) end
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
    bugs.link.keep = AUTHOR_LINK .. "/issues"
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

function P.Selected() return selected, result end
function P.OpenRow(row) openRoute(row) end
function P.Choose(d) choose(d) end

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
        if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, on and 0 or .8) end
        if on and self.SetBackdropBorderColor then self:SetBackdropBorderColor(0, 0, 0, 0) end
        local font = on and ownFonts().sub or ownFonts().button
        if font then pcall(self.label.SetFontObject, self.label, font) end
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", on and 0 or 8, 0)
        self:SetHeight(on and 16 or 22)
        if not on then self.link, self.linkTip = nil, nil end
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
    local room = (self.GetWidth and self:GetWidth() or 260) - 30
    local left, top = 0, 0
    for i, item in ipairs(items) do
        local button = navButton(nav, i)
        button:Plain(true)
        button.option, button.choice, button.link, button.linkTip = item.option, nil, item.link, item.tip
        button.text, button.leads = item.text, item.lit and true or false
        button.label:SetText((item.lit and "|cffffffff" or "|cffffd100") .. "• " .. item.text .. "|r")
        local width = (button.label:GetStringWidth() or 60) + 6
        if left > 0 and left + width > room then left, top = 0, top + 16 end
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", nav, "TOPLEFT", left, -top)
        button:Show()
        left = left + width + 4
    end
    for i = #items + 1, #nav.buttons do nav.buttons[i]:Hide() end
    nav:SetShown(#items > 0)
    nav.rows = #items > 0 and (top / 16 + 1) or 0
    self.fromHeaderOffsetY = #items > 0 and -(10 + top + 16) or -6
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
            items[#items+1] = {text=option.short or (L"Ко входу"), option=option, lit=leads}
        end
        if not browsing and selected and not self:IsCollapsed() and not compact then
            items[#items+1] = {text=L"Журнал", tip=L"Книга: все задания и боссы подземелья, добыча боссов.",
                link=function() if P.ToggleBook then P.ToggleBook(selected) end end}
        end
        -- The junk in the quest log, when there is any: a word that opens the list of it.
        local junk = not compact and not self:IsCollapsed() and P.JunkCount and P.JunkCount() or 0
        if junk > 0 then
            items[#items+1] = {text=L"Мусор: " .. junk, tip=L"Серые неначатые задания без цепочек. Щелчок покажет список и спросит, убрать ли их.",
                link=function() if P.ShowJunk then P.ShowJunk() end end}
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
local function fontOf(entry)
    local own = ownFonts()
    if entry.section or entry.group or entry.routeCount then return own.label or GameFontNormalMed2 or GameFontNormal end
    if entry.now or entry.status or entry.big or entry.heading or (entry.prep and entry.lead) then return own.big or GameFontNormalMed3 or GameFontNormalLarge end
    return own.row
end

-- A line under a row: no dash before it, and a size of its own. The tracker sizes the
-- line as it adds it, so the height is measured again here and the block told of it.
local function addLine(block, key, text)
    -- Seen in the game: the dash stayed. The style has gone by two names over the years,
    -- and by the number two under both; and the dash is hidden by hand besides.
    local hide = (ObjectiveTrackerDashStyle and ObjectiveTrackerDashStyle.Hide) or OBJECTIVE_DASH_STYLE_HIDE or 2
    local line = block:AddObjective(key, text, nil, true, hide)
    if type(line) == "table" and type(line.Dash) == "table" and line.Dash.Hide then pcall(line.Dash.Hide, line.Dash) end
    local font = ownFonts().sub
    if font and type(line) == "table" and type(line.Text) == "table" and line.Text.SetFontObject then
        pcall(function()
            local old = line:GetHeight()
            line.Text:SetFontObject(font)
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

-- A line struck through: a step of a chain that is done. (The owner: "the task is struck
-- out, without any 'handed in'. Done - struck out, on to the next.") The game's font has
-- no struck letters, so a thin line is laid over the words.
local function addStruck(block, key, text)
    local line = addLine(block, key, text)
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
            list[#list+1] = {stop=true, listed=true, npc=stop.npc, name=stop.name, dead=stop.dead and true or false,
                next=inside and stop.next or nil, optional=stop.optional, mine=(not weighed) and mine or 0, best=best, better=better, lines={}}
        end
    end
    if total == 0 then return {} end
    table.insert(list, 1, {section=L"Боссы • убито " .. dead .. L" из " .. total,
        about=L"Все боссы подземелья по порядку. Убитый остаётся в списке зачёркнутым. ПКМ по боссу отмечает его убитым или возвращает."})
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
        -- A thin rule over the label of a section, and air above it.
        if block.CreateTexture then
            if label and not block.rule then
                block.rule = block:CreateTexture(nil, "ARTWORK")
                if block.rule.SetColorTexture then block.rule:SetColorTexture(.62, .52, .32, .45) end
                block.rule:SetHeight(1)
                block.rule:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 6)
                block.rule:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 6)
            end
            if block.rule then block.rule:SetShown(label and i > first) end
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
                    or taken and SIGN.log or SIGN.take
            elseif entry.id then
                local id = entry.step or entry.id
                sign = (entry.levelLocked or entry.unknown) and SIGN.lock or entry.handin and SIGN.ready
                    or P.IsActive(id) and ((C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) and SIGN.ready or SIGN.log) or SIGN.take
            end
        end
        if block.Dress then block:Dress(sign) end
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
                    block:SetHeader("  |cffffd34d" .. entry.name .. "|r" .. (near and (L"|cff71c886 • рядом, метка над ним|r") or ""))
                else
                    block:SetHeader("  " .. entry.name .. (near and (L"|cff71c886 • рядом, метка над ним|r") or entry.next and (L"|cffffd34d • следующий|r")
                        or entry.optional and (DIM .. L" • по желанию|r") or "")
                        .. ((entry.best or 0) > 0 and (L"|cffffd34d • лучшее в слот: " .. entry.best .. "|r")
                            or (entry.better or 0) > 0 and (L"|cff40e040 • лучше надетого: " .. entry.better .. "|r")
                            or (entry.mine or 0) > 0 and (L"|cff40e040 • тебе: " .. entry.mine .. "|r") or ""))
                end
            end
            for i, line in ipairs(entry.lines) do
                -- A fight leaves room for two lines.
                if entry.heading and i > 2 then break end
                addLine(block, "line" .. i, line)
            end
        elseif entry.status then
            block:SetHeader("  " .. (entry.good and "|cff71c886" or "|cffffd34d") .. entry.status .. "|r")
            if entry.hint then addLine(block, "hint", entry.hint) end
            if entry.note then addLine(block, "note", DIM .. entry.note .. "|r") end
        elseif entry.section then
            block:SetHeader(labelTone .. entry.section .. "|r")
            if entry.under then addLine(block, "under", DIM .. entry.under .. "|r") end
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
                addLine(block, "keeper", L"пешком через проход между зонами: по прямой там не пройти")
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
                block:SetHeader("  " .. tone .. (P.Title(goal or entry.id) or title) .. "|r")
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
                local act, said
                if locked then
                    act = entry.note or (L"пока недоступно")
                    said = true
                elseif entry.handin then
                    act = chain .. GREEN .. L"сдать|r" .. named
                elseif entry.working then
                    act = chain .. BLUE .. L"сделать|r" .. named .. (entry.work and entry.work.text and (": " .. entry.work.text) or "")
                elseif taken then
                    act = entry.handInside and (chain .. GREEN .. L"сдать внутри|r" .. named .. (type(entry.handInside) == "string" and (": " .. entry.handInside) or ""))
                        or (goal and (chain .. GREEN .. L"в журнале|r" .. named .. DIM .. L", делается внутри|r") or (GREEN .. L"в журнале|r" .. DIM .. L", делается внутри|r"))
                    said = true
                elseif entry.stepActive then
                    -- A step of the chain that is in the log: to hand in, or to finish.
                    act = chain .. (entry.act == "turnin" and (GREEN .. L"сдать|r") or (BLUE .. L"доделать|r")) .. named
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
                    addLine(block, "act", GOLD .. L"сейчас:|r " .. core .. (toSomeone and (" — " .. who) or ""))
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
                    -- Folded: one line. What to do, and for a taking or a handing in, with whom and how far.
                    local tail = ""
                    if toSomeone then
                        local far = P.Reach(entry.place)
                        tail = ": " .. who .. (far and (DIM .. " • |r" .. GOLD .. far .. "|r") or "")
                    end
                    addLine(block, "act", act .. tail)
                else
                    -- Taken or not, in a word, where the line below does not say it itself:
                    -- the same word as in the count over the list.
                    if not said then
                        addLine(block, "state", taken and (GREEN .. L"взято|r") or (ORANGE .. L"не взято|r" .. (goal and (DIM .. L" • сначала цепочка|r") or "")))
                    end
                    addLine(block, "act", act)
                    whereLine(false)
                end
                if entry.shared and not locked then addLine(block, "shared", L"им может поделиться группа") end
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
    local plain = MenuUtil and MenuUtil.CreateContextMenu and true or false
    local button = CreateFrame(plain and "Button" or "DropdownButton", nil, tracker.Header)
    button:SetSize(24, 19)
    button:SetPoint("RIGHT", tracker.Header.MinimizeButton, "LEFT", -2, 0)
    local dots = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dots:SetPoint("CENTER")
    dots:SetText("•••")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:HookScript("OnEnter", function() tip(button, L"Выбрать подземелье", L"Список подземелий с заданиями для тебя: сколько сдано и взято, что уже пройдено.") end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    if plain then
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function(self)
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, dungeonMenu)
        end)
        button.openMenu = dungeonMenu
    else
        button:SetupMenu(dungeonMenu)
    end
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
    function board:Skin()
        local dark = db and db.boardBack
        if self.SetBackdrop then
            self:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=14, insets={left=3, right=3, top=3, bottom=3}})
            self:SetBackdropColor(.03, .02, .02, dark and .95 or 0)
            self:SetBackdropBorderColor(.72, .6, .36, dark and 1 or 0)
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
    minimize:SetScript("OnClick", function() board:SetCollapsed(not board:IsCollapsed()) end)
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
            self.objectives = nil
            self.struck = nil
            for _, line in ipairs(self.lines) do line:Hide() end
            self.count = 0
            self.HeaderText:SetWidth(blockWidth + (self.rightEdgeOffset or 0) - (self.inset or 0))
            self.HeaderText:SetText(text)
            self.height = self.HeaderText:GetStringHeight() or 14
        end
        function block:AddObjective(key, text)
            self.objectives = self.objectives or {}
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
                line.dash:SetShown(native and not deep and true or false)
                if native and font then line.dash:SetFontObject(font) end
                if native and line.dash.SetTextColor then line.dash:SetTextColor(.8, .8, .8) end
            end
            if native and line.Text.SetTextColor then line.Text:SetTextColor(.8, .8, .8) end
            local lead = native and (deep and 16 or 8) or 0
            line.Text:ClearAllPoints()
            line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", lead, 0)
            local indent = native and ((self.inset or 0) > 0 and (self.inset - 2) or INDENT)
                or ((self.inset or 0) > 0 and (self.inset + 6) or INDENT)
            local width = blockWidth - indent + (self.rightEdgeOffset or 0)
            line.Text:SetWidth(width - lead)
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
                if entry.npc and P.HasPlan and P.HasPlan(entry.npc) then
                    if db then db.floorOff = nil end
                    P.OpenPlan(entry.npc)
                    P.Refresh()
                end
                return
            end
            if entry.book then
                if P.OpenBook then P.OpenBook(selected) end
                return
            end
            if entry.status and entry.door then openRoute({entrance=true}) return end
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
                if mouse == "RightButton" then P.OpenBoss(entry)
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
            elseif entry.prep and tracker.isBoard and nativeLook() and mouse ~= "RightButton" then
                -- In the look of the game's quests a click unfolds the quest in place and
                -- sets the arrow; a click on the unfolded one folds it again. The window
                -- with the map and the buttons is behind the right button.
                local key = ((entry.step ~= entry.id and entry.id) or entry.leads) or entry.id
                if unfolded == key then
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
            if e.stop and e.npc and P.HasPlan and P.HasPlan(e.npc) then tip(block.HeaderButton, e.name, L"Щелчок: большой план этажа в атласе, босс подсвечен.\nПКМ: отметить убитым или вернуть живым, если аддон сам не заметил.") return end
            if e.stop then tip(block.HeaderButton, e.name, e.dead and (L"Этот босс убит. ПКМ вернёт его в живые.") or (e.npc and P.HasPlan and P.HasPlan(e.npc) and (L"Щелчок: карта атласа с этим боссом и маленький план этажа.\n") or "") .. L"ПКМ: отметить убитым, если аддон сам не заметил.\n" .. L"Места внутри подземелья аддон не знает: игра не сообщает там положение. Порядок боссов взят из классической версии.") return end
            if e.book then tip(block.HeaderButton, L"Журнал подземелья", L"Все задания с подробностями и цепочками по шагам и все боссы. То же делает значок книжки в заголовке и команда /dq book.") return end
            if e.plain then return end
            if e.now then tip(block.HeaderButton, L"Сейчас", L"Щелчок ставит стрелку и показывает карточку этого шага.") return end
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
                lines[#lines+1] = steps > 1 and (L"Щелчок — следующий шаг, когда дошёл до перехода. ПКМ — большой план атласа.")
                    or (L"Щелчок — маленький план рядом с трекером. ПКМ — большой план атласа.")
                tip(block.HeaderButton, atlas.BossName(e.boss, selected), table.concat(lines, "\n"))
            elseif e.routeCount then
                tip(block.HeaderButton, L"Советы", L"Секреты, ключи и редкие боссы этого подземелья. Нажми, чтобы раскрыть или свернуть.")
            elseif e.secret then
                tip(block.HeaderButton, e.secret.kind, #e.secret > 1 and (L"Нажми на строку, чтобы увидеть следующий шаг.") or e.action)
            else
                local chain, at, total = chainOf(e.step ~= e.id and e.id or e.leads or e.id)
                tip(block.HeaderButton, P.Title(e.id), (e.detail or e.note or "")
                    .. (e.share and e.state == "missing" and (L"\nЗаданием может поделиться участник группы.") or "")
                    .. (chain and (L"\n\nЦепочка заданий (шаг " .. at .. L" из " .. total .. "):\n" .. table.concat(chain, "\n")) or "")
                    .. ((e.prep and tracker.isBoard and nativeLook()) and (L"\nЩелчок — раскрыть или свернуть. Правая кнопка — карта и подробности.")
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
    -- The addon's own ground: dungeons and quests are read from QuestieDB here.
    if atlas.Init then atlas.Init(db) end
    if P.SeedEver then P.SeedEver() end
    -- The page of welcome: once to a character, a few seconds after coming in, not in a fight.
    if not db.welcomed and C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if not db.welcomed and not InCombatLockdown() then pcall(P.ShowWelcome) end
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
        if P.WatchNeeds then P.WatchNeeds(result.rows, inDungeon) end
        if inDungeon and P.InferKills then P.InferKills(selected, result.rows) end
        -- Walking in is the start of a run, unless the last boss fell a moment ago. The
        -- first look after a /reload inside counts the same: old marks do not outlive it.
        if inDungeon and wasInside ~= true and P.EnterRun then P.EnterRun(selected) end
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
        compact = (focus or guide) and inDungeon and InCombatLockdown() and not browsing
        if compact and not wasCompact then
            detailPage = {first=first, history=history, key=selected.key}
        elseif wasCompact and not compact and detailPage then
            if not browsing and selected.key == detailPage.key then first, history = detailPage.first, detailPage.history end
            detailPage = nil
        end
        if focus and not browsing and inDungeon then
            local key = selected.key .. ":" .. focus.step .. ":" .. focus.state .. ":" .. tostring(C_QuestLog.IsComplete(focus.step))
            if not compact and key ~= lastTracked then
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
                        table.insert(detailRows, {section=L"Следующий босс", about=L"Босс, к которому идёт группа. Под ним зал, где ты стоишь, и путь к боссу по шагам. ПКМ отмечает босса убитым."})
                        heading.big = true
                        -- What is done beside him is not a line under his name: it is a
                        -- thing to do, and stands in white right after him.
                        local asks, lines = {}, {}
                        for _, line in ipairs(heading.asks or {}) do asks[line] = true end
                        for _, line in ipairs(heading.lines) do
                            if not asks[line] then lines[#lines+1] = line end
                        end
                        if room and not heading.inRoom then table.insert(lines, 1, L"ты здесь: «" .. room .. "»") end
                        -- The plan of the floor was closed by its cross: how to get it back.
                        if db.floorOff and heading.npc and P.HasPlan and P.HasPlan(heading.npc) then
                            lines[#lines+1] = DIM .. L"щелчок по боссу вернёт план этажа|r"
                        end
                        if P.LootFor and heading.npc then
                            local loot, mine, best, better = P.LootFor(heading.npc)
                            local weighed = false
                            for _, thing in ipairs(loot) do weighed = weighed or thing.worth.known end
                            local names = {}
                            if best > 0 then
                                -- The very good first, in gold: this boss is worth the fight.
                                for _, thing in ipairs(loot) do
                                    if thing.worth.best and #names < 2 then names[#names+1] = thing.name end
                                end
                                lines[#lines+1] = L"|cffffd34dлучшее в слот: " .. table.concat(names, ", ") .. (best > 2 and (L" и ещё " .. (best - 2)) or "") .. "|r"
                            elseif better > 0 then
                                for _, thing in ipairs(loot) do
                                    if thing.worth.known and thing.worth.gain > 0 and not thing.worth.worn and not thing.worth.later and #names < 2 then
                                        names[#names+1] = thing.name .. (" (+%.0f)"):format(thing.worth.gain)
                                    end
                                end
                                lines[#lines+1] = L"|cff40e040лучше надетого: " .. table.concat(names, ", ") .. (better > 2 and (L" и ещё " .. (better - 2)) or "") .. "|r"
                            elseif mine > 0 and not weighed then
                                for _, thing in ipairs(loot) do
                                    if thing.mine and #names < 2 then names[#names+1] = thing.name end
                                end
                                lines[#lines+1] = L"|cff40e040добыча для тебя: " .. table.concat(names, ", ") .. (mine > 2 and (L" и ещё " .. (mine - 2)) or "") .. "|r"
                            end
                        end
                        heading.lines = lines
                        table.insert(detailRows, heading)
                        if #(heading.todo or {}) > 0 then
                            table.insert(detailRows, {section=L"Не забудь у босса", about=L"То, что из твоих заданий делается рядом с этим боссом. Пройдёшь мимо — придётся возвращаться."})
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
                if #tasks[1] + #tasks[2] + #tasks[3] > 0 then
                    table.insert(detailRows, {section=next(beside) and (L"Другие задания") or (L"Задания"), about=L"Задания этого похода: что ещё надо взять внутри, что в журнале, что готово к сдаче."})
                    for _, list in ipairs(tasks) do
                        for _, row in ipairs(list) do
                            row.brief = true
                            table.insert(detailRows, row)
                        end
                    end
                end
                for _, row in ipairs(folded) do table.insert(detailRows, row) end
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
                        errands[#errands+1] = row
                        row.line = true
                        local list = row.working and work or row.handin and hand or take
                        list[#list+1] = row
                    end
                end
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
                if any and not errands[1] and #doing == 0 then
                    -- Nothing left outside: the one thing to do is go in, and the line
                    -- under the green one says through which door and how far it is.
                    table.insert(detailRows, {section=L"Сейчас", about=L"Снаружи делать больше нечего. Щелчок по строке ниже ставит стрелку ко входу."})
                    local option = P.DoorOption and P.DoorOption(selected)
                    local taken = inLog > 0 and (L"снаружи всё взято") or (L"снаружи брать нечего")
                    if option and option.point then
                        local metres = P.Distance and P.Distance(option.point)
                        local reach = P.Reach(option.point)
                        -- At the door the order is what to do with it; on the way, to walk to it.
                        local order = (metres and metres < 20 and option.near) or ((option.act or (L"Иди ко входу")) .. (reach and (" • " .. reach) or ""))
                        table.insert(detailRows, {status=order, good=true, door=true, note=taken, hint=option.point.hint})
                    else
                        table.insert(detailRows, {status=inLog > 0 and (L"Снаружи всё взято") or (L"Снаружи брать нечего"), good=true})
                    end
                end
                if #prep > 0 then
                    local inHand = 0
                    for _, row in ipairs(prep) do
                        if row.state == "active" then inHand = inHand + 1 end
                    end
                    if errands[1] then errands[1].lead = true end
                    -- In the look of the game's quests the count stands in the heading of the
                    -- section, as on the mock-up, and the list begins at once under it.
                    -- (Short: seen in the game cut off as "… • вз…" beside the three dots.)
                    headNote = inHand .. "/" .. #prep
                    if true then table.insert(detailRows, {section=L"Задания • взято " .. inHand .. L" из " .. #prep,
                        about=L"Все задания этого подземелья. Под названием — что с ним сделать и где. Сверху то, что делается снаружи, ближайшее первым. Щелчок ставит стрелку."}) end
                    for _, row in ipairs(prep) do table.insert(detailRows, row) end
                end
                -- Near the dungeon with nothing left to do outside, the next thing is the
                -- door, and the arrow leads to it unasked: the way into the place, then the
                -- portal; after a finished run, the way out. A ghost is led whatever is left.
                -- Once for each such moment: taken off by hand, the arrow stays off.
                local ghost = UnitIsGhost and UnitIsGhost("player") and true or false
                local clear = any and toTake == 0 and toDo == 0
                local moment = (ghost or clear) and (selected.key .. (ghost and ":ghost" or "")) or nil
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
            local before, inside = P.SecretPlan(selected)
            if #before + #inside > 0 then
                table.insert(detailRows, {routeCount=#before + #inside})
                if routeExpanded then
                    for _, row in ipairs(before) do table.insert(detailRows, row) end
                    for _, row in ipairs(inside) do table.insert(detailRows, row) end
                end
            end
        end
        -- The owner missed the line that opened the book: "it was handy, to open our journal
        -- and look at all the quests". It is back, and on top this time, where he looks
        -- first; not in a fight, where the page is two rows.
        -- On the pages that are tables of sections; a page led by one quest or one boss
        -- under way keeps that on top.
        -- (In the look of the game's quests the journal is a word in the row under the heading.)
        if not compact and not bossTarget and detailRows[1] and detailRows[1].section and not nativeLook() then
            table.insert(detailRows, 1, {book=true, plain=L"Открыть журнал: все задания и боссы"})
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
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS"}) do
    events:RegisterEvent(event)
end
for _, event in ipairs({"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "BOSS_KILL", "ENCOUNTER_END", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "LOOT_OPENED"}) do
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
    local npc, name = atlas.NpcIDFromGUID(atlas.PlainText(UnitGUID(unit))), UnitName and atlas.PlainText(UnitName(unit))
    if not npc and not name then return false end
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
    if event == "LOOT_OPENED" then
        -- A body being looted is a dead one: its number is on every thing in the window.
        local d = db and atlas.CurrentDungeon and atlas.CurrentDungeon()
        if d and P.Killed and GetNumLootItems and GetLootSourceInfo then
            local news = false
            pcall(function()
                for slot = 1, GetNumLootItems() do
                    local guid = GetLootSourceInfo(slot)
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
        return
    end
    if sightings[event] or event == "NAME_PLATE_UNIT_ADDED" then
        if db then
            P.SeenUnit(sightings[event] or id)
            if seenDead(sightings[event] or id) and not pending then P.Refresh() end
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
    C_Timer.After(.25, function()
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
    P.Refresh()
    if msg and msg:match("^%s*run%s*$") then
        if P.NewRun then P.NewRun() end
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
