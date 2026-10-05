local _, ns = ...

--[[
    Quest item buttons for JTS Quest Tracker.

    Quests that give you an item to use ("use the Torch on the haystack") get a clickable
    button beside them in the tracker, like Blizzard's own tracker has.

    Using an item is a protected action, so these are secure buttons, and the game does not
    let addons create, move, show or hide secure buttons during combat. So:
      - buttons are positioned against the screen (not inside the tracker), which keeps the
        tracker itself free to redraw and scroll in combat;
      - changes that happen in combat (a new quest item, the list scrolling) are applied as
        soon as combat ends. The buttons keep working in combat.
]]

local JQT = JTS_QuestTracker;
local Compat = LibStub("JTSQTCompat-1.0");

local MAX_BUTTONS = 40;
local buttons = {};
local items = {};          -- what each button should show, rebuilt after every tracker redraw
local dirty = true;        -- items changed and the buttons still need setting up

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

local function itemID(link)
    return link and tonumber(link:match("item:(%d+)"));
end

local function updateCooldown(button)
    if not button.logIndex then return end

    local start, duration, enable = Compat:GetQuestItemCooldown(button.logIndex);

    if start and duration and duration > 0 then
        button.cooldown:SetCooldown(start, duration);
        button.cooldown:Show();
    else
        button.cooldown:Hide();
    end

    if start and duration and duration > 0 and enable == 0 then
        button.icon:SetVertexColor(0.4, 0.4, 0.4);
    else
        button.icon:SetVertexColor(1, 1, 1);
    end
end

local function onUpdate(button, elapsed)
    button.rangeTimer = (button.rangeTimer or 0) - elapsed;
    if button.rangeTimer > 0 then return end
    button.rangeTimer = 0.2;

    if not button.logIndex or type(IsQuestLogSpecialItemInRange) ~= "function" then
        button.range:Hide();
        return;
    end

    local ok, inRange = pcall(IsQuestLogSpecialItemInRange, button.logIndex);

    if ok and inRange == 0 then
        button.range:SetVertexColor(1.0, 0.1, 0.1);
        button.range:Show();
    elseif ok and inRange == 1 then
        button.range:SetVertexColor(0.6, 0.6, 0.6);
        button.range:Show();
    else
        button.range:Hide();
    end
end

local function onEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT");

    local shown = false;
    if button.logIndex and GameTooltip.SetQuestLogSpecialItem then
        shown = pcall(GameTooltip.SetQuestLogSpecialItem, GameTooltip, button.logIndex);
    end

    if not shown and button.link then
        pcall(GameTooltip.SetHyperlink, GameTooltip, button.link);
    end

    GameTooltip:Show();
end

local function createButton(i)
    local size = 26;
    local button = CreateFrame("Button", "JTS_QuestTrackerItemButton" .. i, UIParent, "SecureActionButtonTemplate");

    button:SetSize(size, size);
    button:SetFrameStrata("MEDIUM");
    button:Hide();

    -- WoW Forever's secure handler decides between key down and key up itself.
    button:RegisterForClicks("AnyUp", "AnyDown");

    button:SetAttribute("type", "item");

    -- Shift-click links the item in chat instead of using it. A custom action type makes the
    -- secure button call button:linkitem() rather than using the item.
    button:SetAttribute("shift-type*", "linkitem");
    button.linkitem = function(self)
        if self.link and type(ChatEdit_InsertLink) == "function" then
            ChatEdit_InsertLink(self.link);
        end
    end;

    button.icon = button:CreateTexture(nil, "BORDER");
    button.icon:SetAllPoints();
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);

    button.border = button:CreateTexture(nil, "OVERLAY");
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
    button.border:SetPoint("CENTER");

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress");
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal");
    button.count:SetPoint("BOTTOMRIGHT", -2, 2);

    -- Small dot in the corner: red when out of range, grey when in range.
    button.range = button:CreateTexture(nil, "OVERLAY");
    button.range:SetTexture("Interface\\Buttons\\WHITE8X8");
    button.range:SetSize(4, 4);
    button.range:SetPoint("TOPRIGHT", -2, -2);
    button.range:Hide();

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate");
    button.cooldown:SetAllPoints();

    button:SetScript("OnEnter", onEnter);
    button:SetScript("OnLeave", function() GameTooltip:Hide() end);
    button:SetScript("OnUpdate", onUpdate);

    buttons[i] = button;

    return button;
end

local function getButton(i)
    return buttons[i] or createButton(i);
end

-- ---------------------------------------------------------------------------
-- Which quests have items
-- ---------------------------------------------------------------------------

function JQT:RefreshQuestItemData()
    wipe(items);

    if self.db and self.db.profile.ShowQuestItems and self.questContainers and not self.db.profile.DisplayDummyData then
        for _, container in ipairs(self.questContainers) do
            local quest = container.metadata and container.metadata.quest;

            if quest and quest.questID then
                local link, texture, charges, showWhenComplete, logIndex = Compat:GetQuestItem(quest.questID, quest.index);

                if link and (not quest.completed or showWhenComplete) and #items < MAX_BUTTONS then
                    items[#items + 1] = {
                        container = container,
                        link = link,
                        texture = texture,
                        charges = charges,
                        logIndex = logIndex
                    };
                end
            end
        end
    end

    dirty = true;
    self:LayoutQuestItems();
end

-- ---------------------------------------------------------------------------
-- Placing the buttons (out of combat only)
-- ---------------------------------------------------------------------------

local function hideFrom(first)
    for i = first, #buttons do
        local button = buttons[i];

        if button:IsShown() then
            button:Hide();
        end

        button.container = nil;
    end
end

function JQT:LayoutQuestItems()
    if InCombatLockdown() then return end

    local p = self.db and self.db.profile;
    local tracker = self.tracker;

    if not p or not p.ShowQuestItems or not tracker or not tracker:IsVisible() then
        hideFrom(1);
        return;
    end

    local size = math.max(16, math.min(48, tonumber(p.QuestItemSize) or 26));
    local onRight = p.QuestItemSide == "Right";
    local uiScale = UIParent:GetEffectiveScale();
    local viewTop, viewBottom = tracker:GetTop(), tracker:GetBottom();

    local shown = 0;

    for _, item in ipairs(items) do
        local container = item.container;
        local top = container:IsVisible() and container:GetTop();

        -- Only rows you can actually see (the tracker scrolls and clips its content).
        if top and viewTop and viewBottom and top <= viewTop + 1 and top - 10 >= viewBottom then
            shown = shown + 1;

            local button = getButton(shown);
            local scale = container:GetEffectiveScale() / uiScale;

            if dirty or button.link ~= item.link or button.logIndex ~= item.logIndex then
                button.link = item.link;
                button.logIndex = item.logIndex;

                local id = itemID(item.link);
                button:SetAttribute("item", id and ("item:" .. id) or item.link);
                button.icon:SetTexture(item.texture);
                button.count:SetText((item.charges and item.charges > 1) and item.charges or "");
                updateCooldown(button);
            end

            local y = top * scale + 2;
            local x, point;

            if onRight then
                point, x = "TOPLEFT", (tracker:GetRight() * tracker:GetEffectiveScale() / uiScale) + 4;
            else
                point, x = "TOPRIGHT", (container:GetLeft() * scale) - 4;
            end

            -- Only touch the button when something actually moved.
            if button.placedX ~= x or button.placedY ~= y or button.placedPoint ~= point or button.placedSize ~= size then
                button:SetSize(size, size);
                button.border:SetSize(size * 1.7, size * 1.7);

                button:ClearAllPoints();
                button:SetPoint(point, UIParent, "BOTTOMLEFT", x, y);

                button.placedX, button.placedY, button.placedPoint, button.placedSize = x, y, point, size;
            end

            button.container = container;

            if not button:IsShown() then
                button:Show();
            end
        end
    end

    hideFrom(shown + 1);
    dirty = false;
end

-- ---------------------------------------------------------------------------
-- Keeping them up to date
-- ---------------------------------------------------------------------------

local driver = CreateFrame("Frame");
local elapsedSinceLayout = 0;

-- Follow the tracker when it is dragged, scrolled or collapsed (cheap: positions only).
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceLayout = elapsedSinceLayout + elapsed;

    if elapsedSinceLayout >= 0.1 then
        elapsedSinceLayout = 0;

        if JQT.db and (#items > 0 or (buttons[1] and buttons[1]:IsShown())) then
            JQT:LayoutQuestItems();
        end
    end
end);

-- pcall: not every client has every event, and registering an unknown one is an error.
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED" }) do
    pcall(driver.RegisterEvent, driver, event);
end

driver:SetScript("OnEvent", function(_, event)
    if not JQT.db then return end

    if event == "BAG_UPDATE_COOLDOWN" then
        for _, button in ipairs(buttons) do
            if button:IsShown() then updateCooldown(button) end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        JQT:RefreshQuestItemData();
    else
        -- Combat is over: apply everything that changed during it.
        dirty = true;
        JQT:RefreshQuestItemData();
    end
end);

-- Rebuild the list every time the tracker redraws, and whenever the whole profile changes.
hooksecurefunc(JQT, "RefreshView", function(self)
    pcall(self.RefreshQuestItemData, self);
end);

JQT:OnSettingsApplied(function(self)
    self:RefreshQuestItemData();
end);

-- ---------------------------------------------------------------------------
-- Options (the Buttons tab, shared with the minimap button)
-- ---------------------------------------------------------------------------

JQT.buttonsTabGroups = JQT.buttonsTabGroups or {};

JQT.buttonsTabGroups.questItems = function()
    return {
        name = "Quest Item Buttons",
        type = "group",
        inline = true,
        order = 1,

        args = {
            desc = {
                name = "Quests that give you an item to use get a button beside them in the tracker. Click it to use the item, Shift-click to link it in chat. The red dot means you are out of range.\n\nThe game doesn't let addons move these buttons during combat, so changes made in a fight show up as soon as it ends.",
                type = "description",
                fontSize = "medium",
                order = 1
            },

            show = {
                name = "Show Quest Item Buttons",
                type = "toggle",
                width = 1.6,
                order = 2,

                get = function() return JQT.db.profile.ShowQuestItems end,
                set = function(_, value)
                    JQT.db.profile.ShowQuestItems = value;
                    JQT:RefreshQuestItemData();
                end
            },

            side = {
                name = "Side",
                desc = "Which side of the tracker the buttons sit on.",
                type = "select",
                width = 0.8,
                order = 3,

                values = { Left = "Left", Right = "Right" },
                sorting = { "Left", "Right" },

                get = function() return JQT.db.profile.QuestItemSide end,
                set = function(_, value)
                    JQT.db.profile.QuestItemSide = value;
                    JQT:RefreshQuestItemData();
                end,

                disabled = function() return not JQT.db.profile.ShowQuestItems end
            },

            size = {
                name = "Button Size",
                type = "range",
                width = 1.2,
                min = 16,
                max = 48,
                step = 1,
                order = 4,

                get = function() return JQT.db.profile.QuestItemSize end,
                set = function(_, value)
                    JQT.db.profile.QuestItemSize = value;
                    JQT:RefreshQuestItemData();
                end,

                disabled = function() return not JQT.db.profile.ShowQuestItems end
            }
        }
    };
end

JQT:AddOptionsTab("buttons", function()
    local tab = {
        name = "Buttons",
        type = "group",
        order = 900,
        args = {}
    };

    for key, builder in pairs(JQT.buttonsTabGroups) do
        local ok, group = pcall(builder);
        if ok and group then tab.args[key] = group end
    end

    return tab;
end);
