JTS_QuestTrackerLocale = {};
JTS_QuestTrackerLocale.locale = {};

local locale = 'enUS';

function JTS_QuestTrackerLocale:FallbackLocale(lang)
    lang = lang or GetLocale();

    if JTS_QuestTrackerLocale.locale[lang] then
        return lang;
    elseif lang == 'enGB' then
        return 'enUS';
    elseif lang == 'enCN' then
        return 'zhCN';
    elseif lang == 'enTW' then
        return 'zhTW';
    elseif lang == 'esMX' then
        return 'esES';
    elseif lang == 'ptPT' then
        return 'ptBR';
    end

    return 'enUS';
end

function JTS_QuestTrackerLocale:SetLocale(lang)
    locale = JTS_QuestTrackerLocale:FallbackLocale(lang);
end

function JTS_QuestTrackerLocale:GetLocale()
    return locale;
end

function JTS_QuestTrackerLocale:GetStringWrap(key)
    return function()
        return self:GetString(key);
    end
end

local unpack = unpack or table.unpack;

function JTS_QuestTrackerLocale:GetString(key, ...)
    if not key then return end

    local lang = locale;
    if not self.locale[lang] then
        lang = 'enUS';
    end

    local dictionary = self.locale[lang];
    local template = dictionary[key] or (self.locale['enUS'] and self.locale['enUS'][key]);

    if not template then
        return tostring(key) .. ' ERROR: ' .. lang .. ' key missing!';
    end

    -- convert all args to strings
    local count = select("#", ...);
    local args = { ... };
    for i = 1, count do
        args[i] = tostring(args[i]);
    end

    local ok, result = pcall(string.format, template, unpack(args, 1, count));

    -- A broken translation shouldn't take the whole options window down with it.
    return ok and result or template;
end
