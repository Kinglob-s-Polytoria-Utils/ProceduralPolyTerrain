--!native
export type ChunkData = {
    ChunkPosition: vector,
    VertexCoordinates: {vector}
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
    PointInterval: number
}

local PPT = {}
PPT.Config = {} :: PPTConfig

local Triangle3D: typeof(require(script.Triangle3D)) = require(script.Triangle3D)
local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create
local Vec3New: typeof(Vector3.New) = Vector3.New -- temporary

local function GetIndex(x: number, z: number, chunksize: number): number
    local gridsize: number = chunksize + 1
    return x * gridsize + z + 1
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
    local ChunkSize: number = PPT.Config.ChunkSize
    local Chunk: ChunkData = {
        ChunkPosition = ChunkCoordinate,
        VertexCoordinates = table.create((ChunkSize + 1) * (ChunkSize + 1))
    }

		-- flatten this loop when possible
    for x: number = 0, ChunkSize do
        local worldx: number = ChunkCoordinate.x * ChunkSize + x
        for z: number = 0, ChunkSize do
						if (x % Config.PointInterval ~= 0) or (z % Config.PointInterval ~= 0) then continue end
            local worldz: number = ChunkCoordinate.y * ChunkSize + z
            local noise: number = WorldgenNoise2D(Config.Frequency, Config.Amplitude, Config.Scale, Config.Octaves, Config.Persistence, Config.Lacunarity, seed, worldx, worldz)
            
            Chunk.VertexCoordinates[GetIndex(x, z, ChunkSize)] = VecCreate(worldx, noise, worldz)
        end
    end

    return Chunk
end

function PPT.RenderChunk(Chunk: ChunkData): nil
    local ChunkSize: number = PPT.Config.ChunkSize
    local ChunkCoordinates: vector = Chunk.ChunkPosition
    local VertexCoordinates: {vector} = Chunk.VertexCoordinates
    local TriangleBuffer: {Part} = table.create(#VertexCoordinates)
    for x: number = 0, ChunkSize - 1 do
        for z: number = 0, ChunkSize - 1 do
            local po1: vector = VertexCoordinates[GetIndex(x, z, ChunkSize)]
            local po2: vector = VertexCoordinates[GetIndex(x + 1, z, ChunkSize)]
            local po3: vector = VertexCoordinates[GetIndex(x, z + 1, ChunkSize)]
            local po4: vector = VertexCoordinates[GetIndex(x + 1, z + 1, ChunkSize)]

            local tri1: Part = Triangle3D.NewTriangle()
            local tri2: Part = Triangle3D.NewTriangle()

            Triangle3D.SplitTriangle(
                tri1,
                tri2, 
                Vec3New(po1.x, po1.y, po1.z),
                Vec3New(po2.x, po2.y, po2.z), 
                Vec3New(po4.x, po4.y, po4.z)
            )

            local tri3: Part = Triangle3D.NewTriangle()
            local tri4: Part = Triangle3D.NewTriangle()

            Triangle3D.SplitTriangle(
                tri3,
                tri4, 
                Vec3New(po1.x, po1.y, po1.z),
                Vec3New(po4.x, po4.y, po4.z), 
                Vec3New(po3.x, po3.y, po3.z)
            )
            
            tri1.Parent = Environment
            tri2.Parent = Environment
            tri3.Parent = Environment
            tri4.Parent = Environment
        end
    end
end

return PPT
