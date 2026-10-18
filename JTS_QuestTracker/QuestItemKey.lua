local _, ns = ...

--[[
    Quest item hotkey (2.0).

    One key binding (Key Bindings > AddOns > JTS Quest Tracker > Use Quest Item) uses the item of:
      1. the focused quest, if it has one (Focused Quest First, on by default), or else
      2. the closest tracked quest that has one (by the distance WoW's quest arrow uses).
    The quest item button it would use shows the key in its corner.

    Using an item is a protected action, so the key presses a hidden secure button. Which item it
    uses can only change out of combat: in a fight it keeps the item it had when the fight began
    (still the right one almost always), and catches up the moment combat ends.
]]

local JQT = JTS_QuestTracker;
local Compat = LibStub("JTSQTCompat-1.0");

local BUTTON_NAME = "JTS_QuestTrackerItemKey";
local BINDING = "CLICK " .. BUTTON_NAME .. ":LeftButton";
local UPDATE_EVERY = 2; -- seconds, out of combat, while there are quest items to choose from

_G["BINDING_NAME_" .. BINDING] = "Use Quest Item (focused or closest)";

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local function p() return JQT.db and JQT.db.profile end

local current;    -- { questID, title, link } the key uses right now
local pending;    -- a change waiting for combat to end
local button;

local function itemAttribute(link)
    local id = link and tonumber(link:match("item:(%d+)"));

    return id and ("item:" .. id) or link;
end

-- ---------------------------------------------------------------------------
-- Choosing the item
-- ---------------------------------------------------------------------------

-- Tracked quests with a usable item, in tracker order: { quest, link }.
local function candidates()
    local list = {};

    for _, container in ipairs(JQT.questContainers or {}) do
        local quest = container.metadata and container.metadata.quest;

        if quest and quest.questID then
            local link, _, _, showWhenComplete = Compat:GetQuestItem(quest.questID);

            if link and (not quest.completed or showWhenComplete) then
                list[#list + 1] = { quest = quest, link = link, order = container.order or #list };
            end
        end
    end

    table.sort(list, function(a, b) return a.order < b.order end);

    return list;
end

function JQT:ChooseQuestItemForKey()
    local list = candidates();
    if #list == 0 then return nil end

    if p() and p().QuestItemKeyFocusFirst ~= false and self.GetFocusedQuestID then
        local focused = self:GetFocusedQuestID();

        for _, entry in ipairs(list) do
            if entry.quest.questID == focused then return entry end
        end
    end

    local best, bestDistance;
    for _, entry in ipairs(list) do
        local distance = Compat:GetBuiltInQuestDistance(entry.quest.questID);

        if distance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = entry, distance;
        end
    end

    -- No locations at all: the first one in the tracker.
    return best or list[1];
end

-- ---------------------------------------------------------------------------
-- The secure button the key presses
-- ---------------------------------------------------------------------------

local function createButton()
    if button then return button end

    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate");
    button:SetSize(1, 1);
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10);
    button:EnableMouse(false);
    button:RegisterForClicks("AnyUp", "AnyDown");
    button:SetAttribute("type", "item");

    -- Nothing to use: say so (not more than once every few seconds).
    local lastNote = 0;
    button:HookScript("OnClick", function()
        if current then return end

        local now = GetTime();
        if now - lastNote > 5 then
            lastNote = now;
            say("None of your tracked quests has an item to use right now.");
        end
    end);

    return button;
end

-- The key on the quest item button it would use.
function JQT:UpdateQuestItemKeyLabel()
    local key = GetBindingKey and GetBindingKey(BINDING);
    local text = key;
    if key and GetBindingText then
        local ok, short = pcall(GetBindingText, key, true);
        if ok and type(short) == "string" and short ~= "" then text = short end
    end

    local show = key and p() and p().QuestItemKeyLabel ~= false;

    for _, itemButton in ipairs(self.GetQuestItemButtons and self:GetQuestItemButtons() or {}) do
        local quest = itemButton.container and itemButton.container.metadata and itemButton.container.metadata.quest;
        local mine = show and current and quest and quest.questID == current.questID and itemButton:IsShown();

        if mine then
            if not itemButton.keyLabel then
                itemButton.keyLabel = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray");
                itemButton.keyLabel:SetPoint("TOPLEFT", 2, -2);
            end
            itemButton.keyLabel:SetText(text);
            itemButton.keyLabel:Show();
        elseif itemButton.keyLabel then
            itemButton.keyLabel:Hide();
        end
    end
end

function JQT:UpdateQuestItemKey()
    if not self.db then return end

    if InCombatLockdown() then
        pending = true;
        return;
    end
    pending = nil;

    createButton();

    local choice = self:ChooseQuestItemForKey();
    local link = choice and choice.link;

    if not current or not choice or current.questID ~= choice.quest.questID or current.link ~= link then
        button:SetAttribute("item", itemAttribute(link));
    end

    current = choice and { questID = choice.quest.questID, title = choice.quest.title, link = link } or nil;

    self:UpdateQuestItemKeyLabel();
end

function JQT:GetQuestItemKeyChoice()
    return current;
end

-- ---------------------------------------------------------------------------
-- When to look again
-- ---------------------------------------------------------------------------

-- After every redraw the quest items are worked out again (QuestItems.lua).
hooksecurefunc(JQT, "RefreshQuestItemData", function(self) self:UpdateQuestItemKey() end);
hooksecurefunc(JQT, "LayoutQuestItems", function(self) self:UpdateQuestItemKeyLabel() end);

local ticker;
hooksecurefunc(JQT, "Initialize", function(self)
    self:UpdateQuestItemKey();

    -- Moving around changes which quest is closest.
    ticker = ticker or C_Timer.NewTicker(UPDATE_EVERY, function()
        if not InCombatLockdown() and #candidates() > 1 then JQT:UpdateQuestItemKey() end
    end);
end);

local events = CreateFrame("Frame");

for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "SUPER_TRACKING_CHANGED", "UPDATE_BINDINGS" }) do
    pcall(events.RegisterEvent, events, event);
end

events:SetScript("OnEvent", function(_, event)
    if not JQT.db then return end

    if event == "UPDATE_BINDINGS" then
        JQT:UpdateQuestItemKeyLabel();
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then JQT:UpdateQuestItemKey() end
    else
        JQT:UpdateQuestItemKey();
    end
end);

-- ---------------------------------------------------------------------------
-- Options (Buttons > Quest Item Key)
-- ---------------------------------------------------------------------------

JQT.buttonsTabGroups = JQT.buttonsTabGroups or {};

JQT.buttonsTabGroups.itemKey = function()
    local function set(info, value)
        JQT.db.profile[info.arg] = value;
        JQT:UpdateQuestItemKey();
    end

    return {
        name = "Quest Item Key",
        type = "group",
        inline = true,
        order = 20,

        args = {
            status = {
                name = function()
                    local key = GetBindingKey and GetBindingKey(BINDING);
                    local line = key and ("Key: |cffffffff" .. key .. "|r")
                        or "Key: |cff999999not set|r. Set it in |cffffffffEsc > Options > Keybindings > AddOns > JTS Quest Tracker > Use Quest Item|r.";

                    local choice = JQT:GetQuestItemKeyChoice();
                    if choice then
                        line = line .. "\nRight now it uses the item for |cffffd100" .. tostring(choice.title) .. "|r.";
                    end

                    return line;
                end,
                type = "description", fontSize = "medium", order = 1
            },
            focusFirst = {
                name = "Focused Quest First", order = 2, width = 1.4,
                desc = "When the quest you focused (middle-click) has an item, the key uses that one. Otherwise, or with this off, it uses the closest quest that has an item.",
                type = "toggle", arg = "QuestItemKeyFocusFirst", set = set,
                get = function() return JQT.db.profile.QuestItemKeyFocusFirst ~= false end
            },
            label = {
                name = "Show the Key on the Button", order = 3, width = 1.4,
                desc = "The quest item button the key would use shows the key in its corner.",
                type = "toggle", arg = "QuestItemKeyLabel", set = set,
                get = function() return JQT.db.profile.QuestItemKeyLabel ~= false end
            },
        }
    };
end
