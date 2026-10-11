local _, ns = ...

--[[
    How far away each quest is, from WoW Forever's own quest helper (the same distance its on-screen
    arrow shows), so it works without Questie. Questie is still used for quests the game has no
    location for.

      - Sort by Quest Proximity uses it (see LibQuestHelpers)
      - optional distance after each quest name:  [12] Wolves Across the Border  120 yd
        updated in place every couple of seconds while you move
]]

local JQT = JTS_QuestTracker;
local QH = LibStub("JTSQTQuestHelpers-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

local UPDATE_EVERY = 2; -- seconds

local distances = {}; -- questID -> yards, from the last update

local function lookUp(quest)
    if quest.sampleDistance then return quest.sampleDistance end -- the preview quests

    return QH:GetDistanceToClosestObjective(quest.questID);
end

-- 7 yd -> "5 yd", 123 yd -> "120 yd", 2345 yd -> "2350 yd"
function JQT:FormatDistance(yards)
    local ok, text = pcall(function()
        if yards < 0 then return nil end

        local step = (yards < 100 and 5) or (yards < 1000 and 10) or 50;

        return string.format("%d yd", math.floor(yards / step + 0.5) * step);
    end);

    return ok and text or nil;
end

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);

    if self.db and self.db.profile.ShowQuestDistance and quest and quest.questID then
        local yards = distances[quest.questID];

        if yards == nil then
            yards = lookUp(quest) or false;
            distances[quest.questID] = yards;
        end

        local text = yards and self:FormatDistance(yards);

        if text then
            header = header .. "  |cff9d9d9d" .. text .. "|r";
        end
    end

    return header;
end

-- Re-reads the distances and changes the quest names in place. A name that now needs another
-- line (rare) redraws the whole tracker instead.
local lastPosition;

function JQT:UpdateQuestDistances(force)
    if not self.db or not self.db.profile.ShowQuestDistance or not self.tracker or not self.tracker:IsVisible() then return end

    local position = Compat:GetPlayerWorldPosition();

    if not force and position and lastPosition
        and (position.x - lastPosition.x) ^ 2 + (position.y - lastPosition.y) ^ 2 < 1 then
        return; -- hasn't moved
    end
    lastPosition = position;

    distances = {};

    local redraw = false;

    for _, container in ipairs(self.questContainers or {}) do
        local font = container.headerFont;
        local quest = container.metadata and container.metadata.quest;

        if font and quest and font:IsVisible() then
            local text = self:GetQuestHeader(quest);

            if font.font:GetText() ~= text then
                local before = font:GetRealHeight();
                font:SetLabel(text);

                if font:GetRealHeight() ~= before then redraw = true end
            end
        end
    end

    if redraw then self:RefreshView() end
end

local ticker;

function JQT:UpdateDistanceTicker()
    local wanted = self.db and self.db.profile.ShowQuestDistance;

    if wanted and not ticker then
        ticker = C_Timer.NewTicker(UPDATE_EVERY, function() JQT:UpdateQuestDistances() end);
    elseif not wanted and ticker then
        ticker:Cancel();
        ticker = nil;
    end
end

-- Fresh distances on every redraw (a quest may have moved on to its next objective).
local refreshView = JQT.RefreshView;

function JQT:RefreshView(...)
    distances = {};

    return refreshView(self, ...);
end

hooksecurefunc(JQT, "Initialize", function(self) self:UpdateDistanceTicker() end);
JQT:OnSettingsApplied(function(self) self:UpdateDistanceTicker() end);

-- ---------------------------------------------------------------------------
-- Option (Appearance > Quest Names)
-- ---------------------------------------------------------------------------

JQT.distanceOptions = function()
    return {
        name = "Show Distance",
        desc = "Shows how far away each quest is after its name, like  |cff9d9d9d120 yd|r. It comes from WoW's own quest helper, so Questie isn't needed. Questie (if you use it) fills in quests the game has no location for.\n\nQuests in another zone or continent may show no distance.",
        type = "toggle", arg = "ShowQuestDistance", width = 1.4,
        set = function(info, value)
            JQT.db.profile[info.arg] = value;
            JQT:UpdateDistanceTicker();
            JQT:RefreshView();
        end
    };
end
