local PPTLibrary: typeof(require(ScriptService.PPTLibrary)) = require(ScriptService.PPTLibrary)

local config: PPTConfig = {
    Frequency = 0.03,
    Amplitude = 1,
    Scale = 20,
    Octaves = 4,
    Persistence = 0.5,
    Lacunarity = 2,
    ChunkSize = 16,
    PointInterval = 4
} :: PPTConfig
PPTLibrary.SetConfig(config)
local chunk: ChunkData = PPTLibrary.GenerateChunk(12932131, vector.create(0, 0))
PPTLibrary.RenderChunk(chunk)
