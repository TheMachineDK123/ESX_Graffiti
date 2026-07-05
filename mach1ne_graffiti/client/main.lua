-- ============================================
-- mach1ne_graffiti — Client
-- Spray paint graffiti via NUI canvas + spray animation
-- ============================================

local Graffiti = {
    active     = false,
    wallCoords = nil,
}

local savedGraffiti  = {}
local graffitiCounter = 0
local GRAFFITI_DURATION  = 300000  -- 5 minutter i ms

-- ============================================
-- Fjern en graffiti (DUI + target zone)
-- ============================================
local function removeGraffiti(id)
    for i = #savedGraffiti, 1, -1 do
        local g = savedGraffiti[i]
        if g.id == id then
            if g.dui    then g.dui:remove() end
            if g.zoneId then exports.ox_target:removeZone(g.zoneId) end
            table.remove(savedGraffiti, i)
            return
        end
    end
end

-- ============================================
-- Tilføj ox_target wash-zone på graffiti
-- ============================================
local function addGraffitiTarget(id, coords)
    return exports.ox_target:addSphereZone({
        coords  = coords,
        radius  = 1.5,
        debug   = false,
        options = {
            {
                label    = 'Vask graffiti af',
                icon     = 'fas fa-eraser',
                distance = 2.0,
                onSelect = function()
                    local ped = PlayerPedId()
                    local washDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
                    local washName = 'malewipe'
                    RequestAnimDict(washDict)
                    local tw = GetGameTimer() + 3000
                    while not HasAnimDictLoaded(washDict) and GetGameTimer() < tw do Wait(10) end

                    local done = lib.progressBar({
                        duration = 4000,
                        label    = 'Vasker graffiti af...',
                        useWhileDead   = false,
                        canCancel      = true,
                        anim = {
                            dict  = washDict,
                            clip  = washName,
                            flags = 49,
                        },
                    })
                    RemoveAnimDict(washDict)
                    if done then
                        TriggerServerEvent('mach1ne_graffiti:logWashed', coords)
                        removeGraffiti(id)
                        lib.notify({ description = 'Graffiti vasket af', type = 'success' })
                    end
                end,
            },
        },
    })
end

-- ============================================
-- Render thread: viser gemte graffiti via DrawSprite
-- ============================================
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local now = GetGameTimer()
        for i = #savedGraffiti, 1, -1 do
            local g = savedGraffiti[i]
            if now - g.created > GRAFFITI_DURATION then
                removeGraffiti(g.id)
            else
                local dist = #(pedCoords - g.coords)
                if dist <= Config.RenderDistance then
                    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(g.coords.x, g.coords.y, g.coords.z)
                    if onScreen then
                        -- Canvas er 1920x1080 (16:9) — DrawSprite skaleres korrekt
                        local aspect = GetAspectRatio(false)
                        local scaleH = math.max(0.03, math.min(0.18, 0.4 / (dist + 0.1)))
                        local scaleW = scaleH * aspect
                        DrawSprite(g.dui.dictName, g.dui.txtName, sx, sy, scaleW, scaleH, 0.0, 255, 255, 255, 230)
                    end
                end
            end
        end
    end
end)

-- ============================================
-- Raycast frem for at finde en væg
-- ============================================
local function raycastWall()
    local ped = PlayerPedId()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local x = math.cos(math.rad(rot.x)) * math.sin(math.rad(-rot.z))
    local y = math.cos(math.rad(rot.x)) * math.cos(math.rad(-rot.z))
    local z = math.sin(math.rad(rot.x))
    local fwd = vec3(x, y, z)
    local target = cam + fwd * Config.MaxDistance
    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, target.x, target.y, target.z, 1 | 16, ped)
    local _, hit, coords, normal, entity = GetShapeTestResult(ray)
    return hit, coords
end

-- ============================================
-- Åbn graffiti mode
-- ============================================
local function openGraffiti()
    if Graffiti.active then return end

    -- Tjek at spilleren kigger mod en væg
    local hit, coords = raycastWall()
    if not hit then
        lib.notify({ description = 'Ingen væg i sigte — vend dig mod en væg', type = 'error' })
        return
    end

    -- Tjek om spilleren har spraydåse
    local hasItem = lib.callback.await('mach1ne_graffiti:checkItem', false)
    if not hasItem then
        lib.notify({ description = 'Du har ikke en spraydåse', type = 'error' })
        return
    end

    Graffiti.active = true
    Graffiti.wallCoords = coords

    -- Skift til first-person så spilleren kigger direkte på væggen
    SetFollowPedCamViewMode(4)

    -- Afspil spray animation
    local animDict = Config.AnimDict
    RequestAnimDict(animDict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(animDict) and GetGameTimer() < t do Wait(10) end

    local ped = PlayerPedId()
    TaskPlayAnim(ped, animDict, Config.AnimName, 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Animation keep-alive + spray partikel-effekt
    CreateThread(function()
        local pt = Config.SprayParticle or 'scr_rcpaparazzo1'
        local pn = Config.SprayParticleName or 'scr_meth_pipe_smoke'
        RequestNamedPtfxAsset(pt)
        local t2 = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(pt) and GetGameTimer() < t2 do Wait(10) end

        while Graffiti.active do
            if not IsEntityPlayingAnim(ped, animDict, Config.AnimName, 3) then
                TaskPlayAnim(ped, animDict, Config.AnimName, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            if HasNamedPtfxAssetLoaded(pt) then
                local bone = GetPedBoneCoords(ped, 28422, 0.0, 0.0, 0.0)
                UseParticleFxAssetNextCall(pt)
                StartParticleFxLoopedAtCoord(pn, bone.x, bone.y, bone.z, 0.0, 0.0, 0.0, 0.3, false, false, false, false)
            end
            Wait(1000)
        end
        RemoveNamedPtfxAsset(pt)
    end)

    -- Åbn NUI canvas
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data   = { colors = Config.Colors, sizes = Config.BrushSizes },
    })
end

-- ============================================
-- Luk graffiti mode
-- ============================================
local function closeGraffiti()
    if not Graffiti.active then return end

    Graffiti.active = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    -- Gendan third-person
    SetFollowPedCamViewMode(0)

    local ped = PlayerPedId()
    StopAnimTask(ped, Config.AnimDict, Config.AnimName, 1.0)
    RemoveAnimDict(Config.AnimDict)
end

-- ============================================
-- NUI Callbacks
-- ============================================
RegisterNUICallback('cancel', function(_, cb)
    closeGraffiti()
    cb('ok')
end)

RegisterNUICallback('save', function(data, cb)
    if not Graffiti.active then cb('ok') return end

    local consumed = lib.callback.await('mach1ne_graffiti:consumeItem', false)
    if not consumed then
        lib.notify({ description = 'Kunne ikke forbruge spraydåse', type = 'error' })
        cb('ok')
        return
    end

    local image      = data and data.image
    local wallCoords = Graffiti.wallCoords
    closeGraffiti()

    if image and wallCoords then
        local url = ('https://cfx-nui-%s/html/display.html'):format(GetCurrentResourceName())
        local ok, dui = pcall(function()
            return lib.dui:new({ url = url, width = 512, height = 512 })
        end)
        if ok and dui then
            graffitiCounter = graffitiCounter + 1
            local id = graffitiCounter

            CreateThread(function()
                Wait(1000)
                dui:sendMessage({ action = 'show', image = image })
            end)

            local zoneId = addGraffitiTarget(id, wallCoords)
            table.insert(savedGraffiti, {
                id      = id,
                dui     = dui,
                coords  = wallCoords,
                created = GetGameTimer(),
                zoneId  = zoneId,
            })
        end
    end

    -- Log til Discord
    if wallCoords then
        TriggerServerEvent('mach1ne_graffiti:logPlaced', wallCoords)
    end

    lib.notify({ description = 'Graffiti sprayet!', type = 'success' })
    cb('ok')
end)

-- ============================================
-- ox_inventory export
-- ============================================
exports('useSpraycan', function(data, slot)
    if Graffiti.active then return end
    openGraffiti()
end)

-- ============================================
-- Cleanup
-- ============================================
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        closeGraffiti()
        for _, g in ipairs(savedGraffiti) do
            if g.dui    then g.dui:remove() end
            if g.zoneId then exports.ox_target:removeZone(g.zoneId) end
        end
        savedGraffiti = {}
    end
end)
