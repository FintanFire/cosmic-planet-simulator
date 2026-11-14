--!strict
local PlanetConfig = {}

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

-- Material node archetypes: higher-value materials have significantly more HP!
PlanetConfig.MaterialNodes = {
	Minerals = {
		Type = "Minerals",
		BaseTitle = "Titanium Ore Asteroid",
		HPMult = 1.0,
		DrillReqMult = 1.0,
		ValueMult = 1.0,
		PrimaryResource = "Minerals",
		SecondaryResource = "Energy",
		GemChance = 0.35,
		GemMult = 0.5,
		Color = Color3.fromRGB(255, 165, 65),
	},
	Biomass = {
		Type = "Biomass",
		BaseTitle = "Bio-Spore Comet",
		HPMult = 1.25,
		DrillReqMult = 1.0,
		ValueMult = 1.2,
		PrimaryResource = "Biomass",
		SecondaryResource = "Minerals",
		GemChance = 0.40,
		GemMult = 0.6,
		Color = Color3.fromRGB(85, 235, 135),
	},
	Energy = {
		Type = "Energy",
		BaseTitle = "Plasma Flux Geode",
		HPMult = 1.65,
		DrillReqMult = 1.15,
		ValueMult = 1.5,
		PrimaryResource = "Energy",
		SecondaryResource = "Minerals",
		GemChance = 0.55,
		GemMult = 0.85,
		Color = Color3.fromRGB(65, 215, 255),
	},
	Tech = {
		Type = "Tech",
		BaseTitle = "Quantum Relic Derelict",
		HPMult = 2.25,
		DrillReqMult = 1.35,
		ValueMult = 2.0,
		PrimaryResource = "Tech",
		SecondaryResource = "Energy",
		GemChance = 0.70,
		GemMult = 1.15,
		Color = Color3.fromRGB(195, 115, 255),
	},
	StarGems = {
		Type = "StarGems",
		BaseTitle = "Star-Gem Crystal Vein",
		HPMult = 2.80,
		DrillReqMult = 1.50,
		ValueMult = 2.5,
		PrimaryResource = "Gems",
		SecondaryResource = "Minerals",
		GemChance = 1.0,
		GemMult = 1.85,
		Color = Color3.fromRGB(56, 235, 255),
	},
	PopulationPod = {
		Type = "PopulationPod",
		BaseTitle = "Colonial Stasis Ark",
		HPMult = 1.40,
		DrillReqMult = 1.0,
		ValueMult = 1.6,
		PrimaryResource = "Biomass",
		SecondaryResource = "Tech",
		GemChance = 0.65,
		GemMult = 0.9,
		Color = Color3.fromRGB(125, 235, 195),
	},
	SupernovaChest = {
		Type = "SupernovaChest",
		BaseTitle = "Ancient Supernova Vault",
		HPMult = 4.50,
		DrillReqMult = 1.80,
		ValueMult = 4.2,
		PrimaryResource = "All",
		SecondaryResource = "Gems",
		GemChance = 1.0,
		GemMult = 3.20,
		Color = Color3.fromRGB(255, 215, 65),
	},
	SpaceEnemy = {
		Type = "SpaceEnemy",
		BaseTitle = "Rogue Void Sentinel",
		HPMult = 3.40,
		DrillReqMult = 1.40,
		ValueMult = 3.5,
		PrimaryResource = "All",
		SecondaryResource = "Gems",
		GemChance = 1.0,
		GemMult = 2.60,
		Color = Color3.fromRGB(255, 75, 95),
	},
}

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
PlanetConfig.BaseDroneSlots = 2
PlanetConfig.MaxDroneLevel = 25

-- Expensive Gem upgrades for additional Drone Slots (Starts at 2 Slots!)
PlanetConfig.DroneSlotUpgrades = {
	{ SlotNumber = 3, GemCost = 500, RobuxCost = 99, Title = "Drone Slot #3", Desc = "Equip up to 3 Orbital Drones simultaneously." },
	{ SlotNumber = 4, GemCost = 2500, RobuxCost = 199, Title = "Drone Slot #4", Desc = "Equip up to 4 Orbital Drones simultaneously." },
	{ SlotNumber = 5, GemCost = 12500, RobuxCost = 399, Title = "Drone Slot #5", Desc = "Equip up to 5 Orbital Drones simultaneously." },
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

-- Rolling for Drones costs APPROPRIATE SPACE RESOURCES (NOT Gems!)
PlanetConfig.CompanionPods = {
	{
		Id = "LunarPod",
		Name = "TIER 1 • SALVAGE ORE CORE",
		Cost = { Minerals = 25 },
		Description = "Fabricates starter mining & laser drones using raw Titanium Ore harvested from Zone 1 asteroids.",
		Color = Color3.fromRGB(95, 205, 255),
		Pool = {
			{ Id = "ScrapWelder", Weight = 52 },
			{ Id = "SputnikMiner", Weight = 32 },
			{ Id = "BioScout", Weight = 13 },
			{ Id = "QuartzCutter", Weight = 3 },
		},
	},
	{
		Id = "IndustrialPod",
		Name = "TIER 2 • TECTONIC ALLOY CORE",
		Cost = { Minerals = 180, Energy = 110, Biomass = 85 },
		Description = "Forges industrial laser cutters and solar prism drones using refined Ore, Plasma Flux, and Bio-Spores.",
		Color = Color3.fromRGB(75, 235, 155),
		Pool = {
			{ Id = "BioScout", Weight = 42 },
			{ Id = "QuartzCutter", Weight = 32 },
			{ Id = "SolarRelay", Weight = 18 },
			{ Id = "CryoSentinel", Weight = 6.5 },
			{ Id = "PulsarValkyrie", Weight = 1.5 },
		},
	},
	{
		Id = "NebulaPod",
		Name = "TIER 3 • CRYO-PLASMA FOUNDRY",
		Cost = { Minerals = 1100, Energy = 950, Biomass = 700, Tech = 500 },
		Description = "Synthesizes high-velocity military strikers and cryo-lances with a chance at Legendary Quantum Seraphs!",
		Color = Color3.fromRGB(185, 105, 255),
		Pool = {
			{ Id = "SolarRelay", Weight = 34 },
			{ Id = "CryoSentinel", Weight = 34 },
			{ Id = "PulsarValkyrie", Weight = 18 },
			{ Id = "DarkMatterCherub", Weight = 9.5 },
			{ Id = "QuantumSeraph", Weight = 3.8 },
			{ Id = "OmniverseEye", Weight = 0.7 },
		},
	},
	{
		Id = "SingularityPod",
		Name = "TIER 4 • OMNIVERSE SINGULARITY CORE",
		Cost = { Minerals = 7500, Energy = 6800, Biomass = 5200, Tech = 6000 },
		Description = "Apex foundry core capable of manifesting Legendary Chronos Dragons and Mythic Omniverse Seraphs!",
		Color = Color3.fromRGB(255, 195, 55),
		Pool = {
			{ Id = "PulsarValkyrie", Weight = 36 },
			{ Id = "DarkMatterCherub", Weight = 34 },
			{ Id = "QuantumSeraph", Weight = 16 },
			{ Id = "ChronosDragon", Weight = 10 },
			{ Id = "OmniverseEye", Weight = 3.0 },
			{ Id = "SingularityArchon", Weight = 1.0 },
		},
	},
}

-- Common -> Epic scale modestly so Leveling Up makes any drone viable;
-- Legendary & Mythic (the rarest drones) are MUCH stronger than the rest!
PlanetConfig.Companions = {
	ScrapWelder = {
		Id = "ScrapWelder",
		Name = "MK-I Scrap Welder",
		Rarity = "Common",
		Icon = "🔧",
		Color = Color3.fromRGB(165, 175, 192),
		BeamColor = Color3.fromRGB(255, 165, 65),
		Damage = 10,
		DrillPower = 3,
		DrillSpeed = 1.15,
		YieldMult = 1.15,
		GemMult = 1.05,
		SpeedBonus = 0.02,
	},
	SputnikMiner = {
		Id = "SputnikMiner",
		Name = "Iron Sputnik Probe",
		Rarity = "Common",
		Icon = "🛰️",
		Color = Color3.fromRGB(185, 198, 220),
		BeamColor = Color3.fromRGB(115, 215, 255),
		Damage = 12,
		DrillPower = 4,
		DrillSpeed = 1.22,
		YieldMult = 1.22,
		GemMult = 1.08,
		SpeedBonus = 0.03,
	},
	BioScout = {
		Id = "BioScout",
		Name = "Gaia Spore Harvester",
		Rarity = "Uncommon",
		Icon = "🌿",
		Color = Color3.fromRGB(75, 235, 130),
		BeamColor = Color3.fromRGB(95, 255, 145),
		Damage = 15,
		DrillPower = 5,
		DrillSpeed = 1.30,
		YieldMult = 1.32,
		GemMult = 1.12,
		SpeedBonus = 0.04,
	},
	QuartzCutter = {
		Id = "QuartzCutter",
		Name = "Quartz Twin-Cutter",
		Rarity = "Uncommon",
		Icon = "💠",
		Color = Color3.fromRGB(95, 225, 210),
		BeamColor = Color3.fromRGB(75, 245, 235),
		Damage = 18,
		DrillPower = 7,
		DrillSpeed = 1.36,
		YieldMult = 1.42,
		GemMult = 1.16,
		SpeedBonus = 0.05,
	},
	SolarRelay = {
		Id = "SolarRelay",
		Name = "Helios Prism Drone",
		Rarity = "Rare",
		Icon = "☀️",
		Color = Color3.fromRGB(255, 200, 65),
		BeamColor = Color3.fromRGB(255, 215, 75),
		Damage = 23,
		DrillPower = 10,
		DrillSpeed = 1.45,
		YieldMult = 1.58,
		GemMult = 1.24,
		SpeedBonus = 0.06,
	},
	CryoSentinel = {
		Id = "CryoSentinel",
		Name = "Cryo-Lance Sentinel",
		Rarity = "Rare",
		Icon = "❄️",
		Color = Color3.fromRGB(85, 225, 255),
		BeamColor = Color3.fromRGB(95, 235, 255),
		Damage = 27,
		DrillPower = 13,
		DrillSpeed = 1.54,
		YieldMult = 1.75,
		GemMult = 1.32,
		SpeedBonus = 0.08,
	},
	PulsarValkyrie = {
		Id = "PulsarValkyrie",
		Name = "Pulsar Valkyrie Striker",
		Rarity = "Epic",
		Icon = "⚡",
		Color = Color3.fromRGB(255, 110, 65),
		BeamColor = Color3.fromRGB(255, 115, 55),
		Damage = 34,
		DrillPower = 18,
		DrillSpeed = 1.68,
		YieldMult = 2.05,
		GemMult = 1.48,
		SpeedBonus = 0.11,
	},
	DarkMatterCherub = {
		Id = "DarkMatterCherub",
		Name = "Void-Rift Excavator",
		Rarity = "Epic",
		Icon = "🌌",
		Color = Color3.fromRGB(195, 85, 250),
		BeamColor = Color3.fromRGB(205, 95, 255),
		Damage = 40,
		DrillPower = 24,
		DrillSpeed = 1.78,
		YieldMult = 2.35,
		GemMult = 1.65,
		SpeedBonus = 0.13,
	},
	-- LEGENDARY DRONES (Dramatically stronger!)
	QuantumSeraph = {
		Id = "QuantumSeraph",
		Name = "Quantum Seraph Arbiter",
		Rarity = "Legendary",
		Icon = "🔮",
		Color = Color3.fromRGB(165, 125, 255),
		BeamColor = Color3.fromRGB(175, 135, 255),
		Damage = 115,
		DrillPower = 65,
		DrillSpeed = 2.40,
		YieldMult = 4.80,
		GemMult = 2.50,
		SpeedBonus = 0.20,
	},
	ChronosDragon = {
		Id = "ChronosDragon",
		Name = "Chronos Wyrm Dreadnought",
		Rarity = "Legendary",
		Icon = "🐉",
		Color = Color3.fromRGB(255, 195, 55),
		BeamColor = Color3.fromRGB(255, 215, 65),
		Damage = 175,
		DrillPower = 110,
		DrillSpeed = 2.75,
		YieldMult = 7.50,
		GemMult = 3.40,
		SpeedBonus = 0.26,
	},
	-- MYTHIC DRONES (Apex God-Tier — far above everything else!)
	OmniverseEye = {
		Id = "OmniverseEye",
		Name = "Omniverse Dyson Seraph",
		Rarity = "Mythic",
		Icon = "👁️",
		Color = Color3.fromRGB(255, 240, 105),
		BeamColor = Color3.fromRGB(255, 245, 135),
		Damage = 460,
		DrillPower = 340,
		DrillSpeed = 3.50,
		YieldMult = 18.0,
		GemMult = 6.50,
		SpeedBonus = 0.36,
	},
	SingularityArchon = {
		Id = "SingularityArchon",
		Name = "Singularity Star-Eater",
		Rarity = "Mythic",
		Icon = "✴️",
		Color = Color3.fromRGB(255, 65, 115),
		BeamColor = Color3.fromRGB(255, 75, 125),
		Damage = 920,
		DrillPower = 750,
		DrillSpeed = 4.20,
		YieldMult = 36.0,
		GemMult = 11.0,
		SpeedBonus = 0.45,
	},
}

-- Compute effective Drone stats at a given Level (1..25) and Golden fusion state
function PlanetConfig.GetDroneStats(droneId: string, level: number?, isGolden: boolean?)
	local base = PlanetConfig.Companions[droneId] or PlanetConfig.Companions.ScrapWelder
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, PlanetConfig.MaxDroneLevel)
	local goldMult = isGolden and 1.85 or 1.0
	local lvStatMult = (1 + (lv - 1) * 0.18) * goldMult
	local lvSpeedMult = (1 + (lv - 1) * 0.035) * (isGolden and 1.15 or 1.0)
	local lvYieldMult = 1 + (base.YieldMult - 1) * (1 + (lv - 1) * 0.14) * goldMult
	local lvGemMult = 1 + (base.GemMult - 1) * (1 + (lv - 1) * 0.12) * goldMult

	return {
		Damage = math.floor(base.Damage * lvStatMult + 0.5),
		DrillPower = math.floor(base.DrillPower * lvStatMult + 0.5),
		DrillSpeed = tonumber(string.format("%.2f", base.DrillSpeed * lvSpeedMult)) or base.DrillSpeed,
		YieldMult = tonumber(string.format("%.2f", lvYieldMult)) or base.YieldMult,
		GemMult = tonumber(string.format("%.2f", lvGemMult)) or base.GemMult,
		SpeedBonus = base.SpeedBonus * (isGolden and 1.35 or 1.0),
		Level = lv,
	}
end

-- Resource cost to level up a drone from currentLevel -> currentLevel + 1
function PlanetConfig.GetDroneLevelUpCost(droneId: string, currentLevel: number): { [string]: number }
	local base = PlanetConfig.Companions[droneId] or PlanetConfig.Companions.ScrapWelder
	local rMeta = PlanetConfig.DroneRarities[base.Rarity] or PlanetConfig.DroneRarities.Common
	local lv = math.clamp(math.floor(tonumber(currentLevel) or 1), 1, PlanetConfig.MaxDroneLevel)
	local scale = math.pow(1.36, lv - 1) * rMeta.LevelCostMult
	local cost: { [string]: number } = {
		Minerals = math.max(15, math.floor(20 * scale)),
		Energy = math.max(10, math.floor(14 * scale)),
	}
	if lv >= 4 or rMeta.Order >= 3 then
		cost.Biomass = math.max(10, math.floor(12 * scale))
	end
	if lv >= 8 or rMeta.Order >= 4 then
		cost.Tech = math.max(8, math.floor(10 * scale))
	end
	return cost
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
	{ Id = 1, TimeReq = 60, Label = "1 Min Gift", RewardText = "+40 Ore & +25 Gems", Gems = 25, Resources = { Minerals = 40 } },
	{ Id = 2, TimeReq = 180, Label = "3 Min Gift", RewardText = "+80 Flux & 5m Speed Boost", Gems = 60, Resources = { Energy = 80 }, BoosterId = "SpeedBoost", BoosterSecs = 300 },
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
		Description = "Fly near or click on Titanium Ore Asteroids in Zone 1 to drill and destroy 2 space nodes.",
		GoalType = "OrbsHarvested",
		Target = 2,
		Reward = { Gems = 15, Resources = { Minerals = 30, Energy = 15 } },
	},
	{
		Id = 2,
		Title = "Roll Your First Drone",
		Description = "Visit the Orbital Drone Foundry on the East Hub Plaza (or click DRONES) and roll a Tier 1 Drone for 25 Ore.",
		GoalType = "DronesHatched",
		Target = 1,
		Reward = { Gems = 40, Resources = { Minerals = 60, Energy = 45 } },
	},
	{
		Id = 3,
		Title = "Level Up a Drone",
		Description = "Open the DRONES menu, select an equipped drone, and Level It Up using harvested space resources.",
		GoalType = "DroneLevels",
		Target = 1,
		Reward = { Gems = 75, Resources = { Minerals = 120, Biomass = 80 } },
	},
	{
		Id = 4,
		Title = "First Planetary Upgrade",
		Description = "Open UPGRADES on the left command dock and upgrade any Planet System to Level 1.",
		GoalType = "TotalUpgrades",
		Target = 1,
		Reward = { Gems = 110, Resources = { Energy = 150, Tech = 90 } },
	},
	{
		Id = 5,
		Title = "Unlock Station 1 Warp Gate",
		Description = "Fly to Station 1 (-1,850 Z) or open STATIONS and spend 100 Gems to unlock the Belt Outpost Warp Gate.",
		GoalType = "StationsUnlocked",
		Target = 1,
		Reward = { Gems = 220, Resources = { Minerals = 350, Energy = 250 } },
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
