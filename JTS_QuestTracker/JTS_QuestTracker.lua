local NAME, ns = ...

local Compat = LibStub("JTSQTCompat-1.0");
local QWH = LibStub("JTSQTQuestWatchHelper-1.0");
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local ZH = LibStub("JTSQTZoneHelper-1.0");
local QH = LibStub("JTSQTQuestHelpers-1.0");

local JQTL = JTS_QuestTrackerLocale;
JTS_QuestTracker = LibStub("AceAddon-3.0"):NewAddon("JTS_QuestTracker", "AceEvent-3.0");
local JQT = JTS_QuestTracker;

-- Plays one of Blizzard's UI sounds, quietly doing nothing if the sound kit isn't there.
local function playSound(name)
    if SOUNDKIT and SOUNDKIT[name] then
        pcall(PlaySound, SOUNDKIT[name]);
    end
end

-- Which sections the player collapsed (saved per character, so they stay collapsed after a reload).
local function collapsed()
    return JQT.db.char.CollapsedSections;
end

local function count(t)
    local n = 0;
    for _ in pairs(t or {}) do n = n + 1 end

    return n;
end

StaticPopupDialogs[NAME .. "_WowheadURL"] = {
    text = "%s", -- the whole text (title + quest name) is passed in as the first argument
    button2 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 300,
    whileDead = true,
    hideOnEscape = true,

    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,

    OnShow = function(self, data)
        local editBox = self.GetEditBox and self:GetEditBox();
        if not editBox or not data then return end

        editBox:SetText(Compat:GetWowheadURL(data));
        editBox:SetFocus();
        editBox:HighlightText();
    end
};

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

function JQT:OnEnable()
    self.db = LibStub("AceDB-3.0"):New("JTS_QuestTrackerDB", ns.CONSTANTS.DB_DEFAULTS, true);
    -- Profiles, migration of older settings, import / export (Profiles.lua).
    if self.SetupProfiles then
        self:SetupProfiles();
    end

    QWH:BypassWatchLimit(self.db.char.MANUALLY_TRACKED_QUESTS);
    QWH:KeepHidden();
end

-- Everything the tracker frame needs from the current profile.
function JQT:GetTrackerSettings()
    local p = self.db.profile;

    return {
        position = { x = p.PositionX, y = p.PositionY },
        width = p.Width,
        maxHeight = p.MaxHeight,
        backgroundColor = p.BackgroundColor,
        backgroundVisible = p.BackgroundAlwaysVisible or p.DeveloperMode,
        locked = self:IsTrackerLocked(),
        scrollBar = p.ShowScrollBar,
        scrollBarOnHover = p.ScrollBarOnHover,
        scrollSpeed = p.ScrollSpeed
    };
end

function JQT:OnPlayerEnteringWorld()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");

    -- If anything below blows up the player would be left with no quest tracker at all,
    -- so in that case hand the Blizzard tracker back.
    local ok = xpcall(function() self:Initialize() end, geterrorhandler());

    if not ok then
        QWH:RestoreBlizzardTracker();
        print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.ERROR.COLOR, "failed to start, the default quest tracker was restored. Type /jtsqt status and report the output.");
    end
end

function JQT:Initialize()
    if self.HookOptionsPanels then
        self:HookOptionsPanels();
    end

    JQTL:SetLocale(JQT.db.profile.Locale);

    -- Tracking changes made while handling a quest update are drawn right away by that handler,
    -- so the watch helper's report of them (a moment later) doesn't need a second redraw.
    self.watchChangesDrawn = {};

    -- The player tracked or untracked a quest in Blizzard's quest log: remember it as their choice.
    QWH:OnQuestWatchUpdated(function(updates)
        local redraw = false;

        for questID, update in pairs(updates) do
            if update.byUser then
                self.db.char.MANUALLY_TRACKED_QUESTS[update.questID] = update.watched and true or false;
                redraw = true;
            elseif self.watchChangesDrawn[questID] then
                self.watchChangesDrawn[questID] = nil;
            else
                redraw = true;
            end
        end

        if redraw then
            self:RefreshView();
        end
    end);

    QLH:OnQuestUpdated(function(quests)
        self:LogTrace("Event(OnQuestUpdated)");

        local currentZone, minimapZone = GetRealZoneText(), GetMinimapZoneText();
        local char = self.db.char;

        -- Alerts must never get in the way of the tracker itself.
        local alertsOk, alertsErr = pcall(self.CheckObjectiveAlerts, self, quests);
        if not alertsOk then
            self:LogError("Objective alert failed:", alertsErr);
        end

        for questID, quest in pairs(quests) do
            if quest.abandoned then
                char.QUESTS_LAST_UPDATED[questID] = nil;
                char.MANUALLY_TRACKED_QUESTS[questID] = nil;
                char.PINNED_QUESTS[questID] = nil;

                -- The watch helper has already dropped it; the redraw below shows that.
                self.watchChangesDrawn[questID] = true;
            elseif quest.accepted or quest.updated then
                char.QUESTS_LAST_UPDATED[questID] = quest.lastUpdated;

                -- Progress on a quest the player had untracked brings it back (or always tracks it).
                if self.db.profile.AutoTrackUpdatedQuests then
                    char.MANUALLY_TRACKED_QUESTS[questID] = true;
                elseif char.MANUALLY_TRACKED_QUESTS[questID] == false then
                    char.MANUALLY_TRACKED_QUESTS[questID] = nil;
                end

                if self:UpdateQuestWatch(currentZone, minimapZone, QLH:GetQuest(questID)) then
                    self.watchChangesDrawn[questID] = true;
                end
            end
        end

        self:RefreshView();
    end);

    ZH:OnZoneChanged(function(info)
        self:LogInfo("Changed Zones: (" .. info.zone .. ", " .. info.subZone .. ")");
        self:RefreshQuestWatch();
    end);

    self.tracker = LibStub("JTSQTTrackerHelper-1.0"):New(self:GetTrackerSettings());

    self:ApplyTextStyle();
    pcall(self.SnapshotObjectives, self);

    if self.db.char.TrackerHidden then
        self.tracker:Hide();
    end

    self.db.char.QUESTS_LAST_UPDATED = QLH:SetQuestsLastUpdated(self.db.char.QUESTS_LAST_UPDATED);

    self:RefreshQuestWatch();
    self:RefreshView();

    if self.db.profile.Sorting == "ByQuestProximity" then
        self:UpdateQuestProximityTimer();
    end

    -- Questie only listens once it is fully loaded.
    C_Timer.After(3.0, function()
        QH:SetAutoHideQuestHelperIcons(self.db.profile.AutoHideQuestHelperIcons);
    end);

    self:LogInfo("Enabled");
end

JQT:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld");

-- ---------------------------------------------------------------------------
-- Locking (by hand, and automatically during combat)
-- ---------------------------------------------------------------------------

function JQT:IsTrackerLocked()
    local p = self.db.profile;

    return p.LockFrame or (p.LockInCombat and InCombatLockdown()) or false;
end

function JQT:ApplyLock()
    if self.tracker then
        self.tracker:UpdateSettings({ locked = self:IsTrackerLocked() });
    end
end

-- Combat starts: drop the tracker if it is being dragged, and lock it.
JQT:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if not JQT.tracker then return end

    if JQT.trackerMoving and JQT.db.profile.LockInCombat then
        JQT.trackerMoving = false;
        JQT.tracker:StopMovingOrSizing();
        JQT.db.profile.PositionX, JQT.db.profile.PositionY = JQT.tracker:GetPosition();
    end

    JQT:ApplyLock();
end);

JQT:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    JQT:ApplyLock();
end);

function JQT:ShowWowheadPopup(id)
    local quest = QLH:GetQuest(id);
    local logo, c = ns.CONSTANTS.PATHS.LOGO, ns.CONSTANTS;
    local title = logo .. c.BRAND_COLOR .. " " .. c.NAME .. "|r - Wowhead URL " .. logo;

    if quest and quest.title then
        title = title .. "\n\n|cffff7f00" .. quest.title .. "|r";
    end

    StaticPopup_Show(NAME .. "_WowheadURL", title, nil, id);
end

-- ---------------------------------------------------------------------------
-- Sorting
-- ---------------------------------------------------------------------------

-- Sorting option -> { quest field, "<" smallest first or ">" biggest first }
local SORT_BY = {
    ByLevel = { "level", "<" },
    ByLevelReversed = { "level", ">" },
    ByPercentCompleted = { "completionPercent", ">" },
    ByRecentlyUpdated = { "lastUpdated", ">" },
    ByQuestProximity = { "distance", "<" }
};

-- Compares one field; quests missing the value go last, ties keep quest log order.
local function compareBy(quest, otherQuest, field, comparator)
    local value, otherValue = field and quest[field], field and otherQuest[field];

    if value == otherValue then return quest.index < otherQuest.index end
    if not value or not otherValue then return value ~= nil end
    if comparator == ">" then return value > otherValue end

    return value < otherValue;
end

local function sortQuests(quest, otherQuest)
    -- Pinned quests always come first (within their zone when zone headers are on).
    local pinned, otherPinned = JQT:IsPinned(quest.questID), JQT:IsPinned(otherQuest.questID);
    if pinned ~= otherPinned then return pinned end

    local sorting = JQT.db.profile.Sorting or "nil";
    if sorting == "Disabled" then return compareBy(quest, otherQuest) end

    local rule = SORT_BY[sorting];
    if rule then return compareBy(quest, otherQuest, rule[1], rule[2]) end

    JQT:LogError("Unknown Sorting value. (" .. sorting .. ")");

    return false;
end

function JQT:UpdateQuestProximityTimer()
    if self.db.profile.Sorting == "ByQuestProximity" then
        local initialized = false;
        self:Sort();

        -- Re-sort every 5 seconds, but only if the player actually moved.
        self.questProximityTimer = C_Timer.NewTicker(5.0, function()
            local position = Compat:GetPlayerWorldPosition();
            if not position then return end

            local last = self.playerPosition;
            local moved = last and ((position.x - last.x) ^ 2 + (position.y - last.y) ^ 2);

            if not initialized or not moved or moved > 0.01 then
                initialized = true;
                self.playerPosition = position;
                self:Sort();
            end
        end);
    elseif self.questProximityTimer then
        self.playerPosition = nil;
        self.questProximityTimer:Cancel();
    end
end

function JQT:Sort()
    self:LogInfo("Sort");

    if not self.questContainers then return end

    local quests = self:GetQuestInfo();
    local keys = {};
    for k in pairs(quests) do keys[#keys + 1] = k end

    -- Distances are expensive (Questie searches every objective location), so look each one up
    -- once per sort instead of once per comparison. No known distance stays nil and sorts last.
    if self.db.profile.Sorting == "ByQuestProximity" then
        local supported = QH:IsSupported();

        for _, quest in pairs(quests) do
            if supported then
                quest.distance = QH:GetDistanceToClosestObjective(quest.questID);
            else
                quest.distance = 0;
            end
        end
    end

    table.sort(keys, function(a, b) return sortQuests(quests[a], quests[b]) end);

    local questOrder, zoneOrder = {}, {};
    for i, questID in pairs(keys) do
        questOrder[questID] = i;

        local zone = quests[questID].zone;
        if zone then
            zoneOrder[zone] = zoneOrder[zone] or i;
        end
    end

    if self.db.profile.ZoneSorting ~= "ByQuestOrder" then
        -- Stable zone order: the zone you are in first, then the rest alphabetically.
        local zones = {};
        for zone in pairs(zoneOrder) do zones[#zones + 1] = zone end

        local currentZone, minimapZone = GetRealZoneText(), GetMinimapZoneText();
        local function isCurrent(zone) return zone == currentZone or zone == minimapZone end

        table.sort(zones, function(a, b)
            local aCurrent, bCurrent = isCurrent(a), isCurrent(b);
            if aCurrent ~= bCurrent then return aCurrent end

            local aName, bName = tostring(a):lower(), tostring(b):lower();
            if aName ~= bName then return aName < bName end

            return tostring(a) < tostring(b);
        end);

        zoneOrder = {};
        for rank, zone in ipairs(zones) do zoneOrder[zone] = rank end
    end

    for _, element in pairs(self.questContainers) do
        element:SetOrder(questOrder[element.metadata.quest.questID]);
    end

    if self.db.profile.ZoneHeaderEnabled then
        for _, element in ipairs(self.questsContainer.elements) do
            local order = zoneOrder[element.metadata.zone];

            if order then
                -- A zone's quests sit just after its header.
                element:SetOrder(element.metadata.header and order or order + 0.1, false);
            end
        end

        self.questsContainer:Order();
    end
end

-- ---------------------------------------------------------------------------
-- Which quests are tracked
-- ---------------------------------------------------------------------------

function JQT:RefreshQuestWatch()
    self:LogTrace("Refreshing Quest Watch");

    local currentZone, minimapZone = GetRealZoneText(), GetMinimapZoneText();

    for _, quest in pairs(QLH:GetQuests()) do
        self:UpdateQuestWatch(currentZone, minimapZone, quest);
    end
end

-- Returns true when the quest's tracked state changed.
function JQT:UpdateQuestWatch(currentZone, minimapZone, quest)
    return QWH:SetWatched(quest, self:ShouldWatchQuest(currentZone, minimapZone, quest));
end

-- Untrack a quest by hand (shift click / context menu) and remember that it was the player's choice.
function JQT:UntrackQuest(quest)
    self.db.char.MANUALLY_TRACKED_QUESTS[quest.questID] = false;
    self.db.char.PINNED_QUESTS[quest.questID] = nil;
    QWH:SetWatched(quest, false);
    self:RefreshView();
end

function JQT:ShouldWatchQuest(currentZone, minimapZone, quest)
    local p, manual = self.db.profile, self.db.char.MANUALLY_TRACKED_QUESTS[quest.questID];
    quest.isCurrentZone = quest.zone == currentZone or quest.zone == minimapZone;

    if self:IsPinned(quest.questID) or manual == true then return true end
    if manual == false or p.DisableFilters then return false end
    if p.HideCompletedQuests and quest.completed then return false end

    if p.CurrentZoneOnly and not quest.isCurrentZone and not quest.isClassQuest and not quest.isProfessionQuest then
        return false;
    end

    return true;
end

-- ---------------------------------------------------------------------------
-- Sample quests ("Display Dummy Data": shown while the options are open)
-- ---------------------------------------------------------------------------

local function sampleObjective(text, fulfilled, required, extra)
    local objective = { text = text, fulfilled = fulfilled, required = required, completed = fulfilled >= required };

    for k, v in pairs(extra or {}) do objective[k] = v end

    return objective;
end

local function sampleQuest(index, questID, title, zone, level, completionPercent, extra)
    local quest = {
        index = index, questID = questID, title = title, zone = zone, level = level,
        difficulty = QLH:GetDifficulty(level), completionPercent = completionPercent,
        completed = false, failed = false, isClassQuest = false, isProfessionQuest = false
    };

    for k, v in pairs(extra or {}) do quest[k] = v end

    return quest;
end

local function sampleQuests()
    return {
        -- Partially completed
        [6563] = sampleQuest(1, 6563, "The Essence of Aku'Mai", "Blackfathom Deeps", 22, 0.25,
            { objectives = { sampleObjective("Sapphire of Aku'Mai: 5/20", 5, 20) } }),
        -- No objectives, summary only
        [1196] = sampleQuest(2, 1196, "The Sacred Flame", "Thunder Bluff", 29, 1,
            { summary = "Deliver the Filled Etched Phial to Rau Cliffrunner at the Freewind Post." }),
        -- Multiple objectives, partially completed
        [4841] = sampleQuest(3, 4841, "Pacify the Centaur", "Thousand Needles", 25, 0.5714, { objectives = {
            sampleObjective("Galak Scout slain: 0/12", 0, 12),
            sampleObjective("Galak Wrangler slain: 10/10", 10, 10),
            sampleObjective("Galak Windchaser slain: 6/6", 6, 6)
        } }),
        -- Completed
        [5147] = sampleQuest(4, 5147, "Compendium of the Fallen", "Scarlet Monastery", 38, 1,
            { completed = true, objectives = { sampleObjective("Compendium of the Fallen: 1/1", 1, 1) } }),
        -- Failed
        [4904] = sampleQuest(5, 4904, "Free at Last", "Thousand Needles", 29, 0, { failed = true, objectives = {
            sampleObjective("Escort Lakota Windsong from the Darkcloud Pinnacle.", 0, 1, { type = "event" })
        } })
    };
end

-- Returns the quests to show, how many quests there are in total, and whether they are samples.
function JQT:GetQuestInfo()
    if self.db.profile.DisplayDummyData and self:IsOptionsShown() then
        local quests, watched = sampleQuests(), {};

        for questID, quest in pairs(quests) do
            if self:ShouldWatchQuest("Thunder Bluff", GetMinimapZoneText(), quest) then
                watched[questID] = quest;
            end
        end

        return watched, count(quests), true;
    end

    return QLH:GetWatchedQuests(), QLH:GetQuestCount(), false;
end

-- ---------------------------------------------------------------------------
-- Drawing the tracker
-- ---------------------------------------------------------------------------

function JQT:GetTrackerHeader(visibleQuestCount, questCount)
    local label, format = JQTL:GetString('QT_QUESTS'), self.db.profile.TrackerHeaderFormat;

    if format == "QuestsNumberVisible" then
        return label .. " (" .. visibleQuestCount .. "/" .. questCount .. ")";
    elseif format == "QuestsNumberVisibleTotal" then
        return label .. " (" .. visibleQuestCount .. "/" .. Compat:GetMaxQuests() .. ")";
    end

    return label;
end

function JQT:GetQuestHeader(quest)
    local p = self.db.profile;
    local format = p.QuestHeaderFormat;

    for match, key in format:gmatch("({{(%w+)}})") do
        local value = quest[key] or "";

        if type(value) == "number" and math.floor(value) ~= value then
            value = string.format("%.1f", value);
        end

        -- Quest names can contain "%" (e.g. "100% Proof"), which means something in a gsub replacement.
        format = format:gsub(match, (tostring(value):gsub("%%", "%%%%")), 1);
    end

    -- Optional level next to the name, unless the player already put {{level}} in their own format.
    local level = tonumber(quest.level);

    if level and level > 0 and not p.QuestHeaderFormat:find("{{level}}", 1, true) then
        if p.QuestLevelDisplay == "Prefix" then
            format = "[" .. level .. "] " .. format;
        elseif p.QuestLevelDisplay == "Suffix" then
            format = format .. " (" .. level .. ")";
        end
    end

    if self:IsPinned(quest.questID) then
        format = self:GetPinIcon() .. format;
    end

    return format;
end

-- Hovering a quest: its level and type, summary, every objective with its count, and what clicks do.
local function showQuestTooltip(quest, target)
    local H, N = HIGHLIGHT_FONT_COLOR, NORMAL_FONT_COLOR;
    local function pair(left, right, l, r)
        l, r = l or H, r or H;
        GameTooltip:AddDoubleLine(left, right, l.r, l.g, l.b, r.r, r.g, r.b);
    end

    GameTooltip:SetOwner(target, "ANCHOR_NONE");
    GameTooltip:SetPoint("RIGHT", target, "LEFT");
    GameTooltip:AddLine(quest.title, N.r, N.g, N.b, true);

    -- "Level 18 · Dungeon", the level in its difficulty color (Color Blind Mode aware).
    local details = {};
    if tonumber(quest.level) and quest.level > 0 then
        local c = JQT:GetDifficultyColor(quest.difficulty);
        details[#details + 1] = string.format("|cff%02x%02x%02xLevel %d|r", c.r * 255, c.g * 255, c.b * 255, quest.level);
    end

    local okTag, tag = pcall(JQT.GetQuestTag, JQT, quest);
    local tagText = okTag and tag and JQT:FormatQuestTag(tag, "Full"):match("^ %((.*)%)$");
    if tagText then details[#details + 1] = tagText end

    if #details > 0 then
        GameTooltip:AddLine(table.concat(details, "  ·  "), H.r, H.g, H.b);
    end

    if quest.summary and quest.summary ~= "" then
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine(quest.summary, H.r, H.g, H.b, true);
    end

    local grey = { r = 0.5, g = 0.5, b = 0.5 };

    if quest.completed then
        GameTooltip:AddLine(" ");
        local c = JQT:GetStatusColor("complete");
        GameTooltip:AddLine(JQTL:GetString('QT_READY_TO_TURN_IN'), c.r, c.g, c.b);
    elseif quest.failed then
        GameTooltip:AddLine(" ");
        local c = JQT:GetStatusColor("failed");
        GameTooltip:AddLine(JQTL:GetString('QT_FAILED'), c.r, c.g, c.b);
    elseif quest.objectives and #quest.objectives > 0 then
        GameTooltip:AddLine(" ");

        for _, objective in ipairs(quest.objectives) do
            local color = objective.completed and grey or H;
            -- "Diseased Timber Wolf slain: 3/8" -> left "Diseased Timber Wolf slain", right "3/8"
            local name, progress = (objective.text or ""):match("^(.-):%s*(%d+%s*/%s*%d+)$");

            if name then
                pair(name, progress, color, color);
            else
                GameTooltip:AddLine(objective.text or "", color.r, color.g, color.b, true);
            end
        end
    end

    GameTooltip:AddLine(" ");
    GameTooltip:AddLine("Click: open in quest log   Right-click: menu", grey.r, grey.g, grey.b);
    GameTooltip:AddLine("Shift: untrack   Ctrl: link in chat   Alt: Wowhead", grey.r, grey.g, grey.b);

    if JQT.db.profile.DeveloperMode then
        pair("\nQuest ID:", quest.questID);
        pair("Quest Index:", quest.index);

        for _, addon in ipairs(QH:GetActiveAddons()) do
            local distance = QH:GetDistanceToClosestObjective(quest.questID, addon);
            pair(addon .. " (distance):", distance and string.format("%.1fm", distance) or "N/A");
        end
    end

    GameTooltip:Show();
end

-- What a click on a quest does.
function JQT:OnQuestClicked(quest, button)
    if button ~= "LeftButton" then
        self:ToggleContextMenu(quest);
    elseif IsShiftKeyDown() then
        playSound("IG_MAINMENU_OPTION_CHECKBOX_ON");
        self:UntrackQuest(quest);
    elseif IsAltKeyDown() then
        self:ShowWowheadPopup(quest.questID);
    elseif IsControlKeyDown() then
        ChatEdit_InsertLink(Compat:GetQuestChatLink(quest));
    else
        QLH:ToggleQuest(quest.questID);
    end
end

-- The tracker header: drag to move, left-click to collapse, right-click for the options.
function JQT:AddTrackerHeader(trackerContainer, visibleCount, questCount)
    local p = self.db.profile;

    self.tracker:Font({
        label = self:GetTrackerHeader(visibleCount, questCount),
        color = p.TrackerHeaderFontColor,
        size = p.TrackerHeaderFontSize,
        container = self.tracker:Container({
            container = trackerContainer,
            margin = { bottom = 10 },
            events = {
                OnMouseDown = function(button)
                    if button == "LeftButton" and not self:IsTrackerLocked() then
                        self.trackerMoving = true;
                        self.tracker:StartMoving();
                    end
                end,

                OnMouseUp = function(button)
                    if button == "LeftButton" and self.trackerMoving then
                        self.trackerMoving = false;
                        self.tracker:StopMovingOrSizing();
                    end
                end,

                OnTrackerDragStart = function()
                    self.tracker:SetBackgroundVisibility(true);
                end,

                -- This fires only if OnTrackerDragStart fires as well.
                OnTrackerDragStop = function()
                    local x, y = self.tracker:GetPosition();

                    if not p.DeveloperMode and not p.BackgroundAlwaysVisible then
                        self.tracker:SetBackgroundVisibility(false);
                    end

                    p.PositionX, p.PositionY = x, y;
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("JTS_QuestTracker");
                end,

                -- This fires only if OnTrackerDragStart doesn't fire.
                OnTrackerMouseUp = function(button)
                    if button == "LeftButton" then
                        collapsed()["QUESTS"] = self.questsContainer:ToggleHidden() or nil;
                        playSound("IG_MAINMENU_OPTION_CHECKBOX_ON");
                    else
                        self:ToggleOptions();
                    end
                end
            }
        })
    });
end

-- A zone header (click to collapse) and the container its quests go in.
function JQT:AddZone(zone, questsInZone)
    local p = self.db.profile;
    local zoneContainer;

    self.tracker:Font({
        label = p.ZoneHeaderQuestCount and (zone .. " (" .. questsInZone .. ")") or zone,
        color = p.ZoneHeaderFontColor,
        size = p.ZoneHeaderFontSize,
        container = self.tracker:Container({
            container = self.questsContainer,
            margin = { bottom = 10, left = 2 },
            metadata = { header = true, zone = zone },
            events = {
                OnMouseUp = function()
                    collapsed()["Z-" .. zone] = zoneContainer:ToggleHidden() or nil;
                    playSound("IG_MAINMENU_OPTION_CHECKBOX_ON");
                end
            }
        })
    });

    zoneContainer = self.tracker:Container({
        container = self.questsContainer,
        hidden = collapsed()["Z-" .. zone],
        margin = { left = 8 },
        metadata = { header = false, zone = zone }
    });

    return zoneContainer;
end

-- One quest: its name, then its objectives (or "Ready to turn in" / "Failed" / its summary).
function JQT:AddQuest(quest, parent)
    local p = self.db.profile;

    local questContainer = self.tracker:Container({
        container = parent,
        backgroundColor = p.DeveloperMode and { g = 1.0, a = 0.2 },
        margin = { bottom = p.QuestPadding, left = (p.ZoneHeaderEnabled or not p.TrackerHeaderEnabled) and 0 or 5 },
        metadata = { quest = quest },
        events = {
            OnMouseUp = function(button) self:OnQuestClicked(quest, button) end,
            OnEnter = function(_, target) showQuestTooltip(quest, target) end,
            OnLeave = function() GameTooltip:ClearLines(); GameTooltip:Hide(); end
        }
    });
    table.insert(self.questContainers, questContainer);

    local flashing = self:IsFlashing(quest.questID);

    self.tracker:Font({
        label = self:GetQuestHeader(quest),
        size = p.QuestHeaderFontSize,
        color = flashing and self:GetStatusColor("flash")
            or (p.ColorHeadersByDifficultyLevel and self:GetDifficultyColor(quest.difficulty) or p.QuestHeaderFontColor),
        container = questContainer
    });

    local function line(text, color, progress, alpha)
        self.tracker:Font({
            label = ' - ' .. text,
            size = p.ObjectiveFontSize,
            color = color,
            alpha = alpha,
            progress = progress,
            progressColor = progress and self:GetProgressColor(progress) or nil,
            container = questContainer,
            margin = { bottom = 2.5 }
        });
    end

    if count(quest.objectives) == 0 then
        -- Some quests have no objectives, only a summary (which may not be loaded yet).
        if quest.summary and quest.summary ~= "" then
            line(quest.summary, p.ObjectiveFontColor);
        end
    elseif quest.completed then
        line(JQTL:GetString('QT_READY_TO_TURN_IN'), self:GetStatusColor("complete"));
    elseif quest.failed then
        line(JQTL:GetString('QT_FAILED'), self:GetStatusColor("failed"));
    else
        for _, objective in ipairs(quest.objectives) do
            local progress = self:GetObjectiveProgress(objective);
            local color;

            if flashing then
                color = self:GetStatusColor("flash");
            elseif p.ObjectiveColorByProgress then
                color = self:GetProgressColor(progress);
            elseif objective.completed then
                color = HIGHLIGHT_FONT_COLOR;
            else
                color = p.ObjectiveFontColor;
            end

            -- A bar only makes sense for objectives that count something (5/20), not "talk to X".
            local showBar = p.ObjectiveProgressBars and (tonumber(objective.required) or 0) > 1;

            -- Finished objectives fade back (unless they are flashing because you just finished them).
            local faded = p.FadeCompletedObjectives and objective.completed and not flashing;

            line(objective.text, color, showBar and progress or nil, faded and 0.5 or nil);
        end
    end
end

function JQT:RefreshView()
    self:LogInfo("Refresh Quests");
    self:ApplyTextStyle();
    self.tracker:Clear();

    local p = self.db.profile;
    local watchedQuests, questCount = self:GetQuestInfo();

    local trackerContainer = self.tracker:Container({
        margin = { x = 10, y = 10 },
        backgroundColor = p.DeveloperMode and { r = 1.0, g = 1.0, a = 0.2 }
    });

    if p.TrackerHeaderEnabled then
        self:AddTrackerHeader(trackerContainer, count(watchedQuests), questCount);
    end

    self.questsContainer = self.tracker:Container({
        container = trackerContainer,
        hidden = collapsed()["QUESTS"]
    });
    self.questContainers = {};

    local zoneContainers, questsPerZone = {}, {};
    for _, quest in pairs(watchedQuests) do
        questsPerZone[quest.zone] = (questsPerZone[quest.zone] or 0) + 1;
    end

    for _, quest in pairs(watchedQuests) do
        local parent = self.questsContainer;

        if p.ZoneHeaderEnabled then
            zoneContainers[quest.zone] = zoneContainers[quest.zone] or self:AddZone(quest.zone, questsPerZone[quest.zone]);
            parent = zoneContainers[quest.zone];
        end

        self:AddQuest(quest, parent);
    end

    self:Sort();
end

-- ---------------------------------------------------------------------------
-- Right-click menu
-- ---------------------------------------------------------------------------

function JQT:ToggleContextMenu(quest)
    if MenuUtil and MenuUtil.CreateContextMenu then
        pcall(self.ShowContextMenu, self, quest);
    end
end

function JQT:ShowContextMenu(quest)
    local questID = quest.questID;

    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateTitle(quest.title);
        root:CreateButton(JQTL:GetString(self:IsPinned(questID) and 'QT_UNPIN_QUEST' or 'QT_PIN_QUEST'), function()
            self:SetPinned(quest, not self:IsPinned(questID));
        end);
        root:CreateButton(JQTL:GetString('QT_UNTRACK_QUEST'), function() self:UntrackQuest(quest) end);
        root:CreateButton(JQTL:GetString('QT_VIEW_QUEST'), function() QLH:ToggleQuest(questID) end);
        root:CreateButton(JQTL:GetString('QT_WOWHEAD_URL'), function() self:ShowWowheadPopup(questID) end);

        local share = root:CreateButton(JQTL:GetString('QT_SHARE_QUEST'), function() Compat:ShareQuest(questID) end);
        if share and share.SetEnabled and (not UnitInParty("player") or not Compat:IsQuestPushable(questID)) then
            share:SetEnabled(false);
        end

        root:CreateButton(JQTL:GetString('QT_CANCEL_QUEST'), function() playSound("IG_MAINMENU_OPTION_CHECKBOX_ON") end);
        root:CreateDivider();
        root:CreateButton(self:GetStatusColorCode("failed") .. JQTL:GetString('QT_ABANDON_QUEST') .. "|r", function()
            Compat:AbandonQuest(questID);
            playSound("IG_QUEST_LOG_ABANDON_QUEST");
        end);
    end);
end

-- ---------------------------------------------------------------------------
-- Misc
-- ---------------------------------------------------------------------------

-- /jtsqt status: everything needed to work out why the addon misbehaves.
function JQT:PrintStatus()
    local prefix = ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR;

    print(prefix, "Version " .. tostring(ns.CONSTANTS.VERSION));

    for _, line in ipairs(Compat:Describe()) do
        print(prefix, line);
    end

    local watched = 0;
    for questID in pairs(QLH:GetQuests()) do
        if QWH:IsWatched(questID) then watched = watched + 1 end
    end

    local helpers = QH:GetActiveAddons();
    print(prefix, "Quests found: " .. QLH:GetQuestCount() .. ", tracked: " .. watched);
    print(prefix, "Quest helper addons: " .. (#helpers > 0 and table.concat(helpers, ", ") or "none"));
end

function JQT:ResetOverrides()
    self:LogInfo("Clearing Tracking Overrides...");
    self.db.char.MANUALLY_TRACKED_QUESTS = {};
    self:RefreshQuestWatch();
end

function JQT:Debug(type, bypass, ...)
    if bypass or (self.db.profile.DeveloperMode and self.db.profile.DebugLevel >= type.LEVEL) then
        print(ns.CONSTANTS.LOGGER.PREFIX .. type.COLOR, ...);
    end
end

function JQT:LogError(...) self:Debug(ns.CONSTANTS.LOGGER.TYPES.ERROR, true, ...) end
function JQT:LogInfo(...) self:Debug(ns.CONSTANTS.LOGGER.TYPES.INFO, false, ...) end
function JQT:LogTrace(...) self:Debug(ns.CONSTANTS.LOGGER.TYPES.TRACE, false, ...) end
