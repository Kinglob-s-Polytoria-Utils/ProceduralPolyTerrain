local PPTLibrary: typeof(require(Hidden.PPTLibrary)) = require(Hidden.PPTLibrary)
local bus: NetworkEvent = Hidden.PPTLibrary.ChunkDataBus

local config: PPTConfig = {
    Frequency = 0.006,
    Amplitude = 1,
    Scale = 80,
    Octaves = 5,
    Persistence = 0.5,
    Lacunarity = 2,
    ChunkSize = 16,
    PointInterval = 8,
    RenderDistance = 0
} :: PPTConfig

PPTLibrary.SetConfig(config)
wait(5)
for x = 0, 16 do
    local chunks: {ChunkData} = {}
    for z = 0, 16 do
        local chunk: ChunkData = PPTLibrary.GenerateChunk(111, vector.create(x, z))
        table.insert(chunks, chunk)
        wait(0.025)
    end
    local msg: NetMessage = NetMessage.New()
    msg:AddString("chunks", PPTLibrary.EncodeBatch(chunks))
    bus:InvokeClients(msg)
end
