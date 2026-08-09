--!native
export type ChunkData = {
    ChunkPosition: vector,
    VertexCoordinates: {vector},
    PooledObjects: {ObjectClass},
    isRendered: boolean
}

--[[
    Chunk size is the length of a single chunk in
    polytoria units.
    
    Point interval is a value for how many points are
		created per length units.

		For example:
		ChunkSize = 16
		PointIntreval = 4
		Each row will have 4 points.
--]]
export type PPTConfig = {
    Frequency: number, -- server
    Amplitude: number, -- server
    Scale: number, -- server
    Octaves: number, -- server
    Persistence: number, -- server
    Lacunarity: number, -- server
    Seed: number,
    ChunkSize: number, -- shared
    PointInterval: number, -- shared
}

local PPT = {}
local ConfigServer = {} :: PPTConfig

local Triangle3D: typeof(require(script.Triangle3D)) = require(script.Triangle3D)
local Basin: typeof(require(script.Basin)) = require(script.Basin)
local Triangle: Part = script.Triangle
local ClientRenderCall: BindableEvent = script.ClientRenderCall
local ChangeRenderDistance: BindableEvent = script.ChangeRenderDistance
local ChunkDataBus: NetworkEvent = script.ChunkDataBus
local SharedConfigBus: NetworkEvent = script.SharedConfigBus

local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create
local Vec3New: typeof(Vector3.New) = Vector3.New
local TableInsert: typeof(table.insert) = table.insert
local TableCreate: typeof(table.create) = table.create
local TableClear: typeof(table.clear) = table.clear

local function GetIndex(x: number, z: number, stepsperrow: number): number
    return x * stepsperrow + z + 1
end

--[[
    Server only function for setting shared & server config.
--]]
function PPT.SetConfig(Config: PPTConfig): nil
    if Players.LocalPlayer then return end
    ConfigServer = Config
end


--[[
    Requests the currently set shared config and returns it as
    a table.
--]]
function PPT.RequestSharedConfig(): {number}
    SharedConfigBus.InvokeServer()
end

local function WorldgenNoise2D(
    Frequency: number,
    Amplitude: number,
    Scale: number,
    Octaves: number,
    Persistence: number,
    Lacunarity: number,
    Seed: number,
    x: number,
    z: number
): number

local Result: number = 0
local MaxAmplitude: number = 0
for CurrOctave = 1, Octaves do
    Result += Noise(x * Frequency, z * Frequency, Seed) * Amplitude
    MaxAmplitude += Amplitude
    Frequency *= Lacunarity
    Amplitude *= Persistence
end
return Result / MaxAmplitude * Scale
end

--[[
    Generates chunk data with a provided seed and chunk coordinate.
    Server use only.
--]]
function PPT.GenerateChunk(ChunkCoordinate: vector): ChunkData
    local Config = ConfigServer
    local ChunkSize: number = Config.ChunkSize
    local PointInterval: number = Config.PointInterval
    local Seed: number = Config.Seed
    local stepsPerRow: number = (ChunkSize / PointInterval) + 1

    local Chunk: ChunkData = {
        ChunkPosition = ChunkCoordinate,
        VertexCoordinates = TableCreate(stepsPerRow * stepsPerRow),
        PooledObjects = {},
        isRendered = false
    }

    -- flatten this loop when possible
    for x: number = 0, ChunkSize do
        if x % PointInterval ~= 0 then continue end
        local worldx: number = ChunkCoordinate.x * ChunkSize + x
        local xi: number = x / PointInterval
        for z: number = 0, ChunkSize do
            if z % PointInterval ~= 0 then continue end
            local worldz: number = ChunkCoordinate.y * ChunkSize + z
            local zi: number = z / PointInterval
            local noise: number = WorldgenNoise2D(Config.Frequency, Config.Amplitude, Config.Scale, Config.Octaves, Config.Persistence, Config.Lacunarity, Seed, worldx, worldz)
            local y: number = math.pow(math.abs(noise) * 1.2, 1)

            Chunk.VertexCoordinates[GetIndex(xi, zi, stepsPerRow)] = VecCreate(worldx, y, worldz)
        end
    end

    return Chunk
end

--[[
    Renders the input chunk using triangles from the provided
    triangle pool.

    SharedConfig is required if you're running this on the client (aka; by default)
    isClient is set to true by default, as server-side rendering is not expected.
--]]
function PPT.RenderChunk(Chunk: ChunkData, TrianglePool: BasinClass, SharedConfig: {number}?, isClient: boolean?): nil
    if isClient == nil then isClient = true end
    Chunk.isRendered = true
    local Config: {number} | PPTConfig
    if isClient then
        Config = SharedConfig
    else
        if Players.LocalPlayer then return end
        Config = ConfigServer
    end
    local ChunkSize: number = Config.ChunkSize
    local PointInterval: number = Config.PointInterval
    local stepsPerRow: number = (ChunkSize / PointInterval) + 1
    local VertexCoordinates: {vector} = Chunk.VertexCoordinates

    for x: number = 0, ChunkSize - 1 do
        if x % PointInterval ~= 0 then continue end
        local xi: number = x / PointInterval
        local xiNext: number = (x + PointInterval) / PointInterval
        for z: number = 0, ChunkSize - 1 do
            if z % PointInterval ~= 0 then continue end
            local zi: number = z / PointInterval
            local ziNext: number = (z + PointInterval) / PointInterval

            local po1: vector = VertexCoordinates[GetIndex(xi, zi, stepsPerRow)]
            local po2: vector = VertexCoordinates[GetIndex(xiNext, zi, stepsPerRow)]
            local po3: vector = VertexCoordinates[GetIndex(xi, ziNext, stepsPerRow)]
            local po4: vector = VertexCoordinates[GetIndex(xiNext, ziNext, stepsPerRow)]

            local triangles: {ObjectClass}, success: boolean = TrianglePool:Pull(4)
            if not success then
                if triangles and #triangles > 0 then
                    for _, obj: ObjectClass in ipairs(triangles) do obj:Push() end
                end
                print("[ PPT ] Failed to pull triangles for chunk!")
                TrianglePool:Reserve(#TrianglePool.Pool + ChunkSize * ChunkSize)
                triangles, success = TrianglePool:Pull(4)
                if not success then 
                    Chunk.isRendered = false
                    continue
                end
            end
            for _, obj: ObjectClass in ipairs(triangles) do Chunk.PooledObjects[#Chunk.PooledObjects + 1] = obj end

            local tri1: Part = triangles[1].Item
            local tri2: Part = triangles[2].Item
            local tri3: Part = triangles[3].Item
            local tri4: Part = triangles[4].Item

            Triangle3D.SplitTriangle(tri1, tri2, po1, po2, po4)
            Triangle3D.SplitTriangle(tri3, tri4, po1, po4, po3)

            tri1.Parent = Environment
            tri2.Parent = Environment
            tri3.Parent = Environment
            tri4.Parent = Environment
        end
    end
end

--[[
    Unrenders a chunk by emptying its triangles and
    sets the rendered state to false.
--]]
function PPT.UnrenderChunk(Chunk: ChunkData): nil
    for _, obj: ObjectClass in ipairs(Chunk.PooledObjects) do
        obj:Push()
    end

    TableClear(Chunk.PooledObjects)
    Chunk.isRendered = false
end

--[[
    Encodes the provided chunkdata into a string.
    Can be decoded back into chunkdata using PPT.Decode.
--]]
function PPT.Encode(Chunk: ChunkData): string
    local vertParts: {string} = TableCreate(#Chunk.VertexCoordinates * 3)
    for i, v in ipairs(Chunk.VertexCoordinates) do
        vertParts[(i-1)*3 + 1] = tostring(v.x)
        vertParts[(i-1)*3 + 2] = tostring(v.y)
        vertParts[(i-1)*3 + 3] = tostring(v.z)
    end
    return json.serialize({
        VertexCoordinates = table.concat(vertParts, "_"),
        ChunkPositionX = Chunk.ChunkPosition.x,
        ChunkPositionY = Chunk.ChunkPosition.y
    })
end

--[[
    Encodes the provided chunkdata string into chunkdata.
    Can be encoded back into string using PPT.Encode.
--]]
function PPT.Decode(ChunkString: string): ChunkData
    local ChunkJson = json.parse(ChunkString)
    local parts: {string} = string.split(ChunkJson.VertexCoordinates, "_")
    local verts: {vector} = TableCreate(#parts / 3)
    for i = 1, #parts, 3 do
        verts[(i - 1) / 3 + 1] = VecCreate(tonumber(parts[i]), tonumber(parts[i+1]), tonumber(parts[i+2]))
    end
    return {
        ChunkPosition = VecCreate(ChunkJson.ChunkPositionX, ChunkJson.ChunkPositionY, 0),
        VertexCoordinates = verts,
        PooledObjects = {},
        isRendered = false
    }
end

--[[
    Batch version of PPT.Encode.
    Input a table of chunks to get a single string.
--]]
function PPT.EncodeBatch(Chunks: {ChunkData}): string
    local batch: {string} = TableCreate(#Chunks)
    for _, chunk: ChunkData in ipairs(Chunks) do
        local chunk_str: string = PPT.Encode(chunk)
        TableInsert(batch, chunk_str)
    end
    return json.serialize(batch)
end

--[[
    Batch version of PPT.Decode.
    Input a chunk batch string from PPT.EncodeBatch to get a table of chunks.
--]]
function PPT.DecodeBatch(ChunkBatchString: string): {ChunkData}
    local batch: {string} = json.parse(ChunkBatchString)
    local decoded: {ChunkData} = TableCreate(#batch)
    for _, chunk_str: string in ipairs(batch) do
        local chunk: ChunkData = PPT.Decode(chunk_str)
        TableInsert(decoded, chunk)
    end
    return decoded
end

--[[
    Only runnable on the client.
    Handles culling, object pooling, and rendering for the client.
    Pass chunks to the client using ChunkDataBus, with only chunk batch sends.

    Tickrate is the number of ticks per second that you want
    Eg; 20 for 1 tick to be 0.05 seconds

    InitialTriAmount is the number of pre-allocated triangles
    you want the client to have.

    RenderDistance is the number of chunks you want the runtime to render.
    RenderDistance can be updated via PPT.UpdateRenderDistance
--]]
function PPT.EnableClientRuntime(Tickrate: number, InitialTriAmount: number, RenderDistance: number): nil
    if not Players.LocalPlayer then return end
    local Player: Player = Players.LocalPlayer

    local ClientCam: Camera = Environment.Camera
    local ChunkDataStorage: {[string]: ChunkData} = {} :: {ChunkData}
    local TrianglePool: BasinClass, PoolSuccess: boolean = Basin.New(Triangle, InitialTriAmount, false);
    if not PoolSuccess then return end

    ChunkDataBus.InvokedClient:Connect(function(ChunkBatchMessage: NetMessage): nil
        for _: string, chunk: ChunkData in ipairs(PPT.DecodeBatch(ChunkBatchMessage:GetString("chunks"))) do
            local key = chunk.ChunkPosition.x .. "," .. chunk.ChunkPosition.y
            ChunkDataStorage[key] = chunk
        end
    end)

    local Config: {number} = {}
    SharedConfigBus.InvokedClient:Connect(function(msg: NetMessage)
        Config.PointInterval = msg:GetNumber("PointInterval")
        Config.ChunkSize = msg:GetNumber("ChunkSize")
    end)

    ChangeRenderDistance.Invoked:Connect(function(NewDist: number): nil
        RenderDistance = NewDist
    end)

    local elapsed_dt: number = 0
    Hooks.PreRendered:Connect(function(DeltaTime: number)
        elapsed_dt += DeltaTime
        if elapsed_dt < 1/Tickrate then return end
        elapsed_dt = 0
        local playerpos: vector = VecCreate(Player.Position.X, 0, Player.Position.Z)

        if not Config or not Config.ChunkSize then 
            PPT.RequestSharedConfig()
            return
        end

        for _, chunk: ChunkData in pairs(ChunkDataStorage) do
            local chunkpos: vector = VecCreate(chunk.ChunkPosition.x, 0, chunk.ChunkPosition.y) * Config.ChunkSize
            local outOfRange: boolean = vector.magnitude(playerpos - chunkpos) > RenderDistance * Config.ChunkSize
            if chunk.isRendered then
                if outOfRange then PPT.UnrenderChunk(chunk) end
                continue
            end
            if outOfRange then continue end
            
            PPT.RenderChunk(chunk, TrianglePool, Config, true)
        end
    end)
end

--[[
    Request chunks from the server. Only usable on the client.
    ChunkCoordinates must be a table of native luau vectors.
--]]
function PPT.RequestChunks(ChunkCoordinates: {vector}): nil
    if not Players.LocalPlayer then return end
    local req: NetMessage = NetMessage.New()
    local chunkcoordstr: {string} = TableCreate(#ChunkCoordinates)
    for idx: number, vec: vector in ipairs(ChunkCoordinates) do
        chunkcoordstr[idx] = tostring(vec)
    end

    req:AddString("ChunkCoordinates", table.concat(chunkcoordstr, "_"))
    ChunkDataBus.InvokeServer(req)
end

--[[
    Update render distance.
    Only runnable on client.
]]--
function PPT.UpdateRenderDistance(RenderDistance: number): nil
    if not Players.LocalPlayer then return end
    ChangeRenderDistance.Invoke(RenderDistance)
end

function PPT.StartServerRuntime(Tickrate: number): nil
    if Players.LocalPlayer then return end
    SharedConfigBus.InvokedServer:Connect(function(sender: Player, msg: NetMessage)
        local returnmsg: NetMessage = NetMessage.New()
        returnmsg:AddNumber("PointInterval", ConfigServer.PointInterval)
        returnmsg:AddNumber("ChunkSize", ConfigServer.ChunkSize)
        SharedConfigBus.InvokeClient(returnmsg, sender)
    end)

    ChunkDataBus.InvokedServer:Connect(function(sender: Player, req: NetMessage)
        local chunkcoordstr: {string} = string.split(req:GetString("ChunkCoordinates"), "_")

        local chunkcoords: {vector} = TableCreate(#chunkcoordstr)
        for idx: number, vecstr: string in ipairs(chunkcoordstr) do
            local nums: {string} = string.split(vecstr, ",")
            chunkcoords[idx] = VecCreate(tonumber(nums[1]), tonumber(nums[2]))
        end

        -- only send 2 chunks at once
        local chunks: {ChunkData} = TableCreate(2)
        for idx: number, vec: vector in ipairs(chunkcoords) do
            chunks[idx] = PPT.GenerateChunk(vec)
        end
        local BatchMsg: NetMessage = NetMessage.New()
        BatchMsg:AddString("chunks", PPT.EncodeBatch(chunks))
        ChunkDataBus.InvokeClient(BatchMsg, sender)
        
    end)

    local temp: PPTConfig = ConfigServer
    local elapsed_dt: number = 0
    local UpdateMsg: NetMessage = NetMessage.New()
    Hooks.PreRendered:Connect(function(DeltaTime: number)
        elapsed_dt += DeltaTime
        if elapsed_dt < 1/Tickrate then return end
        elapsed_dt = 0

        if ConfigServer ~= temp then
            temp = ConfigServer
            UpdateMsg:AddNumber("PointInterval", ConfigServer.PointInterval)
            UpdateMsg:AddNumber("ChunkSize", ConfigServer.ChunkSize)
            SharedConfigBus.InvokeClients(UpdateMsg)
        end
    end)
end

return PPT
