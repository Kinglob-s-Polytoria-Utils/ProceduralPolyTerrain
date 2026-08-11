local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

PPTClient.AppendTriangleVisuals({
	{MinHeight = 1, Color = Color.New(50, 200, 50)}, -- Grass
	{MinHeight = 4, Color = Color.New(20, 20, 20)}, -- Mountain rock
	{MinHeight = 8, Color = Color.New(255, 255, 255)} -- Snow
} :: {AppendTriangleVisuals});

local tickrate: number = 4
local objpoolsize: number = 4096
local renderdist: number = 6

PPTClient.EnableClientRuntime(tickrate, renderdist, objpoolsize)

for x = -16, 16 do
    local reqs: {vector} = {}
    for z = -16, 16 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTClient.RequestChunks(reqs) -- takes a table of native luau vec2s
end

wait(5)
PPTClient.DisableClientRuntime()
print("disabled")
wait(5)
print("reenabled")
PPTClient.EnableClientRuntime(tickrate, renderdist, objpoolsize)
