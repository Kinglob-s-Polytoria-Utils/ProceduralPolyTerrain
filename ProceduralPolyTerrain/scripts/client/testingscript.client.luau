local PPTLibrary: typeof(require(script.PPTLibrary)) = require(script.PPTLibrary)

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
for x = 0, 2 do
    for z = 0, 2 do
        local chunk: ChunkData = PPTLibrary.GenerateChunk(12932131, vector.create(x, z))
        PPTLibrary.RenderChunk(chunk)
        wait(1)
    end
end
