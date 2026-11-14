--!strict
local SpeciesConfig = {}

export type ResourceMultipliers = {
	Minerals: number,
	Biomass: number,
	Energy: number,
	Tech: number,
	PopGrowth: number,
	FlightSpeed: number,
}

export type EvolutionNode = {
	Id: string,
	Name: string,
	Tier: number,
	Branch: string, -- "Root" | "Industrial" | "BioHarmony" | "Psionic" | "Warforge"
	ParentId: string?,
	Description: string,
	PerkSummary: string,
	Cost: {
		Gems: number?,
		Minerals: number?,
		Biomass: number?,
		Energy: number?,
		Tech: number?,
	},
	Multipliers: ResourceMultipliers,
	VisualTrait: {
		CityStyle: string, -- "Primitive" | "Factory" | "BioDome" | "Spire" | "Fortress"
		GlowColor: Color3,
		ScaleMod: number,
	},
}

export type BaseSpecies = {
	Id: string,
	Name: string,
	Tagline: string,
	Description: string,
	PrimaryColor: Color3,
	SecondaryColor: Color3,
	BaseMultipliers: ResourceMultipliers,
}

-- 6 Base Blocky Species that inhabit and harvest your planet
SpeciesConfig.Species = {
	Terranauts = {
		Id = "Terranauts",
		Name = "Blocky Terranauts",
		Tagline = "Adaptable Pioneers & Builders",
		Description = "Versatile blocky humanoids who build balanced colonial domes and adapt rapidly to any planetary biome.",
		PrimaryColor = Color3.fromRGB(65, 155, 255),
		SecondaryColor = Color3.fromRGB(240, 245, 255),
		BaseMultipliers = {
			Minerals = 1.15,
			Biomass = 1.15,
			Energy = 1.15,
			Tech = 1.15,
			PopGrowth = 1.2,
			FlightSpeed = 1.05,
		},
	},
	Lithoids = {
		Id = "Lithoids",
		Name = "Crystalline Lithoids",
		Tagline = "Deep-Core Tectonic Miners",
		Description = "Sentient geometric rock-beings that feed directly on mantle minerals and carve monolithic quarries into your crust.",
		PrimaryColor = Color3.fromRGB(255, 145, 45),
		SecondaryColor = Color3.fromRGB(90, 75, 110),
		BaseMultipliers = {
			Minerals = 1.55,
			Biomass = 0.75,
			Energy = 1.2,
			Tech = 0.95,
			PopGrowth = 0.9,
			FlightSpeed = 0.95,
		},
	},
	Synthetics = {
		Id = "Synthetics",
		Name = "Automaton Collective",
		Tagline = "Hyper-Logical Cybernetic Drones",
		Description = "Self-replicating blocky machine minds that network your planet's surface with high-voltage computation grids.",
		PrimaryColor = Color3.fromRGB(0, 255, 195),
		SecondaryColor = Color3.fromRGB(35, 42, 55),
		BaseMultipliers = {
			Minerals = 1.2,
			Biomass = 0.65,
			Energy = 1.3,
			Tech = 1.5,
			PopGrowth = 1.0,
			FlightSpeed = 1.1,
		},
	},
	Sylvan = {
		Id = "Sylvan",
		Name = "Sylvan Myceloids",
		Tagline = "Symbiotic World-Root Tenders",
		Description = "Botanical spore-folk who weave living root networks through your planet, accelerating biomass and planetary regeneration.",
		PrimaryColor = Color3.fromRGB(65, 235, 115),
		SecondaryColor = Color3.fromRGB(255, 110, 205),
		BaseMultipliers = {
			Minerals = 0.85,
			Biomass = 1.65,
			Energy = 1.1,
			Tech = 1.0,
			PopGrowth = 1.4,
			FlightSpeed = 1.0,
		},
	},
	Pyroclasts = {
		Id = "Pyroclasts",
		Name = "Solar Pyroclasts",
		Tagline = "Plasma Forgers & Core Harvesters",
		Description = "Incandescent elemental beings born from stellar flares; they tap directly into your planet's thermal dynamo.",
		PrimaryColor = Color3.fromRGB(255, 75, 35),
		SecondaryColor = Color3.fromRGB(255, 215, 50),
		BaseMultipliers = {
			Minerals = 1.25,
			Biomass = 0.7,
			Energy = 1.6,
			Tech = 1.05,
			PopGrowth = 1.0,
			FlightSpeed = 1.15,
		},
	},
	Astraeans = {
		Id = "Astraeans",
		Name = "Voidborn Astraeans",
		Tagline = "Psionic Star-Weavers",
		Description = "Ethereal cosmic scholars who bend gravity around your planet and channel astral currents into pure arcane tech.",
		PrimaryColor = Color3.fromRGB(175, 85, 255),
		SecondaryColor = Color3.fromRGB(0, 225, 255),
		BaseMultipliers = {
			Minerals = 0.85,
			Biomass = 0.9,
			Energy = 1.35,
			Tech = 1.5,
			PopGrowth = 0.95,
			FlightSpeed = 1.2,
		},
	},
}

-- Balanced 4-Branch Evolution Tree (4 Tiers per branch + Root Awakening)
-- Each path gives distinct, balanced strengths for resource extraction, planetary value, and future weapon forging.
SpeciesConfig.EvolutionNodes = {
	-- TIER 0: ROOT
	Awakening = {
		Id = "Awakening",
		Name = "Planetary Awakening",
		Tier = 0,
		Branch = "Root",
		ParentId = nil,
		Description = "Your civilization discovers its planet is a living cosmic entity and begins expanding across the surface.",
		PerkSummary = "Base Civilization Unlocked (+10% All Yields)",
		Cost = { Gems = 0 },
		Multipliers = { Minerals = 1.1, Biomass = 1.1, Energy = 1.1, Tech = 1.1, PopGrowth = 1.0, FlightSpeed = 1.0 },
		VisualTrait = { CityStyle = "Primitive", GlowColor = Color3.fromRGB(255, 230, 150), ScaleMod = 1.0 },
	},

	-- ========================================================================
	-- BRANCH 1: INDUSTRIAL & CYBERNETIC
	-- ========================================================================
	Ind_T1 = {
		Id = "Ind_T1",
		Name = "Continental Foundries",
		Tier = 1,
		Branch = "Industrial",
		ParentId = "Awakening",
		Description = "Automated blocky foundries link across tectonic seams without harming the planet's core stability.",
		PerkSummary = "+35% Star Gems & Planet Value",
		Cost = { Gems = 60 },
		Multipliers = { Minerals = 1.4, Biomass = 1.0, Energy = 1.05, Tech = 1.15, PopGrowth = 1.0, FlightSpeed = 1.0 },
		VisualTrait = { CityStyle = "Factory", GlowColor = Color3.fromRGB(255, 165, 50), ScaleMod = 1.15 },
	},
	Ind_T2 = {
		Id = "Ind_T2",
		Name = "Magma Smelteries & Rail-Grids",
		Tier = 2,
		Branch = "Industrial",
		ParentId = "Ind_T1",
		Description = "Global hyper-trains link continental foundries, expanding planetary infrastructure at blistering speeds.",
		PerkSummary = "+65% Star Gems & Planet Value, +5% Speed",
		Cost = { Gems = 220 },
		Multipliers = { Minerals = 1.55, Biomass = 0.95, Energy = 1.3, Tech = 1.2, PopGrowth = 1.05, FlightSpeed = 1.05 },
		VisualTrait = { CityStyle = "Factory", GlowColor = Color3.fromRGB(255, 130, 0), ScaleMod = 1.3 },
	},
	Ind_T3 = {
		Id = "Ind_T3",
		Name = "Cybernetic Hive-Foundries",
		Tier = 3,
		Branch = "Industrial",
		ParentId = "Ind_T2",
		Description = "Every citizen links to a planetary fabrication mind, turning entire mountain ranges into smart-matter.",
		PerkSummary = "+110% Star Gems & Planet Value, +10% Speed",
		Cost = { Gems = 750 },
		Multipliers = { Minerals = 1.75, Biomass = 0.9, Energy = 1.25, Tech = 1.6, PopGrowth = 1.1, FlightSpeed = 1.1 },
		VisualTrait = { CityStyle = "Factory", GlowColor = Color3.fromRGB(0, 255, 200), ScaleMod = 1.45 },
	},
	Ind_T4 = {
		Id = "Ind_T4",
		Name = "Dyson-Mantle Architects",
		Tier = 4,
		Branch = "Industrial",
		ParentId = "Ind_T3",
		Description = "Apex Evolution: Your people encase the inner core in a quantum Dyson lattice, achieving limitless industrial mastery.",
		PerkSummary = "+180% Star Gems & Planet Value, +15% Speed",
		Cost = { Gems = 2500 },
		Multipliers = { Minerals = 2.2, Biomass = 1.0, Energy = 1.5, Tech = 2.0, PopGrowth = 1.2, FlightSpeed = 1.15 },
		VisualTrait = { CityStyle = "Factory", GlowColor = Color3.fromRGB(0, 255, 255), ScaleMod = 1.65 },
	},

	-- ========================================================================
	-- BRANCH 2: BIO-HARMONY & GAIA SYMBIOSIS
	-- ========================================================================
	Bio_T1 = {
		Id = "Bio_T1",
		Name = "Harmonic Root-Networks",
		Tier = 1,
		Branch = "BioHarmony",
		ParentId = "Awakening",
		Description = "Living root-bridges connect settlements, drawing rich nutrients from the planet's soil while healing the crust.",
		PerkSummary = "+30% All Yields, +25% Citizen Growth",
		Cost = { Gems = 60 },
		Multipliers = { Minerals = 1.05, Biomass = 1.45, Energy = 1.05, Tech = 1.0, PopGrowth = 1.25, FlightSpeed = 1.0 },
		VisualTrait = { CityStyle = "BioDome", GlowColor = Color3.fromRGB(80, 255, 130), ScaleMod = 1.15 },
	},
	Bio_T2 = {
		Id = "Bio_T2",
		Name = "Chlorophyll Sky-Canopies",
		Tier = 2,
		Branch = "BioHarmony",
		ParentId = "Bio_T1",
		Description = "Giant bioluminescent flora towers capture starlight across the upper atmosphere, feeding your civilization.",
		PerkSummary = "+60% All Yields, +30% Citizen Growth",
		Cost = { Gems = 220 },
		Multipliers = { Minerals = 1.1, Biomass = 1.65, Energy = 1.35, Tech = 1.1, PopGrowth = 1.3, FlightSpeed = 1.05 },
		VisualTrait = { CityStyle = "BioDome", GlowColor = Color3.fromRGB(50, 255, 180), ScaleMod = 1.3 },
	},
	Bio_T3 = {
		Id = "Bio_T3",
		Name = "Genetic Metamorphosis",
		Tier = 3,
		Branch = "BioHarmony",
		ParentId = "Bio_T2",
		Description = "Your species splice their DNA with extremophile cosmic flora, thriving in vacuum and organically growing crystals.",
		PerkSummary = "+100% All Yields, +45% Citizen Growth",
		Cost = { Gems = 750 },
		Multipliers = { Minerals = 1.35, Biomass = 1.9, Energy = 1.3, Tech = 1.35, PopGrowth = 1.45, FlightSpeed = 1.1 },
		VisualTrait = { CityStyle = "BioDome", GlowColor = Color3.fromRGB(120, 255, 90), ScaleMod = 1.45 },
	},
	Bio_T4 = {
		Id = "Bio_T4",
		Name = "World-Soul Singularity",
		Tier = 4,
		Branch = "BioHarmony",
		ParentId = "Bio_T3",
		Description = "Apex Evolution: Planet and civilization merge into a single conscious super-organism pulsing with eternal life.",
		PerkSummary = "+165% All Yields, +75% Citizen Growth",
		Cost = { Gems = 2500 },
		Multipliers = { Minerals = 1.6, Biomass = 2.5, Energy = 1.6, Tech = 1.6, PopGrowth = 1.75, FlightSpeed = 1.2 },
		VisualTrait = { CityStyle = "BioDome", GlowColor = Color3.fromRGB(0, 255, 140), ScaleMod = 1.65 },
	},

	-- ========================================================================
	-- BRANCH 3: PSIONIC & ASTRAL ASCENSION
	-- ========================================================================
	Psi_T1 = {
		Id = "Psi_T1",
		Name = "Aether-Resonance Monoliths",
		Tier = 1,
		Branch = "Psionic",
		ParentId = "Awakening",
		Description = "Crystalline obelisks tune into cosmic background radiation, harvesting pure starlight and sharpening minds.",
		PerkSummary = "+35% Star Gems, +10% Flight Speed",
		Cost = { Gems = 60 },
		Multipliers = { Minerals = 1.0, Biomass = 1.0, Energy = 1.4, Tech = 1.25, PopGrowth = 1.0, FlightSpeed = 1.1 },
		VisualTrait = { CityStyle = "Spire", GlowColor = Color3.fromRGB(190, 95, 255), ScaleMod = 1.15 },
	},
	Psi_T2 = {
		Id = "Psi_T2",
		Name = "Telepathic Conclave Spires",
		Tier = 2,
		Branch = "Psionic",
		ParentId = "Psi_T1",
		Description = "Language becomes obsolete; scholars share instant geometric equations across floating crystalline spires.",
		PerkSummary = "+65% Star Gems, +15% Flight Speed",
		Cost = { Gems = 220 },
		Multipliers = { Minerals = 1.05, Biomass = 1.0, Energy = 1.45, Tech = 1.55, PopGrowth = 1.05, FlightSpeed = 1.15 },
		VisualTrait = { CityStyle = "Spire", GlowColor = Color3.fromRGB(215, 110, 255), ScaleMod = 1.3 },
	},
	Psi_T3 = {
		Id = "Psi_T3",
		Name = "Graviton Warp-Weavers",
		Tier = 3,
		Branch = "Psionic",
		ParentId = "Psi_T2",
		Description = "Your civilization bends local spacetime, lightening your planet's inertial mass and extracting zero-point gems.",
		PerkSummary = "+110% Star Gems, +25% Flight Speed",
		Cost = { Gems = 750 },
		Multipliers = { Minerals = 1.15, Biomass = 1.05, Energy = 1.85, Tech = 1.75, PopGrowth = 1.1, FlightSpeed = 1.25 },
		VisualTrait = { CityStyle = "Spire", GlowColor = Color3.fromRGB(150, 220, 255), ScaleMod = 1.45 },
	},
	Psi_T4 = {
		Id = "Psi_T4",
		Name = "Celestial Ascendants",
		Tier = 4,
		Branch = "Psionic",
		ParentId = "Psi_T3",
		Description = "Apex Evolution: Beings of pure starlight and thought who turn your planet into a blazing beacon of arcane omniscience.",
		PerkSummary = "+185% Star Gems, +40% Flight Speed",
		Cost = { Gems = 2500 },
		Multipliers = { Minerals = 1.3, Biomass = 1.2, Energy = 2.4, Tech = 2.3, PopGrowth = 1.2, FlightSpeed = 1.4 },
		VisualTrait = { CityStyle = "Spire", GlowColor = Color3.fromRGB(235, 180, 255), ScaleMod = 1.65 },
	},

	-- ========================================================================
	-- BRANCH 4: TECTONIC WARFORGE
	-- ========================================================================
	War_T1 = {
		Id = "War_T1",
		Name = "Sub-Orbital Bastions",
		Tier = 1,
		Branch = "Warforge",
		ParentId = "Awakening",
		Description = "Armored blocky citadels anchor into tectonic plates, fortifying your planetary core.",
		PerkSummary = "+40% Planet Value, +5% Flight Speed",
		Cost = { Gems = 60 },
		Multipliers = { Minerals = 1.35, Biomass = 1.0, Energy = 1.35, Tech = 1.05, PopGrowth = 1.0, FlightSpeed = 1.05 },
		VisualTrait = { CityStyle = "Fortress", GlowColor = Color3.fromRGB(255, 70, 70), ScaleMod = 1.15 },
	},
	War_T2 = {
		Id = "War_T2",
		Name = "Thermal Dynamo Citadels",
		Tier = 2,
		Branch = "Warforge",
		ParentId = "War_T1",
		Description = "Massive citadels compress core magma into hyper-dense alloys and high-output star-forges.",
		PerkSummary = "+75% Planet Value, +10% Flight Speed",
		Cost = { Gems = 220 },
		Multipliers = { Minerals = 1.5, Biomass = 1.0, Energy = 1.5, Tech = 1.25, PopGrowth = 1.05, FlightSpeed = 1.1 },
		VisualTrait = { CityStyle = "Fortress", GlowColor = Color3.fromRGB(255, 95, 45), ScaleMod = 1.3 },
	},
	War_T3 = {
		Id = "War_T3",
		Name = "Star-Metal Arsenal Guilds",
		Tier = 3,
		Branch = "Warforge",
		ParentId = "War_T2",
		Description = "Warrior-engineers construct orbital drydocks and planetary defense grids across the equator.",
		PerkSummary = "+120% Planet Value, +15% Flight Speed",
		Cost = { Gems = 750 },
		Multipliers = { Minerals = 1.75, Biomass = 1.05, Energy = 1.75, Tech = 1.45, PopGrowth = 1.15, FlightSpeed = 1.15 },
		VisualTrait = { CityStyle = "Fortress", GlowColor = Color3.fromRGB(255, 50, 90), ScaleMod = 1.45 },
	},
	War_T4 = {
		Id = "War_T4",
		Name = "Apex Dreadnought Civilization",
		Tier = 4,
		Branch = "Warforge",
		ParentId = "War_T3",
		Description = "Apex Evolution: Your entire planet is fortified into an unstoppable celestial dreadnought crewed by immortal titans.",
		PerkSummary = "+200% Planet Value, +25% Flight Speed",
		Cost = { Gems = 2500 },
		Multipliers = { Minerals = 2.15, Biomass = 1.15, Energy = 2.15, Tech = 1.8, PopGrowth = 1.25, FlightSpeed = 1.25 },
		VisualTrait = { CityStyle = "Fortress", GlowColor = Color3.fromRGB(255, 30, 60), ScaleMod = 1.65 },
	},
}

SpeciesConfig.BranchOrder = {
	{ Id = "Industrial", Name = "Cyber-Industrial", Color = Color3.fromRGB(0, 215, 255), Nodes = { "Ind_T1", "Ind_T2", "Ind_T3", "Ind_T4" } },
	{ Id = "BioHarmony", Name = "Gaia Symbiosis", Color = Color3.fromRGB(75, 245, 130), Nodes = { "Bio_T1", "Bio_T2", "Bio_T3", "Bio_T4" } },
	{ Id = "Psionic", Name = "Astral Psionics", Color = Color3.fromRGB(195, 100, 255), Nodes = { "Psi_T1", "Psi_T2", "Psi_T3", "Psi_T4" } },
	{ Id = "Warforge", Name = "Tectonic Warforge", Color = Color3.fromRGB(255, 80, 75), Nodes = { "War_T1", "War_T2", "War_T3", "War_T4" } },
}

return SpeciesConfig
