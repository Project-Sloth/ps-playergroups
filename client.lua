local QBCore = exports['qb-core']:GetCoreObject()
local currentJobStage = "WAITING"
local GroupID = 0
local isGroupLeader = false
local GroupBlips = {}

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if GroupID ~= nil then
        TriggerServerEvent("groups:leaveGroup", GroupID)
        currentJobStage = "WAITING"
        GroupID = 0
        isGroupLeader = false
        for i=1,#GroupBlips do 
            RemoveBlip(GroupBlips[i]["blip"])
            GroupBlips[i] = nil
        end
    end
end)


RegisterNetEvent("groups:createBlip", function(name, data)

    if data == nil then return print("Invalid Data was passed to the create blip event") end

    if FindBlipByName(name) then
        TriggerEvent("groups:removeBlip", name)
    end

    local blip = nil
    if data.entity then
        blip = AddBlipForEntity(data.entity)
    elseif data.netId then 
        blip = AddBlipForEntity(NetworkGetEntityFromNetworkId(data.netId))
    elseif data.radius then
        blip = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, data.radius)
    else
        blip = AddBlipForCoord(data.coords)
    end

    if data.color == nil then data.color = 1 end
    if data.alpha == nil then data.alpha = 255 end

    if not data.radius then
        if data.sprite == nil then data.sprite = 1 end
        if data.scale == nil then data.scale = 0.7 end
        if data.label == nil then data.label = "NO LABEL FOUND" end

        SetBlipSprite(blip, data.sprite)
        SetBlipScale(blip, data.scale)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(data.label)
        EndTextCommandSetBlipName(blip)
    end
    
    SetBlipColour(blip, data.color)
    SetBlipAlpha(blip, data.alpha)

    if data.route then 
        SetBlipRoute(blip, true)
        if not data.routeColor then data.routeColor = data.color end
        SetBlipRouteColour(blip, data.routeColor)
    end
    GroupBlips[#GroupBlips+1] = {name = name, blip = blip}
end)

RegisterNetEvent("groups:removeBlip", function(name)
    local i = FindBlipByName(name)
    if i then
        local blip = GroupBlips[i]["blip"]
        SetBlipRoute(blip, false)
        RemoveBlip(blip)
        GroupBlips[i] = nil
    end
end)

-- Locations blip by the name of the group blip and returns its index in the table.
function FindBlipByName(name)
    for i=1, #GroupBlips do
        if GroupBlips[i] ~= nil then
            if GroupBlips[i]["name"] == name then
                return i
            end
        end
    end
    return false
end

function openGroupMenu()
    SendNUIMessage({ action = "open" })
    SetNuiFocus(true, true)
end

RegisterNetEvent("groups:updateJobStage", function(stage)
    currentJobStage = stage
    SendNUIMessage({ 
        action = "update",
        type = "setStage",
        data = {stage = stage},
    })
end)

RegisterNetEvent("groups:UpdateGroupData", function(data)
    SendNUIMessage({ 
        action = "update",
        type = "update",
        data = data,
    })
end)

RegisterNetEvent("groups:JoinGroup", function(id)
    GroupID = id
    SendNUIMessage({ 
        action = "join",
        groupID = id,
    })
end)

RegisterNetEvent("groups:UpdateLeader", function()
    isGroupLeader = true
    SendNUIMessage({ 
        action = "makeLeader",  
    })
end)

RegisterNetEvent("groups:GroupDestroy", function()
    currentJobStage = "WAITING"
    GroupID = 0
    isGroupLeader = false
    SendNUIMessage({ 
        action = "update",
        type = "groupDestroy",
    })
end)

-- NUI Callbacks

RegisterNUICallback('close', function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback('group-create', function(data, cb)
    local p = promise.new()
    QBCore.Functions.TriggerCallback("groups:requestCreateGroup", function(r)
        p:resolve(r)
    end)
    local d = Citizen.Await(p)
    cb(d)
end)

RegisterNUICallback('group-created', function(data)
    currentJobStage = data.status
    GroupID = data.GroupID
    isGroupLeader = data.leader
end)


RegisterNUICallback('getActiveGroups', function(data, cb)
    local request = promise.new()
    QBCore.Functions.TriggerCallback("groups:getActiveGroups", function(result)
        request:resolve(result)
    end)
    local data = Citizen.Await(request)
    cb(data)
end)

local requestCooldown = false
RegisterNUICallback('request-join', function(data, cb)
    if not requestCooldown then
        local request = promise.new()
        QBCore.Functions.TriggerCallback("groups:requestJoinGroup", function(result)
            request:resolve(result)
        end, data.groupID)
        local data = Citizen.Await(request)
        if request then 
            QBCore.Functions.Notify("Join request sent", "success")
        else 
            QBCore.Functions.Notify("You cannot do that yet", "error")
        end
        requestCooldown = true
        Wait(5000)
        requestCooldown = false
    else 
        QBCore.Functions.Notify("You need to wait before requesting again", "error")
    end
end)

RegisterNUICallback('view-requests', function(data, cb)
    local request = promise.new()
    QBCore.Functions.TriggerCallback("groups:getGroupRequests", function(result)
        request:resolve(result)
    end, data.groupID)
    local data = Citizen.Await(request)
    cb(data)
end)

RegisterNUICallback('update-status', function(data)
    currentJobStage = data.status
    QBCore.Functions.Notify("Your group status changed to "..currentJobStage, "primary")
end)

RegisterNUICallback('request-accept', function(data)
    TriggerServerEvent("groups:acceptRequest", data.player, data.groupID)
end)

RegisterNUICallback('request-deny', function(data)
    TriggerServerEvent("groups:denyRequest", data.player, data.groupID)
end)

RegisterNUICallback('member-kick', function(data)
    TriggerServerEvent("groups:kickMember", data.player, data.groupID)
end)

RegisterNUICallback('group-leave', function(data)
    TriggerServerEvent("groups:leaveGroup", data.groupID)
    currentJobStage = "WAITING"
    GroupID = 0
    isGroupLeader = false
    for i=1,#GroupBlips do 
        RemoveBlip(GroupBlips[i]["blip"])
        GroupBlips[i] = nil
    end
end)

RegisterNUICallback('group-destroy', function()
    TriggerServerEvent("groups:destroyGroup")
end)


RegisterCommand('group', function()
    openGroupMenu()
end)
RegisterKeyMapping("group", "Open Group Menu", "keyboard", "")


-- Returns Client side job stage
exports("GetJobStage", function()
    return currentJobStage
end)

-- Returns Clients current groupID
exports("GetGroupID", function()
    return GroupID
end)

-- Returns if the Client is the group leader.
exports("IsGroupLeader", function()
    return isGroupLeader
end)