--[[
        SonoranCAD FiveM - A SonoranCAD integration for FiveM servers
              Copyright (C) 2020  Sonoran Software Systems LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program in the file "LICENSE".  If not, see <http://www.gnu.org/licenses/>.
]]

---------------------------------------------------------------------------
-- Client Data Processing for Live Map Blip
---------------------------------------------------------------------------
local playerBlipData = {
    ["pos"] = { x=0, y=0, z=0 },
    ["icon"] = 6, -- Curent player blip id
    ["iconcolor"] = 0, -- Blip Color, Used to show job type
    ["name"] = "NOT SET",
    ["Unit Number"] = "0",
    ["Status"] = "UNAVALIABLE",
    ["Call Assignment"] = "UNASSIGNED"
}

-- Table to keep track of the updated data
local beenUpdated =  {}

function updateData(name, value)
    print("updated data: " .. name .. " - " .. dump(value))
    table.insert(beenUpdated, name)
    playerBlipData[name] = value
end

function getCharName()
    local pid = GetPlayerServerId(player)
    local identity = nil
    GetIdentity(function(data)
        if data == nil then 
            print("ERROR: Failed to obtain character name!")
            return 
        end
        playerBlipData.name = returnedIdentity.firstname .. " " .. returnedIdentity.lastname
    end, pid)
end

RegisterNetEvent('sonorancad:livemap:unitUpdate')
AddEventHandler('sonorancad:livemap:unitUpdate', function(data)
    if playerBlipData['Unit Number'] ~= data.unitNumber then
        updateData('Unit Number', data.unitNumber)
    end
    if playerBlipData['Status'] ~= data.unitStatus then
        updateData('Status', data.unitStatus.label)
    end
    if playerBlipData['name'] ~= data.unitName then
        updateData('name', data.unitName)
    end
    if data.callStatus ~= '' then
        if playerBlipData['Call Assignment'] ~= data.callStatus then
            updateData('Call Assignment', data.callStatus)
        end
    end
end)

local firstSpawn = true
--[[
    When the player spawns, make sure we set their ID in the data that is going
        to be sent via sockets.
]]
AddEventHandler("playerSpawned", function(spawn)
    if firstSpawn then
        TriggerServerEvent("sonorancad:livemap:playerSpawned") -- Set's the ID in "playerData" so it will get send va sockets

        -- Now send the default data set
        for key,val in pairs(playerBlipData) do
            TriggerServerEvent("sonorancad:livemap:AddPlayerData", key, val)
        end

        firstSpawn = false
    end
end)

---------------------------------------------------------------------------
-- Thread that checks for data updates and updates server
---------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)
        if NetworkIsPlayerActive(PlayerId()) then
            -- Update position, if it has changed
            local x,y,z = table.unpack(GetEntityCoords(PlayerPedId()))
            local x1,y1,z1 = playerBlipData["pos"].x, playerBlipData["pos"].y, playerBlipData["pos"].z

            local dist = Vdist(x, y, z, x1, y1, z1)

            if (dist >= 5) then
                -- Update every 5 meters.. Let's reduce the amount of spam
                updateData("pos", {x = x, y=y, z=z})
            end
            -- Make sure the updated data is up-to-date on socket server as well
            for i,k in pairs(beenUpdated) do
                --Citizen.Trace("Updating " .. k)
                TriggerServerEvent("sonorancad:livemap:UpdatePlayerData", k, playerBlipData[k])
                table.remove(beenUpdated, i)
            end
        end
    end
end)