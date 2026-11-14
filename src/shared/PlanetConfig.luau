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
-- EXPONENTIAL PROGRESSION 1: 10 PLANETARY ERAS / RANKS
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
		MinValue = 400,
		YieldMultiplier = 1.5,
		SizeBonus = 0.08,
		BadgeColor = Color3.fromRGB(95, 235, 145),
		RewardDesc = "1.5x All Yields & +8% Planet Scale",
	},
	{
		Rank = 3,
		Title = "Thriving Biosphere",
		MinValue = 1500,
		YieldMultiplier = 2.5,
		SizeBonus = 0.16,
		BadgeColor = Color3.fromRGB(0, 225, 255),
		RewardDesc = "2.5x All Yields & +16% Planet Scale",
	},
	{
		Rank = 4,
		Title = "Sovereign Star-World",
		MinValue = 6000,
		YieldMultiplier = 4.5,
		SizeBonus = 0.25,
		BadgeColor = Color3.fromRGB(195, 110, 255),
		RewardDesc = "4.5x Yields & Unlocks Planetary Ascension!",
	},
	{
		Rank = 5,
		Title = "Galactic Ecumenopolis",
		MinValue = 25000,
		YieldMultiplier = 9.0,
		SizeBonus = 0.36,
		BadgeColor = Color3.fromRGB(255, 195, 55),
		RewardDesc = "9.0x All Yields & +36% Planet Scale",
	},
	{
		Rank = 6,
		Title = "Dyson Super-World",
		MinValue = 120000,
		YieldMultiplier = 20.0,
		SizeBonus = 0.48,
		BadgeColor = Color3.fromRGB(255, 105, 55),
		RewardDesc = "20x All Yields & +48% Planet Scale",
	},
	{
		Rank = 7,
		Title = "Celestial Titan",
		MinValue = 600000,
		YieldMultiplier = 50.0,
		SizeBonus = 0.62,
		BadgeColor = Color3.fromRGB(255, 75, 195),
		RewardDesc = "50x All Yields & +62% Planet Scale",
	},
	{
		Rank = 8,
		Title = "Astral Hyper-Sphere",
		MinValue = 3500000,
		YieldMultiplier = 140.0,
		SizeBonus = 0.78,
		BadgeColor = Color3.fromRGB(85, 255, 220),
		RewardDesc = "140x All Yields & +78% Planet Scale",
	},
	{
		Rank = 9,
		Title = "Galactic Overlord",
		MinValue = 25000000,
		YieldMultiplier = 450.0,
		SizeBonus = 0.95,
		BadgeColor = Color3.fromRGB(255, 85, 95),
		RewardDesc = "450x All Yields & +95% Planet Scale",
	},
	{
		Rank = 10,
		Title = "Omniverse Singularity",
		MinValue = 200000000,
		YieldMultiplier = 1500.0,
		SizeBonus = 1.15,
		BadgeColor = Color3.fromRGB(255, 245, 115),
		RewardDesc = "1,500x All Yields & Colossal Apex Scale!",
	},
}

-- ============================================================================
-- EXPONENTIAL PROGRESSION 2: 6 PLANET UPGRADE TRACKS (Compound 1.42^lvl!)
-- ============================================================================
PlanetConfig.PlanetUpgrades = {
	{
		Id = "CoreDensity",
		Name = "⛏ Enrich Core Mass & Scale",
		Description = "Compounds your planet's Mineral output by 1.42x per level and expands physical diameter.",
		BaseCost = { Minerals = 40, Energy = 20 },
		CostScale = 1.52,
		MaxLevel = 50,
	},
	{
		Id = "BiosphereFertility",
		Name = "🌿 Cultivate Surface Biosphere",
		Description = "Compounds Biomass output by 1.42x per level and accelerates citizen population growth.",
		BaseCost = { Biomass = 40, Minerals = 20 },
		CostScale = 1.52,
		MaxLevel = 50,
	},
	{
		Id = "MagnetosphereDynamo",
		Name = "⚡ Supercharge Dynamo Thrusters",
		Description = "Compounds Energy output by 1.42x per level and boosts space flight velocity.",
		BaseCost = { Energy = 45, Minerals = 25 },
		CostScale = 1.52,
		MaxLevel = 50,
	},
	{
		Id = "OrbitalInfrastructure",
		Name = "🔬 Construct Orbital Ring-Forges",
		Description = "Compounds Tech output by 1.45x per level and adds high-value orbital infrastructure.",
		BaseCost = { Tech = 35, Minerals = 35, Energy = 30 },
		CostScale = 1.54,
		MaxLevel = 50,
	},
	{
		Id = "CivilizationMetropolis",
		Name = "🏙️ Expand Surface Megacities",
		Description = "Compounds ALL 4 Resource Yields by 1.35x per level across your entire civilization!",
		BaseCost = { Minerals = 60, Biomass = 60, Energy = 50 },
		CostScale = 1.58,
		MaxLevel = 50,
	},
	{
		Id = "AnomalyHarvester",
		Name = "🧲 Gravitational Tractor Beam",
		Description = "Expands Cosmic Collectible pull radius and compounds space orb jackpot rewards by 1.45x per level!",
		BaseCost = { Energy = 55, Tech = 45 },
		CostScale = 1.55,
		MaxLevel = 40,
	},
}

-- ============================================================================
-- EXPONENTIAL PROGRESSION 3: 6 INTERACTIVE HUB MACHINES & DEEP-SPACE WARPS
-- ============================================================================
PlanetConfig.HubMachines = {
	DysonReactor = {
		Id = "DysonReactor",
		Name = "⚡ Dyson Star-Reactor Overcharger",
		ShortTitle = "REACTOR",
		Icon = "⚡",
		Position = Vector3.new(0, 28, 0),
		InteractRadius = 115,
		ThemeColor = Color3.fromRGB(0, 235, 255),
		Subtitle = "Harness the central Dyson Star to multiply ALL Planetary Energy & Resource Yields exponentially!",
		ActionButtonText = "⚡ OVERCHARGE DYSON REACTOR (1.65x Energy & 1.25x All Yields / Tier)",
		BaseCost = { Energy = 120, Tech = 60 },
		CostScale = 1.85,
		MaxTier = 30,
	},
	TitanRefinery = {
		Id = "TitanRefinery",
		Name = "⚒️ Titan Matter-Refinery & Core Forge",
		ShortTitle = "REFINERY",
		Icon = "⚒️",
		Position = Vector3.new(420, 18, 0),
		InteractRadius = 110,
		ThemeColor = Color3.fromRGB(255, 165, 45),
		Subtitle = "Smelt raw planetary crust into hyper-dense Core Alloys for 1.75x Minerals & +Planet Size per Tier!",
		ActionButtonText = "⚒️ FORGE TITAN CORE ALLOY (1.75x Minerals & +Size / Tier)",
		BaseCost = { Minerals = 140, Energy = 80 },
		CostScale = 1.85,
		MaxTier = 30,
	},
	GaiaBioVat = {
		Id = "GaiaBioVat",
		Name = "🌿 Gaia Bio-Synthesizer & Cloning Vat",
		ShortTitle = "BIO-VAT",
		Icon = "🌿",
		Position = Vector3.new(0, 18, 420),
		InteractRadius = 110,
		ThemeColor = Color3.fromRGB(75, 250, 135),
		Subtitle = "Clone massive waves of Citizens (+60% Population Boom per batch) and multiply Biomass by 1.70x!",
		ActionButtonText = "🌿 SYNTHESIZE CLONE WAVE (+60% Population Boom & 1.70x Biomass)",
		BaseCost = { Biomass = 140, Energy = 70 },
		CostScale = 1.80,
		MaxTier = 30,
	},
	AstralObservatory = {
		Id = "AstralObservatory",
		Name = "🔭 Astral Quantum Observatory",
		ShortTitle = "TECH LAB",
		Icon = "🔭",
		Position = Vector3.new(0, 18, -420),
		InteractRadius = 110,
		ThemeColor = Color3.fromRGB(130, 210, 255),
		Subtitle = "Chart deep-space anomalies and unlock Quantum Computing Tiers for 1.80x Tech & +25% All Yields!",
		ActionButtonText = "🔭 RESEARCH QUANTUM BREAKTHROUGH (1.80x Tech & 1.25x All Yields)",
		BaseCost = { Tech = 110, Minerals = 90 },
		CostScale = 1.88,
		MaxTier = 30,
	},
	WarpGate = {
		Id = "WarpGate",
		Name = "🌀 Starfarer Warp Gate & Ascension Nexus",
		ShortTitle = "WARP GATE",
		Icon = "🌀",
		Position = Vector3.new(-420, 18, 0),
		InteractRadius = 115,
		ThemeColor = Color3.fromRGB(205, 95, 255),
		Subtitle = "Warp to Deep-Space Sectors for up to 250x Collectible Jackpots or Ascend your Planet for 3x Permanent Multipliers!",
	},
}

PlanetConfig.WarpSectors = {
	{
		Id = "Hub",
		Name = "★ Galactic Nexus Hub (Sanctuary)",
		Position = Vector3.new(0, 45, 220),
		RewardMultiplier = 1.0,
		MinValueReq = 0,
		Description = "Safe central megastructure in space (+50% Passive Yield & 6 Interactive Machines).",
		Color = Color3.fromRGB(0, 235, 255),
	},
	{
		Id = "AsteroidBelt",
		Name = "☄️ Sector 1: Golden Asteroid Belt",
		Position = Vector3.new(0, 60, -1400),
		RewardMultiplier = 3.5,
		MinValueReq = 0,
		Description = "Rich procedural asteroid fields & crystal geodes (3.5x Collectible Rewards!).",
		Color = Color3.fromRGB(255, 195, 55),
	},
	{
		Id = "NebulaFrontier",
		Name = "🌸 Sector 2: Bioluminescent Nebula",
		Position = Vector3.new(2600, 120, -2600),
		RewardMultiplier = 12.0,
		MinValueReq = 1200,
		Description = "Dense living spore-clouds, stranded ark-pods & pulsars (12x Collectible Rewards!).",
		Color = Color3.fromRGB(85, 255, 165),
	},
	{
		Id = "PulsarExpanse",
		Name = "⚡ Sector 3: Hyper-Pulsar Expanse",
		Position = Vector3.new(-4500, 180, -4500),
		RewardMultiplier = 45.0,
		MinValueReq = 15000,
		Description = "High-energy neutron stars & precursor satellites (45x Collectible Rewards!).",
		Color = Color3.fromRGB(110, 215, 255),
	},
	{
		Id = "SingularityDeep",
		Name = "🌌 Sector 4: Abyssal Singularity Core",
		Position = Vector3.new(0, 240, -8000),
		RewardMultiplier = 200.0,
		MinValueReq = 150000,
		Description = "Ultra-deep cosmic frontier teeming with Dark-Matter Shards & Supernova Chests (200x Rewards!).",
		Color = Color3.fromRGB(215, 95, 255),
	},
}

-- ============================================================================
-- EXPONENTIAL PROGRESSION 4: GUIDED MISSIONS
-- ============================================================================
PlanetConfig.Missions = {
	{
		Id = 1,
		Title = "First Planetary Upgrade",
		Description = "Click UPGRADE on the bottom bar and upgrade any Planet System to Level 1.",
		GoalType = "TotalUpgrades",
		Target = 1,
		Reward = { Minerals = 180, Biomass = 180, Energy = 150, Tech = 120 },
	},
	{
		Id = 2,
		Title = "Activate a Hub Machine",
		Description = "Open any Hub Machine (⚡ REACTOR, ⚒️ REFINERY, 🌿 BIO-VAT, or 🔭 TECH LAB) and upgrade it once.",
		GoalType = "TotalMachineTiers",
		Target = 1,
		Reward = { Minerals = 350, Biomass = 350, Energy = 300, Tech = 250 },
	},
	{
		Id = 3,
		Title = "Cosmic Collector",
		Description = "Fly into 3 glowing space collectibles (Asteroids, Pulsars, Satellites, or Pods).",
		GoalType = "OrbsHarvested",
		Target = 3,
		Reward = { Minerals = 650, Biomass = 650, Energy = 550, Tech = 450 },
	},
	{
		Id = 4,
		Title = "Dawn of Evolution",
		Description = "Click 🧬 EVOLVE and unlock your first Tier 1 Species Evolution.",
		GoalType = "UnlockedEvolutions",
		Target = 2,
		Reward = { Minerals = 1200, Biomass = 1200, Energy = 1000, Tech = 850 },
	},
	{
		Id = 5,
		Title = "Expanding Systems",
		Description = "Reach 6 Total Planet Upgrade Levels across your planet systems.",
		GoalType = "TotalUpgrades",
		Target = 6,
		Reward = { Minerals = 2500, Biomass = 2500, Energy = 2200, Tech = 1800 },
	},
	{
		Id = 6,
		Title = "Master of Machines",
		Description = "Reach 4 Total Machine Tiers across the Hub's specialized machines.",
		GoalType = "TotalMachineTiers",
		Target = 4,
		Reward = { Minerals = 5500, Biomass = 5500, Energy = 4800, Tech = 4000 },
	},
	{
		Id = 7,
		Title = "Sovereign Star-World",
		Description = "Reach 6,000+ Planet Value Score (Rank 4: Sovereign Star-World).",
		GoalType = "PlanetValue",
		Target = 6000,
		Reward = { Minerals = 12000, Biomass = 12000, Energy = 10000, Tech = 9000 },
	},
	{
		Id = 8,
		Title = "Deep Space Explorer",
		Description = "Collect 10 total space anomalies or chests across procedural space.",
		GoalType = "OrbsHarvested",
		Target = 10,
		Reward = { Minerals = 28000, Biomass = 28000, Energy = 24000, Tech = 20000 },
	},
	{
		Id = 9,
		Title = "Galactic Ecumenopolis",
		Description = "Reach 25,000+ Planet Value Score (Rank 5).",
		GoalType = "PlanetValue",
		Target = 25000,
		Reward = { Minerals = 75000, Biomass = 75000, Energy = 65000, Tech = 55000 },
	},
	{
		Id = 10,
		Title = "Dyson Super-World",
		Description = "Reach 120,000+ Planet Value Score (Rank 6).",
		GoalType = "PlanetValue",
		Target = 120000,
		Reward = { Minerals = 250000, Biomass = 250000, Energy = 220000, Tech = 180000 },
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
