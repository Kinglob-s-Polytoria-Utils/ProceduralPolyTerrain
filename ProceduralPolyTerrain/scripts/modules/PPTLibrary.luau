--!native
export type ChunkData = {
    ChunkPosition: vector,
    VertexCoordinates: {vector}
}

--[[
    Chunk size is the length of a single chunk in
    polytoria units.
    
    Point interval is a multiplier meant to specify
    the rate at which points are stored in a chunk.
--]]
export type PPTConfig = {
    Frequency: number,
    Amplitude: number,
    Scale: number,
    Octaves: number,
    Persistence: number,
    Lacunarity: number,
    ChunkSize: number,
    PointInterval: number
}

local PPT = {}
PPT.Config = {} :: PPTConfig

local Triangle3D: typeof(require(script.Triangle3D)) = require(script.Triangle3D)
local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create
local Vec3New: typeof(Vector3.New) = Vector3.New -- temporary

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
for CurrOctave = 0, Octaves do
    Result += Noise(x * Frequency, z * Frequency, Seed) * Amplitude
    MaxAmplitude += Amplitude
    Frequency *= Lacunarity
    Amplitude *= Persistence
end
return Result / MaxAmplitude * Scale
end

function PPT.GenerateChunk(seed: number, ChunkCoordinate: vector): ChunkData
    local Config = PPT.Config
    local ChunkSize: number = PPT.Config.ChunkSize
    local Chunk: ChunkData = {
        ChunkPosition = ChunkCoordinate,
        VertexCoordinates = table.create(ChunkSize * ChunkSize)
    }

    for x: number = 1, ChunkSize - 1 do
        for z: number = 1, ChunkSize - 1 do
            local noise: number = WorldgenNoise2D(Config.Frequency, Config.Amplitude, Config.Scale, Config.Octaves, Config.Persistence, Config.Lacunarity, seed, x, z)
            
            Chunk.VertexCoordinates[(x - 1) * ChunkSize + z]      = VecCreate(x - 1, noise, z)
            Chunk.VertexCoordinates[x * ChunkSize + z]            = VecCreate(x, noise, z)
            Chunk.VertexCoordinates[(x - 1) * ChunkSize + z + 1]  = VecCreate(x - 1, noise, z + 1)
            Chunk.VertexCoordinates[x * ChunkSize + z + 1]        = VecCreate(x, noise, z + 1)
        end
    end

    return Chunk
end

function PPT.RenderChunk(Chunk: ChunkData): nil
    local ChunkSize: number = PPT.Config.ChunkSize
    local ChunkCoordinates: vector = Chunk.ChunkPosition
    local VertexCoordinates: {vector} = Chunk.VertexCoordinates
    local TriangleBuffer: {Part} = table.create(#VertexCoordinates / 4)
    local vec_idx: number = 1
    while vec_idx < #VertexCoordinates do
        -- sample by quads
        local vec1: vector = ChunkCoordinates * ChunkSize + VertexCoordinates[vec_idx]
        local vec2: vector = ChunkCoordinates * ChunkSize + VertexCoordinates[vec_idx + 1]
        local vec3: vector = ChunkCoordinates * ChunkSize + VertexCoordinates[vec_idx + 2]
        local vec4: vector = ChunkCoordinates * ChunkSize + VertexCoordinates[vec_idx + 3]

        -- currently, this is a bit slow until i rewrite triangle3d.luau to use the native vector library
        -- and also object pooling
        local tri1_1: Part = Triangle3D.NewTriangle(
            Vec3New(vec1.x, vec1.y, vec1.z),
            Vec3New(vec2.x, vec2.y, vec2.z),
            Vec3New(vec4.x, vec4.y, vec4.z)
        )

        local tri1_2: Part = Triangle3D.NewTriangle(
            Vec3New(vec1.x, vec1.y, vec1.z),
            Vec3New(vec4.x, vec4.y, vec4.z),
            Vec3New(vec3.x, vec3.y, vec3.z)
        )

        Triangle3D.SplitTriangle(
            tri1_1, 
            tri1_2, 
            Vec3New(vec1.x, vec1.y, vec1.z), 
            Vec3New(vec2.x, vec2.y, vec2.z), 
            Vec3New(vec3.x, vec3.y, vec3.z)); 
        tri1_1.Parent = Environment
        tri1_2.Parent = Environment
        vec_idx += 4
    end
end

return PPT