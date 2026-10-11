local _, ns = ...

--[[
    When the tracker is shown.

      - hidden by hand: /jtsqt hide, /jtsqt toggle, the key binding or the minimap button
      - In Combat: Show, Fade (see-through) or Hide
      - hidden in dungeons, raids, or battlegrounds and arenas

    Showing it by hand while a setting hides it keeps it up until that reason ends
    (you leave the instance, or the fight is over).

    Also: Dungeon Quests Only / Raid Quests Only. Inside a dungeon (raid) the tracker lists only
    dungeon (raid) quests: the Dungeon or Heroic tag (the Raid tag), or quests filed under that
    instance in your quest log, plus anything you pinned.
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local inCombat = false;
local instanceType = "none";
local override = false; -- shown by hand while a setting would hide it

local INSTANCE_SETTINGS = {
    party = { "HideInDungeons", "dungeons" },
    raid = { "HideInRaids", "raids" },
    pvp = { "HideInPvP", "battlegrounds and arenas" },
    arena = { "HideInPvP", "battlegrounds and arenas" },
};

local function readInstanceType()
    local ok, inInstance, kind = pcall(IsInInstance);

    return (ok and inInstance and kind) or "none";
end

-- Why the settings hide the tracker right now ("combat", "dungeons", ...), or nil.
function JQT:GetAutoHideReason()
    local p = self.db and self.db.profile;
    if not p then return nil end

    local setting = INSTANCE_SETTINGS[instanceType];
    if setting and p[setting[1]] then return setting[2] end

    if inCombat and p.CombatVisibility == "Hide" then return "combat" end

    return nil;
end

function JQT:IsTrackerHidden()
    return self.db ~= nil and self.db.char.TrackerHidden == true;
end

function JQT:UpdateVisibility()
    local tracker = self.tracker;
    if not tracker or not self.db then return end

    local p = self.db.profile;
    local hidden = self:IsTrackerHidden() or (self:GetAutoHideReason() ~= nil and not override);

    if hidden then
        tracker:Hide();
    else
        tracker:Show();
    end

    local alpha = 1;
    if inCombat and p.CombatVisibility == "Fade" then
        alpha = math.max(0.1, math.min(1, tonumber(p.CombatFadeAlpha) or 0.35));
    end

    tracker:SetAlpha(alpha);

    if self.SetQuestItemAlpha then
        self:SetQuestItemAlpha(alpha);
    end
end

-- Hide by hand (saved per character).
function JQT:SetTrackerHidden(hidden)
    self.db.char.TrackerHidden = hidden and true or false;

    if not hidden then
        -- "Show" means show, even where a setting would hide it.
        override = self:GetAutoHideReason() ~= nil;
    end

    self:UpdateVisibility();
end

function JQT:ToggleTrackerVisibility()
    if not self.tracker then return end

    local reason = self:GetAutoHideReason();

    if reason and not self:IsTrackerHidden() then
        -- Hidden (or about to be) by a setting: show it anyway, or put it back.
        override = not override;
        self:UpdateVisibility();

        if override then
            local untilWhen = reason == "combat" and "the fight ends" or "you leave";
            say("Tracker shown. Your settings hide it in " .. reason .. "; that comes back when " .. untilWhen .. ".");
        else
            say("Tracker hidden (your settings hide it in " .. reason .. ").");
        end

        return;
    end

    local hidden = not self:IsTrackerHidden();
    self:SetTrackerHidden(hidden);

    if hidden then
        say("Tracker hidden. Type /jtsqt toggle (or use your key binding) to show it again.");
    else
        say("Tracker shown.");
    end
end

-- Used by Bindings.xml
function JTS_QuestTracker_Toggle()
    JQT:ToggleTrackerVisibility();
end

-- ---------------------------------------------------------------------------
-- Dungeon Quests Only / Raid Quests Only
-- ---------------------------------------------------------------------------

-- instance type -> the setting, and which quest tags count
local INSTANCE_FILTERS = {
    party = { setting = "DungeonQuestsOnly", tags = { dungeon = true, heroic = true } },
    raid = { setting = "RaidQuestsOnly", tags = { raid = true } },
};

-- The filter that applies where you are right now, or nil.
local function activeFilter()
    local filter = INSTANCE_FILTERS[instanceType];

    return filter and JQT.db and JQT.db.profile[filter.setting] and filter or nil;
end

function JQT:GetInstanceType()
    return instanceType;
end

-- Is this quest for the kind of instance you are in? (tags: from INSTANCE_FILTERS)
function JQT:IsInstanceQuest(quest, tags)
    local ok, tag = pcall(self.GetQuestTag, self, quest);
    if ok and tag and tags[tag.kind] then return true end

    -- Quests filed under this instance's name in the quest log.
    local zone = GetRealZoneText();
    return quest.zone ~= nil and quest.zone ~= "" and quest.zone == zone;
end

local getQuestInfo = JQT.GetQuestInfo;

function JQT:GetQuestInfo()
    local quests, questCount, samples = getQuestInfo(self);

    local filter = activeFilter();

    if samples or not filter then
        return quests, questCount, samples;
    end

    -- Every dungeon (raid) quest in the log, even ones another filter (such as Current Zone Only) would
    -- leave out, but never one you untracked by hand.
    local untracked, only = self.db.char.MANUALLY_TRACKED_QUESTS, {};

    for questID, quest in pairs(QLH:GetQuests()) do
        if self:IsPinned(questID) or (untracked[questID] ~= false and self:IsInstanceQuest(quest, filter.tags)) then
            only[questID] = quest;
        end
    end

    return only, questCount, samples;
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local events = CreateFrame("Frame");

for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(events.RegisterEvent, events, event);
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true;
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false;

        -- Shown by hand for this fight only.
        local setting = INSTANCE_SETTINGS[instanceType];
        if override and not (setting and JQT.db and JQT.db.profile[setting[1]]) then override = false end
    else
        local kind = readInstanceType();

        if kind ~= instanceType then
            local filterBefore = activeFilter();

            instanceType = kind;
            override = false;

            if JQT.tracker and (filterBefore or activeFilter()) then
                JQT:RefreshView();
            end
        end
    end

    JQT:UpdateVisibility();
end);

JQT:OnSettingsApplied(function(self)
    self:UpdateVisibility();
end);

-- ---------------------------------------------------------------------------
-- Options (Frame Settings > Visibility)
-- ---------------------------------------------------------------------------

local function set(info, value)
    JQT.db.profile[info.arg] = value;
    JQT:UpdateVisibility();
end

-- Filters & Sorting > Filters
local function instanceFilterOption(name, arg, desc)
    return {
        name = name, desc = desc, type = "toggle", arg = arg, width = 1.6,
        set = function(info, value)
            JQT.db.profile[info.arg] = value;
            JQT:RefreshView();
        end
    };
end

JQT.dungeonFilterOptions = function()
    return instanceFilterOption("Dungeon Quests Only", "DungeonQuestsOnly",
        "Inside a dungeon, the tracker lists only dungeon quests: quests with the Dungeon or Heroic tag, and quests filed under that dungeon in your quest log. Pinned quests still show. Everything comes back when you leave.");
end

JQT.raidFilterOptions = function()
    return instanceFilterOption("Raid Quests Only", "RaidQuestsOnly",
        "Inside a raid, the tracker lists only raid quests: quests with the Raid tag, and quests filed under that raid in your quest log. Pinned quests still show. Everything comes back when you leave.");
end

JQT.visibilityOptions = function()
    return {
        name = "Visibility",
        type = "group",
        inline = true,

        args = {
            combat = {
                name = "In Combat",
                desc = "|cffffffffShow|r: no change.\n|cffffffffFade|r: the tracker turns see-through while you fight.\n|cffffffffHide|r: the tracker is hidden until the fight is over.\n\nQuest item buttons stay where they are during a fight, so you can still use them.",
                type = "select", arg = "CombatVisibility", width = 1.0, order = 1,
                values = { Show = "Show", Fade = "Fade", Hide = "Hide" }, sorting = { "Show", "Fade", "Hide" },
                set = set
            },
            fadeAlpha = {
                name = "Fade Opacity",
                desc = "How visible the tracker stays when it fades in combat. Default is 35%.",
                type = "range", arg = "CombatFadeAlpha", width = 1.2, order = 2,
                min = 0.1, max = 0.9, step = 0.05, isPercent = true,
                set = set,
                disabled = function() return JQT.db.profile.CombatVisibility ~= "Fade" end
            },
            spacer = { name = " ", type = "description", width = "full", order = 3 },
            dungeons = {
                name = "Hide in Dungeons", type = "toggle", arg = "HideInDungeons", width = 1.1, order = 4, set = set,
                desc = "Hides the tracker inside dungeons."
            },
            raids = {
                name = "Hide in Raids", type = "toggle", arg = "HideInRaids", width = 0.9, order = 5, set = set,
                desc = "Hides the tracker inside raids."
            },
            pvp = {
                name = "Hide in PvP", type = "toggle", arg = "HideInPvP", width = 0.9, order = 6, set = set,
                desc = "Hides the tracker in battlegrounds and arenas."
            },
            note = {
                name = "|cff999999Showing the tracker by hand (/jtsqt toggle, your key binding or the minimap button) keeps it up until you leave the instance or the fight ends.|r",
                type = "description", width = "full", order = 7
            },
        }
    };
end
