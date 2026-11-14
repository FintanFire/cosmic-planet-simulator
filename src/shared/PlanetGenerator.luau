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
-- 2. HIGH-DETAIL SPACE COLLECTIBLE MODELS (Distance-Tiered Materials & Icon Badge!)
-- ============================================================================
local COLLECTIBLE_ICONS: { [string]: string } = {
	Minerals = "⛏",
	Biomass = "🌿",
	Energy = "⚡",
	Tech = "🔬",
	StarGems = "💎",
	PopulationPod = "🛸",
	SupernovaChest = "🌟",
}

function PlanetGenerator.BuildSpaceCollectibleModel(
	collectibleType: string,
	pos: Vector3,
	_title: string,
	accentColor: Color3,
	zoneTier: number?
): Model
	local tier = math.clamp(zoneTier or 1, 1, 6)
	local zDef = PlanetConfig.DeepSpaceZones[tier] or PlanetConfig.DeepSpaceZones[1]
	local s = zDef.ScaleMod or 1.0
	local zoneRockMat = resolveMaterial(zDef.RockMat, Enum.Material.Rock)
	local zoneAccentMat = resolveMaterial(zDef.AccentMat, Enum.Material.Limestone)
	local zTheme = zDef.ThemeColor or accentColor

	local model = Instance.new("Model")
	model.Name = string.format("SpaceCollectible_T%d_%s", tier, collectibleType)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	local originCF = CFrame.new(pos)
	local core = createPart({
		Name = "CollectibleRoot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(16 * s, 16 * s, 16 * s),
		CFrame = originCF,
		Color = Color3.fromRGB(92, 88, 98):Lerp(zTheme, 0.22),
		Material = zoneRockMat,
		Parent = model,
	})
	model.PrimaryPart = core

	if collectibleType == "Minerals" then
		-- Zone-Tiered Ore Geode: Iron Rock (T1) -> Golden Sandstone (T2) -> Cobalt Glacier (T3) -> Molten Mythril (T4) -> Dark-Matter (T5) -> Omnium (T6)
		core.Material = zoneRockMat
		core.Color = Color3.fromRGB(96, 90, 84):Lerp(zTheme, 0.28)
		core.Size = Vector3.new(19 * s, 15 * s, 17 * s)
		for b = 1, 3 do
			local a = (b / 3) * math.pi * 2
			createPart({
				Name = "RockBoulder_" .. b,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(13 * s, 11 * s, 14 * s),
				CFrame = originCF * CFrame.new(math.cos(a) * 6 * s, -2 * s, math.sin(a) * 6 * s),
				Color = Color3.fromRGB(72, 70, 78):Lerp(zTheme, 0.18),
				Material = (tier >= 4) and Enum.Material.Basalt or Enum.Material.Slate,
				Parent = model,
			})
		end
		local spikeCount = 4 + math.min(tier, 4)
		for c = 1, spikeCount do
			local a = (c / spikeCount) * math.pi * 2
			createWedge({
				Name = "OreSpike_" .. c,
				Size = Vector3.new(4.2 * s, (12 + tier * 1.4) * s, 4.2 * s),
				CFrame = originCF * CFrame.Angles(math.rad(25), a, math.rad(-18)) * CFrame.new(0, 7 * s, 0),
				Color = accentColor:Lerp(zTheme, 0.45),
				Material = (c <= math.ceil(tier * 0.4)) and Enum.Material.Neon or zoneAccentMat,
				Parent = model,
			})
		end
	elseif collectibleType == "Biomass" then
		-- Living Botanical Asteroid upgraded by Zone Biome
		core.Material = (tier == 3) and Enum.Material.Glacier or Enum.Material.Ground
		core.Color = Color3.fromRGB(92, 68, 48):Lerp(zTheme, 0.20)
		createPart({
			Name = "MossCrust",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(17.5 * s, 13 * s, 17.5 * s),
			CFrame = originCF * CFrame.new(0, 2.5 * s, 0),
			Color = Color3.fromRGB(52, 145, 68):Lerp(zTheme, 0.30),
			Material = Enum.Material.LeafyGrass,
			Parent = model,
		})
		for m = 1, 4 do
			local a = (m / 4) * math.pi * 2
			local stemCF = originCF * CFrame.Angles(math.rad(32), a, 0) * CFrame.new(0, 9 * s, 0)
			createPart({
				Name = "TreeTrunk_" .. m,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(7 * s, 2.8 * s, 2.8 * s),
				CFrame = stemCF * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(110, 75, 45),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			createPart({
				Name = "TreeCanopy_" .. m,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(8.5 * s, 5.5 * s, 8.5 * s),
				CFrame = stemCF * CFrame.new(0, 4 * s, 0),
				Color = Color3.fromRGB(48, 168, 75):Lerp(zTheme, 0.35),
				Material = Enum.Material.Grass,
				Parent = model,
			})
		end
	elseif collectibleType == "Energy" then
		-- Radioactive / Plasma Pulsar Core surrounded by matte Basalt containment rings
		core.Material = Enum.Material.Neon
		core.Color = accentColor:Lerp(zTheme, 0.4)
		core.Size = Vector3.new(13 * s, 13 * s, 13 * s)
		local ringCount = (tier >= 4) and 3 or 2
		for r = 1, ringCount do
			local rTilt = CFrame.Angles(math.rad(r * 35), math.rad(r * 20), math.rad(r == 1 and 25 or -25))
			for seg = 1, 12 do
				local a = (seg / 12) * math.pi * 2
				createPart({
					Name = string.format("ContainmentRing_%d_%d", r, seg),
					Size = Vector3.new(2.4 * s, 2.0 * s, 7.5 * s),
					CFrame = originCF * rTilt * CFrame.Angles(0, a, 0) * CFrame.new(13 * s, 0, 0),
					Color = Color3.fromRGB(52, 56, 66),
					Material = Enum.Material.Basalt,
					Parent = model,
				})
			end
		end
	elseif collectibleType == "Tech" then
		-- Matte Precursor Satellite with Concrete/Slate Chassis & Solar Wings
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(14 * s, 10 * s, 10 * s)
		core.CFrame = originCF * CFrame.Angles(0, 0, math.rad(90))
		core.Material = Enum.Material.Concrete
		core.Color = Color3.fromRGB(145, 152, 165):Lerp(zTheme, 0.22)
		for _, side in ipairs({ -1, 1 }) do
			createPart({
				Name = "SolarWing_" .. side,
				Size = Vector3.new(22 * s, 1.0 * s, 9 * s),
				CFrame = originCF * CFrame.new(side * 16 * s, 0, 0) * CFrame.Angles(math.rad(20), 0, 0),
				Color = Color3.fromRGB(38, 58, 92):Lerp(zTheme, 0.25),
				Material = Enum.Material.Slate,
				Parent = model,
			})
			createPart({
				Name = "SolarFrame_" .. side,
				Size = Vector3.new(22.4 * s, 1.2 * s, 1.2 * s),
				CFrame = originCF * CFrame.new(side * 16 * s, 0, 0) * CFrame.Angles(math.rad(20), 0, 0),
				Color = Color3.fromRGB(95, 102, 115),
				Material = Enum.Material.DiamondPlate,
				Parent = model,
			})
		end
		createPart({
			Name = "RadioDish",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(8 * s, 3 * s, 8 * s),
			CFrame = originCF * CFrame.new(0, 8 * s, 0),
			Color = Color3.fromRGB(175, 182, 195),
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	elseif collectibleType == "StarGems" then
		-- Crystalline Star-Gem Geode Cluster (Basalt/Slate base + multi-shard Gem Spires!)
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(17 * s, 12 * s, 17 * s)
		core.Color = Color3.fromRGB(48, 52, 66)
		core.Material = Enum.Material.Basalt
		local gemCol = zTheme
		for g = 1, 6 do
			local a = (g / 6) * math.pi * 2
			local h = (14 + (g % 3) * 4) * s
			local w = (3.8 + (g % 2) * 1.2) * s
			local tilt = CFrame.Angles(math.rad(18 + (g % 3) * 8), a, math.rad(-14))
			createWedge({
				Name = "GemCrystalShaft_" .. g,
				Size = Vector3.new(w, h, w),
				CFrame = originCF * tilt * CFrame.new(0, h * 0.45, 0),
				Color = gemCol,
				Material = (g <= 2) and Enum.Material.Neon or Enum.Material.Glacier,
				Parent = model,
			})
		end
	elseif collectibleType == "PopulationPod" then
		-- Matte Spacecraft Escape Pod with Basalt Heatshield
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(18 * s, 11 * s, 11 * s)
		core.Color = Color3.fromRGB(185, 192, 205)
		core.Material = Enum.Material.Concrete
		createPart({
			Name = "PodNosecone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(11 * s, 11 * s, 11 * s),
			CFrame = originCF * CFrame.new(8 * s, 0, 0),
			Color = Color3.fromRGB(55, 62, 74),
			Material = Enum.Material.Basalt,
			Parent = model,
		})
		createPart({
			Name = "PodThruster",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.5 * s, 7.5 * s, 7.5 * s),
			CFrame = originCF * CFrame.new(-10 * s, 0, 0),
			Color = Color3.fromRGB(255, 145, 35),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	elseif collectibleType == "SupernovaChest" then
		-- Ancient Carved Sandstone & Basalt Vault with a glowing inner seam
		core.Shape = Enum.PartType.Block
		core.Size = Vector3.new(18 * s, 13 * s, 14 * s)
		core.Color = Color3.fromRGB(175, 142, 82):Lerp(zTheme, 0.35)
		core.Material = Enum.Material.Sandstone
		createPart({
			Name = "VaultLid",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(18.4 * s, 13.5 * s, 13.5 * s),
			CFrame = originCF * CFrame.new(0, 5.5 * s, 0),
			Color = Color3.fromRGB(72, 66, 78),
			Material = Enum.Material.Basalt,
			Parent = model,
		})
		createPart({
			Name = "VaultCoreSeam",
			Size = Vector3.new(18.6 * s, 1.4 * s, 14.4 * s),
			CFrame = originCF * CFrame.new(0, 2 * s, 0),
			Color = zTheme,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end

	-- Compact, non-disruptive circular Icon Badge (with subtle T1..T6 Tier Pip!)
	local bb = Instance.new("BillboardGui")
	bb.Name = "CollectibleIconGui"
	bb.Size = UDim2.new(0, 36, 0, 36)
	bb.StudsOffset = Vector3.new(0, 15 * s, 0)
	bb.MaxDistance = 260
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Adornee = core
	bb.Parent = core

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	badge.BackgroundTransparency = 0.22
	badge.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = zTheme
	stroke.Thickness = (tier >= 3) and 2.2 or 1.8
	stroke.Transparency = 0.15
	stroke.Parent = badge

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Name = "IconLabel"
	iconLbl.Size = UDim2.fromScale(0.76, 0.76)
	iconLbl.Position = UDim2.fromScale(0.12, 0.08)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = COLLECTIBLE_ICONS[collectibleType] or "★"
	iconLbl.TextColor3 = accentColor
	iconLbl.Font = Enum.Font.FredokaOne
	iconLbl.TextScaled = true
	iconLbl.Parent = badge

	if tier >= 2 then
		local tierTag = Instance.new("TextLabel")
		tierTag.Name = "TierBadge"
		tierTag.Size = UDim2.new(0, 18, 0, 11)
		tierTag.AnchorPoint = Vector2.new(0.5, 1)
		tierTag.Position = UDim2.new(0.5, 0, 1, 2)
		tierTag.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
		tierTag.BackgroundTransparency = 0.15
		tierTag.Text = "T" .. tostring(tier)
		tierTag.TextColor3 = zTheme
		tierTag.Font = Enum.Font.FredokaOne
		tierTag.TextSize = 9
		tierTag.Parent = badge
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 4)
		tc.Parent = tierTag
	end

	return model
end

-- Build a 3D Orbital Companion / Satellite Drone Model
function PlanetGenerator.BuildCompanionDroneModel(companionId: string, isGolden: boolean?): Model
	local cDef = PlanetConfig.Companions[companionId] or PlanetConfig.Companions.SputnikMiner
	local m = Instance.new("Model")
	m.Name = "CompanionDrone_" .. companionId
	local mainCol = isGolden and Color3.fromRGB(255, 215, 55) or cDef.Color

	local body = createPart({
		Name = "DroneCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.2, 4.2, 4.2),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(58, 64, 78),
		Material = isGolden and Enum.Material.Sandstone or Enum.Material.Slate,
		Parent = m,
	})
	m.PrimaryPart = body

	createPart({
		Name = "DroneEye",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 2.2, 2.2),
		CFrame = CFrame.new(0, 0, -1.8) * CFrame.Angles(0, math.rad(90), 0),
		Color = mainCol,
		Material = Enum.Material.Neon,
		Parent = m,
	})

	for _, side in ipairs({ -1, 1 }) do
		createPart({
			Name = "DroneWing_" .. side,
			Size = Vector3.new(4.5, 0.5, 2.0),
			CFrame = CFrame.new(side * 3.6, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 12)),
			Color = mainCol,
			Material = Enum.Material.Concrete,
			Parent = m,
		})
	end

	createPart({
		Name = "DroneHalo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5.8, 5.8),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = mainCol,
		Material = Enum.Material.Limestone,
		Parent = m,
	})

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

	-- 8. Overhead Name & Civilization Status Billboard
	if not hideBillboard then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlanetHUDTag"
		billboard.Adornee = root
		billboard.Size = UDim2.new(0, 280, 0, 64)
		billboard.StudsOffset = Vector3.new(0, radius * 1.45, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 900
		billboard.Parent = root

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = string.format("%s [%s]", safeLook.PlanetName or playerName, pType.Name)
		titleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
		titleLabel.TextStrokeTransparency = 0.15
		titleLabel.Font = Enum.Font.FredokaOne
		titleLabel.TextScaled = true
		titleLabel.Parent = billboard

		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Position = UDim2.new(0, 0, 0.55, 0)
		subLabel.Size = UDim2.new(1, 0, 0.45, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = string.format("%s • %s", species.Name, evoNode.Name)
		subLabel.TextColor3 = cityGlow
		subLabel.TextStrokeTransparency = 0.2
		subLabel.Font = Enum.Font.GothamBold
		subLabel.TextScaled = true
		subLabel.Parent = billboard
	end

	return model
end

return PlanetGenerator
