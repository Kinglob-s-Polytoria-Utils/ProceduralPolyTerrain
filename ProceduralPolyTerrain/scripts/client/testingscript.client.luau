local PPTLibrary: typeof(require(Hidden.PPTLibrary)) = require(Hidden.PPTLibrary)

local tickrate: number = 20
local objpoolsize: number = 4096
local renderdist: number = 4
PPTLibrary.EnableClientRuntime(tickrate, objpoolsize, renderdist)

for x = 0, 32 do
    local reqs: {vector} = {}
    for z = 0, 32 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTLibrary.RequestChunks(reqs) -- takes a table of native luau vec2s
end