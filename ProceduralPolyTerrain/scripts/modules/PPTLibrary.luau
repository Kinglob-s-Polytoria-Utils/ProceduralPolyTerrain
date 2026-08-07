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
    Frequency: number,
    Amplitude: number,
    Scale: number,
    Octaves: number,
    Persistence: number,
    Lacunarity: number,
    ChunkSize: number,
    PointInterval: number,
    RenderDistance: number
}

local PPT = {}
PPT.Config = {} :: PPTConfig

local Triangle3D: typeof(require(script.Triangle3D)) = require(script.Triangle3D)
local Basin: typeof(require(script.Basin)) = require(script.Basin)
local Triangle: Part = script.Triangle
local ClientRenderCall: PTSignal = script.ClientRenderCall
local ChunkDataBus: NetworkEvent = script.ChunkDataBus

local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create

local function GetIndex(x: number, z: number, stepsperrow: number): number
    return x * stepsperrow + z + 1
end

function PPT.SetConfig(Config: PPTConfig): nil
    PPT.Config = Config
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

function PPT.GenerateChunk(seed: number, ChunkCoordinate: vector): ChunkData
    local Config = PPT.Config
    local ChunkSize: number = Config.ChunkSize
    local PointInterval: number = Config.PointInterval
    local stepsPerRow: number = (ChunkSize / PointInterval) + 1

    local Chunk: ChunkData = {
        ChunkPosition = ChunkCoordinate,
        VertexCoordinates = table.create(stepsPerRow * stepsPerRow),
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
            local noise: number = WorldgenNoise2D(Config.Frequency, Config.Amplitude, Config.Scale, Config.Octaves, Config.Persistence, Config.Lacunarity, seed, worldx, worldz)
            local y: number = math.pow(math.abs(noise) * 1.2, 1)

            Chunk.VertexCoordinates[GetIndex(xi, zi, stepsPerRow)] = VecCreate(worldx, y, worldz)
        end
    end

    return Chunk
end

function PPT.RenderChunk(Chunk: ChunkData, TrianglePool: BasinClass): nil
    Chunk.isRendered = true
    local Config: PPTConfig = PPT.Config
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
                print("failed to pull triangles for chunk")
                TrianglePool:Reserve(#TrianglePool.Pool + ChunkSize * ChunkSize)
                triangles, success = TrianglePool:Pull(4)
                if not success then continue end
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

function PPT.UnrenderChunk(Chunk: ChunkData): nil
    for _, obj: ObjectClass in ipairs(Chunk.PooledObjects) do
        obj:Push()
    end

    Chunk.isRendered = false
end

function PPT.Encode(Chunk: ChunkData): string
    local vertParts: {string} = table.create(#Chunk.VertexCoordinates * 3)
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

function PPT.Decode(ChunkString: string): ChunkData
    local ChunkJson = json.parse(ChunkString)
    local parts: {string} = string.split(ChunkJson.VertexCoordinates, "_")
    local verts: {vector} = table.create(#parts / 3)
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

function PPT.EncodeBatch(Chunks: {ChunkData}): string
    local batch: {string} = table.create(#Chunks)
    for _, chunk: ChunkData in ipairs(Chunks) do
        local chunk_str: string = PPT.Encode(chunk)
        table.insert(batch, chunk_str)
    end
    return json.serialize(batch)
end

function PPT.DecodeBatch(ChunkBatchString: string): {ChunkData}
    local batch: {string} = json.parse(ChunkBatchString)
    local decoded: {ChunkData} = table.create(#batch)
    for _, chunk_str: string in ipairs(batch) do
        local chunk: ChunkData = PPT.Decode(chunk_str)
        table.insert(decoded, chunk)
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
--]]
function PPT.EnableClientRuntime(Tickrate: number, InitialTriAmount: number): nil
    if not Players.LocalPlayer then return end
    local Player: Player = Players.LocalPlayer

    local ClientCam: Camera = Environment.Camera
    local ChunkDataStorage: {[string]: ChunkData} = {} :: {ChunkData}
    local TrianglePool: BasinClass, PoolSuccess: boolean = Basin.New(Triangle, InitialTriAmount, false);
    if not PoolSuccess then return end

    ChunkDataBus.InvokedClient:Connect(function(ChunkBatchMessage: NetMessage)
        for _: string, chunk: ChunkData in ipairs(PPT.DecodeBatch(ChunkBatchMessage:GetString("chunks"))) do
            local key = chunk.ChunkPosition.x .. "," .. chunk.ChunkPosition.y
            ChunkDataStorage[key] = chunk
        end
    end)

    local ChunkSize: number = PPT.Config.ChunkSize
    local elapsed_dt: number = 0
    Hooks.PreRendered:Connect(function(DeltaTime: number)
        elapsed_dt += DeltaTime
        if elapsed_dt < 1/Tickrate then return end
        elapsed_dt = 0
        for _, chunk: ChunkData in pairs(ChunkDataStorage) do
            if chunk.isRendered then continue end
            PPT.RenderChunk(chunk, TrianglePool)
        end
    end)
end

return PPT
