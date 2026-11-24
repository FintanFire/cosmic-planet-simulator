--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- 1. Create Networking Remotes FIRST so client scripts never hang waiting
local remotesFolder = ReplicatedStorage:FindFirstChild("PlanetRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "PlanetRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function makeRemoteEvent(name: string): RemoteEvent
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = remotesFolder
	return re
end

local UpdateCustomizationEvent = makeRemoteEvent("UpdateCustomization")
local SelectSpeciesEvent = makeRemoteEvent("SelectSpecies")
local FinalizeSetupEvent = makeRemoteEvent("FinalizeSetup")
local UnlockEvolutionEvent = makeRemoteEvent("UnlockEvolution")
local UpgradePlanetValueEvent = makeRemoteEvent("UpgradePlanetValue")
local UpgradeMachineEvent = makeRemoteEvent("UpgradeMachine")
local WarpToSectorEvent = makeRemoteEvent("WarpToSector")
local UnlockSpaceStationEvent = makeRemoteEvent("UnlockSpaceStation")
local HatchCompanionPodEvent = makeRemoteEvent("HatchCompanionPod")
local CompanionActionEvent = makeRemoteEvent("CompanionAction")
local BuyDroneSlotEvent = makeRemoteEvent("BuyDroneSlot")
local SetDroneTargetEvent = makeRemoteEvent("SetDroneTarget")
local DroneBeamFXEvent = makeRemoteEvent("DroneBeamFX")
local EvolveDronePathEvent = makeRemoteEvent("EvolveDronePath")
local DetonateStickyBombsEvent = makeRemoteEvent("DetonateStickyBombs")
local StickyBombFXEvent = makeRemoteEvent("StickyBombFX")
local AdminCommandEvent = makeRemoteEvent("AdminCommand")
local BuyBoosterEvent = makeRemoteEvent("BuyBooster")
local ClaimPlaytimeGiftEvent = makeRemoteEvent("ClaimPlaytimeGift")
local RedeemPromoCodeEvent = makeRemoteEvent("RedeemPromoCode")
local BuyShardUpgradeEvent = makeRemoteEvent("BuyShardUpgrade")
local AscendPlanetEvent = makeRemoteEvent("AscendPlanet")
local TeleportToHubEvent = makeRemoteEvent("TeleportToHub")
local FlightSyncEvent = makeRemoteEvent("FlightSync")
local RequestInitialStateEvent = makeRemoteEvent("RequestInitialState")
local StateSyncEvent = makeRemoteEvent("StateSync")
local NotificationEvent = makeRemoteEvent("Notification")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlanetConfig = require(Shared:WaitForChild("PlanetConfig"))
local SpeciesConfig = require(Shared:WaitForChild("SpeciesConfig"))
local PlanetGenerator = require(Shared:WaitForChild("PlanetGenerator"))
local SpaceWorldBuilder = require(script.Parent:WaitForChild("SpaceWorldBuilder"))

-- 2. Build Open Deep Space Environment, Galactic Nexus Hub & 6 Deep-Space Outpost Stations
local cosmosModel = SpaceWorldBuilder.BuildCosmos()
local nodesFolder = cosmosModel:WaitForChild("CosmicResourceNodes")

local planetsFolder = Workspace:FindFirstChild("PlayerPlanets")
if not planetsFolder then
	local pf = Instance.new("Model")
	pf.Name = "PlayerPlanets"
	pcall(function()
		pf.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	pf.Parent = Workspace
	planetsFolder = pf
end

local HUB_SPAWN_POS = Vector3.new(0, 48, 215)

export type CompanionInstance = {
	Uid: string,
	Id: string,
	Level: number,
	IsGolden: boolean,
	Equipped: boolean,
}

export type StickyBombRecord = {
	BombId: string,
	TargetModel: Model?,
	TargetRoot: BasePart?,
	LocalOffset: Vector3,
	WorldPos: Vector3,
	Damage: number,
	BlastRadius: number,
	Color: Color3,
	PlacedAt: number,
	DrillPower: number,
}

type PlayerState = {
	HasCompletedSetup: boolean,
	Resources: {
		Minerals: number,
		Biomass: number,
		Energy: number,
		Tech: number,
	},
	Gems: number,
	CosmicShards: number,
	Level: number,
	XP: number,
	XPToNextLevel: number,
	UpgradePoints: number,
	Population: number,
	PlanetValueScore: number,
	RankIndex: number,
	HighestRankReached: number,
	Ascensions: number,
	MissionIndex: number,
	OrbsHarvested: number,
	DronesHatched: number,
	DroneLevels: number,
	DroneSlotLevel: number,
	DronePathClassId: string,
	PlaytimeSeconds: number,
	ClaimedPlaytimeGifts: { [number]: boolean },
	RedeemedCodes: { [string]: boolean },
	UnlockedStations: { [string]: boolean },
	ActiveBoosters: { [string]: number }, -- Remaining seconds
	ShardUpgrades: { [string]: number },
	Companions: { CompanionInstance },
	MaxEquippedDrones: number,
	Look: { [string]: any },
	SpeciesId: string,
	UnlockedEvolutions: { [string]: boolean },
	ActiveEvolutionId: string,
	PlanetUpgrades: { [string]: number },
	MachineTiers: { [string]: number },
	Rates: {
		Gems: number,
		Minerals: number,
		Biomass: number,
		Energy: number,
		Tech: number,
		FlightSpeed: number,
		DrillPower: number,
		DroneDamage: number,
		DroneDamageMult: number,
		FireCooldown: number,
		DrillSpeed: number,
		GlobalYieldMult: number,
		GemMultiplier: number,
		CompanionMult: number,
		InHubSanctuary: boolean,
		ActiveDistrictName: string,
		CurrentSectorName: string,
		CurrentZoneTier: number,
		CurrentZoneReqDrill: number,
	},
	PlanetPosition: Vector3,
	PlanetModel: Model?,
	LockedTarget: Model?,
	LastDrillWarnTime: number,
	LastFireTime: number,
	DroneFireTimes: { [string]: number },
	StickyBombs: { StickyBombRecord },
}

local playerStates: { [Player]: PlayerState } = {}
local nextCompanionUid = 1000

local function getTotalUpgradeLevels(state: PlayerState): number
	local sum = 0
	for _, lvl in pairs(state.PlanetUpgrades) do
		sum += (lvl or 0)
	end
	return sum
end

local function getTotalMachineTiers(state: PlayerState): number
	local sum = 0
	for _, tier in pairs(state.MachineTiers) do
		sum += (tier or 0)
	end
	return sum
end

local function getUnlockedEvolutionCount(state: PlayerState): number
	local count = 0
	for _, isUnlocked in pairs(state.UnlockedEvolutions) do
		if isUnlocked then
			count += 1
		end
	end
	return count
end

local function getUnlockedStationCount(state: PlayerState): number
	local count = 0
	for stId, isUnl in pairs(state.UnlockedStations) do
		if isUnl and stId ~= "Hub" then
			count += 1
		end
	end
	return count
end

local function getEquippedCount(state: PlayerState): number
	local c = 0
	for _, d in ipairs(state.Companions) do
		if d.Equipped then
			c += 1
		end
	end
	return c
end

local function computeCurrentMissionProgress(state: PlayerState, goalType: string): number
	if goalType == "TotalUpgrades" then
		return getTotalUpgradeLevels(state)
	elseif goalType == "OrbsHarvested" then
		return state.OrbsHarvested
	elseif goalType == "UnlockedEvolutions" then
		return getUnlockedEvolutionCount(state)
	elseif goalType == "PlanetValue" then
		return state.PlanetValueScore
	elseif goalType == "TotalMachineTiers" or goalType == "MachineTiers" then
		return getTotalMachineTiers(state)
	elseif goalType == "DronesHatched" then
		return state.DronesHatched
	elseif goalType == "DroneLevels" then
		return state.DroneLevels
	elseif goalType == "DrillLevel" then
		return state.Rates.DrillPower
	elseif goalType == "StationsUnlocked" then
		return getUnlockedStationCount(state)
	end
	return 0
end

local function checkAndCompleteMissions(player: Player, state: PlayerState)
	if not state.HasCompletedSetup then
		return
	end
	while true do
		local mDef = PlanetConfig.Missions[state.MissionIndex]
		if not mDef then
			break
		end
		local prog = computeCurrentMissionProgress(state, mDef.GoalType)
		if prog >= mDef.Target then
			local rw = mDef.Reward :: any
			if type(rw.Resources) == "table" then
				for rKey, rAmt in pairs(rw.Resources) do
					if (state.Resources :: any)[rKey] ~= nil then
						(state.Resources :: any)[rKey] += rAmt
					end
				end
			end
			state.MissionIndex += 1

			NotificationEvent:FireClient(
				player,
				string.format("MISSION COMPLETE: %s!", mDef.Title),
				Color3.fromRGB(85, 235, 165)
			)
		else
			break
		end
	end
end

-- Helper for balanced upgrade track multiplier: steady growth + 1.22x milestone every 5 levels (prevents instant maxing!)
local function calcTrackMultiplier(lvl: number, perLvlAdd: number, milestoneBase: number): number
	if lvl <= 0 then
		return 1.0
	end
	local milestones = math.floor(lvl / 5)
	return (1 + lvl * perLvlAdd) * math.pow(milestoneBase, milestones)
end

local function recalculateRates(player: Player, state: PlayerState)
	local pType = PlanetConfig.PlanetTypes[state.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
	local species = SpeciesConfig.Species[state.SpeciesId] or SpeciesConfig.Species.Terranauts

	-- Logarithmic population factor so citizen growth rewards you without breaking the economy
	local popFactor = 1 + math.log10(math.max(10, state.Population)) * 0.45

	local minMult = pType.Multipliers.Minerals * species.BaseMultipliers.Minerals
	local bioMult = pType.Multipliers.Biomass * species.BaseMultipliers.Biomass
	local engMult = pType.Multipliers.Energy * species.BaseMultipliers.Energy
	local techMult = pType.Multipliers.Tech * species.BaseMultipliers.Tech
	local speedMult = pType.Multipliers.FlightSpeed * species.BaseMultipliers.FlightSpeed
	local valMult = pType.Multipliers.PlanetValue or 1.0
	local gemMult = 1.0

	local feat = state.Look.SurfaceFeature
	if feat == "Forests" then
		bioMult *= 1.15
	elseif feat == "Crystals" then
		engMult *= 1.15
	elseif feat == "Volcanoes" then
		minMult *= 1.15
	elseif feat == "Citadels" then
		techMult *= 1.15
	elseif feat == "CoralReefs" then
		bioMult *= 1.10
		engMult *= 1.10
	elseif feat == "FloatingIsles" then
		minMult *= 1.10
		bioMult *= 1.10
		engMult *= 1.10
		techMult *= 1.10
	end

	-- Layer 1: Planet Upgrade Tracks (Balanced milestone curve)
	local droneAtkLvl = state.PlanetUpgrades.DroneAttackDamage or 0
	local reloadLvl = state.PlanetUpgrades.DroneReloadSpeed or 0
	local coreLvl = state.PlanetUpgrades.CoreDensity or 0
	local bioLvl = state.PlanetUpgrades.BiosphereFertility or 0
	local magLvl = state.PlanetUpgrades.MagnetosphereDynamo or 0
	local orbLvl = state.PlanetUpgrades.OrbitalInfrastructure or 0
	local metroLvl = state.PlanetUpgrades.CivilizationMetropolis or 0
	local harvLvl = state.PlanetUpgrades.AnomalyHarvester or 0

	local metroBonus = calcTrackMultiplier(metroLvl, 0.25, 1.20)
	valMult *= calcTrackMultiplier(coreLvl, 0.25, 1.18) * calcTrackMultiplier(orbLvl, 0.25, 1.18) * metroBonus
	speedMult *= (1 + magLvl * 0.035)
	gemMult *= (1 + harvLvl * 0.12) * (1 + metroLvl * 0.06)

	-- Layer 3: Species Evolution Multipliers
	local activeNode = SpeciesConfig.EvolutionNodes[state.ActiveEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening
	local nodeAvgMult = (
		activeNode.Multipliers.Minerals
		+ activeNode.Multipliers.Biomass
		+ activeNode.Multipliers.Energy
		+ activeNode.Multipliers.Tech
	) / 4
	gemMult *= nodeAvgMult
	speedMult *= activeNode.Multipliers.FlightSpeed

	local unlockedCount = getUnlockedEvolutionCount(state)
	local masteryBonus = math.pow(1.10, unlockedCount - 1)

	-- Layer 4: Unlocked Space Stations Passive Network Perks
	if state.UnlockedStations["Station_Belt"] then
		gemMult *= 1.15
		valMult *= 1.20
	end
	if state.UnlockedStations["Station_Cryo"] then
		valMult *= 1.25
	end
	if state.UnlockedStations["Station_Pulsar"] then
		valMult *= 1.35
		speedMult *= 1.15
	end
	if state.UnlockedStations["Station_Quantum"] then
		valMult *= 1.50
		gemMult *= 1.20
	end
	if state.UnlockedStations["Station_Rift"] then
		valMult *= 1.75
		gemMult *= 1.35
	end
	if state.UnlockedStations["Station_Omega"] then
		valMult *= 2.50
		gemMult *= 1.60
	end

	-- Layer 5: Equipped Orbital Drones (Determine DrillPower, DrillSpeed, Damage & Multipliers!)
	state.MaxEquippedDrones = (PlanetConfig.BaseDroneSlots or 2) + (state.DroneSlotLevel or 0)
	local companionYieldMult = 1.0
	local companionGemMult = 1.0
	local companionSpeedAdd = 0.0
	local totalDrillPower = 0
	local totalDroneDamage = 0
	local speedSum = 0
	local equippedCount = 0

	for _, drone in ipairs(state.Companions) do
		if drone.Equipped then
			local stats = PlanetConfig.GetDroneStats(drone.Id, drone.Level, drone.IsGolden)
			equippedCount += 1
			totalDrillPower += stats.DrillPower
			totalDroneDamage += stats.Damage
			speedSum += stats.DrillSpeed
			companionYieldMult += (stats.YieldMult - 1.0)
			companionGemMult += (stats.GemMult - 1.0)
			companionSpeedAdd += (stats.SpeedBonus or 0)
		end
	end

	-- Shard Mastery bonus to Drone Drill Power & Damage
	local shardFleetLvl = state.ShardUpgrades.ExtraDroneSlots or 0
	local shardFleetMult = 1 + shardFleetLvl * 0.25

	-- Layer 6: Permanent Cosmic Shard Upgrades & Planetary Ascensions
	local ascensionMult = math.pow(2.5, state.Ascensions)
	local levelMult = 1 + ((state.Level or 1) - 1) * 0.12
	local permGemsLvl = state.ShardUpgrades.PermGems or 0
	local permSpeedLvl = state.ShardUpgrades.PermSpeed or 0
	local permValueLvl = state.ShardUpgrades.PermValue or state.ShardUpgrades.PermDrill or 0
	gemMult *= (1 + permGemsLvl * 0.50) * math.pow(1.35, state.Ascensions)
	speedMult *= (1 + permSpeedLvl * 0.25)
	valMult *= (1 + permValueLvl * 0.50) * levelMult

	-- Layer 7: Active Timed Boosters
	local boosterYieldMult = ((state.ActiveBoosters.YieldBoost or 0) > 0) and 2.0 or 1.0
	local boosterGemMult = ((state.ActiveBoosters.GemBoost or 0) > 0) and 2.0 or 1.0
	local boosterSpeedMult = ((state.ActiveBoosters.SpeedBoost or 0) > 0) and 1.6 or 1.0
	local boosterDrillSpeed = ((state.ActiveBoosters.SpeedBoost or 0) > 0) and 1.25 or 1.0

	local droneAtkMult = (1 + droneAtkLvl * 0.30) * math.pow(1.20, math.floor(droneAtkLvl / 5))
	state.Rates.DroneDamageMult = tonumber(string.format("%.2f", droneAtkMult)) or 1.0
	state.Rates.FireCooldown = math.max(0.05, tonumber(string.format("%.2f", 0.45 / (1 + reloadLvl * 0.18))) or 0.45)

	if equippedCount > 0 then
		state.Rates.DrillPower = math.max(1, math.floor(totalDrillPower * shardFleetMult * math.pow(1.4, state.Ascensions)))
		state.Rates.DroneDamage = math.max(1, math.floor(totalDroneDamage * droneAtkMult * levelMult * shardFleetMult * (1 + permValueLvl * 0.5) * math.pow(1.6, state.Ascensions)))
		state.Rates.DrillSpeed = tonumber(string.format("%.2f", (speedSum / equippedCount) * boosterDrillSpeed)) or 1.2
	else
		-- Drones-only combat: 0 drones means 0 attack/drill power
		state.Rates.DrillPower = 0
		state.Rates.DroneDamage = 0
		state.Rates.DrillSpeed = 1.15 * boosterDrillSpeed
	end

	gemMult *= companionGemMult * boosterGemMult
	speedMult *= (1 + companionSpeedAdd) * boosterSpeedMult

	-- Check Open-Space Hub & Deep-Space Station Sanctuary Proximity
	local pos = state.PlanetPosition
	local distFromOrigin = pos.Magnitude
	local inSanctuary = (distFromOrigin <= 560)
	local hubBonus = inSanctuary and 1.25 or 1.0
	local districtName = ""

	if distFromOrigin <= 560 then
		local HM = PlanetConfig.HubMachines
		for _, m in pairs(HM) do
			if (pos - m.Position).Magnitude <= (m.InteractRadius + 25) then
				if m.Id == "DroneBay" then
					districtName = "ORBITAL DRONE FOUNDRY (Press [E] or Click to Roll Drones)"
				else
					districtName = "STARFARER WARP GATE (Press [E] or Click to Teleport)"
					gemMult *= 1.25
					speedMult *= 1.20
				end
				break
			end
		end
	else
		for _, st in ipairs(PlanetConfig.SpaceStations) do
			if st.Id ~= "Hub" and (pos - st.Position).Magnitude <= st.DockRadius then
				if state.UnlockedStations[st.Id] then
					inSanctuary = true
					hubBonus = 1.40
					districtName = string.format("Docked at %s (+40%% Sanctuary Yield)", st.ShortName)
				else
					districtName = string.format("Near %s (Press [E] to Unlock Gate: %s Gems)", st.ShortName, PlanetConfig.FormatNumber(st.GemCost))
				end
				break
			end
		end
	end

	-- Determine Current Distance Zone
	local curZone = PlanetConfig.GetZoneForDistance(distFromOrigin)
	state.Rates.CurrentZoneTier = curZone.Tier
	state.Rates.CurrentZoneReqDrill = curZone.ReqDrill or 1
	state.Rates.CurrentSectorName = string.format(
		"%s  •  %sx Node Loot",
		curZone.Name,
		PlanetConfig.FormatNumber(curZone.YieldMultiplier)
	)

	-- Calculate Controlled Planet Value Score & Planetary Rank
	local totalUpgradeLevels = droneAtkLvl + reloadLvl + coreLvl + bioLvl + magLvl + orbLvl + metroLvl + harvLvl
	local unlockedStations = getUnlockedStationCount(state)
	local milestoneFactor = math.pow(1.13, totalUpgradeLevels * 0.25 + unlockedStations * 2.2)

	local rawValue = (
		100
		+ totalUpgradeLevels * 115
		+ (unlockedCount - 1) * 420
		+ unlockedStations * 1800
		+ state.OrbsHarvested * 18
		+ state.DronesHatched * 150
		+ state.DroneLevels * 95
	) * milestoneFactor * valMult * companionYieldMult * ascensionMult

	state.PlanetValueScore = math.floor(rawValue)

	local currentRankIdx = 1
	for idx, rDef in ipairs(PlanetConfig.PlanetaryRanks) do
		if state.PlanetValueScore >= rDef.MinValue then
			currentRankIdx = idx
		end
	end
	state.RankIndex = currentRankIdx
	local rankDef = PlanetConfig.PlanetaryRanks[currentRankIdx] or PlanetConfig.PlanetaryRanks[1]
	local rankYieldMult = rankDef.YieldMultiplier or 1.0

	if state.HasCompletedSetup and currentRankIdx > state.HighestRankReached then
		state.HighestRankReached = currentRankIdx
		NotificationEvent:FireClient(
			player,
			string.format("PLANETARY RANK UP! Rank %d: %s (%s)!", rankDef.Rank, rankDef.Title, rankDef.RewardDesc),
			rankDef.BadgeColor
		)
	end

	local totalMult = masteryBonus
		* hubBonus
		* rankYieldMult
		* companionYieldMult
		* ascensionMult
		* boosterYieldMult

	state.Rates.GlobalYieldMult = totalMult
	state.Rates.CompanionMult = companionYieldMult
	state.Rates.GemMultiplier = gemMult * totalMult
	state.Rates.Gems = 0
	state.Rates.Minerals = 0
	state.Rates.Biomass = 0
	state.Rates.Energy = 0
	state.Rates.Tech = 0
	state.Rates.FlightSpeed = math.floor(135 * speedMult)
	state.Rates.InHubSanctuary = inSanctuary
	state.Rates.ActiveDistrictName = districtName

	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local lvlStat = ls:FindFirstChild("Level") :: StringValue?
		local valStat = ls:FindFirstChild("PlanetValue") :: StringValue?
		local rankStat = ls:FindFirstChild("Rank") :: StringValue?
		if lvlStat then
			lvlStat.Value = tostring(state.Level or 1)
		end
		if valStat then
			valStat.Value = PlanetConfig.FormatNumber(state.PlanetValueScore)
		end
		if rankStat then
			rankStat.Value = rankDef.Title
		end
	end
end

local function syncStateToClient(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	recalculateRates(player, state)
	checkAndCompleteMissions(player, state)

	StateSyncEvent:FireClient(player, {
		HasCompletedSetup = state.HasCompletedSetup,
		Resources = state.Resources,
		Gems = state.Gems,
		CosmicShards = state.CosmicShards,
		Level = state.Level,
		XP = state.XP,
		XPToNextLevel = state.XPToNextLevel,
		UpgradePoints = state.UpgradePoints,
		Population = state.Population,
		PlanetValueScore = state.PlanetValueScore,
		RankIndex = state.RankIndex,
		Ascensions = state.Ascensions,
		MissionIndex = state.MissionIndex,
		OrbsHarvested = state.OrbsHarvested,
		DronesHatched = state.DronesHatched,
		DroneLevels = state.DroneLevels,
		DroneSlotLevel = state.DroneSlotLevel,
		PlaytimeSeconds = state.PlaytimeSeconds,
		ClaimedPlaytimeGifts = state.ClaimedPlaytimeGifts,
		RedeemedCodes = state.RedeemedCodes,
		UnlockedStations = state.UnlockedStations,
		ActiveBoosters = state.ActiveBoosters,
		ShardUpgrades = state.ShardUpgrades,
		Companions = state.Companions,
		MaxEquippedDrones = state.MaxEquippedDrones,
		DronePathClassId = state.DronePathClassId,
		StickyBombCount = #state.StickyBombs,
		Look = state.Look,
		SpeciesId = state.SpeciesId,
		UnlockedEvolutions = state.UnlockedEvolutions,
		ActiveEvolutionId = state.ActiveEvolutionId,
		PlanetUpgrades = state.PlanetUpgrades,
		MachineTiers = state.MachineTiers,
		Rates = state.Rates,
		PlanetPosition = state.PlanetPosition,
	})
end

local function getPlanetScaleFactor(state: PlayerState): number
	local totalUpgradeLevels = getTotalUpgradeLevels(state)
	local rankDef = PlanetConfig.PlanetaryRanks[state.RankIndex] or PlanetConfig.PlanetaryRanks[1]
	local rankBonus = rankDef.SizeBonus or 0
	return 1.0 + math.min(totalUpgradeLevels * 0.015 + rankBonus, 1.85)
end

local function rebuildPlayerPlanet(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	if state.PlanetModel then
		state.PlanetModel:Destroy()
	end

	local scaleFactor = getPlanetScaleFactor(state)

	local model = PlanetGenerator.BuildPlanetModel(
		player.DisplayName,
		state.Look,
		state.SpeciesId,
		state.ActiveEvolutionId,
		scaleFactor
	)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:PivotTo(CFrame.new(state.PlanetPosition))
	model.Parent = planetsFolder

	state.PlanetModel = model
	syncStateToClient(player)
end

local function syncHiddenCharacterToPlanet(player: Player, pos: Vector3)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.Transparency = 1
		hrp.CFrame = CFrame.new(pos)
		pcall(function()
			player.ReplicationFocus = hrp
		end)
	end
end

local function hideDefaultCharacter(player: Player, character: Model)
	task.defer(function()
		local state = playerStates[player]
		local targetPos = state and state.PlanetPosition or HUB_SPAWN_POS
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
				desc.Anchored = true
				if desc.Name == "HumanoidRootPart" then
					desc.CFrame = CFrame.new(targetPos)
					pcall(function()
						player.ReplicationFocus = desc
					end)
				end
			elseif desc:IsA("Decal") then
				desc.Transparency = 1
			end
		end
	end)
end

-- 4. Player Join / Leave Lifecycle (START WITH NOTHING AT ALL!)
local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		hideDefaultCharacter(player, char)
	end)
	if player.Character then
		hideDefaultCharacter(player, player.Character)
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local lvlStat = Instance.new("StringValue")
	lvlStat.Name = "Level"
	lvlStat.Value = "1"
	lvlStat.Parent = ls

	local valStat = Instance.new("StringValue")
	valStat.Name = "PlanetValue"
	valStat.Value = "100"
	valStat.Parent = ls

	local rankStat = Instance.new("StringValue")
	rankStat.Name = "Rank"
	rankStat.Value = "Proto-Planetoid"
	rankStat.Parent = ls

	local initialLook = table.clone(PlanetConfig.DefaultPlanetLook)
	initialLook.PlanetName = player.DisplayName .. " Prime"

	-- Player starts at Level 1 with 0 Gems, 0 Minerals, 0 Drones, 5 Drone Slots
	playerStates[player] = {
		HasCompletedSetup = true,
		Resources = {
			Minerals = 0,
			Biomass = 0,
			Energy = 0,
			Tech = 0,
		},
		Gems = 0,
		CosmicShards = 0,
		Level = 1,
		XP = 0,
		XPToNextLevel = PlanetConfig.GetXPForLevel(1),
		UpgradePoints = 0,
		Population = 10.0,
		PlanetValueScore = 100,
		RankIndex = 1,
		HighestRankReached = 1,
		Ascensions = 0,
		MissionIndex = 1,
		OrbsHarvested = 0,
		DronesHatched = 1,
		DroneLevels = 0,
		DroneSlotLevel = 0,
		DronePathClassId = "BasicDrone",
		PlaytimeSeconds = 0,
		ClaimedPlaytimeGifts = {},
		RedeemedCodes = {},
		UnlockedStations = {
			Hub = true,
		},
		ActiveBoosters = {
			YieldBoost = 0,
			GemBoost = 0,
			SpeedBoost = 0,
		},
		ShardUpgrades = {
			PermValue = 0,
			PermGems = 0,
			ExtraDroneSlots = 0,
			PermSpeed = 0,
		},
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
		Look = initialLook,
		SpeciesId = "Terranauts",
		UnlockedEvolutions = {
			Awakening = true,
		},
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
			DrillSpeed = 1.15,
			GlobalYieldMult = 1.0,
			GemMultiplier = 1.0,
			CompanionMult = 1.0,
			InHubSanctuary = true,
			ActiveDistrictName = "",
			CurrentSectorName = "Zone 1: Sanctuary Orbit",
			CurrentZoneTier = 1,
			CurrentZoneReqDrill = 1,
		},
		PlanetPosition = HUB_SPAWN_POS,
		PlanetModel = nil,
		LockedTarget = nil,
		LastDrillWarnTime = 0,
		LastFireTime = 0,
		DroneFireTimes = {},
		StickyBombs = {},
	}

	syncHiddenCharacterToPlanet(player, HUB_SPAWN_POS)
	SpaceWorldBuilder.UpdateProceduralChunks({ HUB_SPAWN_POS })
	rebuildPlayerPlanet(player)
end

local function onPlayerRemoving(player: Player)
	local state = playerStates[player]
	if state then
		state.StickyBombs = {}
		if state.PlanetModel then
			state.PlanetModel:Destroy()
		end
	end
	StickyBombFXEvent:FireAllClients("ClearPlayer", player.UserId)
	playerStates[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- 5. Remote Event Handlers

RequestInitialStateEvent.OnServerEvent:Connect(function(player: Player)
	syncStateToClient(player)
end)

FlightSyncEvent.OnServerEvent:Connect(function(player: Player, newPos: Vector3, yawAngle: number, bankRoll: number?, bankPitch: number?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end
	if typeof(newPos) == "Vector3" and newPos.X == newPos.X then
		local clampedPos = Vector3.new(
			math.clamp(newPos.X, -250000, 250000),
			math.clamp(newPos.Y, -25000, 25000),
			math.clamp(newPos.Z, -250000, 250000)
		)
		state.PlanetPosition = clampedPos
		syncHiddenCharacterToPlanet(player, clampedPos)
		if state.PlanetModel then
			local spin = (type(yawAngle) == "number" and yawAngle == yawAngle) and yawAngle or 0
			local roll = (type(bankRoll) == "number" and bankRoll == bankRoll) and bankRoll or 0
			local pitch = (type(bankPitch) == "number" and bankPitch == bankPitch) and bankPitch or 0
			state.PlanetModel:PivotTo(CFrame.new(clampedPos) * CFrame.Angles(pitch, spin, math.rad(8) + roll))
		end
	end
end)

-- A. Planet Customization Handler
UpdateCustomizationEvent.OnServerEvent:Connect(function(player: Player, newLook: any)
	local state = playerStates[player]
	if not state or type(newLook) ~= "table" then
		return
	end

	if type(newLook.Biome) == "string" and PlanetConfig.PlanetTypes[newLook.Biome] then
		local pt = PlanetConfig.PlanetTypes[newLook.Biome]
		state.Look.Biome = pt.Id
		state.Look.WaterColor = table.clone(pt.DefaultColors.WaterColor)
		state.Look.LandColor = table.clone(pt.DefaultColors.LandColor)
		state.Look.TreeColor = table.clone(pt.DefaultColors.TreeColor)
		state.Look.RockColor = table.clone(pt.DefaultColors.RockColor)
		state.Look.AtmosphereColor = table.clone(pt.DefaultColors.AtmosphereColor)
		state.Look.CloudColor = table.clone(pt.DefaultColors.CloudColor)
		state.Look.RingColor = table.clone(pt.DefaultColors.RingColor)
		state.Look.WaterMaterial = pt.DefaultMaterials.WaterMaterial
		state.Look.LandMaterial = pt.DefaultMaterials.LandMaterial
		state.Look.RockMaterial = pt.DefaultMaterials.RockMaterial
	end

	local stringKeys = {
		"PlanetName",
		"CoreShape",
		"LandCoverage",
		"SurfaceFeature",
		"RingStyle",
		"MoonStyle",
		"Atmosphere",
		"RotationSpeedId",
		"WaterMaterial",
		"LandMaterial",
		"RockMaterial",
	}
	for _, k in ipairs(stringKeys) do
		if type(newLook[k]) == "string" and #newLook[k] > 0 then
			state.Look[k] = string.sub(newLook[k], 1, 28)
		end
	end

	local colorKeys = {
		"WaterColor",
		"LandColor",
		"TreeColor",
		"RockColor",
		"AtmosphereColor",
		"CloudColor",
		"RingColor",
	}
	for _, ck in ipairs(colorKeys) do
		if type(newLook[ck]) == "table" and #newLook[ck] >= 3 then
			state.Look[ck] = {
				math.clamp(tonumber(newLook[ck][1]) or 255, 0, 255),
				math.clamp(tonumber(newLook[ck][2]) or 255, 0, 255),
				math.clamp(tonumber(newLook[ck][3]) or 255, 0, 255),
			}
		end
	end

	rebuildPlayerPlanet(player)
end)

-- B. Species Selection Handler
SelectSpeciesEvent.OnServerEvent:Connect(function(player: Player, speciesId: string)
	local state = playerStates[player]
	if not state or type(speciesId) ~= "string" then
		return
	end
	local sp = SpeciesConfig.Species[speciesId]
	if not sp then
		return
	end
	state.SpeciesId = speciesId
	rebuildPlayerPlanet(player)
end)

-- C. Finalize Initial 2D Creator Setup -> Spawn in Open-Space Hub!
FinalizeSetupEvent.OnServerEvent:Connect(function(player: Player, finalPlanetName: string?)
	local state = playerStates[player]
	if not state or state.HasCompletedSetup then
		return
	end
	if type(finalPlanetName) == "string" and #finalPlanetName > 0 then
		state.Look.PlanetName = string.sub(finalPlanetName, 1, 28)
	end

	state.HasCompletedSetup = true
	state.PlanetPosition = HUB_SPAWN_POS
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	SpaceWorldBuilder.UpdateProceduralChunks({ state.PlanetPosition })
	rebuildPlayerPlanet(player)

	local pt = PlanetConfig.PlanetTypes[state.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
	NotificationEvent:FireClient(
		player,
		string.format("🪐 %s (%s) Spawned in Galactic Nexus Hub! Upgrade your Core Drill & explore Deep-Space Zones!", state.Look.PlanetName, pt.Name),
		Color3.fromRGB(85, 255, 160)
	)
end)

-- D. Species Evolution Unlock / Switch Handler
UnlockEvolutionEvent.OnServerEvent:Connect(function(player: Player, nodeId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(nodeId) ~= "string" then
		return
	end

	local node = SpeciesConfig.EvolutionNodes[nodeId]
	if not node then
		return
	end

	if state.UnlockedEvolutions[nodeId] then
		state.ActiveEvolutionId = nodeId
		rebuildPlayerPlanet(player)
		NotificationEvent:FireClient(
			player,
			string.format("Active Civilization Focus: %s", node.Name),
			node.VisualTrait.GlowColor
		)
		return
	end

	if node.ParentId and not state.UnlockedEvolutions[node.ParentId] then
		NotificationEvent:FireClient(
			player,
			"Unlock the previous Evolution Tier first!",
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	local cost = node.Cost
	local reqGems = cost.Gems or 0

	if state.Gems < reqGems then
		NotificationEvent:FireClient(
			player,
			string.format("💎 Need %s Star Gems to evolve your species!", PlanetConfig.FormatNumber(reqGems)),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.Gems -= reqGems

	state.UnlockedEvolutions[nodeId] = true
	state.ActiveEvolutionId = nodeId

	rebuildPlayerPlanet(player)
	NotificationEvent:FireClient(
		player,
		string.format("🧬 EVOLVED: %s! (%s)", node.Name, node.PerkSummary),
		node.VisualTrait.GlowColor
	)
end)

-- E. Planet Value Upgrade Handler (Supports 1x or Buy Max!)
UpgradePlanetValueEvent.OnServerEvent:Connect(function(player: Player, upgradeId: string, buyMax: boolean?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(upgradeId) ~= "string" then
		return
	end

	local upgDef = nil
	for _, u in ipairs(PlanetConfig.PlanetUpgrades) do
		if u.Id == upgradeId then
			upgDef = u
			break
		end
	end
	if not upgDef then
		return
	end

	local currentLvl = state.PlanetUpgrades[upgradeId] or 0
	if currentLvl >= upgDef.MaxLevel then
		NotificationEvent:FireClient(player, "Maximum Upgrade Level Reached!", Color3.fromRGB(255, 215, 80))
		return
	end

	local boughtLevels = 0
	local maxIterations = buyMax and (upgDef.MaxLevel - currentLvl) or 1

	for _ = 1, maxIterations do
		local lvl = (state.PlanetUpgrades[upgradeId] or 0)
		if lvl >= upgDef.MaxLevel then
			break
		end

		if (state.UpgradePoints or 0) >= 1 then
			state.UpgradePoints -= 1
			state.PlanetUpgrades[upgradeId] = lvl + 1
			boughtLevels += 1
		else
			break
		end
	end

	if boughtLevels == 0 then
		NotificationEvent:FireClient(player, "⭐ Need Upgrade Points! Destroy asteroids to level up (+3 Points per Level)!", Color3.fromRGB(255, 95, 95))
		return
	end

	rebuildPlayerPlanet(player)
	NotificationEvent:FireClient(
		player,
		string.format("⬆️ %s Upgraded to Lv.%d! (+%d Levels)", upgDef.Name, state.PlanetUpgrades[upgradeId], boughtLevels),
		Color3.fromRGB(110, 255, 165)
	)
end)

-- F. Hub Machine Overclock / Tier Upgrade Handler (Unused - machines removed)
UpgradeMachineEvent.OnServerEvent:Connect(function(_player: Player, _machineId: string, _buyMax: boolean?)
	return
end)

-- G1. Unlock a Deep-Space Outpost Station's Warp Gate (Costs 💎 Star Gems!)
UnlockSpaceStationEvent.OnServerEvent:Connect(function(player: Player, stationId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(stationId) ~= "string" then
		return
	end

	local stDef = nil
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		if st.Id == stationId then
			stDef = st
			break
		end
	end
	if not stDef then
		return
	end

	if state.UnlockedStations[stationId] then
		NotificationEvent:FireClient(player, "Warp Gate is already unlocked!", Color3.fromRGB(110, 245, 165))
		return
	end

	recalculateRates(player, state)

	local gemCost = stDef.GemCost or 0
	if state.Gems < gemCost then
		NotificationEvent:FireClient(
			player,
			string.format(
				"💎 Need %s Star Gems to unlock %s Warp Gate! (Have: %s💎)",
				PlanetConfig.FormatNumber(gemCost),
				stDef.ShortName,
				PlanetConfig.FormatNumber(state.Gems)
			),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.Gems -= gemCost
	state.UnlockedStations[stationId] = true
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("🛰️ WARP GATE UNLOCKED: %s! (%s)", stDef.Name, stDef.StationUnlockPerk),
		stDef.Color
	)
end)

-- G2. Teleport to an Unlocked Space Station Warp Gate
WarpToSectorEvent.OnServerEvent:Connect(function(player: Player, stationId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(stationId) ~= "string" then
		return
	end

	local targetStation = nil
	for _, st in ipairs(PlanetConfig.SpaceStations) do
		if st.Id == stationId then
			targetStation = st
			break
		end
	end
	if not targetStation then
		return
	end

	if not state.UnlockedStations[stationId] and not targetStation.UnlockedByDefault then
		NotificationEvent:FireClient(
			player,
			string.format(
				"🔒 Unlock %s Warp Gate first (%s 💎 Star Gems)!",
				targetStation.ShortName,
				PlanetConfig.FormatNumber(targetStation.GemCost)
			),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.PlanetPosition = targetStation.Position + Vector3.new(0, 18, 85)
	if stationId == "Hub" then
		state.PlanetPosition = HUB_SPAWN_POS
	end
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	SpaceWorldBuilder.UpdateProceduralChunks({ state.PlanetPosition })
	if state.PlanetModel then
		state.PlanetModel:PivotTo(CFrame.new(state.PlanetPosition))
	end
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("🌀 WARPED TO %s!", string.upper(targetStation.Name)),
		targetStation.Color
	)
end)

-- H1. Orbital Drone Foundry Roll Handler (Costs APPROPRIATE RESOURCES — NOT Gems!)
HatchCompanionPodEvent.OnServerEvent:Connect(function(player: Player, podId: string, hatchThree: boolean?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(podId) ~= "string" then
		return
	end

	local podDef = nil
	for _, p in ipairs(PlanetConfig.CompanionPods) do
		if p.Id == podId then
			podDef = p
			break
		end
	end
	if not podDef then
		return
	end

	local count = hatchThree and 3 or 1
	local costTable = podDef.Cost or { Minerals = 25 }

	-- Verify player has enough harvested Space Resources
	for resKey, baseAmt in pairs(costTable) do
		local reqAmt = baseAmt * count
		local haveAmt = (state.Resources :: any)[resKey] or 0
		if haveAmt < reqAmt then
			local rMeta = PlanetConfig.ResourceMeta and PlanetConfig.ResourceMeta[resKey]
			local rName = rMeta and rMeta.Name or resKey
			NotificationEvent:FireClient(
				player,
				string.format(
					"Need %s %s to roll %dx %s! (Mine asteroids in space!)",
					PlanetConfig.FormatNumber(reqAmt),
					rName,
					count,
					podDef.Name
				),
				Color3.fromRGB(255, 95, 95)
			)
			return
		end
	end

	if #state.Companions + count > 50 then
		NotificationEvent:FireClient(
			player,
			"Drone Hangar is full (50/50)! Fuse Golden Drones or salvage extras first.",
			Color3.fromRGB(255, 175, 55)
		)
		return
	end

	-- Deduct Space Resources
	for resKey, baseAmt in pairs(costTable) do
		(state.Resources :: any)[resKey] -= (baseAmt * count)
	end

	local hatchedNames = {}
	for _ = 1, count do
		local totalWeight = 0
		for _, entry in ipairs(podDef.Pool) do
			totalWeight += entry.Weight
		end
		local roll = math.random() * totalWeight
		local pickedId = podDef.Pool[1].Id
		local acc = 0
		for _, entry in ipairs(podDef.Pool) do
			acc += entry.Weight
			if roll <= acc then
				pickedId = entry.Id
				break
			end
		end

		nextCompanionUid += 1
		local uid = "Drone_" .. tostring(nextCompanionUid)
		local autoEquip = (getEquippedCount(state) < state.MaxEquippedDrones)
		local startLvl = (podDef :: any).StartLevel or 1
		local isGold = ((podDef :: any).GiveGolden == true)

		table.insert(state.Companions, {
			Uid = uid,
			Id = pickedId,
			Level = startLvl,
			IsGolden = isGold,
			Equipped = autoEquip,
		})
		state.DronesHatched += 1

		local cDef = PlanetConfig.Companions[pickedId]
		if cDef then
			table.insert(hatchedNames, string.format("%s%s Lv.%d", isGold and "★ " or "", cDef.Name, startLvl))
		end
	end

	syncStateToClient(player)
	NotificationEvent:FireClient(
		player,
		string.format("ROLLED DRONE: %s!", table.concat(hatchedNames, ", ")),
		podDef.Color
	)
end)

-- H2. Drone Fleet Management (LevelUp, EquipBest, ToggleEquip, CraftGolden, Delete)
CompanionActionEvent.OnServerEvent:Connect(function(player: Player, action: string, targetUid: string?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(action) ~= "string" then
		return
	end

	if action == "LevelUp" and type(targetUid) == "string" then
		for _, d in ipairs(state.Companions) do
			if d.Uid == targetUid then
				local curLvl = d.Level or 1
				if curLvl >= PlanetConfig.MaxDroneLevel then
					NotificationEvent:FireClient(player, "Drone is already at Maximum Level (Lv.25)!", Color3.fromRGB(255, 215, 75))
					return
				end
				local cost = PlanetConfig.GetDroneLevelUpCost(d.Id, curLvl)
				for rKey, reqAmt in pairs(cost) do
					local haveAmt = (state.Resources :: any)[rKey] or 0
					if haveAmt < reqAmt then
						local rMeta = PlanetConfig.ResourceMeta and PlanetConfig.ResourceMeta[rKey]
						local rName = rMeta and rMeta.Name or rKey
						NotificationEvent:FireClient(
							player,
							string.format("Need %s %s to level up this Drone!", PlanetConfig.FormatNumber(reqAmt), rName),
							Color3.fromRGB(255, 95, 95)
						)
						return
					end
				end
				for rKey, reqAmt in pairs(cost) do
					(state.Resources :: any)[rKey] -= reqAmt
				end
				d.Level = curLvl + 1
				state.DroneLevels += 1
				local cDef = PlanetConfig.Companions[d.Id]
				local newStats = PlanetConfig.GetDroneStats(d.Id, d.Level, d.IsGolden)
				syncStateToClient(player)
				NotificationEvent:FireClient(
					player,
					string.format(
						"DRONE LEVEL UP! %s -> Lv.%d (%d DMG • %d Drill Power)",
						cDef and cDef.Name or "Drone",
						d.Level,
						newStats.Damage,
						newStats.DrillPower
					),
					Color3.fromRGB(75, 235, 155)
				)
				return
			end
		end
	elseif action == "EquipBest" then
		for _, d in ipairs(state.Companions) do
			d.Equipped = false
		end
		table.sort(state.Companions, function(a, b)
			local sa = PlanetConfig.GetDroneStats(a.Id, a.Level, a.IsGolden)
			local sb = PlanetConfig.GetDroneStats(b.Id, b.Level, b.IsGolden)
			if sa.Damage ~= sb.Damage then
				return sa.Damage > sb.Damage
			end
			return sa.DrillPower > sb.DrillPower
		end)
		for i = 1, math.min(#state.Companions, state.MaxEquippedDrones) do
			state.Companions[i].Equipped = true
		end
		syncStateToClient(player)
		NotificationEvent:FireClient(player, "Equipped your highest-damage Orbital Drones!", Color3.fromRGB(85, 240, 165))
	elseif action == "ToggleEquip" and type(targetUid) == "string" then
		for _, d in ipairs(state.Companions) do
			if d.Uid == targetUid then
				if d.Equipped then
					d.Equipped = false
				else
					if getEquippedCount(state) >= state.MaxEquippedDrones then
						NotificationEvent:FireClient(
							player,
							string.format("Max Drone Slots (%d/%d) full! Upgrade Drone Slots with Star Gems!", state.MaxEquippedDrones, state.MaxEquippedDrones),
							Color3.fromRGB(255, 165, 65)
						)
						return
					end
					d.Equipped = true
				end
				break
			end
		end
		syncStateToClient(player)
	elseif action == "CraftGolden" then
		-- Fuse any 3 non-golden identical drones into 1 Golden Drone (1.85x stronger, keeps highest Level!)
		local countsById: { [string]: { number } } = {}
		for idx, d in ipairs(state.Companions) do
			if not d.IsGolden then
				countsById[d.Id] = countsById[d.Id] or {}
				table.insert(countsById[d.Id], idx)
			end
		end
		local craftedCount = 0
		for _, indices in pairs(countsById) do
			while #indices >= 3 do
				local i3 = table.remove(indices) :: number
				local i2 = table.remove(indices) :: number
				local i1 = table.remove(indices) :: number
				local bestLvl = math.max(state.Companions[i1].Level or 1, state.Companions[i2].Level or 1, state.Companions[i3].Level or 1)
				state.Companions[i1].IsGolden = true
				state.Companions[i1].Level = bestLvl
				state.Companions[i2].Uid = "REMOVE"
				state.Companions[i3].Uid = "REMOVE"
				craftedCount += 1
			end
		end
		if craftedCount > 0 then
			local cleaned = {}
			for _, d in ipairs(state.Companions) do
				if d.Uid ~= "REMOVE" then
					table.insert(cleaned, d)
				end
			end
			state.Companions = cleaned
			syncStateToClient(player)
			NotificationEvent:FireClient(
				player,
				string.format("FUSED %d GOLDEN DRONE(S) (1.85x All Stats)!", craftedCount),
				Color3.fromRGB(255, 215, 55)
			)
		else
			NotificationEvent:FireClient(
				player,
				"Need 3 identical non-golden Drones to fuse into a Golden Drone!",
				Color3.fromRGB(255, 110, 95)
			)
		end
	elseif action == "Delete" and type(targetUid) == "string" then
		for idx, d in ipairs(state.Companions) do
			if d.Uid == targetUid then
				table.remove(state.Companions, idx)
				break
			end
		end
		syncStateToClient(player)
	end
end)

-- H2B. Upgrade Drone Slots Using Expensive Gems (Starts at 2 Slots -> Up to 8 Slots!)
BuyDroneSlotEvent.OnServerEvent:Connect(function(player: Player, purchaseType: string?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end
	local nextSlotIdx = (state.DroneSlotLevel or 0) + 1
	local upgDef = PlanetConfig.DroneSlotUpgrades and PlanetConfig.DroneSlotUpgrades[nextSlotIdx]
	if not upgDef then
		NotificationEvent:FireClient(player, "Maximum Drone Slots (8/8) already unlocked!", Color3.fromRGB(255, 215, 75))
		return
	end

	if purchaseType == "Robux" then
		NotificationEvent:FireClient(
			player,
			string.format("Robux Pass (%d R$) will be enabled upon Marketplace publish — unlock Slot #%d with %s Star Gems!", upgDef.RobuxCost or 99, upgDef.SlotNumber, PlanetConfig.FormatNumber(upgDef.GemCost)),
			Color3.fromRGB(85, 215, 255)
		)
		return
	end

	if state.Gems < upgDef.GemCost then
		NotificationEvent:FireClient(
			player,
			string.format("Need %s Star Gems to unlock %s! (Have: %s Gems)", PlanetConfig.FormatNumber(upgDef.GemCost), upgDef.Title, PlanetConfig.FormatNumber(state.Gems)),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.Gems -= upgDef.GemCost
	state.DroneSlotLevel = nextSlotIdx
	state.MaxEquippedDrones = (PlanetConfig.BaseDroneSlots or 2) + state.DroneSlotLevel
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("UNLOCKED %s! You can now equip %d Orbital Drones!", string.upper(upgDef.Title), state.MaxEquippedDrones),
		Color3.fromRGB(56, 225, 255)
	)
end)

-- H2C. Hold-Left-Click Mouse-Aim Fire Handler (Asteroids or Rival Player Planets!)
local function setModelVisibility(model: Model, visible: boolean)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			if desc.Name == "CollectibleRoot" then
				desc.Transparency = visible and 0 or 1
			else
				desc.Transparency = visible and 0.04 or 1
			end
		elseif desc:IsA("BillboardGui") or desc:IsA("PointLight") then
			desc.Enabled = visible
		end
	end
end

local function awardDestroyedNodeLoot(player: Player, state: PlayerState, collectible: Model, root: BasePart)
	local nodeTitle = (root:GetAttribute("NodeTitle") :: string) or "Mineral Asteroid"
	local resType = (root:GetAttribute("ResourceType") :: string) or "Iron"
	local matDef = (PlanetConfig.MaterialNodes and PlanetConfig.MaterialNodes[resType])
		or PlanetConfig.MaterialNodes.Iron
	local baseYield = (root:GetAttribute("BaseResourceYield") :: number) or 14
	local xpGain = math.max(5, (root:GetAttribute("XPReward") :: number) or matDef.BaseXP or 20)

	local harvLvl = state.PlanetUpgrades.AnomalyHarvester or 0
	local harvBonus = 1 + harvLvl * 0.25
	local yieldMult = math.max(1.0, state.Rates.GlobalYieldMult * harvBonus)
	local resGain = math.max(4, math.floor(baseYield * yieldMult * (0.9 + math.random() * 0.25)))

	state.OrbsHarvested += 1
	state.Resources.Minerals += resGain
	state.XP += xpGain

	local leveledUp = false
	while state.XP >= PlanetConfig.GetXPForLevel(state.Level) do
		state.XP -= PlanetConfig.GetXPForLevel(state.Level)
		state.Level += 1
		state.UpgradePoints = (state.UpgradePoints or 0) + 3
		leveledUp = true
		NotificationEvent:FireClient(
			player,
			string.format("⭐ LEVEL UP! You are now Level %d! (+3 Upgrade Points)", state.Level),
			Color3.fromRGB(255, 225, 75)
		)
	end
	state.XPToNextLevel = PlanetConfig.GetXPForLevel(state.Level)

	if not leveledUp then
		NotificationEvent:FireClient(
			player,
			string.format(
				"⛏️ Mined %s! +%s XP & +%s Minerals",
				nodeTitle,
				PlanetConfig.FormatNumber(xpGain),
				PlanetConfig.FormatNumber(resGain)
			),
			matDef.Color or Color3.fromRGB(115, 240, 175)
		)
	end

	syncStateToClient(player)
end

local nextStickyBombSeq = 0

local function cleanupBombsOnDestroyedTarget(state: PlayerState, destroyedModel: Model)
	if #state.StickyBombs == 0 then
		return
	end
	local kept = {}
	local removedAny = false
	for _, b in ipairs(state.StickyBombs) do
		if b.TargetModel == destroyedModel then
			removedAny = true
		else
			table.insert(kept, b)
		end
	end
	if removedAny then
		state.StickyBombs = kept
		StickyBombFXEvent:FireAllClients("RemoveByTarget", 0, destroyedModel)
	end
end

local function applyDamageToNode(
	player: Player,
	state: PlayerState,
	targetModel: Model,
	targetRoot: BasePart,
	rawTickDmg: number,
	drillPower: number
): (number, boolean)
	if targetRoot:GetAttribute("Available") ~= true or targetModel:GetAttribute("Available") == false then
		return 0, false
	end

	local now = os.clock()
	local curHP = (tonumber(targetModel:GetAttribute("HP")) or tonumber(targetRoot:GetAttribute("HP")) or 35)
	if curHP <= 0 then
		return 0, false
	end
	local maxHP = (tonumber(targetModel:GetAttribute("MaxHP")) or tonumber(targetRoot:GetAttribute("MaxHP")) or 35)
	local reqDrill = (tonumber(targetRoot:GetAttribute("ReqDrill")) or 1)

	local drillRatio = math.max(1, drillPower) / math.max(1, reqDrill)
	local efficiency = 1.0
	if drillRatio < 1.0 then
		efficiency = math.max(0.12, drillRatio)
		if now - state.LastDrillWarnTime > 7.5 then
			state.LastDrillWarnTime = now
			NotificationEvent:FireClient(
				player,
				string.format(
					"Hard Material (Req %d Drill Power, You have %d)! Evolve or Level Up Drones for full drill speed!",
					reqDrill,
					drillPower
				),
				Color3.fromRGB(255, 175, 65)
			)
		end
	else
		efficiency = math.min(1.65, 1.0 + math.log10(math.max(1, drillRatio)) * 0.35)
	end

	local dmg = math.max(1, math.floor(rawTickDmg * efficiency + 0.5))
	local newHP = math.max(0, curHP - dmg)

	targetModel:SetAttribute("HP", newHP)
	targetRoot:SetAttribute("HP", newHP)

	local destroyed = (newHP <= 0)
	if destroyed then
		targetModel:SetAttribute("Available", false)
		targetRoot:SetAttribute("Available", false)
		setModelVisibility(targetModel, false)
		cleanupBombsOnDestroyedTarget(state, targetModel)
		awardDestroyedNodeLoot(player, state, targetModel, targetRoot)

		local savedModel = targetModel
		local savedRoot = targetRoot
		local savedMaxHP = maxHP
		task.delay(20, function()
			if savedModel and savedModel.Parent and savedRoot then
				savedModel:SetAttribute("HP", savedMaxHP)
				savedRoot:SetAttribute("HP", savedMaxHP)
				savedModel:SetAttribute("Available", true)
				savedRoot:SetAttribute("Available", true)
				setModelVisibility(savedModel, true)
			end
		end)
	end

	return dmg, destroyed
end

-- Helper: find nearby available asteroids around a world center within radius
local function findAvailableNodesInRadius(center: Vector3, radius: number, excludeModel: Model?): { { Model: Model, Root: BasePart, Dist: number } }
	local results = {}
	for _, chunkModel in ipairs(nodesFolder:GetChildren()) do
		if chunkModel:IsA("Model") then
			for _, collectible in ipairs(chunkModel:GetChildren()) do
				if collectible:IsA("Model") and collectible ~= excludeModel then
					local r = collectible.PrimaryPart
					if r and r:GetAttribute("Available") == true then
						local d = (r.Position - center).Magnitude
						if d <= radius then
							table.insert(results, { Model = collectible, Root = r, Dist = d })
						end
					end
				end
			end
		end
	end
	return results
end

-- Point-to-segment distance helper for SpreadShot rays
local function distPointToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local abLenSq = ab:Dot(ab)
	if abLenSq < 0.001 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / abLenSq, 0, 1)
	local closest = a + ab * t
	return (p - closest).Magnitude
end

local function isValidNextChoice(fromClassId: string, targetClassId: string): boolean
	local node = (PlanetConfig.DroneEvolutionTree :: any)[fromClassId]
	if not node or not node.NextChoices then
		return false
	end
	for _, cid in ipairs(node.NextChoices) do
		if cid == targetClassId then
			return true
		end
	end
	return false
end

-- H2B-EVO. Diep.io First-Path Evolution Handler (Basic Drone -> 5 Specialized Paths at Lv.5)
EvolveDronePathEvent.OnServerEvent:Connect(function(player: Player, targetClassId: string, targetDroneUid: string?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(targetClassId) ~= "string" then
		return
	end

	local targetDef = PlanetConfig.Companions[targetClassId]
	local treeNode = (PlanetConfig.DroneEvolutionTree :: any)[targetClassId]
	if not targetDef or not treeNode then
		return
	end

	local unlockLvl = treeNode.UnlockLevel or targetDef.UnlockLevel or 5
	if (state.Level or 1) < unlockLvl then
		NotificationEvent:FireClient(
			player,
			string.format("Reach Level %d to unlock %s!", unlockLvl, targetDef.Name),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	local chosenDrone: CompanionInstance? = nil
	if type(targetDroneUid) == "string" and #targetDroneUid > 0 and targetDroneUid ~= "Evolve" then
		for _, d in ipairs(state.Companions) do
			if d.Uid == targetDroneUid and isValidNextChoice(d.Id, targetClassId) then
				chosenDrone = d
				break
			end
		end
	end
	if not chosenDrone then
		for _, d in ipairs(state.Companions) do
			if d.Uid == "Drone_PathMain" and isValidNextChoice(d.Id, targetClassId) then
				chosenDrone = d
				break
			end
		end
	end
	if not chosenDrone then
		for _, d in ipairs(state.Companions) do
			if d.Equipped and isValidNextChoice(d.Id, targetClassId) then
				chosenDrone = d
				break
			end
		end
	end
	if not chosenDrone then
		for _, d in ipairs(state.Companions) do
			if isValidNextChoice(d.Id, targetClassId) then
				chosenDrone = d
				break
			end
		end
	end

	if not chosenDrone then
		NotificationEvent:FireClient(
			player,
			"You need an unevolved Basic Drone to choose a path! Build another in DRONE SHOP.",
			Color3.fromRGB(255, 165, 65)
		)
		return
	end

	chosenDrone.Id = targetClassId
	if not chosenDrone.Equipped and getEquippedCount(state) < state.MaxEquippedDrones then
		chosenDrone.Equipped = true
	end
	if chosenDrone.Uid == "Drone_PathMain" then
		state.DronePathClassId = targetClassId
	end

	syncStateToClient(player)
	NotificationEvent:FireClient(
		player,
		string.format("🧬 PATH CHOSEN: Basic Drone -> %s (%s)!", targetDef.Name, targetDef.RoleTag or ""),
		targetDef.Color or Color3.fromRGB(85, 240, 165)
	)
end)

-- H2C. Per-Drone Mouse-Aim Combat Handler (Rapid, Heavy, Long-Range, Spread, Sticky Bombs!)
SetDroneTargetEvent.OnServerEvent:Connect(function(
	player: Player,
	targetModelArg: Instance?,
	aimPosArg: Vector3?,
	droneUidArg: string?,
	aimDirArg: Vector3?
)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end

	-- Resolve which equipped Drone is firing
	local firingDrone: CompanionInstance? = nil
	if type(droneUidArg) == "string" then
		for _, d in ipairs(state.Companions) do
			if d.Uid == droneUidArg and d.Equipped then
				firingDrone = d
				break
			end
		end
	end
	if not firingDrone then
		for _, d in ipairs(state.Companions) do
			if d.Equipped then
				firingDrone = d
				break
			end
		end
	end
	if not firingDrone then
		return
	end

	local dStats = PlanetConfig.GetDroneStats(firingDrone.Id, firingDrone.Level, firingDrone.IsGolden)
	local reloadLvl = state.PlanetUpgrades.DroneReloadSpeed or 0
	local effectiveCooldown = math.max(0.05, dStats.FireCooldown / (1 + reloadLvl * 0.18))
	local now = os.clock()
	local lastShot = state.DroneFireTimes[firingDrone.Uid] or 0
	if (now - lastShot) < (effectiveCooldown * 0.78) then
		return
	end
	state.DroneFireTimes[firingDrone.Uid] = now

	-- Compute this drone's scaled attack multiplier
	local droneAtkLvl = state.PlanetUpgrades.DroneAttackDamage or 0
	local droneAtkMult = (1 + droneAtkLvl * 0.30) * math.pow(1.20, math.floor(droneAtkLvl / 5))
	local levelMult = 1 + ((state.Level or 1) - 1) * 0.12
	local shardFleetLvl = state.ShardUpgrades.ExtraDroneSlots or 0
	local shardFleetMult = 1 + shardFleetLvl * 0.25
	local permValueLvl = state.ShardUpgrades.PermValue or state.ShardUpgrades.PermDrill or 0
	local dmgMult = droneAtkMult * levelMult * shardFleetMult * (1 + permValueLvl * 0.5) * math.pow(1.6, state.Ascensions)

	local pPos = state.PlanetPosition
	local maxRange = dStats.Range or 260
	local style = dStats.ProjectileStyle or "Standard"
	local droneDrill = math.max(state.Rates.DrillPower or 1, dStats.DrillPower)

	local targetModel: Model? = nil
	local targetRoot: BasePart? = nil
	if targetModelArg and targetModelArg:IsA("Model") and targetModelArg.Parent and targetModelArg ~= state.PlanetModel then
		local r = targetModelArg.PrimaryPart
		if r and (r.Position - pPos).Magnitude <= (maxRange + 35) then
			local isAvailNode = (r:GetAttribute("IsSpaceCollectible") == true and r:GetAttribute("Available") == true)
			local isRival = (targetModelArg.Parent == planetsFolder)
			if isAvailNode or isRival then
				targetModel = targetModelArg
				targetRoot = r
			end
		end
	end

	local aimPos = (typeof(aimPosArg) == "Vector3" and aimPosArg.X == aimPosArg.X) and aimPosArg or (pPos + Vector3.new(0, 0, -90))
	local rawAimVec = aimPos - pPos
	local aimDist = rawAimVec.Magnitude
	local aimDir = (typeof(aimDirArg) == "Vector3" and aimDirArg.Magnitude > 0.01) and aimDirArg.Unit
		or ((aimDist > 0.5) and rawAimVec.Unit or Vector3.new(0, 0, -1))
	local clampedAimPos = pPos + aimDir * math.min(maxRange, math.max(20, aimDist))

	-- Find nearest asteroid near cursor if client passed aimPos near one
	if not targetModel then
		local nearNodes = findAvailableNodesInRadius(clampedAimPos, 24, nil)
		local bestD = math.huge
		for _, item in ipairs(nearNodes) do
			if (item.Root.Position - pPos).Magnitude <= (maxRange + 35) and item.Dist < bestD then
				bestD = item.Dist
				targetModel = item.Model
				targetRoot = item.Root
			end
		end
	end

	-- ------------------------------------------------------------------------
	-- STYLE A: STICKY BOMB LAUNCHER (Sticks onto Asteroids or Space Mines!)
	-- ------------------------------------------------------------------------
	if style == "StickyBomb" then
		local count = dStats.ProjectilesPerShot or 1
		local maxBombs = math.max(12, dStats.MaxStickyBombs or 24)
		local bombDmg = math.max(12, math.floor(dStats.BombBaseDamage * dmgMult + 0.5))
		local tapDmg = math.max(1, math.floor(dStats.Damage * dmgMult * 0.25 + 0.5))
		local scale = (firingDrone.Id == "NovaDemolisher") and 1.45 or 1.0
		local blastRadius = dStats.BlastRadius or 32

		for shotIdx = 1, count do
			if #state.StickyBombs >= maxBombs then
				local oldest = table.remove(state.StickyBombs, 1)
				if oldest then
					StickyBombFXEvent:FireAllClients("Remove", player.UserId, { BombId = oldest.BombId })
				end
			end

			nextStickyBombSeq += 1
			local bombId = string.format("%d_%d", player.UserId, nextStickyBombSeq)
			local attachRoot: BasePart? = nil
			local attachModel: Model? = nil
			local localOff = Vector3.zero
			local worldPos = clampedAimPos + Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, (math.random() - 0.5) * 6)

			if targetModel and targetRoot and targetModel.Parent ~= planetsFolder then
				local didTap, killed = applyDamageToNode(player, state, targetModel, targetRoot, tapDmg, droneDrill)
				if not killed and targetRoot:GetAttribute("Available") == true then
					attachModel = targetModel
					attachRoot = targetRoot
					local surfaceDir = (aimPos - targetRoot.Position)
					local dirUnit = (surfaceDir.Magnitude > 0.2) and surfaceDir.Unit or -aimDir
					local halfExtent = math.min(targetRoot.Size.X, targetRoot.Size.Y, targetRoot.Size.Z) * 0.52
					local jitter = Vector3.new((math.random() - 0.5) * 4.2, (math.random() - 0.5) * 3.8, (math.random() - 0.5) * 4.2)
					local worldStick = targetRoot.Position + dirUnit * halfExtent + jitter
					localOff = targetRoot.CFrame:PointToObjectSpace(worldStick)
					worldPos = worldStick
				end
			end

			table.insert(state.StickyBombs, {
				BombId = bombId,
				TargetModel = attachModel,
				TargetRoot = attachRoot,
				LocalOffset = localOff,
				WorldPos = worldPos,
				Damage = bombDmg,
				BlastRadius = blastRadius,
				Color = dStats.BeamColor,
				PlacedAt = now,
				DrillPower = droneDrill,
			})

			StickyBombFXEvent:FireAllClients("Attach", player.UserId, {
				BombId = bombId,
				TargetModel = attachModel,
				TargetRoot = attachRoot,
				LocalOffset = localOff,
				WorldPos = worldPos,
				Color = dStats.BeamColor,
				Scale = scale,
				DroneUid = firingDrone.Uid,
				ShotIndex = shotIdx,
			})
		end

		syncStateToClient(player)
		return
	end

	-- ------------------------------------------------------------------------
	-- STYLE B: MULTI-BULLET SPREAD SHOT (Hits multiple asteroids in 3D cone!)
	-- ------------------------------------------------------------------------
	if style == "SpreadPellet" then
		local numPellets = math.max(3, dStats.ProjectilesPerShot or 5)
		local spreadRad = math.rad(dStats.SpreadDeg or 18)
		local pelletRawDmg = math.max(1, dStats.Damage * dmgMult)

		local baseCF = CFrame.lookAt(Vector3.zero, aimDir)
		local candidateNodes = findAvailableNodesInRadius(pPos, maxRange + 25, nil)
		local hitCountsByModel: { [Model]: { Root: BasePart, Count: number, HitPos: Vector3 } } = {}
		local pelletEndpoints: { Vector3 } = {}

		for pIdx = 1, numPellets do
			local yawOff = ((pIdx - (numPellets + 1) * 0.5) / math.max(1, (numPellets - 1) * 0.5)) * (spreadRad * 0.5)
				+ (math.random() - 0.5) * (spreadRad * 0.16)
			local pitchOff = (math.random() - 0.5) * (spreadRad * 0.35)
			local pelletDir = (baseCF * CFrame.Angles(pitchOff, yawOff, 0)).LookVector
			local rayEnd = pPos + pelletDir * maxRange

			local closestModel: Model? = nil
			local closestRoot: BasePart? = nil
			local closestDistAlong = math.huge
			local hitPt = rayEnd

			for _, item in ipairs(candidateNodes) do
				local center = item.Root.Position
				local toCenter = center - pPos
				local proj = toCenter:Dot(pelletDir)
				if proj > 0 and proj <= maxRange then
					local perpDist = distPointToSegment(center, pPos, rayEnd)
					local hitRadius = math.max(11, item.Root.Size.Magnitude * 0.36)
					if perpDist <= hitRadius and proj < closestDistAlong then
						closestDistAlong = proj
						closestModel = item.Model
						closestRoot = item.Root
						hitPt = pPos + pelletDir * math.max(4, proj - hitRadius * 0.4)
					end
				end
			end

			table.insert(pelletEndpoints, hitPt)
			if closestModel and closestRoot then
				if not hitCountsByModel[closestModel] then
					hitCountsByModel[closestModel] = { Root = closestRoot, Count = 1, HitPos = hitPt }
				else
					hitCountsByModel[closestModel].Count += 1
				end
			end
		end

		local primaryHitModel: Model? = nil
		local primaryDmg = 0
		local primaryDestroyed = false
		local primaryHitPos = pelletEndpoints[1] or clampedAimPos

		for hitModel, info in pairs(hitCountsByModel) do
			local dealt, destroyed = applyDamageToNode(player, state, hitModel, info.Root, pelletRawDmg * info.Count, droneDrill)
			if dealt > primaryDmg then
				primaryHitModel = hitModel
				primaryDmg = dealt
				primaryDestroyed = destroyed
				primaryHitPos = info.HitPos
			end
		end

		DroneBeamFXEvent:FireAllClients(player.UserId, primaryHitModel, primaryDmg, primaryDestroyed, primaryHitPos, {
			Style = "SpreadPellet",
			DroneUid = firingDrone.Uid,
			BeamColor = dStats.BeamColor,
			PelletHits = pelletEndpoints,
		})
		return
	end

	-- ------------------------------------------------------------------------
	-- STYLE C: STANDARD / RAPID BOLT / HEAVY CANNON / LONG-RANGE SNIPER
	-- ------------------------------------------------------------------------
	if not (targetModel and targetRoot) then
		return
	end

	local hitPos = (typeof(aimPosArg) == "Vector3") and aimPosArg or targetRoot.Position
	local shotCount = (style == "SniperBeam" and (dStats.ProjectilesPerShot or 1) > 1) and dStats.ProjectilesPerShot or 1
	local rawPerDrone = math.max(1, dStats.Damage * dmgMult * shotCount)

	if targetModel.Parent == planetsFolder then
		local pvpDmg = math.max(1, math.floor(rawPerDrone + 0.5))
		DroneBeamFXEvent:FireAllClients(player.UserId, targetModel, pvpDmg, false, hitPos, {
			Style = style,
			DroneUid = firingDrone.Uid,
			BeamColor = dStats.BeamColor,
			BlastRadius = dStats.BlastRadius,
		})
		if not state.Rates.InHubSanctuary and math.random() <= 0.30 then
			local siphonOre = math.max(1, math.floor(droneDrill * 0.8))
			state.Resources.Minerals += siphonOre
			syncStateToClient(player)
		end
		return
	end

	local dmg, destroyed = applyDamageToNode(player, state, targetModel, targetRoot, rawPerDrone, droneDrill)

	-- Heavy Cannon AoE Splash Damage
	if style == "HeavySlug" and (dStats.BlastRadius or 0) > 0 then
		local splashNodes = findAvailableNodesInRadius(targetRoot.Position, dStats.BlastRadius, targetModel)
		for _, item in ipairs(splashNodes) do
			applyDamageToNode(player, state, item.Model, item.Root, rawPerDrone * 0.45, droneDrill)
		end
	end

	DroneBeamFXEvent:FireAllClients(player.UserId, targetModel, dmg, destroyed, hitPos, {
		Style = style,
		DroneUid = firingDrone.Uid,
		BeamColor = dStats.BeamColor,
		BlastRadius = dStats.BlastRadius,
		BurstCount = shotCount,
	})
end)

-- H2D. Detonate All Planted Sticky Bombs at Once ([R] or HUD Detonate Button)
DetonateStickyBombsEvent.OnServerEvent:Connect(function(player: Player)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end
	if #state.StickyBombs == 0 then
		return
	end

	local bombs = state.StickyBombs
	state.StickyBombs = {}

	local bombCount = #bombs
	local comboMult = 1.0 + math.min(1.20, (bombCount - 1) * 0.08)
	local blastResults = {}
	local totalAllDamage = 0

	for _, b in ipairs(bombs) do
		local blastPos = b.WorldPos
		if b.TargetRoot and b.TargetRoot.Parent and b.TargetRoot:GetAttribute("Available") == true then
			blastPos = b.TargetRoot.CFrame:PointToWorldSpace(b.LocalOffset)
		end

		local bombDamage = 0
		-- Always hit the attached asteroid directly first if still alive
		if b.TargetModel and b.TargetRoot and b.TargetRoot.Parent and b.TargetRoot:GetAttribute("Available") == true then
			local dealt = applyDamageToNode(player, state, b.TargetModel, b.TargetRoot, b.Damage * comboMult, b.DrillPower)
			bombDamage += dealt
		end

		-- AoE Splash across nearby asteroids within BlastRadius
		local nearby = findAvailableNodesInRadius(blastPos, b.BlastRadius, b.TargetModel)
		for _, item in ipairs(nearby) do
			local falloff = math.clamp(1.0 - (item.Dist / math.max(1, b.BlastRadius)) * 0.4, 0.55, 1.0)
			local dealt = applyDamageToNode(player, state, item.Model, item.Root, b.Damage * comboMult * falloff, b.DrillPower)
			bombDamage += dealt
		end

		totalAllDamage += bombDamage
		table.insert(blastResults, {
			Pos = blastPos,
			Radius = b.BlastRadius,
			Color = b.Color,
			Damage = bombDamage,
		})
	end

	StickyBombFXEvent:FireAllClients("DetonateAll", player.UserId, blastResults)
	syncStateToClient(player)

	if bombCount >= 2 then
		NotificationEvent:FireClient(
			player,
			string.format(
				"💥 DETONATED %d STICKY BOMBS! (%s Total Blast DMG • %.1fx Combo)",
				bombCount,
				PlanetConfig.FormatNumber(totalAllDamage),
				comboMult
			),
			Color3.fromRGB(255, 125, 45)
		)
	end
end)

local function clearAllPlayerBombs(player: Player, state: PlayerState)
	if #state.StickyBombs > 0 then
		state.StickyBombs = {}
		StickyBombFXEvent:FireAllClients("ClearPlayer", player.UserId, nil)
	end
end

-- H2E. Exclusive Developer Admin Console Handler (Only Fintanfire & pizqwe + Creator/Studio)
AdminCommandEvent.OnServerEvent:Connect(function(player: Player, cmd: string, arg1: any, arg2: any)
	if not PlanetConfig.IsAdminPlayer(player) then
		return
	end
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(cmd) ~= "string" then
		return
	end

	local toastMsg = ""
	if cmd == "SetClass" and type(arg1) == "string" then
		local cDef = PlanetConfig.Companions[arg1]
		if not cDef then
			return
		end
		if arg1 ~= "StickyBomber" then
			clearAllPlayerBombs(player, state)
		end
		local updated = false
		for _, d in ipairs(state.Companions) do
			if d.Uid == "Drone_PathMain" then
				d.Id = arg1
				d.Equipped = true
				updated = true
				break
			end
		end
		if not updated then
			for _, d in ipairs(state.Companions) do
				if d.Equipped then
					d.Id = arg1
					updated = true
					break
				end
			end
		end
		if not updated then
			table.insert(state.Companions, 1, {
				Uid = "Drone_PathMain",
				Id = arg1,
				Level = 1,
				IsGolden = false,
				Equipped = true,
			})
		end
		state.DronePathClassId = arg1
		toastMsg = "Switched main drone to " .. cDef.Name
	elseif cmd == "AddBasicDrone" then
		if #state.Companions < 50 then
			nextCompanionUid += 1
			table.insert(state.Companions, {
				Uid = "Drone_" .. tostring(nextCompanionUid),
				Id = "BasicDrone",
				Level = 1,
				IsGolden = false,
				Equipped = (getEquippedCount(state) < state.MaxEquippedDrones),
			})
			toastMsg = "Added Lv.1 Basic Drone!"
		else
			toastMsg = "Hangar full (50/50)"
		end
	elseif cmd == "EquipAll5Paths" then
		clearAllPlayerBombs(player, state)
		local order = PlanetConfig.FirstPathDroneOrder or { "RapidPulse", "HeavyCannon", "LongRangeScout", "SpreadShot", "StickyBomber" }
		local newFleet: { CompanionInstance } = {}
		for idx, cId in ipairs(order) do
			local uid = (idx == 1) and "Drone_PathMain" or ("Drone_AdminPath_" .. tostring(idx))
			table.insert(newFleet, {
				Uid = uid,
				Id = cId,
				Level = 1,
				IsGolden = false,
				Equipped = true,
			})
		end
		state.Companions = newFleet
		state.DronePathClassId = order[1] or "RapidPulse"
		toastMsg = "Equipped all 5 First-Path Drones!"
	elseif cmd == "ResetBasicFleet" then
		clearAllPlayerBombs(player, state)
		state.Companions = {
			{
				Uid = "Drone_PathMain",
				Id = "BasicDrone",
				Level = 1,
				IsGolden = false,
				Equipped = true,
			},
		}
		state.DronePathClassId = "BasicDrone"
		toastMsg = "Reset fleet to 1 Basic Drone"
	elseif cmd == "SetLevel" then
		local lvl = math.clamp(math.floor(tonumber(arg1) or 5), 1, 999)
		state.Level = lvl
		state.XP = 0
		state.XPToNextLevel = PlanetConfig.GetXPForLevel(lvl)
		state.UpgradePoints = math.max(state.UpgradePoints or 0, (lvl - 1) * 3)
		toastMsg = string.format("Set Player Level -> Lv.%d", lvl)
	elseif cmd == "AddLevels" then
		local delta = math.clamp(math.floor(tonumber(arg1) or 5), 1, 100)
		state.Level = math.clamp((state.Level or 1) + delta, 1, 999)
		state.XP = 0
		state.XPToNextLevel = PlanetConfig.GetXPForLevel(state.Level)
		state.UpgradePoints = (state.UpgradePoints or 0) + delta * 3
		toastMsg = string.format("+%d Levels -> Now Lv.%d", delta, state.Level)
	elseif cmd == "ResetAllLv1" then
		clearAllPlayerBombs(player, state)
		state.Level = 1
		state.XP = 0
		state.XPToNextLevel = PlanetConfig.GetXPForLevel(1)
		state.UpgradePoints = 0
		for k, _ in pairs(state.PlanetUpgrades) do
			state.PlanetUpgrades[k] = 0
		end
		state.Companions = {
			{
				Uid = "Drone_PathMain",
				Id = "BasicDrone",
				Level = 1,
				IsGolden = false,
				Equipped = true,
			},
		}
		state.DronePathClassId = "BasicDrone"
		toastMsg = "Reset to Lv.1 + Starter Basic Drone"
	elseif cmd == "AddUpgradePoints" then
		local addPts = math.clamp(math.floor(tonumber(arg1) or 10), 1, 1000)
		state.UpgradePoints = (state.UpgradePoints or 0) + addPts
		toastMsg = string.format("+%d [Q] Upgrade Points", addPts)
	elseif cmd == "BoostCombatStats" then
		state.PlanetUpgrades.DroneAttackDamage = 15
		state.PlanetUpgrades.DroneReloadSpeed = 10
		toastMsg = "Set ATK Lv.15 & Reload Lv.10"
	elseif cmd == "ResetCombatStats" then
		state.PlanetUpgrades.DroneAttackDamage = 0
		state.PlanetUpgrades.DroneReloadSpeed = 0
		toastMsg = "Reset [Q] ATK & Reload to Lv.0"
	elseif cmd == "LevelUpDrones" then
		local addLv = math.clamp(math.floor(tonumber(arg1) or 5), 1, 25)
		for _, d in ipairs(state.Companions) do
			if d.Equipped then
				d.Level = math.clamp((d.Level or 1) + addLv, 1, PlanetConfig.MaxDroneLevel)
			end
		end
		toastMsg = string.format("Leveled up equipped drones +%d", addLv)
	elseif cmd == "GiveResources" then
		state.Resources.Minerals += 10000
		state.Gems += 5000
		toastMsg = "+10,000 Minerals & +5,000 Gems"
	elseif cmd == "SpawnTestAsteroids" then
		local dir = (typeof(arg1) == "Vector3" and arg1.Magnitude > 0.01) and arg1.Unit or Vector3.new(0, 0, -1)
		local spawned = SpaceWorldBuilder.SpawnAdminTestAsteroids(state.PlanetPosition, dir)
		toastMsg = string.format("Spawned %d Test Asteroids ahead (Close/Mid/Far 520s)!", spawned)
	elseif cmd == "UnlockAllStations" then
		for _, st in ipairs(PlanetConfig.SpaceStations) do
			state.UnlockedStations[st.Id] = true
		end
		toastMsg = "Unlocked all Deep-Space Stations!"
	else
		return
	end

	syncStateToClient(player)
	NotificationEvent:FireClient(player, "🛠️ [ADMIN] " .. toastMsg, Color3.fromRGB(255, 215, 65))
end)

-- H3. Buy Timed Booster with Star Gems
BuyBoosterEvent.OnServerEvent:Connect(function(player: Player, boosterId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(boosterId) ~= "string" then
		return
	end

	local bDef = nil
	for _, b in ipairs(PlanetConfig.Boosters) do
		if b.Id == boosterId then
			bDef = b
			break
		end
	end
	if not bDef then
		return
	end

	if state.Gems < bDef.GemCost then
		NotificationEvent:FireClient(
			player,
			string.format("Need %d Star Gems to activate %s!", bDef.GemCost, bDef.Name),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.Gems -= bDef.GemCost
	state.ActiveBoosters[boosterId] = (state.ActiveBoosters[boosterId] or 0) + bDef.Duration
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("ACTIVATED %s (+15 Minutes)!", bDef.Name),
		bDef.Color
	)
end)

-- H4. Claim Timed Playtime Gift
ClaimPlaytimeGiftEvent.OnServerEvent:Connect(function(player: Player, giftId: number)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(giftId) ~= "number" then
		return
	end

	local gDef = PlanetConfig.PlaytimeRewards[giftId]
	if not gDef then
		return
	end
	if state.ClaimedPlaytimeGifts[giftId] then
		NotificationEvent:FireClient(player, "Gift already claimed!", Color3.fromRGB(255, 195, 75))
		return
	end
	if state.PlaytimeSeconds < gDef.TimeReq then
		NotificationEvent:FireClient(player, "Keep playing to unlock this Playtime Gift!", Color3.fromRGB(255, 110, 95))
		return
	end

	state.ClaimedPlaytimeGifts[giftId] = true
	if gDef.Gems then
		state.Gems += gDef.Gems
	end
	if type(gDef.Resources) == "table" then
		for rKey, rAmt in pairs(gDef.Resources :: any) do
			if (state.Resources :: any)[rKey] ~= nil then
				(state.Resources :: any)[rKey] += rAmt
			end
		end
	elseif type(gDef.Resources) == "number" then
		local amt = math.floor(gDef.Resources)
		state.Resources.Minerals += amt
		state.Resources.Biomass += amt
		state.Resources.Energy += amt
		state.Resources.Tech += amt
	end
	if gDef.BoosterId and gDef.BoosterSecs then
		state.ActiveBoosters[gDef.BoosterId] = (state.ActiveBoosters[gDef.BoosterId] or 0) + gDef.BoosterSecs
	end
	if gDef.AllBoostSecs then
		for _, b in ipairs(PlanetConfig.Boosters) do
			state.ActiveBoosters[b.Id] = (state.ActiveBoosters[b.Id] or 0) + gDef.AllBoostSecs
		end
	end

	syncStateToClient(player)
	NotificationEvent:FireClient(
		player,
		string.format("CLAIMED %s: %s!", gDef.Label, gDef.RewardText),
		Color3.fromRGB(105, 255, 155)
	)
end)

-- H5. Redeem Simulator Promo Code
RedeemPromoCodeEvent.OnServerEvent:Connect(function(player: Player, rawCode: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(rawCode) ~= "string" then
		return
	end

	local code = string.upper(string.gsub(rawCode, "%s+", ""))
	local cDef = (PlanetConfig.PromoCodes :: any)[code]
	if not cDef then
		NotificationEvent:FireClient(
			player,
			"Invalid Code! Try: COSMIC2026, STARFARER, GALAXY, or GEMS500",
			Color3.fromRGB(255, 95, 95)
		)
		return
	end
	if state.RedeemedCodes[code] then
		NotificationEvent:FireClient(player, "You already redeemed code " .. code .. "!", Color3.fromRGB(255, 195, 75))
		return
	end

	state.RedeemedCodes[code] = true
	if cDef.Gems then
		state.Gems += cDef.Gems
	end
	if cDef.Resources then
		state.Resources.Minerals += cDef.Resources
		state.Resources.Biomass += cDef.Resources
		state.Resources.Energy += cDef.Resources
		state.Resources.Tech += cDef.Resources
	end
	if cDef.BoosterId and cDef.BoosterSecs then
		state.ActiveBoosters[cDef.BoosterId] = (state.ActiveBoosters[cDef.BoosterId] or 0) + cDef.BoosterSecs
	end

	syncStateToClient(player)
	NotificationEvent:FireClient(
		player,
		string.format("CODE REDEEMED (%s): %s!", code, cDef.Desc),
		Color3.fromRGB(95, 245, 255)
	)
end)

-- H6. Buy Permanent Cosmic Shard Upgrade
BuyShardUpgradeEvent.OnServerEvent:Connect(function(player: Player, shardUpgId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(shardUpgId) ~= "string" then
		return
	end

	local sDef = nil
	for _, s in ipairs(PlanetConfig.ShardUpgrades) do
		if s.Id == shardUpgId then
			sDef = s
			break
		end
	end
	if not sDef then
		return
	end

	local lvl = state.ShardUpgrades[shardUpgId] or 0
	if lvl >= sDef.MaxLevel then
		NotificationEvent:FireClient(player, "Shard Mastery already at Max Level!", Color3.fromRGB(255, 215, 80))
		return
	end

	local cost = math.max(1, math.floor(sDef.BaseShardCost * math.pow(sDef.CostScale, lvl)))
	if state.CosmicShards < cost then
		NotificationEvent:FireClient(
			player,
			string.format("Need %d Cosmic Shards! (Ascend your planet to earn Shards!)", cost),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.CosmicShards -= cost
	state.ShardUpgrades[shardUpgId] = lvl + 1
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("SHARD MASTERY UPGRADED: %s (Lv.%d)!", sDef.Name, lvl + 1),
		Color3.fromRGB(215, 115, 255)
	)
end)

-- I. Planetary Ascension / Rebirth Handler
AscendPlanetEvent.OnServerEvent:Connect(function(player: Player)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end
	local reqValue = math.floor(32000 * math.pow(4.2, state.Ascensions))
	if state.PlanetValueScore < reqValue then
		NotificationEvent:FireClient(
			player,
			string.format("Need %s Planet Value Score to Ascend!", PlanetConfig.FormatNumber(reqValue)),
			Color3.fromRGB(255, 105, 105)
		)
		return
	end

	local shardsEarned = math.max(1, 1 + math.floor(state.Ascensions * 0.8) + math.floor(state.RankIndex / 4))
	state.Ascensions += 1
	state.CosmicShards += shardsEarned
	local newMult = math.pow(2.5, state.Ascensions)

	-- Keep Gems, CosmicShards, Companions, DroneSlotLevel, UnlockedStations, and ShardUpgrades!
	state.Resources = { Minerals = 0, Biomass = 0, Energy = 0, Tech = 0 }
	state.Population = 15.0 * math.pow(1.5, state.Ascensions)
	state.PlanetUpgrades = {
		DroneAttackDamage = 0,
		DroneReloadSpeed = 0,
		CoreDensity = 0,
		BiosphereFertility = 0,
		MagnetosphereDynamo = 0,
		OrbitalInfrastructure = 0,
		CivilizationMetropolis = 0,
		AnomalyHarvester = 0,
	}
	state.MachineTiers = {}
	state.RankIndex = 1
	state.HighestRankReached = 1
	state.PlanetPosition = HUB_SPAWN_POS
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	rebuildPlayerPlanet(player)

	NotificationEvent:FireClient(
		player,
		string.format(
			"ASCENSION #%d COMPLETE! +%d Cosmic Shards & Permanent %sx All Yields!",
			state.Ascensions,
			shardsEarned,
			PlanetConfig.FormatNumber(newMult)
		),
		Color3.fromRGB(255, 215, 65)
	)
end)

-- J. Instant Warp Back to Main Galactic Hub
TeleportToHubEvent.OnServerEvent:Connect(function(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	state.PlanetPosition = HUB_SPAWN_POS
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	SpaceWorldBuilder.UpdateProceduralChunks({ state.PlanetPosition })
	if state.PlanetModel then
		state.PlanetModel:PivotTo(CFrame.new(state.PlanetPosition))
	end
	syncStateToClient(player)
	NotificationEvent:FireClient(player, "Warped to The Galactic Nexus Hub!", Color3.fromRGB(0, 235, 255))
end)

-- ============================================================================
-- 6. PROCEDURAL SPACE CHUNK STREAMING LOOP (Every 0.60s)
-- ============================================================================
task.spawn(function()
	while true do
		task.wait(0.60)
		local activePositions: { Vector3 } = {}
		for _, state in pairs(playerStates) do
			if state.HasCompletedSetup then
				table.insert(activePositions, state.PlanetPosition)
			end
		end
		if #activePositions > 0 then
			SpaceWorldBuilder.UpdateProceduralChunks(activePositions)
		end
	end
end)

-- 7. Continuous Economy, Playtime & Booster Tick Loop (Every 1.0 Second)
task.spawn(function()
	while true do
		task.wait(1.0)
		for player, state in pairs(playerStates) do
			if state.HasCompletedSetup then
				state.PlaytimeSeconds += 1
				for bKey, rem in pairs(state.ActiveBoosters) do
					if rem > 0 then
						state.ActiveBoosters[bKey] = math.max(0, rem - 1)
					end
				end
			end

			recalculateRates(player, state)

			if state.HasCompletedSetup then
				local pType = PlanetConfig.PlanetTypes[state.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
				local species = SpeciesConfig.Species[state.SpeciesId] or SpeciesConfig.Species.Terranauts
				local activeNode = SpeciesConfig.EvolutionNodes[state.ActiveEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening
				local bioLvl = state.PlanetUpgrades.BiosphereFertility or 0

				local popGrowthRate = 0.08
					* pType.Multipliers.PopGrowth
					* species.BaseMultipliers.PopGrowth
					* activeNode.Multipliers.PopGrowth
					* (1 + bioLvl * 0.15)
					* math.pow(1.4, state.Ascensions)
				state.Population = math.floor((state.Population + popGrowthRate) * 100) / 100
			end

			syncStateToClient(player)
		end
	end
end)
