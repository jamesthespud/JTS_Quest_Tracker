local _, ns = ...

--[[
    Quest tags for JTS Quest Tracker: Elite, Group (with suggested size), Dungeon, Raid, PvP,
    Heroic and Legendary, shown after the quest name.

        Short:  Kill the Ogre [E]     Defias Brotherhood [D]     Hogger [G3]
        Full:   Kill the Ogre (Elite) Defias Brotherhood (Dungeon) Hogger (Group 3)
]]

local JQT = JTS_QuestTracker;
local Compat = LibStub("JTSQTCompat-1.0");

local SHORT = {
    elite = "E",
    group = "G",
    dungeon = "D",
    raid = "R",
    pvp = "PvP",
    heroic = "H",
    legendary = "L"
};

local FULL = {
    elite = "Elite",
    group = "Group",
    dungeon = "Dungeon",
    raid = "Raid",
    pvp = "PvP",
    heroic = "Heroic",
    legendary = "Legendary"
};

-- A quest's tag never changes, so remember it. "No tag" is only trusted for a little while,
-- because the game sometimes hasn't loaded a quest's details yet.
local cache = {};
local NO_TAG_RETRY = 10;

function JQT:GetQuestTag(quest)
    if not quest or not quest.questID then return nil end

    local entry = cache[quest.questID];

    if entry and (entry.tag or GetTime() < entry.retryAt) then
        return entry.tag;
    end

    local tag = Compat:GetQuestTag(quest.questID, quest.index);

    cache[quest.questID] = {
        tag = tag,
        retryAt = GetTime() + NO_TAG_RETRY
    };

    return tag;
end

function JQT:FormatQuestTag(tag, style)
    if not tag or style == "Off" then return "" end

    local names = style == "Full" and FULL or SHORT;
    local text = names[tag.kind];

    if not text then
        -- A tag type we don't know: use the game's own word for it.
        if not tag.name then return "" end
        text = tag.name;
    end

    if tag.kind == "group" and tag.group then
        text = text .. (style == "Full" and " " or "") .. tag.group;
    elseif tag.kind == "elite" and tag.group and tag.group > 1 then
        text = text .. (style == "Full" and ", Group " or " G") .. tag.group;
    end

    if style == "Full" then
        return " (" .. text .. ")";
    end

    return " [" .. text .. "]";
end

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);
    local style = self.db and self.db.profile.QuestTagStyle or "Off";

    if style ~= "Off" then
        local ok, tag = pcall(self.GetQuestTag, self, quest);

        if ok and tag then
            header = header .. self:FormatQuestTag(tag, style);
        end
    end

    return header;
end
