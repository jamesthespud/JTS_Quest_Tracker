local _, ns = ...

--[[
    Color blind modes for JTS Quest Tracker.

    Every color the tracker uses to *mean* something comes from here:
      - quest difficulty (very hard / hard / normal / easy / too easy)
      - objective progress (just started -> half way -> done) and the progress bars
      - "Ready to turn in" and "Failed"
      - the objective complete flash and the Abandon Quest menu entry

    Each mode picks a palette built for that type of color vision. The palettes were checked
    with the Machado (2009) color vision simulation, at full and partial strength, so every
    color in a group stays clearly different and readable on the dark tracker background.

    Shades of grey alone cannot keep five difficulty levels apart, so the no-color modes
    also add a small text marker after the quest name (see Difficulty Markers).

    Colors the player picks by hand (header, zone, quest and objective text) are never changed.
]]

local JQT = JTS_QuestTracker;

local function rgb(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255
    };
end

-- ---------------------------------------------------------------------------
-- Palettes
-- difficulty[4] = very hard (red in the quest log) ... difficulty[0] = too easy (grey)
-- ---------------------------------------------------------------------------

local PALETTES = {
    -- The tracker's normal colors, unchanged.
    normal = {
        difficulty = {
            [4] = { r = 1, g = 0.1, b = 0.1 },
            [3] = { r = 1, g = 0.5, b = 0.25 },
            [2] = { r = 1, g = 1, b = 0 },
            [1] = { r = 0.25, g = 0.75, b = 0.25 },
            [0] = { r = 0.75, g = 0.75, b = 0.75 }
        },
        progress = { { r = 0.95, g = 0.35, b = 0.30 }, { r = 1.00, g = 0.85, b = 0.20 }, { r = 0.35, g = 0.80, b = 0.35 } },
        complete = rgb("00B205"),
        failed = { r = 1, g = 0.1, b = 0.1 },
        flash = { r = 1.0, g = 0.95, b = 0.55 }
    },

    -- Protanopia, protanomaly, deuteranopia, deuteranomaly: red and green look alike,
    -- blue and orange/yellow stay apart. Uses an orange <-> blue scale.
    redGreen = {
        difficulty = {
            [4] = rgb("DA8047"), -- burnt orange
            [3] = rgb("FDCB01"), -- gold
            [2] = rgb("FAFAE2"), -- cream
            [1] = rgb("679EF4"), -- blue
            [0] = rgb("8C8C8C")  -- grey
        },
        progress = { rgb("E0783A"), rgb("F5F5F5"), rgb("5C9EFF") },
        complete = rgb("5C9EFF"),
        failed = rgb("E0783A"),
        flash = rgb("FFFFFF")
    },

    -- Tritanopia, tritanomaly: blue and yellow (and blue and green) look alike,
    -- red and cyan stay apart. Uses a red <-> cyan scale.
    blueYellow = {
        difficulty = {
            [4] = rgb("EB5136"), -- red
            [3] = rgb("FC9CD9"), -- pink
            [2] = rgb("FCFEFE"), -- white
            [1] = rgb("1BDAD7"), -- cyan
            [0] = rgb("8C8C8C")  -- grey
        },
        progress = { rgb("F05A46"), rgb("F5F5F5"), rgb("1BDAD7") },
        complete = rgb("1BDAD7"),
        failed = rgb("F05A46"),
        flash = rgb("FFE0F0")
    },

    -- Achromatopsia, blue cone monochromacy, achromatomaly: little or no color,
    -- so only brightness is used. Brighter = harder / further along.
    mono = {
        difficulty = {
            [4] = rgb("FFFFFF"),
            [3] = rgb("DDDDDD"),
            [2] = rgb("BDBDBD"),
            [1] = rgb("A0A0A0"),
            [0] = rgb("878787")
        },
        progress = { rgb("878787"), rgb("BDBDBD"), rgb("FFFFFF") },
        complete = rgb("FFFFFF"),
        failed = rgb("878787"),
        flash = rgb("FFFFFF")
    }
};

-- ---------------------------------------------------------------------------
-- Modes (every type of color vision deficiency)
-- ---------------------------------------------------------------------------

JQT.COLOR_BLIND_MODES = {
    { key = "Off",                  palette = "normal",     label = "Off (normal color vision)" },
    { key = "Protanopia",           palette = "redGreen",   label = "Protanopia (red-blind)" },
    { key = "Protanomaly",          palette = "redGreen",   label = "Protanomaly (red-weak)" },
    { key = "Deuteranopia",         palette = "redGreen",   label = "Deuteranopia (green-blind)" },
    { key = "Deuteranomaly",        palette = "redGreen",   label = "Deuteranomaly (green-weak, most common)" },
    { key = "Tritanopia",           palette = "blueYellow", label = "Tritanopia (blue-blind)" },
    { key = "Tritanomaly",          palette = "blueYellow", label = "Tritanomaly (blue-weak)" },
    { key = "Achromatopsia",        palette = "mono",       label = "Achromatopsia (no color)" },
    { key = "BlueConeMonochromacy", palette = "mono",       label = "Blue Cone Monochromacy" },
    { key = "Achromatomaly",        palette = "mono",       label = "Achromatomaly (weak color overall)" }
};

local MODE_PALETTE = {};
for _, mode in ipairs(JQT.COLOR_BLIND_MODES) do
    MODE_PALETTE[mode.key] = mode.palette;
end

function JQT:GetColorBlindModeValues()
    local values, sorting = {}, {};

    for _, mode in ipairs(self.COLOR_BLIND_MODES) do
        values[mode.key] = mode.label;
        table.insert(sorting, mode.key);
    end

    return values, sorting;
end

function JQT:GetColorBlindPaletteName()
    local mode = self.db and self.db.profile.ColorBlindMode;

    return MODE_PALETTE[mode] or "normal";
end

function JQT:GetPalette()
    return PALETTES[self:GetColorBlindPaletteName()] or PALETTES.normal;
end

-- ---------------------------------------------------------------------------
-- Colors used by the tracker
-- ---------------------------------------------------------------------------

function JQT:GetDifficultyColor(difficulty)
    local colors = self:GetPalette().difficulty;

    return colors[difficulty] or colors[0];
end

-- The three stops objective progress blends between: just started, half way, done.
function JQT:GetProgressStops()
    local stops = self:GetPalette().progress;

    return stops[1], stops[2], stops[3];
end

-- "complete", "failed" or "flash"
function JQT:GetStatusColor(kind)
    return self:GetPalette()[kind] or PALETTES.normal[kind];
end

-- The same color as a chat/menu color code, e.g. "|cffe0783a".
function JQT:GetStatusColorCode(kind)
    local c = self:GetStatusColor(kind);

    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255);
end

-- ---------------------------------------------------------------------------
-- Difficulty markers: a text cue after the quest name, so difficulty never relies on color alone.
--   !!  very hard     !  hard     (nothing)  normal     -  easy     --  too easy
-- ---------------------------------------------------------------------------

local MARKERS = {
    [4] = " !!",
    [3] = " !",
    [2] = "",
    [1] = " -",
    [0] = " --"
};

function JQT:ShowDifficultyMarkers()
    local setting = self.db and self.db.profile.DifficultyMarkers;

    if setting == "On" then
        return true;
    elseif setting == "Off" then
        return false;
    end

    -- Auto: on whenever the mode has to work with brightness alone.
    return self:GetColorBlindPaletteName() == "mono";
end

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);

    if quest and quest.difficulty and self:ShowDifficultyMarkers() then
        header = header .. (MARKERS[quest.difficulty] or "");
    end

    return header;
end
