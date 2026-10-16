local _, ns = ...

--[[
    The tracker header and zone headers.

      - right-click menus: Collapse All, Expand All, Share All Quests / Share This Zone's Quests, Settings
      - Expand Current Zone Only: when you change zones, your zone opens and the others fold away
      - quest log full warning after the header count:  Quests (10/40)  Log 37/40
      - sharing quests with your group, one at a time, and a "Share all" button on dungeon and raid
        zone headers while you are in a group
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local ZH = LibStub("JTSQTZoneHelper-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local function collapsed()
    return JQT.db.char.CollapsedSections;
end

local function inGroup()
    return IsInGroup and IsInGroup() or false;
end

-- ---------------------------------------------------------------------------
-- Collapse / expand
-- ---------------------------------------------------------------------------

local function questZones()
    local zones = {};

    for _, quest in pairs(QLH:GetQuests()) do
        if quest.zone then zones[quest.zone] = true end
    end

    return zones;
end

-- Folds every zone away (the tracker itself stays open so you can see the zone names).
-- Without zone headers there is only the whole list to fold.
function JQT:CollapseAll()
    local c = collapsed();

    if self.db.profile.ZoneHeaderEnabled then
        c["QUESTS"] = nil;

        for zone in pairs(questZones()) do c["Z-" .. zone] = true end
    else
        c["QUESTS"] = true;
    end

    self:RefreshView();
end

function JQT:ExpandAll()
    local c = collapsed();

    for key in pairs(c) do
        if key == "QUESTS" or key:sub(1, 2) == "Z-" then c[key] = nil end
    end

    self:RefreshView();
end

-- Expand Current Zone Only: runs when the zone changes (not every subzone), and at login.
local lastZone;

function JQT:ExpandCurrentZoneOnly(force)
    if not self.db or not self.db.profile.ExpandCurrentZoneOnly then return end

    local zone, minimapZone = GetRealZoneText(), GetMinimapZoneText();
    if zone == lastZone and not force then return end
    lastZone = zone;

    local c, changed = collapsed(), false;

    for questZone in pairs(questZones()) do
        local fold = (questZone ~= zone and questZone ~= minimapZone) or nil;

        if c["Z-" .. questZone] ~= fold then
            c["Z-" .. questZone] = fold;
            changed = true;
        end
    end

    if changed and self.tracker then self:RefreshView() end
end

ZH:OnZoneChanged(function()
    if JQT.tracker then JQT:ExpandCurrentZoneOnly() end
end);

hooksecurefunc(JQT, "Initialize", function(self)
    self:ExpandCurrentZoneOnly(true);
end);

-- ---------------------------------------------------------------------------
-- Quest log full warning
-- ---------------------------------------------------------------------------

local function colorCode(c)
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255);
end

local getTrackerHeader = JQT.GetTrackerHeader;

-- questCount is how many quests are in your log (the sample quests while previewing).
function JQT:GetTrackerHeader(visibleQuestCount, questCount)
    local header = getTrackerHeader(self, visibleQuestCount, questCount);
    local p = self.db.profile;
    local max = Compat:GetMaxQuests();

    if not p.QuestLogFullWarning or not tonumber(questCount) then return header end

    -- Text as well as color, so it reads the same in every Color Blind Mode.
    if questCount >= max then
        return header .. "  " .. self:GetStatusColorCode("failed") .. "Log full|r";
    elseif questCount >= (tonumber(p.QuestLogWarnAt) or 36) then
        return header .. "  " .. colorCode(self:GetDifficultyColor(3)) .. "Log " .. questCount .. "/" .. max .. "|r";
    end

    return header;
end

-- ---------------------------------------------------------------------------
-- Sharing quests with your group
-- ---------------------------------------------------------------------------

-- One at a time with a short gap: a party member can only look at one shared quest at once.
local SHARE_GAP = 3;
local shareTicker;

local function shareableQuests(zone)
    local list = {};

    for questID, quest in pairs(QLH:GetQuests()) do
        if (not zone or quest.zone == zone) and not quest.failed and Compat:IsQuestPushable(questID) then
            list[#list + 1] = quest;
        end
    end

    table.sort(list, function(a, b) return (a.index or 0) < (b.index or 0) end);

    return list;
end

function JQT:IsSharingQuests()
    return shareTicker ~= nil;
end

function JQT:StopSharingQuests()
    if shareTicker then
        shareTicker:Cancel();
        shareTicker = nil;

        -- Bring back the "Share all" buttons.
        if self.tracker then C_Timer.After(0.5, function() JQT:RefreshView() end) end
    end
end

-- zone: only the quests under that zone header; nil for your whole quest log.
function JQT:ShareQuests(zone)
    if not inGroup() then
        say("You need to be in a group to share quests.");
        return;
    end

    if shareTicker then
        say("Already sharing quests, give it a moment.");
        return;
    end

    local list = shareableQuests(zone);

    if #list == 0 then
        say(zone and ("None of your quests in " .. zone .. " can be shared.") or "None of your quests can be shared.");
        return;
    end

    local function shareNext()
        local quest = table.remove(list, 1);

        -- Left the group, or abandoned / turned in the quest meanwhile.
        if quest and inGroup() and QLH:GetQuest(quest.questID) then
            Compat:ShareQuest(quest.questID);
        end

        if #list == 0 or not inGroup() then
            JQT:StopSharingQuests();
        end
    end

    if #list == 1 then
        say("Sharing " .. list[1].title .. ".");
    else
        say("Sharing " .. #list .. " quests with your group, one every " .. SHARE_GAP .. " seconds.");
    end

    local single = #list == 1;
    shareNext();

    if not single and #list > 0 then
        shareTicker = C_Timer.NewTicker(SHARE_GAP, shareNext);
    end
end

-- ---------------------------------------------------------------------------
-- "Share all" on dungeon and raid headers
-- ---------------------------------------------------------------------------

local INSTANCE_TAGS = { dungeon = true, heroic = true, raid = true };

-- Does this zone header hold dungeon or raid quests you can share right now?
local function canShareInstanceZone(self, zone)
    if not inGroup() or self:IsSharingQuests() then return false end

    local isInstance, shareable = false, false;

    for questID, quest in pairs(QLH:GetQuests()) do
        if quest.zone == zone then
            local ok, tag = pcall(self.GetQuestTag, self, quest);
            if ok and tag and INSTANCE_TAGS[tag.kind] then isInstance = true end
            if not quest.failed and Compat:IsQuestPushable(questID) then shareable = true end
        end
    end

    return isInstance and shareable;
end

local SHARE_TEXT = "Share all";
local GOLD = { r = 1, g = 0.82, b = 0 };

local function shareButton(header)
    local button = header.jtsShareButton;
    if button then return button end

    button = CreateFrame("Button", nil, header);
    button:SetFrameLevel((header:GetFrameLevel() or 0) + 3);
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.label:SetPoint("RIGHT", button, "RIGHT", 0, 0);
    button.label:SetText(SHARE_TEXT);

    button:SetScript("OnEnter", function(self)
        self.label:SetTextColor(1, 1, 1);
        GameTooltip:SetOwner(self, "ANCHOR_TOP");
        GameTooltip:AddLine("Share all " .. tostring(self.zone) .. " quests with your group");
        GameTooltip:Show();
    end);
    button:SetScript("OnLeave", function(self)
        self.label:SetTextColor(GOLD.r, GOLD.g, GOLD.b);
        GameTooltip:Hide();
    end);
    button:SetScript("OnClick", function(self)
        JQT:ShareQuests(self.zone);
        self:Hide();
    end);

    header.jtsShareButton = button;

    return button;
end

-- Every redraw hands out pooled rows: no button unless this header asks for one again.
local containerAcquire = JTS_QuestTrackerContainer.OnAcquire;
function JTS_QuestTrackerContainer:OnAcquire(...)
    containerAcquire(self, ...);
    if self.jtsShareButton then self.jtsShareButton:Hide() end
end

local addZone = JQT.AddZone;

function JQT:AddZone(zone, questsInZone, ...)
    local zoneContainer = addZone(self, zone, questsInZone, ...);

    if self.db.profile.ShareAllOnInstanceHeaders ~= false and canShareInstanceZone(self, zone) then
        local header = self.questsContainer.elements[#self.questsContainer.elements - 1];
        local font = header and header.elements and header.elements[1];

        if font and font.type == "font" then
            local button = shareButton(header);
            button.zone = zone;

            local _, size, flags = font.font:GetFont();
            local path = button.label:GetFont();
            button.label:SetFont(path, math.max(8, (size or 12) - 2), flags);
            button.label:SetTextColor(GOLD.r, GOLD.g, GOLD.b);

            local width = math.ceil(button.label:GetStringWidth()) + 4;
            button:SetSize(width, math.ceil(size or 12) + 2);
            button:ClearAllPoints();
            button:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0);
            button:Show();

            -- Keep the zone name clear of the button (Skin.lua can move both).
            local before = font:GetFullHeight();
            font.shareReserve = width + 6;
            font.font:SetPoint("RIGHT", -font.shareReserve, 0);
            font:SetHeight(font:_textHeight());

            local delta = font:GetFullHeight() - before;
            if delta ~= 0 then font:UpdateParentsHeight(delta) end
        end
    end

    return zoneContainer;
end

-- The buttons only make sense in a group: redraw when you join or leave one.
local wasInGroup;
local groupEvents = CreateFrame("Frame");
pcall(groupEvents.RegisterEvent, groupEvents, "GROUP_ROSTER_UPDATE");
groupEvents:SetScript("OnEvent", function()
    local now = inGroup();
    if now ~= wasInGroup then
        wasInGroup = now;
        if JQT.tracker then JQT:RefreshView() end
    end
end);

-- ---------------------------------------------------------------------------
-- Right-click menus
-- ---------------------------------------------------------------------------

local function menu(build)
    if MenuUtil and MenuUtil.CreateContextMenu then
        pcall(MenuUtil.CreateContextMenu, UIParent, function(_, root) build(root) end);
    end
end

local function enable(button, enabled)
    if button and button.SetEnabled then button:SetEnabled(enabled and true or false) end
end

local function addCollapseButtons(root)
    root:CreateButton("Collapse All", function() JQT:CollapseAll() end);
    root:CreateButton("Expand All", function() JQT:ExpandAll() end);
end

function JQT:ShowTrackerMenu()
    menu(function(root)
        root:CreateTitle(ns.CONSTANTS.NAME or "JTS Quest Tracker");
        addCollapseButtons(root);

        enable(root:CreateButton("Share All Quests", function() JQT:ShareQuests() end),
            inGroup() and not JQT:IsSharingQuests());

        -- Grey and failed quests (LogCleanup.lua), with how many there are.
        if JQT.GetCleanupQuests then
            local n = #JQT:GetCleanupQuests();
            enable(root:CreateButton("Clean Up Quest Log" .. (n > 0 and (" (" .. n .. ")") or ""), function() JQT:CleanUpQuestLog() end),
                n > 0 and not JQT:IsCleaningUpQuestLog());
        end

        root:CreateDivider();
        root:CreateButton("Hide Tracker", function() JQT:ToggleTrackerVisibility() end);
        root:CreateButton(SETTINGS or "Settings", function() JQT:ToggleOptions() end);
    end);
end

function JQT:ShowZoneMenu(zone)
    menu(function(root)
        root:CreateTitle(zone);

        enable(root:CreateButton("Share This Zone's Quests", function() JQT:ShareQuests(zone) end),
            inGroup() and not JQT:IsSharingQuests());

        root:CreateDivider();
        addCollapseButtons(root);
    end);
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local function set(info, value)
    JQT.db.profile[info.arg] = value;
    JQT:RefreshView();
end

-- Appearance > Tracker Header
JQT.logWarningOptions = function()
    return {
        warning = {
            name = "Quest Log Full Warning",
            desc = "Adds your quest log count after the header when it is nearly full, like  |cffff8000Log 37/40|r, and |cffff2020Log full|r at 40, so a quest giver doesn't catch you out.",
            type = "toggle", arg = "QuestLogFullWarning", width = 1.4, set = set, order = 1,
        },
        warnAt = {
            name = "Warn At",
            desc = "How many quests in your log before the warning shows. The log holds 40.",
            type = "range", arg = "QuestLogWarnAt", order = 2, width = 1.0, min = 30, max = 39, step = 1, set = set,
            disabled = function() return not JQT.db.profile.QuestLogFullWarning end
        },
    };
end

-- Appearance > Zone Headers
JQT.zoneOptions = function()
    return {
        expandCurrent = {
            name = "Expand Current Zone Only",
            desc = "When you move to another zone, its quests open and the other zones fold away. You can still open any zone by clicking it.",
            type = "toggle", arg = "ExpandCurrentZoneOnly", width = 1.6, order = 1,
            set = function(info, value)
                JQT.db.profile[info.arg] = value;
                JQT:ExpandCurrentZoneOnly(true);
            end,
            disabled = function() return not JQT.db.profile.ZoneHeaderEnabled end
        },
        shareAll = {
            name = "Share All on Dungeon Headers", order = 1.5, width = 1.6,
            desc = "In a group, zone headers with dungeon or raid quests (like Wailing Caverns) get a |cffffd100Share all|r button that shares every one of those quests with your group.",
            type = "toggle", arg = "ShareAllOnInstanceHeaders", set = set
        },
        collapseAll = {
            name = "Collapse All", type = "execute", width = 0.7, order = 2,
            desc = "Folds every zone away. Also in the tracker header's right-click menu, or /jtsqt collapse.",
            func = function() JQT:CollapseAll() end
        },
        expandAll = {
            name = "Expand All", type = "execute", width = 0.7, order = 3,
            desc = "Opens every zone. Also in the tracker header's right-click menu, or /jtsqt expand.",
            func = function() JQT:ExpandAll() end
        },
    };
end
