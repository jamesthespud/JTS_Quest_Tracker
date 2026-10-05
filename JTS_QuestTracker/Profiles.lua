local _, ns = ...

--[[
    Profiles and import / export for JTS Quest Tracker.

    - Every setting lives in a profile. All characters start on the shared "Default" profile,
      so a new character looks exactly like your others until you choose otherwise.
    - The Profiles tab (AceDBOptions) lets each character pick, copy, create, reset or delete profiles.
    - Export turns the current profile into one line of text; Import reads such a line back,
      either into the current profile or into a new one.

    Only per-character data (manually tracked quests, pinned quests, hidden state) stays per character.
]]

local JQT = JTS_QuestTracker;
local JQTL = JTS_QuestTrackerLocale;
local AceSerializer = LibStub("AceSerializer-3.0");

local EXPORT_PREFIX = "JTSQT1:";

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local function copy(value)
    if type(value) ~= "table" then return value end

    local result = {};
    for k, v in pairs(value) do result[k] = copy(v) end

    return result;
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

-- Test builds kept the settings account wide (db.global). Move them into the Default profile once.
function JQT:MigrateToProfiles()
    local sv = self.db.sv;
    local old = sv and sv.global;

    if type(old) ~= "table" or old.ProfilesMigrated then return end

    local defaults = ns.CONSTANTS.DB_DEFAULTS.profile;
    local moved = 0;

    for key, value in pairs(old) do
        if defaults[key] ~= nil then
            self.db.profile[key] = value;
            old[key] = nil;
            moved = moved + 1;
        end
    end

    old.ProfilesMigrated = true;

    if moved > 0 then
        self:LogInfo("Moved " .. moved .. " settings into the Default profile.");
    end
end

function JQT:SetupProfiles()
    self:MigrateToProfiles();

    local function onChange()
        self:ApplyAllSettings();
    end

    self.db.RegisterCallback(self, "OnProfileChanged", onChange);
    self.db.RegisterCallback(self, "OnProfileCopied", onChange);
    self.db.RegisterCallback(self, "OnProfileReset", onChange);
end

-- Other files can ask to be told whenever the whole profile changes (minimap button, item buttons, ...).
JQT.settingsHooks = JQT.settingsHooks or {};

function JQT:OnSettingsApplied(fn)
    table.insert(self.settingsHooks, fn);
end

-- Re-reads every setting from the current profile and redraws the tracker.
function JQT:ApplyAllSettings()
    if not self.db then return end

    JQTL:SetLocale(self.db.profile.Locale);

    if self.tracker then
        self.tracker:UpdateSettings(self:GetTrackerSettings());
        self:ApplyTextStyle();
    end

    for _, fn in ipairs(self.settingsHooks) do
        pcall(fn, self);
    end

    if self.tracker then
        self:RefreshQuestWatch();
        self:RefreshView();
    end
end

-- ---------------------------------------------------------------------------
-- Base64 (so the export string only has safe, copyable characters)
-- ---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
local B64_INDEX = {};
for i = 1, #B64 do
    B64_INDEX[B64:sub(i, i)] = i - 1;
end

local function encode64(data)
    local out = {};

    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2);
        local n = a * 65536 + (b or 0) * 256 + (c or 0);

        local c1 = math.floor(n / 262144) % 64;
        local c2 = math.floor(n / 4096) % 64;
        local c3 = math.floor(n / 64) % 64;
        local c4 = n % 64;

        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=")
            .. (c and B64:sub(c4 + 1, c4 + 1) or "=");
    end

    return table.concat(out);
end

local function decode64(text)
    text = text:gsub("[^%w%+/=]", "");

    if #text % 4 ~= 0 then return nil end

    local out = {};

    for i = 1, #text, 4 do
        local chunk = text:sub(i, i + 3);
        local n, pad = 0, 0;

        for j = 1, 4 do
            local ch = chunk:sub(j, j);

            if ch == "=" then
                pad = pad + 1;
                n = n * 64;
            else
                local v = B64_INDEX[ch];
                if v == nil then return nil end
                n = n * 64 + v;
            end
        end

        local a = math.floor(n / 65536) % 256;
        local b = math.floor(n / 256) % 256;
        local c = n % 256;

        if pad == 0 then
            out[#out + 1] = string.char(a, b, c);
        elseif pad == 1 then
            out[#out + 1] = string.char(a, b);
        else
            out[#out + 1] = string.char(a);
        end
    end

    return table.concat(out);
end

-- ---------------------------------------------------------------------------
-- Import / export
-- ---------------------------------------------------------------------------

function JQT:ExportProfile()
    local settings = {};

    for key in pairs(ns.CONSTANTS.DB_DEFAULTS.profile) do
        settings[key] = copy(self.db.profile[key]);
    end

    local payload = {
        addon = "JTS_QuestTracker",
        version = ns.CONSTANTS.VERSION,
        settings = settings
    };

    return EXPORT_PREFIX .. encode64(AceSerializer:Serialize(payload));
end

-- Reads an export string. Returns the settings table, or nil and a reason.
function JQT:DecodeProfileString(text)
    if type(text) ~= "string" then
        return nil, "Nothing to import.";
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "");

    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "That is not a JTS Quest Tracker settings string.";
    end

    local raw = decode64(text:sub(#EXPORT_PREFIX + 1));
    if not raw then
        return nil, "The settings string is damaged (was it copied completely?).";
    end

    local ok, payload = AceSerializer:Deserialize(raw);
    if not ok or type(payload) ~= "table" or payload.addon ~= "JTS_QuestTracker" or type(payload.settings) ~= "table" then
        return nil, "The settings string is damaged (was it copied completely?).";
    end

    -- Only take settings we know, with the right kind of value. Anything else is ignored.
    local settings, count = {}, 0;

    for key, default in pairs(ns.CONSTANTS.DB_DEFAULTS.profile) do
        local value = payload.settings[key];

        if value ~= nil and type(value) == type(default) then
            settings[key] = copy(value);
            count = count + 1;
        end
    end

    if count == 0 then
        return nil, "The settings string has no settings in it.";
    end

    return settings, count;
end

-- Imports into the current profile, or into a new / existing profile called profileName.
function JQT:ImportProfile(text, profileName)
    local settings, countOrError = self:DecodeProfileString(text);

    if not settings then
        say("|cffff7f00Import failed:|r " .. countOrError);
        return false;
    end

    profileName = type(profileName) == "string" and profileName:gsub("^%s+", ""):gsub("%s+$", "") or "";

    local nameLength = type(strlenutf8) == "function" and strlenutf8(profileName) or #profileName;
    if nameLength > 50 then
        say("|cffff7f00Import failed:|r profile names can be at most 50 characters.");
        return false;
    end

    if profileName ~= "" and profileName ~= self.db:GetCurrentProfile() then
        self.db:SetProfile(profileName);
    end

    for key, default in pairs(ns.CONSTANTS.DB_DEFAULTS.profile) do
        if settings[key] ~= nil then
            self.db.profile[key] = settings[key];
        else
            self.db.profile[key] = copy(default);
        end
    end

    self:ApplyAllSettings();

    say("Imported " .. countOrError .. " settings into the profile |cffffffff" .. self.db:GetCurrentProfile() .. "|r.");

    return true;
end

-- ---------------------------------------------------------------------------
-- Profiles tab
-- ---------------------------------------------------------------------------

local importText, importName = "", "";
local profilesTable;

JQT:AddOptionsTab("profiles", function()
    if not JQT.db then return nil end

    if not profilesTable then
        profilesTable = LibStub("AceDBOptions-3.0"):GetOptionsTable(JQT.db);
        profilesTable.order = 1000;

        local args = profilesTable.args;

        args.jtsHeader = {
            name = "Share Settings",
            type = "header",
            order = 200
        };

        args.jtsShareDesc = {
            name = "Copy the text below to share this profile with a friend, or to keep a backup. To load someone else's settings, paste their text into Import and click Import.",
            type = "description",
            fontSize = "medium",
            order = 201
        };

        args.jtsExport = {
            name = "Export (current profile)",
            desc = "Click in the box, press Ctrl+A to select everything, then Ctrl+C to copy.",
            type = "input",
            multiline = 4,
            width = "full",
            order = 202,

            get = function() return JQT:ExportProfile() end,
            set = function() end
        };

        args.jtsImport = {
            name = "Import",
            desc = "Paste a JTS Quest Tracker settings string here (Ctrl+V), then click Accept.",
            type = "input",
            multiline = 4,
            width = "full",
            order = 203,

            get = function() return importText end,
            set = function(_, value) importText = value or "" end
        };

        args.jtsImportName = {
            name = "Import into new profile (optional)",
            desc = "Type a name to put the imported settings into a new profile with that name. Leave it empty to overwrite the current profile.",
            type = "input",
            width = 1.6,
            order = 204,

            get = function() return importName end,
            set = function(_, value) importName = value or "" end
        };

        args.jtsImportButton = {
            name = "Import",
            type = "execute",
            width = 1.0,
            order = 205,

            disabled = function() return importText == "" end,

            confirm = function()
                if importName ~= "" then
                    return "Import these settings into the profile \"" .. importName .. "\"?";
                end

                return "Replace all settings in the current profile (" .. JQT.db:GetCurrentProfile() .. ") with the imported ones?";
            end,

            func = function()
                if JQT:ImportProfile(importText, importName) then
                    importText, importName = "", "";
                end
            end
        };
    end

    return profilesTable;
end);
