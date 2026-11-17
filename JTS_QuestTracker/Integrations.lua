local _, ns = ...

--[[
    Other addons, used only when they are installed:

      TomTom   "TomTom Waypoint" in a quest's right-click menu, and optionally a waypoint every time
               you focus a quest. The location comes from WoW's own quest helper
               (C_QuestLog.GetNextWaypoint), the same place the built-in quest arrow points. When WoW
               has none and Questie is installed, Questie's nearest spot for the quest is used (2.2,
               idea from Waltrapalo's fork).
      Masque   the quest item buttons join a Masque group ("JTS Quest Tracker" > "Quest Items"), so
               they can wear the same skin as your action bars.
]]

local JQT = JTS_QuestTracker;

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

-- ---------------------------------------------------------------------------
-- TomTom
-- ---------------------------------------------------------------------------

local function tomtom()
    local addon = _G.TomTom;

    return type(addon) == "table" and type(addon.AddWaypoint) == "function" and addon or nil;
end

function JQT:HasTomTom()
    return tomtom() ~= nil;
end

-- Where WoW's quest helper would send you for this quest: mapID, x, y (0 to 1), or nil.
local function questLocation(questID)
    local api = C_QuestLog and C_QuestLog.GetNextWaypoint;
    if not api then return nil end

    local ok, mapID, x, y = pcall(api, questID);
    if not ok then return nil end

    return mapID, x, y;
end

local function validLocation(mapID, x, y)
    return type(mapID) == "number" and mapID > 0
        and type(x) == "number" and x >= 0 and x <= 1
        and type(y) == "number" and y >= 0 and y <= 1;
end

-- Questie's nearest spot for the quest (only while Questie is loaded). Uses Questie at run time
-- through its own modules; nothing of Questie's is copied here. Any change on Questie's side just
-- means no location, never an error.
local function questieLocation(questID)
    local loader = _G.QuestieLoader;
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end

    local eligibility = loader:ImportModule("TrackerMapEligibility");
    local quest, capabilities = eligibility.RefreshAndGetCapabilities(questID);
    if not capabilities or not capabilities.canNavigateQuest then return nil end

    local spawn, areaID = loader:ImportModule("DistanceUtils").GetNearestSpawnForQuest(quest);
    if not spawn or not areaID then return nil end

    local mapID = loader:ImportModule("ZoneDB"):GetUiMapIdByAreaId(areaID);
    return mapID, spawn[1] / 100, spawn[2] / 100;
end

-- mapID, x, y from WoW, or else from Questie; nil when neither knows.
local function findLocation(questID)
    local mapID, x, y = questLocation(questID);
    if validLocation(mapID, x, y) then return mapID, x, y end

    local ok;
    ok, mapID, x, y = pcall(questieLocation, questID);
    if ok and validLocation(mapID, x, y) then return mapID, x, y end
end

local waypoint; -- the one waypoint we keep (a new one replaces it)

function JQT:SetTomTomWaypoint(quest, quiet)
    local addon = tomtom();
    if not addon or not quest then return false end

    local mapID, x, y = findLocation(quest.questID);
    if not mapID then
        if not quiet then say("Neither WoW nor Questie has a location for " .. tostring(quest.title) .. " right now, so there's nothing to point TomTom at.") end
        return false;
    end

    if waypoint and addon.RemoveWaypoint then pcall(addon.RemoveWaypoint, addon, waypoint) end

    local ok, uid = pcall(addon.AddWaypoint, addon, mapID, x, y, {
        title = quest.title,
        from = "JTS Quest Tracker",
        persistent = false,
        minimap = true,
        world = true,
    });

    waypoint = ok and uid or nil;

    return waypoint ~= nil;
end

-- "TomTom Waypoint" in the quest's right-click menu (only when TomTom is installed).
JQT.contextMenuExtras = JQT.contextMenuExtras or {};
table.insert(JQT.contextMenuExtras, function(self, root, quest)
    if not tomtom() then return end

    root:CreateButton("TomTom Waypoint", function() JQT:SetTomTomWaypoint(quest) end);
end);

-- Optionally a TomTom waypoint every time you focus a quest (middle-click, menu or Auto-focus).
local setFocusedQuest = JQT.SetFocusedQuest;

function JQT:SetFocusedQuest(questID, ...)
    local result = setFocusedQuest(self, questID, ...);

    if questID and questID ~= 0 and self.db.profile.TomTomOnFocus and tomtom() then
        local quest = LibStub("JTSQTQuestLogHelper-1.0"):GetQuest(questID);
        if quest then self:SetTomTomWaypoint(quest, true) end
    end

    return result;
end

-- ---------------------------------------------------------------------------
-- Masque
-- ---------------------------------------------------------------------------

local masqueGroup;

local function masque()
    if masqueGroup ~= nil then return masqueGroup or nil end

    local lib = LibStub and LibStub("Masque", true);
    if not lib then
        masqueGroup = false;
        return nil;
    end

    local ok, group = pcall(lib.Group, lib, "JTS Quest Tracker", "Quest Items");
    masqueGroup = ok and group or false;

    return masqueGroup or nil;
end

-- Called by QuestItems.lua for every button it makes (out of combat).
function JQT:SkinQuestItemButton(button)
    local group = masque();
    if not group or not button or button.masqued then return end

    local ok = pcall(group.AddButton, group, button, {
        Icon = button.icon,
        Cooldown = button.cooldown,
        Count = button.count,
        Normal = button:GetNormalTexture(),
        Pushed = button:GetPushedTexture(),
        Highlight = button:GetHighlightTexture(),
    });

    if ok then
        button.masqued = true;
        -- Masque draws its own border.
        if button.border then button.border:Hide() end
    end
end

function JQT:HasMasque()
    return masque() ~= nil;
end

-- ---------------------------------------------------------------------------
-- Options (Buttons > Other Addons)
-- ---------------------------------------------------------------------------

JQT.buttonsTabGroups = JQT.buttonsTabGroups or {};

JQT.buttonsTabGroups.integrations = function()
    return {
        name = "Other Addons",
        type = "group",
        inline = true,
        order = 30,

        args = {
            tomtomStatus = {
                name = function()
                    return "TomTom: " .. (tomtom() and "|cff33ff99found|r. Right-click a quest for |cffffffffTomTom Waypoint|r." or "|cff999999not installed|r");
                end,
                type = "description", fontSize = "medium", order = 1
            },
            tomtomOnFocus = {
                name = "TomTom Waypoint When Focusing", order = 2, width = 1.8,
                desc = "Every time you focus a quest (middle-click, the menu or Auto-focus), TomTom gets a waypoint to it too.",
                type = "toggle",
                get = function() return JQT.db.profile.TomTomOnFocus end,
                set = function(_, value) JQT.db.profile.TomTomOnFocus = value end,
                disabled = function() return not tomtom() end
            },
            masqueStatus = {
                name = function()
                    return "Masque: " .. (masque() and "|cff33ff99found|r. Skin the quest item buttons in Masque under |cffffffffJTS Quest Tracker > Quest Items|r." or "|cff999999not installed|r");
                end,
                type = "description", fontSize = "medium", order = 3
            },
        }
    };
end
