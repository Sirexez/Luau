-- MODULE SCRIPT I MADE FOR MY IDLE ENEMY GAME. 

local UnitTable = require(script.Parent)
local PlayerHandler = require(script.Parent.Parent.PlayerHandler)
local GlobalConfig = require(script.Parent.Parent.GlobalConfig)
local PlrOptions = require(script.Parent.Parent.PlayerHandler.PlayerOptions)
local PlrUpgrades = require(script.Parent.Parent.PlayerHandler.PlayerUpgrades)
local Other = require(script.Parent.Parent.Other)

local Events = game.ReplicatedStorage.Events
local Modules = game.ReplicatedStorage.Modules

local Functions = {}
local RespawnTime = 1

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

-- Gets savedata from player
local GetDataTable = function(plr)
	local DataStore = require(script.Parent.Parent.Datastore)
	return DataStore.GetPlayerDataTable(plr)
end

-- Finds unit
Functions.FindUnit = function(UnitName, FindInWorkspace)
	for _, Unit in UnitTable do
		if Unit.Name == UnitName then
			return Unit
		end
	end
end

-- Calculates unit damage
Functions.CalculateDamage = function(UnitName, Level, Rank) -- RETURNS DPS
	local Unit = Functions.FindUnit(UnitName)
	local Base = Unit["BaseDamage"]

	return math.floor(math.pow(Level, 1.7) + (Base * (1 + Level/25)) - 1) * (1+Rank)
end

-- Calculate XP for level
Functions.CalculateXPforLevel = function(Level)
	return math.floor(math.pow(Level, 1.9) * 2 + 100)
end	

-- Gives unit xp
Functions.GiveXP = function(Unit, XP, plr, UnitNumber)
	
	Unit["XP"] = Unit["XP"] + XP
	local XPForLvl = Functions.CalculateXPforLevel(Unit.Level)
	
	local CheckForLevelUp = function()
		if Unit["XP"] >= XPForLvl then
			Unit.Level = Unit.Level + 1
			Unit["XP"] = Unit["XP"] - XPForLvl
			plr.PlayerStats.Units[UnitNumber]["XP"].Value = Unit["XP"]
			Events.UnitLevelUp:FireClient(plr, workspace.UnitPlacements[UnitNumber])
			return true
		else
			plr.PlayerStats.Units[UnitNumber]["XP"].Value = Unit["XP"]
			return false
		end
	end
	
	repeat CheckForLevelUp() until CheckForLevelUp() == false
	
	return Unit
	
end

-- Gives a chance for the player to get that unit to battle with
Functions.AriseEnemy = function(plr: Player, Unit) -- SERVER ONLY	
	local Chance = math.random(0, 1000)
	
	if Chance <= AriseChances[Unit.Rank] * 1000 then
		Events.UnitSummoned:FireClient(plr, game.Workspace.UnitPlacements.Enemy)
		Functions.AddUnit(plr, Unit)
		PlayerHandler.GiveGems(plr, 1)
	end
end

-- When a unit is defeated this function is called
Functions.UnitDefeated = function(plr: Player, Unit) -- SERVER ONLY
	local DataStore = require(Modules.Datastore)
	local DataStoreTable = DataStore.GetPlayerDataTable(plr)
	
	Functions.AriseEnemy(plr, {["Name"] = Unit.Value, ["Rank"] = Unit.Rank.Value, ["Level"] = Unit.Level.Value, ["Equipped"] = false, ["XP"] = 0})
	PlayerHandler.GiveCoins(plr, math.floor(math.pow(Unit.Level.Value , 1.9) * (Unit.Rank.Value + 1) * 2 / 2.5 * PlrUpgrades.CheckUpgrade(plr, "CoinMultiplier").Value) + 1)
	
	for _, unit in pairs(plr.PlayerStats.Units:GetChildren()) do
		if unit.Value ~= nil and unit.Value ~= "" and unit.Level.Value ~= 0 then

			local NewUnit = Functions.GiveXP(DataStoreTable["Unit Inventory"][tostring(unit.key.value)], math.floor(math.pow(Unit.Level.Value , 1.9) * 2 + 100) / 8.5, plr, unit.Name)

			if not NewUnit == nil then 

			local NewUnitInventory = DataStoreTable["Unit Inventory"]
			NewUnitInventory[tostring(unit.key.value)] = NewUnit

			DataStore.UpdatePlayerData(plr, "Unit Inventory", NewUnitInventory)

			end
		end
	end
	
	plr.PlayerStats.EnemiesDefeated.Value += 1
	Events.EnemyDefeated:FireClient(plr, Unit)
	PlayerHandler.GiveXP(plr, math.floor(math.pow(Unit.Level.Value , 1.9) * 2 + 100) / 4.5)
	
	if plr.PlayerStats.EnemiesDefeated.Value >= 10 and PlrOptions.GetOptionTable(plr)["AutoRound"] == true then
		Functions.NextRound(plr)
	end
	
	local Upgrades = PlrUpgrades.GetUpgradeTable(plr)
	if Upgrades.RespawnTime then task.wait(Upgrades.RespawnTime.Value) else task.wait(1.65)	end
	Functions.AssignEnemy(plr)
	
	return true
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

-- Gives enemy an enemy to defeat
Functions.AssignEnemy = function(plr: Player) -- SERVER ONLY
	local PlayerStats = plr:WaitForChild("PlayerStats")
	local CurrentEnemy = PlayerStats.CurrentEnemy

	-- ENEMY STAT VALUES

	local EnemyLevel: IntValue = CurrentEnemy.Level
	local EnemyHealth: IntValue = CurrentEnemy.HP
	CurrentEnemy.Rank.Value = Functions.GetIndexFromRank(Functions.AssignRank())
	
	--

	local ChooseEnemy = function() -- CHOOSES ENEMY
		local PossibleEnemyCount = 0
		local PossibleEnemies = {}

		for _, Unit in UnitTable do

			if Unit.MinimumRound <= PlayerStats.Round.Value then
				PossibleEnemyCount += 1
				table.insert(PossibleEnemies, Unit)
			end

		end

		local EnemyChosen = math.random(1,PossibleEnemyCount) -- ENEMY CHOSEN			
		return PossibleEnemies[EnemyChosen]
	end

	local Enemy = ChooseEnemy()
	CurrentEnemy.Value = Enemy.Name

	-- SETTING STATS OF ENEMY
	EnemyLevel.Value = PlayerStats.Round.Value + math.random(-1,2)
	if EnemyLevel.Value < 1 then EnemyLevel.Value = 1 end

	local UnitDamage = Functions.CalculateDamage(Enemy.Name, EnemyLevel.Value, CurrentEnemy.Rank.Value)
	EnemyHealth.Value = math.floor((UnitDamage * GlobalConfig.Enemy_HP_Multiplier) * (1 + PlayerStats.Round.Value/12))
	
	if PlayerStats.EnemiesDefeated.Value % 9 == 0 and PlayerStats.EnemiesDefeated.Value ~= 0 then -- CHECKS IF ENEMY IS A BOSS
		EnemyHealth.Value = math.floor((Functions.CalculateDamage(Enemy.Name, EnemyLevel.Value, CurrentEnemy.Rank.Value) * GlobalConfig.Boss_HP_Multiplier) * (1 + PlayerStats.Round.Value/12))
		PlayerStats.CurrentEnemy.Boss.Value = true
		print("BOSS")
	else PlayerStats.CurrentEnemy.Boss.Value = false end
	
	--
	Events.EnemyRespawned:FireClient(plr, CurrentEnemy)
	
end

-- Equips Unit for player
Functions.EquipUnit = function(plr, UnitKey)
	local DataStore = require(script.Parent.Parent.Datastore) -- Datastore
	local DataStoreTable = DataStore.GetPlayerDataTable(plr)
	local Inventory = DataStoreTable["Unit Inventory"]
	
	local PlayerStats = plr:WaitForChild("PlayerStats")
	local UnitEquipped = Inventory[tostring(UnitKey)]
	
	local SetUnitValues = function(Unit, UnitEquipped) -- Sets up values in the workspace
		Unit.Value = UnitEquipped.Name
		Unit.Level.Value = UnitEquipped.Level
		Unit.Rank.Value = UnitEquipped.Rank
		Unit.key.Value = UnitKey
	end
	
	if not UnitEquipped.Equipped == true then
		Functions.UnequipUnit(plr, UnitKey)
	else
		for _, Unit: IntValue in pairs(PlayerStats.Units:GetChildren()) do		
			if Unit:FindFirstChild("Level").Value == 0 then -- Sets up unit in the players equipped units.
				
				SetUnitValues(Unit, UnitEquipped)
				UnitEquipped.Equipped = true
				
				PlayerHandler.Notify(plr, "Summon Equipped!")
				
				local DataStoreTable = DataStore.GetPlayerDataTable(plr)
				local NewPlayerStats = DataStoreTable["PlayerStats"]
				NewPlayerStats[Unit.Name] = UnitKey
	
				DataStore.UpdatePlayerData(plr, "PlayerStats", NewPlayerStats)
				
				Events.UpdateInventory:FireClient(plr)
				
				task.spawn(function()
					while UnitEquipped.Equipped == true do
						SetUnitValues(Unit, UnitEquipped)
						task.wait()
					end
				end)
				
			return end	
		end
	end
	
end

-- Unequips unit
Functions.UnequipUnit = function(plr, UnitKey)
	local DataStore = require(script.Parent.Parent.Datastore)
	local DataStoreTable = DataStore.GetPlayerDataTable(plr)
	local Inventory = DataStoreTable["Unit Inventory"]

	local PlayerStats = plr:WaitForChild("PlayerStats")
	print(UnitKey)
	for _, Unit: IntValue in pairs(PlayerStats.Units:GetChildren()) do		
		if Unit.key.Value == UnitKey then
			Unit.Value = ""
			Unit.key.Value = 0
			Unit.Level.Value = 0
			Unit.Rank.Value = 0
			
			Inventory[tostring(UnitKey)].Equipped = false
			
			local NewPlayerStats = DataStoreTable["PlayerStats"]
			NewPlayerStats[Unit.Name] = nil
			DataStore.UpdatePlayerData(plr, "PlayerStats", NewPlayerStats)
			DataStore.UpdatePlayerData(plr, "Unit Inventory", Inventory)

			Events.UpdateInventory:FireClient(plr)
		end
	end
	
	Inventory[tostring(UnitKey)].Equipped = false
end

-- Activate units (so they can attack)
Functions.ActivateUnits = function(plr: Player)
	-- Setting up the enemy in the workspace so the units can attack it.
	local EnemyAlive = true
	local Enemy = plr.PlayerStats.CurrentEnemy 
	local EnemyHealth = plr.PlayerStats.CurrentEnemy.HP
	local Units = plr.PlayerStats.Units

	-- Adds the functionality for units to attack this enemy.
	local AttackFunction = function(Unit)		
		task.spawn(function()
			
			while plr do
				-- Checks if there is a unit equipped and the enemy is alive, then making it so that unit attacks the enemy.
				if Unit.Value ~= "" and Unit.Value ~= nil and EnemyHealth.Value > 0 and EnemyAlive == true then
					local Damage = Functions.CalculateDamage(Unit.Value, Unit.Level.Value, Unit.Rank.Value)
					plr.PlayerStats.CurrentEnemy.HP.Value -= Damage	
					Events.UnitAttacks:FireClient(plr, Unit.Name) -- VFX
					
					task.spawn(function()
						plr.PlayerStats.DPS.Value += Damage
						task.wait(1)
						plr.PlayerStats.DPS.Value -= Damage
					end)
					
					local Unit = Functions.FindUnit(Unit.Value)
					task.wait(Unit.CD)
				end

					-- Debounce timer
				task.wait(math.random(5,7)/100)
			end

		end)		
	end
	
	task.spawn(function()
	
	while plr do

		if EnemyHealth.Value <= 0 and EnemyAlive == true then
			EnemyAlive = false
			Functions.UnitDefeated(plr, Enemy)
			task.wait(1.15)
			EnemyAlive = true
		end
		
		task.wait(.05)
	end
	
	end)
	
	for _, Unit in pairs(Units:GetChildren()) do AttackFunction(Unit) end

end

-- INVENTORY STUFF

Functions.DeleteUnit = function(plr: Player, UnitKey) -- Deletes unit from inventory
	local DataStore = require(Modules.Datastore)
	local DataStoreTable = GetDataTable(plr)

	Functions.UnequipUnit(plr, UnitKey)
	local NewUnitInventory = DataStoreTable["Unit Inventory"]
	NewUnitInventory[tostring(UnitKey)] = nil
	
	task.wait(.05)
	DataStore.UpdatePlayerData(plr, "Unit Inventory", NewUnitInventory)
	Events.UpdateInventory:FireClient(plr)
end

Functions.AddUnit = function(plr: Player, Unit) -- SERVER ONLY - Adds unit to inventory
	local DataStore = require(Modules.Datastore)
	local DataStoreTable = GetDataTable(plr)
	
	local NewUnitInventory = DataStoreTable["Unit Inventory"]
	NewUnitInventory[tostring(math.random(1,147483647))] = Unit -- Creates random key for unit and adds the unit into the inventory table.
	
	DataStore.UpdatePlayerData(plr, "Unit Inventory", NewUnitInventory)
	Events.UpdateInventory:FireClient(plr)
end

Functions.GetInventory = function(plr: Player) -- SERVER ONLY
	local DataStoreTable = GetDataTable(plr)
	return DataStoreTable
end

-- Inventory Units have (LEVEL, DAMAGE, RANK)

-- RoundStuff

Functions.NextRound = function(plr) -- Advances to the next round after defeating a certain amount of enemies.
	if plr.PlayerStats.EnemiesDefeated.Value >= 10 then
		plr.PlayerStats.EnemiesDefeated.Value = 0
		plr.PlayerStats.Round.Value += 1
		PlayerHandler.Notify(plr, "Round ".. tostring(plr.PlayerStats.Round.Value))
		Functions.AssignEnemy(plr)
	end
end

return Functions
