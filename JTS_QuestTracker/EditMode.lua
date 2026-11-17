local _, ns = ...

--[[
    Edit Mode (2.2, idea from Waltrapalo's fork).

    While WoW's Edit Mode is open (Esc > Edit Mode), the tracker gets a blue box like Blizzard's own
    frames: drag it to move the tracker, or drag the corner grip to change its width and maximum
    height. Changes are saved to your profile when you let go. Works with Tracker Scale and Grow
    Upwards. Turn it off with "Show in Edit Mode" (Window > Position & Size).
]]

local JQT = JTS_QuestTracker;

local MIN_WIDTH, MAX_WIDTH = 100, 400; -- the same limits as the Width slider
local MIN_HEIGHT = 100;

local box;       -- the blue box, created the first time Edit Mode opens
local resizing;  -- what a corner drag started from

local function enabled()
    return JQT.db and JQT.db.profile.ShowInEditMode ~= false and JQT.tracker ~= nil;
end

-- The tracker's size on screen compared to its own units (Tracker Scale).
local function relativeScale()
    local tracker = JQT.tracker;
    return (tracker:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1);
end

local function cursor()
    local x, y = GetCursorPosition();
    local scale = UIParent:GetEffectiveScale();
    return x / scale, y / scale;
end

local function maxHeightLimit()
    return math.ceil(GetScreenHeight() * UIParent:GetEffectiveScale());
end

-- Lay the box over the tracker (anchored on the same corner, so it grows the same way).
local function place(width, height)
    local tracker = JQT.tracker;
    local scale = relativeScale();
    local growUp = tracker:IsGrowingUp();
    local corner = growUp and "BOTTOMRIGHT" or "TOPRIGHT";

    width = width or tracker:GetWidth();
    height = height or math.max(tracker:GetHeight() or 0, 60);

    box:ClearAllPoints();
    box:SetPoint(corner, tracker, corner);
    box:SetSize(width * scale, height * scale);

    -- The grip goes on the free corner: the tracker is held by its right edge.
    box.grip:ClearAllPoints();
    if growUp then
        box.grip:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2);
    else
        box.grip:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 2, 2);
    end
end

local function tooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT");
    GameTooltip:AddLine(title);
    GameTooltip:AddLine(text, 1, 1, 1, true);
    GameTooltip:Show();
end

local function hideTooltip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------------------
-- Moving
-- ---------------------------------------------------------------------------

local function stopMoving(self)
    if not self.moving then return end
    self.moving = nil;
    self:StopMovingOrSizing();
    self:SetUserPlaced(false);

    local tracker = JQT.tracker;
    if not InCombatLockdown() then
        local x = self:GetRight() - UIParent:GetRight();
        local y = (tracker:IsGrowingUp() and self:GetBottom() or self:GetTop()) - UIParent:GetTop();

        tracker:SetPosition(x, y);
        JQT.db.profile.PositionX, JQT.db.profile.PositionY = tracker:GetPosition();
        if JQT.RefreshQuestItemData then JQT:RefreshQuestItemData() end
    end

    place();
end

-- ---------------------------------------------------------------------------
-- Resizing (width and maximum height, in the tracker's own units)
-- ---------------------------------------------------------------------------

local function preview()
    local x, y = cursor();
    local scale = resizing.scale;

    -- Dragging left widens; dragging away from the anchored edge makes it taller.
    local dx = (resizing.x - x) / scale;
    local dy = (resizing.growUp and (y - resizing.y) or (resizing.y - y)) / scale;

    resizing.width = math.floor(math.max(MIN_WIDTH, math.min(MAX_WIDTH, resizing.startWidth + dx)) + 0.5);
    resizing.height = math.floor(math.max(MIN_HEIGHT, math.min(maxHeightLimit(), resizing.startHeight + dy)) + 0.5);

    place(resizing.width, resizing.height);
end

local function stopResizing(grip, save)
    grip:SetScript("OnUpdate", nil);
    if not resizing then return end

    if save and not InCombatLockdown() then
        preview();

        local p = JQT.db.profile;
        p.Width, p.MaxHeight = resizing.width, resizing.height;
        JQT.tracker:UpdateSettings({ width = p.Width, maxHeight = p.MaxHeight });
        JQT:RefreshView();
    end

    resizing = nil;
    place();
end

-- ---------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------

local function createBox()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate");
    frame:SetFrameStrata("DIALOG");
    frame:SetMovable(true);
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 });
    frame:SetBackdropColor(0.10, 0.37, 0.58, 0.28);
    frame:SetBackdropBorderColor(0.42, 0.78, 1, 1);

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    label:SetPoint("CENTER");
    label:SetText("JTS Quest Tracker");

    frame:SetScript("OnEnter", function(self)
        tooltip(self, "JTS Quest Tracker", "Drag to move. Drag the corner grip to change the width and maximum height.");
    end);
    frame:SetScript("OnLeave", hideTooltip);
    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        hideTooltip(self);
        self.moving = true;
        self:StartMoving();
    end);
    frame:SetScript("OnDragStop", stopMoving);

    local grip = CreateFrame("Frame", nil, frame, "BackdropTemplate");
    frame.grip = grip;
    grip:SetSize(18, 18);
    grip:EnableMouse(true);
    grip:RegisterForDrag("LeftButton");
    grip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" });
    grip:SetBackdropColor(0.42, 0.78, 1, 0.9);

    local gripLabel = grip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    gripLabel:SetPoint("CENTER");
    gripLabel:SetText("+");

    grip:SetScript("OnEnter", function(self)
        tooltip(self, "Resize", "Drag to change the tracker's width and maximum height.");
    end);
    grip:SetScript("OnLeave", hideTooltip);
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        hideTooltip(self);

        local x, y = cursor();
        local tracker = JQT.tracker;
        resizing = {
            x = x, y = y, scale = relativeScale(), growUp = tracker:IsGrowingUp(),
            startWidth = tracker:GetWidth(),
            startHeight = math.max(tracker:GetHeight() or 0, MIN_HEIGHT),
        };
        self:SetScript("OnUpdate", preview);
    end);
    grip:SetScript("OnMouseUp", function(self) stopResizing(self, true) end);

    frame:SetScript("OnHide", function(self)
        hideTooltip(self);
        hideTooltip(grip);
        stopResizing(grip, false);
        stopMoving(self);
    end);

    return frame;
end

local function show()
    if not enabled() or InCombatLockdown() then return end

    box = box or createBox();
    place();
    box:Show();
    JQT.inEditMode = true;
    if JQT.UpdateVisibility then JQT:UpdateVisibility() end
end

local function hide()
    JQT.inEditMode = nil;
    if box then box:Hide() end
    if JQT.UpdateVisibility and JQT.db then JQT:UpdateVisibility() end
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", show, JQT);
    EventRegistry:RegisterCallback("EditMode.Exit", hide, JQT);
end

-- Combat closes Edit Mode anyway, but don't leave the box up.
local events = CreateFrame("Frame");
pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED");
events:SetScript("OnEvent", function() if box and box:IsShown() then box:Hide() end end);

-- Option (Window > Position & Size)
JQT.editModeOptions = function()
    return {
        showInEditMode = {
            name = "Show in Edit Mode", order = 20, width = 1.6,
            desc = "In WoW's Edit Mode (Esc > Edit Mode) the tracker gets a blue box: drag it to move the tracker, or drag its corner to change the width and maximum height.",
            type = "toggle", arg = "ShowInEditMode",
            get = function() return JQT.db.profile.ShowInEditMode ~= false end,
            set = function(_, value)
                JQT.db.profile.ShowInEditMode = value;
                if not value then hide() end
            end
        },
    };
end
