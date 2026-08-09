local PPTClient: typeof(require(Hidden.PPTClient)) = require(Hidden.PPTClient)

local tickrate: number = 20
local objpoolsize: number = 4096
local renderdist: number = 4
PPTClient.EnableClientRuntime(tickrate, objpoolsize, renderdist)

for x = 0, 32 do
    local reqs: {vector} = {}
    for z = 0, 32 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTClient.RequestChunks(reqs) -- takes a table of native luau vec2s
end