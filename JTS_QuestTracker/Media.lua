local _, ns = ...

--[[
    Fonts and sounds for JTS Quest Tracker.

    Fonts:  the game's own fonts, plus every font another addon has registered with
            LibSharedMedia-3.0 (SharedMedia, ElvUI, ...), if one is installed.
    Sounds: a set of the game's own UI sounds (only the ones this client actually has),
            plus LibSharedMedia sounds, for "objective complete" and "quest complete".

    Saved values look like "game:Friz Quadrata", "jts:Oswald", "lsm:Expressway", "kit:READY_CHECK" or "None".

    Bundled fonts (Fonts\, free licences in Fonts\Licenses): shown after the game's fonts, and
    shared with other addons through LibSharedMedia when it is loaded. Fonts without Cyrillic
    letters are left out on Russian clients, and all of them on Chinese and Korean clients
    (none of them has those letters).
]]

local JQT = JTS_QuestTracker;

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true);
end

-- ---------------------------------------------------------------------------
-- Fonts
-- ---------------------------------------------------------------------------

local GAME_FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
    { name = "2002",          path = "Fonts\\2002.TTF" },
    { name = "2002 Bold",     path = "Fonts\\2002B.TTF" }
};

local FONT_DIR = "Interface\\AddOns\\JTS_QuestTracker\\Fonts\\";

-- name, file, has Cyrillic letters
local BUNDLED_FONTS = {
    { name = "Barlow Semi Condensed", file = "BarlowSemiCondensed-Medium.ttf" },
    { name = "Fira Sans Condensed",   file = "FiraSansCondensed-Medium.ttf", cyrillic = true },
    { name = "PT Sans Narrow",        file = "PT_Sans-Narrow-Web-Bold.ttf", cyrillic = true },
    { name = "Ubuntu Condensed",      file = "UbuntuCondensed-Regular.ttf", cyrillic = true },
    { name = "Oswald",                file = "Oswald-Regular.ttf", cyrillic = true },
    { name = "Titillium Web",         file = "TitilliumWeb-SemiBold.ttf" },
    { name = "Rajdhani",              file = "Rajdhani-SemiBold.ttf" },
    { name = "Alegreya Sans SC",      file = "AlegreyaSansSC-Medium.ttf", cyrillic = true },
    { name = "Cinzel",                file = "Cinzel-Bold.ttf" },
};

-- The bundled fonts this client can show.
local function bundledFonts()
    local locale = GetLocale and GetLocale() or "enUS";
    if locale == "zhCN" or locale == "zhTW" or locale == "koKR" then return {} end

    local list = {};
    for _, font in ipairs(BUNDLED_FONTS) do
        if locale ~= "ruRU" or font.cyrillic then list[#list + 1] = font end
    end

    return list;
end

-- Share them with other addons (and SharedMedia font pickers).
local shared = false;

local function shareBundledFonts()
    local lsm = LSM();
    if shared or not lsm then return end
    shared = true;

    local mask = lsm.LOCALE_BIT_western;
    for _, font in ipairs(bundledFonts()) do
        local fontMask = font.cyrillic and lsm.LOCALE_BIT_ruRU and mask and (mask + lsm.LOCALE_BIT_ruRU) or mask;
        pcall(lsm.Register, lsm, "font", font.name, FONT_DIR .. font.file, fontMask);
    end
end

pcall(shareBundledFonts);
hooksecurefunc(JQT, "Initialize", function() pcall(shareBundledFonts) end);

-- Returns values, sorting for an options dropdown.
function JQT:GetFontChoices()
    local values, sorting = { Default = "Game Default" }, { "Default" };

    for _, font in ipairs(GAME_FONTS) do
        local key = "game:" .. font.name;
        values[key] = font.name;
        sorting[#sorting + 1] = key;
    end

    local ours = {};
    for _, font in ipairs(bundledFonts()) do
        local key = "jts:" .. font.name;
        values[key] = font.name;
        sorting[#sorting + 1] = key;
        ours[font.name] = true;
    end

    local lsm = LSM();
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "font");

        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                local key = "lsm:" .. name;

                -- SharedMedia also lists the game's fonts; don't show those twice.
                local duplicate = false;
                for _, font in ipairs(GAME_FONTS) do
                    if font.name == name then duplicate = true end
                end

                if not duplicate and not values[key] and not ours[name] then
                    values[key] = name .. " |cff888888(SharedMedia)|r";
                    sorting[#sorting + 1] = key;
                end
            end
        end
    end

    -- Keep a saved font that isn't available right now, so the dropdown doesn't look empty.
    local current = self.db and self.db.profile.FontFace;
    if current and not values[current] then
        values[current] = (current:match("^%a+:(.+)$") or current) .. " |cffff7f00(missing)|r";
        sorting[#sorting + 1] = current;
    end

    return values, sorting;
end

-- The font file to use, or nil for the game's default font.
function JQT:GetFontPath()
    local choice = self.db and self.db.profile.FontFace;

    if not choice or choice == "Default" then return nil end

    local source, name = choice:match("^(%a+):(.+)$");

    if source == "game" then
        for _, font in ipairs(GAME_FONTS) do
            if font.name == name then return font.path end
        end
    elseif source == "jts" then
        for _, font in ipairs(bundledFonts()) do
            if font.name == name then return FONT_DIR .. font.file end
        end
    elseif source == "lsm" then
        local lsm = LSM();

        if lsm then
            local ok, path = pcall(lsm.Fetch, lsm, "font", name, true);
            if ok and path then return path end
        end
    end

    return nil;
end

-- ---------------------------------------------------------------------------
-- Sounds
-- ---------------------------------------------------------------------------

-- Game UI sounds by SOUNDKIT name. Any this client doesn't have are simply not listed.
local GAME_SOUNDS = {
    { key = "IG_QUEST_LIST_COMPLETE",    name = "Quest Complete" },
    { key = "IG_QUEST_LIST_OPEN",        name = "Quest Log Open" },
    { key = "IG_QUEST_LOG_OPEN",         name = "Quest Page" },
    { key = "IG_QUEST_LOG_ABANDON_QUEST", name = "Quest Abandon" },
    { key = "READY_CHECK",               name = "Ready Check" },
    { key = "RAID_WARNING",              name = "Raid Warning" },
    { key = "ALARM_CLOCK_WARNING_3",     name = "Alarm Clock" },
    { key = "MAP_PING",                  name = "Map Ping" },
    { key = "TELL_MESSAGE",              name = "Whisper" },
    { key = "IG_PLAYER_INVITE",          name = "Group Invite" },
    { key = "UI_BNET_TOAST",             name = "Friend Toast" },
    { key = "LEVELUPSOUND",              name = "Level Up" },
    { key = "UI_RAID_BOSS_WHISPER_WARNING", name = "Boss Whisper" },
    { key = "PVP_THROUGH_QUEUE",         name = "Queue Pop" },
    { key = "AUCTION_WINDOW_OPEN",       name = "Auction House" },
    { key = "IG_MAINMENU_OPEN",          name = "Menu Open" },
    { key = "IG_CHARACTER_INFO_TAB",     name = "Click" },
    { key = "U_CHAT_SCROLL_BUTTON",      name = "Tick" }
};

function JQT:GetSoundChoices()
    local values, sorting = { None = "None" }, { "None" };

    for _, sound in ipairs(GAME_SOUNDS) do
        if SOUNDKIT and SOUNDKIT[sound.key] then
            local key = "kit:" .. sound.key;
            values[key] = sound.name;
            sorting[#sorting + 1] = key;
        end
    end

    local lsm = LSM();
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "sound");

        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                local key = "lsm:" .. name;

                if name ~= "None" and not values[key] then
                    values[key] = name .. " |cff888888(SharedMedia)|r";
                    sorting[#sorting + 1] = key;
                end
            end
        end
    end

    return values, sorting;
end

-- Plays a saved sound choice. Uses the Master channel so it is heard even with effects turned down.
function JQT:PlaySoundChoice(choice)
    if not choice or choice == "None" then return end

    local source, name = choice:match("^(%a+):(.+)$");

    if source == "kit" then
        if SOUNDKIT and SOUNDKIT[name] then
            pcall(PlaySound, SOUNDKIT[name], "Master");
        end
    elseif source == "lsm" then
        local lsm = LSM();

        if lsm then
            local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true);

            if ok and path then
                pcall(PlaySoundFile, path, "Master");
            end
        end
    end
end

-- Called by the objective complete alert. questComplete = the whole quest is now ready to turn in.
function JQT:PlayAlertSound(questComplete)
    local p = self.db.profile;

    self:PlaySoundChoice(questComplete and p.SoundQuestComplete or p.SoundObjectiveComplete);
end
