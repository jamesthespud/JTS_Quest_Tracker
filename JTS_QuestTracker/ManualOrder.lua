local _, ns = ...

--[[
    Manual order: with Sorting set to "Manual (drag to reorder)", drag a quest up or down to move it.
    A green line shows where it will go. The order is saved per character (db.char.ManualOrder,
    questID -> position); new quests go to the end. With zone headers on, quests move within their
    zone (zones keep their own order).

    Dragging uses the tracker's own drag detection, so it is off while the tracker is locked
    (Lock Frame, or Lock in Combat during a fight).
]]

local JQT = JTS_QuestTracker;

local GREEN = { r = 0.2, g = 1, b = 0.6 };

local function manual()
    return JQT.db and JQT.db.profile.Sorting == "ByManual";
end

local dragging;  -- the quest row being dragged
local startY;    -- where the cursor was when the drag began
local MIN_MOVE = 6; -- a smaller wobble is still a click
local line;      -- the drop marker
local driver;    -- moves the marker with the cursor

local function cursorY(frame)
    local _, y = GetCursorPosition();
    local scale = frame:GetEffectiveScale() or 1;

    return y and (y / scale) or nil;
end

-- The rows the dragged one can move between (same zone), top to bottom.
local function siblingsOf(row)
    local list = {};
    local parent = row:GetParent();

    for _, other in ipairs(JQT.questContainers or {}) do
        if other:GetParent() == parent then list[#list + 1] = other end
    end

    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end);

    return list;
end

-- Where the dragged row would land: the row to put it before (nil = at the end of its zone).
local function dropTarget(row)
    local y = cursorY(row);
    if not y then return nil end

    for _, other in ipairs(siblingsOf(row)) do
        if other ~= row then
            local top, bottom = other:GetTop(), other:GetBottom();

            if top and bottom and y > (top + bottom) / 2 then
                return other;
            end
        end
    end

    return nil;
end

local function placeLine(row)
    local tracker = JQT.tracker;
    if not tracker or not line then return end

    local target = dropTarget(row);
    local siblings = siblingsOf(row);
    local anchor = target or siblings[#siblings];
    if not anchor then return end

    line:ClearAllPoints();
    if target then
        line:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -4, 1);
        line:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 4, 1);
    else
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, -1);
        line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 4, -1);
    end
    line:Show();
end

local function stopDrag()
    if dragging then dragging:SetAlpha(1) end
    if line then line:Hide() end
    if driver then driver:Hide() end
end

local function startDrag(row)
    local tracker = JQT.tracker;
    if not tracker then return end

    dragging = row;
    startY = cursorY(row);
    row.manualMoved = nil;
    row:SetAlpha(0.5);

    if not line then
        line = tracker:CreateTexture(nil, "OVERLAY");
        line:SetColorTexture(GREEN.r, GREEN.g, GREEN.b, 0.9);
        line:SetHeight(2);
    end

    if not driver then
        driver = CreateFrame("Frame");
        driver:SetScript("OnUpdate", function()
            if dragging then placeLine(dragging) end
        end);
    end

    driver:Show();
    placeLine(row);
end

-- Saves the new order: every tracked quest gets its position, with the dragged one moved.
local function drop(row)
    local target = dropTarget(row);
    local siblings = siblingsOf(row);

    -- The full current order (all zones), by the order the tracker drew them in.
    local all = {};
    for _, other in ipairs(JQT.questContainers or {}) do all[#all + 1] = other end
    table.sort(all, function(a, b) return (a.order or 0) < (b.order or 0) end);

    for i, other in ipairs(all) do
        if other == row then table.remove(all, i) break end
    end

    -- Before the target, or right after the last quest of its zone.
    local anchor = target or siblings[#siblings];
    local at = #all + 1;
    for i, other in ipairs(all) do
        if other == anchor then
            at = target and i or (i + 1);
            break;
        end
    end
    if anchor == row then at = #all + 1 end
    table.insert(all, math.min(at, #all + 1), row);

    local saved = {};
    for i, other in ipairs(all) do
        local quest = other.metadata and other.metadata.quest;
        if quest and quest.questID then saved[quest.questID] = i end
    end

    -- Quests not on screen keep their place after the ones that are.
    local old = JQT.db.char.ManualOrder or {};
    for questID, position in pairs(old) do
        if not saved[questID] then saved[questID] = #all + position end
    end

    JQT.db.char.ManualOrder = saved;
    JQT:RefreshView();
end

-- Quest rows are pooled: a recycled row starts without a finished drag.
local containerAcquire = JTS_QuestTrackerContainer.OnAcquire;
function JTS_QuestTrackerContainer:OnAcquire(...)
    containerAcquire(self, ...);
    self.manualMoved = nil;
end

local addQuest = JQT.AddQuest;

function JQT:AddQuest(quest, parent, ...)
    local result = addQuest(self, quest, parent, ...);

    if manual() then
        local row = self.questContainers[#self.questContainers];

        row:AddListener("OnTrackerDragStart", function() startDrag(row) end);
        row:AddListener("OnTrackerDragStop", function()
            stopDrag();
            if dragging == row then
                dragging = nil;

                local y = cursorY(row);
                if y and startY and math.abs(y - startY) >= MIN_MOVE then
                    row.manualMoved = true;
                    drop(row);
                else
                    row.manualMoved = nil; -- barely moved: let it be a click
                end
            end
        end);
    end

    return result;
end

-- A redraw in the middle of a drag (a quest updated) ends it.
hooksecurefunc(JQT, "RefreshView", function()
    if dragging and not dragging:IsShown() then
        stopDrag();
        dragging = nil;
    end
end);

function JQT:ResetManualOrder()
    self.db.char.ManualOrder = {};
    self:RefreshView();
end
