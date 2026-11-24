--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlanetConfig = require(Shared:WaitForChild("PlanetConfig"))
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

local function makeMachineBillboard(adornee: BasePart, title: string, subtitle: string, color: Color3, offsetY: number, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "StylizedMachineCallout"
	bb.Size = UDim2.new(0, 260, 0, 56)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDist or 440
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
	bg.BackgroundTransparency = 0.16
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.4
	stroke.Transparency = 0.25
	stroke.Parent = bg

	-- Sleek left vertical accent bar
	local leftBar = Instance.new("Frame")
	leftBar.Size = UDim2.new(0, 4, 1, -12)
	leftBar.Position = UDim2.new(0, 6, 0, 6)
	leftBar.BackgroundColor3 = color
	leftBar.BorderSizePixel = 0
	leftBar.Parent = bg
	local lbc = Instance.new("UICorner")
	lbc.CornerRadius = UDim.new(1, 0)
	lbc.Parent = leftBar

	-- Subtle top specular highlight line
	local topGlow = Instance.new("Frame")
	topGlow.Size = UDim2.new(1, -24, 0, 1)
	topGlow.Position = UDim2.new(0, 12, 0, 0)
	topGlow.BackgroundColor3 = color
	topGlow.BackgroundTransparency = 0.45
	topGlow.BorderSizePixel = 0
	topGlow.Parent = bg

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -24, 0, 22)
	t.Position = UDim2.new(0, 16, 0, 6)
	t.BackgroundTransparency = 1
	t.Text = string.upper(title)
	t.TextColor3 = Color3.fromRGB(242, 247, 255)
	t.Font = Enum.Font.GothamBlack
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = bg

	local s = Instance.new("TextLabel")
	s.Position = UDim2.new(0, 16, 0, 28)
	s.Size = UDim2.new(1, -24, 0, 22)
	s.BackgroundTransparency = 1
	s.Text = subtitle
	s.TextColor3 = color
	s.Font = Enum.Font.GothamMedium
	s.TextSize = 10
	s.TextWrapped = true
	s.TextXAlignment = Enum.TextXAlignment.Left
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
	-- C. STARFARER WARP GATE & ASCENSION MONOLITH ON THE ORBITAL CONCOURSE
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

	-- WEST PLAZA (`-420, 0, 0`): 🌀 STARFARER WARP GATE & ASCENSION MONOLITH (Carved Basalt & Sandstone)
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
	warpPortal:SetAttribute("HubMachineId", "WarpGate")
	makeMachineBillboard(
		warpPortal,
		"STARFARER WARP & ASCENSION GATE",
		"PRESS [E] OR CLICK [STATIONS] TO TELEPORT OR ASCEND",
		Color3.fromRGB(205, 135, 255),
		46,
		420
	)

	-- ========================================================================
	-- D. EAST PLAZA (`420, 0, 0`): ORBITAL DRONE FOUNDRY & ROLL BAY
	-- ========================================================================
	local eastPos = Vector3.new(hubRingRadius, 0, 0)
	buildMachinePlaza("DroneFoundryPlaza", eastPos, Enum.Material.Concrete, SLATE_MID)

	-- Central Foundry Reactor Pedestal & Gantry Ring
	makePart({
		Name = "FoundryCentralBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 56, 56),
		CFrame = CFrame.new(eastPos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BASALT_DARK,
		Material = Enum.Material.Basalt,
		Parent = hubModel,
	})
	makePart({
		Name = "FoundryTrimRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 60, 60),
		CFrame = CFrame.new(eastPos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(56, 215, 255),
		Material = Enum.Material.Neon,
		Parent = hubModel,
	})

	-- 4 Angled Robotic Gantry Arms converging above the Foundry Core
	local foundryCorePos = eastPos + Vector3.new(0, 38, 0)
	for g = 1, 4 do
		local ga = (g / 4) * math.pi * 2 + math.pi * 0.25
		local gBase = eastPos + Vector3.new(math.cos(ga) * 44, 4, math.sin(ga) * 44)
		local gTop = eastPos + Vector3.new(math.cos(ga) * 24, 54, math.sin(ga) * 24)
		local gLen = (gTop - gBase).Magnitude
		makePart({
			Name = "FoundryGantryArm_" .. g,
			Size = Vector3.new(7, 7, gLen),
			CFrame = CFrame.lookAt((gBase + gTop) * 0.5, gTop),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
		makePart({
			Name = "FoundryGantryEmitter_" .. g,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(8, 8, 8),
			CFrame = CFrame.new(gTop),
			Color = Color3.fromRGB(56, 215, 255),
			Material = Enum.Material.Neon,
			Parent = hubModel,
		})
	end

	local droneFoundryCore = makePart({
		Name = "DroneFoundryCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(24, 24, 24),
		CFrame = CFrame.new(foundryCorePos),
		Color = Color3.fromRGB(56, 215, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = hubModel,
	})
	droneFoundryCore:SetAttribute("HubMachineId", "DroneBay")
	makeMachineBillboard(
		droneFoundryCore,
		"ORBITAL DRONE FOUNDRY & ROLL BAY",
		"PRESS [E] OR CLICK TO ROLL DRONES WITH RESOURCES & UPGRADE SLOTS",
		Color3.fromRGB(56, 215, 255),
		34,
		460
	)

	-- 4 Physical Tiered Drone Roll Pods around the East Plaza (Display 3D Basic Voxel Drones inside!)
	local podShowcaseDrones = { "BasicDrone", "BasicDrone", "BasicDrone", "BasicDrone" }
	for pIdx, podDef in ipairs(PlanetConfig.CompanionPods) do
		local pa = ((pIdx - 2.5) * 0.52) + math.pi -- Arc facing inward toward the Hub bridge (-X)
		local podPos = eastPos + Vector3.new(math.cos(pa) * 46, 0, math.sin(pa) * 46)
		makePart({
			Name = "DronePodPedestal_" .. podDef.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 18, 18),
			CFrame = CFrame.new(podPos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = BASALT_DARK,
			Material = Enum.Material.Basalt,
			Parent = hubModel,
		})
		local podChamber = makePart({
			Name = "DronePodChamber_" .. podDef.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 14, 14),
			CFrame = CFrame.new(podPos + Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = podDef.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.68,
			Parent = hubModel,
		})
		podChamber:SetAttribute("HubMachineId", "DroneBay")
		podChamber:SetAttribute("DronePodId", podDef.Id)
		makePart({
			Name = "DronePodCap_" .. podDef.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 18, 18),
			CFrame = CFrame.new(podPos + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SLATE_MID,
			Material = Enum.Material.Concrete,
			Parent = hubModel,
		})

		-- Place a 3D Hologram Drone inside each Roll Pod
		local sampleDroneId = podShowcaseDrones[pIdx] or "BasicDrone"
		local sampleModel = PlanetGenerator.BuildCompanionDroneModel(sampleDroneId, pIdx == 4, pIdx * 5)
		sampleModel.Name = "PodDisplayDrone_" .. podDef.Id
		sampleModel:PivotTo(CFrame.new(podPos + Vector3.new(0, 16, 0)) * CFrame.Angles(0, pa, 0))
		sampleModel.Parent = hubModel

		local costParts = {}
		if type(podDef.Cost) == "table" then
			for rKey, rAmt in pairs(podDef.Cost) do
				local rMeta = PlanetConfig.ResourceMeta and PlanetConfig.ResourceMeta[rKey]
				local shortName = rMeta and rMeta.ShortName or rKey
				table.insert(costParts, string.format("%s %s", PlanetConfig.FormatNumber(rAmt), shortName))
			end
		end
		makeMachineBillboard(
			podChamber,
			podDef.Name,
			"COST: " .. table.concat(costParts, " + "),
			podDef.Color,
			22,
			220
		)
	end

	-- Animate the Central Dyson Star, Gyroscopic Rings & Drone Foundry Core
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
			droneFoundryCore.CFrame = CFrame.new(foundryCorePos + Vector3.new(0, math.sin(t * 1.8) * 1.5, 0))
				* CFrame.Angles(0, t * 0.6, 0)
		end
	end)

	-- ========================================================================
	-- 4. SCATTERED DEEP-SPACE OUTPOST STATIONS WITH GEM-UNLOCKABLE WARP GATES!
	-- ========================================================================
	local stationsModel = makePersistentModel("DeepSpaceStations", cosmos)
	for _, stDef in ipairs(PlanetConfig.SpaceStations) do
		if stDef.Id ~= "Hub" then
			local stRoot = makePersistentModel("SpaceStation_" .. stDef.Id, stationsModel)
			local center = stDef.Position
			local stColor = stDef.Color

			-- 1. Lower Keel & Multi-Tiered Matte Basalt/Slate Command Deck
			makePart({
				Name = "StationLowerKeel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(36, 68, 68),
				CFrame = CFrame.new(center + Vector3.new(0, -24, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = BASALT_DARK,
				Material = Enum.Material.Basalt,
				Parent = stRoot,
			})
			makePart({
				Name = "StationOuterHullRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(12, 156, 156),
				CFrame = CFrame.new(center + Vector3.new(0, -8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = BASALT_DARK,
				Material = Enum.Material.Basalt,
				Parent = stRoot,
			})
			makePart({
				Name = "StationMainDeck",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(6, 142, 142),
				CFrame = CFrame.new(center + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = SLATE_MID,
				Material = Enum.Material.Slate,
				Parent = stRoot,
			})
			makePart({
				Name = "StationLandingPad",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.5, 118, 118),
				CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = CONCRETE_LIGHT,
				Material = Enum.Material.Cobblestone,
				Parent = stRoot,
			})

			-- 2. 4 Radial Solar / Radiator Wings & 8 Docking Pylons
			for w = 1, 8 do
				local a = (w / 8) * math.pi * 2
				local rimCF = CFrame.new(center) * CFrame.Angles(0, a, 0) * CFrame.new(0, 8, -68)
				makePart({
					Name = "DockingPylon_" .. w,
					Size = Vector3.new(10, 24, 12),
					CFrame = rimCF,
					Color = BASALT_DARK,
					Material = Enum.Material.Basalt,
					Parent = stRoot,
				})
				makePart({
					Name = "DockingBeacon_" .. w,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(6, 6, 6),
					CFrame = rimCF * CFrame.new(0, 14, 0),
					Color = stColor,
					Material = Enum.Material.Neon,
					Parent = stRoot,
				})

				if w % 2 == 1 then
					local wingCF = CFrame.new(center) * CFrame.Angles(0, a, 0) * CFrame.new(0, -4, -108)
					makePart({
						Name = "SolarArrayStrut_" .. w,
						Size = Vector3.new(6, 4, 68),
						CFrame = wingCF,
						Color = CONCRETE_LIGHT,
						Material = Enum.Material.DiamondPlate,
						Parent = stRoot,
					})
					makePart({
						Name = "SolarArrayPanel_" .. w,
						Size = Vector3.new(28, 1.5, 58),
						CFrame = wingCF * CFrame.new(0, 1.5, 0),
						Color = Color3.fromRGB(32, 48, 82):Lerp(stColor, 0.25),
						Material = Enum.Material.Slate,
						Parent = stRoot,
					})
				end
			end

			-- 3. Station Command Citadel & High-Altitude Beacon Spire (Rear of Deck)
			local towerPos = center + Vector3.new(0, 22, -36)
			makePart({
				Name = "StationCommandTower",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(42, 34, 34),
				CFrame = CFrame.new(towerPos) * CFrame.Angles(0, 0, math.rad(90)),
				Color = SLATE_MID,
				Material = Enum.Material.Concrete,
				Parent = stRoot,
			})
			makePart({
				Name = "StationCommandDome",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(32, 22, 32),
				CFrame = CFrame.new(towerPos + Vector3.new(0, 20, 0)),
				Color = SANDSTONE_TRIM,
				Material = Enum.Material.Sandstone,
				Parent = stRoot,
			})
			makePart({
				Name = "StationBeaconSpire",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(48, 3.5, 3.5),
				CFrame = CFrame.new(towerPos + Vector3.new(0, 48, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = BASALT_DARK,
				Material = Enum.Material.Basalt,
				Parent = stRoot,
			})
			local beaconOrb = makePart({
				Name = "StationBeaconTop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(12, 12, 12),
				CFrame = CFrame.new(towerPos + Vector3.new(0, 74, 0)),
				Color = stColor,
				Material = Enum.Material.Neon,
				Parent = stRoot,
			})
			attachStarPngSprite(beaconOrb, stColor, 42, 30000)

			-- 4. THE SPACE STATION WARP GATE STARGATE RING (Center-Front of Deck)
			local stGateCenter = center + Vector3.new(0, 36, 18)
			local stGateRadius = 32
			local stGateSegs = 24
			local stSegLen = (2 * math.pi * stGateRadius) / stGateSegs * 1.08
			for s = 1, stGateSegs do
				local a = (s / stGateSegs) * math.pi * 2
				local segCF = CFrame.new(stGateCenter) * CFrame.Angles(0, 0, a) * CFrame.new(0, stGateRadius, 0)
				makePart({
					Name = "StationGateArch_" .. s,
					Size = Vector3.new(8, stSegLen, 8),
					CFrame = segCF,
					Color = (s % 2 == 0) and BASALT_DARK or SANDSTONE_TRIM,
					Material = (s % 2 == 0) and Enum.Material.Basalt or Enum.Material.Sandstone,
					Parent = stRoot,
				})
			end
			local stPortal = makePart({
				Name = "StationWarpPortal_" .. stDef.Id,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.5, 58, 58),
				CFrame = CFrame.new(stGateCenter) * CFrame.Angles(0, math.rad(90), 0),
				Color = stColor,
				Material = Enum.Material.Neon,
				Transparency = 0.42,
				Parent = stRoot,
			})
			stRoot.PrimaryPart = stPortal

			makeMachineBillboard(
				stPortal,
				string.format("%s (%s💎 TO UNLOCK)", string.upper(stDef.Name), PlanetConfig.FormatNumber(stDef.GemCost)),
				string.format("FLY NEAR & PRESS [E] TO UNLOCK WARP GATE • %s", stDef.StationUnlockPerk),
				stColor,
				42
			)
		end
	end

	-- ========================================================================
	-- 5. INFINITE PROCEDURAL SPACE COLLECTIBLES & STAR CHUNKS CONTAINER
	-- ========================================================================
	local nodesModel = makePersistentModel("CosmicResourceNodes", cosmos)
	nodesContainer = nodesModel

	-- Seed initial chunks around the Hub
	SpaceWorldBuilder.UpdateProceduralChunks({ Vector3.new(0, 48, 215) })

	return cosmos
end

-- ============================================================================
-- 6. DISTANCE-TIERED PROCEDURAL SPACE CHUNK GENERATOR (HP-Scaled Materials & Enemies!)
-- ============================================================================
local CHUNK_SIZE = 550
local COLLECTIBLE_COLORS: { [string]: Color3 } = {
	Aluminum = Color3.fromRGB(190, 202, 218),
	Iron = Color3.fromRGB(185, 118, 82),
	Copper = Color3.fromRGB(232, 132, 68),
	Silver = Color3.fromRGB(220, 234, 250),
	Gold = Color3.fromRGB(255, 205, 45),
	Platinum = Color3.fromRGB(115, 235, 255),
	Titanium = Color3.fromRGB(190, 115, 255),
	Diamond = Color3.fromRGB(85, 255, 225),
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

local function isTooCloseToHubOrStation(pos: Vector3): boolean
	-- Keep central Dyson Star Citadel (r < 140) and East/West Plazas clear,
	-- while allowing starter asteroids around the Sanctuary Orbit!
	local flatDist = Vector2.new(pos.X, pos.Z).Magnitude
	if flatDist < 145 and math.abs(pos.Y) < 95 then
		return true
	end
	if (pos - Vector3.new(420, 18, 0)).Magnitude < 95 or (pos - Vector3.new(-420, 18, 0)).Magnitude < 95 then
		return true
	end
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		if st.Id ~= "Hub" and (pos - st.Position).Magnitude < 145 then
			return true
		end
	end
	return false
end

local function attachNodeAttributes(colModel: Model, resType: string, zoneDef: any, rng: Random)
	local matDef = (PlanetConfig.MaterialNodes and PlanetConfig.MaterialNodes[resType])
		or PlanetConfig.MaterialNodes.Iron
	local hpMult = matDef.HPMult or 1.0
	local drillMult = matDef.DrillReqMult or 1.0
	local valMult = matDef.ValueMult or 1.0

	local baseHP = zoneDef.BaseHP or 35
	local maxHP = math.max(15, math.floor(baseHP * hpMult * rng:NextNumber(0.92, 1.12) + 0.5))
	local reqDrill = math.max(1, math.floor((zoneDef.ReqDrill or 1) * drillMult + 0.5))
	local nodeTitle = matDef.BaseTitle or (resType .. " Asteroid")
	local xpMult = math.max(1, math.pow(zoneDef.YieldMultiplier or 1, 0.55))
	local xpReward = math.max(5, math.floor((matDef.BaseXP or 20) * xpMult + 0.5))

	colModel:SetAttribute("IsSpaceCollectible", true)
	colModel:SetAttribute("NodeType", resType)
	colModel:SetAttribute("ResourceType", resType)
	colModel:SetAttribute("NodeTitle", nodeTitle)
	colModel:SetAttribute("ZoneTier", zoneDef.Tier)
	colModel:SetAttribute("XPReward", xpReward)
	colModel:SetAttribute("MaxHP", maxHP)
	colModel:SetAttribute("HP", maxHP)
	colModel:SetAttribute("ReqDrill", reqDrill)
	colModel:SetAttribute("Available", true)

	local rootPart = colModel.PrimaryPart
	if rootPart then
		rootPart:SetAttribute("IsSpaceCollectible", true)
		rootPart:SetAttribute("NodeType", resType)
		rootPart:SetAttribute("ResourceType", resType)
		rootPart:SetAttribute("NodeTitle", nodeTitle)
		rootPart:SetAttribute("ZoneTier", zoneDef.Tier)
		rootPart:SetAttribute("XPReward", xpReward)
		rootPart:SetAttribute("MaxHP", maxHP)
		rootPart:SetAttribute("HP", maxHP)
		rootPart:SetAttribute("ReqDrill", reqDrill)
		rootPart:SetAttribute("BaseNodeValue", math.floor((zoneDef.BaseNodeValue or 18) * valMult))
		rootPart:SetAttribute("BaseResourceYield", math.floor((zoneDef.BaseResourceYield or 14) * valMult))
		rootPart:SetAttribute("YieldMultiplier", zoneDef.YieldMultiplier or 1.0)
		rootPart:SetAttribute("GemMin", math.max(1, math.floor(zoneDef.GemRange[1] * (matDef.GemMult or 1.0))))
		rootPart:SetAttribute("GemMax", math.max(2, math.floor(zoneDef.GemRange[2] * (matDef.GemMult or 1.0))))
		rootPart:SetAttribute("Available", true)
	end
end

local function pickMineralTypeForZone(zoneTier: number, rng: Random): string
	local roll = rng:NextInteger(1, 100)
	if zoneTier <= 1 then
		if roll <= 34 then
			return "Aluminum"
		elseif roll <= 66 then
			return "Iron"
		elseif roll <= 86 then
			return "Copper"
		elseif roll <= 95 then
			return "Silver"
		else
			return "Gold"
		end
	elseif zoneTier == 2 then
		if roll <= 18 then
			return "Aluminum"
		elseif roll <= 44 then
			return "Iron"
		elseif roll <= 70 then
			return "Copper"
		elseif roll <= 88 then
			return "Silver"
		elseif roll <= 97 then
			return "Gold"
		else
			return "Platinum"
		end
	elseif zoneTier == 3 then
		if roll <= 20 then
			return "Iron"
		elseif roll <= 45 then
			return "Copper"
		elseif roll <= 72 then
			return "Silver"
		elseif roll <= 90 then
			return "Gold"
		elseif roll <= 97 then
			return "Platinum"
		else
			return "Titanium"
		end
	elseif zoneTier == 4 then
		if roll <= 18 then
			return "Copper"
		elseif roll <= 42 then
			return "Silver"
		elseif roll <= 70 then
			return "Gold"
		elseif roll <= 90 then
			return "Platinum"
		else
			return "Titanium"
		end
	else
		if roll <= 15 then
			return "Silver"
		elseif roll <= 38 then
			return "Gold"
		elseif roll <= 65 then
			return "Platinum"
		elseif roll <= 88 then
			return "Titanium"
		else
			return "Diamond"
		end
	end
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

	-- Special Starter Ring in the central chunk (0, 0, 0) with Aluminum, Iron, Copper & Gold asteroids!
	if cx == 0 and cy == 0 and cz == 0 then
		local z1 = PlanetConfig.DeepSpaceZones[1]
		local starterTypes = { "Aluminum", "Iron", "Aluminum", "Iron", "Copper", "Iron", "Gold", "Aluminum", "Copper", "Iron" }
		for idx, sType in ipairs(starterTypes) do
			local angle = (idx / #starterTypes) * math.pi * 2 + 0.35
			local rDist = 250 + (idx % 3) * 45
			local sPos = Vector3.new(math.cos(angle) * rDist, 32 + ((idx % 2 == 0) and 18 or -12), math.sin(angle) * rDist)
			if not isTooCloseToHubOrStation(sPos) then
				local baseCol = COLLECTIBLE_COLORS[sType] or z1.ThemeColor
				local matDef = PlanetConfig.MaterialNodes[sType] or PlanetConfig.MaterialNodes.Iron
				local nodeTitle = matDef.BaseTitle or (sType .. " Asteroid")
				local colModel = PlanetGenerator.BuildSpaceCollectibleModel(sType, sPos, nodeTitle, baseCol, 1)
				attachNodeAttributes(colModel, sType, z1, rng)
				colModel.Parent = chunkModel
			end
		end
	end

	-- Spawn 6 to 8 mineral element asteroids per chunk scaled to zone distance
	local itemCount = rng:NextInteger(6, 8)
	for _ = 1, itemCount do
		local pos = chunkOrigin + Vector3.new(
			rng:NextNumber(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45),
			rng:NextNumber(-115, 115),
			rng:NextNumber(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45)
		)

		if not isTooCloseToHubOrStation(pos) then
			local dist = pos.Magnitude
			local zoneDef = PlanetConfig.GetZoneForDistance(dist)

			local resType = pickMineralTypeForZone(zoneDef.Tier, rng)
			local matDef = PlanetConfig.MaterialNodes[resType] or PlanetConfig.MaterialNodes.Iron
			local nodeTitle = matDef.BaseTitle or (resType .. " Asteroid")
			local baseCol = COLLECTIBLE_COLORS[resType] or zoneDef.ThemeColor

			local colModel = PlanetGenerator.BuildSpaceCollectibleModel(
				resType,
				pos,
				nodeTitle,
				baseCol,
				zoneDef.Tier
			)
			attachNodeAttributes(colModel, resType, zoneDef, rng)
			colModel.Parent = chunkModel
		end
	end

	-- Optimized: 4 distant stars per chunk (reduced from 16 to eliminate instance bloat!)
	for s = 1, 4 do
		local sPos = chunkOrigin + Vector3.new(
			rng:NextNumber(-CHUNK_SIZE * 0.48, CHUNK_SIZE * 0.48),
			rng:NextNumber(-200, 200),
			rng:NextNumber(-CHUNK_SIZE * 0.48, CHUNK_SIZE * 0.48)
		)
		if sPos.Magnitude > 540 then
			local isBright = (s == 1)
			local sz = isBright and rng:NextNumber(5.0, 8.5) or rng:NextNumber(2.0, 3.8)
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
				attachStarPngSprite(sp, sCol, sz * 2.8, 5500)
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

function SpaceWorldBuilder.SpawnAdminTestAsteroids(originPos: Vector3, forwardDir: Vector3?): number
	if not nodesContainer then
		return 0
	end
	local oldChunk = nodesContainer:FindFirstChild("SpaceChunk_AdminTest")
	if oldChunk then
		oldChunk:Destroy()
	end

	local chunkModel = makePersistentModel("SpaceChunk_AdminTest", nodesContainer)
	local rng = Random.new(os.clock() * 1000)
	local rawFwd = (typeof(forwardDir) == "Vector3") and Vector3.new(forwardDir.X, 0, forwardDir.Z) or Vector3.new(0, 0, -1)
	local fwd = (rawFwd.Magnitude > 0.05) and rawFwd.Unit or Vector3.new(0, 0, -1)
	local right = fwd:Cross(Vector3.yAxis)
	if right.Magnitude < 0.01 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local z1 = PlanetConfig.DeepSpaceZones[1]
	local targets = {
		-- Close spread row (85 studs ahead): fast & spread shots
		{ Type = "Aluminum", Fwd = 85, Right = -28, Up = 0 },
		{ Type = "Iron", Fwd = 85, Right = 0, Up = 0 },
		{ Type = "Copper", Fwd = 85, Right = 28, Up = 0 },
		-- Tight mid cluster (165 studs ahead): heavy splash & sticky bomb stacking
		{ Type = "Silver", Fwd = 165, Right = -14, Up = 0 },
		{ Type = "Gold", Fwd = 165, Right = 0, Up = 0 },
		{ Type = "Platinum", Fwd = 165, Right = 14, Up = 0 },
		-- Far sniper target (520 studs ahead): Long-Range Drone flight & sniping
		{ Type = "Diamond", Fwd = 520, Right = 0, Up = 0 },
	}

	for _, t in ipairs(targets) do
		local pos = originPos + fwd * t.Fwd + right * t.Right + Vector3.new(0, t.Up, 0)
		local matDef = PlanetConfig.MaterialNodes[t.Type] or PlanetConfig.MaterialNodes.Iron
		local baseCol = COLLECTIBLE_COLORS[t.Type] or z1.ThemeColor
		local colModel = PlanetGenerator.BuildSpaceCollectibleModel(t.Type, pos, matDef.BaseTitle or (t.Type .. " Asteroid"), baseCol, 1)
		attachNodeAttributes(colModel, t.Type, z1, rng)
		colModel.Parent = chunkModel
	end

	return #targets
end

return SpaceWorldBuilder
