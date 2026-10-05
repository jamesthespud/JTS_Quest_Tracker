local Compat = LibStub("JTSQTCompat-1.0");
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local helper = LibStub:NewLibrary("JTSQTQuestWatchHelper-1.0", 3);
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

        applying = true;
        pcall(Compat.MirrorWatch, Compat, questID, watched);
        applying = false;
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
