local PPTServer: typeof(require(ScriptService.PPTServer)) = require(ScriptService.PPTServer)

local config: PPTConfig = {
    Frequency = 0.006, -- server only
    Amplitude = 1, -- server only
    Scale = 120, -- server only
    Octaves = 5, -- server only
    Persistence = 0.5, -- server only
    Lacunarity = 2, -- server only
    Seed = 111, -- server only
    ChunkSize = 32, -- shared, server controlled
    PointInterval = 8 -- shared, server controlled
} :: PPTConfig
local tickrate: number = 20

PPTServer.SetConfig(config)
PPTServer.StartServerRuntime(tickrate)