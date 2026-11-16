local _, P = ...

-- Wago App supplies the optional provider for players participating in analytics.
-- Only the fixed action keys below can reach the provider.
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
}
local steps = {"BookOpened", "QuestRead", "RouteRequested"}
local provider, seen, stage = nil, {}, 1
if WagoAnalytics and type(WagoAnalytics.Register) == "function" then
    local ok, api = pcall(WagoAnalytics.Register, WagoAnalytics, "mNwwe5No", {reportErrors=false})
    if ok then provider = api end
end

function P.Track(action)
    if not provider or not actionIDs[action] then return end
    local ok = pcall(function()
        if not seen[action] then
            provider:Switch("Reached_" .. action, true)
            seen[action] = true
        end
        provider:IncrementCounter("Count_" .. action)
        provider:SetCounter("LastAction", actionIDs[action])
        if steps[stage] == action then
            provider:Switch("Flow_" .. stage .. "_" .. action, true)
            stage = stage + 1
        end
    end)
    if not ok then provider = nil end
end
P.Track("Loaded")
