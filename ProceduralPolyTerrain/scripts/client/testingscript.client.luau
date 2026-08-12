local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

PPTClient.AppendTriangleVisuals({
	{MinHeight = 0, Color = Color.FromHex("#224f23")}, -- Grass
	{MinHeight = 24, Color = Color.FromHex("#4d4d4d")}, -- Mountain rock
	{MinHeight = 36, Color = Color.FromHex("#ffffff")} -- Snow
} :: {AppendTriangleVisuals});

local tickrate: number = 20
local objpoolsize: number = 4096
local renderdist: number = 12

PPTClient.EnableClientRuntime(tickrate, renderdist)

for x = -64, 64 do
    for z = -64, 64 do
        local reqs: {vector} = {}
        reqs[#reqs + 1] = vector.create(x, z)
        if #reqs ~= 64 then 
            PPTClient.RequestChunks(reqs) -- takes a table of native luau vec2s
            table.clear(reqs)
            reqs = {}
        end 
    end
end
print("finished requests")
