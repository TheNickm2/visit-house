--[[
Function name: VisitHouse
Parameter(s) required: target playername as input
Purpose: Take the provided player name and attempt to jump to their primary residence via the ESO API
Returns: nil
--]]
function VisitHouse(input)
    local playerName = input
    if not StartsWith(playerName, '@') then
        playerName = '@'..input
    end
    d('Teleporting to the primary residence of '..playerName..'...')
    JumpToHouse(playerName)
end

--[[
Function name: LoadPlayers
Parameter(s) required: none
Purpose: Load all players from the user's group, friend, and guild lists into a single array to use as command autocomplete output
Returns: Array<String> of player names
--]]
function LoadPlayers()
    local playersList, groupList, friendsList, guildList = {},LoadGroup(),LoadFriends(),LoadGuildmates()
    for i, player in ipairs(groupList) do
        table.insert(playersList, player)
    end
    for i, player in ipairs(friendsList) do
        table.insert(playersList, player)
    end
    for i, player in ipairs(guildList) do
        table.insert(playersList, player)
    end

    local hash = {}
    local playersListTrimmed = {}
    for _,v in ipairs(playersList) do
        if not hash[v] then
            playersListTrimmed[#playersListTrimmed+1] = v
            hash[v] = true
        end
    end
    return playersListTrimmed
end

--[[
Function name: LoadGroup
Parameter(s) required: none
Purpose: Load all players from the user's group and return the list of player names
Returns: Array<String> of player names
--]]
function LoadGroup()
    local group = {}
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        local displayName = GetUnitDisplayName(unitTag)
        if(displayName ~= playerDisplayName) then
            table.insert(group, displayName)
        end
    end
    return group
end

--[[
Function name: LoadFriends
Parameter(s) required: none
Purpose: Load all players from the user's friends list and return the list of player names
Returns: Array<String> of player names
--]]
function LoadFriends()
    local friends = {}
    for i = 1, GetNumFriends() do
        local displayName = GetFriendInfo(i)
        if(displayName ~= playerDisplayName) then
            table.insert(friends, displayName)
        end
    end
    return friends
end

--[[
Function name: LoadGuildmates
Parameter(s) required: none
Purpose: Load all players from all of the user's guilds and return the list of player names
Returns: Array<String> of player names
--]]
function LoadGuildmates()
    local guildMembers = {}
    for g = 1, GetNumGuilds() do
        local guildId = GetGuildId(g)
        for i = 1, GetNumGuildMembers(guildId) do
            local displayName = GetGuildMemberInfo(guildId, i)
            if(displayName ~= playerDisplayName) then
                table.insert(guildMembers, displayName)
            end
        end
    end
    return guildMembers
end

--[[
Function name: StartsWith
Parameter(s) required: none
Purpose: Load all players from the user's friends list and return the list of player names
Returns: Boolean
--]]
function StartsWith(str, start)
    return str:sub(1, #start) == start
end

-- Initialize command with aliases and load the player list into the command autocomplete
playerDisplayName = GetDisplayName()
local LSC = LibSlashCommander
local command = LSC:Register()
command:AddAlias("/visit")
command:AddAlias("/gotohouse")
command:AddAlias("/jumptohouse")
command:SetCallback(VisitHouse)
command:SetDescription("Jump to a player's house")
local allPlayers = LoadPlayers()
d(allPlayers)
command:SetAutoComplete(allPlayers)