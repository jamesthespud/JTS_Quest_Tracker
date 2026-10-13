local _, ns = ...

--[[
    New-to-Forever marker.

    Quests that are new in WoW Forever (not in the original game) get a small blue infinity symbol in
    front of their name, and a line in their tooltip.

    The game has no flag for this. Forever's new quests have quest IDs from about 86,000 up (the
    datamined Forever quest list runs from about 86,000 to 99,234), while the original quests are all
    far below that, under about 10,000. So a quest counts as new when its ID is at least
    FIRST_FOREVER_QUEST_ID. Original quests that Forever only changed keep their old IDs and are not
    marked.
]]

local JQT = JTS_QuestTracker;

local FIRST_FOREVER_QUEST_ID = 86000;
local ICON = "|TInterface\\AddOns\\JTS_QuestTracker\\Textures\\Infinity:0|t ";
local BLUE = { r = 0.25, g = 0.67, b = 1 };

function JQT:IsNewToForever(quest)
    if not quest then return false end
    if quest.sampleForever then return true end -- the preview quests

    local id = tonumber(quest.questID);

    return id ~= nil and id >= FIRST_FOREVER_QUEST_ID;
end

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);

    if self.db and self.db.profile.ShowForeverMarker ~= false and self:IsNewToForever(quest) then
        header = ICON .. header;
    end

    return header;
end

-- Tooltip: say what the symbol means.
JQT.tooltipExtras = JQT.tooltipExtras or {};
table.insert(JQT.tooltipExtras, 1, function(self, quest, tooltip)
    if self.db.profile.ShowForeverMarker ~= false and self:IsNewToForever(quest) then
        tooltip:AddLine(" ");
        tooltip:AddLine(ICON .. "New in WoW Forever", BLUE.r, BLUE.g, BLUE.b);
    end
end);

-- ---------------------------------------------------------------------------
-- Option (Appearance > Quest Names)
-- ---------------------------------------------------------------------------

JQT.foreverMarkerOptions = function()
    return {
        foreverMarker = {
            name = "Mark New Forever Quests", order = 3, width = 1.4,
            desc = "Puts a blue " .. ICON .. "in front of quests that are new in WoW Forever (not in the original game), so you can spot the new content.",
            type = "toggle", arg = "ShowForeverMarker",
            set = function(info, value)
                JQT.db.profile[info.arg] = value;
                JQT:RefreshView();
            end
        },
    };
end
