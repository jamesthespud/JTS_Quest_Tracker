local Compat = LibStub("JTSQTCompat-1.0");
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local AceEvent = LibStub("AceEvent-3.0");
local helper = LibStub:NewLibrary("JTSQTQuestWatchHelper-1.0", 5);
if not helper then return end

--[[
    JTS Quest Tracker keeps its *own* list of watched quests, so Blizzard's watch limit
    doesn't apply. We still mirror our list into Blizzard's (best effort), so the quest log's
    tracking checkmarks stay meaningful, and we listen for the player toggling tracking in the
    quest log so those clicks keep working as manual overrides.
]]

local tracked = {};    -- questID -> true / false. Quests we haven't decided about yet are absent.
local mirrored = {};   -- questID -> the last state we pushed into Blizzard's watch list.
local seed = {};       -- quests the player manually tracked last session, used until decided otherwise.
local applying = false; -- true while *we* call Blizzard's watch functions, so our hooks ignore it.

local listeners, pending, timer = {}, {}, nil;

local function notify(update)
    pending[update.questID] = update;

    if timer then timer:Cancel() end

    timer = C_Timer.NewTimer(0.1, function()
        local updates = pending;
        pending = {};

        for _, listener in ipairs(listeners) do
            listener(updates);
        end
    end);
end

function helper:OnQuestWatchUpdated(listener)
    table.insert(listeners, listener);
end

function helper:OffQuestWatchUpdated(listener)
    for i, existing in ipairs(listeners) do
        if existing == listener then
            table.remove(listeners, i);
            return;
        end
    end
end

-- ---------------------------------------------------------------------------
-- The watched set
-- ---------------------------------------------------------------------------

function helper:IsWatched(questID)
    local watched = tracked[questID];

    if watched == nil then
        return seed[questID] == true;
    end

    return watched;
end

-- Returns true when the watched state actually changed.
function helper:SetWatched(quest, watched)
    local questID = quest.questID;
    if not questID then return false end

    watched = watched and true or false;

    local previous = self:IsWatched(questID);
    tracked[questID] = watched;

    if mirrored[questID] ~= watched then
        mirrored[questID] = watched;

        -- Out of combat and with the world map closed only (see Compat:RunWhenMapSafe).
        Compat:RunWhenMapSafe("watch-" .. questID, function()
            if mirrored[questID] ~= watched then return end -- changed again meanwhile

            applying = true;
            pcall(Compat.MirrorWatch, Compat, questID, watched);
            applying = false;
        end);
    end

    if previous == watched then return false end

    notify({ index = quest.index, questID = questID, watched = watched, byUser = false });

    return true;
end

-- The *player* (not us) changed tracking through Blizzard's quest log.
local function onUserWatchChanged(questID, watched)
    if applying or not questID or not QLH:IsShown() then return end

    tracked[questID] = watched;
    mirrored[questID] = watched;

    notify({ index = QLH:GetIndexFromQuestID(questID), questID = questID, watched = watched, byUser = true });
end

-- WoW's own watch list stops at 25 (Constants.QuestWatchConsts.MAX_QUEST_WATCHES). When the player
-- clicks Track in the quest log and that list is full, Blizzard refuses before AddQuestWatch is ever
-- called, so we wouldn't hear about it. Ours has no limit: track the quest anyway.
local function isInBlizzardWatchList(questID)
    local api = C_QuestLog and C_QuestLog.GetQuestWatchType;
    if not api then return false end

    local ok, watchType = pcall(api, questID);

    return ok and watchType ~= nil;
end

local toldAboutLimit = false;

local function onQuestLogTrackClicked(questID)
    if not questID or not QLH:GetQuest(questID) then return end

    -- Blizzard added or removed it itself (onUserWatchChanged already heard about that).
    if isInBlizzardWatchList(questID) or helper:IsWatched(questID) then return end

    -- Blizzard only refuses when its list is full; after a removal it has room again.
    local count = C_QuestLog and C_QuestLog.GetNumQuestWatches and select(2, pcall(C_QuestLog.GetNumQuestWatches));
    local max = (type(Constants) == "table" and type(Constants.QuestWatchConsts) == "table" and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or 25;
    if type(count) ~= "number" or count < max then return end

    -- Refused because WoW's list is full: track it in ours instead.
    tracked[questID] = true;
    notify({ index = QLH:GetIndexFromQuestID(questID), questID = questID, watched = true, byUser = true });

    if not toldAboutLimit then
        toldAboutLimit = true;
        print("|cff33ff99JTS QT:|r WoW's own tracking list is full (25 quests), so it shows an error, but JTS Quest Tracker is tracking this quest anyway. You can track all 40.");
    end
end

local trackHooked = false;

local function hookQuestLogTrack()
    if trackHooked or type(QuestMapQuestOptions_TrackQuest) ~= "function" then return end
    trackHooked = true;

    hooksecurefunc("QuestMapQuestOptions_TrackQuest", onQuestLogTrackClicked);
end

local installed = false;

-- Starts managing the watched set, beginning with the quests the player tracked last session.
function helper:BypassWatchLimit(initialTrackedQuests)
    seed = {};
    for questID, isTracked in pairs(initialTrackedQuests or {}) do
        if isTracked == true then seed[questID] = true end
    end

    if installed then return end
    installed = true;

    if C_QuestLog then
        pcall(hooksecurefunc, C_QuestLog, "AddQuestWatch", function(questID) onUserWatchChanged(questID, true) end);
        pcall(hooksecurefunc, C_QuestLog, "RemoveQuestWatch", function(questID) onUserWatchChanged(questID, false) end);
    end

    -- The quest log's Track button (and shift-click), for when WoW's own list is full.
    pcall(hookQuestLogTrack);
    if not trackHooked then
        AceEvent.RegisterEvent(helper, "ADDON_LOADED", function() pcall(hookQuestLogTrack) end);
    end

    -- Forget quests that left the log.
    QLH:OnQuestUpdated(function(updates)
        for questID, quest in pairs(updates) do
            if quest.abandoned then
                local wasTracked = tracked[questID];

                tracked[questID], mirrored[questID], seed[questID] = nil, nil, nil;

                if wasTracked then
                    notify({ index = quest.index, questID = questID, watched = false, byUser = false });
                end
            end
        end
    end);
end

-- ---------------------------------------------------------------------------
-- Blizzard's own tracker
-- ---------------------------------------------------------------------------

local keepHidden, hooked = true, false;

function helper:KeepHidden()
    keepHidden = true;

    local frame = Compat:GetBlizzardTracker();
    if not frame then return end

    if not hooked and frame.HookScript then
        hooked = true;
        pcall(frame.HookScript, frame, "OnShow", function(shown)
            if keepHidden then shown:Hide() end
        end);
    end

    pcall(frame.Hide, frame);
end

-- Safety net: if JTS Quest Tracker can't start, the player gets their normal tracker back.
function helper:RestoreBlizzardTracker()
    keepHidden = false;

    local frame = Compat:GetBlizzardTracker();
    if frame then pcall(frame.Show, frame) end
end

-- Plug into the quest log helper so it knows what is being watched.
QLH:SetWatchProvider(function(questID)
    return helper:IsWatched(questID);
end);
