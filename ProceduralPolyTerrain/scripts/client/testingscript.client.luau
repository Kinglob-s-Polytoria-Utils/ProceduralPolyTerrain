local PPTLibrary: typeof(require(Hidden.PPTLibrary)) = require(Hidden.PPTLibrary)

local tickrate: number = 20
local objpoolsize: number = 8096
local renderdist: number = 8
PPTLibrary.EnableClientRuntime(tickrate, objpoolsize, renderdist)

local newrenderdist: number = 16
PPTLibrary.UpdateRenderDistance(newrenderdist)

for x = 0, 4 do
    local reqs: {vector} = {}
    for z = 0, 4 do
        reqs[#reqs + 1] = vector.create(x, z)
    end
    PPTLibrary.RequestChunks(reqs) -- takes a table of native luau vec2s
end