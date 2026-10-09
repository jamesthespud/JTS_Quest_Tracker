local _, ns = ...

local ACD = LibStub("AceConfigDialog-3.0");
local QH = LibStub("JTSQTQuestHelpers-1.0");
local JQTL = JTS_QuestTrackerLocale;
local JQT = JTS_QuestTracker;

-- ---------------------------------------------------------------------------
-- Helpers for building the options table
-- ---------------------------------------------------------------------------

local _order = 0;
local function O(option)
    _order = _order + 1;
    option.order = _order;

    return option;
end

local function L(key)
    return JQTL:GetStringWrap(key);
end

local function Spacer(width, size)
    return O{ type = "description", name = " ", fontSize = size or "small", width = width or "full" };
end

local function Group(name, args)
    return O{ name = name, type = "group", inline = true, args = args };
end

local function GetFromDB(info)
    return JQT.db.profile[info.arg];
end

local function SetInDB(info, value)
    JQT.db.profile[info.arg] = value;
end

local function SetAndRefreshQuestWatch(info, value)
    SetInDB(info, value);
    JQT:RefreshQuestWatch();
end

local function SetAndRefreshView(info, value)
    SetInDB(info, value);
    JQT:RefreshView();
end

-- Saves the value and passes it straight to the tracker frame as `key`.
local function SetTracker(key)
    return function(info, value)
        SetInDB(info, value);
        JQT.tracker:UpdateSettings({ [key] = value });
    end
end

local function Off(arg) return function() return not JQT.db.profile[arg] end end
local function On(arg) return function() return JQT.db.profile[arg] end end

-- Colors are saved as "RRGGBB" or "AARRGGBB" hex strings.
local function GetColor(info)
    local hex = JQT.db.profile[info.arg]:gsub("#", "");
    local a = 1;

    if #hex == 8 then
        a, hex = tonumber(hex:sub(1, 2), 16) / 255, hex:sub(3);
    end

    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, a;
end

local function SetColor(info, r, g, b, a)
    local hex = ("%02X%02X%02X"):format(r * 255, g * 255, b * 255);

    JQT.db.profile[info.arg] = a and (("%02X"):format(a * 255) .. hex) or hex;
end

local function FontSize(arg, max, disabled)
    return O{ name = L('SETTINGS_FONT_SIZE_NAME'), arg = arg, type = "range", min = 4, max = max or 20, step = 1,
        set = SetAndRefreshView, disabled = disabled };
end

local function FontColor(arg, disabled)
    return O{ name = L('SETTINGS_FONT_COLOR_NAME'), arg = arg, type = "color", hasAlpha = false, get = GetColor,
        set = function(info, r, g, b) SetColor(info, r, g, b); JQT:RefreshView(); end, disabled = disabled };
end

-- A dropdown whose choices come from a function returning values, sorting.
local function Choices(source)
    return function() return (source()) end, function() return select(2, source()) end;
end

local function SoundPicker(arg, name, desc)
    local values, sorting = Choices(function() return JQT:GetSoundChoices() end);

    return O{ name = name, desc = desc, arg = arg, type = "select", width = 1.6, values = values, sorting = sorting,
        set = function(info, value) SetInDB(info, value); JQT:PlaySoundChoice(value); end,
        disabled = Off("AlertSound") };
end

local function SoundPreview(arg)
    return O{ name = "Play", desc = "Plays the chosen sound.", type = "execute", width = 0.5,
        func = function() JQT:PlaySoundChoice(JQT.db.profile[arg]) end, disabled = Off("AlertSound") };
end

-- Other files add their own tabs with JQT:AddOptionsTab(key, builder).
JQT.optionsTabs = JQT.optionsTabs or {};

function JQT:AddOptionsTab(key, builder)
    self.optionsTabs[key] = builder;
end

-- ---------------------------------------------------------------------------
-- The options
-- ---------------------------------------------------------------------------

local function sortingChoices()
    local values = {
        Disabled = JQTL:GetString('SETTINGS_SORTING_DISABLED_OPTION'),
        ByLevel = JQTL:GetString('SETTINGS_SORTING_BY_LEVEL_OPTION'),
        ByLevelReversed = JQTL:GetString('SETTINGS_SORTING_BY_LEVEL_REVERSED_OPTION'),
        ByPercentCompleted = JQTL:GetString('SETTINGS_SORTING_BY_PERCENT_COMPLETED_OPTION'),
        ByRecentlyUpdated = JQTL:GetString('SETTINGS_SORTING_BY_RECENTLY_UPDATED_OPTION')
    };
    local sorting = { "Disabled", "ByLevel", "ByLevelReversed", "ByPercentCompleted", "ByRecentlyUpdated" };

    if QH:IsSupported() then
        values.ByQuestProximity = JQTL:GetString('SETTINGS_SORTING_BY_QUEST_PROXIMITY_OPTION');
        sorting[#sorting + 1] = "ByQuestProximity";
    end

    return values, sorting;
end

-- A category in the sidebar.
local function Category(name, order, args)
    return { name = name, type = "group", order = order, args = args };
end

-- ---------------------------------------------------------------------------
-- Tracking: what is shown and in which order
-- ---------------------------------------------------------------------------

local function trackingCategory()
    local sortValues, sortOrder = Choices(sortingChoices);

    return Category(L('SETTINGS_FILTERS_AND_SORTING_TAB'), 1, {
        sortingGroup = Group("Sorting", {
            sorting = O{ name = L('SETTINGS_SORTING_NAME'), desc = L('SETTINGS_SORTING_DESC'), arg = "Sorting", type = "select",
                values = sortValues, sorting = sortOrder,
                set = function(info, value)
                    SetInDB(info, value);
                    JQT:UpdateQuestProximityTimer();
                    if value ~= "ByQuestProximity" then JQT:Sort() end
                end },
            zoneSorting = O{ name = "Zone Order",
                desc = "Current zone first, then A-Z keeps the groups in a steady order. \"By quest order\" puts zones in the order of their first quest under your chosen sorting.",
                arg = "ZoneSorting", type = "select", width = 1.5,
                values = { CurrentThenAlphabetical = "Current zone first, then A-Z", ByQuestOrder = "By quest order" },
                set = SetAndRefreshView, disabled = Off("ZoneHeaderEnabled") },
            spacer1 = Spacer(),
            autoHideQuestHelperIcons = O{ name = L('SETTINGS_AUTO_HIDE_QUEST_HELPER_ICONS_NAME'),
                desc = function() return JQTL:GetString('SETTINGS_AUTO_HIDE_QUEST_HELPER_ICONS_DESC', table.concat(QH:GetActiveAddons(), ", ")) end,
                arg = "AutoHideQuestHelperIcons", type = "toggle", width = 1.6,
                disabled = function() return not QH:IsSupported() end,
                set = function(info, value) SetInDB(info, value); QH:SetAutoHideQuestHelperIcons(value); end },
        }),

        focusGroup = JQT.focusOptions and (function()
            local group = JQT.focusOptions();
            group.order = 1000000; -- after Sorting and Filters
            return group;
        end)() or nil,

        filtersGroup = Group("Filters", {
            autoTrackUpdatedQuests = O{ name = L('SETTINGS_AUTO_TRACK_UPDATED_QUESTS_NAME'), desc = L('SETTINGS_AUTO_TRACK_UPDATED_QUESTS_DESC'),
                arg = "AutoTrackUpdatedQuests", type = "toggle", width = 1.6,
                set = function(info, value) SetInDB(info, value); if not value then JQT:ResetOverrides() end end },
            disableFilters = O{ name = L('SETTINGS_DISABLE_FILTERS_NAME'), desc = L('SETTINGS_DISABLE_FILTERS_DESC'),
                arg = "DisableFilters", type = "toggle", width = 1.6,
                set = function(info, value)
                    if value == false then JQT:ResetOverrides() end
                    SetAndRefreshQuestWatch(info, value);
                end },
            currentZoneOnly = O{ name = L('SETTINGS_CURRENT_ZONE_ONLY_NAME'), desc = L('SETTINGS_CURRENT_ZONE_ONLY_DESC'),
                arg = "CurrentZoneOnly", type = "toggle", width = 1.6, disabled = On("DisableFilters"), set = SetAndRefreshQuestWatch },
            hideCompletedQuests = O{ name = L('SETTINGS_HIDE_COMPLETED_QUESTS_NAME'), desc = L('SETTINGS_HIDE_COMPLETED_QUESTS_DESC'),
                arg = "HideCompletedQuests", type = "toggle", width = 1.6, disabled = On("DisableFilters"), set = SetAndRefreshQuestWatch },
            spacer1 = Spacer(),
            reset = O{ name = L('SETTINGS_RESET_TRACKING_OVERRIDES_NAME'), desc = L('SETTINGS_RESET_TRACKING_OVERRIDES_DESC'),
                type = "execute", width = 1.3, func = function() JQT:ResetOverrides() end },
        }),
    });
end

-- ---------------------------------------------------------------------------
-- Appearance: text, headers, quest names and objectives
-- ---------------------------------------------------------------------------

local function appearanceCategory()
    local fontValues, fontOrder = Choices(function() return JQT:GetFontChoices() end);

    return Category("Appearance", 2, {
        previewGroup = Group("Preview", {
            displayDummyData = O{ name = L('SETTINGS_DISPLAY_DUMMY_DATA_NAME'), desc = L('SETTINGS_DISPLAY_DUMMY_DATA_DESC'),
                arg = "DisplayDummyData", type = "toggle", width = "full", set = SetAndRefreshView },
        }),

        textStyleSettings = Group("Text", {
            fontFace = O{ name = "Font",
                desc = "The font used for all tracker text. Fonts from SharedMedia (or any addon that shares fonts with it) show up here too.",
                arg = "FontFace", type = "select", width = 2.4, values = fontValues, sorting = fontOrder,
                set = function(info, value) SetInDB(info, value); JQT:ApplyTextStyle(); JQT:RefreshView(); end },
            spacer1 = Spacer(),
            textOutline = O{ name = "Outline", desc = "Draws an outline around all tracker text. It helps when the tracker sits over a busy background.",
                arg = "TextOutline", type = "select", width = 1.2,
                values = { None = "None", Outline = "Outline", Thick = "Thick Outline" }, set = SetAndRefreshView },
            textShadow = O{ name = "Shadow", desc = "\"Default\" keeps the game's own text shadow.",
                arg = "TextShadow", type = "select", width = 1.2,
                values = { Default = "Default", Strong = "Strong", Off = "Off" }, set = SetAndRefreshView },
        }),

        trackerHeaderSettings = Group("Tracker Header", {
            enabled = O{ name = L('SETTINGS_ENABLED_NAME'), desc = L('SETTINGS_TRACKER_HEADER_ENABLED_DESC'),
                arg = "TrackerHeaderEnabled", type = "toggle", set = SetAndRefreshView },
            spacer1 = Spacer(1.1),
            format = O{ name = L('SETTINGS_FORMAT_NAME'), desc = L('SETTINGS_TRACKER_HEADER_FORMAT_DESC'),
                arg = "TrackerHeaderFormat", type = "select",
                values = function()
                    return {
                        Quests = JQTL:GetString('SETTINGS_TRACKER_HEADER_FORMAT_QUESTS_OPTION'),
                        QuestsNumberVisible = JQTL:GetString('SETTINGS_TRACKER_HEADER_FORMAT_QUESTS_NUMBER_VISIBLE_OPTION'),
                        QuestsNumberVisibleTotal = JQTL:GetString('SETTINGS_TRACKER_HEADER_FORMAT_QUESTS_NUMBER_VISIBLE_TOTAL_OPTION')
                    };
                end,
                sorting = { "Quests", "QuestsNumberVisible", "QuestsNumberVisibleTotal" },
                set = SetAndRefreshView, disabled = Off("TrackerHeaderEnabled") },
            spacer2 = Spacer(),
            fontSize = FontSize("TrackerHeaderFontSize", 20, Off("TrackerHeaderEnabled")),
            spacer3 = Spacer(1.1),
            fontColor = FontColor("TrackerHeaderFontColor", Off("TrackerHeaderEnabled")),
        }),

        zoneHeaderSettings = Group("Zone Headers", {
            enabled = O{ name = L('SETTINGS_ENABLED_NAME'), desc = L('SETTINGS_ZONE_HEADER_ENABLED_DESC'),
                arg = "ZoneHeaderEnabled", type = "toggle", set = SetAndRefreshView },
            spacer1 = Spacer(1.1),
            questCount = O{ name = "Show Quest Count", desc = "Shows how many tracked quests are in each zone, like Elwynn Forest (3).",
                arg = "ZoneHeaderQuestCount", type = "toggle", width = 1.4, set = SetAndRefreshView, disabled = Off("ZoneHeaderEnabled") },
            spacer2 = Spacer(),
            fontSize = FontSize("ZoneHeaderFontSize", 24, Off("ZoneHeaderEnabled")),
            spacer3 = Spacer(1.1),
            fontColor = FontColor("ZoneHeaderFontColor", Off("ZoneHeaderEnabled")),
        }),

        questHeaderSettings = Group("Quest Names", {
            format = O{ name = L('SETTINGS_FORMAT_NAME'), desc = L('SETTINGS_QUEST_HEADER_FORMAT_DESC'),
                arg = "QuestHeaderFormat", type = "input", set = SetAndRefreshView },
            spacer1 = Spacer(0.1),
            questLevel = O{ name = "Show Quest Level",
                desc = "Adds the quest's level (the level it is meant for) to the quest name.\n\n|c00FF9696Before name|r: [12] Quest Name\n|c00FF9696After name|r: Quest Name (12)\n\nIgnored if your Format already contains {{level}}.",
                arg = "QuestLevelDisplay", type = "select", width = 1.4,
                values = { None = "Off", Prefix = "Before name  [12] Name", Suffix = "After name  Name (12)" },
                set = SetAndRefreshView },
            questTags = O{ name = "Quest Tags",
                desc = "Shows the quest's type after its name.\n\n|cffffffffShort|r: [E] Elite, [G3] Group of 3, [D] Dungeon, [R] Raid, [PvP], [H] Heroic, [L] Legendary\n|cffffffffFull|r: (Elite), (Group 3), (Dungeon), ...",
                arg = "QuestTagStyle", type = "select", width = 1.4,
                values = { Off = "Off", Short = "Short  [E] [G3] [D]", Full = "Full  (Elite) (Group 3)" },
                sorting = { "Off", "Short", "Full" }, set = SetAndRefreshView },
            spacer2 = Spacer(),
            colorHeadersByDifficultyLevel = O{ name = L('SETTINGS_COLOR_HEADERS_BY_DIFFICULTY_NAME'), desc = L('SETTINGS_COLOR_HEADERS_BY_DIFFICULTY_DESC'),
                arg = "ColorHeadersByDifficultyLevel", type = "toggle", width = 1.4, set = SetAndRefreshView },
            spacer3 = Spacer(0.7),
            fontColor = FontColor("QuestHeaderFontColor", On("ColorHeadersByDifficultyLevel")),
            spacer4 = Spacer(),
            fontSize = FontSize("QuestHeaderFontSize"),
            spacer5 = Spacer(1.1),
            questPadding = O{ name = L('SETTINGS_QUEST_PADDING_NAME'), arg = "QuestPadding", type = "range",
                min = 0, max = 20, step = 1, set = SetAndRefreshView },
        }),

        objectiveSettings = Group("Objectives", {
            fontSize = FontSize("ObjectiveFontSize"),
            spacer3 = Spacer(1.1),
            fontColor = FontColor("ObjectiveFontColor", On("ObjectiveColorByProgress")),
            spacerExtras = Spacer(),
            colorByProgress = O{ name = "Color by Progress",
                desc = "Colors each objective from red (just started) through yellow to green (done). Color Blind Mode swaps these for colors you can tell apart.",
                arg = "ObjectiveColorByProgress", type = "toggle", width = 1.4, set = SetAndRefreshView },
            progressBars = O{ name = "Progress Bars", desc = "Draws a thin bar under objectives that count something, like 5/20.",
                arg = "ObjectiveProgressBars", type = "toggle", width = 1.4, set = SetAndRefreshView },
            progressBarHeight = O{ name = "Progress Bar Thickness", desc = "How thick the progress bars are, in pixels. Default is 3.",
                arg = "ProgressBarHeight", type = "range", width = 1.4, min = 2, max = 6, step = 1,
                set = SetAndRefreshView, disabled = Off("ObjectiveProgressBars") },
            fadeCompleted = O{ name = "Fade Finished Objectives",
                desc = "Shows objectives you have already finished dimmer, so the ones still to do stand out.",
                arg = "FadeCompletedObjectives", type = "toggle", width = 1.4, set = SetAndRefreshView },
        }),
    });
end

-- ---------------------------------------------------------------------------
-- Color blind mode
-- ---------------------------------------------------------------------------

local function colorBlindCategory()
    local cbValues, cbOrder = Choices(function() return JQT:GetColorBlindModeValues() end);

    return Category("Color Blind Mode", 3, {
        colorBlindSettings = Group("Color Blind Mode", {
            colorBlindMode = O{ name = "Color Blind Mode",
                desc = "Swaps every color the tracker uses to show meaning (quest difficulty, objective progress, progress bars, Ready to Turn In, Failed and the complete flash) for colors that stay easy to tell apart with your type of color vision. Your own text colors are not changed.\n\nIf you use the game's own color blind filter, use that or this mode, not both.",
                arg = "ColorBlindMode", type = "select", width = 2.3, values = cbValues, sorting = cbOrder, set = SetAndRefreshView },
            difficultyMarkers = O{ name = "Difficulty Markers",
                desc = "Adds a mark after each quest name so you can see its difficulty without relying on color:\n\n|cffffffff!!|r  very hard\n|cffffffff!|r  hard\n(nothing)  normal\n|cffffffff-|r  easy\n|cffffffff--|r  too easy\n\n|cffffffffAuto|r turns them on for the no-color modes (Achromatopsia, Blue Cone Monochromacy, Achromatomaly).",
                arg = "DifficultyMarkers", type = "select", width = 1.2,
                values = { Auto = "Auto", On = "On", Off = "Off" }, sorting = { "Auto", "On", "Off" }, set = SetAndRefreshView },
        }),
    });
end

-- ---------------------------------------------------------------------------
-- Alerts
-- ---------------------------------------------------------------------------

local function alertsCategory()
    return Category("Alerts", 4, {
        alertSettings = Group("Objective Complete Alert", {
            alertFlash = O{ name = "Flash", desc = "Briefly highlights a quest in the tracker when you finish one of its objectives.",
                arg = "AlertFlash", type = "toggle", width = 0.8, set = SetInDB },
            alertChat = O{ name = "Chat Message", desc = "Prints a line in your chat window when you finish an objective.",
                arg = "AlertChat", type = "toggle", width = 1.0, set = SetInDB },
            alertSound = O{ name = "Sound", desc = "Plays a sound when you finish an objective. The game may already play its own.",
                arg = "AlertSound", type = "toggle", width = 0.8, set = SetInDB },
            soundObjective = SoundPicker("SoundObjectiveComplete", "Objective Complete Sound",
                "Played when you finish one objective of a quest. Sounds from SharedMedia show up here too."),
            soundObjectivePreview = SoundPreview("SoundObjectiveComplete"),
            soundQuest = SoundPicker("SoundQuestComplete", "Quest Complete Sound", "Played when a whole quest is ready to turn in."),
            soundQuestPreview = SoundPreview("SoundQuestComplete"),
        }),
    });
end

-- ---------------------------------------------------------------------------
-- Window: position, size, background and scrolling
-- ---------------------------------------------------------------------------

local function windowCategory()
    -- Positions are saved as negative offsets from the top right corner, but shown as positive numbers.
    local function Position(arg, axis, max)
        return O{ name = L('SETTINGS_POSITION' .. axis:upper() .. '_NAME'), arg = arg, type = "range", width = 1.6,
            min = 0, max = max, step = 0.01, bigStep = 10,
            get = function(info) return -GetFromDB(info) end,
            set = function(info, value)
                SetInDB(info, -value);
                JQT.tracker:UpdateSettings({ position = { [axis] = -value } });
            end };
    end

    local defaults = ns.CONSTANTS.DB_DEFAULTS.profile;

    return Category(L('SETTINGS_FRAME_TAB'), 5, {
        positionGroup = Group("Position & Size", {
            lockFrame = O{ name = L('SETTINGS_LOCK_FRAME_NAME'), desc = L('SETTINGS_LOCK_FRAME_DESC'),
                arg = "LockFrame", type = "toggle",
                set = function(info, value) SetInDB(info, value); JQT:ApplyLock(); end },
            lockInCombat = O{ name = "Lock in Combat",
                desc = "Stops the tracker from being dragged while you are in combat, so a stray click in a fight can't move it. If you are dragging it when combat starts, it is dropped where it is.",
                arg = "LockInCombat", type = "toggle", width = 1.2,
                set = function(info, value) SetInDB(info, value); JQT:ApplyLock(); end,
                disabled = On("LockFrame") },
            spacer0 = Spacer(),
            positionX = Position("PositionX", "x", math.ceil(GetScreenWidth())),
            positionY = Position("PositionY", "y", math.ceil(GetScreenHeight())),
            spacer1 = Spacer(),
            width = O{ name = L('SETTINGS_WIDTH_NAME'), arg = "Width", type = "range", width = 1.6,
                min = 100, max = 400, step = 1, bigStep = 10, set = SetTracker("width") },
            maxHeight = O{ name = L('SETTINGS_MAX_HEIGHT_NAME'), arg = "MaxHeight", type = "range", width = 1.6,
                min = 100, max = math.ceil(GetScreenHeight() * UIParent:GetEffectiveScale()), step = 1, bigStep = 10,
                set = SetTracker("maxHeight") },
            spacer2 = Spacer(),
            resetPosition = O{ name = L('SETTINGS_RESET_POSITION_NAME'), type = "execute", width = 0.8,
                func = function()
                    local p = JQT.db.profile;
                    p.PositionX, p.PositionY = defaults.PositionX, defaults.PositionY;
                    JQT.tracker:UpdateSettings({ position = { x = p.PositionX, y = p.PositionY } });
                end },
            resetSize = O{ name = L('SETTINGS_RESET_SIZE_NAME'), type = "execute", width = 0.7,
                func = function()
                    local p = JQT.db.profile;
                    p.Width, p.MaxHeight = defaults.Width, defaults.MaxHeight;
                    JQT.tracker:UpdateSettings({ width = p.Width, maxHeight = p.MaxHeight });
                end },
        }),

        backgroundGroup = Group("Background", {
            backgroundAlwaysVisible = O{ name = L('SETTINGS_BACKGROUND_ALWAYS_VISIBLE_NAME'), desc = L('SETTINGS_BACKGROUND_ALWAYS_VISIBLE_DESC'),
                arg = "BackgroundAlwaysVisible", type = "toggle", width = 2.3,
                set = function(info, value)
                    SetInDB(info, value);
                    JQT.tracker:UpdateSettings({ backgroundVisible = JQT.db.profile.DeveloperMode or value });
                end },
            backgroundColor = O{ name = L('SETTINGS_BACKGROUND_COLOR_NAME'), desc = L('SETTINGS_BACKGROUND_COLOR_DESC'),
                arg = "BackgroundColor", type = "color", hasAlpha = true, get = GetColor,
                set = function(info, r, g, b, a)
                    SetColor(info, r, g, b, a);
                    JQT.tracker:UpdateSettings({ backgroundColor = JQT.db.profile.BackgroundColor });
                end },
        }),

        scrollGroup = Group("Scrolling", {
            showScrollBar = O{ name = "Show Scroll Bar",
                desc = "Shows a slim bar on the right edge of the tracker while you scroll with the mouse wheel, so you can see where you are in a long list. It fades away a moment after you stop, and only appears when there is something to scroll.",
                arg = "ShowScrollBar", type = "toggle", width = 2.3, set = SetTracker("scrollBar") },
            scrollBarOnHover = O{ name = "Keep Scroll Bar Visible on Hover",
                desc = "Keeps the scroll bar up for as long as your mouse is over the tracker, so you can grab it and drag. Needs Show Scroll Bar.",
                arg = "ScrollBarOnHover", type = "toggle", width = 2.3, set = SetTracker("scrollBarOnHover"), disabled = Off("ShowScrollBar") },
            scrollSpeed = O{ name = "Scroll Speed",
                desc = "How far the tracker moves for each notch of the mouse wheel, in pixels. Higher is faster. Default is 30.",
                arg = "ScrollSpeed", type = "range", width = 1.6, min = 10, max = 100, step = 1, bigStep = 5, set = SetTracker("scrollSpeed") },
        }),
    });
end

-- ---------------------------------------------------------------------------
-- Advanced: language, developer tools and reset
-- ---------------------------------------------------------------------------

local function advancedCategory()
    return Category(L('SETTINGS_ADVANCED_TAB'), 2000, {
        localeGroup = Group(L('SETTINGS_LOCALE_HEADER'), {
            locale = O{ name = L('SETTINGS_LOCALE_NAME'), type = "select", style = "dropdown",
                values = { enUS = "English", ruRU = "русский", zhCN = "简体中文" },
                get = function() return JQTL:GetLocale() end,
                set = function(_, locale)
                    JQT.db.profile.Locale = locale;
                    JQTL:SetLocale(locale);
                    JQT:RefreshView();
                end },
        }),

        developerGroup = Group(L('SETTINGS_DEVELOPER_HEADER'), {
            developerMode = O{ name = L('SETTINGS_DEVELOPER_MODE_NAME'), desc = L('SETTINGS_DEVELOPER_MODE_DESC'),
                arg = "DeveloperMode", type = "toggle",
                set = function(info, value)
                    SetAndRefreshView(info, value);
                    JQT.tracker:UpdateSettings({ backgroundVisible = JQT.db.profile.BackgroundAlwaysVisible or value });
                end },
            spacer1 = Spacer(0.2),
            debugLevel = O{ name = L('SETTINGS_DEBUG_LEVEL_NAME'), desc = "ERROR = 1\nWARN = 2\nINFO = 3\nTRACE = 4",
                arg = "DebugLevel", type = "range", min = 1, max = 4, step = 1, disabled = Off("DeveloperMode") },
        }),

        resetGroup = Group(L('SETTINGS_RESET_HEADER'), {
            resetDescription = O{ name = L('SETTINGS_RESET_TEXT'), type = "description", fontSize = "medium" },
            reset = O{ name = L('SETTINGS_RESET_NAME'), desc = L('SETTINGS_RESET_DESC'), type = "execute", width = 1.0,
                func = function()
                    JQT.db:ResetProfile();

                    for k, v in pairs(ns.CONSTANTS.DB_DEFAULTS.char) do
                        JQT.db.char[k] = type(v) == "table" and {} or v;
                    end

                    JQT:SetTrackerHidden(JQT.db.char.TrackerHidden);
                    JQT:ApplyAllSettings();
                end },
        }),

        spacer8 = Spacer(),
        advert = O{ name = L('SETTINGS_ADVERT_TEXT'), type = "description", fontSize = "medium" },
    });
end

LibStub("AceConfig-3.0"):RegisterOptionsTable("JTS_QuestTracker", function()
    local options = {
        name = function() return JQTL:GetString('SETTINGS_NAME', ns.CONSTANTS.VERSION) end,
        type = "group",
        childGroups = "tree", -- categories in a sidebar, like Blizzard's own options
        get = GetFromDB,
        set = SetInDB,

        args = {
            tracking = trackingCategory(),
            appearance = appearanceCategory(),
            colorBlind = colorBlindCategory(),
            alerts = alertsCategory(),
            window = windowCategory(),
            advanced = advancedCategory(),
        }
    };

    for key, builder in pairs(JQT.optionsTabs) do
        local ok, tab = pcall(builder);

        if ok and type(tab) == "table" then
            options.args[key] = tab;
        end
    end

    return options;
end);

-- ---------------------------------------------------------------------------
-- Showing the options (Esc > Options > AddOns, or AceConfigDialog's own window as a fallback)
-- ---------------------------------------------------------------------------

local ok, _, optionsCategoryID = pcall(ACD.AddToBlizOptions, ACD, "JTS_QuestTracker");
if not ok then optionsCategoryID = nil end

-- When "display dummy data" is on, the tracker shows sample quests while the options are open.
function JQT:HookOptionsPanels()
    if self.optionsHooked or not SettingsPanel then return end
    self.optionsHooked = true;

    local function refresh()
        if JQT.db and JQT.db.profile.DisplayDummyData and JQT.tracker then
            JQT:RefreshView();
        end
    end

    SettingsPanel:HookScript("OnShow", refresh);
    SettingsPanel:HookScript("OnHide", refresh);
end
JQT:HookOptionsPanels();

function JQT:IsOptionsShown()
    return (SettingsPanel and SettingsPanel:IsShown()) or (ACD.OpenFrames and ACD.OpenFrames["JTS_QuestTracker"] ~= nil) or false;
end

function JQT:ToggleOptions()
    if self:IsOptionsShown() then
        if SettingsPanel and SettingsPanel:IsShown() then
            pcall(HideUIPanel, SettingsPanel);
        end

        pcall(ACD.Close, ACD, "JTS_QuestTracker");
        return;
    end

    if optionsCategoryID and Settings and Settings.OpenToCategory and pcall(Settings.OpenToCategory, optionsCategoryID) then
        return;
    end

    ACD:Open("JTS_QuestTracker");
end

-- ---------------------------------------------------------------------------
-- /jtsqt
-- ---------------------------------------------------------------------------

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

SLASH_JTS_QUESTTRACKER1 = '/jtsqt'
SlashCmdList['JTS_QUESTTRACKER'] = function(command)
    command = (command or ""):match("^%s*(.-)%s*$"):lower();

    if command == "" or command == "options" or command == "config" then
        JQT:ToggleOptions();
    elseif command == "reset" then
        JQT:ResetOverrides();
        say("Tracking overrides were reset.");
    elseif command == "status" or command == "debug" then
        JQT:PrintStatus();
    elseif command == "toggle" then
        JQT:ToggleTrackerVisibility();
    elseif command == "show" then
        JQT:SetTrackerHidden(false);
    elseif command == "hide" then
        JQT:SetTrackerHidden(true);
    elseif command == "minimap" then
        local icon = JQT.db.profile.MinimapIcon;
        icon.hide = not icon.hide;
        JQT:UpdateMinimapButton();
        say(icon.hide and "Minimap button hidden." or "Minimap button shown.");
    else
        say("Usage: /jtsqt [options | toggle | show | hide | minimap | reset | status]");
    end
end
