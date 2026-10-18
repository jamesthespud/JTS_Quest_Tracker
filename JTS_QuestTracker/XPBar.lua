local _, ns = ...

--[[
    XP bar under the tracker header (2.0).

    A thin bar shows how far you are through your level. The XP from quests that are ready to turn
    in is drawn on top in a lighter shade, so you can see what handing them in will do; when they
    are enough to level you, that part turns gold and the header says "Level up!". Hover the
    header for the numbers (and your rested XP).

    Hidden at max level and when XP gain is turned off. Uses the tracker's own progress bar on the
    header row (Font:SetProgress), so it follows Progress Bar Thickness and both skins.
]]

local JQT = JTS_QuestTracker;
local Font = JTS_QuestTrackerFont;

local FILL = { r = 0.42, g = 0.36, b = 1.0 };         -- XP you have
local PENDING = { r = 0.40, g = 0.85, b = 1.0, a = 0.55 }; -- XP waiting in finished quests
local LEVEL_UP = { r = 1.0, g = 0.82, b = 0.0, a = 0.85 }; -- ...when it is enough to level

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end

    local ok, a, b = pcall(fn, ...);
    if not ok then return nil end

    return a, b;
end

local function number(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value or nil;
end

-- Level, XP, XP needed, rested XP; nil when there is no XP to show.
function JQT:GetXPState()
    local level = number(call(UnitLevel, "player"));
    local current = number(call(UnitXP, "player"));
    local max = number(call(UnitXPMax, "player"));
    if not level or not current or not max or max <= 0 then return nil end

    local cap = number(call(GetMaxLevelForPlayerExpansion)) or number(MAX_PLAYER_LEVEL);
    if cap and level >= cap then return nil end
    if call(IsXPUserDisabled) == true then return nil end

    return level, current, max, number(call(GetXPExhaustion)) or 0;
end

local function turnInXP()
    if not JQT.GetTurnInSummary then return 0 end

    local _, xp = JQT:GetTurnInSummary();

    return tonumber(xp) or 0;
end

local function enabled()
    return JQT.db and JQT.db.profile.ShowXPBar ~= false;
end

-- true when the quests that are ready to turn in would level you up.
function JQT:TurnInsLevelYouUp()
    local _, current, max = self:GetXPState();
    if not current then return false end

    local pending = turnInXP();

    return pending > 0 and current + pending >= max;
end

-- ---------------------------------------------------------------------------
-- The pending part of the bar (drawn after the fill, on the same row)
-- ---------------------------------------------------------------------------

local layoutBar = Font._layoutBar;

function Font:_layoutBar(...)
    layoutBar(self, ...);

    local texture = self.xpPendingTexture;
    if not texture then return end

    local width = self:GetWidth();
    local progress = self.progress or 0;
    local pending = math.min(self.xpPending or 0, 1 - progress);

    if self.progress ~= nil and width and width > 0 and pending > 0 then
        texture:ClearAllPoints();
        texture:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", width * progress, 0);
        texture:SetSize(math.max(1, width * pending), self.barFill and self.barFill:GetHeight() or 3);
        texture:Show();
    else
        texture:Hide();
    end
end

-- Rows are pooled: a reused row must not keep the XP shade.
local fontAcquire = Font.OnAcquire;

function Font:OnAcquire(...)
    fontAcquire(self, ...);

    self.xpPending = nil;
    self.isXPBar = nil;
    if self.xpPendingTexture then self.xpPendingTexture:Hide() end
end

local function setBar(font)
    local level, current, max = JQT:GetXPState();

    if not enabled() or not level then
        if font.isXPBar then
            font.isXPBar = nil;
            font.xpPending = nil;
            font:SetProgress(nil);
            if font.xpPendingTexture then font.xpPendingTexture:Hide() end
        end
        return;
    end

    local pending = turnInXP();
    local levelsUp = pending > 0 and current + pending >= max;

    if not font.xpPendingTexture then
        font.xpPendingTexture = font:CreateTexture(nil, "OVERLAY", nil, 1);
    end

    local shade = levelsUp and LEVEL_UP or PENDING;
    font.xpPendingTexture:SetColorTexture(shade.r, shade.g, shade.b, shade.a);

    font.isXPBar = true;
    font.xpPending = pending / max;
    font:SetProgress(current / max, FILL);
end

-- Adding or removing the bar changes the header's height: tell the rows above (like Skin.lua does).
local function apply(font)
    local before = font:GetFullHeight();
    setBar(font);
    font:SetHeight(font:_textHeight());

    local delta = font:GetFullHeight() - before;
    if delta ~= 0 then font:UpdateParentsHeight(delta) end
end

-- The header row of the tracker that is drawn now.
local headerFont;

-- A header row given back to the pool is no longer ours to update.
local fontRelease = Font.OnRelease;

function Font:OnRelease(...)
    if fontRelease then fontRelease(self, ...) end

    self.isXPBar = nil;
    if headerFont == self then headerFont = nil end
end

-- AddTrackerHeader has just added the header row: it is the tracker's last element.
local function findHeaderFont(trackerContainer)
    local elements = trackerContainer.elements or {};
    local header = elements[#elements];
    local font = header and header.elements and header.elements[1];

    if font and font.type == "font" then return font, header end
end

-- The pinned header copy (StickyHeader.lua) gets the same bar, so it stays in view with the header.
function JQT:ApplyXPBar(font)
    if not font then return end

    pcall(setBar, font);
    font:SetHeight(font:_textHeight());
end

local addTrackerHeader = JQT.AddTrackerHeader;

function JQT:AddTrackerHeader(trackerContainer, ...)
    local result = addTrackerHeader(self, trackerContainer, ...);

    local ok, font, header = pcall(findHeaderFont, trackerContainer);
    if ok and font then
        headerFont = font;
        pcall(apply, font);

        -- Hover the header for the numbers.
        if header and not header.xpTooltip then
            header.xpTooltip = true;
            header:AddListener("OnEnter", function() JQT:ShowXPTooltip(header) end);
            header:AddListener("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end);
        end
    end

    return result;
end

-- The header's listeners go when the row is reused.
local containerAcquire = JTS_QuestTrackerContainer.OnAcquire;

function JTS_QuestTrackerContainer:OnAcquire(...)
    containerAcquire(self, ...);
    self.xpTooltip = nil;
end

-- "Level up!" after the turn-in summary (both skins and the pinned header use this text).
local summaryText = JQT.GetTurnInSummaryText;

if summaryText then
    function JQT:GetTurnInSummaryText(...)
        local text = summaryText(self, ...);

        if text and enabled() and self:TurnInsLevelYouUp() then
            text = text .. " · |cffffd100Level up!|r";
        end

        return text;
    end
end

-- ---------------------------------------------------------------------------
-- Tooltip
-- ---------------------------------------------------------------------------

function JQT:ShowXPTooltip(owner)
    if not enabled() or not GameTooltip then return end

    local level, current, max, rested = self:GetXPState();
    if not level then return end

    local pending = turnInXP();
    local N, H = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }, HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 };
    local function pct(x) return math.floor(x / max * 100 + 0.5) .. "%" end

    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM");
    GameTooltip:AddLine("Level " .. level, N.r, N.g, N.b);
    GameTooltip:AddDoubleLine("XP", self:FormatNumber(current) .. " / " .. self:FormatNumber(max) .. "  (" .. pct(current) .. ")", H.r, H.g, H.b, H.r, H.g, H.b);

    if pending > 0 then
        local after = current + pending;
        local result = after >= max
            and ("|cffffd100Level " .. (level + 1) .. "!|r +" .. self:FormatNumber(after - max) .. " XP")
            or pct(after);
        GameTooltip:AddDoubleLine("Ready to turn in", "+" .. self:FormatNumber(pending) .. " XP  ->  " .. result, H.r, H.g, H.b, H.r, H.g, H.b);
    end

    if rested > 0 then
        GameTooltip:AddDoubleLine("Rested", self:FormatNumber(rested) .. " XP", H.r, H.g, H.b, 0.4, 0.6, 1);
    end

    GameTooltip:AddDoubleLine("To level " .. (level + 1), self:FormatNumber(math.max(0, max - current)) .. " XP", H.r, H.g, H.b, H.r, H.g, H.b);
    GameTooltip:Show();
end

-- ---------------------------------------------------------------------------
-- Keeping it current
-- ---------------------------------------------------------------------------

local events = CreateFrame("Frame");

for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
    pcall(events.RegisterEvent, events, event);
end

events:SetScript("OnEvent", function(_, event)
    if not JQT.tracker or not JQT.db then return end

    -- A new level can change the header text ("Level up!" goes away) and turn quests grey: redraw.
    if event == "PLAYER_LEVEL_UP" then
        C_Timer.After(0.5, function() JQT:RefreshView() end);
        return;
    end

    -- Otherwise just move the bar.
    if headerFont and headerFont.isXPBar then pcall(apply, headerFont) end
    if JQT.RefreshStickyHeader then JQT:RefreshStickyHeader() end
end);

-- ---------------------------------------------------------------------------
-- Option (Appearance > Tracker Header)
-- ---------------------------------------------------------------------------

JQT.xpBarOptions = function()
    return {
        xpBar = {
            name = "Show XP Bar", order = 3.5, width = 1.4,
            desc = "A thin bar under the header shows how far you are through your level. The XP from quests that are ready to turn in is drawn on top in a lighter shade, and turns |cffffd100gold|r when handing them in would level you up (the header then says Level up!).\n\nHover the header for the numbers and your rested XP. Hidden at max level.",
            type = "toggle", arg = "ShowXPBar",
            set = function(info, value)
                JQT.db.profile[info.arg] = value;
                JQT:RefreshView();
            end
        },
    };
end
