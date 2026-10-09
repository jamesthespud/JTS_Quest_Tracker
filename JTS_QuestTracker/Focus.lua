local _, ns = ...

--[[
    Quest focus for JTS Quest Tracker.

    WoW Forever's built-in quest helper (the on-screen arrow with distance, the map waypoint and
    the highlighted objective area) follows one "focused" quest, which Blizzard calls super-tracking.
    Blizzard's own tracker lets you pick it from its right-click menu; we hide that tracker, so this
    file gives ours the same:

      - "Focus Quest" / "Stop Focusing" in the right-click menu
      - middle-click a quest to focus it (or stop focusing it)
      - a marker in front of the focused quest's name
      - optional Auto-focus: the quest you just accepted or made progress on becomes the focus
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");

-- The same icon Forever's own navigation arrow uses, so it always exists in the game.
local FOCUS_ICON = "|A:Navigation-Tracked-Icon:13:13|a ";

local function superTrack()
    return C_SuperTrack;
end

function JQT:GetFocusedQuestID()
    local api = superTrack();
    if not api or not api.GetSuperTrackedQuestID then return nil end

    local ok, questID = pcall(api.GetSuperTrackedQuestID);

    return ok and questID and questID ~= 0 and questID or nil;
end

function JQT:IsFocused(questID)
    return questID ~= nil and questID == self:GetFocusedQuestID();
end

-- questID 0 or nil stops focusing.
function JQT:SetFocusedQuest(questID)
    local api = superTrack();
    if not api or not api.SetSuperTrackedQuestID then return end

    pcall(api.SetSuperTrackedQuestID, questID or 0);
end

function JQT:ToggleFocus(quest)
    if not quest or not quest.questID then return end

    self:SetFocusedQuest(self:IsFocused(quest.questID) and 0 or quest.questID);
end

-- Menu labels: Blizzard's own (translated) text, so it reads like their tracker.
function JQT:GetFocusMenuLabel(questID)
    if self:IsFocused(questID) then
        return STOP_SUPER_TRACK_QUEST or "Stop Focusing";
    end

    return SUPER_TRACK_QUEST or "Focus Quest";
end

-- ---------------------------------------------------------------------------
-- Marker in front of the focused quest's name
-- ---------------------------------------------------------------------------

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);

    if self.db and self.db.profile.ShowFocusMarker and quest and self:IsFocused(quest.questID) then
        header = FOCUS_ICON .. header;
    end

    return header;
end

-- ---------------------------------------------------------------------------
-- Keeping it up to date
-- ---------------------------------------------------------------------------

local events = CreateFrame("Frame");

-- The focus can also change from the quest map or Blizzard's own UI.
pcall(events.RegisterEvent, events, "SUPER_TRACKING_CHANGED");

events:SetScript("OnEvent", function()
    if JQT.tracker and JQT.db and JQT.db.profile.ShowFocusMarker then
        JQT:RefreshView();
    end
end);

-- Auto-focus: the quest you just accepted or made progress on (the latest one, if several).
QLH:OnQuestUpdated(function(updates)
    if not JQT.db or not JQT.db.profile.AutoFocusQuest then return end

    local latest, latestTime;

    for questID, update in pairs(updates) do
        if not update.abandoned and (update.accepted or update.updated) and QLH:GetQuest(questID) then
            local when = update.lastUpdated or 0;

            if not latest or when >= latestTime then
                latest, latestTime = questID, when;
            end
        end
    end

    if latest and not JQT:IsFocused(latest) then
        JQT:SetFocusedQuest(latest);
    end
end);

-- ---------------------------------------------------------------------------
-- Options (in Filters & Sorting)
-- ---------------------------------------------------------------------------

JQT.focusOptions = function()
    return {
        name = "Quest Focus (map arrow)",
        type = "group",
        inline = true,
        order = 3,

        args = {
            desc = {
                name = "The focused quest is the one WoW's built-in quest helper points you to: the arrow with distance on your screen, its map waypoint and its highlighted area. Focus a quest from its right-click menu or by middle-clicking it.",
                type = "description",
                fontSize = "medium",
                order = 1
            },

            showMarker = {
                name = "Mark the Focused Quest",
                desc = "Shows the navigation icon in front of the focused quest's name.",
                type = "toggle",
                width = 1.6,
                order = 2,

                get = function() return JQT.db.profile.ShowFocusMarker end,
                set = function(_, value)
                    JQT.db.profile.ShowFocusMarker = value;
                    JQT:RefreshView();
                end
            },

            autoFocus = {
                name = "Auto-focus",
                desc = "Focuses the quest you just accepted or made progress on, so the arrow follows what you are doing.",
                type = "toggle",
                width = 1.2,
                order = 3,

                get = function() return JQT.db.profile.AutoFocusQuest end,
                set = function(_, value) JQT.db.profile.AutoFocusQuest = value end
            },
        }
    };
end
