local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

PPTClient.AppendTriangleVisuals({
	{MinHeight = 0, Color = Color.FromHex("#224f23")}, -- Grass
	{MinHeight = 24, Color = Color.FromHex("#4d4d4d")}, -- Mountain rock
	{MinHeight = 36, Color = Color.FromHex("#ffffff")} -- Snow
} :: {AppendTriangleVisuals});

local tickrate: number = 4
local objpoolsize: number = 4096
local renderdist: number = 8

PPTClient.EnableClientRuntime(tickrate, renderdist, objpoolsize)

for x = -16, 16 do
    local reqs: {vector} = {}
    for z = -16, 16 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTClient.RequestChunks(reqs) -- takes a table of native luau vec2s
end
