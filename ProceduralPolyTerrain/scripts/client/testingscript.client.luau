local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

local tickrate: number = 2
local objpoolsize: number = 256
local renderdist: number = 1

PPTClient.EnableClientRuntime(tickrate, objpoolsize, renderdist)

for x = 0, 1 do
    local reqs: {vector} = {}
    for z = 0, 1 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTClient.RequestChunks(reqs) -- takes a table of native luau vec2s
end
