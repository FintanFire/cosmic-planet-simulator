--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlanetConfig = require(Shared:WaitForChild("PlanetConfig"))
local SpeciesConfig = require(Shared:WaitForChild("SpeciesConfig"))
local PlanetGenerator = require(Shared:WaitForChild("PlanetGenerator"))

local Remotes = ReplicatedStorage:WaitForChild("PlanetRemotes")
local UpdateCustomizationEvent = Remotes:WaitForChild("UpdateCustomization") :: RemoteEvent
local SelectSpeciesEvent = Remotes:WaitForChild("SelectSpecies") :: RemoteEvent
local FinalizeSetupEvent = Remotes:WaitForChild("FinalizeSetup") :: RemoteEvent
local UnlockEvolutionEvent = Remotes:WaitForChild("UnlockEvolution") :: RemoteEvent
local UpgradePlanetValueEvent = Remotes:WaitForChild("UpgradePlanetValue") :: RemoteEvent
local UpgradeMachineEvent = Remotes:WaitForChild("UpgradeMachine") :: RemoteEvent
local WarpToSectorEvent = Remotes:WaitForChild("WarpToSector") :: RemoteEvent
local UnlockSpaceStationEvent = Remotes:WaitForChild("UnlockSpaceStation") :: RemoteEvent
local HatchCompanionPodEvent = Remotes:WaitForChild("HatchCompanionPod") :: RemoteEvent
local CompanionActionEvent = Remotes:WaitForChild("CompanionAction") :: RemoteEvent
local BuyBoosterEvent = Remotes:WaitForChild("BuyBooster") :: RemoteEvent
local ClaimPlaytimeGiftEvent = Remotes:WaitForChild("ClaimPlaytimeGift") :: RemoteEvent
local RedeemPromoCodeEvent = Remotes:WaitForChild("RedeemPromoCode") :: RemoteEvent
local BuyShardUpgradeEvent = Remotes:WaitForChild("BuyShardUpgrade") :: RemoteEvent
local AscendPlanetEvent = Remotes:WaitForChild("AscendPlanet") :: RemoteEvent
local TeleportToHubEvent = Remotes:WaitForChild("TeleportToHub") :: RemoteEvent
local FlightSyncEvent = Remotes:WaitForChild("FlightSync") :: RemoteEvent
local RequestInitialStateEvent = Remotes:WaitForChild("RequestInitialState") :: RemoteEvent
local StateSyncEvent = Remotes:WaitForChild("StateSync") :: RemoteEvent
local NotificationEvent = Remotes:WaitForChild("Notification") :: RemoteEvent

-- ============================================================================
-- 1. USER SETTINGS & AUTHENTIC, NON-INTRUSIVE SFX ENGINE
-- ============================================================================
local userSettings = {
	SfxVolume = 0.75, -- 0.0, 0.4, 0.75, 1.0
	ThrusterHum = 0.5, -- 0.0 (Off), 0.5 (Subtle), 1.0 (Standard)
	StarDensity = 220, -- 120, 220, 320
	ShowCollectibleIcons = true,
	BaseFOV = 70,
}

local sfxFolder = SoundService:FindFirstChild("PlanetGameSFX")
if sfxFolder then
	sfxFolder:Destroy()
end
sfxFolder = Instance.new("Folder")
sfxFolder.Name = "PlanetGameSFX"
sfxFolder.Parent = SoundService

local function createSound(name: string, soundId: string, baseVolume: number, speed: number, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Volume = baseVolume
	s.PlaybackSpeed = speed
	s.Looped = looped or false
	s.Parent = sfxFolder
	return s
end

-- Authentic, subtle mechanical & ambient audio (no grating retro buzz)
local sfxClick = createSound("Click", "rbxassetid://6895079853", 0.28, 1.05)
local sfxHover = createSound("Hover", "rbxassetid://6895079853", 0.10, 1.35)
local sfxUpgrade = createSound("Upgrade", "rbxassetid://9119720940", 0.38, 1.0)
local sfxEvolve = createSound("Evolve", "rbxassetid://9119720940", 0.45, 0.88)
local sfxLaunch = createSound("Launch", "rbxassetid://9114224721", 0.35, 0.95)
local sfxThrusterLoop = createSound("DeepSpaceThrusterHum", "rbxassetid://9114224721", 0.0, 0.72, true)
pcall(function()
	sfxThrusterLoop:Play()
end)

local function playSFX(snd: Sound, baseVol: number, pitchJitter: number?)
	if userSettings.SfxVolume <= 0.01 then
		return
	end
	pcall(function()
		snd.Volume = baseVol * userSettings.SfxVolume
		if pitchJitter then
			snd.PlaybackSpeed = 1.0 + (math.random() - 0.5) * pitchJitter
		end
		snd:Play()
	end)
end

-- ============================================================================
-- 2. LOCAL STATE MIRROR
-- ============================================================================
local HUB_SPAWN_POS = Vector3.new(0, 48, 215)

local currentState: any = {
	HasCompletedSetup = true,
	Resources = { Minerals = 0, Biomass = 0, Energy = 0, Tech = 0 },
	Gems = 75,
	CosmicShards = 0,
	Population = 10.0,
	PlanetValueScore = 100,
	RankIndex = 1,
	Ascensions = 0,
	MissionIndex = 1,
	OrbsHarvested = 0,
	DronesHatched = 0,
	PlaytimeSeconds = 0,
	ClaimedPlaytimeGifts = {},
	RedeemedCodes = {},
	UnlockedStations = { Hub = true },
	ActiveBoosters = { YieldBoost = 0, GemBoost = 0, SpeedBoost = 0 },
	ShardUpgrades = { PermValue = 0, PermGems = 0, ExtraDroneSlots = 0, PermSpeed = 0 },
	Companions = {},
	MaxEquippedDrones = 3,
	Look = table.clone(PlanetConfig.DefaultPlanetLook),
	SpeciesId = "Terranauts",
	UnlockedEvolutions = { Awakening = true },
	ActiveEvolutionId = "Awakening",
	PlanetUpgrades = {
		CoreDensity = 0,
		BiosphereFertility = 0,
		MagnetosphereDynamo = 0,
		OrbitalInfrastructure = 0,
		CivilizationMetropolis = 0,
		AnomalyHarvester = 0,
	},
	MachineTiers = {},
	Rates = {
		Gems = 2.5,
		Minerals = 0,
		Biomass = 0,
		Energy = 0,
		Tech = 0,
		FlightSpeed = 135,
		DrillPower = 999,
		GlobalYieldMult = 1.0,
		GemMultiplier = 1.0,
		CompanionMult = 1.0,
		InHubSanctuary = true,
		ActiveDistrictName = "",
		CurrentSectorName = "Zone 1: Inner Sanctuary Orbit  •  1x Node Loot",
		CurrentZoneTier = 1,
		CurrentZoneReqDrill = 0,
	},
	PlanetPosition = HUB_SPAWN_POS,
}

local localPlanetPos = HUB_SPAWN_POS
local localVelocity = Vector3.zero
local spinAngle = 0
local currentBankRoll = 0
local currentBankPitch = 0
local syncTimer = 0

local function getRotationSpeedValue(): number
	local rotId = currentState.Look.RotationSpeedId or "Normal"
	for _, r in ipairs(PlanetConfig.RotationSpeeds) do
		if r.Id == rotId then
			return r.Speed
		end
	end
	return 0.42
end

local function getLocalPlanetScaleFactor(): number
	local sum = 0
	if type(currentState.PlanetUpgrades) == "table" then
		for _, lvl in pairs(currentState.PlanetUpgrades) do
			sum += (lvl or 0)
		end
	end
	local rankDef = PlanetConfig.PlanetaryRanks[currentState.RankIndex or 1] or PlanetConfig.PlanetaryRanks[1]
	local rankBonus = rankDef.SizeBonus or 0
	return 1.0 + math.min(sum * 0.018 + rankBonus, 1.85)
end

-- ============================================================================
-- 3. CLIENT-RENDERED ACTIVE PLANET & INFINITE 3D SCATTERED STARFIELD
-- ============================================================================
local activeClientPlanetFolder = Workspace:FindFirstChild("ClientActivePlanet")
if activeClientPlanetFolder then
	activeClientPlanetFolder:Destroy()
end
activeClientPlanetFolder = Instance.new("Folder")
activeClientPlanetFolder.Name = "ClientActivePlanet"
activeClientPlanetFolder.Parent = Workspace

local clientStarsFolder = Workspace:FindFirstChild("ClientInfiniteStarfield")
if clientStarsFolder then
	clientStarsFolder:Destroy()
end
clientStarsFolder = Instance.new("Folder")
clientStarsFolder.Name = "ClientInfiniteStarfield"
clientStarsFolder.Parent = Workspace

-- Build 240 local 3D stars that wrap infinitely around the camera as you fly anywhere in space!
local starPool: { { Part: Part, Offset: Vector3 } } = {}
do
	local rng = Random.new(90210)
	local sCols = {
		Color3.fromRGB(255, 252, 245),
		Color3.fromRGB(205, 230, 255),
		Color3.fromRGB(255, 232, 175),
		Color3.fromRGB(255, 195, 140),
		Color3.fromRGB(185, 220, 255),
	}
	for i = 1, 240 do
		local off = Vector3.new(
			rng:NextNumber(-900, 900),
			rng:NextNumber(-550, 550),
			rng:NextNumber(-900, 900)
		)
		local isBright = (i % 9 == 0)
		local sz = isBright and rng:NextNumber(2.8, 4.8) or rng:NextNumber(1.1, 2.2)
		local col = sCols[rng:NextInteger(1, #sCols)]

		local p = Instance.new("Part")
		p.Name = "InfStar_" .. i
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = col
		p.Size = Vector3.new(sz, sz, sz)
		p.CFrame = CFrame.new(off)
		p.Parent = clientStarsFolder

		if isBright then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(sz * 3.0, 0, sz * 3.0, 0)
			bb.AlwaysOnTop = false
			bb.LightInfluence = 0
			bb.MaxDistance = 3000
			bb.Adornee = p
			bb.Parent = p

			local img = Instance.new("ImageLabel")
			img.Size = UDim2.fromScale(1, 1)
			img.BackgroundTransparency = 1
			img.Image = "rbxasset://textures/particles/sparkles_main.dds"
			img.ImageColor3 = col
			img.ImageTransparency = 0.18
			img.Parent = bb
		end

		table.insert(starPool, { Part = p, Offset = off })
	end
end

local function updateInfiniteStarfield(centerPos: Vector3)
	local boxX, boxY, boxZ = 1800, 1100, 1800
	local halfX, halfY, halfZ = boxX * 0.5, boxY * 0.5, boxZ * 0.5
	for idx, item in ipairs(starPool) do
		if idx <= userSettings.StarDensity then
			-- Wrap each star's offset modulo the 3D box around `centerPos`
			local dx = (item.Offset.X - centerPos.X) % boxX
			local dy = (item.Offset.Y - centerPos.Y) % boxY
			local dz = (item.Offset.Z - centerPos.Z) % boxZ
			local wx = centerPos.X + dx - halfX
			local wy = centerPos.Y + dy - halfY
			local wz = centerPos.Z + dz - halfZ
			local worldPos = Vector3.new(wx, wy, wz)
			-- Keep stars at least 85 studs away from the player's planet so you don't clip through close dots
			if (worldPos - centerPos).Magnitude < 85 then
				worldPos = worldPos + Vector3.new(0, 140, 0)
			end
			item.Part.CFrame = CFrame.new(worldPos)
			item.Part.Transparency = 0
		else
			item.Part.Transparency = 1
		end
	end
end

local localActivePlanetModel: Model? = nil
local lastBuiltPlanetSignature = ""

local function computePlanetSignature(): string
	local l = currentState.Look or {}
	local wc = l.WaterColor or { 0, 0, 0 }
	local lc = l.LandColor or { 0, 0, 0 }
	local tc = l.TreeColor or { 0, 0, 0 }
	local rc = l.RockColor or { 0, 0, 0 }
	local ac = l.AtmosphereColor or { 0, 0, 0 }
	local cc = l.CloudColor or { 0, 0, 0 }
	local rgc = l.RingColor or { 0, 0, 0 }
	return string.format(
		"%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%.3f|%d_%d_%d|%d_%d_%d|%d_%d_%d|%d_%d_%d|%d_%d_%d|%d_%d_%d|%d_%d_%d",
		tostring(l.PlanetName),
		tostring(l.Biome),
		tostring(l.CoreShape),
		tostring(l.LandCoverage),
		tostring(l.SurfaceFeature),
		tostring(l.RingStyle),
		tostring(l.MoonStyle),
		tostring(l.Atmosphere),
		tostring(l.WaterMaterial),
		tostring(l.LandMaterial),
		tostring(l.RockMaterial),
		tostring(currentState.SpeciesId),
		tostring(currentState.ActiveEvolutionId),
		getLocalPlanetScaleFactor(),
		wc[1] or 0, wc[2] or 0, wc[3] or 0,
		lc[1] or 0, lc[2] or 0, lc[3] or 0,
		tc[1] or 0, tc[2] or 0, tc[3] or 0,
		rc[1] or 0, rc[2] or 0, rc[3] or 0,
		ac[1] or 0, ac[2] or 0, ac[3] or 0,
		cc[1] or 0, cc[2] or 0, cc[3] or 0,
		rgc[1] or 0, rgc[2] or 0, rgc[3] or 0
	)
end

local function hideServerDuplicateOfMyPlanet()
	local folder = Workspace:FindFirstChild("PlayerPlanets")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == localPlayer.UserId then
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.LocalTransparencyModifier = 1
				elseif desc:IsA("BillboardGui") or desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Highlight") then
					(desc :: any).Enabled = false
				end
			end
		end
	end
end

-- ============================================================================
-- 4. GUI HELPERS & 2D/3D VIEWPORT FACTORIES
-- ============================================================================
local playerGui = localPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("CosmicPlanetUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CosmicPlanetUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addBorderStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addTextStroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(12, 14, 24)
	s.Thickness = thickness or 1.8
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function addGradient(parent: Instance, topColor: Color3, bottomColor: Color3, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = rot or 90
	g.Parent = parent
end

local function attachBounceAndSFX(btn: GuiButton)
	local origSize = btn.Size
	btn.MouseEnter:Connect(function()
		playSFX(sfxHover, 0.10, 0.08)
		TweenService:Create(btn, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(origSize.X.Scale, origSize.X.Offset + 4, origSize.Y.Scale, origSize.Y.Offset + 3),
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = origSize,
		}):Play()
	end)
end

local function create3DViewportThumbnail(parent: Instance, size: UDim2, pos: UDim2, model: Model, camOffset: Vector3): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Size = size
	vf.Position = pos
	vf.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
	vf.Ambient = Color3.fromRGB(175, 182, 198)
	vf.LightColor = Color3.fromRGB(240, 244, 255)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	vf.Parent = parent
	addCorner(vf, 10)
	addBorderStroke(vf, Color3.fromRGB(75, 135, 195), 1.5)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vf

	model:PivotTo(CFrame.Angles(math.rad(14), math.rad(32), 0))
	model.Parent = worldModel

	local vpCam = Instance.new("Camera")
	vpCam.CFrame = CFrame.lookAt(camOffset, Vector3.zero)
	vpCam.Parent = vf
	vf.CurrentCamera = vpCam

	return vf
end

local function buildCustomizationPreviewModel(lookKey: string, itemId: string): (Model, Vector3)
	local previewLook = table.clone(PlanetConfig.DefaultPlanetLook)
	previewLook.RingStyle = "None"
	previewLook.MoonStyle = "None"
	;(previewLook :: any)[lookKey] = itemId

	if lookKey == "Biome" and PlanetConfig.PlanetTypes[itemId] then
		local pt = PlanetConfig.PlanetTypes[itemId]
		previewLook.WaterColor = pt.DefaultColors.WaterColor
		previewLook.LandColor = pt.DefaultColors.LandColor
		previewLook.TreeColor = pt.DefaultColors.TreeColor
		previewLook.RockColor = pt.DefaultColors.RockColor
		previewLook.AtmosphereColor = pt.DefaultColors.AtmosphereColor
		previewLook.CloudColor = pt.DefaultColors.CloudColor
		previewLook.RingColor = pt.DefaultColors.RingColor
		previewLook.WaterMaterial = pt.DefaultMaterials.WaterMaterial
		previewLook.LandMaterial = pt.DefaultMaterials.LandMaterial
		previewLook.RockMaterial = pt.DefaultMaterials.RockMaterial
	end

	local m = PlanetGenerator.BuildPlanetModel("Preview", previewLook, "Terranauts", "Awakening", 0.5, true)
	local camDistVec = Vector3.new(0, 9, 26)
	if lookKey == "RingStyle" or lookKey == "MoonStyle" then
		camDistVec = Vector3.new(0, 16, 40)
	end
	return m, camDistVec
end

local function formatCost(cost: { [string]: number? }): string
	local parts = {}
	if cost.Gems and cost.Gems > 0 then
		table.insert(parts, string.format("%s💎", PlanetConfig.FormatNumber(cost.Gems)))
	end
	if cost.Minerals and cost.Minerals > 0 then
		table.insert(parts, string.format("%s⛏", PlanetConfig.FormatNumber(cost.Minerals)))
	end
	if cost.Biomass and cost.Biomass > 0 then
		table.insert(parts, string.format("%s🌿", PlanetConfig.FormatNumber(cost.Biomass)))
	end
	if cost.Energy and cost.Energy > 0 then
		table.insert(parts, string.format("%s⚡", PlanetConfig.FormatNumber(cost.Energy)))
	end
	if cost.Tech and cost.Tech > 0 then
		table.insert(parts, string.format("%s🔬", PlanetConfig.FormatNumber(cost.Tech)))
	end
	if #parts == 0 then
		return "FREE"
	end
	return table.concat(parts, "  ")
end

-- ============================================================================
-- 5. FULL-SCREEN 2D MAIN MENU (PLAY | CUSTOMIZE | SETTINGS) WITH LIVE 3D PREVIEW
-- ============================================================================
local genesisContainer = Instance.new("Frame")
genesisContainer.Name = "Main2DMenuScreen"
genesisContainer.Size = UDim2.new(1, 0, 1, 0)
genesisContainer.BackgroundColor3 = Color3.fromRGB(9, 12, 22)
genesisContainer.BackgroundTransparency = 0
genesisContainer.Visible = false
genesisContainer.Parent = screenGui

-- Subtle 2D Starfield Backdrop Dots inside the 2D Menu
do
	local bgStars = Instance.new("Frame")
	bgStars.Name = "Menu2DStarBackdrop"
	bgStars.Size = UDim2.fromScale(1, 1)
	bgStars.BackgroundTransparency = 1
	bgStars.Parent = genesisContainer
	local rng = Random.new(1337)
	for i = 1, 85 do
		local dot = Instance.new("Frame")
		local sz = (i % 7 == 0) and 4 or 2
		dot.Size = UDim2.fromOffset(sz, sz)
		dot.Position = UDim2.fromScale(rng:NextNumber(0.01, 0.99), rng:NextNumber(0.02, 0.98))
		dot.BackgroundColor3 = (i % 5 == 0) and Color3.fromRGB(165, 215, 255) or Color3.fromRGB(245, 248, 255)
		dot.BackgroundTransparency = rng:NextNumber(0.15, 0.65)
		dot.BorderSizePixel = 0
		dot.Parent = bgStars
		addCorner(dot, sz)
	end
end

-- TOP NAVIGATION BAR OF THE 2D MENU: [▶️ PLAY]  [🎨 CUSTOMIZE]  [⚙️ SETTINGS]
local menuTopBar = Instance.new("Frame")
menuTopBar.Size = UDim2.new(0, 760, 0, 56)
menuTopBar.AnchorPoint = Vector2.new(0.5, 0)
menuTopBar.Position = UDim2.new(0.5, 0, 0, 14)
menuTopBar.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
menuTopBar.Parent = genesisContainer
addCorner(menuTopBar, 16)
addBorderStroke(menuTopBar, Color3.fromRGB(75, 145, 225), 2)

local menuBrandTitle = Instance.new("TextLabel")
menuBrandTitle.Size = UDim2.new(0, 270, 1, 0)
menuBrandTitle.Position = UDim2.new(0, 16, 0, 0)
menuBrandTitle.BackgroundTransparency = 1
menuBrandTitle.Text = "🪐 COSMIC PLANET SIM"
menuBrandTitle.TextColor3 = Color3.fromRGB(255, 230, 105)
menuBrandTitle.Font = Enum.Font.FredokaOne
menuBrandTitle.TextSize = 20
menuBrandTitle.TextXAlignment = Enum.TextXAlignment.Left
menuBrandTitle.Parent = menuTopBar
addTextStroke(menuBrandTitle, 2)

local menuNavBtnsContainer = Instance.new("Frame")
menuNavBtnsContainer.Size = UDim2.new(0, 450, 0, 40)
menuNavBtnsContainer.Position = UDim2.new(1, -462, 0.5, -20)
menuNavBtnsContainer.BackgroundTransparency = 1
menuNavBtnsContainer.Parent = menuTopBar

local menuNavLayout = Instance.new("UIGridLayout")
menuNavLayout.CellSize = UDim2.new(0, 142, 1, 0)
menuNavLayout.CellPadding = UDim2.new(0, 10, 0, 0)
menuNavLayout.Parent = menuNavBtnsContainer

local menuPages: { [string]: Frame } = {}
local menuTabButtons: { [string]: TextButton } = {}

-- Forward declaration for `refreshUI` and `launchIntoHub`
local refreshUI: () -> ()
local launchIntoHub: () -> ()
local planetNameInput: TextBox
local activeMenuTab = "Play"

local function switchMainMenuTab(tabName: string)
	activeMenuTab = tabName
	for k, frame in pairs(menuPages) do
		frame.Visible = (k == tabName)
	end
	for k, btn in pairs(menuTabButtons) do
		if k == tabName then
			btn.BackgroundColor3 = Color3.fromRGB(45, 165, 245)
		else
			btn.BackgroundColor3 = Color3.fromRGB(32, 42, 74)
		end
	end
end

for _, tabDef in ipairs({
	{ Id = "Play", Label = "▶️ PLAY" },
	{ Id = "Customize", Label = "🎨 CUSTOMIZE" },
	{ Id = "Settings", Label = "⚙️ SETTINGS" },
}) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(32, 42, 74)
	b.Text = tabDef.Label
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.Parent = menuNavBtnsContainer
	addCorner(b, 10)
	addBorderStroke(b, Color3.fromRGB(255, 255, 255), 1.5)
	addTextStroke(b, 1.5)
	b.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.28, 0.08)
		if tabDef.Id == "Play" and activeMenuTab == "Play" and launchIntoHub then
			launchIntoHub()
		else
			switchMainMenuTab(tabDef.Id)
		end
	end)
	menuTabButtons[tabDef.Id] = b
end

-- CENTRAL 2D MENU INTERACTIVE 3D VIEWPORT PREVIEW (Shared by Play & Customize tabs!)
local centerPreviewCard = Instance.new("Frame")
centerPreviewCard.Size = UDim2.new(1, -740, 1, -158)
centerPreviewCard.AnchorPoint = Vector2.new(0.5, 0)
centerPreviewCard.Position = UDim2.new(0.5, 10, 0, 80)
centerPreviewCard.BackgroundColor3 = Color3.fromRGB(14, 18, 32)
centerPreviewCard.Parent = genesisContainer
addCorner(centerPreviewCard, 18)
addBorderStroke(centerPreviewCard, Color3.fromRGB(70, 145, 225), 2)

local mainViewport = Instance.new("ViewportFrame")
mainViewport.Name = "Creator2DViewport"
mainViewport.Size = UDim2.new(1, -12, 1, -46)
mainViewport.Position = UDim2.new(0, 6, 0, 6)
mainViewport.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
mainViewport.Ambient = Color3.fromRGB(165, 172, 188)
mainViewport.LightColor = Color3.fromRGB(240, 244, 252)
mainViewport.LightDirection = Vector3.new(-1, -0.8, -1)
mainViewport.Parent = centerPreviewCard
addCorner(mainViewport, 14)

local mainViewportWorld = Instance.new("WorldModel")
mainViewportWorld.Parent = mainViewport

local mainViewportCam = Instance.new("Camera")
mainViewportCam.Parent = mainViewport
mainViewport.CurrentCamera = mainViewportCam

local vpHintLabel = Instance.new("TextLabel")
vpHintLabel.Size = UDim2.new(1, -16, 0, 30)
vpHintLabel.Position = UDim2.new(0, 8, 1, -36)
vpHintLabel.BackgroundTransparency = 1
vpHintLabel.Text = "🖱️ Right-Click Drag to Rotate 3D Preview • Scroll Wheel to Zoom"
vpHintLabel.TextColor3 = Color3.fromRGB(185, 205, 235)
vpHintLabel.Font = Enum.Font.GothamBold
vpHintLabel.TextSize = 12
vpHintLabel.Parent = centerPreviewCard

local vpPlanetModel: Model? = nil
local vpSpeciesModel: Model? = nil

local function rebuild2DMenuPreviewModels()
	mainViewportWorld:ClearAllChildren()

	local pModel = PlanetGenerator.BuildPlanetModel(
		localPlayer.DisplayName,
		currentState.Look,
		currentState.SpeciesId,
		currentState.ActiveEvolutionId,
		1.0,
		true
	)
	pModel:PivotTo(CFrame.new(-7, 2, 0))
	pModel.Parent = mainViewportWorld
	vpPlanetModel = pModel

	local sModel = PlanetGenerator.BuildSpeciesCharacterModel(currentState.SpeciesId, 2.2)
	sModel:PivotTo(CFrame.new(18, -3, 4))
	sModel.Parent = mainViewportWorld
	vpSpeciesModel = sModel
end

local function refreshShowroomAndActivePlanetModels()
	hideServerDuplicateOfMyPlanet()
	rebuild2DMenuPreviewModels()

	if not currentState.HasCompletedSetup then
		if localActivePlanetModel then
			localActivePlanetModel:Destroy()
			localActivePlanetModel = nil
			lastBuiltPlanetSignature = ""
		end
	else
		local sig = computePlanetSignature()
		if not localActivePlanetModel or not localActivePlanetModel.Parent or sig ~= lastBuiltPlanetSignature then
			lastBuiltPlanetSignature = sig
			if localActivePlanetModel then
				localActivePlanetModel:Destroy()
			end
			local newActive = PlanetGenerator.BuildPlanetModel(
				localPlayer.DisplayName,
				currentState.Look,
				currentState.SpeciesId,
				currentState.ActiveEvolutionId,
				getLocalPlanetScaleFactor(),
				false
			)
			newActive:PivotTo(CFrame.new(localPlanetPos) * CFrame.Angles(0, spinAngle, math.rad(8)))
			newActive.Parent = activeClientPlanetFolder
			localActivePlanetModel = newActive
		end
	end
end

-- Create the 3 Menu Pages inside `genesisContainer`
local playMenuPage = Instance.new("Frame")
playMenuPage.Name = "PlayMenuPage"
playMenuPage.Size = UDim2.fromScale(1, 1)
playMenuPage.BackgroundTransparency = 1
playMenuPage.Parent = genesisContainer
menuPages["Play"] = playMenuPage

local customizeMenuPage = Instance.new("Frame")
customizeMenuPage.Name = "CustomizeMenuPage"
customizeMenuPage.Size = UDim2.fromScale(1, 1)
customizeMenuPage.BackgroundTransparency = 1
customizeMenuPage.Visible = false
customizeMenuPage.Parent = genesisContainer
menuPages["Customize"] = customizeMenuPage

local settingsMenuPage = Instance.new("Frame")
settingsMenuPage.Name = "SettingsMenuPage"
settingsMenuPage.Size = UDim2.fromScale(1, 1)
settingsMenuPage.BackgroundTransparency = 1
settingsMenuPage.Visible = false
settingsMenuPage.Parent = genesisContainer
menuPages["Settings"] = settingsMenuPage

launchIntoHub = function()
	playSFX(sfxLaunch, 0.35)
	if planetNameInput and #planetNameInput.Text > 0 then
		currentState.Look.PlanetName = planetNameInput.Text
	end
	currentState.HasCompletedSetup = true
	localPlanetPos = HUB_SPAWN_POS
	localVelocity = Vector3.zero
	genesisContainer.Visible = false
	FinalizeSetupEvent:FireServer(currentState.Look.PlanetName)
	refreshShowroomAndActivePlanetModels()
	if refreshUI then
		refreshUI()
	end
end

-- ============================================================================
-- 5A. [▶️ PLAY] PAGE (Left Summary Card & Right Quick Actions)
-- ============================================================================
local playLeftCard = Instance.new("Frame")
playLeftCard.Size = UDim2.new(0, 345, 1, -158)
playLeftCard.Position = UDim2.new(0, 16, 0, 80)
playLeftCard.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
playLeftCard.Parent = playMenuPage
addCorner(playLeftCard, 18)
addBorderStroke(playLeftCard, Color3.fromRGB(80, 165, 245), 2)

local playLeftHdr = Instance.new("TextLabel")
playLeftHdr.Size = UDim2.new(1, -24, 0, 34)
playLeftHdr.Position = UDim2.new(0, 12, 0, 12)
playLeftHdr.BackgroundTransparency = 1
playLeftHdr.Text = "🪐 YOUR PLANET OVERVIEW"
playLeftHdr.TextColor3 = Color3.fromRGB(255, 230, 105)
playLeftHdr.Font = Enum.Font.FredokaOne
playLeftHdr.TextSize = 18
playLeftHdr.TextXAlignment = Enum.TextXAlignment.Left
playLeftHdr.Parent = playLeftCard
addTextStroke(playLeftHdr, 1.8)

local playSummaryLabel = Instance.new("TextLabel")
playSummaryLabel.Size = UDim2.new(1, -28, 1, -170)
playSummaryLabel.Position = UDim2.new(0, 14, 0, 52)
playSummaryLabel.BackgroundTransparency = 1
playSummaryLabel.Text = ""
playSummaryLabel.TextColor3 = Color3.fromRGB(220, 230, 248)
playSummaryLabel.Font = Enum.Font.GothamBold
playSummaryLabel.TextSize = 13
playSummaryLabel.TextWrapped = true
playSummaryLabel.TextXAlignment = Enum.TextXAlignment.Left
playSummaryLabel.TextYAlignment = Enum.TextYAlignment.Top
playSummaryLabel.Parent = playLeftCard

local openCustomizeFromPlayBtn = Instance.new("TextButton")
openCustomizeFromPlayBtn.Size = UDim2.new(1, -28, 0, 44)
openCustomizeFromPlayBtn.Position = UDim2.new(0, 14, 1, -108)
openCustomizeFromPlayBtn.BackgroundColor3 = Color3.fromRGB(45, 145, 235)
openCustomizeFromPlayBtn.Text = "🎨 CUSTOMIZE PLANET & SPECIES"
openCustomizeFromPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openCustomizeFromPlayBtn.Font = Enum.Font.FredokaOne
openCustomizeFromPlayBtn.TextSize = 15
openCustomizeFromPlayBtn.Parent = playLeftCard
addCorner(openCustomizeFromPlayBtn, 12)
addBorderStroke(openCustomizeFromPlayBtn, Color3.fromRGB(255, 255, 255), 1.8)
addTextStroke(openCustomizeFromPlayBtn, 1.8)
openCustomizeFromPlayBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.28)
	switchMainMenuTab("Customize")
end)

local randomizePlanetBtn = Instance.new("TextButton")
randomizePlanetBtn.Size = UDim2.new(1, -28, 0, 42)
randomizePlanetBtn.Position = UDim2.new(0, 14, 1, -54)
randomizePlanetBtn.BackgroundColor3 = Color3.fromRGB(135, 75, 215)
randomizePlanetBtn.Text = "🎲 RANDOMIZE PLANET LOOK"
randomizePlanetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
randomizePlanetBtn.Font = Enum.Font.FredokaOne
randomizePlanetBtn.TextSize = 14
randomizePlanetBtn.Parent = playLeftCard
addCorner(randomizePlanetBtn, 12)
addBorderStroke(randomizePlanetBtn, Color3.fromRGB(255, 255, 255), 1.5)
addTextStroke(randomizePlanetBtn, 1.6)
randomizePlanetBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.28, 0.15)
	local bOrder = PlanetConfig.PlanetTypeOrder
	local pickBiome = bOrder[math.random(1, #bOrder)]
	local pt = PlanetConfig.PlanetTypes[pickBiome]
	local covList = PlanetConfig.LandCoverages
	local pickCov = covList[math.random(1, #covList)].Id
	local featList = PlanetConfig.SurfaceFeatures
	local pickFeat = featList[math.random(1, #featList)].Id
	local ringList = PlanetConfig.RingStyles
	local pickRing = ringList[math.random(1, #ringList)].Id
	local moonList = PlanetConfig.MoonStyles
	local pickMoon = moonList[math.random(1, #moonList)].Id

	currentState.Look.Biome = pickBiome
	currentState.Look.LandCoverage = pickCov
	currentState.Look.SurfaceFeature = pickFeat
	currentState.Look.RingStyle = pickRing
	currentState.Look.MoonStyle = pickMoon
	currentState.Look.WaterColor = table.clone(pt.DefaultColors.WaterColor)
	currentState.Look.LandColor = table.clone(pt.DefaultColors.LandColor)
	currentState.Look.TreeColor = table.clone(pt.DefaultColors.TreeColor)
	currentState.Look.RockColor = table.clone(pt.DefaultColors.RockColor)
	currentState.Look.AtmosphereColor = table.clone(pt.DefaultColors.AtmosphereColor)
	currentState.Look.CloudColor = table.clone(pt.DefaultColors.CloudColor)
	currentState.Look.RingColor = table.clone(pt.DefaultColors.RingColor)
	currentState.Look.WaterMaterial = pt.DefaultMaterials.WaterMaterial
	currentState.Look.LandMaterial = pt.DefaultMaterials.LandMaterial
	currentState.Look.RockMaterial = pt.DefaultMaterials.RockMaterial

	UpdateCustomizationEvent:FireServer({
		Biome = pickBiome,
		LandCoverage = pickCov,
		SurfaceFeature = pickFeat,
		RingStyle = pickRing,
		MoonStyle = pickMoon,
	})
	if refreshUI then
		refreshUI()
	end
end)

local playRightCard = Instance.new("Frame")
playRightCard.Size = UDim2.new(0, 325, 1, -158)
playRightCard.Position = UDim2.new(1, -341, 0, 80)
playRightCard.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
playRightCard.Parent = playMenuPage
addCorner(playRightCard, 18)
addBorderStroke(playRightCard, Color3.fromRGB(75, 225, 135), 2)

local playRightHdr = Instance.new("TextLabel")
playRightHdr.Size = UDim2.new(1, -24, 0, 34)
playRightHdr.Position = UDim2.new(0, 12, 0, 12)
playRightHdr.BackgroundTransparency = 1
playRightHdr.Text = "🚀 HOW TO PLAY"
playRightHdr.TextColor3 = Color3.fromRGB(95, 245, 155)
playRightHdr.Font = Enum.Font.FredokaOne
playRightHdr.TextSize = 18
playRightHdr.TextXAlignment = Enum.TextXAlignment.Left
playRightHdr.Parent = playRightCard
addTextStroke(playRightHdr, 1.8)

local playGuideLabel = Instance.new("TextLabel")
playGuideLabel.Size = UDim2.new(1, -28, 1, -120)
playGuideLabel.Position = UDim2.new(0, 14, 0, 52)
playGuideLabel.BackgroundTransparency = 1
playGuideLabel.Text = "• 1. Customize your Planet's Class, Continent Size, Colors, Realistic Materials, Rings, Moons & Founding Species.\n\n• 2. Click PLAY below to spawn inside the massive open-space Galactic Nexus Hub!\n\n• 3. Fly around in 3D space (WASD + Space/Ctrl + Shift Boost) to harvest procedural Asteroids, Spore-Comets, Pulsars, Satellites & Relic Chests.\n\n• 4. Use the 5 Colossal Hub Machines (⚡ Reactor, ⚒️ Refinery, 🌿 Bio-Vat, 🔭 Tech Lab, 🌀 Warp Gate) for exponential progression!"
playGuideLabel.TextColor3 = Color3.fromRGB(215, 226, 245)
playGuideLabel.Font = Enum.Font.GothamMedium
playGuideLabel.TextSize = 13
playGuideLabel.TextWrapped = true
playGuideLabel.TextXAlignment = Enum.TextXAlignment.Left
playGuideLabel.TextYAlignment = Enum.TextYAlignment.Top
playGuideLabel.Parent = playRightCard

local openSettingsFromPlayBtn = Instance.new("TextButton")
openSettingsFromPlayBtn.Size = UDim2.new(1, -28, 0, 42)
openSettingsFromPlayBtn.Position = UDim2.new(0, 14, 1, -54)
openSettingsFromPlayBtn.BackgroundColor3 = Color3.fromRGB(52, 68, 108)
openSettingsFromPlayBtn.Text = "⚙️ AUDIO & GRAPHICS SETTINGS"
openSettingsFromPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openSettingsFromPlayBtn.Font = Enum.Font.FredokaOne
openSettingsFromPlayBtn.TextSize = 14
openSettingsFromPlayBtn.Parent = playRightCard
addCorner(openSettingsFromPlayBtn, 12)
addBorderStroke(openSettingsFromPlayBtn, Color3.fromRGB(255, 255, 255), 1.5)
addTextStroke(openSettingsFromPlayBtn, 1.5)
openSettingsFromPlayBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.28)
	switchMainMenuTab("Settings")
end)

-- ============================================================================
-- 5B. [🎨 CUSTOMIZE] PAGE (4-Tab Planet Customizer + Species Selector)
-- ============================================================================
local leftCustPanel = Instance.new("Frame")
leftCustPanel.Size = UDim2.new(0, 355, 1, -158)
leftCustPanel.Position = UDim2.new(0, 14, 0, 80)
leftCustPanel.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
leftCustPanel.Parent = customizeMenuPage
addCorner(leftCustPanel, 18)
addBorderStroke(leftCustPanel, Color3.fromRGB(70, 175, 245), 2.5)

local nameRow = Instance.new("Frame")
nameRow.Size = UDim2.new(1, -16, 0, 36)
nameRow.Position = UDim2.new(0, 8, 0, 8)
nameRow.BackgroundColor3 = Color3.fromRGB(28, 38, 68)
nameRow.Parent = leftCustPanel
addCorner(nameRow, 10)
addBorderStroke(nameRow, Color3.fromRGB(85, 165, 235), 1.5)

local nameTag = Instance.new("TextLabel")
nameTag.Size = UDim2.new(0, 72, 1, 0)
nameTag.Position = UDim2.new(0, 8, 0, 0)
nameTag.BackgroundTransparency = 1
nameTag.Text = "NAME:"
nameTag.TextColor3 = Color3.fromRGB(255, 230, 105)
nameTag.Font = Enum.Font.FredokaOne
nameTag.TextSize = 13
nameTag.TextXAlignment = Enum.TextXAlignment.Left
nameTag.Parent = nameRow
addTextStroke(nameTag, 1.5)

planetNameInput = Instance.new("TextBox")
planetNameInput.Size = UDim2.new(1, -86, 0, 26)
planetNameInput.Position = UDim2.new(0, 80, 0.5, -13)
planetNameInput.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
planetNameInput.Text = localPlayer.DisplayName .. " Prime"
planetNameInput.PlaceholderText = "Enter Planet Name..."
planetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
planetNameInput.Font = Enum.Font.FredokaOne
planetNameInput.TextSize = 14
planetNameInput.Parent = nameRow
addCorner(planetNameInput, 6)

planetNameInput.FocusLost:Connect(function()
	if not currentState.HasCompletedSetup then
		currentState.Look.PlanetName = planetNameInput.Text
		refreshShowroomAndActivePlanetModels()
		UpdateCustomizationEvent:FireServer({ PlanetName = planetNameInput.Text })
	end
end)

local subTabBar = Instance.new("Frame")
subTabBar.Size = UDim2.new(1, -16, 0, 34)
subTabBar.Position = UDim2.new(0, 8, 0, 50)
subTabBar.BackgroundTransparency = 1
subTabBar.Parent = leftCustPanel

local subTabLayout = Instance.new("UIGridLayout")
subTabLayout.CellSize = UDim2.new(0.24, 0, 1, 0)
subTabLayout.CellPadding = UDim2.new(0.012, 0, 0, 0)
subTabLayout.Parent = subTabBar

local creatorSubPages: { [string]: ScrollingFrame } = {}
local creatorSubButtons: { [string]: TextButton } = {}

local function makeCreatorSubPage(key: string): ScrollingFrame
	local sf = Instance.new("ScrollingFrame")
	sf.Name = key .. "SubPage"
	sf.Size = UDim2.new(1, -14, 1, -94)
	sf.Position = UDim2.new(0, 7, 0, 88)
	sf.BackgroundTransparency = 1
	sf.ScrollBarThickness = 6
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.Visible = false
	sf.Parent = leftCustPanel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = sf

	creatorSubPages[key] = sf
	return sf
end

local pageTypeShape = makeCreatorSubPage("TypeShape")
local pageColors = makeCreatorSubPage("Colors")
local pageTextures = makeCreatorSubPage("Textures")
local pageAtmosphereOrbit = makeCreatorSubPage("Orbit")

local subTabDefs = {
	{ Key = "TypeShape", Text = "🪐 LAND" },
	{ Key = "Colors", Text = "🎨 COLORS" },
	{ Key = "Textures", Text = "🧱 TEXTURE" },
	{ Key = "Orbit", Text = "✨ ORBIT" },
}

local function switchCreatorSubTab(activeKey: string)
	for k, page in pairs(creatorSubPages) do
		page.Visible = (k == activeKey)
	end
	for k, btn in pairs(creatorSubButtons) do
		if k == activeKey then
			btn.BackgroundColor3 = Color3.fromRGB(45, 165, 245)
		else
			btn.BackgroundColor3 = Color3.fromRGB(36, 48, 86)
		end
	end
end

for _, st in ipairs(subTabDefs) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(36, 48, 86)
	b.Text = st.Text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 11
	b.Parent = subTabBar
	addCorner(b, 8)
	addBorderStroke(b, Color3.fromRGB(255, 255, 255), 1.3)
	addTextStroke(b, 1.3)
	b.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.28, 0.08)
		switchCreatorSubTab(st.Key)
	end)
	creatorSubButtons[st.Key] = b
end
switchCreatorSubTab("TypeShape")

local lookOptionButtons: { [string]: { [string]: { Button: TextButton, Stroke: UIStroke } } } = {}

local function add3DGridSection(parentPage: ScrollingFrame, titleText: string, lookKey: string, items: { { Id: string, Name: string } })
	lookOptionButtons[lookKey] = {}
	local sec = Instance.new("Frame")
	local rows = math.ceil(#items / 2)
	sec.Size = UDim2.new(1, -8, 0, 32 + rows * 74)
	sec.BackgroundColor3 = Color3.fromRGB(26, 36, 66)
	sec.Parent = parentPage
	addCorner(sec, 12)
	addBorderStroke(sec, Color3.fromRGB(75, 145, 225), 1.5)

	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(1, -16, 0, 22)
	hdr.Position = UDim2.new(0, 10, 0, 4)
	hdr.BackgroundTransparency = 1
	hdr.Text = titleText
	hdr.TextColor3 = Color3.fromRGB(255, 230, 105)
	hdr.Font = Enum.Font.FredokaOne
	hdr.TextSize = 13
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.Parent = sec
	addTextStroke(hdr, 1.5)

	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, -14, 1, -30)
	gridFrame.Position = UDim2.new(0, 7, 0, 28)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = sec

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.48, 0, 0, 66)
	grid.CellPadding = UDim2.new(0.03, 0, 0, 6)
	grid.Parent = gridFrame

	for _, item in ipairs(items) do
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
		b.Text = ""
		b.Parent = gridFrame
		addCorner(b, 10)
		local bStroke = addBorderStroke(b, Color3.fromRGB(255, 255, 255), 1.5)

		local previewModel, camOffset = buildCustomizationPreviewModel(lookKey, item.Id)
		create3DViewportThumbnail(b, UDim2.new(0, 52, 0, 52), UDim2.new(0, 6, 0.5, -26), previewModel, camOffset)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -64, 1, -8)
		lbl.Position = UDim2.new(0, 62, 0, 4)
		lbl.BackgroundTransparency = 1
		lbl.Text = item.Name
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 12
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = b
		addTextStroke(lbl, 1.4)

		b.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.28, 0.1)
			;(currentState.Look :: any)[lookKey] = item.Id
			refreshShowroomAndActivePlanetModels()
			local payload: { [string]: any } = {}
			payload[lookKey] = item.Id
			UpdateCustomizationEvent:FireServer(payload)
			if refreshUI then
				refreshUI()
			end
		end)
		lookOptionButtons[lookKey][item.Id] = { Button = b, Stroke = bStroke }
	end
end

-- SUB-PAGE 1: CONTINENT SIZE, PLANET TYPES & CORE SHAPES
do
	add3DGridSection(pageTypeShape, "1. CONTINENT & LANDMASS SIZE:", "LandCoverage", PlanetConfig.LandCoverages)
	add3DGridSection(pageTypeShape, "2. PLANETARY GLOBE GEOMETRY:", "CoreShape", PlanetConfig.CoreShapes)

	lookOptionButtons["Biome"] = {}
	local ptHeader = Instance.new("TextLabel")
	ptHeader.Size = UDim2.new(1, -8, 0, 22)
	ptHeader.BackgroundTransparency = 1
	ptHeader.Text = "3. CHOOSE PLANET CLASS (PROS & CONS):"
	ptHeader.TextColor3 = Color3.fromRGB(255, 230, 105)
	ptHeader.Font = Enum.Font.FredokaOne
	ptHeader.TextSize = 14
	ptHeader.TextXAlignment = Enum.TextXAlignment.Left
	ptHeader.Parent = pageTypeShape
	addTextStroke(ptHeader, 1.6)

	for _, ptId in ipairs(PlanetConfig.PlanetTypeOrder) do
		local pt = PlanetConfig.PlanetTypes[ptId]
		local card = Instance.new("TextButton")
		card.Size = UDim2.new(1, -8, 0, 104)
		card.BackgroundColor3 = Color3.fromRGB(32, 44, 80)
		card.Text = ""
		card.Parent = pageTypeShape
		addCorner(card, 12)
		local cStroke = addBorderStroke(card, Color3.fromRGB(95, 175, 245), 2)

		local pMod, camOff = buildCustomizationPreviewModel("Biome", pt.Id)
		create3DViewportThumbnail(card, UDim2.new(0, 76, 0, 76), UDim2.new(0, 8, 0.5, -38), pMod, camOff)

		local tLbl = Instance.new("TextLabel")
		tLbl.Size = UDim2.new(1, -94, 0, 20)
		tLbl.Position = UDim2.new(0, 90, 0, 5)
		tLbl.BackgroundTransparency = 1
		tLbl.Text = pt.Name .. " • " .. pt.Tagline
		tLbl.TextColor3 = Color3.fromRGB(255, 235, 110)
		tLbl.Font = Enum.Font.FredokaOne
		tLbl.TextSize = 13
		tLbl.TextXAlignment = Enum.TextXAlignment.Left
		tLbl.Parent = card
		addTextStroke(tLbl, 1.5)

		local prosLbl = Instance.new("TextLabel")
		prosLbl.Size = UDim2.new(1, -94, 0, 34)
		prosLbl.Position = UDim2.new(0, 90, 0, 26)
		prosLbl.BackgroundTransparency = 1
		prosLbl.Text = "✅ " .. table.concat(pt.Advantages, " | ")
		prosLbl.TextColor3 = Color3.fromRGB(95, 245, 145)
		prosLbl.Font = Enum.Font.GothamBold
		prosLbl.TextSize = 10
		prosLbl.TextWrapped = true
		prosLbl.TextXAlignment = Enum.TextXAlignment.Left
		prosLbl.Parent = card

		local consLbl = Instance.new("TextLabel")
		consLbl.Size = UDim2.new(1, -94, 0, 28)
		consLbl.Position = UDim2.new(0, 90, 0, 62)
		consLbl.BackgroundTransparency = 1
		consLbl.Text = "⚠️ " .. table.concat(pt.Disadvantages, " | ")
		consLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
		consLbl.Font = Enum.Font.GothamBold
		consLbl.TextSize = 10
		consLbl.TextWrapped = true
		consLbl.TextXAlignment = Enum.TextXAlignment.Left
		consLbl.Parent = card

		card.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.28, 0.1)
			currentState.Look.Biome = pt.Id
			currentState.Look.WaterColor = table.clone(pt.DefaultColors.WaterColor)
			currentState.Look.LandColor = table.clone(pt.DefaultColors.LandColor)
			currentState.Look.TreeColor = table.clone(pt.DefaultColors.TreeColor)
			currentState.Look.RockColor = table.clone(pt.DefaultColors.RockColor)
			currentState.Look.AtmosphereColor = table.clone(pt.DefaultColors.AtmosphereColor)
			currentState.Look.CloudColor = table.clone(pt.DefaultColors.CloudColor)
			currentState.Look.RingColor = table.clone(pt.DefaultColors.RingColor)
			currentState.Look.WaterMaterial = pt.DefaultMaterials.WaterMaterial
			currentState.Look.LandMaterial = pt.DefaultMaterials.LandMaterial
			currentState.Look.RockMaterial = pt.DefaultMaterials.RockMaterial
			refreshShowroomAndActivePlanetModels()
			UpdateCustomizationEvent:FireServer({ Biome = pt.Id })
			if refreshUI then
				refreshUI()
			end
		end)
		lookOptionButtons["Biome"][pt.Id] = { Button = card, Stroke = cStroke }
	end
end

-- SUB-PAGE 2: CUSTOMIZE ALL COLORS
local activeColorChannel = "LandColor"
local channelButtons: { [string]: TextButton } = {}
do
	local chSec = Instance.new("Frame")
	chSec.Size = UDim2.new(1, -8, 0, 165)
	chSec.BackgroundColor3 = Color3.fromRGB(26, 36, 66)
	chSec.Parent = pageColors
	addCorner(chSec, 12)
	addBorderStroke(chSec, Color3.fromRGB(75, 145, 225), 1.5)

	local chHdr = Instance.new("TextLabel")
	chHdr.Size = UDim2.new(1, -16, 0, 22)
	chHdr.Position = UDim2.new(0, 10, 0, 4)
	chHdr.BackgroundTransparency = 1
	chHdr.Text = "1. SELECT PART OF PLANET TO COLOR:"
	chHdr.TextColor3 = Color3.fromRGB(255, 230, 105)
	chHdr.Font = Enum.Font.FredokaOne
	chHdr.TextSize = 13
	chHdr.TextXAlignment = Enum.TextXAlignment.Left
	chHdr.Parent = chSec
	addTextStroke(chHdr, 1.5)

	local chGridFrame = Instance.new("Frame")
	chGridFrame.Size = UDim2.new(1, -16, 1, -32)
	chGridFrame.Position = UDim2.new(0, 8, 0, 28)
	chGridFrame.BackgroundTransparency = 1
	chGridFrame.Parent = chSec

	local chGrid = Instance.new("UIGridLayout")
	chGrid.CellSize = UDim2.new(0.48, 0, 0, 28)
	chGrid.CellPadding = UDim2.new(0.03, 0, 0, 6)
	chGrid.Parent = chGridFrame

	local channels = {
		{ Key = "LandColor", Label = "🏝️ Land / Continents" },
		{ Key = "WaterColor", Label = "🌊 Water / Ocean" },
		{ Key = "TreeColor", Label = "🌲 Trees / Flora" },
		{ Key = "RockColor", Label = "🪨 Rocks / Mountains" },
		{ Key = "CloudColor", Label = "🌥️ Clouds & Poles" },
		{ Key = "RingColor", Label = "🪐 Orbital Rings" },
		{ Key = "AtmosphereColor", Label = "✨ Flight Wake Tint" },
	}

	local function updateChannelHighlights()
		for k, b in pairs(channelButtons) do
			if k == activeColorChannel then
				b.BackgroundColor3 = Color3.fromRGB(45, 195, 115)
			else
				b.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
			end
		end
	end

	for _, ch in ipairs(channels) do
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
		b.Text = ch.Label
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 12
		b.Parent = chGridFrame
		addCorner(b, 8)
		addBorderStroke(b, Color3.fromRGB(255, 255, 255), 1.4)
		addTextStroke(b, 1.4)
		b.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.28, 0.08)
			activeColorChannel = ch.Key
			updateChannelHighlights()
		end)
		channelButtons[ch.Key] = b
	end
	updateChannelHighlights()

	local palSec = Instance.new("Frame")
	palSec.Size = UDim2.new(1, -8, 0, 275)
	palSec.BackgroundColor3 = Color3.fromRGB(26, 36, 66)
	palSec.Parent = pageColors
	addCorner(palSec, 12)
	addBorderStroke(palSec, Color3.fromRGB(75, 145, 225), 1.5)

	local palHdr = Instance.new("TextLabel")
	palHdr.Size = UDim2.new(1, -16, 0, 22)
	palHdr.Position = UDim2.new(0, 10, 0, 4)
	palHdr.BackgroundTransparency = 1
	palHdr.Text = "2. PICK A COLOR FOR SELECTED PART:"
	palHdr.TextColor3 = Color3.fromRGB(255, 230, 105)
	palHdr.Font = Enum.Font.FredokaOne
	palHdr.TextSize = 13
	palHdr.TextXAlignment = Enum.TextXAlignment.Left
	palHdr.Parent = palSec
	addTextStroke(palHdr, 1.5)

	local swatchContainer = Instance.new("Frame")
	swatchContainer.Size = UDim2.new(1, -16, 1, -34)
	swatchContainer.Position = UDim2.new(0, 8, 0, 28)
	swatchContainer.BackgroundTransparency = 1
	swatchContainer.Parent = palSec

	local sGrid = Instance.new("UIGridLayout")
	sGrid.CellSize = UDim2.new(0, 74, 0, 34)
	sGrid.CellPadding = UDim2.new(0, 8, 0, 6)
	sGrid.Parent = swatchContainer

	for _, swatch in ipairs(PlanetConfig.ColorPalette) do
		local sb = Instance.new("TextButton")
		sb.BackgroundColor3 = Color3.fromRGB(swatch.RGB[1], swatch.RGB[2], swatch.RGB[3])
		sb.Text = swatch.Name
		sb.TextColor3 = Color3.fromRGB(255, 255, 255)
		sb.Font = Enum.Font.FredokaOne
		sb.TextSize = 10
		sb.TextWrapped = true
		sb.Parent = swatchContainer
		addCorner(sb, 8)
		addBorderStroke(sb, Color3.fromRGB(255, 255, 255), 1.5)
		addTextStroke(sb, 1.5)

		sb.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.28, 0.12)
			local rgbCopy = { swatch.RGB[1], swatch.RGB[2], swatch.RGB[3] }
			;(currentState.Look :: any)[activeColorChannel] = rgbCopy
			refreshShowroomAndActivePlanetModels()
			local payload: { [string]: any } = {}
			payload[activeColorChannel] = rgbCopy
			UpdateCustomizationEvent:FireServer(payload)
		end)
	end
end

-- SUB-PAGE 3: REALISTIC NATURAL TEXTURES (MATERIALS) & SURFACE FLORA
do
	local function addMaterialPickerSection(titleText: string, lookKey: string)
		lookOptionButtons[lookKey] = {}
		local sec = Instance.new("Frame")
		local rows = math.ceil(#PlanetConfig.CustomizableMaterials / 3)
		sec.Size = UDim2.new(1, -8, 0, 34 + rows * 34)
		sec.BackgroundColor3 = Color3.fromRGB(26, 36, 66)
		sec.Parent = pageTextures
		addCorner(sec, 12)
		addBorderStroke(sec, Color3.fromRGB(75, 145, 225), 1.5)

		local hdr = Instance.new("TextLabel")
		hdr.Size = UDim2.new(1, -16, 0, 22)
		hdr.Position = UDim2.new(0, 10, 0, 4)
		hdr.BackgroundTransparency = 1
		hdr.Text = titleText
		hdr.TextColor3 = Color3.fromRGB(255, 230, 105)
		hdr.Font = Enum.Font.FredokaOne
		hdr.TextSize = 13
		hdr.TextXAlignment = Enum.TextXAlignment.Left
		hdr.Parent = sec
		addTextStroke(hdr, 1.5)

		local gf = Instance.new("Frame")
		gf.Size = UDim2.new(1, -16, 1, -30)
		gf.Position = UDim2.new(0, 8, 0, 28)
		gf.BackgroundTransparency = 1
		gf.Parent = sec

		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.31, 0, 0, 28)
		gl.CellPadding = UDim2.new(0.02, 0, 0, 5)
		gl.Parent = gf

		for _, matInfo in ipairs(PlanetConfig.CustomizableMaterials) do
			local mb = Instance.new("TextButton")
			mb.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
			mb.Text = matInfo.Name
			mb.TextColor3 = Color3.fromRGB(255, 255, 255)
			mb.Font = Enum.Font.FredokaOne
			mb.TextSize = 10
			mb.TextWrapped = true
			mb.Parent = gf
			addCorner(mb, 7)
			local mStroke = addBorderStroke(mb, Color3.fromRGB(255, 255, 255), 1.2)
			addTextStroke(mb, 1.3)

			mb.MouseButton1Click:Connect(function()
				playSFX(sfxClick, 0.28, 0.1)
				;(currentState.Look :: any)[lookKey] = matInfo.Id
				refreshShowroomAndActivePlanetModels()
				local payload: { [string]: any } = {}
				payload[lookKey] = matInfo.Id
				UpdateCustomizationEvent:FireServer(payload)
				if refreshUI then
					refreshUI()
				end
			end)
			lookOptionButtons[lookKey][matInfo.Id] = { Button = mb, Stroke = mStroke }
		end
	end

	add3DGridSection(pageTextures, "1. SURFACE ECOSYSTEM & LANDMARKS:", "SurfaceFeature", PlanetConfig.SurfaceFeatures)
	addMaterialPickerSection("2. CONTINENT / LAND TEXTURE:", "LandMaterial")
	addMaterialPickerSection("3. OCEAN / CORE TEXTURE:", "WaterMaterial")
	addMaterialPickerSection("4. MOUNTAIN / ROCK TEXTURE:", "RockMaterial")
end

-- SUB-PAGE 4: CLOUDS, RINGS, MOONS & AXIAL ROTATION SPEED
do
	add3DGridSection(pageAtmosphereOrbit, "1. CLOUD & EXOSPHERE LAYER:", "Atmosphere", PlanetConfig.Atmospheres)
	add3DGridSection(pageAtmosphereOrbit, "2. ORBITAL RING SYSTEM:", "RingStyle", PlanetConfig.RingStyles)
	add3DGridSection(pageAtmosphereOrbit, "3. ORBITING MOON SYSTEM:", "MoonStyle", PlanetConfig.MoonStyles)

	lookOptionButtons["RotationSpeedId"] = {}
	local spinSec = Instance.new("Frame")
	spinSec.Size = UDim2.new(1, -8, 0, 140)
	spinSec.BackgroundColor3 = Color3.fromRGB(26, 36, 66)
	spinSec.Parent = pageAtmosphereOrbit
	addCorner(spinSec, 12)
	addBorderStroke(spinSec, Color3.fromRGB(75, 145, 225), 1.5)

	local spinHdr = Instance.new("TextLabel")
	spinHdr.Size = UDim2.new(1, -16, 0, 22)
	spinHdr.Position = UDim2.new(0, 10, 0, 4)
	spinHdr.BackgroundTransparency = 1
	spinHdr.Text = "4. PLANET AXIAL ROTATION SPEED:"
	spinHdr.TextColor3 = Color3.fromRGB(255, 230, 105)
	spinHdr.Font = Enum.Font.FredokaOne
	spinHdr.TextSize = 13
	spinHdr.TextXAlignment = Enum.TextXAlignment.Left
	spinHdr.Parent = spinSec
	addTextStroke(spinHdr, 1.5)

	local spinGF = Instance.new("Frame")
	spinGF.Size = UDim2.new(1, -16, 1, -30)
	spinGF.Position = UDim2.new(0, 8, 0, 28)
	spinGF.BackgroundTransparency = 1
	spinGF.Parent = spinSec

	local spinGL = Instance.new("UIGridLayout")
	spinGL.CellSize = UDim2.new(0.48, 0, 0, 28)
	spinGL.CellPadding = UDim2.new(0.03, 0, 0, 6)
	spinGL.Parent = spinGF

	for _, rInfo in ipairs(PlanetConfig.RotationSpeeds) do
		local rb = Instance.new("TextButton")
		rb.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
		rb.Text = "🔄 " .. rInfo.Name
		rb.TextColor3 = Color3.fromRGB(255, 255, 255)
		rb.Font = Enum.Font.FredokaOne
		rb.TextSize = 11
		rb.Parent = spinGF
		addCorner(rb, 8)
		local rStroke = addBorderStroke(rb, Color3.fromRGB(255, 255, 255), 1.4)
		addTextStroke(rb, 1.3)

		rb.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.28, 0.1)
			currentState.Look.RotationSpeedId = rInfo.Id
			UpdateCustomizationEvent:FireServer({ RotationSpeedId = rInfo.Id })
			if refreshUI then
				refreshUI()
			end
		end)
		lookOptionButtons["RotationSpeedId"][rInfo.Id] = { Button = rb, Stroke = rStroke }
	end
end

-- RIGHT PANEL OF CUSTOMIZE PAGE: Founding Species Selection with 3D Viewports
local rightSpeciesPanel = Instance.new("Frame")
rightSpeciesPanel.Size = UDim2.new(0, 335, 1, -158)
rightSpeciesPanel.Position = UDim2.new(1, -349, 0, 80)
rightSpeciesPanel.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
rightSpeciesPanel.Parent = customizeMenuPage
addCorner(rightSpeciesPanel, 18)
addBorderStroke(rightSpeciesPanel, Color3.fromRGB(75, 225, 135), 2.5)

local rightHeader = Instance.new("Frame")
rightHeader.Size = UDim2.new(1, 0, 0, 38)
rightHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
rightHeader.Parent = rightSpeciesPanel
addCorner(rightHeader, 16)
addGradient(rightHeader, Color3.fromRGB(55, 195, 115), Color3.fromRGB(25, 135, 75), 90)

local rightHeaderLbl = Instance.new("TextLabel")
rightHeaderLbl.Size = UDim2.new(1, 0, 1, 0)
rightHeaderLbl.BackgroundTransparency = 1
rightHeaderLbl.Text = "👽 CHOOSE FOUNDING SPECIES"
rightHeaderLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
rightHeaderLbl.Font = Enum.Font.FredokaOne
rightHeaderLbl.TextSize = 16
rightHeaderLbl.Parent = rightHeader
addTextStroke(rightHeaderLbl, 1.8)

local spScroll = Instance.new("ScrollingFrame")
spScroll.Size = UDim2.new(1, -14, 1, -46)
spScroll.Position = UDim2.new(0, 7, 0, 42)
spScroll.BackgroundTransparency = 1
spScroll.ScrollBarThickness = 6
spScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
spScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
spScroll.Parent = rightSpeciesPanel

local spList = Instance.new("UIListLayout")
spList.Padding = UDim.new(0, 10)
spList.Parent = spScroll

local speciesSelectButtons: { [string]: { Button: TextButton, Stroke: UIStroke } } = {}
for _, spId in ipairs({ "Terranauts", "Lithoids", "Synthetics", "Sylvan", "Pyroclasts", "Astraeans" }) do
	local sp = SpeciesConfig.Species[spId]
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 122)
	card.BackgroundColor3 = Color3.fromRGB(28, 38, 68)
	card.Parent = spScroll
	addCorner(card, 14)
	local cardStroke = addBorderStroke(card, sp.PrimaryColor, 2.0)

	local charModel = PlanetGenerator.BuildSpeciesCharacterModel(sp.Id, 1.0)
	create3DViewportThumbnail(
		card,
		UDim2.new(0, 72, 0, 72),
		UDim2.new(0, 8, 0, 8),
		charModel,
		Vector3.new(0, 4.5, -7.5)
	)

	local sName = Instance.new("TextLabel")
	sName.Size = UDim2.new(1, -90, 0, 20)
	sName.Position = UDim2.new(0, 86, 0, 6)
	sName.BackgroundTransparency = 1
	sName.Text = sp.Name
	sName.TextColor3 = sp.PrimaryColor
	sName.Font = Enum.Font.FredokaOne
	sName.TextSize = 15
	sName.TextXAlignment = Enum.TextXAlignment.Left
	sName.Parent = card
	addTextStroke(sName, 1.6)

	local sDesc = Instance.new("TextLabel")
	sDesc.Size = UDim2.new(1, -90, 0, 34)
	sDesc.Position = UDim2.new(0, 86, 0, 25)
	sDesc.BackgroundTransparency = 1
	sDesc.Text = sp.Description
	sDesc.TextColor3 = Color3.fromRGB(215, 226, 245)
	sDesc.Font = Enum.Font.GothamMedium
	sDesc.TextSize = 10
	sDesc.TextWrapped = true
	sDesc.TextXAlignment = Enum.TextXAlignment.Left
	sDesc.Parent = card

	local m = sp.BaseMultipliers
	local sStats = Instance.new("TextLabel")
	sStats.Size = UDim2.new(1, -90, 0, 18)
	sStats.Position = UDim2.new(0, 86, 0, 60)
	sStats.BackgroundTransparency = 1
	sStats.Text = string.format(
		"⛏%d%% 🌿%d%% ⚡%d%% 🔬%d%% 👥%d%%",
		math.floor(m.Minerals * 100),
		math.floor(m.Biomass * 100),
		math.floor(m.Energy * 100),
		math.floor(m.Tech * 100),
		math.floor(m.PopGrowth * 100)
	)
	sStats.TextColor3 = Color3.fromRGB(255, 235, 115)
	sStats.Font = Enum.Font.FredokaOne
	sStats.TextSize = 11
	sStats.TextXAlignment = Enum.TextXAlignment.Left
	sStats.Parent = card
	addTextStroke(sStats, 1.4)

	local pickBtn = Instance.new("TextButton")
	pickBtn.Size = UDim2.new(1, -16, 0, 30)
	pickBtn.Position = UDim2.new(0, 8, 1, -36)
	pickBtn.BackgroundColor3 = sp.PrimaryColor
	pickBtn.Text = "SELECT SPECIES"
	pickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pickBtn.Font = Enum.Font.FredokaOne
	pickBtn.TextSize = 14
	pickBtn.Parent = card
	addCorner(pickBtn, 8)
	addBorderStroke(pickBtn, Color3.fromRGB(255, 255, 255), 1.5)
	addTextStroke(pickBtn, 1.6)

	pickBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.28, 0.1)
		currentState.SpeciesId = sp.Id
		refreshShowroomAndActivePlanetModels()
		SelectSpeciesEvent:FireServer(sp.Id)
		if refreshUI then
			refreshUI()
		end
	end)
	speciesSelectButtons[sp.Id] = { Button = pickBtn, Stroke = cardStroke }
end

-- ============================================================================
-- 5C. [⚙️ SETTINGS] PAGE (Audio, Starfield Density, Collectible Icons & FOV)
-- ============================================================================
local settingsLeftCard = Instance.new("Frame")
settingsLeftCard.Size = UDim2.new(0, 355, 1, -158)
settingsLeftCard.Position = UDim2.new(0, 14, 0, 80)
settingsLeftCard.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
settingsLeftCard.Parent = settingsMenuPage
addCorner(settingsLeftCard, 18)
addBorderStroke(settingsLeftCard, Color3.fromRGB(145, 185, 245), 2)

local settingsHdr = Instance.new("TextLabel")
settingsHdr.Size = UDim2.new(1, -24, 0, 34)
settingsHdr.Position = UDim2.new(0, 12, 0, 10)
settingsHdr.BackgroundTransparency = 1
settingsHdr.Text = "⚙️ GAME & AUDIO SETTINGS"
settingsHdr.TextColor3 = Color3.fromRGB(255, 230, 105)
settingsHdr.Font = Enum.Font.FredokaOne
settingsHdr.TextSize = 18
settingsHdr.TextXAlignment = Enum.TextXAlignment.Left
settingsHdr.Parent = settingsLeftCard
addTextStroke(settingsHdr, 1.8)

local settingsListFrame = Instance.new("Frame")
settingsListFrame.Size = UDim2.new(1, -24, 1, -56)
settingsListFrame.Position = UDim2.new(0, 12, 0, 48)
settingsListFrame.BackgroundTransparency = 1
settingsListFrame.Parent = settingsLeftCard

local settingsListLayout = Instance.new("UIListLayout")
settingsListLayout.Padding = UDim.new(0, 12)
settingsListLayout.Parent = settingsListFrame

local function makeSettingCycleRow(titleText: string, options: { { Label: string, Apply: () -> () } }, defaultIndex: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(28, 38, 68)
	row.Parent = settingsListFrame
	addCorner(row, 12)
	addBorderStroke(row, Color3.fromRGB(75, 135, 205), 1.4)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 22)
	lbl.Position = UDim2.new(0, 10, 0, 4)
	lbl.BackgroundTransparency = 1
	lbl.Text = titleText
	lbl.TextColor3 = Color3.fromRGB(225, 235, 250)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	addTextStroke(lbl, 1.4)

	local idx = defaultIndex
	local cycleBtn = Instance.new("TextButton")
	cycleBtn.Size = UDim2.new(1, -20, 0, 28)
	cycleBtn.Position = UDim2.new(0, 10, 0, 30)
	cycleBtn.BackgroundColor3 = Color3.fromRGB(45, 145, 235)
	cycleBtn.Text = options[idx].Label
	cycleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cycleBtn.Font = Enum.Font.FredokaOne
	cycleBtn.TextSize = 13
	cycleBtn.Parent = row
	addCorner(cycleBtn, 8)
	addBorderStroke(cycleBtn, Color3.fromRGB(255, 255, 255), 1.3)
	addTextStroke(cycleBtn, 1.4)

	cycleBtn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		cycleBtn.Text = options[idx].Label
		options[idx].Apply()
		playSFX(sfxClick, 0.28, 0.08)
	end)
end

makeSettingCycleRow("🔊 UI & Upgrade Sound Volume:", {
	{ Label = "Normal (75%)", Apply = function() userSettings.SfxVolume = 0.75 end },
	{ Label = "High (100%)", Apply = function() userSettings.SfxVolume = 1.0 end },
	{ Label = "Muted (0%)", Apply = function() userSettings.SfxVolume = 0.0 end },
	{ Label = "Soft (35%)", Apply = function() userSettings.SfxVolume = 0.35 end },
}, 1)

makeSettingCycleRow("🚀 Space Flight Thruster Audio:", {
	{ Label = "Subtle Deep Rumble", Apply = function() userSettings.ThrusterHum = 0.5 end },
	{ Label = "Standard Thrusters", Apply = function() userSettings.ThrusterHum = 1.0 end },
	{ Label = "Off (Silent Flight)", Apply = function() userSettings.ThrusterHum = 0.0; sfxThrusterLoop.Volume = 0 end },
}, 1)

makeSettingCycleRow("✨ Infinite 3D Starfield Density:", {
	{ Label = "High (220 Local Stars + Sky)", Apply = function() userSettings.StarDensity = 220 end },
	{ Label = "Ultra (240 Local Stars + Sky)", Apply = function() userSettings.StarDensity = 240 end },
	{ Label = "Standard (120 Local Stars)", Apply = function() userSettings.StarDensity = 120 end },
}, 1)

makeSettingCycleRow("🛰️ Collectible Space Icons:", {
	{ Label = "Show Compact Icons Only", Apply = function()
		userSettings.ShowCollectibleIcons = true
		local nodes = Workspace:FindFirstChild("CosmicEnvironment") and Workspace.CosmicEnvironment:FindFirstChild("CosmicResourceNodes")
		if nodes then
			for _, d in ipairs(nodes:GetDescendants()) do
				if d:IsA("BillboardGui") and d.Name == "CollectibleIconGui" then
					d.Enabled = true
				end
			end
		end
	end },
	{ Label = "Hide All Collectible Icons", Apply = function()
		userSettings.ShowCollectibleIcons = false
		local nodes = Workspace:FindFirstChild("CosmicEnvironment") and Workspace.CosmicEnvironment:FindFirstChild("CosmicResourceNodes")
		if nodes then
			for _, d in ipairs(nodes:GetDescendants()) do
				if d:IsA("BillboardGui") and d.Name == "CollectibleIconGui" then
					d.Enabled = false
				end
			end
		end
	end },
}, 1)

makeSettingCycleRow("🎥 Third-Person Camera FOV:", {
	{ Label = "70° Standard", Apply = function() userSettings.BaseFOV = 70 end },
	{ Label = "78° Wide Cosmic", Apply = function() userSettings.BaseFOV = 78 end },
	{ Label = "64° Cinematic", Apply = function() userSettings.BaseFOV = 64 end },
}, 1)

-- BOTTOM LAUNCH BAR ON THE 2D MENU (Always visible across Play, Customize & Settings!)
local launchBtn = Instance.new("TextButton")
launchBtn.Size = UDim2.new(0, 420, 0, 56)
launchBtn.AnchorPoint = Vector2.new(0.5, 1)
launchBtn.Position = UDim2.new(0.5, 0, 1, -12)
launchBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
launchBtn.Text = "🚀 PLAY & SPAWN IN GALACTIC HUB!"
launchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
launchBtn.Font = Enum.Font.FredokaOne
launchBtn.TextSize = 21
launchBtn.Parent = genesisContainer
addCorner(launchBtn, 18)
addBorderStroke(launchBtn, Color3.fromRGB(255, 255, 255), 3.0)
addGradient(launchBtn, Color3.fromRGB(65, 225, 110), Color3.fromRGB(22, 160, 62), 90)
addTextStroke(launchBtn, 2.2)
attachBounceAndSFX(launchBtn)

launchBtn.MouseButton1Click:Connect(launchIntoHub)

-- ============================================================================
-- 6. IN-GAME SIMULATOR HUD, MACHINE UI WINDOWS & PROGRESSION SYSTEM
-- ============================================================================
local inGameHUD = Instance.new("Frame")
inGameHUD.Name = "SimulatorInGameHUD"
inGameHUD.Size = UDim2.new(1, 0, 1, 0)
inGameHUD.BackgroundTransparency = 1
inGameHUD.Visible = true
inGameHUD.Parent = screenGui

-- A. TOP-CENTER PLANETARY RANK, XP PROGRESS BAR & SECTOR PILL
local topProgressionCard = Instance.new("Frame")
topProgressionCard.Size = UDim2.new(0, 520, 0, 74)
topProgressionCard.AnchorPoint = Vector2.new(0.5, 0)
topProgressionCard.Position = UDim2.new(0.5, 0, 0, 10)
topProgressionCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topProgressionCard.Parent = inGameHUD
addCorner(topProgressionCard, 18)
addBorderStroke(topProgressionCard, Color3.fromRGB(95, 165, 240), 2.2)
addGradient(topProgressionCard, Color3.fromRGB(24, 34, 64), Color3.fromRGB(14, 20, 40), 90)

local rankTitleLbl = Instance.new("TextLabel")
rankTitleLbl.Size = UDim2.new(1, -24, 0, 22)
rankTitleLbl.Position = UDim2.new(0, 12, 0, 4)
rankTitleLbl.BackgroundTransparency = 1
rankTitleLbl.Text = "🏆 RANK 1: PROTO-PLANETOID (1.0x Yield)"
rankTitleLbl.TextColor3 = Color3.fromRGB(255, 230, 95)
rankTitleLbl.Font = Enum.Font.FredokaOne
rankTitleLbl.TextSize = 15
rankTitleLbl.Parent = topProgressionCard
addTextStroke(rankTitleLbl, 1.8)

local rankBarBg = Instance.new("Frame")
rankBarBg.Size = UDim2.new(1, -32, 0, 18)
rankBarBg.Position = UDim2.new(0, 16, 0, 28)
rankBarBg.BackgroundColor3 = Color3.fromRGB(10, 14, 28)
rankBarBg.Parent = topProgressionCard
addCorner(rankBarBg, 9)
addBorderStroke(rankBarBg, Color3.fromRGB(75, 145, 225), 1.3)

local rankBarFill = Instance.new("Frame")
rankBarFill.Size = UDim2.new(0.25, 0, 1, 0)
rankBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
rankBarFill.Parent = rankBarBg
addCorner(rankBarFill, 9)
addGradient(rankBarFill, Color3.fromRGB(65, 225, 135), Color3.fromRGB(35, 175, 245), 0)

local rankBarText = Instance.new("TextLabel")
rankBarText.Size = UDim2.new(1, 0, 1, 0)
rankBarText.BackgroundTransparency = 1
rankBarText.Text = "Planet Value: 100 / 400 -> Next Rank: Awakening World"
rankBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
rankBarText.Font = Enum.Font.FredokaOne
rankBarText.TextSize = 11
rankBarText.Parent = rankBarBg
addTextStroke(rankBarText, 1.4)

local zoneTitleLbl = Instance.new("TextLabel")
zoneTitleLbl.Size = UDim2.new(1, -20, 0, 20)
zoneTitleLbl.Position = UDim2.new(0, 10, 0, 49)
zoneTitleLbl.BackgroundTransparency = 1
zoneTitleLbl.Text = "★ GALACTIC NEXUS HUB (+50% YIELD) • WASD + Shift (Boost) + Right-Click Orbit"
zoneTitleLbl.TextColor3 = Color3.fromRGB(110, 240, 185)
zoneTitleLbl.Font = Enum.Font.GothamBold
zoneTitleLbl.TextSize = 11
zoneTitleLbl.Parent = topProgressionCard
addTextStroke(zoneTitleLbl, 1.2)

-- B. LEFT-SIDE GUIDED MISSION TRACKER CARD
local missionCard = Instance.new("Frame")
missionCard.Size = UDim2.new(0, 275, 0, 118)
missionCard.Position = UDim2.new(0, 16, 0, 96)
missionCard.BackgroundColor3 = Color3.fromRGB(18, 26, 50)
missionCard.BackgroundTransparency = 0.06
missionCard.Parent = inGameHUD
addCorner(missionCard, 16)
addBorderStroke(missionCard, Color3.fromRGB(245, 205, 65), 2.2)

local missionHeader = Instance.new("TextLabel")
missionHeader.Size = UDim2.new(1, -18, 0, 22)
missionHeader.Position = UDim2.new(0, 10, 0, 6)
missionHeader.BackgroundTransparency = 1
missionHeader.Text = "🎯 ACTIVE MISSION #1"
missionHeader.TextColor3 = Color3.fromRGB(255, 225, 85)
missionHeader.Font = Enum.Font.FredokaOne
missionHeader.TextSize = 14
missionHeader.TextXAlignment = Enum.TextXAlignment.Left
missionHeader.Parent = missionCard
addTextStroke(missionHeader, 1.6)

local missionDescLbl = Instance.new("TextLabel")
missionDescLbl.Size = UDim2.new(1, -20, 0, 36)
missionDescLbl.Position = UDim2.new(0, 10, 0, 28)
missionDescLbl.BackgroundTransparency = 1
missionDescLbl.Text = "Click UPGRADE and upgrade any Planet System to Level 1."
missionDescLbl.TextColor3 = Color3.fromRGB(225, 235, 250)
missionDescLbl.Font = Enum.Font.GothamBold
missionDescLbl.TextSize = 11
missionDescLbl.TextWrapped = true
missionDescLbl.TextXAlignment = Enum.TextXAlignment.Left
missionDescLbl.Parent = missionCard

local missionBarBg = Instance.new("Frame")
missionBarBg.Size = UDim2.new(1, -20, 0, 18)
missionBarBg.Position = UDim2.new(0, 10, 0, 68)
missionBarBg.BackgroundColor3 = Color3.fromRGB(10, 14, 28)
missionBarBg.Parent = missionCard
addCorner(missionBarBg, 9)
addBorderStroke(missionBarBg, Color3.fromRGB(245, 205, 65), 1.2)

local missionBarFill = Instance.new("Frame")
missionBarFill.Size = UDim2.new(0, 0, 1, 0)
missionBarFill.BackgroundColor3 = Color3.fromRGB(245, 205, 65)
missionBarFill.Parent = missionBarBg
addCorner(missionBarFill, 9)

local missionBarText = Instance.new("TextLabel")
missionBarText.Size = UDim2.new(1, 0, 1, 0)
missionBarText.BackgroundTransparency = 1
missionBarText.Text = "0 / 1"
missionBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
missionBarText.Font = Enum.Font.FredokaOne
missionBarText.TextSize = 11
missionBarText.Parent = missionBarBg
addTextStroke(missionBarText, 1.3)

local missionRewardLbl = Instance.new("TextLabel")
missionRewardLbl.Size = UDim2.new(1, -20, 0, 20)
missionRewardLbl.Position = UDim2.new(0, 10, 0, 92)
missionRewardLbl.BackgroundTransparency = 1
missionRewardLbl.Text = "🎁 Reward: +180⛏ +180🌿 +150⚡ +120🔬"
missionRewardLbl.TextColor3 = Color3.fromRGB(105, 245, 160)
missionRewardLbl.Font = Enum.Font.FredokaOne
missionRewardLbl.TextSize = 11
missionRewardLbl.TextXAlignment = Enum.TextXAlignment.Left
missionRewardLbl.Parent = missionCard
addTextStroke(missionRewardLbl, 1.3)

-- C. POPUP TOAST BANNER
local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(0, 540, 0, 40)
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.Position = UDim2.new(0.5, 0, 0, 90)
toastLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 54)
toastLabel.BackgroundTransparency = 1
toastLabel.TextTransparency = 1
toastLabel.Text = ""
toastLabel.TextColor3 = Color3.fromRGB(255, 240, 110)
toastLabel.Font = Enum.Font.FredokaOne
toastLabel.TextSize = 15
toastLabel.TextWrapped = true
toastLabel.Parent = screenGui
addCorner(toastLabel, 12)

local toastId = 0
local function showToast(msg: string, color: Color3)
	toastId += 1
	local myId = toastId
	playSFX(sfxUpgrade, 0.35, 0.08)
	toastLabel.Text = msg
	toastLabel.TextColor3 = color
	toastLabel.BackgroundTransparency = 0.10
	toastLabel.TextTransparency = 0
	task.delay(3.5, function()
		if toastId == myId then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
		end
	end)
end
NotificationEvent.OnClientEvent:Connect(showToast)

-- D. BOTTOM-RIGHT 4 CURRENCY & STAT PILLS (Gems, Citizens, Planet Value, Cosmic Shards)
local bottomRightHud = Instance.new("Frame")
bottomRightHud.Size = UDim2.new(0, 396, 0, 96)
bottomRightHud.AnchorPoint = Vector2.new(1, 1)
bottomRightHud.Position = UDim2.new(1, -14, 1, -12)
bottomRightHud.BackgroundTransparency = 1
bottomRightHud.Parent = inGameHUD

local pillGrid = Instance.new("UIGridLayout")
pillGrid.CellSize = UDim2.new(0, 190, 0, 41)
pillGrid.CellPadding = UDim2.new(0, 10, 0, 7)
pillGrid.HorizontalAlignment = Enum.HorizontalAlignment.Right
pillGrid.VerticalAlignment = Enum.VerticalAlignment.Bottom
pillGrid.Parent = bottomRightHud

local statCards: { [string]: { ValueLabel: TextLabel, RateLabel: TextLabel } } = {}
local statDefs = {
	{ Key = "Gems", Icon = "💎", Title = "Star Gems", TopC = Color3.fromRGB(255, 85, 225), BotC = Color3.fromRGB(175, 25, 165) },
	{ Key = "Population", Icon = "👥", Title = "Citizens", TopC = Color3.fromRGB(245, 220, 90), BotC = Color3.fromRGB(195, 150, 25) },
	{ Key = "PlanetValue", Icon = "★", Title = "Planet Value", TopC = Color3.fromRGB(245, 105, 185), BotC = Color3.fromRGB(180, 35, 125) },
	{ Key = "CosmicShards", Icon = "🪐", Title = "Cosmic Shards", TopC = Color3.fromRGB(255, 215, 65), BotC = Color3.fromRGB(195, 125, 20) },
}

for _, def in ipairs(statDefs) do
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = Color3.fromRGB(18, 24, 46)
	pill.Parent = bottomRightHud
	addCorner(pill, 20)
	addBorderStroke(pill, Color3.fromRGB(90, 140, 210), 2.0)

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 34, 0, 34)
	badge.Position = UDim2.new(0, 4, 0.5, -17)
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.Parent = pill
	addCorner(badge, 17)
	addGradient(badge, def.TopC, def.BotC, 90)

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 1, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = def.Icon
	iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLbl.Font = Enum.Font.FredokaOne
	iconLbl.TextSize = 17
	iconLbl.Parent = badge
	addTextStroke(iconLbl, 1.4)

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(1, -46, 0, 21)
	valLbl.Position = UDim2.new(0, 42, 0, 2)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = "0"
	valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLbl.Font = Enum.Font.FredokaOne
	valLbl.TextSize = 17
	valLbl.TextXAlignment = Enum.TextXAlignment.Left
	valLbl.Parent = pill
	addTextStroke(valLbl, 1.8)

	local rateLbl = Instance.new("TextLabel")
	rateLbl.Size = UDim2.new(1, -46, 0, 14)
	rateLbl.Position = UDim2.new(0, 42, 0, 23)
	rateLbl.BackgroundTransparency = 1
	rateLbl.Text = def.Title
	rateLbl.TextColor3 = def.TopC
	rateLbl.Font = Enum.Font.GothamBlack
	rateLbl.TextSize = 10
	rateLbl.TextXAlignment = Enum.TextXAlignment.Left
	rateLbl.Parent = pill
	addTextStroke(rateLbl, 1.2)

	statCards[def.Key] = { ValueLabel = valLbl, RateLabel = rateLbl }
end

-- E. ACTIVE BOOSTERS & DISTANCE TRACKER BAR (Right below topProgressionCard)
local boosterTrackerBar = Instance.new("Frame")
boosterTrackerBar.Size = UDim2.new(0, 560, 0, 28)
boosterTrackerBar.AnchorPoint = Vector2.new(0.5, 0)
boosterTrackerBar.Position = UDim2.new(0.5, 0, 0, 92)
boosterTrackerBar.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
boosterTrackerBar.BackgroundTransparency = 0.15
boosterTrackerBar.Parent = inGameHUD
addCorner(boosterTrackerBar, 12)
addBorderStroke(boosterTrackerBar, Color3.fromRGB(95, 165, 240), 1.6)

local boosterStatusLbl = Instance.new("TextLabel")
boosterStatusLbl.Size = UDim2.new(1, -16, 1, 0)
boosterStatusLbl.Position = UDim2.new(0, 8, 0, 0)
boosterStatusLbl.BackgroundTransparency = 1
boosterStatusLbl.Text = "🛸 Drones: 0/3 • 🛰️ Next Gate: Belt Outpost (1,850 studs)"
boosterStatusLbl.TextColor3 = Color3.fromRGB(220, 238, 255)
boosterStatusLbl.Font = Enum.Font.FredokaOne
boosterStatusLbl.TextSize = 12
boosterStatusLbl.Parent = boosterTrackerBar
addTextStroke(boosterStatusLbl, 1.4)

-- ============================================================================
-- 7. DEDICATED HUB MACHINE UIs, DRONES, BOOSTS, EVOLUTION, UPGRADES & WARP
-- ============================================================================
local modalFrame = Instance.new("Frame")
modalFrame.Name = "SimulatorModalWindow"
modalFrame.Size = UDim2.new(0, 880, 0, 520)
modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
modalFrame.Position = UDim2.new(0.5, 0, 0.5, -10)
modalFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 46)
modalFrame.Visible = false
modalFrame.Parent = inGameHUD
addCorner(modalFrame, 20)
addBorderStroke(modalFrame, Color3.fromRGB(95, 175, 250), 3.0)

local modalHeader = Instance.new("Frame")
modalHeader.Size = UDim2.new(1, 0, 0, 50)
modalHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
modalHeader.Parent = modalFrame
addCorner(modalHeader, 18)
addGradient(modalHeader, Color3.fromRGB(42, 125, 225), Color3.fromRGB(24, 64, 155), 90)

local modalTitleLabel = Instance.new("TextLabel")
modalTitleLabel.Size = UDim2.new(1, -80, 1, 0)
modalTitleLabel.Position = UDim2.new(0, 20, 0, 0)
modalTitleLabel.BackgroundTransparency = 1
modalTitleLabel.Text = "HUB MACHINE CONTROL PANEL"
modalTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitleLabel.Font = Enum.Font.FredokaOne
modalTitleLabel.TextSize = 20
modalTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
modalTitleLabel.Parent = modalHeader
addTextStroke(modalTitleLabel, 2.0)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.Position = UDim2.new(1, -46, 0.5, -19)
closeBtn.BackgroundColor3 = Color3.fromRGB(235, 60, 75)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 18
closeBtn.Parent = modalHeader
addCorner(closeBtn, 10)
addBorderStroke(closeBtn, Color3.fromRGB(255, 255, 255), 1.8)
addTextStroke(closeBtn, 1.8)

local tabPages: { [string]: ScrollingFrame } = {}
local activeTab: string? = nil

local function createTabPage(name: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, -28, 1, -66)
	page.Position = UDim2.new(0, 14, 0, 56)
	page.BackgroundTransparency = 1
	page.ScrollBarThickness = 6
	page.Visible = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Parent = modalFrame
	tabPages[name] = page
	return page
end

local machinesPage = createTabPage("Machines")
local evolutionPage = createTabPage("Evolution")
local planetValuePage = createTabPage("PlanetValue")
local warpAscendPage = createTabPage("WarpAscend")
local dronesPage = createTabPage("Drones")
local boostsRewardsPage = createTabPage("BoostsRewards")

local selectedMachineFilter: string? = nil
local machineCardsUI: {
	[string]: {
		Card: Frame,
		TierLabel: TextLabel,
		EffectLabel: TextLabel,
		CostLabel: TextLabel,
		BuyOneBtn: TextButton,
		BuyMaxBtn: TextButton,
	},
} = {}

local function openMachineModal(machineId: string?)
	playSFX(sfxClick, 0.28)
	selectedMachineFilter = machineId
	activeTab = "Machines"
	if machineId and PlanetConfig.HubMachines[machineId] then
		local mDef = PlanetConfig.HubMachines[machineId]
		modalTitleLabel.Text = mDef.Name .. "  (Dedicated Machine UI)"
	else
		modalTitleLabel.Text = "⚙️ ALL GALACTIC HUB MACHINES (TIERED OVERCLOCK)"
	end
	for k, page in pairs(tabPages) do
		page.Visible = (k == "Machines")
	end
	for mId, ui in pairs(machineCardsUI) do
		ui.Card.Visible = (machineId == nil) or (mId == machineId)
	end
	modalFrame.Visible = true
end

local function toggleTab(tabKey: string, titleText: string)
	playSFX(sfxClick, 0.28)
	if modalFrame.Visible and activeTab == tabKey and selectedMachineFilter == nil then
		modalFrame.Visible = false
		activeTab = nil
		return
	end
	selectedMachineFilter = nil
	activeTab = tabKey
	modalTitleLabel.Text = titleText
	for k, page in pairs(tabPages) do
		page.Visible = (k == tabKey)
	end
	if tabKey == "Machines" then
		for _, ui in pairs(machineCardsUI) do
			ui.Card.Visible = true
		end
	end
	modalFrame.Visible = true
end

closeBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.28)
	modalFrame.Visible = false
	activeTab = nil
end)

-- BUILD DEDICATED HUB MACHINE CARDS (DysonReactor, TitanRefinery, GaiaBioVat, AstralObservatory)
do
	local mList = Instance.new("UIListLayout")
	mList.Padding = UDim.new(0, 14)
	mList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mList.Parent = machinesPage

	local showAllBtn = Instance.new("TextButton")
	showAllBtn.Size = UDim2.new(1, -16, 0, 34)
	showAllBtn.BackgroundColor3 = Color3.fromRGB(36, 52, 92)
	showAllBtn.Text = "📋 SHOW ALL 4 UPGRADEABLE HUB MACHINES"
	showAllBtn.TextColor3 = Color3.fromRGB(220, 235, 255)
	showAllBtn.Font = Enum.Font.FredokaOne
	showAllBtn.TextSize = 13
	showAllBtn.Parent = machinesPage
	addCorner(showAllBtn, 10)
	addBorderStroke(showAllBtn, Color3.fromRGB(95, 165, 240), 1.5)
	showAllBtn.MouseButton1Click:Connect(function()
		openMachineModal(nil)
	end)

	local machineOrder = { "DysonReactor", "TitanRefinery", "GaiaBioVat", "AstralObservatory" }
	for _, mId in ipairs(machineOrder) do
		local mDef = PlanetConfig.HubMachines[mId]
		if mDef then
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -16, 0, 178)
		card.BackgroundColor3 = Color3.fromRGB(26, 36, 68)
		card.Parent = machinesPage
		addCorner(card, 16)
		addBorderStroke(card, mDef.ThemeColor, 2.5)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -170, 0, 28)
		title.Position = UDim2.new(0, 16, 0, 10)
		title.BackgroundTransparency = 1
		title.Text = mDef.Name
		title.TextColor3 = mDef.ThemeColor
		title.Font = Enum.Font.FredokaOne
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = card
		addTextStroke(title, 1.8)

		local tierLbl = Instance.new("TextLabel")
		tierLbl.Size = UDim2.new(0, 145, 0, 26)
		tierLbl.Position = UDim2.new(1, -160, 0, 11)
		tierLbl.BackgroundTransparency = 1
		tierLbl.Text = "Tier 0 / 50"
		tierLbl.TextColor3 = Color3.fromRGB(255, 235, 105)
		tierLbl.Font = Enum.Font.FredokaOne
		tierLbl.TextSize = 16
		tierLbl.TextXAlignment = Enum.TextXAlignment.Right
		tierLbl.Parent = card
		addTextStroke(tierLbl, 1.6)

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -32, 0, 36)
		sub.Position = UDim2.new(0, 16, 0, 40)
		sub.BackgroundTransparency = 1
		sub.Text = mDef.Subtitle
		sub.TextColor3 = Color3.fromRGB(215, 226, 245)
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 12
		sub.TextWrapped = true
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Parent = card

		local effectLbl = Instance.new("TextLabel")
		effectLbl.Size = UDim2.new(1, -32, 0, 22)
		effectLbl.Position = UDim2.new(0, 16, 0, 78)
		effectLbl.BackgroundTransparency = 1
		effectLbl.Text = "Current Multiplier: 1.00x  ➔  Next Tier: 1.45x"
		effectLbl.TextColor3 = Color3.fromRGB(105, 245, 165)
		effectLbl.Font = Enum.Font.FredokaOne
		effectLbl.TextSize = 14
		effectLbl.TextXAlignment = Enum.TextXAlignment.Left
		effectLbl.Parent = card
		addTextStroke(effectLbl, 1.4)

		local costLbl = Instance.new("TextLabel")
		costLbl.Size = UDim2.new(1, -32, 0, 20)
		costLbl.Position = UDim2.new(0, 16, 0, 102)
		costLbl.BackgroundTransparency = 1
		costLbl.Text = "Cost: ..."
		costLbl.TextColor3 = Color3.fromRGB(255, 225, 105)
		costLbl.Font = Enum.Font.FredokaOne
		costLbl.TextSize = 13
		costLbl.TextXAlignment = Enum.TextXAlignment.Left
		costLbl.Parent = card
		addTextStroke(costLbl, 1.4)

		local buyOneBtn = Instance.new("TextButton")
		buyOneBtn.Size = UDim2.new(0.64, -20, 0, 40)
		buyOneBtn.Position = UDim2.new(0, 16, 1, -48)
		buyOneBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buyOneBtn.Text = mDef.ActionButtonText
		buyOneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyOneBtn.Font = Enum.Font.FredokaOne
		buyOneBtn.TextSize = 13
		buyOneBtn.Parent = card
		addCorner(buyOneBtn, 10)
		addBorderStroke(buyOneBtn, Color3.fromRGB(255, 255, 255), 1.8)
		addGradient(buyOneBtn, Color3.fromRGB(65, 225, 115), Color3.fromRGB(22, 165, 65), 90)
		addTextStroke(buyOneBtn, 1.8)

		local buyMaxBtn = Instance.new("TextButton")
		buyMaxBtn.Size = UDim2.new(0.36, -16, 0, 40)
		buyMaxBtn.Position = UDim2.new(0.64, 4, 1, -48)
		buyMaxBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buyMaxBtn.Text = "⚡ MAX OVERCLOCK"
		buyMaxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyMaxBtn.Font = Enum.Font.FredokaOne
		buyMaxBtn.TextSize = 13
		buyMaxBtn.Parent = card
		addCorner(buyMaxBtn, 10)
		addBorderStroke(buyMaxBtn, Color3.fromRGB(255, 255, 255), 1.8)
		addGradient(buyMaxBtn, Color3.fromRGB(245, 185, 45), Color3.fromRGB(205, 105, 15), 90)
		addTextStroke(buyMaxBtn, 1.8)

		buyOneBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.38)
			UpgradeMachineEvent:FireServer(mId, false)
		end)
		buyMaxBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.38)
			UpgradeMachineEvent:FireServer(mId, true)
		end)

		machineCardsUI[mId] = {
			Card = card,
			TierLabel = tierLbl,
			EffectLabel = effectLbl,
			CostLabel = costLbl,
			BuyOneBtn = buyOneBtn,
			BuyMaxBtn = buyMaxBtn,
		}
		end
	end
end

-- BUILD DEEP-SPACE STATIONS WARP GATE, PLANETARY ASCENSION & COSMIC SHARDS SHOP (`warpAscendPage`)
local ascensionInfoLabel: TextLabel
local ascendActionBtn: TextButton
local warpStationBtns: { [string]: { Btn: TextButton, ReqLabel: TextLabel, StatusBadge: TextLabel } } = {}
local shardUpgBtns: { [string]: { Btn: TextButton, LvlLabel: TextLabel } } = {}
do
	local wList = Instance.new("UIListLayout")
	wList.Padding = UDim.new(0, 12)
	wList.Parent = warpAscendPage

	-- 1. Deep-Space Stations & Warp Gate Network Header
	local stHdr = Instance.new("TextLabel")
	stHdr.Size = UDim2.new(1, -16, 0, 26)
	stHdr.BackgroundTransparency = 1
	stHdr.Text = "🛰️ DEEP-SPACE OUTPOST STATIONS (UNLOCK WARP GATES WITH 💎 STAR GEMS)"
	stHdr.TextColor3 = Color3.fromRGB(115, 225, 255)
	stHdr.Font = Enum.Font.FredokaOne
	stHdr.TextSize = 16
	stHdr.TextXAlignment = Enum.TextXAlignment.Left
	stHdr.Parent = warpAscendPage
	addTextStroke(stHdr, 1.6)

	for _, st in ipairs(PlanetConfig.SpaceStations) do
		local sCard = Instance.new("Frame")
		sCard.Size = UDim2.new(1, -16, 0, 96)
		sCard.BackgroundColor3 = Color3.fromRGB(24, 34, 64)
		sCard.Parent = warpAscendPage
		addCorner(sCard, 14)
		addBorderStroke(sCard, st.Color, 2.0)

		local distStuds = math.floor(st.Position.Magnitude)
		local sTitle = Instance.new("TextLabel")
		sTitle.Size = UDim2.new(1, -225, 0, 24)
		sTitle.Position = UDim2.new(0, 14, 0, 6)
		sTitle.BackgroundTransparency = 1
		sTitle.Text = string.format("%s  •  %s studs (%sx Zone Yield)", st.Name, PlanetConfig.FormatNumber(distStuds), PlanetConfig.FormatNumber(st.RewardMultiplier))
		sTitle.TextColor3 = st.Color
		sTitle.Font = Enum.Font.FredokaOne
		sTitle.TextSize = 15
		sTitle.TextXAlignment = Enum.TextXAlignment.Left
		sTitle.Parent = sCard
		addTextStroke(sTitle, 1.6)

		local sDesc = Instance.new("TextLabel")
		sDesc.Size = UDim2.new(1, -225, 0, 22)
		sDesc.Position = UDim2.new(0, 14, 0, 30)
		sDesc.BackgroundTransparency = 1
		sDesc.Text = st.PassiveBuffDesc or st.Description or ""
		sDesc.TextColor3 = Color3.fromRGB(215, 226, 245)
		sDesc.Font = Enum.Font.GothamMedium
		sDesc.TextSize = 11
		sDesc.TextWrapped = true
		sDesc.TextXAlignment = Enum.TextXAlignment.Left
		sDesc.Parent = sCard

		local perkLbl = Instance.new("TextLabel")
		perkLbl.Size = UDim2.new(1, -225, 0, 18)
		perkLbl.Position = UDim2.new(0, 14, 0, 52)
		perkLbl.BackgroundTransparency = 1
		perkLbl.Text = "✨ Gate Perk: " .. (st.StationUnlockPerk or "Permanent Network Bonus")
		perkLbl.TextColor3 = Color3.fromRGB(110, 245, 175)
		perkLbl.Font = Enum.Font.FredokaOne
		perkLbl.TextSize = 11
		perkLbl.TextXAlignment = Enum.TextXAlignment.Left
		perkLbl.Parent = sCard
		addTextStroke(perkLbl, 1.2)

		local reqLbl = Instance.new("TextLabel")
		reqLbl.Size = UDim2.new(1, -225, 0, 18)
		reqLbl.Position = UDim2.new(0, 14, 0, 71)
		reqLbl.BackgroundTransparency = 1
		reqLbl.Text = (st.GemCost > 0)
			and string.format("Requires 🔨 Drill Lv.%d  •  Unlock Cost: %s 💎 Gems", st.ReqDrill, PlanetConfig.FormatNumber(st.GemCost))
			or "Unlocked from Start!"
		reqLbl.TextColor3 = Color3.fromRGB(255, 230, 105)
		reqLbl.Font = Enum.Font.FredokaOne
		reqLbl.TextSize = 11
		reqLbl.TextXAlignment = Enum.TextXAlignment.Left
		reqLbl.Parent = sCard
		addTextStroke(reqLbl, 1.3)

		local wBtn = Instance.new("TextButton")
		wBtn.Size = UDim2.new(0, 195, 0, 52)
		wBtn.Position = UDim2.new(1, -208, 0.5, -26)
		wBtn.BackgroundColor3 = st.Color
		wBtn.Text = "🌀 WARP HERE"
		wBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		wBtn.Font = Enum.Font.FredokaOne
		wBtn.TextSize = 14
		wBtn.Parent = sCard
		addCorner(wBtn, 12)
		addBorderStroke(wBtn, Color3.fromRGB(255, 255, 255), 1.8)
		addTextStroke(wBtn, 1.8)

		wBtn.MouseButton1Click:Connect(function()
			local isUnlocked = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
			if isUnlocked then
				playSFX(sfxLaunch, 0.35)
				localPlanetPos = (st.Id == "Hub") and HUB_SPAWN_POS or (st.Position + Vector3.new(0, 18, 85))
				localVelocity = Vector3.zero
				WarpToSectorEvent:FireServer(st.Id)
				modalFrame.Visible = false
			else
				playSFX(sfxUpgrade, 0.38)
				UnlockSpaceStationEvent:FireServer(st.Id)
			end
		end)

		warpStationBtns[st.Id] = { Btn = wBtn, ReqLabel = reqLbl, StatusBadge = perkLbl }
	end

	-- 2. Planetary Ascension Card (Awards Cosmic Shards + 2.5x Permanent Multiplier)
	local ascCard = Instance.new("Frame")
	ascCard.Size = UDim2.new(1, -16, 0, 140)
	ascCard.BackgroundColor3 = Color3.fromRGB(36, 26, 68)
	ascCard.Parent = warpAscendPage
	addCorner(ascCard, 16)
	addBorderStroke(ascCard, Color3.fromRGB(255, 205, 65), 2.5)

	local ascHdr = Instance.new("TextLabel")
	ascHdr.Size = UDim2.new(1, -24, 0, 26)
	ascHdr.Position = UDim2.new(0, 14, 0, 8)
	ascHdr.BackgroundTransparency = 1
	ascHdr.Text = "🌟 PLANETARY ASCENSION & 🪐 COSMIC SHARD REBIRTH"
	ascHdr.TextColor3 = Color3.fromRGB(255, 225, 85)
	ascHdr.Font = Enum.Font.FredokaOne
	ascHdr.TextSize = 16
	ascHdr.TextXAlignment = Enum.TextXAlignment.Left
	ascHdr.Parent = ascCard
	addTextStroke(ascHdr, 1.8)

	ascensionInfoLabel = Instance.new("TextLabel")
	ascensionInfoLabel.Size = UDim2.new(1, -28, 0, 44)
	ascensionInfoLabel.Position = UDim2.new(0, 14, 0, 36)
	ascensionInfoLabel.BackgroundTransparency = 1
	ascensionInfoLabel.Text = "Current Ascensions: 0 (1x Permanent Bonus)  •  Requires 32K Planet Value"
	ascensionInfoLabel.TextColor3 = Color3.fromRGB(225, 235, 255)
	ascensionInfoLabel.Font = Enum.Font.GothamBold
	ascensionInfoLabel.TextSize = 12
	ascensionInfoLabel.TextWrapped = true
	ascensionInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ascensionInfoLabel.Parent = ascCard

	ascendActionBtn = Instance.new("TextButton")
	ascendActionBtn.Size = UDim2.new(1, -28, 0, 42)
	ascendActionBtn.Position = UDim2.new(0, 14, 1, -50)
	ascendActionBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ascendActionBtn.Text = "🌟 ASCEND PLANET (+2.5x ALL YIELDS & 🪐 COSMIC SHARDS)"
	ascendActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	ascendActionBtn.Font = Enum.Font.FredokaOne
	ascendActionBtn.TextSize = 14
	ascendActionBtn.Parent = ascCard
	addCorner(ascendActionBtn, 10)
	addBorderStroke(ascendActionBtn, Color3.fromRGB(255, 255, 255), 2)
	addGradient(ascendActionBtn, Color3.fromRGB(245, 115, 195), Color3.fromRGB(185, 35, 130), 90)
	addTextStroke(ascendActionBtn, 1.8)

	ascendActionBtn.MouseButton1Click:Connect(function()
		playSFX(sfxEvolve, 0.45)
		AscendPlanetEvent:FireServer()
	end)

	-- 3. Cosmic Shard Permanent Upgrades Grid
	local shardGridFrame = Instance.new("Frame")
	shardGridFrame.Size = UDim2.new(1, -16, 0, 195)
	shardGridFrame.BackgroundTransparency = 1
	shardGridFrame.Parent = warpAscendPage

	local sGrid = Instance.new("UIGridLayout")
	sGrid.CellSize = UDim2.new(0, 405, 0, 88)
	sGrid.CellPadding = UDim2.new(0, 12, 0, 12)
	sGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sGrid.Parent = shardGridFrame

	for _, sUpg in ipairs(PlanetConfig.ShardUpgrades) do
		local sc = Instance.new("Frame")
		sc.BackgroundColor3 = Color3.fromRGB(32, 24, 58)
		sc.Parent = shardGridFrame
		addCorner(sc, 12)
		addBorderStroke(sc, Color3.fromRGB(195, 115, 255), 2.0)

		local st = Instance.new("TextLabel")
		st.Size = UDim2.new(1, -145, 0, 22)
		st.Position = UDim2.new(0, 12, 0, 6)
		st.BackgroundTransparency = 1
		st.Text = sUpg.Name
		st.TextColor3 = Color3.fromRGB(225, 165, 255)
		st.Font = Enum.Font.FredokaOne
		st.TextSize = 14
		st.TextXAlignment = Enum.TextXAlignment.Left
		st.Parent = sc
		addTextStroke(st, 1.4)

		local sl = Instance.new("TextLabel")
		sl.Size = UDim2.new(0, 120, 0, 20)
		sl.Position = UDim2.new(1, -132, 0, 7)
		sl.BackgroundTransparency = 1
		sl.Text = "Lv. 0 / " .. tostring(sUpg.MaxLevel)
		sl.TextColor3 = Color3.fromRGB(255, 225, 95)
		sl.Font = Enum.Font.FredokaOne
		sl.TextSize = 12
		sl.TextXAlignment = Enum.TextXAlignment.Right
		sl.Parent = sc
		addTextStroke(sl, 1.3)

		local sd = Instance.new("TextLabel")
		sd.Size = UDim2.new(1, -150, 0, 34)
		sd.Position = UDim2.new(0, 12, 0, 30)
		sd.BackgroundTransparency = 1
		sd.Text = sUpg.Description
		sd.TextColor3 = Color3.fromRGB(215, 225, 245)
		sd.Font = Enum.Font.GothamBold
		sd.TextSize = 11
		sd.TextWrapped = true
		sd.TextXAlignment = Enum.TextXAlignment.Left
		sd.Parent = sc

		local sb = Instance.new("TextButton")
		sb.Size = UDim2.new(0, 128, 0, 42)
		sb.Position = UDim2.new(1, -138, 0.5, -14)
		sb.BackgroundColor3 = Color3.fromRGB(165, 65, 235)
		sb.Text = "🪐 1 SHARD"
		sb.TextColor3 = Color3.fromRGB(255, 255, 255)
		sb.Font = Enum.Font.FredokaOne
		sb.TextSize = 12
		sb.Parent = sc
		addCorner(sb, 10)
		addBorderStroke(sb, Color3.fromRGB(255, 255, 255), 1.6)
		addTextStroke(sb, 1.5)

		sb.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			BuyShardUpgradeEvent:FireServer(sUpg.Id)
		end)

		shardUpgBtns[sUpg.Id] = { Btn = sb, LvlLabel = sl }
	end
end

-- ============================================================================
-- 7B. ORBITAL COMPANIONS / DRONE PODS GACHA & INVENTORY PAGE (`dronesPage`)
-- ============================================================================
local droneSummaryLabel: TextLabel
local droneInventoryGridFrame: Frame
do
	local dList = Instance.new("UIListLayout")
	dList.Padding = UDim.new(0, 12)
	dList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dList.Parent = dronesPage

	-- Pod Hatching Row (3 Tiers of Drone Pods)
	local podRow = Instance.new("Frame")
	podRow.Size = UDim2.new(1, -16, 0, 168)
	podRow.BackgroundTransparency = 1
	podRow.Parent = dronesPage

	local podGrid = Instance.new("UIGridLayout")
	podGrid.CellSize = UDim2.new(0, 268, 0, 164)
	podGrid.CellPadding = UDim2.new(0, 12, 0, 0)
	podGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	podGrid.Parent = podRow

	for _, pod in ipairs(PlanetConfig.CompanionPods) do
		local pCard = Instance.new("Frame")
		pCard.BackgroundColor3 = Color3.fromRGB(26, 36, 68)
		pCard.Parent = podRow
		addCorner(pCard, 16)
		addBorderStroke(pCard, pod.Color, 2.4)

		local pTitle = Instance.new("TextLabel")
		pTitle.Size = UDim2.new(1, -16, 0, 26)
		pTitle.Position = UDim2.new(0, 8, 0, 8)
		pTitle.BackgroundTransparency = 1
		pTitle.Text = pod.Name
		pTitle.TextColor3 = pod.Color
		pTitle.Font = Enum.Font.FredokaOne
		pTitle.TextSize = 15
		pTitle.Parent = pCard
		addTextStroke(pTitle, 1.6)

		local pDesc = Instance.new("TextLabel")
		pDesc.Size = UDim2.new(1, -20, 0, 40)
		pDesc.Position = UDim2.new(0, 10, 0, 36)
		pDesc.BackgroundTransparency = 1
		pDesc.Text = pod.Description
		pDesc.TextColor3 = Color3.fromRGB(215, 226, 245)
		pDesc.Font = Enum.Font.GothamBold
		pDesc.TextSize = 11
		pDesc.TextWrapped = true
		pDesc.Parent = pCard

		local pCost = Instance.new("TextLabel")
		pCost.Size = UDim2.new(1, -16, 0, 22)
		pCost.Position = UDim2.new(0, 8, 0, 80)
		pCost.BackgroundTransparency = 1
		pCost.Text = string.format("Cost: %s 💎 Star Gems", PlanetConfig.FormatNumber(pod.GemCost))
		pCost.TextColor3 = Color3.fromRGB(255, 130, 240)
		pCost.Font = Enum.Font.FredokaOne
		pCost.TextSize = 14
		pCost.Parent = pCard
		addTextStroke(pCost, 1.4)

		local hatch1Btn = Instance.new("TextButton")
		hatch1Btn.Size = UDim2.new(0.48, -10, 0, 42)
		hatch1Btn.Position = UDim2.new(0, 10, 1, -50)
		hatch1Btn.BackgroundColor3 = pod.Color
		hatch1Btn.Text = "HATCH 1x"
		hatch1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		hatch1Btn.Font = Enum.Font.FredokaOne
		hatch1Btn.TextSize = 13
		hatch1Btn.Parent = pCard
		addCorner(hatch1Btn, 10)
		addBorderStroke(hatch1Btn, Color3.fromRGB(255, 255, 255), 1.6)
		addTextStroke(hatch1Btn, 1.6)

		local hatch3Btn = Instance.new("TextButton")
		hatch3Btn.Size = UDim2.new(0.52, -14, 0, 42)
		hatch3Btn.Position = UDim2.new(0.48, 4, 1, -50)
		hatch3Btn.BackgroundColor3 = Color3.fromRGB(245, 185, 45)
		hatch3Btn.Text = "⚡ HATCH 3x"
		hatch3Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		hatch3Btn.Font = Enum.Font.FredokaOne
		hatch3Btn.TextSize = 13
		hatch3Btn.Parent = pCard
		addCorner(hatch3Btn, 10)
		addBorderStroke(hatch3Btn, Color3.fromRGB(255, 255, 255), 1.6)
		addTextStroke(hatch3Btn, 1.6)

		hatch1Btn.MouseButton1Click:Connect(function()
			playSFX(sfxEvolve, 0.42)
			HatchCompanionPodEvent:FireServer(pod.Id, false)
		end)
		hatch3Btn.MouseButton1Click:Connect(function()
			playSFX(sfxEvolve, 0.48)
			HatchCompanionPodEvent:FireServer(pod.Id, true)
		end)
	end

	-- Action Bar: Equip Best & Craft All Golden (3 Identical -> 1 Golden 1.85x Stats!)
	local actRow = Instance.new("Frame")
	actRow.Size = UDim2.new(1, -16, 0, 44)
	actRow.BackgroundColor3 = Color3.fromRGB(24, 34, 62)
	actRow.Parent = dronesPage
	addCorner(actRow, 12)
	addBorderStroke(actRow, Color3.fromRGB(95, 165, 240), 1.8)

	droneSummaryLabel = Instance.new("TextLabel")
	droneSummaryLabel.Size = UDim2.new(1, -360, 1, 0)
	droneSummaryLabel.Position = UDim2.new(0, 14, 0, 0)
	droneSummaryLabel.BackgroundTransparency = 1
	droneSummaryLabel.Text = "🛸 Equipped Drones: 0 / 3  •  Total Bonus: 1.00x Yield"
	droneSummaryLabel.TextColor3 = Color3.fromRGB(115, 240, 185)
	droneSummaryLabel.Font = Enum.Font.FredokaOne
	droneSummaryLabel.TextSize = 13
	droneSummaryLabel.TextXAlignment = Enum.TextXAlignment.Left
	droneSummaryLabel.Parent = actRow
	addTextStroke(droneSummaryLabel, 1.4)

	local equipBestBtn = Instance.new("TextButton")
	equipBestBtn.Size = UDim2.new(0, 150, 0, 34)
	equipBestBtn.Position = UDim2.new(1, -328, 0.5, -17)
	equipBestBtn.BackgroundColor3 = Color3.fromRGB(45, 205, 115)
	equipBestBtn.Text = "⚡ EQUIP BEST"
	equipBestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipBestBtn.Font = Enum.Font.FredokaOne
	equipBestBtn.TextSize = 13
	equipBestBtn.Parent = actRow
	addCorner(equipBestBtn, 8)
	addBorderStroke(equipBestBtn, Color3.fromRGB(255, 255, 255), 1.5)
	addTextStroke(equipBestBtn, 1.5)

	local craftGoldBtn = Instance.new("TextButton")
	craftGoldBtn.Size = UDim2.new(0, 164, 0, 34)
	craftGoldBtn.Position = UDim2.new(1, -170, 0.5, -17)
	craftGoldBtn.BackgroundColor3 = Color3.fromRGB(245, 185, 40)
	craftGoldBtn.Text = "✨ CRAFT GOLDEN (3➔1)"
	craftGoldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	craftGoldBtn.Font = Enum.Font.FredokaOne
	craftGoldBtn.TextSize = 12
	craftGoldBtn.Parent = actRow
	addCorner(craftGoldBtn, 8)
	addBorderStroke(craftGoldBtn, Color3.fromRGB(255, 255, 255), 1.5)
	addTextStroke(craftGoldBtn, 1.5)

	equipBestBtn.MouseButton1Click:Connect(function()
		playSFX(sfxUpgrade, 0.38)
		CompanionActionEvent:FireServer("EquipBest")
	end)
	craftGoldBtn.MouseButton1Click:Connect(function()
		playSFX(sfxEvolve, 0.42)
		CompanionActionEvent:FireServer("CraftGolden")
	end)

	droneInventoryGridFrame = Instance.new("Frame")
	droneInventoryGridFrame.Size = UDim2.new(1, -16, 0, 260)
	droneInventoryGridFrame.AutomaticSize = Enum.AutomaticSize.Y
	droneInventoryGridFrame.BackgroundTransparency = 1
	droneInventoryGridFrame.Parent = dronesPage

	local invGrid = Instance.new("UIGridLayout")
	invGrid.CellSize = UDim2.new(0, 196, 0, 108)
	invGrid.CellPadding = UDim2.new(0, 10, 0, 10)
	invGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	invGrid.Parent = droneInventoryGridFrame
end

-- ============================================================================
-- 7C. BOOSTERS, PLAYTIME GIFTS & PROMO CODES PAGE (`boostsRewardsPage`)
-- ============================================================================
local giftButtonsUI: { [number]: { Btn: TextButton, StatusLbl: TextLabel } } = {}
local boosterButtonsUI: { [string]: { Btn: TextButton, TimerLbl: TextLabel } } = {}
do
	local bList = Instance.new("UIListLayout")
	bList.Padding = UDim.new(0, 12)
	bList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bList.Parent = boostsRewardsPage

	-- 1. Playtime Gift Milestones
	local giftHdr = Instance.new("TextLabel")
	giftHdr.Size = UDim2.new(1, -16, 0, 24)
	giftHdr.BackgroundTransparency = 1
	giftHdr.Text = "🎁 FREE SESSION PLAYTIME GIFTS (RESET EVERY SESSION!)"
	giftHdr.TextColor3 = Color3.fromRGB(255, 225, 85)
	giftHdr.Font = Enum.Font.FredokaOne
	giftHdr.TextSize = 15
	giftHdr.TextXAlignment = Enum.TextXAlignment.Left
	giftHdr.Parent = boostsRewardsPage
	addTextStroke(giftHdr, 1.5)

	local giftGridFrame = Instance.new("Frame")
	giftGridFrame.Size = UDim2.new(1, -16, 0, 168)
	giftGridFrame.BackgroundTransparency = 1
	giftGridFrame.Parent = boostsRewardsPage

	local gGrid = Instance.new("UIGridLayout")
	gGrid.CellSize = UDim2.new(0, 268, 0, 78)
	gGrid.CellPadding = UDim2.new(0, 10, 0, 10)
	gGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gGrid.Parent = giftGridFrame

	for _, gDef in ipairs(PlanetConfig.PlaytimeRewards) do
		local gCard = Instance.new("Frame")
		gCard.BackgroundColor3 = Color3.fromRGB(26, 36, 68)
		gCard.Parent = giftGridFrame
		addCorner(gCard, 12)
		addBorderStroke(gCard, Color3.fromRGB(255, 205, 75), 1.8)

		local gt = Instance.new("TextLabel")
		gt.Size = UDim2.new(1, -110, 0, 22)
		gt.Position = UDim2.new(0, 10, 0, 6)
		gt.BackgroundTransparency = 1
		gt.Text = "🎁 " .. (gDef.Label or gDef.Title or "Gift")
		gt.TextColor3 = Color3.fromRGB(255, 235, 110)
		gt.Font = Enum.Font.FredokaOne
		gt.TextSize = 13
		gt.TextXAlignment = Enum.TextXAlignment.Left
		gt.Parent = gCard
		addTextStroke(gt, 1.3)

		local gr = Instance.new("TextLabel")
		gr.Size = UDim2.new(1, -110, 0, 36)
		gr.Position = UDim2.new(0, 10, 0, 28)
		gr.BackgroundTransparency = 1
		gr.Text = gDef.RewardText or "Free Session Gift"
		gr.TextColor3 = Color3.fromRGB(125, 245, 185)
		gr.Font = Enum.Font.GothamBold
		gr.TextSize = 10
		gr.TextWrapped = true
		gr.TextXAlignment = Enum.TextXAlignment.Left
		gr.Parent = gCard

		local gBtn = Instance.new("TextButton")
		gBtn.Size = UDim2.new(0, 92, 0, 44)
		gBtn.Position = UDim2.new(1, -100, 0.5, -22)
		gBtn.BackgroundColor3 = Color3.fromRGB(55, 155, 235)
		gBtn.Text = "00:00"
		gBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		gBtn.Font = Enum.Font.FredokaOne
		gBtn.TextSize = 13
		gBtn.Parent = gCard
		addCorner(gBtn, 10)
		addBorderStroke(gBtn, Color3.fromRGB(255, 255, 255), 1.5)
		addTextStroke(gBtn, 1.5)

		gBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			ClaimPlaytimeGiftEvent:FireServer(gDef.Id)
		end)

		giftButtonsUI[gDef.Id] = { Btn = gBtn, StatusLbl = gr }
	end

	-- 2. Timed Gem Boosters Shop
	local boostHdr = Instance.new("TextLabel")
	boostHdr.Size = UDim2.new(1, -16, 0, 24)
	boostHdr.BackgroundTransparency = 1
	boostHdr.Text = "⚡ TIMED OVERDRIVE BOOSTERS (STACK DURATION WITH 💎 GEMS)"
	boostHdr.TextColor3 = Color3.fromRGB(95, 235, 255)
	boostHdr.Font = Enum.Font.FredokaOne
	boostHdr.TextSize = 15
	boostHdr.TextXAlignment = Enum.TextXAlignment.Left
	boostHdr.Parent = boostsRewardsPage
	addTextStroke(boostHdr, 1.5)

	local boostGridFrame = Instance.new("Frame")
	boostGridFrame.Size = UDim2.new(1, -16, 0, 178)
	boostGridFrame.BackgroundTransparency = 1
	boostGridFrame.Parent = boostsRewardsPage

	local bGrid = Instance.new("UIGridLayout")
	bGrid.CellSize = UDim2.new(0, 405, 0, 82)
	bGrid.CellPadding = UDim2.new(0, 12, 0, 10)
	bGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bGrid.Parent = boostGridFrame

	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local bCard = Instance.new("Frame")
		bCard.BackgroundColor3 = Color3.fromRGB(24, 34, 64)
		bCard.Parent = boostGridFrame
		addCorner(bCard, 12)
		addBorderStroke(bCard, bDef.Color, 2.0)

		local bt = Instance.new("TextLabel")
		bt.Size = UDim2.new(1, -150, 0, 22)
		bt.Position = UDim2.new(0, 12, 0, 6)
		bt.BackgroundTransparency = 1
		bt.Text = bDef.Icon .. " " .. bDef.Name
		bt.TextColor3 = bDef.Color
		bt.Font = Enum.Font.FredokaOne
		bt.TextSize = 14
		bt.TextXAlignment = Enum.TextXAlignment.Left
		bt.Parent = bCard
		addTextStroke(bt, 1.4)

		local bd = Instance.new("TextLabel")
		bd.Size = UDim2.new(1, -150, 0, 24)
		bd.Position = UDim2.new(0, 12, 0, 28)
		bd.BackgroundTransparency = 1
		bd.Text = bDef.Description
		bd.TextColor3 = Color3.fromRGB(215, 226, 245)
		bd.Font = Enum.Font.GothamBold
		bd.TextSize = 10
		bd.TextWrapped = true
		bd.TextXAlignment = Enum.TextXAlignment.Left
		bd.Parent = bCard

		local bTimer = Instance.new("TextLabel")
		bTimer.Size = UDim2.new(1, -150, 0, 18)
		bTimer.Position = UDim2.new(0, 12, 0, 56)
		bTimer.BackgroundTransparency = 1
		bTimer.Text = "Inactive (+15m per purchase)"
		bTimer.TextColor3 = Color3.fromRGB(255, 225, 105)
		bTimer.Font = Enum.Font.FredokaOne
		bTimer.TextSize = 11
		bTimer.TextXAlignment = Enum.TextXAlignment.Left
		bTimer.Parent = bCard
		addTextStroke(bTimer, 1.2)

		local bBtn = Instance.new("TextButton")
		bBtn.Size = UDim2.new(0, 128, 0, 44)
		bBtn.Position = UDim2.new(1, -138, 0.5, -22)
		bBtn.BackgroundColor3 = bDef.Color
		bBtn.Text = string.format("💎 %d GEMS", bDef.GemCost)
		bBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		bBtn.Font = Enum.Font.FredokaOne
		bBtn.TextSize = 13
		bBtn.Parent = bCard
		addCorner(bBtn, 10)
		addBorderStroke(bBtn, Color3.fromRGB(255, 255, 255), 1.6)
		addTextStroke(bBtn, 1.5)

		bBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			BuyBoosterEvent:FireServer(bDef.Id)
		end)

		boosterButtonsUI[bDef.Id] = { Btn = bBtn, TimerLbl = bTimer }
	end

	-- 3. Promo Code Redemption Bar
	local codeCard = Instance.new("Frame")
	codeCard.Size = UDim2.new(1, -16, 0, 56)
	codeCard.BackgroundColor3 = Color3.fromRGB(26, 36, 68)
	codeCard.Parent = boostsRewardsPage
	addCorner(codeCard, 12)
	addBorderStroke(codeCard, Color3.fromRGB(245, 130, 250), 2.0)

	local codeLbl = Instance.new("TextLabel")
	codeLbl.Size = UDim2.new(0, 350, 1, 0)
	codeLbl.Position = UDim2.new(0, 14, 0, 0)
	codeLbl.BackgroundTransparency = 1
	codeLbl.Text = "🎟️ CODES: COSMIC2026, STARFARER, GALAXY, GEMS500"
	codeLbl.TextColor3 = Color3.fromRGB(245, 175, 255)
	codeLbl.Font = Enum.Font.FredokaOne
	codeLbl.TextSize = 13
	codeLbl.TextXAlignment = Enum.TextXAlignment.Left
	codeLbl.Parent = codeCard
	addTextStroke(codeLbl, 1.4)

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(0, 260, 0, 36)
	codeBox.Position = UDim2.new(1, -430, 0.5, -18)
	codeBox.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
	codeBox.PlaceholderText = "Enter Code (e.g. COSMIC2026)"
	codeBox.Text = ""
	codeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	codeBox.Font = Enum.Font.FredokaOne
	codeBox.TextSize = 13
	codeBox.Parent = codeCard
	addCorner(codeBox, 8)
	addBorderStroke(codeBox, Color3.fromRGB(125, 185, 255), 1.5)

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0, 145, 0, 36)
	redeemBtn.Position = UDim2.new(1, -158, 0.5, -18)
	redeemBtn.BackgroundColor3 = Color3.fromRGB(55, 215, 120)
	redeemBtn.Text = "✓ REDEEM CODE"
	redeemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	redeemBtn.Font = Enum.Font.FredokaOne
	redeemBtn.TextSize = 13
	redeemBtn.Parent = codeCard
	addCorner(redeemBtn, 8)
	addBorderStroke(redeemBtn, Color3.fromRGB(255, 255, 255), 1.6)
	addTextStroke(redeemBtn, 1.5)

	redeemBtn.MouseButton1Click:Connect(function()
		if #codeBox.Text > 0 then
			playSFX(sfxUpgrade, 0.4)
			RedeemPromoCodeEvent:FireServer(codeBox.Text)
			codeBox.Text = ""
		end
	end)
end

-- ============================================================================
-- 8. BOTTOM-LEFT / CENTER 9-BUTTON DOCK & PROXIMITY MACHINE / STATION PROMPT
-- ============================================================================
local proximityPromptBtn = Instance.new("TextButton")
proximityPromptBtn.Name = "MachineProximityPrompt"
proximityPromptBtn.Size = UDim2.new(0, 480, 0, 44)
proximityPromptBtn.AnchorPoint = Vector2.new(0.5, 1)
proximityPromptBtn.Position = UDim2.new(0.5, -60, 1, -86)
proximityPromptBtn.BackgroundColor3 = Color3.fromRGB(24, 36, 72)
proximityPromptBtn.Text = "⚡ PRESS [E] OR CLICK TO OPEN MACHINE"
proximityPromptBtn.TextColor3 = Color3.fromRGB(255, 240, 110)
proximityPromptBtn.Font = Enum.Font.FredokaOne
proximityPromptBtn.TextSize = 14
proximityPromptBtn.Visible = false
proximityPromptBtn.Parent = inGameHUD
addCorner(proximityPromptBtn, 14)
local proxStroke = addBorderStroke(proximityPromptBtn, Color3.fromRGB(255, 225, 85), 2.5)
addTextStroke(proximityPromptBtn, 1.8)

local nearestHubMachineId: string? = nil
local nearestSpaceStationId: string? = nil

local function triggerNearestMachineUI()
	if nearestSpaceStationId then
		for _, st in ipairs(PlanetConfig.SpaceStations) do
			if st.Id == nearestSpaceStationId then
				local isUnlocked = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
				if not isUnlocked then
					playSFX(sfxEvolve, 0.45)
					UnlockSpaceStationEvent:FireServer(st.Id)
				else
					toggleTab("WarpAscend", "🛰️ DEEP-SPACE STATIONS, WARP GATES & ASCENSION")
				end
				return
			end
		end
	end
	if not nearestHubMachineId then
		return
	end
	if nearestHubMachineId == "WarpGate" then
		toggleTab("WarpAscend", "🛰️ DEEP-SPACE STATIONS, WARP GATES & ASCENSION")
	else
		openMachineModal(nearestHubMachineId)
	end
end

proximityPromptBtn.MouseButton1Click:Connect(triggerNearestMachineUI)

local bottomLeftDock = Instance.new("Frame")
bottomLeftDock.Size = UDim2.new(0, 740, 0, 64)
bottomLeftDock.AnchorPoint = Vector2.new(0, 1)
bottomLeftDock.Position = UDim2.new(0, 14, 1, -12)
bottomLeftDock.BackgroundTransparency = 1
bottomLeftDock.Parent = inGameHUD

local dockGrid = Instance.new("UIListLayout")
dockGrid.FillDirection = Enum.FillDirection.Horizontal
dockGrid.Padding = UDim.new(0, 6)
dockGrid.VerticalAlignment = Enum.VerticalAlignment.Bottom
dockGrid.Parent = bottomLeftDock

local function makeSimulatorActionBtn(icon: string, label: string, topC: Color3, botC: Color3, onClick: () -> ())
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 76, 0, 56)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = ""
	btn.Parent = bottomLeftDock
	addCorner(btn, 14)
	addBorderStroke(btn, Color3.fromRGB(255, 255, 255), 2.0)
	addGradient(btn, topC, botC, 90)
	attachBounceAndSFX(btn)

	local ic = Instance.new("TextLabel")
	ic.Size = UDim2.new(1, 0, 0, 26)
	ic.Position = UDim2.new(0, 0, 0, 4)
	ic.BackgroundTransparency = 1
	ic.Text = icon
	ic.TextColor3 = Color3.fromRGB(255, 255, 255)
	ic.Font = Enum.Font.FredokaOne
	ic.TextSize = 20
	ic.Parent = btn
	addTextStroke(ic, 1.8)

	local lb = Instance.new("TextLabel")
	lb.Size = UDim2.new(1, 0, 0, 16)
	lb.Position = UDim2.new(0, 0, 1, -18)
	lb.BackgroundTransparency = 1
	lb.Text = label
	lb.TextColor3 = Color3.fromRGB(255, 255, 255)
	lb.Font = Enum.Font.FredokaOne
	lb.TextSize = 10
	lb.Parent = btn
	addTextStroke(lb, 1.5)

	btn.MouseButton1Click:Connect(onClick)
end

makeSimulatorActionBtn("⬆️", "UPGRADE", Color3.fromRGB(250, 205, 55), Color3.fromRGB(205, 130, 18), function()
	toggleTab("PlanetValue", "⬆️ PLANET SYSTEMS & SIZE UPGRADES")
end)

makeSimulatorActionBtn("🛸", "DRONES", Color3.fromRGB(95, 235, 195), Color3.fromRGB(25, 145, 115), function()
	toggleTab("Drones", "🛸 ORBITAL COMPANION DRONES (HATCH, EQUIP & GOLDEN CRAFT)")
end)

makeSimulatorActionBtn("🎁", "BOOSTS", Color3.fromRGB(255, 145, 65), Color3.fromRGB(195, 65, 18), function()
	toggleTab("BoostsRewards", "🎁 PLAYTIME GIFTS, TIMED GEM BOOSTERS & PROMO CODES")
end)

makeSimulatorActionBtn("🧬", "EVOLVE", Color3.fromRGB(190, 95, 250), Color3.fromRGB(115, 35, 200), function()
	toggleTab("Evolution", "🧬 SPECIES EVOLUTION TREE (4 BALANCED PATHS)")
end)

makeSimulatorActionBtn("🌀", "STATIONS", Color3.fromRGB(235, 95, 195), Color3.fromRGB(165, 30, 125), function()
	toggleTab("WarpAscend", "🛰️ DEEP-SPACE STATIONS, WARP GATES & ASCENSION")
end)

-- ============================================================================
-- 9. EVOLUTION TREE & 6-TRACK PLANET UPGRADES PAGES
-- ============================================================================
local evoNodeButtons: { [string]: { Button: TextButton, Stroke: UIStroke } } = {}

local evoList = Instance.new("UIListLayout")
evoList.Padding = UDim.new(0, 10)
evoList.Parent = evolutionPage

for _, bInfo in ipairs(SpeciesConfig.BranchOrder) do
	local branchRow = Instance.new("Frame")
	branchRow.Size = UDim2.new(1, -12, 0, 132)
	branchRow.BackgroundColor3 = Color3.fromRGB(26, 36, 68)
	branchRow.Parent = evolutionPage
	addCorner(branchRow, 14)
	addBorderStroke(branchRow, bInfo.Color, 2)

	local bHdr = Instance.new("TextLabel")
	bHdr.Size = UDim2.new(0, 175, 1, -16)
	bHdr.Position = UDim2.new(0, 12, 0, 8)
	bHdr.BackgroundTransparency = 1
	bHdr.Text = (bInfo.Title or bInfo.Name) .. "\n\n" .. (bInfo.Subtitle or "")
	bHdr.TextColor3 = bInfo.Color
	bHdr.Font = Enum.Font.FredokaOne
	bHdr.TextSize = 13
	bHdr.TextWrapped = true
	bHdr.TextXAlignment = Enum.TextXAlignment.Left
	bHdr.Parent = branchRow
	addTextStroke(bHdr, 1.5)

	local nContainer = Instance.new("Frame")
	nContainer.Size = UDim2.new(1, -198, 1, -14)
	nContainer.Position = UDim2.new(0, 192, 0, 7)
	nContainer.BackgroundTransparency = 1
	nContainer.Parent = branchRow

	local nGrid = Instance.new("UIGridLayout")
	nGrid.CellSize = UDim2.new(0, 148, 1, 0)
	nGrid.CellPadding = UDim2.new(0, 10, 0, 0)
	nGrid.Parent = nContainer

	local branchNodes = {}
	for _, node in pairs(SpeciesConfig.EvolutionNodes) do
		if node.Branch == bInfo.Id then
			table.insert(branchNodes, node)
		end
	end
	table.sort(branchNodes, function(a, b)
		return a.Tier < b.Tier
	end)

	for _, node in ipairs(branchNodes) do
		local nCard = Instance.new("Frame")
		nCard.BackgroundColor3 = Color3.fromRGB(18, 24, 46)
		nCard.Parent = nContainer
		addCorner(nCard, 10)
		local nStroke = addBorderStroke(nCard, bInfo.Color, 1.8)

		local nTitle = Instance.new("TextLabel")
		nTitle.Size = UDim2.new(1, -10, 0, 20)
		nTitle.Position = UDim2.new(0, 5, 0, 4)
		nTitle.BackgroundTransparency = 1
		nTitle.Text = string.format("T%d: %s", node.Tier, node.Name)
		nTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		nTitle.Font = Enum.Font.FredokaOne
		nTitle.TextSize = 11
		nTitle.TextWrapped = true
		nTitle.Parent = nCard
		addTextStroke(nTitle, 1.4)

		local nPerk = Instance.new("TextLabel")
		nPerk.Size = UDim2.new(1, -10, 0, 38)
		nPerk.Position = UDim2.new(0, 5, 0, 25)
		nPerk.BackgroundTransparency = 1
		nPerk.Text = node.PerkSummary
		nPerk.TextColor3 = Color3.fromRGB(120, 240, 185)
		nPerk.Font = Enum.Font.GothamBold
		nPerk.TextSize = 10
		nPerk.TextWrapped = true
		nPerk.Parent = nCard

		local nCost = Instance.new("TextLabel")
		nCost.Size = UDim2.new(1, -10, 0, 16)
		nCost.Position = UDim2.new(0, 5, 0, 64)
		nCost.BackgroundTransparency = 1
		nCost.Text = formatCost(node.Cost)
		nCost.TextColor3 = Color3.fromRGB(255, 225, 105)
		nCost.Font = Enum.Font.FredokaOne
		nCost.TextSize = 10
		nCost.Parent = nCard
		addTextStroke(nCost, 1.2)

		local nBtn = Instance.new("TextButton")
		nBtn.Size = UDim2.new(1, -12, 0, 28)
		nBtn.Position = UDim2.new(0, 6, 1, -33)
		nBtn.BackgroundColor3 = bInfo.Color
		nBtn.Text = "EVOLVE"
		nBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		nBtn.Font = Enum.Font.FredokaOne
		nBtn.TextSize = 12
		nBtn.Parent = nCard
		addCorner(nBtn, 6)
		addTextStroke(nBtn, 1.5)

		nBtn.MouseButton1Click:Connect(function()
			playSFX(sfxEvolve, 0.45)
			UnlockEvolutionEvent:FireServer(node.Id)
		end)

		evoNodeButtons[node.Id] = { Button = nBtn, Stroke = nStroke }
	end
end

-- Planet Value Upgrades Grid (6 Upgrade Tracks with +1 Level & BUY MAX!)
local upgGrid = Instance.new("UIGridLayout")
upgGrid.CellSize = UDim2.new(0, 392, 0, 164)
upgGrid.CellPadding = UDim2.new(0, 14, 0, 14)
upgGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
upgGrid.Parent = planetValuePage

local upgradeCardsUI: { [string]: { LevelLabel: TextLabel, CostLabel: TextLabel, BuyOneBtn: TextButton, BuyMaxBtn: TextButton } } = {}

for _, upg in ipairs(PlanetConfig.PlanetUpgrades) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(28, 38, 70)
	card.Parent = planetValuePage
	addCorner(card, 16)
	addBorderStroke(card, Color3.fromRGB(245, 195, 65), 2.2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -120, 0, 26)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = upg.Name
	title.TextColor3 = Color3.fromRGB(255, 225, 95)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	addTextStroke(title, 1.8)

	local lvlLbl = Instance.new("TextLabel")
	lvlLbl.Size = UDim2.new(0, 100, 0, 24)
	lvlLbl.Position = UDim2.new(1, -112, 0, 9)
	lvlLbl.BackgroundTransparency = 1
	lvlLbl.Text = "Lv. 0 / 75"
	lvlLbl.TextColor3 = Color3.fromRGB(85, 230, 250)
	lvlLbl.Font = Enum.Font.FredokaOne
	lvlLbl.TextSize = 14
	lvlLbl.TextXAlignment = Enum.TextXAlignment.Right
	lvlLbl.Parent = card
	addTextStroke(lvlLbl, 1.6)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -28, 0, 42)
	desc.Position = UDim2.new(0, 14, 0, 36)
	desc.BackgroundTransparency = 1
	desc.Text = upg.Description
	desc.TextColor3 = Color3.fromRGB(215, 226, 245)
	desc.Font = Enum.Font.GothamBold
	desc.TextSize = 11
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = card

	local costLbl = Instance.new("TextLabel")
	costLbl.Size = UDim2.new(1, -28, 0, 20)
	costLbl.Position = UDim2.new(0, 14, 0, 82)
	costLbl.BackgroundTransparency = 1
	costLbl.Text = "Cost: ..."
	costLbl.TextColor3 = Color3.fromRGB(105, 245, 165)
	costLbl.Font = Enum.Font.FredokaOne
	costLbl.TextSize = 13
	costLbl.TextXAlignment = Enum.TextXAlignment.Left
	costLbl.Parent = card
	addTextStroke(costLbl, 1.4)

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.62, -18, 0, 40)
	buyBtn.Position = UDim2.new(0, 14, 1, -48)
	buyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Text = "⬆️ UPGRADE (+1)"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextSize = 14
	buyBtn.Parent = card
	addCorner(buyBtn, 10)
	addBorderStroke(buyBtn, Color3.fromRGB(255, 255, 255), 1.8)
	addGradient(buyBtn, Color3.fromRGB(70, 230, 115), Color3.fromRGB(22, 165, 62), 90)
	addTextStroke(buyBtn, 1.8)

	local buyMaxBtn = Instance.new("TextButton")
	buyMaxBtn.Size = UDim2.new(0.38, -14, 0, 40)
	buyMaxBtn.Position = UDim2.new(0.62, 4, 1, -48)
	buyMaxBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	buyMaxBtn.Text = "⚡ BUY MAX"
	buyMaxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyMaxBtn.Font = Enum.Font.FredokaOne
	buyMaxBtn.TextSize = 13
	buyMaxBtn.Parent = card
	addCorner(buyMaxBtn, 10)
	addBorderStroke(buyMaxBtn, Color3.fromRGB(255, 255, 255), 1.8)
	addGradient(buyMaxBtn, Color3.fromRGB(245, 185, 45), Color3.fromRGB(205, 105, 15), 90)
	addTextStroke(buyMaxBtn, 1.8)

	buyBtn.MouseButton1Click:Connect(function()
		playSFX(sfxUpgrade, 0.38)
		UpgradePlanetValueEvent:FireServer(upg.Id, false)
	end)

	buyMaxBtn.MouseButton1Click:Connect(function()
		playSFX(sfxUpgrade, 0.38)
		UpgradePlanetValueEvent:FireServer(upg.Id, true)
	end)

	upgradeCardsUI[upg.Id] = { LevelLabel = lvlLbl, CostLabel = costLbl, BuyOneBtn = buyBtn, BuyMaxBtn = buyMaxBtn }
end

-- ============================================================================
-- 9B. 3D ORBITING COMPANION DRONES MANAGER
-- ============================================================================
local activeDroneModels: { { Model: Model, Phase: number } } = {}
local lastDroneSignature = ""

local function rebuildOrbitingDrones()
	local owned = currentState.Companions or currentState.OwnedCompanions or {}
	local sigParts = {}
	for _, entry in ipairs(owned) do
		if entry.Equipped then
			local isGold = (entry.IsGolden == true) or (entry.Golden == true)
			table.insert(sigParts, tostring(entry.Uid) .. ":" .. tostring(entry.Id) .. ":" .. tostring(isGold))
		end
	end
	local sig = table.concat(sigParts, "|")
	if sig == lastDroneSignature then
		return
	end
	lastDroneSignature = sig

	for _, d in ipairs(activeDroneModels) do
		if d.Model then
			d.Model:Destroy()
		end
	end
	table.clear(activeDroneModels)

	if not currentState.HasCompletedSetup then
		return
	end

	local idx = 0
	for _, entry in ipairs(owned) do
		if entry.Equipped then
			idx += 1
			local isGold = (entry.IsGolden == true) or (entry.Golden == true)
			local dm = PlanetGenerator.BuildCompanionDroneModel(entry.Id, isGold)
			dm.Parent = Workspace
			table.insert(activeDroneModels, {
				Model = dm,
				Phase = idx * ((math.pi * 2) / math.max(1, #sigParts)),
			})
		end
	end
end

-- ============================================================================
-- 10. STATE SYNC & LIVE UI REFRESH
-- ============================================================================
local function getMissionProgressLocal(goalType: string): number
	if goalType == "TotalUpgrades" then
		local s = 0
		for _, v in pairs(currentState.PlanetUpgrades or {}) do
			s += (v or 0)
		end
		return s
	elseif goalType == "TotalMachineTiers" or goalType == "MachineTiers" then
		local s = 0
		for _, v in pairs(currentState.MachineTiers or {}) do
			s += (v or 0)
		end
		return s
	elseif goalType == "OrbsHarvested" then
		return currentState.OrbsHarvested or 0
	elseif goalType == "UnlockedEvolutions" then
		local c = 0
		for _, v in pairs(currentState.UnlockedEvolutions or {}) do
			if v then
				c += 1
			end
		end
		return c
	elseif goalType == "StationsUnlocked" or goalType == "UnlockedStations" then
		local c = 0
		for _, v in pairs(currentState.UnlockedStations or {}) do
			if v then
				c += 1
			end
		end
		return math.max(0, c - 1)
	elseif goalType == "DronesHatched" or goalType == "CompanionsHatched" then
		return currentState.DronesHatched or #(currentState.Companions or {})
	elseif goalType == "DrillLevel" then
		return (currentState.Rates and currentState.Rates.DrillPower) or 0
	elseif goalType == "PlanetValue" then
		return currentState.PlanetValueScore or 0
	end
	return 0
end

local function formatSecondsMMSS(sec: number): string
	local s = math.max(0, math.floor(sec))
	local m = math.floor(s / 60)
	local r = s % 60
	return string.format("%02d:%02d", m, r)
end

refreshUI = function()
	genesisContainer.Visible = not currentState.HasCompletedSetup
	inGameHUD.Visible = currentState.HasCompletedSetup

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, currentState.HasCompletedSetup)
	end)

	refreshShowroomAndActivePlanetModels()
	rebuildOrbitingDrones()

	if not currentState.HasCompletedSetup then
		local pt = PlanetConfig.PlanetTypes[currentState.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
		local sp = SpeciesConfig.Species[currentState.SpeciesId] or SpeciesConfig.Species.Terranauts
		local covName = currentState.Look.LandCoverage or "MajorContinents"
		for _, cDef in ipairs(PlanetConfig.LandCoverages) do
			if cDef.Id == covName then
				covName = cDef.Name
				break
			end
		end
		playSummaryLabel.Text = string.format(
			"• Planet Name: %s\n• Planet Class: %s (%s)\n• Continent Coverage: %s\n• Land Material: %s\n• Water Material: %s\n• Surface Landmarks: %s\n• Founding Species: %s\n\n✅ Class Pros: %s",
			tostring(currentState.Look.PlanetName),
			pt.Name,
			pt.Tagline,
			covName,
			tostring(currentState.Look.LandMaterial),
			tostring(currentState.Look.WaterMaterial),
			tostring(currentState.Look.SurfaceFeature),
			sp.Name,
			table.concat(pt.Advantages, ", ")
		)

		for lookKey, btnMap in pairs(lookOptionButtons) do
			local activeVal = (currentState.Look :: any)[lookKey]
			for id, ui in pairs(btnMap) do
				if id == activeVal then
					ui.Button.BackgroundColor3 = Color3.fromRGB(35, 160, 95)
					ui.Stroke.Color = Color3.fromRGB(100, 250, 150)
					ui.Stroke.Thickness = 2.8
				else
					ui.Button.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
					ui.Stroke.Color = Color3.fromRGB(255, 255, 255)
					ui.Stroke.Thickness = 1.4
				end
			end
		end

		for spId, ui in pairs(speciesSelectButtons) do
			if spId == currentState.SpeciesId then
				ui.Button.Text = "✓ SELECTED SPECIES"
				ui.Button.BackgroundColor3 = Color3.fromRGB(45, 210, 115)
				ui.Stroke.Thickness = 3.2
			else
				local sDef = SpeciesConfig.Species[spId]
				ui.Button.Text = "SELECT SPECIES"
				ui.Button.BackgroundColor3 = sDef.PrimaryColor
				ui.Stroke.Thickness = 1.8
			end
		end
	end

	local rates = currentState.Rates

	statCards.Gems.ValueLabel.Text = PlanetConfig.FormatNumber(currentState.Gems or 0)
	statCards.Gems.RateLabel.Text = string.format("💎 Star Gems (+%s/s)", PlanetConfig.FormatNumber(rates.Gems or 2.5))

	statCards.Population.ValueLabel.Text = PlanetConfig.FormatNumber(currentState.Population) .. "M"
	local sp = SpeciesConfig.Species[currentState.SpeciesId] or SpeciesConfig.Species.Terranauts
	statCards.Population.RateLabel.Text = sp.Name

	statCards.PlanetValue.ValueLabel.Text = PlanetConfig.FormatNumber(currentState.PlanetValueScore)
	local evo = SpeciesConfig.EvolutionNodes[currentState.ActiveEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening
	statCards.PlanetValue.RateLabel.Text = evo.Name

	statCards.CosmicShards.ValueLabel.Text = PlanetConfig.FormatNumber(currentState.CosmicShards or 0)
	statCards.CosmicShards.RateLabel.Text = "🪐 Cosmic Shards"

	-- Update Booster & Next Space Station Tracker Bar
	local ownedDrones = currentState.Companions or {}
	local eqCount = 0
	for _, entry in ipairs(ownedDrones) do
		if entry.Equipped then
			eqCount += 1
		end
	end
	local maxSlots = currentState.MaxEquippedDrones or rates.MaxEquippedDrones or 3
	local activeBoostTags = {}
	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local rem = (currentState.ActiveBoosters and currentState.ActiveBoosters[bDef.Id]) or 0
		if rem > 0 then
			table.insert(activeBoostTags, string.format("%s %s", bDef.Icon, formatSecondsMMSS(rem)))
		end
	end
	local nextStationText = "All Space Stations Unlocked!"
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		local isUnl = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
		if not isUnl then
			local d = math.floor((st.Position - localPlanetPos).Magnitude)
			nextStationText = string.format("🛰️ Next Gate: %s (%s studs • %s 💎)", st.Name, PlanetConfig.FormatNumber(d), PlanetConfig.FormatNumber(st.GemCost))
			break
		end
	end
	local boostSummary = (#activeBoostTags > 0) and (" • Boosts: " .. table.concat(activeBoostTags, " ")) or ""
	boosterStatusLbl.Text = string.format(
		"🌌 Zone %d • 🛸 Drones: %d/%d • %s%s",
		rates.CurrentZoneTier or 1,
		eqCount,
		maxSlots,
		nextStationText,
		boostSummary
	)

	-- Update Planetary Rank & Next Rank Progress Bar
	local rIdx = currentState.RankIndex or 1
	local rankDef = PlanetConfig.PlanetaryRanks[rIdx] or PlanetConfig.PlanetaryRanks[1]
	local nextRankDef = PlanetConfig.PlanetaryRanks[rIdx + 1]
	local ascCount = currentState.Ascensions or 0
	local ascMult = math.pow(2.5, ascCount)
	local ascTag = (ascCount > 0) and string.format(" • 🌟 Asc.%d (%sx)", ascCount, PlanetConfig.FormatNumber(ascMult)) or ""

	rankTitleLbl.Text = string.format(
		"🏆 RANK %d: %s (%sx Yield)%s",
		rankDef.Rank,
		string.upper(rankDef.Title),
		PlanetConfig.FormatNumber(rankDef.YieldMultiplier),
		ascTag
	)
	rankTitleLbl.TextColor3 = rankDef.BadgeColor

	if nextRankDef then
		local span = math.max(1, nextRankDef.MinValue - rankDef.MinValue)
		local prog = math.clamp((currentState.PlanetValueScore - rankDef.MinValue) / span, 0, 1)
		rankBarFill.Size = UDim2.new(prog, 0, 1, 0)
		rankBarText.Text = string.format(
			"Planet Value: %s / %s  ➔  Next: %s (%s)",
			PlanetConfig.FormatNumber(currentState.PlanetValueScore),
			PlanetConfig.FormatNumber(nextRankDef.MinValue),
			nextRankDef.Title,
			nextRankDef.RewardDesc
		)
	else
		rankBarFill.Size = UDim2.new(1, 0, 1, 0)
		rankBarText.Text = string.format("MAX PLANETARY RANK ACHIEVED! (Value: %s)", PlanetConfig.FormatNumber(currentState.PlanetValueScore))
	end

	-- Update Zone & Sector Banner
	if rates.ActiveDistrictName and #rates.ActiveDistrictName > 0 then
		zoneTitleLbl.Text = string.format("★ %s • Press [E] to Interact!", rates.ActiveDistrictName)
		zoneTitleLbl.TextColor3 = Color3.fromRGB(255, 230, 95)
	else
		local zTier = rates.CurrentZoneTier or 1
		local zDef = PlanetConfig.DeepSpaceZones[zTier] or PlanetConfig.DeepSpaceZones[1]
		zoneTitleLbl.Text = string.format("🌌 %s • WASD + Shift", rates.CurrentSectorName or zDef.Name)
		zoneTitleLbl.TextColor3 = zDef.ThemeColor
	end

	-- Update Guided Mission Card
	local mIdx = currentState.MissionIndex or 1
	local mDef = PlanetConfig.Missions[mIdx]
	if mDef then
		missionHeader.Text = string.format("🎯 MISSION #%d: %s", mDef.Id, string.upper(mDef.Title))
		missionDescLbl.Text = mDef.Description
		local curProg = getMissionProgressLocal(mDef.GoalType)
		local ratio = math.clamp(curProg / math.max(1, mDef.Target), 0, 1)
		missionBarFill.Size = UDim2.new(ratio, 0, 1, 0)
		missionBarText.Text = string.format("%s / %s", PlanetConfig.FormatNumber(curProg), PlanetConfig.FormatNumber(mDef.Target))
		missionRewardLbl.Text = "🎁 Reward: " .. formatCost(mDef.Reward)
	else
		missionHeader.Text = "🏆 ALL MISSIONS COMPLETED!"
		missionDescLbl.Text = "Open 🌀 STATIONS to Unlock Deep-Space Gates or Ascend your planet!"
		missionBarFill.Size = UDim2.new(1, 0, 1, 0)
		missionBarText.Text = "COMPLETE"
		missionRewardLbl.Text = "🌟 Ready for Planetary Ascension!"
	end

	-- Update Hub Machine Cards UI
	local mTiers = currentState.MachineTiers or {}
	local machineBases: { [string]: { Base: number, Label: string } } = {
		DysonReactor = { Base = 0.42, Label = "Energy & All-Yield Boost" },
		TitanRefinery = { Base = 0.48, Label = "Minerals & +🔨 Drill Power" },
		GaiaBioVat = { Base = 0.45, Label = "Biomass & Citizen Wave" },
		AstralObservatory = { Base = 0.50, Label = "Tech & Gem Discovery" },
	}
	for mId, ui in pairs(machineCardsUI) do
		local mConfig = PlanetConfig.HubMachines[mId]
		local tier = mTiers[mId] or 0
		local bInfo = machineBases[mId]
		ui.TierLabel.Text = string.format("Tier %d / %d", tier, mConfig.MaxTier)

		local curMult = (1 + tier * bInfo.Base) * math.pow(1.35, math.floor(tier / 5))
		local nxtMult = (1 + (tier + 1) * bInfo.Base) * math.pow(1.35, math.floor((tier + 1) / 5))
		ui.EffectLabel.Text = string.format(
			"Current: %sx %s  ➔  Next Tier: %sx",
			PlanetConfig.FormatNumber(curMult),
			bInfo.Label,
			PlanetConfig.FormatNumber(nxtMult)
		)

		if tier >= mConfig.MaxTier then
			ui.CostLabel.Text = "MAXIMUM OVERCLOCK TIER REACHED!"
			ui.BuyOneBtn.Text = "✓ MAXED OUT"
			ui.BuyMaxBtn.Text = "✓ MAX"
		else
			local mult = math.pow(mConfig.CostScale, tier)
			local cTable = {
				Minerals = mConfig.BaseCost.Minerals and math.floor(mConfig.BaseCost.Minerals * mult) or nil,
				Biomass = mConfig.BaseCost.Biomass and math.floor(mConfig.BaseCost.Biomass * mult) or nil,
				Energy = mConfig.BaseCost.Energy and math.floor(mConfig.BaseCost.Energy * mult) or nil,
				Tech = mConfig.BaseCost.Tech and math.floor(mConfig.BaseCost.Tech * mult) or nil,
			}
			ui.CostLabel.Text = "Next Tier Cost: " .. formatCost(cTable)
			ui.BuyOneBtn.Text = mConfig.ActionButtonText
			ui.BuyMaxBtn.Text = "⚡ MAX OVERCLOCK"
		end
	end

	-- Update Deep-Space Stations, Ascension & Cosmic Shard Shop UI
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		local ui = warpStationBtns[st.Id]
		if ui then
			local isUnlocked = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
			if isUnlocked then
				ui.Btn.Text = "🌀 WARP HERE"
				ui.Btn.BackgroundColor3 = st.Color
				ui.ReqLabel.Text = "✓ WARP GATE UNLOCKED & ACTIVE!"
				ui.ReqLabel.TextColor3 = Color3.fromRGB(105, 245, 165)
			else
				ui.Btn.Text = string.format("🔓 UNLOCK (%s 💎)", PlanetConfig.FormatNumber(st.GemCost))
				local canUnlock = (currentState.Gems or 0) >= st.GemCost
				ui.Btn.BackgroundColor3 = canUnlock and Color3.fromRGB(55, 215, 120) or Color3.fromRGB(85, 75, 115)
				ui.ReqLabel.Text = string.format(
					"Unlock Cost: %s 💎 Star Gems",
					PlanetConfig.FormatNumber(st.GemCost)
				)
				ui.ReqLabel.TextColor3 = canUnlock and Color3.fromRGB(255, 230, 105) or Color3.fromRGB(255, 115, 115)
			end
		end
	end

	local reqAscVal = math.floor(32000 * math.pow(4.2, ascCount))
	ascensionInfoLabel.Text = string.format(
		"Current Ascensions: %d (%sx Permanent All-Yield Multiplier) • 🪐 Cosmic Shards: %s\nNext Ascension Requires: %s Planet Value Score (Keep Gems, Stations & Drones!)",
		ascCount,
		PlanetConfig.FormatNumber(ascMult),
		PlanetConfig.FormatNumber(currentState.CosmicShards or 0),
		PlanetConfig.FormatNumber(reqAscVal)
	)

	for _, sUpg in ipairs(PlanetConfig.ShardUpgrades) do
		local ui = shardUpgBtns[sUpg.Id]
		if ui then
			local lvl = (currentState.ShardUpgrades and currentState.ShardUpgrades[sUpg.Id]) or 0
			ui.LvlLabel.Text = string.format("Lv. %d / %d", lvl, sUpg.MaxLevel)
			if lvl >= sUpg.MaxLevel then
				ui.Btn.Text = "✓ MAXED"
				ui.Btn.BackgroundColor3 = Color3.fromRGB(65, 80, 110)
			else
				local cost = math.floor(sUpg.BaseShardCost * math.pow(sUpg.CostScale, lvl))
				ui.Btn.Text = string.format("🪐 %d SHARDS", cost)
				ui.Btn.BackgroundColor3 = ((currentState.CosmicShards or 0) >= cost) and Color3.fromRGB(165, 65, 235) or Color3.fromRGB(75, 60, 95)
			end
		end
	end

	-- Update Drones Inventory Grid
	if droneSummaryLabel then
		droneSummaryLabel.Text = string.format(
			"🛸 Equipped Drones: %d / %d  •  Total Drone Bonus: %sx All Yields  •  Owned: %d",
			eqCount,
			maxSlots,
			PlanetConfig.FormatNumber(rates.CompanionMult or 1),
			#ownedDrones
		)
	end
	if droneInventoryGridFrame then
		for _, ch in ipairs(droneInventoryGridFrame:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		for _, entry in ipairs(ownedDrones) do
			local cDef = PlanetConfig.Companions[entry.Id]
			if cDef then
				local isGold = (entry.IsGolden == true) or (entry.Golden == true)
				local gMult = isGold and 1.85 or 1.0
				local dCard = Instance.new("Frame")
				dCard.BackgroundColor3 = entry.Equipped and Color3.fromRGB(28, 52, 68) or Color3.fromRGB(22, 30, 56)
				dCard.Parent = droneInventoryGridFrame
				addCorner(dCard, 12)
				addBorderStroke(dCard, isGold and Color3.fromRGB(255, 215, 55) or cDef.Color, entry.Equipped and 2.6 or 1.6)

				local dName = Instance.new("TextLabel")
				dName.Size = UDim2.new(1, -12, 0, 22)
				dName.Position = UDim2.new(0, 6, 0, 4)
				dName.BackgroundTransparency = 1
				dName.Text = (isGold and "✨ GOLDEN " or "🛸 ") .. cDef.Name
				dName.TextColor3 = isGold and Color3.fromRGB(255, 225, 75) or cDef.Color
				dName.Font = Enum.Font.FredokaOne
				dName.TextSize = 12
				dName.TextWrapped = true
				dName.Parent = dCard
				addTextStroke(dName, 1.3)

				local dRarity = Instance.new("TextLabel")
				dRarity.Size = UDim2.new(1, -12, 0, 16)
				dRarity.Position = UDim2.new(0, 6, 0, 26)
				dRarity.BackgroundTransparency = 1
				dRarity.Text = cDef.Rarity
				dRarity.TextColor3 = Color3.fromRGB(205, 220, 245)
				dRarity.Font = Enum.Font.GothamBold
				dRarity.TextSize = 10
				dRarity.Parent = dCard

				local dStats = Instance.new("TextLabel")
				dStats.Size = UDim2.new(1, -12, 0, 28)
				dStats.Position = UDim2.new(0, 6, 0, 42)
				dStats.BackgroundTransparency = 1
				dStats.Text = string.format(
					"%.2fx Yield • %.2fx 💎 • +%d Spd",
					cDef.YieldMult * gMult,
					cDef.GemMult * gMult,
					math.floor(cDef.SpeedBonus * gMult + 0.5)
				)
				dStats.TextColor3 = Color3.fromRGB(115, 245, 180)
				dStats.Font = Enum.Font.FredokaOne
				dStats.TextSize = 10
				dStats.TextWrapped = true
				dStats.Parent = dCard
				addTextStroke(dStats, 1.1)

				local eqBtn = Instance.new("TextButton")
				eqBtn.Size = UDim2.new(1, -16, 0, 26)
				eqBtn.Position = UDim2.new(0, 8, 1, -31)
				eqBtn.BackgroundColor3 = entry.Equipped and Color3.fromRGB(45, 210, 115) or Color3.fromRGB(52, 74, 128)
				eqBtn.Text = entry.Equipped and "✓ EQUIPPED" or "EQUIP DRONE"
				eqBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				eqBtn.Font = Enum.Font.FredokaOne
				eqBtn.TextSize = 11
				eqBtn.Parent = dCard
				addCorner(eqBtn, 6)
				addTextStroke(eqBtn, 1.3)

				local uidCopy = entry.Uid
				eqBtn.MouseButton1Click:Connect(function()
					playSFX(sfxClick, 0.32)
					CompanionActionEvent:FireServer("ToggleEquip", uidCopy)
				end)
			end
		end
	end

	-- Update Playtime Gifts & Boosters UI
	local pSec = currentState.PlaytimeSeconds or 0
	for _, gDef in ipairs(PlanetConfig.PlaytimeRewards) do
		local ui = giftButtonsUI[gDef.Id]
		if ui then
			local claimed = currentState.ClaimedPlaytimeGifts
				and (currentState.ClaimedPlaytimeGifts[gDef.Id] == true or currentState.ClaimedPlaytimeGifts[tostring(gDef.Id)] == true)
			if claimed then
				ui.Btn.Text = "✓ CLAIMED"
				ui.Btn.BackgroundColor3 = Color3.fromRGB(55, 70, 95)
			elseif pSec >= gDef.TimeReq then
				ui.Btn.Text = "🎁 CLAIM!"
				ui.Btn.BackgroundColor3 = Color3.fromRGB(45, 215, 115)
			else
				ui.Btn.Text = formatSecondsMMSS(gDef.TimeReq - pSec)
				ui.Btn.BackgroundColor3 = Color3.fromRGB(55, 135, 215)
			end
		end
	end

	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local ui = boosterButtonsUI[bDef.Id]
		if ui then
			local rem = (currentState.ActiveBoosters and currentState.ActiveBoosters[bDef.Id]) or 0
			if rem > 0 then
				ui.TimerLbl.Text = "⚡ ACTIVE: " .. formatSecondsMMSS(rem) .. " remaining"
				ui.TimerLbl.TextColor3 = Color3.fromRGB(105, 250, 165)
			else
				ui.TimerLbl.Text = "Inactive (+15m per purchase)"
				ui.TimerLbl.TextColor3 = Color3.fromRGB(215, 225, 245)
			end
		end
	end

	-- Update Evolution Tree Buttons
	for nodeId, ui in pairs(evoNodeButtons) do
		local node = SpeciesConfig.EvolutionNodes[nodeId]
		local isUnlocked = currentState.UnlockedEvolutions[nodeId] == true
		local isActive = currentState.ActiveEvolutionId == nodeId
		local parentUnlocked = (node.ParentId == nil) or (currentState.UnlockedEvolutions[node.ParentId] == true)

		if isActive then
			ui.Button.Text = "★ ACTIVE"
			ui.Button.BackgroundColor3 = Color3.fromRGB(45, 215, 120)
			ui.Stroke.Color = Color3.fromRGB(45, 215, 120)
		elseif isUnlocked then
			ui.Button.Text = "EQUIP FOCUS"
			ui.Button.BackgroundColor3 = Color3.fromRGB(55, 145, 230)
			ui.Stroke.Color = Color3.fromRGB(55, 145, 230)
		elseif parentUnlocked then
			ui.Button.Text = "EVOLVE"
			ui.Button.BackgroundColor3 = node.VisualTrait.GlowColor
			ui.Stroke.Color = node.VisualTrait.GlowColor
		else
			ui.Button.Text = "LOCKED"
			ui.Button.BackgroundColor3 = Color3.fromRGB(48, 56, 82)
			ui.Stroke.Color = Color3.fromRGB(40, 48, 70)
		end
	end

	-- Update Planet Upgrades Grid
	for _, upg in ipairs(PlanetConfig.PlanetUpgrades) do
		local cardUI = upgradeCardsUI[upg.Id]
		if cardUI then
			local lvl = currentState.PlanetUpgrades[upg.Id] or 0
			cardUI.LevelLabel.Text = string.format("Lv. %d / %d", lvl, upg.MaxLevel)

			if lvl >= upg.MaxLevel then
				cardUI.CostLabel.Text = "MAX LEVEL REACHED!"
				cardUI.BuyOneBtn.Text = "✓ MAXED OUT"
				cardUI.BuyMaxBtn.Text = "✓ MAX"
			else
				local mult = math.pow(upg.CostScale, lvl)
				local cTable = {
					Gems = upg.BaseCost.Gems and math.floor(upg.BaseCost.Gems * mult) or nil,
				}
				cardUI.CostLabel.Text = "Cost: " .. formatCost(cTable)
				cardUI.BuyOneBtn.Text = "⬆️ UPGRADE (+1)"
				cardUI.BuyMaxBtn.Text = "⚡ BUY MAX"
			end
		end
	end
end

-- ============================================================================
-- 11. 3D CAMERA, FLIGHT CONTROLS, ORBITING DRONES & STATION DETECTOR
-- ============================================================================
local camYaw = 0
local camPitch = -0.18
local camDist = 92
local creatorOrbitYaw = 0.35
local creatorOrbitPitch = -0.15
local creatorZoom = 56
local isRightMouseDown = false
local droneOrbitClock = 0

local moveKeys = {
	W = false,
	A = false,
	S = false,
	D = false,
	E = false,
	Q = false,
	Space = false,
	LeftShift = false,
	LeftControl = false,
}

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightMouseDown = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
	if gameProcessed then
		return
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.W then
		moveKeys.W = true
	elseif kc == Enum.KeyCode.S then
		moveKeys.S = true
	elseif kc == Enum.KeyCode.A then
		moveKeys.A = true
	elseif kc == Enum.KeyCode.D then
		moveKeys.D = true
	elseif kc == Enum.KeyCode.Space then
		moveKeys.Space = true
	elseif kc == Enum.KeyCode.Q or kc == Enum.KeyCode.LeftControl then
		moveKeys.Q = true
	elseif kc == Enum.KeyCode.LeftShift then
		moveKeys.LeftShift = true
	elseif kc == Enum.KeyCode.E or kc == Enum.KeyCode.F then
		if currentState.HasCompletedSetup and (nearestHubMachineId or nearestSpaceStationId) then
			triggerNearestMachineUI()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightMouseDown = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.W then
		moveKeys.W = false
	elseif kc == Enum.KeyCode.S then
		moveKeys.S = false
	elseif kc == Enum.KeyCode.A then
		moveKeys.A = false
	elseif kc == Enum.KeyCode.D then
		moveKeys.D = false
	elseif kc == Enum.KeyCode.Space then
		moveKeys.Space = false
	elseif kc == Enum.KeyCode.Q or kc == Enum.KeyCode.LeftControl then
		moveKeys.Q = false
	elseif kc == Enum.KeyCode.LeftShift then
		moveKeys.LeftShift = false
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseMovement and isRightMouseDown then
		if not currentState.HasCompletedSetup then
			creatorOrbitYaw -= input.Delta.X * 0.005
			creatorOrbitPitch = math.clamp(creatorOrbitPitch - input.Delta.Y * 0.005, -1.1, 1.1)
		else
			camYaw -= input.Delta.X * 0.0045
			camPitch = math.clamp(camPitch - input.Delta.Y * 0.0045, -1.25, 1.25)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		if not currentState.HasCompletedSetup then
			creatorZoom = math.clamp(creatorZoom - input.Position.Z * 5, 34, 95)
		else
			camDist = math.clamp(camDist - input.Position.Z * 8, 46, 260)
		end
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local rotSpeed = getRotationSpeedValue()
	hideServerDuplicateOfMyPlanet()

	-- 2D MENU PHASE: Animate the 3D Planet & Species inside `mainViewport`
	if not currentState.HasCompletedSetup then
		spinAngle += dt * rotSpeed * 1.35
		if vpPlanetModel then
			vpPlanetModel:PivotTo(CFrame.new(-7, 2, 0) * CFrame.Angles(0, spinAngle, math.rad(8)))
		end
		if vpSpeciesModel then
			vpSpeciesModel:PivotTo(CFrame.new(18, -3, 4) * CFrame.Angles(0, -spinAngle * 0.55, 0))
		end

		local lookTarget = Vector3.new(2, 0, 0)
		local orbitRot = CFrame.fromEulerAnglesYXZ(creatorOrbitPitch, creatorOrbitYaw, 0)
		local vpCamPos = lookTarget + (orbitRot * Vector3.new(0, 4, creatorZoom))
		mainViewportCam.CFrame = CFrame.lookAt(vpCamPos, lookTarget)
		sfxThrusterLoop.Volume = 0
		return
	end

	-- ACTIVE THIRD-PERSON PLANET GAMEPLAY IN OPEN SPACE!
	if not localActivePlanetModel or not localActivePlanetModel.Parent then
		refreshShowroomAndActivePlanetModels()
	end

	local camRot = CFrame.fromEulerAnglesYXZ(camPitch, camYaw, 0)
	local lookForward = camRot.LookVector
	local lookRight = camRot.RightVector

	local moveDir = Vector3.zero
	local strafeInput = 0
	local forwardInput = 0
	if moveKeys.W then
		moveDir += lookForward
		forwardInput += 1
	end
	if moveKeys.S then
		moveDir -= lookForward
		forwardInput -= 1
	end
	if moveKeys.D then
		moveDir += lookRight
		strafeInput += 1
	end
	if moveKeys.A then
		moveDir -= lookRight
		strafeInput -= 1
	end
	if moveKeys.Space then
		moveDir += Vector3.new(0, 1, 0)
	end
	if moveKeys.Q then
		moveDir -= Vector3.new(0, 1, 0)
	end

	local baseSpeed = (currentState.Rates and currentState.Rates.FlightSpeed) or 135
	local isBoosting = moveKeys.LeftShift and (moveDir.Magnitude > 0.01)
	local boostMult = isBoosting and 2.1 or 1.0

	if moveDir.Magnitude > 0.01 then
		moveDir = moveDir.Unit
	end

	local targetVel = moveDir * (baseSpeed * boostMult)
	localVelocity = localVelocity:Lerp(targetVel, math.clamp(dt * 7.5, 0, 1))
	local nextPos = localPlanetPos + localVelocity * dt
	localPlanetPos = Vector3.new(
		math.clamp(nextPos.X, -250000, 250000),
		math.clamp(nextPos.Y, -25000, 25000),
		math.clamp(nextPos.Z, -250000, 250000)
	)

	-- Update Infinite 3D Scattered Starfield around the player
	updateInfiniteStarfield(localPlanetPos)

	-- Dynamic Axial Spin + Smooth Flight Banking
	spinAngle += dt * rotSpeed * (isBoosting and 2.0 or 1.0)
	local targetRoll = -strafeInput * math.rad(14)
	local targetPitch = -forwardInput * math.rad(9)
	currentBankRoll = currentBankRoll + (targetRoll - currentBankRoll) * math.clamp(dt * 6, 0, 1)
	currentBankPitch = currentBankPitch + (targetPitch - currentBankPitch) * math.clamp(dt * 6, 0, 1)

	local planetTiltCF = CFrame.fromEulerAnglesYXZ(0, camYaw, 0)
		* CFrame.Angles(currentBankPitch, 0, currentBankRoll)
		* CFrame.Angles(0, spinAngle - camYaw, math.rad(8))

	if localActivePlanetModel then
		localActivePlanetModel:PivotTo(CFrame.new(localPlanetPos) * planetTiltCF)
		local rootPart = localActivePlanetModel.PrimaryPart
		if rootPart then
			local wake = rootPart:FindFirstChild("PlanetarySlipstreamVFX") :: ParticleEmitter?
			if wake then
				local spd = localVelocity.Magnitude
				wake.Rate = (spd > 15) and math.floor(math.clamp(spd * 0.14, 6, 28)) or 0
			end
		end
	end

	-- Orbit Equipped 3D Companion Drones Smoothly Around the Player's Planet!
	droneOrbitClock += dt * 1.85
	local pScale = getLocalPlanetScaleFactor()
	local orbitRad = 24 * pScale + 8
	for i, dInfo in ipairs(activeDroneModels) do
		if dInfo.Model and dInfo.Model.Parent then
			local ang = droneOrbitClock + dInfo.Phase
			local bobY = math.sin(droneOrbitClock * 2.2 + i * 1.4) * 3.2
			local dPos = localPlanetPos + Vector3.new(math.cos(ang) * orbitRad, bobY + 4, math.sin(ang) * orbitRad)
			dInfo.Model:PivotTo(CFrame.new(dPos) * CFrame.Angles(0, -ang + math.pi / 2, math.rad(8)))
		end
	end

	-- Authentic Low-Frequency Space Thruster Audio (Silent when stopped!)
	local speedMag = localVelocity.Magnitude
	local speedRatio = math.clamp(speedMag / (baseSpeed * 2.1), 0, 1)
	if speedMag > 8 and userSettings.ThrusterHum > 0 and userSettings.SfxVolume > 0 then
		sfxThrusterLoop.Volume = speedRatio * 0.14 * userSettings.ThrusterHum * userSettings.SfxVolume
		sfxThrusterLoop.PlaybackSpeed = 0.68 + speedRatio * 0.32
	else
		sfxThrusterLoop.Volume = 0
	end

	-- Check Proximity to Hub Machines OR Deep-Space Outpost Stations
	local foundMachine: string? = nil
	local foundDist = math.huge
	for mId, mDef in pairs(PlanetConfig.HubMachines) do
		local d = (localPlanetPos - mDef.Position).Magnitude
		if d <= (mDef.InteractRadius + 25) and d < foundDist then
			foundDist = d
			foundMachine = mId
		end
	end
	nearestHubMachineId = foundMachine

	local foundStation: any = nil
	local foundStationDist = math.huge
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		if st.Id ~= "Hub" then
			local d = (localPlanetPos - st.Position).Magnitude
			if d <= (st.DockRadius + 55) and d < foundStationDist then
				foundStationDist = d
				foundStation = st
			end
		end
	end
	nearestSpaceStationId = foundStation and foundStation.Id or nil

	if foundStation then
		local isUnl = currentState.UnlockedStations and currentState.UnlockedStations[foundStation.Id] == true
		proximityPromptBtn.Visible = true
		proxStroke.Color = foundStation.Color
		if isUnl then
			proximityPromptBtn.Text = string.format("🛰️ PRESS [E] AT %s: OPEN WARP NETWORK", string.upper(foundStation.Name))
		else
			proximityPromptBtn.Text = string.format(
				"🔓 PRESS [E] TO UNLOCK %s WARP GATE (%s 💎)",
				string.upper(foundStation.Name),
				PlanetConfig.FormatNumber(foundStation.GemCost)
			)
		end
	elseif foundMachine then
		local mDef = PlanetConfig.HubMachines[foundMachine]
		proximityPromptBtn.Visible = true
		proximityPromptBtn.Text = string.format("%s PRESS [E] OR CLICK TO OPEN: %s", mDef.Icon, string.upper(mDef.Name))
		proxStroke.Color = mDef.ThemeColor
	else
		proximityPromptBtn.Visible = false
	end

	-- Smooth Camera FOV on Boost
	local targetFOV = isBoosting and (userSettings.BaseFOV + 12) or userSettings.BaseFOV
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * math.clamp(dt * 8, 0, 1)

	syncTimer += dt
	if syncTimer >= 0.065 then
		syncTimer = 0
		FlightSyncEvent:FireServer(localPlanetPos, spinAngle, currentBankRoll, currentBankPitch)
	end

	local camPos = localPlanetPos + (camRot * Vector3.new(0, 14, camDist))
	local lookAtTarget = localPlanetPos + Vector3.new(0, 3, 0)
	camera.CFrame = CFrame.lookAt(camPos, lookAtTarget)
end)

StateSyncEvent.OnClientEvent:Connect(function(newState: any)
	local wasSetup = currentState.HasCompletedSetup
	currentState = newState
	if newState.PlanetPosition and (not wasSetup or (newState.PlanetPosition - localPlanetPos).Magnitude > 85) then
		localPlanetPos = newState.PlanetPosition
	end
	refreshUI()
end)

switchMainMenuTab("Play")
refreshUI()
RequestInitialStateEvent:FireServer()
