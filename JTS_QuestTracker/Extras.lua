local _, ns = ...

--[[
    Optional extras for JTS Quest Tracker. Everything in here is switched by a setting
    and keeps working (or quietly does nothing) when the game lacks a function it would like to use.

    - objective complete alerts (chat line / sound / flash)
    - objective colors by progress
    - text outline and shadow
    - pinned quests
    - show / hide the tracker (/jtsqt toggle and the key binding)
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local QWH = LibStub("JTSQTQuestWatchHelper-1.0");

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value));
end

local function lerp(a, b, t)
    return a + (b - a) * t;
end

-- ---------------------------------------------------------------------------
-- Objective progress colors
-- ---------------------------------------------------------------------------

-- The actual colors come from ColorBlind.lua (normal: red, yellow, green).

-- 0 to 1: how far along an objective is.
function JQT:GetObjectiveProgress(objective)
    if objective.completed then
        return 1;
    end

    local required = tonumber(objective.required);
    local fulfilled = tonumber(objective.fulfilled);

    if required and required > 0 and fulfilled then
        return clamp(fulfilled / required, 0, 1);
    end

    return 0;
end

-- Normally red when you have just started, yellow half way, green when it's done.
function JQT:GetProgressColor(progress)
    progress = clamp(progress or 0, 0, 1);

    local start, middle, done = self:GetProgressStops();

    local from, to, t;
    if progress < 0.5 then
        from, to, t = start, middle, progress / 0.5;
    else
        from, to, t = middle, done, (progress - 0.5) / 0.5;
    end

    return {
        r = lerp(from.r, to.r, t),
        g = lerp(from.g, to.g, t),
        b = lerp(from.b, to.b, t)
    };
end

-- ---------------------------------------------------------------------------
-- Text style (outline / shadow)
-- ---------------------------------------------------------------------------

local OUTLINE_FLAGS = {
    None = "",
    Outline = "OUTLINE",
    Thick = "THICKOUTLINE"
};

function JQT:ApplyTextStyle()
    local outline = OUTLINE_FLAGS[self.db.profile.TextOutline] or "";
    local shadow = self.db.profile.TextShadow;

    if shadow ~= "Strong" and shadow ~= "Off" then
        shadow = "Default";
    end

    JTS_QuestTrackerFont.textStyle = {
        flags = outline,
        shadow = shadow,
        face = self.GetFontPath and self:GetFontPath() or nil,
        barHeight = self.db.profile.ProgressBarHeight
    };
end

-- ---------------------------------------------------------------------------
-- Pinned quests
-- ---------------------------------------------------------------------------

local PIN_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t ";

function JQT:IsPinned(questID)
    local pins = self.db and self.db.char.PINNED_QUESTS;

    return pins ~= nil and questID ~= nil and pins[questID] == true;
end

function JQT:GetPinIcon()
    return PIN_ICON;
end

function JQT:SetPinned(quest, pinned)
    if not quest or not quest.questID then return end

    self.db.char.PINNED_QUESTS[quest.questID] = pinned and true or nil;

    -- Pinned quests are always tracked, unpinned ones go back to the normal filters.
    local current = QLH:GetQuest(quest.questID);
    if current then
        self:UpdateQuestWatch(GetRealZoneText(), GetMinimapZoneText(), current);
    end

    self:RefreshView();
end

-- ---------------------------------------------------------------------------
-- Objective complete alerts
-- ---------------------------------------------------------------------------

local FLASH_SECONDS = 1.5;
local flashUntil = {};
local flashTimer;

function JQT:IsFlashing(questID)
    local untilTime = flashUntil[questID];

    return untilTime ~= nil and GetTime() < untilTime;
end

local function snapshotOf(quest)
    local snapshot = {
        completed = quest.completed and true or false,
        objectives = {}
    };

    for i, objective in ipairs(quest.objectives or {}) do
        snapshot.objectives[i] = objective.completed and true or false;
    end

    return snapshot;
end

-- Remember where every quest stands right now, so only *new* progress triggers an alert.
function JQT:SnapshotObjectives()
    self.objectiveState = {};

    for questID, quest in pairs(QLH:GetQuests() or {}) do
        self.objectiveState[questID] = snapshotOf(quest);
    end
end

local function startFlash(questID)
    flashUntil[questID] = GetTime() + FLASH_SECONDS;

    if flashTimer then
        flashTimer:Cancel();
    end

    -- One redraw after the flash is over puts the normal colors back.
    flashTimer = C_Timer.NewTimer(FLASH_SECONDS + 0.1, function()
        flashTimer = nil;

        if JQT.tracker then
            JQT:RefreshView();
        end
    end);
end

-- `events` is a list of { quest = <quest>, text = <what to say>, complete = <whole quest done> }.
function JQT:Alert(events)
    if #events == 0 then return end

    local settings = self.db.profile;

    if settings.AlertChat then
        for _, event in ipairs(events) do
            say("|cff4aa854" .. event.quest.title .. "|r: " .. event.text);
        end
    end

    if settings.AlertSound then
        local questComplete = false;

        for _, event in ipairs(events) do
            if event.complete then questComplete = true end
        end

        self:PlayAlertSound(questComplete);
    end

    if settings.AlertFlash then
        for _, event in ipairs(events) do
            startFlash(event.quest.questID);
        end
    end
end

-- Called with the quests that QuestLogHelper just reported as changed.
function JQT:CheckObjectiveAlerts(updates)
    self.objectiveState = self.objectiveState or {};

    local events = {};

    for questID, info in pairs(updates) do
        local quest = (not info.abandoned) and QLH:GetQuest(questID) or nil;

        if not quest then
            self.objectiveState[questID] = nil;
        else
            local previous = self.objectiveState[questID];
            local current = snapshotOf(quest);

            -- A quest we have not seen before only gets recorded, it can't have "new" progress.
            if previous and not info.accepted then
                if current.completed and not previous.completed then
                    events[#events + 1] = {
                        quest = quest,
                        text = "ready to turn in",
                        complete = true
                    };
                else
                    for i, done in ipairs(current.objectives) do
                        if done and not previous.objectives[i] and quest.objectives[i] then
                            events[#events + 1] = {
                                quest = quest,
                                text = quest.objectives[i].text,
                                complete = false
                            };
                        end
                    end
                end
            end

            self.objectiveState[questID] = current;
        end
    end

    self:Alert(events);
end

-- ---------------------------------------------------------------------------
-- Show / hide the tracker
-- ---------------------------------------------------------------------------

function JQT:SetTrackerHidden(hidden)
    hidden = hidden and true or false;

    self.db.char.TrackerHidden = hidden;

    if self.tracker then
        if hidden then
            self.tracker:Hide();
        else
            self.tracker:Show();
        end
    end
end

function JQT:IsTrackerHidden()
    return self.db ~= nil and self.db.char.TrackerHidden == true;
end

function JQT:ToggleTrackerVisibility()
    if not self.tracker then return end

    local hidden = not self:IsTrackerHidden();

    self:SetTrackerHidden(hidden);

    if hidden then
        say("Tracker hidden. Type /jtsqt toggle (or use your key binding) to show it again.");
    else
        say("Tracker shown.");
    end
end

-- Used by Bindings.xml
function JTS_QuestTracker_Toggle()
    JQT:ToggleTrackerVisibility();
end

BINDING_HEADER_JTS_QUESTTRACKER = "JTS Quest Tracker";
BINDING_NAME_JTS_QUESTTRACKER_TOGGLE = "Show / Hide Tracker";
