--[[
    LRXUI Complete Demo
    ===================
    This script demonstrates:
    - Window, Tabs, Groupboxes, Tabboxes
    - Labels, Buttons, Toggles, Inputs, Sliders
    - Dropdowns (single/multi/searchable/value-mapped)
    - ColorPickers (with transparency), KeyPickers
    - Viewports, Images, Dividers, Spacers
    - DependencyBoxes, Tooltips, Dialogs, Notifications
    - Watermark, Keybind Menu, Draggable Buttons
]]

--// Load Library
local Library =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/source.lua"))()
-- If you're using a local copy, replace the above with:
-- local Library = loadstring(readfile("LRXUI.lua"))()

--// Create Window
local Window = Library:CreateWindow({
	Title = "LRXUI Demo",
	Footer = "v1.0.0 | by You",
	Icon = "rbxassetid://10747372976", -- optional window icon
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.fromOffset(860, 640),
	Center = true,
	AutoShow = true,
	Resizable = true,
	SearchbarSize = UDim2.fromScale(1, 1),
	CornerRadius = 6,
	NotifySide = "Right",
	ShowCustomCursor = true,
	Font = Enum.Font.BuilderSans,
	ToggleKeybind = Enum.KeyCode.RightControl,
	MobileButtonsSide = "Left",
	DisableSearch = false,
})

--// Watermark
Library:SetWatermarkVisibility(true)
Library:SetWatermark("LRXUI Demo | FPS: " .. math.floor(1 / game:GetService("RunService").RenderStepped:Wait()))

--// Tabs
local MainTab = Window:AddTab({
	Name = "Main",
	Icon = "home",
	Description = "General settings and basic controls",
})

local VisualsTab = Window:AddTab({
	Name = "Visuals",
	Icon = "eye",
	Description = "ESP, Chams, and world visuals",
})

local CombatTab = Window:AddTab({
	Name = "Combat",
	Icon = "swords",
	Description = "Aimbot, silent aim, and weapon mods",
})

local MiscTab = Window:AddTab({
	Name = "Misc",
	Icon = "settings",
	Description = "Utilities, macros, and fun stuff",
})

local KeyTab = Window:AddKeyTab("Key System")

--// ============================================
--// MAIN TAB
--// ============================================

local LeftMain = MainTab:AddLeftGroupbox("General", "sliders-horizontal")
local RightMain = MainTab:AddRightGroupbox("Information", "info")

--// Left Main: Basic Controls
do
	LeftMain:AddLabel("Welcome to LRXUI", true, 14)

	LeftMain:AddDivider()

	-- Toggle (Switch style)
	local MasterToggle = LeftMain:AddToggle("MasterToggle", {
		Text = "Enable Master Switch",
		Default = true,
		Tooltip = "This is the master power switch",
		Callback = function(Value)
			Library:Notify({
				Title = "Master Switch",
				Description = "State changed to: " .. tostring(Value),
				Time = 3,
			})
		end,
	})

	-- Toggle with KeyPicker
	MasterToggle:AddKeyPicker("MasterKeybind", {
		Default = "RightShift",
		Mode = "Toggle",
		Text = "Master Toggle Key",
		SyncToggleState = true,
	})

	-- Checkbox style toggle (if ForceCheckbox is enabled)
	-- LeftMain:AddCheckbox("CheckboxDemo", { Text = "Checkbox Style", Default = false })

	-- Button with sub-button
	local ActionBtn = LeftMain:AddButton({
		Text = "Perform Action",
		Func = function()
			Library:Notify("Action executed!", 2)
		end,
		Tooltip = "Click to perform a generic action",
	})

	ActionBtn:AddButton({
		Text = "Sub Action",
		Func = function()
			Library:InfoPopup("Sub Action", "This is a secondary button in the same row.")
		end,
		Tooltip = "A secondary action button",
	})

	-- Risky button with double-click
	LeftMain:AddButton({
		Text = "Danger Zone",
		Func = function()
			Library:Confirm({
				Title = "Are you sure?",
				Description = "This action cannot be undone.",
				Callback = function(accepted)
					if accepted then
						Library:Notify("Dangerous action confirmed!", 3)
					end
				end,
			})
		end,
		Risky = true,
		DoubleClick = true,
		Tooltip = "Double-click to trigger a confirmation dialog",
	})

	-- Input
	LeftMain:AddInput("UsernameInput", {
		Text = "Username Filter",
		Default = "",
		Placeholder = "Enter target name...",
		Finished = true,
		ClearTextOnFocus = true,
		Callback = function(Value)
			print("Input changed:", Value)
		end,
	})

	-- Slider
	LeftMain:AddSlider("SpeedSlider", {
		Text = "WalkSpeed",
		Default = 16,
		Min = 0,
		Max = 200,
		Rounding = 0,
		Suffix = " studs/s",
		Callback = function(Value)
			print("Speed set to:", Value)
		end,
	})

	-- Compact Slider
	LeftMain:AddSlider("FOVSlider", {
		Text = "Field of View",
		Default = 70,
		Min = 30,
		Max = 120,
		Rounding = 0,
		Compact = true,
		Suffix = "°",
	})

	-- Spacer
	LeftMain:AddSpacer(12)

	-- Dropdown (Single, searchable)
	LeftMain:AddDropdown("ThemeDropdown", {
		Text = "Select Theme",
		Values = { "Dark", "Light", "Amethyst", "Ocean", "Forest" },
		Default = 1,
		Searchable = true,
		Callback = function(Value)
			print("Theme selected:", Value)
		end,
	})

	-- Dropdown (Multi)
	LeftMain:AddDropdown("MultiDropdown", {
		Text = "Multi Select",
		Values = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
		Multi = true,
		Default = { "Head", "Torso" },
		MaxDisplayItems = 3,
		Callback = function(Value)
			print("Multi selected:", Value)
		end,
	})

	-- Value Dropdown (Label/Value pairs with rich text)
	LeftMain:AddValueDropdown("SeedDropdown", {
		Text = "Incubator Seed",
		Values = {
			{ Text = '<font color="#ffd166">Honey Seed</font>', Value = "Honey Seed" },
			{ Text = "<b>Bee Balm</b>", Value = "Bee Balm" },
			{ Text = '<font color="#ff66cc">Huge Pet</font>', Value = "pet-uuid-123" },
		},
		Multi = true,
		Callback = function(Value)
			print("Seed value:", Value)
		end,
	})
end

--// Right Main: Info & Status
do
	RightMain:AddLabel("Status: <font color='#4ade80'>Online</font>", false, 14)
	RightMain:AddDivider()
	RightMain:AddLabel(
		"This is a wrapping label that demonstrates long text support. You can write paragraphs here and they will automatically wrap to fit the groupbox width.",
		true,
		13
	)

	RightMain:AddSpacer(8)

	-- Image
	RightMain:AddImage("DemoImage", {
		Image = "rbxassetid://10747372976",
		Height = 120,
		ScaleType = Enum.ScaleType.Fit,
	})

	-- Color Picker with Transparency
	local ColorPick = RightMain:AddColorPicker("AccentColor", {
		Default = Color3.fromRGB(88, 166, 255),
		Title = "Accent Color",
		Transparency = 0,
		Callback = function(Color, Transparency)
			print("Color:", Color, "Transparency:", Transparency)
		end,
	})

	-- Viewport (if you have a model/part to show)
	--[[
    local Viewport = RightMain:AddViewport("ModelViewport", {
        Object = workspace:FindFirstChild("DemoModel") or workspace.Baseplate,
        Clone = true,
        AutoFocus = true,
        Interactive = true,
        Height = 160,
    })
    --]]
end

--// ============================================
--// VISUALS TAB
--// ============================================

local LeftVisuals = VisualsTab:AddLeftGroupbox("ESP", "scan-eye")
local RightVisuals = VisualsTab:AddRightGroupbox("Chams", "palette")

do
	-- ESP Toggles
	LeftVisuals:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = false })
	LeftVisuals:AddToggle("ESPBoxes", { Text = "Show Boxes", Default = true })
	LeftVisuals:AddToggle("ESPNames", { Text = "Show Names", Default = true })
	LeftVisuals:AddToggle("ESPDistance", { Text = "Show Distance", Default = false })
	LeftVisuals:AddToggle("ESPTeamCheck", { Text = "Team Check", Default = true })

	LeftVisuals:AddDivider()

	-- Dependency Box: Only shows if ESP is enabled
	local ESPSettings = LeftVisuals:AddDependencyBox()
	ESPSettings:SetupDependencies({
		{ Toggles["ESPEnabled"], true },
	})

	ESPSettings:AddSlider("ESPMaxDist", {
		Text = "Max Distance",
		Default = 1000,
		Min = 100,
		Max = 5000,
		Rounding = 0,
		Suffix = " studs",
	})

	ESPSettings:AddDropdown("ESPBoxType", {
		Text = "Box Type",
		Values = { "2D", "3D", "Corner", "Dynamic" },
		Default = "2D",
	})

	-- Dependency Groupbox on the right
	local ChamsDep = RightVisuals:AddDependencyGroupbox()
	ChamsDep:SetupDependencies({
		{ Toggles["ESPEnabled"], true },
	})

	ChamsDep:AddToggle("ChamsEnabled", { Text = "Chams", Default = false })
	ChamsDep:AddColorPicker("ChamsColor", {
		Default = Color3.fromRGB(255, 0, 0),
		Title = "Visible Color",
		Transparency = 0.5,
	})
	ChamsDep:AddColorPicker("ChamsHiddenColor", {
		Default = Color3.fromRGB(255, 255, 0),
		Title = "Hidden Color",
		Transparency = 0.5,
	})
end

--// ============================================
--// COMBAT TAB
--// ============================================

local LeftCombat = CombatTab:AddLeftGroupbox("Aimbot", "crosshair")
local RightCombat = CombatTab:AddRightGroupbox("Weapon", "zap")

do
	local AimToggle = LeftCombat:AddToggle("AimbotEnabled", {
		Text = "Aimbot",
		Default = false,
		Risky = true,
		Tooltip = "Automatically aims at targets",
	})

	AimToggle:AddKeyPicker("AimbotKey", {
		Default = "MB2",
		Mode = "Hold",
		Text = "Aimbot Key",
		Callback = function(Value)
			print("Aimbot key state:", Value)
		end,
	})

	LeftCombat:AddSlider("AimbotSmoothing", {
		Text = "Smoothing",
		Default = 0.1,
		Min = 0,
		Max = 1,
		Rounding = 2,
	})

	LeftCombat:AddDropdown("AimbotPart", {
		Text = "Target Part",
		Values = { "Head", "Torso", "HumanoidRootPart" },
		Default = "Head",
	})

	-- Tabbox for weapon mods
	local WeaponTabbox = RightCombat:AddTabbox({ Side = 1, Name = "Weapon Mods" })
	local RecoilTab = WeaponTabbox:AddTab("Recoil")
	local SpreadTab = WeaponTabbox:AddTab("Spread")

	RecoilTab:AddToggle("NoRecoil", { Text = "No Recoil", Default = false })
	RecoilTab:AddSlider("RecoilScale", { Text = "Recoil %", Default = 100, Min = 0, Max = 100, Rounding = 0 })

	SpreadTab:AddToggle("NoSpread", { Text = "No Spread", Default = false })
	SpreadTab:AddSlider("SpreadScale", { Text = "Spread %", Default = 100, Min = 0, Max = 100, Rounding = 0 })
end

--// ============================================
--// MISC TAB
--// ============================================

local LeftMisc = MiscTab:AddLeftGroupbox("Utilities", "wrench")
local RightMisc = MiscTab:AddRightGroupbox("Fun", "smile")

do
	-- Draggable Menu
	local MenuBg, MenuContainer = Library:AddDraggableMenu("Quick Menu")
	MenuBg.Position = UDim2.new(1, -220, 0, 80)
	MenuBg.AnchorPoint = Vector2.new(1, 0)

	-- Add some buttons to the draggable menu
	local function AddMenuButton(text, callback)
		local btn = Library:MakeDraggableButton(text, callback)
		-- Reparent to our menu container if desired, or keep as floating buttons
	end

	-- Notifications demo
	LeftMisc:AddButton({
		Text = "Send Notification",
		Func = function()
			Library:Notify({
				Title = "Demo Notification",
				Description = "This is a styled notification with a timer bar!",
				Time = 5,
				SoundId = 9113083740, -- optional sound
			})
		end,
	})

	LeftMisc:AddButton({
		Text = "Persistent Notify",
		Func = function()
			local notif = Library:Notify({
				Title = "Loading...",
				Description = "Please wait while data is fetched.",
				Persist = true,
			})

			task.delay(3, function()
				notif:ChangeTitle("Complete!")
				notif:ChangeDescription("Data has been loaded successfully.")
				notif:Destroy()
			end)
		end,
	})

	LeftMisc:AddButton({
		Text = "Stepped Notify",
		Func = function()
			local notif = Library:Notify({
				Title = "Progress",
				Description = "Processing items...",
				Time = 10,
				Steps = 10,
			})

			for i = 1, 10 do
				task.wait(0.8)
				notif:ChangeStep(i)
			end
		end,
	})

	-- Dialog demo
	LeftMisc:AddButton({
		Text = "Show Confirm Dialog",
		Func = function()
			Library:Confirm({
				Title = "Delete Save?",
				Description = "Are you sure you want to delete your local save data? This cannot be undone.",
				ConfirmText = "Delete",
				CancelText = "Keep",
				Risky = true,
				Callback = function(accepted)
					if accepted then
						Library:Notify("Save deleted!", 3)
					else
						Library:Notify("Deletion cancelled.", 2)
					end
				end,
			})
		end,
	})

	LeftMisc:AddButton({
		Text = "Show Info Dialog",
		Func = function()
			Library:InfoPopup("Update Available", "A new version of the script is available. Please rejoin to update.")
		end,
	})

	-- Player dropdown (auto-populates)
	LeftMisc:AddDropdown("PlayerDropdown", {
		Text = "Select Player",
		SpecialType = "Player",
		ExcludeLocalPlayer = true,
		Callback = function(Value)
			print("Selected player:", Value)
		end,
	})

	-- Team dropdown (auto-populates)
	LeftMisc:AddDropdown("TeamDropdown", {
		Text = "Select Team",
		SpecialType = "Team",
		Callback = function(Value)
			print("Selected team:", Value)
		end,
	})

	-- Keybind display toggle
	LeftMisc:AddToggle("ShowKeybinds", {
		Text = "Show Keybind Menu",
		Default = false,
		Callback = function(Value)
			Library.KeybindFrame.Visible = Value
		end,
	})

	-- Fun stuff
	RightMisc:AddButton({
		Text = "Rainbow Watermark",
		Func = function()
			local colors = {
				"#FF0000",
				"#FF7F00",
				"#FFFF00",
				"#00FF00",
				"#0000FF",
				"#4B0082",
				"#9400D3",
			}
			local i = 1
			task.spawn(function()
				while true do
					Library:SetWatermark(string.format("<b><font color='%s'>LRXUI Demo</font></b>", colors[i]))
					i = (i % #colors) + 1
					task.wait(0.3)
				end
			end)
		end,
	})

	RightMisc:AddButton({
		Text = "Unload Library",
		Func = function()
			Library:Unload()
		end,
		Risky = true,
		DoubleClick = true,
	})
end

--// ============================================
--// KEY SYSTEM TAB
--// ============================================

do
	KeyTab:AddKeyBox("Enter your access key...", function(success, key)
		if success then
			Library:Notify("Key accepted! Welcome.", 3)
			-- You could enable tabs here or set a global flag
		else
			Library:Notify("Invalid key: " .. tostring(key), 3)
		end
	end)
end

--// ============================================
--// POST-SETUP
--// ============================================

-- Update watermark with FPS
task.spawn(function()
	while task.wait(1) do
		local fps = math.floor(1 / game:GetService("RunService").RenderStepped:Wait())
		Library:SetWatermark("LRXUI Demo | FPS: " .. fps)
	end
end)

-- Example: Change footer dynamically
task.delay(5, function()
	Window:SetFooterText("v1.0.0 | Loaded in " .. tostring(tick()) .. "s")
end)

-- Return references for external access
getgenv().DemoWindow = Window
getgenv().DemoLibrary = Library

print("[LRXUI Demo] UI loaded successfully!")
