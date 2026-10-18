local _, ns = ...

--[[
    Quest icons on nameplates (2.0).

    A small "!" next to the nameplate of every enemy that is part of one of your quests (the ones
    you still need to kill or loot), using the game's own C_QuestLog.UnitIsRelatedToActiveQuest.

    Notes for testing:
      - nameplates must be turned on in the game (V key) for there to be anything to mark
      - inside dungeons and raids the game doesn't let addons touch nameplates, so no icons there
      - in combat Forever may hide the answer from addons; a nameplate that appears mid-fight then
        gets its icon once the game tells us (at the latest when the fight ends)
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");

local TEXTURE = "Interface\\AddOns\\JTS_QuestTracker\\Textures\\QuestMarker";
local SIZE = 16;

local markers = {}; -- nameplate frame -> our icon frame
local units = {};   -- unit token -> nameplate frame, for the nameplates on screen

local function enabled()
    return JQT.db ~= nil and JQT.db.profile.NameplateQuestIcons ~= false;
end

local function secret(value)
    return issecretvalue ~= nil and issecretvalue(value);
end

-- true / false, or nil when the game won't say right now.
local function isQuestEnemy(unit)
    local api = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest;
    if not api then return false end

    local ok, related = pcall(api, unit);
    if not ok or secret(related) then return nil end
    if not related then return false end

    -- Quest givers and helpers count as "related" too; only mark what you can fight.
    local okAttack, attackable = pcall(UnitCanAttack, "player", unit);
    if not okAttack or secret(attackable) then return nil end

    local okDead, dead = pcall(UnitIsDead, unit);
    if okDead and not secret(dead) and dead then return false end

    return attackable and true or false;
end

local function markerFor(plate)
    local marker = markers[plate];
    if marker then return marker end

    marker = CreateFrame("Frame", nil, plate);
    marker:SetSize(SIZE, SIZE);
    marker:SetFrameLevel((plate:GetFrameLevel() or 0) + 10);

    marker.icon = marker:CreateTexture(nil, "OVERLAY");
    marker.icon:SetAllPoints();
    marker.icon:SetTexture(TEXTURE);

    -- Right of the health bar when the plate has one, otherwise right of the plate.
    local unitFrame = type(plate.UnitFrame) == "table" and plate.UnitFrame or nil;
    local bar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBarsContainer);
    local anchor = (type(bar) == "table" and bar.GetObjectType and bar) or plate;
    marker:SetPoint("LEFT", anchor, "RIGHT", 2, 0);
    marker:Hide();

    markers[plate] = marker;

    return marker;
end

local function plateFor(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end

    -- Without includeForbidden: forbidden plates (dungeons, raids) come back as nil.
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit);

    return ok and plate or nil;
end

local function update(unit)
    local plate = units[unit] or plateFor(unit);
    if not plate then return end
    units[unit] = plate;

    if not enabled() then
        if markers[plate] then markers[plate]:Hide() end
        return;
    end

    local quest = isQuestEnemy(unit);
    if quest == nil then return end -- unknown right now: leave it as it is

    local ok, marker = pcall(markerFor, plate);
    if not ok then return end

    if quest then marker:Show() else marker:Hide() end
end

function JQT:UpdateNameplateQuestIcons()
    for unit in pairs(units) do update(unit) end
end

local events = CreateFrame("Frame");

for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED", "UNIT_FLAGS" }) do
    pcall(events.RegisterEvent, events, event);
end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        units[unit] = nil;
        update(unit);
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = units[unit];
        if plate and markers[plate] then markers[plate]:Hide() end
        units[unit] = nil;
    elseif event == "UNIT_FLAGS" then
        -- e.g. a mob dying or becoming attackable
        if unit and units[unit] then update(unit) end
    else
        JQT:UpdateNameplateQuestIcons();
    end
end);

-- Progress on a quest can mean a mob is no longer needed (or now is).
QLH:OnQuestUpdated(function()
    JQT:UpdateNameplateQuestIcons();
end);

-- ---------------------------------------------------------------------------
-- Option (Alerts > Quest Objects)
-- ---------------------------------------------------------------------------

JQT.nameplateOptions = function()
    return {
        name = "Quest Icons on Nameplates", order = 2, width = 1.6,
        desc = "Shows a small |TInterface\\AddOns\\JTS_QuestTracker\\Textures\\QuestMarker:0|t next to the nameplate of every enemy that's part of one of your quests.\n\nNameplates need to be turned on (V key). The game doesn't allow this inside dungeons and raids.\n\nIf you also use Questie or a nameplate addon that does the same, you may see two icons.",
        type = "toggle",
        get = function() return JQT.db.profile.NameplateQuestIcons ~= false end,
        set = function(_, value)
            JQT.db.profile.NameplateQuestIcons = value;
            JQT:UpdateNameplateQuestIcons();
        end
    };
end
