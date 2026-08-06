--!native
--[[
    Base triangle functions provided by @stkptr at their repo:
    https://github.com/stkptr/polyrecipe/blob/trunk/triangles/triangles-2.0.lua
    
    optimized by me (and --!native :) ).
    Big thanks to them (I don't like trig :fear:)
--]]
local Triangle3D = {}
local Vec3New: typeof(Vector3.New) = Vector3.New
local Vec3Dist: typeof(Vector3.Distance) = Vector3.Distance
local Vec3Cross: typeof(Vector3.Cross) = Vector3.Cross

-- Given a wedge part t, rescale, position, and orient it so its vertices meet at, bt, ct
-- at, bt, ct must form a right triangle
local function localRegisterTriangle(part: Part, p1: Vector3, p2: Vector3, p3: Vector3): nil
	local offset: Vector3 = (p1 + p2) / 2
	part.Size = Vec3New(Vec3Dist(p2, p3), Vec3Dist(p1, p3), 0.05)
	part.Position = offset
	local normal: Vector3 = Vec3Cross(p2 - p3, p1 - p2)
	local planeUp: Vector3 = p1 - p3
	part:LookAt(normal + offset, planeUp)
end


-- First two vertices are the longest edge
-- Output remains clockwise
local function TriSort(a, b, c)
	local ab = Vec3Dist(a, b)
	local ac = Vec3Dist(a, c)
	local bc = Vec3Dist(b, c)
	if ab > ac and ab > bc then
		return {a, b, c}
	elseif ac > ab and ac > bc then
		return {c, a, b}
	else
		return {b, c, a}
	end
end

-- exposed form
function Triangle3D.RegisterTriangle(part: Part, p1: Vector3, p2: Vector3, p3: Vector3): nil
	local offset: Vector3 = (p1 + p2) / 2
	part.Size = Vec3New(Vec3Dist(p2, p3), Vec3Dist(p1, p3), 0.05)
	part.Position = offset
	local normal: Vector3 = Vec3Cross(p2 - p3, p1 - p2)
	local planeUp: Vector3 = p1 - p3
	part:LookAt(normal + offset, planeUp)
end

function Triangle3D.NewTriangle(p1: Vector3, p2: Vector3, p3: Vector3): Part
    local Triangle: Part = Part.New()
    Triangle.Shape = Enums.PartShape.Wedge
    localRegisterTriangle(Triangle, p1, p2, p3)
    return Triangle
end

-- Given the arbitrary positions a, b, c
-- Find the pair of right triangles which form the triangle
-- And suitably position, scale, and orient t1 and t2 to be that pair
function Triangle3D.SplitTriangle(part1: Part, part2: Part, a, b, c): nil
	local sort = TriSort(a, b, c)
	local a = sort[1]
	local b = sort[2]
	local c = sort[3]
	-- https://math.stackexchange.com/q/436700
	-- https://math.stackexchange.com/a/1426955
	local proportion: number = Vector3.Dot(a - b, a - c) / (a - b).SqrMagnitude
	local d = proportion * b + (1 - proportion) * a
	localRegisterTriangle(part1, c, a, d)
	localRegisterTriangle(part2, b, c, d)
end

return Triangle3D