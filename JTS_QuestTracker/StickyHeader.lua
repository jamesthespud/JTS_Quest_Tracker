local _, ns = ...

--[[
    Sticky header.

    The tracker header ("Quests (10/40)  3 ready · 4,250 XP") scrolls away with the list. With this,
    a copy of it stays pinned to the top of the tracker once you scroll down (or to the bottom, when
    Header Position is Bottom and you scroll up), so the counts and the turn-in XP are always in view. It is the same text, font and colors, and clicking it does what
    clicking the header does: drag to move, left-click to collapse, right-click for the menu.
]]

local JQT = JTS_QuestTracker;

local sticky;        -- the pinned copy (a frame on the tracker, above the list)
local header;        -- the real header's container, whose clicks the copy forwards
local headerArgs;    -- the counts the real header was drawn with

local function enabled()
    local p = JQT.db and JQT.db.profile;

    return p and p.TrackerHeaderEnabled and p.StickyHeader ~= false;
end

local function backgroundColor()
    local p = JQT.db.profile;
    local hex = (type(p.BackgroundColor) == "string" and p.BackgroundColor or "7F000000"):gsub("#", "");
    local a, r, g, b = 0.5, 0, 0, 0;

    if #hex == 8 then
        a = tonumber(hex:sub(1, 2), 16) / 255;
        hex = hex:sub(3);
    end
    if #hex == 6 then
        r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255;
    end

    -- Solid enough that the rows scrolling underneath don't show through.
    return r, g, b, math.max(a, 0.85);
end

local function build(tracker)
    if sticky then return sticky end

    sticky = CreateFrame("Frame", nil, tracker);
    sticky:SetHeight(24);
    -- Above the list, below the scroll bar (which sits at +20).
    sticky:SetFrameLevel((tracker:GetFrameLevel() or 0) + 19);
    sticky:EnableMouse(true);
    sticky:Hide();

    sticky.bg = sticky:CreateTexture(nil, "BACKGROUND");
    sticky.bg:SetAllPoints();

    sticky.text = JTS_QuestTrackerFont(sticky);

    -- Clicks do what they do on the real header.
    sticky:SetScript("OnMouseDown", function(_, button)
        if header and header.OnMouseDown then header:OnMouseDown(button) end
    end);
    sticky:SetScript("OnMouseUp", function(_, button)
        if header and header.OnMouseUp then header:OnMouseUp(button) end
    end);

    return sticky;
end

-- Is the header below the list? (Defined before everything that uses it.)
local function atBottom()
    return JQT.db.profile.HeaderPosition == "Bottom";
end

-- Fills in the copy from the current settings and the counts the header was drawn with.
local function fill()
    local p = JQT.db.profile;
    local text = sticky.text;

    text:SetMargin({ left = 10, right = 10, top = atBottom() and 4 or 6 });
    text:SetLabel(JQT:GetTrackerHeader(headerArgs[1], headerArgs[2]));
    text:SetSize(p.TrackerHeaderFontSize);
    text:SetColor(p.TrackerHeaderFontColor);
    text:SetHoverColor(p.TrackerHeaderFontColor);

    sticky.bg:SetColorTexture(backgroundColor());
    sticky:SetHeight((text:GetRealHeight() or 12) + 12);

    -- Skins (Skin.lua) can restyle the copy like the real header.
    if JQT.StyleStickyHeader then pcall(JQT.StyleStickyHeader, JQT, sticky, headerArgs[1], headerArgs[2]) end
end

-- Pinned to the top of the tracker, or to the bottom when the header sits below the list.
local function place(tracker)
    local edge = atBottom() and "BOTTOM" or "TOP";
    if sticky.edge == edge then return end
    sticky.edge = edge;

    sticky:ClearAllPoints();
    sticky:SetPoint(edge .. "LEFT", tracker, edge .. "LEFT", 0, 0);
    sticky:SetPoint(edge .. "RIGHT", tracker, edge .. "RIGHT", 0, 0);
end

-- How far the list is from the end where the real header is, in pixels.
local function distanceFromHeader(tracker)
    local offset = tracker:_getScrollOffset() or 0;
    if not atBottom() then return offset end

    local overflow = (tracker.content:GetHeight() or 0) - (tracker:GetHeight() or 0);

    return overflow > 1 and (overflow - offset) or 0;
end

-- Shows the copy once the real header has scrolled out of view, hides it otherwise.
function JQT:UpdateStickyHeader()
    local tracker = self.tracker;
    if not tracker then return end

    if not enabled() or not header or not headerArgs or not tracker.content then
        if sticky then sticky:Hide() end
        return;
    end

    if distanceFromHeader(tracker) > 2 then
        build(tracker);
        place(tracker);

        if not sticky:IsShown() or sticky.dirty then
            sticky.dirty = false;
            fill();
        end

        sticky:Show();
    elseif sticky then
        sticky:Hide();
    end
end

-- The real header: remember it and its counts every time it's drawn.
local addTrackerHeader = JQT.AddTrackerHeader;

function JQT:AddTrackerHeader(trackerContainer, visibleCount, questCount, ...)
    local result = addTrackerHeader(self, trackerContainer, visibleCount, questCount, ...);

    local elements = trackerContainer and trackerContainer.elements;
    header = elements and elements[#elements];
    headerArgs = { visibleCount, questCount };
    if sticky then sticky.dirty = true end

    return result;
end

-- After every redraw (new counts, new settings) and every scroll.
hooksecurefunc(JQT, "RefreshView", function(self)
    if not self.db.profile.TrackerHeaderEnabled then header, headerArgs = nil, nil end
    if sticky then sticky.dirty = true end
    self:UpdateStickyHeader();
end);

hooksecurefunc(JQT, "Initialize", function(self)
    local tracker = self.tracker;
    if not tracker or tracker.stickyHooked then return end
    tracker.stickyHooked = true;

    -- Every way of scrolling (wheel, scroll bar, redraw) ends here.
    hooksecurefunc(tracker, "_clampScroll", function() JQT:UpdateStickyHeader() end);
end);

-- ---------------------------------------------------------------------------
-- Option (Appearance > Tracker Header)
-- ---------------------------------------------------------------------------

JQT.stickyHeaderOptions = function()
    return {
        stickyHeader = {
            name = "Keep Header in View", order = 4, width = 1.4,
            desc = "When you scroll down the list, the header (with your quest count and turn-in XP) stays pinned to the top of the tracker instead of scrolling away.",
            type = "toggle", arg = "StickyHeader",
            set = function(info, value)
                JQT.db.profile[info.arg] = value;
                if sticky then sticky.dirty = true end
                JQT:UpdateStickyHeader();
            end,
            disabled = function() return not JQT.db.profile.TrackerHeaderEnabled end
        },
    };
end
