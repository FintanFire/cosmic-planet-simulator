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
-- DISTANCE-TIERED DEEP SPACE ZONES (Gem & Node Yields Upgrade With Distance!)
-- ============================================================================
PlanetConfig.DeepSpaceZones = {
	{
		Tier = 1,
		Id = "InnerOrbit",
		Name = "Zone 1: Inner Sanctuary Orbit",
		MinDist = 0,
		MaxDist = 1400,
		ReqDrill = 0,
		YieldMultiplier = 1.0,
		BaseNodeValue = 18,
		GemRange = { 1, 3 },
		ScaleMod = 1.0,
		ThemeColor = Color3.fromRGB(110, 220, 255),
		RockMat = "Rock",
		AccentMat = "Limestone",
		NodeNames = {
			StarGems = "Quartz Star-Gem Cluster",
			PopulationPod = "Colonial Lifeboat Pod",
			SupernovaChest = "Orbital Supply Cache",
		},
	},
	{
		Tier = 2,
		Id = "GoldenBelt",
		Name = "Zone 2: Golden Asteroid Belt",
		MinDist = 1400,
		MaxDist = 3500,
		ReqDrill = 0,
		YieldMultiplier = 3.8,
		BaseNodeValue = 75,
		GemRange = { 4, 8 },
		ScaleMod = 1.18,
		ThemeColor = Color3.fromRGB(255, 195, 55),
		RockMat = "Sandstone",
		AccentMat = "Limestone",
		NodeNames = {
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
		ReqDrill = 0,
		YieldMultiplier = 15.0,
		BaseNodeValue = 320,
		GemRange = { 10, 20 },
		ScaleMod = 1.35,
		ThemeColor = Color3.fromRGB(85, 245, 225),
		RockMat = "Glacier",
		AccentMat = "Snow",
		NodeNames = {
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
		ReqDrill = 0,
		YieldMultiplier = 65.0,
		BaseNodeValue = 1450,
		GemRange = { 25, 50 },
		ScaleMod = 1.52,
		ThemeColor = Color3.fromRGB(255, 105, 65),
		RockMat = "Basalt",
		AccentMat = "CrackedLava",
		NodeNames = {
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
		ReqDrill = 0,
		YieldMultiplier = 300.0,
		BaseNodeValue = 7200,
		GemRange = { 65, 130 },
		ScaleMod = 1.70,
		ThemeColor = Color3.fromRGB(195, 95, 255),
		RockMat = "Slate",
		AccentMat = "Basalt",
		NodeNames = {
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
		ReqDrill = 0,
		YieldMultiplier = 1500.0,
		BaseNodeValue = 40000,
		GemRange = { 180, 380 },
		ScaleMod = 1.90,
		ThemeColor = Color3.fromRGB(255, 235, 95),
		RockMat = "Limestone",
		AccentMat = "Glacier",
		NodeNames = {
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
-- CHALLENGING PROGRESSION 3: HUB WARP GATE
-- ============================================================================
PlanetConfig.HubMachines = {
	WarpGate = {
		Id = "WarpGate",
		Name = "🌀 Starfarer Warp Gate & Station Network",
		ShortTitle = "WARP GATE",
		Icon = "🌀",
		Position = Vector3.new(-420, 18, 0),
		InteractRadius = 115,
		ThemeColor = Color3.fromRGB(205, 95, 255),
		Subtitle = "Unlock Deep-Space Station Warp Gates with 💎 Star Gems, Track Stations in 3D, or Ascend for 🪐 Cosmic Shards!",
	},
}

-- ============================================================================
-- SIMULATOR SYSTEM 4: 🛸 ORBITAL COMPANIONS / DRONES GACHA (Pets/Satellites!)
-- ============================================================================
PlanetConfig.CompanionPods = {
	{
		Id = "LunarPod",
		Name = "🛰️ Tier 1: Lunar Probe Pod",
		GemCost = 75,
		Description = "Hatches starter orbital satellites that circle your planet and multiply Star Gem & Value yields!",
		Color = Color3.fromRGB(85, 195, 255),
		Pool = {
			{ Id = "SputnikMiner", Weight = 55 },
			{ Id = "BioScout", Weight = 32 },
			{ Id = "SolarRelay", Weight = 13 },
		},
	},
	{
		Id = "NebulaPod",
		Name = "🌸 Tier 2: Cryo-Nebula Pod",
		GemCost = 400,
		Description = "Hatches advanced deep-space drones with high Planet Value & 💎 Star Gem multipliers!",
		Color = Color3.fromRGB(85, 245, 185),
		Pool = {
			{ Id = "CryoSentinel", Weight = 55 },
			{ Id = "PulsarValkyrie", Weight = 33 },
			{ Id = "QuantumSeraph", Weight = 12 },
		},
	},
	{
		Id = "SingularityPod",
		Name = "🌌 Tier 3: Singularity Omega Pod",
		GemCost = 2000,
		Description = "Hatches apex cosmic guardians with massive All-Yield, Gem & Flight Speed multipliers!",
		Color = Color3.fromRGB(215, 95, 255),
		Pool = {
			{ Id = "DarkMatterCherub", Weight = 58 },
			{ Id = "ChronosDragon", Weight = 32 },
			{ Id = "OmniverseEye", Weight = 10 },
		},
	},
}

PlanetConfig.Companions = {
	SputnikMiner = {
		Id = "SputnikMiner",
		Name = "Iron Sputnik Probe",
		Rarity = "Common",
		Icon = "🛰️",
		Color = Color3.fromRGB(185, 195, 215),
		YieldMult = 1.25,
		GemMult = 1.05,
		SpeedBonus = 0.02,
	},
	BioScout = {
		Id = "BioScout",
		Name = "Gaia Spore-Drone",
		Rarity = "Uncommon",
		Icon = "🌿",
		Color = Color3.fromRGB(85, 235, 125),
		YieldMult = 1.50,
		GemMult = 1.12,
		SpeedBonus = 0.04,
	},
	SolarRelay = {
		Id = "SolarRelay",
		Name = "Helios Prism Cube",
		Rarity = "Rare",
		Icon = "☀️",
		Color = Color3.fromRGB(255, 205, 65),
		YieldMult = 1.90,
		GemMult = 1.25,
		SpeedBonus = 0.06,
	},
	CryoSentinel = {
		Id = "CryoSentinel",
		Name = "Cryo-Crystal Sentinel",
		Rarity = "Rare",
		Icon = "❄️",
		Color = Color3.fromRGB(95, 235, 255),
		YieldMult = 2.40,
		GemMult = 1.35,
		SpeedBonus = 0.08,
	},
	PulsarValkyrie = {
		Id = "PulsarValkyrie",
		Name = "Pulsar Valkyrie Wing",
		Rarity = "Epic",
		Icon = "⚡",
		Color = Color3.fromRGB(255, 115, 65),
		YieldMult = 3.50,
		GemMult = 1.60,
		SpeedBonus = 0.12,
	},
	QuantumSeraph = {
		Id = "QuantumSeraph",
		Name = "Quantum Seraph Orb",
		Rarity = "Legendary",
		Icon = "🔮",
		Color = Color3.fromRGB(165, 125, 255),
		YieldMult = 5.50,
		GemMult = 2.00,
		SpeedBonus = 0.16,
	},
	DarkMatterCherub = {
		Id = "DarkMatterCherub",
		Name = "Void-Rift Guardian",
		Rarity = "Epic",
		Icon = "🌌",
		Color = Color3.fromRGB(195, 75, 245),
		YieldMult = 7.00,
		GemMult = 2.30,
		SpeedBonus = 0.18,
	},
	ChronosDragon = {
		Id = "ChronosDragon",
		Name = "Chronos Wyrm Satellite",
		Rarity = "Legendary",
		Icon = "🐉",
		Color = Color3.fromRGB(255, 195, 55),
		YieldMult = 12.0,
		GemMult = 3.20,
		SpeedBonus = 0.25,
	},
	OmniverseEye = {
		Id = "OmniverseEye",
		Name = "Omniverse Dyson Seraph",
		Rarity = "Mythic",
		Icon = "👁️",
		Color = Color3.fromRGB(255, 245, 115),
		YieldMult = 25.0,
		GemMult = 5.00,
		SpeedBonus = 0.35,
	},
}

-- ============================================================================
-- SIMULATOR SYSTEM 5: ⚡ ACTIVE TIMED BOOSTERS, PLAYTIME GIFTS, CODES & SHARD SHOP
-- ============================================================================
PlanetConfig.Boosters = {
	{
		Id = "YieldBoost",
		Name = "⚡ 2x All Yields",
		ShortTag = "2x YIELDS",
		Icon = "⚡",
		Duration = 900, -- 15 minutes
		GemCost = 90,
		Color = Color3.fromRGB(255, 205, 55),
		Description = "Doubles ALL passive Star Gems, Citizen growth, and Planet Value yields for 15 minutes!",
	},
	{
		Id = "GemBoost",
		Name = "💎 2x Star Gem Drops",
		ShortTag = "2x GEMS",
		Icon = "💎",
		Duration = 900,
		GemCost = 110,
		Color = Color3.fromRGB(85, 225, 255),
		Description = "Doubles all 💎 Star Gem drops from space crystal nodes, chests, and anomalies for 15 minutes!",
	},
	{
		Id = "SpeedBoost",
		Name = "🚀 Hyper-Drive Overdrive (+60% Speed)",
		ShortTag = "+60% SPEED",
		Icon = "🚀",
		Duration = 900,
		GemCost = 65,
		Color = Color3.fromRGB(95, 250, 145),
		Description = "Boosts your planet's flight speed by +60% for 15 minutes so you can reach distant Space Stations fast!",
	},
}

PlanetConfig.PlaytimeRewards = {
	{ Id = 1, TimeReq = 60, Label = "1 Min Gift", RewardText = "+75 💎 Star Gems", Gems = 75 },
	{ Id = 2, TimeReq = 180, Label = "3 Min Gift", RewardText = "+120 💎 Gems & 5m Speed Boost", Gems = 120, BoosterId = "SpeedBoost", BoosterSecs = 300 },
	{ Id = 3, TimeReq = 360, Label = "6 Min Gift", RewardText = "+220 💎 Gems & 10m 2x Yields", Gems = 220, BoosterId = "YieldBoost", BoosterSecs = 600 },
	{ Id = 4, TimeReq = 720, Label = "12 Min Gift", RewardText = "+450 💎 Gems & 10m 2x Gems", Gems = 450, BoosterId = "GemBoost", BoosterSecs = 600 },
	{ Id = 5, TimeReq = 1200, Label = "20 Min Gift", RewardText = "+900 💎 Gems & 15m 2x Yields", Gems = 900, BoosterId = "YieldBoost", BoosterSecs = 900 },
	{ Id = 6, TimeReq = 1800, Label = "30 Min Jackpot", RewardText = "+2,500 💎 Gems & All Boosts!", Gems = 2500, AllBoostSecs = 900 },
}

PlanetConfig.PromoCodes = {
	COSMIC2026 = { Gems = 250, Desc = "+250 💎 Star Gems" },
	STARFARER = { Gems = 200, BoosterId = "SpeedBoost", BoosterSecs = 600, Desc = "+200 💎 Star Gems & 10m Hyper-Drive Boost" },
	GALAXY = { Gems = 250, BoosterId = "YieldBoost", BoosterSecs = 600, Desc = "+250 💎 Star Gems & 10m 2x Yield Boost" },
	GEMS500 = { Gems = 500, Desc = "+500 💎 Star Gems" },
}

PlanetConfig.ShardUpgrades = {
	{
		Id = "PermValue",
		Name = "★ Precursor Core Matrix (+50% Planet Value / Lv)",
		Description = "Permanently increases your Planet Value Score by +50% per level (persists through Ascensions!).",
		BaseShardCost = 1,
		CostScale = 2.0,
		MaxLevel = 15,
	},
	{
		Id = "PermGems",
		Name = "💎 Astral Gem Harvester (+50% Star Gems / Lv)",
		Description = "Permanently increases all 💎 Star Gem drops and income by +50% per level!",
		BaseShardCost = 1,
		CostScale = 1.8,
		MaxLevel = 20,
	},
	{
		Id = "ExtraDroneSlots",
		Name = "🛸 Drone Fleet Command (+1 Max Equipped Drone / Lv)",
		Description = "Increases your maximum equipped Orbital Companions from 3 up to 6!",
		BaseShardCost = 2,
		CostScale = 3.0,
		MaxLevel = 3,
	},
	{
		Id = "PermSpeed",
		Name = "🚀 Warp-Slipstream Hull (+25% Flight Speed / Lv)",
		Description = "Permanently increases your planet's flight speed by +25% per level!",
		BaseShardCost = 1,
		CostScale = 1.8,
		MaxLevel = 10,
	},
}

-- ============================================================================
-- GUIDED MISSIONS (Gems, Drones, Evolution & Space Stations!)
-- ============================================================================
PlanetConfig.Missions = {
	{
		Id = 1,
		Title = "First Planetary Upgrade",
		Description = "Click ⬆️ UPGRADE on the bottom bar and upgrade any Planet System to Level 1.",
		GoalType = "TotalUpgrades",
		Target = 1,
		Reward = { Gems = 50 },
	},
	{
		Id = 2,
		Title = "Cosmic Collector",
		Description = "Fly out into Zone 1 and harvest 4 space collectibles (Star-Gem Clusters, Lifeboat Pods, or Supply Caches).",
		GoalType = "OrbsHarvested",
		Target = 4,
		Reward = { Gems = 85 },
	},
	{
		Id = 3,
		Title = "Hatch an Orbital Drone",
		Description = "Click 🛸 DRONES on the bottom bar and hatch your first Lunar Probe Pod (75 💎 Gems)!",
		GoalType = "DronesHatched",
		Target = 1,
		Reward = { Gems = 120 },
	},
	{
		Id = 4,
		Title = "Unlock Space Station 1 Warp Gate",
		Description = "Fly to Station 1 (-1,850 Z) or open 🌀 STATIONS and spend 100 💎 Gems to unlock the Belt Outpost Warp Gate!",
		GoalType = "StationsUnlocked",
		Target = 1,
		Reward = { Gems = 220 },
	},
	{
		Id = 5,
		Title = "Dawn of Evolution",
		Description = "Click 🧬 EVOLVE and unlock your first Tier 1 Species Evolution.",
		GoalType = "UnlockedEvolutions",
		Target = 2,
		Reward = { Gems = 350 },
	},
	{
		Id = 6,
		Title = "Unlock Space Station 2 (Cryo-Nebula)",
		Description = "Unlock Station 2: Cryo-Nebula Citadel Warp Gate (450 💎 Gems)!",
		GoalType = "StationsUnlocked",
		Target = 2,
		Reward = { Gems = 750 },
	},
	{
		Id = 7,
		Title = "Sovereign Star-World",
		Description = "Reach 32,000+ Planet Value Score (Rank 4: Sovereign Star-World) to unlock Planetary Ascension!",
		GoalType = "PlanetValue",
		Target = 32000,
		Reward = { Gems = 1500 },
	},
	{
		Id = 8,
		Title = "Unlock Space Station 3 (Pulsar Starbase)",
		Description = "Unlock Station 3: Hyper-Pulsar Relay Starbase (1,800 💎 Gems)!",
		GoalType = "StationsUnlocked",
		Target = 3,
		Reward = { Gems = 3500 },
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
