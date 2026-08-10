local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

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
