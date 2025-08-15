-- ScoreClient (Bottom-left, Level Progress only)
-- Level up triggers ONLY when crossing the next level (every 1000).
-- The bar shows % progress to next level; no streak bar. No overlap with default leaderboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer
local REQUEST_EVENT = ReplicatedStorage:WaitForChild("RequestRandomPoints")
local GRANTED_EVENT = ReplicatedStorage:WaitForChild("PointsGranted")

-- Theme
local MAROON = Color3.fromRGB(128, 0, 0)
local BLACK  = Color3.fromRGB(0, 0, 0)
local WHITE  = Color3.fromRGB(255, 255, 255)

-- Sound IDs (use your own asset ids)
local SOUND_CLICK      = "rbxassetid://6042053626"
local SOUND_CRITICAL   = "rbxassetid://3165700530"
local SOUND_LEVELUP    = "rbxassetid://3120909354"
local SOUND_DAILYBONUS = "rbxassetid://75506392957470"

-- Helpers
local function levelFromScore(score: number) return math.floor(score / 1000) end
local function levelProgress(score: number) return (score % 1000) / 1000 end
local function parseInt(s: string) return tonumber(s) or 0 end

local function animateNumber(label: TextLabel, fromValue: number, toValue: number, duration: number)
	duration = math.max(0.05, duration or 0.5)
	local t0 = os.clock()
	local diff = toValue - fromValue
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / duration
		if t >= 1 then
			label.Text = tostring(toValue)
			conn:Disconnect()
			return
		end
		local eased = 1 - (1 - t) ^ 3
		label.Text = tostring(math.floor(fromValue + diff * eased + 0.5))
	end)
end

local function makeSound(parent: Instance, id: string, vol: number)
	local s = Instance.new("Sound")
	s.SoundId = id or ""
	s.Volume = vol or 0.7
	s.RollOffMaxDistance = 100
	s.Parent = parent
	return s
end
local function play(snd: Sound, pitchMin: number, pitchMax: number)
	if not snd or snd.SoundId == "" then return end
	snd.PlaybackSpeed = math.random() * (pitchMax - pitchMin) + pitchMin
	snd:Play()
end

local function floatText(root: Instance, pos: UDim2, text: string, color: Color3)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 180, 0, 26)
	lbl.Position = pos
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = root
	local up = TweenService:Create(lbl, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = pos - UDim2.new(0, 0, 0, 24),
		TextTransparency = 0
	})
	local fade = TweenService:Create(lbl, TweenInfo.new(0.35), {TextTransparency = 1})
	up:Play()
	task.delay(0.45, function() fade:Play(); fade.Completed:Wait(); lbl:Destroy() end)
end

-- UI
local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScoreUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LOCAL_PLAYER:WaitForChild("PlayerGui")

	-- Bottom-left placement (away from PlayerList/leaderboard)
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0, 1)
	container.Position = UDim2.new(0, 20, 1, -20)
	container.Size = UDim2.new(0, 356, 0, 200)
	container.BackgroundColor3 = BLACK
	container.BackgroundTransparency = 0.32
	container.BorderSizePixel = 0
	container.Parent = gui

	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 20); corner.Parent = container
	local stroke = Instance.new("UIStroke"); stroke.Color = MAROON; stroke.Thickness = 2; stroke.Parent = container

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14); pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = container

	local vlist = Instance.new("UIListLayout")
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	vlist.Padding = UDim.new(0, 10)
	vlist.Parent = container

	-- Header: Title (left) + Level Chip (right)
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	header.LayoutOrder = 1
	header.Parent = container

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -110, 1, 0)
	title.Font = Enum.Font.GothamBold
	title.Text = "Secure Score"
	title.TextColor3 = WHITE
	title.TextTransparency = 0.05
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 20
	title.Parent = header

	local levelChip = Instance.new("TextLabel")
	levelChip.Name = "LevelChip"
	levelChip.AnchorPoint = Vector2.new(1, 0)
	levelChip.Position = UDim2.new(1, 0, 0, 0)
	levelChip.Size = UDim2.new(0, 100, 1, 0)
	levelChip.BackgroundColor3 = BLACK
	levelChip.BackgroundTransparency = 0.45
	levelChip.TextColor3 = WHITE
	levelChip.Font = Enum.Font.GothamSemibold
	levelChip.TextSize = 16
	levelChip.Text = "Level 0"
	levelChip.Parent = header
	local chipCorner = Instance.new("UICorner"); chipCorner.CornerRadius = UDim.new(1, 0); chipCorner.Parent = levelChip
	local chipStroke = Instance.new("UIStroke"); chipStroke.Color = MAROON; chipStroke.Thickness = 2; chipStroke.Parent = levelChip

	-- Big Score
	local scoreHolder = Instance.new("Frame")
	scoreHolder.BackgroundTransparency = 1
	scoreHolder.Size = UDim2.new(1, 0, 0, 56)
	scoreHolder.LayoutOrder = 2
	scoreHolder.Parent = container

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Size = UDim2.new(1, 0, 1, 0)
	scoreLabel.Font = Enum.Font.GothamBlack
	scoreLabel.Text = "0"
	scoreLabel.TextColor3 = WHITE
	scoreLabel.TextScaled = true
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = scoreHolder

	-- Level Progress Bar (ONLY shows progress to next level)
	local progWrap = Instance.new("Frame")
	progWrap.Name = "ProgressWrap"
	progWrap.BackgroundTransparency = 1
	progWrap.Size = UDim2.new(1, 0, 0, 18)
	progWrap.LayoutOrder = 3
	progWrap.Parent = container

	local bar = Instance.new("Frame")
	bar.Name = "LevelBar"
	bar.Size = UDim2.new(1, 0, 0, 12)
	bar.Position = UDim2.new(0, 0, 0, 3)
	bar.BackgroundColor3 = Color3.fromRGB(20,20,20)
	bar.BackgroundTransparency = 0.38
	bar.BorderSizePixel = 0
	bar.Parent = progWrap
	local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0, 8); barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = MAROON
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 8); fillCorner.Parent = fill

	-- Button
	local button = Instance.new("TextButton")
	button.Name = "AddButton"
	button.AutoButtonColor = false
	button.Text = "+ Random Points"
	button.TextColor3 = WHITE
	button.TextScaled = true
	button.Font = Enum.Font.GothamSemibold
	button.BackgroundColor3 = BLACK
	button.BackgroundTransparency = 0.45
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, 50)
	button.LayoutOrder = 4
	button.Parent = container
	local bCorner = Instance.new("UICorner"); bCorner.CornerRadius = UDim.new(0, 12); bCorner.Parent = button
	local bStroke = Instance.new("UIStroke"); bStroke.Color = MAROON; bStroke.Thickness = 2; bStroke.Parent = button

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.28
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.45
		}):Play()
	end)

	return gui, container, scoreLabel, levelChip, button, fill
end

-- Build UI
local gui, container, scoreLabel, levelChip, button, progressFill = buildUI()

-- Sounds
local clickSound    = makeSound(gui, SOUND_CLICK,      0.55)
local critSound     = makeSound(gui, SOUND_CRITICAL,   0.75)
local levelupSound  = makeSound(gui, SOUND_LEVELUP,    0.85)
local dailySound    = makeSound(gui, SOUND_DAILYBONUS, 0.85)

-- Progress tween
local function setProgress(alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	TweenService:Create(progressFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(alpha, 0, 1, 0)
	}):Play()
end

-- Level chip update (with subtle pop only on level-up)
local function updateLevelChip(level: number, pop: boolean)
	levelChip.Text = "Level " .. tostring(level)
	if pop then
		local tw1 = TweenService:Create(levelChip, TweenInfo.new(0.08), {Size = UDim2.new(0, 110, 1, 0)})
		local tw2 = TweenService:Create(levelChip, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 100, 1, 0)})
		tw1:Play(); tw1.Completed:Wait(); tw2:Play()
	end
end

-- Wait for leaderstats/score to exist
local function waitForScoreValue(): IntValue
	local plr = LOCAL_PLAYER
	local ls = plr:FindFirstChild("leaderstats")
	while not ls do plr.ChildAdded:Wait(); ls = plr:FindFirstChild("leaderstats") end
	local score = ls:FindFirstChild("Score")
	while not score do ls.ChildAdded:Wait(); score = ls:FindFirstChild("Score") end
	return score :: IntValue
end
local scoreValue = waitForScoreValue()

-- Initial state (animate from 0 → saved score; set progress & level)
do
	local target = scoreValue.Value
	animateNumber(scoreLabel, 0, target, math.clamp(target / 300, 0.35, 1.25))
	updateLevelChip(levelFromScore(target), false)
	setProgress(levelProgress(target))
end

-- Keep in sync when server adjusts score (e.g., daily bonus)
scoreValue:GetPropertyChangedSignal("Value"):Connect(function()
	local shown = parseInt(scoreLabel.Text)
	local newVal = scoreValue.Value
	animateNumber(scoreLabel, shown, newVal, 0.4)
	updateLevelChip(levelFromScore(newVal), false)
	setProgress(levelProgress(newVal))
end)

-- Button
local busy = false
button.Activated:Connect(function()
	if busy then return end
	busy = true
	button.Text = "Adding..."
	REQUEST_EVENT:FireServer()
	task.delay(0.22, function()
		busy = false
		button.Text = "+ Random Points"
	end)
end)

-- React only to real level-ups and grants
GRANTED_EVENT.OnClientEvent:Connect(function(info)
	-- info: { base, multiplier, crit, streak, delta, newScore, daily? }

	-- Small float near the score
	local pos = scoreLabel.AbsolutePosition
	local origin = UDim2.new(0, pos.X, 0, pos.Y - 6)

	if info.daily then
		floatText(gui, origin, "+ Daily " .. tostring(info.delta), MAROON)
		play(dailySound, 0.96, 1.04)
	else
		floatText(gui, origin, "+" .. tostring(info.delta), WHITE)
		play(clickSound, 0.96, 1.04)
	end

	if info.crit then
		play(critSound, 0.98, 1.08)
	end

	-- Animate to the new score; update progress bar
	local shown = parseInt(scoreLabel.Text)
	local prevLevel = levelFromScore(shown)
	local newLevel  = levelFromScore(info.newScore)

	animateNumber(scoreLabel, shown, info.newScore, 0.35)
	setProgress(levelProgress(info.newScore))

	-- LEVEL UP happens ONLY when crossing the threshold
	if newLevel > prevLevel then
		updateLevelChip(newLevel, true)
		play(levelupSound, 0.95, 1.05)
		-- Optional: celebratory float text
		floatText(gui, origin - UDim2.new(0, 0, 0, 26), "LEVEL UP!", MAROON)
	end
end)
