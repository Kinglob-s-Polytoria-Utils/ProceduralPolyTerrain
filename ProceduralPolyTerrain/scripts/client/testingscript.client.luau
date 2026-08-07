local PPTLibrary: typeof(require(Hidden.PPTLibrary)) = require(Hidden.PPTLibrary)

local config: PPTConfig = {
    Frequency = 0.025,
    Amplitude = 1,
    Scale = 5,
    Octaves = 4,
    Persistence = 0.5,
    Lacunarity = 2,
    ChunkSize = 16,
    PointInterval = 8,
    RenderDistance = 64
} :: PPTConfig

PPTLibrary.SetConfig(config)
PPTLibrary.EnableClientRuntime(20, 8096)
