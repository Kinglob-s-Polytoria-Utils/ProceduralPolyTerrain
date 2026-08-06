local PPTLibrary: typeof(require(ScriptService.PPTLibrary)) = require(ScriptService.PPTLibrary)

local config: PPTConfig = {
    Frequency = 1,
    Amplitude = 1,
    Scale = 2,
    Octaves = 1,
    Persistence = 1,
    Lacunarity = 1,
    ChunkSize = 16,
    PointInterval = 0.25
} :: PPTConfig
PPTLibrary.SetConfig(config)
local chunk: ChunkData = PPTLibrary.GenerateChunk(12932131, vector.create(1, 1))
print(chunk, "chunk vertices: ", #chunk.VertexCoordinates, "chunk coord: ", chunk.ChunkPosition.x, chunk.ChunkPosition.y)
PPTLibrary.RenderChunk(chunk)