local _, ns = ...

--[[
    Welcome screen.

    Shown once (per account) the first time this version of JTS Quest Tracker loads, and any time with
    /jtsqt welcome or the button in Advanced. It walks through the features people might not know
    about, one section per page (Questing, Group, Tracker; Next / Back, Finish on the last page), each
    with a checkbox that turns it on or off right there.

    Other files can add rows or sections with JQT:AddWelcomeSection(section) (the skin picker does).

    What's new: features carry the version they arrived in (added = "1.4.0"). When someone who has
    seen the welcome screen before loads a newer version with new features, they get a single
    "New in X.Y" page with just those (and a button for the full tour) instead of the whole tour.
    In the full tour, features new in this version are marked NEW.
]]

local JQT = JTS_QuestTracker;

local WIDTH, HEIGHT = 700, 450;

-- Footer, from the bottom edge up: the credit line, a thin rule, then the buttons and page names.
local CREDIT_STRIP = 26;              -- the rule sits here; the credit is below it
local BUTTONS_Y = CREDIT_STRIP + 10;  -- bottom of All Settings / Back / Next
local FOOTER = BUTTONS_Y + 24 + 14;   -- pages end here (buttons are 24 high, plus a gap)
local GREEN = { r = 0.2, g = 1, b = 0.6 };

local function p() return JQT.db.profile end

local function refresh() JQT:RefreshView() end

-- { title, text, get, set } per feature.
local FEATURES = {
    {
        title = "Announce to Party", group = "Group",
        text = "Your group sees each objective you finish in party chat.",
        get = function() return p().AlertParty end,
        set = function(v) p().AlertParty = v end
    },
    {
        title = "Party Progress", group = "Group",
        text = "See group members' progress under your quests (they need JTS QT too).",
        get = function() return p().PartyProgress ~= false end,
        set = function(v) p().PartyProgress = v; refresh() end
    },
    {
        title = "Auto-focus", group = "Questing",
        text = "WoW's quest arrow follows the quest you just progressed. Middle-click any quest to focus it.",
        get = function() return p().AutoFocusQuest end,
        set = function(v) p().AutoFocusQuest = v end
    },
    {
        title = "Show Distance", group = "Questing",
        text = "How far away each quest is, like 120 yd, after its name.",
        get = function() return p().ShowQuestDistance end,
        set = function(v)
            p().ShowQuestDistance = v;
            if JQT.UpdateDistanceTicker then JQT:UpdateDistanceTicker() end
            refresh();
        end
    },
    {
        title = "Rewards in Tooltip", group = "Questing",
        text = "Hover a quest to see its XP, money and item rewards.",
        get = function() return p().ShowQuestRewards end,
        set = function(v) p().ShowQuestRewards = v end
    },
    {
        title = "Turn-in XP", group = "Questing",
        text = "The header shows quests ready to turn in and their XP.",
        get = function() return p().TurnInXPSummary end,
        set = function(v) p().TurnInXPSummary = v; refresh() end
    },
    {
        title = "Quest Item Buttons", group = "Questing",
        text = "Use a quest's item straight from the tracker.",
        get = function() return p().ShowQuestItems end,
        set = function(v)
            p().ShowQuestItems = v;
            if JQT.RefreshQuestItemData then JQT:RefreshQuestItemData() end
        end
    },
    {
        title = "Fade in Combat", group = "Tracker",
        text = "The tracker turns see-through while you fight.",
        get = function() return p().CombatVisibility == "Fade" end,
        set = function(v)
            p().CombatVisibility = v and "Fade" or "Show";
            if JQT.UpdateVisibility then JQT:UpdateVisibility() end
        end
    },
    {
        title = "Dungeon & Raid Quests Only", group = "Group",
        text = "Inside an instance, only its kind of quests are listed.",
        get = function() return p().DungeonQuestsOnly and p().RaidQuestsOnly end,
        set = function(v) p().DungeonQuestsOnly, p().RaidQuestsOnly = v, v; refresh() end
    },
    {
        title = "Expand Current Zone Only", group = "Tracker",
        text = "Your zone opens and the others fold away as you travel.",
        get = function() return p().ExpandCurrentZoneOnly end,
        set = function(v)
            p().ExpandCurrentZoneOnly = v;
            if JQT.ExpandCurrentZoneOnly then JQT:ExpandCurrentZoneOnly(true) end
        end
    },
    {
        title = "Quest Timers", group = "Questing",
        text = "Timed quests count down under their name.",
        get = function() return p().ShowQuestTimers end,
        set = function(v) p().ShowQuestTimers = v; refresh() end
    },
    {
        title = "Mark New Forever Quests", group = "Questing",
        text = "A blue infinity symbol on quests that are new in WoW Forever.",
        get = function() return p().ShowForeverMarker ~= false end,
        set = function(v) p().ShowForeverMarker = v; refresh() end
    },
    {
        title = "Share All on Dungeon Headers", group = "Group",
        text = "In a group, dungeon and raid headers get a Share all button.",
        get = function() return p().ShareAllOnInstanceHeaders ~= false end,
        set = function(v) p().ShareAllOnInstanceHeaders = v; refresh() end
    },
    {
        title = "Grow Upwards", group = "Tracker",
        text = "For a tracker near the bottom of the screen: it grows up, header below.",
        get = function() return p().GrowUp end,
        set = function(v) JQT:SetGrowUpwards(v) end
    },
    {
        title = "Keep Header in View", group = "Tracker",
        text = "The header with your counts stays pinned while you scroll.",
        get = function() return p().StickyHeader ~= false end,
        set = function(v)
            p().StickyHeader = v;
            if JQT.UpdateStickyHeader then JQT:UpdateStickyHeader() end
        end
    },
    {
        title = "Always Show Scroll Bar", group = "Tracker",
        text = "The scroll bar stays up instead of fading (long lists only).",
        get = function() return p().ShowScrollBar and p().ScrollBarAlways end,
        set = function(v)
            p().ScrollBarAlways = v;
            if v then p().ShowScrollBar = true end
            if JQT.tracker then JQT.tracker:UpdateSettings({ scrollBar = p().ShowScrollBar, scrollBarAlways = v }) end
        end
    },
    {
        title = "Minimap Button", group = "Tracker",
        text = "Left-click for settings, right-click to show or hide the tracker.",
        get = function() return not (p().MinimapIcon and p().MinimapIcon.hide) end,
        set = function(v)
            p().MinimapIcon = p().MinimapIcon or {};
            p().MinimapIcon.hide = not v;
            if JQT.UpdateMinimapButton then JQT:UpdateMinimapButton() end
        end
    },

    -- 1.4.0
    {
        title = "Auto-accept Quests", group = "Questing", added = "1.4.0",
        text = "Accepts the quests NPCs offer you. Hold Shift to do it yourself. Grey quests are skipped.",
        get = function() return p().AutoAcceptQuests end,
        set = function(v) p().AutoAcceptQuests = v end
    },
    {
        title = "Auto-turn-in Quests", group = "Questing", added = "1.4.0",
        text = "Hands in finished quests. Stops so you can pick when there's a choice of rewards.",
        get = function() return p().AutoTurnInQuests end,
        set = function(v) p().AutoTurnInQuests = v end
    },
    {
        title = "TomTom Waypoint When Focusing", group = "Questing", added = "1.4.0",
        text = "Needs TomTom. Focusing a quest also sets a TomTom arrow; right-click quests for one any time.",
        get = function() return p().TomTomOnFocus end,
        set = function(v) p().TomTomOnFocus = v end
    },
    {
        title = "Party Progress as a Count", group = "Group", added = "1.4.0",
        text = "A small group icon and a number by each quest instead of a row per member. Hover for details.",
        get = function() return p().PartyProgressDisplay ~= "Rows" end,
        set = function(v) p().PartyProgressDisplay = v and "Count" or "Rows"; refresh() end
    },
    {
        title = "Collapse in Instances", group = "Group", added = "1.4.0",
        text = "Dungeons, raids, battlegrounds: the tracker folds up to its header, and opens again when you leave.",
        get = function() return p().AutoCollapseInInstance end,
        set = function(v) p().AutoCollapseInInstance = v end
    },
    {
        title = "Drag to Reorder", group = "Tracker", added = "1.4.0",
        text = "Sorts quests by hand: drag one up or down to move it (the tracker must be unlocked).",
        get = function() return p().Sorting == "ByManual" end,
        set = function(v)
            if v then
                if p().Sorting ~= "ByManual" then p().SortingBeforeManual = p().Sorting end
                p().Sorting = "ByManual";
            elseif p().Sorting == "ByManual" then
                p().Sorting = p().SortingBeforeManual or "Disabled";
            end
            pcall(JQT.UpdateQuestProximityTimer, JQT);
            JQT:Sort();
        end
    },

    -- 1.5.0
    {
        title = "Quest Notes", group = "Questing", added = "1.5.0",
        text = "Right-click a quest > Add Note. It shows in the tooltip; the tick shows a note icon after the name.",
        get = function() return p().ShowQuestNoteIcon ~= false end,
        set = function(v) p().ShowQuestNoteIcon = v; refresh() end
    },

    -- 2.0.0
    {
        -- The full tour has its own Look page, so this one is only on the "New in" page.
        title = "Modern Skin", group = "Tracker", added = "2.0.0", newOnly = true,
        text = "A dark rounded panel, level badges and counts on the right. Untick for the classic look.",
        get = function() return p().Skin == "Modern" end,
        set = function(v) p().Skin = v and "Modern" or "Classic"; if JQT.ApplySkin then JQT:ApplySkin() end end
    },
    {
        title = "XP Bar", group = "Tracker", added = "2.0.0",
        text = "A thin bar under the header, with what your finished quests will add. Gold when they level you up.",
        get = function() return p().ShowXPBar ~= false end,
        set = function(v) p().ShowXPBar = v; refresh() end
    },
    {
        title = "Highlight Quest Objects", group = "World", added = "2.0.0",
        text = "Marks and outlines the nearest thing you can use, which in quest areas is mostly quest objects.",
        get = function() return JQT.IsHighlightingQuestObjects and JQT:IsHighlightingQuestObjects() end,
        set = function(v) if JQT.SetHighlightQuestObjects then JQT:SetHighlightQuestObjects(v) end end
    },
    {
        title = "Quest Item Glow", group = "World", added = "2.0.0",
        text = "A quest item button glows and sparkles when your target is in range for it.",
        get = function() return p().QuestItemGlow ~= false end,
        set = function(v) p().QuestItemGlow = v end
    },
    {
        title = "Quest Icons on Nameplates", group = "World", added = "2.0.0",
        text = "A gold ! by the nameplate of enemies you still need for a quest (nameplates on, V key).",
        get = function() return p().NameplateQuestIcons ~= false end,
        set = function(v) p().NameplateQuestIcons = v; if JQT.UpdateNameplateQuestIcons then JQT:UpdateNameplateQuestIcons() end end
    },
};

-- Extra lines for the "New in" page, per version (things without an on/off switch).
local NEW_NOTES = {
    ["2.0.0"] = "|cffffd100Also new:|r bind a key to |cffffffffUse Quest Item|r (Key Bindings > AddOns > JTS Quest Tracker): it uses the focused or closest quest's item  ·  Safe to try: everything here can be turned off again",
    ["1.5.0"] = "|cffffd100Also new:|r right-click the tracker header > Clean Up Quest Log abandons your grey and failed quests in one go (it lists them first)  ·  /jtsqt cleanup",
    ["1.4.0"] = "|cffffd100Also new:|r Masque can skin the quest item buttons (Masque > JTS Quest Tracker > Quest Items)  ·  right-click a quest for a TomTom waypoint",
};

-- "1.3.10" -> { 1, 3, 10 }; nil when it isn't a version number.
local function parseVersion(version)
    if type(version) ~= "string" or not version:match("^%d") then return nil end

    local parts = {};
    for n in version:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end

    return parts;
end

-- true when a is a newer version than b.
local function newer(a, b)
    local va, vb = parseVersion(a), parseVersion(b);
    if not va or not vb then return false end

    for i = 1, math.max(#va, #vb) do
        local x, y = va[i] or 0, vb[i] or 0;
        if x ~= y then return x > y end
    end

    return false;
end

-- The features added after the version the player last saw (and up to this one).
local function newSince(seen)
    local list = {};

    for _, feature in ipairs(FEATURES) do
        if feature.added and newer(feature.added, seen) and not newer(feature.added, ns.CONSTANTS.VERSION) then
            list[#list + 1] = feature;
        end
    end

    return list;
end

function JQT:GetNewWelcomeFeatures(seen)
    local titles = {};
    for _, feature in ipairs(newSince(seen or self.db.global.WelcomeSeen)) do titles[#titles + 1] = feature.title end

    return titles;
end

-- The order of the sections.
local GROUPS = { "Questing", "World", "Group", "Tracker" };

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
    check.feature = feature;
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false;
        pcall(feature.set, on);
        if PlaySound and SOUNDKIT then pcall(PlaySound, on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    end);

    local title = text(parent, 13, HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 });
    title:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -4);
    title:SetWidth(width - 32);
    local base = tostring(ns.CONSTANTS.VERSION or ""):match("^[%d%.]+");
    local isNew = feature.added and feature.added == base and not parent.isNewPage;
    title:SetText(feature.title .. (isNew and "  |cff33ff99NEW|r" or ""));

    local desc = text(parent, 11, { r = 0.7, g = 0.7, b = 0.7 });
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2);
    desc:SetWidth(width - 32);
    desc:SetText(feature.text);

    checkboxes[#checkboxes + 1] = { check = check, feature = feature };
end

-- One page per section; what each page is about.
local INTROS = {
    Questing = "Help with finding, tracking and finishing quests.",
    Group = "For questing with friends and in dungeons.",
    Tracker = "How the tracker looks and where it sits.",
    World = "Help spotting what your quests need, out in the world.",
};

local TIPS = "|cffffd100Tips:|r middle-click a quest to point WoW's quest arrow at it  ·  right-click quests and headers for menus  ·  Color Blind Mode (all 9 types) is in the settings";

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
    icon:SetPoint("TOPLEFT", 24, -20);

    local heading = text(frame, 20, GREEN);
    heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2);
    heading:SetText("Welcome to JTS Quest Tracker");

    local version = text(frame, 12, { r = 0.6, g = 0.6, b = 0.6 });
    version:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3);
    version:SetText("Version " .. tostring(ns.CONSTANTS.VERSION) .. "  ·  a quick tour of what you can turn on or off. You can change all of it later in the settings.");

    -- Pages: extra sections first (the skin picker), then one per feature section.
    -- `tour` is the full walk-through; `pages` is what is showing (the tour, or the "New in" page).
    local tour = {};
    local pages = tour;
    local top, pageWidth = -86, WIDTH - 48;

    local function newPage(title)
        local page = CreateFrame("Frame", nil, frame);
        page:SetPoint("TOPLEFT", 24, top);
        page:SetPoint("BOTTOMRIGHT", -24, FOOTER);
        page:Hide();

        page.title = text(page, 16, NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 });
        page.title:SetPoint("TOPLEFT", 0, 0);
        page.title:SetText(title);
        page.name = title;

        tour[#tour + 1] = page;

        return page;
    end

    for _, section in ipairs(sections) do
        local page = newPage(section.title);

        local holder = CreateFrame("Frame", nil, page);
        holder:SetPoint("TOPLEFT", 0, -34);
        holder:SetSize(pageWidth, 10);

        local ok, height = pcall(section.build, holder, pageWidth);
        holder:SetHeight(math.max(1, ok and tonumber(height) or 1));
    end

    local columns, rowHeight = 2, 58;
    local columnWidth = (pageWidth - (columns - 1) * 28) / columns;

    for _, group in ipairs(GROUPS) do
        local members = {};
        for _, feature in ipairs(FEATURES) do
            if feature.group == group and not feature.newOnly then members[#members + 1] = feature end
        end

        if #members > 0 then
            local page = newPage(group);

            local intro = text(page, 12, { r = 0.7, g = 0.7, b = 0.7 });
            intro:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4);
            intro:SetText(INTROS[group] or "");

            for i, feature in ipairs(members) do
                local column = (i - 1) % columns;
                local row = math.floor((i - 1) / columns);
                featureRow(page, feature, column * (columnWidth + 28), -50 - row * rowHeight, columnWidth);
            end
        end
    end

    -- Tips on the last page.
    local last = tour[#tour];
    if last then
        local tips = text(last, 11, { r = 0.75, g = 0.75, b = 0.75 });
        tips:SetPoint("BOTTOMLEFT", 0, 4);
        tips:SetWidth(pageWidth);
        tips:SetText(TIPS);
    end

    -- Footer: settings on the left, where you are in the middle, Back / Next on the right.
    local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    settings:SetSize(130, 24);
    settings:SetPoint("BOTTOMLEFT", 24, BUTTONS_Y);
    settings:SetText("All Settings");
    settings:SetScript("OnClick", function()
        frame:Hide();
        JQT:ToggleOptions();
    end);

    local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    nextButton:SetSize(110, 24);
    nextButton:SetPoint("BOTTOMRIGHT", -24, BUTTONS_Y);

    local backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    backButton:SetSize(90, 24);
    backButton:SetPoint("RIGHT", nextButton, "LEFT", -8, 0);
    backButton:SetText("Back");

    local steps = text(frame, 12, { r = 0.55, g = 0.55, b = 0.55 }, "CENTER");
    steps:SetPoint("BOTTOM", 0, BUTTONS_Y + 6);

    local credit = text(frame, 10, { r = 0.45, g = 0.45, b = 0.45 }, "CENTER");
    -- The credit has its own strip under the buttons, with a thin line between them.
    credit:SetPoint("BOTTOM", 0, 9);
    credit:SetWidth(WIDTH - 48);
    credit:SetWordWrap(false);

    local rule = frame:CreateTexture(nil, "ARTWORK");
    rule:SetPoint("BOTTOMLEFT", 24, CREDIT_STRIP);
    rule:SetPoint("BOTTOMRIGHT", -24, CREDIT_STRIP);
    rule:SetHeight(1);
    rule:SetColorTexture(1, 1, 1, 0.08);
    credit:SetText("James's own fork of Butter Quest Tracker by Butter Cookie Kitkat (MIT). Not affiliated with the original author.  ·  /jtsqt welcome");

    local current = 1;
    local newPage; -- the "New in" page, rebuilt for whatever is new since the last visit

    local function showPage(index)
        current = math.max(1, math.min(#pages, index));

        for _, page in ipairs(tour) do page:Hide() end
        if newPage then newPage:Hide() end

        for i, page in ipairs(pages) do
            if i == current then page:Show() end
        end

        local names = {};
        for i, page in ipairs(pages) do
            names[i] = i == current and ("|cff33ff99" .. page.name .. "|r") or page.name;
        end
        steps:SetText(table.concat(names, "   ·   "));

        if current > 1 then backButton:Show() else backButton:Hide() end
        nextButton:SetText(current < #pages and "Next" or "Finish");
    end

    nextButton:SetScript("OnClick", function()
        if current < #pages then showPage(current + 1) else frame:Hide() end
    end);
    backButton:SetScript("OnClick", function() showPage(current - 1) end);

    frame.ShowPage = function(_, index) showPage(index) end;
    frame.GetPage = function() return current, #pages end;

    -- The "New in" page: just the features added since `seen`, with a way into the full tour.
    frame.ShowNew = function(_, seen)
        local features = newSince(seen);
        if #features == 0 then return false end

        if newPage then newPage:Hide() end

        newPage = CreateFrame("Frame", nil, frame);
        newPage:SetPoint("TOPLEFT", 24, top);
        newPage:SetPoint("BOTTOMRIGHT", -24, FOOTER);
        newPage.isNewPage = true;
        newPage.name = "New in " .. (tostring(ns.CONSTANTS.VERSION):match("^[%d%.]+") or tostring(ns.CONSTANTS.VERSION));

        -- Tall enough for everything new (a long list when someone skipped several versions).
        local needed = 86 + 50 + math.ceil(#features / columns) * rowHeight + 40 + 30 + FOOTER;
        if needed > frame:GetHeight() then
            frame:SetHeight(needed);
            local screenHeight = UIParent and UIParent:GetHeight();
            if type(screenHeight) == "number" and screenHeight > 0 and needed > screenHeight * 0.92 then
                frame:SetScale(screenHeight * 0.92 / needed);
            end
        end

        local title = text(newPage, 16, GREEN);
        title:SetPoint("TOPLEFT", 0, 0);
        title:SetText(newPage.name);

        local intro = text(newPage, 12, { r = 0.7, g = 0.7, b = 0.7 });
        intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4);
        intro:SetWidth(pageWidth - 140);
        intro:SetText("New since you last looked" .. (parseVersion(seen) and (" (" .. seen .. ")") or "") .. ". Tick what you'd like on, untick what you don't.");

        local tourButton = CreateFrame("Button", nil, newPage, "UIPanelButtonTemplate");
        tourButton:SetSize(120, 22);
        tourButton:SetPoint("TOPRIGHT", 0, 2);
        tourButton:SetText("Full Tour");
        tourButton:SetScript("OnClick", function()
            pages = tour;
            showPage(1);
        end);
        newPage.tourButton = tourButton;

        local versions = {};
        for i, feature in ipairs(features) do
            local column = (i - 1) % columns;
            local row = math.floor((i - 1) / columns);
            featureRow(newPage, feature, column * (columnWidth + 28), -50 - row * rowHeight, columnWidth);
            versions[feature.added] = true;
        end

        local notes = {};
        for version in pairs(versions) do
            if NEW_NOTES[version] then notes[#notes + 1] = NEW_NOTES[version] end
        end
        table.sort(notes);

        if #notes > 0 then
            local extra = text(newPage, 11, { r = 0.75, g = 0.75, b = 0.75 });
            extra:SetPoint("BOTTOMLEFT", 0, 4);
            extra:SetWidth(pageWidth);
            extra:SetText(table.concat(notes, "\n"));
        end

        for _, entry in ipairs(checkboxes) do
            local ok, value = pcall(entry.feature.get);
            entry.check:SetChecked(ok and value and true or false);
        end

        pages = { newPage };
        showPage(1);

        return true;
    end;

    -- Tall enough for the biggest page, smaller on small screens.
    local tallest = 0;
    for _, group in ipairs(GROUPS) do
        local n = 0;
        for _, feature in ipairs(FEATURES) do if feature.group == group and not feature.newOnly then n = n + 1 end end
        tallest = math.max(tallest, math.ceil(n / columns));
    end

    local height = 86 + 50 + tallest * rowHeight + 40 + FOOTER;
    frame:SetHeight(math.max(HEIGHT, height));

    local screenHeight = UIParent and UIParent:GetHeight();
    if type(screenHeight) == "number" and screenHeight > 0 and frame:GetHeight() > screenHeight * 0.92 then
        frame:SetScale(screenHeight * 0.92 / frame:GetHeight());
    end

    frame:SetScript("OnShow", function()
        for _, entry in ipairs(checkboxes) do
            local ok, value = pcall(entry.feature.get);
            entry.check:SetChecked(ok and value and true or false);
        end

        if not frame.keepPage then
            pages = tour;
            showPage(1);
        end
        frame.keepPage = nil;
    end);

    frame:SetScript("OnHide", function()
        JQT.db.global.WelcomeSeen = ns.CONSTANTS.VERSION;
    end);

    showPage(1);

    return frame;
end

-- onlyNewSince: a version; shows just the "New in" page for features added after it.
function JQT:ShowWelcome(onlyNewSince)
    local ok, window = pcall(build);
    if not ok or not window then
        self:LogError("Welcome screen:", window);
        return;
    end

    if window:IsShown() then window.keepPage = nil end

    if onlyNewSince then
        local shown, hasNew = pcall(window.ShowNew, window, onlyNewSince);
        if shown and hasNew then
            window.keepPage = not window:IsShown();
        elseif not shown then
            self:LogError("Welcome screen:", hasNew);
        end
    end

    window:Show();
end

-- First login: the full tour. A returning player on a version with new features: just those.
-- Shown once things have settled (and never in combat).
hooksecurefunc(JQT, "Initialize", function(self)
    local seen = self.db.global.WelcomeSeen;
    local onlyNew;

    if seen then
        if #newSince(seen) == 0 then
            if newer(ns.CONSTANTS.VERSION, seen) then self.db.global.WelcomeSeen = ns.CONSTANTS.VERSION end
            return;
        end
        onlyNew = seen;
    end

    C_Timer.After(4, function()
        if InCombatLockdown and InCombatLockdown() then
            local wait = CreateFrame("Frame");
            wait:RegisterEvent("PLAYER_REGEN_ENABLED");
            wait:SetScript("OnEvent", function(w) w:UnregisterAllEvents(); JQT:ShowWelcome(onlyNew) end);
        else
            JQT:ShowWelcome(onlyNew);
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
