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
local BuyDroneSlotEvent = Remotes:WaitForChild("BuyDroneSlot") :: RemoteEvent
local SetDroneTargetEvent = Remotes:WaitForChild("SetDroneTarget") :: RemoteEvent
local DroneBeamFXEvent = Remotes:WaitForChild("DroneBeamFX") :: RemoteEvent
local EvolveDronePathEvent = Remotes:WaitForChild("EvolveDronePath") :: RemoteEvent
local DetonateStickyBombsEvent = Remotes:WaitForChild("DetonateStickyBombs") :: RemoteEvent
local StickyBombFXEvent = Remotes:WaitForChild("StickyBombFX") :: RemoteEvent
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
	Gems = 0,
	CosmicShards = 0,
	Level = 1,
	XP = 0,
	XPToNextLevel = 45,
	UpgradePoints = 0,
	Population = 1.0,
	PlanetValueScore = 100,
	RankIndex = 1,
	Ascensions = 0,
	MissionIndex = 1,
	OrbsHarvested = 0,
	DronesHatched = 1,
	DroneLevels = 0,
	DroneSlotLevel = 0,
	DronePathClassId = "BasicDrone",
	StickyBombCount = 0,
	PlaytimeSeconds = 0,
	ClaimedPlaytimeGifts = {},
	RedeemedCodes = {},
	UnlockedStations = { Hub = true },
	ActiveBoosters = { YieldBoost = 0, GemBoost = 0, SpeedBoost = 0 },
	ShardUpgrades = { PermValue = 0, PermGems = 0, ExtraDroneSlots = 0, PermSpeed = 0 },
	Companions = {
		{
			Uid = "Drone_PathMain",
			Id = "BasicDrone",
			Level = 1,
			IsGolden = false,
			Equipped = true,
		},
	},
	MaxEquippedDrones = 5,
	Look = table.clone(PlanetConfig.DefaultPlanetLook),
	SpeciesId = "Terranauts",
	UnlockedEvolutions = { Awakening = true },
	ActiveEvolutionId = "Awakening",
	PlanetUpgrades = {
		DroneAttackDamage = 0,
		DroneReloadSpeed = 0,
		CoreDensity = 0,
		BiosphereFertility = 0,
		MagnetosphereDynamo = 0,
		OrbitalInfrastructure = 0,
		CivilizationMetropolis = 0,
		AnomalyHarvester = 0,
	},
	MachineTiers = {},
	Rates = {
		Gems = 0,
		Minerals = 0,
		Biomass = 0,
		Energy = 0,
		Tech = 0,
		FlightSpeed = 135,
		DrillPower = 0,
		DroneDamage = 0,
		DroneDamageMult = 1.0,
		FireCooldown = 0.45,
		DrillSpeed = 1.0,
		DroneDPS = 7,
		EquippedDroneCount = 0,
		GlobalYieldMult = 1.0,
		GemMultiplier = 1.0,
		CompanionMult = 1.0,
		InHubSanctuary = true,
		ActiveDistrictName = "",
		CurrentSectorName = "Zone 1: Inner Sanctuary Orbit  •  1x Node Loot",
		CurrentZoneTier = 1,
		CurrentZoneReqDrill = 1,
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

local lastStarUpdatePos = Vector3.new(999999, 999999, 999999)
local lastStarDensity = -1

local function updateInfiniteStarfield(centerPos: Vector3)
	if (centerPos - lastStarUpdatePos).Magnitude < 14 and userSettings.StarDensity == lastStarDensity then
		return
	end
	lastStarUpdatePos = centerPos
	lastStarDensity = userSettings.StarDensity

	local boxX, boxY, boxZ = 1800, 1100, 1800
	local halfX, halfY, halfZ = boxX * 0.5, boxY * 0.5, boxZ * 0.5
	for idx, item in ipairs(starPool) do
		if idx <= userSettings.StarDensity then
			local dx = (item.Offset.X - centerPos.X) % boxX
			local dy = (item.Offset.Y - centerPos.Y) % boxY
			local dz = (item.Offset.Z - centerPos.Z) % boxZ
			local wx = centerPos.X + dx - halfX
			local wy = centerPos.Y + dy - halfY
			local wz = centerPos.Z + dz - halfZ
			local worldPos = Vector3.new(wx, wy, wz)
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
local lastBuilt2DMenuSignature = ""

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

local hiddenServerModels: { [Instance]: boolean } = {}
local function hideServerDuplicateOfMyPlanet(forceScan: boolean?)
	local folder = Workspace:FindFirstChild("PlayerPlanets")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == localPlayer.UserId then
			if forceScan or not hiddenServerModels[model] then
				hiddenServerModels[model] = true
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

local function addBorderStroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = math.min(thickness or 1.2, 1.5)
	s.Transparency = 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addTextStroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(6, 9, 18)
	s.Thickness = math.min(thickness or 1.0, 1.1)
	s.Transparency = 0.45
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
menuBrandTitle.Font = Enum.Font.GothamBlack
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
local isCustomizingOverlayOpen = false

local function is2DMenuActive(): boolean
	return (not currentState.HasCompletedSetup) or isCustomizingOverlayOpen
end

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
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 15
	b.Parent = menuNavBtnsContainer
	addCorner(b, 10)
	addBorderStroke(b, Color3.fromRGB(255, 255, 255), 1.5)
	addTextStroke(b, 1.5)
	b.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.28, 0.08)
		if tabDef.Id == "Play" and (activeMenuTab == "Play" or isCustomizingOverlayOpen) and launchIntoHub then
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
	hideServerDuplicateOfMyPlanet(true)
	local sig = computePlanetSignature()

	if is2DMenuActive() then
		if sig ~= lastBuilt2DMenuSignature or not vpPlanetModel then
			lastBuilt2DMenuSignature = sig
			rebuild2DMenuPreviewModels()
		end
		if not currentState.HasCompletedSetup and localActivePlanetModel then
			localActivePlanetModel:Destroy()
			localActivePlanetModel = nil
			lastBuiltPlanetSignature = ""
		end
	end

	if currentState.HasCompletedSetup and not isCustomizingOverlayOpen then
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
				true
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
	local wasFirstSetup = not currentState.HasCompletedSetup
	isCustomizingOverlayOpen = false
	currentState.HasCompletedSetup = true
	if wasFirstSetup then
		localPlanetPos = HUB_SPAWN_POS
		localVelocity = Vector3.zero
	end
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
playLeftHdr.Font = Enum.Font.GothamBlack
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
openCustomizeFromPlayBtn.Font = Enum.Font.GothamBlack
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
randomizePlanetBtn.Font = Enum.Font.GothamBlack
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
playRightHdr.Font = Enum.Font.GothamBlack
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
openSettingsFromPlayBtn.Font = Enum.Font.GothamBlack
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
nameTag.Font = Enum.Font.GothamBlack
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
planetNameInput.Font = Enum.Font.GothamBlack
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
	b.Font = Enum.Font.GothamBlack
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
	hdr.Font = Enum.Font.GothamBlack
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
		lbl.Font = Enum.Font.GothamBlack
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
	ptHeader.Font = Enum.Font.GothamBlack
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
		tLbl.Font = Enum.Font.GothamBlack
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
	chHdr.Font = Enum.Font.GothamBlack
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
		b.Font = Enum.Font.GothamBlack
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
	palHdr.Font = Enum.Font.GothamBlack
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
		sb.Font = Enum.Font.GothamBlack
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
		hdr.Font = Enum.Font.GothamBlack
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
			mb.Font = Enum.Font.GothamBlack
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
	spinHdr.Font = Enum.Font.GothamBlack
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
		rb.Font = Enum.Font.GothamBlack
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
rightHeaderLbl.Font = Enum.Font.GothamBlack
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
	sName.Font = Enum.Font.GothamBlack
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
	sStats.Font = Enum.Font.GothamBlack
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
	pickBtn.Font = Enum.Font.GothamBlack
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
settingsHdr.Font = Enum.Font.GothamBlack
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
	lbl.Font = Enum.Font.GothamBlack
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
	cycleBtn.Font = Enum.Font.GothamBlack
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
launchBtn.Font = Enum.Font.GothamBlack
launchBtn.TextSize = 21
launchBtn.Parent = genesisContainer
addCorner(launchBtn, 18)
addBorderStroke(launchBtn, Color3.fromRGB(255, 255, 255), 3.0)
addGradient(launchBtn, Color3.fromRGB(65, 225, 110), Color3.fromRGB(22, 160, 62), 90)
addTextStroke(launchBtn, 2.2)
attachBounceAndSFX(launchBtn)

launchBtn.MouseButton1Click:Connect(launchIntoHub)

-- ============================================================================
-- 6. IN-GAME SIMULATOR HUD (TOP-CHART ROBLOX SIMULATOR BEVELED UI)
-- ============================================================================
local inGameHUD = Instance.new("Frame")
inGameHUD.Name = "SimulatorInGameHUD"
inGameHUD.Size = UDim2.new(1, 0, 1, 0)
inGameHUD.BackgroundTransparency = 1
inGameHUD.Visible = true
inGameHUD.Parent = screenGui

-- Helper for custom generated UI icons in `rbxasset://cosmic_ui/`
local CUSTOM_UI_ICONS = {
	Drones = "rbxasset://cosmic_ui/icon_drones.png",
	Shop = "rbxasset://cosmic_ui/icon_shop.png",
	Quests = "rbxasset://cosmic_ui/icon_quests.png",
	Stations = "rbxasset://cosmic_ui/icon_stations.png",
	Evolve = "rbxasset://cosmic_ui/icon_evolve.png",
	Customize = "rbxasset://cosmic_ui/icon_customize.png",
}

-- Forward declaration for modal tab opener used by top-left [+] buttons
local toggleTab: (tabKey: string, titleText: string) -> ()
local openMachineModal: (machineId: string?) -> ()

-- A. TOP-CENTER SLANTED STATUS BANNER + ORANGE-RED SUB-BANNER (Hover/Click expands Telemetry & Quests)
local topInfoPinned = false
local topBarHovered = false
local topDrawerHovered = false

local topCompactBtn = Instance.new("TextButton")
topCompactBtn.Name = "TopStatusBanner"
topCompactBtn.Size = UDim2.new(0, 316, 0, 44)
topCompactBtn.AnchorPoint = Vector2.new(0.5, 0)
topCompactBtn.Position = UDim2.new(0.5, 0, 0, 10)
topCompactBtn.BackgroundColor3 = Color3.fromRGB(20, 27, 45)
topCompactBtn.AutoButtonColor = false
topCompactBtn.Text = ""
topCompactBtn.Visible = false
topCompactBtn.Parent = nil
addCorner(topCompactBtn, 10)
local topCompactStroke = addBorderStroke(topCompactBtn, Color3.fromRGB(8, 12, 22), 3.0)

-- Decorative racing stripes on the right of the top banner (matching reference screenshot)
do
	local stripe1 = Instance.new("Frame")
	stripe1.Size = UDim2.new(0, 14, 1, 0)
	stripe1.Position = UDim2.new(1, -54, 0, 0)
	stripe1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	stripe1.BackgroundTransparency = 0.78
	stripe1.BorderSizePixel = 0
	stripe1.Parent = topCompactBtn

	local stripe2 = Instance.new("Frame")
	stripe2.Size = UDim2.new(0, 8, 1, 0)
	stripe2.Position = UDim2.new(1, -34, 0, 0)
	stripe2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	stripe2.BackgroundTransparency = 0.84
	stripe2.BorderSizePixel = 0
	stripe2.Parent = topCompactBtn

	local topBannerIcon = Instance.new("TextLabel")
	topBannerIcon.Size = UDim2.new(0, 32, 0, 32)
	topBannerIcon.Position = UDim2.new(0, 10, 0.5, -16)
	topBannerIcon.BackgroundTransparency = 1
	topBannerIcon.Text = "🪐"
	topBannerIcon.TextSize = 20
	topBannerIcon.Font = Enum.Font.GothamBlack
	topBannerIcon.Parent = topCompactBtn
end

local topCompactSummaryLbl = Instance.new("TextLabel")
topCompactSummaryLbl.Size = UDim2.new(1, -84, 0, 22)
topCompactSummaryLbl.Position = UDim2.new(0, 42, 0, 3)
topCompactSummaryLbl.BackgroundTransparency = 1
topCompactSummaryLbl.Text = "NOW: Sanctuary Orbit"
topCompactSummaryLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
topCompactSummaryLbl.Font = Enum.Font.GothamBlack
topCompactSummaryLbl.TextSize = 15
topCompactSummaryLbl.Parent = topCompactBtn
addTextStroke(topCompactSummaryLbl, 2.0)

local topCompactBadge = Instance.new("TextLabel")
topCompactBadge.Size = UDim2.new(1, -84, 0, 16)
topCompactBadge.Position = UDim2.new(0, 42, 0, 24)
topCompactBadge.BackgroundTransparency = 1
topCompactBadge.Text = "0/2 Drones  •  Hover for Info"
topCompactBadge.TextColor3 = Color3.fromRGB(200, 218, 245)
topCompactBadge.Font = Enum.Font.GothamBold
topCompactBadge.TextSize = 11
topCompactBadge.Parent = topCompactBtn
addTextStroke(topCompactBadge, 1.4)

-- Orange-Red Sub-Banner directly underneath ("🔥 DRILL: 1 • DPS: 7", matching "🔥 RALLY x8")
local topRallyBanner = Instance.new("TextButton")
topRallyBanner.Name = "TopOrangeSubBanner"
topRallyBanner.Size = UDim2.new(0, 210, 0, 24)
topRallyBanner.AnchorPoint = Vector2.new(0.5, 0)
topRallyBanner.Position = UDim2.new(0.5, 0, 0, 56)
topRallyBanner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topRallyBanner.AutoButtonColor = false
topRallyBanner.Text = ""
topRallyBanner.Visible = false
topRallyBanner.Parent = nil
addCorner(topRallyBanner, 7)
addBorderStroke(topRallyBanner, Color3.fromRGB(10, 14, 24), 2.5)
addGradient(topRallyBanner, Color3.fromRGB(255, 92, 38), Color3.fromRGB(214, 42, 22), 90)

local topRallyText = Instance.new("TextLabel")
topRallyText.Size = UDim2.new(1, -12, 1, 0)
topRallyText.Position = UDim2.new(0, 6, 0, 0)
topRallyText.BackgroundTransparency = 1
topRallyText.Text = "🔥 DRILL x1  •  DPS 7"
topRallyText.TextColor3 = Color3.fromRGB(255, 255, 255)
topRallyText.Font = Enum.Font.GothamBlack
topRallyText.TextSize = 12
topRallyText.Parent = topRallyBanner
addTextStroke(topRallyText, 1.8)

-- Prominent Player Level & Live XP Progress Bar (Only element at Top-Center!)
local levelXPBarBg = Instance.new("Frame")
levelXPBarBg.Name = "TopLevelXPBar"
levelXPBarBg.Size = UDim2.new(0, 340, 0, 28)
levelXPBarBg.AnchorPoint = Vector2.new(0.5, 0)
levelXPBarBg.Position = UDim2.new(0.5, 0, 0, 14)
levelXPBarBg.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
levelXPBarBg.Parent = inGameHUD
addCorner(levelXPBarBg, 10)
addBorderStroke(levelXPBarBg, Color3.fromRGB(10, 14, 24), 2.8)

local levelXPBarFill = Instance.new("Frame")
levelXPBarFill.Size = UDim2.new(0, 0, 1, 0)
levelXPBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
levelXPBarFill.BorderSizePixel = 0
levelXPBarFill.Parent = levelXPBarBg
addCorner(levelXPBarFill, 10)
addGradient(levelXPBarFill, Color3.fromRGB(255, 225, 65), Color3.fromRGB(235, 155, 20), 0)

local levelXPBarText = Instance.new("TextLabel")
levelXPBarText.Size = UDim2.new(1, -12, 1, 0)
levelXPBarText.Position = UDim2.new(0, 6, 0, 0)
levelXPBarText.BackgroundTransparency = 1
levelXPBarText.Text = "⭐ LEVEL 1  •  0 / 45 XP"
levelXPBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
levelXPBarText.Font = Enum.Font.GothamBlack
levelXPBarText.TextSize = 13
levelXPBarText.ZIndex = 2
levelXPBarText.Parent = levelXPBarBg
addTextStroke(levelXPBarText, 1.8)

-- A1-DIEP. DIEP.IO LIVE EVOLUTION CHOICE BANNER (Auto-appears below XP bar at Level 3 & Level 8!)
local isDiepBannerMinimized = false
local diepToggleBtn: TextButton
local diepEvoPanel: Frame
local diepCardsRow: Frame
local lastDiepSig = ""
local updateDiepEvoBanner: () -> ()
do
	diepToggleBtn = Instance.new("TextButton")
	diepToggleBtn.Name = "DiepEvoToggleChip"
	diepToggleBtn.Size = UDim2.new(0, 210, 0, 24)
	diepToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
	diepToggleBtn.Position = UDim2.new(0.5, 0, 0, 46)
	diepToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	diepToggleBtn.Text = "🧬 DRONE EVOLUTION READY! [SHOW]"
	diepToggleBtn.TextColor3 = Color3.fromRGB(16, 26, 12)
	diepToggleBtn.Font = Enum.Font.GothamBlack
	diepToggleBtn.TextSize = 11
	diepToggleBtn.Visible = false
	diepToggleBtn.ZIndex = 7
	diepToggleBtn.Parent = inGameHUD
	addCorner(diepToggleBtn, 8)
	addBorderStroke(diepToggleBtn, Color3.fromRGB(10, 16, 10), 2.2)
	addGradient(diepToggleBtn, Color3.fromRGB(128, 255, 75), Color3.fromRGB(58, 205, 32), 90)

	diepEvoPanel = Instance.new("Frame")
	diepEvoPanel.Name = "DiepEvoChoiceBanner"
	diepEvoPanel.Size = UDim2.new(0, 620, 0, 142)
	diepEvoPanel.AnchorPoint = Vector2.new(0.5, 0)
	diepEvoPanel.Position = UDim2.new(0.5, 0, 0, 46)
	diepEvoPanel.BackgroundColor3 = Color3.fromRGB(18, 28, 56)
	diepEvoPanel.BackgroundTransparency = 0.06
	diepEvoPanel.Visible = false
	diepEvoPanel.ZIndex = 7
	diepEvoPanel.Parent = inGameHUD
	addCorner(diepEvoPanel, 14)
	addBorderStroke(diepEvoPanel, Color3.fromRGB(10, 14, 24), 3.0)
	addGradient(diepEvoPanel, Color3.fromRGB(38, 62, 120), Color3.fromRGB(18, 30, 64), 90)

	local diepHeaderLbl = Instance.new("TextLabel")
	diepHeaderLbl.Size = UDim2.new(1, -90, 0, 22)
	diepHeaderLbl.Position = UDim2.new(0, 12, 0, 4)
	diepHeaderLbl.BackgroundTransparency = 1
	diepHeaderLbl.Text = "🧬 BASIC DRONE UPGRADE READY (LV.5) — CHOOSE 1 OF 5 PATHS!"
	diepHeaderLbl.TextColor3 = Color3.fromRGB(128, 255, 95)
	diepHeaderLbl.Font = Enum.Font.GothamBlack
	diepHeaderLbl.TextSize = 12
	diepHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
	diepHeaderLbl.ZIndex = 8
	diepHeaderLbl.Parent = diepEvoPanel
	addTextStroke(diepHeaderLbl, 1.5)

	local diepMinBtn = Instance.new("TextButton")
	diepMinBtn.Size = UDim2.new(0, 66, 0, 20)
	diepMinBtn.Position = UDim2.new(1, -74, 0, 5)
	diepMinBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 78)
	diepMinBtn.Text = "HIDE"
	diepMinBtn.TextColor3 = Color3.fromRGB(220, 232, 255)
	diepMinBtn.Font = Enum.Font.GothamBlack
	diepMinBtn.TextSize = 10
	diepMinBtn.ZIndex = 8
	diepMinBtn.Parent = diepEvoPanel
	addCorner(diepMinBtn, 6)
	addBorderStroke(diepMinBtn, Color3.fromRGB(10, 14, 24), 1.8)

	diepCardsRow = Instance.new("Frame")
	diepCardsRow.Size = UDim2.new(1, -16, 1, -32)
	diepCardsRow.Position = UDim2.new(0, 8, 0, 28)
	diepCardsRow.BackgroundTransparency = 1
	diepCardsRow.ZIndex = 8
	diepCardsRow.Parent = diepEvoPanel

	local diepCardsLayout = Instance.new("UIListLayout")
	diepCardsLayout.FillDirection = Enum.FillDirection.Horizontal
	diepCardsLayout.Padding = UDim.new(0, 8)
	diepCardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	diepCardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	diepCardsLayout.Parent = diepCardsRow

	diepMinBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.25)
		isDiepBannerMinimized = true
		if updateDiepEvoBanner then
			updateDiepEvoBanner()
		end
	end)
	diepToggleBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.25)
		isDiepBannerMinimized = false
		if updateDiepEvoBanner then
			updateDiepEvoBanner()
		end
	end)
end

-- Collapsible Telemetry & Quest Drawer (Detached so only the Level & XP bar shows at top-center)
local topProgressionCard = Instance.new("Frame")
topProgressionCard.Name = "TopTelemetryDrawer"
topProgressionCard.Size = UDim2.new(0, 480, 0, 168)
topProgressionCard.AnchorPoint = Vector2.new(0.5, 0)
topProgressionCard.Position = UDim2.new(0.5, 0, 0, 112)
topProgressionCard.BackgroundColor3 = Color3.fromRGB(22, 34, 68)
topProgressionCard.Visible = false
topProgressionCard.Parent = nil
addCorner(topProgressionCard, 14)
addBorderStroke(topProgressionCard, Color3.fromRGB(10, 14, 26), 3.0)
addGradient(topProgressionCard, Color3.fromRGB(36, 58, 112), Color3.fromRGB(20, 32, 64), 90)

local rankTitleLbl = Instance.new("TextLabel")
rankTitleLbl.Size = UDim2.new(1, -28, 0, 20)
rankTitleLbl.Position = UDim2.new(0, 14, 0, 8)
rankTitleLbl.BackgroundTransparency = 1
rankTitleLbl.Text = "RANK 1 // PROTO-PLANETOID (1.0x YIELD)"
rankTitleLbl.TextColor3 = Color3.fromRGB(255, 225, 85)
rankTitleLbl.Font = Enum.Font.GothamBlack
rankTitleLbl.TextSize = 13
rankTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
rankTitleLbl.Parent = topProgressionCard
addTextStroke(rankTitleLbl, 1.6)

local rankBarBg = Instance.new("Frame")
rankBarBg.Size = UDim2.new(1, -28, 0, 18)
rankBarBg.Position = UDim2.new(0, 14, 0, 30)
rankBarBg.BackgroundColor3 = Color3.fromRGB(14, 20, 38)
rankBarBg.BorderSizePixel = 0
rankBarBg.Parent = topProgressionCard
addCorner(rankBarBg, 6)
addBorderStroke(rankBarBg, Color3.fromRGB(8, 12, 22), 2.0)

local rankBarFill = Instance.new("Frame")
rankBarFill.Size = UDim2.new(0.25, 0, 1, 0)
rankBarFill.BackgroundColor3 = Color3.fromRGB(88, 232, 44)
rankBarFill.BorderSizePixel = 0
rankBarFill.Parent = rankBarBg
addCorner(rankBarFill, 6)

local rankBarText = Instance.new("TextLabel")
rankBarText.Size = UDim2.new(1, -12, 1, 0)
rankBarText.Position = UDim2.new(0, 6, 0, 0)
rankBarText.BackgroundTransparency = 1
rankBarText.Text = "Planet Value: 100 / 1.2K  •  Next: Awakening World"
rankBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
rankBarText.Font = Enum.Font.GothamBlack
rankBarText.TextSize = 10
rankBarText.Parent = rankBarBg
addTextStroke(rankBarText, 1.4)

local zoneTitleLbl = Instance.new("TextLabel")
zoneTitleLbl.Size = UDim2.new(1, -28, 0, 18)
zoneTitleLbl.Position = UDim2.new(0, 14, 0, 52)
zoneTitleLbl.BackgroundTransparency = 1
zoneTitleLbl.Text = "GALACTIC NEXUS HUB  •  WASD + Shift Boost + Click Nodes to Mine"
zoneTitleLbl.TextColor3 = Color3.fromRGB(125, 240, 255)
zoneTitleLbl.Font = Enum.Font.GothamBold
zoneTitleLbl.TextSize = 11
zoneTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
zoneTitleLbl.Parent = topProgressionCard
addTextStroke(zoneTitleLbl, 1.3)

local boosterStatusLbl = Instance.new("TextLabel")
boosterStatusLbl.Size = UDim2.new(1, -28, 0, 18)
boosterStatusLbl.Position = UDim2.new(0, 14, 0, 70)
boosterStatusLbl.BackgroundTransparency = 1
boosterStatusLbl.Text = "Drones: 0/2  •  Drill Power: 1  •  Next Gate: Belt Outpost"
boosterStatusLbl.TextColor3 = Color3.fromRGB(215, 230, 255)
boosterStatusLbl.Font = Enum.Font.GothamBold
boosterStatusLbl.TextSize = 10
boosterStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
boosterStatusLbl.Parent = topProgressionCard
addTextStroke(boosterStatusLbl, 1.2)

-- Embedded Quest / Directive Tracker inside the collapsible drawer
local missionCard = Instance.new("Frame")
missionCard.Name = "EmbeddedQuestBox"
missionCard.Size = UDim2.new(1, -24, 0, 66)
missionCard.Position = UDim2.new(0, 12, 0, 92)
missionCard.BackgroundColor3 = Color3.fromRGB(16, 24, 48)
missionCard.Parent = topProgressionCard
addCorner(missionCard, 10)
addBorderStroke(missionCard, Color3.fromRGB(10, 14, 24), 2.0)

local missionHeader = Instance.new("TextLabel")
missionHeader.Size = UDim2.new(0.62, -12, 0, 18)
missionHeader.Position = UDim2.new(0, 10, 0, 4)
missionHeader.BackgroundTransparency = 1
missionHeader.Text = "QUEST #1: FIRST DRONE ROLL"
missionHeader.TextColor3 = Color3.fromRGB(255, 220, 75)
missionHeader.Font = Enum.Font.GothamBlack
missionHeader.TextSize = 11
missionHeader.TextXAlignment = Enum.TextXAlignment.Left
missionHeader.Parent = missionCard
addTextStroke(missionHeader, 1.4)

local missionRewardLbl = Instance.new("TextLabel")
missionRewardLbl.Size = UDim2.new(0.38, -10, 0, 18)
missionRewardLbl.Position = UDim2.new(0.62, 0, 0, 4)
missionRewardLbl.BackgroundTransparency = 1
missionRewardLbl.Text = "+25💎 +60⛏"
missionRewardLbl.TextColor3 = Color3.fromRGB(105, 245, 165)
missionRewardLbl.Font = Enum.Font.GothamBlack
missionRewardLbl.TextSize = 10
missionRewardLbl.TextXAlignment = Enum.TextXAlignment.Right
missionRewardLbl.Parent = missionCard
addTextStroke(missionRewardLbl, 1.3)

local missionDescLbl = Instance.new("TextLabel")
missionDescLbl.Size = UDim2.new(1, -20, 0, 18)
missionDescLbl.Position = UDim2.new(0, 10, 0, 22)
missionDescLbl.BackgroundTransparency = 1
missionDescLbl.Text = "Mine 25 Titanium Ore near the Hub and roll your first Drone."
missionDescLbl.TextColor3 = Color3.fromRGB(225, 236, 255)
missionDescLbl.Font = Enum.Font.GothamBold
missionDescLbl.TextSize = 10
missionDescLbl.TextTruncate = Enum.TextTruncate.AtEnd
missionDescLbl.TextXAlignment = Enum.TextXAlignment.Left
missionDescLbl.Parent = missionCard

local missionBarBg = Instance.new("Frame")
missionBarBg.Size = UDim2.new(1, -20, 0, 16)
missionBarBg.Position = UDim2.new(0, 10, 0, 44)
missionBarBg.BackgroundColor3 = Color3.fromRGB(10, 15, 28)
missionBarBg.BorderSizePixel = 0
missionBarBg.Parent = missionCard
addCorner(missionBarBg, 5)
addBorderStroke(missionBarBg, Color3.fromRGB(8, 12, 22), 1.5)

local missionBarFill = Instance.new("Frame")
missionBarFill.Size = UDim2.new(0, 0, 1, 0)
missionBarFill.BackgroundColor3 = Color3.fromRGB(88, 232, 44)
missionBarFill.BorderSizePixel = 0
missionBarFill.Parent = missionBarBg
addCorner(missionBarFill, 5)

local missionBarText = Instance.new("TextLabel")
missionBarText.Size = UDim2.new(1, 0, 1, 0)
missionBarText.BackgroundTransparency = 1
missionBarText.Text = "0 / 1"
missionBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
missionBarText.Font = Enum.Font.GothamBlack
missionBarText.TextSize = 10
missionBarText.Parent = missionBarBg
addTextStroke(missionBarText, 1.4)

-- A2. ACTIVE TARGET LOCK HUD BAR (Shows when mining an asteroid, enemy, or rival planet)
local targetLockCard = Instance.new("Frame")
targetLockCard.Name = "ActiveTargetLockCard"
targetLockCard.Size = UDim2.new(0, 316, 0, 44)
targetLockCard.AnchorPoint = Vector2.new(0.5, 0)
targetLockCard.Position = UDim2.new(0.5, 0, 0, 112)
targetLockCard.BackgroundColor3 = Color3.fromRGB(20, 27, 45)
targetLockCard.Visible = false
targetLockCard.Parent = nil
addCorner(targetLockCard, 10)
local targetLockStroke = addBorderStroke(targetLockCard, Color3.fromRGB(10, 14, 24), 2.8)

local targetLockTitle = Instance.new("TextLabel")
targetLockTitle.Size = UDim2.new(1, -20, 0, 18)
targetLockTitle.Position = UDim2.new(0, 10, 0, 4)
targetLockTitle.BackgroundTransparency = 1
targetLockTitle.Text = "TARGET // TITANIUM ORE"
targetLockTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
targetLockTitle.Font = Enum.Font.GothamBlack
targetLockTitle.TextSize = 11
targetLockTitle.TextXAlignment = Enum.TextXAlignment.Left
targetLockTitle.Parent = targetLockCard
addTextStroke(targetLockTitle, 1.6)

local targetLockBarBg = Instance.new("Frame")
targetLockBarBg.Size = UDim2.new(1, -20, 0, 15)
targetLockBarBg.Position = UDim2.new(0, 10, 0, 24)
targetLockBarBg.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
targetLockBarBg.BorderSizePixel = 0
targetLockBarBg.Parent = targetLockCard
addCorner(targetLockBarBg, 5)
addBorderStroke(targetLockBarBg, Color3.fromRGB(8, 10, 18), 1.5)

local targetLockBarFill = Instance.new("Frame")
targetLockBarFill.Size = UDim2.new(1, 0, 1, 0)
targetLockBarFill.BackgroundColor3 = Color3.fromRGB(88, 232, 44)
targetLockBarFill.BorderSizePixel = 0
targetLockBarFill.Parent = targetLockBarBg
addCorner(targetLockBarFill, 5)

local targetLockBarText = Instance.new("TextLabel")
targetLockBarText.Size = UDim2.new(1, 0, 1, 0)
targetLockBarText.BackgroundTransparency = 1
targetLockBarText.Text = "HP: 35 / 35"
targetLockBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
targetLockBarText.Font = Enum.Font.GothamBlack
targetLockBarText.TextSize = 10
targetLockBarText.Parent = targetLockBarBg
addTextStroke(targetLockBarText, 1.4)

local function updateTopTelemetryVisibility()
	local show = topInfoPinned or topBarHovered or topDrawerHovered
	topProgressionCard.Visible = show
	topCompactStroke.Color = show and Color3.fromRGB(88, 232, 44) or Color3.fromRGB(8, 12, 22)
	targetLockCard.Position = show and UDim2.new(0.5, 0, 0, 286) or UDim2.new(0.5, 0, 0, 112)
end

topCompactBtn.MouseEnter:Connect(function()
	topBarHovered = true
	updateTopTelemetryVisibility()
end)
topCompactBtn.MouseLeave:Connect(function()
	topBarHovered = false
	task.delay(0.08, updateTopTelemetryVisibility)
end)
topRallyBanner.MouseEnter:Connect(function()
	topBarHovered = true
	updateTopTelemetryVisibility()
end)
topRallyBanner.MouseLeave:Connect(function()
	topBarHovered = false
	task.delay(0.08, updateTopTelemetryVisibility)
end)
topProgressionCard.MouseEnter:Connect(function()
	topDrawerHovered = true
	updateTopTelemetryVisibility()
end)
topProgressionCard.MouseLeave:Connect(function()
	topDrawerHovered = false
	task.delay(0.08, updateTopTelemetryVisibility)
end)
topCompactBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.25)
	topInfoPinned = not topInfoPinned
	updateTopTelemetryVisibility()
end)
topRallyBanner.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.25)
	topInfoPinned = not topInfoPinned
	updateTopTelemetryVisibility()
end)

-- B. TOP-LEFT STACKED BEVELED CURRENCY BARS (Matching Reference Screenshot: Dark Navy Pill + Icon + Outlined Value + Green [+] Button)
local statCards: { [string]: { ValueLabel: TextLabel, RateLabel: TextLabel } } = {}
do
	local function makeDummyStatEntry()
		local v = Instance.new("TextLabel")
		local r = Instance.new("TextLabel")
		return { ValueLabel = v, RateLabel = r }
	end
	for _, k in ipairs({ "Gems", "DroneFleet", "Minerals", "Energy", "Biomass", "Tech", "PlanetValue", "CosmicShards", "Population" }) do
		statCards[k] = makeDummyStatEntry()
	end
end

local function createTopLeftCurrencyBar(orderIdx: number, yOffset: number, badgeColor: Color3, iconText: string, statKey: string, onPlusClick: () -> ())
	local bar = Instance.new("Frame")
	bar.Name = statKey .. "CurrencyBar"
	bar.Size = UDim2.new(0, 212, 0, 42)
	bar.Position = UDim2.new(0, 16, 0, yOffset)
	bar.BackgroundColor3 = Color3.fromRGB(27, 45, 88)
	bar.Parent = inGameHUD
	addCorner(bar, 12)
	addBorderStroke(bar, Color3.fromRGB(8, 12, 22), 3.0)
	addGradient(bar, Color3.fromRGB(42, 68, 128), Color3.fromRGB(22, 36, 72), 90)

	local gloss = Instance.new("Frame")
	gloss.Size = UDim2.new(1, -12, 0.42, 0)
	gloss.Position = UDim2.new(0, 6, 0, 3)
	gloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	gloss.BackgroundTransparency = 0.88
	gloss.BorderSizePixel = 0
	gloss.Parent = bar
	addCorner(gloss, 8)

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 32, 0, 32)
	badge.Position = UDim2.new(0, 6, 0.5, -16)
	badge.BackgroundColor3 = badgeColor
	badge.Parent = bar
	addCorner(badge, 16)
	addBorderStroke(badge, Color3.fromRGB(10, 14, 24), 2.2)

	local badgeIcon = Instance.new("TextLabel")
	badgeIcon.Size = UDim2.new(1, 0, 1, 0)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Text = iconText
	badgeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeIcon.Font = Enum.Font.GothamBlack
	badgeIcon.TextSize = 17
	badgeIcon.Parent = badge
	addTextStroke(badgeIcon, 1.5)

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(1, -86, 1, 0)
	valLbl.Position = UDim2.new(0, 44, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = "0"
	valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLbl.Font = Enum.Font.GothamBlack
	valLbl.TextSize = 20
	valLbl.TextXAlignment = Enum.TextXAlignment.Left
	valLbl.Parent = bar
	addTextStroke(valLbl, 2.2)

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 32, 0, 32)
	plusBtn.Position = UDim2.new(1, -37, 0.5, -16)
	plusBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	plusBtn.Text = "+"
	plusBtn.TextColor3 = Color3.fromRGB(14, 22, 12)
	plusBtn.Font = Enum.Font.GothamBlack
	plusBtn.TextSize = 22
	plusBtn.Parent = bar
	addCorner(plusBtn, 9)
	addBorderStroke(plusBtn, Color3.fromRGB(10, 16, 10), 2.4)
	addGradient(plusBtn, Color3.fromRGB(105, 245, 55), Color3.fromRGB(48, 192, 22), 90)
	plusBtn.MouseButton1Click:Connect(onPlusClick)

	statCards[statKey].ValueLabel = valLbl
end

-- Bar 1: Titanium Ore / Minerals (Amber Coin Badge + Green [+])
createTopLeftCurrencyBar(1, 14, Color3.fromRGB(255, 182, 38), "⛏", "Minerals", function()
	if toggleTab then
		toggleTab("Drones", "DRONE SHOP")
	end
end)

-- Compact Level & XP Pill directly below Bar 1
local subResourceStrip = Instance.new("Frame")
subResourceStrip.Name = "SubResourceStrip"
subResourceStrip.Size = UDim2.new(0, 212, 0, 26)
subResourceStrip.Position = UDim2.new(0, 16, 0, 62)
subResourceStrip.BackgroundColor3 = Color3.fromRGB(20, 32, 64)
subResourceStrip.Parent = inGameHUD
addCorner(subResourceStrip, 8)
addBorderStroke(subResourceStrip, Color3.fromRGB(8, 12, 22), 2.4)

local topLeftLevelXPLbl = Instance.new("TextLabel")
topLeftLevelXPLbl.Size = UDim2.new(1, -12, 1, 0)
topLeftLevelXPLbl.Position = UDim2.new(0, 6, 0, 0)
topLeftLevelXPLbl.BackgroundTransparency = 1
topLeftLevelXPLbl.Text = "⭐ LV.1  •  0 / 45 XP"
topLeftLevelXPLbl.TextColor3 = Color3.fromRGB(255, 225, 85)
topLeftLevelXPLbl.Font = Enum.Font.GothamBlack
topLeftLevelXPLbl.TextSize = 11
topLeftLevelXPLbl.Parent = subResourceStrip
addTextStroke(topLeftLevelXPLbl, 1.5)

-- C. POPUP TOAST BANNER (Beveled Bottom-Center Notification)
local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(0, 500, 0, 36)
toastLabel.AnchorPoint = Vector2.new(0.5, 1)
toastLabel.Position = UDim2.new(0.5, 0, 1, -152)
toastLabel.BackgroundColor3 = Color3.fromRGB(20, 30, 58)
toastLabel.BackgroundTransparency = 1
toastLabel.TextTransparency = 1
toastLabel.Text = ""
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.Font = Enum.Font.GothamBlack
toastLabel.TextSize = 13
toastLabel.TextWrapped = true
toastLabel.Parent = screenGui
addCorner(toastLabel, 10)
local toastStroke = addBorderStroke(toastLabel, Color3.fromRGB(10, 14, 24), 2.5)
toastStroke.Transparency = 1

local toastId = 0
local function showToast(msg: string, color: Color3)
	toastId += 1
	local myId = toastId
	playSFX(sfxUpgrade, 0.30, 0.08)
	toastLabel.Text = msg
	toastLabel.TextColor3 = color
	toastLabel.BackgroundTransparency = 0.06
	toastLabel.TextTransparency = 0
	toastStroke.Transparency = 0
	task.delay(3.2, function()
		if toastId == myId then
			TweenService:Create(toastLabel, TweenInfo.new(0.35), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.35), {
				Transparency = 1,
			}):Play()
		end
	end)
end
NotificationEvent.OnClientEvent:Connect(showToast)

-- ============================================================================
-- 7. SCREENSHOT-MATCHED MODAL WINDOW: FLOATING TOP TABS + SKY-BLUE & WHITE FRAME + 3D SPOTLIGHT
-- ============================================================================
local modalFrame = Instance.new("Frame")
modalFrame.Name = "SimulatorModalWindow"
modalFrame.Size = UDim2.new(0, 860, 0, 470)
modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
modalFrame.Position = UDim2.new(0.5, 105, 0.5, 24)
modalFrame.BackgroundColor3 = Color3.fromRGB(238, 246, 255) -- Crisp Ice-White Outer Rim
modalFrame.Visible = false
modalFrame.Parent = inGameHUD
addCorner(modalFrame, 18)
addBorderStroke(modalFrame, Color3.fromRGB(10, 14, 26), 3.5)

-- Inner Royal Sky-Blue Frame (Matches the vibrant blue SHOP body in the screenshot!)
local modalInnerSky = Instance.new("Frame")
modalInnerSky.Name = "ModalSkyBlueBody"
modalInnerSky.Size = UDim2.new(1, -14, 1, -14)
modalInnerSky.Position = UDim2.new(0, 7, 0, 7)
modalInnerSky.BackgroundColor3 = Color3.fromRGB(48, 132, 242)
modalInnerSky.BorderSizePixel = 0
modalInnerSky.Parent = modalFrame
addCorner(modalInnerSky, 14)
addBorderStroke(modalInnerSky, Color3.fromRGB(22, 68, 152), 2.0)
addGradient(modalInnerSky, Color3.fromRGB(64, 152, 255), Color3.fromRGB(30, 104, 218), 90)

-- Big Outlined Window Title on Top-Left ("DRONE SHOP", "UPGRADES", etc.)
local modalTitleLabel = Instance.new("TextLabel")
modalTitleLabel.Size = UDim2.new(0, 380, 0, 36)
modalTitleLabel.Position = UDim2.new(0, 18, 0, 8)
modalTitleLabel.BackgroundTransparency = 1
modalTitleLabel.Text = "DRONE SHOP"
modalTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitleLabel.Font = Enum.Font.GothamBlack
modalTitleLabel.TextSize = 24
modalTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
modalTitleLabel.Parent = modalInnerSky
addTextStroke(modalTitleLabel, 2.4)

-- Top-Right Mini Currency Pill inside the Modal Header
local modalHeaderOrePill = Instance.new("Frame")
modalHeaderOrePill.Size = UDim2.new(0, 132, 0, 32)
modalHeaderOrePill.Position = UDim2.new(1, -178, 0, 10)
modalHeaderOrePill.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
modalHeaderOrePill.Parent = modalInnerSky
addCorner(modalHeaderOrePill, 8)
addBorderStroke(modalHeaderOrePill, Color3.fromRGB(8, 12, 22), 2.5)

local modalHeaderOreLbl = Instance.new("TextLabel")
modalHeaderOreLbl.Size = UDim2.new(1, -12, 1, 0)
modalHeaderOreLbl.Position = UDim2.new(0, 6, 0, 0)
modalHeaderOreLbl.BackgroundTransparency = 1
modalHeaderOreLbl.Text = "⛏ 0"
modalHeaderOreLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
modalHeaderOreLbl.Font = Enum.Font.GothamBlack
modalHeaderOreLbl.TextSize = 15
modalHeaderOreLbl.Parent = modalHeaderOrePill
addTextStroke(modalHeaderOreLbl, 1.8)

-- Overlapping Red Square [X] Close Button on Top-Right Corner (Exact match to screenshot!)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "RedCloseSquareBtn"
closeBtn.Size = UDim2.new(0, 46, 0, 46)
closeBtn.Position = UDim2.new(1, -24, 0, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 25
closeBtn.ZIndex = 10
closeBtn.Parent = modalFrame
addCorner(closeBtn, 10)
addBorderStroke(closeBtn, Color3.fromRGB(12, 14, 22), 3.0)
addGradient(closeBtn, Color3.fromRGB(255, 72, 68), Color3.fromRGB(204, 28, 28), 90)
addTextStroke(closeBtn, 2.4)
attachBounceAndSFX(closeBtn)

-- Floating Top Category Tabs Sitting Above the Modal Frame (Active = Bright Lime Green, Inactive = Dark Navy)
local topCategoryBar = Instance.new("Frame")
topCategoryBar.Name = "FloatingTopCategoryBar"
topCategoryBar.Size = UDim2.new(1, -20, 0, 40)
topCategoryBar.Position = UDim2.new(0, 4, 0, -48)
topCategoryBar.BackgroundTransparency = 1
topCategoryBar.Parent = modalFrame

local topCatLayout = Instance.new("UIListLayout")
topCatLayout.FillDirection = Enum.FillDirection.Horizontal
topCatLayout.Padding = UDim.new(0, 8)
topCatLayout.SortOrder = Enum.SortOrder.LayoutOrder
topCatLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topCatLayout.Parent = topCategoryBar

local topCategoryBtns: { [string]: { Btn: TextButton, Grad: UIGradient } } = {}
local topCategoryDefs = {
	{ Order = 1, Key = "Drones", Label = "🛸 DRONES", Title = "DRONE SHOP" },
	{ Order = 2, Key = "DronePath", Label = "🧬 CLASS PATH", Title = "DIEP.IO DRONE PATH" },
	{ Order = 3, Key = "PlanetValue", Label = "⬆️ UPGRADES", Title = "PLANET UPGRADES" },
	{ Order = 4, Key = "WarpAscend", Label = "🛰️ STATIONS", Title = "STATIONS & WARP" },
	{ Order = 5, Key = "Evolution", Label = "🌟 SPECIES", Title = "SPECIES EVOLUTION" },
	{ Order = 6, Key = "BoostsRewards", Label = "🎁 REWARDS", Title = "REWARDS & BOOSTS" },
}

local tabPages: { [string]: GuiObject } = {}
local activeTab: string? = nil
local selectedMachineFilter: string? = nil

local function updateTopCategoryTabVisuals()
	for k, ui in pairs(topCategoryBtns) do
		local isAct = (k == activeTab)
		if isAct then
			ui.Grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 245, 58)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 192, 22)),
			})
		else
			ui.Grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 38, 64)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 22, 38)),
			})
		end
	end
end

for _, cDef in ipairs(topCategoryDefs) do
	local tBtn = Instance.new("TextButton")
	tBtn.LayoutOrder = cDef.Order
	tBtn.Size = UDim2.new(0, 128, 0, 38)
	tBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tBtn.Text = cDef.Label
	tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	tBtn.Font = Enum.Font.GothamBlack
	tBtn.TextSize = 13
	tBtn.Parent = topCategoryBar
	addCorner(tBtn, 10)
	addBorderStroke(tBtn, Color3.fromRGB(8, 12, 22), 2.8)
	addTextStroke(tBtn, 1.8)

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Parent = tBtn

	topCategoryBtns[cDef.Key] = { Btn = tBtn, Grad = grad }
	tBtn.MouseButton1Click:Connect(function()
		if cDef.Key == "Machines" then
			openMachineModal(nil)
		else
			toggleTab(cDef.Key, cDef.Title)
		end
	end)
end

local function createTabPage(name: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, -24, 1, -58)
	page.Position = UDim2.new(0, 12, 0, 48)
	page.BackgroundColor3 = Color3.fromRGB(28, 86, 188)
	page.BackgroundTransparency = 0.35
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.Visible = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Parent = modalInnerSky
	addCorner(page, 12)
	tabPages[name] = page
	return page
end

local machinesPage = createTabPage("Machines")
local evolutionPage = createTabPage("Evolution")
local planetValuePage = createTabPage("PlanetValue")
local warpAscendPage = createTabPage("WarpAscend")
local boostsRewardsPage = createTabPage("BoostsRewards")
local dronePathPage = createTabPage("DronePath")

-- Drones Page uses a Full Master-Detail Split Frame (Left 62% Rarity Card Grid + Right 38% Circular 3D Spotlight Inspector!)
local dronesPage = Instance.new("Frame")
dronesPage.Name = "DronesMasterDetailPage"
dronesPage.Size = UDim2.new(1, -24, 1, -58)
dronesPage.Position = UDim2.new(0, 12, 0, 48)
dronesPage.BackgroundTransparency = 1
dronesPage.Visible = false
dronesPage.Parent = modalInnerSky
tabPages["Drones"] = dronesPage

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

openMachineModal = function(machineId: string?)
	playSFX(sfxClick, 0.28)
	selectedMachineFilter = machineId
	activeTab = "Machines"
	if machineId and PlanetConfig.HubMachines[machineId] then
		local mDef = PlanetConfig.HubMachines[machineId]
		modalTitleLabel.Text = string.upper(mDef.Name)
	else
		modalTitleLabel.Text = "HUB MACHINES"
	end
	for k, page in pairs(tabPages) do
		page.Visible = (k == "Machines")
	end
	for mId, ui in pairs(machineCardsUI) do
		ui.Card.Visible = (machineId == nil) or (mId == machineId)
	end
	updateTopCategoryTabVisuals()
	modalFrame.Visible = true
	if updateDiepEvoBanner then
		updateDiepEvoBanner()
	end
end

toggleTab = function(tabKey: string, titleText: string)
	playSFX(sfxClick, 0.28)
	if modalFrame.Visible and activeTab == tabKey and selectedMachineFilter == nil then
		modalFrame.Visible = false
		activeTab = nil
		if updateDiepEvoBanner then
			updateDiepEvoBanner()
		end
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
	updateTopCategoryTabVisuals()
	modalFrame.Visible = true
	if updateDiepEvoBanner then
		updateDiepEvoBanner()
	end
end

closeBtn.MouseButton1Click:Connect(function()
	playSFX(sfxClick, 0.28)
	modalFrame.Visible = false
	activeTab = nil
	if updateDiepEvoBanner then
		updateDiepEvoBanner()
	end
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
	showAllBtn.Font = Enum.Font.GothamBlack
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
		title.Font = Enum.Font.GothamBlack
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
		tierLbl.Font = Enum.Font.GothamBlack
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
		effectLbl.Font = Enum.Font.GothamBlack
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
		costLbl.Font = Enum.Font.GothamBlack
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
		buyOneBtn.Font = Enum.Font.GothamBlack
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
		buyMaxBtn.Font = Enum.Font.GothamBlack
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
	stHdr.Font = Enum.Font.GothamBlack
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
		sTitle.Font = Enum.Font.GothamBlack
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
		perkLbl.Font = Enum.Font.GothamBlack
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
		reqLbl.Font = Enum.Font.GothamBlack
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
		wBtn.Font = Enum.Font.GothamBlack
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
	ascHdr.Font = Enum.Font.GothamBlack
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
	ascendActionBtn.Font = Enum.Font.GothamBlack
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
		st.Font = Enum.Font.GothamBlack
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
		sl.Font = Enum.Font.GothamBlack
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
		sb.Font = Enum.Font.GothamBlack
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
-- 7B. SCREENSHOT-MATCHED DRONE SHOP & INVENTORY SHOWCASE (`dronesPage`)
--     Left 62%: Rarity-Colored Vertical Cards with 3D ViewportFrames & Top-Left Ribbons
--     Right 38%: Circular 3D Spotlight Inspector + Big Lime-Green Beveled Action Button
-- ============================================================================
local droneSummaryLabel: TextLabel
local buyDroneSlotBtn: TextButton
local robuxDroneSlotBtn: TextButton
local droneInventoryGridFrame: Frame
local lastDroneInvUISignature = ""
local selectedShowcaseItem: { Kind: string, Id: string, Uid: string? } = { Kind = "Pod", Id = "LunarPod", Uid = nil }
local updateDroneSpotlightPanel: () -> ()
local spotlightViewportModel: Model? = nil
local spotlightViewportCam: Camera? = nil

local function populateDroneViewport(vp: ViewportFrame, droneId: string, isGolden: boolean, lvl: number)
	for _, ch in ipairs(vp:GetChildren()) do
		ch:Destroy()
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 42
	cam.Parent = vp
	vp.CurrentCamera = cam

	local ok, dm = pcall(function()
		return PlanetGenerator.BuildCompanionDroneModel(droneId, isGolden, lvl)
	end)
	if ok and dm then
		dm:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(10), math.rad(-28), 0))
		dm.Parent = vp
	end
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.8, 7.6), Vector3.new(0, 0, 0))
	return dm, cam
end

do
	-- LEFT 62%: Showcase Grid Container (Matches the light-blue recessed card grid in the screenshot!)
	local leftGridPanel = Instance.new("Frame")
	leftGridPanel.Name = "LeftShowcaseGridContainer"
	leftGridPanel.Size = UDim2.new(0.62, -8, 1, 0)
	leftGridPanel.Position = UDim2.new(0, 0, 0, 0)
	leftGridPanel.BackgroundColor3 = Color3.fromRGB(32, 92, 198)
	leftGridPanel.BackgroundTransparency = 0.25
	leftGridPanel.Parent = dronesPage
	addCorner(leftGridPanel, 12)
	addBorderStroke(leftGridPanel, Color3.fromRGB(18, 56, 132), 2.0)

	-- Top Quick-Action Strip inside Left Panel (Slots, Equip Best, Fuse 3->1)
	local actRow = Instance.new("Frame")
	actRow.Size = UDim2.new(1, -12, 0, 38)
	actRow.Position = UDim2.new(0, 6, 0, 6)
	actRow.BackgroundColor3 = Color3.fromRGB(18, 28, 54)
	actRow.Parent = leftGridPanel
	addCorner(actRow, 8)
	addBorderStroke(actRow, Color3.fromRGB(8, 12, 22), 2.0)

	droneSummaryLabel = Instance.new("TextLabel")
	droneSummaryLabel.Size = UDim2.new(1, -335, 1, 0)
	droneSummaryLabel.Position = UDim2.new(0, 10, 0, 0)
	droneSummaryLabel.BackgroundTransparency = 1
	droneSummaryLabel.Text = "SLOTS: 0/2  •  🔨 1"
	droneSummaryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	droneSummaryLabel.Font = Enum.Font.GothamBlack
	droneSummaryLabel.TextSize = 11
	droneSummaryLabel.TextXAlignment = Enum.TextXAlignment.Left
	droneSummaryLabel.Parent = actRow
	addTextStroke(droneSummaryLabel, 1.5)

	buyDroneSlotBtn = Instance.new("TextButton")
	buyDroneSlotBtn.Size = UDim2.new(0, 126, 0, 28)
	buyDroneSlotBtn.Position = UDim2.new(1, -324, 0.5, -14)
	buyDroneSlotBtn.BackgroundColor3 = Color3.fromRGB(215, 62, 242)
	buyDroneSlotBtn.Text = "+1 SLOT (500 💎)"
	buyDroneSlotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyDroneSlotBtn.Font = Enum.Font.GothamBlack
	buyDroneSlotBtn.TextSize = 10
	buyDroneSlotBtn.Parent = actRow
	addCorner(buyDroneSlotBtn, 6)
	addBorderStroke(buyDroneSlotBtn, Color3.fromRGB(10, 14, 24), 1.8)
	addTextStroke(buyDroneSlotBtn, 1.4)

	robuxDroneSlotBtn = Instance.new("TextButton")
	robuxDroneSlotBtn.Size = UDim2.new(0, 52, 0, 28)
	robuxDroneSlotBtn.Position = UDim2.new(1, -194, 0.5, -14)
	robuxDroneSlotBtn.BackgroundColor3 = Color3.fromRGB(38, 56, 98)
	robuxDroneSlotBtn.Text = "R$ 99"
	robuxDroneSlotBtn.TextColor3 = Color3.fromRGB(130, 225, 255)
	robuxDroneSlotBtn.Font = Enum.Font.GothamBlack
	robuxDroneSlotBtn.TextSize = 9
	robuxDroneSlotBtn.Parent = actRow
	addCorner(robuxDroneSlotBtn, 6)
	addBorderStroke(robuxDroneSlotBtn, Color3.fromRGB(10, 14, 24), 1.6)

	local equipBestBtn = Instance.new("TextButton")
	equipBestBtn.Size = UDim2.new(0, 68, 0, 28)
	equipBestBtn.Position = UDim2.new(1, -138, 0.5, -14)
	equipBestBtn.BackgroundColor3 = Color3.fromRGB(72, 225, 48)
	equipBestBtn.Text = "BEST"
	equipBestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipBestBtn.Font = Enum.Font.GothamBlack
	equipBestBtn.TextSize = 10
	equipBestBtn.Parent = actRow
	addCorner(equipBestBtn, 6)
	addBorderStroke(equipBestBtn, Color3.fromRGB(10, 14, 24), 1.8)
	addTextStroke(equipBestBtn, 1.4)

	local craftGoldBtn = Instance.new("TextButton")
	craftGoldBtn.Size = UDim2.new(0, 62, 0, 28)
	craftGoldBtn.Position = UDim2.new(1, -66, 0.5, -14)
	craftGoldBtn.BackgroundColor3 = Color3.fromRGB(255, 192, 38)
	craftGoldBtn.Text = "FUSE"
	craftGoldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	craftGoldBtn.Font = Enum.Font.GothamBlack
	craftGoldBtn.TextSize = 10
	craftGoldBtn.Parent = actRow
	addCorner(craftGoldBtn, 6)
	addBorderStroke(craftGoldBtn, Color3.fromRGB(10, 14, 24), 1.8)
	addTextStroke(craftGoldBtn, 1.4)

	buyDroneSlotBtn.MouseButton1Click:Connect(function()
		playSFX(sfxUpgrade, 0.40)
		BuyDroneSlotEvent:FireServer("Gems")
	end)
	robuxDroneSlotBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.35)
		BuyDroneSlotEvent:FireServer("Robux")
	end)
	equipBestBtn.MouseButton1Click:Connect(function()
		playSFX(sfxUpgrade, 0.38)
		CompanionActionEvent:FireServer("EquipBest")
	end)
	craftGoldBtn.MouseButton1Click:Connect(function()
		playSFX(sfxEvolve, 0.42)
		CompanionActionEvent:FireServer("CraftGolden")
	end)

	-- Scrolling Showcase Area inside Left Panel (Roll Pods + Owned Drone Fleet Cards)
	local leftScroll = Instance.new("ScrollingFrame")
	leftScroll.Name = "LeftShowcaseScroll"
	leftScroll.Size = UDim2.new(1, -12, 1, -50)
	leftScroll.Position = UDim2.new(0, 6, 0, 46)
	leftScroll.BackgroundTransparency = 1
	leftScroll.BorderSizePixel = 0
	leftScroll.ScrollBarThickness = 5
	leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	leftScroll.Parent = leftGridPanel

	local leftScrollList = Instance.new("UIListLayout")
	leftScrollList.Padding = UDim.new(0, 8)
	leftScrollList.SortOrder = Enum.SortOrder.LayoutOrder
	leftScrollList.Parent = leftScroll

	-- Section 1: 4 Vertical Roll Pod Cards (Styled exactly like the 4 top row cards in the screenshot!)
	local podSectionRow = Instance.new("Frame")
	podSectionRow.LayoutOrder = 1
	podSectionRow.Size = UDim2.new(1, -4, 0, 154)
	podSectionRow.BackgroundTransparency = 1
	podSectionRow.Parent = leftScroll

	local podGrid = Instance.new("UIGridLayout")
	podGrid.CellSize = UDim2.new(0, 118, 0, 148)
	podGrid.CellPadding = UDim2.new(0, 8, 0, 8)
	podGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	podGrid.SortOrder = Enum.SortOrder.LayoutOrder
	podGrid.Parent = podSectionRow

	local podCardPreviewDrones = { "BasicDrone", "BasicDrone", "BasicDrone", "BasicDrone" }
	local podCardBgColors = {
		{ Top = Color3.fromRGB(122, 142, 168), Bot = Color3.fromRGB(76, 92, 116) }, -- Slate Grey (like TV Remote)
		{ Top = Color3.fromRGB(58, 168, 245), Bot = Color3.fromRGB(28, 108, 198) }, -- Sky Blue (like Foam Finger)
		{ Top = Color3.fromRGB(168, 72, 245), Bot = Color3.fromRGB(108, 32, 188) }, -- Royal Purple (like Toy Brick Burst)
		{ Top = Color3.fromRGB(255, 205, 52), Bot = Color3.fromRGB(218, 138, 18) }, -- Golden Amber (like Toy UFO)
	}

	for podIdx, pod in ipairs(PlanetConfig.CompanionPods) do
		local cTheme = podCardBgColors[podIdx] or podCardBgColors[1]
		local pBtn = Instance.new("TextButton")
		pBtn.LayoutOrder = podIdx
		pBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		pBtn.Text = ""
		pBtn.AutoButtonColor = false
		pBtn.Parent = podSectionRow
		addCorner(pBtn, 12)
		addBorderStroke(pBtn, Color3.fromRGB(10, 14, 24), 2.5)
		addGradient(pBtn, cTheme.Top, cTheme.Bot, 90)

		-- Top-Left Red Corner Ribbon Tag (Matches "SALE" tag in screenshot!)
		local ribbon = Instance.new("TextLabel")
		ribbon.Size = UDim2.new(0, 56, 0, 20)
		ribbon.Position = UDim2.new(0, -2, 0, -2)
		ribbon.BackgroundColor3 = Color3.fromRGB(238, 52, 48)
		ribbon.Text = "TIER " .. tostring(podIdx)
		ribbon.TextColor3 = Color3.fromRGB(255, 255, 255)
		ribbon.Font = Enum.Font.GothamBlack
		ribbon.TextSize = 11
		ribbon.ZIndex = 4
		ribbon.Parent = pBtn
		addCorner(ribbon, 6)
		addBorderStroke(ribbon, Color3.fromRGB(12, 14, 22), 2.0)
		addTextStroke(ribbon, 1.5)

		-- Live 3D ViewportFrame inside the Card
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, -12, 0, 78)
		vp.Position = UDim2.new(0, 6, 0, 16)
		vp.BackgroundTransparency = 1
		vp.Parent = pBtn
		populateDroneViewport(vp, podCardPreviewDrones[podIdx] or "BasicDrone", podIdx == 4, 1)

		local pName = Instance.new("TextLabel")
		pName.Size = UDim2.new(1, -8, 0, 18)
		pName.Position = UDim2.new(0, 4, 1, -50)
		pName.BackgroundTransparency = 1
		pName.Text = pod.Name:gsub("^[^%w]+", "")
		pName.TextColor3 = Color3.fromRGB(255, 255, 255)
		pName.Font = Enum.Font.GothamBlack
		pName.TextSize = 11
		pName.TextTruncate = Enum.TextTruncate.AtEnd
		pName.Parent = pBtn
		addTextStroke(pName, 1.6)

		-- Dark Navy Bottom Cost Pill (Exact match to screenshot's [400], [1,200], [96], [240] pills!)
		local pricePill = Instance.new("Frame")
		pricePill.Size = UDim2.new(1, -12, 0, 24)
		pricePill.Position = UDim2.new(0, 6, 1, -29)
		pricePill.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		pricePill.Parent = pBtn
		addCorner(pricePill, 7)
		addBorderStroke(pricePill, Color3.fromRGB(8, 12, 22), 2.0)

		local priceTxt = Instance.new("TextLabel")
		priceTxt.Size = UDim2.new(1, -6, 1, 0)
		priceTxt.Position = UDim2.new(0, 3, 0, 0)
		priceTxt.BackgroundTransparency = 1
		priceTxt.Text = formatCost(pod.Cost or {})
		priceTxt.TextColor3 = Color3.fromRGB(255, 232, 95)
		priceTxt.Font = Enum.Font.GothamBlack
		priceTxt.TextSize = 10
		priceTxt.TextTruncate = Enum.TextTruncate.AtEnd
		priceTxt.Parent = pricePill
		addTextStroke(priceTxt, 1.4)

		pBtn.MouseButton1Click:Connect(function()
			playSFX(sfxClick, 0.30)
			selectedShowcaseItem = { Kind = "Pod", Id = pod.Id, Uid = nil }
			if updateDroneSpotlightPanel then
				updateDroneSpotlightPanel()
			end
		end)
	end

	-- Section 2 Header: Owned Drone Hangar
	local hangarHdr = Instance.new("TextLabel")
	hangarHdr.LayoutOrder = 2
	hangarHdr.Size = UDim2.new(1, -12, 0, 20)
	hangarHdr.BackgroundTransparency = 1
	hangarHdr.Text = "🛸 YOUR OWNED DRONES (CLICK A CARD TO INSPECT, EQUIP OR LEVEL UP)"
	hangarHdr.TextColor3 = Color3.fromRGB(255, 240, 125)
	hangarHdr.Font = Enum.Font.GothamBlack
	hangarHdr.TextSize = 11
	hangarHdr.TextXAlignment = Enum.TextXAlignment.Left
	hangarHdr.Parent = leftScroll
	addTextStroke(hangarHdr, 1.5)

	-- Section 3: Owned Drone Cards Grid (Vertical Rarity Cards with 3D ViewportFrames!)
	droneInventoryGridFrame = Instance.new("Frame")
	droneInventoryGridFrame.LayoutOrder = 3
	droneInventoryGridFrame.Size = UDim2.new(1, -4, 0, 160)
	droneInventoryGridFrame.AutomaticSize = Enum.AutomaticSize.Y
	droneInventoryGridFrame.BackgroundTransparency = 1
	droneInventoryGridFrame.Parent = leftScroll

	local invGrid = Instance.new("UIGridLayout")
	invGrid.CellSize = UDim2.new(0, 118, 0, 148)
	invGrid.CellPadding = UDim2.new(0, 8, 0, 8)
	invGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	invGrid.Parent = droneInventoryGridFrame

	-- RIGHT 38%: Spotlight Inspector Panel (Exact match to "Foam Finger" circular spotlight on the right of screenshot!)
	local rightSpotlightPanel = Instance.new("Frame")
	rightSpotlightPanel.Name = "RightSpotlightInspector"
	rightSpotlightPanel.Size = UDim2.new(0.38, -4, 1, 0)
	rightSpotlightPanel.Position = UDim2.new(0.62, 4, 0, 0)
	rightSpotlightPanel.BackgroundColor3 = Color3.fromRGB(42, 118, 228)
	rightSpotlightPanel.BackgroundTransparency = 0.15
	rightSpotlightPanel.Parent = dronesPage
	addCorner(rightSpotlightPanel, 14)
	addBorderStroke(rightSpotlightPanel, Color3.fromRGB(20, 62, 142), 2.0)

	-- Big Dark-Blue Circular Spotlight Backdrop (`148x148` Circle)
	local spotlightCircle = Instance.new("Frame")
	spotlightCircle.Name = "SpotlightCircle"
	spotlightCircle.Size = UDim2.new(0, 148, 0, 148)
	spotlightCircle.AnchorPoint = Vector2.new(0.5, 0)
	spotlightCircle.Position = UDim2.new(0.5, 0, 0, 12)
	spotlightCircle.BackgroundColor3 = Color3.fromRGB(26, 74, 168)
	spotlightCircle.Parent = rightSpotlightPanel
	addCorner(spotlightCircle, 74)
	addBorderStroke(spotlightCircle, Color3.fromRGB(16, 48, 118), 2.5)

	local spotlightViewport = Instance.new("ViewportFrame")
	spotlightViewport.Size = UDim2.new(1, 16, 1, 16)
	spotlightViewport.Position = UDim2.new(0, -8, 0, -8)
	spotlightViewport.BackgroundTransparency = 1
	spotlightViewport.Parent = spotlightCircle

	-- Selected Item Title ("Foam Finger" -> Selected Pod or Drone Name)
	local spotTitleLbl = Instance.new("TextLabel")
	spotTitleLbl.Size = UDim2.new(1, -16, 0, 26)
	spotTitleLbl.Position = UDim2.new(0, 8, 0, 166)
	spotTitleLbl.BackgroundTransparency = 1
	spotTitleLbl.Text = "Rust-Bit Pod"
	spotTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	spotTitleLbl.Font = Enum.Font.GothamBlack
	spotTitleLbl.TextSize = 20
	spotTitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	spotTitleLbl.Parent = rightSpotlightPanel
	addTextStroke(spotTitleLbl, 2.2)

	-- Selected Item Rarity / Subtitle ("RARE HITTER" -> "TIER 1 RESOURCE POD" or "MYTHIC DRONE • LV. 5")
	local spotRarityLbl = Instance.new("TextLabel")
	spotRarityLbl.Size = UDim2.new(1, -16, 0, 18)
	spotRarityLbl.Position = UDim2.new(0, 8, 0, 192)
	spotRarityLbl.BackgroundTransparency = 1
	spotRarityLbl.Text = "RESOURCE ROLL POD"
	spotRarityLbl.TextColor3 = Color3.fromRGB(125, 232, 255)
	spotRarityLbl.Font = Enum.Font.GothamBlack
	spotRarityLbl.TextSize = 12
	spotRarityLbl.Parent = rightSpotlightPanel
	addTextStroke(spotRarityLbl, 1.6)

	-- Selected Item Description / Stats Box
	local spotDescLbl = Instance.new("TextLabel")
	spotDescLbl.Size = UDim2.new(1, -24, 0, 62)
	spotDescLbl.Position = UDim2.new(0, 12, 0, 214)
	spotDescLbl.BackgroundTransparency = 1
	spotDescLbl.Text = "Rolls 1 random mining drone using Titanium Ore & Plasma Flux."
	spotDescLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	spotDescLbl.Font = Enum.Font.GothamBold
	spotDescLbl.TextSize = 12
	spotDescLbl.TextWrapped = true
	spotDescLbl.Parent = rightSpotlightPanel
	addTextStroke(spotDescLbl, 1.6)

	-- Secondary Action Button (e.g., "⚡ ROLL 3x" or "⬆️ LEVEL UP DRONE")
	local spotSecondaryBtn = Instance.new("TextButton")
	spotSecondaryBtn.Size = UDim2.new(1, -28, 0, 38)
	spotSecondaryBtn.Position = UDim2.new(0, 14, 1, -104)
	spotSecondaryBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	spotSecondaryBtn.Text = "⚡ ROLL 3x DRONES"
	spotSecondaryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	spotSecondaryBtn.Font = Enum.Font.GothamBlack
	spotSecondaryBtn.TextSize = 13
	spotSecondaryBtn.Parent = rightSpotlightPanel
	addCorner(spotSecondaryBtn, 10)
	addBorderStroke(spotSecondaryBtn, Color3.fromRGB(10, 14, 24), 2.5)
	addGradient(spotSecondaryBtn, Color3.fromRGB(255, 195, 45), Color3.fromRGB(214, 122, 18), 90)
	addTextStroke(spotSecondaryBtn, 1.8)

	-- Primary Big Lime-Green Beveled Action Button at Bottom (Matches "BUY 1,200" button in screenshot!)
	local spotPrimaryBtn = Instance.new("TextButton")
	spotPrimaryBtn.Size = UDim2.new(1, -28, 0, 50)
	spotPrimaryBtn.Position = UDim2.new(0, 14, 1, -58)
	spotPrimaryBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	spotPrimaryBtn.Text = "ROLL 1x (25 ⛏)"
	spotPrimaryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	spotPrimaryBtn.Font = Enum.Font.GothamBlack
	spotPrimaryBtn.TextSize = 17
	spotPrimaryBtn.Parent = rightSpotlightPanel
	addCorner(spotPrimaryBtn, 12)
	addBorderStroke(spotPrimaryBtn, Color3.fromRGB(10, 16, 10), 3.0)
	addGradient(spotPrimaryBtn, Color3.fromRGB(108, 248, 56), Color3.fromRGB(46, 188, 20), 90)
	addTextStroke(spotPrimaryBtn, 2.2)

	updateDroneSpotlightPanel = function()
		local ownedDrones = currentState.Companions or {}
		local res = currentState.Resources or {}

		if selectedShowcaseItem.Kind == "Drone" and selectedShowcaseItem.Uid then
			local foundEntry: any = nil
			for _, entry in ipairs(ownedDrones) do
				if entry.Uid == selectedShowcaseItem.Uid then
					foundEntry = entry
					break
				end
			end
			if foundEntry then
				local cDef = PlanetConfig.Companions[foundEntry.Id]
				if cDef then
					local isGold = (foundEntry.IsGolden == true) or (foundEntry.Golden == true)
					local lvl = foundEntry.Level or 1
					local stats = PlanetConfig.GetDroneStats(foundEntry.Id, lvl, isGold)
					local rInfo = PlanetConfig.DroneRarities[cDef.Rarity]
					local rCol = isGold and Color3.fromRGB(255, 215, 65) or ((rInfo and rInfo.Color) or cDef.Color)

					spotlightViewportModel, spotlightViewportCam = populateDroneViewport(spotlightViewport, foundEntry.Id, isGold, lvl)
					spotTitleLbl.Text = (isGold and "★ " or "") .. cDef.Name
					spotRarityLbl.Text = string.format("%s  •  LV.%d/%d", string.upper(stats.RoleTag or cDef.Rarity), lvl, PlanetConfig.MaxDroneLevel or 25)
					spotRarityLbl.TextColor3 = rCol
					local styleLine = (stats.ProjectileStyle == "StickyBomb")
						and string.format("💣 %s Blast • Radius %d (Max %d)", PlanetConfig.FormatNumber(stats.BombBaseDamage), stats.BlastRadius, stats.MaxStickyBombs)
						or string.format("🔨 %s Drill • ⚔️ %s DMG (%.2fs)", PlanetConfig.FormatNumber(stats.DrillPower), PlanetConfig.FormatNumber(stats.Damage), stats.FireCooldown)
					spotDescLbl.Text = string.format(
						"%s\n🎯 %d Studs • x%d Shots • 📈 %.2fx Yield",
						styleLine,
						stats.Range,
						stats.ProjectilesPerShot,
						stats.YieldMult
					)

					spotPrimaryBtn.Text = foundEntry.Equipped and "✓ EQUIPPED (UNEQUIP)" or "EQUIP DRONE"
					local maxLvl = PlanetConfig.MaxDroneLevel or 25
					if lvl >= maxLvl then
						spotSecondaryBtn.Text = "✓ MAX LEVEL (" .. tostring(maxLvl) .. ")"
					else
						local upCost = PlanetConfig.GetDroneLevelUpCost(foundEntry.Id, lvl)
						spotSecondaryBtn.Text = "⬆️ LV." .. tostring(lvl + 1) .. " (" .. formatCost(upCost) .. ")"
					end
					return
				end
			end
		end

		-- Default / Pod Selection
		local podIdx = 1
		local chosenPod = PlanetConfig.CompanionPods[1]
		for i, p in ipairs(PlanetConfig.CompanionPods) do
			if p.Id == selectedShowcaseItem.Id then
				chosenPod = p
				podIdx = i
				break
			end
		end
		if chosenPod then
			local previewId = podCardPreviewDrones[podIdx] or "BasicDrone"
			spotlightViewportModel, spotlightViewportCam = populateDroneViewport(spotlightViewport, previewId, podIdx == 4, 1)
			spotTitleLbl.Text = chosenPod.Name:gsub("^[^%w]+", "")
			spotRarityLbl.Text = string.format("TIER %d BASIC DRONE POD (NO GEMS)", podIdx)
			spotRarityLbl.TextColor3 = chosenPod.Color
			spotDescLbl.Text = chosenPod.Description .. "\nCost: " .. formatCost(chosenPod.Cost or {})
			spotPrimaryBtn.Text = "ROLL 1x (" .. formatCost(chosenPod.Cost or {}) .. ")"
			spotSecondaryBtn.Text = "⚡ ROLL 3x DRONES"
		end
	end

	spotPrimaryBtn.MouseButton1Click:Connect(function()
		if selectedShowcaseItem.Kind == "Drone" and selectedShowcaseItem.Uid then
			playSFX(sfxClick, 0.35)
			CompanionActionEvent:FireServer("ToggleEquip", selectedShowcaseItem.Uid)
		else
			playSFX(sfxEvolve, 0.44)
			HatchCompanionPodEvent:FireServer(selectedShowcaseItem.Id, false)
		end
	end)

	spotSecondaryBtn.MouseButton1Click:Connect(function()
		if selectedShowcaseItem.Kind == "Drone" and selectedShowcaseItem.Uid then
			playSFX(sfxUpgrade, 0.38)
			CompanionActionEvent:FireServer("LevelUp", selectedShowcaseItem.Uid)
		else
			playSFX(sfxEvolve, 0.48)
			HatchCompanionPodEvent:FireServer(selectedShowcaseItem.Id, true)
		end
	end)

	updateDroneSpotlightPanel()
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

	local giftHdr = Instance.new("TextLabel")
	giftHdr.Size = UDim2.new(1, -16, 0, 22)
	giftHdr.BackgroundTransparency = 1
	giftHdr.Text = "SESSION PLAYTIME REWARDS (RESET EACH SESSION)"
	giftHdr.TextColor3 = Color3.fromRGB(255, 235, 95)
	giftHdr.Font = Enum.Font.GothamBlack
	giftHdr.TextSize = 13
	giftHdr.TextXAlignment = Enum.TextXAlignment.Left
	giftHdr.Parent = boostsRewardsPage
	addTextStroke(giftHdr, 1.5)

	local giftGridFrame = Instance.new("Frame")
	giftGridFrame.Size = UDim2.new(1, -16, 0, 168)
	giftGridFrame.BackgroundTransparency = 1
	giftGridFrame.Parent = boostsRewardsPage

	local gGrid = Instance.new("UIGridLayout")
	gGrid.CellSize = UDim2.new(0, 258, 0, 78)
	gGrid.CellPadding = UDim2.new(0, 10, 0, 10)
	gGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gGrid.Parent = giftGridFrame

	for _, gDef in ipairs(PlanetConfig.PlaytimeRewards) do
		local gCard = Instance.new("Frame")
		gCard.BackgroundColor3 = Color3.fromRGB(20, 32, 64)
		gCard.Parent = giftGridFrame
		addCorner(gCard, 10)
		addBorderStroke(gCard, Color3.fromRGB(10, 14, 24), 2.2)

		local gt = Instance.new("TextLabel")
		gt.Size = UDim2.new(1, -110, 0, 20)
		gt.Position = UDim2.new(0, 10, 0, 6)
		gt.BackgroundTransparency = 1
		gt.Text = "🎁 " .. (gDef.Label or gDef.Title or "Gift")
		gt.TextColor3 = Color3.fromRGB(255, 230, 105)
		gt.Font = Enum.Font.GothamBlack
		gt.TextSize = 12
		gt.TextXAlignment = Enum.TextXAlignment.Left
		gt.Parent = gCard
		addTextStroke(gt, 1.4)

		local gr = Instance.new("TextLabel")
		gr.Size = UDim2.new(1, -110, 0, 36)
		gr.Position = UDim2.new(0, 10, 0, 28)
		gr.BackgroundTransparency = 1
		gr.Text = gDef.RewardText or "Free Session Gift"
		gr.TextColor3 = Color3.fromRGB(125, 240, 185)
		gr.Font = Enum.Font.GothamBold
		gr.TextSize = 10
		gr.TextWrapped = true
		gr.TextXAlignment = Enum.TextXAlignment.Left
		gr.Parent = gCard

		local gBtn = Instance.new("TextButton")
		gBtn.Size = UDim2.new(0, 92, 0, 40)
		gBtn.Position = UDim2.new(1, -100, 0.5, -20)
		gBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 220)
		gBtn.Text = "00:00"
		gBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		gBtn.Font = Enum.Font.GothamBlack
		gBtn.TextSize = 12
		gBtn.Parent = gCard
		addCorner(gBtn, 8)
		addBorderStroke(gBtn, Color3.fromRGB(10, 14, 24), 2.0)
		addTextStroke(gBtn, 1.5)

		gBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			ClaimPlaytimeGiftEvent:FireServer(gDef.Id)
		end)

		giftButtonsUI[gDef.Id] = { Btn = gBtn, StatusLbl = gr }
	end

	local boostHdr = Instance.new("TextLabel")
	boostHdr.Size = UDim2.new(1, -16, 0, 22)
	boostHdr.BackgroundTransparency = 1
	boostHdr.Text = "TIMED OVERDRIVE BOOSTERS (STACK DURATION WITH STAR GEMS)"
	boostHdr.TextColor3 = Color3.fromRGB(255, 255, 255)
	boostHdr.Font = Enum.Font.GothamBlack
	boostHdr.TextSize = 13
	boostHdr.TextXAlignment = Enum.TextXAlignment.Left
	boostHdr.Parent = boostsRewardsPage
	addTextStroke(boostHdr, 1.5)

	local boostGridFrame = Instance.new("Frame")
	boostGridFrame.Size = UDim2.new(1, -16, 0, 178)
	boostGridFrame.BackgroundTransparency = 1
	boostGridFrame.Parent = boostsRewardsPage

	local bGrid = Instance.new("UIGridLayout")
	bGrid.CellSize = UDim2.new(0, 390, 0, 82)
	bGrid.CellPadding = UDim2.new(0, 12, 0, 10)
	bGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bGrid.Parent = boostGridFrame

	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local bCard = Instance.new("Frame")
		bCard.BackgroundColor3 = Color3.fromRGB(20, 32, 64)
		bCard.Parent = boostGridFrame
		addCorner(bCard, 10)
		addBorderStroke(bCard, Color3.fromRGB(10, 14, 24), 2.2)

		local bt = Instance.new("TextLabel")
		bt.Size = UDim2.new(1, -150, 0, 20)
		bt.Position = UDim2.new(0, 12, 0, 6)
		bt.BackgroundTransparency = 1
		bt.Text = bDef.Icon .. " " .. bDef.Name
		bt.TextColor3 = bDef.Color
		bt.Font = Enum.Font.GothamBlack
		bt.TextSize = 13
		bt.TextXAlignment = Enum.TextXAlignment.Left
		bt.Parent = bCard
		addTextStroke(bt, 1.4)

		local bd = Instance.new("TextLabel")
		bd.Size = UDim2.new(1, -150, 0, 24)
		bd.Position = UDim2.new(0, 12, 0, 28)
		bd.BackgroundTransparency = 1
		bd.Text = bDef.Description
		bd.TextColor3 = Color3.fromRGB(220, 232, 255)
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
		bTimer.TextColor3 = Color3.fromRGB(255, 220, 95)
		bTimer.Font = Enum.Font.GothamBold
		bTimer.TextSize = 10
		bTimer.TextXAlignment = Enum.TextXAlignment.Left
		bTimer.Parent = bCard

		local bBtn = Instance.new("TextButton")
		bBtn.Size = UDim2.new(0, 128, 0, 40)
		bBtn.Position = UDim2.new(1, -138, 0.5, -20)
		bBtn.BackgroundColor3 = Color3.fromRGB(88, 232, 44)
		bBtn.Text = string.format("💎 %d GEMS", bDef.GemCost)
		bBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		bBtn.Font = Enum.Font.GothamBlack
		bBtn.TextSize = 12
		bBtn.Parent = bCard
		addCorner(bBtn, 8)
		addBorderStroke(bBtn, Color3.fromRGB(10, 14, 24), 2.0)
		addTextStroke(bBtn, 1.6)

		bBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			BuyBoosterEvent:FireServer(bDef.Id)
		end)

		boosterButtonsUI[bDef.Id] = { Btn = bBtn, TimerLbl = bTimer }
	end

	local codeCard = Instance.new("Frame")
	codeCard.Size = UDim2.new(1, -16, 0, 52)
	codeCard.BackgroundColor3 = Color3.fromRGB(20, 32, 64)
	codeCard.Parent = boostsRewardsPage
	addCorner(codeCard, 10)
	addBorderStroke(codeCard, Color3.fromRGB(10, 14, 24), 2.2)

	local codeLbl = Instance.new("TextLabel")
	codeLbl.Size = UDim2.new(0, 340, 1, 0)
	codeLbl.Position = UDim2.new(0, 14, 0, 0)
	codeLbl.BackgroundTransparency = 1
	codeLbl.Text = "CODES // COSMIC2026, STARFARER, GALAXY, GEMS500"
	codeLbl.TextColor3 = Color3.fromRGB(255, 230, 105)
	codeLbl.Font = Enum.Font.GothamBlack
	codeLbl.TextSize = 11
	codeLbl.TextXAlignment = Enum.TextXAlignment.Left
	codeLbl.Parent = codeCard
	addTextStroke(codeLbl, 1.4)

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(0, 240, 0, 34)
	codeBox.Position = UDim2.new(1, -405, 0.5, -17)
	codeBox.BackgroundColor3 = Color3.fromRGB(12, 18, 34)
	codeBox.PlaceholderText = "Enter Code (e.g. COSMIC2026)"
	codeBox.Text = ""
	codeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	codeBox.Font = Enum.Font.GothamBold
	codeBox.TextSize = 12
	codeBox.Parent = codeCard
	addCorner(codeBox, 6)
	addBorderStroke(codeBox, Color3.fromRGB(8, 12, 22), 1.8)

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0, 145, 0, 34)
	redeemBtn.Position = UDim2.new(1, -154, 0.5, -17)
	redeemBtn.BackgroundColor3 = Color3.fromRGB(88, 232, 44)
	redeemBtn.Text = "REDEEM CODE"
	redeemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	redeemBtn.Font = Enum.Font.GothamBlack
	redeemBtn.TextSize = 12
	redeemBtn.Parent = codeCard
	addCorner(redeemBtn, 6)
	addBorderStroke(redeemBtn, Color3.fromRGB(10, 14, 24), 2.0)
	addTextStroke(redeemBtn, 1.6)

	redeemBtn.MouseButton1Click:Connect(function()
		if #codeBox.Text > 0 then
			playSFX(sfxUpgrade, 0.4)
			RedeemPromoCodeEvent:FireServer(codeBox.Text)
			codeBox.Text = ""
		end
	end)
end

-- ============================================================================
-- 7D. DIEP.IO FIRST-PATH DRONE EVOLUTION TREE (`BasicDrone` -> 5 Drones at Lv.5)
-- ============================================================================
local dronePathCardsUI: { [string]: { Card: Frame, EvolveBtn: TextButton, Badge: TextLabel } } = {}
local dronePathHeaderLbl: TextLabel
do
	local pList = Instance.new("UIListLayout")
	pList.Padding = UDim.new(0, 10)
	pList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pList.SortOrder = Enum.SortOrder.LayoutOrder
	pList.Parent = dronePathPage

	dronePathHeaderLbl = Instance.new("TextLabel")
	dronePathHeaderLbl.LayoutOrder = 1
	dronePathHeaderLbl.Size = UDim2.new(1, -16, 0, 26)
	dronePathHeaderLbl.BackgroundTransparency = 1
	dronePathHeaderLbl.Text = "🧬 DIEP.IO FIRST PATH • REACH LEVEL 5 TO EVOLVE YOUR BASIC DRONE!"
	dronePathHeaderLbl.TextColor3 = Color3.fromRGB(128, 255, 115)
	dronePathHeaderLbl.Font = Enum.Font.GothamBlack
	dronePathHeaderLbl.TextSize = 13
	dronePathHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
	dronePathHeaderLbl.Parent = dronePathPage
	addTextStroke(dronePathHeaderLbl, 1.5)

	-- Starter Root Node: Basic Drone
	local rootHolder = Instance.new("Frame")
	rootHolder.LayoutOrder = 2
	rootHolder.Size = UDim2.new(1, -16, 0, 88)
	rootHolder.BackgroundTransparency = 1
	rootHolder.Parent = dronePathPage

	local basicDef = PlanetConfig.Companions.BasicDrone
	local rootCard = Instance.new("Frame")
	rootCard.Size = UDim2.new(0, 420, 0, 84)
	rootCard.AnchorPoint = Vector2.new(0.5, 0)
	rootCard.Position = UDim2.new(0.5, 0, 0, 2)
	rootCard.BackgroundColor3 = Color3.fromRGB(18, 32, 66)
	rootCard.Parent = rootHolder
	addCorner(rootCard, 12)
	addBorderStroke(rootCard, basicDef.Color, 2.2)

	local rootVP = Instance.new("ViewportFrame")
	rootVP.Size = UDim2.new(0, 68, 0, 68)
	rootVP.Position = UDim2.new(0, 8, 0.5, -34)
	rootVP.BackgroundColor3 = Color3.fromRGB(10, 16, 34)
	rootVP.Parent = rootCard
	addCorner(rootVP, 8)
	populateDroneViewport(rootVP, "BasicDrone", false, 1)

	local rootTitle = Instance.new("TextLabel")
	rootTitle.Size = UDim2.new(1, -92, 0, 22)
	rootTitle.Position = UDim2.new(0, 84, 0, 8)
	rootTitle.BackgroundTransparency = 1
	rootTitle.Text = "🛸 STARTER NODE: " .. string.upper(basicDef.Name) .. " (LV.1)"
	rootTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	rootTitle.Font = Enum.Font.GothamBlack
	rootTitle.TextSize = 13
	rootTitle.TextXAlignment = Enum.TextXAlignment.Left
	rootTitle.Parent = rootCard
	addTextStroke(rootTitle, 1.5)

	local rootDesc = Instance.new("TextLabel")
	rootDesc.Size = UDim2.new(1, -92, 0, 46)
	rootDesc.Position = UDim2.new(0, 84, 0, 32)
	rootDesc.BackgroundTransparency = 1
	rootDesc.Text = basicDef.Description
	rootDesc.TextColor3 = Color3.fromRGB(195, 220, 255)
	rootDesc.Font = Enum.Font.GothamBold
	rootDesc.TextSize = 11
	rootDesc.TextWrapped = true
	rootDesc.TextXAlignment = Enum.TextXAlignment.Left
	rootDesc.Parent = rootCard

	local branchHdr = Instance.new("TextLabel")
	branchHdr.LayoutOrder = 3
	branchHdr.Size = UDim2.new(1, -16, 0, 22)
	branchHdr.BackgroundTransparency = 1
	branchHdr.Text = "▼  LEVEL 5 FIRST-PATH CHOICES (EACH PATH WILL GROW ITS OWN TREE LATER!)  ▼"
	branchHdr.TextColor3 = Color3.fromRGB(255, 232, 115)
	branchHdr.Font = Enum.Font.GothamBlack
	branchHdr.TextSize = 12
	branchHdr.TextXAlignment = Enum.TextXAlignment.Center
	branchHdr.Parent = dronePathPage
	addTextStroke(branchHdr, 1.4)

	local gridHolder = Instance.new("Frame")
	gridHolder.LayoutOrder = 4
	gridHolder.Size = UDim2.new(1, -12, 0, 140)
	gridHolder.AutomaticSize = Enum.AutomaticSize.Y
	gridHolder.BackgroundTransparency = 1
	gridHolder.Parent = dronePathPage

	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0, 258, 0, 136)
	gl.CellPadding = UDim2.new(0, 10, 0, 10)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.Parent = gridHolder

	local firstPathIds = PlanetConfig.FirstPathDroneOrder or { "RapidPulse", "HeavyCannon", "LongRangeScout", "SpreadShot", "StickyBomber" }
	for _, cId in ipairs(firstPathIds) do
		local cDef = PlanetConfig.Companions[cId]
		if cDef then
			local card = Instance.new("Frame")
			card.BackgroundColor3 = Color3.fromRGB(16, 26, 52)
			card.Parent = gridHolder
			addCorner(card, 12)
			addBorderStroke(card, cDef.Color, 2.0)

			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(0, 68, 0, 68)
			vp.Position = UDim2.new(0, 8, 0, 8)
			vp.BackgroundColor3 = Color3.fromRGB(10, 16, 34)
			vp.Parent = card
			addCorner(vp, 8)
			populateDroneViewport(vp, cId, false, 1)

			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(1, -86, 0, 15)
			badge.Position = UDim2.new(0, 82, 0, 6)
			badge.BackgroundTransparency = 1
			badge.Text = cDef.RoleTag or cDef.Rarity
			badge.TextColor3 = cDef.Color
			badge.Font = Enum.Font.GothamBlack
			badge.TextSize = 10
			badge.TextXAlignment = Enum.TextXAlignment.Left
			badge.Parent = card

			local tLbl = Instance.new("TextLabel")
			tLbl.Size = UDim2.new(1, -86, 0, 20)
			tLbl.Position = UDim2.new(0, 82, 0, 21)
			tLbl.BackgroundTransparency = 1
			tLbl.Text = cDef.Icon .. " " .. cDef.Name
			tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			tLbl.Font = Enum.Font.GothamBlack
			tLbl.TextSize = 13
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.TextTruncate = Enum.TextTruncate.AtEnd
			tLbl.Parent = card
			addTextStroke(tLbl, 1.5)

			local descLbl = Instance.new("TextLabel")
			descLbl.Size = UDim2.new(1, -86, 0, 36)
			descLbl.Position = UDim2.new(0, 82, 0, 41)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = cDef.Description
			descLbl.TextColor3 = Color3.fromRGB(195, 214, 240)
			descLbl.Font = Enum.Font.GothamMedium
			descLbl.TextSize = 9
			descLbl.TextWrapped = true
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.Parent = card

			local subTreeHint = Instance.new("TextLabel")
			subTreeHint.Size = UDim2.new(1, -16, 0, 14)
			subTreeHint.Position = UDim2.new(0, 8, 1, -50)
			subTreeHint.BackgroundTransparency = 1
			subTreeHint.Text = "↳ Further Drone Branch Tree: Coming Soon"
			subTreeHint.TextColor3 = Color3.fromRGB(145, 175, 225)
			subTreeHint.Font = Enum.Font.GothamBold
			subTreeHint.TextSize = 9
			subTreeHint.TextXAlignment = Enum.TextXAlignment.Left
			subTreeHint.Parent = card

			local evolveBtn = Instance.new("TextButton")
			evolveBtn.Size = UDim2.new(1, -16, 0, 30)
			evolveBtn.Position = UDim2.new(0, 8, 1, -34)
			evolveBtn.BackgroundColor3 = Color3.fromRGB(72, 225, 58)
			evolveBtn.Text = "🔒 UNLOCKS AT LV.5"
			evolveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			evolveBtn.Font = Enum.Font.GothamBlack
			evolveBtn.TextSize = 11
			evolveBtn.Parent = card
			addCorner(evolveBtn, 7)
			addBorderStroke(evolveBtn, Color3.fromRGB(10, 14, 24), 1.8)
			addTextStroke(evolveBtn, 1.4)

			local cidCopy = cId
			evolveBtn.MouseButton1Click:Connect(function()
				playSFX(sfxEvolve, 0.45)
				EvolveDronePathEvent:FireServer(cidCopy)
			end)

			dronePathCardsUI[cId] = { Card = card, EvolveBtn = evolveBtn, Badge = badge }
		end
	end
end

-- ============================================================================
-- 8. LEFT-SIDE 2x4 ILLUSTRATED BEVELED BUTTON GRID (Matching SHOP / LOCKER / QUESTS / DAILY / AFK / SETTINGS)
-- ============================================================================
local proximityPromptBtn = Instance.new("TextButton")
proximityPromptBtn.Name = "MachineProximityPrompt"
proximityPromptBtn.Size = UDim2.new(0, 440, 0, 42)
proximityPromptBtn.AnchorPoint = Vector2.new(0.5, 1)
proximityPromptBtn.Position = UDim2.new(0.5, 0, 1, -152)
proximityPromptBtn.BackgroundColor3 = Color3.fromRGB(24, 38, 76)
proximityPromptBtn.Text = "[E] ACCESS TERMINAL"
proximityPromptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
proximityPromptBtn.Font = Enum.Font.GothamBlack
proximityPromptBtn.TextSize = 14
proximityPromptBtn.Visible = false
proximityPromptBtn.Parent = inGameHUD
addCorner(proximityPromptBtn, 10)
local proxStroke = addBorderStroke(proximityPromptBtn, Color3.fromRGB(10, 14, 24), 2.8)
addTextStroke(proximityPromptBtn, 1.8)

-- Sticky Bomb Manual Detonate Button (Shows right above the 5 Drone Slots whenever bombs are planted!)
local detonateBombsBtn = Instance.new("TextButton")
detonateBombsBtn.Name = "DetonateStickyBombsButton"
detonateBombsBtn.Size = UDim2.new(0, 290, 0, 40)
detonateBombsBtn.AnchorPoint = Vector2.new(0.5, 1)
detonateBombsBtn.Position = UDim2.new(0.5, 0, 1, -104)
detonateBombsBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
detonateBombsBtn.Text = "💥 DETONATE ALL [R] (0 BOMBS)"
detonateBombsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
detonateBombsBtn.Font = Enum.Font.GothamBlack
detonateBombsBtn.TextSize = 14
detonateBombsBtn.Visible = false
detonateBombsBtn.ZIndex = 7
detonateBombsBtn.Parent = inGameHUD
addCorner(detonateBombsBtn, 11)
addBorderStroke(detonateBombsBtn, Color3.fromRGB(14, 10, 10), 3.0)
addGradient(detonateBombsBtn, Color3.fromRGB(255, 115, 38), Color3.fromRGB(215, 35, 35), 90)
addTextStroke(detonateBombsBtn, 2.0)

detonateBombsBtn.MouseButton1Click:Connect(function()
	playSFX(sfxEvolve, 0.45)
	DetonateStickyBombsEvent:FireServer()
end)

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
					toggleTab("WarpAscend", "STATIONS & WARP")
				end
				return
			end
		end
	end
	if not nearestHubMachineId then
		return
	end
	if nearestHubMachineId == "WarpGate" then
		toggleTab("WarpAscend", "STATIONS & WARP")
	elseif nearestHubMachineId == "DroneBay" then
		toggleTab("Drones", "DRONE SHOP")
	else
		openMachineModal(nearestHubMachineId)
	end
end

proximityPromptBtn.MouseButton1Click:Connect(triggerNearestMachineUI)

-- 8A. BOTTOM-CENTER 5 EQUIPPED DRONE SLOTS DOCK
local bottomDroneSlotsBar = Instance.new("Frame")
bottomDroneSlotsBar.Name = "BottomEquippedDroneSlots"
bottomDroneSlotsBar.Size = UDim2.new(0, 418, 0, 84)
bottomDroneSlotsBar.AnchorPoint = Vector2.new(0.5, 1)
bottomDroneSlotsBar.Position = UDim2.new(0.5, 0, 1, -12)
bottomDroneSlotsBar.BackgroundColor3 = Color3.fromRGB(16, 24, 44)
bottomDroneSlotsBar.BackgroundTransparency = 0.12
bottomDroneSlotsBar.Parent = inGameHUD
addCorner(bottomDroneSlotsBar, 14)
addBorderStroke(bottomDroneSlotsBar, Color3.fromRGB(8, 12, 22), 3.0)

local bottomDroneSlotsLayout = Instance.new("UIListLayout")
bottomDroneSlotsLayout.FillDirection = Enum.FillDirection.Horizontal
bottomDroneSlotsLayout.Padding = UDim.new(0, 8)
bottomDroneSlotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomDroneSlotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bottomDroneSlotsLayout.Parent = bottomDroneSlotsBar

local bottomDroneSlotUIs: {
	{
		Frame: TextButton,
		Stroke: UIStroke,
		Viewport: ViewportFrame,
		EmptyLabel: TextLabel,
		StatPill: Frame,
		StatLabel: TextLabel,
	}
} = {}
local lastBottomSlotsSignature = ""

for slotIdx = 1, 5 do
	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "DroneSlot_" .. tostring(slotIdx)
	slotBtn.Size = UDim2.new(0, 74, 0, 72)
	slotBtn.BackgroundColor3 = Color3.fromRGB(22, 32, 60)
	slotBtn.Text = ""
	slotBtn.AutoButtonColor = false
	slotBtn.Parent = bottomDroneSlotsBar
	addCorner(slotBtn, 10)
	local slotStroke = addBorderStroke(slotBtn, Color3.fromRGB(48, 66, 104), 2.2)

	local slotNumLbl = Instance.new("TextLabel")
	slotNumLbl.Size = UDim2.new(0, 18, 0, 15)
	slotNumLbl.Position = UDim2.new(0, 4, 0, 3)
	slotNumLbl.BackgroundColor3 = Color3.fromRGB(12, 18, 34)
	slotNumLbl.BackgroundTransparency = 0.25
	slotNumLbl.Text = tostring(slotIdx)
	slotNumLbl.TextColor3 = Color3.fromRGB(165, 185, 225)
	slotNumLbl.Font = Enum.Font.GothamBlack
	slotNumLbl.TextSize = 10
	slotNumLbl.ZIndex = 4
	slotNumLbl.Parent = slotBtn
	addCorner(slotNumLbl, 4)

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -6, 1, -20)
	vp.Position = UDim2.new(0, 3, 0, 2)
	vp.BackgroundTransparency = 1
	vp.Visible = false
	vp.Parent = slotBtn

	local emptyLbl = Instance.new("TextLabel")
	emptyLbl.Size = UDim2.new(1, -8, 1, -8)
	emptyLbl.Position = UDim2.new(0, 4, 0, 4)
	emptyLbl.BackgroundTransparency = 1
	emptyLbl.Text = "EMPTY"
	emptyLbl.TextColor3 = Color3.fromRGB(110, 130, 168)
	emptyLbl.Font = Enum.Font.GothamBlack
	emptyLbl.TextSize = 10
	emptyLbl.Parent = slotBtn

	local statPill = Instance.new("Frame")
	statPill.Size = UDim2.new(1, -8, 0, 18)
	statPill.Position = UDim2.new(0, 4, 1, -21)
	statPill.BackgroundColor3 = Color3.fromRGB(14, 20, 38)
	statPill.Visible = false
	statPill.ZIndex = 3
	statPill.Parent = slotBtn
	addCorner(statPill, 5)
	addBorderStroke(statPill, Color3.fromRGB(8, 12, 22), 1.5)

	local statLbl = Instance.new("TextLabel")
	statLbl.Size = UDim2.new(1, -4, 1, 0)
	statLbl.Position = UDim2.new(0, 2, 0, 0)
	statLbl.BackgroundTransparency = 1
	statLbl.Text = "Lv.1 • ⚔️10"
	statLbl.TextColor3 = Color3.fromRGB(125, 245, 180)
	statLbl.Font = Enum.Font.GothamBlack
	statLbl.TextSize = 9
	statLbl.TextTruncate = Enum.TextTruncate.AtEnd
	statLbl.ZIndex = 4
	statLbl.Parent = statPill
	addTextStroke(statLbl, 1.2)

	slotBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.28)
		toggleTab("Drones", "DRONE SHOP")
	end)

	bottomDroneSlotUIs[slotIdx] = {
		Frame = slotBtn,
		Stroke = slotStroke,
		Viewport = vp,
		EmptyLabel = emptyLbl,
		StatPill = statPill,
		StatLabel = statLbl,
	}
end

-- 8B. [Q] SLIDE-OUT ATTACK UPGRADE POPUP MENU (2 Upgrade Slots: Player Damage & Drones' Damage)
local isQUpgradeOpen = false
local qPopupClosedPos = UDim2.new(1, 350, 0.5, 0)
local qPopupOpenPos = UDim2.new(1, -16, 0.5, 0)

local qUpgradeToggleTab = Instance.new("TextButton")
qUpgradeToggleTab.Name = "QUpgradeEdgeButton"
qUpgradeToggleTab.Size = UDim2.new(0, 122, 0, 40)
qUpgradeToggleTab.AnchorPoint = Vector2.new(1, 0.5)
qUpgradeToggleTab.Position = UDim2.new(1, -14, 0.5, 0)
qUpgradeToggleTab.BackgroundColor3 = Color3.fromRGB(27, 45, 88)
qUpgradeToggleTab.Text = "⚔️ [Q] UPGRADES"
qUpgradeToggleTab.TextColor3 = Color3.fromRGB(255, 255, 255)
qUpgradeToggleTab.Font = Enum.Font.GothamBlack
qUpgradeToggleTab.TextSize = 11
qUpgradeToggleTab.Parent = inGameHUD
addCorner(qUpgradeToggleTab, 10)
addBorderStroke(qUpgradeToggleTab, Color3.fromRGB(8, 12, 22), 2.8)
addGradient(qUpgradeToggleTab, Color3.fromRGB(58, 145, 245), Color3.fromRGB(28, 86, 192), 90)
addTextStroke(qUpgradeToggleTab, 1.6)

local qUpgradePopup = Instance.new("Frame")
qUpgradePopup.Name = "QSlideUpgradePopup"
qUpgradePopup.Size = UDim2.new(0, 320, 0, 336)
qUpgradePopup.AnchorPoint = Vector2.new(1, 0.5)
qUpgradePopup.Position = qPopupClosedPos
qUpgradePopup.BackgroundColor3 = Color3.fromRGB(238, 246, 255)
qUpgradePopup.Visible = true
qUpgradePopup.ZIndex = 6
qUpgradePopup.Parent = inGameHUD
addCorner(qUpgradePopup, 16)
addBorderStroke(qUpgradePopup, Color3.fromRGB(10, 14, 26), 3.2)

local qInnerBody = Instance.new("Frame")
qInnerBody.Size = UDim2.new(1, -12, 1, -12)
qInnerBody.Position = UDim2.new(0, 6, 0, 6)
qInnerBody.BackgroundColor3 = Color3.fromRGB(48, 132, 242)
qInnerBody.ZIndex = 6
qInnerBody.Parent = qUpgradePopup
addCorner(qInnerBody, 12)
addBorderStroke(qInnerBody, Color3.fromRGB(22, 68, 152), 2.0)
addGradient(qInnerBody, Color3.fromRGB(64, 152, 255), Color3.fromRGB(30, 104, 218), 90)

local qHeaderTitle = Instance.new("TextLabel")
qHeaderTitle.Size = UDim2.new(1, -56, 0, 32)
qHeaderTitle.Position = UDim2.new(0, 14, 0, 8)
qHeaderTitle.BackgroundTransparency = 1
qHeaderTitle.Text = "⚔️ ATTACK UPGRADES [Q]"
qHeaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
qHeaderTitle.Font = Enum.Font.GothamBlack
qHeaderTitle.TextSize = 16
qHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
qHeaderTitle.ZIndex = 7
qHeaderTitle.Parent = qInnerBody
addTextStroke(qHeaderTitle, 2.0)

local qCloseBtn = Instance.new("TextButton")
qCloseBtn.Size = UDim2.new(0, 32, 0, 32)
qCloseBtn.Position = UDim2.new(1, -40, 0, 8)
qCloseBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
qCloseBtn.Text = "X"
qCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
qCloseBtn.Font = Enum.Font.GothamBlack
qCloseBtn.TextSize = 16
qCloseBtn.ZIndex = 8
qCloseBtn.Parent = qInnerBody
addCorner(qCloseBtn, 8)
addBorderStroke(qCloseBtn, Color3.fromRGB(10, 14, 24), 2.2)
addGradient(qCloseBtn, Color3.fromRGB(255, 72, 68), Color3.fromRGB(204, 28, 28), 90)
addTextStroke(qCloseBtn, 1.8)

local function toggleQUpgradePopup(forceState: boolean?)
	if forceState ~= nil then
		isQUpgradeOpen = forceState
	else
		isQUpgradeOpen = not isQUpgradeOpen
	end
	playSFX(sfxClick, 0.28)
	TweenService:Create(
		qUpgradePopup,
		TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = isQUpgradeOpen and qPopupOpenPos or qPopupClosedPos }
	):Play()
	qUpgradeToggleTab.Visible = not isQUpgradeOpen
end

qCloseBtn.MouseButton1Click:Connect(function()
	toggleQUpgradePopup(false)
end)
qUpgradeToggleTab.MouseButton1Click:Connect(function()
	toggleQUpgradePopup(true)
end)

local qSlotCardsUI: {
	[string]: {
		LevelLabel: TextLabel,
		StatLabel: TextLabel,
		Button: TextButton,
		BtnGradient: UIGradient,
	}
} = {}

do
	local slotConfigs = {
		{
			Id = "DroneAttackDamage",
			Y = 48,
			Title = "🛸 DRONES' ATTACK DAMAGE",
			Accent = Color3.fromRGB(85, 235, 255),
			Desc = "Multiplies all equipped Drones' weapon damage.",
		},
		{
			Id = "DroneReloadSpeed",
			Y = 188,
			Title = "⚡ DRONE RELOAD SPEED",
			Accent = Color3.fromRGB(115, 255, 145),
			Desc = "Decreases the shooting cooldown for your Drones.",
		},
	}

	for _, sc in ipairs(slotConfigs) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -20, 0, 130)
		card.Position = UDim2.new(0, 10, 0, sc.Y)
		card.BackgroundColor3 = Color3.fromRGB(18, 28, 54)
		card.ZIndex = 7
		card.Parent = qInnerBody
		addCorner(card, 12)
		addBorderStroke(card, sc.Accent, 2.2)

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -92, 0, 22)
		titleLbl.Position = UDim2.new(0, 12, 0, 8)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = sc.Title
		titleLbl.TextColor3 = sc.Accent
		titleLbl.Font = Enum.Font.GothamBlack
		titleLbl.TextSize = 13
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.ZIndex = 8
		titleLbl.Parent = card
		addTextStroke(titleLbl, 1.5)

		local lvlLbl = Instance.new("TextLabel")
		lvlLbl.Size = UDim2.new(0, 78, 0, 20)
		lvlLbl.Position = UDim2.new(1, -88, 0, 9)
		lvlLbl.BackgroundTransparency = 1
		lvlLbl.Text = "Lv. 0 / 100"
		lvlLbl.TextColor3 = Color3.fromRGB(215, 235, 255)
		lvlLbl.Font = Enum.Font.GothamBlack
		lvlLbl.TextSize = 11
		lvlLbl.TextXAlignment = Enum.TextXAlignment.Right
		lvlLbl.ZIndex = 8
		lvlLbl.Parent = card
		addTextStroke(lvlLbl, 1.3)

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -24, 0, 20)
		descLbl.Position = UDim2.new(0, 12, 0, 32)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = sc.Desc
		descLbl.TextColor3 = Color3.fromRGB(195, 212, 240)
		descLbl.Font = Enum.Font.GothamBold
		descLbl.TextSize = 10
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.ZIndex = 8
		descLbl.Parent = card

		local statLbl = Instance.new("TextLabel")
		statLbl.Size = UDim2.new(1, -24, 0, 22)
		statLbl.Position = UDim2.new(0, 12, 0, 52)
		statLbl.BackgroundTransparency = 1
		statLbl.Text = "Current: 7 DMG  ➔  Next: +25%"
		statLbl.TextColor3 = Color3.fromRGB(115, 245, 175)
		statLbl.Font = Enum.Font.GothamBlack
		statLbl.TextSize = 12
		statLbl.TextXAlignment = Enum.TextXAlignment.Left
		statLbl.ZIndex = 8
		statLbl.Parent = card
		addTextStroke(statLbl, 1.3)

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(1, -24, 0, 40)
		buyBtn.Position = UDim2.new(0, 12, 1, -48)
		buyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Text = "UPGRADE (10 💎)"
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 14
		buyBtn.ZIndex = 8
		buyBtn.Parent = card
		addCorner(buyBtn, 9)
		addBorderStroke(buyBtn, Color3.fromRGB(10, 16, 10), 2.4)
		addTextStroke(buyBtn, 1.8)

		local btnGrad = Instance.new("UIGradient")
		btnGrad.Rotation = 90
		btnGrad.Color = ColorSequence.new(Color3.fromRGB(108, 248, 56), Color3.fromRGB(46, 188, 20))
		btnGrad.Parent = buyBtn

		local idCopy = sc.Id
		buyBtn.MouseButton1Click:Connect(function()
			playSFX(sfxUpgrade, 0.4)
			UpgradePlanetValueEvent:FireServer(idCopy, false)
		end)

		qSlotCardsUI[sc.Id] = {
			LevelLabel = lvlLbl,
			StatLabel = statLbl,
			Button = buyBtn,
			BtnGradient = btnGrad,
		}
	end
end

local bottomLeftDock = Instance.new("Frame")
bottomLeftDock.Name = "LeftBeveledButtonGrid"
bottomLeftDock.Size = UDim2.new(0, 212, 0, 238)
bottomLeftDock.Position = UDim2.new(0, 16, 0, 146)
bottomLeftDock.BackgroundTransparency = 1
bottomLeftDock.Parent = inGameHUD

do
	local dockGrid = Instance.new("UIGridLayout")
	dockGrid.CellSize = UDim2.new(0, 102, 0, 52)
	dockGrid.CellPadding = UDim2.new(0, 8, 0, 8)
	dockGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	dockGrid.VerticalAlignment = Enum.VerticalAlignment.Top
	dockGrid.SortOrder = Enum.SortOrder.LayoutOrder
	dockGrid.Parent = bottomLeftDock

	local dockBtnOrder = 0
	local function makeSimulatorActionBtn(
		fallbackEmoji: string,
		imageAsset: string,
		label: string,
		accentC: Color3,
		onClick: () -> ()
	)
		dockBtnOrder += 1
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = dockBtnOrder
		btn.BackgroundColor3 = Color3.fromRGB(27, 45, 88)
		btn.Text = ""
		btn.Parent = bottomLeftDock
		addCorner(btn, 12)
		local bStroke = addBorderStroke(btn, Color3.fromRGB(8, 12, 22), 3.0)
		addGradient(btn, Color3.fromRGB(44, 72, 136), Color3.fromRGB(24, 38, 76), 90)

		local topGloss = Instance.new("Frame")
		topGloss.Size = UDim2.new(1, -10, 0.42, 0)
		topGloss.Position = UDim2.new(0, 5, 0, 3)
		topGloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		topGloss.BackgroundTransparency = 0.88
		topGloss.BorderSizePixel = 0
		topGloss.Parent = btn
		addCorner(topGloss, 8)

		local emojiBg = Instance.new("TextLabel")
		emojiBg.Size = UDim2.new(0, 36, 0, 36)
		emojiBg.Position = UDim2.new(0, 5, 0.5, -18)
		emojiBg.BackgroundTransparency = 1
		emojiBg.Text = fallbackEmoji
		emojiBg.TextSize = 22
		emojiBg.Font = Enum.Font.GothamBlack
		emojiBg.Parent = btn

		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(0, 38, 0, 38)
		iconImg.Position = UDim2.new(0, 4, 0.5, -19)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = imageAsset
		iconImg.ScaleType = Enum.ScaleType.Fit
		iconImg.ZIndex = 2
		iconImg.Parent = btn
		addCorner(iconImg, 8)

		local lb = Instance.new("TextLabel")
		lb.Size = UDim2.new(1, -46, 1, 0)
		lb.Position = UDim2.new(0, 44, 0, 0)
		lb.BackgroundTransparency = 1
		lb.Text = label
		lb.TextColor3 = Color3.fromRGB(255, 255, 255)
		lb.Font = Enum.Font.GothamBlack
		lb.TextSize = 11
		lb.TextWrapped = true
		lb.TextXAlignment = Enum.TextXAlignment.Left
		lb.Parent = btn
		addTextStroke(lb, 1.8)

		btn.MouseEnter:Connect(function()
			playSFX(sfxHover, 0.08, 0.06)
			bStroke.Color = accentC
		end)
		btn.MouseLeave:Connect(function()
			bStroke.Color = Color3.fromRGB(8, 12, 22)
		end)
		btn.MouseButton1Click:Connect(onClick)
	end

	makeSimulatorActionBtn("🛸", CUSTOM_UI_ICONS.Drones, "DRONES", Color3.fromRGB(88, 232, 44), function()
		toggleTab("Drones", "DRONE SHOP")
	end)

	makeSimulatorActionBtn("🛒", CUSTOM_UI_ICONS.Shop, "SHOP", Color3.fromRGB(255, 205, 55), function()
		toggleTab("PlanetValue", "PLANET UPGRADES")
	end)

	makeSimulatorActionBtn("📜", CUSTOM_UI_ICONS.Quests, "QUESTS", Color3.fromRGB(255, 215, 75), function()
		playSFX(sfxClick, 0.28)
		topInfoPinned = not topInfoPinned
		updateTopTelemetryVisibility()
	end)

	makeSimulatorActionBtn("🛰️", CUSTOM_UI_ICONS.Stations, "STATIONS", Color3.fromRGB(245, 105, 205), function()
		toggleTab("WarpAscend", "STATIONS & WARP")
	end)

	makeSimulatorActionBtn("🧬", CUSTOM_UI_ICONS.Evolve, "EVOLVE", Color3.fromRGB(190, 110, 255), function()
		toggleTab("Evolution", "EVOLUTION TREE")
	end)

	makeSimulatorActionBtn("🎨", CUSTOM_UI_ICONS.Customize, "CUSTOMIZE", Color3.fromRGB(110, 215, 255), function()
		playSFX(sfxClick, 0.28)
		modalFrame.Visible = false
		activeTab = nil
		isCustomizingOverlayOpen = true
		switchMainMenuTab("Customize")
		refreshUI()
	end)

	makeSimulatorActionBtn("🧬", CUSTOM_UI_ICONS.Evolve, "CLASS PATH", Color3.fromRGB(108, 248, 56), function()
		toggleTab("DronePath", "DIEP.IO DRONE PATH")
	end)

	makeSimulatorActionBtn("🌀", CUSTOM_UI_ICONS.Stations, "HUB WARP", Color3.fromRGB(120, 245, 205), function()
		playSFX(sfxLaunch, 0.35)
		localPlanetPos = HUB_SPAWN_POS
		localVelocity = Vector3.zero
		TeleportToHubEvent:FireServer()
	end)
end

-- ============================================================================
-- 9. EVOLUTION TREE & 6-TRACK PLANET UPGRADES PAGES
-- ============================================================================
local evoNodeButtons: { [string]: { Button: TextButton, Stroke: UIStroke } } = {}
do
	local evoList = Instance.new("UIListLayout")
	evoList.Padding = UDim.new(0, 10)
	evoList.Parent = evolutionPage

for _, bInfo in ipairs(SpeciesConfig.BranchOrder) do
	local branchRow = Instance.new("Frame")
	branchRow.Size = UDim2.new(1, -12, 0, 132)
	branchRow.BackgroundColor3 = Color3.fromRGB(14, 20, 36)
	branchRow.Parent = evolutionPage
	addCorner(branchRow, 10)
	addBorderStroke(branchRow, bInfo.Color, 1.2)

	local bHdr = Instance.new("TextLabel")
	bHdr.Size = UDim2.new(0, 175, 1, -16)
	bHdr.Position = UDim2.new(0, 12, 0, 8)
	bHdr.BackgroundTransparency = 1
	bHdr.Text = (bInfo.Title or bInfo.Name) .. "\n\n" .. (bInfo.Subtitle or "")
	bHdr.TextColor3 = bInfo.Color
	bHdr.Font = Enum.Font.GothamBlack
	bHdr.TextSize = 12
	bHdr.TextWrapped = true
	bHdr.TextXAlignment = Enum.TextXAlignment.Left
	bHdr.Parent = branchRow

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
		nCard.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
		nCard.Parent = nContainer
		addCorner(nCard, 8)
		local nStroke = addBorderStroke(nCard, bInfo.Color, 1.2)

		local nTitle = Instance.new("TextLabel")
		nTitle.Size = UDim2.new(1, -10, 0, 20)
		nTitle.Position = UDim2.new(0, 5, 0, 4)
		nTitle.BackgroundTransparency = 1
		nTitle.Text = string.format("T%d // %s", node.Tier, node.Name)
		nTitle.TextColor3 = Color3.fromRGB(240, 246, 255)
		nTitle.Font = Enum.Font.GothamBlack
		nTitle.TextSize = 11
		nTitle.TextWrapped = true
		nTitle.Parent = nCard

		local nPerk = Instance.new("TextLabel")
		nPerk.Size = UDim2.new(1, -10, 0, 38)
		nPerk.Position = UDim2.new(0, 5, 0, 25)
		nPerk.BackgroundTransparency = 1
		nPerk.Text = node.PerkSummary
		nPerk.TextColor3 = Color3.fromRGB(120, 235, 185)
		nPerk.Font = Enum.Font.GothamMedium
		nPerk.TextSize = 10
		nPerk.TextWrapped = true
		nPerk.Parent = nCard

		local nCost = Instance.new("TextLabel")
		nCost.Size = UDim2.new(1, -10, 0, 16)
		nCost.Position = UDim2.new(0, 5, 0, 64)
		nCost.BackgroundTransparency = 1
		nCost.Text = formatCost(node.Cost)
		nCost.TextColor3 = Color3.fromRGB(255, 220, 95)
		nCost.Font = Enum.Font.GothamBold
		nCost.TextSize = 10
		nCost.Parent = nCard

		local nBtn = Instance.new("TextButton")
		nBtn.Size = UDim2.new(1, -12, 0, 28)
		nBtn.Position = UDim2.new(0, 6, 1, -33)
		nBtn.BackgroundColor3 = bInfo.Color
		nBtn.Text = "EVOLVE"
		nBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		nBtn.Font = Enum.Font.GothamBlack
		nBtn.TextSize = 11
		nBtn.Parent = nCard
		addCorner(nBtn, 6)

		nBtn.MouseButton1Click:Connect(function()
			playSFX(sfxEvolve, 0.45)
			UnlockEvolutionEvent:FireServer(node.Id)
		end)

		evoNodeButtons[node.Id] = { Button = nBtn, Stroke = nStroke }
	end
end
end

-- Planet Value Upgrades Grid (6 Upgrade Tracks with +1 Level & BUY MAX!)
local upgradeCardsUI: { [string]: { LevelLabel: TextLabel, CostLabel: TextLabel, BuyOneBtn: TextButton, BuyMaxBtn: TextButton } } = {}
do
	local upgGrid = Instance.new("UIGridLayout")
	upgGrid.CellSize = UDim2.new(0, 405, 0, 152)
	upgGrid.CellPadding = UDim2.new(0, 12, 0, 12)
	upgGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	upgGrid.Parent = planetValuePage

for _, upg in ipairs(PlanetConfig.PlanetUpgrades) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(14, 20, 36)
	card.Parent = planetValuePage
	addCorner(card, 10)
	addBorderStroke(card, Color3.fromRGB(245, 195, 65), 1.2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -120, 0, 24)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = upg.Name
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local lvlLbl = Instance.new("TextLabel")
	lvlLbl.Size = UDim2.new(0, 100, 0, 22)
	lvlLbl.Position = UDim2.new(1, -112, 0, 9)
	lvlLbl.BackgroundTransparency = 1
	lvlLbl.Text = "Lv. 0 / 75"
	lvlLbl.TextColor3 = Color3.fromRGB(85, 225, 250)
	lvlLbl.Font = Enum.Font.GothamBlack
	lvlLbl.TextSize = 12
	lvlLbl.TextXAlignment = Enum.TextXAlignment.Right
	lvlLbl.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -28, 0, 38)
	desc.Position = UDim2.new(0, 14, 0, 34)
	desc.BackgroundTransparency = 1
	desc.Text = upg.Description
	desc.TextColor3 = Color3.fromRGB(205, 220, 245)
	desc.Font = Enum.Font.GothamMedium
	desc.TextSize = 11
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = card

	local costLbl = Instance.new("TextLabel")
	costLbl.Size = UDim2.new(1, -28, 0, 20)
	costLbl.Position = UDim2.new(0, 14, 0, 76)
	costLbl.BackgroundTransparency = 1
	costLbl.Text = "Cost: ..."
	costLbl.TextColor3 = Color3.fromRGB(105, 240, 165)
	costLbl.Font = Enum.Font.GothamBold
	costLbl.TextSize = 12
	costLbl.TextXAlignment = Enum.TextXAlignment.Left
	costLbl.Parent = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.62, -18, 0, 38)
	buyBtn.Position = UDim2.new(0, 14, 1, -46)
	buyBtn.BackgroundColor3 = Color3.fromRGB(40, 185, 110)
	buyBtn.Text = "UPGRADE (+1)"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextSize = 12
	buyBtn.Parent = card
	addCorner(buyBtn, 7)

	local buyMaxBtn = Instance.new("TextButton")
	buyMaxBtn.Size = UDim2.new(0.38, -14, 0, 38)
	buyMaxBtn.Position = UDim2.new(0.62, 4, 1, -46)
	buyMaxBtn.BackgroundColor3 = Color3.fromRGB(225, 165, 35)
	buyMaxBtn.Text = "⚡ BUY MAX"
	buyMaxBtn.TextColor3 = Color3.fromRGB(14, 18, 28)
	buyMaxBtn.Font = Enum.Font.GothamBlack
	buyMaxBtn.TextSize = 12
	buyMaxBtn.Parent = card
	addCorner(buyMaxBtn, 7)

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
end

-- ============================================================================
-- 9B. PER-DRONE ORBIT, LONG-RANGE SCOUT FLIGHT, STICKY BOMBS & PROJECTILE VFX
-- ============================================================================
type ActiveDroneEntry = {
	Model: Model,
	Uid: string,
	Phase: number,
	DroneId: string,
	BeamColor: Color3,
	CurrentPos: Vector3,
	FireTimer: number,
	RecoilOffset: Vector3,
	Stats: any,
}

local activeDroneModels: { ActiveDroneEntry } = {}
local lastDroneSignature = ""
local activeDroneTarget: Model? = nil

local beamFXFolder = Workspace:FindFirstChild("ClientDroneBeamFX")
if beamFXFolder then
	beamFXFolder:Destroy()
end
beamFXFolder = Instance.new("Folder")
beamFXFolder.Name = "ClientDroneBeamFX"
beamFXFolder.Parent = Workspace

local stickyBombsFolder = Workspace:FindFirstChild("ClientStickyBombs")
if stickyBombsFolder then
	stickyBombsFolder:Destroy()
end
stickyBombsFolder = Instance.new("Folder")
stickyBombsFolder.Name = "ClientStickyBombs"
stickyBombsFolder.Parent = Workspace

type ClientBombEntry = {
	Model: Model,
	OwnerUserId: number,
	TargetModel: Model?,
	TargetRoot: BasePart?,
	LocalOffset: Vector3,
	WorldPos: Vector3,
	Color: Color3,
	PlacedAt: number,
}
local activeStickyBombs: { [string]: ClientBombEntry } = {}

local function countLocalStickyBombs(): number
	local c = 0
	for _, b in pairs(activeStickyBombs) do
		if b.OwnerUserId == localPlayer.UserId then
			c += 1
		end
	end
	return c
end

local function rebuildOrbitingDrones()
	local owned = currentState.Companions or currentState.OwnedCompanions or {}
	local sigParts = { tostring(is2DMenuActive()) }
	for _, entry in ipairs(owned) do
		if entry.Equipped then
			local isGold = (entry.IsGolden == true) or (entry.Golden == true)
			local lvl = entry.Level or 1
			table.insert(sigParts, string.format("%s:%s:%s:%d", tostring(entry.Uid), tostring(entry.Id), tostring(isGold), lvl))
		end
	end
	local sig = table.concat(sigParts, "|")
	if sig == lastDroneSignature then
		return
	end
	lastDroneSignature = sig

	local prevPositions: { [string]: Vector3 } = {}
	for _, d in ipairs(activeDroneModels) do
		if d.Uid then
			prevPositions[d.Uid] = d.CurrentPos
		end
		if d.Model then
			d.Model:Destroy()
		end
	end
	table.clear(activeDroneModels)

	if is2DMenuActive() then
		return
	end

	local idx = 0
	for _, entry in ipairs(owned) do
		if entry.Equipped then
			idx += 1
			local isGold = (entry.IsGolden == true) or (entry.Golden == true)
			local lvl = entry.Level or 1
			local cDef = PlanetConfig.Companions[entry.Id]
			local dStats = PlanetConfig.GetDroneStats(entry.Id, lvl, isGold)
			local dm = PlanetGenerator.BuildCompanionDroneModel(entry.Id, isGold, lvl)
			dm.Parent = Workspace
			local uid = tostring(entry.Uid)
			table.insert(activeDroneModels, {
				Model = dm,
				Uid = uid,
				Phase = idx * ((math.pi * 2) / math.max(1, #sigParts - 1)),
				DroneId = entry.Id,
				BeamColor = (cDef and cDef.BeamColor) or Color3.fromRGB(85, 225, 255),
				CurrentPos = prevPositions[uid] or (localPlanetPos + Vector3.new(0, 12, 0)),
				FireTimer = dStats.FireCooldown,
				RecoilOffset = Vector3.zero,
				Stats = dStats,
			})
		end
	end
end

local function spawnLaserBeamSegment(fromPos: Vector3, toPos: Vector3, beamColor: Color3, thickness: number?, fadeTime: number?)
	local diff = toPos - fromPos
	local dist = diff.Magnitude
	if dist < 0.5 or dist > 1100 then
		return
	end
	local mid = fromPos + diff * 0.5
	local bWidth = thickness or 0.55
	local dur = fadeTime or 0.20

	local beamPart = Instance.new("Part")
	beamPart.Name = "DroneLaserBeam"
	beamPart.Shape = Enum.PartType.Cylinder
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CastShadow = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = beamColor
	beamPart.Transparency = 0.06
	beamPart.Size = Vector3.new(dist, bWidth, bWidth)
	beamPart.CFrame = CFrame.lookAt(mid, toPos) * CFrame.Angles(0, math.rad(90), 0)
	beamPart.Parent = beamFXFolder

	TweenService:Create(beamPart, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(dist, bWidth * 0.14, bWidth * 0.14),
	}):Play()
	task.delay(dur + 0.03, function()
		if beamPart and beamPart.Parent then
			beamPart:Destroy()
		end
	end)
end

local function spawnHitImpactFX(pos: Vector3, color: Color3, size: number, textStr: string?, textCol: Color3?, duration: number?)
	if (pos - localPlanetPos).Magnitude > 950 then
		return
	end
	local spark = Instance.new("Part")
	spark.Name = "LaserHitSpark"
	spark.Shape = Enum.PartType.Ball
	spark.Anchored = true
	spark.CanCollide = false
	spark.CastShadow = false
	spark.Material = Enum.Material.Neon
	spark.Color = color
	spark.Transparency = 0.15
	spark.Size = Vector3.new(size, size, size)
	spark.CFrame = CFrame.new(pos)
	spark.Parent = beamFXFolder

	local dur = duration or 0.34
	if textStr and #textStr > 0 then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(110, 28)
		bb.StudsOffset = Vector3.new(0, 4.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 420
		bb.Adornee = spark
		bb.Parent = spark

		local dmgLbl = Instance.new("TextLabel")
		dmgLbl.Size = UDim2.fromScale(1, 1)
		dmgLbl.BackgroundTransparency = 1
		dmgLbl.Text = textStr
		dmgLbl.TextColor3 = textCol or Color3.fromRGB(255, 255, 255)
		dmgLbl.Font = Enum.Font.GothamBlack
		dmgLbl.TextSize = 13
		dmgLbl.Parent = bb
		addTextStroke(dmgLbl, 1.2)

		TweenService:Create(bb, TweenInfo.new(dur + 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = Vector3.new(0, 10, 0),
		}):Play()
	end

	TweenService:Create(spark, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(size * 2.3, size * 2.3, size * 2.3),
	}):Play()
	task.delay(dur + 0.08, function()
		if spark and spark.Parent then
			spark:Destroy()
		end
	end)
end

local function spawnVoxelBlastFX(center: Vector3, radius: number, color: Color3, dmg: number?)
	if (center - localPlanetPos).Magnitude > 950 then
		return
	end
	local dmgTxt = (dmg and dmg > 0) and ("💥 -" .. PlanetConfig.FormatNumber(dmg)) or nil
	spawnHitImpactFX(center, color, math.clamp(radius * 0.48, 8, 22), dmgTxt, Color3.fromRGB(255, 215, 75), 0.45)

	-- Burst of glowing voxel cube debris
	for k = 1, 7 do
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		if dir.Magnitude < 0.05 then
			dir = Vector3.new(0, 1, 0)
		else
			dir = dir.Unit
		end
		local cube = Instance.new("Part")
		cube.Shape = Enum.PartType.Block
		cube.Anchored = true
		cube.CanCollide = false
		cube.CastShadow = false
		cube.Material = (k % 2 == 0) and Enum.Material.Neon or Enum.Material.SmoothPlastic
		cube.Color = (k % 2 == 0) and color or Color3.fromRGB(255, 195, 55)
		local sz = 1.6 + math.random() * 1.4
		cube.Size = Vector3.new(sz, sz, sz)
		cube.CFrame = CFrame.new(center) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
		cube.Parent = beamFXFolder

		local endCF = CFrame.new(center + dir * math.clamp(radius * 0.72, 10, 32)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		TweenService:Create(cube, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = endCF,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
		}):Play()
		task.delay(0.45, function()
			if cube and cube.Parent then
				cube:Destroy()
			end
		end)
	end
end

local function findActiveDroneByUid(uid: string?): ActiveDroneEntry?
	if uid then
		for _, dInfo in ipairs(activeDroneModels) do
			if dInfo.Uid == uid and dInfo.Model and dInfo.Model.Parent then
				return dInfo
			end
		end
	end
	return activeDroneModels[1]
end

local function getDroneMuzzlePos(dInfo: ActiveDroneEntry?): Vector3
	if not dInfo or not dInfo.Model or not dInfo.Model.Parent then
		return localPlanetPos
	end
	local root = dInfo.Model.PrimaryPart
	local muzzle = root and root:FindFirstChild("BeamMuzzle") :: Attachment?
	return (muzzle and muzzle.WorldPosition) or dInfo.Model:GetPivot().Position
end

StickyBombFXEvent.OnClientEvent:Connect(function(action: string, ownerUserId: number, payload: any)
	if action == "ClearPlayer" then
		for bId, bEntry in pairs(activeStickyBombs) do
			if bEntry.OwnerUserId == ownerUserId then
				if bEntry.Model and bEntry.Model.Parent then
					bEntry.Model:Destroy()
				end
				activeStickyBombs[bId] = nil
			end
		end
		return
	elseif action == "RemoveByTarget" then
		local targetModel = payload
		for bId, bEntry in pairs(activeStickyBombs) do
			if bEntry.TargetModel == targetModel then
				if bEntry.Model and bEntry.Model.Parent then
					bEntry.Model:Destroy()
				end
				activeStickyBombs[bId] = nil
			end
		end
		return
	elseif action == "Remove" and type(payload) == "table" and payload.BombId then
		local entry = activeStickyBombs[payload.BombId]
		if entry then
			if entry.Model and entry.Model.Parent then
				entry.Model:Destroy()
			end
			activeStickyBombs[payload.BombId] = nil
		end
		return
	elseif action == "DetonateAll" then
		for bId, bEntry in pairs(activeStickyBombs) do
			if bEntry.OwnerUserId == ownerUserId then
				if bEntry.Model and bEntry.Model.Parent then
					bEntry.Model:Destroy()
				end
				activeStickyBombs[bId] = nil
			end
		end
		if type(payload) == "table" then
			playSFX(sfxEvolve, 0.42, 0.14)
			for _, blast in ipairs(payload) do
				if typeof(blast.Pos) == "Vector3" then
					spawnVoxelBlastFX(blast.Pos, blast.Radius or 32, blast.Color or Color3.fromRGB(255, 95, 45), blast.Damage)
				end
			end
		end
		return
	elseif action == "Attach" and type(payload) == "table" and payload.BombId then
		local bColor = payload.Color or Color3.fromRGB(255, 85, 45)
		local bScale = payload.Scale or 1.0
		local destPos = payload.WorldPos or localPlanetPos

		local startPos = destPos
		if ownerUserId == localPlayer.UserId then
			local shooter = findActiveDroneByUid(payload.DroneUid)
			startPos = getDroneMuzzlePos(shooter)
		end

		local bombModel = PlanetGenerator.BuildStickyBombModel(bColor, bScale)
		bombModel.Parent = stickyBombsFolder
		local rotCF = CFrame.Angles(math.random() * 0.6, math.random() * 6.28, math.random() * 0.6)
		bombModel:PivotTo(CFrame.new(startPos) * rotCF)

		local entry: ClientBombEntry = {
			Model = bombModel,
			OwnerUserId = ownerUserId,
			TargetModel = payload.TargetModel,
			TargetRoot = payload.TargetRoot,
			LocalOffset = payload.LocalOffset or Vector3.zero,
			WorldPos = destPos,
			Color = bColor,
			PlacedAt = os.clock(),
		}
		activeStickyBombs[payload.BombId] = entry

		-- Smooth fast 0.14s visual lob from drone barrel to stick point
		local lobSteps = 6
		task.spawn(function()
			for step = 1, lobSteps do
				if not bombModel.Parent or activeStickyBombs[payload.BombId] ~= entry then
					return
				end
				local alpha = step / lobSteps
				local liveDest = destPos
				if entry.TargetRoot and entry.TargetRoot.Parent and entry.TargetRoot:GetAttribute("Available") ~= false then
					liveDest = entry.TargetRoot.CFrame:PointToWorldSpace(entry.LocalOffset)
				end
				local p = startPos:Lerp(liveDest, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 3.5, 0)
				bombModel:PivotTo(CFrame.new(p) * rotCF)
				task.wait(0.022)
			end
		end)
	end
end)

DroneBeamFXEvent.OnClientEvent:Connect(function(
	shooterUserId: number,
	targetModel: Model?,
	totalDamage: number,
	destroyed: boolean,
	hitPosArg: Vector3?,
	fxData: any?
)
	local targetPos = hitPosArg
	if not targetPos and targetModel and targetModel.Parent then
		targetPos = targetModel:GetPivot().Position
	end
	if not targetPos then
		return
	end

	local style = (type(fxData) == "table" and fxData.Style) or "Standard"
	local beamColor = (type(fxData) == "table" and fxData.BeamColor) or Color3.fromRGB(115, 235, 255)

	if shooterUserId == localPlayer.UserId then
		if targetModel and targetModel.Parent and not destroyed then
			activeDroneTarget = targetModel
		elseif destroyed and activeDroneTarget == targetModel then
			activeDroneTarget = nil
		end

		local dInfo = findActiveDroneByUid(type(fxData) == "table" and fxData.DroneUid or nil)
		local startPos = getDroneMuzzlePos(dInfo)
		local c = (type(fxData) == "table" and fxData.BeamColor) or (dInfo and dInfo.BeamColor) or beamColor

		if style == "SpreadPellet" and type(fxData) == "table" and type(fxData.PelletHits) == "table" then
			for _, pt in ipairs(fxData.PelletHits) do
				if typeof(pt) == "Vector3" then
					spawnLaserBeamSegment(startPos, pt, c, 0.36, 0.16)
				end
			end
		elseif style == "HeavySlug" then
			spawnLaserBeamSegment(startPos, targetPos, c, 1.55, 0.30)
			if type(fxData) == "table" and (fxData.BlastRadius or 0) > 0 then
				spawnVoxelBlastFX(targetPos, math.min(22, fxData.BlastRadius), c, nil)
			end
		elseif style == "SniperBeam" then
			spawnLaserBeamSegment(startPos, targetPos, c, 0.42, 0.32)
		elseif style == "RapidBolt" then
			spawnLaserBeamSegment(startPos, targetPos, c, 0.32, 0.12)
		else
			spawnLaserBeamSegment(startPos, targetPos, c, 0.58, 0.20)
		end
	else
		local pFolder = Workspace:FindFirstChild("PlayerPlanets")
		if pFolder then
			for _, pm in ipairs(pFolder:GetChildren()) do
				if pm:IsA("Model") and pm:GetAttribute("OwnerUserId") == shooterUserId then
					spawnLaserBeamSegment(pm:GetPivot().Position, targetPos, Color3.fromRGB(255, 115, 95), 0.65, 0.20)
					break
				end
			end
		end
	end

	-- Impact Spark & Floating Damage Callout (visible even for Long-Range Sniper hits!)
	if totalDamage and totalDamage > 0 then
		local initSz = destroyed and 6.0 or ((style == "HeavySlug") and 5.2 or 2.8)
		local col = destroyed and Color3.fromRGB(255, 215, 75) or beamColor
		local txt = (destroyed and "💥 -" or "-") .. PlanetConfig.FormatNumber(totalDamage)
		spawnHitImpactFX(targetPos, col, initSz, txt, col, 0.32)
	end
end)

-- ============================================================================
-- 10. STATE SYNC & LIVE UI REFRESH
-- ============================================================================
local function getMissionProgressLocal(goalType: string): number
	if goalType == "ResourceMinerals" then
		return (currentState.Resources and currentState.Resources.Minerals) or 0
	elseif goalType == "DroneLevels" then
		return currentState.DroneLevels or 0
	elseif goalType == "TotalUpgrades" then
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
		return (currentState.Rates and currentState.Rates.DrillPower) or 1
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
	local menu2D = is2DMenuActive()
	genesisContainer.Visible = menu2D
	inGameHUD.Visible = not menu2D
	launchBtn.Text = isCustomizingOverlayOpen and "🚀 APPLY & RETURN TO SPACE!" or "🚀 PLAY & SPAWN IN GALACTIC HUB!"

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not menu2D)
	end)

	refreshShowroomAndActivePlanetModels()
	rebuildOrbitingDrones()

	if menu2D then
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
					ui.Stroke.Thickness = 2.2
				else
					ui.Button.BackgroundColor3 = Color3.fromRGB(38, 52, 92)
					ui.Stroke.Color = Color3.fromRGB(255, 255, 255)
					ui.Stroke.Thickness = 1.2
				end
			end
		end

		for spId, ui in pairs(speciesSelectButtons) do
			if spId == currentState.SpeciesId then
				ui.Button.Text = "✓ SELECTED SPECIES"
				ui.Button.BackgroundColor3 = Color3.fromRGB(45, 210, 115)
				ui.Stroke.Thickness = 2.4
			else
				local sDef = SpeciesConfig.Species[spId]
				ui.Button.Text = "SELECT SPECIES"
				ui.Button.BackgroundColor3 = sDef.PrimaryColor
				ui.Stroke.Thickness = 1.4
			end
		end
	end

	local rates = currentState.Rates or {}
	local res = currentState.Resources or {}
	local ownedDrones = currentState.Companions or {}
	local eqCount = 0
	for _, entry in ipairs(ownedDrones) do
		if entry.Equipped then
			eqCount += 1
		end
	end
	local maxSlots = currentState.MaxEquippedDrones or rates.MaxEquippedDrones or 5
	local drillPower = rates.DrillPower or 0
	local droneDamage = rates.DroneDamage or 0
	local fleetDPS = rates.DroneDPS or droneDamage

	-- Update Top-Left Currency Bars, Level/XP Bar & Modal Header Mini Pills
	local playerLvl = currentState.Level or 1
	local curXP = currentState.XP or 0
	local reqXP = currentState.XPToNextLevel or PlanetConfig.GetXPForLevel(playerLvl)
	local xpRatio = math.clamp(curXP / math.max(1, reqXP), 0, 1)

	levelXPBarFill.Size = UDim2.new(xpRatio, 0, 1, 0)
	local pathHint = (playerLvl < (PlanetConfig.DronePathUnlockLevels.Tier1 or 5)) and "  •  Path @ Lv.5" or ""
	levelXPBarText.Text = string.format(
		"⭐ LEVEL %d  •  %s / %s XP%s",
		playerLvl,
		PlanetConfig.FormatNumber(curXP),
		PlanetConfig.FormatNumber(reqXP),
		pathHint
	)
	topLeftLevelXPLbl.Text = string.format(
		"⭐ LV.%d  •  %s / %s XP",
		playerLvl,
		PlanetConfig.FormatNumber(curXP),
		PlanetConfig.FormatNumber(reqXP)
	)

	statCards.Minerals.ValueLabel.Text = PlanetConfig.FormatNumber(res.Minerals or 0)

	modalHeaderOreLbl.Text = "⛏ " .. PlanetConfig.FormatNumber(res.Minerals or 0)

	-- Update Top-Center Status Banner + Orange-Red Sub-Banner + Collapsible Drawer
	local rIdx = currentState.RankIndex or 1
	local rankDef = PlanetConfig.PlanetaryRanks[rIdx] or PlanetConfig.PlanetaryRanks[1]
	local nextRankDef = PlanetConfig.PlanetaryRanks[rIdx + 1]
	local ascCount = currentState.Ascensions or 0
	local ascMult = math.pow(2.5, ascCount)
	local ascTag = (ascCount > 0) and string.format(" • ASC.%d (%sx)", ascCount, PlanetConfig.FormatNumber(ascMult)) or ""

	local zTier = rates.CurrentZoneTier or 1
	local zShortNames = { "Sanctuary Orbit", "Golden Belt", "Bio-Nebula", "Magma Rift", "Void Core", "Eternity Singularity" }
	topCompactSummaryLbl.Text = string.format("NOW: %s", zShortNames[zTier] or ("Zone " .. tostring(zTier)))
	topCompactBadge.Text = string.format("Rank %d  •  %d/%d Drones Active", rankDef.Rank, eqCount, maxSlots)
	topRallyText.Text = string.format("🔥 DRILL x%s  •  DPS %s", PlanetConfig.FormatNumber(drillPower), PlanetConfig.FormatNumber(fleetDPS))

	local activeBoostTags = {}
	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local rem = (currentState.ActiveBoosters and currentState.ActiveBoosters[bDef.Id]) or 0
		if rem > 0 then
			table.insert(activeBoostTags, string.format("%s %s", bDef.Icon, formatSecondsMMSS(rem)))
		end
	end
	local nextStationText = "All Gates Unlocked"
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		local isUnl = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
		if not isUnl then
			local d = math.floor((st.Position - localPlanetPos).Magnitude)
			nextStationText = string.format("Next Gate: %s (%s studs • %s💎)", st.Name, PlanetConfig.FormatNumber(d), PlanetConfig.FormatNumber(st.GemCost))
			break
		end
	end
	local boostSummary = (#activeBoostTags > 0) and (" • " .. table.concat(activeBoostTags, " ")) or ""
	boosterStatusLbl.Text = string.format(
		"🛸 Drones: %d/%d  •  🔨 Drill: %s (Req %s)  •  ⚔️ DPS: %s  •  %s%s",
		eqCount,
		maxSlots,
		PlanetConfig.FormatNumber(drillPower),
		PlanetConfig.FormatNumber(rates.CurrentZoneReqDrill or 1),
		PlanetConfig.FormatNumber(fleetDPS),
		nextStationText,
		boostSummary
	)

	rankTitleLbl.Text = string.format(
		"RANK %d // %s (%sx YIELD)%s",
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
		rankBarText.Text = string.format("MAX PLANETARY RANK ACHIEVED (Value: %s)", PlanetConfig.FormatNumber(currentState.PlanetValueScore))
	end

	if rates.ActiveDistrictName and #rates.ActiveDistrictName > 0 then
		zoneTitleLbl.Text = string.format("HUB TERMINAL // %s • Press [E] to Access", rates.ActiveDistrictName)
		zoneTitleLbl.TextColor3 = Color3.fromRGB(255, 225, 95)
	else
		local zTier = rates.CurrentZoneTier or 1
		local zDef = PlanetConfig.DeepSpaceZones[zTier] or PlanetConfig.DeepSpaceZones[1]
		zoneTitleLbl.Text = string.format("%s • Click Asteroids/Enemies or Fly Close to Mine", rates.CurrentSectorName or zDef.Name)
		zoneTitleLbl.TextColor3 = zDef.ThemeColor
	end

	-- Update Guided Mission Card
	local mIdx = currentState.MissionIndex or 1
	local mDef = PlanetConfig.Missions[mIdx]
	if mDef then
		missionHeader.Text = string.format("DIRECTIVE %02d // %s", mDef.Id, string.upper(mDef.Title))
		missionDescLbl.Text = mDef.Description
		local curProg = getMissionProgressLocal(mDef.GoalType)
		local ratio = math.clamp(curProg / math.max(1, mDef.Target), 0, 1)
		missionBarFill.Size = UDim2.new(ratio, 0, 1, 0)
		missionBarText.Text = string.format("%s / %s", PlanetConfig.FormatNumber(curProg), PlanetConfig.FormatNumber(mDef.Target))
		missionRewardLbl.Text = "REWARD // " .. formatCost(mDef.Reward)
	else
		missionHeader.Text = "ALL DIRECTIVES COMPLETED"
		missionDescLbl.Text = "Unlock Deep-Space Station Warp Gates or Ascend your planet!"
		missionBarFill.Size = UDim2.new(1, 0, 1, 0)
		missionBarText.Text = "COMPLETE"
		missionRewardLbl.Text = "Ready for Planetary Ascension"
	end

	-- Update Hub Machine Cards UI
	local mTiers = currentState.MachineTiers or {}
	local machineBases: { [string]: { Base: number, Label: string } } = {
		DysonReactor = { Base = 0.42, Label = "Flux & All-Yield Boost" },
		TitanRefinery = { Base = 0.48, Label = "Ore & +🔨 Drill Power" },
		GaiaBioVat = { Base = 0.45, Label = "Spores & Citizen Wave" },
		AstralObservatory = { Base = 0.50, Label = "Alloy & Gem Discovery" },
	}
	for mId, ui in pairs(machineCardsUI) do
		local mConfig = PlanetConfig.HubMachines[mId]
		if mConfig and machineBases[mId] then
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
	end

	-- Update Deep-Space Stations, Ascension & Cosmic Shard Shop UI
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		local ui = warpStationBtns[st.Id]
		if ui then
			local isUnlocked = (st.GemCost == 0) or (currentState.UnlockedStations and currentState.UnlockedStations[st.Id] == true)
			if isUnlocked then
				ui.Btn.Text = "🌀 WARP HERE"
				ui.Btn.BackgroundColor3 = st.Color
				ui.ReqLabel.Text = "✓ WARP GATE UNLOCKED & ACTIVE"
				ui.ReqLabel.TextColor3 = Color3.fromRGB(105, 245, 165)
			else
				ui.Btn.Text = string.format("🔓 UNLOCK (%s 💎)", PlanetConfig.FormatNumber(st.GemCost))
				local canUnlock = (currentState.Gems or 0) >= st.GemCost and drillPower >= (st.ReqDrill or 0)
				ui.Btn.BackgroundColor3 = canUnlock and Color3.fromRGB(45, 205, 115) or Color3.fromRGB(65, 58, 92)
				ui.ReqLabel.Text = string.format(
					"Requires 🔨 %s Drill Power  •  Unlock Cost: %s 💎 Gems",
					PlanetConfig.FormatNumber(st.ReqDrill or 0),
					PlanetConfig.FormatNumber(st.GemCost)
				)
				ui.ReqLabel.TextColor3 = canUnlock and Color3.fromRGB(255, 225, 95) or Color3.fromRGB(255, 115, 115)
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
				ui.Btn.BackgroundColor3 = Color3.fromRGB(55, 68, 95)
			else
				local cost = math.floor(sUpg.BaseShardCost * math.pow(sUpg.CostScale, lvl))
				ui.Btn.Text = string.format("🪐 %d SHARDS", cost)
				ui.Btn.BackgroundColor3 = ((currentState.CosmicShards or 0) >= cost) and Color3.fromRGB(155, 60, 225) or Color3.fromRGB(65, 52, 85)
			end
		end
	end

	-- Update Drone Foundry Summary, Slot Upgrade Button, Vertical Rarity Cards & Spotlight Inspector
	if droneSummaryLabel then
		droneSummaryLabel.Text = string.format(
			"SLOTS: %d/%d  •  🔨 %s  •  ⚔️ %s",
			eqCount,
			maxSlots,
			PlanetConfig.FormatNumber(drillPower),
			PlanetConfig.FormatNumber(fleetDPS)
		)
	end
	if buyDroneSlotBtn then
		local slotLvl = currentState.DroneSlotLevel or 0
		local nextSlotDef = PlanetConfig.DroneSlotUpgrades[slotLvl + 1]
		if nextSlotDef then
			local canBuy = (currentState.Gems or 0) >= nextSlotDef.GemCost
			buyDroneSlotBtn.Text = string.format("+SLOT #%d (%s💎)", nextSlotDef.SlotNumber, PlanetConfig.FormatNumber(nextSlotDef.GemCost))
			buyDroneSlotBtn.BackgroundColor3 = canBuy and Color3.fromRGB(215, 62, 242) or Color3.fromRGB(55, 48, 82)
			if robuxDroneSlotBtn then
				robuxDroneSlotBtn.Text = string.format("R$ %d", nextSlotDef.RobuxCost or 99)
			end
		else
			buyDroneSlotBtn.Text = "✓ MAX SLOTS"
			buyDroneSlotBtn.BackgroundColor3 = Color3.fromRGB(45, 62, 88)
			if robuxDroneSlotBtn then
				robuxDroneSlotBtn.Text = "MAX"
			end
		end
	end

	if droneInventoryGridFrame then
		local invSigParts = {
			tostring(maxSlots),
			tostring(selectedShowcaseItem.Uid or ""),
		}
		for _, entry in ipairs(ownedDrones) do
			table.insert(
				invSigParts,
				string.format("%s:%s:%s:%d:%s", tostring(entry.Uid), tostring(entry.Id), tostring(entry.Equipped), entry.Level or 1, tostring(entry.IsGolden))
			)
		end
		local invSig = table.concat(invSigParts, "|")
		if invSig ~= lastDroneInvUISignature then
			lastDroneInvUISignature = invSig
			for _, ch in ipairs(droneInventoryGridFrame:GetChildren()) do
				if ch:IsA("GuiButton") or ch:IsA("Frame") then
					ch:Destroy()
				end
			end

			local rarityGradients: { [string]: { Top: Color3, Bot: Color3 } } = {
				Common = { Top = Color3.fromRGB(122, 142, 168), Bot = Color3.fromRGB(76, 92, 116) },
				Uncommon = { Top = Color3.fromRGB(62, 212, 118), Bot = Color3.fromRGB(28, 142, 68) },
				Rare = { Top = Color3.fromRGB(58, 168, 245), Bot = Color3.fromRGB(28, 108, 198) },
				Epic = { Top = Color3.fromRGB(168, 72, 245), Bot = Color3.fromRGB(108, 32, 188) },
				Legendary = { Top = Color3.fromRGB(255, 205, 52), Bot = Color3.fromRGB(218, 138, 18) },
				Mythic = { Top = Color3.fromRGB(255, 68, 132), Bot = Color3.fromRGB(188, 22, 78) },
			}

			for _, entry in ipairs(ownedDrones) do
				local cDef = PlanetConfig.Companions[entry.Id]
				if cDef then
					local isGold = (entry.IsGolden == true) or (entry.Golden == true)
					local lvl = entry.Level or 1
					local stats = PlanetConfig.GetDroneStats(entry.Id, lvl, isGold)
					local rGrad = rarityGradients[cDef.Rarity] or rarityGradients.Common
					local isSelected = (selectedShowcaseItem.Kind == "Drone" and selectedShowcaseItem.Uid == entry.Uid)

					local dCard = Instance.new("TextButton")
					dCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					dCard.Text = ""
					dCard.AutoButtonColor = false
					dCard.Parent = droneInventoryGridFrame
					addCorner(dCard, 12)
					addBorderStroke(
						dCard,
						isSelected and Color3.fromRGB(108, 248, 56) or Color3.fromRGB(10, 14, 24),
						isSelected and 3.2 or 2.5
					)
					addGradient(dCard, rGrad.Top, rGrad.Bot, 90)

					-- Top-Left Corner Ribbon ("EQUIPPED" in Lime Green or "LV.X" in Red)
					local ribbon = Instance.new("TextLabel")
					ribbon.Size = UDim2.new(0, entry.Equipped and 68 or 48, 0, 20)
					ribbon.Position = UDim2.new(0, -2, 0, -2)
					ribbon.BackgroundColor3 = entry.Equipped and Color3.fromRGB(72, 225, 42) or Color3.fromRGB(238, 52, 48)
					ribbon.Text = entry.Equipped and "EQUIPPED" or ("LV." .. tostring(lvl))
					ribbon.TextColor3 = Color3.fromRGB(255, 255, 255)
					ribbon.Font = Enum.Font.GothamBlack
					ribbon.TextSize = 10
					ribbon.ZIndex = 4
					ribbon.Parent = dCard
					addCorner(ribbon, 6)
					addBorderStroke(ribbon, Color3.fromRGB(10, 14, 22), 2.0)
					addTextStroke(ribbon, 1.4)

					-- Live 3D Drone ViewportFrame inside Card
					local vp = Instance.new("ViewportFrame")
					vp.Size = UDim2.new(1, -12, 0, 78)
					vp.Position = UDim2.new(0, 6, 0, 16)
					vp.BackgroundTransparency = 1
					vp.Parent = dCard
					populateDroneViewport(vp, entry.Id, isGold, lvl)

					local dName = Instance.new("TextLabel")
					dName.Size = UDim2.new(1, -8, 0, 18)
					dName.Position = UDim2.new(0, 4, 1, -50)
					dName.BackgroundTransparency = 1
					dName.Text = (isGold and "★ " or "") .. cDef.Name
					dName.TextColor3 = Color3.fromRGB(255, 255, 255)
					dName.Font = Enum.Font.GothamBlack
					dName.TextSize = 11
					dName.TextTruncate = Enum.TextTruncate.AtEnd
					dName.Parent = dCard
					addTextStroke(dName, 1.6)

					-- Bottom Dark-Navy Stat Pill (Matches Price/Stat Pill in Screenshot!)
					local statPill = Instance.new("Frame")
					statPill.Size = UDim2.new(1, -12, 0, 24)
					statPill.Position = UDim2.new(0, 6, 1, -29)
					statPill.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
					statPill.Parent = dCard
					addCorner(statPill, 7)
					addBorderStroke(statPill, Color3.fromRGB(8, 12, 22), 2.0)

					local statTxt = Instance.new("TextLabel")
					statTxt.Size = UDim2.new(1, -6, 1, 0)
					statTxt.Position = UDim2.new(0, 3, 0, 0)
					statTxt.BackgroundTransparency = 1
					statTxt.Text = string.format("🔨%s • ⚔️%s", PlanetConfig.FormatNumber(stats.DrillPower), PlanetConfig.FormatNumber(stats.Damage))
					statTxt.TextColor3 = Color3.fromRGB(115, 245, 175)
					statTxt.Font = Enum.Font.GothamBlack
					statTxt.TextSize = 10
					statTxt.TextTruncate = Enum.TextTruncate.AtEnd
					statTxt.Parent = statPill
					addTextStroke(statTxt, 1.3)

					local uidCopy = entry.Uid
					dCard.MouseButton1Click:Connect(function()
						playSFX(sfxClick, 0.30)
						if selectedShowcaseItem.Kind == "Drone" and selectedShowcaseItem.Uid == uidCopy then
							-- Clicking an already-selected drone card toggles equip immediately!
							CompanionActionEvent:FireServer("ToggleEquip", uidCopy)
						else
							selectedShowcaseItem = { Kind = "Drone", Id = entry.Id, Uid = uidCopy }
							lastDroneInvUISignature = ""
							refreshUI()
						end
					end)
				end
			end
		end
	end

	if updateDroneSpotlightPanel then
		updateDroneSpotlightPanel()
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
				ui.Btn.BackgroundColor3 = Color3.fromRGB(48, 60, 82)
			elseif pSec >= gDef.TimeReq then
				ui.Btn.Text = "🎁 CLAIM"
				ui.Btn.BackgroundColor3 = Color3.fromRGB(40, 195, 110)
			else
				ui.Btn.Text = formatSecondsMMSS(gDef.TimeReq - pSec)
				ui.Btn.BackgroundColor3 = Color3.fromRGB(45, 125, 205)
			end
		end
	end

	for _, bDef in ipairs(PlanetConfig.Boosters) do
		local ui = boosterButtonsUI[bDef.Id]
		if ui then
			local rem = (currentState.ActiveBoosters and currentState.ActiveBoosters[bDef.Id]) or 0
			if rem > 0 then
				ui.TimerLbl.Text = "⚡ ACTIVE: " .. formatSecondsMMSS(rem) .. " remaining"
				ui.TimerLbl.TextColor3 = Color3.fromRGB(105, 245, 165)
			else
				ui.TimerLbl.Text = "Inactive (+15m per purchase)"
				ui.TimerLbl.TextColor3 = Color3.fromRGB(195, 210, 235)
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
			ui.Button.BackgroundColor3 = Color3.fromRGB(40, 195, 110)
			ui.Stroke.Color = Color3.fromRGB(40, 195, 110)
		elseif isUnlocked then
			ui.Button.Text = "EQUIP FOCUS"
			ui.Button.BackgroundColor3 = Color3.fromRGB(50, 135, 220)
			ui.Stroke.Color = Color3.fromRGB(50, 135, 220)
		elseif parentUnlocked then
			ui.Button.Text = "EVOLVE"
			ui.Button.BackgroundColor3 = node.VisualTrait.GlowColor
			ui.Stroke.Color = node.VisualTrait.GlowColor
		else
			ui.Button.Text = "LOCKED"
			ui.Button.BackgroundColor3 = Color3.fromRGB(42, 50, 74)
			ui.Stroke.Color = Color3.fromRGB(36, 44, 64)
		end
	end

	-- Update Planet Upgrades Grid (Uses Upgrade Points)
	local upgPoints = currentState.UpgradePoints or 0
	for _, upg in ipairs(PlanetConfig.PlanetUpgrades) do
		local cardUI = upgradeCardsUI[upg.Id]
		if cardUI then
			local lvl = currentState.PlanetUpgrades[upg.Id] or 0
			cardUI.LevelLabel.Text = string.format("Lv. %d / %d", lvl, upg.MaxLevel)

			if lvl >= upg.MaxLevel then
				cardUI.CostLabel.Text = "MAX LEVEL REACHED"
				cardUI.BuyOneBtn.Text = "✓ MAXED OUT"
				cardUI.BuyMaxBtn.Text = "✓ MAX"
			else
				cardUI.CostLabel.Text = string.format("Cost: 1 Upgrade Point (Have: %d Pts)", upgPoints)
				cardUI.BuyOneBtn.Text = "UPGRADE (1 PT)"
				cardUI.BuyMaxBtn.Text = "⚡ BUY MAX"
			end
		end
	end

	-- Update Bottom 5 Equipped Drone Slots HUD
	local equippedList = {}
	for _, entry in ipairs(ownedDrones) do
		if entry.Equipped then
			table.insert(equippedList, entry)
		end
	end
	local droneDmgMult = rates.DroneDamageMult or 1.0
	local slotSigParts = { tostring(droneDmgMult) }
	for slotIdx = 1, 5 do
		local entry = equippedList[slotIdx]
		if entry then
			table.insert(
				slotSigParts,
				string.format("%d:%s:%s:%d:%s", slotIdx, tostring(entry.Uid), tostring(entry.Id), entry.Level or 1, tostring(entry.IsGolden))
			)
		else
			table.insert(slotSigParts, string.format("%d:EMPTY", slotIdx))
		end
	end
	local bottomSig = table.concat(slotSigParts, "|")
	if bottomSig ~= lastBottomSlotsSignature then
		lastBottomSlotsSignature = bottomSig
		for slotIdx = 1, 5 do
			local ui = bottomDroneSlotUIs[slotIdx]
			if ui then
				local entry = equippedList[slotIdx]
				if entry then
					local cDef = PlanetConfig.Companions[entry.Id]
					local isGold = (entry.IsGolden == true) or (entry.Golden == true)
					local lvl = entry.Level or 1
					local stats = PlanetConfig.GetDroneStats(entry.Id, lvl, isGold)
					local rInfo = cDef and PlanetConfig.DroneRarities[cDef.Rarity]
					local borderC = isGold and Color3.fromRGB(255, 215, 65) or ((rInfo and rInfo.Color) or (cDef and cDef.Color) or Color3.fromRGB(85, 225, 255))

					ui.Viewport.Visible = true
					ui.EmptyLabel.Visible = false
					ui.StatPill.Visible = true
					ui.Stroke.Color = borderC
					ui.Frame.BackgroundColor3 = Color3.fromRGB(28, 46, 86)
					ui.StatLabel.Text = string.format("Lv.%d • ⚔️%s", lvl, PlanetConfig.FormatNumber(math.floor(stats.Damage * droneDmgMult + 0.5)))
					populateDroneViewport(ui.Viewport, entry.Id, isGold, lvl)
				else
					ui.Viewport.Visible = false
					for _, ch in ipairs(ui.Viewport:GetChildren()) do
						ch:Destroy()
					end
					ui.EmptyLabel.Visible = true
					ui.StatPill.Visible = false
					ui.Stroke.Color = Color3.fromRGB(48, 66, 104)
					ui.Frame.BackgroundColor3 = Color3.fromRGB(20, 28, 52)
				end
			end
		end
	end

	-- Update [Q] Slide-Out Attack Upgrade Popup Slots
	qHeaderTitle.Text = string.format("⚔️ UPGRADES [Q] • %d PTS", upgPoints)
	qUpgradeToggleTab.Text = (upgPoints > 0) and string.format("⚔️ [Q] UPGRADES (%d)", upgPoints) or "⚔️ [Q] UPGRADES"

	local levelMult = 1 + (playerLvl - 1) * 0.12
	local permValLvl = (currentState.ShardUpgrades and (currentState.ShardUpgrades.PermValue or currentState.ShardUpgrades.PermDrill)) or 0
	for _, upg in ipairs(PlanetConfig.PlanetUpgrades) do
		local qUI = qSlotCardsUI[upg.Id]
		if qUI then
			local lvl = (currentState.PlanetUpgrades and currentState.PlanetUpgrades[upg.Id]) or 0
			qUI.LevelLabel.Text = string.format("Lv. %d / %d", lvl, upg.MaxLevel)

			if upg.Id == "DroneAttackDamage" then
				local nxtMult = (1 + (lvl + 1) * 0.30) * math.pow(1.20, math.floor((lvl + 1) / 5))
				qUI.StatLabel.Text = string.format(
					"Drone DMG: %.2fx (%s)  ➔  %.2fx",
					droneDmgMult,
					PlanetConfig.FormatNumber(droneDamage),
					nxtMult
				)
			elseif upg.Id == "DroneReloadSpeed" then
				local curCd = rates.FireCooldown or math.max(0.05, 0.45 / (1 + lvl * 0.18))
				local nxtCd = math.max(0.05, 0.45 / (1 + (lvl + 1) * 0.18))
				qUI.StatLabel.Text = string.format(
					"Cooldown: %.2fs  ➔  Next: %.2fs",
					curCd,
					nxtCd
				)
			end

			if lvl >= upg.MaxLevel then
				qUI.Button.Text = "✓ MAXED OUT"
				qUI.BtnGradient.Color = ColorSequence.new(Color3.fromRGB(70, 82, 105), Color3.fromRGB(50, 60, 82))
			else
				local canAfford = upgPoints >= 1
				qUI.Button.Text = "UPGRADE (1 PT)"
				if canAfford then
					qUI.BtnGradient.Color = ColorSequence.new(Color3.fromRGB(108, 248, 56), Color3.fromRGB(46, 188, 20))
				else
					qUI.BtnGradient.Color = ColorSequence.new(Color3.fromRGB(92, 102, 130), Color3.fromRGB(62, 70, 96))
				end
			end
		end
	end

	-- Update Sticky Bomb Detonate HUD Button
	local bombCount = math.max(currentState.StickyBombCount or 0, countLocalStickyBombs())
	if bombCount > 0 then
		detonateBombsBtn.Visible = true
		local comboPct = math.min(120, (bombCount - 1) * 8)
		detonateBombsBtn.Text = (comboPct > 0)
			and string.format("💥 DETONATE [R] (%d BOMBS • +%d%%)", bombCount, comboPct)
			or string.format("💥 DETONATE [R] (%d BOMB)", bombCount)
	else
		detonateBombsBtn.Visible = false
	end

	-- Update Diep.io First-Path Tree Tab (`dronePathCardsUI`)
	do
		local unlockTier1Lv = (PlanetConfig.DronePathUnlockLevels and PlanetConfig.DronePathUnlockLevels.Tier1) or 5
		local basicDroneToEvolve: any = nil
		local ownedClasses: { [string]: boolean } = {}
		for _, entry in ipairs(ownedDrones) do
			ownedClasses[entry.Id] = true
			if entry.Id == "BasicDrone" and not basicDroneToEvolve then
				basicDroneToEvolve = entry
			end
		end

		local pathClassId = currentState.DronePathClassId or "BasicDrone"
		local pathDef = PlanetConfig.Companions[pathClassId] or PlanetConfig.Companions.BasicDrone
		if dronePathHeaderLbl then
			dronePathHeaderLbl.Text = string.format(
				"🧬 DIEP.IO FIRST PATH: %s (%s) • LEVEL %d  •  Unlocks @ Lv.%d!",
				string.upper(pathDef.Name),
				pathDef.RoleTag or "STARTER",
				playerLvl,
				unlockTier1Lv
			)
		end

		for cId, pUI in pairs(dronePathCardsUI) do
			local cDef = PlanetConfig.Companions[cId]
			if cDef then
				local reqLv = cDef.UnlockLevel or unlockTier1Lv
				local unlocked = playerLvl >= reqLv
				if not unlocked then
					pUI.EvolveBtn.Text = "🔒 REACH LV." .. tostring(reqLv)
					pUI.EvolveBtn.BackgroundColor3 = Color3.fromRGB(52, 60, 88)
				elseif basicDroneToEvolve ~= nil then
					pUI.EvolveBtn.Text = "🧬 CHOOSE THIS PATH"
					pUI.EvolveBtn.BackgroundColor3 = Color3.fromRGB(78, 228, 52)
				elseif pathClassId == cId or ownedClasses[cId] then
					pUI.EvolveBtn.Text = "✓ CHOSEN IN FLEET"
					pUI.EvolveBtn.BackgroundColor3 = Color3.fromRGB(48, 165, 195)
				else
					pUI.EvolveBtn.Text = "BUILD BASIC DRONE FIRST"
					pUI.EvolveBtn.BackgroundColor3 = Color3.fromRGB(48, 58, 92)
				end
			end
		end
	end

	-- Update Top-Center Live Diep.io Evolution Banner
	if updateDiepEvoBanner then
		updateDiepEvoBanner()
	end
end

updateDiepEvoBanner = function()
	local playerLvl = currentState.Level or 1
	local unlockTier1Lv = (PlanetConfig.DronePathUnlockLevels and PlanetConfig.DronePathUnlockLevels.Tier1) or 5
	local equippedBasicEntry: any = nil
	for _, entry in ipairs(currentState.Companions or {}) do
		if entry.Equipped and entry.Id == "BasicDrone" then
			equippedBasicEntry = entry
			break
		end
	end

	local choices = (equippedBasicEntry and playerLvl >= unlockTier1Lv)
		and PlanetConfig.GetDroneEvolutionChoices("BasicDrone", playerLvl)
		or {}

	if (#choices == 0) or is2DMenuActive() or modalFrame.Visible then
		diepEvoPanel.Visible = false
		diepToggleBtn.Visible = false
		return
	end

	if isDiepBannerMinimized then
		diepEvoPanel.Visible = false
		diepToggleBtn.Visible = true
		diepToggleBtn.Text = string.format("🧬 BASIC DRONE UPGRADE READY! (%d)", #choices)
		return
	end

	diepToggleBtn.Visible = false
	diepEvoPanel.Visible = true
	local basicUid = tostring(equippedBasicEntry.Uid)
	local sig = basicUid .. ":" .. table.concat(choices, ",")
	if sig == lastDiepSig then
		return
	end
	lastDiepSig = sig

	for _, ch in ipairs(diepCardsRow:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end

	local cardWidth = math.clamp(math.floor(590 / math.max(1, #choices)) - 8, 110, 240)
	diepEvoPanel.Size = UDim2.new(0, math.max(360, (#choices * (cardWidth + 8)) + 22), 0, 142)

	for _, nextId in ipairs(choices) do
		local cDef = PlanetConfig.Companions[nextId]
		if cDef then
			local cardBtn = Instance.new("TextButton")
			cardBtn.Size = UDim2.new(0, cardWidth, 1, -4)
			cardBtn.BackgroundColor3 = Color3.fromRGB(16, 26, 54)
			cardBtn.Text = ""
			cardBtn.AutoButtonColor = false
			cardBtn.ZIndex = 9
			cardBtn.Parent = diepCardsRow
			addCorner(cardBtn, 10)
			addBorderStroke(cardBtn, cDef.Color, 2.2)

			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(1, -12, 0, 58)
			vp.Position = UDim2.new(0, 6, 0, 4)
			vp.BackgroundTransparency = 1
			vp.ZIndex = 10
			vp.Parent = cardBtn
			populateDroneViewport(vp, nextId, false, 1)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -8, 0, 18)
			nameLbl.Position = UDim2.new(0, 4, 0, 64)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = cDef.Icon .. " " .. cDef.Name
			nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextSize = 11
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.ZIndex = 10
			nameLbl.Parent = cardBtn
			addTextStroke(nameLbl, 1.4)

			local roleLbl = Instance.new("TextLabel")
			roleLbl.Size = UDim2.new(1, -8, 0, 16)
			roleLbl.Position = UDim2.new(0, 4, 0, 82)
			roleLbl.BackgroundTransparency = 1
			roleLbl.Text = cDef.RoleTag or ""
			roleLbl.TextColor3 = cDef.Color
			roleLbl.Font = Enum.Font.GothamBlack
			roleLbl.TextSize = 9
			roleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			roleLbl.ZIndex = 10
			roleLbl.Parent = cardBtn

			local idCopy = nextId
			local uidCopy = basicUid
			cardBtn.MouseButton1Click:Connect(function()
				playSFX(sfxEvolve, 0.45)
				EvolveDronePathEvent:FireServer(idCopy, uidCopy)
			end)
		end
	end
end

-- ============================================================================
-- 11. 3D CAMERA, FLIGHT CONTROLS, CLICK-TO-TARGET DRONES & STATION DETECTOR
-- ============================================================================
(function()
local camCtrl = {
	Yaw = 0,
	Pitch = -0.18,
	Dist = 92,
	CreatorYaw = 0.35,
	CreatorPitch = -0.15,
	CreatorZoom = 56,
	RightDown = false,
	LeftDown = false,
	LastSideDir = Vector3.new(1, 0, 0),
	OrbitClock = 0,
}

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

local function buildAimExcludeList(): { Instance }
	local excludeList: { Instance } = { clientStarsFolder, beamFXFolder, stickyBombsFolder }
	if localActivePlanetModel then
		table.insert(excludeList, localActivePlanetModel)
	end
	for _, dInfo in ipairs(activeDroneModels) do
		if dInfo.Model then
			table.insert(excludeList, dInfo.Model)
		end
	end
	return excludeList
end

local function handleHubFoundryClick(screenPos: Vector2): boolean
	if not camera or is2DMenuActive() or modalFrame.Visible then
		return false
	end
	local unitRay = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local rParams = RaycastParams.new()
	rParams.FilterType = Enum.RaycastFilterType.Exclude
	rParams.FilterDescendantsInstances = buildAimExcludeList()

	local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 650, rParams)
	if not hit or not hit.Instance then
		return false
	end

	local inst: Instance? = hit.Instance
	while inst and inst ~= Workspace do
		if inst.Name == "OrbitalDroneFoundry" or inst:GetAttribute("PodId") ~= nil or inst:GetAttribute("DronePodId") ~= nil then
			local clickedPodId = inst:GetAttribute("PodId") or inst:GetAttribute("DronePodId")
			if type(clickedPodId) == "string" and #clickedPodId > 0 then
				selectedShowcaseItem = { Kind = "Pod", Id = clickedPodId, Uid = nil }
				if updateDroneSpotlightPanel then
					updateDroneSpotlightPanel()
				end
			end
			playSFX(sfxClick, 0.32)
			toggleTab("Drones", "DRONE SHOP")
			return true
		end
		inst = inst.Parent
	end
	return false
end

local function getMaxFleetRange(): number
	local maxR = 260
	for _, dInfo in ipairs(activeDroneModels) do
		local r = (dInfo.Stats and dInfo.Stats.Range) or 260
		if r > maxR then
			maxR = r
		end
	end
	return maxR
end

local function getMouseAimData(camRot: CFrame): (Model?, Vector3, Vector3)
	if not camera then
		return nil, localPlanetPos + camCtrl.LastSideDir * 80, camCtrl.LastSideDir
	end
	local maxRange = getMaxFleetRange()
	local mPos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mPos.X, mPos.Y)
	local camLook = camRot.LookVector
	local denom = unitRay.Direction:Dot(camLook)
	local tPlane = (math.abs(denom) > 0.05) and ((localPlanetPos - unitRay.Origin):Dot(camLook) / denom) or 100
	local planePoint = unitRay.Origin + unitRay.Direction * math.max(10, tPlane)
	local sideOffset = planePoint - localPlanetPos
	if sideOffset.Magnitude > 0.5 then
		camCtrl.LastSideDir = sideOffset.Unit
	end

	local rParams = RaycastParams.new()
	rParams.FilterType = Enum.RaycastFilterType.Exclude
	rParams.FilterDescendantsInstances = buildAimExcludeList()

	local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * (maxRange + 140), rParams)
	local aimWorldPos = (hit and hit.Position) or (unitRay.Origin + unitRay.Direction * math.clamp(tPlane + 55, 70, math.min(maxRange, 420)))
	local aimedTarget: Model? = nil

	if hit and hit.Instance then
		local inst: Instance? = hit.Instance
		while inst and inst ~= Workspace do
			if inst:IsA("Model") and (inst:GetAttribute("IsSpaceCollectible") == true or inst:GetAttribute("NodeType") ~= nil or inst:GetAttribute("OwnerUserId") ~= nil) then
				if inst:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
					local hp = (inst:GetAttribute("HP") :: number?) or 1
					if inst:GetAttribute("Available") ~= false and hp > 0 then
						aimedTarget = inst
					end
				end
				break
			end
			inst = inst.Parent
		end
	end

	if not aimedTarget then
		local env = Workspace:FindFirstChild("CosmicEnvironment")
		local nodes = env and env:FindFirstChild("CosmicResourceNodes")
		if nodes then
			local bestD = 26
			for _, chunk in ipairs(nodes:GetChildren()) do
				if chunk:IsA("Model") then
					for _, ch in ipairs(chunk:GetChildren()) do
						if ch:IsA("Model") and ch:GetAttribute("Available") ~= false and ((ch:GetAttribute("HP") :: number?) or 0) > 0 then
							local d = (ch:GetPivot().Position - aimWorldPos).Magnitude
							if d < bestD and (ch:GetPivot().Position - localPlanetPos).Magnitude <= maxRange then
								bestD = d
								aimedTarget = ch
							end
						end
					end
				end
			end
		end
	end

	return aimedTarget, aimWorldPos, camCtrl.LastSideDir
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		camCtrl.RightDown = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		if not is2DMenuActive() and not modalFrame.Visible then
			if not handleHubFoundryClick(Vector2.new(input.Position.X, input.Position.Y)) then
				camCtrl.LeftDown = true
				for _, dInfo in ipairs(activeDroneModels) do
					local reloadLvl = (currentState.PlanetUpgrades and currentState.PlanetUpgrades.DroneReloadSpeed) or 0
					local effCd = math.max(0.05, ((dInfo.Stats and dInfo.Stats.FireCooldown) or 0.45) / (1 + reloadLvl * 0.18))
					dInfo.FireTimer = effCd
				end
			end
		end
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
	elseif kc == Enum.KeyCode.Q then
		if not is2DMenuActive() then
			toggleQUpgradePopup()
		end
	elseif kc == Enum.KeyCode.R then
		if not is2DMenuActive() then
			playSFX(sfxEvolve, 0.45)
			DetonateStickyBombsEvent:FireServer()
		end
	elseif kc == Enum.KeyCode.LeftControl then
		moveKeys.Q = true
	elseif kc == Enum.KeyCode.LeftShift then
		moveKeys.LeftShift = true
	elseif kc == Enum.KeyCode.E or kc == Enum.KeyCode.F then
		if (not is2DMenuActive()) and (nearestHubMachineId or nearestSpaceStationId) then
			triggerNearestMachineUI()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		camCtrl.RightDown = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		camCtrl.LeftDown = false
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
	elseif kc == Enum.KeyCode.LeftControl then
		moveKeys.Q = false
	elseif kc == Enum.KeyCode.LeftShift then
		moveKeys.LeftShift = false
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseMovement and camCtrl.RightDown then
		if is2DMenuActive() then
			camCtrl.CreatorYaw -= input.Delta.X * 0.005
			camCtrl.CreatorPitch = math.clamp(camCtrl.CreatorPitch - input.Delta.Y * 0.005, -1.1, 1.1)
		else
			camCtrl.Yaw -= input.Delta.X * 0.0045
			camCtrl.Pitch = math.clamp(camCtrl.Pitch - input.Delta.Y * 0.0045, -1.25, 1.25)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		if is2DMenuActive() then
			camCtrl.CreatorZoom = math.clamp(camCtrl.CreatorZoom - input.Position.Z * 5, 34, 95)
		else
			camCtrl.Dist = math.clamp(camCtrl.Dist - input.Position.Z * 8, 46, 260)
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
	hideServerDuplicateOfMyPlanet(false)

	-- Animate 3D Spotlight Model when Drone Shop modal is open
	if modalFrame.Visible and activeTab == "Drones" and spotlightViewportModel and spotlightViewportModel.Parent then
		spotlightViewportModel:PivotTo(
			CFrame.new(0, math.sin(os.clock() * 2.4) * 0.25, 0) * CFrame.Angles(math.rad(10), os.clock() * 1.15, 0)
		)
	end

	-- 2D MENU PHASE (Initial Setup OR In-Game Customize Planet Overlay): Animate 3D Planet & Species inside `mainViewport`
	if is2DMenuActive() then
		spinAngle += dt * rotSpeed * 1.35
		if vpPlanetModel then
			vpPlanetModel:PivotTo(CFrame.new(-7, 2, 0) * CFrame.Angles(0, spinAngle, math.rad(8)))
		end
		if vpSpeciesModel then
			vpSpeciesModel:PivotTo(CFrame.new(18, -3, 4) * CFrame.Angles(0, -spinAngle * 0.55, 0))
		end

		local lookTarget = Vector3.new(2, 0, 0)
		local orbitRot = CFrame.fromEulerAnglesYXZ(camCtrl.CreatorPitch, camCtrl.CreatorYaw, 0)
		local vpCamPos = lookTarget + (orbitRot * Vector3.new(0, 4, camCtrl.CreatorZoom))
		mainViewportCam.CFrame = CFrame.lookAt(vpCamPos, lookTarget)
		sfxThrusterLoop.Volume = 0
		return
	end

	-- ACTIVE THIRD-PERSON PLANET GAMEPLAY IN OPEN SPACE!
	if not localActivePlanetModel or not localActivePlanetModel.Parent then
		refreshShowroomAndActivePlanetModels()
	end

	local camRot = CFrame.fromEulerAnglesYXZ(camCtrl.Pitch, camCtrl.Yaw, 0)
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

	-- Update Infinite 3D Scattered Starfield around the player (throttled)
	updateInfiniteStarfield(localPlanetPos)

	-- Dynamic Axial Spin + Smooth Flight Banking
	spinAngle += dt * rotSpeed * (isBoosting and 2.0 or 1.0)
	local targetRoll = -strafeInput * math.rad(14)
	local targetPitch = -forwardInput * math.rad(9)
	currentBankRoll = currentBankRoll + (targetRoll - currentBankRoll) * math.clamp(dt * 6, 0, 1)
	currentBankPitch = currentBankPitch + (targetPitch - currentBankPitch) * math.clamp(dt * 6, 0, 1)

	local planetTiltCF = CFrame.fromEulerAnglesYXZ(0, camCtrl.Yaw, 0)
		* CFrame.Angles(currentBankPitch, 0, currentBankRoll)
		* CFrame.Angles(0, spinAngle - camCtrl.Yaw, math.rad(8))

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

	-- Aim Drones toward Mouse Cursor, Support Far-Flying Long-Range Scouts, & Per-Drone Firing Cadence!
	local aimedTarget, aimWorldPos, cursorSideDir = getMouseAimData(camRot)
	targetLockCard.Visible = false

	camCtrl.OrbitClock += dt * 2.1
	local pScale = getLocalPlanetScaleFactor()
	local sideDist = 22 * pScale + 6
	local droneCount = #activeDroneModels
	local reloadLvl = (currentState.PlanetUpgrades and currentState.PlanetUpgrades.DroneReloadSpeed) or 0
	local aimDir = (aimWorldPos - localPlanetPos)
	local aimDirUnit = (aimDir.Magnitude > 0.5) and aimDir.Unit or lookForward

	for i, dInfo in ipairs(activeDroneModels) do
		if dInfo.Model and dInfo.Model.Parent then
			local bobY = math.sin(camCtrl.OrbitClock * 2.4 + i * 1.4) * 2.2
			local spreadAngle = (i - (droneCount + 1) * 0.5) * 0.30
			local droneDir = (CFrame.fromAxisAngle(lookForward, spreadAngle):VectorToWorldSpace(cursorSideDir)).Unit
			local dStats = dInfo.Stats or PlanetConfig.GetDroneStats(dInfo.DroneId, 1, false)
			local leash = dStats.LeashRange or 0

			local desiredPos: Vector3
			if leash > 0 and (aimedTarget ~= nil or camCtrl.LeftDown) then
				-- Long-Range Scout / Sniper physically flies very far out toward target/cursor!
				local focusPoint = aimedTarget and aimedTarget:GetPivot().Position or aimWorldPos
				local offsetFromPlanet = focusPoint - localPlanetPos
				local distToFocus = offsetFromPlanet.Magnitude
				local scoutDist = math.clamp(distToFocus - 65, sideDist, leash)
				local scoutDir = (distToFocus > 0.5) and offsetFromPlanet.Unit or aimDirUnit
				local sideJog = CFrame.fromAxisAngle(lookForward, spreadAngle * 0.5):VectorToWorldSpace(scoutDir).Unit
				desiredPos = localPlanetPos + sideJog * scoutDist + Vector3.new(0, bobY + 4, 0)
			else
				desiredPos = localPlanetPos + droneDir * sideDist + Vector3.new(0, bobY + 2, 0)
			end

			dInfo.RecoilOffset = dInfo.RecoilOffset:Lerp(Vector3.zero, math.clamp(dt * 12, 0, 1))
			dInfo.CurrentPos = dInfo.CurrentPos:Lerp(desiredPos + dInfo.RecoilOffset, math.clamp(dt * 9.5, 0, 1))
			dInfo.Model:PivotTo(CFrame.lookAt(dInfo.CurrentPos, aimWorldPos))
		end
	end

	if camCtrl.LeftDown and (#activeDroneModels > 0) and (not is2DMenuActive()) and (not modalFrame.Visible) then
		for _, dInfo in ipairs(activeDroneModels) do
			if dInfo.Model and dInfo.Model.Parent then
				local dStats = dInfo.Stats or PlanetConfig.GetDroneStats(dInfo.DroneId, 1, false)
				local effCd = math.max(0.05, (dStats.FireCooldown or 0.45) / (1 + reloadLvl * 0.18))
				dInfo.FireTimer += dt
				if dInfo.FireTimer >= effCd then
					dInfo.FireTimer = 0
					local maxR = dStats.Range or 260
					local style = dStats.ProjectileStyle or "Standard"
					local startPos = getDroneMuzzlePos(dInfo)
					local recoilMag = (style == "HeavySlug") and 4.2 or ((style == "RapidBolt") and 0.9 or 1.8)
					dInfo.RecoilOffset = -aimDirUnit * recoilMag

					local targetInRange = aimedTarget and ((aimedTarget:GetPivot().Position - localPlanetPos).Magnitude <= (maxR + 25))
					if style == "StickyBomb" or style == "SpreadPellet" or targetInRange then
						SetDroneTargetEvent:FireServer(targetInRange and aimedTarget or nil, aimWorldPos, dInfo.Uid, aimDirUnit)
					else
						-- Pure client-side open-space laser preview so every drone visibly fires toward cursor
						local previewEnd = localPlanetPos + aimDirUnit * math.min(maxR, math.max(60, (aimWorldPos - localPlanetPos).Magnitude))
						local width = (style == "HeavySlug" and 1.45) or (style == "RapidBolt" and 0.30) or (style == "SniperBeam" and 0.40) or 0.55
						spawnLaserBeamSegment(startPos, previewEnd, dInfo.BeamColor, width, (style == "RapidBolt") and 0.11 or 0.18)
					end
				end
			end
		end
	else
		for _, dInfo in ipairs(activeDroneModels) do
			local dStats = dInfo.Stats or PlanetConfig.GetDroneStats(dInfo.DroneId, 1, false)
			local effCd = math.max(0.05, (dStats.FireCooldown or 0.45) / (1 + reloadLvl * 0.18))
			dInfo.FireTimer = effCd
		end
	end

	-- Keep attached Sticky Bombs glued to moving/rotating asteroids & blink their LEDs!
	local blinkOn = (os.clock() % 0.6) < 0.3
	for bId, bEntry in pairs(activeStickyBombs) do
		if bEntry.Model and bEntry.Model.Parent then
			if bEntry.TargetRoot and bEntry.TargetRoot.Parent then
				if bEntry.TargetRoot:GetAttribute("Available") == false then
					bEntry.Model:Destroy()
					activeStickyBombs[bId] = nil
				else
					local worldStick = bEntry.TargetRoot.CFrame:PointToWorldSpace(bEntry.LocalOffset)
					local curRot = bEntry.Model:GetPivot() - bEntry.Model:GetPivot().Position
					bEntry.Model:PivotTo(CFrame.new(worldStick) * curRot)
				end
			end
			if activeStickyBombs[bId] then
				local led = bEntry.Model:FindFirstChild("BombLED") :: BasePart?
				if led then
					led.Color = blinkOn and bEntry.Color or Color3.fromRGB(255, 235, 110)
				end
			end
		else
			activeStickyBombs[bId] = nil
		end
	end

	-- Update Proximity Prompt Y position above Sticky Detonate button when active
	proximityPromptBtn.Position = detonateBombsBtn.Visible and UDim2.new(0.5, 0, 1, -152) or UDim2.new(0.5, 0, 1, -104)

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
			proximityPromptBtn.Text = string.format("[E] %s // OPEN WARP NETWORK", string.upper(foundStation.Name))
		else
			proximityPromptBtn.Text = string.format(
				"[E] UNLOCK %s WARP GATE (%s 💎)",
				string.upper(foundStation.Name),
				PlanetConfig.FormatNumber(foundStation.GemCost)
			)
		end
	elseif foundMachine then
		local mDef = PlanetConfig.HubMachines[foundMachine]
		proximityPromptBtn.Visible = true
		proximityPromptBtn.Text = string.format("[E] ACCESS %s", string.upper(mDef.Name))
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

	local camPos = localPlanetPos + (camRot * Vector3.new(0, 14, camCtrl.Dist))
	local lookAtTarget = localPlanetPos + Vector3.new(0, 3, 0)
	camera.CFrame = CFrame.lookAt(camPos, lookAtTarget)
end)
end)() -- End Section 11 scope

StateSyncEvent.OnClientEvent:Connect(function(newState: any)
	local wasSetup = currentState.HasCompletedSetup
	currentState = newState
	if newState.PlanetPosition and (not wasSetup or (newState.PlanetPosition - localPlanetPos).Magnitude > 85) then
		localPlanetPos = newState.PlanetPosition
	end
	refreshUI()
end)

-- ============================================================================
-- 12. EXCLUSIVE DEVELOPER ADMIN CONSOLE (Fintanfire & pizqwe ONLY)
-- ============================================================================
;(function()
	if not PlanetConfig.IsAdminPlayer(localPlayer) then
		return
	end

	local AdminCommandEvent = Remotes:WaitForChild("AdminCommand") :: RemoteEvent

	local adminToggleBtn = Instance.new("TextButton")
	adminToggleBtn.Name = "DevAdminToggleBtn"
	adminToggleBtn.Size = UDim2.new(0, 122, 0, 36)
	adminToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
	adminToggleBtn.Position = UDim2.new(1, -14, 0.5, -48)
	adminToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	adminToggleBtn.Text = "🛠️ ADMIN [F2]"
	adminToggleBtn.TextColor3 = Color3.fromRGB(22, 16, 8)
	adminToggleBtn.Font = Enum.Font.GothamBlack
	adminToggleBtn.TextSize = 11
	adminToggleBtn.ZIndex = 12
	adminToggleBtn.Parent = inGameHUD
	addCorner(adminToggleBtn, 10)
	addBorderStroke(adminToggleBtn, Color3.fromRGB(16, 12, 8), 2.8)
	addGradient(adminToggleBtn, Color3.fromRGB(255, 222, 72), Color3.fromRGB(232, 152, 22), 90)

	local adminFrame = Instance.new("TextButton")
	adminFrame.Name = "DevAdminConsoleFrame"
	adminFrame.Size = UDim2.new(0, 480, 0, 396)
	adminFrame.AnchorPoint = Vector2.new(1, 0.5)
	adminFrame.Position = UDim2.new(1, -14, 0.5, -8)
	adminFrame.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
	adminFrame.Text = ""
	adminFrame.AutoButtonColor = false
	adminFrame.Active = true
	adminFrame.Visible = false
	adminFrame.ZIndex = 20
	adminFrame.Parent = inGameHUD
	addCorner(adminFrame, 16)
	addBorderStroke(adminFrame, Color3.fromRGB(255, 205, 55), 3.0)

	local adminHeader = Instance.new("TextLabel")
	adminHeader.Size = UDim2.new(1, -56, 0, 30)
	adminHeader.Position = UDim2.new(0, 14, 0, 8)
	adminHeader.BackgroundTransparency = 1
	adminHeader.Text = "🛠️ DEV ADMIN TEST CONSOLE (FINTANFIRE & PIZQWE)"
	adminHeader.TextColor3 = Color3.fromRGB(255, 220, 75)
	adminHeader.Font = Enum.Font.GothamBlack
	adminHeader.TextSize = 13
	adminHeader.TextXAlignment = Enum.TextXAlignment.Left
	adminHeader.ZIndex = 21
	adminHeader.Parent = adminFrame
	addTextStroke(adminHeader, 1.5)

	local adminCloseBtn = Instance.new("TextButton")
	adminCloseBtn.Size = UDim2.new(0, 30, 0, 30)
	adminCloseBtn.Position = UDim2.new(1, -38, 0, 8)
	adminCloseBtn.BackgroundColor3 = Color3.fromRGB(235, 58, 58)
	adminCloseBtn.Text = "X"
	adminCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	adminCloseBtn.Font = Enum.Font.GothamBlack
	adminCloseBtn.TextSize = 14
	adminCloseBtn.ZIndex = 22
	adminCloseBtn.Parent = adminFrame
	addCorner(adminCloseBtn, 8)
	addBorderStroke(adminCloseBtn, Color3.fromRGB(10, 14, 24), 2.0)

	local adminScroll = Instance.new("ScrollingFrame")
	adminScroll.Size = UDim2.new(1, -20, 1, -48)
	adminScroll.Position = UDim2.new(0, 10, 0, 42)
	adminScroll.BackgroundTransparency = 1
	adminScroll.BorderSizePixel = 0
	adminScroll.ScrollBarThickness = 5
	adminScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	adminScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	adminScroll.ZIndex = 21
	adminScroll.Parent = adminFrame

	local sList = Instance.new("UIListLayout")
	sList.Padding = UDim.new(0, 8)
	sList.SortOrder = Enum.SortOrder.LayoutOrder
	sList.Parent = adminScroll

	local function addAdminSection(order: number, titleText: string, buttons: { { Label: string, Color: Color3, Action: () -> () } })
		local hdr = Instance.new("TextLabel")
		hdr.LayoutOrder = order
		hdr.Size = UDim2.new(1, -8, 0, 18)
		hdr.BackgroundTransparency = 1
		hdr.Text = titleText
		hdr.TextColor3 = Color3.fromRGB(135, 225, 255)
		hdr.Font = Enum.Font.GothamBlack
		hdr.TextSize = 11
		hdr.TextXAlignment = Enum.TextXAlignment.Left
		hdr.ZIndex = 22
		hdr.Parent = adminScroll

		local gridHolder = Instance.new("Frame")
		gridHolder.LayoutOrder = order + 1
		gridHolder.Size = UDim2.new(1, -8, 0, 36)
		gridHolder.AutomaticSize = Enum.AutomaticSize.Y
		gridHolder.BackgroundTransparency = 1
		gridHolder.ZIndex = 21
		gridHolder.Parent = adminScroll

		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0, 144, 0, 34)
		gl.CellPadding = UDim2.new(0, 6, 0, 6)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		gl.Parent = gridHolder

		for _, def in ipairs(buttons) do
			local b = Instance.new("TextButton")
			b.BackgroundColor3 = def.Color
			b.Text = def.Label
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 10
			b.TextWrapped = true
			b.ZIndex = 22
			b.Parent = gridHolder
			addCorner(b, 8)
			addBorderStroke(b, Color3.fromRGB(10, 14, 24), 1.8)
			addTextStroke(b, 1.3)
			b.MouseButton1Click:Connect(function()
				playSFX(sfxUpgrade, 0.35)
				def.Action()
			end)
		end
	end

	addAdminSection(1, "1. INSTANT SWITCH MAIN DRONE (TEST EACH ARCHETYPE)", {
		{ Label = "🛸 Basic Drone", Color = Color3.fromRGB(52, 138, 220), Action = function() AdminCommandEvent:FireServer("SetClass", "BasicDrone") end },
		{ Label = "⚡ Rapid (Fast)", Color = Color3.fromRGB(28, 172, 205), Action = function() AdminCommandEvent:FireServer("SetClass", "RapidPulse") end },
		{ Label = "💥 Heavy (Big)", Color = Color3.fromRGB(205, 58, 58), Action = function() AdminCommandEvent:FireServer("SetClass", "HeavyCannon") end },
		{ Label = "🎯 Long-Range", Color = Color3.fromRGB(42, 178, 108), Action = function() AdminCommandEvent:FireServer("SetClass", "LongRangeScout") end },
		{ Label = "🔸 Spread (5x)", Color = Color3.fromRGB(212, 142, 32), Action = function() AdminCommandEvent:FireServer("SetClass", "SpreadShot") end },
		{ Label = "💣 Sticky Bomb", Color = Color3.fromRGB(218, 86, 36), Action = function() AdminCommandEvent:FireServer("SetClass", "StickyBomber") end },
	})

	addAdminSection(3, "2. DIEP.IO PATH & FLEET TESTING", {
		{
			Label = "⭐ Lv.5 + Basic (Popup)",
			Color = Color3.fromRGB(68, 188, 42),
			Action = function()
				modalFrame.Visible = false
				isDiepBannerMinimized = false
				AdminCommandEvent:FireServer("ResetBasicFleet")
				AdminCommandEvent:FireServer("SetLevel", 5)
			end,
		},
		{ Label = "🔄 Reset Lv.1 Basic", Color = Color3.fromRGB(92, 62, 138), Action = function() AdminCommandEvent:FireServer("ResetAllLv1") end },
		{ Label = "🌟 Equip All 5 Paths", Color = Color3.fromRGB(165, 68, 215), Action = function() AdminCommandEvent:FireServer("EquipAll5Paths") end },
		{ Label = "➕ Add Basic Drone", Color = Color3.fromRGB(42, 128, 198), Action = function() AdminCommandEvent:FireServer("AddBasicDrone") end },
		{ Label = "⬆️ Drones +5 Lv", Color = Color3.fromRGB(38, 165, 135), Action = function() AdminCommandEvent:FireServer("LevelUpDrones", 5) end },
		{ Label = "⭐ Player +5 Lv", Color = Color3.fromRGB(212, 155, 28), Action = function() AdminCommandEvent:FireServer("AddLevels", 5) end },
	})

	addAdminSection(5, "3. TARGET DUMMIES, COMBAT & ECONOMY", {
		{
			Label = "🪨 Spawn Test Asteroids",
			Color = Color3.fromRGB(195, 118, 52),
			Action = function()
				local cam = Workspace.CurrentCamera
				local fwd = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
				AdminCommandEvent:FireServer("SpawnTestAsteroids", Vector3.new(fwd.X, 0, fwd.Z))
			end,
		},
		{ Label = "⚡ +10 [Q] Upgrade Pts", Color = Color3.fromRGB(48, 175, 88), Action = function() AdminCommandEvent:FireServer("AddUpgradePoints", 10) end },
		{ Label = "🚀 Boost ATK & Reload", Color = Color3.fromRGB(225, 78, 78), Action = function() AdminCommandEvent:FireServer("BoostCombatStats") end },
		{ Label = "🔄 Reset [Q] Stats", Color = Color3.fromRGB(78, 92, 128), Action = function() AdminCommandEvent:FireServer("ResetCombatStats") end },
		{ Label = "⛏️ +10K Ore & Gems", Color = Color3.fromRGB(195, 152, 32), Action = function() AdminCommandEvent:FireServer("GiveResources") end },
		{ Label = "🌀 Unlock Stations", Color = Color3.fromRGB(145, 72, 205), Action = function() AdminCommandEvent:FireServer("UnlockAllStations") end },
	})

	local function toggleAdmin()
		playSFX(sfxClick, 0.25)
		adminFrame.Visible = not adminFrame.Visible
	end

	adminToggleBtn.MouseButton1Click:Connect(toggleAdmin)
	adminCloseBtn.MouseButton1Click:Connect(function()
		playSFX(sfxClick, 0.25)
		adminFrame.Visible = false
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if (not gameProcessed) and input.KeyCode == Enum.KeyCode.F2 then
			toggleAdmin()
		end
	end)
end)()

switchMainMenuTab("Play")
refreshUI()
RequestInitialStateEvent:FireServer()
