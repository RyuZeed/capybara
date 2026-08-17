if _G.ModernSettings and typeof(_G.ModernSettings) == "table" and typeof(_G.ModernSettings.CreateProfileManager) == "function" then
    return _G.ModernSettings
end

local localPaths = {
    "modules/shared/modern_settings.lua",
    "RitodHub/modules/shared/modern_settings.lua",
    "lucid-shannon/modules/shared/modern_settings.lua",
    "shared/modern_settings.lua",
    "../shared/modern_settings.lua"
}
if typeof(readfile) == "function" and typeof(isfile) == "function" then
    for _, path in ipairs(localPaths) do
        if isfile(path) then
            local s, r = pcall(function() return loadstring(readfile(path))() end)
            if s and typeof(r) == "table" and typeof(r.CreateProfileManager) == "function" then
                _G.ModernSettings = r
                return r
            end
        end
    end
end

local s, r = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/modern_settings.lua?t=" .. tostring(os.time())))()
end)
if s and typeof(r) == "table" and typeof(r.CreateProfileManager) == "function" then
    _G.ModernSettings = r
    return r
end

return _G.ModernSettings or {}

