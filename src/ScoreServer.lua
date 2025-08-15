-- ScoreServer
-- Random points + secure multipliers, critical hits, streaks, and a daily login bonus.
-- Saves score; notifies the client about each grant so the client can animate/sound.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--== DataStores ==--
local SCORE_DS    = DataStoreService:GetDataStore("PlayerScore_V2") -- bumped to V2 for new features
local DAILY_DS    = DataStoreService:GetDataStore("DailyBonus_V1")

--== Remotes ==--
local REQUEST_EVENT_NAME = "RequestRandomPoints" -- client -> server (asks for points)
local GRANTED_EVENT_NAME = "PointsGranted"       -- server -> client (tells what happened)

local RequestEvent = ReplicatedStorage:FindFirstChild(REQUEST_EVENT_NAME)
if not RequestEvent then
	RequestEvent = Instance.new("RemoteEvent")
	RequestEvent.Name = REQUEST_EVENT_NAME
	RequestEvent.Parent = ReplicatedStorage
end

local GrantedEvent = ReplicatedStorage:FindFirstChild(GRANTED_EVENT_NAME)
if not GrantedEvent then
	GrantedEvent = Instance.new("RemoteEvent")
	GrantedEvent.Name = GRANTED_EVENT_NAME
	GrantedEvent.Parent = ReplicatedStorage
end

--== Tuning ==--
local CLICK_COOLDOWN = 0.5           -- seconds between accepted clicks
local CRIT_CHANCE    = 0.10          -- 10% chance to double
local STREAK_WINDOW  = 2.0           -- seconds to chain a streak
local STREAK_MAX     = 10            -- cap for multiplier growth
local STREAK_STEP    = 0.05          -- +5% per streak step (up to +50%)
local DAILY_BONUS    = 500           -- points on first join of the UTC day

--== Internal state ==--
local lastClickAt: {[number]: number} = {}
local streakCount: {[number]: number} = {} -- grows while clicking within STREAK_WINDOW

--== Helpers ==--
local function tryDS(fn, retries)
	retries = retries or 3
	local lastErr
	for i = 1, retries do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		task.wait(2 ^ i * 0.2)
	end
	return false, tostring(lastErr)
end

local function loadScore(userId: number): number
	local key = "score_" .. userId
	local ok, result = tryDS(function()
		return SCORE_DS:GetAsync(key)
	end)
	if ok and typeof(result) == "number" then
		return math.max(0, math.floor(result))
	end
	return 0
end

local function saveScore(userId: number, value: number)
	local key = "score_" .. userId
	tryDS(function()
		SCORE_DS:SetAsync(key, value)
	end)
end

local function isSameUTCDate(t1: number, t2: number): boolean
	-- Compare year-month-day in UTC
	local d1 = os.date("!*t", t1)
	local d2 = os.date("!*t", t2)
	return d1.year == d2.year and d1.yday == d2.yday
end

local function applyDailyBonus(plr: Player, currentScore: number): number?
	local key = "daily_" .. plr.UserId
	local now = os.time()
	local grant = false

	local ok, valueOrErr = tryDS(function()
		return DAILY_DS:GetAsync(key)
	end)

	local lastClaim = ok and valueOrErr or nil
	if lastClaim == nil or not isSameUTCDate(tonumber(lastClaim) or 0, now) then
		grant = true
	end

	if grant then
		local newScore = currentScore + DAILY_BONUS
		-- Persist both score and daily timestamp atomically-ish
		tryDS(function()
			SCORE_DS:SetAsync("score_" .. plr.UserId, newScore)
		end)
		tryDS(function()
			DAILY_DS:SetAsync(key, now)
		end)
		return newScore
	end

	return nil
end

local function currentMultiplier(uid: number): number
	local steps = math.clamp(streakCount[uid] or 0, 0, STREAK_MAX)
	return 1 + steps * STREAK_STEP
end

local function maybeCritical(): boolean
	return math.random() < CRIT_CHANCE
end

local function grantPoints(plr: Player)
	-- Cooldown
	local now = os.clock()
	if (lastClickAt[plr.UserId] or -math.huge) + CLICK_COOLDOWN > now then
		return
	end

	-- Streak tracking
	local last = lastClickAt[plr.UserId]
	if last and (now - last) <= STREAK_WINDOW then
		streakCount[plr.UserId] = math.min((streakCount[plr.UserId] or 0) + 1, STREAK_MAX)
	else
		streakCount[plr.UserId] = 0
	end
	lastClickAt[plr.UserId] = now

	-- Base random
	local base = math.random(1, 100)

	-- Multiplier + crit are server authoritative
	local mult = currentMultiplier(plr.UserId)
	local crit = maybeCritical()
	if crit then mult *= 2 end

	local delta = math.floor(base * mult + 0.5)

	-- Update score atomically
	local key = "score_" .. plr.UserId
	local newValue = 0
	local ok = tryDS(function()
		return SCORE_DS:UpdateAsync(key, function(old)
			old = typeof(old) == "number" and old or 0
			local updated = old + delta
			newValue = updated
			return updated
		end)
	end)

	-- leaderstats mirror
	local ls = plr:FindFirstChild("leaderstats")
	local scoreVal = ls and ls:FindFirstChild("Score")
	if scoreVal and scoreVal:IsA("IntValue") then
		if ok then
			scoreVal.Value = newValue
		else
			scoreVal.Value += delta
			newValue = scoreVal.Value
			saveScore(plr.UserId, newValue)
		end
	end

	-- Notify client about exactly what happened
	GrantedEvent:FireClient(plr, {
		base = base,
		multiplier = mult,
		crit = crit,
		streak = streakCount[plr.UserId] or 0,
		delta = delta,
		newScore = newValue,
	})
end

-- Player lifecycle
Players.PlayerAdded:Connect(function(plr)
	-- leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = leaderstats

	-- load
	local saved = loadScore(plr.UserId)

	-- daily bonus (first time each UTC day)
	local maybeNew = applyDailyBonus(plr, saved)
	if maybeNew then
		saved = maybeNew
	end

	score.Value = saved

	-- Tell client about daily bonus if it happened
	if maybeNew then
		GrantedEvent:FireClient(plr, {
			base = DAILY_BONUS,
			multiplier = 1,
			crit = false,
			streak = 0,
			delta = DAILY_BONUS,
			newScore = saved,
			daily = true
		})
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local ls = plr:FindFirstChild("leaderstats")
	local scoreVal = ls and ls:FindFirstChild("Score")
	if scoreVal and scoreVal:IsA("IntValue") then
		saveScore(plr.UserId, scoreVal.Value)
	end
	lastClickAt[plr.UserId] = nil
	streakCount[plr.UserId] = nil
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		local ls = plr:FindFirstChild("leaderstats")
		local scoreVal = ls and ls:FindFirstChild("Score")
		if scoreVal and scoreVal:IsA("IntValue") then
			saveScore(plr.UserId, scoreVal.Value)
		end
	end
	if not RunService:IsStudio() then task.wait(2) end
end)

-- Requests from client
RequestEvent.OnServerEvent:Connect(function(plr)
	grantPoints(plr)
end)

