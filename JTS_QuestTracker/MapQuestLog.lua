local _, ns = ...

--[[
    Hide the Map's Quest Log (2.0.5, on by default).

    With JTS Quest Tracker running, the zones in the world map's quest log won't fold. Until that is
    solved, the map opens without its quest log panel; the arrow at the bottom of the map still opens
    it whenever you want it, and the tracker does the quest log's everyday job.

    How: the map decides whether to show the panel from the game setting "questLogOpen" each time it
    opens (Blizzard's QuestLogOwnerMixin). We set that to 0 when you log in and whenever the map
    closes, and leave Blizzard's map frames alone. Turning the option off sets it back to 1.
]]

local JQT = JTS_QuestTracker;

local CVAR = "questLogOpen";
local waitingForCombat = false;

local function enabled()
    return JQT.db and JQT.db.profile.HideMapQuestLog ~= false;
end

local function setPanel(open)
    if InCombatLockdown and InCombatLockdown() then
        waitingForCombat = true;
        return;
    end

    local want = open and "1" or "0";
    local ok, current = pcall(GetCVar, CVAR);
    if ok and current ~= nil and tostring(current) ~= want then
        pcall(SetCVar, CVAR, want);
    end
end

-- Called at login and every time the map closes.
function JQT:ApplyMapQuestLog()
    if enabled() then setPanel(false) end
end

hooksecurefunc(JQT, "Initialize", function(self) self:ApplyMapQuestLog() end);

local events = CreateFrame("Frame");
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED");
events:SetScript("OnEvent", function()
    if waitingForCombat then
        waitingForCombat = false;
        JQT:ApplyMapQuestLog();
    end
end);

-- ---------------------------------------------------------------------------
-- Option (Frame Settings > Visibility)
-- ---------------------------------------------------------------------------

JQT.mapQuestLogOptions = function()
    return {
        hideMapQuestLog = {
            name = "Hide the Map's Quest Log", order = 6.7, width = 1.6,
            desc = "Opens the world map without its quest log panel. The arrow at the bottom of the map still opens it when you want it.\n\nOn by default for now: while JTS Quest Tracker runs, the zones in the map's quest log won't fold, so the tracker does that job instead.",
            type = "toggle",
            get = function() return enabled() end,
            set = function(_, value)
                JQT.db.profile.HideMapQuestLog = value;
                setPanel(not value);
            end
        },
    };
end
