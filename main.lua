--[[
	===============================================================
	⚡ RITOD HUB - UNIVERSAL MASTER LAUNCHER (V3.4)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end

local PlaceId = game.PlaceId
local GameId = game.GameId
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/"

-- Deteksi game
local isRollAnime = (PlaceId == 107653945083776 or GameId == 107653945083776)
if not isRollAnime then
    local rs = game:GetService("ReplicatedStorage")
    if rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Characters") then
        isRollAnime = true
    end
end

local targetScript = isRollAnime and "roll_anime.lua" or "capybara.lua"
local url = BASE_URL .. targetScript

task.spawn(function()
    local success, src = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success and src and #src > 10 and not src:find("404: Not Found") then
        local fn = loadstring(src)
        if fn then
            fn()
        end
    else
        local s2, src2 = pcall(function()
            return game:HttpGet(url .. "?t=" .. tostring(os.time()))
        end)
        if s2 and src2 and #src2 > 10 and not src2:find("404: Not Found") then
            local fn2 = loadstring(src2)
            if fn2 then
                fn2()
            end
        end
    end
end)
