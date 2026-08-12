--!native
export type ChunkData = {
	ChunkPosition: vector,
	VertexCoordinates: { vector },
	PooledObjects: { ObjectClass },
	isRendered: boolean,
}

export type PPTConfig = {
	--[[
		Server only property.
		How drastically / erratically the noise value
		can change.
	--]]
	Frequency: number,
	--[[
		Server only property.
		Intensity of the noise value.
	--]]
	Amplitude: number,
	--[[
		Server only property.
		Multiplier added to the finishing result of the
		noise function after normalization. Controls
		the overall height range of the terrain.
	--]]
	Scale: number,
	--[[
		Server only property.
		The number of times noise is layered
		ontop of itself. Must be atleast 1.
	--]]
	Octaves: number,
	--[[
		Server only property.
		The amount the amplitude value changes
		every octave.
	--]]
	Persistence: number,
	--[[
		Server only property.
		The amount the frequency value changes
		every octave.
	--]]
	Lacunarity: number,
	--[[
		Server only property.
		The maximum value the Y position of a vertex.
	--]]
	MaximumY: number,
	--[[
		Server only property.
		The minimum value the Y position of a vertex.
	--]]
	MinimumY: number,
	--[[
		Server only property.
		The seed used to generate noise.
	--]]
	Seed: number,
	--[[
		Server only property, but the client can view it.
		The size of a chunk in polytoria units.
	--]]
	ChunkSize: number,
	--[[
		Server only property, but the client can view it.
		The amount of units that a point is placed.
		Must be a factor of chunk size / evenly divide with it.
		Eg; ChunkSize 16, PointInterval 4 works, but if PointInterval is 5 it'll crash.
	--]]
	PointInterval: number
}

local PPT = {}
local ModuleConfig: typeof(require(script.ServerConfig)) = require(script.ServerConfig)
assert(ModuleConfig, "[ PPTServer ] Couldn't find ModuleConfig (ServerConfig)!")

-- Hi, Don't change paths to events here, instead do it in ServerConfig!
local ChunkDataBus: NetworkEvent = ModuleConfig.ChunkDataBus
assert(ChunkDataBus, "[ PPTServer ] Couldn't find ChunkDataBus!")
local SharedConfigBus: NetworkEvent = ModuleConfig.SharedConfigBus
assert(SharedConfigBus, "[ PPTServer ] Couldn't find SharedConfigBus!")
local DisableRuntime: BindableEvent = ModuleConfig.DisableRuntime
assert(SharedConfigBus, "[ PPTServer ] Couldn't find DisableRuntime!")
-- Did you read the comment?

local Noise: typeof(math.noise) = math.noise
local VecCreate: typeof(vector.create) = vector.create
local TableInsert: typeof(table.insert) = table.insert
local TableCreate: typeof(table.create) = table.create
local TableClear: typeof(table.clear) = table.clear
local TableConcat: typeof(table.concat) = table.concat
local StringSplit: typeof(string.split) = string.split

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
    Server only function for setting shared & server config.
--]]
function PPT.SetConfig(Config: PPTConfig): nil
	if Players.LocalPlayer then return end
	ConfigServer = Config
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
		Result += Noise(x * Frequency + Seed, z * Frequency + Seed) * Amplitude
		MaxAmplitude += Amplitude
		Frequency *= Lacunarity
		Amplitude *= Persistence
	end
	return Result / MaxAmplitude * Scale
end

--[[
    Generates chunk data with a provided seed and chunk coordinate.
    Server use only.
--]]
function PPT.GenerateChunk(ChunkCoordinate: vector, PredicateHeight: (number) -> number): ChunkData
	local Config = ConfigServer
	local ChunkSize: number = Config.ChunkSize
	local PointInterval: number = Config.PointInterval
	local Seed: number = Config.Seed
	local stepsPerRow: number = (ChunkSize / PointInterval) + 1

	local Chunk: ChunkData = {
		ChunkPosition = ChunkCoordinate,
		VertexCoordinates = TableCreate(stepsPerRow * stepsPerRow),
		PooledObjects = {},
		isRendered = false,
	}

	-- flatten this loop when possible
	for x: number = 0, ChunkSize do
		if x % PointInterval ~= 0 then
			continue
		end
		local worldx: number = ChunkCoordinate.x * ChunkSize + x
		local xi: number = x / PointInterval
		for z: number = 0, ChunkSize do
			if z % PointInterval ~= 0 then
				continue
			end
			local worldz: number = ChunkCoordinate.y * ChunkSize + z
			local zi: number = z / PointInterval
			local noise: number = WorldgenNoise2D(
				Config.Frequency,
				Config.Amplitude,
				Config.Scale,
				Config.Octaves,
				Config.Persistence,
				Config.Lacunarity,
				Seed,
				worldx,
				worldz
			)
			local y: number = math.clamp(PredicateHeight(noise), Config.MinimumY, Config.MaximumY)

			Chunk.VertexCoordinates[GetIndex(xi, zi, stepsPerRow)] = VecCreate(worldx, y, worldz)
		end
	end

	return Chunk
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

--[[
	Starts the server runtime. Tickrate is the amount of ticks per second you want.
	
	PredicateHeight is a callback you can pass into modify the height value generated by noise,
	which is then clamped by your configuration's minimum X and minimum Y.

	Note that cached chunks will disappear when stopping the runtime.
	This probably isn't that big of an issue, as computing chunk data is very fast, assuming
	your predicate height callback isn't doing anything freaky.
--]]
function PPT.StartServerRuntime(Tickrate: number, PredicateHeight: (number) -> number): nil
	local DisableRuntimeValue: boolean = false
	if Players.LocalPlayer then
		return
	end
	local SharedConfigBusConnection: PTSignal = SharedConfigBus.InvokedServer:Connect(function(sender: Player, msg: NetMessage)
		local returnmsg: NetMessage = NetMessage.New()
		returnmsg:AddNumber("PointInterval", ConfigServer.PointInterval)
		returnmsg:AddNumber("ChunkSize", ConfigServer.ChunkSize)
		SharedConfigBus.InvokeClient(returnmsg, sender)
	end)

	local CachedChunks: { ChunkData } = {}
	local ChunkDataBusConnection: PTSignal = ChunkDataBus.InvokedServer:Connect(function(sender: Player, req: NetMessage)
		local chunkcoordstr: { string } = StringSplit(req:GetString("ChunkCoordinates"), "_")

		local chunkcoords: { vector } = TableCreate(#chunkcoordstr)
		for idx: number, vecstr: string in ipairs(chunkcoordstr) do
			local nums: { string } = StringSplit(vecstr, ",")
			chunkcoords[idx] = VecCreate(tonumber(nums[1]), tonumber(nums[2]))
		end

		-- only send 2 chunks at once
		local chunks: { ChunkData } = TableCreate(2)
		for idx: number, vec: vector in ipairs(chunkcoords) do
			local key: string = tostring(vec.x) .. "," .. tostring(vec.y)
			if not CachedChunks[key] then
				local chunk = PPT.GenerateChunk(vec, PredicateHeight)
				chunks[idx] = chunk
				CachedChunks[key] = chunk
			else
				chunks[idx] = CachedChunks[key]
			end
		end
		local BatchMsg: NetMessage = NetMessage.New()
		BatchMsg:AddString("chunks", PPT.EncodeBatch(chunks))
		ChunkDataBus.InvokeClient(BatchMsg, sender)
	end)

	local temp: PPTConfig = ConfigServer
	local elapsed_dt: number = 0
	local UpdateMsg: NetMessage = NetMessage.New()
	local PrerenderedConnection: PTSignal = Hooks.PreRendered:Connect(function(DeltaTime: number)
		if DisableRuntimeValue then
			Hooks.PreRendered:Disconnect()
			return
		end
		elapsed_dt += DeltaTime
		if elapsed_dt < 1 / Tickrate then
			return
		end
		elapsed_dt = 0

		if ConfigServer ~= temp then
			temp = ConfigServer
			UpdateMsg:AddNumber("PointInterval", ConfigServer.PointInterval)
			UpdateMsg:AddNumber("ChunkSize", ConfigServer.ChunkSize)
			SharedConfigBus.InvokeClients(UpdateMsg)
		end
	end)

	local DisableRuntimeConnection: PTSignal
	DisableRuntimeConnection = DisableRuntime.Invoked:Connect(function()
		print("[ PPTServer ] Disabling server runtime!")
		SharedConfigBusConnection:Disconnect()
		ChunkDataBusConnection:Disconnect()
		PrerenderedConnection:Disconnect()
		DisableRuntimeConnection:Disconnect()
		TableClear(CachedChunks)
	end)
end

--[[
	Disables the currently active server runtime.
--]]
function PPT.DisableServerRuntime(): nil
	DisableRuntime.Invoke()
end

return PPT
