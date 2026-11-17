local _, ns = ...

--[[
    Turned In Today (2.2, idea from Waltrapalo's fork; off by default).

    A foldable "Turned in today" section at the bottom of the tracker lists the quests you've handed
    in today, newest first, with the time. Kept per character and cleared at midnight.
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

local MAX_SHOWN = 15; -- older ones still count, they just aren't listed

local function today() return date("%Y-%m-%d") end

-- Today's list (a new day starts a new one).
local function entries()
    local saved = JQT.db.char.TurnedInToday;

    if type(saved) ~= "table" or saved.day ~= today() then
        saved = { day = today(), entries = {} };
        JQT.db.char.TurnedInToday = saved;
    end

    return saved.entries;
end

local function enabled()
    return JQT.db and JQT.db.profile.ShowTurnedInToday;
end

-- Redraw just after midnight so yesterday's list goes away.
local midnightTimer;
local function refreshAtMidnight()
    if midnightTimer or not C_Timer.NewTimer then return end

    local midnight = date("*t");
    midnight.day, midnight.hour, midnight.min, midnight.sec, midnight.isdst = midnight.day + 1, 0, 0, 0, nil;

    midnightTimer = C_Timer.NewTimer(math.max(1, time(midnight) - time() + 1), function()
        midnightTimer = nil;
        if JQT.tracker then JQT:RefreshView() end
    end);
end

function JQT:AddTurnedInToday()
    if not enabled() or self.db.char.CollapsedSections["QUESTS"] then return end

    local list = entries();
    if #list == 0 then return end

    refreshAtMidnight();

    local p = self.db.profile;
    local zone = self.TODAY_SECTION;
    local container = self:AddZone(zone, #list);

    -- Without zone headers nothing else orders the sections: put it last by hand.
    if not p.ZoneHeaderEnabled then
        local elements = self.questsContainer.elements;
        local header = elements[#elements - 1];
        if header then header:SetOrder(1e9) end
        container:SetOrder(1e9 + 1);
    end

    local color = p.ObjectiveFontColor;
    for i = #list, math.max(1, #list - MAX_SHOWN + 1), -1 do
        local entry = list[i];
        self.tracker:Font({
            container = container,
            label = date("%H:%M", entry.at) .. "  " .. tostring(entry.title),
            size = p.ObjectiveFontSize,
            color = color,
            alpha = 0.75,
            margin = { bottom = 2.5 }
        });
    end
end

-- Drawn after the quests.
local refreshView = JQT.RefreshView;
function JQT:RefreshView(...)
    local result = refreshView(self, ...);

    if enabled() then
        local ok, err = pcall(self.AddTurnedInToday, self);
        if not ok then self:LogError("Turned in today:", err) end
        self:Sort();
    end

    return result;
end

-- Remember the quest's name as it's handed in (it leaves the quest log right after).
local events = CreateFrame("Frame");
pcall(events.RegisterEvent, events, "QUEST_TURNED_IN");
events:SetScript("OnEvent", function(_, _, questID)
    if not JQT.db or type(questID) ~= "number" or questID <= 0 then return end

    local quest = QLH:GetQuest(questID);
    local title = quest and quest.title;
    if not title or title == "" then title = Compat:GetQuestTitle(questID) end

    local list = entries();
    list[#list + 1] = { title = (title and title ~= "") and title or ("Quest #" .. questID), at = time() };

    if enabled() and JQT.tracker then JQT:RefreshView() end
end);

-- Option (Appearance > Zone Headers)
JQT.turnedInTodayOptions = function()
    return {
        turnedInToday = {
            name = "Turned In Today", order = 9, width = 1.6,
            desc = "Adds a foldable section at the bottom of the tracker listing the quests you've handed in today, newest first, with the time. Cleared at midnight.",
            type = "toggle", arg = "ShowTurnedInToday",
            set = function(info, value) JQT.db.profile[info.arg] = value; JQT:RefreshView() end
        },
    };
end
