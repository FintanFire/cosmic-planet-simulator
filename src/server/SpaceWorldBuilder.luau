--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlanetGenerator = require(Shared:WaitForChild("PlanetGenerator"))

local SpaceWorldBuilder = {}

-- Every structural part defaults to matte Slate with 0 reflectance (NO plastic/metallic glare!)
local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Reflectance = 0
	p.Material = Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.LeftSurface = Enum.SurfaceType.Smooth
	p.RightSurface = Enum.SurfaceType.Smooth
	p.FrontSurface = Enum.SurfaceType.Smooth
	p.BackSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	if p.Material ~= Enum.Material.Neon then
		p.Reflectance = 0
	end
	return p
end

local function makeWedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CastShadow = false
	w.Reflectance = 0
	w.Material = Enum.Material.Slate
	w.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(w :: any)[k] = v
	end
	if w.Material ~= Enum.Material.Neon then
		w.Reflectance = 0
	end
	return w
end

local function makePersistentModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	m.Parent = parent
	return m
end

local function makeMachineBillboard(adornee: BasePart, title: string, subtitle: string, color: Color3, offsetY: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 340, 0, 76)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 1400
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	bg.BackgroundTransparency = 0.15
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = bg

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 0.54, 0)
	t.Position = UDim2.new(0, 8, 0, 4)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.15
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Parent = bg

	local s = Instance.new("TextLabel")
	s.Position = UDim2.new(0, 8, 0.55, 0)
	s.Size = UDim2.new(1, -16, 0.38, 0)
	s.BackgroundTransparency = 1
	s.Text = subtitle
	s.TextColor3 = Color3.fromRGB(220, 228, 242)
	s.TextStrokeTransparency = 0.25
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.Parent = bg
end

-- Attach a crisp PNG Starburst Sprite (`BillboardGui` + `ImageLabel`) for distant stars
local function attachStarPngSprite(parentPart: BasePart, color: Color3, studSize: number, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "StarPNGSprite"
	bb.Size = UDim2.new(studSize, 0, studSize, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or 18000
	bb.Adornee = parentPart
	bb.Parent = parentPart

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.Image = "rbxasset://textures/particles/sparkles_main.dds"
	img.ImageColor3 = color
	img.ImageTransparency = 0.12
	img.Parent = bb
end

-- Helper to build a natural multi-part Wood + LeafyGrass tree for the Gaia Bio-Vat Sanctuary
local function buildNaturalTree(parent: Instance, basePos: Vector3, trunkH: number, canopyColor: Color3)
	makePart({
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 2.8, 2.8),
		CFrame = CFrame.new(basePos + Vector3.new(0, trunkH * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(102, 68, 38),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	makePart({
		Name = "TreeCanopyLow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(12, 7.5, 12),
		CFrame = CFrame.new(basePos + Vector3.new(0, trunkH + 1.5, 0)),
		Color = canopyColor,
		Material = Enum.Material.LeafyGrass,
		Parent = parent,
	})
	makePart({
		Name = "TreeCanopyHigh",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8.5, 6, 8.5),
		CFrame = CFrame.new(basePos + Vector3.new(0, trunkH + 5.5, 0)),
		Color = canopyColor:Lerp(Color3.fromRGB(185, 225, 130), 0.22),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
end

local cosmosRoot: Model? = nil
local nodesContainer: Model? = nil
local activeChunks: { [string]: { Model: Model, LastTouched: number } } = {}

function SpaceWorldBuilder.BuildCosmos(): Model
	pcall(function()
		(Workspace :: any).StreamingEnabled = false
	end)

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local spawnLoc = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLoc then
		spawnLoc:Destroy()
	end

	-- ========================================================================
	-- 1. PITCH-BLACK OPEN SPACE SKY + NATURAL MATTE LIGHTING (NO SHINY GLARE!)
	-- ========================================================================
	for _, child in ipairs(Lighting:GetChildren()) do
		child:Destroy()
	end

	Lighting.ClockTime = 0.0
	Lighting.Ambient = Color3.fromRGB(128, 134, 148)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 144, 158)
	Lighting.Brightness = 1.15
	Lighting.GlobalShadows = false
	Lighting.EnvironmentSpecularScale = 0.0
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.FogEnd = 100000
	Lighting.FogStart = 100000

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 5000
	sky.Parent = Lighting

	-- High-threshold subtle bloom so ONLY true Neon (Stars & Radioactive Cores) glows softly
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.16
	bloom.Size = 18
	bloom.Threshold = 1.65
	bloom.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = 0.0
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.08
	colorCorrection.Parent = Lighting

	local existingCosmos = Workspace:FindFirstChild("CosmicEnvironment")
	if existingCosmos then
		existingCosmos:Destroy()
	end
	local cosmos = makePersistentModel("CosmicEnvironment", Workspace)
	cosmosRoot = cosmos

	-- ========================================================================
	-- 2. PROPERLY SCATTERED 360° DISTANT STARFIELD (Stars ARE Shiny/Glowing!)
	-- ========================================================================
	local starsModel = makePersistentModel("OpenSpaceStarfield", cosmos)
	local rng = Random.new(20261114)
	local starColors = {
		Color3.fromRGB(255, 252, 245), -- Pure Warm Starlight White
		Color3.fromRGB(210, 232, 255), -- Blue-White B-Type Star
		Color3.fromRGB(255, 232, 175), -- G-Type Solar Yellow
		Color3.fromRGB(255, 195, 135), -- K-Type Amber Star
		Color3.fromRGB(175, 215, 255), -- Sirius Cyan-White
		Color3.fromRGB(245, 195, 225), -- Faint Rose Binary
	}

	-- 650 Uniformly Scattered Stars across the full 3D Celestial Sphere (Tiny Pinpoints + Bright Stars)
	local goldenAngle = math.pi * (3 - math.sqrt(5))
	for i = 1, 650 do
		-- Golden-angle spherical Fibonacci + jitter ensures zero clumping and natural scattering
		local yBase = 1 - ((i - 0.5) / 650) * 2
		local y = math.clamp(yBase + rng:NextNumber(-0.04, 0.04), -0.99, 0.99)
		local rSlice = math.sqrt(math.max(0.001, 1 - y * y))
		local theta = i * goldenAngle + rng:NextNumber(-0.12, 0.12)
		local dir = Vector3.new(math.cos(theta) * rSlice, y, math.sin(theta) * rSlice).Unit

		local dist = rng:NextNumber(850, 5800)
		local pos = dir * dist
		local sColor = starColors[rng:NextInteger(1, #starColors)]

		local roll = i % 16
		local coreSz = 2.5
		if roll == 0 then
			coreSz = rng:NextNumber(14, 24) -- Major distant star
		elseif roll <= 3 then
			coreSz = rng:NextNumber(6, 11) -- Medium star
		else
			coreSz = rng:NextNumber(2.0, 4.8) -- Tiny pinpoint star
		end

		local starPart = makePart({
			Name = "Star_" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(coreSz, coreSz, coreSz),
			CFrame = CFrame.new(pos),
			Color = sColor,
			Material = Enum.Material.Neon,
			Parent = starsModel,
		})

		if roll == 0 then
			attachStarPngSprite(starPart, sColor, coreSz * 3.8, 22000)
		elseif roll <= 3 then
			attachStarPngSprite(starPart, sColor, coreSz * 2.5, 16000)
		end
	end

	-- 4 Distant Stellar Suns in Deep Space (True Stars -> Neon + Corona)
	local distantSuns = {
		{ Name = "Hyperion Red Giant", Pos = Vector3.new(3200, 680, -3400), Size = 240, Color = Color3.fromRGB(255, 135, 55) },
		{ Name = "Vega Blue Supergiant", Pos = Vector3.new(-3500, 520, -2900), Size = 210, Color = Color3.fromRGB(135, 210, 255) },
		{ Name = "Antares Golden Star", Pos = Vector3.new(2600, 880, 3300), Size = 190, Color = Color3.fromRGB(255, 215, 115) },
		{ Name = "Sirius Binary Sun", Pos = Vector3.new(-3100, -440, 3200), Size = 200, Color = Color3.fromRGB(185, 235, 255) },
	}
	for _, g in ipairs(distantSuns) do
		local sun = makePart({
			Name = g.Name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(g.Size, g.Size, g.Size),
			CFrame = CFrame.new(g.Pos),
			Color = g.Color,
			Material = Enum.Material.Neon,
			Parent = starsModel,
		})
		attachStarPngSprite(sun, g.Color, g.Size * 3.0, 25000)
	end

	-- ========================================================================
	-- 3. MASSIVE OPEN-SPACE GALACTIC NEXUS HUB (`Radius = 420`, Matte Stone & Alloy!)
	-- ========================================================================
	local hubModel = makePersistentModel("GalacticNexusHub", cosmos)
	local hubRingRadius = 420

	local BASALT_DARK = Color3.fromRGB(42, 46, 56)
	local SLATE_MID = Color3.fromRGB(68, 74, 88)
	local CONCRETE_LIGHT = Color3.fromRGB(132, 138, 152)
	local SANDSTONE_TRIM = Color3.fromRGB(178, 154, 112)
	local LIMESTONE_PALE = Color3.fromRGB(192, 188, 178)

	-- A. CENTRAL MEGASTRUCTURE: THE DYSON STAR-REACTOR CITADEL (At 0, 0, 0)
	-- Multi-tiered Matte Basalt, Slate & Concrete Citadel Foundation
	makePart({
		Name = "CitadelDeepKeel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(44, 104, 104),
		CFrame = CFrame.new(0, -30, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "CitadelLowerBasaltDeck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 198, 198),
		CFrame = CFrame.new(0, -9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "CitadelMainSlateDeck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 176, 176),
		CFrame = CFrame.new(0, -3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = SLATE_MID,
		Material = Enum.Material.Slate,
		Parent = hubModel,
	})
	makePart({
		Name = "CitadelUpperPlaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 144, 144),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = CONCRETE_LIGHT,
		Material = Enum.Material.Cobblestone,
		Parent = hubModel,
	})
	makePart({
		Name = "CitadelReactorPedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 74, 74),
		CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "CitadelSandstoneTrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 78, 78),
		CFrame = CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = SANDSTONE_TRIM,
		Material = Enum.Material.Sandstone,
		Parent = hubModel,
	})

	-- 8 Radial Stone Buttresses & 4 Angled Dyson Containment Pylons
	local starPos = Vector3.new(0, 56, 0)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		makePart({
			Name = "CitadelButtress_" .. i,
			Size = Vector3.new(14, 10, 52),
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, -3, -74),
			Color = SLATE_MID,
			Material = Enum.Material.Concrete,
			Parent = hubModel,
		})
		makeWedge({
			Name = "CitadelKeelFin_" .. i,
			Size = Vector3.new(8, 36, 54),
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, -24, -64) * CFrame.Angles(math.rad(180), 0, 0),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})

		if i % 2 == 0 then
			local basePos = Vector3.new(math.cos(a) * 62, 4, math.sin(a) * 62)
			local midPos = Vector3.new(math.cos(a) * 56, 36, math.sin(a) * 56)
			local tipPos = Vector3.new(math.cos(a) * 40, 66, math.sin(a) * 40)

			local len1 = (midPos - basePos).Magnitude
			makePart({
				Name = "DysonPylonLower_" .. i,
				Size = Vector3.new(10, 10, len1),
				CFrame = CFrame.lookAt((basePos + midPos) * 0.5, midPos),
				Color = BASALT_DARK,
				Material = Enum.Material.Basalt,
				Parent = hubModel,
			})
			local len2 = (tipPos - midPos).Magnitude
			makePart({
				Name = "DysonPylonUpper_" .. i,
				Size = Vector3.new(8, 8, len2),
				CFrame = CFrame.lookAt((midPos + tipPos) * 0.5, tipPos),
				Color = CONCRETE_LIGHT,
				Material = Enum.Material.Concrete,
				Parent = hubModel,
			})
			makePart({
				Name = "DysonPylonJoint_" .. i,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(12, 12, 12),
				CFrame = CFrame.new(midPos),
				Color = SANDSTONE_TRIM,
				Material = Enum.Material.Sandstone,
				Parent = hubModel,
			})
			makePart({
				Name = "DysonEmitterCap_" .. i,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(9, 9, 9),
				CFrame = CFrame.new(tipPos),
				Color = Color3.fromRGB(255, 205, 85),
				Material = Enum.Material.Neon,
				Parent = hubModel,
			})
			-- Thin plasma containment beam feeding the captured Dyson Star
			local beamLen = (starPos - tipPos).Magnitude
			makePart({
				Name = "DysonStarBeam_" .. i,
				Size = Vector3.new(1.4, 1.4, beamLen),
				CFrame = CFrame.lookAt((tipPos + starPos) * 0.5, starPos),
				Color = Color3.fromRGB(255, 215, 110),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				Parent = hubModel,
			})
		end
	end

	-- The Captured Dyson Star Core (A real star -> legitimately Neon!)
	local nexusCore = makePart({
		Name = "CentralDysonStar",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(36, 36, 36),
		CFrame = CFrame.new(starPos),
		Color = Color3.fromRGB(255, 225, 115),
		Material = Enum.Material.Neon,
		Parent = hubModel,
	})
	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(255, 230, 170)
	coreLight.Brightness = 1.8
	coreLight.Range = 220
	coreLight.Parent = nexusCore

	-- 2 Counter-Rotating Matte Basalt & Slate Gyroscopic Rings around the Dyson Star
	local function buildGyroRing(name: string, radius: number, mat: Enum.Material, col: Color3): Model
		local rm = makePersistentModel(name, hubModel)
		local pRoot = makePart({
			Name = "RingPivot",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(starPos),
			Transparency = 1,
			Parent = rm,
		})
		rm.PrimaryPart = pRoot
		local segs = 28
		local segLen = (2 * math.pi * radius) / segs * 1.06
		for s = 1, segs do
			local a = (s / segs) * math.pi * 2
			makePart({
				Name = "GyroSeg_" .. s,
				Size = Vector3.new(3.5, 3.0, segLen),
				CFrame = CFrame.new(starPos) * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0),
				Color = col,
				Material = mat,
				Parent = rm,
			})
		end
		return rm
	end

	local gyroRing1 = buildGyroRing("DysonGyroRingOuter", 44, Enum.Material.Basalt, BASALT_DARK)
	local gyroRing2 = buildGyroRing("DysonGyroRingInner", 34, Enum.Material.Sandstone, SANDSTONE_TRIM)

	makeMachineBillboard(
		nexusCore,
		"⚡ MACHINE 1: DYSON STAR-REACTOR",
		"FLY NEAR & PRESS [E] OR CLICK [⚡ REACTOR] TO OVERCLOCK ENERGY!",
		Color3.fromRGB(255, 220, 95),
		34
	)

	-- B. GRAND ORBITAL CONCOURSE RING (`Radius = 420` Studs) & 4 RADIAL STONE BRIDGES
	local ringSegments = 64
	local ringSegLen = (2 * math.pi * hubRingRadius) / ringSegments * 1.04
	for i = 1, ringSegments do
		local a = (i / ringSegments) * math.pi * 2
		local segCF = CFrame.Angles(0, a, 0) * CFrame.new(hubRingRadius, -4, 0)
		makePart({
			Name = "ConcourseDeck_" .. i,
			Size = Vector3.new(34, 5, ringSegLen),
			CFrame = segCF,
			Color = SLATE_MID,
			Material = Enum.Material.Slate,
			Parent = hubModel,
		})
		makePart({
			Name = "ConcoursePaving_" .. i,
			Size = Vector3.new(20, 1.2, ringSegLen),
			CFrame = segCF * CFrame.new(0, 2.5, 0),
			Color = CONCRETE_LIGHT,
			Material = Enum.Material.Cobblestone,
			Parent = hubModel,
		})
		makePart({
			Name = "ConcourseCurbOuter_" .. i,
			Size = Vector3.new(2.5, 2.5, ringSegLen),
			CFrame = segCF * CFrame.new(16, 2.5, 0),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
		makePart({
			Name = "ConcourseCurbInner_" .. i,
			Size = Vector3.new(2.5, 2.5, ringSegLen),
			CFrame = segCF * CFrame.new(-16, 2.5, 0),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
	end

	-- 4 Radial Causeway Bridges connecting the Central Citadel (`95` studs) to the Orbital Concourse (`420` studs)
	local bridgeAngles = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
	for bIdx, bAngle in ipairs(bridgeAngles) do
		local bridgeLen = 250
		local midDist = 220
		local bridgeCF = CFrame.Angles(0, bAngle, 0) * CFrame.new(0, -4, -midDist)
		makePart({
			Name = "RadialCauseway_" .. bIdx,
			Size = Vector3.new(28, 5, bridgeLen),
			CFrame = bridgeCF,
			Color = SLATE_MID,
			Material = Enum.Material.Slate,
			Parent = hubModel,
		})
		makePart({
			Name = "CausewayStoneRoad_" .. bIdx,
			Size = Vector3.new(16, 1.2, bridgeLen),
			CFrame = bridgeCF * CFrame.new(0, 2.5, 0),
			Color = LIMESTONE_PALE,
			Material = Enum.Material.Cobblestone,
			Parent = hubModel,
		})
		-- Stone Archways along each bridge
		for arch = -2, 2 do
			local archZ = arch * 46
			for _, side in ipairs({ -1, 1 }) do
				makePart({
					Name = string.format("BridgePillar_%d_%d_%d", bIdx, arch, side),
					Size = Vector3.new(3.5, 24, 3.5),
					CFrame = bridgeCF * CFrame.new(side * 12.5, 14, archZ),
					Color = BASALT_DARK,
					Material = Enum.Material.Basalt,
					Parent = hubModel,
				})
			end
			makePart({
				Name = string.format("BridgeArchTop_%d_%d", bIdx, arch),
				Size = Vector3.new(29, 3.5, 4.0),
				CFrame = bridgeCF * CFrame.new(0, 26, archZ),
				Color = SANDSTONE_TRIM,
				Material = Enum.Material.Sandstone,
				Parent = hubModel,
			})
		end
	end

	-- ========================================================================
	-- C. 4 COLOSSAL HUB MACHINES ON THE ORBITAL CONCOURSE (Realistic Materials!)
	-- ========================================================================

	-- Helper to build a Machine Plaza Platform
	local function buildMachinePlaza(name: string, center: Vector3, topMat: Enum.Material, topColor: Color3)
		makePart({
			Name = name .. "_Foundation",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 136, 136),
			CFrame = CFrame.new(center + Vector3.new(0, -10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
		makePart({
			Name = name .. "_Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 142, 142),
			CFrame = CFrame.new(center + Vector3.new(0, -3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SANDSTONE_TRIM,
			Material = Enum.Material.Sandstone,
			Parent = hubModel,
		})
		makePart({
			Name = name .. "_Surface",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 126, 126),
			CFrame = CFrame.new(center + Vector3.new(0, -1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = topColor,
			Material = topMat,
			Parent = hubModel,
		})
	end

	-- 1. NORTH MACHINE (`0, 0, -420`): 🔭 ASTRAL QUANTUM OBSERVATORY (Limestone, Concrete & Slate)
	local northPos = Vector3.new(0, 0, -hubRingRadius)
	buildMachinePlaza("ObservatoryPlaza", northPos, Enum.Material.Cobblestone, LIMESTONE_PALE)

	makePart({
		Name = "ObservatoryDrumWall",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(28, 76, 76),
		CFrame = CFrame.new(northPos + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = LIMESTONE_PALE,
		Material = Enum.Material.Limestone,
		Parent = hubModel,
	})
	local obsDome = makePart({
		Name = "ObservatoryRotundaDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(74, 58, 74),
		CFrame = CFrame.new(northPos + Vector3.new(0, 26, 0)),
		Color = CONCRETE_LIGHT,
		Material = Enum.Material.Concrete,
		Parent = hubModel,
	})
	-- Telescope Barrel (Matte Basalt & Slate)
	local teleCF = CFrame.new(northPos + Vector3.new(0, 42, 16)) * CFrame.Angles(math.rad(-35), 0, 0)
	makePart({
		Name = "TelescopeMainTube",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(52, 18, 18),
		CFrame = teleCF * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "Telescope BrassTrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 20, 20),
		CFrame = teleCF * CFrame.new(0, 0, -22) * CFrame.Angles(0, 0, math.rad(90)),
		Color = SANDSTONE_TRIM,
		Material = Enum.Material.Sandstone,
		Parent = hubModel,
	})
	local lensPart = makePart({
		Name = "TelescopeObjectiveLens",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 16.5, 16.5),
		CFrame = teleCF * CFrame.new(0, 0, -25.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 185, 235),
		Material = Enum.Material.Glacier,
		Parent = hubModel,
	})
	-- 4 Stone Astrolabe Pillars around the Observatory
	for p = 1, 4 do
		local a = (p / 4) * math.pi * 2 + math.rad(45)
		local pPos = northPos + Vector3.new(math.cos(a) * 50, 16, math.sin(a) * 50)
		makePart({
			Name = "ObservatoryPillar_" .. p,
			Size = Vector3.new(8, 32, 8),
			CFrame = CFrame.new(pPos),
			Color = SANDSTONE_TRIM,
			Material = Enum.Material.Sandstone,
			Parent = hubModel,
		})
		makePart({
			Name = "ObservatoryGlobe_" .. p,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(10, 10, 10),
			CFrame = CFrame.new(pPos + Vector3.new(0, 20, 0)),
			Color = SLATE_MID,
			Material = Enum.Material.Slate,
			Parent = hubModel,
		})
	end
	makeMachineBillboard(
		obsDome,
		"🔭 MACHINE 4: ASTRAL QUANTUM OBSERVATORY",
		"FLY NEAR & PRESS [E] OR CLICK [🔭 TECH LAB] FOR 1.80x TECH!",
		Color3.fromRGB(130, 210, 255),
		46
	)
	local _ = lensPart

	-- 2. EAST MACHINE (`420, 0, 0`): ⚒️ TITAN MATTER-REFINERY & CORE FORGE (Basalt, DiamondPlate, Rock & Magma)
	local eastPos = Vector3.new(hubRingRadius, 0, 0)
	buildMachinePlaza("RefineryPlaza", eastPos, Enum.Material.DiamondPlate, SLATE_MID)

	local furnaceCore = makePart({
		Name = "TitanBlastFurnace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(54, 52, 52),
		CFrame = CFrame.new(eastPos + Vector3.new(-10, 26, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	for band = 1, 3 do
		makePart({
			Name = "FurnaceReinforcementBand_" .. band,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 55, 55),
			CFrame = CFrame.new(eastPos + Vector3.new(-10, band * 14, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SANDSTONE_TRIM,
			Material = Enum.Material.DiamondPlate,
			Parent = hubModel,
		})
	end
	-- Molten Smelting Crucible Vat in front of the furnace (Molten Lava -> CrackedLava + Neon core)
	makePart({
		Name = "CrucibleOuterWall",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 38, 38),
		CFrame = CFrame.new(eastPos + Vector3.new(26, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "CrucibleMoltenMagma",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(15, 32, 32),
		CFrame = CFrame.new(eastPos + Vector3.new(26, 7.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 115, 20),
		Material = Enum.Material.CrackedLava,
		Parent = hubModel,
	})
	-- Twin Industrial Smokestacks (Matte Concrete & Basalt)
	for _, zOff in ipairs({ -32, 32 }) do
		makePart({
			Name = "RefinerySmokestack_" .. zOff,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(72, 16, 16),
			CFrame = CFrame.new(eastPos + Vector3.new(-28, 36, zOff)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SLATE_MID,
			Material = Enum.Material.Concrete,
			Parent = hubModel,
		})
		makePart({
			Name = "SmokestackCap_" .. zOff,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 19, 19),
			CFrame = CFrame.new(eastPos + Vector3.new(-28, 72, zOff)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
	end
	-- Ore Conveyor Ramp with natural Rock & Limestone Ore Boulders
	makePart({
		Name = "OreConveyorBed",
		Size = Vector3.new(14, 3, 76),
		CFrame = CFrame.new(eastPos + Vector3.new(26, 4, 0)),
		Color = BASALT_DARK,
		Material = Enum.Material.DiamondPlate,
		Parent = hubModel,
	})
	for k = -2, 2 do
		makePart({
			Name = "OreBoulder_" .. k,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 6, 7),
			CFrame = CFrame.new(eastPos + Vector3.new(26, 8, k * 14)),
			Color = (k % 2 == 0) and SANDSTONE_TRIM or CONCRETE_LIGHT,
			Material = (k % 2 == 0) and Enum.Material.Limestone or Enum.Material.Rock,
			Parent = hubModel,
		})
	end
	makeMachineBillboard(
		furnaceCore,
		"⚒️ MACHINE 2: TITAN MATTER-REFINERY",
		"FLY NEAR & PRESS [E] OR CLICK [⚒️ REFINERY] FOR 1.75x MINERALS!",
		Color3.fromRGB(255, 175, 55),
		42
	)

	-- 3. SOUTH MACHINE (`0, 0, 420`): 🌿 GAIA BIO-SYNTHESIZER & TERRARIUM SANCTUARY (Grass, Wood, Soil & Stone)
	local southPos = Vector3.new(0, 0, hubRingRadius)
	buildMachinePlaza("BioSanctuaryPlaza", southPos, Enum.Material.Grass, Color3.fromRGB(58, 152, 68))

	-- Central Ancient World-Tree & Botanical Pergola Arches (Natural Wood & LeafyGrass!)
	makePart({
		Name = "BioEarthMound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(56, 16, 56),
		CFrame = CFrame.new(southPos + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(96, 70, 46),
		Material = Enum.Material.Ground,
		Parent = hubModel,
	})
	local worldTreeTrunk = makePart({
		Name = "WorldTreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(44, 16, 16),
		CFrame = CFrame.new(southPos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(102, 68, 38),
		Material = Enum.Material.Wood,
		Parent = hubModel,
	})
	makePart({
		Name = "WorldTreeMainCanopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(54, 28, 54),
		CFrame = CFrame.new(southPos + Vector3.new(0, 48, 0)),
		Color = Color3.fromRGB(48, 158, 68),
		Material = Enum.Material.LeafyGrass,
		Parent = hubModel,
	})
	makePart({
		Name = "WorldTreeUpperCanopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(38, 22, 38),
		CFrame = CFrame.new(southPos + Vector3.new(0, 62, 0)),
		Color = Color3.fromRGB(68, 182, 82),
		Material = Enum.Material.Grass,
		Parent = hubModel,
	})
	-- 6 Surrounding Botanical Grove Trees & 4 Limestone Terrarium Planters
	for t = 1, 6 do
		local a = (t / 6) * math.pi * 2
		local tPos = southPos + Vector3.new(math.cos(a) * 44, 0, math.sin(a) * 44)
		buildNaturalTree(
			hubModel,
			tPos,
			14 + (t % 2) * 4,
			(t % 2 == 0) and Color3.fromRGB(52, 162, 74) or Color3.fromRGB(78, 175, 68)
		)
	end
	for k = 1, 4 do
		local a = (k / 4) * math.pi * 2 + math.rad(45)
		local pPos = southPos + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
		makePart({
			Name = "BioPlanter_" .. k,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(8, 16, 16),
			CFrame = CFrame.new(pPos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = LIMESTONE_PALE,
			Material = Enum.Material.Limestone,
			Parent = hubModel,
		})
	end
	makeMachineBillboard(
		worldTreeTrunk,
		"🌿 MACHINE 3: GAIA BIO-SYNTHESIZER",
		"FLY NEAR & PRESS [E] OR CLICK [🌿 BIO-VAT] FOR 1.70x BIOMASS & CITIZENS!",
		Color3.fromRGB(85, 235, 125),
		52
	)

	-- 4. WEST MACHINE (`-420, 0, 0`): 🌀 STARFARER WARP GATE & ASCENSION MONOLITH (Carved Basalt & Sandstone)
	local westPos = Vector3.new(-hubRingRadius, 0, 0)
	buildMachinePlaza("WarpGatePlaza", westPos, Enum.Material.Cobblestone, SLATE_MID)

	-- Colossal 28-Segment Carved Basalt & Sandstone Stargate Ring (`Radius = 46`)
	local gateCenter = westPos + Vector3.new(0, 48, 0)
	local gateSegs = 28
	local gateRadius = 44
	local gateSegLen = (2 * math.pi * gateRadius) / gateSegs * 1.08
	for s = 1, gateSegs do
		local a = (s / gateSegs) * math.pi * 2
		local segCF = CFrame.new(gateCenter) * CFrame.Angles(a, 0, 0) * CFrame.new(0, gateRadius, 0)
		makePart({
			Name = "StargateStoneArch_" .. s,
			Size = Vector3.new(10, 8, gateSegLen),
			CFrame = segCF,
			Color = (s % 2 == 0) and BASALT_DARK or SANDSTONE_TRIM,
			Material = (s % 2 == 0) and Enum.Material.Basalt or Enum.Material.Sandstone,
			Parent = hubModel,
		})
	end
	-- 2 Massive Flanking Stone Obelisks supporting the Stargate
	for _, zOff in ipairs({ -48, 48 }) do
		makePart({
			Name = "WarpObelisk_" .. zOff,
			Size = Vector3.new(16, 68, 16),
			CFrame = CFrame.new(westPos + Vector3.new(0, 34, zOff)),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
		makeWedge({
			Name = "WarpObeliskCap_" .. zOff,
			Size = Vector3.new(16, 14, 16),
			CFrame = CFrame.new(westPos + Vector3.new(0, 75, zOff)),
			Color = SANDSTONE_TRIM,
			Material = Enum.Material.Sandstone,
			Parent = hubModel,
		})
	end
	local warpPortal = makePart({
		Name = "WarpEventHorizon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.5, 78, 78),
		CFrame = CFrame.new(gateCenter),
		Color = Color3.fromRGB(155, 85, 235),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		Parent = hubModel,
	})
	makeMachineBillboard(
		warpPortal,
		"🌀 MACHINE 5: STARFARER WARP & ASCENSION GATE",
		"FLY NEAR & PRESS [E] OR CLICK [🌀 WARP] TO TELEPORT OR ASCEND!",
		Color3.fromRGB(205, 135, 255),
		52
	)

	-- Animate the Central Dyson Star & Counter-Rotating Gyroscopic Containment Rings
	task.spawn(function()
		local t = 0
		while hubModel.Parent do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			if gyroRing1.PrimaryPart then
				gyroRing1:PivotTo(CFrame.new(starPos) * CFrame.Angles(t * 0.45, t * 0.28, math.rad(32)))
			end
			if gyroRing2.PrimaryPart then
				gyroRing2:PivotTo(CFrame.new(starPos) * CFrame.Angles(-t * 0.58, -t * 0.36, math.rad(-48)))
			end
			nexusCore.CFrame = CFrame.new(starPos + Vector3.new(0, math.sin(t * 1.2) * 2, 0))
		end
	end)

	-- ========================================================================
	-- 4. INFINITE PROCEDURAL SPACE COLLECTIBLES & STAR CHUNKS CONTAINER
	-- ========================================================================
	local nodesModel = makePersistentModel("CosmicResourceNodes", cosmos)
	nodesContainer = nodesModel

	-- Seed initial chunks around the Hub
	SpaceWorldBuilder.UpdateProceduralChunks({ Vector3.new(0, 48, 215) })

	return cosmos
end

-- ============================================================================
-- 5. INFINITE PROCEDURAL SPACE CHUNK GENERATOR (Detailed Models + Local Stars!)
-- ============================================================================
local CHUNK_SIZE = 550
local COLLECTIBLE_DEFS = {
	{ Type = "Minerals", Title = "Asteroid Ore Geode", Color = Color3.fromRGB(235, 175, 55) },
	{ Type = "Biomass", Title = "Botanical Spore-Asteroid", Color = Color3.fromRGB(75, 225, 115) },
	{ Type = "Energy", Title = "Radioactive Pulsar Core", Color = Color3.fromRGB(65, 215, 255) },
	{ Type = "Tech", Title = "Precursor Satellite", Color = Color3.fromRGB(185, 125, 255) },
	{ Type = "PopulationPod", Title = "Colonist Ark-Pod", Color = Color3.fromRGB(255, 215, 95) },
	{ Type = "SupernovaChest", Title = "Supernova Relic Vault", Color = Color3.fromRGB(255, 145, 55) },
}

local CHUNK_STAR_COLORS = {
	Color3.fromRGB(255, 252, 245),
	Color3.fromRGB(205, 230, 255),
	Color3.fromRGB(255, 230, 175),
	Color3.fromRGB(255, 195, 140),
}

local function getChunkKey(cx: number, cy: number, cz: number): string
	return string.format("%d_%d_%d", cx, cy, cz)
end

local function spawnProceduralChunk(cx: number, cy: number, cz: number)
	if not nodesContainer then
		return
	end
	local key = getChunkKey(cx, cy, cz)
	if activeChunks[key] then
		activeChunks[key].LastTouched = os.clock()
		return
	end

	local chunkModel = makePersistentModel("SpaceChunk_" .. key, nodesContainer)
	local seed = cx * 73856093 + cy * 19349663 + cz * 83492791
	local rng = Random.new(seed)

	local chunkOrigin = Vector3.new(cx * CHUNK_SIZE, cy * 320, cz * CHUNK_SIZE)

	-- Spawn 4 to 6 high-detail collectible space objects per chunk (outside the central Hub core)
	local itemCount = rng:NextInteger(4, 6)
	for _ = 1, itemCount do
		local pos = chunkOrigin + Vector3.new(
			rng:NextNumber(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45),
			rng:NextNumber(-120, 120),
			rng:NextNumber(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45)
		)

		if pos.Magnitude >= 195 then
			local roll = rng:NextInteger(1, 100)
			local def = COLLECTIBLE_DEFS[1]
			if roll <= 23 then
				def = COLLECTIBLE_DEFS[1]
			elseif roll <= 46 then
				def = COLLECTIBLE_DEFS[2]
			elseif roll <= 69 then
				def = COLLECTIBLE_DEFS[3]
			elseif roll <= 86 then
				def = COLLECTIBLE_DEFS[4]
			elseif roll <= 95 then
				def = COLLECTIBLE_DEFS[5]
			else
				def = COLLECTIBLE_DEFS[6]
			end

			local colModel = PlanetGenerator.BuildSpaceCollectibleModel(def.Type, pos, def.Title, def.Color)
			local rootPart = colModel.PrimaryPart
			if rootPart then
				rootPart:SetAttribute("IsSpaceCollectible", true)
				rootPart:SetAttribute("ResourceType", def.Type)
				rootPart:SetAttribute("NodeTitle", def.Title)
				rootPart:SetAttribute("Available", true)
				local distMult = math.max(1.0, math.pow(pos.Magnitude / 400, 1.35))
				rootPart:SetAttribute("DistanceMultiplier", distMult)
			end
			colModel.Parent = chunkModel
		end
	end

	-- Scatter 16 procedural deep-space stars inside every chunk so infinite space is always naturally starry!
	for s = 1, 16 do
		local sPos = chunkOrigin + Vector3.new(
			rng:NextNumber(-CHUNK_SIZE * 0.49, CHUNK_SIZE * 0.49),
			rng:NextNumber(-220, 220),
			rng:NextNumber(-CHUNK_SIZE * 0.49, CHUNK_SIZE * 0.49)
		)
		if sPos.Magnitude > 520 then
			local isBright = (s % 5 == 0)
			local sz = isBright and rng:NextNumber(4.5, 8.5) or rng:NextNumber(1.6, 3.6)
			local sCol = CHUNK_STAR_COLORS[rng:NextInteger(1, #CHUNK_STAR_COLORS)]
			local sp = makePart({
				Name = "ChunkStar_" .. s,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(sz, sz, sz),
				CFrame = CFrame.new(sPos),
				Color = sCol,
				Material = Enum.Material.Neon,
				Parent = chunkModel,
			})
			if isBright then
				attachStarPngSprite(sp, sCol, sz * 3.0, 6000)
			end
		end
	end

	activeChunks[key] = {
		Model = chunkModel,
		LastTouched = os.clock(),
	}
end

function SpaceWorldBuilder.UpdateProceduralChunks(playerPositions: { Vector3 })
	local now = os.clock()
	for _, pos in ipairs(playerPositions) do
		local cx = math.floor((pos.X + CHUNK_SIZE * 0.5) / CHUNK_SIZE)
		local cy = math.floor((pos.Y + 160) / 320)
		local cz = math.floor((pos.Z + CHUNK_SIZE * 0.5) / CHUNK_SIZE)

		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					spawnProceduralChunk(cx + dx, cy + dy, cz + dz)
				end
			end
		end
	end

	for key, info in pairs(activeChunks) do
		if (now - info.LastTouched) > 45 then
			if info.Model and info.Model.Parent then
				info.Model:Destroy()
			end
			activeChunks[key] = nil
		end
	end
end

return SpaceWorldBuilder
