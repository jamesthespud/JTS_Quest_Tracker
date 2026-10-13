local _, ns = ...

--[[
    Skins (V3 alpha).

      Classic: the tracker as it has always looked.
      Modern:  a dark rounded panel, an accent bar and count pill on the header, small caps zone
               names with counts on the right, level badges, tag labels, objective counts on the
               right, rounded progress bars, check marks on finished objectives and a pill for
               "Ready to turn in". The focused quest gets a soft row highlight.

    Modern doesn't replace any drawing code: the Classic code builds the rows as usual and this file
    restyles them right after. Pooled rows are reset every time they are handed out, so switching
    back to Classic leaves nothing behind. If restyling a row fails, that row stays Classic.
]]

local JQT = JTS_QuestTracker;
local JQTL = JTS_QuestTrackerLocale;
local Compat = LibStub("JTSQTCompat-1.0");
local Font = JTS_QuestTrackerFont;
local Container = JTS_QuestTrackerContainer;

local TEX = "Interface\\AddOns\\JTS_QuestTracker\\Textures\\";
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t ";

local TEXT = { r = 0.914, g = 0.925, b = 0.937 };      -- #e9ecef
local MUTED = { r = 0.769, g = 0.788, b = 0.808 };     -- #c4c9ce
local ZONE = { r = 0.604, g = 0.631, b = 0.663 };      -- #9aa1a9
local ZONE_COUNT = { r = 0.486, g = 0.514, b = 0.545 }; -- #7c838b
local PANEL = { r = 0.067, g = 0.078, b = 0.094 };     -- #111418

function JQT:IsModernSkin()
    return self.db ~= nil and self.db.profile.Skin == "Modern";
end

local function hexColor(hex, fallback)
    hex = type(hex) == "string" and hex:gsub("#", "") or "";
    if #hex == 8 then hex = hex:sub(3) end
    if #hex ~= 6 then return fallback end

    return { r = tonumber(hex:sub(1, 2), 16) / 255, g = tonumber(hex:sub(3, 4), 16) / 255, b = tonumber(hex:sub(5, 6), 16) / 255 };
end

local function accent()
    return hexColor(JQT.db.profile.ModernAccent, { r = 0.2, g = 1, b = 0.6 });
end

-- A texture drawn from one of our rounded shapes, stretched without stretching its corners.
local function rounded(texture, file, margin)
    texture:SetTexture(TEX .. file);

    if texture.SetTextureSliceMargins then
        pcall(texture.SetTextureSliceMargins, texture, margin, margin, margin, margin);
        if texture.SetTextureSliceMode then pcall(texture.SetTextureSliceMode, texture, 0) end
    end
end

local function plain(texture)
    if texture.ClearTextureSlice then pcall(texture.ClearTextureSlice, texture) end
end

local function luminance(c)
    return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
end

-- ---------------------------------------------------------------------------
-- Row decorations (added to the tracker's text rows)
-- ---------------------------------------------------------------------------

local function regions(self)
    local d = self.modern;
    if d then return d end

    d = {};
    d.badgeBg = self:CreateTexture(nil, "ARTWORK");
    rounded(d.badgeBg, "Round4", 4);
    d.badgeText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal");

    d.accent = self:CreateTexture(nil, "ARTWORK");
    rounded(d.accent, "Round4", 1);

    d.rightBg = self:CreateTexture(nil, "ARTWORK");
    d.rightText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    d.rightText:SetJustifyH("RIGHT");

    d.pill = self:CreateTexture(nil, "BACKGROUND");
    rounded(d.pill, "Round6", 6);

    d.all = { d.badgeBg, d.badgeText, d.accent, d.rightBg, d.rightText, d.pill };
    self.modern = d;

    return d;
end

local function fontInfo(self)
    local path, size, flags = self.font:GetFont();

    return path, size or 12, flags;
end

function Font:ModernReset()
    if self.modern then
        for _, region in ipairs(self.modern.all) do region:Hide() end
    end

    self.modernLeft, self.modernRight, self.modernPadY, self.modernMinHeight, self.modernLine = 0, 0, 0, 0, nil;

    if self.barTrack then plain(self.barTrack); plain(self.barFill) end
end

function Font:ModernLayout()
    self.font:ClearAllPoints();
    self.font:SetPoint("TOPLEFT", self.modernLeft or 0, -(self.modernPadY or 0));
    self.font:SetPoint("RIGHT", -(self.modernRight or 0), 0);
end

-- Coloured badge in front of the text (the quest level).
function Font:ModernBadge(text, bg)
    local d = regions(self);
    local path, size, flags = fontInfo(self);
    local fg = luminance(bg) > 0.55 and { r = 0.06, g = 0.08, b = 0.06 } or { r = 1, g = 1, b = 1 };

    d.badgeText:SetFont(path, math.max(8, size - 2), flags);
    d.badgeText:SetText(text);
    d.badgeText:SetTextColor(fg.r, fg.g, fg.b);

    local width = math.max(16, math.ceil(d.badgeText:GetStringWidth()) + 8);
    local height = math.ceil(size) + 2;

    d.badgeBg:SetVertexColor(bg.r, bg.g, bg.b, 1);
    d.badgeBg:ClearAllPoints();
    d.badgeBg:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
    d.badgeBg:SetSize(width, height);
    d.badgeText:ClearAllPoints();
    d.badgeText:SetPoint("CENTER", d.badgeBg, "CENTER", 0, 0);
    d.badgeBg:Show();
    d.badgeText:Show();

    self.modernLeft = width + 6;
    self.modernMinHeight = height - 1;
    self:ModernLayout();
end

-- Thin accent bar in front of the text (the tracker header).
function Font:ModernAccent(color)
    local d = regions(self);
    local _, size = fontInfo(self);

    d.accent:SetVertexColor(color.r, color.g, color.b, 1);
    d.accent:ClearAllPoints();
    d.accent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    d.accent:SetSize(3, math.ceil(size) + 1);
    d.accent:Show();

    self.modernLeft = 10;
    self:ModernLayout();
end

-- Text on the right: plain, in a soft pill ("pill") or an outlined box ("box").
function Font:ModernRight(text, color, style)
    local d = regions(self);
    local path, size, flags = fontInfo(self);

    d.rightText:SetFont(path, math.max(8, size - (style == "box" and 3 or 1)), flags);
    d.rightText:SetText(text);
    d.rightText:SetTextColor(color.r, color.g, color.b);
    d.rightText:ClearAllPoints();

    local width = math.ceil(d.rightText:GetStringWidth());

    if style then
        if style == "box" then
            rounded(d.rightBg, "Round4Border", 4);
            d.rightBg:SetVertexColor(1, 1, 1, 0.22);
        else
            rounded(d.rightBg, "Round6", 6);
            d.rightBg:SetVertexColor(1, 1, 1, 0.07);
        end

        d.rightBg:ClearAllPoints();
        d.rightBg:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 2);
        d.rightBg:SetSize(width + (style == "box" and 8 or 14), math.ceil(size) + (style == "box" and 2 or 4));
        d.rightText:SetPoint("CENTER", d.rightBg, "CENTER", 0, 0);
        d.rightBg:Show();

        self.modernRight = width + (style == "box" and 8 or 14) + 6;
    else
        d.rightText:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0);
        self.modernRight = width + 8;
    end

    d.rightText:Show();
    self:ModernLayout();
end

-- Soft pill behind the text itself ("Ready to turn in").
function Font:ModernPill(color)
    local d = regions(self);
    local _, size = fontInfo(self);

    self.modernLeft, self.modernPadY = 8, 3;
    self:ModernLayout();

    local width = math.ceil(self.font:GetStringWidth()) + 16;
    local available = (self:GetWidth() or 0);
    if available > 0 then width = math.min(width, available) end

    d.pill:SetVertexColor(color.r, color.g, color.b, 0.16);
    d.pill:ClearAllPoints();
    d.pill:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    d.pill:SetSize(width, math.ceil(size) + 6);
    d.pill:Show();
end

-- Rounded progress bars.
function Font:ModernBar()
    if self.progress == nil or not self.barTrack then return end

    local c = self.progressColor or { r = 1, g = 0.85, b = 0.2 };

    rounded(self.barTrack, "Bar", 2);
    self.barTrack:SetVertexColor(1, 1, 1, 0.09);
    rounded(self.barFill, "Bar", 2);
    self.barFill:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 1);
end

-- Every row is reset when it is handed out, so nothing carries over between skins.
local fontAcquire = Font.OnAcquire;
function Font:OnAcquire(...)
    fontAcquire(self, ...);
    self:ModernReset();
    self:ModernLayout();
end

local setProgress = Font.SetProgress;
function Font:SetProgress(fraction, color)
    self.progressColor = color;

    if self.barTrack then plain(self.barTrack); plain(self.barFill) end

    return setProgress(self, fraction, color);
end

-- Objective rows keep their " - " prefix in Classic only (the timer updates its row in place).
local setLabel = Font.SetLabel;
function Font:SetLabel(label)
    if self.modernLine and type(label) == "string" then
        label = label:gsub("^ %- ", "");
    end

    return setLabel(self, label);
end

local textHeight = Font._textHeight;
function Font:_textHeight()
    local height = textHeight(self) + 2 * (self.modernPadY or 0);
    local minimum = (self.modernMinHeight or 0) + self:_barExtra();

    return math.max(height, minimum);
end

local containerAcquire = Container.OnAcquire;
function Container:OnAcquire(...)
    containerAcquire(self, ...);

    if self.modernRowBg then self.modernRowBg:Hide() end
    if self.modernDivider then self.modernDivider:Hide() end
    self.timerFont, self.headerFont = nil, nil;
end

-- Re-measures a row after restyling it, and tells the rows above about any change in height.
local function restyle(font, fn)
    local before = font:GetFullHeight();
    fn();
    font:SetHeight(font:_textHeight());

    local delta = font:GetFullHeight() - before;
    if delta ~= 0 then font:UpdateParentsHeight(delta) end
end

-- ---------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------

local function modernPanel(background)
    background.texture = background.texture or background:CreateTexture(nil, "BACKGROUND");
    background.texture:SetAllPoints();
    rounded(background.texture, "Round8", 8);

    local opacity = tonumber(JQT.db.profile.ModernOpacity) or 0.88;
    background.texture:SetVertexColor(PANEL.r, PANEL.g, PANEL.b, opacity);
    background.texture:Show();

    background.modernBorder = background.modernBorder or background:CreateTexture(nil, "BORDER");
    background.modernBorder:SetAllPoints();
    rounded(background.modernBorder, "Round8Border", 8);
    background.modernBorder:SetVertexColor(1, 1, 1, 0.08);
    background.modernBorder:Show();
end

local function classicPanel(background)
    if background.texture then
        plain(background.texture);
        background.texture:SetVertexColor(1, 1, 1, 1);
    end

    if background.modernBorder then background.modernBorder:Hide() end
end

-- Hooked onto the tracker's own background once it exists.
local function hookPanel(tracker)
    local background = tracker.background;
    if not background or background.modernHooked then return end
    background.modernHooked = true;

    local setColor = background.SetBackgroundColor;
    function background:SetBackgroundColor(color)
        if JQT:IsModernSkin() then
            modernPanel(self);
        else
            classicPanel(self);
            setColor(self, color);
        end
    end

    local setVisibility = background.SetBackgroundVisibility;
    function background:SetBackgroundVisibility(visible)
        -- The Modern panel is always there.
        return setVisibility(self, JQT:IsModernSkin() or visible);
    end
end

function JQT:ApplySkin()
    if not self.tracker then return end

    hookPanel(self.tracker);

    local p = self.db.profile;
    self.tracker:SetBackgroundColor(p.BackgroundColor);
    self.tracker:SetBackgroundVisibility(p.BackgroundAlwaysVisible or p.DeveloperMode);
    self:RefreshView();
end

hooksecurefunc(JQT, "Initialize", function(self)
    if self:IsModernSkin() then self:ApplySkin() else hookPanel(self.tracker) end
end);

JQT:OnSettingsApplied(function(self) self:ApplySkin() end);

-- ---------------------------------------------------------------------------
-- Restyling the rows
-- ---------------------------------------------------------------------------

-- The quest name without the level and tag (those get their own badge and label).
function JQT:GetModernQuestTitle(quest)
    local p = self.db.profile;
    local level, tags = p.QuestLevelDisplay, p.QuestTagStyle;

    p.QuestLevelDisplay, p.QuestTagStyle = "None", "Off";
    local ok, title = pcall(self.GetQuestHeader, self, quest);
    p.QuestLevelDisplay, p.QuestTagStyle = level, tags;

    return ok and title or quest.title or "";
end

-- What the quest name row should say (Distance.lua keeps it up to date with this).
function JQT:GetQuestRowTitle(quest)
    if self:IsModernSkin() then return self:GetModernQuestTitle(quest) end

    return self:GetQuestHeader(quest);
end

local function lastElement(container)
    return container and container.elements and container.elements[#container.elements];
end

local function headerCount(self, visible, questCount)
    local p = self.db.profile;
    local max = Compat:GetMaxQuests();

    if p.QuestLogFullWarning and tonumber(questCount) then
        if questCount >= max then
            return "Log full", self:GetStatusColor("failed");
        elseif questCount >= (tonumber(p.QuestLogWarnAt) or 36) then
            return "Log " .. questCount .. "/" .. max, self:GetDifficultyColor(3);
        end
    end

    if p.TrackerHeaderFormat == "QuestsNumberVisible" then
        return visible .. " / " .. questCount, MUTED;
    elseif p.TrackerHeaderFormat == "QuestsNumberVisibleTotal" then
        return visible .. " / " .. max, MUTED;
    end
end

local function styleTrackerHeader(self, trackerContainer, visible, questCount)
    local header = lastElement(trackerContainer);
    local font = header and header.elements and header.elements[1];
    if not font or font.type ~= "font" then return end

    restyle(font, function()
        local label = JQTL:GetString('QT_QUESTS'):upper();

        -- What you are carrying back to town (Rewards.lua).
        local summary = self.db.profile.TurnInXPSummary and self.GetTurnInSummaryText and self:GetTurnInSummaryText();
        if summary then label = label .. "  " .. self:GetStatusColorCode("complete") .. summary .. "|r" end

        font:SetLabel(label);
        font:SetColor(TEXT);
        font:SetHoverColor(TEXT);
        font:ModernAccent(accent());

        local text, color = headerCount(self, visible, questCount);
        if text then font:ModernRight(text, color, "pill") end
    end);

    -- A faint line between the header and the list.
    header.modernDivider = header.modernDivider or header:CreateTexture(nil, "ARTWORK");
    header.modernDivider:SetColorTexture(1, 1, 1, 0.07);
    header.modernDivider:ClearAllPoints();
    if self.db.profile.HeaderPosition == "Bottom" then
        -- Header below the list: the line goes between the list and the header.
        header.modernDivider:SetPoint("BOTTOMLEFT", header, "TOPLEFT", -10, 5);
        header.modernDivider:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT", 10, 5);
    else
        header.modernDivider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -10, -5);
        header.modernDivider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 10, -5);
    end
    header.modernDivider:SetHeight(1);
    header.modernDivider:Show();
end

-- The pinned header copy (StickyHeader.lua) looks like the real header.
function JQT:StyleStickyHeader(sticky, visible, questCount)
    local font = sticky.text;

    font:ModernReset();
    font:ModernLayout();

    if not self:IsModernSkin() then return end

    local label = JQTL:GetString('QT_QUESTS'):upper();
    local summary = self.db.profile.TurnInXPSummary and self.GetTurnInSummaryText and self:GetTurnInSummaryText();
    if summary then label = label .. "  " .. self:GetStatusColorCode("complete") .. summary .. "|r" end

    font:SetLabel(label);
    font:SetColor(TEXT);
    font:SetHoverColor(TEXT);
    font:ModernAccent(accent());

    local text, color = headerCount(self, visible, questCount);
    if text then font:ModernRight(text, color, "pill") end

    local opacity = tonumber(self.db.profile.ModernOpacity) or 0.88;
    sticky.bg:SetColorTexture(PANEL.r, PANEL.g, PANEL.b, math.max(opacity, 0.92));
    sticky:SetHeight((font:GetRealHeight() or 12) + 14);
end

local function styleZoneHeader(self, zone, questsInZone)
    local header = self.questsContainer.elements[#self.questsContainer.elements - 1];
    local font = header and header.elements and header.elements[1];
    if not font or font.type ~= "font" then return end

    local p = self.db.profile;

    restyle(font, function()
        font:SetSize(math.max(9, (p.ObjectiveFontSize or 12) - 1));
        font:SetLabel(tostring(zone):upper());
        font:SetColor(ZONE);
        font:SetHoverColor(TEXT);

        if p.ZoneHeaderQuestCount then font:ModernRight(tostring(questsInZone), ZONE_COUNT) end
    end);
end

local function splitObjective(text)
    local name, count = text:match("^(.-):%s*(%d+%s*/%s*%d+)$");
    if name then return name, count end

    count, name = text:match("^(%d+%s*/%s*%d+)%s+(.+)$");
    if name then return name, count end

    return text, nil;
end

local function styleQuest(self, quest, questContainer)
    local p = self.db.profile;
    local title = questContainer.headerFont;
    if not title then return end

    local flashing = self:IsFlashing(quest.questID);

    restyle(title, function()
        title:SetLabel(self:GetModernQuestTitle(quest));
        title:SetColor(flashing and self:GetStatusColor("flash") or TEXT);

        local level = tonumber(quest.level);
        if level and level > 0 then
            title:ModernBadge(tostring(level), self:GetDifficultyColor(quest.difficulty));
        end

        local okTag, tag = pcall(self.GetQuestTag, self, quest);
        if okTag and tag and p.QuestTagStyle ~= "Off" then
            local label = self:FormatQuestTag(tag, "Full"):match("^ %((.*)%)$");
            if label then title:ModernRight(label:upper(), MUTED, "box") end
        end
    end);

    local ready, failed = JQTL:GetString('QT_READY_TO_TURN_IN'), JQTL:GetString('QT_FAILED');
    local objectiveIndex = 0;

    for i = 1, #questContainer.elements do
        local row = questContainer.elements[i];

        if row.partyRow then
            -- A group member's progress (PartyProgress.lua): name on the left, progress on the right.
            local text = row.font:GetText() or "";
            local name, progress = text:match("^%s*(.-)  (.+)$");

            if name then
                local done = progress == "ready";
                restyle(row, function()
                    row:SetLabel(name);
                    row.modernLeft = 10;
                    row:ModernLayout();
                    row:ModernRight(done and (CHECK .. progress) or progress, done and self:GetStatusColor("complete") or ZONE);
                    row:SetColor(ZONE_COUNT);
                end);
            end
        elseif row ~= title and row.type == "font" then
            local text = (row.font:GetText() or ""):gsub("^ %- ", "");
            local isTimer = row == questContainer.timerFont;
            local objective;

            -- Objective rows come in the same order as the quest's objectives.
            if not isTimer and text ~= ready and text ~= failed and not quest.completed and not quest.failed then
                objectiveIndex = objectiveIndex + 1;
                objective = quest.objectives and quest.objectives[objectiveIndex];
            end

            restyle(row, function()
                row.modernLine = true;

                if text == ready then
                    local c = self:GetStatusColor("complete");
                    row:SetLabel(CHECK .. text);
                    row:SetColor(c);
                    row:ModernPill(c);
                elseif text == failed then
                    local c = self:GetStatusColor("failed");
                    row:SetLabel(text);
                    row:SetColor(c);
                    row:ModernPill(c);
                elseif isTimer then
                    row:SetLabel(text);
                else
                    local name, count = splitObjective(text);
                    local finished = objective and objective.completed and not flashing;

                    if finished then
                        row:SetLabel(CHECK .. text);
                        row:SetAlpha(0.45);
                    else
                        row:SetLabel(name);
                        if count then row:ModernRight(count, TEXT) end
                    end

                    if not flashing then row:SetColor(MUTED) end
                    row:ModernBar();
                end
            end);
        end
    end

    -- A soft highlight behind the focused quest.
    if self:IsFocused(quest.questID) then
        local bg = questContainer.modernRowBg or questContainer:CreateTexture(nil, "BACKGROUND");
        questContainer.modernRowBg = bg;
        rounded(bg, "Round8", 8);
        bg:SetVertexColor(1, 1, 1, 0.05);
        bg:ClearAllPoints();
        bg:SetPoint("TOPLEFT", questContainer, "TOPLEFT", -6, 4);
        bg:SetPoint("BOTTOMRIGHT", questContainer, "BOTTOMRIGHT", 6, 0);
        bg:Show();
    end
end

local function guarded(name, fn)
    local ok, err = pcall(fn);
    if not ok then JQT:LogError("Modern skin (" .. name .. "):", err) end
end

local addTrackerHeader = JQT.AddTrackerHeader;
function JQT:AddTrackerHeader(trackerContainer, visibleCount, questCount, ...)
    local result = addTrackerHeader(self, trackerContainer, visibleCount, questCount, ...);

    if self:IsModernSkin() then
        guarded("header", function() styleTrackerHeader(self, trackerContainer, visibleCount, questCount) end);
    end

    return result;
end

local addZone = JQT.AddZone;
function JQT:AddZone(zone, questsInZone, ...)
    local zoneContainer = addZone(self, zone, questsInZone, ...);

    if self:IsModernSkin() then
        guarded("zone", function() styleZoneHeader(self, zone, questsInZone) end);
    end

    return zoneContainer;
end

local addQuest = JQT.AddQuest;
function JQT:AddQuest(quest, parent, ...)
    local result = addQuest(self, quest, parent, ...);

    if self:IsModernSkin() then
        local questContainer = self.questContainers[#self.questContainers];
        guarded("quest", function() styleQuest(self, quest, questContainer) end);
    end

    return result;
end

-- ---------------------------------------------------------------------------
-- Welcome screen: pick a look
-- ---------------------------------------------------------------------------

if JQT.AddWelcomeSection then
    JQT:AddWelcomeSection({
        title = "Look",
        build = function(parent, width)
            local choices = {
                { key = "Classic", text = "The tracker as it has always looked." },
                { key = "Modern", text = "Dark rounded panel, level badges, counts on the right." },
            };
            local buttons = {};
            local half = (width - 20) / 2;

            local function refresh()
                for _, b in ipairs(buttons) do
                    local selected = (JQT.db.profile.Skin or "Classic") == b.key;
                    b:SetText(selected and (b.key .. "  |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t") or b.key);
                end
            end

            for i, choice in ipairs(choices) do
                local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
                button:SetSize(140, 24);
                button:SetPoint("TOPLEFT", parent, "TOPLEFT", (i - 1) * (half + 20), 0);
                button.key = choice.key;
                button:SetScript("OnClick", function()
                    JQT.db.profile.Skin = choice.key;
                    JQT:ApplySkin();
                    refresh();
                end);

                local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
                local path, _, flags = desc:GetFont();
                if path then desc:SetFont(path, 11, flags) end
                desc:SetTextColor(0.7, 0.7, 0.7);
                desc:SetJustifyH("LEFT");
                desc:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 2, -4);
                desc:SetWidth(half);
                desc:SetText(choice.text);

                buttons[i] = button;
            end

            parent:SetScript("OnShow", refresh);
            refresh();

            return 46;
        end
    });
end

-- ---------------------------------------------------------------------------
-- Options (Appearance > Skin)
-- ---------------------------------------------------------------------------

JQT.skinOptions = function()
    local function set(info, value)
        JQT.db.profile[info.arg] = value;
        JQT:ApplySkin();
    end

    local function notModern() return not JQT:IsModernSkin() end

    return {
        skin = {
            name = "Skin", order = 1, width = 1.0,
            desc = "|cffffffffClassic|r: the tracker as it has always looked.\n|cffffffffModern|r: a dark rounded panel, level badges, quest type labels, counts on the right and rounded progress bars.\n\n|cffff8000V3 alpha:|r Modern is new, please report anything that looks off.",
            type = "select", arg = "Skin", values = { Classic = "Classic", Modern = "Modern" }, sorting = { "Classic", "Modern" },
            set = set
        },
        accent = {
            name = "Accent Color", order = 2, width = 0.9,
            desc = "The color of the bar next to the tracker header in the Modern skin.",
            type = "color", hasAlpha = false, arg = "ModernAccent",
            get = function() local c = accent(); return c.r, c.g, c.b end,
            set = function(_, r, g, b)
                JQT.db.profile.ModernAccent = string.format("%02X%02X%02X", r * 255, g * 255, b * 255);
                JQT:ApplySkin();
            end,
            disabled = notModern
        },
        opacity = {
            name = "Panel Opacity", order = 3, width = 1.0,
            desc = "How solid the Modern panel is. Default is 88%.",
            type = "range", arg = "ModernOpacity", min = 0.2, max = 1, step = 0.01, isPercent = true,
            set = set, disabled = notModern
        },
    };
end
