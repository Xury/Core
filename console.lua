-- Implements things related to console commands

function InitConsoleCommands()
	local PluginMgr = cPluginManager:Get()

	-- Please keep the list alpha-sorted
	PluginMgr:BindConsoleCommand("ban",         HandleConsoleBan,        " ~ Bans a player by name")
	PluginMgr:BindConsoleCommand("banlist ips", HandleConsoleBanList,    " - Lists all players banned by IP")
	PluginMgr:BindConsoleCommand("banlist",     HandleConsoleBanList,    " - Lists all players banned by name")
	PluginMgr:BindConsoleCommand("getversion",  HandleConsoleVersion,    " - Gets server version reported to 1.4+ clients")
	PluginMgr:BindConsoleCommand("help",        HandleConsoleHelp,       " - Lists all commands")
	PluginMgr:BindConsoleCommand("give",        HandleConsoleGive,       " - Gives items to the specified player.")
	PluginMgr:BindConsoleCommand("kick",        HandleConsoleKick,       " ~ Kicks a player by name")
	PluginMgr:BindConsoleCommand("list",        HandleConsoleList,       " - Lists all players in a machine-readable format")
	PluginMgr:BindConsoleCommand("listgroups",  HandleConsoleListGroups, " - Shows a list of all the groups")
	PluginMgr:BindConsoleCommand("numchunks",   HandleConsoleNumChunks,  " - Shows number of chunks currently loaded")
	PluginMgr:BindConsoleCommand("players",     HandleConsolePlayers,    " - Lists all connected players")
	PluginMgr:BindConsoleCommand("rank",        HandleConsoleRank,       " ~ Add a player to a group")
	PluginMgr:BindConsoleCommand("reload",      HandleConsoleReload,     " - Reloads all plugins")
	PluginMgr:BindConsoleCommand("save-all",    HandleConsoleSaveAll,    " - Saves all chunks")
	PluginMgr:BindConsoleCommand("say",         HandleConsoleSay,        " - Sends a chat message to all players")
	PluginMgr:BindConsoleCommand("setversion",  HandleConsoleVersion,    " ~ Sets server version reported to 1.4+ clients")
	PluginMgr:BindConsoleCommand("unban",       HandleConsoleUnban,      " ~ Unbans a player by name")
	PluginMgr:BindConsoleCommand("unload",      HandleConsoleUnload,     " - Unloads all unused chunks")

end

function HandleConsoleGive(Split)

	-- Make sure there are a correct number of arguments.
	if #Split ~= 3 and #Split ~= 4 and #Split ~= 5 then
		return true, "Usage: give <player> <item> [amount] [meta]"
	end

	-- Get the item from the arguments and check it's valid.
	local Item = cItem()
	if #Split == 5 then
		local FoundItem = StringToItem(Split[3] .. ":" .. Split[5], Item)
	else
		local FoundItem = StringToItem(Split[3], Item)
	end
	if not IsValidItem(Item.m_ItemType) then  -- StringToItem does not check if item is valid
		FoundItem = false
	end

	if not FoundItem  then
		return true, "Invalid item id or name!"
	end

	-- Work out how many items the user wants.
	local ItemAmount = 1
	if #Split > 3 then
		ItemAmount = tonumber(Split[4])
		if ItemAmount == nil or ItemAmount < 1 or ItemAmount > 512 then
			return true, "Invalid amount!"
		end
	end

	Item.m_ItemCount = ItemAmount

	-- Get the playername from the split.
	local playerName = Split[2]

	local function giveItems(newPlayer)
		local ItemsGiven = newPlayer:GetInventory():AddItem(Item)
		if ItemsGiven == ItemAmount then
			SendMessageSuccess( newPlayer, "There you go!" )
			LOG("Gave " .. newPlayer:GetName() .. " " .. Item.m_ItemCount .. " times " .. Item.m_ItemType .. ":" .. Item.m_ItemDamage)
		else
			SendMessageFailure( Player, "Not enough space in inventory, only gave " .. ItemsGiven)
			return true, "Only " .. Item.m_ItemCount .. " out of " .. ItemsGiven .. "items could be delivered."
		end
	end

	-- Finally give the items to the player.
	itemStatus = cRoot:Get():FindAndDoWithPlayer(playerName, giveItems)

	-- Check to make sure that giving items was successful.
	if not itemStatus then
		return true, "There was no player that matched your query."
	end

	return true

end

function HandleConsoleBan(Split)
	if (#Split < 2) then
		return true, "Usage: ban [Player] <Reason>"
	end

	local Reason = cChatColor.Red .. "You have been banned." .. cChatColor.White .. " Did you do something illegal?"
	if( #Split > 2 ) then
		Reason = table.concat(Split, " ", 3)
	end

	if KickPlayer(Split[2], Reason) == false then
		BannedPlayersIni:DeleteValue("Banned", Split[2])
		BannedPlayersIni:SetValueB("Banned", Split[2], true)
		BannedPlayersIni:WriteFile()
		LOGINFO("Could not find player, but banned anyway" )
	else
		BannedPlayersIni:DeleteValue("Banned", Split[2])
		BannedPlayersIni:SetValueB("Banned", Split[2], true)
		BannedPlayersIni:WriteFile()
		LOGINFO("Successfully kicked and banned player" )
	end

	return true
end





function HandleConsoleKick(Split)
	if (#Split < 2) then
		return true, "Usage: kick [Player] <Reason>"
	end

	local Reason = cChatColor.Red .. "You have been kicked." .. cChatColor.White
	if (#Split > 2) then
		Reason = table.concat(Split, " ", 3)
	end

	local HasKicked, PlayerName = KickPlayer(Split[2], Reason)
	if (HasKicked) then
		return true, "Successfully kicked \"" .. PlayerName .. "\""
	end

	return true, "Cannot find \"" .. Split[2] .. "\""
end





function HandleConsoleUnban(Split)

	if #Split < 2 then
		return true, "Usage: /unban [Player]"
	end

	if( BannedPlayersIni:GetValueB("Banned", Split[2], false) == false ) then
		return true, Split[2] .. " is not banned!"
	end

	BannedPlayersIni:SetValueB("Banned", Split[2], false, false)
	BannedPlayersIni:WriteFile()

	local Server = cRoot:Get():GetServer()
	return true, "Unbanned " .. Split[2]

end

function HandleConsoleBanList(Split)
	if (#Split == 1) then
		return true, BanListByName()
	end

	if (string.lower(Split[2]) == "ips") then
		return true, BanListByIPs()
	end

	return true, "Unknown banlist subcommand"
end

function HandleConsoleHelp(Split)
	local Commands = {}   -- {index => {"Command", "HelpString"} }
	local MaxLength = 0
	local AddToTable = function(Command, HelpString)
		table.insert(Commands, { Command, HelpString })
		local CmdLen = Command:len()
		if (CmdLen > MaxLength) then
			MaxLength = CmdLen
		end
	end

	cPluginManager:Get():ForEachConsoleCommand(AddToTable)

	-- Sort the table:
	local CompareCommands = function(a, b)
		return a[1] < b[1]  -- compare command strings
	end
	table.sort(Commands, CompareCommands)

	local Out = ""
	Out = "'-' denotes no prefix, '~' denotes that a value is required.\n"
	for i, Command in ipairs(Commands) do
		Out = Out .. Command[1] .. string.rep(" ", MaxLength - Command[1]:len())  -- Align to a table
		Out = Out .. Command[2] .. "\n"
	end
	return true, Out
end

function HandleConsoleList(Split)
	-- Get a list of all players, one playername per line
	local Out = ""
	cRoot:Get():ForEachWorld(
		function (a_World)
			a_World:ForEachPlayer(
				function (a_Player)
					Out = Out .. a_Player:GetName() .. "\n"
				end
			)
		end
	)
	return true, Out
end

function HandleConsoleListGroups(Split)
	-- Read the groups.ini file:
	local GroupsIni = cIniFile("groups.ini")
	if (not(GroupsIni:ReadFile())) then
		return true, "No groups found"
	end

	-- Read the groups:
	Number = GroupsIni:NumKeys()
	Groups = {}
	for i = 0, Number do
		table.insert(Groups, GroupsIni:KeyName(i))
	end

	-- Output the groups, concatenated to a string:
	local Out = "Groups:\n"
	Out = Out .. table.concat(Groups, ", ")
	return true, Out
end

function HandleConsoleNumChunks(Split)
	local Output = {}
	local AddNumChunks = function(World)
		Output[World:GetName()] = World:GetNumChunks()
	end

	cRoot:Get():ForEachWorld(AddNumChunks)

	local Total = 0
	local Out = ""
	for name, num in pairs(Output) do
		Out = Out .. "  " .. name .. ": " .. num .. " chunks\n"
		Total = Total + num
	end
	Out = Out .. "Total: " .. Total .. " chunks\n"

	return true, Out
end

function HandleConsolePlayers(Split)
	local PlayersInWorlds = {}    -- "WorldName" => [players array]
	local AddToTable = function(Player)
		local WorldName = Player:GetWorld():GetName()
		if (PlayersInWorlds[WorldName] == nil) then
			PlayersInWorlds[WorldName] = {}
		end
		table.insert(PlayersInWorlds[WorldName], Player:GetName() .. " @ " ..  Player:GetIP())
	end

	cRoot:Get():ForEachPlayer(AddToTable)

	local Out = ""
	for WorldName, Players in pairs(PlayersInWorlds) do
		Out = Out .. "World " .. WorldName .. ":\n"
		for i, PlayerName in ipairs(Players) do
			Out = Out .. "  " .. PlayerName .. "\n"
		end
	end

	return true, Out
end

function HandleConsoleVersion(Split)
	if (#Split == 1) then
		-- Display current version:
		local Version = cRoot:Get():GetPrimaryServerVersion()
		return true, "Primary server version: #" .. Version .. ", " .. cRoot:GetProtocolVersionTextFromInt(Version)
	end

	-- Set new value as the version:
	cRoot:Get():SetPrimaryServerVersion(tonumber(Split[2]))
	local Version = cRoot:Get():GetPrimaryServerVersion()
	return true, "Primary server version is now #" .. Version .. ", " .. cRoot:GetProtocolVersionTextFromInt(Version)
end

function HandleConsoleRank(Split)
	if (Split[2] == nil) or (Split[3] == nil) then
		return true, "Usage: /rank [Player] [Group]"
	end
	local Out = ""

	-- Read the groups.ini file:
	local GroupsIni = cIniFile("groups.ini")
	if (not(GroupsIni:ReadFile())) then
		Out = "Could not read groups.ini, creating anew!\n"
	end

	-- Find the group:
	if (GroupsIni:FindKey(Split[3]) == -1) then
		return true, Out .. "Group does not exist"
	end

	-- Read the users.ini file:
	local UsersIni = cIniFile("users.ini")
	if (not(UsersIni:ReadFile())) then
		Out = Out .. "Could not read users.ini, creating anew!\n"
	end

	-- Write the new group value to users.ini:
	UsersIni:DeleteKey(Split[2])
	UsersIni:GetValueSet(Split[2], "Groups", Split[3])
	UsersIni:WriteFile()

	-- Reload the player's permissions:
	cRoot:Get():ForEachWorld(
		function (World)
			World:ForEachPlayer(
				function (Player)
					if (Player:GetName() == Split[2]) then
						SendMessage( Player, "You were moved to group " .. Split[3] )
						Player:LoadPermissionsFromDisk()
					end
				end
			)
		end
	)

	return true, Out .. "Player " .. Split[2] .. " was moved to " .. Split[3]
end

function HandleConsoleReload(Split)

	cRoot:Get():BroadcastChat(cChatColor.Rose .. "[WARNING] " .. cChatColor.White .. "Reloading all plugins!")
	LOGINFO("Reloading all plugins!")
	cRoot:Get():GetPluginManager():ReloadPlugins()
	return true
end

function HandleConsoleSaveAll(Split)

	cRoot:Get():BroadcastChat(cChatColor.Rose .. "[WARNING] " .. cChatColor.White .. "Saving all chunks!")
	cRoot:Get():SaveAllChunks()
	return true
end

function HandleConsoleSay(Split)
	table.remove(Split, 1)
	local Message = ""
	for i, Text in ipairs(Split) do
		Message = Message .. " " .. Text
	end
	Message = Message:sub(2)  -- Cut off the first space
	
	cRoot:Get():BroadcastChat(cChatColor.Gold .. "[SERVER] " .. cChatColor.Yellow .. Message)
	return true
end

function HandleConsoleUnload(Split)
	local UnloadChunks = function(World)
		World:UnloadUnusedChunks()
	end

	local Out = "Num loaded chunks before: " .. cRoot:Get():GetTotalChunkCount() .. "\n"
	cRoot:Get():ForEachWorld(UnloadChunks)
	Out = Out .. "Num loaded chunks after: " .. cRoot:Get():GetTotalChunkCount()
	return true, Out
end
