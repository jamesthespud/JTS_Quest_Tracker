local _, ns = ...

--[[
    Quest notes: right-click a quest > Add Note to write yourself a reminder ("need a group",
    "the item drops from the ogres"). The note shows in the quest's tooltip, and a small note icon
    after the quest name shows which quests have one (Show Note Icon, on by default).

    Notes are saved per character (db.char.QuestNotes, questID -> text) and removed when you turn
    the quest in. An abandoned quest keeps its note, in case you pick it up again.
]]

local JQT = JTS_QuestTracker;

local NAME = "JTS_QUESTTRACKER";
local MAX_LETTERS = 200;
local NOTE_ICON = "|TInterface\\AddOns\\JTS_QuestTracker\\Textures\\Note:0|t";
local NOTE_COLOR = { r = 0.95, g = 0.89, b = 0.65 };

local function notes()
    local char = JQT.db.char;
    char.QuestNotes = char.QuestNotes or {};

    return char.QuestNotes;
end

function JQT:GetQuestNote(questID)
    if not self.db or not questID then return nil end

    local note = notes()[questID];

    return (type(note) == "string" and note ~= "") and note or nil;
end

function JQT:SetQuestNote(questID, text)
    if not questID then return end

    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or "";
    notes()[questID] = text ~= "" and text:sub(1, MAX_LETTERS) or nil;

    self:RefreshView();
end

-- ---------------------------------------------------------------------------
-- Writing a note
-- ---------------------------------------------------------------------------

local function editBoxOf(dialog)
    return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox;
end

local function save(dialog, questID)
    local editBox = editBoxOf(dialog);
    if editBox and questID then JQT:SetQuestNote(questID, editBox:GetText()) end
end

StaticPopupDialogs[NAME .. "_QuestNote"] = {
    text = "%s",
    button1 = SAVE or ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 280,
    maxLetters = MAX_LETTERS,
    whileDead = true,
    hideOnEscape = true,

    OnShow = function(self, questID)
        local editBox = editBoxOf(self);
        if not editBox then return end

        editBox:SetText(JQT:GetQuestNote(questID) or "");
        editBox:SetFocus();
        editBox:HighlightText();
    end,
    OnAccept = function(self, questID) save(self, questID) end,
    EditBoxOnEnterPressed = function(self, questID)
        local dialog = self:GetParent();
        save(dialog, questID or dialog.data);
        dialog:Hide();
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
};

function JQT:EditQuestNote(quest)
    if not quest or not quest.questID then return end

    local title = "Note for |cffffd100" .. tostring(quest.title or quest.questID) .. "|r\n|cff999999(leave it empty to remove the note)|r";
    StaticPopup_Show(NAME .. "_QuestNote", title, nil, quest.questID);
end

-- Right-click menu: Add Note / Edit Note, and Remove Note when there is one.
JQT.contextMenuExtras = JQT.contextMenuExtras or {};
table.insert(JQT.contextMenuExtras, function(self, root, quest)
    local hasNote = self:GetQuestNote(quest.questID) ~= nil;

    root:CreateButton(hasNote and "Edit Note" or "Add Note", function() self:EditQuestNote(quest) end);

    if hasNote then
        root:CreateButton("Remove Note", function() self:SetQuestNote(quest.questID, nil) end);
    end
end);

-- ---------------------------------------------------------------------------
-- Showing it
-- ---------------------------------------------------------------------------

local getQuestHeader = JQT.GetQuestHeader;

function JQT:GetQuestHeader(quest)
    local header = getQuestHeader(self, quest);

    if quest and self.db and self.db.profile.ShowQuestNoteIcon ~= false and self:GetQuestNote(quest.questID) then
        header = header .. " " .. NOTE_ICON;
    end

    return header;
end

JQT.tooltipExtras = JQT.tooltipExtras or {};
table.insert(JQT.tooltipExtras, function(self, quest, tooltip)
    local note = self:GetQuestNote(quest.questID);
    if not note then return end

    local N = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 };
    tooltip:AddLine(" ");
    tooltip:AddLine(NOTE_ICON .. " Your note", N.r, N.g, N.b);
    tooltip:AddLine(note, NOTE_COLOR.r, NOTE_COLOR.g, NOTE_COLOR.b, true);
end);

-- Turned in: the note has done its job.
local events = CreateFrame("Frame");
pcall(events.RegisterEvent, events, "QUEST_TURNED_IN");

events:SetScript("OnEvent", function(_, _, questID)
    if JQT.db and questID and notes()[questID] then
        notes()[questID] = nil;
    end
end);

-- ---------------------------------------------------------------------------
-- Option (Appearance > Quest Names)
-- ---------------------------------------------------------------------------

JQT.questNoteOptions = function()
    return {
        noteIcon = {
            name = "Show Note Icon", order = 4, width = 1.4,
            desc = "Puts " .. NOTE_ICON .. " after the name of quests you wrote a note for. Right-click a quest > Add Note to write one; it shows in the quest's tooltip.",
            type = "toggle", arg = "ShowQuestNoteIcon",
            set = function(info, value)
                JQT.db.profile[info.arg] = value;
                JQT:RefreshView();
            end
        },
    };
end
