-- If you find any problems please give feedback!
-- MODULE SCRIPT I MADE FOR MY IDLE ENEMY GAME. 

local http = game:GetService("HttpService")

-- Modules and other stuff.

local UnitTable = require(script.Parent)
local PlayerHandler = require(script.Parent.Parent.PlayerHandler)
local GlobalConfig = require(script.Parent.Parent.GlobalConfig)
local PlrOptions = require(script.Parent.Parent.PlayerHandler.PlayerOptions)
local PlrUpgrades = require(script.Parent.Parent.PlayerHandler.PlayerUpgrades)
local Other = require(script.Parent.Parent.Other)
local DataStore = nil

local Events = game.ReplicatedStorage.Events
local Modules = game.ReplicatedStorage.Modules

local Functions = {}

-- AriseChances for unit game im making
local AriseChances = {

	[0] = 1/3,
	[1] = 1/5,
	[2] = 1/8,
	[3] = 1/13,
	[4] = 1/17,
	[5] = 1/22,
	[6] = 1/29,
	[7] = 1/45,

}

-- Rank of units with chances
local Ranks = {

	[0] = { Rank = "E", Chance = 1/3 },
	[1] = { Rank = "F", Chance = 1/7 },
	[2] = { Rank = "D", Chance = 1/14 },
	[3] = { Rank = "C", Chance = 1/33 },
	[4] = { Rank = "B", Chance = 1/57 },
	[5] = { Rank = "A", Chance = 1/105 },
	[6] = { Rank = "S", Chance = 1/409 },
	[7] = { Rank = "SS", Chance = 1/905 },

}

-- Gets savedata from player, this can include "PlayerStats", "Inventory", and "Upgrades".
local GetDataTable = function(plr)
	DataStore = require(game.ReplicatedStorage.Modules.Datastore)
	return DataStore.GetPlayerDataTable(plr) -- returns player data
end

-- Returns a unit from UnitTable
Functions.FindUnit = function(UnitName, FindInWorkspace)
	for _, Unit in UnitTable do
		if Unit.Name == UnitName then
			return Unit -- Returns unit from unit table.
		end
	end
end

-- Calculates unit damage
Functions.CalculateDamage = function(UnitName, Level, Rank) -- RETURNS DPS
	local Unit = Functions.FindUnit(UnitName)
	local Base = Unit["BaseDamage"]

	-- Calculates DPS: scaled by level^1.7 plus base scaled by level, modified by rank multiplier
	return math.floor(math.pow(Level, 1.7) + (Base * (1 + Level/25)) - 1) * (1+Rank) -- calculates damage off of unit rank, basedamage, and level.
end

-- Calculate XP for level
Functions.CalculateXPforLevel = function(Level)
	return math.floor(math.pow(Level, 1.9) * 2 + 100)
end	

local function LevelUpUnit(plr, Unit, UnitNumber, XPForLvl)
	Unit.Level = Unit.Level + 1 -- Adds level
	Unit["XP"] = Unit["XP"] - XPForLvl
	plr.PlayerStats.Units[UnitNumber]["XP"].Value = Unit["XP"] -- This makes it so the player can see the xp value in game.
	Events.UnitLevelUp:FireClient(plr, workspace.UnitPlacements[UnitNumber]) -- VFX
end

-- Gives the unit xp
Functions.GiveXP = function(Unit, XP, plr, UnitNumber)
	print(Unit)
	Unit["XP"] = Unit["XP"] + XP
	local XPForLvl = Functions.CalculateXPforLevel(Unit.Level)

	while Unit["XP"] >= XPForLvl do -- While the unit has enough xp to level up.
		LevelUpUnit(plr, Unit, UnitNumber, XPForLvl)
		task.wait()
	end

	return Unit -- returns the unit after the xp changes

end

-- Awards XP to all equipped player units
Functions.AwardXPToAllUnits = function(plr: Player, XPAmount: number)
	local DataStoreTable = GetDataTable(plr)
	local UnitInventory = DataStoreTable["Unit Inventory"]

	for _, unit in pairs(plr.PlayerStats.Units:GetChildren()) do
		if unit.Value == nil or unit.Value == "" or unit.Level.Value == 0 or unit.Name == 'CurrentEnemy' then
			continue
		end

		local UnitKey = tostring(unit.key.Value)
		local CurrentUnit = UnitInventory[UnitKey]
		if not CurrentUnit then continue end -- Safety check

		local NewUnit = Functions.GiveXP(CurrentUnit, XPAmount, plr, unit.Name)
		UnitInventory[UnitKey] = NewUnit
	end

	DataStore.UpdatePlayerData(plr, "Unit Inventory", UnitInventory)
end


-- Gives a chance for the player to get that unit to battle with
Functions.AriseEnemy = function(plr: Player, Unit) -- SERVER ONLY	
	local Chance = math.random(0, 1000) -- gets a chance ranging from 0 to 1000

	if Chance <= AriseChances[Unit.Rank] * 1000 then return end

	Events.UnitSummoned:FireClient(plr, game.Workspace.UnitPlacements.Enemy) -- Client VFX
	Functions.AddUnit(plr, Unit) -- Adds unit to players inventory
	PlayerHandler.GiveGems(plr, 1)
end

local function WaitForRespawn(plr) -- Waits for enemy respawn
	local Upgrades = PlrUpgrades.GetUpgradeTable(plr)
	if Upgrades.RespawnTime then
		task.wait(Upgrades.RespawnTime.Value)
	else
		task.wait(1.65)
	end
end


-- When a unit is defeated this function is called.
Functions.UnitDefeated = function(plr, Unit)
	local DataStoreTable = GetDataTable(plr)

	Functions.AriseEnemy(plr, { -- Gives the player a chance to get that unit
		Name = Unit.Value,
		Rank = Unit.Rank.Value,
		Level = Unit.Level.Value,
		Equipped = false,
		XP = 0
	})

	PlayerHandler.GiveCoins(plr, math.floor(math.pow(Unit.Level.Value , 1.9) * (Unit.Rank.Value + 1) * 2 / 2.5 * PlrUpgrades.CheckUpgrade(plr, "CoinMultiplier").Value) + 1)

	local xpToGive = math.floor(math.pow(Unit.Level.Value , 1.9) * 2 + 100) / 8.5 -- Gets the amount of xp to give to each of the player's units.
	Functions.AwardXPToAllUnits(plr, xpToGive)

	plr.PlayerStats.EnemiesDefeated.Value += 1
	Events.EnemyDefeated:FireClient(plr, Unit) -- VFX
	PlayerHandler.GiveXP(plr, math.floor(math.pow(Unit.Level.Value , 1.9) * 2 + 100) / 4.5)

	if plr.PlayerStats.EnemiesDefeated.Value >= 10 and PlrOptions.GetOptionTable(plr)["AutoRound"] then
		Functions.NextRound(plr)
	end

	WaitForRespawn(plr) -- Waits for the enemies respawn timer.
	Functions.AssignEnemy(plr)
end


-- Gets rank from index
Functions.GetRankFromIndex = function(Index)
	return Ranks[Index]["Rank"]
end

-- Gets index from rank
Functions.GetIndexFromRank = function(rankToFind)
	for index, rankData in Ranks do
		if rankData.Rank == rankToFind then
			return index
		end
	end
	return nil -- Return nil if the rank is not found
end

-- Assign Rank to arised enemy
Functions.AssignRank = function()
	local totalChance = 0
	for _, rankData in Ranks do
		totalChance = totalChance + rankData.Chance
	end

	local randomValue = math.random() * totalChance
	local cumulativeChance = 0

	-- Sort ranks by index to ensure consistent iteration order
	local sortedKeys = {}
	for k in Ranks do
		table.insert(sortedKeys, k)
	end
	table.sort(sortedKeys)

	for _, key in sortedKeys do
		local rankData = Ranks[key]
		cumulativeChance = cumulativeChance + rankData.Chance
		if randomValue <= cumulativeChance then
			return rankData.Rank -- Return the rank name
		end
	end

	-- Fallback in case of floating point errors, return the last rank
	return Ranks[sortedKeys[#sortedKeys]].Rank
end

-- Gets rank color (vfx)
Functions.GiveRankColor = function(TextLabel, Rank)
	local RankColor = game.ReplicatedStorage.Gui.RankColors[Rank]:Clone()
	RankColor.Parent = TextLabel
end

local function ChooseEnemy(round) -- Choose a random, valid enemy based on current round
	local possibleEnemies = {}
	for _, unit in UnitTable do
		if unit.MinimumRound <= round then
			table.insert(possibleEnemies, unit)
		end
	end
	return possibleEnemies[math.random(#possibleEnemies)]
end

-- Gives enemy an enemy to defeat
Functions.AssignEnemy = function(plr: Player)
	-- Variables
	local PlayerStats = plr:WaitForChild("PlayerStats")
	local CurrentEnemy = PlayerStats.CurrentEnemy
	local round = PlayerStats.Round.Value
	local defeated = PlayerStats.EnemiesDefeated.Value

	local EnemyLevel = CurrentEnemy.Level
	local EnemyHealth = CurrentEnemy.HP
	local EnemyRank = Functions.AssignRank()
	CurrentEnemy.Rank.Value = Functions.GetIndexFromRank(EnemyRank)

	local Enemy = ChooseEnemy(round) -- Chooses an enemy for the player to fight based off a table
	CurrentEnemy.Value = Enemy.Name

	-- Set enemy level and clamp it to at least 1
	EnemyLevel.Value = math.max(1, round + math.random(-1, 2))

	-- Calculates enemy stats
	local baseDamage = Functions.CalculateDamage(Enemy.Name, EnemyLevel.Value, CurrentEnemy.Rank.Value)
	local hpMultiplier = defeated % 9 == 0 and defeated ~= 0 and GlobalConfig.Boss_HP_Multiplier or GlobalConfig.Enemy_HP_Multiplier
	EnemyHealth.Value = math.floor(baseDamage * hpMultiplier * (1 + round / 12))

	-- Spawns boss every 9 enemies
	CurrentEnemy.Boss.Value = (defeated % 9 == 0 and defeated ~= 0)

	Events.EnemyRespawned:FireClient(plr, CurrentEnemy)
end

local function SetUnitValues(Unit, UnitEquipped, UnitKey) -- Sets unit values in the workspace.
	Unit.Value = UnitEquipped.Name
	Unit.Level.Value = UnitEquipped.Level
	Unit.Rank.Value = UnitEquipped.Rank
	Unit.key.Value = UnitKey
end

local function MaintainEquippedUnit(Unit, UnitEquipped, UnitKey)
	while UnitEquipped.Equipped do
		SetUnitValues(Unit, UnitEquipped, UnitKey)
		task.wait()
	end
end

local function SetupEquippedUnit(plr, Unit, UnitEquipped, UnitKey)
	SetUnitValues(Unit, UnitEquipped, UnitKey)
	UnitEquipped.Equipped = true
	PlayerHandler.Notify(plr, "Summon Equipped!")

	local DataStoreTable = GetDataTable(plr)
	local NewPlayerStats = DataStoreTable["PlayerStats"]
	NewPlayerStats[Unit.Name] = UnitKey
	DataStore.UpdatePlayerData(plr, "PlayerStats", NewPlayerStats)

	Events.UpdateInventory:FireClient(plr)
	task.spawn(MaintainEquippedUnit, Unit, UnitEquipped, UnitKey)
end

-- Equips Unit for the player
Functions.EquipUnit = function(plr, UnitKey)
	local DataStoreTable = GetDataTable(plr)
	local Inventory = DataStoreTable["Unit Inventory"]
	local PlayerStats = plr:WaitForChild("PlayerStats")
	local UnitEquipped = Inventory[tostring(UnitKey)]

	if not UnitEquipped then return end -- If unit isn't equipped.

	if UnitEquipped.Equipped then 	-- If the unit is already equipped, unequip it instead and exit
		Functions.UnequipUnit(plr, UnitKey)
		return
	end

	-- Loop through the player's unit slots in PlayerStats.Units
	for _, Unit in pairs(PlayerStats.Units:GetChildren()) do
		-- Skip if this slot is already occupied by a unit with level not zero
		if Unit:FindFirstChild("Level").Value ~= 0 then continue end

		-- Setup the unit in this empty slot (equipping)
		SetupEquippedUnit(plr, Unit, UnitEquipped, UnitKey)
		return
	end
end


-- Unequips unit
Functions.UnequipUnit = function(plr, UnitKey) -- Unequips player unit
	local DataStoreTable = GetDataTable(plr)
	local Inventory = DataStoreTable["Unit Inventory"]

	local PlayerStats = plr:WaitForChild("PlayerStats")
	print(UnitKey)
	for _, Unit: IntValue in pairs(PlayerStats.Units:GetChildren()) do
		if Unit.key.Value ~= UnitKey then continue end
		-- Resets the equipped unit values in the workspace.
		Unit.Value = ""
		Unit.key.Value = 0
		Unit.Level.Value = 0
		Unit.Rank.Value = 0

		Inventory[tostring(UnitKey)].Equipped = false

		local NewPlayerStats = DataStoreTable["PlayerStats"]
		NewPlayerStats[Unit.Name] = nil
		DataStore.UpdatePlayerData(plr, "PlayerStats", NewPlayerStats) -- Updates data in the datastore
		DataStore.UpdatePlayerData(plr, "Unit Inventory", Inventory)

		Events.UpdateInventory:FireClient(plr)
	end

	Inventory[tostring(UnitKey)].Equipped = false
end


local function HandleDPS(plr, Damage) -- Handles the dps value for the player.
	plr.PlayerStats.DPS.Value += Damage
	task.wait(1)
	plr.PlayerStats.DPS.Value -= Damage
end

local function UnitAttackLoop(plr, Unit, EnemyHealth) -- Adds the functionality for units to attack this enemy.
	while plr do
		if Unit.Value ~= "" and Unit.Value ~= nil and EnemyHealth.Value > 0 then
			local Damage = Functions.CalculateDamage(Unit.Value, Unit.Level.Value, Unit.Rank.Value)
			plr.PlayerStats.CurrentEnemy.HP.Value -= Damage
			Events.UnitAttacks:FireClient(plr, Unit.Name) -- VFX

			task.spawn(HandleDPS, plr, Damage) -- Increases DPS Value based of unit damage

			local UnitData = Functions.FindUnit(Unit.Value)
			task.wait(UnitData.CD) -- Cooldown
		end
		task.wait(math.random(5, 7) / 100)
	end
end

local function MonitorEnemyHealth(plr: Player) -- Checks if the enemy is dead, if so it fired the enemy defeated function.
	local EnemyHealth = plr.PlayerStats.CurrentEnemy.HP

	while plr do
		if not plr:GetAttribute("ProcessingEnemy") and EnemyHealth.Value <= 0 then -- if the enemy is dead.
			plr:SetAttribute("ProcessingEnemy", true)
			Functions.UnitDefeated(plr, plr.PlayerStats.CurrentEnemy)
			task.wait(1.15)
			plr:SetAttribute("ProcessingEnemy", false)
		end
		task.wait(0.15)
	end
end

-- Activate units (so they can attack)
Functions.ActivateUnits = function(plr: Player)
	
	plr:SetAttribute("ProcessingEnemy", false) -- Attribute that sets a debounce for processing the enemy
	-- Setting up the enemy in the workspace so the units can attack it.
	local Enemy = plr.PlayerStats.CurrentEnemy 
	local EnemyHealth = plr.PlayerStats.CurrentEnemy.HP
	local Units = plr.PlayerStats.Units

	task.spawn(MonitorEnemyHealth, plr) -- Monitors the enemy health to check if it's dead.

	for _, Unit in pairs(Units:GetChildren()) do -- Activates each unit, allowing them to attack.
		task.spawn(UnitAttackLoop, plr, Unit, EnemyHealth)
	end

end

-- INVENTORY STUFF

Functions.DeleteUnit = function(plr: Player, UnitKey) -- Deletes unit from inventory
	local DataStoreTable = GetDataTable(plr)

	Functions.UnequipUnit(plr, UnitKey) -- Unequips unit so that it clears it's values from the workspace.
	local NewUnitInventory = DataStoreTable["Unit Inventory"]
	NewUnitInventory[tostring(UnitKey)] = nil

	task.wait(.05)
	DataStore.UpdatePlayerData(plr, "Unit Inventory", NewUnitInventory)
	Events.UpdateInventory:FireClient(plr)
end

Functions.AddUnit = function(plr: Player, Unit) -- SERVER ONLY - Adds unit to inventory
	local DataStoreTable = GetDataTable(plr)

	local NewUnitInventory = DataStoreTable["Unit Inventory"]
	NewUnitInventory[http:GenerateGUID(false)] = Unit -- Creates random key for unit and adds the unit into the inventory table.

	DataStore.UpdatePlayerData(plr, "Unit Inventory", NewUnitInventory)
	Events.UpdateInventory:FireClient(plr)
end

Functions.GetInventory = function(plr: Player) -- SERVER ONLY, Gets players inventory
	local DataStoreTable = GetDataTable(plr)
	return DataStoreTable
end

-- Inventory Units have (LEVEL, DAMAGE, RANK)

-- RoundStuff

Functions.NextRound = function(plr) -- Advances to the next round after defeating a certain amount of enemies.
	if plr.PlayerStats.EnemiesDefeated.Value < 10 then return end -- if player defeats 10 enemies, they go to the next round.
	-- Reseting values
	plr.PlayerStats.EnemiesDefeated.Value = 0
	plr.PlayerStats.Round.Value += 1
	PlayerHandler.Notify(plr, "Round ".. tostring(plr.PlayerStats.Round.Value))
	Functions.AssignEnemy(plr)

end

return Functions
