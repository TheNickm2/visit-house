--[[
function name: StartsWith
Parameter(s) required: str = string to test, start = character to test at start of string
Purpose: Abstract away the annoying syntax to check if a string starts with a specific character
Returns: Boolean
--]]
local function StartsWith(str, start)
    return str:sub(1, #start) == start
end

--[[
function name: IsEmpty
Parameter(s) required: str = string to test
Purpose: Abstract away the syntax to check if a string nil OR empty
Returns: Boolean
--]]
local function IsEmpty(str)
    return str == nil or str == ""
end

local function SplitString(inputstr, splitter)
    if splitter == nil then
        splitter = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. splitter .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function TableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

--[[
function name: VisitHouse
Parameter(s) required: target playername as input
Purpose: Take the provided player name and attempt to jump to their primary residence via the ESO API
Returns: nil
--]]
local function VisitHouseAutoComplete(input, allHouses)
    if (not input) or (input == "") or (input == nil) or (not input.player) then
        return
    end

    if (not StartsWith(input.player, "@")) then
        input.player = "@" .. input.player
    end

    if (IsEmpty(input.house)) then
        d("Teleporting to the primary residence of " .. input.player .. "...")
        JumpToHouse(input.player)
    else
        local houseId = -1
        for _, house in pairs(allHouses) do
            if (input.house:lower() == house.name:lower()) then
                houseId = house.id
                input.house = house.name
                break
            end
        end
        if (houseId == -1) then
            d("Unable to find a house named " .. input.house ..
                  ". The name of the house must match the in-game spelling (case insensitive, but punctuation is required - e.g. Water's Edge requires the single quote). If you believe this is an error, please send @TheNickm2 an in-game mail describing the issue.")
            return
        end
        d("Teleporting to " .. input.player .. '\'s "' .. input.house .. '"...')
        JumpToSpecificHouse(input.player, houseId)
    end
end

local function VisitHouseManual(input, allHouses)
    local strSplit = SplitString(input)
    local player = strSplit[1]
    if not player then
        return
    end
    local houseName = input:gsub(player, ""):gsub('^%s*(.-)%s*$', '%1')
    if (not StartsWith(player, '@')) then
        player = '@' .. player
    end

    local tableLength = TableLength(strSplit)
    if (tableLength <= 1) then
        d("Teleporting to the primary residence of " .. player .. "...")
        JumpToHouse(player)
    else
        if not houseName then
            -- Fallback to teleport to the user's primary house if no house is specified - shouldn't be possible but just in case
            d("Teleporting to the primary residence of " .. player .. "...")
            JumpToHouse(player)
            return
        end
        local houseId = -1
        for _, house in pairs(allHouses) do
            if (houseName:lower() == house.name:lower()) then
                houseId = house.id
                houseName = house.name
                break
            end
        end
        if (houseId == -1) then
            d("Unable to find a house named " .. houseName ..
                  ". The name of the house must match the in-game spelling (case insensitive, but punctuation is required - e.g. Water's Edge requires the single quote). If you believe this is an error, please send @TheNickm2 an in-game mail describing the issue.")
        else
            d("Teleporting to " .. player .. '\'s "' .. houseName .. '"...')
            JumpToSpecificHouse(player, houseId)
        end
    end
end

--[[
function name: LoadGroup
Parameter(s) required: none
Purpose: Load all players from the user's group and return the list of player names
Returns: Array<String> of player names
--]]
local function LoadGroup(playerName)
    local group = {}
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        local displayName = GetUnitDisplayName(unitTag)
        if (displayName ~= playerName) then
            table.insert(group, displayName)
        end
    end
    return group
end

--[[
function name: LoadFriends
Parameter(s) required: none
Purpose: Load all players from the user's friends list and return the list of player names
Returns: Array<String> of player names
--]]
local function LoadFriends(playerName)
    local friends = {}
    for i = 1, GetNumFriends() do
        local displayName = GetFriendInfo(i)
        if (displayName ~= playerName) then
            table.insert(friends, displayName)
        end
    end
    return friends
end

--[[
function name: LoadGuildmates
Parameter(s) required: none
Purpose: Load all players from all of the user's guilds and return the list of player names
Returns: Array<String> of player names
--]]
local function LoadGuildmates(playerName)
    local guildMembers = {}
    for g = 1, GetNumGuilds() do
        local guildId = GetGuildId(g)
        for i = 1, GetNumGuildMembers(guildId) do
            local displayName = GetGuildMemberInfo(guildId, i)
            if (displayName ~= playerName) then
                table.insert(guildMembers, displayName)
            end
        end
    end
    return guildMembers
end

--[[
function name: LoadPlayers
Parameter(s) required: none
Purpose: Load all players from the user's group, friend, and guild lists into a single array to use as command autocomplete output
Returns: Array<String> of player names
--]]
local function LoadPlayers(playerName)
    local playersList, groupList, friendsList, guildList = {}, LoadGroup(playerName), LoadFriends(playerName), LoadGuildmates(playerName)
    for _, player in ipairs(groupList) do
        table.insert(playersList, player)
    end
    for _, player in ipairs(friendsList) do
        table.insert(playersList, player)
    end
    for _, player in ipairs(guildList) do
        table.insert(playersList, player)
    end

    local hash = {}
    local playersListTrimmed = {}
    for _, v in ipairs(playersList) do
        if not hash[v] then
            playersListTrimmed[#playersListTrimmed + 1] = v
            hash[v] = true
        end
    end
    return playersListTrimmed
end

--[[
function name: LoadHouses
Parameter(s) required: none
Purpose: Load all ESO Houses into a table for ID look-up by name
Returns: Table<String, Number> of player houses
--]]
local function LoadHouses()
    local allHouses = {}
    for houseId = 1, 200 do
        local houseName = GetCollectibleName(GetCollectibleIdForHouse(houseId))
        table.insert(allHouses, {
            name = houseName,
            id = houseId
        })
    end
    table.sort(allHouses, function(left, right)
        local leftVal, rightVal = "", ""
        if (StartsWith(left.name, "The ")) then
            leftVal = left.name:gsub("The ", "")
        else
            leftVal = left.name
        end
        if (StartsWith(right.name, "The ")) then
            rightVal = right.name:gsub("The ", "")
        else
            rightVal = right.name
        end
        return leftVal < rightVal
    end)
    return allHouses
end

-- Initialize command with aliases and load the player list into the command autocomplete
local function LoadAddon()
    local playerDisplayName = GetDisplayName()
    local allPlayers = LoadPlayers(playerDisplayName)
    local houses = LoadHouses()

    local houseNames = {}
    for _, house in pairs(houses) do
        if (not IsEmpty(house.name)) then
            table.insert(houseNames, house.name)
        end
    end
    
    local LSC = LibSlashCommander
    local command = LSC:Register()
    command:AddAlias("/visit")
    command:AddAlias("/gotohouse")
    command:AddAlias("/jumptohouse")
    command:SetDescription("Visit a player's in-game home")
    command:SetCallback(function(input)
        VisitHouseManual(input, houses)
    end)
    command:SetDescription("Jump to a player's house")

    for _, player in pairs(allPlayers) do
        local subCmd = command:RegisterSubCommand()
        subCmd:AddAlias(player)
        subCmd:SetCallback(function(input)
            local inputData = {
                player = player,
                house = input
            }
            VisitHouseAutoComplete(inputData, houses)
        end)
        subCmd:SetAutoComplete(houseNames)
    end
end
LoadAddon()
