-- ============================================
-- mach1ne_graffiti — Server
-- Håndterer spraydåse item tjek og forbrug
-- ============================================

-- ============================================
-- DISCORD WEBHOOK KONFIGURATION
-- ============================================
local WEBHOOK_URL     = 'https://discord.com/api/webhooks/DIN_WEBHOOK_URL_HER'
local WEBHOOK_ENABLED = true        -- sæt til false for at slå logs fra
local BOT_NAME        = 'Graffiti Logger'
local BOT_AVATAR      = 'https://i.imgur.com/8vHBVoG.png'
local EMBED_COLOR     = 16711680    -- rød (decimal: 0xFF0000)

-- ============================================
-- Discord embed sender
-- ============================================
local function sendWebhook(title, description, fields, color)
    if not WEBHOOK_ENABLED or WEBHOOK_URL == 'https://discord.com/api/webhooks/DIN_WEBHOOK_URL_HER' then
        return
    end

    local embedFields = {}
    if fields then
        for _, f in ipairs(fields) do
            embedFields[#embedFields + 1] = {
                name   = f.name,
                value  = f.value,
                inline = f.inline or false,
            }
        end
    end

    local payload = json.encode({
        username   = BOT_NAME,
        avatar_url = BOT_AVATAR,
        embeds = {
            {
                title       = title,
                description = description,
                color       = color or EMBED_COLOR,
                fields      = embedFields,
                footer      = { text = 'mach1ne_graffiti • ' .. os.date('%d/%m/%Y %H:%M:%S') },
            }
        }
    })

    PerformHttpRequest(WEBHOOK_URL, function(code, _, headers)
        if code ~= 204 then
            print(('[graffiti] Webhook fejl: HTTP %s'):format(code))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

-- ============================================
-- Hent spillerinfo
-- ============================================
local function getPlayerInfo(src)
    local name      = GetPlayerName(src) or 'Ukendt'
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then identifiers[#identifiers + 1] = id end
    end
    local steam   = ''
    local license = ''
    for _, id in ipairs(identifiers) do
        if id:sub(1, 6) == 'steam:' then steam = id end
        if id:sub(1, 8) == 'license:' then license = id end
    end
    return name, steam ~= '' and steam or license
end

-- ============================================
-- Ekstern event: klient melder graffiti placeret
-- ============================================
RegisterNetEvent('mach1ne_graffiti:logPlaced', function(coords)
    local src = source
    local name, identifier = getPlayerInfo(src)

    sendWebhook(
        '🎨  Ny graffiti sprayed',
        ('**%s** har lavet graffiti på serveren.'):format(name),
        {
            { name = '👤 Spiller',    value = ('`%s`'):format(name),                    inline = true  },
            { name = '🆔 ID',         value = ('`%d`'):format(src),                     inline = true  },
            { name = '🔑 Identifier', value = ('`%s`'):format(identifier),              inline = false },
            { name = '📍 Koordinater',value = ('`%.2f, %.2f, %.2f`'):format(coords.x, coords.y, coords.z), inline = false },
        },
        5763719  -- blå
    )
end)

-- ============================================
-- Ekstern event: klient melder graffiti vasket af
-- ============================================
RegisterNetEvent('mach1ne_graffiti:logWashed', function(coords)
    local src = source
    local name, identifier = getPlayerInfo(src)

    sendWebhook(
        '🧹  Graffiti vasket af',
        ('**%s** har fjernet graffiti.'):format(name),
        {
            { name = '👤 Spiller',    value = ('`%s`'):format(name),       inline = true  },
            { name = '🆔 ID',         value = ('`%d`'):format(src),        inline = true  },
            { name = '🔑 Identifier', value = ('`%s`'):format(identifier), inline = false },
            { name = '📍 Koordinater',value = ('`%.2f, %.2f, %.2f`'):format(coords.x, coords.y, coords.z), inline = false },
        },
        16776960  -- gul
    )
end)

local ox = exports['ox_inventory']

-- Tjek om spilleren har en spraydåse
lib.callback.register('mach1ne_graffiti:checkItem', function(source)
    local item = ox:GetItem(source, 'spraycan', nil, false)
    return item and item.count > 0
end)

-- Forbrug spraydåse
lib.callback.register('mach1ne_graffiti:consumeItem', function(source)
    local amount = Config.ConsumeAmount or 1
    if amount <= 0 then return true end

    local item = ox:GetItem(source, 'spraycan', nil, false)
    if not item or item.count < amount then
        return false
    end

    local removed = ox:RemoveItem(source, 'spraycan', amount)
    return removed and true or false
end)
