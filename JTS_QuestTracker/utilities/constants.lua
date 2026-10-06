local NAME, ns = ...

local FALLBACK_VERSION = "1.0.0";
local function getVersion()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata;
    local ok, version = false, nil;

    if type(getter) == "function" then
        ok, version = pcall(getter, NAME, "Version");
    end

    -- "@project-version@" is what the CurseForge packager would have replaced.
    if ok and type(version) == "string" and version ~= "" and not version:find("@", 1, true) then
        return version;
    end

    return FALLBACK_VERSION;
end

local CONSTANTS = {
    VERSION = getVersion(),
    NAME = "JTS Quest Tracker",
    NAME_SQUASHED = "JTS QT",
    BRAND_COLOR = "|cff33ff99",
    PATHS = {}
};

CONSTANTS.PATHS.MEDIA = "Interface\\AddOns\\" .. NAME .. "\\Media\\";
CONSTANTS.PATHS.LOGO = "|T" .. CONSTANTS.PATHS.MEDIA .. "JTS_QT_logo:24:24:0:-8" .. "|t";

CONSTANTS.DB_DEFAULTS = {
    -- Per profile. Every character uses the shared "Default" profile unless it picks another one.
    profile = {
        DisplayDummyData = false,

        -- Filters & Sorting

        DisableFilters = false,
        Sorting = "Disabled",
        CurrentZoneOnly = false,
        HideCompletedQuests = false,
        AutoTrackUpdatedQuests = false,
        AutoHideQuestHelperIcons = false,

        -- Visuals

        BackgroundAlwaysVisible = false,
        BackgroundColor = "7F000000",

        QuestPadding = 10,

        -- Visuals > Tracker Header Font Settings

        TrackerHeaderEnabled = true,
        TrackerHeaderFormat = "QuestsNumberVisibleTotal",
        TrackerHeaderFontSize = 12,
        TrackerHeaderFontColor = "FFD100",

        -- Visuals > Zone Header Font Settings

        ZoneHeaderEnabled = true,
        ZoneSorting = "CurrentThenAlphabetical",
        ZoneHeaderFontSize = 14,
        ZoneHeaderFontColor = "FFD100",

        -- Visuals > Quest Header Font Settings

        ColorHeadersByDifficultyLevel = true,
        QuestLevelDisplay = "Prefix",
        QuestHeaderFormat = "{{title}}",
        QuestHeaderFontSize = 12,
        QuestHeaderFontColor = "FFD100",

        -- Visuals > Objective Font Settings

        ObjectiveFontSize = 12,
        ObjectiveFontColor = "CCCCCC",

        -- Frame Settings

        LockFrame = false,
        ShowScrollBar = true,
        ScrollBarOnHover = false,
        ScrollSpeed = 30,

        -- Visuals > Extras

        ObjectiveColorByProgress = false,
        ObjectiveProgressBars = true,
        FadeCompletedObjectives = true,
        ZoneHeaderQuestCount = true,
        TextOutline = "Outline",
        TextShadow = "Default",
        ColorBlindMode = "Off",
        DifficultyMarkers = "Auto",
        QuestTagStyle = "Short",
        FontFace = "Default",
        SoundObjectiveComplete = "kit:IG_QUEST_LIST_COMPLETE",
        SoundQuestComplete = "kit:READY_CHECK",
        ShowQuestItems = true,
        QuestItemSize = 26,
        QuestItemSide = "Left",
        MinimapIcon = { hide = false, minimapPos = 200 },
        AlertChat = false,
        AlertSound = false,
        AlertFlash = true,
        PositionX = -42.67,
        PositionY = -322.05,
        Width = 250,
        MaxHeight = 450,

        -- Advanced

        DeveloperMode = false,
        DebugLevel = 3
    },

    char = {
        -- Backend

        MANUALLY_TRACKED_QUESTS = {},
        QUESTS_LAST_UPDATED = {},
        PINNED_QUESTS = {},
        CollapsedSections = {},  -- "QUESTS" (whole tracker) and "Z-<zone>" -> true when collapsed
        TrackerHidden = false
    }
};

CONSTANTS.LOGGER = {
    PREFIX = CONSTANTS.BRAND_COLOR .. CONSTANTS.NAME_SQUASHED .. ":|r",
    TYPES = {
        ERROR = {
            COLOR = "|c00FF0000",
            LEVEL = 1
        },
        WARN = {
            COLOR = "|c00FF7F00",
            LEVEL = 2
        },
        INFO = {
            COLOR = "|r",
            LEVEL = 3
        },
        TRACE = {
            COLOR = "|c00ADD8E6",
            LEVEL = 4
        }
    }
};

ns.CONSTANTS = CONSTANTS
