Config = {}

-- Hvor langt spilleren kan være fra væggen for at spraye
Config.MaxDistance    = 7.0
Config.RenderDistance = 25.0  -- maks afstand for at se graffiti

-- Prop der bruges som "lærred" på væggen (en flad plane)
Config.CanvasModel = 'prop_paint_canvas_01'
Config.CanvasTxd   = 'prop_paint_canvas_01'
Config.CanvasTex   = 'painting_spray_01'
Config.CanvasWidth = 2.0
Config.CanvasHeight = 2.0

-- DUI opløsning
Config.DuiWidth = 1024
Config.DuiHeight = 1024

-- Spray animation
Config.AnimDict = 'switch@franklin@ig_15_painting'
Config.AnimName = 'painting_spray_high'

-- Spray partikeleffekt (vises ved hånd under tegning)
Config.SprayParticle     = 'core'
Config.SprayParticleName = 'ent_sht_steam'

-- Farver spilleren kan vælge
Config.Colors = {
    { name = 'Sort',     hex = '#1a1a1a' },
    { name = 'Hvid',     hex = '#ffffff' },
    { name = 'Rød',      hex = '#e63946' },
    { name = 'Blå',      hex = '#1d4ed8' },
    { name = 'Grøn',     hex = '#16a34a' },
    { name = 'Gul',      hex = '#fbbf24' },
    { name = 'Lilla',    hex = '#9333ea' },
    { name = 'Orange',   hex = '#f97316' },
    { name = 'Pink',     hex = '#ec4899' },
    { name = 'Cyan',     hex = '#06b6d4' },
}

-- Brush sizes
Config.BrushSizes = { 4, 8, 14, 22, 32 }

-- Antal spraydåser der forbruges per graffiti (0 = gratis)
Config.ConsumeAmount = 1
