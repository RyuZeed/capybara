--[[
	===============================================================
	⚡ RITOD HUB - UNIVERSAL MASTER LAUNCHER (V3.5)
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

return loadstring(game:HttpGet(url))()
