local PPTLibrary: typeof(require(Hidden.PPTLibrary)) = require(Hidden.PPTLibrary)
local bus: NetworkEvent = Hidden.PPTLibrary.ChunkDataBus

local config: PPTConfig = {
    Frequency = 0.006, -- server
    Amplitude = 1, -- server
    Scale = 120, -- server
    Octaves = 5, -- server
    Persistence = 0.5, -- server
    Lacunarity = 2, -- server
    ChunkSize = 32, -- shared
    PointInterval = 8, -- shared
} :: PPTConfig

PPTLibrary.SetConfig(config)
PPTLibrary.StartServerRuntime()

wait(5)
for x = 0, 8 do
    
    for z = 0, 8 do
        local chunks: {ChunkData} = {}
        local msg: NetMessage = NetMessage.New()
        local chunk: ChunkData = PPTLibrary.GenerateChunk(111, vector.create(x, z))
        table.insert(chunks, chunk)
        msg:AddString("chunks", PPTLibrary.EncodeBatch(chunks))
        bus:InvokeClients(msg)
        wait(0.25)
    end
    

end
