local _, ns = ...

--[[
    Fonts and sounds for JTS Quest Tracker.

    Fonts:  the game's own fonts, plus every font another addon has registered with
            LibSharedMedia-3.0 (SharedMedia, ElvUI, ...), if one is installed.
    Sounds: a set of the game's own UI sounds (only the ones this client actually has),
            plus LibSharedMedia sounds, for "objective complete" and "quest complete".

    Saved values look like "game:Friz Quadrata", "lsm:Expressway", "kit:READY_CHECK" or "None".

    The default font is "auto:Expressway": Expressway when another addon shares it through
    LibSharedMedia (ElvUI and most media packs do), otherwise the game's own font. Expressway's
    licence doesn't allow shipping the font file with the addon, so it is never bundled.
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

local PREFERRED = "Expressway";

local function fetchShared(name)
    local lsm = LSM();
    if not lsm then return nil end

    local ok, path = pcall(lsm.Fetch, lsm, "font", name, true);

    return ok and path or nil;
end

function JQT:HasExpressway()
    return fetchShared(PREFERRED) ~= nil;
end

-- Returns values, sorting for an options dropdown.
function JQT:GetFontChoices()
    local values, sorting = { Default = "Game Default" }, { "auto:" .. PREFERRED, "Default" };

    values["auto:" .. PREFERRED] = PREFERRED .. (self:HasExpressway()
        and " |cff888888(recommended)|r"
        or " |cff888888(not installed: using the game font)|r");

    for _, font in ipairs(GAME_FONTS) do
        local key = "game:" .. font.name;
        values[key] = font.name;
        sorting[#sorting + 1] = key;
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

                if not duplicate and not values[key] and name ~= PREFERRED then
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

    if source == "auto" then
        return fetchShared(name);
    elseif source == "game" then
        for _, font in ipairs(GAME_FONTS) do
            if font.name == name then return font.path end
        end
    elseif source == "lsm" then
        return fetchShared(name);
    end

    return nil;
end

-- Fonts can be shared after the tracker has drawn (another addon loading later): when the one
-- we're waiting for turns up, use it.
local listener = {};

local function watchSharedFonts()
    local lsm = LSM();
    if not lsm or listener.watching or type(lsm.RegisterCallback) ~= "function" then return end
    listener.watching = true;

    lsm.RegisterCallback(listener, "LibSharedMedia_Registered", function(_, mediaType, name)
        if mediaType ~= "font" or not JQT.db then return end

        local choice = JQT.db.profile.FontFace;
        local wanted = choice and choice:match("^%a+:(.+)$");

        if wanted == name and JQT.ApplyTextStyle then
            JQT:ApplyTextStyle();
            if JQT.tracker then JQT:RefreshView() end
        end
    end);
end

hooksecurefunc(JQT, "Initialize", function() pcall(watchSharedFonts) end);

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
