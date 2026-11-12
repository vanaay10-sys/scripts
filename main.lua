local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local Stats        = game:GetService("Stats")
local VirtualUser  = game:GetService("VirtualUser")

local CONFIG = {
	DEFAULT_IMAGE_ID = "",
	MONSTER_NAME     = "ver",
	TOGGLE_KEY       = Enum.KeyCode.RightShift,
	CONFIG_FILE      = "DogScriptingV8.json",
	VERSION          = "V8",
}

local player    = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

for _, name in ipairs({"DogIsScripting", "DogIsScriptingV8"}) do
	local old = guiParent:FindFirstChild(name)
	if old then old:Destroy() end
end

local THEME = {
	accent  = Color3.fromRGB(255, 35, 55),
	dark    = Color3.fromRGB(12, 12, 18),
	panel   = Color3.fromRGB(24, 24, 33),
	card    = Color3.fromRGB(34, 34, 46),
	white   = Color3.fromRGB(245, 245, 250),
	dim     = Color3.fromRGB(55, 55, 68),
	success = Color3.fromRGB(40, 200, 110),
	danger  = Color3.fromRGB(230, 60, 70),
}
local accent = THEME.accent

local function create(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do pcall(function() obj[k] = v end) end
	obj.Parent = parent
	return obj
end

local function rounded(obj, r) return create("UICorner", {CornerRadius = UDim.new(0, r)}, obj) end
local function outlined(obj, color, t) return create("UIStroke", {Color = color or accent, Thickness = t or 1}, obj) end
local function selectedBg() return accent:Lerp(THEME.dark, 0.78) end
local function tween(obj, time, props)
	return TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
end

local function loadConfig()
	local raw = nil
	pcall(function()
		if isfile and isfile(CONFIG.CONFIG_FILE) then raw = readfile(CONFIG.CONFIG_FILE) end
	end)
	if not raw then return {} end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and data or {}
end

local function saveConfig(data)
	pcall(function()
		if writefile then writefile(CONFIG.CONFIG_FILE, HttpService:JSONEncode(data)) end
	end)
end
local SAVED = loadConfig()

local S = {
	connections = {}, themed = {}, highlights = {}, nav = {}, pages = {},
	currentPage = nil, ready = false,
	playerESP = false, monsterESP = false,
	fullbright = false, noclip = false,
	speedBoost = false, highJump = false, fovEnabled = false,
	antiAFK = false, clickTP = false, infJump = false,
	monsterName = SAVED.monsterName or CONFIG.MONSTER_NAME,
	boostSpeed = SAVED.boostSpeed or 32,
	boostJump = SAVED.boostJump or 100,
	boostFOV = SAVED.boostFOV or 100,
	original = {WalkSpeed = 16, JumpPower = 50, UseJumpPower = true},
	savedFOV = 70,
	lightingSnapshot = nil,
	noclipConn = nil, antiAFKConn = nil, infJumpConn = nil, clickTPConn = nil,
	noclipCache = setmetatable({}, {__mode = "k"}),
	imageTransparency = SAVED.imageTransparency or 0.65,
	lastImageId = SAVED.lastImageId or "",
	selectedPlayer = nil,
}

if SAVED.accent and #SAVED.accent == 3 then
	accent = Color3.fromRGB(SAVED.accent[1], SAVED.accent[2], SAVED.accent[3])
end

local freeCam = false
local freeCamConn, freeCamInput, freeCamSpeed
local camCFrame = CFrame.new()
local spectating = nil
local specConn = nil
local hitboxEnabled = false
local hitboxSize = 15
local hitboxCache = {}
local clickTPEnabled = false
local mapEnabled = false
local mapRange = 250
local spamActive = false
local spamConn = nil
local spamKey = Enum.KeyCode.Z
local hideChar = false
local rainbowActive = false
local rainbowConn = nil
local rainbowHue = 0
local rainbowIconActive = true
local rainbowIconConn = nil
local rainbowIconHue = 0

local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(S.connections, c)
	return c
end

local function track(obj, prop)
	table.insert(S.themed, {obj, prop})
	return obj
end

local function persist()
	SAVED.monsterName       = S.monsterName
	SAVED.boostSpeed        = S.boostSpeed
	SAVED.boostJump         = S.boostJump
	SAVED.boostFOV          = S.boostFOV
	SAVED.imageTransparency = S.imageTransparency
	SAVED.lastImageId       = S.lastImageId
	SAVED.accent            = {math.floor(accent.R*255), math.floor(accent.G*255), math.floor(accent.B*255)}
	saveConfig(SAVED)
end local gui = create("ScreenGui", {
	Name = "DogIsScriptingV8", ResetOnSpawn = false,
	IgnoreGuiInset = true, DisplayOrder = 9999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)

local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(280, 38), BackgroundColor3 = THEME.dark,
	BackgroundTransparency = 1, TextTransparency = 1, Text = "",
	TextColor3 = THEME.white, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 30,
}, gui)
rounded(toast, 8)
local toastStroke = outlined(toast, accent, 1)
toastStroke.Transparency = 1
local toastId = 0

local function notify(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or THEME.white
	toastStroke.Color = color or accent
	toastStroke.Transparency = 0
	tween(toast, 0.15, {BackgroundTransparency = 0.1, TextTransparency = 0}):Play()
	task.delay(1.8, function()
		if id == toastId and toast.Parent then
			toastStroke.Transparency = 1
			tween(toast, 0.3, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		end
	end)
end

local loading = create("CanvasGroup", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(7, 8, 20),
	BorderSizePixel = 0, ZIndex = 20,
}, gui)
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 8, 38)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 7, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 5, 32)),
	}),
	Rotation = 35,
}, loading)
local loadGlow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
	Size = UDim2.fromOffset(112, 112), BackgroundTransparency = 1, ZIndex = 21,
}, loading)
rounded(loadGlow, 56)
local loadRing = outlined(loadGlow, Color3.fromRGB(255, 0, 180), 5)
local loadRingGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 90)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 40)),
		ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 230, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 255)),
	}),
	Rotation = 0,
}, loadRing)

local loadTitle = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.fromOffset(520, 60), BackgroundTransparency = 1,
	Text = "DOG IS SCRIPTING " .. CONFIG.VERSION,
	TextColor3 = Color3.fromRGB(255, 235, 238),
	Font = Enum.Font.GothamBlack, TextSize = 34, ZIndex = 21,
}, loading)
local loadTitleStroke = outlined(loadTitle, accent, 2)
tween(loadTitleStroke, 1.1, {Thickness = 5}):Play()

local percent = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.57),
	Size = UDim2.fromOffset(300, 22), BackgroundTransparency = 1, Text = "0%",
	TextColor3 = Color3.fromRGB(255, 130, 140), Font = Enum.Font.GothamBold,
	TextSize = 16, ZIndex = 21,
}, loading)

local loadBack = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.new(0.5, 0, 0, 9), BackgroundColor3 = Color3.fromRGB(22, 18, 38),
	BorderSizePixel = 0, ZIndex = 21,
}, loading)
rounded(loadBack, 8)
outlined(loadBack, Color3.fromRGB(105, 70, 150), 1)
create("UISizeConstraint", {MaxSize = Vector2.new(420, 8)}, loadBack)

local loadFill = create("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0, ZIndex = 22,
}, loadBack)
rounded(loadFill, 8)
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 235, 170)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 40, 255)),
	}),
}, loadFill)

local loadStatus = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72),
	Size = UDim2.fromOffset(300, 20), BackgroundTransparency = 1, Text = "",
	TextColor3 = Color3.fromRGB(185, 175, 220), Font = Enum.Font.GothamMedium,
	TextSize = 13, ZIndex = 21,
}, loading)

local main = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0.88, 0, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = THEME.dark, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 2,
}, gui)
rounded(main, 12)
track(outlined(main, accent, 2), "Color")
create("UISizeConstraint", {MinSize = Vector2.new(320, 320), MaxSize = Vector2.new(880, 660)}, main)

local bgImage = create("ImageLabel", {
	Name = "MenuImage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Visible = false,
}, main)
rounded(bgImage, 12) local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0, ZIndex = 5,
}, main)
rounded(header, 12)
create("Frame", {
	Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ZIndex = 5,
}, header)

local rainbowIcon = create("TextButton", {
	Size = UDim2.fromOffset(48, 42), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(15, 12, 28), Text = "🐾",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
	TextSize = 23, BorderSizePixel = 0, ZIndex = 10, AutoButtonColor = false,
}, header)
rounded(rainbowIcon, 11)
local rainbowIconStroke = outlined(rainbowIcon, THEME.white, 3)

track(create("TextLabel", {
	Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 50, 0, 0),
	BackgroundTransparency = 1, Text = "DOG IS SCRIPTING | " .. CONFIG.VERSION,
	TextColor3 = accent, Font = Enum.Font.GothamBlack,
	TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
}, header), "TextColor3")

local close = track(create("TextButton", {
	Size = UDim2.new(0, 34, 0, 32), Position = UDim2.new(1, -40, 0, 8),
	BackgroundColor3 = accent, Text = "X", TextColor3 = THEME.white,
	Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0, ZIndex = 7,
}, header), "BackgroundColor3")
rounded(close, 7)

local minimize = create("TextButton", {
	Size = UDim2.new(0, 30, 0, 32), Position = UDim2.new(1, -76, 0, 8),
	BackgroundColor3 = THEME.card, Text = "—", TextColor3 = THEME.white,
	Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0, ZIndex = 7,
}, header)
rounded(minimize, 7)
outlined(minimize, THEME.dim, 1)

local sidebar = track(create("ScrollingFrame", {
	Size = UDim2.new(0, 125, 1, -58), Position = UDim2.new(0, 7, 0, 52),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ScrollBarThickness = 3,
	ScrollBarImageColor3 = accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4,
}, main), "ScrollBarImageColor3")
rounded(sidebar, 8)
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
create("UIPadding", {
	PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 5),
	PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 7),
}, sidebar)

local content = track(create("ScrollingFrame", {
	Size = UDim2.new(1, -140, 1, -58), Position = UDim2.new(0, 132, 0, 52),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4,
}, main), "ScrollBarImageColor3")
rounded(content, 8)
create("UIPadding", {
	PaddingTop = UDim.new(0, 9), PaddingLeft = UDim.new(0, 9),
	PaddingRight = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9),
}, content)
create("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, content)

local reopen = create("TextButton", {
	Size = UDim2.new(0, 120, 0, 40), Position = UDim2.new(0, 10, 0.5, -20),
	BackgroundColor3 = THEME.dark, Text = "DOG MENU", TextColor3 = accent,
	Font = Enum.Font.GothamBlack, TextSize = 12, Visible = false,
	BorderSizePixel = 0, ZIndex = 10,
}, gui)
track(reopen, "TextColor3")
rounded(reopen, 8)
track(outlined(reopen, accent, 2), "Color")

local minimap = create("Frame", {
	Size = UDim2.fromOffset(180, 180), Position = UDim2.new(1, -190, 0, 60),
	BackgroundColor3 = THEME.dark, BorderSizePixel = 0, ZIndex = 15, Visible = false,
}, gui)
rounded(minimap, 90)
track(outlined(minimap, accent, 2), "Color")

local mapCenter = create("Frame", {
	Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.white,
	BorderSizePixel = 0, ZIndex = 17,
}, minimap)
rounded(mapCenter, 3)

local hud = create("Frame", {
	Size = UDim2.fromOffset(200, 60), Position = UDim2.new(0, 10, 1, -80),
	BackgroundColor3 = THEME.dark, BackgroundTransparency = 0.3,
	BorderSizePixel = 0, ZIndex = 12, Visible = true,
}, gui)
rounded(hud, 8)
outlined(hud, accent, 1)

local hudLabel = create("TextLabel", {
	Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5),
	BackgroundTransparency = 1, Text = "FPS: --\nPING: --\nMEM: --",
	TextColor3 = THEME.white, Font = Enum.Font.Code, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13,
}, hud) local frames, fps, lastFps = 0, 60, tick()
RunService.RenderStepped:Connect(function()
	frames += 1
	if tick() - lastFps >= 0.5 then
		fps = math.floor(frames / (tick() - lastFps))
		frames = 0
		lastFps = tick()
	end
end)

task.spawn(function()
	while gui.Parent do
		local ping = 0
		pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
		local mem = math.floor(Stats:GetTotalMemoryUsageMb() * 10) / 10
		hudLabel.Text = string.format("FPS: %d\nPING: %d ms\nMEM: %.1f MB", fps, ping, mem)
		task.wait(0.5)
	end
end)

local showPage, refreshPage

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIPadding") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function label(text, color)
	return create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		Text = text, TextColor3 = color or accent, Font = Enum.Font.GothamBlack,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, content)
end

local function button(parent, text, callback, selected)
	local b = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = selected and selectedBg() or THEME.card,
		BorderSizePixel = 0, Text = text, TextColor3 = selected and accent or THEME.white,
		Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
		AutoButtonColor = false, ZIndex = 5,
	}, parent)
	rounded(b, 7)
	local stroke = outlined(b, selected and accent or THEME.dim, 1)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Locked") then
			tween(b, 0.12, {BackgroundColor3 = THEME.card:Lerp(accent, 0.12)}):Play()
			stroke.Color = accent
		end
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Locked") then
			tween(b, 0.12, {BackgroundColor3 = THEME.card}):Play()
			stroke.Color = THEME.dim
		end
	end)
	b.Activated:Connect(function()
		local ok, err = pcall(callback)
		if not ok then
			warn("[DogScript] Button error:", err)
			notify("Ошибка: " .. tostring(err):sub(1, 40), THEME.danger)
		end
	end)
	return b, stroke
end

local function addButton(text, callback, selected)
	return button(content, text, callback, selected)
end

local function addToggle(text, getter, setter)
	local b, stroke
	local function refresh()
		local on = getter()
		b.Text = text .. (on and "  ● ON" or "  ○ OFF")
		b.TextColor3 = on and accent or THEME.white
		b.BackgroundColor3 = on and selectedBg() or THEME.card
		stroke.Color = on and accent or THEME.dim
		b:SetAttribute("Locked", on)
	end
	b, stroke = button(content, text, function()
		setter(not getter())
		refresh()
		notify(text .. ": " .. (getter() and "ON" or "OFF"), getter() and THEME.success or THEME.danger)
	end, getter())
	b:SetAttribute("Locked", getter())
	refresh()
	return b
end

local function addTextBox(placeholder, default)
	local box = create("TextBox", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.card, BorderSizePixel = 0,
		Text = default or "", PlaceholderText = placeholder,
		PlaceholderColor3 = Color3.fromRGB(150, 150, 165), TextColor3 = THEME.white,
		Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, ZIndex = 5,
	}, content)
	rounded(box, 7)
	outlined(box, accent, 1)
	return box
end local function addSlider(text, min, max, default, onChanged)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = THEME.card, BorderSizePixel = 0, ZIndex = 5,
	}, content)
	rounded(frame, 7)
	outlined(frame, THEME.dim, 1)
	local lbl = create("TextLabel", {
		Size = UDim2.new(1, -14, 0, 22), Position = UDim2.new(0, 8, 0, 4),
		BackgroundTransparency = 1, Text = text .. ": " .. default,
		TextColor3 = THEME.white, Font = Enum.Font.GothamBold, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, frame)
	local bar = create("Frame", {
		Size = UDim2.new(1, -16, 0, 8), Position = UDim2.new(0, 8, 0, 32),
		BackgroundColor3 = THEME.dark, BorderSizePixel = 0, ZIndex = 6,
	}, frame)
	rounded(bar, 4)
	local fill = create("Frame", {
		Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 7,
	}, bar)
	rounded(fill, 4)
	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8,
	}, bar)
	local function setFromX(x)
		local frac = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local val = math.floor(min + (max - min) * frac + 0.5)
		fill.Size = UDim2.new(frac, 0, 1, 0)
		lbl.Text = text .. ": " .. val
		onChanged(val)
	end
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			btn:SetAttribute("Dragging", true)
			setFromX(input.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and btn:GetAttribute("Dragging") then
			setFromX(input.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			btn:SetAttribute("Dragging", false)
		end
	end)
	return frame
end

local function rootOf(plr)
	local char = plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(plr)
	local char = (plr or player).Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applyMovement()
	local hum = getHumanoid()
	if not hum then return end
	hum.WalkSpeed = S.speedBoost and S.boostSpeed or S.original.WalkSpeed
	if S.highJump then
		hum.UseJumpPower = true
		hum.JumpPower = S.boostJump
	else
		hum.UseJumpPower = S.original.UseJumpPower
		hum.JumpPower = S.original.JumpPower
	end
end

local function setSpeedBoost(on)
	local hum = getHumanoid()
	if on and not S.speedBoost and hum then S.original.WalkSpeed = hum.WalkSpeed end
	S.speedBoost = on
	applyMovement()
end

local function setHighJump(on)
	local hum = getHumanoid()
	if on and not S.highJump and hum then
		S.original.JumpPower = hum.JumpPower
		S.original.UseJumpPower = hum.UseJumpPower
	end
	S.highJump = on
	applyMovement()
end

local function setNoclip(on)
	S.noclip = on
	if S.noclipConn then S.noclipConn:Disconnect(); S.noclipConn = nil end
	if on then
		S.noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then
					S.noclipCache[p] = true
					p.CanCollide = false
				end
			end
		end)
	else
		for p in pairs(S.noclipCache) do
			if p.Parent then p.CanCollide = true end
		end
		table.clear(S.noclipCache)
	end
end local function setFOV(on)
	local cam = workspace.CurrentCamera
	if on and not S.fovEnabled and cam then S.savedFOV = cam.FieldOfView end
	S.fovEnabled = on
	if cam then cam.FieldOfView = on and S.boostFOV or S.savedFOV end
end

local function setAntiAFK(on)
	S.antiAFK = on
	if S.antiAFKConn then S.antiAFKConn:Disconnect(); S.antiAFKConn = nil end
	if on then
		S.antiAFKConn = connect(player.Idled, function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end

local function setInfJump(on)
	S.infJump = on
	if S.infJumpConn then S.infJumpConn:Disconnect(); S.infJumpConn = nil end
	if on then
		S.infJumpConn = connect(UIS.JumpRequest, function()
			local hum = getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end

local espNames = {player = "DogPlayerESP", monster = "DogMonsterESP"}

local function isMonster(obj)
	return obj:IsA("Model") and obj.Name:lower() == S.monsterName:lower()
end

local function setHighlight(model, kind, enabled)
	local name = espNames[kind]
	local h = model:FindFirstChild(name)
	if enabled then
		if not h then
			h = Instance.new("Highlight")
			h.Name = name
			h.FillColor = accent
			h.OutlineColor = THEME.white
			h.FillTransparency = 0.4
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = model
			table.insert(S.highlights, h)
		end
	elseif h then
		h:Destroy()
	end
end

local function setESP(kind, enabled)
	if kind == "player" then
		S.playerESP = enabled
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				setHighlight(plr.Character, "player", enabled)
			end
		end
	else
		S.monsterESP = enabled
		for _, obj in ipairs(workspace:GetDescendants()) do
			if isMonster(obj) then setHighlight(obj, "monster", enabled) end
		end
	end
end

local function snapshotLighting()
	if S.lightingSnapshot then return end
	local props = {"Brightness","ClockTime","GlobalShadows","Ambient","OutdoorAmbient","FogEnd","ColorShift_Top","FogStart","FogColor"}
	S.lightingSnapshot = {}
	for _, k in ipairs(props) do S.lightingSnapshot[k] = Lighting[k] end
end

local function restoreLighting()
	S.fullbright = false
	if not S.lightingSnapshot then return end
	for k, v in pairs(S.lightingSnapshot) do Lighting[k] = v end
	S.lightingSnapshot = nil
end

local function setFullbright(on)
	if on then
		snapshotLighting()
		S.fullbright = true
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.FogEnd = 100000
	else
		restoreLighting()
	end
end

local skyPresets = {
	{"❄ Snowy Sky",   {20,30,50},   {160,190,220},{210,230,255},8},
	{"🌌 Galaxy Sky",  {8,0,30},     {65,20,120},  {120,70,200}, 0},
	{"🌅 Sunset Sky",  {80,20,40},   {255,100,50}, {255,180,90}, 18},
	{"🌑 Dark Sky",    {0,0,0},      {10,10,20},   {20,20,35},   0},
	{"🌊 Ocean Sky",   {0,40,80},    {0,130,180},  {80,210,230}, 12},
	{"🌋 Lava Sky",    {40,0,0},     {180,25,0},   {255,100,10}, 19},
	{"💜 Purple Sky",  {30,0,60},    {120,40,180}, {210,100,255},17},
	{"🌧 Storm Sky",   {15,20,30},   {55,65,80},   {90,100,120}, 15},
	{"🌿 Toxic Sky",   {10,30,0},    {60,130,0},   {160,255,30}, 13},
	{"🌸 Pink Sky",    {80,20,60},   {220,100,180},{255,190,230},17},
	{"🔥 Blood Moon",  {20,0,0},     {100,0,10},   {200,20,30},  0},
	{"☁ Cloudy Sky",  {50,55,65},   {130,140,155},{200,205,215},12},
	{"🌠 Meteor Sky",  {5,0,20},     {80,20,60},   {255,120,90}, 3},
	{"🩸 Bloodmoon",   {30,0,0},     {150,0,5},    {255,10,20},  0},
	{"🌁 Foggy Morn",  {60,70,80},  {170,180,190},{220,225,235},7},
	{"🍭 Candy Sky",   {90,40,90},  {255,140,200},{255,220,240},16},
	{"🧊 Ice Age",     {40,60,90},  {150,200,240},{220,240,255},11},
	{"🌙 Midnight",    {2,2,10},    {15,20,40},   {40,50,90},   0},
	{"🟣 Neon Nights", {20,0,40},   {140,0,180},  {255,0,200},  1},
	{"🌋 Volcanic",    {50,10,0},   {200,50,0},   {255,160,20}, 19},
	{"💚 Matrix Sky",  {0,20,0},    {0,120,40},   {40,255,80},  13},
	{"🏖 Tropical",    {30,120,180},{100,200,240},{255,240,180},13},
	{"🌪 Tornado Sky", {40,45,55},  {100,110,125},{160,165,180},14},
	{"☀ Desert",       {120,90,50}, {230,190,130},{255,230,190},13},
	{"🌌 Cosmos",      {0,0,5},     {30,0,60},    {100,20,180}, 0},
	{"🩵 Aqua Sky",    {10,60,90},  {40,180,220}, {140,240,255},12},
	{"🌺 Floral",      {100,60,80}, {255,180,210},{255,220,235},15},
	{"⚡ Thunder",      {20,20,30},  {70,70,100},  {180,180,255},15},
	{"🩶 Silver Sky",  {70,75,85},  {180,185,195},{230,235,245},12},
	{"🟡 Golden Hour", {90,60,20},  {255,190,80}, {255,230,150},17},
	{"🌃 City Lights", {10,10,25},  {60,40,90},   {180,120,255},0},
	{"🔴 Mars Sky",    {80,30,10},  {190,90,50},  {255,170,120},10},
} local function applySky(sky)
	snapshotLighting()
	S.fullbright = false
	Lighting.ClockTime = sky[5]
	Lighting.Brightness = 2
	Lighting.FogEnd = 100000
	Lighting.Ambient = Color3.fromRGB(sky[2][1], sky[2][2], sky[2][3])
	Lighting.OutdoorAmbient = Color3.fromRGB(sky[3][1], sky[3][2], sky[3][3])
	Lighting.ColorShift_Top = Color3.fromRGB(sky[4][1], sky[4][2], sky[4][3])
end

local function setClock(hour)
	snapshotLighting()
	Lighting.ClockTime = hour
end

local function setMenuImage(id)
	if not id then
		bgImage.Visible = false
		sidebar.BackgroundTransparency = 0
		content.BackgroundTransparency = 0
		return
	end
	bgImage.Image = "rbxassetid://" .. id
	bgImage.ImageTransparency = S.imageTransparency
	bgImage.Visible = true
	sidebar.BackgroundTransparency = 0.3
	content.BackgroundTransparency = 0.3
end

local function setMenuVisible(visible)
	if not S.ready then return end
	main.Visible = visible
	reopen.Visible = not visible
end

local function setFreeCam(on)
	freeCam = on
	if freeCamConn then freeCamConn:Disconnect(); freeCamConn = nil end
	if freeCamInput then freeCamInput:Disconnect(); freeCamInput = nil end
	local cam = workspace.CurrentCamera
	cam.CameraType = on and Enum.CameraType.Scriptable or Enum.CameraType.Custom
	if not on then return end
	camCFrame = cam.CFrame
	freeCamSpeed = 2
	local moveKeys = {}
	freeCamInput = connect(UIS.InputBegan, function(inp) moveKeys[inp.KeyCode] = true end)
	connect(UIS.InputEnded, function(inp) moveKeys[inp.KeyCode] = false end)
	connect(UIS.InputChanged, function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseWheel then
			freeCamSpeed = math.clamp(freeCamSpeed + inp.Position.Z, 0.5, 20)
		end
	end)
	freeCamConn = RunService.RenderStepped:Connect(function(dt)
		local move = Vector3.zero
		if moveKeys[Enum.KeyCode.W] then move += cam.CFrame.LookVector end
		if moveKeys[Enum.KeyCode.S] then move -= cam.CFrame.LookVector end
		if moveKeys[Enum.KeyCode.A] then move -= cam.CFrame.RightVector end
		if moveKeys[Enum.KeyCode.D] then move += cam.CFrame.RightVector end
		if moveKeys[Enum.KeyCode.Space] then move += Vector3.new(0, 1, 0) end
		if moveKeys[Enum.KeyCode.LeftControl] then move -= Vector3.new(0, 1, 0) end
		camCFrame = camCFrame + move * freeCamSpeed * dt
		cam.CFrame = camCFrame
	end)
end

local function setSpectate(plr)
	if specConn then specConn:Disconnect(); specConn = nil end
	spectating = plr
	local cam = workspace.CurrentCamera
	if not plr then
		cam.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	specConn = RunService.RenderStepped:Connect(function()
		local root = rootOf(plr)
		if root then
			cam.CFrame = cam.CFrame:Lerp(CFrame.new(root.Position + Vector3.new(0, 8, 12), root.Position), 0.1)
		end
	end)
end

local function updateHitboxes()
	for obj in pairs(hitboxCache) do
		if not obj.Parent then hitboxCache[obj] = nil end
	end
	if not hitboxEnabled then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:IsDescendantOf(player.Character or workspace) then
			if not hitboxCache[obj] then hitboxCache[obj] = obj.Size end
			local parent = obj.Parent
			if parent and (isMonster(parent) or parent:FindFirstChild("Humanoid")) then
				obj.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
				obj.Transparency = 0.5
				obj.CanCollide = false
			end
		end
	end
end

local function setHitbox(on)
	hitboxEnabled = on
	if not on then
		for obj, size in pairs(hitboxCache) do
			if obj.Parent then
				obj.Size = size
				obj.Transparency = 0
				obj.CanCollide = true
			end
		end
		table.clear(hitboxCache)
	else
		updateHitboxes()
	end
end local function setClickTP(on)
	clickTPEnabled = on
	if S.clickTPConn then S.clickTPConn:Disconnect(); S.clickTPConn = nil end
	if not on then return end
	S.clickTPConn = connect(UIS.InputBegan, function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
			local mouse = player:GetMouse()
			local root = rootOf(player)
			if mouse.Hit and root then root.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end
		end
	end)
end

local function setSpam(on, key)
	spamActive = on
	if spamConn then spamConn:Disconnect(); spamConn = nil end
	if not on then return end
	spamConn = connect(UIS.InputBegan, function(inp)
		if inp.KeyCode == key and not UIS:GetFocusedTextBox() then
			VirtualUser:CaptureController()
			VirtualUser:ClickButton1(Vector2.new(0, 0))
			VirtualUser:Button1Down(Vector2.new())
		end
	end)
end

local function setHideChar(on)
	hideChar = on
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = on and 1 or 0 end
	end
end

local function setRainbowTheme(on)
	rainbowActive = on
	if rainbowConn then rainbowConn:Disconnect(); rainbowConn = nil end
	if not on then return end
	rainbowConn = RunService.RenderStepped:Connect(function(dt)
		rainbowHue = (rainbowHue + dt * 0.25) % 1
		accent = Color3.fromHSV(rainbowHue, 1, 1)
		for i = #S.themed, 1, -1 do
			local e = S.themed[i]
			if e[1].Parent then e[1][e[2]] = accent else table.remove(S.themed, i) end
		end
		for i = #S.highlights, 1, -1 do
			local h = S.highlights[i]
			if h.Parent then h.FillColor = accent else table.remove(S.highlights, i) end
		end
		for _, entry in pairs(S.nav) do
			if entry.button.BackgroundColor3 ~= THEME.card then entry.stroke.Color = accent end
		end
		close.BackgroundColor3 = accent
		reopen.TextColor3 = accent
		toastStroke.Color = accent
	end)
end

local function setRainbowIcon(on)
	rainbowIconActive = on
	if rainbowIconConn then rainbowIconConn:Disconnect(); rainbowIconConn = nil end
	if not on then
		rainbowIcon.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
		rainbowIconStroke.Color = THEME.white
		return
	end
	rainbowIconConn = RunService.RenderStepped:Connect(function(dt)
		rainbowIconHue = (rainbowIconHue + dt * 0.5) % 1
		rainbowIcon.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
		rainbowIconStroke.Color = Color3.fromHSV(rainbowIconHue, 1, 1)
	end)
end
setRainbowIcon(true)
rainbowIcon.Activated:Connect(function()
	setRainbowTheme(not rainbowActive)
	notify("Rainbow Theme: " .. (rainbowActive and "ON" or "OFF"))
end)

local function updateMinimap()
	if not mapEnabled then return end
	local myRoot = rootOf(player)
	if not myRoot then return end
	local myPos = myRoot.Position
	local cam = workspace.CurrentCamera
	local myLook = cam.CFrame.LookVector
	for _, child in ipairs(minimap:GetChildren()) do
		if child:GetAttribute("Blip") then child:Destroy() end
	end
	local function addBlip(worldPos, color, size)
		local rel = worldPos - myPos
		if Vector2.new(rel.X, rel.Z).Magnitude > mapRange then return end
		local angle = math.atan2(myLook.X, myLook.Z)
		local rx = rel.X * math.cos(-angle) - rel.Z * math.sin(-angle)
		local rz = rel.X * math.sin(-angle) + rel.Z * math.cos(-angle)
		local b = create("Frame", {
			Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((rx / mapRange) * 0.5 + 0.5, (rz / mapRange) * 0.5 + 0.5),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 16,
		}, minimap)
		rounded(b, size // 2)
		b:SetAttribute("Blip", true)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local r = rootOf(plr)
			if r then addBlip(r.Position, Color3.fromRGB(80, 200, 255), 8) end
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isMonster(obj) then addBlip(obj:GetPivot().Position, accent, 10) end
	end
end
RunService.RenderStepped:Connect(updateMinimap) local function applyTheme(color)
	setRainbowTheme(false)
	accent = color
	for i = #S.themed, 1, -1 do
		local e = S.themed[i]
		if e[1].Parent then e[1][e[2]] = accent else table.remove(S.themed, i) end
	end
	for i = #S.highlights, 1, -1 do
		local h = S.highlights[i]
		if h.Parent then h.FillColor = accent else table.remove(S.highlights, i) end
	end
	refreshPage()
end

showPage = function(name)
	S.currentPage = name
	clearContent()
	for pageName, entry in pairs(S.nav) do
		local active = pageName == name
		entry.button.BackgroundColor3 = active and selectedBg() or THEME.card
		entry.stroke.Color = active and accent or THEME.dim
		entry.button.TextColor3 = active and accent or THEME.white
		entry.button:SetAttribute("Locked", active)
	end
	if S.pages[name] then S.pages[name]() end
end

refreshPage = function()
	local pos = content.CanvasPosition
	if S.currentPage then showPage(S.currentPage) end
	task.defer(function()
		if content.Parent then content.CanvasPosition = pos end
	end)
end

local function addPage(name, icon, callback)
	S.pages[name] = callback
	local b, stroke = button(sidebar, icon .. " " .. name, function()
		content.CanvasPosition = Vector2.zero
		showPage(name)
	end)
	b.TextXAlignment = Enum.TextXAlignment.Left
	S.nav[name] = {button = b, stroke = stroke}
end

addPage("Visual", "◉", function()
	label("ESP")
	addToggle("Monster ESP: " .. S.monsterName, function() return S.monsterESP end, function(v) setESP("monster", v) end)
	addToggle("Player ESP", function() return S.playerESP end, function(v) setESP("player", v) end)
	addToggle("Fullbright", function() return S.fullbright end, setFullbright)
	addToggle("Wide FOV", function() return S.fovEnabled end, setFOV)
	addToggle("📦 Hitbox Expander", function() return hitboxEnabled end, setHitbox)
	addToggle("🗺 Minimap", function() return mapEnabled end, function(v)
		mapEnabled = v
		minimap.Visible = v
	end)
	addToggle("👤 Hide Character", function() return hideChar end, setHideChar)
	label("MONSTER NAME")
	local input = addTextBox("Имя монстра", S.monsterName)
	addButton("Apply monster name", function()
		local name = input.Text:match("^%s*(.-)%s*$")
		if name == "" then
			notify("Введи имя монстра")
			return
		end
		local wasOn = S.monsterESP
		if wasOn then setESP("monster", false) end
		S.monsterName = name
		persist()
		if wasOn then setESP("monster", true) end
		notify("Monster name: " .. name)
		refreshPage()
	end)
	addButton("Refresh ESP", function()
		setESP("monster", S.monsterESP)
		setESP("player", S.playerESP)
		notify("ESP refreshed")
	end)
end) addPage("Players", "♙", function()
	label("PLAYER LIST")
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Parent then
			addButton(plr.Name, function()
				local target = rootOf(plr)
				local root = rootOf(player)
				if target and root then
					root.CFrame = target.CFrame * CFrame.new(0, 0, -5)
					S.selectedPlayer = plr
					refreshPage()
				else
					notify("Игрок недоступен")
				end
			end, S.selectedPlayer == plr)
			addButton("👁 Spectate " .. plr.Name, function()
				notify("Spectate: " .. plr.Name)
				setSpectate(plr)
			end)
		end
	end
	addButton("❌ Stop spectate", function() setSpectate(nil) end)
	addButton("Teleport forward +10", function()
		local root = rootOf(player)
		if root then root.CFrame = root.CFrame * CFrame.new(0, 0, -10) end
	end)
	addButton("Teleport to Spawn", function()
		local root = rootOf(player)
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if root and spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		else
			notify("Spawn не найден")
		end
	end)
	addButton("Refresh list", refreshPage)
end)

addPage("Movement", "↗", function()
	label("MOVEMENT")
	addToggle("Speed Boost (" .. S.boostSpeed .. ")", function() return S.speedBoost end, setSpeedBoost)
	addToggle("High Jump", function() return S.highJump end, setHighJump)
	addToggle("Noclip", function() return S.noclip end, setNoclip)
	addToggle("🎥 Free Cam", function() return freeCam end, setFreeCam)
	addToggle("🖱 Click TP (Alt+Click)", function() return clickTPEnabled end, setClickTP)
	addToggle("⌨ Spam Z (autoclick)", function() return spamActive end, function(v) setSpam(v, spamKey) end)
	addToggle("🤖 Anti-AFK", function() return S.antiAFK end, setAntiAFK)
	addToggle("🦘 Infinite Jump", function() return S.infJump end, setInfJump)
	for _, value in ipairs({32, 50, 100}) do
		addButton("Speed " .. value, function()
			S.boostSpeed = value
			setSpeedBoost(true)
			persist()
			refreshPage()
		end, S.speedBoost and S.boostSpeed == value)
	end
	addButton("Normal movement", function()
		S.speedBoost = false
		S.highJump = false
		applyMovement()
		refreshPage()
	end)
	addButton("Reset character", function()
		local hum = getHumanoid()
		if hum then hum.Health = 0 end
	end)
end)

addPage("World", "◇", function()
	label("WORLD SETTINGS")
	addButton("☀️ Day", function() setClock(14) end)
	addButton("🌙 Night", function() setClock(0) end)
	addButton("🌅 Sunset", function() setClock(18) end)
	addButton("🌫 Remove fog", function()
		snapshotLighting()
		Lighting.FogEnd = 100000
	end)
	addButton("💡 Toggle Fullbright", function()
		setFullbright(not S.fullbright)
		refreshPage()
	end)
	label("SKY PRESETS")
	for _, sky in ipairs(skyPresets) do
		addButton(sky[1], function() applySky(sky) end)
	end
	addButton("↩ Restore original lighting", function()
		restoreLighting()
		notify("Lighting restored")
	end)
end) addPage("Monsters", "👾", function()
	label("МОНСТРЫ В МИРЕ")
	local found = 0
	local myPos = rootOf(player) and rootOf(player).Position or Vector3.zero
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isMonster(obj) then
			found += 1
			local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
			if root then
				local dist = math.floor((root.Position - myPos).Magnitude)
				addButton("👾 " .. obj.Name .. " [" .. dist .. " studs]", function()
					local r = rootOf(player)
					if r then
						r.CFrame = CFrame.new(root.Position + Vector3.new(0, 5, 5))
						notify("TP к монстру")
					end
				end)
			end
		end
	end
	if found == 0 then
		label("Монстров не найдено", THEME.danger)
	end
	addButton("🔄 Refresh", refreshPage)
end)

addPage("Themes", "✦", function()
	label("РАДУЖНЫЕ РЕЖИМЫ")
	addToggle("🌈 Rainbow Theme", function() return rainbowActive end, setRainbowTheme)
	addToggle("🌈 Rainbow Icon", function() return rainbowIconActive end, setRainbowIcon)
	addButton("⏹ Остановить радугу", function()
		setRainbowTheme(false)
		accent = THEME.accent
		for i = #S.themed, 1, -1 do
			local e = S.themed[i]
			if e[1].Parent then e[1][e[2]] = accent end
		end
		refreshPage()
		notify("Радуга остановлена", THEME.danger)
	end)
	label("ОСНОВНЫЕ ТЕМЫ")
	local themeList = {
		{"RED NEON",Color3.fromRGB(255,25,55)}, {"BLUE NEON",Color3.fromRGB(25,120,255)},
		{"PURPLE NEON",Color3.fromRGB(180,45,255)}, {"GREEN NEON",Color3.fromRGB(30,255,100)},
		{"CYAN NEON",Color3.fromRGB(0,240,255)}, {"ORANGE NEON",Color3.fromRGB(255,125,20)},
		{"PINK NEON",Color3.fromRGB(255,50,170)}, {"GOLD",Color3.fromRGB(255,205,35)},
		{"WHITE ICE",Color3.fromRGB(235,245,255)}, {"TOXIC",Color3.fromRGB(170,255,0)},
		{"ARCTIC",Color3.fromRGB(100,210,255)}, {"BLOOD",Color3.fromRGB(130,0,15)},
		{"LAVA",Color3.fromRGB(255,70,0)}, {"MATRIX",Color3.fromRGB(0,255,65)},
		{"GHOST",Color3.fromRGB(180,190,210)}, {"AQUA",Color3.fromRGB(0,180,200)},
		{"VIOLET",Color3.fromRGB(110,50,220)}, {"CRIMSON",Color3.fromRGB(190,10,45)},
		{"SILVER",Color3.fromRGB(170,180,195)}, {"ELECTRIC",Color3.fromRGB(255,255,0)},
		{"DARK BLUE",Color3.fromRGB(20,45,130)}, {"ROSE GOLD",Color3.fromRGB(255,150,160)},
		{"MINT",Color3.fromRGB(100,255,190)}, {"LIME",Color3.fromRGB(190,255,0)},
	}
	for _, entry in ipairs(themeList) do
		local b = addButton(entry[1], function()
			applyTheme(entry[2])
			persist()
			notify("Theme: " .. entry[1])
		end, accent == entry[2])
		b.TextColor3 = entry[2]
	end
	label("НОВЫЕ ТЕМЫ")
	local extraThemes = {
		{"NEON RED",Color3.fromRGB(255,30,60)}, {"NEON GREEN",Color3.fromRGB(0,255,120)},
		{"NEON BLUE",Color3.fromRGB(0,180,255)}, {"NEON PINK",Color3.fromRGB(255,40,200)},
		{"CYBER YELLOW",Color3.fromRGB(255,230,0)}, {"ELECTRIC PURPLE",Color3.fromRGB(160,0,255)},
		{"MINT GREEN",Color3.fromRGB(100,255,180)}, {"PEACH",Color3.fromRGB(255,170,130)},
		{"BLOOD RED",Color3.fromRGB(180,0,20)}, {"DEEP PURPLE",Color3.fromRGB(90,20,160)},
		{"OCEAN BLUE",Color3.fromRGB(0,120,200)}, {"SUNSET ORANGE",Color3.fromRGB(255,120,40)},
		{"LAVENDER",Color3.fromRGB(180,140,255)}, {"MATCHA",Color3.fromRGB(140,200,100)},
		{"SNOW WHITE",Color3.fromRGB(240,245,255)}, {"ROSE",Color3.fromRGB(255,100,140)},
		{"TURQUOISE",Color3.fromRGB(0,220,200)}, {"RUBY",Color3.fromRGB(200,0,60)},
		{"EMERALD",Color3.fromRGB(20,180,100)}, {"AMBER",Color3.fromRGB(255,190,0)},
		{"INDIGO",Color3.fromRGB(75,0,180)}, {"SAPPHIRE",Color3.fromRGB(20,60,200)},
		{"COPPER",Color3.fromRGB(200,100,50)}, {"SLATE",Color3.fromRGB(100,120,140)},
	}
	for _, entry in ipairs(extraThemes) do
		local b = addButton(entry[1], function()
			applyTheme(entry[2])
			persist()
			notify("Theme: " .. entry[1])
		end, accent == entry[2])
		b.TextColor3 = entry[2]
	end
end) addPage("RGB Theme", "🎨", function()
	label("КАСТОМНЫЙ ЦВЕТ АКЦЕНТА")
	local r = math.floor(accent.R * 255)
	local g = math.floor(accent.G * 255)
	local b = math.floor(accent.B * 255)
	addSlider("Red", 0, 255, r, function(v) r = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addSlider("Green", 0, 255, g, function(v) g = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addSlider("Blue", 0, 255, b, function(v) b = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addButton("💾 Save as default", function()
		accent = Color3.fromRGB(r, g, b)
		persist()
		notify("Цвет сохранён", THEME.success)
	end)
end)

addPage("Pictures", "▧", function()
	label("MENU IMAGE ID")
	local input = addTextBox("Вставь ID картинки", S.lastImageId)
	addButton("Apply image", function()
		local id = input.Text:match("%d+")
		if not id then
			notify("Нужен числовой ID")
			return
		end
		S.lastImageId = id
		setMenuImage(id)
		persist()
		notify("Image applied")
	end)
	addButton("More visible", function()
		S.imageTransparency = math.max(0, S.imageTransparency - 0.1)
		bgImage.ImageTransparency = S.imageTransparency
		persist()
	end)
	addButton("Less visible", function()
		S.imageTransparency = math.min(1, S.imageTransparency + 0.1)
		bgImage.ImageTransparency = S.imageTransparency
		persist()
	end)
	addButton("Remove image", function()
		setMenuImage(nil)
		notify("Image removed")
	end)
end)

addPage("Info", "ℹ", function()
	label("ИНФОРМАЦИЯ")
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if hum then label("❤ Health: " .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) end
		if root then label("📍 Position: " .. math.floor(root.Position.X) .. ", " .. math.floor(root.Position.Y) .. ", " .. math.floor(root.Position.Z)) end
	end
	label("🌍 Place ID: " .. game.PlaceId)
	label("👥 Players: " .. #Players:GetPlayers())
	label("💾 Memory: " .. math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB")
	local ping = 0
	pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
	label("📶 Ping: " .. ping .. " ms")
	addButton("🔄 Refresh", refreshPage)
end)

addPage("Settings", "⚙", function()
	label("SETTINGS")
	addButton("Reset menu position", function() main.Position = UDim2.fromScale(0.5, 0.5) end)
	addButton("🚨 PANIC — выключить всё", function()
		setESP("player", false)
		setESP("monster", false)
		setFullbright(false)
		setNoclip(false)
		setFOV(false)
		setSpeedBoost(false)
		setHighJump(false)
		setAntiAFK(false)
		setInfJump(false)
		setFreeCam(false)
		setHitbox(false)
		setClickTP(false)
		setSpectate(nil)
		mapEnabled = false
		minimap.Visible = false
		notify("ВСЁ ВЫКЛЮЧЕНО", THEME.danger)
		refreshPage()
	end)
	addButton("Hide menu (" .. CONFIG.TOGGLE_KEY.Name .. ")", function() setMenuVisible(false) end)
	addButton("Unload script", function() gui:Destroy() end)
end)

close.Activated:Connect(function() setMenuVisible(false) end)
reopen.Activated:Connect(function() setMenuVisible(true) end)
minimize.Activated:Connect(function() setMenuVisible(false) end)

connect(UIS.InputBegan, function(input, processed)
	if processed or not S.ready then return end
	if input.KeyCode == CONFIG.TOGGLE_KEY then setMenuVisible(not main.Visible) end
	if input.KeyCode == Enum.KeyCode.F1 then setESP("monster", not S.monsterESP); notify("Monster ESP: " .. tostring(S.monsterESP)) end
	if input.KeyCode == Enum.KeyCode.F2 then setFullbright(not S.fullbright); notify("Fullbright: " .. tostring(S.fullbright)) end
	if input.KeyCode == Enum.KeyCode.F3 then setNoclip(not S.noclip); notify("Noclip: " .. tostring(S.noclip)) end
	if input.KeyCode == Enum.KeyCode.F4 then setFreeCam(not freeCam); notify("FreeCam: " .. tostring(freeCam)) end
	if input.KeyCode == Enum.KeyCode.F5 then setSpeedBoost(not S.speedBoost); notify("Speed: " .. tostring(S.speedBoost)) end
	if input.KeyCode == Enum.KeyCode.F6 then setRainbowTheme(not rainbowActive); notify("Rainbow Theme: " .. (rainbowActive and "ON" or "OFF")) end
	if input.KeyCode == Enum.KeyCode.F7 then setRainbowIcon(not rainbowIconActive); notify("Rainbow Icon: " .. (rainbowIconActive and "ON" or "OFF")) end
end)

local dragging, dragStart, startPosition = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = main.Position
	end
end)
connect(UIS.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end
end)
connect(UIS.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local function hookPlayer(plr)
	if plr == player then return end
	connect(plr.CharacterAdded, function(char)
		if S.playerESP then setHighlight(char, "player", true) end
	end)
end
for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end

connect(Players.PlayerAdded, function(plr)
	hookPlayer(plr)
	if S.currentPage == "Players" then refreshPage() end
end)
connect(Players.PlayerRemoving, function(plr)
	if S.selectedPlayer == plr then S.selectedPlayer = nil end
	task.delay(0.2, function()
		if S.currentPage == "Players" and gui.Parent then refreshPage() end
	end)
end)
connect(workspace.DescendantAdded, function(obj)
	if S.monsterESP and isMonster(obj) then setHighlight(obj, "monster", true) end
	if hitboxEnabled then updateHitboxes() end
end)

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	S.original.WalkSpeed = hum.WalkSpeed
	S.original.JumpPower = hum.JumpPower
	S.original.UseJumpPower = hum.UseJumpPower
	applyMovement()
	if hideChar then
		task.wait(0.5)
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
		end
	end
end
connect(player.CharacterAdded, onCharacter)
if player.Character then task.spawn(onCharacter, player.Character) end

gui.Destroying:Connect(function()
	for _, c in ipairs(S.connections) do c:Disconnect() end
end)

local defaultId = CONFIG.DEFAULT_IMAGE_ID:match("%d+")
if defaultId then S.lastImageId = defaultId end
if S.lastImageId and S.lastImageId ~= "" then setMenuImage(S.lastImageId) end

task.spawn(function()
	local steps = {"Initializing", "Loading modules", "Building interface", "Almost ready"}
	for i = 1, 100 do
		if not gui.Parent then return end
		loadRingGradient.Rotation = (loadRingGradient.Rotation + 5) % 360
		loadRing.Color = Color3.fromHSV((i / 100) % 1, 0.9, 1)
		loadFill.Size = UDim2.new(i / 100, 0, 1, 0)
		percent.Text = i .. "%"
		loadStatus.Text = steps[math.min(#steps, math.ceil(i / 25))] .. "..."
		task.wait(0.02)
	end
	showPage("Visual")
	main.Visible = true
	S.ready = true
	local fade = TweenService:Create(loading, TweenInfo.new(0.5), {GroupTransparency = 1})
	fade:Play()
	fade.Completed:Wait()
	loading:Destroy()
	notify("Dog Scripting V8 загружен!", THEME.success)
end)
