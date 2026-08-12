local PPTServer: typeof(require(ScriptService.PPTServer)) = require(ScriptService.PPTServer)

local config: PPTConfig = {
    Frequency = 0.006, -- server only
    Amplitude = 1, -- server only
    Scale = 120, -- server only
    Octaves = 4, -- server only
    Persistence = 0.5, -- server only
    Lacunarity = 2, -- server only
		MaximumY = math.huge, -- server only
		MinimumY = -math.huge, -- server only
    Seed = 111, -- server only
    ChunkSize = 64, -- shared, server controlled
    PointInterval = 32 -- shared, server controlled
} :: PPTConfig
local tickrate: number = 10

PPTServer.SetConfig(config)
PPTServer.StartServerRuntime(
  tickrate,
  function(noise: number): nil
    return math.pow(math.abs(noise) * 1.2, 1)
  end
)
