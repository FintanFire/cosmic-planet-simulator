--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlanetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlanetConfig"))
local SpeciesConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpeciesConfig"))

local PlanetGenerator = {}

-- Realistic Material Map (Matte, natural materials that match what the object actually is)
local MATERIAL_MAP: { [string]: Enum.Material } = {
	Grass = Enum.Material.Grass,
	LeafyGrass = Enum.Material.LeafyGrass,
	Ground = Enum.Material.Ground,
	Sand = Enum.Material.Sand,
	Rock = Enum.Material.Rock,
	Slate = Enum.Material.Slate,
	Basalt = Enum.Material.Basalt,
	Limestone = Enum.Material.Limestone,
	Sandstone = Enum.Material.Sandstone,
	Snow = Enum.Material.Snow,
	Glacier = Enum.Material.Glacier,
	Mud = Enum.Material.Mud,
	CrackedLava = Enum.Material.CrackedLava,
	Concrete = Enum.Material.Concrete,
	Wood = Enum.Material.Wood,
	WoodPlanks = Enum.Material.WoodPlanks,
	Fabric = Enum.Material.Fabric,
	Cobblestone = Enum.Material.Cobblestone,
	Granite = Enum.Material.Granite,
	DiamondPlate = Enum.Material.DiamondPlate,
	Neon = Enum.Material.Neon,
	-- Legacy fallbacks mapped to non-shiny natural equivalents
	Plastic = Enum.Material.Grass,
	SmoothPlastic = Enum.Material.Slate,
	Glass = Enum.Material.Glacier,
	Ice = Enum.Material.Glacier,
	Metal = Enum.Material.Concrete,
	Foil = Enum.Material.Limestone,
	Marble = Enum.Material.Sandstone,
	ForceField = Enum.Material.Neon,
}

local function resolveMaterial(matName: string?, fallback: Enum.Material): Enum.Material
	if matName and MATERIAL_MAP[matName] then
		return MATERIAL_MAP[matName]
	end
	return fallback
end

local function resolveColor(rgb: { number }?, fallback: Color3): Color3
	if type(rgb) == "table" and #rgb >= 3 then
		return Color3.fromRGB(
			math.clamp(tonumber(rgb[1]) or 255, 0, 255),
			math.clamp(tonumber(rgb[2]) or 255, 0, 255),
			math.clamp(tonumber(rgb[3]) or 255, 0, 255)
		)
	end
	return fallback
end

local function createPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Massless = true
	p.Reflectance = 0
	p.CastShadow = false
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

local function createWedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.Massless = true
	w.Reflectance = 0
	w.CastShadow = false
	w.Material = Enum.Material.Rock
	w.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(w :: any)[k] = v
	end
	if w.Material ~= Enum.Material.Neon then
		w.Reflectance = 0
	end
	return w
end

-- Safe orthonormal CFrame where local +Y points along outward radial normal `n`
local function radialCFrame(originPos: Vector3, normal: Vector3, dist: number, twistAngle: number?): CFrame
	local n = normal.Unit
	local refUp = (math.abs(n.Y) < 0.92) and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local right = n:Cross(refUp).Unit
	local back = right:Cross(n).Unit
	local pos = originPos + n * dist
	local cf = CFrame.fromMatrix(pos, right, n, back)
	if twistAngle then
		cf = cf * CFrame.Angles(0, twistAngle, 0)
	end
	return cf
end

-- Precompute 28 Fibonacci Sphere points for organic, expansive planetary continent & island placement
local FIBONACCI_POINTS: { { Normal: Vector3, Twist: number, RankRatio: number } } = {}
do
	local count = 28
	local goldenAngle = math.pi * (3 - math.sqrt(5))
	local validIdx = 0
	for i = 0, count - 1 do
		local y = 1 - (i / (count - 1)) * 2
		local radiusAtY = math.sqrt(math.max(0, 1 - y * y))
		local theta = goldenAngle * i
		local x = math.cos(theta) * radiusAtY
		local z = math.sin(theta) * radiusAtY
		if math.abs(y) < 0.86 then
			validIdx += 1
			table.insert(FIBONACCI_POINTS, {
				Normal = Vector3.new(x, y, z).Unit,
				Twist = (i * 1.47) % (math.pi * 2),
				RankRatio = ((validIdx * 7) % 20) / 20,
			})
		end
	end
end

-- ============================================================================
-- 1. DETAILED 3D SPECIES CHARACTER BUILDER (Natural Matte Materials!)
-- ============================================================================
function PlanetGenerator.BuildSpeciesCharacterModel(speciesId: string, scale: number?): Model
	local s = scale or 1.0
	local sp = SpeciesConfig.Species[speciesId] or SpeciesConfig.Species.Terranauts
	local charModel = Instance.new("Model")
	charModel.Name = "Species_" .. sp.Id
	pcall(function()
		charModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	-- Choose realistic materials based on the species biology
	local bodyMat = Enum.Material.Fabric
	local headMat = Enum.Material.Limestone
	local armorMat = Enum.Material.Slate
	if speciesId == "Lithoids" then
		bodyMat = Enum.Material.Rock
		headMat = Enum.Material.Slate
		armorMat = Enum.Material.Basalt
	elseif speciesId == "Synthetics" then
		bodyMat = Enum.Material.Concrete
		headMat = Enum.Material.Concrete
		armorMat = Enum.Material.DiamondPlate
	elseif speciesId == "Sylvan" then
		bodyMat = Enum.Material.Wood
		headMat = Enum.Material.Wood
		armorMat = Enum.Material.LeafyGrass
	elseif speciesId == "Pyroclasts" then
		bodyMat = Enum.Material.Basalt
		headMat = Enum.Material.CrackedLava
		armorMat = Enum.Material.Rock
	elseif speciesId == "Astraeans" then
		bodyMat = Enum.Material.Fabric
		headMat = Enum.Material.Sandstone
		armorMat = Enum.Material.Limestone
	end

	local origin = CFrame.new(0, 0, 0)
	local darkTrim = sp.PrimaryColor:Lerp(Color3.fromRGB(24, 26, 34), 0.50)

	local torso = createPart({
		Name = "Torso",
		Size = Vector3.new(2.0 * s, 2.0 * s, 1.05 * s),
		CFrame = origin * CFrame.new(0, 3.0 * s, 0),
		Color = sp.PrimaryColor,
		Material = bodyMat,
		Parent = charModel,
	})
	charModel.PrimaryPart = torso

	createPart({
		Name = "UtilityBelt",
		Size = Vector3.new(2.08 * s, 0.35 * s, 1.12 * s),
		CFrame = torso.CFrame * CFrame.new(0, -0.82 * s, 0),
		Color = darkTrim,
		Material = armorMat,
		Parent = charModel,
	})

	createPart({
		Name = "ChestCorePlate",
		Size = Vector3.new(1.3 * s, 1.1 * s, 0.16 * s),
		CFrame = torso.CFrame * CFrame.new(0, 0.18 * s, -0.52 * s),
		Color = darkTrim,
		Material = armorMat,
		Parent = charModel,
	})

	createPart({
		Name = "ChestEmblem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.22 * s, 0.68 * s, 0.68 * s),
		CFrame = torso.CFrame * CFrame.new(0, 0.18 * s, -0.56 * s) * CFrame.Angles(0, math.rad(90), 0),
		Color = sp.SecondaryColor,
		Material = (speciesId == "Pyroclasts" or speciesId == "Synthetics") and Enum.Material.Neon or armorMat,
		Parent = charModel,
	})

	createPart({
		Name = "Neck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35 * s, 0.8 * s, 0.8 * s),
		CFrame = torso.CFrame * CFrame.new(0, 1.08 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = darkTrim,
		Material = armorMat,
		Parent = charModel,
	})

	local head = createPart({
		Name = "Head",
		Size = Vector3.new(1.45 * s, 1.45 * s, 1.45 * s),
		CFrame = torso.CFrame * CFrame.new(0, 1.82 * s, 0),
		Color = sp.SecondaryColor,
		Material = headMat,
		Parent = charModel,
	})

	for _, side in ipairs({ -1, 1 }) do
		createPart({
			Name = "Eye_" .. side,
			Size = Vector3.new(0.26 * s, 0.32 * s, 0.14 * s),
			CFrame = head.CFrame * CFrame.new(side * 0.34 * s, 0.12 * s, -0.70 * s),
			Color = (speciesId == "Synthetics" or speciesId == "Pyroclasts")
				and Color3.fromRGB(255, 210, 75)
				or Color3.fromRGB(22, 26, 34),
			Material = (speciesId == "Synthetics" or speciesId == "Pyroclasts") and Enum.Material.Neon or Enum.Material.Slate,
			Parent = charModel,
		})

		createPart({
			Name = "ShoulderPad_" .. side,
			Size = Vector3.new(1.12 * s, 0.55 * s, 1.18 * s),
			CFrame = torso.CFrame * CFrame.new(side * 1.50 * s, 0.78 * s, 0),
			Color = sp.PrimaryColor,
			Material = armorMat,
			Parent = charModel,
		})

		createPart({
			Name = "Arm_" .. side,
			Size = Vector3.new(0.95 * s, 1.85 * s, 0.95 * s),
			CFrame = torso.CFrame * CFrame.new(side * 1.50 * s, -0.05 * s, 0),
			Color = sp.SecondaryColor,
			Material = bodyMat,
			Parent = charModel,
		})

		createPart({
			Name = "Gauntlet_" .. side,
			Size = Vector3.new(1.02 * s, 0.55 * s, 1.02 * s),
			CFrame = torso.CFrame * CFrame.new(side * 1.50 * s, -0.78 * s, 0),
			Color = darkTrim,
			Material = armorMat,
			Parent = charModel,
		})

		createPart({
			Name = "Leg_" .. side,
			Size = Vector3.new(0.95 * s, 1.95 * s, 0.98 * s),
			CFrame = torso.CFrame * CFrame.new(side * 0.52 * s, -1.98 * s, 0),
			Color = darkTrim,
			Material = bodyMat,
			Parent = charModel,
		})

		createPart({
			Name = "Boot_" .. side,
			Size = Vector3.new(1.02 * s, 0.50 * s, 1.22 * s),
			CFrame = torso.CFrame * CFrame.new(side * 0.52 * s, -2.75 * s, -0.10 * s),
			Color = sp.PrimaryColor,
			Material = armorMat,
			Parent = charModel,
		})
	end

	if speciesId == "Terranauts" then
		createPart({
			Name = "HelmetVisor",
			Size = Vector3.new(1.32 * s, 0.64 * s, 0.22 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.08 * s, -0.68 * s),
			Color = Color3.fromRGB(38, 65, 98),
			Material = Enum.Material.Slate,
			Parent = charModel,
		})
		createPart({
			Name = "BackpackMain",
			Size = Vector3.new(1.5 * s, 1.5 * s, 0.65 * s),
			CFrame = torso.CFrame * CFrame.new(0, 0.1 * s, 0.82 * s),
			Color = Color3.fromRGB(165, 175, 190),
			Material = Enum.Material.Concrete,
			Parent = charModel,
		})
	elseif speciesId == "Lithoids" then
		for _, side in ipairs({ -1, 1 }) do
			createWedge({
				Name = "StoneShoulderHorn_" .. side,
				Size = Vector3.new(0.65 * s, 1.45 * s, 0.65 * s),
				CFrame = torso.CFrame * CFrame.new(side * 1.55 * s, 1.35 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 22)),
				Color = Color3.fromRGB(205, 130, 55),
				Material = Enum.Material.Limestone,
				Parent = charModel,
			})
		end
		createWedge({
			Name = "StoneCrown",
			Size = Vector3.new(0.8 * s, 1.1 * s, 0.8 * s),
			CFrame = head.CFrame * CFrame.new(0, 1.15 * s, 0),
			Color = Color3.fromRGB(215, 145, 65),
			Material = Enum.Material.Rock,
			Parent = charModel,
		})
	elseif speciesId == "Synthetics" then
		createPart({
			Name = "CyberVisor",
			Size = Vector3.new(1.48 * s, 0.30 * s, 0.20 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.14 * s, -0.68 * s),
			Color = Color3.fromRGB(0, 215, 175),
			Material = Enum.Material.Neon,
			Parent = charModel,
		})
		for _, side in ipairs({ -1, 1 }) do
			createPart({
				Name = "MechaWing_" .. side,
				Size = Vector3.new(0.22 * s, 1.8 * s, 1.1 * s),
				CFrame = torso.CFrame * CFrame.new(side * 0.85 * s, 0.35 * s, 0.95 * s) * CFrame.Angles(math.rad(15), math.rad(side * 28), 0),
				Color = Color3.fromRGB(75, 88, 105),
				Material = Enum.Material.DiamondPlate,
				Parent = charModel,
			})
		end
	elseif speciesId == "Sylvan" then
		local cap = createPart({
			Name = "BotanicalCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.65 * s, 1.15 * s, 2.65 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.92 * s, 0),
			Color = Color3.fromRGB(55, 165, 85),
			Material = Enum.Material.LeafyGrass,
			Parent = charModel,
		})
		for spotIdx = 1, 6 do
			local a = (spotIdx / 6) * math.pi * 2
			createPart({
				Name = "CapBud_" .. spotIdx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.45 * s, 0.28 * s, 0.45 * s),
				CFrame = cap.CFrame * CFrame.new(math.cos(a) * 0.85 * s, 0.35 * s, math.sin(a) * 0.85 * s),
				Color = Color3.fromRGB(215, 195, 110),
				Material = Enum.Material.Sandstone,
				Parent = charModel,
			})
		end
	elseif speciesId == "Pyroclasts" then
		for p = 1, 4 do
			local a = (p / 4) * math.pi * 2
			createWedge({
				Name = "MagmaHorn_" .. p,
				Size = Vector3.new(0.55 * s, 1.05 * s, 0.55 * s),
				CFrame = head.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.05 * s, -0.45 * s),
				Color = Color3.fromRGB(245, 125, 25),
				Material = Enum.Material.CrackedLava,
				Parent = charModel,
			})
		end
	elseif speciesId == "Astraeans" then
		for seg = 1, 12 do
			local a = (seg / 12) * math.pi * 2
			createPart({
				Name = "AstralCrownSeg_" .. seg,
				Size = Vector3.new(0.22 * s, 0.18 * s, 0.62 * s),
				CFrame = head.CFrame * CFrame.new(0, 1.25 * s, 0) * CFrame.Angles(math.rad(14), a, 0) * CFrame.new(1.05 * s, 0, 0),
				Color = Color3.fromRGB(215, 195, 140),
				Material = Enum.Material.Sandstone,
				Parent = charModel,
			})
		end
	end

	return charModel
end

-- ============================================================================
-- 2. HIGH-DETAIL MINERAL ELEMENT ASTEROID MODELS (With Sleek Sci-Fi XP + HP Tag!)
-- ============================================================================
function PlanetGenerator.BuildSpaceCollectibleModel(
	collectibleType: string,
	pos: Vector3,
	_title: string,
	accentColor: Color3,
	zoneTier: number?
): Model
	local tier = math.clamp(zoneTier or 1, 1, 6)
	local zDef = PlanetConfig.DeepSpaceZones[tier] or PlanetConfig.DeepSpaceZones[1]
	local matNode = (PlanetConfig.MaterialNodes and PlanetConfig.MaterialNodes[collectibleType])
		or PlanetConfig.MaterialNodes.Iron
	local s = (zDef.ScaleMod or 1.0) * math.clamp(0.92 + (matNode.HPMult or 1.0) * 0.08, 0.9, 1.45)
	local zoneRockMat = resolveMaterial(matNode.RockMaterial or zDef.RockMat, Enum.Material.Rock)
	local veinMat = resolveMaterial(matNode.VeinMaterial or zDef.AccentMat, Enum.Material.Slate)
	local nodeColor = matNode.Color or accentColor or zDef.ThemeColor

	local model = Instance.new("Model")
	model.Name = string.format("SpaceAsteroid_T%d_%s", tier, collectibleType)
	model:SetAttribute("NodeType", collectibleType)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	local originCF = CFrame.new(pos)
	local core = createPart({
		Name = "CollectibleRoot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(18 * s, 14.5 * s, 16.5 * s),
		CFrame = originCF,
		Color = Color3.fromRGB(78, 76, 82):Lerp(nodeColor, 0.28),
		Material = zoneRockMat,
		Parent = model,
	})
	model.PrimaryPart = core

	-- Clustered asteroid rock boulders around the core
	for b = 1, 4 do
		local a = (b / 4) * math.pi * 2 + 0.4
		local yOff = ((b % 2 == 0) and 2.5 or -2.2) * s
		createPart({
			Name = "AsteroidBoulder_" .. b,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(12.5 * s, 10.5 * s, 13.0 * s),
			CFrame = originCF * CFrame.new(math.cos(a) * 6.5 * s, yOff, math.sin(a) * 6.5 * s),
			Color = Color3.fromRGB(64, 62, 70):Lerp(nodeColor, 0.22),
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end

	-- Protruding Mineral Element Veins & Ore Chunks across the asteroid
	local veinCount = (collectibleType == "Gold" or collectibleType == "Platinum" or collectibleType == "Titanium" or collectibleType == "Diamond") and 7 or 5
	for v = 1, veinCount do
		local a = (v / veinCount) * math.pi * 2
		local tilt = CFrame.Angles(math.rad(22 + (v % 3) * 14), a, math.rad(-18))
		local h = (9.5 + (v % 3) * 2.5) * s
		local w = (3.8 + (v % 2) * 1.1) * s
		createWedge({
			Name = "MineralVein_" .. v,
			Size = Vector3.new(w, h, w),
			CFrame = originCF * tilt * CFrame.new(0, 6.2 * s, 0),
			Color = nodeColor,
			Material = veinMat,
			Parent = model,
		})
	end

	-- Equatorial metallic ore chunks embedded into the asteroid sides
	for c = 1, 4 do
		local ca = (c / 4) * math.pi * 2 + 0.8
		createPart({
			Name = "OreChunk_" .. c,
			Shape = Enum.PartType.Block,
			Size = Vector3.new(5.2 * s, 4.4 * s, 5.2 * s),
			CFrame = originCF * CFrame.Angles(math.rad(c * 28), ca, math.rad(c * 17)) * CFrame.new(8.2 * s, 0, 0),
			Color = nodeColor,
			Material = veinMat,
			Parent = model,
		})
	end

	-- Sleek High-Tech Sci-Fi Telemetry Callout with Element Name, XP Reward & Live HP Bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "CollectibleIconGui"
	bb.Size = UDim2.new(0, 156, 0, 38)
	bb.StudsOffset = Vector3.new(0, 15.5 * s, 0)
	bb.MaxDistance = (matNode.BaseXP and matNode.BaseXP >= 150) and 340 or 230
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Adornee = core
	bb.Parent = core

	local badge = Instance.new("Frame")
	badge.Name = "BadgeFrame"
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	badge.BackgroundTransparency = 0.18
	badge.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = nodeColor
	stroke.Thickness = 1.2
	stroke.Transparency = 0.25
	stroke.Parent = badge

	local leftAccent = Instance.new("Frame")
	leftAccent.Size = UDim2.new(0, 3, 1, -8)
	leftAccent.Position = UDim2.new(0, 4, 0, 4)
	leftAccent.BackgroundColor3 = nodeColor
	leftAccent.BorderSizePixel = 0
	leftAccent.Parent = badge
	local lac = Instance.new("UICorner")
	lac.CornerRadius = UDim.new(1, 0)
	lac.Parent = leftAccent

	local symbolStr = matNode.Symbol or "◆"
	local shortTag = matNode.ShortTag or string.upper(collectibleType)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "IconLabel"
	titleLbl.Size = UDim2.new(1, -14, 0, 16)
	titleLbl.Position = UDim2.new(0, 11, 0, 2)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = string.format("%s %s • +%s XP", symbolStr, shortTag, PlanetConfig.FormatNumber(matNode.BaseXP or 20))
	titleLbl.TextColor3 = Color3.fromRGB(238, 244, 255)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 10
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = badge

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Size = UDim2.new(1, -16, 0, 10)
	hpBg.Position = UDim2.new(0, 11, 0, 21)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = badge
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(1, 0)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = nodeColor
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(1, 0)
	hpfc.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Text = "100%"
	hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpText.Font = Enum.Font.GothamBold
	hpText.TextSize = 8
	hpText.Parent = hpBg

	local function refreshHeaderAndHP()
		local xpVal = tonumber(model:GetAttribute("XPReward")) or matNode.BaseXP or 20
		titleLbl.Text = string.format("%s %s • +%s XP", symbolStr, shortTag, PlanetConfig.FormatNumber(xpVal))

		local curHP = tonumber(model:GetAttribute("HP"))
		local maxHP = tonumber(model:GetAttribute("MaxHP"))
		if curHP and maxHP and maxHP > 0 then
			local ratio = math.clamp(curHP / maxHP, 0, 1)
			hpFill.Size = UDim2.fromScale(ratio, 1)
			hpText.Text = string.format("%s / %s", PlanetConfig.FormatNumber(curHP), PlanetConfig.FormatNumber(maxHP))
			if ratio < 1 then
				bb.MaxDistance = 380
			end
		end
	end
	model:GetAttributeChangedSignal("HP"):Connect(refreshHeaderAndHP)
	model:GetAttributeChangedSignal("MaxHP"):Connect(refreshHeaderAndHP)
	model:GetAttributeChangedSignal("XPReward"):Connect(refreshHeaderAndHP)
	task.defer(refreshHeaderAndHP)

	return model
end

-- ============================================================================
-- 2B. HIGH-CRAFT VOXEL-STYLE DRONE MODELS & STICKY BOMB BUILDER
-- ============================================================================
local function addVoxel(
	m: Model,
	posUnits: Vector3,
	sizeUnits: Vector3,
	u: number,
	col: Color3,
	mat: Enum.Material?,
	name: string?
): Part
	return createPart({
		Name = name or "Voxel",
		Shape = Enum.PartType.Block,
		Size = sizeUnits * u,
		CFrame = CFrame.new(posUnits * u),
		Color = col,
		Material = mat or Enum.Material.SmoothPlastic,
		Parent = m,
	})
end

local function addVoxelSym(
	m: Model,
	posUnits: Vector3,
	sizeUnits: Vector3,
	u: number,
	col: Color3,
	mat: Enum.Material?,
	namePrefix: string?
)
	addVoxel(m, Vector3.new(posUnits.X, posUnits.Y, posUnits.Z), sizeUnits, u, col, mat, (namePrefix or "Voxel") .. "_R")
	addVoxel(m, Vector3.new(-posUnits.X, posUnits.Y, posUnits.Z), sizeUnits, u, col, mat, (namePrefix or "Voxel") .. "_L")
end

-- Resolves legacy drone IDs to their modern Voxel Class archetype
local LEGACY_VOXEL_CLASS_MAP: { [string]: string } = {
	ScrapWelder = "BasicDrone",
	SputnikMiner = "LongRangeScout",
	BioScout = "SpreadShot",
	QuartzCutter = "RapidPulse",
	SolarRelay = "HeavyCannon",
	CryoSentinel = "OrbitalSniper",
	PulsarValkyrie = "MinigunVortex",
	DarkMatterCherub = "StickyBomber",
	QuantumSeraph = "ClusterSapper",
	ChronosDragon = "AnnihilatorCore",
}

function PlanetGenerator.BuildCompanionDroneModel(companionId: string, isGolden: boolean?, level: number?): Model
	local resolvedId = LEGACY_VOXEL_CLASS_MAP[companionId] or companionId
	local cDef = PlanetConfig.Companions[resolvedId] or PlanetConfig.Companions.BasicDrone
	local m = Instance.new("Model")
	m.Name = "VoxelDrone_" .. resolvedId
	local lvScale = 1.0 + math.clamp((tonumber(level) or 1) - 1, 0, 24) * 0.015
	local u = 0.52 * lvScale

	local priCol = isGolden and Color3.fromRGB(255, 210, 55) or (cDef.Color or Color3.fromRGB(85, 195, 255))
	local glowCol = isGolden and Color3.fromRGB(255, 240, 120) or (cDef.BeamColor or priCol)
	local darkCol = isGolden and Color3.fromRGB(72, 58, 32) or Color3.fromRGB(34, 40, 54)
	local midCol = darkCol:Lerp(priCol, 0.25)
	local lightCol = priCol:Lerp(Color3.fromRGB(245, 248, 255), 0.38)
	local armorMat = isGolden and Enum.Material.Sandstone or Enum.Material.SmoothPlastic
	local frameMat = Enum.Material.Slate

	-- Central Voxel Cube Core (PrimaryPart)
	local body = addVoxel(m, Vector3.new(0, 0, 0), Vector3.new(5, 4, 5), u, darkCol, frameMat, "DroneCore")
	m.PrimaryPart = body

	-- Stepped Top & Bottom Armor Caps (crisp voxel bevel silhouette)
	addVoxel(m, Vector3.new(0, 2.5, 0), Vector3.new(4, 1, 4), u, priCol, armorMat, "TopCap")
	addVoxel(m, Vector3.new(0, -2.4, 0), Vector3.new(3.5, 1, 3.5), u, midCol, armorMat, "BotCap")
	-- Glowing Front Optics Strip
	addVoxel(m, Vector3.new(0, 0.6, -2.7), Vector3.new(3.2, 1.0, 0.8), u, glowCol, Enum.Material.Neon, "OpticVisor")
	-- Rear Voxel Engine Thrust Block
	addVoxel(m, Vector3.new(0, 0, 2.8), Vector3.new(3.0, 2.2, 1.0), u, darkCol, frameMat, "RearThrusterHousing")
	addVoxel(m, Vector3.new(0, 0, 3.3), Vector3.new(2.0, 1.2, 0.6), u, glowCol, Enum.Material.Neon, "RearThrusterGlow")

	local muzzleZ = -4.2 * u

	if resolvedId == "RapidPulse" or resolvedId == "MinigunVortex" or resolvedId == "TwinLaser" then
		-- FAST-FIRE GATLING / RAPID BOLT VOXEL DRONE
		local isQuad = (resolvedId == "MinigunVortex")
		local isTwin = (resolvedId == "TwinLaser")
		addVoxelSym(m, Vector3.new(3.2, 0.4, 0.4), Vector3.new(1.8, 2.2, 3.6), u, priCol, armorMat, "AmmoDrum")
		addVoxelSym(m, Vector3.new(3.2, 1.7, 0.4), Vector3.new(1.2, 0.7, 2.2), u, lightCol, armorMat, "DrumTop")
		addVoxelSym(m, Vector3.new(4.4, -0.3, 1.2), Vector3.new(1.0, 1.4, 2.6), u, glowCol, Enum.Material.Neon, "CoolingVent")

		if isQuad then
			-- 4 rotary stacked voxel gatling barrels
			local offsets = { Vector2.new(-1.1, 0.9), Vector2.new(1.1, 0.9), Vector2.new(-1.1, -0.9), Vector2.new(1.1, -0.9) }
			for bIdx, off in ipairs(offsets) do
				addVoxel(m, Vector3.new(off.X, off.Y, -4.6), Vector3.new(0.85, 0.85, 5.4), u, darkCol, frameMat, "QuadBarrel_" .. bIdx)
				addVoxel(m, Vector3.new(off.X, off.Y, -7.4), Vector3.new(0.95, 0.95, 0.7), u, glowCol, Enum.Material.Neon, "QuadTip_" .. bIdx)
			end
			muzzleZ = -7.6 * u
		elseif isTwin then
			-- 2 wide rapid-laser cannon pods
			addVoxelSym(m, Vector3.new(1.6, -0.2, -4.5), Vector3.new(1.2, 1.2, 4.8), u, darkCol, frameMat, "TwinBarrel")
			addVoxelSym(m, Vector3.new(1.6, -0.2, -7.0), Vector3.new(1.3, 1.3, 0.8), u, glowCol, Enum.Material.Neon, "TwinTip")
			muzzleZ = -7.2 * u
		else
			-- RapidPulse: sleek twin stacked rapid voxel barrels
			addVoxelSym(m, Vector3.new(1.1, -0.2, -4.0), Vector3.new(0.9, 1.0, 4.2), u, darkCol, frameMat, "GatBarrel")
			addVoxelSym(m, Vector3.new(1.1, -0.2, -6.2), Vector3.new(0.95, 1.05, 0.7), u, glowCol, Enum.Material.Neon, "GatTip")
			muzzleZ = -6.4 * u
		end

	elseif resolvedId == "HeavyCannon" or resolvedId == "AnnihilatorCore" or resolvedId == "RailJuggernaut" then
		-- SLOW / HUGE-DAMAGE SIEGE CANNON VOXEL DRONE
		local isAnnihilator = (resolvedId == "AnnihilatorCore")
		local isRail = (resolvedId == "RailJuggernaut")
		-- Heavy armored pauldrons
		addVoxelSym(m, Vector3.new(3.8, 0.6, 0.3), Vector3.new(2.4, 3.8, 4.6), u, priCol, armorMat, "HeavyPauldron")
		addVoxelSym(m, Vector3.new(3.8, 2.8, 0.3), Vector3.new(1.8, 1.0, 3.6), u, darkCol, frameMat, "PauldronTrim")
		addVoxelSym(m, Vector3.new(5.2, 0.2, 1.4), Vector3.new(0.8, 2.2, 2.4), u, glowCol, Enum.Material.Neon, "ReactorCell")

		if isRail then
			-- Twin elongated rail prongs + glowing magnetic bridge coils
			addVoxelSym(m, Vector3.new(1.3, -0.1, -5.6), Vector3.new(0.9, 1.4, 7.6), u, darkCol, frameMat, "RailProng")
			for seg = 1, 3 do
				addVoxel(m, Vector3.new(0, -0.1, -3.2 - seg * 1.8), Vector3.new(2.2, 0.9, 0.65), u, glowCol, Enum.Material.Neon, "RailCoil_" .. seg)
			end
			muzzleZ = -9.5 * u
		else
			local boreW = isAnnihilator and 3.4 or 2.6
			local barrelL = isAnnihilator and 6.2 or 5.2
			addVoxel(m, Vector3.new(0, -0.2, -4.4), Vector3.new(boreW, boreW, barrelL), u, darkCol, frameMat, "SiegeBarrel")
			addVoxel(m, Vector3.new(0, -0.2, -4.4 - barrelL * 0.5 + 0.4), Vector3.new(boreW + 0.6, boreW + 0.6, 1.2), u, priCol, armorMat, "MuzzleCollar")
			addVoxel(m, Vector3.new(0, -0.2, -4.4 - barrelL * 0.5 - 0.1), Vector3.new(boreW * 0.62, boreW * 0.62, 0.5), u, glowCol, Enum.Material.Neon, "SiegeCore")
			muzzleZ = (-4.5 - barrelL * 0.5) * u
		end

	elseif resolvedId == "LongRangeScout" or resolvedId == "OrbitalSniper" or resolvedId == "HunterDrone" then
		-- LONG-RANGE SNIPER / FAR-FLYING SCOUT VOXEL DRONE
		local isSniperPlus = (resolvedId == "OrbitalSniper")
		local isHunter = (resolvedId == "HunterDrone")
		-- Stepped swept delta wings
		addVoxelSym(m, Vector3.new(3.8, 0, 1.2), Vector3.new(2.6, 0.8, 3.0), u, priCol, armorMat, "DeltaWingInner")
		addVoxelSym(m, Vector3.new(5.8, -0.2, 2.2), Vector3.new(2.2, 0.7, 2.2), u, lightCol, armorMat, "DeltaWingTip")
		addVoxelSym(m, Vector3.new(5.8, 0.4, 2.2), Vector3.new(0.8, 0.6, 1.6), u, glowCol, Enum.Material.Neon, "WingBeacon")
		-- Dorsal radar / rangefinder cube
		addVoxel(m, Vector3.new(0, 3.6, 0.4), Vector3.new(2.0, 1.4, 2.0), u, darkCol, frameMat, "Rangefinder")
		addVoxel(m, Vector3.new(0, 3.8, -0.7), Vector3.new(1.2, 0.8, 0.6), u, glowCol, Enum.Material.Neon, "ScopeLens")

		if isHunter then
			-- Dual long-range precision barrels
			addVoxelSym(m, Vector3.new(1.1, -0.2, -5.6), Vector3.new(0.8, 0.8, 7.0), u, darkCol, frameMat, "HunterBarrel")
			addVoxelSym(m, Vector3.new(1.1, -0.2, -9.2), Vector3.new(0.95, 0.95, 0.7), u, glowCol, Enum.Material.Neon, "HunterTip")
			muzzleZ = -9.4 * u
		else
			local len = isSniperPlus and 10.2 or 8.0
			addVoxel(m, Vector3.new(0, -0.2, -2.5 - len * 0.5), Vector3.new(1.1, 1.1, len), u, darkCol, frameMat, "SniperBarrel")
			addVoxel(m, Vector3.new(0, -0.2, -2.5 - len * 0.45), Vector3.new(1.7, 1.7, 1.0), u, priCol, armorMat, "FocusRingA")
			addVoxel(m, Vector3.new(0, -0.2, -2.5 - len * 0.78), Vector3.new(1.5, 1.5, 0.8), u, glowCol, Enum.Material.Neon, "FocusRingB")
			addVoxel(m, Vector3.new(0, -0.2, -2.5 - len - 0.3), Vector3.new(1.2, 1.2, 0.7), u, glowCol, Enum.Material.Neon, "SniperTip")
			muzzleZ = (-2.6 - len) * u
		end

	elseif resolvedId == "SpreadShot" or resolvedId == "PentaBlaster" or resolvedId == "OctoBarrage" then
		-- MULTI-BULLET SPREAD VOXEL DRONE
		local nozzleCount = (resolvedId == "OctoBarrage" and 7) or 5
		addVoxel(m, Vector3.new(0, -0.2, -2.6), Vector3.new(6.8, 2.2, 1.4), u, priCol, armorMat, "SpreadBow")
		addVoxelSym(m, Vector3.new(3.8, 0.4, 0.6), Vector3.new(1.8, 2.0, 2.8), u, lightCol, armorMat, "FlakPod")

		local half = (nozzleCount - 1) * 0.5
		for nIdx = 1, nozzleCount do
			local rel = nIdx - 1 - half
			local angY = math.rad(-rel * 11)
			local xPos = rel * 1.15
			local nozzlePivot = CFrame.new(Vector3.new(xPos, -0.2, -3.2) * u) * CFrame.Angles(0, angY, 0)
			createPart({
				Name = "SpreadBarrel_" .. nIdx,
				Shape = Enum.PartType.Block,
				Size = Vector3.new(0.85, 0.85, 2.6) * u,
				CFrame = nozzlePivot * CFrame.new(0, 0, -1.2 * u),
				Color = darkCol,
				Material = frameMat,
				Parent = m,
			})
			createPart({
				Name = "SpreadTip_" .. nIdx,
				Shape = Enum.PartType.Block,
				Size = Vector3.new(0.95, 0.95, 0.55) * u,
				CFrame = nozzlePivot * CFrame.new(0, 0, -2.5 * u),
				Color = glowCol,
				Material = Enum.Material.Neon,
				Parent = m,
			})
		end
		muzzleZ = -5.6 * u

	elseif resolvedId == "StickyBomber" or resolvedId == "ClusterSapper" or resolvedId == "NovaDemolisher" then
		-- STICKY BOMB SAPPER VOXEL DRONE (Hazard Stripe Body + Mortar Chute + Side Bomb Racks!)
		local isCluster = (resolvedId == "ClusterSapper")
		local isNova = (resolvedId == "NovaDemolisher")
		local hazardDark = Color3.fromRGB(28, 30, 38)
		local hazardYellow = Color3.fromRGB(255, 195, 38)
		local armedRed = Color3.fromRGB(255, 65, 55)

		-- Top Hazard Beacon & Bomb Tank
		addVoxel(m, Vector3.new(0, 3.2, 0.2), Vector3.new(2.2, 1.2, 2.6), u, hazardYellow, armorMat, "HazardDeck")
		addVoxel(m, Vector3.new(0, 4.1, 0.2), Vector3.new(1.1, 0.9, 1.1), u, armedRed, Enum.Material.Neon, "DetonatorBeacon")

		-- Side Bomb Racks carrying visible mini voxel sticky mines
		addVoxelSym(m, Vector3.new(3.5, -0.4, 0.3), Vector3.new(1.6, 2.4, 3.6), u, hazardDark, frameMat, "BombRack")
		addVoxelSym(m, Vector3.new(4.2, -0.2, -0.6), Vector3.new(1.1, 1.1, 1.1), u, armedRed, Enum.Material.Neon, "RackMineFront")
		addVoxelSym(m, Vector3.new(4.2, -0.2, 1.1), Vector3.new(1.1, 1.1, 1.1), u, hazardYellow, Enum.Material.Neon, "RackMineRear")

		if isCluster then
			-- Dual wide mortar chutes
			addVoxelSym(m, Vector3.new(1.4, -0.2, -3.9), Vector3.new(1.6, 1.8, 3.2), u, hazardDark, frameMat, "ClusterChute")
			addVoxelSym(m, Vector3.new(1.4, -0.2, -5.6), Vector3.new(1.75, 1.95, 0.65), u, hazardYellow, armorMat, "ClusterLip")
			muzzleZ = -5.8 * u
		elseif isNova then
			-- Oversized Nova Demolisher heavy mortar mouth + glowing core bay
			addVoxel(m, Vector3.new(0, 2.8, 0.2), Vector3.new(3.2, 1.8, 3.4), u, armedRed, Enum.Material.Neon, "NovaVolatileTank")
			addVoxel(m, Vector3.new(0, -0.3, -4.1), Vector3.new(3.2, 2.8, 3.6), u, hazardDark, frameMat, "NovaMortar")
			addVoxel(m, Vector3.new(0, -0.3, -6.0), Vector3.new(3.5, 3.1, 0.8), u, hazardYellow, armorMat, "NovaMortarRim")
			muzzleZ = -6.2 * u
		else
			-- Standard wide voxel mortar chute
			addVoxel(m, Vector3.new(0, -0.2, -3.8), Vector3.new(2.4, 2.2, 2.8), u, hazardDark, frameMat, "MortarChute")
			addVoxel(m, Vector3.new(0, -0.2, -5.3), Vector3.new(2.7, 2.5, 0.7), u, hazardYellow, armorMat, "MortarRim")
			muzzleZ = -5.5 * u
		end

	elseif resolvedId == "OmniverseEye" or resolvedId == "SingularityArchon" then
		-- MYTHIC ENDGAME VOXEL MONOLITH DRONES
		addVoxelSym(m, Vector3.new(4.2, 0.6, 0.4), Vector3.new(1.4, 5.2, 2.4), u, priCol, Enum.Material.Neon, "MythicWingA")
		addVoxelSym(m, Vector3.new(5.8, -0.4, 1.2), Vector3.new(1.2, 3.8, 1.8), u, darkCol, frameMat, "MythicWingB")
		addVoxel(m, Vector3.new(0, 3.8, 0), Vector3.new(2.4, 2.4, 2.4), u, glowCol, Enum.Material.Neon, "CrownCube")
		addVoxel(m, Vector3.new(0, -0.2, -4.6), Vector3.new(2.2, 2.2, 4.4), u, darkCol, frameMat, "ApexBarrel")
		addVoxel(m, Vector3.new(0, -0.2, -7.0), Vector3.new(2.5, 2.5, 0.9), u, glowCol, Enum.Material.Neon, "ApexTip")
		muzzleZ = -7.2 * u

	else
		-- BasicDrone (Starter Tier 0 Voxel Scout)
		addVoxelSym(m, Vector3.new(3.2, 0, 0.8), Vector3.new(1.6, 1.2, 2.6), u, lightCol, armorMat, "StarterWinglet")
		addVoxel(m, Vector3.new(0, -0.2, -3.7), Vector3.new(1.3, 1.3, 2.8), u, darkCol, frameMat, "BasicBarrel")
		addVoxel(m, Vector3.new(0, -0.2, -5.2), Vector3.new(1.4, 1.4, 0.6), u, glowCol, Enum.Material.Neon, "BasicTip")
		muzzleZ = -5.3 * u
	end

	-- Muzzle attachment cleanly placed at the front tip (-Z)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "BeamMuzzle"
	muzzle.Position = Vector3.new(0, -0.2 * u, muzzleZ)
	muzzle.Parent = body

	return m
end

-- ============================================================================
-- 2C. VOXEL STICKY BOMB MODEL BUILDER (Claws + Hazard Cube + Blinking Neon LED)
-- ============================================================================
function PlanetGenerator.BuildStickyBombModel(bombColor: Color3?, scale: number?): Model
	local s = scale or 1.0
	local u = 0.55 * s
	local mainCol = bombColor or Color3.fromRGB(255, 85, 45)
	local m = Instance.new("Model")
	m.Name = "VoxelStickyBomb"

	local core = addVoxel(m, Vector3.new(0, 0, 0), Vector3.new(2.8, 2.2, 2.8), u, Color3.fromRGB(28, 32, 44), Enum.Material.Slate, "BombCore")
	m.PrimaryPart = core

	-- Hazard yellow accent trim collar
	addVoxel(m, Vector3.new(0, 0.35, 0), Vector3.new(3.1, 0.65, 3.1), u, Color3.fromRGB(255, 195, 42), Enum.Material.SmoothPlastic, "HazardTrim")

	-- 4 magnetic voxel claws on the corners
	addVoxelSym(m, Vector3.new(1.4, -0.9, 1.4), Vector3.new(0.9, 1.1, 0.9), u, Color3.fromRGB(72, 82, 105), Enum.Material.Concrete, "MagnetClawF")
	addVoxelSym(m, Vector3.new(1.4, -0.9, -1.4), Vector3.new(0.9, 1.1, 0.9), u, Color3.fromRGB(72, 82, 105), Enum.Material.Concrete, "MagnetClawB")

	-- Blinking Neon Detonator LED on top
	addVoxel(m, Vector3.new(0, 1.45, 0), Vector3.new(1.3, 0.95, 1.3), u, mainCol, Enum.Material.Neon, "BombLED")

	return m
end

-- ============================================================================
-- 3. NATURAL SURFACE BIOME LANDMARKS (Matte Wood, LeafyGrass, Rock, Snow)
-- ============================================================================
local function buildContinentDetails(
	model: Instance,
	originPos: Vector3,
	normal: Vector3,
	twist: number,
	featureId: string,
	radius: number,
	landColor: Color3,
	treeColor: Color3,
	rockColor: Color3,
	rockMat: Enum.Material,
	index: number
)
	local surfCF = radialCFrame(originPos, normal, radius * 1.03, twist)

	-- Rugged Mountain Range with Snow Cap
	local mtnBaseCF = surfCF * CFrame.new(radius * 0.09, 0, radius * 0.05) * CFrame.Angles(0, math.rad(index * 37), 0)
	local mtnH = radius * 0.18
	local mtnW = radius * 0.14

	createWedge({
		Name = "MountainSlopeA_" .. index,
		Size = Vector3.new(mtnW, mtnH, mtnW * 0.78),
		CFrame = mtnBaseCF * CFrame.new(0, mtnH * 0.32, -mtnW * 0.39),
		Color = rockColor,
		Material = rockMat,
		Parent = model,
	})
	createWedge({
		Name = "MountainSlopeB_" .. index,
		Size = Vector3.new(mtnW, mtnH, mtnW * 0.78),
		CFrame = mtnBaseCF * CFrame.new(0, mtnH * 0.32, mtnW * 0.39) * CFrame.Angles(0, math.rad(180), 0),
		Color = rockColor:Lerp(Color3.fromRGB(28, 32, 40), 0.18),
		Material = rockMat,
		Parent = model,
	})
	createPart({
		Name = "MountainSnowCap_" .. index,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(mtnW * 0.58, mtnH * 0.36, mtnW * 0.58),
		CFrame = mtnBaseCF * CFrame.new(0, mtnH * 0.72, 0),
		Color = Color3.fromRGB(238, 244, 250),
		Material = Enum.Material.Snow,
		Parent = model,
	})

	local featCF = surfCF * CFrame.new(-radius * 0.08, 0, -radius * 0.05)

	if featureId == "Forests" then
		-- Natural Wood trunk + LeafyGrass / Grass canopies (zero plastic shine!)
		for t = 1, 2 do
			local tOff = (t == 1) and CFrame.new(0, 0, 0) or CFrame.new(radius * 0.07, -radius * 0.01, radius * 0.06)
			local tScale = (t == 1) and 1.0 or 0.78
			local trunkH = radius * 0.14 * tScale
			local baseCF = featCF * tOff
			createPart({
				Name = string.format("TreeTrunk_%d_%d", index, t),
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(trunkH, radius * 0.045 * tScale, radius * 0.045 * tScale),
				CFrame = baseCF * CFrame.new(0, trunkH * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(102, 66, 36),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			createPart({
				Name = string.format("TreeCanopyLow_%d_%d", index, t),
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.16 * tScale, radius * 0.11 * tScale, radius * 0.16 * tScale),
				CFrame = baseCF * CFrame.new(0, trunkH * 0.85, 0),
				Color = treeColor,
				Material = Enum.Material.LeafyGrass,
				Parent = model,
			})
			createPart({
				Name = string.format("TreeCanopyTop_%d_%d", index, t),
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.11 * tScale, radius * 0.09 * tScale, radius * 0.11 * tScale),
				CFrame = baseCF * CFrame.new(0, trunkH * 1.32, 0),
				Color = treeColor:Lerp(Color3.fromRGB(185, 225, 120), 0.22),
				Material = Enum.Material.Grass,
				Parent = model,
			})
		end
	elseif featureId == "Crystals" then
		local angles = {
			CFrame.Angles(math.rad(8), 0, math.rad(-10)),
			CFrame.Angles(math.rad(-16), math.rad(45), math.rad(22)),
			CFrame.Angles(math.rad(20), math.rad(-60), math.rad(-24)),
		}
		for cIdx, ang in ipairs(angles) do
			local h = radius * (0.21 - cIdx * 0.035)
			local w = radius * (0.055 - cIdx * 0.008)
			local shardCF = featCF * ang * CFrame.new(0, h * 0.42, 0)
			createPart({
				Name = string.format("CrystalShaft_%d_%d", index, cIdx),
				Size = Vector3.new(w, h, w),
				CFrame = shardCF,
				Color = treeColor,
				Material = (cIdx == 1) and Enum.Material.Neon or Enum.Material.Limestone,
				Parent = model,
			})
		end
	elseif featureId == "Volcanoes" then
		local vHeight = radius * 0.16
		local vDiam = radius * 0.22
		createPart({
			Name = "VolcanoBase_" .. index,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(vDiam, vHeight * 1.3, vDiam),
			CFrame = featCF * CFrame.new(0, vHeight * 0.2, 0),
			Color = Color3.fromRGB(45, 42, 48),
			Material = Enum.Material.Basalt,
			Parent = model,
		})
		createPart({
			Name = "VolcanoCraterRim_" .. index,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(vHeight * 0.65, vDiam * 0.62, vDiam * 0.62),
			CFrame = featCF * CFrame.new(0, vHeight * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rockColor,
			Material = Enum.Material.CrackedLava,
			Parent = model,
		})
		-- Molten lava vent inside crater (legitimate thermal glow)
		createPart({
			Name = "VolcanoLavaPool_" .. index,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(vHeight * 0.72, vDiam * 0.42, vDiam * 0.42),
			CFrame = featCF * CFrame.new(0, vHeight * 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 115, 20),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	elseif featureId == "Citadels" then
		createPart({
			Name = "CitadelPlaza_" .. index,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(radius * 0.04, radius * 0.20, radius * 0.20),
			CFrame = featCF * CFrame.new(0, radius * 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rockColor,
			Material = Enum.Material.Concrete,
			Parent = model,
		})
		createPart({
			Name = "CitadelMainTower_" .. index,
			Size = Vector3.new(radius * 0.065, radius * 0.24, radius * 0.065),
			CFrame = featCF * CFrame.new(0, radius * 0.11, 0),
			Color = rockColor:Lerp(Color3.fromRGB(190, 200, 215), 0.25),
			Material = Enum.Material.Slate,
			Parent = model,
		})
	elseif featureId == "CoralReefs" then
		createPart({
			Name = "CoralDome_" .. index,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(radius * 0.16, radius * 0.11, radius * 0.16),
			CFrame = featCF * CFrame.new(0, radius * 0.04, 0),
			Color = treeColor,
			Material = Enum.Material.Sandstone,
			Parent = model,
		})
		createPart({
			Name = "CoralBranch_" .. index,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(radius * 0.16, radius * 0.045, radius * 0.045),
			CFrame = featCF * CFrame.new(radius * 0.04, radius * 0.08, 0) * CFrame.Angles(0, 0, math.rad(72)),
			Color = treeColor:Lerp(Color3.fromRGB(245, 235, 210), 0.35),
			Material = Enum.Material.Limestone,
			Parent = model,
		})
	elseif featureId == "FloatingIsles" then
		local skyCF = featCF * CFrame.new(0, radius * 0.22, 0)
		createPart({
			Name = "SkyIslandTop_" .. index,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(radius * 0.045, radius * 0.19, radius * 0.19),
			CFrame = skyCF * CFrame.Angles(0, 0, math.rad(90)),
			Color = landColor,
			Material = Enum.Material.Grass,
			Parent = model,
		})
		createPart({
			Name = "SkyIslandRockBase_" .. index,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(radius * 0.15, radius * 0.11, radius * 0.15),
			CFrame = skyCF * CFrame.new(0, -radius * 0.04, 0),
			Color = rockColor,
			Material = rockMat,
			Parent = model,
		})
	end
end

-- ============================================================================
-- 4. REFINED PLANETARY FLIGHT TRAILS & SUBTLE COSMIC WAKE
-- ============================================================================
local function attachPlanetaryFlightVFX(root: BasePart, radius: number, atmoColor: Color3, ringColor: Color3)
	local leftAtt0 = Instance.new("Attachment")
	leftAtt0.Name = "TrailLeft0"
	leftAtt0.Position = Vector3.new(-radius * 0.72, radius * 0.06, 0)
	leftAtt0.Parent = root

	local leftAtt1 = Instance.new("Attachment")
	leftAtt1.Name = "TrailLeft1"
	leftAtt1.Position = Vector3.new(-radius * 0.72, -radius * 0.06, 0)
	leftAtt1.Parent = root

	local rightAtt0 = Instance.new("Attachment")
	rightAtt0.Name = "TrailRight0"
	rightAtt0.Position = Vector3.new(radius * 0.72, radius * 0.06, 0)
	rightAtt0.Parent = root

	local rightAtt1 = Instance.new("Attachment")
	rightAtt1.Name = "TrailRight1"
	rightAtt1.Position = Vector3.new(radius * 0.72, -radius * 0.06, 0)
	rightAtt1.Parent = root

	local coreAtt0 = Instance.new("Attachment")
	coreAtt0.Name = "CoreTrail0"
	coreAtt0.Position = Vector3.new(0, radius * 0.18, 0)
	coreAtt0.Parent = root

	local coreAtt1 = Instance.new("Attachment")
	coreAtt1.Name = "CoreTrail1"
	coreAtt1.Position = Vector3.new(0, -radius * 0.18, 0)
	coreAtt1.Parent = root

	local function makeTrail(name: string, a0: Attachment, a1: Attachment, c1: Color3, c2: Color3, lifetime: number): Trail
		local tr = Instance.new("Trail")
		tr.Name = name
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = lifetime
		tr.MinLength = 0.8
		tr.FaceCamera = true
		tr.LightEmission = 0.35
		tr.LightInfluence = 0.2
		tr.Color = ColorSequence.new(c1, c2)
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.45, 0.78),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		tr.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0.0),
		})
		tr.Parent = root
		return tr
	end

	makeTrail("LeftAirTrail", leftAtt0, leftAtt1, atmoColor, Color3.fromRGB(210, 225, 245), 0.65)
	makeTrail("RightAirTrail", rightAtt0, rightAtt1, atmoColor, Color3.fromRGB(210, 225, 245), 0.65)
	makeTrail("CoreWakeTrail", coreAtt0, coreAtt1, ringColor, atmoColor, 0.90)

	local wakeParticles = Instance.new("ParticleEmitter")
	wakeParticles.Name = "PlanetarySlipstreamVFX"
	wakeParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	wakeParticles.Color = ColorSequence.new(atmoColor, Color3.fromRGB(235, 242, 255))
	wakeParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.035),
		NumberSequenceKeypoint.new(0.5, radius * 0.06),
		NumberSequenceKeypoint.new(1, 0),
	})
	wakeParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	wakeParticles.Lifetime = NumberRange.new(0.35, 0.75)
	wakeParticles.Rate = 0 -- Driven dynamically by velocity in PlanetClient!
	wakeParticles.Speed = NumberRange.new(4, 12)
	wakeParticles.SpreadAngle = Vector2.new(35, 35)
	wakeParticles.LightEmission = 0.5
	wakeParticles.Parent = root
end

-- ============================================================================
-- 5. COMPLETE SEAMLESS 3D PLANET MODEL GENERATOR (Expansive Continents & Matte Materials)
-- ============================================================================
function PlanetGenerator.BuildPlanetModel(
	playerName: string,
	look: any,
	speciesId: string,
	activeEvolutionId: string,
	planetTierScale: number,
	hideBillboard: boolean?
): Model
	local model = Instance.new("Model")
	model.Name = "Planet_" .. playerName
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	local safeLook = (type(look) == "table") and look or PlanetConfig.DefaultPlanetLook
	local pType = PlanetConfig.PlanetTypes[safeLook.Biome] or PlanetConfig.PlanetTypes.Terrestrial
	local species = SpeciesConfig.Species[speciesId] or SpeciesConfig.Species.Terranauts
	local evoNode = SpeciesConfig.EvolutionNodes[activeEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening

	local defColors = pType.DefaultColors
	local waterColor = resolveColor(safeLook.WaterColor, resolveColor(defColors.WaterColor, Color3.fromRGB(22, 105, 205)))
	local landColor = resolveColor(safeLook.LandColor, resolveColor(defColors.LandColor, Color3.fromRGB(58, 168, 72)))
	local treeColor = resolveColor(safeLook.TreeColor, resolveColor(defColors.TreeColor, Color3.fromRGB(34, 138, 48)))
	local rockColor = resolveColor(safeLook.RockColor, resolveColor(defColors.RockColor, Color3.fromRGB(122, 126, 136)))
	local atmoColor = resolveColor(safeLook.AtmosphereColor, resolveColor(defColors.AtmosphereColor, Color3.fromRGB(95, 180, 240)))
	local cloudColor = resolveColor(safeLook.CloudColor, resolveColor(defColors.CloudColor, Color3.fromRGB(242, 246, 250)))
	local ringColor = resolveColor(safeLook.RingColor, resolveColor(defColors.RingColor, Color3.fromRGB(215, 185, 130)))

	local rawWaterMat = safeLook.WaterMaterial or pType.DefaultMaterials.WaterMaterial
	local waterMat = resolveMaterial(rawWaterMat, Enum.Material.Slate)
	local landMat = resolveMaterial(safeLook.LandMaterial or pType.DefaultMaterials.LandMaterial, Enum.Material.Grass)
	local rockMat = resolveMaterial(safeLook.RockMaterial or pType.DefaultMaterials.RockMaterial, Enum.Material.Rock)

	local diameter = 36 * math.clamp(planetTierScale or 1.0, 0.45, 2.6)
	local radius = diameter * 0.5
	local originPos = Vector3.zero
	local originCF = CFrame.new(originPos)

	local shapeId = safeLook.CoreShape or "RoundSphere"

	-- Resolve Land Coverage setting (how big & expansive continents are)
	local covId = safeLook.LandCoverage or "MajorContinents"
	local covScale = 1.42
	local covRatio = 0.88
	if PlanetConfig.LandCoverages then
		for _, cDef in ipairs(PlanetConfig.LandCoverages) do
			if cDef.Id == covId then
				covScale = cDef.Scale
				covRatio = cDef.ContinentRatio
				break
			end
		end
	end

	-- 1. Solid Matte Ocean / Core Sphere (`PlanetCore`)
	local root = createPart({
		Name = "PlanetCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = originCF,
		Color = waterColor,
		Material = waterMat,
		Reflectance = 0,
		Transparency = 0,
	})
	root.Parent = model
	model.PrimaryPart = root

	-- Gentle ambient light so the planet is readable in pitch-black space without making it shiny
	local planetLight = Instance.new("PointLight")
	planetLight.Color = Color3.fromRGB(235, 240, 250)
	planetLight.Brightness = 0.65
	planetLight.Range = radius * 4.5
	planetLight.Shadows = false
	planetLight.Parent = root

	if not hideBillboard then
		attachPlanetaryFlightVFX(root, radius, atmoColor, ringColor)
	end

	-- 2. Shape-Specific Sculpting
	if shapeId == "VoxelSphere" then
		for i = -3, 3 do
			local frac = i / 3.5
			local yOff = frac * radius * 0.86
			local sliceDiam = math.sqrt(math.max(0.12, 1 - frac * frac)) * diameter * 1.02
			createPart({
				Name = "VoxelLatRing_" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(diameter * 0.15, sliceDiam, sliceDiam),
				CFrame = originCF * CFrame.new(0, yOff, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = (math.abs(i) == 3) and cloudColor or waterColor:Lerp(landColor, (i % 2 == 0) and 0.25 or 0),
				Material = (math.abs(i) == 3) and Enum.Material.Snow or landMat,
				Parent = model,
			})
		end
	elseif shapeId == "BandedGasSphere" or safeLook.Biome == "GasGiant" then
		for b = -4, 4 do
			local frac = b / 4.4
			local yOff = frac * radius * 0.88
			local bandDiam = math.sqrt(math.max(0.14, 1 - frac * frac)) * diameter * 1.025
			local bandColor = (b % 2 == 0) and landColor or waterColor:Lerp(treeColor, 0.35)
			createPart({
				Name = "GasBand_" .. b,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(diameter * 0.11, bandDiam, bandDiam),
				CFrame = originCF * CFrame.new(0, yOff, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = bandColor,
				Material = Enum.Material.Sandstone,
				Parent = model,
			})
		end
		createPart({
			Name = "GreatStormEyeOuter",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.30, diameter * 0.20, diameter * 0.12),
			CFrame = originCF * CFrame.new(0, -radius * 0.16, -radius * 0.96),
			Color = treeColor,
			Material = Enum.Material.Sand,
			Parent = model,
		})
	elseif shapeId == "DysonMegosphere" then
		for r = 1, 3 do
			local angleCF = CFrame.Angles(math.rad(r * 60), math.rad(r * 45), 0)
			for seg = 1, 16 do
				local a = (seg / 16) * math.pi * 2
				local segCF = originCF * angleCF * CFrame.Angles(0, a, 0) * CFrame.new(radius * 1.03, 0, 0)
				createPart({
					Name = string.format("DysonBeam_%d_%d", r, seg),
					Size = Vector3.new(radius * 0.06, radius * 0.06, radius * 0.44),
					CFrame = segCF,
					Color = rockColor,
					Material = Enum.Material.Concrete,
					Parent = model,
				})
			end
		end
	end

	-- 3. Natural Snow / Glacial Polar Ice Caps
	for _, poleSign in ipairs({ 1, -1 }) do
		createPart({
			Name = "PolarCap_" .. poleSign,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.54, diameter * 0.22, diameter * 0.54),
			CFrame = originCF * CFrame.new(0, poleSign * radius * 0.88, 0),
			Color = cloudColor,
			Material = Enum.Material.Snow,
			Parent = model,
		})
	end

	-- 4. Expansive Multi-Tiered Continents, Peninsulas, Highlands, Flora & Cities
	local featureId = safeLook.SurfaceFeature or "Forests"
	local cityStyle = evoNode.VisualTrait.CityStyle
	local cityScale = evoNode.VisualTrait.ScaleMod or 1.0
	local cityGlow = evoNode.VisualTrait.GlowColor

	local isOceanic = (safeLook.Biome == "Oceanic") or (shapeId == "RingedArchipelago")
	local isShattered = (shapeId == "ShatteredSphere")

	for idx, pt in ipairs(FIBONACCI_POINTS) do
		local contScale = (isOceanic and 0.72 or 1.0) * covScale
		local baseDist = isShattered and (radius * 0.96) or (radius * 0.89)
		local shelfCF = radialCFrame(originPos, pt.Normal, baseDist, pt.Twist)
		local isContinent = (pt.RankRatio <= covRatio)

		if isContinent then
			-- Tier 1: Wide Coastal Beach / Continental Shelf
			createPart({
				Name = "ContinentCoast_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.68 * contScale, radius * 0.25, radius * 0.62 * contScale),
				CFrame = shelfCF,
				Color = landColor:Lerp(Color3.fromRGB(228, 205, 145), 0.35),
				Material = Enum.Material.Sand,
				Parent = model,
			})

			-- Tier 2: Expansive Mainland Continent
			local mainLandCF = radialCFrame(originPos, pt.Normal, baseDist + radius * 0.032, pt.Twist)
			createPart({
				Name = "ContinentMain_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.60 * contScale, radius * 0.26, radius * 0.54 * contScale),
				CFrame = mainLandCF,
				Color = landColor,
				Material = landMat,
				Parent = model,
			})

			-- Tier 3: Connected Peninsula Lobe A
			local lobeNormalA = (pt.Normal + mainLandCF.RightVector * 0.22 + mainLandCF.LookVector * 0.14).Unit
			local lobeCFA = radialCFrame(originPos, lobeNormalA, baseDist + radius * 0.026, pt.Twist + 0.5)
			createPart({
				Name = "ContinentLobeA_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.46 * contScale, radius * 0.24, radius * 0.40 * contScale),
				CFrame = lobeCFA,
				Color = landColor:Lerp(treeColor, 0.14),
				Material = landMat,
				Parent = model,
			})

			-- Tier 4: Connected Peninsula Lobe B + Highland Plateau
			local lobeNormalB = (pt.Normal - mainLandCF.RightVector * 0.18 - mainLandCF.LookVector * 0.16).Unit
			local lobeCFB = radialCFrame(originPos, lobeNormalB, baseDist + radius * 0.024, pt.Twist - 0.4)
			createPart({
				Name = "ContinentLobeB_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.40 * contScale, radius * 0.23, radius * 0.36 * contScale),
				CFrame = lobeCFB,
				Color = landColor:Lerp(rockColor, 0.12),
				Material = landMat,
				Parent = model,
			})

			buildContinentDetails(
				model,
				originPos,
				pt.Normal,
				pt.Twist,
				featureId,
				radius,
				landColor,
				treeColor,
				rockColor,
				rockMat,
				idx
			)

			if idx % 2 == 0 then
				local civNormal = (pt.Normal + mainLandCF.RightVector * 0.09 - mainLandCF.LookVector * 0.09).Unit
				local civBaseCF = radialCFrame(originPos, civNormal, radius * 1.03, pt.Twist)
				local bWidth = radius * 0.075 * math.sqrt(cityScale)
				local bHeight = radius * 0.15 * cityScale

				createPart({
					Name = "CivPad_" .. idx,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(radius * 0.03, bWidth * 1.6, bWidth * 1.6),
					CFrame = civBaseCF * CFrame.Angles(0, 0, math.rad(90)),
					Color = species.PrimaryColor:Lerp(Color3.fromRGB(45, 50, 62), 0.45),
					Material = Enum.Material.Concrete,
					Parent = model,
				})

				createPart({
					Name = "CivBuilding_" .. idx,
					Shape = (cityStyle == "BioDome") and Enum.PartType.Ball or Enum.PartType.Block,
					Size = Vector3.new(bWidth, bHeight, bWidth),
					CFrame = civBaseCF * CFrame.new(0, bHeight * 0.45, 0),
					Color = species.SecondaryColor,
					Material = Enum.Material.Limestone,
					Parent = model,
				})
			end
		else
			createPart({
				Name = "IslandSandbar_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.34, radius * 0.16, radius * 0.30),
				CFrame = shelfCF,
				Color = Color3.fromRGB(228, 205, 145),
				Material = Enum.Material.Sand,
				Parent = model,
			})
			createPart({
				Name = "IslandGreen_" .. idx,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.25, radius * 0.17, radius * 0.22),
				CFrame = radialCFrame(originPos, pt.Normal, baseDist + radius * 0.022, pt.Twist),
				Color = landColor,
				Material = landMat,
				Parent = model,
			})
		end
	end

	-- 5. Subtle Matte Cloud Puffs (NO shiny plastic/neon atmosphere shells!)
	local atmoData = PlanetConfig.Atmospheres[3]
	for _, a in ipairs(PlanetConfig.Atmospheres) do
		if a.Id == safeLook.Atmosphere then
			atmoData = a
			break
		end
	end

	if atmoData and atmoData.Id ~= "None" and atmoData.HasClouds then
		for c = 1, 10 do
			local cAngle = (c / 10) * math.pi * 2
			local cLat = ((c % 3) - 1) * 0.42
			local cNormal = Vector3.new(math.cos(cAngle), cLat, math.sin(cAngle)).Unit
			local cloudCF = radialCFrame(originPos, cNormal, radius * 1.14, cAngle)

			createPart({
				Name = "CloudCenter_" .. c,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.25, radius * 0.07, radius * 0.18),
				CFrame = cloudCF,
				Color = cloudColor,
				Material = Enum.Material.Snow,
				Transparency = 0.22,
				Parent = model,
			})
			createPart({
				Name = "CloudLobeA_" .. c,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.17, radius * 0.06, radius * 0.14),
				CFrame = cloudCF * CFrame.new(radius * 0.09, -radius * 0.01, 0),
				Color = cloudColor,
				Material = Enum.Material.Snow,
				Transparency = 0.25,
				Parent = model,
			})
		end
	end

	-- 6. Seamless Multi-Band Planetary Ring Systems (Natural Rock, Limestone, or Glacier)
	local ringStyle = safeLook.RingStyle or "None"
	if ringStyle ~= "None" then
		local ringCount = 36
		local ringRadius = radius * 1.68
		local ringMat = Enum.Material.Limestone

		if ringStyle == "IceRings" then
			ringMat = Enum.Material.Glacier
		elseif ringStyle == "AsteroidBelt" then
			ringMat = Enum.Material.Rock
		elseif ringStyle == "NeonHalo" then
			ringMat = Enum.Material.Neon
		end

		local segLength = (2 * math.pi * ringRadius) / ringCount * 1.08
		local ringTilt = CFrame.Angles(math.rad(15), 0, math.rad(9))
		for i = 1, ringCount do
			local angle = (i / ringCount) * math.pi * 2
			local segCF = originCF * ringTilt * CFrame.Angles(0, angle, 0) * CFrame.new(ringRadius, 0, 0)

			createPart({
				Name = "RingOuter_" .. i,
				Size = Vector3.new(radius * 0.20, radius * 0.032, segLength),
				CFrame = segCF,
				Color = ringColor,
				Material = ringMat,
				Parent = model,
			})

			if ringStyle == "SaturnBands" or ringStyle == "IceRings" then
				local innerSegCF = originCF * ringTilt * CFrame.Angles(0, angle, 0) * CFrame.new(ringRadius * 0.82, 0, 0)
				createPart({
					Name = "RingInnerBand_" .. i,
					Size = Vector3.new(radius * 0.15, radius * 0.028, segLength * 0.84),
					CFrame = innerSegCF,
					Color = ringColor:Lerp(rockColor, 0.35),
					Material = ringMat,
					Parent = model,
				})
			end
		end

		if ringStyle == "DualGyro" then
			local innerRadius = radius * 1.42
			local innerLen = (2 * math.pi * innerRadius) / 24 * 1.08
			local innerTilt = CFrame.Angles(math.rad(-28), 0, math.rad(-16))
			for i = 1, 24 do
				local angle = (i / 24) * math.pi * 2
				local segCF = originCF * innerTilt * CFrame.Angles(0, angle, 0) * CFrame.new(innerRadius, 0, 0)

				createPart({
					Name = "GyroRing_" .. i,
					Size = Vector3.new(radius * 0.12, radius * 0.032, innerLen),
					CFrame = segCF,
					Color = rockColor,
					Material = Enum.Material.Slate,
					Parent = model,
				})
			end
		end
	end

	-- 7. Round Orbiting Moons with Sculpted 3D Rock Craters
	local moonCount = 0
	for _, m in ipairs(PlanetConfig.MoonStyles) do
		if m.Id == safeLook.MoonStyle then
			moonCount = m.Count
			break
		end
	end

	for m = 1, moonCount do
		local angle = ((m - 1) / math.max(1, moonCount)) * math.pi * 2 + 0.5
		local dist = radius * (2.10 + (m % 3) * 0.24)
		local height = ((m % 2 == 0) and 1 or -1) * (radius * 0.20)
		local moonDiam = (safeLook.MoonStyle == "CrystalSwarm") and (radius * 0.26) or (radius * 0.34)
		local moonPos = Vector3.new(math.cos(angle) * dist, height, math.sin(angle) * dist)
		local moonCF = originCF * CFrame.new(moonPos)
		local mColor = (safeLook.MoonStyle == "CrystalSwarm") and treeColor or rockColor:Lerp(Color3.fromRGB(195, 200, 210), 0.4)

		createPart({
			Name = "Moon_" .. m,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(moonDiam, moonDiam, moonDiam),
			CFrame = moonCF,
			Color = mColor,
			Material = (safeLook.MoonStyle == "CrystalSwarm") and Enum.Material.Limestone or rockMat,
			Parent = model,
		})

		if safeLook.MoonStyle ~= "CrystalSwarm" then
			local craterDirs = {
				Vector3.new(0, 0.7, -0.7).Unit,
				Vector3.new(0.8, -0.3, 0.5).Unit,
				Vector3.new(-0.7, 0.4, 0.6).Unit,
			}
			for cIdx, cDir in ipairs(craterDirs) do
				local cCF = radialCFrame(moonPos, cDir, moonDiam * 0.47, cIdx)
				createPart({
					Name = string.format("MoonCrater_%d_%d", m, cIdx),
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(moonDiam * 0.32, moonDiam * 0.08, moonDiam * 0.32),
					CFrame = cCF,
					Color = mColor:Lerp(Color3.fromRGB(42, 46, 56), 0.40),
					Material = rockMat,
					Parent = model,
				})
			end
		end
	end

	-- 8. Sleek Sci-Fi Overhead Name & Civilization Status Callout
	if not hideBillboard then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlanetHUDTag"
		billboard.Adornee = root
		billboard.Size = UDim2.new(0, 210, 0, 44)
		billboard.StudsOffset = Vector3.new(0, radius * 1.48, 0)
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0
		billboard.MaxDistance = 420
		billboard.Parent = root

		local tagCard = Instance.new("Frame")
		tagCard.Size = UDim2.fromScale(1, 1)
		tagCard.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
		tagCard.BackgroundTransparency = 0.22
		tagCard.Parent = billboard
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 7)
		tc.Parent = tagCard
		local ts = Instance.new("UIStroke")
		ts.Color = cityGlow
		ts.Thickness = 1.2
		ts.Transparency = 0.35
		ts.Parent = tagCard

		local topBar = Instance.new("Frame")
		topBar.Size = UDim2.new(1, -16, 0, 2)
		topBar.Position = UDim2.new(0, 8, 0, 0)
		topBar.BackgroundColor3 = cityGlow
		topBar.BorderSizePixel = 0
		topBar.Parent = tagCard

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.new(1, -14, 0, 20)
		titleLabel.Position = UDim2.new(0, 7, 0, 4)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = string.upper(string.format("%s • %s", safeLook.PlanetName or playerName, pType.Name))
		titleLabel.TextColor3 = Color3.fromRGB(240, 246, 255)
		titleLabel.Font = Enum.Font.GothamBlack
		titleLabel.TextSize = 11
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		titleLabel.Parent = tagCard

		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Position = UDim2.new(0, 7, 0, 23)
		subLabel.Size = UDim2.new(1, -14, 0, 16)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = string.format("%s // %s", species.Name, evoNode.Name)
		subLabel.TextColor3 = cityGlow
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.TextSize = 10
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = tagCard
	end

	return model
end

return PlanetGenerator
