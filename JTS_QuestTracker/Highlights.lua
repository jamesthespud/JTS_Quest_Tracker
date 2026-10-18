local _, ns = ...

--[[
    Highlight Quest Objects (2.0).

    Modern WoW makes quest objects sparkle. Addons can't draw on things in the 3D world, but WoW
    Forever has the modern Interact Key system, which can mark and outline the nearest thing you
    can use. Most quest objects can only be used while you are on their quest, so in quest areas
    that mostly lights up what you need. This switches those game settings on in one go:

      softTargetInteract        Interact Key on (mouse and keyboard)
      SoftTargetIconInteract    icon over the nearest NPC you can interact with
      SoftTargetIconGameObject  icon over the nearest object you can interact with
      graphicsOutlineMode       outlines on (only if they were off)

    Your own values are saved first and put back when you turn it off (only the ones still set the
    way we left them, so a change you made yourself meanwhile is kept). CVars are account wide, so
    the option is too (db.global). Changes wait until combat is over.
]]

local JQT = JTS_QuestTracker;

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local ANY = (type(Enum) == "table" and type(Enum.SoftTargetEnableFlags) == "table" and Enum.SoftTargetEnableFlags.Any) or 3;

-- { cvar, the value we want, only change it when it is currently one of these (nil = always) }
local CVARS = {
    { "softTargetInteract", tostring(ANY) },
    { "SoftTargetIconInteract", "1" },
    { "SoftTargetIconGameObject", "1" },
    { "graphicsOutlineMode", "1", { ["0"] = true }, outline = true },
    { "raidGraphicsOutlineMode", "1", { ["0"] = true }, outline = true },
};

local function getCVar(name)
    local ok, value = pcall(GetCVar, name);

    return ok and value ~= nil and tostring(value) or nil;
end

local function setCVar(name, value)
    return pcall(SetCVar, name, value);
end

local function outlineSupported()
    local api = C_VideoOptions and C_VideoOptions.IsOutlineModeSupported;
    if not api then return true end

    local ok, supported = pcall(api);

    return not ok or supported ~= false;
end

local function store()
    local global = JQT.db.global;
    global.HighlightSavedCVars = global.HighlightSavedCVars or {};

    return global.HighlightSavedCVars;
end

local function apply(on)
    local saved = store();

    if on then
        for _, entry in ipairs(CVARS) do
            local name, want, onlyFrom = entry[1], entry[2], entry[3];
            local current = getCVar(name);

            if current ~= nil and (not entry.outline or outlineSupported()) and current ~= want
                and (not onlyFrom or onlyFrom[current]) then
                if saved[name] == nil then saved[name] = { from = current, to = want } end
                setCVar(name, want);
            end
        end
    else
        for name, change in pairs(saved) do
            if getCVar(name) == change.to then setCVar(name, change.from) end
            saved[name] = nil;
        end
    end
end

local pendingState;
local events = CreateFrame("Frame");
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED");

events:SetScript("OnEvent", function()
    if pendingState ~= nil then
        local state = pendingState;
        pendingState = nil;
        apply(state);
    end
end);

function JQT:IsHighlightingQuestObjects()
    return self.db ~= nil and self.db.global.HighlightQuestObjects == true;
end

function JQT:SetHighlightQuestObjects(on)
    self.db.global.HighlightQuestObjects = on and true or false;

    if InCombatLockdown and InCombatLockdown() then
        pendingState = on and true or false;
        say("Quest object highlights change when combat ends.");
    else
        apply(on);
    end
end

-- Keep them on after a relog (unless the player turned the game settings off themselves).
hooksecurefunc(JQT, "Initialize", function(self)
    if self:IsHighlightingQuestObjects() and next(store()) == nil then apply(true) end
end);

-- ---------------------------------------------------------------------------
-- Option (Alerts > Quest Objects)
-- ---------------------------------------------------------------------------

JQT.highlightOptions = function()
    return {
        name = "Quest Objects",
        type = "group",
        inline = true,

        args = {
            highlight = {
                name = "Highlight Quest Objects", order = 1, width = 1.6,
                desc = "Uses WoW's own Interact Key system to mark and outline the nearest thing you can use, which in quest areas is mostly quest objects (crates, plants, pages...). It can also mark other usable things nearby, like mailboxes or chairs.\n\nThis turns on the game's Interact Key, Interact Key Icons and, if they were off, Outlines. Your own settings are put back when you turn this off.\n\nTo use the marked object with a key, bind |cffffffffInteract With Target|r in Key Bindings.",
                type = "toggle",
                get = function() return JQT:IsHighlightingQuestObjects() end,
                set = function(_, value) JQT:SetHighlightQuestObjects(value) end
            },
        }
    };
end
