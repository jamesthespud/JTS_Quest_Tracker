local _, ns = ...

--[[
    Timed quests (escorts and the like): a "Time left: 4:32" line under the quest name that counts
    down every second. Uses the same game function as Blizzard's own tracker (C_QuestLog.GetTimeAllowed).
    The line is updated in place, so the tracker isn't redrawn every second.
]]

local JQT = JTS_QuestTracker;

local rows = {};   -- { font = <row>, endsAt = <GetTime() when it runs out> } for the rows on screen
local ticker;
local LOW_TIME = 60; -- seconds: the line changes color from here on

-- Seconds left on a timed quest, or nil when it isn't timed (or the timer has run out).
local function readTimeLeft(questID)
    local api = C_QuestLog and C_QuestLog.GetTimeAllowed;
    if not api then return nil end

    -- pcall around the comparison too: some Forever values can't be compared.
    local ok, left = pcall(function()
        local total, elapsed = api(questID);

        if total and elapsed and total > 0 and elapsed < total then
            return total - elapsed;
        end
    end);

    return ok and left or nil;
end

function JQT:GetQuestTimeLeft(quest)
    if quest.sampleTimeLeft then return quest.sampleTimeLeft end -- the preview quests

    return quest.questID and readTimeLeft(quest.questID);
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5));

    local hours, minutes, secs = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60;

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs);
    end

    return string.format("%d:%02d", minutes, secs);
end

local function label(left)
    return " - Time left: " .. formatTime(left);
end

local function colorFor(left)
    if left <= LOW_TIME then
        return JQT:GetDifficultyColor(4); -- red, or the Color Blind Mode equivalent
    end

    return JQT.db.profile.ObjectiveFontColor;
end

local function tick()
    local now, redraw = GetTime(), false;

    for _, row in ipairs(rows) do
        local left = row.endsAt - now;

        if left <= 0 then
            redraw = true; -- the quest has most likely failed; show its real state
        else
            local text = label(left);

            if text ~= row.text then
                row.text = text;
                row.font:SetLabel(text);

                local low = left <= LOW_TIME;
                if low ~= row.low then
                    row.low = low;
                    row.font:SetColor(colorFor(left));
                end
            end
        end
    end

    if redraw then
        JQT:RefreshView();
    elseif #rows == 0 and ticker then
        ticker:Cancel();
        ticker = nil;
    end
end

-- Called by AddQuest, right after the quest name.
function JQT:AddQuestTimer(quest, container)
    local p = self.db.profile;
    if not p.ShowQuestTimers or quest.completed or quest.failed then return end

    local left = self:GetQuestTimeLeft(quest);
    if not left then return end

    local font = self.tracker:Font({
        label = label(left),
        size = p.ObjectiveFontSize,
        color = colorFor(left),
        container = container,
        margin = { bottom = 2.5 }
    });

    rows[#rows + 1] = { font = font, endsAt = GetTime() + left, text = label(left), low = left <= LOW_TIME };

    if not ticker then
        ticker = C_Timer.NewTicker(1, tick);
    end
end

-- Every redraw rebuilds the rows, so forget the old ones first.
local refreshView = JQT.RefreshView;

function JQT:RefreshView(...)
    rows = {};

    return refreshView(self, ...);
end

-- ---------------------------------------------------------------------------
-- Option (Appearance > Objectives)
-- ---------------------------------------------------------------------------

JQT.timerOptions = function()
    return {
        name = "Show Quest Timers",
        desc = "Timed quests, such as some escorts, show how long you have left under the quest name, counting down every second. It turns red in the last minute.",
        type = "toggle", arg = "ShowQuestTimers", width = 1.4,
        set = function(info, value)
            JQT.db.profile[info.arg] = value;
            JQT:RefreshView();
        end
    };
end
