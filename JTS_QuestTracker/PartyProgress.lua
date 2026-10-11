local _, ns = ...

--[[
    Party progress.

    Group members who also run JTS Quest Tracker share their quest progress through hidden addon
    messages (nothing shows in chat). On a quest you both have, their progress shows under yours:

        [12] Wolves Across the Border
         - Diseased Timber Wolf slain: 3/8
           Mike  5/8
           Anna  ready

    What is sent: quest IDs and objective counts, nothing else. Messages (prefix "JTSQT", "1" is
    the protocol version):

        R1                        please send me everything (sent when joining a group)
        S1|<id>|<n>/<of>|<list>   everything, in parts (part 1 clears what we knew about the sender)
        U1|<list>                 these quests changed
        X1|<questID>              this quest left my log

        <list> = entries joined by ";", entry = <questID>:<done/needed>,<done/needed>...  or <questID>:C (ready)

    Sending is bundled (at most about once a second) and retried if the game blocks addon messages
    for a moment, for example during some boss fights.
]]

local JQT = JTS_QuestTracker;
local QLH = LibStub("JTSQTQuestLogHelper-1.0");

local PREFIX = "JTSQT";
local VERSION = "1";
local MAX_LENGTH = 250;
local SEND_DELAY = 1.0;

local members = {};    -- sender name -> { name = <display name>, quests = { [questID] = { complete, objectives = { {done, needed} } } } }
local syncParts = {};  -- sender -> sync id being received

local function enabled()
    return JQT.db ~= nil and JQT.db.profile.PartyProgress ~= false;
end

local function secret(value)
    return issecretvalue ~= nil and issecretvalue(value);
end

local function channel()
    if not IsInGroup then return nil end

    local home = LE_PARTY_CATEGORY_HOME or 1;
    local instance = LE_PARTY_CATEGORY_INSTANCE or 2;

    if IsInGroup(home) then return "PARTY" end
    if IsInGroup(instance) then return "INSTANCE_CHAT" end

    return nil;
end

-- ---------------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------------

local function shortName(name)
    if type(name) ~= "string" then return "?" end

    if type(Ambiguate) == "function" then
        local ok, short = pcall(Ambiguate, name, "short");
        if ok and type(short) == "string" and short ~= "" then return short end
    end

    return (name:gsub("%-.*$", ""));
end

local function isMe(sender)
    local mine = { GetUnitName and GetUnitName("player", true), GetUnitName and GetUnitName("player", false), UnitName and UnitName("player") };
    local short = shortName(sender);

    for _, name in ipairs(mine) do
        if type(name) == "string" and (name == sender or name == short) then return true end
    end

    return false;
end

-- The group's units, by every name a message could arrive under.
local function groupNames()
    local names = {};
    local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0;
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party";

    for i = 1, count do
        local unit = prefix .. i;

        if UnitExists and UnitExists(unit) then
            local full = GetUnitName and GetUnitName(unit, true);
            local display = (GetUnitName and GetUnitName(unit, false)) or full;

            if type(full) == "string" then
                names[full] = display;
                names[shortName(full)] = display;
            end
        end
    end

    return names;
end

-- ---------------------------------------------------------------------------
-- Encoding
-- ---------------------------------------------------------------------------

local function encodeQuest(quest)
    if quest.completed then return quest.questID .. ":C" end

    local parts = {};
    for _, objective in ipairs(quest.objectives or {}) do
        local done = tonumber(objective.fulfilled) or (objective.completed and 1 or 0);
        local needed = tonumber(objective.required) or 1;

        if objective.completed and done < needed then done = needed end
        parts[#parts + 1] = done .. "/" .. needed;
    end

    return quest.questID .. ":" .. table.concat(parts, ",");
end

local function decodeQuest(entry)
    local id, rest = entry:match("^(%d+):(.*)$");
    id = tonumber(id);
    if not id then return nil end

    if rest == "C" then return id, { complete = true, objectives = {} } end

    local objectives = {};
    for done, needed in rest:gmatch("(%d+)/(%d+)") do
        objectives[#objectives + 1] = { tonumber(done), tonumber(needed) };
    end

    return id, { complete = false, objectives = objectives };
end

-- Splits entries into messages that fit.
local function pack(head, entries)
    local messages, current = {}, nil;

    for _, entry in ipairs(entries) do
        if current and #current + 1 + #entry > MAX_LENGTH then
            messages[#messages + 1] = current;
            current = nil;
        end

        current = current and (current .. ";" .. entry) or (head .. entry);
    end

    if current then messages[#messages + 1] = current end

    return messages;
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

local outbox = {};      -- messages waiting to go out
local changed = {};     -- questIDs to send as an update
local removed = {};     -- questIDs to send as removed
local wantSync = false; -- send everything
local syncCounter = 0;
local scheduled = false;

local function sendRaw(message)
    local target = channel();
    if not target then return true end -- nobody to send to: done

    local api = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage;
    if not api then return true end

    local ok, result = pcall(api, PREFIX, message, target);
    if not ok then return true end -- give up on this one rather than loop

    -- Throttled or locked down for a moment (e.g. a boss fight): try again later.
    if result == 3 or result == 8 or result == 11 then return false end

    return true;
end

local flush;

local function schedule(delay)
    if scheduled then return end
    scheduled = true;

    C_Timer.After(delay or SEND_DELAY, function()
        scheduled = false;
        flush();
    end);
end

flush = function()
    if not enabled() or not channel() then
        outbox, changed, removed, wantSync = {}, {}, {}, false;
        return;
    end

    local quests = QLH:GetQuests();

    if wantSync then
        wantSync = false;
        changed = {};

        local entries = {};
        for _, quest in pairs(quests) do entries[#entries + 1] = encodeQuest(quest) end
        table.sort(entries);

        syncCounter = syncCounter % 999 + 1;
        local parts = pack("", entries);
        if #parts == 0 then parts = { "" } end

        for i, part in ipairs(parts) do
            outbox[#outbox + 1] = "S" .. VERSION .. "|" .. syncCounter .. "|" .. i .. "/" .. #parts .. "|" .. part;
        end
    else
        local entries = {};
        for questID in pairs(changed) do
            if quests[questID] then entries[#entries + 1] = encodeQuest(quests[questID]) end
        end
        changed = {};
        table.sort(entries);

        for _, message in ipairs(pack("U" .. VERSION .. "|", entries)) do outbox[#outbox + 1] = message end
    end

    for questID in pairs(removed) do outbox[#outbox + 1] = "X" .. VERSION .. "|" .. questID end
    removed = {};

    -- A few at a time, a moment apart.
    local sent = 0;
    while #outbox > 0 and sent < 4 do
        if not sendRaw(outbox[1]) then break end
        table.remove(outbox, 1);
        sent = sent + 1;
    end

    if #outbox > 0 then schedule(2) end
end

local function requestSync()
    if not enabled() or not channel() then return end

    sendRaw("R" .. VERSION);
    wantSync = true;
    schedule();
end

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------

local redrawPending = false;

local function redraw()
    if redrawPending then return end
    redrawPending = true;

    C_Timer.After(0.3, function()
        redrawPending = false;
        if JQT.tracker then JQT:RefreshView() end
    end);
end

local function memberFor(sender)
    local member = members[sender];

    if not member then
        local display = groupNames()[sender] or groupNames()[shortName(sender)] or shortName(sender);
        member = { name = shortName(display), quests = {} };
        members[sender] = member;
    end

    return member;
end

local function storeEntries(member, list)
    for entry in (list or ""):gmatch("[^;]+") do
        local id, progress = decodeQuest(entry);
        if id then member.quests[id] = progress end
    end
end

local function receive(message, sender)
    local kind, version, body = message:match("^(%a)(%d+)|?(.*)$");
    if not kind or version ~= VERSION then return end

    if kind == "R" then
        wantSync = true;
        schedule();
        return;
    end

    local member = memberFor(sender);

    if kind == "S" then
        local id, part, _, list = body:match("^(%d+)|(%d+)/(%d+)|(.*)$");
        if not id then return end

        if part == "1" or syncParts[sender] ~= id then
            member.quests = {};
            syncParts[sender] = id;
        end

        storeEntries(member, list);
    elseif kind == "U" then
        storeEntries(member, body);
    elseif kind == "X" then
        local questID = tonumber(body);
        if questID then member.quests[questID] = nil end
    end

    redraw();
end

-- Forget people who left the group (and everyone when we leave).
local function pruneMembers()
    if not channel() then
        if next(members) then members = {}; redraw() end
        return;
    end

    local names = groupNames();
    local pruned = false;

    for sender in pairs(members) do
        if not names[sender] and not names[shortName(sender)] then
            members[sender] = nil;
            pruned = true;
        end
    end

    if pruned then redraw() end
end

-- ---------------------------------------------------------------------------
-- Showing it
-- ---------------------------------------------------------------------------

-- { { name = "Mike", progress = <their progress> }, ... } for a quest, sorted by name.
function JQT:GetPartyProgress(questID)
    local list = {};

    if not enabled() then return list end

    for _, member in pairs(members) do
        local progress = member.quests[questID];
        if progress then list[#list + 1] = { name = member.name, progress = progress } end
    end

    table.sort(list, function(a, b) return a.name < b.name end);

    return list;
end

function JQT:FormatPartyProgress(progress)
    if progress.complete then return "ready" end

    local parts = {};
    for _, objective in ipairs(progress.objectives) do
        parts[#parts + 1] = objective[1] .. "/" .. objective[2];
    end

    return #parts > 0 and table.concat(parts, " · ") or "on it";
end

local GREY = { r = 0.62, g = 0.62, b = 0.62 };

local addQuest = JQT.AddQuest;

function JQT:AddQuest(quest, parent, ...)
    local result = addQuest(self, quest, parent, ...);

    local others = quest.sampleParty or self:GetPartyProgress(quest.questID);
    if #others == 0 then return result end

    local p = self.db.profile;
    local questContainer = self.questContainers[#self.questContainers];
    questContainer.partyRows = {};

    for _, other in ipairs(others) do
        local done = other.progress.complete;
        local color = done and self:GetStatusColor("complete") or GREY;

        local row = self.tracker:Font({
            label = "    " .. other.name .. "  " .. self:FormatPartyProgress(other.progress),
            size = math.max(8, (p.ObjectiveFontSize or 12) - 1),
            color = color,
            container = questContainer,
            margin = { bottom = 2 }
        });

        row.partyRow = true; -- so a skin can tell it from the objectives
        questContainer.partyRows[#questContainer.partyRows + 1] = row;
    end

    return result;
end

-- Tooltip: who in the group has this quest.
JQT.tooltipExtras = JQT.tooltipExtras or {};
table.insert(JQT.tooltipExtras, function(self, quest, tooltip)
    local others = quest.sampleParty or self:GetPartyProgress(quest.questID);
    if #others == 0 then return end

    local N, H = NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR;
    tooltip:AddLine(" ");
    tooltip:AddLine("Your group", N.r, N.g, N.b);

    for _, other in ipairs(others) do
        tooltip:AddDoubleLine(other.name, self:FormatPartyProgress(other.progress), H.r, H.g, H.b, H.r, H.g, H.b);
    end
end);

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local events = CreateFrame("Frame");

for _, event in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, event);
end

local registered = false;
local wasInGroup = false;
local rosterSize = 0;

local function register()
    if registered then return end

    local api = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix;
    if api then pcall(api, PREFIX) end

    registered = true;
end

events:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix ~= PREFIX or secret(text) or secret(sender) or type(text) ~= "string" or not enabled() then return end
        if isMe(sender) then return end

        receive(text, sender);
    elseif event == "PLAYER_REGEN_ENABLED" then
        if #outbox > 0 then schedule(0.5) end
    else
        register();

        local inGroup = channel() ~= nil;
        local size = (GetNumGroupMembers and GetNumGroupMembers()) or 0;

        -- Joined a group, or someone new joined ours: swap progress.
        if inGroup and (not wasInGroup or size > rosterSize) then requestSync() end

        wasInGroup, rosterSize = inGroup, size;
        pruneMembers();
    end
end);

-- Our own progress changed.
QLH:OnQuestUpdated(function(updates)
    if not enabled() or not channel() then return end

    for questID, update in pairs(updates) do
        if update.abandoned then
            removed[questID] = true;
            changed[questID] = nil;
        elseif update.accepted or update.updated then
            changed[questID] = true;
        end
    end

    schedule();
end);

-- ---------------------------------------------------------------------------
-- Option (Alerts > Group)
-- ---------------------------------------------------------------------------

JQT.partyProgressOptions = function()
    return {
        name = "Party Progress", order = 2, width = 1.6,
        desc = "Group members who also use JTS Quest Tracker see each other's progress: on a quest you share, theirs shows under yours (and in its tooltip), like  |cff9e9e9eMike  5/8|r.\n\nOnly quest IDs and objective counts are shared, through hidden addon messages, so nothing shows in chat. Turning this off stops both sharing and showing.",
        type = "toggle", arg = "PartyProgress",
        set = function(info, value)
            JQT.db.profile[info.arg] = value;
            if value then requestSync() else members = {} end
            JQT:RefreshView();
        end
    };
end

-- For tests and /jtsqt status.
function JQT:GetPartyProgressMembers()
    return members;
end
