local QBCore = exports['qb-core']:GetCoreObject()
local Groups = {} -- Don't Touch
local Players = {} -- Don't Touch
local Requests = {} -- Don't Touch
local GroupData = {} -- Don't Touch

local GroupLimit = 4 -- Maximum Number of players allowed per group


-- Removes player from group when they leave the server.
AddEventHandler('playerDropped', function(reason)
	local src = source
    local groupID = FindGroupByMember(src)
    if groupID > 0 then 
        RemovePlayerFromGroup(src, groupID) -- This function now handles changing leader as well.
    end	
end)

-- Player sends a requested asking the server if they can create a group.
QBCore.Functions.CreateCallback("groups:requestCreateGroup", function(source, cb)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not Players[src] then
        Players[src] = true
        local groupID = #Groups+1
        Groups[groupID] = {
            status="WAITING", 
            members = {
                leader = src,
                helpers= {},
            }
        }
        GroupData[groupID] = {}
        cb({ groupID = groupID, name = GetPlayerCharName(src), id = src })
    else
        TriggerClientEvent("QBCore:Notify", src, "You are already in a group", "error")
        cb(false)
    end
end)

-- Get all active groups currently in the server.
QBCore.Functions.CreateCallback("groups:getActiveGroups", function(source, cb)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    local temp = {}
    for k,v in pairs(Groups) do
        if Groups[k] ~= nil then 
            if v.status == "WAITING" then
                table.insert(temp, {name = GetPlayerCharName(v["members"]["leader"]), id = k})
            end
        end
    end
    cb(temp)
end)

-- Returns all current join requests for the specified groupID.
QBCore.Functions.CreateCallback("groups:getGroupRequests", function(source, cb, groupID)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    local temp = {}
    if Requests[groupID] then 
        for k,v in pairs(Requests[groupID]) do
            table.insert(temp, {name = GetPlayerCharName(v), id = v})
        end
        cb(temp)
    else 
        cb(temp)
    end
end)

-- Sends a request to join the specified groupID
QBCore.Functions.CreateCallback("groups:requestJoinGroup", function(source, cb, groupID)
    local src = source
    local lead = Groups[groupID]["members"]["leader"]
    if not Players[src] then
        if Groups[groupID] then 
            if #Groups[groupID]["members"] < GroupLimit then
                if Requests[groupID] == nil then 
                    Requests[groupID] = {}
                end
                table.insert(Requests[groupID], src)
                cb(true)
                TriggerClientEvent("QBCore:Notify", lead, "Someone has requested to join the group", "success")
            else
                TriggerClientEvent("QBCore:Notify", src, "The group is full", "error")
            end
        else 
            TriggerClientEvent("QBCore:Notify", src, "That group doesn't exist", "error")
        end
        cb(true)
    else
        TriggerClientEvent("QBCore:Notify", src, "You already have a request pending", "error")
        cb(false)
    end
end)

-- Accept the pending join request.
RegisterNetEvent("groups:acceptRequest", function(player, groupID)
    local src = source
    if AddPlayerToGroup(player, groupID) then
        for k,v in pairs(Requests[groupID]) do
            if v == player then
                Requests[groupID][k] = nil
            end
        end
        TriggerClientEvent("QBCore:Notify", player, "Your group join request was accepted", "success")
        TriggerClientEvent("groups:JoinGroup", player, groupID)
    end
end)

-- Deny the pending join request.
RegisterNetEvent("groups:denyRequest", function(player, groupID)
    local src = source
    for k,v in pairs(Requests[groupID]) do
        if v == player then
            Requests[groupID][k] = nil
        end
    end
    TriggerClientEvent("QBCore:Notify", player, "Your group join request was denied", "error")
end)

-- Kicks the specified player from the group.
RegisterNetEvent("groups:kickMember", function(player, groupID)
    RemovePlayerFromGroup(player, groupID)
    TriggerClientEvent("QBCore:Notify", player, "You were removed from the group", "error")
end)

-- Returns all members in the specified groupID.
QBCore.Functions.CreateCallback("groups:getGroupMembers", function(source, cb, groupID)
    local src = source
    local temp = {}
    local members = getGroupMembers(groupID)
    for i=1, #members do 
        temp[#temp+1] = {id = members[i], name = GetPlayerCharName(members[i])}
    end
    cb(temp)
end)

-- Leave the speicifed group.
RegisterServerEvent("groups:leaveGroup", function(groupID)
    local src = source
    RemovePlayerFromGroup(src, groupID)
end)

-- Destroy a group object.
-- This is called when the leader leaves the group.
RegisterServerEvent("groups:destroyGroup", function()
    local src = source
    local g = FindGroupByMember(src)
    
    if g > 0 then
        DestroyGroup(g)
    else 
        print("Unable to destory group as it doesn't exist.")
    end
end)

-- Adds player to specified group.
function AddPlayerToGroup(player, groupID)
    if not Players[player] then 
        if Groups[groupID] then
            Players[player] = true
            local g = Groups[groupID]["members"]["helpers"]
            g[#g+1] = player
            UpdateGroupData(groupID)
            return true
        else
            print("Group doesn't exist")
        end
    else
        print("Player is already in a group")
    end
    return false
end

-- Removes player from the specified group and will change leader if player leaving is leader
function RemovePlayerFromGroup(player, groupID)
    if Players[player] then
        if Groups[groupID] then
            local g = Groups[groupID]["members"]["helpers"]
            if Groups[groupID]["members"]["leader"] == player then
                if ChangeGroupLeader(groupID) then
                    Players[player] = nil
                    TriggerClientEvent("QBCore:Notify", player, "You have left the group", "primary")
                    Wait(10)
                    UpdateGroupData(groupID)
                else
                    Players[player] = nil
                    TriggerClientEvent("QBCore:Notify", player, "You have left the group", "primary")
                    DestroyGroup(groupID)
                end
            else
                for k,v in pairs(g) do
                    if player == v then
                        Groups[groupID]["members"]["helpers"][k] = nil
                        TriggerClientEvent('groups:GroupDestroy', v)
                        Players[player] = nil
                    end
                end
                TriggerClientEvent("QBCore:Notify", player, "You have left the group", "primary")
                Wait(10)
                UpdateGroupData(groupID)
            end
        end 
    end
end

-- Pushes current group data to the specified groupID to ALL members.
function UpdateGroupData(groupID)
    local members = getGroupMembers(groupID)
    local temp = {}
    for i=1, #members do
        temp[#temp+1] = {id = members[i], name = GetPlayerCharName(members[i])}
    end

    for i=1, #members do
        TriggerClientEvent("groups:UpdateGroupData", members[i], temp)
    end
end

-- Returns characters first and last name for the UI.
function GetPlayerCharName(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player.PlayerData.charinfo.firstname.." "..player.PlayerData.charinfo.lastname
end

-- Returns if player is the group leader.
function isGroupLeader(src)
    local group = FindGroupByMember(src)
    if src == Groups[group]["members"]["leader"] then 
        return true
    end
    return false
end

-- Remove all group members.
function removeGroupMembers(groupID)
    local g = Groups[groupID]
    for i=1, #g["members"]["helpers"] do 
        Players[g["members"]["helpers"][i]] = nil
        Groups[groupID]["members"]["helpers"][i] = nil
    end
    Players[g["members"]["leader"]] = nil
end

-- Locoate a group by player ID.
function FindGroupByMember(src)
    if Players[src] then 
        for group, data in pairs(Groups) do 
            local members = data["members"]
            if members["leader"] == src then 
                return group
            else
                for i=1, #members["helpers"] do 
                    if members["helpers"][i] == src then 
                        return group
                    end
                end
                return 0
            end
        end
    else
        return 0
    end
end
exports("FindGroupByMember", FindGroupByMember)

-- Experimental
function ChangeGroupLeader(groupID)
    -- local m = getGroupMembers(groupID)
    local m = Groups[groupID]['members']['helpers'] or {}
    local l = GetGroupLeader(groupID)
    local leaderFound = false
    local leader = 0
    for k,v in pairs(m) do
        if not leaderFound then
            if Groups[groupID]["members"]["helpers"][k] ~= l then
                Groups[groupID]["members"]["leader"] = v
                Groups[groupID]["members"]["helpers"][k] = nil
                leaderFound = true
                leader = v
            end
        end
    end
    if leader ~= 0 then
        TriggerClientEvent("groups:UpdateLeader", leader)
    end
    return leaderFound
end

-- Destroy a group object.
function DestroyGroup(groupID)
    local m = getGroupMembers(groupID)
    removeGroupMembers(groupID)
    for i=1, #m do 
         TriggerClientEvent("groups:GroupDestroy", m[i])
    end
    Groups[groupID] = nil
end

-- Returns group's leader src
function GetGroupLeader(groupID)
    if groupID == nil then return print("GetGroupLeader was sent an invalid groupID :"..groupID) end
    return Groups[groupID]["members"]["leader"]
end
exports("GetGroupLeader", GetGroupLeader)

-- Returns group's job status.
function getJobStatus(groupID)
    if groupID == nil then return print("getJobStatus was sent an invalid groupID :"..groupID) end
    return Groups[groupID]["status"]
end
exports('getJobStatus', getJobStatus)

-- Sets a group job status.
function setJobStatus(groupID, status)
    if groupID == nil then return print("setJobStatus was sent an invalid groupID :"..groupID) end
    Groups[groupID]["status"] = status
    local m = getGroupMembers(groupID)
    for i=1, #m do
        TriggerClientEvent("groups:updateJobStage", m[i], status)
    end
end
exports('setJobStatus', setJobStatus)

-- Gets number of players in a group.
function getGroupSize(groupID)
    if groupID == nil then return print("getGroupSize was sent an invalid groupID :"..groupID) end
    if Groups[groupID]["members"]["helpers"] == nil or 0 then 
        return 1
    else
        return #Groups[groupID]["members"]["helpers"] + 1
    end
end
exports('getGroupSize', getGroupSize)

-- Returns player IDs inside a table.
function getGroupMembers(groupID)
    if groupID == nil then return print("getGroupMembers was sent an invalid groupID :"..groupID) end
    local temp = {}
    temp[#temp+1] = Groups[groupID]["members"]["leader"]
    for k,v in pairs(Groups[groupID]["members"]["helpers"]) do
        temp[#temp+1] = v
    end
    return temp   
end
exports('getGroupMembers', getGroupMembers)

function CreateBlipForGroup(groupID, name, data)
    if groupID == nil then return print("CreateBlipForGroup was sent an invalid groupID :"..groupID) end

    local members = getGroupMembers(groupID)
    for i=1,#members do
        TriggerClientEvent("groups:createBlip", members[i], name, data)
    end
end
exports('CreateBlipForGroup', CreateBlipForGroup)

-- Remove a blip for everyone in a group with the matching blip name.
function RemoveBlipForGroup(groupID, name)
    if groupID == nil then return print("RemoveBlipForGroup was sent an invalid groupID :"..groupID) end
    local members = getGroupMembers(groupID)
    for i=1,#members do
        TriggerClientEvent("groups:removeBlip", members[i], name)
    end
end
exports('RemoveBlipForGroup', RemoveBlipForGroup)
-- Triggers event for each member of a group. Args are optional.
function GroupEvent(groupID, event, args)
    if groupID == nil then return print("GroupEvent was sent an invalid groupID :"..groupID) end
    if event == nil then return print("no valid event was passed to GroupEvent") end
    local members = getGroupMembers(groupID)
    for i=1,#members do
        if args ~= nil then
            TriggerClientEvent(event, members[i], table.unpack(args))
        else 
            TriggerClientEvent(event, members[i])
        end
    end
end
exports("GroupEvent", GroupEvent)

function SetGroupData(groupID, key, data)
    if groupID == nil then return print("SetGroupData was sent an invalid groupID") end
    if key == nil then return print("SetGroupData was sent an invalid key") end
    GroupData[groupID][key] = data
end
exports("SetGroupData", SetGroupData)

function GetGroupData(groupID, key)
    if groupID == nil then return print("GetGroupData was sent an invalid groupID") end
    if key == nil then return print("GetGroupData was sent an invalid key") end
    if GroupData[groupID][key] == nil then
        return false
    else
        return GroupData[groupID][key]
    end
    
end
exports("GetGroupData", GetGroupData)

function DestroyGroupData(groupID, key)
    if groupID == nil then return print("DestroyGroupData was sent an invalid groupID") end
    if key == nil then return print("DestroyGroupData was sent an invalid key") end
    GroupData[groupID][key] = nil
end
exports("DestroyGroupData", DestroyGroupData)