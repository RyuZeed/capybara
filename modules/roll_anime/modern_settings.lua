if _G.ModernSettings and typeof(_G.ModernSettings) == "table" and typeof(_G.ModernSettings.CreateProfileManager) == "function" then
    return _G.ModernSettings
end

local s, r = pcall(function()
    local src = game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/modules/shared/modern_settings.lua?t=" .. tostring(os.time()))
    if src and #src > 10 and not src:find("404: Not Found") then
        local fn = loadstring(src)
        if fn then return fn() end
    end
    return nil
end)
if s and typeof(r) == "table" and typeof(r.CreateProfileManager) == "function" then
    _G.ModernSettings = r
    return r
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
            local s2, r2 = pcall(function()
                local src = readfile(path)
                local fn = loadstring(src)
                if fn then return fn() end
            end)
            if s2 and typeof(r2) == "table" and typeof(r2.CreateProfileManager) == "function" then
                _G.ModernSettings = r2
                return r2
            end
        end
    end
end

return _G.ModernSettings or {}


