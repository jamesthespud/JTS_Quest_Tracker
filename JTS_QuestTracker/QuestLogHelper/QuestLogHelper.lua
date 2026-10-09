local AceEvent = LibStub:GetLibrary("AceEvent-3.0");
local Compat = LibStub("JTSQTCompat-1.0");
local helper = LibStub:NewLibrary("JTSQTQuestLogHelper-1.0", 3);
if not helper then return end
-- /dump LibStub("JTSQTQuestLogHelper-1.0"):GetQuests();

--[[
    Keeps a cache of the player's quests (refreshed on QUEST_LOG_UPDATE) and tells listeners
    which quests were accepted, progressed or left the log.
]]

local class = UnitClass("player");
local PROFESSIONS = {};
for _, name in ipairs({ "Herbalism", "Mining", "Skinning", "Alchemy", "Blacksmithing", "Enchanting",
    "Engineering", "Leatherworking", "Tailoring", "Cooking", "Fishing", "First Aid" }) do
    PROFESSIONS[name] = true;
end

local quests;              -- questID -> quest, nil until the first refresh
local indexToQuestID = {};

-- ---------------------------------------------------------------------------
-- Listeners (batched, so a burst of updates arrives as one call)
-- ---------------------------------------------------------------------------

local listeners, pending, timer = {}, {}, nil;

local function notify(questID, info)
    pending[questID] = info;

    if timer then timer:Cancel() end

    timer = C_Timer.NewTimer(0.1, function()
        local updates = pending;
        pending = {};

        for _, listener in ipairs(listeners) do
            listener(updates);
        end
    end);
end

function helper:OnQuestUpdated(listener)
    table.insert(listeners, listener);
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function grayLevel(level)
    if level <= 5 then return 0 end
    if level <= 39 then return level - math.floor(level / 10) - 5 end

    return level - math.floor(level / 5) - 1;
end

-- 0 = too easy (grey) ... 4 = very hard (red), like the quest log colors.
function helper:GetDifficulty(level)
    local playerLevel = UnitLevel("player");

    if level > playerLevel + 4 then return 4 end
    if level > playerLevel + 2 then return 3 end
    if level >= playerLevel - 2 then return 2 end
    if level > grayLevel(playerLevel) then return 1 end

    return 0;
end

local function getObjectives(questID)
    local objectives = {};

    for _, objective in ipairs(Compat:GetQuestObjectives(questID)) do
        -- Some quests return blank objectives.
        if objective.text and objective.text:match("%S") then
            objectives[#objectives + 1] = {
                text = objective.text,
                type = objective.type,
                completed = objective.finished,
                fulfilled = objective.numFulfilled,
                required = objective.numRequired
            };
        end
    end

    return objectives;
end

local function completionPercent(objectives)
    if #objectives == 0 then return 0 end

    local total = 0;

    for _, objective in ipairs(objectives) do
        if objective.completed then
            total = total + 1;
        elseif objective.fulfilled and objective.required and objective.required > 0 then
            total = total + math.min(objective.fulfilled / objective.required, 1);
        end
    end

    return total / #objectives;
end

-- ---------------------------------------------------------------------------
-- Refreshing the cache
-- ---------------------------------------------------------------------------

local function doRefresh(self)
    local initialized = quests ~= nil;
    quests = quests or {};

    if not Compat:CanReadQuestLog() then return end

    local entries = Compat:GetQuestLogEntries();

    local present = {};
    for _, entry in ipairs(entries) do
        if not entry.isHeader and entry.questID then
            present[entry.questID] = true;
        end
    end

    -- Anything we knew about that is no longer in the log has been turned in or abandoned.
    for questID, quest in pairs(quests) do
        if not present[questID] then
            local onQuest = Compat:IsOnQuest(questID);
            local gone = (onQuest == nil) and #entries > 0 or (onQuest == false);

            if gone then
                quests[questID] = nil;
                indexToQuestID[quest.index] = nil;

                notify(questID, {
                    index = quest.index,
                    questID = questID,
                    lastUpdated = quest.lastUpdated,
                    previousCompletionPercent = quest.completionPercent,
                    completionPercent = quest.completionPercent,
                    abandoned = true
                });
            end
        end
    end

    local zone;
    for _, entry in ipairs(entries) do
        local questID = entry.questID;

        if entry.isHeader then
            zone = entry.title;
        elseif questID and questID ~= 0 then
            local accepted = initialized and quests[questID] == nil;

            quests[questID] = quests[questID] or { questID = questID, index = entry.index, summaryTries = 0 };
            local quest = quests[questID];

            quest.title = entry.title;
            quest.level = entry.level;
            quest.zone = zone;
            quest.isClassQuest = zone == class;
            quest.isProfessionQuest = PROFESSIONS[zone] == true;

            -- Quests without objectives show their summary instead. It isn't always loaded yet.
            if quest.summary == nil and quest.summaryTries < 3 then
                quest.summaryTries = quest.summaryTries + 1;
                quest.summary = Compat:GetQuestSummary(questID);
            end

            if indexToQuestID[quest.index] == questID then
                indexToQuestID[quest.index] = nil;
            end
            indexToQuestID[entry.index] = questID;

            quest.index = entry.index;
            quest.completed = entry.completed;
            quest.failed = entry.failed;
            quest.difficulty = self:GetDifficulty(entry.level);
            quest.objectives = getObjectives(questID);

            local percent = completionPercent(quest.objectives);
            local updated = quest.completionPercent ~= nil and quest.completionPercent ~= percent;

            if updated or accepted then
                quest.lastUpdated = time();

                notify(questID, {
                    index = quest.index,
                    questID = questID,
                    lastUpdated = quest.lastUpdated,
                    previousCompletionPercent = quest.completionPercent,
                    completionPercent = percent,
                    accepted = accepted,
                    updated = updated
                });
            end

            quest.completionPercent = percent;
        end
    end
end

local refreshing, refreshQueued = false, false;

function helper:Refresh()
    -- Reading quest details can fire QUEST_LOG_UPDATE again; don't recurse.
    if refreshing then
        refreshQueued = true;
        return quests;
    end

    refreshing = true;
    local ok, err = pcall(doRefresh, self);
    refreshing = false;

    if not ok then
        -- Report it like any other addon error but keep the event handler alive.
        geterrorhandler()(err);
    end

    if refreshQueued then
        refreshQueued = false;
        C_Timer.After(0, function() helper:Refresh() end);
    end

    return quests;
end

-- ---------------------------------------------------------------------------
-- Reading the cache
-- ---------------------------------------------------------------------------

function helper:AreQuestsLoaded()
    return quests ~= nil;
end

function helper:GetQuests()
    if not quests then self:Refresh() end

    return quests or {};
end

function helper:GetQuest(questID)
    return self:GetQuests()[questID];
end

function helper:GetQuestCount()
    local n = 0;
    for _ in pairs(self:GetQuests()) do n = n + 1 end

    return n;
end

function helper:GetIndexFromQuestID(questID)
    local quest = self:GetQuest(questID);

    return quest and quest.index;
end

-- Restores "last updated" times saved from an earlier session (and forgets quests no longer in the log).
function helper:SetQuestsLastUpdated(saved)
    if not saved then return end

    local current = self:GetQuests();

    for questID, lastUpdated in pairs(saved) do
        if current[questID] then
            current[questID].lastUpdated = lastUpdated;
        else
            saved[questID] = nil;
        end
    end

    return saved;
end

-- The set of watched quests is owned by QuestWatchHelper, which plugs itself in here.
local watchProvider;

function helper:SetWatchProvider(provider)
    watchProvider = provider;
end

function helper:GetWatchedQuests()
    local watched = {};

    for questID, quest in pairs(self:GetQuests()) do
        if watchProvider and watchProvider(questID, quest) then
            watched[questID] = quest;
        end
    end

    return watched;
end

-- ---------------------------------------------------------------------------
-- The quest log window (on WoW Forever it lives inside the world map)
-- ---------------------------------------------------------------------------

function helper:IsShown()
    return WorldMapFrame ~= nil and WorldMapFrame:IsShown();
end

-- Opens the quest log on the given quest, or closes it if that quest is already showing.
function helper:ToggleQuest(questID)
    if not questID or not WorldMapFrame then return false end

    local selected = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest();

    if self:IsShown() and selected == questID then
        HideUIPanel(WorldMapFrame);
    elseif type(QuestMapFrame_OpenToQuestDetails) == "function" then
        pcall(QuestMapFrame_OpenToQuestDetails, questID);
    end

    return true;
end

-- The game often fires QUEST_LOG_UPDATE several times in a row (4 times for a single kill, and often
-- when nothing quest related changed at all). Read the log once, on the next frame, for the whole burst.
local refreshScheduled = false;

AceEvent.RegisterEvent(helper, "QUEST_LOG_UPDATE", function()
    if refreshScheduled then return end
    refreshScheduled = true;

    C_Timer.After(0, function()
        refreshScheduled = false;
        helper:Refresh();
    end);
end);
