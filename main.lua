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
local rs = game:GetService("ReplicatedStorage")
local remotes = rs:FindFirstChild("Remotes")

local isChickenFighter = (remotes and remotes:FindFirstChild("IncubatorClaim") and remotes:FindFirstChild("HatchEgg")) or workspace:FindFirstChild("NestEggs") ~= nil
local isRollAnime = (PlaceId == 107653945083776 or GameId == 107653945083776)

if not isRollAnime and not isChickenFighter then
    if rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Characters") then
        isRollAnime = true
    end
end

local targetScript = "capybara.lua"
if isChickenFighter then
    targetScript = "chicken_fighter.lua"
elseif isRollAnime then
    targetScript = "roll_anime.lua"
end

local url = BASE_URL .. targetScript
return loadstring(game:HttpGet(url))()

