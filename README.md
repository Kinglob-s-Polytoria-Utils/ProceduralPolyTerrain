# ProceduralPolyTerrain

ProceduralPolyTerrain is a custom library for generating
polygonal terrain procedurally, as the name states.

ProceduralPolyTerrain *(PTT)* aims to be easy to use and
has no voxels, opting to have more polygonal terrain which
you can suit to your needs.

PTT also aims to be highly customizable to developer needs,
such as;
- Terrain generation parameters
- Indepth modification of height values
- Terrain resolution
- Encoding & Decoding of chunks to and from strings

Examples of usage:

CLIENT:
```lua 
-- This is a *client* script!
local PPTClient = require(world.Hidden.PPTClient)

-- Create different types of triangles to render for different heights
PPTClient.AppendTriangleVisuals({
	{MinHeight = 0, Color = Color.FromHex("#224f23")}, -- Grass
	{MinHeight = 24, Color = Color.FromHex("#4d4d4d")}, -- Mountain rock
	{MinHeight = 36, Color = Color.FromHex("#ffffff")} -- Snow
} :: {AppendTriangleVisuals});

local Tickrate: number = 20
local RenderDistance: number = 8
PPTClient.StartClientRuntime(Tickrate, RenderDistance)

-- Demo for generating an 16x16 grid of chunks
for x = -8, 8 do
  for z = -8, 8 do
    -- Create a table of vectors
    local Requests: {vector} = {}
    Requests[#Requests + 1] = vector.create(x, z)

    -- Pass it into PPTClient.RequestChunks
    -- This will request chunks from the server, and then pass it to the client.
    PPTClient.RequestChunks(Requests)

    -- clear it or something idk bro
    table.clear(Requests)
    Requests = {}
  end
end
```

SERVER:
```lua
-- This is a *server* script!
local PPTServer = require(world.ScriptService.PPTServer)

-- For more info on the config properties,
-- please consult the built-in documentation in PPTServer.luau!
local ServerConfig: PPTConfig = {
    Frequency = 0.006,
    Amplitude = 1,
    Scale = 120,
    Octaves = 4,
    Persistence = 0.5,
    Lacunarity = 2,
	MaximumY = math.huge,
	MinimumY = -math.huge,
    Seed = 111,
    ChunkSize = 64,
    PointInterval = 32
}

-- Set the configuration for the server
PPTServer.SetConfig(ServerConfig)

local Tickrate = 10
-- Start the server runtime
PPTServer.StartServerRuntime(
  Tickrate,
  
  -- Callback function to modify the Y value of chunk vertices.
  -- Think of this as a way to change the heightmap of the generated chunk(s)
  function(noise: number): number
    return math.pow(math.abs(noise) * 1.2, 1)
  end
)
```
