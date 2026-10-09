local CreateClass = LibStub("JTSQTFrameClass-1.0");

JTS_QuestTrackerFrame = CreateClass("Frame", "JTS_QuestTrackerFrame", nil, nil, JTS_QuestTrackerBase);
local Frame = JTS_QuestTrackerFrame;

function Frame:OnCreate()
    JTS_QuestTrackerBase.OnCreate(self);

    local setWidth = self.SetWidth;
    function self:SetWidth(width)
        setWidth(self, width);
        self.content:RefreshSize();
        -- Re-anchor the frame to prevent sizing issues
        self:SetPosition(self:GetPosition());
    end

    local setHeight = self.SetHeight;
    function self:SetHeight(height)
        if not self.maxHeight then
            setHeight(self, self.content:GetFullHeight());
        else
            setHeight(self, math.min(self.content:GetFullHeight(), self.maxHeight));
        end

        -- Re-anchor the frame to prevent sizing issues
        self:SetPosition(self:GetPosition());
        self:_clampScroll();
    end

    local stopMovingOrSizing = self.StopMovingOrSizing;
    function self:StopMovingOrSizing()
        stopMovingOrSizing(self);
        self:SetUserPlaced(false);
        -- Re-anchor the frame to prevent sizing issues
        self:SetPosition(self:GetPosition());
    end
end

function Frame:OnAcquire()
    self.locked = false;
    self.background = JTS_QuestTrackerBackgroundFrame(self);

    self:SetClipsChildren(true);
    self:SetClampedToScreen(true);
    self:SetFrameStrata("BACKGROUND");
    self:SetSize(1, 1);
    self:EnableMouseWheel(true);
    self:SetMovable(true);
    self:SetBackgroundColor({
        r = 0.0,
        g = 0.0,
        b = 0.0,
        a = 0.5
    });
    self:SetPosition(0, 400);

    self:SetBackgroundVisibility(false);
    self:SetLocked(false);

    self:SetScript("OnMouseWheel", self.OnMouseWheel);

    self:Clear();
    self:SetWidth(200);
    self:SetMaxHeight(500);
end

function Frame:Clear()
    if self.content then
        self.content:Release();
    end

    self.elements = {};
    self.content = JTS_QuestTrackerContainer(self);
end

-- Element Creators

function Frame:Container(options)
    options = options or {};

    local container = JTS_QuestTrackerContainer(options.container or self.content);

    container:SetMargin(options.margin);
    container:SetBackgroundColor(options.backgroundColor);

    if options.events then
        for event, listener in pairs(options.events) do
            container:AddListener(event, listener);
        end
    end

    container:SetLocked(self.locked);
    container:UpdateParentsHeight(container:GetFullHeight());
    container:SetHidden(options.hidden);
    container:SetMetadata(options.metadata);

    return container;
end

function Frame:Font(options)
    options = options or {};

    local font = JTS_QuestTrackerFont(options.container or self.content);
    font:SetMargin(options.margin);
    font:SetColor(options.color);
    font:SetHoverColor(options.hoverColor);
    font:SetProgress(options.progress, options.progressColor);
    font:SetLabel(options.label);
    font:SetSize(options.size or 12);
    font:SetAlpha(options.alpha or 1);

    font:UpdateParentsHeight(font:GetFullHeight());

    return font;
end

-- Getters & Setters

function Frame:UpdateSettings(settings)
    if settings.maxHeight ~= nil then
        self:SetMaxHeight(settings.maxHeight);
    end

    if settings.width ~= nil then
        self:SetWidth(settings.width);
    end

    if settings.backgroundColor ~= nil then
        self:SetBackgroundColor(settings.backgroundColor);
    end

    if settings.position ~= nil then
        self:SetPosition(settings.position.x, settings.position.y);
    end

    if settings.backgroundVisible ~= nil then
        self:SetBackgroundVisibility(settings.backgroundVisible);
    end

    if settings.locked ~= nil then
        self:SetLocked(settings.locked);
    end

    if settings.scrollBar ~= nil then
        self:SetScrollBarEnabled(settings.scrollBar);
    end

    if settings.scrollBarOnHover ~= nil then
        self:SetScrollBarOnHover(settings.scrollBarOnHover);
    end

    if settings.scrollSpeed ~= nil then
        self:SetScrollSpeed(settings.scrollSpeed);
    end
end

-- Pixels moved per mouse wheel notch.
function Frame:SetScrollSpeed(speed)
    speed = tonumber(speed) or 30;
    self.scrollSpeed = math.max(5, math.min(200, speed));
end

function Frame:SetBackgroundVisibility(visible)
    self.background:SetBackgroundVisibility(visible);
end

function Frame:SetBackgroundColor(backgroundColor)
    self.background:SetBackgroundColor(backgroundColor);
end

-- Offset of our top right corner from UIParent's top right corner (what SetPosition expects).
function Frame:GetPosition()
    local x = self:GetRight();
    local y = self:GetTop();

    local parentRight = UIParent:GetRight() or GetScreenWidth();
    local parentTop = UIParent:GetTop() or GetScreenHeight();

    -- Frames that haven't been laid out yet report nothing, fall back to the last known spot.
    if not (x and y and parentRight and parentTop) then
        if self.position then
            return self.position.x, self.position.y;
        end

        return nil, nil;
    end

    return x - parentRight, y - parentTop;
end

function Frame:SetPosition(x, y)
    local current = self.position or { x = 0, y = 0 };

    if x == nil then
        x = current.x;
    end

    if y == nil then
        y = current.y;
    end

    self:ClearAllPoints();
    self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y);

    self.position = { x = x, y = y };
end

function Frame:SetMaxHeight(maxHeight)
    self.maxHeight = maxHeight;

    self:SetHeight(self:GetHeight());
end

function Frame:SetLocked(locked)
    self.locked = locked;

    if self.content then
        self.content:SetLocked(locked);
    end
end

-- Events

function Frame:OnMouseWheel(value)
    self.content:SetPoint("TOP", self, 0, self:_getScrollOffset() + (self.scrollSpeed or 30) * -value);

    self:_clampScroll(self.content);
    self:_updateScrollBar(true);
end

-- Scroll bar: a slim bar on the right edge that shows where you are while you scroll with the wheel.

local SCROLLBAR_WIDTH = 4;
local SCROLLBAR_VISIBLE_SECONDS = 1.2;
local SCROLLBAR_FADE_SECONDS = 0.4;

local function paint(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a);
    else
        texture:SetTexture(r, g, b, a);
    end
end

function Frame:SetScrollBarEnabled(enabled)
    self.scrollBarEnabled = enabled and true or false;

    if not self.scrollBarEnabled then
        self:_hideScrollBar();
    end
end

function Frame:_createScrollBar()
    if self.scrollBar then return self.scrollBar end

    local bar = CreateFrame("Frame", nil, self);
    bar:SetFrameLevel(self:GetFrameLevel() + 20);
    bar:SetWidth(SCROLLBAR_WIDTH);
    bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -3);
    bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 3);

    bar.track = bar:CreateTexture(nil, "BACKGROUND");
    bar.track:SetAllPoints(bar);
    paint(bar.track, 1, 1, 1, 0.12);

    bar.thumb = bar:CreateTexture(nil, "OVERLAY");
    bar.thumb:SetWidth(SCROLLBAR_WIDTH);
    paint(bar.thumb, 1, 0.82, 0.31, 0.9);

    -- The bar is thin, so make it easier to grab: the clickable area reaches further to the left.
    bar:EnableMouse(true);
    bar:SetHitRectInsets(-8, 0, 0, 0);

    bar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:_beginScrollDrag();
        end
    end);

    bar:SetScript("OnMouseUp", function()
        self:_endScrollDrag();
    end);

    bar:SetScript("OnEnter", function()
        self.scrollBarHovered = true;
        self:_cancelScrollBarTimer();
        bar:SetAlpha(1);
    end);

    bar:SetScript("OnLeave", function()
        self.scrollBarHovered = false;

        if not self.scrollDragging and not self.scrollHoverActive then
            self:_scheduleScrollBarFade();
        end
    end);

    bar:SetScript("OnHide", function()
        self:_endScrollDrag();
        self.scrollBarHovered = false;
    end);

    bar:Hide();
    self.scrollBar = bar;

    return bar;
end

function Frame:_cancelScrollBarTimer()
    if self.scrollBarTimer then
        self.scrollBarTimer:Cancel();
        self.scrollBarTimer = nil;
    end
end

-- Moves the list so that `ratio` (0 = top, 1 = bottom) of the way through it is showing.
function Frame:_scrollToRatio(ratio)
    local overflow = (self.content:GetHeight() or 0) - (self:GetHeight() or 0);

    if overflow <= 1 then return end

    self.content:SetPoint("TOP", self, 0, math.max(0, math.min(1, ratio)) * overflow);

    self:_clampScroll();
    self:_updateScrollBar(true);
end

function Frame:_beginScrollDrag()
    local bar = self.scrollBar;

    if not bar or not self.scrollBar:IsShown() then return end

    self.scrollDragging = true;
    self:_cancelScrollBarTimer();
    bar:SetAlpha(1);

    bar:SetScript("OnUpdate", function()
        self:_dragScrollBar();
    end);

    -- Jump straight to where the mouse is.
    self:_dragScrollBar();
end

function Frame:_endScrollDrag()
    local wasDragging = self.scrollDragging;
    self.scrollDragging = false;

    if self.scrollBar then
        self.scrollBar:SetScript("OnUpdate", nil);

        if wasDragging and self.scrollBar:IsShown() and not self.scrollBarHovered and not self.scrollHoverActive then
            self:_scheduleScrollBarFade();
        end
    end
end

function Frame:_dragScrollBar()
    local bar = self.scrollBar;

    if not bar or not self.scrollDragging then return end

    -- The mouse button was let go somewhere we didn't get told about.
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self:_endScrollDrag();

        return;
    end

    local _, cursorY = GetCursorPosition();
    local scale = bar:GetEffectiveScale();
    local top = bar:GetTop();
    local trackHeight, thumbHeight = self.scrollTrackHeight, self.scrollThumbHeight;

    if not (cursorY and scale and scale > 0 and top and trackHeight and thumbHeight) then return end

    local usable = trackHeight - thumbHeight;

    if usable <= 0 then return end

    -- Keep the thumb centred on the mouse.
    self:_scrollToRatio((top - cursorY / scale - thumbHeight / 2) / usable);
end

-- Optionally keeps the bar up for as long as the mouse is over the tracker (so it can be grabbed).
function Frame:SetScrollBarOnHover(enabled)
    self.scrollBarOnHover = enabled and true or false;

    if self.scrollHoverTicker then
        self.scrollHoverTicker:Cancel();
        self.scrollHoverTicker = nil;
    end

    self.scrollHoverActive = false;

    if self.scrollBarOnHover then
        self.scrollHoverTicker = C_Timer.NewTicker(0.2, function()
            self:_hoverTick();
        end);
    end
end

function Frame:_hoverTick()
    if not (self.scrollBarEnabled and self.scrollBarOnHover) then return end

    local over = self.IsMouseOver ~= nil and self:IsMouseOver() or false;

    if over then
        self.scrollHoverActive = true;
        self:_updateScrollBar(true);
    elseif self.scrollHoverActive then
        self.scrollHoverActive = false;

        if self.scrollBar and self.scrollBar:IsShown() and not self.scrollDragging and not self.scrollBarHovered then
            self:_scheduleScrollBarFade();
        end
    end
end

function Frame:_hideScrollBar()
    if self.scrollBarTimer then
        self.scrollBarTimer:Cancel();
        self.scrollBarTimer = nil;
    end

    if self.scrollBar then
        self.scrollBar:SetAlpha(1);
        self.scrollBar:Hide();
    end
end

-- Keeps the bar visible for a moment, then fades it away.
function Frame:_scheduleScrollBarFade()
    if self.scrollBarTimer then
        self.scrollBarTimer:Cancel();
    end

    local bar = self.scrollBar;
    bar:SetAlpha(1);

    self.scrollBarTimer = C_Timer.NewTimer(SCROLLBAR_VISIBLE_SECONDS, function()
        self.scrollBarTimer = nil;

        local steps, step = 8, 0;
        self.scrollBarTimer = C_Timer.NewTicker(SCROLLBAR_FADE_SECONDS / steps, function(ticker)
            step = step + 1;

            if step >= steps then
                ticker:Cancel();
                self.scrollBarTimer = nil;
                bar:Hide();
                bar:SetAlpha(1);
            else
                bar:SetAlpha(1 - step / steps);
            end
        end);
    end);
end

-- Places the thumb. Only shows the bar when the player just scrolled (`reveal`), and only if
-- there is something to scroll.
function Frame:_updateScrollBar(reveal)
    if not self.scrollBarEnabled or not self.content then return end

    local contentHeight = self.content:GetHeight() or 0;
    local viewHeight = self:GetHeight() or 0;
    local overflow = contentHeight - viewHeight;

    if overflow <= 1 or viewHeight <= 0 then
        self:_hideScrollBar();

        return;
    end

    local bar = self:_createScrollBar();

    local scrolled = math.max(0, math.min(self:_getScrollOffset(), overflow));

    local trackHeight = math.max(1, viewHeight - 6);
    local thumbHeight = math.max(16, math.min(trackHeight, trackHeight * viewHeight / contentHeight));
    local thumbOffset = (trackHeight - thumbHeight) * (scrolled / overflow);

    bar.thumb:SetHeight(thumbHeight);
    bar.thumb:ClearAllPoints();
    bar.thumb:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -thumbOffset);

    self.scrollTrackHeight = trackHeight;
    self.scrollThumbHeight = thumbHeight;

    if reveal then
        bar:Show();

        if self.scrollDragging or self.scrollBarHovered or self.scrollHoverActive then
            self:_cancelScrollBarTimer();
            bar:SetAlpha(1);
        else
            self:_scheduleScrollBarFade();
        end
    end
end

-- Helpers

-- How far the list has been scrolled: the vertical offset of the content's "TOP" anchor.
-- (GetPoint wants an index, so look through the anchors for the one called TOP.)
function Frame:_getScrollOffset()
    local count = self.content.GetNumPoints and self.content:GetNumPoints() or 1;

    for index = 1, count do
        local point, _, _, _, y = self.content:GetPoint(index);

        if point == "TOP" then
            return y or 0;
        end
    end

    return 0;
end

function Frame:_clampScroll()
    local parent = self.content:GetParent();

    local contentTop, contentBottom = self.content:GetTop(), self.content:GetBottom();
    local parentTop, parentBottom = parent:GetTop(), parent:GetBottom();

    -- Nothing to clamp until the frames have been laid out.
    if not (contentTop and contentBottom and parentTop and parentBottom) then
        self:_updateScrollBar(false);

        return;
    end

    if contentTop < parentTop then
        self.content:SetPoint("TOP", parent, 0, 0);
    elseif contentBottom > parentBottom then
        self.content:SetPoint("TOP", parent, 0, self.content:GetHeight() - parent:GetHeight());
    end

    self:_updateScrollBar(false);
end
