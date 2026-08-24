--// ============================================
--// BOOTH CLAIMER + AUTO PET LISTING + LIVE DATA + AUTO REJOIN + UNLIST
--// Booth discovery via ReplicationReciever + numbered booths
--// ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// ============================================
--// INSTANCE GUARD
--// ============================================
if getgenv().LRX_BoothClaimer_Stop ~= nil then
	getgenv().LRX_BoothClaimer_Stop = true
	task.wait(0.6)
end
getgenv().LRX_BoothClaimer_Stop = false

local function ShouldStop()
	return getgenv().LRX_BoothClaimer_Stop == true
end

if getgenv().Library and typeof(getgenv().Library) == "table" and not getgenv().Library.Unloaded then
	pcall(function()
		getgenv().Library:Unload()
	end)
	task.wait(0.2)
end

--// Remotes & Folders
local ClaimRemote = ReplicatedStorage:WaitForChild("GameEvents")
	:WaitForChild("TradeEvents")
	:WaitForChild("Booths")
	:WaitForChild("ClaimBooth")

local SkinRemote =
	ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeBoothSkinService"):WaitForChild("Equip")

local CreateListingRemote = ReplicatedStorage:WaitForChild("GameEvents")
	:WaitForChild("TradeEvents")
	:WaitForChild("Booths")
	:WaitForChild("CreateListing")

local RemoveListingRemote = ReplicatedStorage:WaitForChild("GameEvents")
	:WaitForChild("TradeEvents")
	:WaitForChild("Booths")
	:WaitForChild("RemoveListing")

local BoothsFolder = workspace:WaitForChild("TradeWorld"):WaitForChild("Booths")

--// CONFIG
local COOLDOWN = 2.5
local MAX_LISTINGS = 50

--// CONFIG SAVE SYSTEM
local CONFIG_FOLDER = "LRX_BoothClaimer"
local CONFIG_FILE = CONFIG_FOLDER .. "/Config.json"

local Config = {}

local function LoadConfig()
	if isfile and isfile(CONFIG_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(CONFIG_FILE))
		end)
		if ok and typeof(data) == "table" then
			Config = data
			return
		end
	end
	Config = {}
end

local function SaveConfig()
	if not isfolder(CONFIG_FOLDER) and makefolder then
		makefolder(CONFIG_FOLDER)
	end
	if writefile then
		local ok, json = pcall(function()
			return HttpService:JSONEncode(Config)
		end)
		if ok then
			pcall(function()
				writefile(CONFIG_FILE, json)
			end)
		end
	end
end

local function SetConfig(key, value)
	Config[key] = value
	SaveConfig()
end

local function GetConfig(key, default)
	if Config[key] == nil then
		return default
	end
	return Config[key]
end

LoadConfig()

--// ============================================
--// REPLICATION RECEIVER -- live booth data
--// ============================================
local BoothDataReceiver = nil
local TradeBoothsData = nil
local MyTradePlayerId = nil

pcall(function()
	local ReplicationReciever = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ReplicationReciever"))
	BoothDataReceiver = ReplicationReciever.new("Booths")
end)

pcall(function()
	TradeBoothsData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("TradeBoothsData"))
	if TradeBoothsData and TradeBoothsData.getPlayerId then
		MyTradePlayerId = TradeBoothsData.getPlayerId(player)
	end
end)

--// ============================================
--// BOOTH NUMBERING SYSTEM
--// ============================================
local BoothNumberMap = {} -- uuid -> number
local NumberToBooth = {} -- number -> uuid

local function ScanBoothNumbers()
	BoothNumberMap = {}
	NumberToBooth = {}
	for _, booth in ipairs(BoothsFolder:GetChildren()) do
		if booth:IsA("Model") or booth:IsA("Folder") then
			for _, child in ipairs(booth:GetDescendants()) do
				if child:IsA("BasePart") and child:GetAttribute("TradePad") == true then
					local idx = child:GetAttribute("Index")
					if type(idx) == "string" then
						idx = tonumber(idx)
					end
					if idx then
						BoothNumberMap[booth.Name] = idx
						NumberToBooth[idx] = booth.Name
						break
					end
				end
			end
			-- Fallback: if no TradePad found, try direct attribute
			if not BoothNumberMap[booth.Name] then
				local idx = booth:GetAttribute("Index") or booth:GetAttribute("BoothIndex")
				if type(idx) == "string" then
					idx = tonumber(idx)
				end
				if idx then
					BoothNumberMap[booth.Name] = idx
					NumberToBooth[idx] = booth.Name
				end
			end
		end
	end
end

local function GetBoothNumber(booth)
	if not booth then
		return nil
	end
	local name = typeof(booth) == "Instance" and booth.Name or tostring(booth)
	return BoothNumberMap[name]
end

local function GetBoothByNumber(num)
	local uuid = NumberToBooth[num]
	if uuid then
		return BoothsFolder:FindFirstChild(uuid)
	end
	return nil
end

local function GetBoothNumberString(booth)
	local num = GetBoothNumber(booth)
	if num then
		return "Booth #" .. num
	end
	return booth and booth.Name:sub(1, 8) or "Unknown"
end

--// ============================================
--// LIVE DATA FUNCTIONS
--// ============================================
local function GetBoothData()
	if not BoothDataReceiver then
		return nil
	end
	local ok, data = pcall(function()
		return BoothDataReceiver:GetDataAsync()
	end)
	if ok and typeof(data) == "table" then
		return data
	end
	return nil
end

local function GetBoothListings(boothUUID)
	local listings = {}
	local data = GetBoothData()
	if not data then
		return listings
	end

	local boothData = data.Booths and data.Booths[boothUUID]
	if not boothData then
		return listings
	end

	local ownerId = boothData.Owner
	if not ownerId then
		return listings
	end

	local playerData = data.Players and data.Players[ownerId]
	if not playerData then
		return listings
	end

	local listingsMap = playerData.Listings or {}
	local itemsMap = playerData.Items or {}

	for listingUUID, listing in pairs(listingsMap) do
		local itemData = itemsMap[listing.ItemId]
		local petName = "Unknown"
		local age = 0
		local kg = 0

		if typeof(itemData) == "table" then
			petName = itemData.Name or itemData.ItemName or itemData.PetType or "Unknown"
			age = tonumber(itemData.Age or itemData.PetAge or itemData.petAge or 0) or 0
			kg = tonumber(itemData.Weight or itemData.KG or itemData.kg or itemData.Mass or itemData.PetWeight or 0)
				or 0
		end

		table.insert(listings, {
			UID = tostring(listing.ItemId),
			Name = petName,
			Price = tonumber(listing.Price) or 0,
			ListingUUID = tostring(listingUUID),
			ItemType = listing.ItemType or "Pet",
			Age = age,
			KG = kg,
		})
	end

	return listings
end

local function GetMyBoothUUID()
	if MyBooth and MyBooth.Parent then
		return MyBooth.Name
	end
	if not BoothDataReceiver or not MyTradePlayerId then
		return nil
	end
	local data = GetBoothData()
	if not data then
		return nil
	end
	for uuid, booth in pairs(data.Booths or {}) do
		if booth.Owner == MyTradePlayerId then
			return uuid
		end
	end
	return nil
end

local function FindMyBoothFromData()
	local uuid = GetMyBoothUUID()
	if not uuid then
		return nil
	end
	return BoothsFolder:FindFirstChild(uuid)
end

local function GetLiveListingCount()
	local uuid = GetMyBoothUUID()
	if not uuid then
		return 0
	end
	return #GetBoothListings(uuid)
end

local function IsPetListed(uid)
	local uuid = GetMyBoothUUID()
	if not uuid then
		return false
	end
	for _, item in ipairs(GetBoothListings(uuid)) do
		if item.UID == uid then
			return true
		end
	end
	return false
end

local function GetListedPetNames()
	local uuid = GetMyBoothUUID()
	local names = {}
	if not uuid then
		return names
	end
	local seen = {}
	for _, item in ipairs(GetBoothListings(uuid)) do
		if not seen[item.Name] then
			seen[item.Name] = true
			table.insert(names, item.Name)
		end
	end
	table.sort(names)
	return names
end

local function GetAllBoothStatus()
	local data = GetBoothData()
	if not data then
		return {}, {}, {}
	end

	local myBooth = nil
	local occupied = {}
	local unclaimed = {}

	for uuid, boothData in pairs(data.Booths or {}) do
		local num = BoothNumberMap[uuid]
		local info = {
			UUID = uuid,
			Number = num,
			NumberStr = num and ("Booth #" .. num) or uuid:sub(1, 8),
			Owner = boothData.Owner,
		}

		if boothData.Owner == MyTradePlayerId then
			myBooth = info
		elseif boothData.Owner ~= nil then
			table.insert(occupied, info)
		else
			table.insert(unclaimed, info)
		end
	end

	table.sort(occupied, function(a, b)
		return (a.Number or 999) < (b.Number or 999)
	end)
	table.sort(unclaimed, function(a, b)
		return (a.Number or 999) < (b.Number or 999)
	end)

	return myBooth, occupied, unclaimed
end

--// ============================================
--// STATE
--// ============================================
local MyBooth = nil
local AutoClaim = GetConfig("AutoClaim", false)
local LastClaim = 0
local FailCount = 0
local SelectedSkin = GetConfig("SelectedSkin", "Default")
local SelectedPet = GetConfig("SelectedPet", "")
local ListPrice = GetConfig("ListPrice", 99)
local AutoList = GetConfig("AutoList", false)
local HadBooth = false
local PreviousListingCount = 0
local UnlistSelection = "Select All"

local SaleCooldownMinutes = GetConfig("SaleCooldownMinutes", 1)
local SaleCooldownEnd = 0

local MinPlayers = GetConfig("MinPlayers", 5)

--// Override Listing Filters
local MinAge = GetConfig("MinAge", 0)
local MaxAge = GetConfig("MaxAge", 0)
local MinKG = GetConfig("MinKG", 0)
local MaxKG = GetConfig("MaxKG", 0)

--// ============================================
--// HELPERS
--// ============================================
local function GetPos(booth)
	if not booth then
		return Vector3.zero
	end
	if booth:IsA("Model") and booth.PrimaryPart then
		return booth.PrimaryPart.Position
	end
	for _, d in ipairs(booth:GetDescendants()) do
		if d:IsA("BasePart") then
			return d.Position
		end
	end
	return Vector3.zero
end

local function IsOccupied(booth)
	if not booth then
		return false
	end
	local data = GetBoothData()
	if data and data.Booths and data.Booths[booth.Name] then
		return data.Booths[booth.Name].Owner ~= nil
	end
	-- Fallback
	local dyn = booth:FindFirstChild("DynamicInstances")
	if dyn and #dyn:GetChildren() > 0 then
		return true
	end
	if booth:GetAttribute("Occupied") == true or booth:GetAttribute("Claimed") == true then
		return true
	end
	return false
end

local function GetSpawn()
	local spawnLoc = workspace:FindFirstChild("SpawnLocation")
	if spawnLoc and spawnLoc:IsA("BasePart") then
		return spawnLoc.Position
	end
	local total, count = Vector3.zero, 0
	for _, b in ipairs(BoothsFolder:GetChildren()) do
		if b:IsA("Model") or b:IsA("Folder") then
			local p = GetPos(b)
			if p ~= Vector3.zero then
				total = total + p
				count = count + 1
			end
		end
	end
	return count > 0 and (total / count) or Vector3.new(-9115, 5, -23)
end

local SpawnPos = GetSpawn()

local function GetBestFreeBooth()
	local data = GetBoothData()

	local best, bestNum, bestDist = nil, nil, math.huge

	for _, booth in ipairs(BoothsFolder:GetChildren()) do
		if not (booth:IsA("Model") or booth:IsA("Folder")) then
			continue
		end

		local isFree = false
		if data and data.Booths and data.Booths[booth.Name] then
			isFree = data.Booths[booth.Name].Owner == nil
		else
			isFree = not IsOccupied(booth)
		end

		if isFree then
			local pos = GetPos(booth)
			if pos ~= Vector3.zero then
				local num = GetBoothNumber(booth)
				local dist = (pos - SpawnPos).Magnitude

				if num and (not bestNum or num < bestNum) then
					bestNum = num
					bestDist = dist
					best = booth
				elseif num and bestNum and num == bestNum then
					if dist < bestDist then
						bestDist = dist
						best = booth
					end
				elseif not bestNum and dist < bestDist then
					bestDist = dist
					best = booth
				end
			end
		end
	end
	return best
end

local function TradeBoothOpen()
	local tb = playerGui:FindFirstChild("TradeBooth")
	return tb ~= nil and tb.Enabled == true
end

local function HasBooth()
	if TradeBoothOpen() then
		return true
	end
	if MyBooth ~= nil and MyBooth.Parent ~= nil and IsOccupied(MyBooth) then
		return true
	end
	return false
end

--// ============================================
--// FILTER HELPER
--// ============================================
local function PetMatchesFilters(petData)
	local age = petData.Age or 0
	local kg = petData.KG or 0

	if MinAge > 0 and age < MinAge then
		return false
	end
	if MaxAge > 0 and age > MaxAge then
		return false
	end
	if MinKG > 0 and kg < MinKG then
		return false
	end
	if MaxKG > 0 and kg > MaxKG then
		return false
	end
	return true
end

--// ============================================
--// SKIN SCANNER
--// ============================================
local skinMap = {}
local function ScanSkins()
	local found, map = {}, {}
	local selector = playerGui:FindFirstChild("TradeBoothSkinSelector")
	if selector then
		local content = selector:FindFirstChild("SkinSelector")
			and selector.SkinSelector:FindFirstChild("Main")
			and selector.SkinSelector.Main:FindFirstChild("Skins")
			and selector.SkinSelector.Main.Skins:FindFirstChild("ScrollerHolder")
			and selector.SkinSelector.Main.Skins.ScrollerHolder:FindFirstChild("Scroller")
			and selector.SkinSelector.Main.Skins.ScrollerHolder.Scroller:FindFirstChild("Content")
		if content then
			for _, f in ipairs(content:GetChildren()) do
				if f:IsA("Frame") then
					local lock = f:FindFirstChild("LockIcon")
					local qty = f:FindFirstChild("ITEM_QUANTITY")
					local owned = false
					if lock and lock:IsA("ImageLabel") and lock.Visible == false then
						owned = true
					end
					if qty and qty:IsA("TextLabel") and qty.Text ~= "x0" and qty.Text ~= "" then
						owned = true
					end
					if owned then
						local id = f:GetAttribute("SearchId") or f.Name
						local disp = f:GetAttribute("SearchDisplay") or id
						if id and id ~= "" then
							table.insert(found, tostring(id))
							map[tostring(id)] = tostring(disp)
						end
					end
				end
			end
		end
	end
	local seen, clean = {}, {}
	for _, s in ipairs(found) do
		s = tostring(s)
		if s ~= "" and not seen[s:lower()] then
			seen[s:lower()] = true
			table.insert(clean, s)
		end
	end
	return #clean > 0 and clean or nil, map
end

--// ============================================
--// PET REGISTRY SCANNER
--// ============================================
local function ScanPetRegistry()
	local names = {}
	local registry = ReplicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"):WaitForChild("PetList")

	local list
	if registry:IsA("ModuleScript") then
		local ok, result = pcall(require, registry)
		if ok and typeof(result) == "table" then
			list = result
		else
			list = {}
		end
	elseif registry:IsA("Folder") then
		list = {}
		for _, child in ipairs(registry:GetChildren()) do
			list[child.Name] = true
		end
	else
		list = {}
	end

	for name, _ in pairs(list) do
		if typeof(name) == "string" and name ~= "" then
			table.insert(names, name)
		end
	end

	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	return names
end

--// ============================================
--// BACKPACK PET SCANNER
--// ============================================
local function GetPetsInBackpack(petName)
	local matches = {}
	local containers = {}

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end

	local character = player.Character
	if character then
		table.insert(containers, character)
	end

	for _, container in ipairs(containers) do
		for _, obj in ipairs(container:GetChildren()) do
			if obj:IsA("Tool") then
				if obj:GetAttribute("ItemType") ~= "Pet" and obj:GetAttribute("PetType") ~= "Pet" then
					continue
				end

				local objPetName = obj:GetAttribute("f")

				if not objPetName then
					if obj.Name:match("^" .. petName .. "[%s%[]") or obj.Name == petName then
						objPetName = petName
					end
				end

				if objPetName == petName then
					local uid = obj:GetAttribute("PET_UUID")

					if not uid then
						uid = obj:GetAttribute("UUID") or obj:GetAttribute("UID") or obj:GetAttribute("Id")
					end

					if not uid then
						for _, child in ipairs(obj:GetChildren()) do
							if
								child:IsA("StringValue")
								and (child.Name == "PET_UUID" or child.Name == "UUID" or child.Name == "UID")
							then
								uid = child.Value
								break
							end
						end
					end

					if uid then
						local age = tonumber(
							obj:GetAttribute("Age") or obj:GetAttribute("PetAge") or obj:GetAttribute("petAge") or 0
						) or 0
						local kg = tonumber(
							obj:GetAttribute("Weight")
								or obj:GetAttribute("KG")
								or obj:GetAttribute("kg")
								or obj:GetAttribute("Mass")
								or obj:GetAttribute("PetWeight")
								or 0
						) or 0

						table.insert(matches, {
							Tool = obj,
							UID = tostring(uid),
							Name = petName,
							Age = age,
							KG = kg,
						})
					end
				end
			end
		end
	end
	return matches
end

--// ============================================
--// LIBRARY
--// ============================================
local function loadLibrary()
	if getgenv().Library and typeof(getgenv().Library) == "table" and not getgenv().Library.Unloaded then
		return getgenv().Library
	end
	if isfile and isfile("LRX/LRXUI.lua") then
		local lib = loadstring(readfile("LRX/LRXUI.lua"))()
		getgenv().Library = lib
		return lib
	end
	if not game or not game.HttpGet then
		error("[LRX] HttpGet unavailable")
	end
	local ok, src = pcall(
		game.HttpGet,
		game,
		"https://raw.githubusercontent.com/Lqwrence16/Lqwrence-TradeWorld/refs/heads/main/library.lua"
	)
	if not ok or not src or #src < 1000 then
		error("[LRX] Download failed")
	end
	if makefolder and not isfolder("LRX") then
		makefolder("LRX")
	end
	if writefile then
		writefile("LRX/LRXUI.lua", src)
	end
	local lib = loadstring(src)()
	getgenv().Library = lib
	return lib
end

local Library = loadLibrary()

--// ============================================
--// UI
--// ============================================
local Window = Library:CreateWindow({
	Title = "Booth Claimer",
	Footer = "TradeWorld",
	Icon = "rbxassetid://10747372976",
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.fromOffset(480, 420),
	Center = true,
	AutoShow = true,
	Resizable = true,
	CornerRadius = 6,
	NotifySide = "Right",
	ShowCustomCursor = true,
	Font = Enum.Font.BuilderSans,
	ToggleKeybind = Enum.KeyCode.RightControl,
	MobileButtonsSide = "Left",
})

--// ============================================
--// TAB 1: CLAIMER
--// ============================================
local ClaimerTab = Window:AddTab({ Name = "Claimer", Icon = "store", Description = "Auto-claim trade booths" })
local ClaimerGroup = ClaimerTab:AddLeftGroupbox("Controls", "sliders-horizontal", true)
local StatusGroup = ClaimerTab:AddRightGroupbox("Status", "activity", false)

local StatusLabel = StatusGroup:AddLabel("Status: Idle", false, 14)
StatusGroup:AddLabel("Spawn: " .. string.format("%.0f, %.0f, %.0f", SpawnPos.X, SpawnPos.Y, SpawnPos.Z), false, 12)
local BoothInfoLabel = StatusGroup:AddLabel("Booths: scanning...", false, 12)

local skins, sMap = ScanSkins()
if skins then
	skinMap = sMap
else
	skins = { "Default" }
	skinMap = { ["Default"] = "Wooden Stall" }
end
if not table.find(skins, SelectedSkin) then
	SelectedSkin = skins[1] or "Default"
end

local SkinDropdown = ClaimerGroup:AddDropdown("BoothSkin", {
	Text = "Booth Skin",
	Values = skins,
	Default = SelectedSkin,
	FormatDisplayValue = function(v)
		return skinMap[v] or v
	end,
	Callback = function(v)
		SelectedSkin = v
		SetConfig("SelectedSkin", v)
	end,
})

ClaimerGroup:AddButton({
	Text = "Refresh Skins",
	Func = function()
		StatusLabel:SetText("Scanning...")
		local ns, nm = ScanSkins()
		if ns then
			skinMap = nm
			SkinDropdown:SetValues(ns)
			StatusLabel:SetText("Found " .. #ns .. " skins")
		else
			StatusLabel:SetText("No skins found")
		end
	end,
})

ClaimerGroup:AddDivider()

ClaimerGroup:AddButton({
	Text = "Claim Best Booth Now",
	Func = function()
		if HasBooth() then
			StatusLabel:SetText("Already have " .. GetBoothNumberString(MyBooth))
			return
		end
		MyBooth = nil
		local booth = GetBestFreeBooth()
		if not booth then
			StatusLabel:SetText("No free booths")
			return
		end

		StatusLabel:SetText("Equipping skin...")
		pcall(function()
			SkinRemote:FireServer(SelectedSkin)
		end)
		task.wait(0.3)

		StatusLabel:SetText("Claiming " .. GetBoothNumberString(booth) .. "...")
		pcall(function()
			ClaimRemote:FireServer(booth)
		end)

		local claimed = false
		for i = 1, 6 do
			task.wait(0.5)
			if IsOccupied(booth) then
				claimed = true
				break
			end
		end

		if claimed then
			MyBooth = booth
			HadBooth = true
			FailCount = 0
			StatusLabel:SetText("Claimed " .. GetBoothNumberString(booth))
		else
			FailCount = FailCount + 1
			StatusLabel:SetText("Verify failed (" .. FailCount .. ")")
		end
	end,
})

ClaimerGroup:AddDivider()

ClaimerGroup:AddToggle("AutoClaim", {
	Text = "Auto Claim",
	Default = AutoClaim,
	Callback = function(v)
		AutoClaim = v
		SetConfig("AutoClaim", v)
		StatusLabel:SetText(v and "Auto ON" or "Idle")
	end,
})

--// ============================================
--// TAB 2: PET LISTING
--// ============================================
local PetTab = Window:AddTab({ Name = "Pet List", Icon = "paw-print", Description = "Auto-list pets from inventory" })
local PetGroup = PetTab:AddLeftGroupbox("Auto Lister", "paw-print", false)
local OverrideGroup = PetTab:AddRightGroupbox("Override Listing", "filter", false)

OverrideGroup:AddLabel("Put 0 for default / no limit", false, 12)

OverrideGroup:AddInput("MinAge", {
	Text = "Min Age",
	Default = tostring(MinAge),
	Numeric = true,
	Finished = true,
	Placeholder = "0",
	Callback = function(v)
		MinAge = tonumber(v) or 0
		SetConfig("MinAge", MinAge)
	end,
})

OverrideGroup:AddInput("MaxAge", {
	Text = "Max Age",
	Default = tostring(MaxAge),
	Numeric = true,
	Finished = true,
	Placeholder = "0",
	Callback = function(v)
		MaxAge = tonumber(v) or 0
		SetConfig("MaxAge", MaxAge)
	end,
})

OverrideGroup:AddInput("MinKG", {
	Text = "Min KG",
	Default = tostring(MinKG),
	Numeric = true,
	Finished = true,
	Placeholder = "0",
	Callback = function(v)
		MinKG = tonumber(v) or 0
		SetConfig("MinKG", MinKG)
	end,
})

OverrideGroup:AddInput("MaxKG", {
	Text = "Max KG",
	Default = tostring(MaxKG),
	Numeric = true,
	Finished = true,
	Placeholder = "0",
	Callback = function(v)
		MaxKG = tonumber(v) or 0
		SetConfig("MaxKG", MaxKG)
	end,
})

-- Pet listing left side
local PetNames = ScanPetRegistry()
if not table.find(PetNames, SelectedPet) then
	SelectedPet = PetNames[1] or ""
end

local PetDropdown = PetGroup:AddDropdown("PetType", {
	Text = "Pet Type",
	Values = PetNames,
	Default = SelectedPet,
	Searchable = true,
	Callback = function(v)
		SelectedPet = v
		SetConfig("SelectedPet", v)
	end,
})

PetGroup:AddButton({
	Text = "Refresh Pet List",
	Func = function()
		local newNames = ScanPetRegistry()
		PetDropdown:SetValues(newNames)
		ListStatusLabel:SetText("Refreshed: " .. #newNames .. " pets")
	end,
})

PetGroup:AddDivider()

local ListStatusLabel = PetGroup:AddLabel("Ready", false, 12)
local ListedCountLabel = PetGroup:AddLabel("Listed: 0/50", false, 12)

PetGroup:AddInput("ListPrice", {
	Text = "Listing Price",
	Default = tostring(ListPrice),
	Numeric = true,
	Finished = true,
	Placeholder = "Enter price...",
	Callback = function(v)
		ListPrice = tonumber(v) or 99
		SetConfig("ListPrice", ListPrice)
	end,
})

PetGroup:AddDivider()

PetGroup:AddToggle("AutoList", {
	Text = "Auto List",
	Default = AutoList,
	Callback = function(v)
		AutoList = v
		SetConfig("AutoList", v)
		ListStatusLabel:SetText(v and "Auto List ON" or "Auto List OFF")
	end,
})

--// Unlist section
PetGroup:AddDivider()

local UnlistMap = {}
local UnlistDropdown = PetGroup:AddDropdown("UnlistPet", {
	Text = "Listed Pets",
	Values = { "Select All" },
	Default = "Select All",
	Searchable = true,
	FormatDisplayValue = function(v)
		return UnlistMap[v] or v
	end,
	Callback = function(v)
		UnlistSelection = v
	end,
})

local function GetListedPetDetails()
	local uuid = GetMyBoothUUID()
	local items = {}
	if not uuid then
		return items
	end
	local listings = GetBoothListings(uuid)
	for _, item in ipairs(listings) do
		local display = item.Name
		if item.Age and item.Age > 0 then
			display = display .. " [Age:" .. item.Age .. "]"
		end
		if item.KG and item.KG > 0 then
			display = display .. " [KG:" .. item.KG .. "]"
		end
		display = display .. " @ " .. item.Price
		table.insert(items, {
			Value = item.ListingUUID,
			Display = display,
			Data = item,
		})
	end
	return items
end

local function RefreshUnlistDropdown()
	local details = GetListedPetDetails()
	local values = { "Select All" }
	UnlistMap = { ["Select All"] = "Select All" }
	for _, d in ipairs(details) do
		table.insert(values, d.Value)
		UnlistMap[d.Value] = d.Display
	end
	UnlistDropdown:SetValues(values)
end

PetGroup:AddButton({
	Text = "Refresh Listed Pets",
	Func = function()
		RefreshUnlistDropdown()
		local count = GetLiveListingCount()
		ListedCountLabel:SetText("Listed: " .. count .. "/50")
		ListStatusLabel:SetText("Found " .. count .. " listed pets")
	end,
})

PetGroup:AddButton({
	Text = "Unlist",
	Func = function()
		local uuid = GetMyBoothUUID()
		if not uuid then
			ListStatusLabel:SetText("No booth claimed")
			return
		end

		local listings = GetBoothListings(uuid)
		local toUnlist = {}

		if UnlistSelection == "Select All" then
			toUnlist = listings
		else
			for _, item in ipairs(listings) do
				if item.ListingUUID == UnlistSelection then
					table.insert(toUnlist, item)
					break
				end
			end
		end

		if #toUnlist == 0 then
			ListStatusLabel:SetText("Nothing to unlist")
			return
		end

		local removed = 0
		for i, item in ipairs(toUnlist) do
			local ok = pcall(function()
				RemoveListingRemote:InvokeServer(item.ListingUUID)
			end)
			if ok then
				removed = removed + 1
			end
			ListStatusLabel:SetText("Unlisting " .. i .. "/" .. #toUnlist)
			task.wait(0.2)
		end

		task.wait(0.3)
		RefreshUnlistDropdown()
		local count = GetLiveListingCount()
		ListedCountLabel:SetText("Listed: " .. count .. "/50")
		ListStatusLabel:SetText("Unlisted " .. removed .. "/" .. #toUnlist)
	end,
})

--// ============================================
--// TAB 3: AUTO SERVER HOP
--// ============================================
local HopTab = Window:AddTab({ Name = "Server Hop", Icon = "globe", Description = "Auto hop servers on timer" })
local HopGroup = HopTab:AddLeftGroupbox("Settings", "timer", false)

local HopMinutes = GetConfig("HopMinutes", 20)
local AutoHop = GetConfig("AutoHop", false)
local HopEnabled = AutoHop
local NextHopTime = 0

if HopEnabled then
	NextHopTime = tick() + (HopMinutes * 60)
end

local HopStatusLabel = HopGroup:AddLabel("Status: Idle", false, 14)

HopGroup:AddInput("HopMinutes", {
	Text = "Interval (minutes)",
	Default = tostring(HopMinutes),
	Numeric = true,
	Finished = true,
	Placeholder = "20",
	Callback = function(v)
		local num = tonumber(v)
		if num and num >= 1 then
			HopMinutes = num
			SetConfig("HopMinutes", num)
			if HopEnabled then
				NextHopTime = tick() + (HopMinutes * 60)
			end
			HopStatusLabel:SetText("Interval set: " .. HopMinutes .. " min")
		end
	end,
})

HopGroup:AddInput("SaleCooldown", {
	Text = "Sale Cooldown (min)",
	Default = tostring(SaleCooldownMinutes),
	Numeric = true,
	Finished = true,
	Placeholder = "1",
	Callback = function(v)
		local num = tonumber(v)
		if num and num >= 0 then
			SaleCooldownMinutes = num
			SetConfig("SaleCooldownMinutes", num)
			HopStatusLabel:SetText("Sale cooldown set: " .. num .. " min")
		end
	end,
})

HopGroup:AddInput("MinPlayers", {
	Text = "Min Players",
	Default = tostring(MinPlayers),
	Numeric = true,
	Finished = true,
	Placeholder = "5",
	Callback = function(v)
		local num = tonumber(v)
		if num and num >= 0 then
			MinPlayers = num
			SetConfig("MinPlayers", num)
			HopStatusLabel:SetText("Min players set: " .. num)
		end
	end,
})

local SaleCooldownLabel = HopGroup:AddLabel("No recent sales", false, 12)

HopGroup:AddToggle("AutoHop", {
	Text = "Auto Server Hop",
	Default = HopEnabled,
	Callback = function(v)
		HopEnabled = v
		SetConfig("AutoHop", v)
		if v then
			NextHopTime = tick() + (HopMinutes * 60)
			HopStatusLabel:SetText("Hopping in " .. HopMinutes .. " min")
		else
			HopStatusLabel:SetText("Auto Hop OFF")
		end
	end,
})

HopGroup:AddButton({
	Text = "Hop Now",
	Func = function()
		local remaining = math.max(0, SaleCooldownEnd - tick())
		if remaining > 0 then
			local mins = math.floor(remaining / 60)
			local secs = math.floor(remaining % 60)
			HopStatusLabel:SetText("Blocked: sale cooldown " .. mins .. "m " .. secs .. "s")
			return
		end
		HopStatusLabel:SetText("Hopping...")
		task.wait(0.5)
		ServerHop()
	end,
})

HopGroup:AddButton({
	Text = "Reset Timer",
	Func = function()
		if HopEnabled then
			NextHopTime = tick() + (HopMinutes * 60)
			HopStatusLabel:SetText("Timer reset: " .. HopMinutes .. " min")
		else
			HopStatusLabel:SetText("Enable Auto Hop first")
		end
	end,
})

--// ============================================
--// SERVER HOP FUNCTION
--// ============================================
function ServerHop()
	pcall(function()
		local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
		local raw = game:HttpGet(api)
		local decoded = HttpService:JSONDecode(raw)

		if decoded and decoded.data then
			for _, server in ipairs(decoded.data) do
				if server.id ~= game.JobId and server.playing >= MinPlayers and server.playing < server.maxPlayers then
					HopStatusLabel:SetText("Teleporting...")
					TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
					return
				end
			end
		end
		HopStatusLabel:SetText("No servers found")
	end)
end

--// ============================================
--// SERVER HOP LOOP
--// ============================================
task.spawn(function()
	while not ShouldStop() do
		if HopEnabled then
			local saleRemaining = math.max(0, SaleCooldownEnd - tick())
			if saleRemaining > 0 then
				local mins = math.floor(saleRemaining / 60)
				local secs = math.floor(saleRemaining % 60)
				HopStatusLabel:SetText("Sale cooldown: " .. mins .. "m " .. secs .. "s")
				SaleCooldownLabel:SetText("Blocking hop: " .. mins .. "m " .. secs .. "s")
			else
				local remaining = math.max(0, NextHopTime - tick())
				if remaining <= 0 then
					HopStatusLabel:SetText("Server hopping...")
					task.wait(1)
					ServerHop()
					task.wait(10)
				else
					local mins = math.floor(remaining / 60)
					local secs = math.floor(remaining % 60)
					HopStatusLabel:SetText("Next hop: " .. mins .. "m " .. secs .. "s")
					SaleCooldownLabel:SetText("No recent sales")
				end
			end
		else
			HopStatusLabel:SetText("Auto Hop OFF")
			SaleCooldownLabel:SetText("No recent sales")
		end
		task.wait(1)
	end
end)

--// ============================================
--// AUTO REJOIN
--// ============================================
local function SetupAutoRejoin()
	local function TryRejoin()
		task.wait(2)
		pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
	end

	pcall(function()
		game:GetService("NetworkClient").ChildRemoved:Connect(function()
			TryRejoin()
		end)
	end)

	pcall(function()
		game:GetService("CoreGui").ChildAdded:Connect(function(child)
			if child:IsA("ScreenGui") then
				local n = child.Name:lower()
				if n:find("error") or n:find("kick") or n:find("ban") or n:find("disconnect") then
					TryRejoin()
				end
			end
		end)
	end)
end

SetupAutoRejoin()

--// ============================================
--// STARTUP: scan booth numbers + find booth + init
--// ============================================
task.spawn(function()
	task.wait(1)
	ScanBoothNumbers()

	-- Update booth info label
	local myBooth, occupied, unclaimed = GetAllBoothStatus()
	local info = "Booths: "
	if myBooth then
		info = info .. "You=#" .. myBooth.Number .. " "
	end
	info = info .. "Free=" .. #unclaimed .. " Occ=" .. #occupied
	BoothInfoLabel:SetText(info)

	-- Try data-first booth discovery
	local fromData = FindMyBoothFromData()
	if fromData then
		MyBooth = fromData
		HadBooth = true
		StatusLabel:SetText("Tracking " .. GetBoothNumberString(fromData))
	elseif TradeBoothOpen() then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local nearest = nil
			local nearDist = 8
			for _, booth in ipairs(BoothsFolder:GetChildren()) do
				if booth:IsA("Model") or booth:IsA("Folder") and IsOccupied(booth) then
					local d = (GetPos(booth) - hrp.Position).Magnitude
					if d < nearDist then
						nearDist = d
						nearest = booth
					end
				end
			end
			if nearest then
				MyBooth = nearest
				HadBooth = true
				StatusLabel:SetText("Tracking " .. GetBoothNumberString(nearest))
			end
		end
	end

	task.wait(1)
	local count = GetLiveListingCount()
	ListedCountLabel:SetText("Listed: " .. count .. "/50")
	PreviousListingCount = count
	RefreshUnlistDropdown()
end)

--// ============================================
--// MAIN LOOP -- AUTO CLAIM (auto-reclaims on loss)
--// ============================================
task.spawn(function()
	while not ShouldStop() do
		if AutoClaim then
			-- Recover booth ref from data if lost
			if not MyBooth or not MyBooth.Parent then
				local fromData = FindMyBoothFromData()
				if fromData then
					MyBooth = fromData
				end
			end

			if HasBooth() then
				if not HadBooth then
					HadBooth = true
				end
				FailCount = 0
				if MyBooth then
					StatusLabel:SetText("Own " .. GetBoothNumberString(MyBooth))
				else
					StatusLabel:SetText("Have booth")
				end
			else
				MyBooth = nil
				if HadBooth then
					HadBooth = false
					if ListStatusLabel then
						ListStatusLabel:SetText("Booth unclaimed")
					end
				end
				local now = tick()
				local cd = math.min(COOLDOWN + (FailCount * 2), 10)
				if now - LastClaim >= cd then
					LastClaim = now
					local booth = GetBestFreeBooth()
					if booth then
						StatusLabel:SetText("Claiming " .. GetBoothNumberString(booth) .. "...")
						pcall(function()
							SkinRemote:FireServer(SelectedSkin)
						end)
						task.wait(0.3)
						pcall(function()
							ClaimRemote:FireServer(booth)
						end)

						local claimed = false
						for i = 1, 6 do
							task.wait(0.5)
							if IsOccupied(booth) then
								claimed = true
								break
							end
						end

						if claimed then
							MyBooth = booth
							HadBooth = true
							FailCount = 0
							StatusLabel:SetText("Claimed " .. GetBoothNumberString(booth))
						else
							FailCount = FailCount + 1
							StatusLabel:SetText(
								"Failed ("
									.. FailCount
									.. "), retry in "
									.. math.min(COOLDOWN + (FailCount * 2), 10)
									.. "s"
							)
						end
					else
						StatusLabel:SetText("No free booths")
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

--// ============================================
--// AUTO LIST LOOP -- uses live data, no cache
--// ============================================
task.spawn(function()
	while not ShouldStop() do
		if not AutoList then
			ListStatusLabel:SetText("Auto List OFF")
			task.wait(0.2)
			continue
		end

		if SelectedPet == "" then
			ListStatusLabel:SetText("No pet selected")
			task.wait(0.5)
			continue
		end

		if not HasBooth() then
			ListStatusLabel:SetText("No booth claimed")
			task.wait(0.5)
			continue
		end

		local price = tonumber(ListPrice) or 99
		if price <= 0 then
			ListStatusLabel:SetText("Invalid price")
			task.wait(0.5)
			continue
		end

		local liveCount = GetLiveListingCount()
		if liveCount >= MAX_LISTINGS then
			ListStatusLabel:SetText("Max listings reached (" .. liveCount .. "/50)")
			ListedCountLabel:SetText("Listed: " .. liveCount .. "/50")
			task.wait(1)
			continue
		end

		local allPets = GetPetsInBackpack(SelectedPet)
		local pets = {}
		for _, p in ipairs(allPets) do
			if not IsPetListed(p.UID) and PetMatchesFilters(p) then
				table.insert(pets, p)
			end
		end

		if #pets == 0 then
			if #allPets > 0 then
				ListStatusLabel:SetText(
					"All " .. #allPets .. " " .. SelectedPet .. "(s) already listed or filtered out"
				)
			else
				ListStatusLabel:SetText("No " .. SelectedPet .. " in inventory")
			end
			ListedCountLabel:SetText("Listed: " .. liveCount .. "/50")
			task.wait(1.0)
			continue
		end

		local slotsLeft = MAX_LISTINGS - liveCount
		local toList = math.min(#pets, slotsLeft)

		ListStatusLabel:SetText("Found " .. toList .. " unlisted " .. SelectedPet .. "(s)")
		ListedCountLabel:SetText("Listed: " .. liveCount .. "/50")

		for i = 1, toList do
			local petData = pets[i]
			if not AutoList then
				ListStatusLabel:SetText("Stopped")
				break
			end
			if SelectedPet ~= petData.Name then
				ListStatusLabel:SetText("Pet changed, restarting...")
				break
			end
			if not HasBooth() then
				ListStatusLabel:SetText("Booth lost")
				break
			end
			if GetLiveListingCount() >= MAX_LISTINGS then
				ListStatusLabel:SetText("Max listings reached")
				break
			end

			local currentPrice = tonumber(ListPrice) or 99
			local ok = pcall(function()
				CreateListingRemote:InvokeServer("Pet", petData.UID, currentPrice)
			end)

			if ok then
				ListStatusLabel:SetText("Listed " .. i .. "/" .. toList .. " " .. SelectedPet .. " @ " .. currentPrice)
			else
				ListStatusLabel:SetText("Failed " .. i .. "/" .. toList)
			end

			local elapsed = 0
			while elapsed < 5.0 do
				task.wait(0.1)
				elapsed = elapsed + 0.1
				if not AutoList then
					break
				end
				if SelectedPet ~= petData.Name then
					break
				end
				if not HasBooth() then
					break
				end
				if GetLiveListingCount() >= MAX_LISTINGS then
					break
				end
			end
			if not AutoList then
				break
			end
			if SelectedPet ~= petData.Name then
				break
			end
		end

		task.wait(0.2)
	end
end)

--// ============================================
--// SALE WATCHER -- live data count comparison
--// ============================================
task.spawn(function()
	task.wait(3)
	while not ShouldStop() do
		task.wait(1)
		if not ShouldStop() and HasBooth() then
			local uuid = GetMyBoothUUID()
			if uuid then
				local live = GetBoothListings(uuid)
				local currentCount = #live

				if ListedCountLabel then
					ListedCountLabel:SetText("Listed: " .. currentCount .. "/50")
				end

				if currentCount < PreviousListingCount then
					local sold = PreviousListingCount - currentCount
					SaleCooldownEnd = tick() + (SaleCooldownMinutes * 60)
					if SaleCooldownLabel then
						SaleCooldownLabel:SetText("Sale detected! Cooldown reset")
					end
					if HopStatusLabel then
						HopStatusLabel:SetText("Sale! Cooldown active")
					end
					if ListStatusLabel then
						ListStatusLabel:SetText("Sold " .. sold .. "x -- slots freed")
					end
				end

				PreviousListingCount = currentCount
			end
		end
	end
end)

--// ============================================
--// BOOTH INFO REFRESH LOOP
--// ============================================
task.spawn(function()
	while not ShouldStop() do
		task.wait(5)
		if not ShouldStop() then
			ScanBoothNumbers()
			local myBooth, occupied, unclaimed = GetAllBoothStatus()
			local info = "Booths: "
			if myBooth then
				info = info .. "You=#" .. myBooth.Number .. " "
			end
			info = info .. "Free=" .. #unclaimed .. " Occ=" .. #occupied
			BoothInfoLabel:SetText(info)
		end
	end
end)

print("[BoothClaimer] Loaded | Numbered booths | Receiver: " .. tostring(BoothDataReceiver ~= nil))
