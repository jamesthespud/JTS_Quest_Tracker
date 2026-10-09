local CreateClass = LibStub("JTSQTFrameClass-1.0");

JTS_QuestTrackerFont = CreateClass("Frame", "JTS_QuestTrackerFont", nil, nil, JTS_QuestTrackerBaseElement);
local Font = JTS_QuestTrackerFont;

function Font:OnAcquire()
    JTS_QuestTrackerBaseElement.OnAcquire(self);

    self.type = "font";

    if not self.font then
        self.font = self:CreateFontString(nil, nil, "GameFontNormal");
        self.font:SetParent(self);
        self.font:SetJustifyH("LEFT");

        -- The template's own font file, used when no other font is chosen (or the chosen one is missing).
        self.defaultFace = self.font:GetFont();

        -- Font strings are pooled: remember the game's own shadow so "Default" can restore it.
        self.defaultShadow = { color = { 0, 0, 0, 1 }, offset = { 1, -1 } };
        if self.font.GetShadowColor and self.font.GetShadowOffset then
            local ok, r, g, b, a = pcall(self.font.GetShadowColor, self.font);
            local okOffset, x, y = pcall(self.font.GetShadowOffset, self.font);

            if ok and r then self.defaultShadow.color = { r, g, b, a or 1 } end
            if okOffset and x then self.defaultShadow.offset = { x, y } end
        end
    end

    self.progress = nil;
    if self.barTrack then
        self.barTrack:Hide();
        self.barFill:Hide();
    end

    self.font:ClearAllPoints();
    self.font:SetPoint("TOPLEFT", 0, 0);
    self.font:SetPoint("RIGHT", 0, 0);

    self:SetColor(NORMAL_FONT_COLOR);
    self:SetHoverColor(HIGHLIGHT_FONT_COLOR);
    self:SetHovering(false);

    self:RefreshPosition();
    self:RefreshColor();
    self:Show();
end

-- Thin progress bar drawn along the bottom of the text (used for "5/20" style objectives).
local BAR_HEIGHT = 3; -- default thickness; the Progress Bar Thickness option overrides it

local function barHeight()
    local style = JTS_QuestTrackerFont.textStyle;

    return (style and tonumber(style.barHeight)) or BAR_HEIGHT;
end
local BAR_GAP = 5; -- space between the text and the bar (was 2 in 1.0.0)

local function paint(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a);
    else
        texture:SetTexture(r, g, b, a);
    end
end

function Font:_barExtra()
    return self.progress ~= nil and (barHeight() + BAR_GAP) or 0;
end

function Font:_textHeight()
    return self.font:GetHeight() + self:_barExtra();
end

function Font:_layoutBar()
    if self.progress == nil or not self.barFill then return end

    local width = self:GetWidth();

    if width and width > 0 and self.progress > 0 then
        self.barFill:SetWidth(math.max(1, width * self.progress));
        self.barFill:Show();
    else
        self.barFill:Hide();
    end
end

-- fraction: 0 to 1, or nil for no bar. color: { r, g, b }.
function Font:SetProgress(fraction, color)
    if fraction == nil then
        self.progress = nil;

        if self.barTrack then
            self.barTrack:Hide();
            self.barFill:Hide();
        end

        if self.font then
            self:SetHeight(self:_textHeight());
        end

        return;
    end

    self.progress = math.max(0, math.min(1, fraction));

    if not self.barTrack then
        self.barTrack = self:CreateTexture(nil, "ARTWORK");
        self.barTrack:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0);
        self.barTrack:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0);
        paint(self.barTrack, 1, 1, 1, 0.15);

        self.barFill = self:CreateTexture(nil, "OVERLAY");
        self.barFill:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0);

        -- The width of the fill depends on how wide the text row ends up being.
        self:SetScript("OnSizeChanged", function(row)
            row:_layoutBar();
        end);
    end

    -- Pooled rows keep their textures, so apply the current thickness every time.
    self.barTrack:SetHeight(barHeight());
    self.barFill:SetHeight(barHeight());

    color = color or { r = 1, g = 0.85, b = 0.2 };
    paint(self.barFill, color.r or 1, color.g or 1, color.b or 1, 0.95);

    self.barTrack:Show();
    self:_layoutBar();
    self:SetHeight(self:_textHeight());
end

function Font:SetLabel(label)
    self.font:SetText(label);

    self:SetHeight(self:_textHeight());
end

function Font:SetSize(size)
    if not size then return end

    local path, _, flags = self.font:GetFont();

    -- Outline and shadow come from the options (see JQT:ApplyTextStyle).
    local style = JTS_QuestTrackerFont.textStyle;

    local flagsToUse = style and style.flags or flags;
    local face = (style and style.face) or self.defaultFace or path;

    if face then
        -- SetFont returns false when the file doesn't exist on this client; fall back to the default.
        local ok, applied = pcall(self.font.SetFont, self.font, face, size, flagsToUse);

        if (not ok or applied == false) and (self.defaultFace or path) then
            self.font:SetFont(self.defaultFace or path, size, flagsToUse);
        end
    end

    if style and self.defaultShadow then
        if style.shadow == "Strong" then
            self.font:SetShadowColor(0, 0, 0, 1);
            self.font:SetShadowOffset(1.5, -1.5);
        elseif style.shadow == "Off" then
            self.font:SetShadowColor(0, 0, 0, 0);
            self.font:SetShadowOffset(0, 0);
        else
            local color, offset = self.defaultShadow.color, self.defaultShadow.offset;

            self.font:SetShadowColor(color[1], color[2], color[3], color[4]);
            self.font:SetShadowOffset(offset[1], offset[2]);
        end
    end

    self:SetHeight(self:_textHeight());
end

function Font:SetColor(color)
    if not color then return end

    self.color = self:_normalizeColor(color);

    self:RefreshColor();
end

function Font:SetHoverColor(hoverColor)
    if not hoverColor then return end

    self.hoverColor = self:_normalizeColor(hoverColor);

    self:RefreshColor();
end

function Font:SetHovering(hovering)
    self.hovering = hovering;

    self:RefreshColor();
end

function Font:RefreshSize()
    self:SetHeight(self:_textHeight());
    self:UpdateParentsHeight(self:GetFullHeight());
end

function Font:RefreshColor()
    local activeColor = self.hovering and self.hoverColor or self.color;

    self.font:SetTextColor(activeColor.r, activeColor.g, activeColor.b);
end
