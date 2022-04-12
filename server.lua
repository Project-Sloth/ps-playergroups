local QBCore = exports['qb-core']:GetCoreObject()
local Groups = {} -- Don't Touch
local Players = {} -- Don't Touch
local Requests = {} -- Don't Touch

local GroupLimit = 4 -- Maximum Number of players allowed per group


-- Removes player from group when they leave the server.
AddEventHandler('playerDropped', function(reason)
	local src = source
	
    local groupID = FindGroupByMember(src)
    if groupID > 0 then
        if isGroupLeader(src) then 
            if ChangeGroupLeader(src) then
                TriggerClientEvent("groups:UpdateLeader", Groups[groupID]["members"]["leader"])
            else 
                DestroyGroup(groupID)
            end 
        else 
            RemovePlayerFromGroup(groupID, src)
        end 
    end	
end)

-- Player sends a requested asking the server if they can create a group.
QBCore.Functions.CreateCallback("groups:requestCreateGroup", function(source, cb)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not Players[src] then 
        Players[src] = true
        Groups[#Groups+1] = {
            status="WAITING", 
            members={
                leader = src,
                helpers= {},
            }
        }
        cb({ groupID = #Groups, name = GetPlayerCharName(src), id = src })
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
            table.insert(temp, {name = GetPlayerCharName(v["members"]["leader"]), id = k})
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
    if not Players[src] then
        if Groups[groupID] then 
            if #Groups[groupID]["members"] < GroupLimit then
                if Requests[groupID] == nil then 
                    Requests[groupID] = {}
                end
                table.insert(Requests[groupID], src)
                cb(true)
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

-- Removes player from the specified group.
function RemovePlayerFromGroup(player, groupID)
    if Players[player] then 
        if Groups[groupID] then
            local g = Groups[groupID]["members"]["helpers"]
            for k,v in pairs(g) do 
                if v == player then
                    Groups[groupID]["members"]["helpers"][k] = nil
                    Players[player] = nil
                end
            end
            TriggerClientEvent("QBCore:Notify", player, "You have left the group", "primary")
            UpdateGroupData(groupID)
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

function ChangeGroupLeader(groupID)
    local m = getGroupMembers(groupID)
    local l = GetGroupLeader(groupID)
    if #m > 1 then 
        for i=1, #m do 
            if m[i] ~= l then 
                Groups[groupID]["members"]["leader"] = m[i]
                Groups[groupID]["members"]["helpers"][i] = nil
                return true
            end
        end
        return false
    end
    return false
end

function DestroyGroup(groupID)
    local m = getGroupMembers(groupID)
    removeGroupMembers(groupID)
    for i=1, #m do 
         TriggerClientEvent("groups:groupUpdate", m[i])
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
