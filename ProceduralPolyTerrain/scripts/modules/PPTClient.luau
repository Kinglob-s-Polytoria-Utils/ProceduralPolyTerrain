--!native
export type ChunkData = {
	ChunkPosition: vector,
	VertexCoordinates: { vector },
	PooledObjects: { ObjectClass },
	isRendered: boolean,
}

--[[
    Chunk size is the length of a single chunk in
    polytoria units.
    
    Point interval is a value for how many points are
		created per length units.

		For example:
		ChunkSize = 16
		PointIntreval = 4
		Each row will have 4 points.
--]]
export type PPTConfig = {
	Frequency: number, -- server
	Amplitude: number, -- server
	Scale: number, -- server
	Octaves: number, -- server
	Persistence: number, -- server
	Lacunarity: number, -- server
	MaximumY: number, -- server
	Seed: number,
	ChunkSize: number, -- shared
	PointInterval: number, -- shared
}

--[[
	All values are optional, except for MinHeight.
--]]
export type TriangleVisualQuery = {
	MinHeight: number,
	Color: Color?,
	Material: PartMaterial?,
	IsSpawn: boolean?,
	Mass: number?,
	Friction: number?,
	Bounciness: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CollisionLayers: number?,
	CollisionMask: number?
}

local PPT = {}
local ModuleConfig: typeof(require(script.ClientConfig)) = require(script.ClientConfig)
assert(ModuleConfig, "[ PPTClient ] Couldn't find ModuleConfig (ClientConfig)!")

-- Hi, Don't change paths to events here, instead do it in ClientConfig!
local Triangle3D: typeof(require(ModuleConfig.Triangle3DModule)) = require(ModuleConfig.Triangle3DModule)
assert(Triangle3D, "[ PPTClient ] Couldn't find Triangle3D!")
local Basin: typeof(require(ModuleConfig.BasinModule)) = require(ModuleConfig.BasinModule)
assert(Basin, "[ PPTClient ] Couldn't find Basin!")

local Triangle: Part = ModuleConfig.ClientTriangle
assert(Triangle, "[ PPTClient ] Couldn't find template Triangle!")
local ChangeRenderDistance: BindableEvent = ModuleConfig.ChangeRenderDistance
assert(ChangeRenderDistance, "[ PPTClient ] Couldn't find ChangeRenderDistance!")
local ChunkDataBus: NetworkEvent = ModuleConfig.ChunkDataBus
assert(ChunkDataBus, "[ PPTClient ] Couldn't find ChunkDataBus!")
local SharedConfigBus: NetworkEvent = ModuleConfig.SharedConfigBus
assert(SharedConfigBus, "[ PPTClient ] Couldn't find SharedConfigBus!")
local DisableRuntime: BindableEvent = ModuleConfig.DisableRuntime
assert(SharedConfigBus, "[ PPTServer ] Couldn't find DisableRuntime!")
-- Did you read the comment?

local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create
local VecFloor: typeof(vector.floor) = vector.floor
local MathFloor: typeof(math.floor) = math.floor
local TableInsert: typeof(table.insert) = table.insert
local TableCreate: typeof(table.create) = table.create
local TableClear: typeof(table.clear) = table.clear
local TableConcat: typeof(table.concat) = table.concat
local StringSplit: typeof(string.split) = string.split

-- Runtime data that is stored privately.
-- Call PPT.Cleanup() to empty these.
local TrianglePool: BasinClass
local UnrenderedChunks: { [number]: ChunkData } = {} :: { [number]: ChunkData }
local RenderedChunks: { [number]: ChunkData } = {} :: { [number]: ChunkData }
local TriangleVisuals: {[number]: TriangleVisualQuery} = {} :: {[number]: TriangleVisualQuery}

--[[
    Helper function for getting the index of a vertex.
--]]
local function GetIndex(x: number, z: number, stepsperrow: number): number
	return x * stepsperrow + z + 1
end

--[[
    Helper function for getting the index / key of a chunk.
--]]
local function GetChunkKey(x: number, z: number): number
	return x * 10000000 + z
end

--[[
    Requests the currently set shared config and returns it as
    a table.
--]]
function PPT.RequestSharedConfig(): { number }
	SharedConfigBus.InvokeServer()
end

local function WorldgenNoise2D(
	Frequency: number,
	Amplitude: number,
	Scale: number,
	Octaves: number,
	Persistence: number,
	Lacunarity: number,
	Seed: number,
	x: number,
	z: number
): number
	local Result: number = 0
	local MaxAmplitude: number = 0
	for CurrOctave = 1, Octaves do
		Result += Noise(x * Frequency, z * Frequency, Seed) * Amplitude
		MaxAmplitude += Amplitude
		Frequency *= Lacunarity
		Amplitude *= Persistence
	end
	return Result / MaxAmplitude * Scale
end

--[[
	Applies visuals to the passed in part
--]]
local function ApplyVisual(Query: TriangleVisualQuery, Triangle: Part): nil
	if Query.Color then Triangle.Color = Query.Color end
	if Query.Material then Triangle.Material = Query.Material end
	if Query.Anchored then Triangle.Anchored = Query.Anchored end
	if Query.Friction then Triangle.Friction = Query.Friction end
	if Query.Mass then Triangle.Mass = Query.Mass end
	if Query.CollisionLayers then Triangle.CollisionLayers = Query.CollisionLayers end
	if Query.CollisionMask then Triangle.CollisionMask = Query.CollisionMask end
	if Query.IsSpawn then Triangle.IsSpawn = Query.IsSpawn end
	if Query.CanCollide then Triangle.CanCollide = Query.CanCollide end
	if Query.Bounciness then Triangle.Bounciness = Query.Bounciness end
end

--[[
    Renders the input chunk using triangles from the provided
    triangle pool.
--]]
function PPT.RenderChunk(Chunk: ChunkData, TrianglePool: BasinClass, SharedConfig: { number }): nil
	Chunk.isRendered = true
	local Config: { number } = SharedConfig
	local ChunkSize: number = Config.ChunkSize
	local PointInterval: number = Config.PointInterval
	local stepsPerRow: number = (ChunkSize / PointInterval) + 1
	local VertexCoordinates: { vector } = Chunk.VertexCoordinates

	for x: number = 0, ChunkSize - 1 do
		if x % PointInterval ~= 0 then
			continue
		end
		local xi: number = x / PointInterval
		local xiNext: number = (x + PointInterval) / PointInterval
		for z: number = 0, ChunkSize - 1 do
			if z % PointInterval ~= 0 then
				continue
			end
			local zi: number = z / PointInterval
			local ziNext: number = (z + PointInterval) / PointInterval

			local po1: vector = VertexCoordinates[GetIndex(xi, zi, stepsPerRow)]
			local po2: vector = VertexCoordinates[GetIndex(xiNext, zi, stepsPerRow)]
			local po3: vector = VertexCoordinates[GetIndex(xi, ziNext, stepsPerRow)]
			local po4: vector = VertexCoordinates[GetIndex(xiNext, ziNext, stepsPerRow)]

			local triangles: { ObjectClass }, success: boolean = TrianglePool:Pull(4)
			if not success then
				if triangles and #triangles > 0 then
					for _, obj: ObjectClass in ipairs(triangles) do
						obj:Push()
					end
				end
				print("[ PPT ] Failed to pull triangles for chunk!")
				TrianglePool:Reserve(#TrianglePool.Pool + ChunkSize * ChunkSize)
				triangles, success = TrianglePool:Pull(4)
				if not success then
					Chunk.isRendered = false
					continue
				end
			end
			for _, obj: ObjectClass in ipairs(triangles) do
				Chunk.PooledObjects[#Chunk.PooledObjects + 1] = obj
			end

			local tri1: Part = triangles[1].Item
			local tri2: Part = triangles[2].Item
			local tri3: Part = triangles[3].Item
			local tri4: Part = triangles[4].Item

			Triangle3D.SplitTriangle(tri1, tri2, po1, po2, po4)
			Triangle3D.SplitTriangle(tri3, tri4, po1, po4, po3)

			-- process triangle visuals
			for _: number, obj: ObjectClass in ipairs(triangles) do
				local Height: number = obj.Item.Position.Y
				local currquery: TriangleVisualQuery = nil
				for minheight: number, query: TriangleVisualQuery in pairs(TriangleVisuals) do
					if not currquery then currquery = query end
					if Height > minheight and currquery.MinHeight < minheight then
						currquery = query
					end
				end
				ApplyVisual(currquery, obj.Item)
			end

			tri1.Parent = Environment
			tri2.Parent = Environment
			tri3.Parent = Environment
			tri4.Parent = Environment
		end
	end
end

--[[
    Unrenders a chunk by emptying its triangles and
    sets the rendered state to false.
--]]
function PPT.UnrenderChunk(Chunk: ChunkData): nil
	for _, obj: ObjectClass in ipairs(Chunk.PooledObjects) do
		obj:Push()
	end

	TableClear(Chunk.PooledObjects)
	Chunk.isRendered = false
end

--[[
    Encodes the provided chunkdata into a string.
    Can be decoded back into chunkdata using PPT.Decode.
--]]
function PPT.Encode(Chunk: ChunkData): string
	local vertParts: { string } = TableCreate(#Chunk.VertexCoordinates * 3)
	for i, v in ipairs(Chunk.VertexCoordinates) do
		vertParts[(i - 1) * 3 + 1] = tostring(v.x)
		vertParts[(i - 1) * 3 + 2] = tostring(v.y)
		vertParts[(i - 1) * 3 + 3] = tostring(v.z)
	end
	return json.serialize({
		VertexCoordinates = TableConcat(vertParts, "_"),
		ChunkPositionX = Chunk.ChunkPosition.x,
		ChunkPositionY = Chunk.ChunkPosition.y,
	})
end

--[[
    Encodes the provided chunkdata string into chunkdata.
    Can be encoded back into string using PPT.Encode.
--]]
function PPT.Decode(ChunkString: string): ChunkData
	local ChunkJson = json.parse(ChunkString)
	local parts: { string } = StringSplit(ChunkJson.VertexCoordinates, "_")
	local verts: { vector } = TableCreate(#parts / 3)
	for i = 1, #parts, 3 do
		verts[(i - 1) / 3 + 1] = VecCreate(tonumber(parts[i]), tonumber(parts[i + 1]), tonumber(parts[i + 2]))
	end
	return {
		ChunkPosition = VecCreate(ChunkJson.ChunkPositionX, ChunkJson.ChunkPositionY, 0),
		VertexCoordinates = verts,
		PooledObjects = {},
		isRendered = false,
	}
end

--[[
    Batch version of PPT.Encode.
    Input a table of chunks to get a single string.
--]]
function PPT.EncodeBatch(Chunks: { ChunkData }): string
	local batch: { string } = TableCreate(#Chunks)
	for _, chunk: ChunkData in ipairs(Chunks) do
		local chunk_str: string = PPT.Encode(chunk)
		TableInsert(batch, chunk_str)
	end
	return json.serialize(batch)
end

--[[
    Batch version of PPT.Decode.
    Input a chunk batch string from PPT.EncodeBatch to get a table of chunks.
--]]
function PPT.DecodeBatch(ChunkBatchString: string): { ChunkData }
	local batch: { string } = json.parse(ChunkBatchString)
	local decoded: { ChunkData } = TableCreate(#batch)
	for _, chunk_str: string in ipairs(batch) do
		local chunk: ChunkData = PPT.Decode(chunk_str)
		TableInsert(decoded, chunk)
	end
	return decoded
end

local function CalculateTriPoolSize(PointInterval: number, ChunkSize: number, RenderDistance: number): number
	local chunktricount: number = (ChunkSize / PointInterval) / 3 * RenderDistance
	return chunktricount
end

--[[
    Only runnable on the client.
    Handles culling, object pooling, and rendering for the client.
    Pass chunks to the client using ChunkDataBus, with only chunk batch sends.

    Tickrate is the number of ticks per second that you want
    Eg; 20 for 1 tick to be 0.05 seconds

    InitialTriAmount is the number of pre-allocated triangles
    you want the client to have.

    RenderDistance is the number of chunks you want the runtime to render.
    RenderDistance can be updated via PPT.UpdateRenderDistance
--]]
function PPT.EnableClientRuntime(Tickrate: number, RenderDistance: number, InitialTriAmount: number): nil
	if not Players.LocalPlayer then
		return
	end
	if not RenderDistance or RenderDistance < 0 then
		return
	end
	if not Tickrate or (Tickrate and Tickrate < 0) then
		return
	end
	if not InitialTriAmount or InitialTriAmount < 1 then
		return
	end
	local Player: Player = Players.LocalPlayer


	local ChunkDataBusConnection: PTSignal = ChunkDataBus.InvokedClient:Connect(
		function(ChunkBatchMessage: NetMessage): nil
			for _: string, chunk: ChunkData in ipairs(PPT.DecodeBatch(ChunkBatchMessage:GetString("chunks"))) do
				UnrenderedChunks[GetChunkKey(chunk.ChunkPosition.x, chunk.ChunkPosition.y)] = chunk
			end
		end
	)

	local Config: { number } = {}
	local SharedConfigBusConnection: PTSignal = SharedConfigBus.InvokedClient:Connect(function(msg: NetMessage)
		Config.PointInterval = msg:GetNumber("PointInterval")
		Config.ChunkSize = msg:GetNumber("ChunkSize")
	end)
	PPT.RequestSharedConfig()

	if not TrianglePool then
		local PoolSuccess: boolean
		TrianglePool, PoolSuccess = Basin.New(Triangle, InitialTriAmount, false)
		if not PoolSuccess then
			return
		end
	elseif TrianglePool.Size < InitialTriAmount then
		TrianglePool:Reserve(InitialTriAmount)
	end

	local ChangeRenderDistanceConnection: PTSignal = ChangeRenderDistance.Invoked:Connect(function(NewDist: number): nil
		RenderDistance = NewDist
	end)

	local last_position: vector? = nil
	local elapsed_dt: number = 0
	local PreRenderedConnection: PTSignal = Hooks.PreRendered:Connect(function(DeltaTime: number)
		elapsed_dt += DeltaTime
		if elapsed_dt < 1 / Tickrate then
			return
		end
		elapsed_dt = 0

		if not Config or not Config.ChunkSize then
			PPT.RequestSharedConfig()
			return
		end

		local playerchunkpos: vector = VecFloor(VecCreate(Player.Position.X, Player.Position.Z) / Config.ChunkSize)
		if last_position == playerchunkpos then return end
		last_position = playerchunkpos

		local renderwidth: number = RenderDistance * 2 - 1
		for idx: number = 0, renderwidth * renderwidth - 1 do
			local x: number = (idx % renderwidth) - RenderDistance
			local z: number = MathFloor(idx / renderwidth) - RenderDistance
			local currchunkpos: vector = VecCreate(x, z) + playerchunkpos
			local key: number = GetChunkKey(currchunkpos.x, currchunkpos.y)
			if not UnrenderedChunks[key] then
				continue
			end
			local chunk: ChunkData = UnrenderedChunks[key]
			UnrenderedChunks[key] = nil
			RenderedChunks[key] = chunk
			PPT.RenderChunk(chunk, TrianglePool, Config)
		end

		for key: number, chunk: ChunkData in pairs(RenderedChunks) do
			local outOfRange: boolean = vector.magnitude((chunk.ChunkPosition - playerchunkpos)) > RenderDistance
			if not outOfRange then
				continue
			end
			PPT.UnrenderChunk(chunk)
			UnrenderedChunks[key] = chunk
			RenderedChunks[key] = nil
		end
	end)

	local DisableRuntimeConnection: PTSignal
	DisableRuntimeConnection = DisableRuntime.Invoked:Connect(function()
		print("[ PPTClient ] Disabled Client Runtime!")
		PreRenderedConnection:Disconnect()
		ChunkDataBusConnection:Disconnect()
		SharedConfigBusConnection:Disconnect()
		ChangeRenderDistanceConnection:Disconnect()
		DisableRuntimeConnection:Disconnect()
	end)
end

--[[
    Request chunks from the server. Only usable on the client.
    ChunkCoordinates must be a table of native luau vectors.
--]]
function PPT.RequestChunks(ChunkCoordinates: { vector }): nil
	if not Players.LocalPlayer then
		return
	end
	local req: NetMessage = NetMessage.New()
	local chunkcoordstr: { string } = TableCreate(#ChunkCoordinates)
	for idx: number, vec: vector in ipairs(ChunkCoordinates) do
		chunkcoordstr[idx] = tostring(vec)
	end

	req:AddString("ChunkCoordinates", TableConcat(chunkcoordstr, "_"))
	ChunkDataBus.InvokeServer(req)
end

--[[
    Update render distance.
    Only runnable on client.
--]]
function PPT.UpdateRenderDistance(RenderDistance: number): nil
	if not Players.LocalPlayer then
		return
	end
	ChangeRenderDistance.Invoke(RenderDistance)
end

--[[
	Disables the currently active client runtime.
--]]
function PPT.DisableClientRuntime(): nil
	DisableRuntime.Invoke()
end

--[[
	Empties currently cached rendered and unrendered chunks,
	along with the triangle pool.
--]]
function PPT.Cleanup(): nil
	TrianglePool:Destroy()
	TableClear(RenderedChunks)
	TableClear(UnrenderedChunks)
	TableClear(TriangleVisuals)
end

--[[
	Appends a configuration(s) to the TriangleVisuals	
	table which allows the automatic changing of properties
	for triangles at different heights.
--]]
function PPT.AppendTriangleVisuals(Queries: {TriangleVisualQuery}): nil
	for idx: number, Query: TriangleVisualQuery in ipairs(Queries) do
		local MinHeight: number = Query.MinHeight
		if TriangleVisuals[MinHeight] then 
			print("[ PPTClient ] Unable to add triangle visual query as it matches the MinHeight of another query!")
			continue
		end
		TriangleVisuals[MinHeight] = Query
	end
end

return PPT
