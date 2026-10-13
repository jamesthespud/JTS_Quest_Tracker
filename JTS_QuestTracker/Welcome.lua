local _, ns = ...

--[[
    Welcome screen.

    Shown once (per account) the first time this version of JTS Quest Tracker loads, and any time with
    /jtsqt welcome or the button in Advanced. It lists the features people might not know about, each
    with a checkbox that turns it on or off right there.

    Other files can add rows or sections with JQT:AddWelcomeSection(section) (the V3 skin picker does).
]]

local JQT = JTS_QuestTracker;

local WIDTH, HEIGHT = 680, 520;
local GREEN = { r = 0.2, g = 1, b = 0.6 };

local function p() return JQT.db.profile end

local function refresh() JQT:RefreshView() end

-- { title, text, get, set } per feature.
local FEATURES = {
    {
        title = "Announce to Party",
        text = "Your group sees each objective you finish in party chat.",
        get = function() return p().AlertParty end,
        set = function(v) p().AlertParty = v end
    },
    {
        title = "Party Progress",
        text = "See group members' progress under your quests (they need JTS QT too).",
        get = function() return p().PartyProgress ~= false end,
        set = function(v) p().PartyProgress = v; refresh() end
    },
    {
        title = "Auto-focus",
        text = "WoW's quest arrow follows the quest you just progressed. Middle-click any quest to focus it.",
        get = function() return p().AutoFocusQuest end,
        set = function(v) p().AutoFocusQuest = v end
    },
    {
        title = "Show Distance",
        text = "How far away each quest is, like 120 yd, after its name.",
        get = function() return p().ShowQuestDistance end,
        set = function(v)
            p().ShowQuestDistance = v;
            if JQT.UpdateDistanceTicker then JQT:UpdateDistanceTicker() end
            refresh();
        end
    },
    {
        title = "Rewards in Tooltip",
        text = "Hover a quest to see its XP, money and item rewards.",
        get = function() return p().ShowQuestRewards end,
        set = function(v) p().ShowQuestRewards = v end
    },
    {
        title = "Turn-in XP",
        text = "The header shows quests ready to turn in and their XP.",
        get = function() return p().TurnInXPSummary end,
        set = function(v) p().TurnInXPSummary = v; refresh() end
    },
    {
        title = "Quest Item Buttons",
        text = "Use a quest's item straight from the tracker.",
        get = function() return p().ShowQuestItems end,
        set = function(v)
            p().ShowQuestItems = v;
            if JQT.RefreshQuestItemData then JQT:RefreshQuestItemData() end
        end
    },
    {
        title = "Fade in Combat",
        text = "The tracker turns see-through while you fight.",
        get = function() return p().CombatVisibility == "Fade" end,
        set = function(v)
            p().CombatVisibility = v and "Fade" or "Show";
            if JQT.UpdateVisibility then JQT:UpdateVisibility() end
        end
    },
    {
        title = "Dungeon & Raid Quests Only",
        text = "Inside an instance, only its kind of quests are listed.",
        get = function() return p().DungeonQuestsOnly and p().RaidQuestsOnly end,
        set = function(v) p().DungeonQuestsOnly, p().RaidQuestsOnly = v, v; refresh() end
    },
    {
        title = "Expand Current Zone Only",
        text = "Your zone opens and the others fold away as you travel.",
        get = function() return p().ExpandCurrentZoneOnly end,
        set = function(v)
            p().ExpandCurrentZoneOnly = v;
            if JQT.ExpandCurrentZoneOnly then JQT:ExpandCurrentZoneOnly(true) end
        end
    },
    {
        title = "Quest Timers",
        text = "Timed quests count down under their name.",
        get = function() return p().ShowQuestTimers end,
        set = function(v) p().ShowQuestTimers = v; refresh() end
    },
    {
        title = "Mark New Forever Quests",
        text = "A blue infinity symbol on quests that are new in WoW Forever.",
        get = function() return p().ShowForeverMarker ~= false end,
        set = function(v) p().ShowForeverMarker = v; refresh() end
    },
    {
        title = "Minimap Button",
        text = "Left-click for settings, right-click to show or hide the tracker.",
        get = function() return not (p().MinimapIcon and p().MinimapIcon.hide) end,
        set = function(v)
            p().MinimapIcon = p().MinimapIcon or {};
            p().MinimapIcon.hide = not v;
            if JQT.UpdateMinimapButton then JQT:UpdateMinimapButton() end
        end
    },
};

-- Extra sections from other files: { title = ..., build = function(parent, width) return height end }
local sections = {};

function JQT:AddWelcomeSection(section)
    table.insert(sections, section);
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local frame;
local checkboxes = {};

local function text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    local path, _, flags = fs:GetFont();
    if path then fs:SetFont(path, size, flags) end
    fs:SetTextColor(color.r, color.g, color.b);
    fs:SetJustifyH(justify or "LEFT");
    fs:SetWordWrap(true);

    return fs;
end

local function featureRow(parent, feature, x, y, width)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
    check:SetSize(24, 24);
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false;
        pcall(feature.set, on);
        if PlaySound and SOUNDKIT then pcall(PlaySound, on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    end);

    local title = text(parent, 13, HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 });
    title:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -4);
    title:SetWidth(width - 32);
    title:SetText(feature.title);

    local desc = text(parent, 11, { r = 0.7, g = 0.7, b = 0.7 });
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2);
    desc:SetWidth(width - 32);
    desc:SetText(feature.text);

    checkboxes[#checkboxes + 1] = { check = check, feature = feature };
end

local function build()
    if frame then return frame end

    frame = CreateFrame("Frame", "JTS_QuestTrackerWelcome", UIParent);
    frame:SetSize(WIDTH, HEIGHT);
    frame:SetPoint("CENTER");
    frame:SetFrameStrata("DIALOG");
    frame:SetToplevel(true);
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:SetMovable(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", frame.StartMoving);
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
    frame:Hide();

    -- Esc closes it.
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "JTS_QuestTrackerWelcome") end

    local bg = frame:CreateTexture(nil, "BACKGROUND");
    bg:SetAllPoints();
    bg:SetColorTexture(0.067, 0.078, 0.094, 0.96);

    local edge = frame:CreateTexture(nil, "BORDER");
    edge:SetPoint("TOPLEFT", -1, 1);
    edge:SetPoint("BOTTOMRIGHT", 1, -1);
    edge:SetColorTexture(1, 1, 1, 0.12);
    edge:SetDrawLayer("BACKGROUND", -1);

    local bar = frame:CreateTexture(nil, "ARTWORK");
    bar:SetPoint("TOPLEFT", 0, 0);
    bar:SetPoint("TOPRIGHT", 0, 0);
    bar:SetHeight(3);
    bar:SetColorTexture(GREEN.r, GREEN.g, GREEN.b, 1);

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT", -2, -4);

    local icon = frame:CreateTexture(nil, "ARTWORK");
    icon:SetTexture("Interface\\AddOns\\JTS_QuestTracker\\Icon");
    icon:SetSize(40, 40);
    icon:SetPoint("TOPLEFT", 20, -18);

    local heading = text(frame, 20, GREEN);
    heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2);
    heading:SetText("Welcome to JTS Quest Tracker");

    local version = text(frame, 12, { r = 0.6, g = 0.6, b = 0.6 });
    version:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3);
    version:SetText("Version " .. tostring(ns.CONSTANTS.VERSION) .. "  ·  here's what you can turn on or off. You can change all of it later in the settings.");

    local y = -78;

    -- Extra sections first (e.g. the skin picker).
    for _, section in ipairs(sections) do
        local label = text(frame, 14, NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 });
        label:SetPoint("TOPLEFT", 20, y);
        label:SetText(section.title);
        y = y - 22;

        local holder = CreateFrame("Frame", nil, frame);
        holder:SetPoint("TOPLEFT", 20, y);
        holder:SetSize(WIDTH - 40, 10);

        local ok, height = pcall(section.build, holder, WIDTH - 40);
        height = ok and tonumber(height) or 0;
        holder:SetHeight(math.max(1, height));
        y = y - height - 10;
    end

    local label = text(frame, 14, NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 });
    label:SetPoint("TOPLEFT", 20, y);
    label:SetText("Features");
    y = y - 24;

    -- Two columns.
    local columnWidth = (WIDTH - 60) / 2;
    local rowHeight = 50;

    for i, feature in ipairs(FEATURES) do
        local column = (i - 1) % 2;
        local row = math.floor((i - 1) / 2);
        featureRow(frame, feature, 20 + column * (columnWidth + 20), y - row * rowHeight, columnWidth);
    end

    -- Tall enough for everything above, plus the footer.
    frame:SetHeight(-y + math.ceil(#FEATURES / 2) * rowHeight + 80);

    -- Footer
    local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    settings:SetSize(150, 24);
    settings:SetPoint("BOTTOMLEFT", 20, 16);
    settings:SetText("All Settings");
    settings:SetScript("OnClick", function()
        frame:Hide();
        JQT:ToggleOptions();
    end);

    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    done:SetSize(120, 24);
    done:SetPoint("BOTTOMRIGHT", -20, 16);
    done:SetText("Done");
    done:SetScript("OnClick", function() frame:Hide() end);

    local hint = text(frame, 11, { r = 0.55, g = 0.55, b = 0.55 }, "CENTER");
    hint:SetPoint("BOTTOM", 0, 22);
    hint:SetText("/jtsqt welcome shows this again");

    local credit = text(frame, 10, { r = 0.45, g = 0.45, b = 0.45 }, "CENTER");
    credit:SetPoint("BOTTOM", 0, 50);
    credit:SetWidth(WIDTH - 40);
    credit:SetText("James's own fork of Butter Quest Tracker by Butter Cookie Kitkat (MIT). Not affiliated with the original author.");

    frame:SetScript("OnShow", function()
        for _, entry in ipairs(checkboxes) do
            local ok, value = pcall(entry.feature.get);
            entry.check:SetChecked(ok and value and true or false);
        end
    end);

    frame:SetScript("OnHide", function()
        JQT.db.global.WelcomeSeen = ns.CONSTANTS.VERSION;
    end);

    return frame;
end

function JQT:ShowWelcome()
    local ok, window = pcall(build);
    if not ok or not window then
        self:LogError("Welcome screen:", window);
        return;
    end

    window:Show();
end

-- First login with this version: show it once things have settled (and never in combat).
hooksecurefunc(JQT, "Initialize", function(self)
    if self.db.global.WelcomeSeen then return end

    C_Timer.After(4, function()
        if InCombatLockdown and InCombatLockdown() then
            local wait = CreateFrame("Frame");
            wait:RegisterEvent("PLAYER_REGEN_ENABLED");
            wait:SetScript("OnEvent", function(w) w:UnregisterAllEvents(); JQT:ShowWelcome() end);
        else
            JQT:ShowWelcome();
        end
    end);
end);

-- Advanced > Welcome Screen
JQT.welcomeOptions = function()
    return {
        name = "Show Welcome Screen", type = "execute", width = 1.2,
        desc = "Opens the welcome screen again: a quick tour of the features you can turn on or off. Also /jtsqt welcome.",
        func = function()
            local ACD = LibStub("AceConfigDialog-3.0", true);
            if ACD then pcall(ACD.Close, ACD, "JTS_QuestTracker") end
            if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
            JQT:ShowWelcome();
        end
    };
end
