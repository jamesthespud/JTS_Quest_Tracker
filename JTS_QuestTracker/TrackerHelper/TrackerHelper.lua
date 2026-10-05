

local helper = LibStub:NewLibrary("JTSQTTrackerHelper-1.0", 2);

function helper:New(options)
    local frame = JTS_QuestTrackerFrame(UIParent);

    frame:UpdateSettings(options);

    return frame;
end
