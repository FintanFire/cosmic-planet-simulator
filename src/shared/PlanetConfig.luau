--!strict
local RunService = game:GetService("RunService")

local PlanetConfig = {}

-- Exclusive Admin Access (Only Hani / Fintanfire & Brother / pizqwe, plus Creator / Studio Test Players)
PlanetConfig.AdminUserIds = {
	[2597018995] = true, -- Fintanfire
	[693367824] = true, -- pizqwe
}
PlanetConfig.AdminUsernames = {
	fintanfire = true,
	pizqwe = true,
}

function PlanetConfig.IsAdminPlayer(player: Player): boolean
	if not player then
		return false
	end
	if PlanetConfig.AdminUserIds[player.UserId] == true then
		return true
	end
	if type(player.Name) == "string" and PlanetConfig.AdminUsernames[string.lower(player.Name)] == true then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 and player.UserId == game.CreatorId then
		return true
	end
	if RunService:IsStudio() and player.UserId <= 0 then
		return true
	end
	return false
end

-- Clean Exponential Simulator Number Formatter (1.25K, 3.40M, 12.8B, 4.50T, 1.20Qa, 8.50Qi)
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function PlanetConfig.FormatNumber(n: number): string
	if type(n) ~= "number" or n ~= n then
		return "0"
	end
	local absN = math.abs(n)
	if absN < 1000 then
		if absN < 10 and absN ~= math.floor(absN) then
			return string.format("%.1f", n)
		end
		return tostring(math.floor(n + 0.5))
	end
	local tier = math.min(#SUFFIXES, math.floor(math.log10(absN) / 3) + 1)
	local scaled = n / math.pow(10, (tier - 1) * 3)
	if math.abs(scaled) >= 100 then
		return string.format("%.0f%s", scaled, SUFFIXES[tier])
	elseif math.abs(scaled) >= 10 then
		return string.format("%.1f%s", scaled, SUFFIXES[tier])
	else
		return string.format("%.2f%s", scaled, SUFFIXES[tier])
	end
end

function PlanetConfig.FormatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local m = math.floor(s / 60)
	local rem = s % 60
	return string.format("%02d:%02d", m, rem)
end

function PlanetConfig.GetXPForLevel(level: number): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	return math.floor(45 * math.pow(1.35, lv - 1) + 0.5)
end

export type PlanetTypeData = {
	Id: string,
	Name: string,
	Tagline: string,
	Description: string,
	Advantages: { string },
	Disadvantages: { string },
	DefaultColors: {
		WaterColor: { number },
		LandColor: { number },
		TreeColor: { number },
		RockColor: { number },
		AtmosphereColor: { number },
		CloudColor: { number },
		RingColor: { number },
	},
	DefaultMaterials: {
		WaterMaterial: string,
		LandMaterial: string,
		RockMaterial: string,
	},
	Multipliers: {
		Minerals: number,
		Biomass: number,
		Energy: number,
		Tech: number,
		PopGrowth: number,
		FlightSpeed: number,
		PlanetValue: number,
	},
}

-- 9 Distinct Planet Types
PlanetConfig.PlanetTypes = {
	Terrestrial = {
		Id = "Terrestrial",
		Name = "Terran World",
		Tagline = "Balanced Continental Biosphere",
		Description = "A classic Earth-like round planet with deep oceans, fertile continents, lush forests, and snow-capped mountain ranges.",
		Advantages = { "+25% Biomass Yield", "+20% Population Growth", "+15% All-Around Stability" },
		Disadvantages = { "-10% Raw Energy Output" },
		DefaultColors = {
			WaterColor = { 22, 118, 235 },
			LandColor = { 62, 188, 78 },
			TreeColor = { 32, 148, 52 },
			RockColor = { 132, 138, 150 },
			AtmosphereColor = { 95, 190, 255 },
			CloudColor = { 245, 250, 255 },
			RingColor = { 215, 190, 145 },
		},
		DefaultMaterials = {
			WaterMaterial = "Slate",
			LandMaterial = "Grass",
			RockMaterial = "Rock",
		},
		Multipliers = { Minerals = 1.1, Biomass = 1.25, Energy = 0.9, Tech = 1.1, PopGrowth = 1.2, FlightSpeed = 1.0, PlanetValue = 1.1 },
	},
	Oceanic = {
		Id = "Oceanic",
		Name = "Oceanic Pelagic",
		Tagline = "Global Abyssal Sea & Coral Atolls",
		Description = "A deep water world submerged beneath pelagic oceans, dotted with sandy island chains and natural coral reefs.",
		Advantages = { "+45% Biomass Yield", "+30% Hydro-Thermal Energy", "+25% Population Growth" },
		Disadvantages = { "-30% Deep-Crust Minerals", "-10% Flight Acceleration" },
		DefaultColors = {
			WaterColor = { 18, 105, 195 },
			LandColor = { 232, 205, 130 },
			TreeColor = { 42, 185, 135 },
			RockColor = { 92, 112, 132 },
			AtmosphereColor = { 75, 195, 240 },
			CloudColor = { 230, 242, 250 },
			RingColor = { 125, 195, 225 },
		},
		DefaultMaterials = {
			WaterMaterial = "Slate",
			LandMaterial = "Sand",
			RockMaterial = "Limestone",
		},
		Multipliers = { Minerals = 0.7, Biomass = 1.45, Energy = 1.3, Tech = 1.05, PopGrowth = 1.25, FlightSpeed = 0.9, PlanetValue = 1.15 },
	},
	GasGiant = {
		Id = "GasGiant",
		Name = "Jovian Gas Giant",
		Tagline = "Hyper-Velocity Storm Bands & Cyclone Eye",
		Description = "A colossal swirling gas planet wrapped in matte cloud belts, atmospheric jet-streams, and floating sky-plateaus.",
		Advantages = { "+65% Atmospheric Energy", "+35% Flight Speed", "+25% Planet Value" },
		Disadvantages = { "-35% Solid Minerals", "-25% Surface Biomass" },
		DefaultColors = {
			WaterColor = { 205, 120, 62 },
			LandColor = { 228, 172, 102 },
			TreeColor = { 240, 205, 125 },
			RockColor = { 165, 92, 55 },
			AtmosphereColor = { 235, 160, 85 },
			CloudColor = { 245, 225, 185 },
			RingColor = { 215, 175, 115 },
		},
		DefaultMaterials = {
			WaterMaterial = "Sand",
			LandMaterial = "Sandstone",
			RockMaterial = "Basalt",
		},
		Multipliers = { Minerals = 0.65, Biomass = 0.75, Energy = 1.65, Tech = 1.2, PopGrowth = 0.95, FlightSpeed = 1.35, PlanetValue = 1.25 },
	},
	Volcanic = {
		Id = "Volcanic",
		Name = "Magma Tectonic",
		Tagline = "Molten Mantle & Basalt Crust",
		Description = "A primordial tectonic world where glowing lava fissures carve through dark matte basalt continents and volcanic calderas.",
		Advantages = { "+55% Core Minerals", "+40% Geothermal Energy" },
		Disadvantages = { "-35% Biomass (Extreme Heat)", "-20% Population Growth" },
		DefaultColors = {
			WaterColor = { 235, 75, 15 },
			LandColor = { 48, 44, 52 },
			TreeColor = { 245, 135, 20 },
			RockColor = { 68, 60, 66 },
			AtmosphereColor = { 225, 95, 35 },
			CloudColor = { 110, 98, 102 },
			RingColor = { 165, 95, 55 },
		},
		DefaultMaterials = {
			WaterMaterial = "CrackedLava",
			LandMaterial = "Basalt",
			RockMaterial = "Rock",
		},
		Multipliers = { Minerals = 1.55, Biomass = 0.65, Energy = 1.4, Tech = 0.95, PopGrowth = 0.8, FlightSpeed = 1.05, PlanetValue = 1.2 },
	},
	CryoGlacial = {
		Id = "CryoGlacial",
		Name = "Cryo-Glacial World",
		Tagline = "Sub-Zero Alpine Snow & Glacial Ridges",
		Description = "A frozen sphere of deep snowfields, matte glacial shelves, and rugged frost-covered mountain ranges.",
		Advantages = { "+50% Quantum Tech", "+30% Superconductor Energy", "+20% Core Density" },
		Disadvantages = { "-25% Biomass", "-15% Flight Speed" },
		DefaultColors = {
			WaterColor = { 68, 155, 215 },
			LandColor = { 225, 240, 250 },
			TreeColor = { 115, 195, 225 },
			RockColor = { 135, 165, 195 },
			AtmosphereColor = { 125, 210, 245 },
			CloudColor = { 240, 248, 255 },
			RingColor = { 165, 215, 240 },
		},
		DefaultMaterials = {
			WaterMaterial = "Glacier",
			LandMaterial = "Snow",
			RockMaterial = "Slate",
		},
		Multipliers = { Minerals = 1.2, Biomass = 0.75, Energy = 1.3, Tech = 1.5, PopGrowth = 0.9, FlightSpeed = 0.85, PlanetValue = 1.2 },
	},
	Crystalline = {
		Id = "Crystalline",
		Name = "Aether Geode",
		Tagline = "Limestone Continents & Quartz Spires",
		Description = "A mineral-rich planet whose stone continents are crowned with natural amethyst, emerald, and quartz crystal formations.",
		Advantages = { "+45% Minerals", "+45% Energy", "+35% Planet Value Score" },
		Disadvantages = { "-30% Biomass", "-20% Population Growth" },
		DefaultColors = {
			WaterColor = { 85, 52, 145 },
			LandColor = { 165, 115, 195 },
			TreeColor = { 65, 225, 195 },
			RockColor = { 125, 85, 155 },
			AtmosphereColor = { 175, 110, 235 },
			CloudColor = { 225, 205, 240 },
			RingColor = { 145, 195, 215 },
		},
		DefaultMaterials = {
			WaterMaterial = "Slate",
			LandMaterial = "Limestone",
			RockMaterial = "Rock",
		},
		Multipliers = { Minerals = 1.45, Biomass = 0.7, Energy = 1.45, Tech = 1.15, PopGrowth = 0.8, FlightSpeed = 1.0, PlanetValue = 1.35 },
	},
	Bioluminescent = {
		Id = "Bioluminescent",
		Name = "Mycelial Gaia",
		Tagline = "Mossy Continents & Giant Fungal Groves",
		Description = "An ancient botanical planet covered in thick mossy continents, giant fungal groves, and deep twilight seas.",
		Advantages = { "+70% Biomass", "+45% Population Growth" },
		Disadvantages = { "-25% Heavy Minerals", "-20% Tech Output" },
		DefaultColors = {
			WaterColor = { 42, 55, 98 },
			LandColor = { 38, 165, 115 },
			TreeColor = { 215, 85, 165 },
			RockColor = { 82, 75, 115 },
			AtmosphereColor = { 65, 215, 155 },
			CloudColor = { 205, 240, 225 },
			RingColor = { 175, 115, 185 },
		},
		DefaultMaterials = {
			WaterMaterial = "Ground",
			LandMaterial = "LeafyGrass",
			RockMaterial = "Slate",
		},
		Multipliers = { Minerals = 0.75, Biomass = 1.7, Energy = 1.05, Tech = 0.8, PopGrowth = 1.45, FlightSpeed = 0.95, PlanetValue = 1.15 },
	},
	CyberForge = {
		Id = "CyberForge",
		Name = "Cyber-Forge World",
		Tagline = "Matte Industrial Concrete & Alloy Crust",
		Description = "A mechanized fortress world built from heavy concrete sectors, industrial basalt plates, and command citadels.",
		Advantages = { "+65% Tech Output", "+35% Minerals", "+20% Planet Value" },
		Disadvantages = { "-45% Organic Biomass", "-15% Population Growth" },
		DefaultColors = {
			WaterColor = { 32, 65, 82 },
			LandColor = { 62, 70, 84 },
			TreeColor = { 65, 195, 235 },
			RockColor = { 88, 96, 112 },
			AtmosphereColor = { 75, 195, 235 },
			CloudColor = { 185, 215, 230 },
			RingColor = { 125, 165, 185 },
		},
		DefaultMaterials = {
			WaterMaterial = "Concrete",
			LandMaterial = "Slate",
			RockMaterial = "DiamondPlate",
		},
		Multipliers = { Minerals = 1.35, Biomass = 0.55, Energy = 1.2, Tech = 1.65, PopGrowth = 0.85, FlightSpeed = 1.1, PlanetValue = 1.2 },
	},
	VoidSingularity = {
		Id = "VoidSingularity",
		Name = "Abyssal Singularity",
		Tagline = "Dark Basalt Crust & Radioactive Rifts",
		Description = "An exotic deep-space world formed from dark volcanic basalt continents, ancient stone monoliths, and radioactive rifts.",
		Advantages = { "+55% Zero-Point Energy", "+50% Arcane Tech", "+30% Flight Speed" },
		Disadvantages = { "-35% Biomass", "-25% Minerals" },
		DefaultColors = {
			WaterColor = { 32, 22, 54 },
			LandColor = { 72, 42, 115 },
			TreeColor = { 175, 85, 245 },
			RockColor = { 54, 38, 82 },
			AtmosphereColor = { 155, 75, 235 },
			CloudColor = { 195, 165, 225 },
			RingColor = { 145, 95, 195 },
		},
		DefaultMaterials = {
			WaterMaterial = "Basalt",
			LandMaterial = "Slate",
			RockMaterial = "Rock",
		},
		Multipliers = { Minerals = 0.75, Biomass = 0.65, Energy = 1.55, Tech = 1.5, PopGrowth = 0.85, FlightSpeed = 1.3, PlanetValue = 1.3 },
	},
}

PlanetConfig.PlanetTypeOrder = {
	"Terrestrial",
	"Oceanic",
	"GasGiant",
	"Volcanic",
	"CryoGlacial",
	"Crystalline",
	"Bioluminescent",
	"CyberForge",
	"VoidSingularity",
}

PlanetConfig.Biomes = PlanetConfig.PlanetTypes

-- 6 Round & Sculpted Planetary Geometries
PlanetConfig.CoreShapes = {
	{ Id = "RoundSphere", Name = "Round Planet Globe", Description = "Seamless spherical globe with contoured continents, oceans, polar caps, and clouds." },
	{ Id = "VoxelSphere", Name = "Lego Studded Globe", Description = "Multi-tiered rounded Lego sphere built from stacked studded latitude rings." },
	{ Id = "BandedGasSphere", Name = "Swirling Gas Giant", Description = "Banded spherical gas giant with equatorial jet-streams and a Great Storm Eye." },
	{ Id = "RingedArchipelago", Name = "Island Atoll Globe", Description = "Round ocean globe wrapped in multi-tiered island archipelagos, sandbars, and reefs." },
	{ Id = "ShatteredSphere", Name = "Tectonic Core Globe", Description = "Glowing inner mantle core surrounded by elevated tectonic continental plates." },
	{ Id = "DysonMegosphere", Name = "Dyson Geodesic Globe", Description = "Round planet encased in an interlocking geometric planetary energy lattice." },
}

-- 6 Surface Detail & Flora Styles
PlanetConfig.SurfaceFeatures = {
	{ Id = "Forests", Name = "Lush Forests & Peaks", Description = "Multi-part trees, canopies, and snow-capped mountains across all continents (+15% Biomass)." },
	{ Id = "Crystals", Name = "Quartz Crystal Clusters", Description = "Glowing multi-shard crystal formations & mineral geodes (+15% Energy)." },
	{ Id = "Volcanoes", Name = "Active Magma Calderas", Description = "Volcanic cones with glowing lava craters & basalt ridges (+15% Minerals)." },
	{ Id = "Citadels", Name = "Sky-Spire Megacities", Description = "High-tech civilization skyscrapers, biodomes, and orbital antennas (+15% Tech)." },
	{ Id = "CoralReefs", Name = "Bioluminescent Reefs", Description = "Vibrant coral arches, anemone rings, and thermal sea vents (+10% Bio & Energy)." },
	{ Id = "FloatingIsles", Name = "Sky-Continents", Description = "Levitating landmasses with energy waterfalls & sky-trees (+10% All Yields)." },
}

-- 4 Customizable Continent & Landmass Coverage Sizes
PlanetConfig.LandCoverages = {
	{ Id = "Islands", Name = "Archipelago Islands", Scale = 0.82, ContinentRatio = 0.55 },
	{ Id = "Balanced", Name = "Standard Continents", Scale = 1.15, ContinentRatio = 0.75 },
	{ Id = "MajorContinents", Name = "Massive Continents", Scale = 1.42, ContinentRatio = 0.88 },
	{ Id = "Pangaea", Name = "Giant Supercontinent", Scale = 1.68, ContinentRatio = 1.00 },
}

-- 15 Realistic Surface & Core Textures (Materials)
PlanetConfig.CustomizableMaterials = {
	{ Id = "Grass", Name = "Natural Lush Grass", EnumMat = Enum.Material.Grass },
	{ Id = "LeafyGrass", Name = "Wild Forest Moss", EnumMat = Enum.Material.LeafyGrass },
	{ Id = "Ground", Name = "Rich Earth & Soil", EnumMat = Enum.Material.Ground },
	{ Id = "Sand", Name = "Coastal Desert Sand", EnumMat = Enum.Material.Sand },
	{ Id = "Rock", Name = "Rugged Mountain Rock", EnumMat = Enum.Material.Rock },
	{ Id = "Slate", Name = "Tectonic Slate Stone", EnumMat = Enum.Material.Slate },
	{ Id = "Basalt", Name = "Volcanic Basalt Rock", EnumMat = Enum.Material.Basalt },
	{ Id = "Limestone", Name = "Ancient Limestone", EnumMat = Enum.Material.Limestone },
	{ Id = "Sandstone", Name = "Canyon Sandstone", EnumMat = Enum.Material.Sandstone },
	{ Id = "Snow", Name = "Alpine Snowpack", EnumMat = Enum.Material.Snow },
	{ Id = "Glacier", Name = "Packed Glacial Ice", EnumMat = Enum.Material.Glacier },
	{ Id = "Mud", Name = "Wetland Mudflats", EnumMat = Enum.Material.Mud },
	{ Id = "CrackedLava", Name = "Molten Magma Crust", EnumMat = Enum.Material.CrackedLava },
	{ Id = "Concrete", Name = "Matte Fortress Concrete", EnumMat = Enum.Material.Concrete },
	{ Id = "Neon", Name = "Radioactive Glow (Neon)", EnumMat = Enum.Material.Neon },
}

-- 6 Orbital Ring Systems
PlanetConfig.RingStyles = {
	{ Id = "None", Name = "No Rings" },
	{ Id = "AsteroidBelt", Name = "Dense Asteroid Belt" },
	{ Id = "SaturnBands", Name = "Grand Saturn Rings" },
	{ Id = "IceRings", Name = "Glacial Diamond Rings" },
	{ Id = "NeonHalo", Name = "Plasma Energy Halo" },
	{ Id = "DualGyro", Name = "Dual Gyroscopic Rings" },
}

-- 6 Orbiting Moon Systems
PlanetConfig.MoonStyles = {
	{ Id = "None", Name = "No Moons", Count = 0 },
	{ Id = "SingleLunar", Name = "1 Cratered Moon", Count = 1 },
	{ Id = "TwinMoons", Name = "2 Binary Moons", Count = 2 },
	{ Id = "Triad", Name = "3 Triad Moons", Count = 3 },
	{ Id = "CrystalSwarm", Name = "4 Crystal Satellites", Count = 4 },
	{ Id = "MiniSolarSystem", Name = "6 Mini-Moon System", Count = 6 },
}

-- 6 Atmosphere Styles & Densities
PlanetConfig.Atmospheres = {
	{ Id = "None", Name = "Vacuum (No Atmosphere)", Transparency = 1.0, HasClouds = false },
	{ Id = "Thin", Name = "Thin Exosphere", Transparency = 0.90, HasClouds = true },
	{ Id = "Breathable", Name = "Earth-Like Sky & Clouds", Transparency = 0.85, HasClouds = true },
	{ Id = "DenseNebula", Name = "Dense Nebula Shroud", Transparency = 0.78, HasClouds = true },
	{ Id = "Stormy", Name = "Charged Storm Corona", Transparency = 0.82, HasClouds = true },
	{ Id = "ForceShield", Name = "Planetary Energy Shield", Transparency = 0.75, HasClouds = true },
}

-- 5 Axial Rotation Speeds
PlanetConfig.RotationSpeeds = {
	{ Id = "Slow", Name = "Slow Majestic Drift", Speed = 0.18 },
	{ Id = "Normal", Name = "Standard Day/Night Spin", Speed = 0.42 },
	{ Id = "Fast", Name = "Rapid Planetary Spin", Speed = 0.85 },
	{ Id = "Hyper", Name = "Hyper-Pulsar Spin", Speed = 1.55 },
	{ Id = "Reverse", Name = "Retrograde Orbit Spin", Speed = -0.50 },
}

-- 24 Rich Color Swatches
PlanetConfig.ColorPalette = {
	{ Name = "Ocean Blue", RGB = { 22, 118, 235 } },
	{ Name = "Tropical Cyan", RGB = { 0, 215, 255 } },
	{ Name = "Abyssal Navy", RGB = { 24, 48, 125 } },
	{ Name = "Emerald Gaia", RGB = { 55, 195, 85 } },
	{ Name = "Forest Pine", RGB = { 28, 135, 55 } },
	{ Name = "Lime Bio-Glow", RGB = { 115, 255, 75 } },
	{ Name = "Teal Spore", RGB = { 0, 225, 165 } },
	{ Name = "Golden Sand", RGB = { 245, 200, 95 } },
	{ Name = "Solar Amber", RGB = { 255, 150, 35 } },
	{ Name = "Magma Orange", RGB = { 255, 75, 15 } },
	{ Name = "Crimson Core", RGB = { 235, 35, 55 } },
	{ Name = "Rose Nebula", RGB = { 255, 85, 195 } },
	{ Name = "Amethyst Geode", RGB = { 185, 75, 255 } },
	{ Name = "Void Violet", RGB = { 105, 35, 195 } },
	{ Name = "Glacial White", RGB = { 240, 248, 255 } },
	{ Name = "Frost Ice", RGB = { 155, 225, 255 } },
	{ Name = "Mountain Slate", RGB = { 125, 132, 148 } },
	{ Name = "Obsidian Dark", RGB = { 42, 40, 54 } },
	{ Name = "Red Mars", RGB = { 195, 78, 52 } },
	{ Name = "Canyon Terracotta", RGB = { 215, 120, 75 } },
	{ Name = "Sakura Blossom", RGB = { 255, 155, 210 } },
	{ Name = "Starlight Gold", RGB = { 255, 235, 115 } },
	{ Name = "Titanium Silver", RGB = { 195, 205, 220 } },
	{ Name = "Deep Indigo", RGB = { 38, 28, 82 } },
}

-- ============================================================================
-- RESOURCE & MATERIAL DEFINITIONS + DISTANCE-TIERED DEEP SPACE ZONES
-- ============================================================================
PlanetConfig.ResourceMeta = {
	Minerals = {
		Id = "Minerals",
		Name = "Titanium Ore",
		ShortName = "ORE",
		Symbol = "◆",
		Color = Color3.fromRGB(255, 165, 65),
	},
	Energy = {
		Id = "Energy",
		Name = "Plasma Flux",
		ShortName = "FLUX",
		Symbol = "⚡",
		Color = Color3.fromRGB(75, 215, 255),
	},
	Biomass = {
		Id = "Biomass",
		Name = "Bio-Spores",
		ShortName = "BIO",
		Symbol = "❖",
		Color = Color3.fromRGB(85, 235, 135),
	},
	Tech = {
		Id = "Tech",
		Name = "Quantum Alloy",
		ShortName = "TECH",
		Symbol = "⬢",
		Color = Color3.fromRGB(195, 115, 255),
	},
	Gems = {
		Id = "Gems",
		Name = "Star Gems",
		ShortName = "GEMS",
		Symbol = "💎",
		Color = Color3.fromRGB(56, 225, 255),
	},
}

-- Mineral element asteroid archetypes ordered by value: more valuable elements give more XP, Minerals & Gems!
PlanetConfig.MineralOrder = { "Aluminum", "Iron", "Copper", "Silver", "Gold", "Platinum", "Titanium", "Diamond" }

PlanetConfig.MaterialNodes = {
	Aluminum = {
		Type = "Aluminum",
		Label = "Aluminum Asteroid",
		BaseTitle = "Aluminum Asteroid",
		ShortTag = "ALUMINUM",
		Symbol = "Al",
		HPMult = 0.85,
		DrillReqMult = 1.0,
		ValueMult = 0.85,
		BaseXP = 15,
		GemChance = 0.50,
		GemMult = 0.60,
		Color = Color3.fromRGB(190, 202, 218),
		RockMaterial = "Slate",
		VeinMaterial = "Concrete",
	},
	Iron = {
		Type = "Iron",
		Label = "Iron Asteroid",
		BaseTitle = "Iron Asteroid",
		ShortTag = "IRON",
		Symbol = "Fe",
		HPMult = 1.00,
		DrillReqMult = 1.0,
		ValueMult = 1.00,
		BaseXP = 25,
		GemChance = 0.60,
		GemMult = 0.80,
		Color = Color3.fromRGB(185, 118, 82),
		RockMaterial = "Rock",
		VeinMaterial = "Slate",
	},
	Copper = {
		Type = "Copper",
		Label = "Copper Asteroid",
		BaseTitle = "Copper Asteroid",
		ShortTag = "COPPER",
		Symbol = "Cu",
		HPMult = 1.35,
		DrillReqMult = 1.0,
		ValueMult = 1.40,
		BaseXP = 45,
		GemChance = 0.70,
		GemMult = 1.00,
		Color = Color3.fromRGB(232, 132, 68),
		RockMaterial = "Sandstone",
		VeinMaterial = "Limestone",
	},
	Silver = {
		Type = "Silver",
		Label = "Silver Asteroid",
		BaseTitle = "Silver Asteroid",
		ShortTag = "SILVER",
		Symbol = "Ag",
		HPMult = 1.85,
		DrillReqMult = 1.10,
		ValueMult = 2.00,
		BaseXP = 80,
		GemChance = 0.80,
		GemMult = 1.40,
		Color = Color3.fromRGB(220, 234, 250),
		RockMaterial = "Slate",
		VeinMaterial = "Glacier",
	},
	Gold = {
		Type = "Gold",
		Label = "Gold Asteroid",
		BaseTitle = "Gold Asteroid",
		ShortTag = "GOLD",
		Symbol = "Au",
		HPMult = 2.60,
		DrillReqMult = 1.25,
		ValueMult = 3.20,
		BaseXP = 150,
		GemChance = 1.00,
		GemMult = 2.20,
		Color = Color3.fromRGB(255, 205, 45),
		RockMaterial = "Sandstone",
		VeinMaterial = "Neon",
	},
	Platinum = {
		Type = "Platinum",
		Label = "Platinum Asteroid",
		BaseTitle = "Platinum Asteroid",
		ShortTag = "PLATINUM",
		Symbol = "Pt",
		HPMult = 3.80,
		DrillReqMult = 1.40,
		ValueMult = 5.00,
		BaseXP = 300,
		GemChance = 1.00,
		GemMult = 3.50,
		Color = Color3.fromRGB(115, 235, 255),
		RockMaterial = "Slate",
		VeinMaterial = "Neon",
	},
	Titanium = {
		Type = "Titanium",
		Label = "Titanium Asteroid",
		BaseTitle = "Titanium Asteroid",
		ShortTag = "TITANIUM",
		Symbol = "Ti",
		HPMult = 5.50,
		DrillReqMult = 1.60,
		ValueMult = 8.00,
		BaseXP = 600,
		GemChance = 1.00,
		GemMult = 5.50,
		Color = Color3.fromRGB(190, 115, 255),
		RockMaterial = "Basalt",
		VeinMaterial = "Neon",
	},
	Diamond = {
		Type = "Diamond",
		Label = "Diamond Asteroid",
		BaseTitle = "Diamond Asteroid",
		ShortTag = "DIAMOND",
		Symbol = "◆",
		HPMult = 8.00,
		DrillReqMult = 1.90,
		ValueMult = 14.00,
		BaseXP = 1250,
		GemChance = 1.00,
		GemMult = 10.00,
		Color = Color3.fromRGB(85, 255, 225),
		RockMaterial = "Basalt",
		VeinMaterial = "Glacier",
	},
}
PlanetConfig.MaterialNodes.Minerals = PlanetConfig.MaterialNodes.Iron

PlanetConfig.DeepSpaceZones = {
	{
		Tier = 1,
		Id = "InnerOrbit",
		Name = "Zone 1: Sanctuary Orbit",
		MinDist = 0,
		MaxDist = 1400,
		BaseHP = 35,
		ReqDrill = 1,
		YieldMultiplier = 1.0,
		BaseResourceYield = 14,
		BaseNodeValue = 18,
		GemRange = { 2, 5 },
		ScaleMod = 1.0,
		ThemeColor = Color3.fromRGB(85, 215, 255),
		RockMat = "Rock",
		AccentMat = "Limestone",
		EnemyName = "Scrap Pirate Drone",
		NodeNames = {
			Minerals = "Iron-Titanium Asteroid",
			Biomass = "Verdant Spore Boulder",
			Energy = "Solar Quartz Capacitor",
			Tech = "Orbital Probe Wreckage",
			StarGems = "Quartz Star-Gem Cluster",
			PopulationPod = "Colonial Lifeboat Pod",
			SupernovaChest = "Orbital Supply Vault",
		},
	},
	{
		Tier = 2,
		Id = "GoldenBelt",
		Name = "Zone 2: Golden Asteroid Belt",
		MinDist = 1400,
		MaxDist = 3500,
		BaseHP = 260,
		ReqDrill = 8,
		YieldMultiplier = 3.8,
		BaseResourceYield = 52,
		BaseNodeValue = 75,
		GemRange = { 6, 14 },
		ScaleMod = 1.18,
		ThemeColor = Color3.fromRGB(255, 195, 55),
		RockMat = "Sandstone",
		AccentMat = "Limestone",
		EnemyName = "Corsair Raider Frigate",
		NodeNames = {
			Minerals = "Auric Titanium Lode",
			Biomass = "Amber Mycelium Asteroid",
			Energy = "Helios Plasma Core",
			Tech = "Gilded Relay Satellite",
			StarGems = "Topaz Star-Gem Vein",
			PopulationPod = "Pioneer Stasis Ark",
			SupernovaChest = "Gilded Asteroid Vault",
		},
	},
	{
		Tier = 3,
		Id = "CryoNebula",
		Name = "Zone 3: Cryo-Nebula Expanse",
		MinDist = 3500,
		MaxDist = 6500,
		BaseHP = 1850,
		ReqDrill = 28,
		YieldMultiplier = 15.0,
		BaseResourceYield = 210,
		BaseNodeValue = 320,
		GemRange = { 16, 34 },
		ScaleMod = 1.35,
		ThemeColor = Color3.fromRGB(85, 245, 225),
		RockMat = "Glacier",
		AccentMat = "Snow",
		EnemyName = "Cryo-Wraith Interceptor",
		NodeNames = {
			Minerals = "Permafrost Cobalt Asteroid",
			Biomass = "Cryo-Flora Glacier",
			Energy = "Sub-Zero Superconductor",
			Tech = "Cryo-Research Derelict",
			StarGems = "Sapphire Ice-Gem Cluster",
			PopulationPod = "Cryo-Fleet Sleeper Ark",
			SupernovaChest = "Glacial Relic Treasury",
		},
	},
	{
		Tier = 4,
		Id = "PulsarForge",
		Name = "Zone 4: Hyper-Pulsar Starforge",
		MinDist = 6500,
		MaxDist = 10500,
		BaseHP = 14000,
		ReqDrill = 95,
		YieldMultiplier = 65.0,
		BaseResourceYield = 920,
		BaseNodeValue = 1450,
		GemRange = { 42, 88 },
		ScaleMod = 1.52,
		ThemeColor = Color3.fromRGB(255, 105, 65),
		RockMat = "Basalt",
		AccentMat = "CrackedLava",
		EnemyName = "Pulsar Dreadnought",
		NodeNames = {
			Minerals = "Molten Mythril Monolith",
			Biomass = "Thermophilic Magma-Spore",
			Energy = "Magnetar Fusion Geode",
			Tech = "Starforge Automaton Core",
			StarGems = "Ruby Starfire Gem Geode",
			PopulationPod = "Vanguard Star-Cruiser Pod",
			SupernovaChest = "Starforge Magma Strongbox",
		},
	},
	{
		Tier = 5,
		Id = "DarkMatterRift",
		Name = "Zone 5: Dark-Matter Rift",
		MinDist = 10500,
		MaxDist = 15500,
		BaseHP = 95000,
		ReqDrill = 320,
		YieldMultiplier = 300.0,
		BaseResourceYield = 4200,
		BaseNodeValue = 7200,
		GemRange = { 115, 240 },
		ScaleMod = 1.70,
		ThemeColor = Color3.fromRGB(195, 95, 255),
		RockMat = "Slate",
		AccentMat = "Basalt",
		EnemyName = "Abyssal Void Goliath",
		NodeNames = {
			Minerals = "Dark-Matter Obsidian Core",
			Biomass = "Abyssal Leviathan Spore",
			Energy = "Zero-Point RiftSingularity",
			Tech = "Precursor Quantum Monolith",
			StarGems = "Amethyst Void-Gem Motherlode",
			PopulationPod = "Astral Ascendant Citadel-Pod",
			SupernovaChest = "Dark-Matter Relic Vault",
		},
	},
	{
		Tier = 6,
		Id = "OmniverseFrontier",
		Name = "Zone 6: Omniverse Horizon",
		MinDist = 15500,
		MaxDist = 999999,
		BaseHP = 650000,
		ReqDrill = 1100,
		YieldMultiplier = 1500.0,
		BaseResourceYield = 22000,
		BaseNodeValue = 40000,
		GemRange = { 320, 680 },
		ScaleMod = 1.90,
		ThemeColor = Color3.fromRGB(255, 235, 95),
		RockMat = "Limestone",
		AccentMat = "Glacier",
		EnemyName = "Omniverse Seraph Boss",
		NodeNames = {
			Minerals = "Omnium Celestite Lode",
			Biomass = "World-Tree Genesis Seed",
			Energy = "Hypernova Dyson Core",
			Tech = "Omniverse Chronos Matrix",
			StarGems = "Astral Diamond Motherlode",
			PopulationPod = "Immortal Titan Ark-Ship",
			SupernovaChest = "Omniverse Supernova Chest",
		},
	},
}

function PlanetConfig.GetZoneForDistance(dist: number)
	for i = #PlanetConfig.DeepSpaceZones, 1, -1 do
		local z = PlanetConfig.DeepSpaceZones[i]
		if dist >= z.MinDist then
			return z
		end
	end
	return PlanetConfig.DeepSpaceZones[1]
end

-- ============================================================================
-- SCATTERED DEEP-SPACE OUTPOST STATIONS WITH GEM-UNLOCKABLE WARP GATES!
-- ============================================================================
PlanetConfig.SpaceStations = {
	{
		Id = "Hub",
		StationNumber = 0,
		Name = "★ Galactic Nexus Hub (Main Sanctuary)",
		ShortName = "Galactic Hub",
		ZoneTier = 1,
		Position = Vector3.new(0, 48, 215),
		DockRadius = 560,
		GemCost = 0,
		ReqDrill = 0,
		UnlockedByDefault = true,
		RewardMultiplier = 1.0,
		PassiveBuffDesc = "+25% Base Sanctuary Yield & Starfarer Warp Gate",
		StationUnlockPerk = "Starter Home Sanctuary",
		Color = Color3.fromRGB(0, 235, 255),
	},
	{
		Id = "Station_Belt",
		StationNumber = 1,
		Name = "🛰️ Station 1: Golden Belt Outpost",
		ShortName = "Belt Outpost",
		ZoneTier = 2,
		Position = Vector3.new(0, 65, -1850),
		DockRadius = 195,
		GemCost = 100,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 3.8,
		PassiveBuffDesc = "Zone 2 Outpost • 3.8x Node Yields • Topaz Star-Gem Veins",
		StationUnlockPerk = "+20% Permanent Planet Value & +15% Star Gems",
		Color = Color3.fromRGB(255, 195, 55),
	},
	{
		Id = "Station_Cryo",
		StationNumber = 2,
		Name = "❄️ Station 2: Cryo-Nebula Research Citadel",
		ShortName = "Cryo Citadel",
		ZoneTier = 3,
		Position = Vector3.new(2800, 95, -3200),
		DockRadius = 195,
		GemCost = 450,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 15.0,
		PassiveBuffDesc = "Zone 3 Outpost • 15x Node Yields • Sapphire Ice-Gem Clusters",
		StationUnlockPerk = "+30% Citizen Growth & +25% Star Gems",
		Color = Color3.fromRGB(85, 245, 225),
	},
	{
		Id = "Station_Pulsar",
		StationNumber = 3,
		Name = "⚡ Station 3: Hyper-Pulsar Relay Starbase",
		ShortName = "Pulsar Starbase",
		ZoneTier = 4,
		Position = Vector3.new(-5200, 135, -5400),
		DockRadius = 205,
		GemCost = 1800,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 65.0,
		PassiveBuffDesc = "Zone 4 Outpost • 65x Node Yields • Ruby Starfire Gem Geodes",
		StationUnlockPerk = "+35% Star Gems & +15% Flight Speed",
		Color = Color3.fromRGB(255, 110, 65),
	},
	{
		Id = "Station_Quantum",
		StationNumber = 4,
		Name = "🔬 Station 4: Starforge Quantum Armada Dock",
		ShortName = "Quantum Dock",
		ZoneTier = 5,
		Position = Vector3.new(7800, 175, -8600),
		DockRadius = 210,
		GemCost = 7500,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 300.0,
		PassiveBuffDesc = "Zone 5 Outpost • 300x Node Yields • Amethyst Void-Gem Motherlodes",
		StationUnlockPerk = "+50% Permanent All Yields & Planet Value",
		Color = Color3.fromRGB(195, 95, 255),
	},
	{
		Id = "Station_Rift",
		StationNumber = 5,
		Name = "🌌 Station 5: Dark-Matter Singularity Bastion",
		ShortName = "Singularity Bastion",
		ZoneTier = 6,
		Position = Vector3.new(-11200, 220, -12500),
		DockRadius = 220,
		GemCost = 30000,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 1500.0,
		PassiveBuffDesc = "Zone 6 Outpost • 1,500x Node Yields • Astral Diamond Motherlodes",
		StationUnlockPerk = "+75% Permanent All Yields & +25% Star Gems",
		Color = Color3.fromRGB(235, 85, 195),
	},
	{
		Id = "Station_Omega",
		StationNumber = 6,
		Name = "🌟 Station 6: Omniverse Horizon Ark-Citadel",
		ShortName = "Omniverse Ark",
		ZoneTier = 6,
		Position = Vector3.new(0, 280, -22000),
		DockRadius = 240,
		GemCost = 125000,
		ReqDrill = 0,
		UnlockedByDefault = false,
		RewardMultiplier = 3500.0,
		PassiveBuffDesc = "Apex Frontier • 3,500x Node Jackpots • Ultimate Endgame Gems",
		StationUnlockPerk = "+150% Permanent All Yields & +50% Star Gems",
		Color = Color3.fromRGB(255, 235, 95),
	},
}

PlanetConfig.WarpSectors = PlanetConfig.SpaceStations

-- ============================================================================
-- CHALLENGING MULTI-LAYERED PROGRESSION 1: 12 PLANETARY ERAS / RANKS
-- ============================================================================
PlanetConfig.PlanetaryRanks = {
	{
		Rank = 1,
		Title = "Proto-Planetoid",
		MinValue = 0,
		YieldMultiplier = 1.0,
		SizeBonus = 0.0,
		BadgeColor = Color3.fromRGB(165, 185, 220),
		RewardDesc = "Base Planetary Output (1.0x)",
	},
	{
		Rank = 2,
		Title = "Awakening World",
		MinValue = 1200,
		YieldMultiplier = 1.35,
		SizeBonus = 0.06,
		BadgeColor = Color3.fromRGB(95, 235, 145),
		RewardDesc = "1.35x All Yields & +6% Planet Scale",
	},
	{
		Rank = 3,
		Title = "Terraformed Biosphere",
		MinValue = 6500,
		YieldMultiplier = 1.85,
		SizeBonus = 0.12,
		BadgeColor = Color3.fromRGB(0, 225, 255),
		RewardDesc = "1.85x All Yields & +12% Planet Scale",
	},
	{
		Rank = 4,
		Title = "Sovereign Star-World",
		MinValue = 32000,
		YieldMultiplier = 2.6,
		SizeBonus = 0.20,
		BadgeColor = Color3.fromRGB(195, 110, 255),
		RewardDesc = "2.6x Yields & Unlocks Planetary Ascension!",
	},
	{
		Rank = 5,
		Title = "Galactic Ecumenopolis",
		MinValue = 160000,
		YieldMultiplier = 4.0,
		SizeBonus = 0.28,
		BadgeColor = Color3.fromRGB(255, 195, 55),
		RewardDesc = "4.0x All Yields & +28% Planet Scale",
	},
	{
		Rank = 6,
		Title = "Dyson Super-World",
		MinValue = 850000,
		YieldMultiplier = 6.5,
		SizeBonus = 0.38,
		BadgeColor = Color3.fromRGB(255, 105, 55),
		RewardDesc = "6.5x All Yields & +38% Planet Scale",
	},
	{
		Rank = 7,
		Title = "Celestial Titan",
		MinValue = 4500000,
		YieldMultiplier = 11.0,
		SizeBonus = 0.48,
		BadgeColor = Color3.fromRGB(255, 75, 195),
		RewardDesc = "11x All Yields & +48% Planet Scale",
	},
	{
		Rank = 8,
		Title = "Astral Hyper-Sphere",
		MinValue = 25000000,
		YieldMultiplier = 19.0,
		SizeBonus = 0.60,
		BadgeColor = Color3.fromRGB(85, 255, 220),
		RewardDesc = "19x All Yields & +60% Planet Scale",
	},
	{
		Rank = 9,
		Title = "Singularity Monarch",
		MinValue = 150000000,
		YieldMultiplier = 35.0,
		SizeBonus = 0.72,
		BadgeColor = Color3.fromRGB(255, 85, 95),
		RewardDesc = "35x All Yields & +72% Planet Scale",
	},
	{
		Rank = 10,
		Title = "Galactic Overlord",
		MinValue = 1000000000,
		YieldMultiplier = 65.0,
		SizeBonus = 0.85,
		BadgeColor = Color3.fromRGB(165, 115, 255),
		RewardDesc = "65x All Yields & +85% Planet Scale",
	},
	{
		Rank = 11,
		Title = "Chronos Sovereign",
		MinValue = 7500000000,
		YieldMultiplier = 125.0,
		SizeBonus = 1.0,
		BadgeColor = Color3.fromRGB(95, 245, 255),
		RewardDesc = "125x All Yields & +100% Planet Scale",
	},
	{
		Rank = 12,
		Title = "Omniverse Apex",
		MinValue = 60000000000,
		YieldMultiplier = 250.0,
		SizeBonus = 1.15,
		BadgeColor = Color3.fromRGB(255, 245, 115),
		RewardDesc = "250x All Yields & Colossal Apex Scale!",
	},
}

-- ============================================================================
-- CHALLENGING PROGRESSION 2: 6 PLANET UPGRADE TRACKS (75 Levels, Gem Cost!)
-- ============================================================================
PlanetConfig.PlanetUpgrades = {
	{
		Id = "DroneAttackDamage",
		Name = "🛸 Drones' Attack Damage",
		Description = "Supercharges all equipped Drones' weapon systems, boosting Drone Attack Damage by +30% per level!",
		BaseCost = { Gems = 15 },
		CostScale = 1.35,
		MaxLevel = 100,
	},
	{
		Id = "DroneReloadSpeed",
		Name = "⚡ Drone Reload Speed",
		Description = "Decreases the shooting cooldown for your Drones so they fire lasers much faster while holding Left-Click!",
		BaseCost = { Points = 1 },
		CostScale = 1.0,
		MaxLevel = 100,
	},
	{
		Id = "CoreDensity",
		Name = "🪐 Planetary Core Mass & Size",
		Description = "Expands your planet's diameter, boosts Planet Value Score, and increases passive 💎 Star Gem income!",
		BaseCost = { Gems = 15 },
		CostScale = 1.38,
		MaxLevel = 75,
	},
	{
		Id = "BiosphereFertility",
		Name = "👥 Citizen Habitat Expansion",
		Description = "Accelerates citizen population growth across all continents, boosting your Planet Value and yields!",
		BaseCost = { Gems = 18 },
		CostScale = 1.38,
		MaxLevel = 75,
	},
	{
		Id = "MagnetosphereDynamo",
		Name = "🚀 Hyper-Drive Thrusters",
		Description = "Increases deep-space flight speed to reach distant Space Stations and boosts passive Star Gems.",
		BaseCost = { Gems = 22 },
		CostScale = 1.40,
		MaxLevel = 75,
	},
	{
		Id = "OrbitalInfrastructure",
		Name = "🛰️ Orbital Ring Network",
		Description = "Constructs orbital infrastructure that multiplies your Planet Value Score and Star Gem output.",
		BaseCost = { Gems = 28 },
		CostScale = 1.42,
		MaxLevel = 75,
	},
	{
		Id = "CivilizationMetropolis",
		Name = "🏙️ Expand Surface Megacities",
		Description = "Boosts ALL Star Gem & Planet Value yields across your civilization (+25% per level & 1.2x every 10 levels)!",
		BaseCost = { Gems = 40 },
		CostScale = 1.45,
		MaxLevel = 75,
	},
	{
		Id = "AnomalyHarvester",
		Name = "🧲 Graviton Tractor & Gem Scanner",
		Description = "Expands Cosmic Collectible pull radius, boosts space node loot, and increases 💎 Star Gem drops!",
		BaseCost = { Gems = 30 },
		CostScale = 1.42,
		MaxLevel = 60,
	},
}

-- ============================================================================
-- CHALLENGING PROGRESSION 3: HUB FACILITIES (WARP GATE & DRONE FOUNDRY BAY)
-- ============================================================================
PlanetConfig.HubMachines = {
	WarpGate = {
		Id = "WarpGate",
		Name = "STARFARER WARP GATE",
		ShortTitle = "WARP NETWORK",
		Icon = "🌀",
		Position = Vector3.new(-420, 18, 0),
		InteractRadius = 115,
		ThemeColor = Color3.fromRGB(185, 95, 255),
		Subtitle = "Unlock Deep-Space Station Warp Gates with Star Gems or Ascend for Cosmic Shards.",
	},
	DroneBay = {
		Id = "DroneBay",
		Name = "ORBITAL DRONE FOUNDRY",
		ShortTitle = "DRONE ROLL BAY",
		Icon = "🛸",
		Position = Vector3.new(420, 18, 0),
		InteractRadius = 125,
		ThemeColor = Color3.fromRGB(56, 215, 255),
		Subtitle = "Roll for Mining & Combat Drones using harvested Space Resources, Level Up Drones, and Expand Slots.",
	},
}

-- ============================================================================
-- SIMULATOR SYSTEM 4: ORBITAL DRONE FLEET, RARITIES, RESOURCE ROLLS & SLOTS
-- ============================================================================
PlanetConfig.BaseDroneSlots = 5
PlanetConfig.MaxDroneLevel = 25

-- Expensive Gem upgrades for additional Drone Slots (Starts at 5 Slots!)
PlanetConfig.DroneSlotUpgrades = {
	{ SlotNumber = 6, GemCost = 65000, RobuxCost = 799, Title = "Drone Slot #6", Desc = "Equip up to 6 Orbital Drones simultaneously." },
	{ SlotNumber = 7, GemCost = 325000, RobuxCost = 1299, Title = "Drone Slot #7", Desc = "Equip up to 7 Orbital Drones simultaneously." },
	{ SlotNumber = 8, GemCost = 1500000, RobuxCost = 1999, Title = "Drone Slot #8", Desc = "Maximum Fleet Command: Equip 8 Orbital Drones!" },
}

PlanetConfig.DroneRarities = {
	Common = { Order = 1, Name = "Common", Color = Color3.fromRGB(175, 188, 210), LevelCostMult = 1.0 },
	Uncommon = { Order = 2, Name = "Uncommon", Color = Color3.fromRGB(72, 235, 138), LevelCostMult = 1.4 },
	Rare = { Order = 3, Name = "Rare", Color = Color3.fromRGB(56, 198, 255), LevelCostMult = 2.0 },
	Epic = { Order = 4, Name = "Epic", Color = Color3.fromRGB(195, 105, 255), LevelCostMult = 3.2 },
	Legendary = { Order = 5, Name = "Legendary", Color = Color3.fromRGB(255, 195, 45), LevelCostMult = 6.5 },
	Mythic = { Order = 6, Name = "Mythic", Color = Color3.fromRGB(255, 65, 105), LevelCostMult = 15.0 },
}

PlanetConfig.DronePathUnlockLevels = {
	Tier1 = 5,
}

PlanetConfig.FirstPathDroneOrder = { "RapidPulse", "HeavyCannon", "LongRangeScout", "SpreadShot", "StickyBomber" }

PlanetConfig.DroneEvolutionTree = {
	BasicDrone = {
		Tier = 0,
		ParentId = nil,
		UnlockLevel = 1,
		NextChoices = { "RapidPulse", "HeavyCannon", "LongRangeScout", "SpreadShot", "StickyBomber" },
	},
	-- Tier 1 First Path: 5 Specialized Voxel Drones (Unlock at Player Level 5)
	-- Future Tier-2 / Tier-3 sub-path trees for each drone can be plugged into NextChoices below!
	RapidPulse = {
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		NextChoices = {}, -- Future Tier-2 paths for this drone branch here
	},
	HeavyCannon = {
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		NextChoices = {}, -- Future Tier-2 paths for this drone branch here
	},
	LongRangeScout = {
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		NextChoices = {}, -- Future Tier-2 paths for this drone branch here
	},
	SpreadShot = {
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		NextChoices = {}, -- Future Tier-2 paths for this drone branch here
	},
	StickyBomber = {
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		NextChoices = {}, -- Future Tier-2 paths for this drone branch here
	},
}

-- Rolling for Drones costs mined Minerals (NOT Gems!) — All pods craft Basic Drones so you choose their path at Lv.5!
PlanetConfig.CompanionPods = {
	{
		Id = "LunarPod",
		Name = "TIER 1 • BASIC DRONE POD",
		Cost = { Minerals = 25 },
		StartLevel = 1,
		GiveGolden = false,
		Description = "Builds a Lv.1 Basic Drone for your fleet. At Player Lv.5, choose its path!",
		Color = Color3.fromRGB(95, 205, 255),
		Pool = {
			{ Id = "BasicDrone", Weight = 100 },
		},
	},
	{
		Id = "IndustrialPod",
		Name = "TIER 2 • VETERAN BASIC POD",
		Cost = { Minerals = 250 },
		StartLevel = 3,
		GiveGolden = false,
		Description = "Builds a pre-upgraded Lv.3 Basic Drone ready for stronger asteroid drilling.",
		Color = Color3.fromRGB(75, 235, 155),
		Pool = {
			{ Id = "BasicDrone", Weight = 100 },
		},
	},
	{
		Id = "NebulaPod",
		Name = "TIER 3 • SUPER BASIC POD",
		Cost = { Minerals = 1500 },
		StartLevel = 6,
		GiveGolden = false,
		Description = "Builds a high-power Lv.6 Basic Drone with boosted damage and drill power.",
		Color = Color3.fromRGB(185, 105, 255),
		Pool = {
			{ Id = "BasicDrone", Weight = 100 },
		},
	},
	{
		Id = "SingularityPod",
		Name = "TIER 4 • GOLDEN BASIC POD",
		Cost = { Minerals = 8500 },
		StartLevel = 8,
		GiveGolden = true,
		Description = "Builds a ★ Golden Basic Drone (1.85x All Stats) that retains Golden status when evolved!",
		Color = Color3.fromRGB(255, 195, 55),
		Pool = {
			{ Id = "BasicDrone", Weight = 100 },
		},
	},
}

-- Diep.io Voxel Drone Classes (Starter BasicDrone -> 5 First-Path Archetypes at Lv.5)
PlanetConfig.Companions = {
	-- TIER 0 STARTER
	BasicDrone = {
		Id = "BasicDrone",
		Name = "Basic Drone",
		Rarity = "Common",
		Tier = 0,
		ParentId = nil,
		UnlockLevel = 1,
		RoleTag = "STARTER DRONE",
		Description = "Balanced voxel starter drone. Reach Level 5 to choose 1 of 5 specialized Drone Paths!",
		Icon = "🛸",
		Color = Color3.fromRGB(85, 195, 255),
		BeamColor = Color3.fromRGB(95, 220, 255),
		Damage = 12,
		DrillPower = 3,
		DrillSpeed = 1.20,
		FireCooldown = 0.45,
		Range = 260,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "Standard",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 20,
		YieldMult = 1.15,
		GemMult = 1.05,
		SpeedBonus = 0.02,
	},

	-- TIER 1 ARCHETYPE 1: FAST FIRE, LOW DAMAGE
	RapidPulse = {
		Id = "RapidPulse",
		Name = "Rapid Drone",
		Rarity = "Uncommon",
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		RoleTag = "FAST • LOW DMG",
		Description = "Shoots very fast (0.14s) rapid-fire voxel bolts with low damage per shot.",
		Icon = "⚡",
		Color = Color3.fromRGB(55, 235, 255),
		BeamColor = Color3.fromRGB(120, 245, 255),
		Damage = 5,
		DrillPower = 4,
		DrillSpeed = 1.45,
		FireCooldown = 0.14,
		Range = 250,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 3.5,
		ProjectileStyle = "RapidBolt",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 40,
		YieldMult = 1.25,
		GemMult = 1.10,
		SpeedBonus = 0.05,
	},

	-- TIER 1 ARCHETYPE 2: VERY SLOW, LARGE DAMAGE
	HeavyCannon = {
		Id = "HeavyCannon",
		Name = "Heavy Drone",
		Rarity = "Rare",
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		RoleTag = "SLOW • LARGE DMG",
		Description = "Shoots very slowly (1.55s) for massive impact damage + 18-stud splash.",
		Icon = "💥",
		Color = Color3.fromRGB(245, 72, 68),
		BeamColor = Color3.fromRGB(255, 110, 55),
		Damage = 56,
		DrillPower = 9,
		DrillSpeed = 1.10,
		FireCooldown = 1.55,
		Range = 275,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "HeavySlug",
		BlastRadius = 18,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 45,
		YieldMult = 1.35,
		GemMult = 1.12,
		SpeedBonus = 0.02,
	},

	-- TIER 1 ARCHETYPE 3: LARGE RANGE, FLIES VERY FAR OUT, LOW-MEDIUM DAMAGE
	LongRangeScout = {
		Id = "LongRangeScout",
		Name = "Long-Range Drone",
		Rarity = "Rare",
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		RoleTag = "FAR RANGE • SCOUT",
		Description = "Flies very far out (540 studs) and snipes distant targets up to 720 studs!",
		Icon = "🎯",
		Color = Color3.fromRGB(65, 235, 145),
		BeamColor = Color3.fromRGB(105, 255, 175),
		Damage = 11,
		DrillPower = 6,
		DrillSpeed = 1.28,
		FireCooldown = 0.54,
		Range = 720,
		LeashRange = 540,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "SniperBeam",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 45,
		YieldMult = 1.30,
		GemMult = 1.18,
		SpeedBonus = 0.08,
	},

	-- TIER 1 ARCHETYPE 4: MULTIPLE BULLETS, LOW DMG, MEDIUM SPEED SPREAD
	SpreadShot = {
		Id = "SpreadShot",
		Name = "Spread Drone",
		Rarity = "Uncommon",
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		RoleTag = "5x SPREAD BULLETS",
		Description = "Fires 5 low-damage bullets at once in a medium-speed wide spread cone.",
		Icon = "🔸",
		Color = Color3.fromRGB(255, 185, 45),
		BeamColor = Color3.fromRGB(255, 215, 75),
		Damage = 4,
		DrillPower = 5,
		DrillSpeed = 1.25,
		FireCooldown = 0.48,
		Range = 240,
		LeashRange = 0,
		ProjectilesPerShot = 5,
		SpreadDeg = 18,
		ProjectileStyle = "SpreadPellet",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 45,
		YieldMult = 1.28,
		GemMult = 1.12,
		SpeedBonus = 0.04,
	},

	-- TIER 1 ARCHETYPE 5: STICKY BOMBS + DETONATE ALL BUTTON
	StickyBomber = {
		Id = "StickyBomber",
		Name = "Sticky Bomb Drone",
		Rarity = "Epic",
		Tier = 1,
		ParentId = "BasicDrone",
		UnlockLevel = 5,
		RoleTag = "STICKY BOMBS [R]",
		Description = "Shoots voxel bombs that stick and stack (up to 24). Press [R] to detonate all at once!",
		Icon = "💣",
		Color = Color3.fromRGB(255, 125, 35),
		BeamColor = Color3.fromRGB(255, 75, 55),
		Damage = 3,
		DrillPower = 6,
		DrillSpeed = 1.22,
		FireCooldown = 0.62,
		Range = 310,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 2,
		ProjectileStyle = "StickyBomb",
		BlastRadius = 32,
		StickyDamageMult = 2.65,
		MaxStickyBombs = 24,
		CraftMineralCost = 55,
		YieldMult = 1.40,
		GemMult = 1.16,
		SpeedBonus = 0.03,
	},

	-- TIER 2 EVOLUTIONS (10 BRANCHES AT LEVEL 8)
	MinigunVortex = {
		Id = "MinigunVortex",
		Name = "Minigun Vortex",
		Rarity = "Epic",
		Tier = 2,
		ParentId = "RapidPulse",
		UnlockLevel = 8,
		RoleTag = "ULTRA FAST • QUAD",
		Description = "4-barrel rotary voxel minigun firing at blistering 0.095s cadence!",
		Icon = "⚡",
		Color = Color3.fromRGB(0, 245, 255),
		BeamColor = Color3.fromRGB(145, 255, 255),
		Damage = 7,
		DrillPower = 12,
		DrillSpeed = 1.75,
		FireCooldown = 0.095,
		Range = 265,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 4.5,
		ProjectileStyle = "RapidBolt",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 220,
		YieldMult = 1.75,
		GemMult = 1.35,
		SpeedBonus = 0.09,
	},
	TwinLaser = {
		Id = "TwinLaser",
		Name = "Twin Streamer",
		Rarity = "Epic",
		Tier = 2,
		ParentId = "RapidPulse",
		UnlockLevel = 8,
		RoleTag = "2x RAPID BOLTS",
		Description = "Dual synchronized pulse emitters firing double rapid-fire bolts every 0.18s.",
		Icon = "⚡",
		Color = Color3.fromRGB(75, 195, 255),
		BeamColor = Color3.fromRGB(115, 225, 255),
		Damage = 6,
		DrillPower = 11,
		DrillSpeed = 1.65,
		FireCooldown = 0.18,
		Range = 280,
		LeashRange = 0,
		ProjectilesPerShot = 2,
		SpreadDeg = 2.5,
		ProjectileStyle = "RapidBolt",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 220,
		YieldMult = 1.70,
		GemMult = 1.32,
		SpeedBonus = 0.08,
	},
	AnnihilatorCore = {
		Id = "AnnihilatorCore",
		Name = "Annihilator Cube",
		Rarity = "Legendary",
		Tier = 2,
		ParentId = "HeavyCannon",
		UnlockLevel = 8,
		RoleTag = "MEGA CANNON • AOE",
		Description = "Colossal slow siege bore dealing devastating single-shot + 28-stud blast damage!",
		Icon = "💥",
		Color = Color3.fromRGB(255, 55, 75),
		BeamColor = Color3.fromRGB(255, 95, 45),
		Damage = 110,
		DrillPower = 24,
		DrillSpeed = 1.35,
		FireCooldown = 1.95,
		Range = 290,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "HeavySlug",
		BlastRadius = 28,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 260,
		YieldMult = 2.15,
		GemMult = 1.45,
		SpeedBonus = 0.04,
	},
	RailJuggernaut = {
		Id = "RailJuggernaut",
		Name = "Rail Juggernaut",
		Rarity = "Legendary",
		Tier = 2,
		ParentId = "HeavyCannon",
		UnlockLevel = 8,
		RoleTag = "HEAVY RAIL • 440R",
		Description = "Extended electromagnetic railgun combining heavy cannon power with long reach!",
		Icon = "💥",
		Color = Color3.fromRGB(235, 95, 195),
		BeamColor = Color3.fromRGB(255, 130, 225),
		Damage = 82,
		DrillPower = 20,
		DrillSpeed = 1.32,
		FireCooldown = 1.25,
		Range = 440,
		LeashRange = 180,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "HeavySlug",
		BlastRadius = 20,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 260,
		YieldMult = 2.00,
		GemMult = 1.42,
		SpeedBonus = 0.06,
	},
	OrbitalSniper = {
		Id = "OrbitalSniper",
		Name = "Orbital Ranger",
		Rarity = "Epic",
		Tier = 2,
		ParentId = "LongRangeScout",
		UnlockLevel = 8,
		RoleTag = "950R EXTREME SCOUT",
		Description = "Roves up to 720 studs away from your planet and hits asteroids from 950 studs!",
		Icon = "🎯",
		Color = Color3.fromRGB(45, 255, 165),
		BeamColor = Color3.fromRGB(95, 255, 195),
		Damage = 20,
		DrillPower = 15,
		DrillSpeed = 1.55,
		FireCooldown = 0.50,
		Range = 950,
		LeashRange = 720,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "SniperBeam",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 240,
		YieldMult = 1.90,
		GemMult = 1.55,
		SpeedBonus = 0.14,
	},
	HunterDrone = {
		Id = "HunterDrone",
		Name = "Predator Hunter",
		Rarity = "Epic",
		Tier = 2,
		ParentId = "LongRangeScout",
		UnlockLevel = 8,
		RoleTag = "FAR • 2-SHOT BURST",
		Description = "Long-range twin-burst voxel hunter patrolling far out to double-tap targets!",
		Icon = "🎯",
		Color = Color3.fromRGB(95, 225, 95),
		BeamColor = Color3.fromRGB(155, 255, 120),
		Damage = 14,
		DrillPower = 14,
		DrillSpeed = 1.50,
		FireCooldown = 0.58,
		Range = 780,
		LeashRange = 580,
		ProjectilesPerShot = 2,
		SpreadDeg = 1.5,
		ProjectileStyle = "SniperBeam",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 240,
		YieldMult = 1.85,
		GemMult = 1.48,
		SpeedBonus = 0.12,
	},
	PentaBlaster = {
		Id = "PentaBlaster",
		Name = "Penta-Shot Voxel",
		Rarity = "Epic",
		Tier = 2,
		ParentId = "SpreadShot",
		UnlockLevel = 8,
		RoleTag = "7x WIDE FAN",
		Description = "Blankets space in a wide 7-bullet cone every 0.45s for massive multi-target clear.",
		Icon = "🔸",
		Color = Color3.fromRGB(255, 165, 35),
		BeamColor = Color3.fromRGB(255, 205, 65),
		Damage = 6,
		DrillPower = 14,
		DrillSpeed = 1.50,
		FireCooldown = 0.45,
		Range = 265,
		LeashRange = 0,
		ProjectilesPerShot = 7,
		SpreadDeg = 26,
		ProjectileStyle = "SpreadPellet",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 240,
		YieldMult = 1.90,
		GemMult = 1.42,
		SpeedBonus = 0.08,
	},
	OctoBarrage = {
		Id = "OctoBarrage",
		Name = "Octo-Flak Cannon",
		Rarity = "Legendary",
		Tier = 2,
		ParentId = "SpreadShot",
		UnlockLevel = 8,
		RoleTag = "8x BULLET STORM",
		Description = "Fires 8 high-speed voxel flak shards per volley at medium-fast reload speed!",
		Icon = "🔸",
		Color = Color3.fromRGB(255, 215, 65),
		BeamColor = Color3.fromRGB(255, 240, 115),
		Damage = 5,
		DrillPower = 16,
		DrillSpeed = 1.60,
		FireCooldown = 0.40,
		Range = 255,
		LeashRange = 0,
		ProjectilesPerShot = 8,
		SpreadDeg = 22,
		ProjectileStyle = "SpreadPellet",
		BlastRadius = 0,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 280,
		YieldMult = 2.10,
		GemMult = 1.50,
		SpeedBonus = 0.10,
	},
	ClusterSapper = {
		Id = "ClusterSapper",
		Name = "Cluster Bomber",
		Rarity = "Legendary",
		Tier = 2,
		ParentId = "StickyBomber",
		UnlockLevel = 8,
		RoleTag = "2x STICKY • 36 MAX",
		Description = "Launches 2 sticky bombs per shot (up to 36 stacked mines!) before pressing [R]!",
		Icon = "💣",
		Color = Color3.fromRGB(255, 145, 35),
		BeamColor = Color3.fromRGB(255, 95, 45),
		Damage = 4,
		DrillPower = 16,
		DrillSpeed = 1.48,
		FireCooldown = 0.56,
		Range = 340,
		LeashRange = 0,
		ProjectilesPerShot = 2,
		SpreadDeg = 6,
		ProjectileStyle = "StickyBomb",
		BlastRadius = 34,
		StickyDamageMult = 2.30,
		MaxStickyBombs = 36,
		CraftMineralCost = 280,
		YieldMult = 2.10,
		GemMult = 1.50,
		SpeedBonus = 0.06,
	},
	NovaDemolisher = {
		Id = "NovaDemolisher",
		Name = "Nova C4 Titan",
		Rarity = "Legendary",
		Tier = 2,
		ParentId = "StickyBomber",
		UnlockLevel = 8,
		RoleTag = "GIANT STICKY BOMBS",
		Description = "Plants oversized high-yield Nova Charges with huge 46-stud detonation shockwaves!",
		Icon = "💣",
		Color = Color3.fromRGB(255, 65, 95),
		BeamColor = Color3.fromRGB(255, 55, 115),
		Damage = 6,
		DrillPower = 19,
		DrillSpeed = 1.40,
		FireCooldown = 0.72,
		Range = 360,
		LeashRange = 0,
		ProjectilesPerShot = 1,
		SpreadDeg = 1.5,
		ProjectileStyle = "StickyBomb",
		BlastRadius = 46,
		StickyDamageMult = 4.20,
		MaxStickyBombs = 24,
		CraftMineralCost = 300,
		YieldMult = 2.30,
		GemMult = 1.60,
		SpeedBonus = 0.06,
	},

	-- MYTHIC ENDGAME APEX DRONES
	OmniverseEye = {
		Id = "OmniverseEye",
		Name = "Omniverse Voxel Seraph",
		Rarity = "Mythic",
		Tier = 3,
		ParentId = nil,
		UnlockLevel = 15,
		RoleTag = "MYTHIC • 3x BEAM",
		Description = "Mythic multi-array voxel construct firing rapid high-power tri-beams at long range.",
		Icon = "👁️",
		Color = Color3.fromRGB(255, 240, 105),
		BeamColor = Color3.fromRGB(255, 245, 135),
		Damage = 95,
		DrillPower = 140,
		DrillSpeed = 2.80,
		FireCooldown = 0.24,
		Range = 520,
		LeashRange = 240,
		ProjectilesPerShot = 3,
		SpreadDeg = 6,
		ProjectileStyle = "SpreadPellet",
		BlastRadius = 18,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 18000,
		YieldMult = 6.50,
		GemMult = 3.50,
		SpeedBonus = 0.24,
	},
	SingularityArchon = {
		Id = "SingularityArchon",
		Name = "Singularity Star-Eater",
		Rarity = "Mythic",
		Tier = 3,
		ParentId = nil,
		UnlockLevel = 20,
		RoleTag = "APEX • HEAVY STICKY",
		Description = "God-tier voxel monolith firing devastating heavy plasma + sticky nova cores.",
		Icon = "✴️",
		Color = Color3.fromRGB(255, 65, 115),
		BeamColor = Color3.fromRGB(255, 75, 125),
		Damage = 240,
		DrillPower = 280,
		DrillSpeed = 3.20,
		FireCooldown = 0.35,
		Range = 600,
		LeashRange = 300,
		ProjectilesPerShot = 1,
		SpreadDeg = 0,
		ProjectileStyle = "HeavySlug",
		BlastRadius = 38,
		StickyDamageMult = 0,
		MaxStickyBombs = 0,
		CraftMineralCost = 45000,
		YieldMult = 12.0,
		GemMult = 5.50,
		SpeedBonus = 0.32,
	},
}

-- Backward-compatible aliases for legacy drone IDs
PlanetConfig.Companions.ScrapWelder = PlanetConfig.Companions.BasicDrone
PlanetConfig.Companions.SputnikMiner = PlanetConfig.Companions.LongRangeScout
PlanetConfig.Companions.BioScout = PlanetConfig.Companions.SpreadShot
PlanetConfig.Companions.QuartzCutter = PlanetConfig.Companions.RapidPulse
PlanetConfig.Companions.SolarRelay = PlanetConfig.Companions.HeavyCannon
PlanetConfig.Companions.CryoSentinel = PlanetConfig.Companions.OrbitalSniper
PlanetConfig.Companions.PulsarValkyrie = PlanetConfig.Companions.MinigunVortex
PlanetConfig.Companions.DarkMatterCherub = PlanetConfig.Companions.StickyBomber
PlanetConfig.Companions.QuantumSeraph = PlanetConfig.Companions.ClusterSapper
PlanetConfig.Companions.ChronosDragon = PlanetConfig.Companions.AnnihilatorCore

-- Returns next-tier Diep.io evolution class IDs available for `classId` at `playerLevel`
function PlanetConfig.GetDroneEvolutionChoices(classId: string, playerLevel: number): { string }
	local node = (PlanetConfig.DroneEvolutionTree :: any)[classId] or PlanetConfig.DroneEvolutionTree.BasicDrone
	if not node or not node.NextChoices then
		return {}
	end
	local unlocked: { string } = {}
	for _, nextId in ipairs(node.NextChoices) do
		local nextNode = (PlanetConfig.DroneEvolutionTree :: any)[nextId]
		if nextNode and playerLevel >= (nextNode.UnlockLevel or 1) then
			table.insert(unlocked, nextId)
		end
	end
	return unlocked
end

-- Compute effective Drone stats at a given Level (1..25) and Golden fusion state
function PlanetConfig.GetDroneStats(droneId: string, level: number?, isGolden: boolean?)
	local base = PlanetConfig.Companions[droneId] or PlanetConfig.Companions.BasicDrone
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, PlanetConfig.MaxDroneLevel)
	local goldMult = isGolden and 1.85 or 1.0
	local lvStatMult = (1 + (lv - 1) * 0.18) * goldMult
	local lvSpeedMult = (1 + (lv - 1) * 0.035) * (isGolden and 1.15 or 1.0)
	local lvYieldMult = 1 + ((base.YieldMult or 1.1) - 1) * (1 + (lv - 1) * 0.14) * goldMult
	local lvGemMult = 1 + ((base.GemMult or 1.05) - 1) * (1 + (lv - 1) * 0.12) * goldMult
	local stickyMult = base.StickyDamageMult or 0
	local bombBaseDmg = (stickyMult > 0) and math.floor(14 * stickyMult * lvStatMult + 0.5) or 0

	return {
		Damage = math.max(1, math.floor((base.Damage or 10) * lvStatMult + 0.5)),
		DrillPower = math.max(1, math.floor((base.DrillPower or 3) * lvStatMult + 0.5)),
		DrillSpeed = tonumber(string.format("%.2f", (base.DrillSpeed or 1.2) * lvSpeedMult)) or 1.2,
		FireCooldown = base.FireCooldown or 0.45,
		Range = base.Range or 260,
		LeashRange = base.LeashRange or 0,
		ProjectilesPerShot = base.ProjectilesPerShot or 1,
		SpreadDeg = base.SpreadDeg or 0,
		ProjectileStyle = base.ProjectileStyle or "Standard",
		BlastRadius = base.BlastRadius or 0,
		StickyDamageMult = stickyMult,
		MaxStickyBombs = base.MaxStickyBombs or 0,
		BombBaseDamage = bombBaseDmg,
		Tier = base.Tier or 0,
		RoleTag = base.RoleTag or "STANDARD",
		Color = base.Color,
		BeamColor = base.BeamColor or base.Color,
		YieldMult = tonumber(string.format("%.2f", lvYieldMult)) or 1.15,
		GemMult = tonumber(string.format("%.2f", lvGemMult)) or 1.05,
		SpeedBonus = (base.SpeedBonus or 0.02) * (isGolden and 1.35 or 1.0),
		Level = lv,
	}
end

-- Resource cost to level up a drone from currentLevel -> currentLevel + 1
function PlanetConfig.GetDroneLevelUpCost(droneId: string, currentLevel: number): { [string]: number }
	local base = PlanetConfig.Companions[droneId] or PlanetConfig.Companions.BasicDrone
	local rMeta = PlanetConfig.DroneRarities[base.Rarity] or PlanetConfig.DroneRarities.Common
	local lv = math.clamp(math.floor(tonumber(currentLevel) or 1), 1, PlanetConfig.MaxDroneLevel)
	local scale = math.pow(1.36, lv - 1) * rMeta.LevelCostMult
	return {
		Minerals = math.max(25, math.floor(32 * scale)),
	}
end

-- ============================================================================
-- SIMULATOR SYSTEM 5: ⚡ ACTIVE TIMED BOOSTERS, PLAYTIME GIFTS, CODES & SHARD SHOP
-- ============================================================================
PlanetConfig.Boosters = {
	{
		Id = "YieldBoost",
		Name = "2x All Yields",
		ShortTag = "2x YIELDS",
		Icon = "⚡",
		Duration = 900, -- 15 minutes
		GemCost = 90,
		Color = Color3.fromRGB(255, 205, 55),
		Description = "Doubles ALL Resource drops, Citizen growth, and Planet Value yields for 15 minutes!",
	},
	{
		Id = "GemBoost",
		Name = "2x Star Gem Drops",
		ShortTag = "2x GEMS",
		Icon = "💎",
		Duration = 900,
		GemCost = 110,
		Color = Color3.fromRGB(85, 225, 255),
		Description = "Doubles all Star Gem drops from space crystal nodes, chests, and enemies for 15 minutes!",
	},
	{
		Id = "SpeedBoost",
		Name = "Hyper-Drive Overdrive (+60% Speed)",
		ShortTag = "+60% SPEED",
		Icon = "🚀",
		Duration = 900,
		GemCost = 65,
		Color = Color3.fromRGB(95, 250, 145),
		Description = "Boosts your planet's flight speed by +60% and Drone Drill Speed by +25% for 15 minutes!",
	},
}

PlanetConfig.PlaytimeRewards = {
	{ Id = 1, TimeReq = 60, Label = "1 Min Gift", RewardText = "+40 Minerals & +25 Gems", Gems = 25, Resources = { Minerals = 40 } },
	{ Id = 2, TimeReq = 180, Label = "3 Min Gift", RewardText = "+120 Minerals & 5m Speed Boost", Gems = 60, Resources = { Minerals = 120 }, BoosterId = "SpeedBoost", BoosterSecs = 300 },
	{ Id = 3, TimeReq = 360, Label = "6 Min Gift", RewardText = "+180 Gems & 10m 2x Yields", Gems = 180, BoosterId = "YieldBoost", BoosterSecs = 600 },
	{ Id = 4, TimeReq = 720, Label = "12 Min Gift", RewardText = "+400 Gems & 10m 2x Gems", Gems = 400, BoosterId = "GemBoost", BoosterSecs = 600 },
	{ Id = 5, TimeReq = 1200, Label = "20 Min Gift", RewardText = "+850 Gems & 15m 2x Yields", Gems = 850, BoosterId = "YieldBoost", BoosterSecs = 900 },
	{ Id = 6, TimeReq = 1800, Label = "30 Min Jackpot", RewardText = "+2,500 Gems & All Boosts!", Gems = 2500, AllBoostSecs = 900 },
}

PlanetConfig.PromoCodes = {
	COSMIC2026 = { Gems = 250, Desc = "+250 Star Gems" },
	STARFARER = { Gems = 200, BoosterId = "SpeedBoost", BoosterSecs = 600, Desc = "+200 Star Gems & 10m Hyper-Drive Boost" },
	GALAXY = { Gems = 250, BoosterId = "YieldBoost", BoosterSecs = 600, Desc = "+250 Star Gems & 10m 2x Yield Boost" },
	GEMS500 = { Gems = 500, Desc = "+500 Star Gems" },
}

PlanetConfig.ShardUpgrades = {
	{
		Id = "PermValue",
		Name = "Precursor Core Matrix (+50% Planet Value / Lv)",
		Description = "Permanently increases your Planet Value Score & Drone Damage by +50% per level.",
		BaseShardCost = 1,
		CostScale = 2.0,
		MaxLevel = 15,
	},
	{
		Id = "PermGems",
		Name = "Astral Gem Harvester (+50% Star Gems / Lv)",
		Description = "Permanently increases all Star Gem drops and income by +50% per level!",
		BaseShardCost = 1,
		CostScale = 1.8,
		MaxLevel = 20,
	},
	{
		Id = "ExtraDroneSlots",
		Name = "Ascended Fleet Mastery (+25% Drone Drill Power / Lv)",
		Description = "Permanently boosts all equipped Drones' Drill Power and Damage by +25% per level!",
		BaseShardCost = 2,
		CostScale = 2.5,
		MaxLevel = 10,
	},
	{
		Id = "PermSpeed",
		Name = "Warp-Slipstream Hull (+25% Flight Speed / Lv)",
		Description = "Permanently increases your planet's flight speed by +25% per level!",
		BaseShardCost = 1,
		CostScale = 1.8,
		MaxLevel = 10,
	},
}

-- ============================================================================
-- GUIDED MISSIONS (Starting from 0 -> Mining Ore -> Rolling First Drone -> Leveling -> Stations!)
-- ============================================================================
PlanetConfig.Missions = {
	{
		Id = 1,
		Title = "First Asteroid Harvest",
		Description = "Fly near or click on Mineral Asteroids (Aluminum, Iron, Copper, Gold) in Zone 1 to destroy 2 asteroids and earn XP!",
		GoalType = "OrbsHarvested",
		Target = 2,
		Reward = { Gems = 15, Resources = { Minerals = 45 } },
	},
	{
		Id = 2,
		Title = "Roll Your First Drone",
		Description = "Visit the Orbital Drone Foundry on the East Hub Plaza (or click DRONES) and roll a Tier 1 Drone for 25 Minerals.",
		GoalType = "DronesHatched",
		Target = 1,
		Reward = { Gems = 40, Resources = { Minerals = 100 } },
	},
	{
		Id = 3,
		Title = "Level Up a Drone",
		Description = "Open the DRONES menu, select an equipped drone, and Level It Up using harvested Minerals.",
		GoalType = "DroneLevels",
		Target = 1,
		Reward = { Gems = 75, Resources = { Minerals = 200 } },
	},
	{
		Id = 4,
		Title = "First Planetary Upgrade",
		Description = "Press [Q] to upgrade your Attack Damage or open SHOP to upgrade a Planet System to Level 1.",
		GoalType = "TotalUpgrades",
		Target = 1,
		Reward = { Gems = 110, Resources = { Minerals = 250 } },
	},
	{
		Id = 5,
		Title = "Unlock Station 1 Warp Gate",
		Description = "Fly to Station 1 (-1,850 Z) or open STATIONS and spend 100 Gems to unlock the Belt Outpost Warp Gate.",
		GoalType = "StationsUnlocked",
		Target = 1,
		Reward = { Gems = 220, Resources = { Minerals = 600 } },
	},
	{
		Id = 6,
		Title = "Dawn of Evolution",
		Description = "Open EVOLVE and unlock your first Tier 1 Species Evolution.",
		GoalType = "UnlockedEvolutions",
		Target = 2,
		Reward = { Gems = 380 },
	},
	{
		Id = 7,
		Title = "Unlock Station 2 (Cryo-Nebula)",
		Description = "Unlock Station 2: Cryo-Nebula Citadel Warp Gate (450 Gems).",
		GoalType = "StationsUnlocked",
		Target = 2,
		Reward = { Gems = 800 },
	},
	{
		Id = 8,
		Title = "Sovereign Star-World",
		Description = "Reach 32,000+ Planet Value Score (Rank 4: Sovereign Star-World) to unlock Planetary Ascension.",
		GoalType = "PlanetValue",
		Target = 32000,
		Reward = { Gems = 1600 },
	},
}

PlanetConfig.DefaultPlanetLook = {
	PlanetName = "Terra Prime",
	Biome = "Terrestrial",
	CoreShape = "RoundSphere",
	LandCoverage = "MajorContinents",
	SurfaceFeature = "Forests",
	RingStyle = "SaturnBands",
	MoonStyle = "TwinMoons",
	Atmosphere = "Breathable",
	RotationSpeedId = "Normal",
	WaterMaterial = "Slate",
	LandMaterial = "Grass",
	RockMaterial = "Rock",
	WaterColor = { 22, 105, 205 },
	LandColor = { 58, 168, 72 },
	TreeColor = { 34, 138, 48 },
	RockColor = { 122, 126, 136 },
	AtmosphereColor = { 95, 180, 240 },
	CloudColor = { 242, 246, 250 },
	RingColor = { 215, 185, 130 },
}

return PlanetConfig
