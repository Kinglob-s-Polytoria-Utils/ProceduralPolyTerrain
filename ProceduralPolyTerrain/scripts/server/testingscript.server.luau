local PPTServer: typeof(require(ScriptService.PPTServer)) = require(ScriptService.PPTServer)

local config: PPTConfig = {
    Frequency = 0.006, -- server only
    Amplitude = 1, -- server only
    Scale = 120, -- server only
    Octaves = 1, -- server only
    Persistence = 0.5, -- server only
    Lacunarity = 2, -- server only
		MaximumY = 12, -- server only
		MinimumY = -1, -- server only
    Seed = 111, -- server only
    ChunkSize = 96, -- shared, server controlled
    PointInterval = 48 -- shared, server controlled
} :: PPTConfig
local tickrate: number = 10

PPTServer.SetConfig(config)
PPTServer.StartServerRuntime(tickrate)
