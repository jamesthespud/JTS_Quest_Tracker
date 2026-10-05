--[[
    JTSQTCompat-1.0

    Every call JTS Quest Tracker makes into Blizzard's quest / map / UI APIs goes through this file.
    WoW Forever uses the modern C_QuestLog API (the "mainline" client family), which is all this
    supports. Calls are wrapped in pcall so one renamed function can't take the whole addon down.

    If a Forever patch breaks the addon, this is almost always the only file that needs touching.
    Run `/jtsqt status` in game to see what was found.
]]

local Compat = LibStub:NewLibrary("JTSQTCompat-1.0", 2);
if not Compat then return end

local _G = _G;
local pcall, type, tostring = pcall, type, tostring;

-- Calls fn and returns its results, or nothing if it is missing or raised an error.
local function try(fn, ...)
    if type(fn) ~= "function" then return end

    local ok, a, b, c, d, e = pcall(fn, ...);

    if ok then return a, b, c, d, e end
end

local function Q(name)
    return _G.C_QuestLog and _G.C_QuestLog[name];
end

-- WoW Forever lets you hold 40 quests.
function Compat:GetMaxQuests()
    return 40;
end

function Compat:GetWowheadURL(questID)
    return "https://www.wowhead.com/forever/quest=" .. tostring(questID);
end

function Compat:GetLogIndex(questID)
    local index = questID and try(Q("GetLogIndexForQuestID"), questID);

    return index and index > 0 and index or nil;
end

-- ---------------------------------------------------------------------------
-- Reading the quest log
-- ---------------------------------------------------------------------------

function Compat:CanReadQuestLog()
    return type(Q("GetInfo")) == "function" and type(Q("GetNumQuestLogEntries")) == "function";
end

-- Returns rows of { index, title, level, isHeader, questID, completed, failed }.
function Compat:GetQuestLogEntries()
    local entries = {};

    for index = 1, try(Q("GetNumQuestLogEntries")) or 0 do
        local info = try(Q("GetInfo"), index);

        if info and not info.isHidden and not info.isBounty then
            local questID = info.questID;
            local isQuest = not info.isHeader and questID and questID ~= 0;

            entries[#entries + 1] = {
                index = index,
                title = info.title or "",
                level = info.level or 0,
                isHeader = info.isHeader and true or false,
                questID = questID,
                completed = isQuest and try(Q("IsComplete"), questID) and true or false,
                failed = isQuest and try(Q("IsFailed"), questID) and true or false
            };
        end
    end

    return entries;
end

function Compat:GetQuestObjectives(questID)
    local objectives = questID and try(Q("GetQuestObjectives"), questID);

    return type(objectives) == "table" and objectives or {};
end

-- Is the player currently on this quest? nil when the client can't tell.
function Compat:IsOnQuest(questID)
    local result = questID and try(Q("IsOnQuest"), questID);

    if result == nil then return nil end

    return result and true or false;
end

-- The short "objectives" text of a quest (shown for quests without objectives).
function Compat:GetQuestSummary(questID)
    local index = self:GetLogIndex(questID);
    if not index then return nil end

    local _, objectives = try(_G.GetQuestLogQuestText, index);

    return objectives;
end

-- ---------------------------------------------------------------------------
-- Quest actions
-- ---------------------------------------------------------------------------

function Compat:IsQuestPushable(questID)
    return try(Q("IsPushableQuest"), questID) and true or false;
end

function Compat:ShareQuest(questID)
    local index = self:GetLogIndex(questID);

    if index then try(_G.QuestLogPushQuest, index) end
end

function Compat:AbandonQuest(questID)
    if not self:GetLogIndex(questID) then return end

    try(Q("SetSelectedQuest"), questID);
    try(Q("SetAbandonQuest"));
    try(Q("AbandonQuest"));
end

function Compat:GetQuestChatLink(quest)
    local link = try(_G.GetQuestLink, quest.questID);

    if type(link) == "string" and link ~= "" then return link end

    return "[" .. (quest.title or "?") .. "]";
end

-- Mirrors our tracked set into Blizzard's own watch list (best effort).
function Compat:MirrorWatch(questID, watched)
    try(Q(watched and "AddQuestWatch" or "RemoveQuestWatch"), questID);
end

-- Blizzard's own objective tracker, which we hide while JTS Quest Tracker runs.
function Compat:GetBlizzardTracker()
    local frame = _G.ObjectiveTrackerFrame;

    return type(frame) == "table" and type(frame.Hide) == "function" and frame or nil;
end

-- ---------------------------------------------------------------------------
-- Quest tags (Elite, Group, Dungeon, Raid, PvP, ...)
-- ---------------------------------------------------------------------------

-- Blizzard's quest tag IDs (Enum.QuestTag).
local TAG_KINDS = {
    [1] = "group",
    [41] = "pvp",
    [62] = "raid",
    [81] = "dungeon",
    [83] = "legendary",
    [85] = "heroic",
    [88] = "raid",
    [89] = "raid"
};

--[[
    Returns { kind = "elite" | "group" | "dungeon" | "raid" | "pvp" | "heroic" | "legendary" | "other",
              name = <the game's own text for the tag, if any>, group = <suggested group size> }
    or nil when the quest has no tag.
]]
function Compat:GetQuestTag(questID)
    if not questID then return nil end

    local tagID, tagName, isElite;
    local info = try(Q("GetQuestTagInfo"), questID);

    if type(info) == "table" then
        tagID, tagName, isElite = info.tagID, info.tagName, info.isElite;
    end

    local index = self:GetLogIndex(questID);
    local logInfo = index and try(Q("GetInfo"), index);
    local group = tonumber(type(logInfo) == "table" and logInfo.suggestedGroup) or 0;

    local kind = TAG_KINDS[tonumber(tagID) or -1];

    if not kind and type(tagName) == "string" and tagName ~= "" then
        kind = (tagName == _G.ELITE or tagName:lower() == "elite") and "elite" or "other";
    end

    if isElite and (not kind or kind == "other") then kind = "elite" end
    if not kind and group > 1 then kind = "group" end
    if not kind then return nil end

    return {
        kind = kind,
        name = type(tagName) == "string" and tagName ~= "" and tagName or nil,
        group = group > 1 and group or nil
    };
end

-- ---------------------------------------------------------------------------
-- Quest items (the "use this on ..." item some quests give you)
-- ---------------------------------------------------------------------------

-- Returns link, texture, charges, showWhenComplete, logIndex, or nil if the quest has no usable item.
function Compat:GetQuestItem(questID)
    local index = self:GetLogIndex(questID);
    if not index then return nil end

    local link, texture, charges, showWhenComplete = try(_G.GetQuestLogSpecialItemInfo, index);

    if not link or not texture then return nil end

    return link, texture, charges, showWhenComplete, index;
end

-- Returns start, duration, enable for the quest item's cooldown (or nil).
function Compat:GetQuestItemCooldown(logIndex)
    if logIndex then
        return try(_G.GetQuestLogSpecialItemCooldown, logIndex);
    end
end

-- ---------------------------------------------------------------------------
-- Maps / distance (used for "sort by proximity")
-- ---------------------------------------------------------------------------

local function M(name)
    return _G.C_Map and _G.C_Map[name];
end

function Compat:WorldPositionFromMap(uiMapID, x, y)
    if not uiMapID then return nil end

    local _, position = try(M("GetWorldPosFromMapPos"), uiMapID, { x = x, y = y });

    return position and position.x and position.y and position or nil;
end

function Compat:GetPlayerWorldPosition()
    local uiMapID = try(M("GetBestMapForUnit"), "player");
    local mapPosition = uiMapID and try(M("GetPlayerMapPosition"), uiMapID, "player");

    if not mapPosition then return nil end

    local _, position = try(M("GetWorldPosFromMapPos"), uiMapID, mapPosition);

    return position and position.x and position.y and position or nil;
end

function Compat:HasBuiltInQuestDistance()
    return type(Q("GetDistanceSqToQuest")) == "function";
end

function Compat:GetBuiltInQuestDistance(questID)
    local squared = try(Q("GetDistanceSqToQuest"), questID);

    if type(squared) == "number" and squared >= 0 then
        return math.sqrt(squared);
    end
end

-- ---------------------------------------------------------------------------
-- Diagnostics (/jtsqt status)
-- ---------------------------------------------------------------------------

function Compat:Describe()
    local function yes(value) return value and "yes" or "no" end

    return {
        "Interface " .. tostring(select(4, GetBuildInfo())),
        "Quest log API found: " .. yes(self:CanReadQuestLog()),
        "Quest watch API found: " .. yes(Q("AddQuestWatch") and Q("RemoveQuestWatch")),
        "Blizzard tracker found: " .. yes(self:GetBlizzardTracker()),
        "Settings panel API: " .. yes(_G.Settings and _G.Settings.RegisterCanvasLayoutCategory),
        "Context menu API: " .. yes(_G.MenuUtil and _G.MenuUtil.CreateContextMenu),
        "Quest item API: " .. yes(_G.GetQuestLogSpecialItemInfo),
        "Built-in quest distance: " .. yes(self:HasBuiltInQuestDistance())
    };
end
