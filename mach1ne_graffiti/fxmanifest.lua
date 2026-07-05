fx_version 'cerulean'
game 'gta5'

name 'mach1ne_graffiti'
description 'DUI Graffiti Script'
author 'Mach1ne'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/display.html',
}

lua54 'yes'
