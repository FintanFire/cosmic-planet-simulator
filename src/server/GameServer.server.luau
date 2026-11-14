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

-- 2. Build Open Deep Space Environment & Grand Galactic Nexus Hub
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

-- 3. Player Session Data Store
type PlayerState = {
	HasCompletedSetup: boolean,
	Resources: {
		Minerals: number,
		Biomass: number,
		Energy: number,
		Tech: number,
	},
	Population: number,
	PlanetValueScore: number,
	RankIndex: number,
	HighestRankReached: number,
	Ascensions: number,
	MissionIndex: number,
	OrbsHarvested: number,
	Look: { [string]: any },
	SpeciesId: string,
	UnlockedEvolutions: { [string]: boolean },
	ActiveEvolutionId: string,
	PlanetUpgrades: { [string]: number },
	MachineTiers: { [string]: number },
	Rates: {
		Minerals: number,
		Biomass: number,
		Energy: number,
		Tech: number,
		FlightSpeed: number,
		InHubSanctuary: boolean,
		ActiveDistrictName: string,
		CurrentSectorName: string,
	},
	PlanetPosition: Vector3,
	PlanetModel: Model?,
}

local playerStates: { [Player]: PlayerState } = {}

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
			local rw = mDef.Reward
			state.Resources.Minerals += (rw.Minerals or 0)
			state.Resources.Biomass += (rw.Biomass or 0)
			state.Resources.Energy += (rw.Energy or 0)
			state.Resources.Tech += (rw.Tech or 0)
			state.MissionIndex += 1

			NotificationEvent:FireClient(
				player,
				string.format(
					"🎯 MISSION COMPLETE: %s! (+%s Minerals, +%s Biomass, +%s Energy, +%s Tech)",
					mDef.Title,
					PlanetConfig.FormatNumber(rw.Minerals or 0),
					PlanetConfig.FormatNumber(rw.Biomass or 0),
					PlanetConfig.FormatNumber(rw.Energy or 0),
					PlanetConfig.FormatNumber(rw.Tech or 0)
				),
				Color3.fromRGB(255, 235, 85)
			)
		else
			break
		end
	end
end

local function recalculateRates(player: Player, state: PlayerState)
	local pType = PlanetConfig.PlanetTypes[state.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
	local species = SpeciesConfig.Species[state.SpeciesId] or SpeciesConfig.Species.Terranauts

	local popFactor = 1 + math.pow(math.max(state.Population, 1) / 10, 0.62)

	local minMult = pType.Multipliers.Minerals * species.BaseMultipliers.Minerals
	local bioMult = pType.Multipliers.Biomass * species.BaseMultipliers.Biomass
	local engMult = pType.Multipliers.Energy * species.BaseMultipliers.Energy
	local techMult = pType.Multipliers.Tech * species.BaseMultipliers.Tech
	local speedMult = pType.Multipliers.FlightSpeed * species.BaseMultipliers.FlightSpeed
	local valMult = pType.Multipliers.PlanetValue or 1.0

	local feat = state.Look.SurfaceFeature
	if feat == "Forests" then
		bioMult *= 1.18
	elseif feat == "Crystals" then
		engMult *= 1.18
	elseif feat == "Volcanoes" then
		minMult *= 1.18
	elseif feat == "Citadels" then
		techMult *= 1.18
	elseif feat == "CoralReefs" then
		bioMult *= 1.12
		engMult *= 1.12
	elseif feat == "FloatingIsles" then
		minMult *= 1.12
		bioMult *= 1.12
		engMult *= 1.12
		techMult *= 1.12
	end

	-- Exponential Planet Upgrades (1.42^lvl & 1.35^metroLvl)
	local coreLvl = state.PlanetUpgrades.CoreDensity or 0
	local bioLvl = state.PlanetUpgrades.BiosphereFertility or 0
	local magLvl = state.PlanetUpgrades.MagnetosphereDynamo or 0
	local orbLvl = state.PlanetUpgrades.OrbitalInfrastructure or 0
	local metroLvl = state.PlanetUpgrades.CivilizationMetropolis or 0
	local harvLvl = state.PlanetUpgrades.AnomalyHarvester or 0

	local metroBonus = math.pow(1.35, metroLvl)
	minMult *= math.pow(1.42, coreLvl) * metroBonus
	bioMult *= math.pow(1.42, bioLvl) * metroBonus
	engMult *= math.pow(1.42, magLvl) * metroBonus
	techMult *= math.pow(1.45, orbLvl) * metroBonus
	speedMult *= (1 + magLvl * 0.08)

	-- Exponential Hub Machine Tiers (1.65^tier to 1.80^tier)
	local dysonTier = state.MachineTiers.DysonReactor or 0
	local titanTier = state.MachineTiers.TitanRefinery or 0
	local gaiaTier = state.MachineTiers.GaiaBioVat or 0
	local astralTier = state.MachineTiers.AstralObservatory or 0

	engMult *= math.pow(1.65, dysonTier)
	minMult *= math.pow(1.75, titanTier)
	bioMult *= math.pow(1.70, gaiaTier)
	techMult *= math.pow(1.80, astralTier)
	local allMachineBonus = math.pow(1.25, dysonTier) * math.pow(1.25, astralTier)

	-- Species Evolution Multipliers
	local activeNode = SpeciesConfig.EvolutionNodes[state.ActiveEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening
	minMult *= activeNode.Multipliers.Minerals
	bioMult *= activeNode.Multipliers.Biomass
	engMult *= activeNode.Multipliers.Energy
	techMult *= activeNode.Multipliers.Tech
	speedMult *= activeNode.Multipliers.FlightSpeed

	local unlockedCount = getUnlockedEvolutionCount(state)
	local masteryBonus = math.pow(1.15, unlockedCount - 1)
	local ascensionMult = math.pow(3.0, state.Ascensions)

	-- Open-Space Hub Sanctuary & Machine Proximity Buffs
	local pos = state.PlanetPosition
	local distFromOrigin = pos.Magnitude
	local inSanctuary = (distFromOrigin <= 560)
	local hubBonus = inSanctuary and 1.5 or 1.0
	local districtName = ""

	if distFromOrigin <= 560 then
		local HM = PlanetConfig.HubMachines
		local function near(id: string): boolean
			local m = HM[id]
			return m ~= nil and (pos - m.Position).Magnitude <= (m.InteractRadius + 25)
		end
		if near("DysonReactor") then
			districtName = "⚡ Dyson Star-Reactor (+50% Energy)"
			engMult *= 1.50
		elseif near("AstralObservatory") then
			districtName = "🔭 Astral Observatory (+50% Tech)"
			techMult *= 1.50
		elseif near("TitanRefinery") then
			districtName = "⚒️ Titan Refinery (+50% Minerals)"
			minMult *= 1.50
		elseif near("GaiaBioVat") then
			districtName = "🌿 Gaia Bio-Vat (+50% Biomass)"
			bioMult *= 1.50
		elseif near("WarpGate") then
			districtName = "🌀 Warp Gate (+40% Energy & Speed)"
			engMult *= 1.40
			speedMult *= 1.25
		end
	end

	-- Determine Current Deep-Space Sector Name
	local sectorName = "Galactic Nexus Hub"
	if inSanctuary then
		sectorName = "Galactic Nexus Hub"
	else
		local bestDist = math.huge
		for _, sec in ipairs(PlanetConfig.WarpSectors) do
			if sec.Id ~= "Hub" then
				local d = (pos - sec.Position).Magnitude
				if d < bestDist then
					bestDist = d
					sectorName = sec.Name
				end
			end
		end
		if bestDist > 1500 then
			sectorName = "Uncharted Deep Space"
		end
	end
	local distMultNow = math.max(1.0, math.pow(distFromOrigin / 400, 1.35))
	sectorName = string.format("%s  •  %sx Loot", sectorName, PlanetConfig.FormatNumber(distMultNow))

	-- Calculate Exponential Planet Value Score & Planetary Rank
	local totalUpgradeLevels = coreLvl + bioLvl + magLvl + orbLvl + metroLvl + harvLvl
	local totalMachineTiers = dysonTier + titanTier + gaiaTier + astralTier
	local expFactor = math.pow(1.22, totalUpgradeLevels * 0.35 + totalMachineTiers * 0.65)
	local rawValue = (
		100
		+ totalUpgradeLevels * 180
		+ totalMachineTiers * 450
		+ (unlockedCount - 1) * 500
		+ state.Population * 4.5
		+ state.OrbsHarvested * 65
	) * expFactor * valMult * ascensionMult
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
			string.format("🏆 PLANETARY RANK UP! Rank %d: %s (%s)!", rankDef.Rank, rankDef.Title, rankDef.RewardDesc),
			rankDef.BadgeColor
		)
	end

	local totalMult = masteryBonus * allMachineBonus * hubBonus * rankYieldMult * ascensionMult
	state.Rates.Minerals = math.floor(6.0 * popFactor * minMult * totalMult * 10) / 10
	state.Rates.Biomass = math.floor(6.0 * popFactor * bioMult * totalMult * 10) / 10
	state.Rates.Energy = math.floor(5.5 * popFactor * engMult * totalMult * 10) / 10
	state.Rates.Tech = math.floor(4.5 * popFactor * techMult * totalMult * 10) / 10
	state.Rates.FlightSpeed = math.floor(135 * speedMult)
	state.Rates.InHubSanctuary = inSanctuary
	state.Rates.ActiveDistrictName = districtName
	state.Rates.CurrentSectorName = sectorName

	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local valStat = ls:FindFirstChild("PlanetValue") :: StringValue?
		local rankStat = ls:FindFirstChild("Rank") :: StringValue?
		local popStat = ls:FindFirstChild("Population") :: StringValue?
		if valStat then
			valStat.Value = PlanetConfig.FormatNumber(state.PlanetValueScore)
		end
		if rankStat then
			rankStat.Value = rankDef.Title
		end
		if popStat then
			popStat.Value = PlanetConfig.FormatNumber(state.Population) .. "M"
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
		Population = state.Population,
		PlanetValueScore = state.PlanetValueScore,
		RankIndex = state.RankIndex,
		Ascensions = state.Ascensions,
		MissionIndex = state.MissionIndex,
		OrbsHarvested = state.OrbsHarvested,
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
	local titanTier = state.MachineTiers.TitanRefinery or 0
	local rankDef = PlanetConfig.PlanetaryRanks[state.RankIndex] or PlanetConfig.PlanetaryRanks[1]
	local rankBonus = rankDef.SizeBonus or 0
	return 1.0 + math.min(totalUpgradeLevels * 0.018 + titanTier * 0.03 + rankBonus, 1.85)
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

-- Keep the hidden Avatar Character right at the player's PlanetPosition so Roblox StreamingFocus never unloads chunks
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

-- 4. Player Join / Leave Lifecycle
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

	local valStat = Instance.new("StringValue")
	valStat.Name = "PlanetValue"
	valStat.Value = "100"
	valStat.Parent = ls

	local rankStat = Instance.new("StringValue")
	rankStat.Name = "Rank"
	rankStat.Value = "Proto-Planetoid"
	rankStat.Parent = ls

	local popStat = Instance.new("StringValue")
	popStat.Name = "Population"
	popStat.Value = "10M"
	popStat.Parent = ls

	local initialLook = table.clone(PlanetConfig.DefaultPlanetLook)
	initialLook.PlanetName = player.DisplayName .. " Prime"

	playerStates[player] = {
		HasCompletedSetup = false,
		Resources = {
			Minerals = 180,
			Biomass = 180,
			Energy = 160,
			Tech = 120,
		},
		Population = 10.0,
		PlanetValueScore = 100,
		RankIndex = 1,
		HighestRankReached = 1,
		Ascensions = 0,
		MissionIndex = 1,
		OrbsHarvested = 0,
		Look = initialLook,
		SpeciesId = "Terranauts",
		UnlockedEvolutions = {
			Awakening = true,
		},
		ActiveEvolutionId = "Awakening",
		PlanetUpgrades = {
			CoreDensity = 0,
			BiosphereFertility = 0,
			MagnetosphereDynamo = 0,
			OrbitalInfrastructure = 0,
			CivilizationMetropolis = 0,
			AnomalyHarvester = 0,
		},
		MachineTiers = {
			DysonReactor = 0,
			TitanRefinery = 0,
			GaiaBioVat = 0,
			AstralObservatory = 0,
		},
		Rates = {
			Minerals = 6,
			Biomass = 6,
			Energy = 5.5,
			Tech = 4.5,
			FlightSpeed = 135,
			InHubSanctuary = true,
			ActiveDistrictName = "",
			CurrentSectorName = "Galactic Nexus Hub (1x Node Rewards)",
		},
		PlanetPosition = HUB_SPAWN_POS,
		PlanetModel = nil,
	}

	rebuildPlayerPlanet(player)
end

local function onPlayerRemoving(player: Player)
	local state = playerStates[player]
	if state and state.PlanetModel then
		state.PlanetModel:Destroy()
	end
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
		-- Open, virtually infinite space flight (up to ±250,000 studs!)
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

-- A. Planet Customization Handler (During Initial 2D Creator Screen)
UpdateCustomizationEvent.OnServerEvent:Connect(function(player: Player, newLook: any)
	local state = playerStates[player]
	if not state or type(newLook) ~= "table" or state.HasCompletedSetup then
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

-- B. Species Selection Handler (During Initial 2D Creator Screen)
SelectSpeciesEvent.OnServerEvent:Connect(function(player: Player, speciesId: string)
	local state = playerStates[player]
	if not state or type(speciesId) ~= "string" or state.HasCompletedSetup then
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
		string.format("🪐 %s (%s) Spawned in Galactic Nexus Hub! Fly with WASD & use Hub Machines!", state.Look.PlanetName, pt.Name),
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
	local reqMin = cost.Minerals or 0
	local reqBio = cost.Biomass or 0
	local reqEng = cost.Energy or 0
	local reqTech = cost.Tech or 0

	if
		state.Resources.Minerals < reqMin
		or state.Resources.Biomass < reqBio
		or state.Resources.Energy < reqEng
		or state.Resources.Tech < reqTech
	then
		NotificationEvent:FireClient(
			player,
			"Need more resources to evolve your species!",
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.Resources.Minerals -= reqMin
	state.Resources.Biomass -= reqBio
	state.Resources.Energy -= reqEng
	state.Resources.Tech -= reqTech

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
		local mult = math.pow(upgDef.CostScale, lvl)
		local reqMin = math.floor((upgDef.BaseCost.Minerals or 0) * mult)
		local reqBio = math.floor((upgDef.BaseCost.Biomass or 0) * mult)
		local reqEng = math.floor((upgDef.BaseCost.Energy or 0) * mult)
		local reqTech = math.floor((upgDef.BaseCost.Tech or 0) * mult)

		if
			state.Resources.Minerals >= reqMin
			and state.Resources.Biomass >= reqBio
			and state.Resources.Energy >= reqEng
			and state.Resources.Tech >= reqTech
		then
			state.Resources.Minerals -= reqMin
			state.Resources.Biomass -= reqBio
			state.Resources.Energy -= reqEng
			state.Resources.Tech -= reqTech
			state.PlanetUpgrades[upgradeId] = lvl + 1
			boughtLevels += 1
		else
			break
		end
	end

	if boughtLevels == 0 then
		NotificationEvent:FireClient(player, "Not enough resources to upgrade planet!", Color3.fromRGB(255, 95, 95))
		return
	end

	rebuildPlayerPlanet(player)
	NotificationEvent:FireClient(
		player,
		string.format("⬆️ %s Upgraded to Lv.%d! (+%d Levels)", upgDef.Name, state.PlanetUpgrades[upgradeId], boughtLevels),
		Color3.fromRGB(110, 255, 165)
	)
end)

-- F. Hub Machine Overclock / Tier Upgrade Handler (Supports 1x or Buy Max!)
UpgradeMachineEvent.OnServerEvent:Connect(function(player: Player, machineId: string, buyMax: boolean?)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(machineId) ~= "string" then
		return
	end

	local mDef = PlanetConfig.HubMachines[machineId]
	if not mDef or not mDef.MaxTier or mDef.MaxTier <= 0 then
		return
	end

	local currentTier = state.MachineTiers[machineId] or 0
	if currentTier >= mDef.MaxTier then
		NotificationEvent:FireClient(player, "Machine is already at Maximum Overclock Tier!", Color3.fromRGB(255, 215, 80))
		return
	end

	local boughtTiers = 0
	local maxIterations = buyMax and (mDef.MaxTier - currentTier) or 1

	for _ = 1, maxIterations do
		local tier = state.MachineTiers[machineId] or 0
		if tier >= mDef.MaxTier then
			break
		end
		local mult = math.pow(mDef.CostScale, tier)
		local reqMin = math.floor((mDef.BaseCost.Minerals or 0) * mult)
		local reqBio = math.floor((mDef.BaseCost.Biomass or 0) * mult)
		local reqEng = math.floor((mDef.BaseCost.Energy or 0) * mult)
		local reqTech = math.floor((mDef.BaseCost.Tech or 0) * mult)

		if
			state.Resources.Minerals >= reqMin
			and state.Resources.Biomass >= reqBio
			and state.Resources.Energy >= reqEng
			and state.Resources.Tech >= reqTech
		then
			state.Resources.Minerals -= reqMin
			state.Resources.Biomass -= reqBio
			state.Resources.Energy -= reqEng
			state.Resources.Tech -= reqTech
			state.MachineTiers[machineId] = tier + 1
			boughtTiers += 1

			if machineId == "GaiaBioVat" then
				state.Population = math.floor((state.Population * 1.60 + 15) * 10) / 10
			end
		else
			break
		end
	end

	if boughtTiers == 0 then
		NotificationEvent:FireClient(
			player,
			string.format("Need more resources to overclock %s!", mDef.Name),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	if machineId == "TitanRefinery" then
		rebuildPlayerPlanet(player)
	else
		syncStateToClient(player)
	end

	NotificationEvent:FireClient(
		player,
		string.format("%s upgraded to Tier %d! (+%d)", mDef.Name, state.MachineTiers[machineId], boughtTiers),
		mDef.ThemeColor
	)
end)

-- G. Starfarer Warp Gate Sector Teleport Handler
WarpToSectorEvent.OnServerEvent:Connect(function(player: Player, sectorId: string)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup or type(sectorId) ~= "string" then
		return
	end

	local targetSector = nil
	for _, sec in ipairs(PlanetConfig.WarpSectors) do
		if sec.Id == sectorId then
			targetSector = sec
			break
		end
	end
	if not targetSector then
		return
	end

	local reqValue = targetSector.MinValueReq or 0
	if state.PlanetValueScore < reqValue then
		NotificationEvent:FireClient(
			player,
			string.format("🔒 Need %s Planet Value to warp to %s!", PlanetConfig.FormatNumber(reqValue), targetSector.Name),
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	state.PlanetPosition = targetSector.Position
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	SpaceWorldBuilder.UpdateProceduralChunks({ state.PlanetPosition })
	if state.PlanetModel then
		state.PlanetModel:PivotTo(CFrame.new(state.PlanetPosition))
	end
	syncStateToClient(player)

	NotificationEvent:FireClient(
		player,
		string.format("🌀 WARPED TO %s!", string.upper(targetSector.Name)),
		targetSector.Color
	)
end)

-- H. Planetary Ascension / Rebirth Handler (Permanent 3^Ascensions Multiplier!)
AscendPlanetEvent.OnServerEvent:Connect(function(player: Player)
	local state = playerStates[player]
	if not state or not state.HasCompletedSetup then
		return
	end
	local reqValue = math.floor(15000 * math.pow(4.5, state.Ascensions))
	if state.PlanetValueScore < reqValue then
		NotificationEvent:FireClient(
			player,
			string.format("Need %s Planet Value Score to Ascend!", PlanetConfig.FormatNumber(reqValue)),
			Color3.fromRGB(255, 105, 105)
		)
		return
	end

	state.Ascensions += 1
	local newMult = math.pow(3, state.Ascensions)
	state.Resources = { Minerals = 500, Biomass = 500, Energy = 450, Tech = 350 }
	state.Population = 20.0 * math.pow(2.0, state.Ascensions)
	state.PlanetUpgrades = {
		CoreDensity = 0,
		BiosphereFertility = 0,
		MagnetosphereDynamo = 0,
		OrbitalInfrastructure = 0,
		CivilizationMetropolis = 0,
		AnomalyHarvester = 0,
	}
	state.MachineTiers = {
		DysonReactor = 0,
		TitanRefinery = 0,
		GaiaBioVat = 0,
		AstralObservatory = 0,
	}
	state.RankIndex = 1
	state.HighestRankReached = 1
	state.PlanetPosition = HUB_SPAWN_POS
	syncHiddenCharacterToPlanet(player, state.PlanetPosition)
	rebuildPlayerPlanet(player)

	NotificationEvent:FireClient(
		player,
		string.format("🌟 PLANETARY ASCENSION #%d COMPLETE! Permanent %sx All Yields & Planet Value!", state.Ascensions, PlanetConfig.FormatNumber(newMult)),
		Color3.fromRGB(255, 215, 65)
	)
end)

-- I. Instant Warp Back to Main Galactic Hub
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
	NotificationEvent:FireClient(player, "🚀 Warped to The Galactic Nexus Hub!", Color3.fromRGB(0, 235, 255))
end)

-- 6. Fast Procedural Collectible Harvesting & Chunk Spawner Loop (Every 0.35 Seconds)
local function setModelVisibility(model: Model, visible: boolean)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			if desc.Name == "CollectibleRoot" then
				desc.Transparency = 1
			else
				desc.Transparency = visible and 0.05 or 1
			end
		elseif desc:IsA("BillboardGui") or desc:IsA("PointLight") then
			desc.Enabled = visible
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.35)
		local activePositions: { Vector3 } = {}
		for _, state in pairs(playerStates) do
			if state.HasCompletedSetup then
				table.insert(activePositions, state.PlanetPosition)
			end
		end
		if #activePositions > 0 then
			SpaceWorldBuilder.UpdateProceduralChunks(activePositions)
		end

		for player, state in pairs(playerStates) do
			if state.HasCompletedSetup then
				local pPos = state.PlanetPosition
				local harvLvl = state.PlanetUpgrades.AnomalyHarvester or 0
				local harvestRadius = 56 * (1 + harvLvl * 0.14)
				local harvMult = math.pow(1.48, harvLvl) * math.pow(3.0, state.Ascensions)

				for _, chunkModel in ipairs(nodesFolder:GetChildren()) do
					if chunkModel:IsA("Model") then
						for _, collectible in ipairs(chunkModel:GetChildren()) do
							if collectible:IsA("Model") then
								local root = collectible.PrimaryPart
								if root and root:GetAttribute("Available") == true then
									if (root.Position - pPos).Magnitude <= harvestRadius then
										root:SetAttribute("Available", false)
										setModelVisibility(collectible, false)

										local resType = root:GetAttribute("ResourceType") :: string
										local nodeTitle = (root:GetAttribute("NodeTitle") :: string) or "Cosmic Object"
										local distMult = (root:GetAttribute("DistanceMultiplier") :: number) or 1.0

										state.OrbsHarvested += 1

										if resType == "PopulationPod" then
											local popGain = math.max(5.0, math.floor(state.Population * 0.28 * 10) / 10)
											local techGain = math.floor((90 + state.Rates.Tech * 6.5) * distMult * harvMult)
											state.Population = math.floor((state.Population + popGain) * 10) / 10
											state.Resources.Tech += techGain
											NotificationEvent:FireClient(
												player,
												string.format("🛸 RESCUED %s! +%sM Citizens & +%s Tech!", nodeTitle, PlanetConfig.FormatNumber(popGain), PlanetConfig.FormatNumber(techGain)),
												Color3.fromRGB(80, 225, 255)
											)
										elseif resType == "SupernovaChest" then
											local minBurst = math.floor((250 + state.Rates.Minerals * 14) * distMult * harvMult)
											local bioBurst = math.floor((250 + state.Rates.Biomass * 14) * distMult * harvMult)
											local engBurst = math.floor((250 + state.Rates.Energy * 14) * distMult * harvMult)
											local techBurst = math.floor((220 + state.Rates.Tech * 14) * distMult * harvMult)
											state.Resources.Minerals += minBurst
											state.Resources.Biomass += bioBurst
											state.Resources.Energy += engBurst
											state.Resources.Tech += techBurst
											NotificationEvent:FireClient(
												player,
												string.format(
													"🌟 SUPERNOVA JACKPOT (%s)! +%s Minerals, +%s Biomass, +%s Energy, +%s Tech!",
													nodeTitle,
													PlanetConfig.FormatNumber(minBurst),
													PlanetConfig.FormatNumber(bioBurst),
													PlanetConfig.FormatNumber(engBurst),
													PlanetConfig.FormatNumber(techBurst)
												),
												Color3.fromRGB(255, 215, 55)
											)
										elseif resType and (state.Resources :: any)[resType] ~= nil then
											local rateForRes = (state.Rates :: any)[resType] or 10
											local bonusAmount = math.floor((75 + rateForRes * 5.5) * distMult * harvMult)
											;(state.Resources :: any)[resType] += bonusAmount
											NotificationEvent:FireClient(
												player,
												string.format("★ +%s %s (%s)!", PlanetConfig.FormatNumber(bonusAmount), resType, nodeTitle),
												Color3.fromRGB(110, 245, 255)
											)
										end

										syncStateToClient(player)

										task.delay(20, function()
											if collectible and collectible.Parent and root then
												root:SetAttribute("Available", true)
												setModelVisibility(collectible, true)
											end
										end)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- 7. Continuous Economy Tick Loop (Every 1.0 Second)
task.spawn(function()
	while true do
		task.wait(1.0)
		for player, state in pairs(playerStates) do
			recalculateRates(player, state)

			if state.HasCompletedSetup then
				state.Resources.Minerals = math.floor((state.Resources.Minerals + state.Rates.Minerals) * 10) / 10
				state.Resources.Biomass = math.floor((state.Resources.Biomass + state.Rates.Biomass) * 10) / 10
				state.Resources.Energy = math.floor((state.Resources.Energy + state.Rates.Energy) * 10) / 10
				state.Resources.Tech = math.floor((state.Resources.Tech + state.Rates.Tech) * 10) / 10

				local pType = PlanetConfig.PlanetTypes[state.Look.Biome] or PlanetConfig.PlanetTypes.Terrestrial
				local species = SpeciesConfig.Species[state.SpeciesId] or SpeciesConfig.Species.Terranauts
				local activeNode = SpeciesConfig.EvolutionNodes[state.ActiveEvolutionId] or SpeciesConfig.EvolutionNodes.Awakening
				local bioLvl = state.PlanetUpgrades.BiosphereFertility or 0
				local gaiaTier = state.MachineTiers.GaiaBioVat or 0

				local popGrowthRate = 0.22
					* pType.Multipliers.PopGrowth
					* species.BaseMultipliers.PopGrowth
					* activeNode.Multipliers.PopGrowth
					* math.pow(1.28, bioLvl)
					* math.pow(1.38, gaiaTier)
					* math.pow(2.0, state.Ascensions)
				state.Population = math.floor((state.Population + popGrowthRate) * 100) / 100
			end

			syncStateToClient(player)
		end
	end
end)
