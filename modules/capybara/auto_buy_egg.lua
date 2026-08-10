--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY EGG LOADER ALIAS
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	===============================================================
]]

local success, result = pcall(function()
    local localPaths = {
        "modules/capybara/Auto buy Egg.lua",
        "Auto buy Egg.lua",
        "RitodHub/modules/capybara/Auto buy Egg.lua"
    }
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        for _, path in ipairs(localPaths) do
            if isfile(path) then
                return loadstring(readfile(path))()
            end
        end
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/capybara/Auto%20buy%20Egg.lua"))()
end)

if success and result then
    return result
else
    -- Fallback inline if file loading had issues
    return _G.AutoBuyEgg or {}
end
