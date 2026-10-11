local _, ns = ...

--[[
    Rewards.

      - the quest tooltip lists what the quest gives: XP, money, items and the items you choose from
      - the tracker header adds what you are carrying back to town:  3 ready · 4,250 XP
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

-- Other files add their own parts to the quest tooltip here (shown above the click hints).
JQT.tooltipExtras = JQT.tooltipExtras or {};

function JQT:AddQuestTooltipExtras(quest, tooltip)
    for _, part in ipairs(self.tooltipExtras) do
        local ok, err = pcall(part, self, quest, tooltip);
        if not ok then self:LogError("Tooltip:", err) end
    end
end

-- 4250 -> "4,250"
function JQT:FormatNumber(n)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, text = pcall(BreakUpLargeNumbers, n);
        if ok and text then return text end
    end

    local text = tostring(math.floor(n));
    local formatted;

    repeat
        text, formatted = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2");
    until formatted == 0

    return text;
end

local function formatMoney(copper)
    if type(GetCoinTextureString) == "function" then
        local ok, text = pcall(GetCoinTextureString, copper);
        if ok and text then return text end
    end

    local gold, silver, cop = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100;
    local parts = {};
    if gold > 0 then parts[#parts + 1] = "|cffffd700" .. gold .. "g|r" end
    if silver > 0 then parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r" end
    if cop > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. cop .. "c|r" end

    return table.concat(parts, " ");
end

local function qualityColor(quality)
    if quality and C_Item and C_Item.GetItemQualityColor then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality);
        if ok and r then return { r = r, g = g, b = b } end
    end

    local colors = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality];
    if colors then return { r = colors.r, g = colors.g, b = colors.b } end

    return HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 };
end

local function itemLine(item)
    local icon = item.texture and ("|T" .. tostring(item.texture) .. ":0|t ") or "";
    local count = (item.count or 1) > 1 and (" x" .. item.count) or "";

    return icon .. item.name .. count;
end

-- ---------------------------------------------------------------------------
-- Tooltip
-- ---------------------------------------------------------------------------

table.insert(JQT.tooltipExtras, function(self, quest, tooltip)
    if not self.db.profile.ShowQuestRewards or not quest.questID then return end

    local H, N, grey = HIGHLIGHT_FONT_COLOR, NORMAL_FONT_COLOR, { r = 0.5, g = 0.5, b = 0.5 };
    local rewards = quest.sampleRewards or Compat:GetQuestRewards(quest.questID);

    if not rewards then
        tooltip:AddLine(" ");
        tooltip:AddLine("Rewards are still loading...", grey.r, grey.g, grey.b);
        return;
    end

    local hasAny = rewards.xp > 0 or rewards.money > 0 or #rewards.items > 0 or #rewards.choices > 0;
    if not hasAny then return end

    tooltip:AddLine(" ");
    tooltip:AddLine("Rewards", N.r, N.g, N.b);

    if rewards.xp > 0 then tooltip:AddLine(self:FormatNumber(rewards.xp) .. " XP", H.r, H.g, H.b) end
    if rewards.money > 0 then tooltip:AddLine(formatMoney(rewards.money), H.r, H.g, H.b) end

    for _, item in ipairs(rewards.items) do
        local c = qualityColor(item.quality);
        tooltip:AddLine(itemLine(item), c.r, c.g, c.b);
    end

    if #rewards.choices > 0 then
        tooltip:AddLine(#rewards.choices > 1 and "Choose one of:" or "You also get:", grey.r, grey.g, grey.b);

        for _, item in ipairs(rewards.choices) do
            local c = qualityColor(item.quality);
            tooltip:AddLine("  " .. itemLine(item), c.r, c.g, c.b);
        end
    end
end);

-- ---------------------------------------------------------------------------
-- Turn-in summary in the tracker header
-- ---------------------------------------------------------------------------

-- How many quests in your log are ready to turn in, and the XP they give together.
function JQT:GetTurnInSummary()
    local ready, xp = 0, 0;

    for questID, quest in pairs(QLH:GetQuests()) do
        if quest.completed then
            ready = ready + 1;
            xp = xp + Compat:GetQuestRewardXP(questID);
        end
    end

    return ready, xp;
end

function JQT:GetTurnInSummaryText()
    local ready, xp = self:GetTurnInSummary();
    if ready == 0 then return nil end

    local text = ready .. " ready";
    if xp > 0 then text = text .. " · " .. self:FormatNumber(xp) .. " XP" end

    return text;
end

local getTrackerHeader = JQT.GetTrackerHeader;

function JQT:GetTrackerHeader(...)
    local header = getTrackerHeader(self, ...);

    if self.db.profile.TurnInXPSummary then
        local summary = self:GetTurnInSummaryText();

        if summary then
            header = header .. "  " .. self:GetStatusColorCode("complete") .. summary .. "|r";
        end
    end

    return header;
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local function set(info, value)
    JQT.db.profile[info.arg] = value;
    JQT:RefreshView();
end

-- Appearance > Tracker Header
JQT.turnInOptions = function()
    return {
        turnInXP = {
            name = "Show Turn-in XP", order = 3, width = 1.4,
            desc = "Adds what you are carrying back to town after the header: how many quests are ready to turn in and the XP they give together, like  |cff00b2053 ready · 4,250 XP|r.",
            type = "toggle", arg = "TurnInXPSummary", set = set
        },
    };
end

-- Appearance > Quest Names
JQT.rewardTooltipOptions = function()
    return {
        rewards = {
            name = "Rewards in Tooltip", order = 2, width = 1.4,
            desc = "Hovering a quest also lists its rewards: XP, money, items and the items you can choose from.",
            type = "toggle", arg = "ShowQuestRewards", set = function(info, value) JQT.db.profile[info.arg] = value end
        },
    };
end
