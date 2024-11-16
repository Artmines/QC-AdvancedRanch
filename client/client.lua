local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedAnimals = {}
local isBusy = false
local isFollowing = false
local wanderDist = 0
local cost = 0
local isLoggedIn = false
local PlayerData = {}
local carthash
local spawncoords
local cargohash
local lightupgardehash
local maxweight
local maxslots
local SpawnedWagon = nil
local wagonSpawned = false

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function() -- Don't use this with the native method
    isLoggedIn = true
    PlayerData = RSGCore.Functions.GetPlayerData()
    TriggerEvent('qc-advancedranch:client:setupjobsystem')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() -- Don't use this with the native method
    isLoggedIn = false
    PlayerData = {}
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    TriggerEvent('qc-advancedranch:client:setupjobsystem')
end)

-------------------------------------------------------------------------------------------
-- prompts and blips
-------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    for _, v in pairs(Config.RanchLocations) do
        exports['rsg-core']:createPrompt(v.ranchid, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], 'Open '..v.name, {
            type = 'client',
            event = 'qc-advancedranch:client:mainmenu',
            args = { v.job },
        })
        if v.showblip == true then
            local RanchMenuBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords)
            SetBlipSprite(RanchMenuBlip,  joaat(Config.RanchBlip.blipSprite), true)
            SetBlipScale(RanchMenuBlip, Config.RanchBlip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, RanchMenuBlip, Config.RanchBlip.blipName)
        end
    end
end)
-------------------------------------------------------------------------------------------

RegisterNetEvent('qc-advancedranch:client:mainmenu', function(job)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerjob = PlayerData.job.name
    jobaccess = job
    if playerjob == jobaccess then
        lib.registerContext({
            id = 'ranch_mainmenu',
            title = 'Ranch Menu',
            options = {
                {
                    title = 'Ranch Boss Menu',
                    description = 'access boss menu',
                    icon = 'fa-solid fa-hat-cowboy',
                    event = 'rsg-bossmenu:client:mainmenu',
                    arrow = true
                },
                {
                    title = 'Ranch Vehicle',
                    description = 'access vehicle menu',
                    icon = 'fa-solid fa-truck-ramp-box',
                    event = 'qc-advancedranch:client:openWagonMenu',
                    arrow = true
                },
            }
        })
        lib.showContext('ranch_mainmenu')
    else
        lib.notify({ title = 'No Access', description = 'you don\'t have access to this!', type = 'error' })
    end
end)

-- setup job system
RegisterNetEvent('qc-advancedranch:client:setupjobsystem', function()
    local job = PlayerData.job.name
    for k, v in pairs(Config.JobsSettings) do
        if k == job then
            carthash = v.carthash
            spawncoords = v.spawncoords
            cargohash = v.cargohash
            lightupgardehash = v.lightupgardehash
            maxweight = v.maxweight
            maxslots = v.maxslots
        end
    end
end)


-----------------------------------------------------------------------------------

RegisterNetEvent('qc-advancedranch:client:openWagonMenu', function()
	lib.registerContext({
		id = 'jobwagon_menu',
		title = Lang:t('menu.wagon_menu'),
		options = {
			{
				title = Lang:t('menu.wagon_setup'),
				description = '',
				icon = 'fas fa-box',
				serverEvent = 'qc-advancedranch:server:SetupWagon',
				arrow = true
			},
			{
				title = Lang:t('menu.wagon_get'),
				description = '',
				icon = 'fa-solid fa-circle-arrow-up',
				iconColor = 'green',
				event = 'qc-advancedranch:client:SpawnWagon',
				arrow = true
			},
			{
				title = Lang:t('menu.wagon_store'),
				description = '',
				icon = 'fa-solid fa-circle-arrow-down',
				iconColor = 'red',
				event = 'qc-advancedranch:client:storewagon',
				arrow = true
			},
		}
	})
	lib.showContext("jobwagon_menu")
end)

-- spawn company wagon
RegisterNetEvent('qc-advancedranch:client:SpawnWagon', function()
    RSGCore.Functions.TriggerCallback('qc-advancedranch:server:GetActiveWagon', function(data)
        if data ~= nil then
            if wagonSpawned == false then
                local ped = PlayerPedId()
                local playerjob = RSGCore.Functions.GetPlayerData().job.name
                local plate = data.plate
                local carthash = Config.JobsSettings[playerjob].carthash
                local spawncoords = Config.JobsSettings[playerjob].spawncoords
                local cargohash = Config.JobsSettings[playerjob].cargohash
                local lightupgardehash = Config.JobsSettings[playerjob].lightupgardehash
                RequestModel(carthash)
                while not HasModelLoaded(carthash) do
                    Citizen.Wait(0)
                end
                local wagon = CreateVehicle(carthash, spawncoords.x, spawncoords.y, spawncoords.z, spawncoords.w, true, false)
                SetVehicleOnGroundProperly(wagon)
                Wait(200)
                SetPedIntoVehicle(ped, wagon, -1)
                SetModelAsNoLongerNeeded(carthash)
                Citizen.InvokeNative(0xD80FAF919A2E56EA, wagon, cargohash)
                Citizen.InvokeNative(0xC0F0417A90402742, wagon, lightupgardehash) 
                SpawnedWagon = wagon
                wagonSpawned = true
                lib.notify({ title = Lang:t('primary.wagon_out'), type = 'inform' })
            else
                lib.notify({ title = Lang:t('primary.wagon_already_out'), type = 'inform' })
            end
        else
            lib.notify({ title = Lang:t('error.no_wagon_setup'), type = 'error' })
        end
    end)
end)

-- open wagon menu
CreateThread(function()
    while true do
        Wait(1)
        if Citizen.InvokeNative(0x91AEF906BCA88877, 0, RSGCore.Shared.Keybinds[Config.CartInvKeybind]) then
            local playercoords = GetEntityCoords(PlayerPedId())
            local wagoncoords = GetEntityCoords(SpawnedWagon)
            if #(playercoords - wagoncoords) <= 2.0 then
                RSGCore.Functions.TriggerCallback('qc-advancedranch:server:GetActiveWagon', function(data)
                    local wagonstash = data.plate
                    TriggerServerEvent("inventory:server:OpenInventory", "stash", wagonstash, { maxweight = Config.MaxWeight, slots = Config.MaxSlots, })
                    TriggerEvent("inventory:client:SetCurrentStash", wagonstash)
                end)
            end
        end
    end
end)

-- store wagon
RegisterNetEvent('qc-advancedranch:client:storewagon', function()
    if wagonSpawned == true then
        DeleteVehicle(SpawnedWagon)
        SetEntityAsNoLongerNeeded(SpawnedWagon)
        lib.notify({ title = Lang:t('success.wagon_stored'), type = 'success' })
        wagonSpawned = false
    end
end)

-- update animals
RegisterNetEvent('qc-advancedranch:client:updateAnimalData')
AddEventHandler('qc-advancedranch:client:updateAnimalData', function(data)
    Config.RanchAnimals = data
end)

function WanderDistance(animalType)
    if animalType == 'cow' then
        wanderDist = Config.CowWanderDistance
    end
    if animalType == 'sheep' then
        wanderDist = Config.SheepWanderDistance
    end
    if animalType == 'chicken' then
        wanderDist = Config.ChickenWanderDistance
    end
    if animalType == 'pig' then
        wanderDist = Config.PigWanderDistance
    end
    return wanderDist
end

-- new animal : use item
RegisterNetEvent('qc-advancedranch:client:newanimaluseitem')
AddEventHandler('qc-advancedranch:client:newanimaluseitem', function(animal, hash, product)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerjob = PlayerData.job.name

    if (playerjob == 'macfarranch') or (playerjob == 'prongranch') then
    
        local animalspawn = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 3.0, 0.0)
        local heading = GetEntityHeading(PlayerPedId())
        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(PlayerPedId(), false) and not isBusy then
            isBusy = true
            local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, anim1, 0, true)
            Wait(10000)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            if animal == 'chicken' then
                cost = Config.ChickenPrice
            end
            if animal == 'pig' then
                cost = Config.PigPrice
            end
            data = {
                animal = animal, 
                animalspawn = animalspawn,
                heading = heading, 
                hash = hash,
                playerjob = playerjob,
                product = product,
                cost = cost
            }
            TriggerServerEvent('qc-advancedranch:server:newanimal', data)
            TriggerServerEvent('qc-advancedranch:server:removeitem', animal, 1)
            isBusy = false
            return
        end
        lib.notify({ title = 'Problem', description = 'can\'t place it while in a vehicle!', type = 'error' })
    else
        lib.notify({ title = 'Not Authorised', description = 'you are not authorised to do that!', type = 'error' })
    end
end)

-- spawn ranch animals
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local InRange = false

        for i = 1, #Config.RanchAnimals do

            local coords = vector3(Config.RanchAnimals[i].x, Config.RanchAnimals[i].y, Config.RanchAnimals[i].z)
            local dist = #(pos - coords)

            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedAnimals do
                local p = SpawnedAnimals[z]
                if p.id == Config.RanchAnimals[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.RanchAnimals[i].hash
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end
            
            data.id = Config.RanchAnimals[i].id
            data.obj = CreatePed(modelHash, Config.RanchAnimals[i].x, Config.RanchAnimals[i].y, Config.RanchAnimals[i].z -1.2, true, true, false)
            data.ranchid = Config.RanchAnimals[i].ranchid
            data.animal = Config.RanchAnimals[i].animal
            data.posx = Config.RanchAnimals[i].x
            data.posy = Config.RanchAnimals[i].y
            data.posz = Config.RanchAnimals[i].z
            SetEntityHeading(data.obj, Config.RanchAnimals[i].h)
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, data.obj, 0, false)
            wanderDist = WanderDistance(data.animal)
            Citizen.InvokeNative(0xE054346CA3A0F315, data.obj, Config.RanchAnimals[i].x, Config.RanchAnimals[i].y, Config.RanchAnimals[i].z, wanderDist, tonumber(1077936128), tonumber(1086324736), 1)
            Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, data.obj)
            SetEntityAsMissionEntity(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)
            SetRelationshipBetweenGroups(1, GetPedRelationshipGroupHash(data.obj), joaat('PLAYER'))

            SpawnedAnimals[#SpawnedAnimals + 1] = data
            hasSpawned = false
            
            -- create animal target
            exports['rsg-target']:AddTargetEntity(data.obj, {
                options = {
                    {
                        type = "client",
                        event = 'qc-advancedranch:client:animalinfo',
                        id = Config.RanchAnimals[i].id,
                        icon = "far fa-eye",
                        label = 'Animal Info',
                    },
                    {
                        type = "client",
                        event = 'qc-advancedranch:client:animalactions',
                        id = Config.RanchAnimals[i].id,
                        entity = data.obj,
                        animal = data.animal,
                        icon = "far fa-eye",
                        label = 'Animal Actions'
                    }
                },
                distance = Config.AnimalTargetDistance
            })

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

-- animal info menu
RegisterNetEvent('qc-advancedranch:client:animalinfo', function(data)
    RSGCore.Functions.TriggerCallback('qc-advancedranch:server:getanimaldata', function(result)
        local animals = json.decode(result[1].animals)
        lib.registerContext({
            id = 'ranch_animalinfo',
            title = 'Animal Info',
            options = {
                {
                    title = 'ID: '..animals.id,
                    description = animals.animal..' id',
                    icon = 'fa-solid fa-fingerprint',
                },
                {
                    title = 'Age: '..animals.age,
                    description = animals.animal..' age',
                    icon = 'fa-solid fa-paw',
                },
                {
                    title = 'Health: '..animals.health,
                    progress = animals.health,
                    colorScheme = 'green',
                    description = animals.animal..' health',
                    icon = 'fa-solid fa-heart-pulse',
                },
                {
                    title = 'Product Progress : '..animals.product,
                    progress = animals.product,
                    colorScheme = 'green',
                    description = animals.animal..' '..animals.productoutput..' production in progress',
                    icon = 'fa-solid fa-bars-progress',
                },
            }
        })
        lib.showContext('ranch_animalinfo')
    end, data.id)
end)

-- animal actions menu
RegisterNetEvent('qc-advancedranch:client:animalactions', function(data)
    RSGCore.Functions.TriggerCallback('qc-advancedranch:server:getanimaldata', function(result)
        local animals = json.decode(result[1].animals)
        lib.registerContext({
            id = 'ranch_animalactions',
            title = 'Animal Actions',
            options = {
                {
                    title = 'Toggle Animal Follow',
                    description = 'ask your animal to follow you',
                    icon = 'fa-solid fa-wheat-awn',
                    event = 'qc-advancedranch:client:animalfollow',
                    args = {
                        entity = data.entity,
                        animal = data.animal
                    },
                    arrow = true
                },
                {
                    title = 'Feed Animal',
                    description = 'feed animal to improve health',
                    icon = 'fa-solid fa-wheat-awn',
                    event = 'qc-advancedranch:client:feedanimal',
                    args = {
                        animalid = animals.id,
                        animalhealth = animals.health,
                        animaltype = animals.animal
                    },
                    arrow = true
                },
                {
                    title = 'Colect Product',
                    description = 'collect product from animal',
                    icon = 'fa-solid fa-wheat-awn',
                    event = 'qc-advancedranch:client:collectproduct',
                    args = {
                        ranchid = animals.ranchid,
                        animalid = animals.id,
                        animalproduct = animals.product,
                        animalproductoutput = animals.productoutput,
                        animaltype = animals.animal
                    },
                    arrow = true
                },
            }
        })
        lib.showContext('ranch_animalactions')
    end, data.id)
end)

-- feed animal / improve health
RegisterNetEvent('qc-advancedranch:client:feedanimal', function(data)
    if data.animalhealth <= 100 then
        TriggerServerEvent('qc-advancedranch:server:feedanimal', data.animalid, data.animalhealth, data.animaltype)
    else
        lib.notify({ title = 'Animal Full', description = 'animal does not require any food!', type = 'inform' })
    end
end)

-- collect product
RegisterNetEvent('qc-advancedranch:client:collectproduct', function(data)
    if data.animalproduct >= 100 then
        TriggerServerEvent('qc-advancedranch:server:collectproduct', data.ranchid, data.animalid, data.animalproduct, data.animalproductoutput, data.animaltype)
    else
        lib.notify({ title = 'Product Not Ready', description = 'product not ready to collect yet!', type = 'inform' })
    end
end)

-- set new animal position and handle animal being killed
Citizen.CreateThread(function()
    while true do
        for k, v in pairs(SpawnedAnimals) do
            if IsPedDeadOrDying(v.obj, true) then
                TriggerServerEvent('qc-advancedranch:server:animalkilled', v.id)
            else
                local pos = GetEntityCoords(v.obj)
                TriggerServerEvent('qc-advancedranch:server:updateposition', v.id, pos.x, pos.y, pos.z)
            end
        end
        Wait(5000)
    end
end)

-- set animal to follow you
RegisterNetEvent('qc-advancedranch:client:animalfollow')
AddEventHandler('qc-advancedranch:client:animalfollow', function(data)
    if IsPedDeadOrDying(data.entity, true) then
        lib.notify({ title = 'Animal Dead', description = 'this animal is dead!', type = 'error' })
        return 
    end
    if isFollowing == false then
        isFollowing = true
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)
        local animalOffset = vector3(0.0, 2.0, 0.0) 
        ClearPedTasks(data.entity)
        TaskFollowToOffsetOfEntity(data.entity, player, animalOffset.x, animalOffset.y, animalOffset.z, 1.0, -1, 0.0, 1)
    else
        isFollowing = false
        wanderDist = WanderDistance(data.animal)
        local x,y,z = table.unpack(GetEntityCoords(data.entity))
        Citizen.InvokeNative(0xE054346CA3A0F315, data.entity, x, y, z, wanderDist, tonumber(1077936128), tonumber(1086324736), 1)
    end
end)

-------------------------------------------------------------------------------

-- herd livestock
RegisterNetEvent('qc-advancedranch:client:herdanimals', function(animaltype)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerjob = PlayerData.job.name

    if (playerjob == 'macfarranch') or (playerjob == 'prongranch') then

        -- herd animals
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)
        local animalOffset = vector3(0.0, 2.0, 0.0)

        for k, v in ipairs(SpawnedAnimals) do

            local entity = v.obj
            local entityCoords = GetEntityCoords(entity)
            local dist = #(playerCoords - entityCoords)
                
            if dist >= 50.0 then 
                goto continue 
            end
            
            if v.animal == animaltype and v.ranchid == playerjob then
                ClearPedTasks(entity)
                TaskFollowToOffsetOfEntity(entity, player, animalOffset.x, animalOffset.y, animalOffset.z, 1.0, -1, 0.0, 1)
            end
            ::continue::
        end
    else
        lib.notify({ title = 'Not Allowed', description = 'only rancher\'s are able to do this!', type = 'error' })
    end
end)

-- unherd livestock
RegisterNetEvent('qc-advancedranch:client:unherdanimals', function(animal)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerjob = PlayerData.job.name

    if (playerjob == 'macfarranch') or (playerjob == 'prongranch') then
        -- unherd animals
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)

        for i, v in ipairs(SpawnedAnimals) do
            local entity = v.obj
            local x,y,z = table.unpack(GetEntityCoords(entity))
            wanderDist = WanderDistance(animal)
            Citizen.InvokeNative(0xE054346CA3A0F315, entity, x, y, z, wanderDist, tonumber(1077936128), tonumber(1086324736), 1)
        end
    else
        lib.notify({ title = 'Not Allowed', description = 'only rancher\'s are able to do this!', type = 'error' })
    end
end)

-------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedAnimals do
        local animals = SpawnedAnimals[i].obj

        SetEntityAsMissionEntity(animals, false)
        FreezeEntityPosition(animals, false)
        DeletePed(animals)
    end
end)
