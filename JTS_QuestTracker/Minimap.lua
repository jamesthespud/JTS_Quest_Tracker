local _, ns = ...

--[[
    Minimap button for JTS Quest Tracker.

        Left-click:   open / close the settings
        Right-click:  show / hide the tracker
        Drag:         move it around the minimap

    If another addon provides LibDataBroker and LibDBIcon (very common), the button is registered
    through them, so minimap button bags and data bars (Titan Panel, ElvUI, ...) can show it.
    Otherwise JTS Quest Tracker draws its own button.
]]

local JQT = JTS_QuestTracker;

local NAME = "JTS_QuestTracker";
local ICON = "Interface\\AddOns\\JTS_QuestTracker\\Icon";

local function onClick(button)
    if button == "RightButton" then
        JQT:ToggleTrackerVisibility();
    else
        JQT:ToggleOptions();
    end
end

local function fillTooltip(tooltip)
    tooltip:AddLine("|cff33ff99JTS Quest Tracker|r");
    tooltip:AddLine("|cffffffffLeft-click|r  Settings", 0.8, 0.8, 0.8);
    tooltip:AddLine("|cffffffffRight-click|r  Show / hide tracker", 0.8, 0.8, 0.8);
    tooltip:AddLine("|cffffffffDrag|r  Move this button", 0.8, 0.8, 0.8);
end

local function iconSettings()
    return JQT.db.profile.MinimapIcon;
end

-- ---------------------------------------------------------------------------
-- Our own button (used when LibDBIcon isn't available)
-- ---------------------------------------------------------------------------

local ownButton;

local function placeOwnButton()
    if not ownButton then return end

    local angle = math.rad(tonumber(iconSettings().minimapPos) or 200);
    local x, y = math.cos(angle), math.sin(angle);
    local radius = (Minimap:GetWidth() / 2) + 5;

    local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND";

    if shape == "SQUARE" then
        -- Push the button out to the square's edge.
        local scale = 1 / math.max(math.abs(x), math.abs(y));
        x, y = x * scale, y * scale;
        radius = (Minimap:GetWidth() / 2) + 2;
    end

    ownButton:ClearAllPoints();
    ownButton:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius);
end

local function createOwnButton()
    local button = CreateFrame("Button", "JTS_QuestTrackerMinimapButton", Minimap);
    button:SetSize(31, 31);
    button:SetFrameStrata("MEDIUM");
    button:SetFrameLevel(8);
    button:RegisterForClicks("AnyUp");
    button:RegisterForDrag("LeftButton");
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

    local background = button:CreateTexture(nil, "BACKGROUND");
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
    background:SetSize(20, 20);
    background:SetPoint("CENTER", 0, 1);

    local icon = button:CreateTexture(nil, "ARTWORK");
    icon:SetTexture(ICON);
    icon:SetSize(18, 18);
    icon:SetPoint("CENTER", 0, 1);
    button.icon = icon;

    local border = button:CreateTexture(nil, "OVERLAY");
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
    border:SetSize(53, 53);
    border:SetPoint("TOPLEFT");

    button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end);

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT");
        fillTooltip(GameTooltip);
        GameTooltip:Show();
    end);
    button:SetScript("OnLeave", function() GameTooltip:Hide() end);

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide();

        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter();
            local scale = Minimap:GetEffectiveScale();
            local cx, cy = GetCursorPosition();

            local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360;
            iconSettings().minimapPos = angle;
            placeOwnButton();
        end);
    end);

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil);
    end);

    return button;
end

-- ---------------------------------------------------------------------------
-- Setup / refresh
-- ---------------------------------------------------------------------------

local dbIcon;      -- LibDBIcon, if we registered with it

local function setupLibraries()
    local ldb = LibStub("LibDataBroker-1.1", true);
    local icon = LibStub("LibDBIcon-1.0", true);

    if not ldb then return false end

    local launcher = ldb:GetDataObjectByName(NAME) or ldb:NewDataObject(NAME, {
        type = "launcher",
        label = "JTS Quest Tracker",
        icon = ICON,
        OnClick = function(_, mouseButton) onClick(mouseButton) end,
        OnTooltipShow = fillTooltip
    });

    if icon and launcher then
        if not icon:IsRegistered(NAME) then
            icon:Register(NAME, launcher, iconSettings());
        end

        dbIcon = icon;
    end

    return dbIcon ~= nil;
end

function JQT:UpdateMinimapButton()
    if not self.db then return end

    local settings = iconSettings();

    if dbIcon then
        -- The profile may have changed, so give LibDBIcon the current profile's table.
        pcall(dbIcon.Refresh, dbIcon, NAME, settings);

        if settings.hide then
            dbIcon:Hide(NAME);
        else
            dbIcon:Show(NAME);
        end

        return;
    end

    if settings.hide then
        if ownButton then ownButton:Hide() end
        return;
    end

    ownButton = ownButton or createOwnButton();
    placeOwnButton();
    ownButton:Show();
end

function JQT:SetupMinimapButton()
    if self.minimapReady then return end
    self.minimapReady = true;

    pcall(setupLibraries);
    self:UpdateMinimapButton();
end

-- Once in the world: our settings exist by then, and other addons have had the chance to load LibDBIcon.
local loader = CreateFrame("Frame");
loader:RegisterEvent("PLAYER_ENTERING_WORLD");
loader:SetScript("OnEvent", function(self)
    if JQT.db then
        self:UnregisterAllEvents();
        JQT:SetupMinimapButton();
    end
end);

JQT:OnSettingsApplied(function(self)
    self:UpdateMinimapButton();
end);

-- ---------------------------------------------------------------------------
-- Options (in the Buttons tab)
-- ---------------------------------------------------------------------------

JQT.buttonsTabGroups = JQT.buttonsTabGroups or {};

JQT.buttonsTabGroups.minimap = function()
    return {
        name = "Minimap Button",
        type = "group",
        inline = true,
        order = 2,

        args = {
            desc = {
                name = "Left-click the button for these settings, right-click it to show or hide the tracker, and drag it to move it around the minimap.",
                type = "description",
                fontSize = "medium",
                order = 1
            },

            show = {
                name = "Show Minimap Button",
                type = "toggle",
                width = 1.6,
                order = 2,

                get = function() return not iconSettings().hide end,
                set = function(_, value)
                    iconSettings().hide = not value;
                    JQT:UpdateMinimapButton();
                end
            },

            reset = {
                name = "Reset Position",
                type = "execute",
                width = 1.0,
                order = 3,

                func = function()
                    iconSettings().minimapPos = ns.CONSTANTS.DB_DEFAULTS.profile.MinimapIcon.minimapPos;
                    JQT:UpdateMinimapButton();
                end,

                disabled = function() return iconSettings().hide end
            }
        }
    };
end
