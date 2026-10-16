local _, ns = ...

--[[
    Clean Up Quest Log: abandons grey (too low level) and failed quests in one go, after a
    confirmation that lists them. Kept: pinned quests, grey quests that are ready to turn in, and
    anything the game says can't be abandoned.

    In the tracker header's right-click menu (with how many there are), and /jtsqt cleanup.
    Quests are abandoned a quarter second apart so the quest log keeps up.
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

local NAME = "JTS_QUESTTRACKER";
local LIST_MAX = 10; -- names shown in the confirmation; the rest are counted
local GAP = 0.25;

local function say(message)
    print(ns.CONSTANTS.LOGGER.PREFIX .. ns.CONSTANTS.LOGGER.TYPES.INFO.COLOR, message);
end

local function canAbandon(questID)
    local api = C_QuestLog and C_QuestLog.CanAbandonQuest;
    if not api then return true end

    local ok, can = pcall(api, questID);

    return not ok or can ~= false;
end

-- The quests Clean Up would abandon, lowest level first.
function JQT:GetCleanupQuests()
    local list = {};

    for _, quest in pairs(QLH:GetQuests()) do
        local grey = quest.difficulty == 0 and not quest.completed;

        if (grey or quest.failed) and not self:IsPinned(quest.questID) and canAbandon(quest.questID) then
            list[#list + 1] = quest;
        end
    end

    table.sort(list, function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return tostring(a.title) < tostring(b.title);
    end);

    return list;
end

local function describe(quest)
    local name = "[" .. tostring(quest.level or "?") .. "] " .. tostring(quest.title);

    return quest.failed and (name .. " |cffff4040(failed)|r") or name;
end

local pending; -- quests waiting to be abandoned

local function abandonNext(done)
    local quest = pending and table.remove(pending, 1);

    if not quest then
        pending = nil;
        say("Cleaned up your quest log: abandoned " .. done .. (done == 1 and " quest." or " quests."));
        return;
    end

    -- Still in the log (and still something to clean up)?
    if Compat:GetLogIndex(quest.questID) then
        Compat:AbandonQuest(quest.questID);
        done = done + 1;
    end

    C_Timer.After(GAP, function() abandonNext(done) end);
end

StaticPopupDialogs[NAME .. "_CleanUp"] = {
    text = "%s",
    button1 = ABANDON_QUEST_ABBREV or "Abandon",
    button2 = CANCEL,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,

    OnAccept = function(_, quests)
        if pending or type(quests) ~= "table" then return end

        pending = {};
        for _, quest in ipairs(quests) do pending[#pending + 1] = quest end

        if PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST then
            pcall(PlaySound, SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST);
        end

        abandonNext(0);
    end,
};

function JQT:CleanUpQuestLog()
    if pending then
        say("Still cleaning up your quest log...");
        return;
    end

    local quests = self:GetCleanupQuests();

    if #quests == 0 then
        say("Nothing to clean up: you have no grey or failed quests (pinned ones are always kept).");
        return;
    end

    local lines = {};
    for i = 1, math.min(#quests, LIST_MAX) do lines[#lines + 1] = describe(quests[i]) end
    if #quests > LIST_MAX then lines[#lines + 1] = "and " .. (#quests - LIST_MAX) .. " more" end

    local text = "Abandon " .. (#quests == 1 and "this quest" or ("these " .. #quests .. " quests")) .. "?\n\n"
        .. table.concat(lines, "\n")
        .. "\n\n|cff999999Pinned quests and grey quests that are ready to turn in are kept.|r";

    StaticPopup_Show(NAME .. "_CleanUp", text, nil, quests);
end

function JQT:IsCleaningUpQuestLog()
    return pending ~= nil;
end
