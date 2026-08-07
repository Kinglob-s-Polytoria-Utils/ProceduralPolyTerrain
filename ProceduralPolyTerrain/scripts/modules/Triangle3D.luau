--!native
--!strict
--[[
    Base triangle functions provided by @stkptr at their repo:
    https://github.com/stkptr/polyrecipe/blob/trunk/triangles/triangles-2.0.lua
    
    optimized by me (and --!native :) ).
    Big thanks to them (I don't like trig :fear:)
--]]
local Triangle3D = {}
local VecMag: typeof(vector.magnitude) = vector.magnitude
local VecCross: typeof(vector.cross) = vector.cross
local VecDot: typeof(vector.dot) = vector.dot
local Vec3New: typeof(Vector3.New) = Vector3.New

local function VecDist(a: vector, b: vector): number
	return VecMag((a - b))
end

local function VecSqrMag(a: vector): number
	return a.x * a.x + a.y * a.y + a.z * a.z
end

-- First two vertices are the longest edge
-- Output remains clockwise
local function TriSort(a: vector, b: vector, c: vector): (vector, vector, vector, number)
	local ab: number = VecSqrMag(a - b)
	local ac: number = VecSqrMag(a - c)
	local bc: number = VecSqrMag(b - c)
	if ab >= ac and ab >= bc then
		return a, b, c, ab
	elseif ac >= ab and ac >= bc then
		return c, a, b, ac
	else
		return b, c, a, bc
	end
end

-- exposed form
function Triangle3D.RegisterTriangle(part: Part, p1: vector, p2: vector, p3: vector): nil
	local offset: vector = (p1 + p2) / 2
	part.Size = Vec3New(VecDist(p2, p3), VecDist(p1, p3), 0.05)
	part.Position = Vec3New(offset.x, offset.y, offset.z)
	local normal: vector = VecCross(p2 - p3, p1 - p2)
	local planeUp: vector = p1 - p3
	local lookvector: vector = normal + offset
	part:LookAt(Vec3New(lookvector.x, lookvector.y, lookvector.z), Vec3New(planeUp.x, planeUp.y, planeUp.z))
end

function Triangle3D.NewTriangle(): Part
    local Triangle: Part = Part.New()
    Triangle.Shape = Enums.PartShape.Wedge
    return Triangle
end

-- Given the arbitrary positions a, b, c
-- Find the pair of right triangles which form the triangle
-- And suitably position, scale, and orient t1 and t2 to be that pair
function Triangle3D.SplitTriangle(part1: Part, part2: Part, a0: vector, b0: vector, c0: vector): nil
	local a1: vector, b1: vector, c1: vector, ab: number = TriSort(a0, b0, c0)
	-- https://math.stackexchange.com/q/436700
	-- https://math.stackexchange.com/a/1426955
	local proportion: number = VecDot(a1 - b1, a1 - c1) / ab
	local d: vector = proportion * b1 + (1 - proportion) * a1
	Triangle3D.RegisterTriangle(part1, c1, a1, d)
	Triangle3D.RegisterTriangle(part2, b1, c1, d)
end

return Triangle3D