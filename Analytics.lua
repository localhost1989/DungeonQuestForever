local _, P = ...

-- Wago App supplies the optional provider for players participating in analytics.
-- Only the fixed action keys below can reach the provider: no names, no text, no places.
-- What it answers: which parts of the addon people use, and which nobody touches
-- (a key whose Reached_ switch stays off on the dashboard).
local actionIDs = {
    Loaded = 1,
    BookOpened = 2,
    DungeonChosen = 3,
    QuestRead = 4,
    BossRead = 5,
    RouteRequested = 6,
    ReportOpened = 7,
    LootOpened = 8,
    GearOpened = 9,
    -- 3.51.0: every button and setting.
    ArrowRemoved = 10,
    TeleportUsed = 11,
    FlightPointClicked = 12,
    StepClicked = 13,
    SharedWithGroup = 14,
    AutoAccepted = 15,
    AutoTurnedIn = 16,
    JunkRemoved = 17,
    FloorPlanOpened = 18,
    FloorPlanToggled = 19,
    DungeonHidden = 20,
    DoorPicked = 21,
    SettingsMenuOpened = 22,
    DungeonMenuOpened = 23,
    WelcomeShown = 24,
    Command = 25,
    PanelCollapsed = 26,
    NewRun = 27,
    EnteredDungeon = 28,
    BossKilled = 29,
    ToldGroup = 30,
    MetAddonUser = 31,
    RewardClicked = 32,
    BookModeSwitched = 33,
    ToldBis = 34,
}
-- The words of /dq (and of the settings menu, which goes through them) that are counted.
local commands = {
    run=true, book=true, gear=true, size=true, place=true, welcome=true, auto=true, junk=true,
    dock=true, cards=true, back=true, ping=true, glow=true, share=true, paths=true, sign=true,
    minimap=true, bug=true, full=true, where=true, list=true, done=true, bis=true, test=true,
}
-- Settings read once a session: a switch is on when the player turned that part off.
local settings = {
    noAuto="Off_AutoQuests", boardFree="Off_Docked", boardCards="Off_GameLook", noPing="Off_RoomPing",
    noGlow="Off_Glow", noShare="Off_TellGroup", noQuestDone="Off_QuestDone", noBis="Off_Bis", noPaths="Off_Paths", noSign="Off_Sign",
    minimapHidden="Off_Minimap", arrowOff="Off_Arrow", planOff="Off_FloorPlan", boardBack="On_DarkBack",
}
local steps = {"BookOpened", "QuestRead", "RouteRequested"}
local provider, seen, stage = nil, {}, 1
if WagoAnalytics and type(WagoAnalytics.Register) == "function" then
    local ok, api = pcall(WagoAnalytics.Register, WagoAnalytics, "mNwwe5No", {reportErrors=false})
    if ok then provider = api end
end

function P.Track(action, word)
    if not provider or not actionIDs[action] then return end
    local ok = pcall(function()
        if not seen[action] then
            provider:Switch("Reached_" .. action, true)
            seen[action] = true
        end
        provider:IncrementCounter("Count_" .. action)
        provider:SetCounter("LastAction", actionIDs[action])
        if action == "Command" then
            word = type(word) == "string" and word:match("^%s*(%a+)") or "list"
            word = word:lower()
            if commands[word] then provider:IncrementCounter("Cmd_" .. word) end
        end
        if steps[stage] == action then
            provider:Switch("Flow_" .. stage .. "_" .. action, true)
            stage = stage + 1
        end
    end)
    if not ok then provider = nil end
end

-- Once a session, after the character's settings are read.
function P.TrackSettings(db)
    if not provider or type(db) ~= "table" then return end
    local ok = pcall(function()
        for key, name in pairs(settings) do
            local on = db[key]
            if key == "boardBack" then on = on == true end
            provider:Switch(name, on and true or false)
        end
    end)
    if not ok then provider = nil end
end

P.Track("Loaded")
