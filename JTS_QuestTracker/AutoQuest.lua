local _, ns = ...

--[[
    Auto-accept and auto-turn-in (both off by default).

      Auto-accept:   quests an NPC offers (and quests your group shares with you) are accepted.
      Auto-turn-in:  finished quests are handed in; when the quest lets you pick a reward from
                     several, it stops and lets you choose.

    Hold Shift while talking to the NPC to do it yourself this time. Low-level (grey) quests are
    skipped unless "Include Low-Level Quests" is on.
]]

local JQT = JTS_QuestTracker;

local function p() return JQT.db and JQT.db.profile end

local function bypass()
    return IsShiftKeyDown and IsShiftKeyDown();
end

local function accepting()
    local profile = p();
    return profile and profile.AutoAcceptQuests and not bypass();
end

local function turningIn()
    local profile = p();
    return profile and profile.AutoTurnInQuests and not bypass();
end

local function call(fn, ...)
    if type(fn) == "function" then return pcall(fn, ...) end
end

-- ---------------------------------------------------------------------------
-- Talking to an NPC (the gossip window, or the older quest greeting)
-- ---------------------------------------------------------------------------

local function wantsQuest(info)
    if not info then return false end
    if info.isTrivial and not p().AutoAcceptTrivial then return false end
    if info.isIgnored then return false end

    return true;
end

local function onGossip()
    local gossip = C_GossipInfo;
    if not gossip then return end

    -- Hand in what's done first, then pick up what's new (one at a time: the window refreshes).
    if turningIn() and gossip.GetActiveQuests then
        local ok, active = pcall(gossip.GetActiveQuests);
        for _, info in ipairs(ok and active or {}) do
            if info.isComplete then
                call(gossip.SelectActiveQuest, info.questID);
                return;
            end
        end
    end

    if accepting() and gossip.GetAvailableQuests then
        local ok, available = pcall(gossip.GetAvailableQuests);
        for _, info in ipairs(ok and available or {}) do
            if wantsQuest(info) then
                call(gossip.SelectAvailableQuest, info.questID);
                return;
            end
        end
    end
end

local function onGreeting()
    if turningIn() and GetNumActiveQuests then
        for i = 1, GetNumActiveQuests() or 0 do
            local _, isComplete = GetActiveTitle(i);
            if isComplete then
                call(SelectActiveQuest, i);
                return;
            end
        end
    end

    if accepting() and GetNumAvailableQuests then
        for i = 1, GetNumAvailableQuests() or 0 do
            local isTrivial = GetAvailableQuestInfo and select(1, GetAvailableQuestInfo(i));
            if not isTrivial or p().AutoAcceptTrivial then
                call(SelectAvailableQuest, i);
                return;
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The quest window
-- ---------------------------------------------------------------------------

local function onDetail()
    if not accepting() then return end

    -- Quests the game accepts by itself only need acknowledging.
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        call(AcknowledgeAutoAcceptQuest);
    else
        call(AcceptQuest);
    end
end

local function onProgress()
    if turningIn() and IsQuestCompletable and IsQuestCompletable() then
        call(CompleteQuest);
    end
end

local function onComplete()
    if not turningIn() then return end

    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0;

    -- A reward to pick: that's the player's call.
    if choices > 1 then return end

    call(GetQuestReward, choices == 1 and 1 or nil);
end

local function onAcceptConfirm()
    -- An escort or group quest someone started: join it.
    if accepting() then call(ConfirmAcceptQuest) end
end

local HANDLERS = {
    GOSSIP_SHOW = onGossip,
    QUEST_GREETING = onGreeting,
    QUEST_DETAIL = onDetail,
    QUEST_PROGRESS = onProgress,
    QUEST_COMPLETE = onComplete,
    QUEST_ACCEPT_CONFIRM = onAcceptConfirm,
};

local events = CreateFrame("Frame");

for event in pairs(HANDLERS) do
    pcall(events.RegisterEvent, events, event);
end

events:SetScript("OnEvent", function(_, event)
    local handler = HANDLERS[event];
    if handler and JQT.db then
        local ok, err = pcall(handler);
        if not ok then JQT:LogError("Auto quest:", err) end
    end
end);

-- ---------------------------------------------------------------------------
-- Options (Filters & Sorting > Auto Quest)
-- ---------------------------------------------------------------------------

JQT.autoQuestOptions = function()
    local function set(info, value) JQT.db.profile[info.arg] = value end

    return {
        name = "Auto Quest",
        type = "group",
        inline = true,

        args = {
            accept = {
                name = "Auto-accept Quests", order = 1, width = 1.4,
                desc = "Accepts the quests NPCs offer you, and quests your group shares with you.\n\nHold |cffffffffShift|r while talking to the NPC to do it yourself.",
                type = "toggle", arg = "AutoAcceptQuests", set = set
            },
            turnIn = {
                name = "Auto-turn-in Quests", order = 2, width = 1.4,
                desc = "Hands in finished quests. When a quest lets you choose your reward from several, it stops so you can pick.\n\nHold |cffffffffShift|r while talking to the NPC to do it yourself.",
                type = "toggle", arg = "AutoTurnInQuests", set = set
            },
            trivial = {
                name = "Include Low-Level Quests", order = 3, width = 1.4,
                desc = "Also auto-accept grey (low-level) quests. Off by default, so your log doesn't fill up with them.",
                type = "toggle", arg = "AutoAcceptTrivial", set = set,
                disabled = function() return not JQT.db.profile.AutoAcceptQuests end
            },
        }
    };
end
