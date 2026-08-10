--!strict
--!native
type Success	= boolean
type Reason		= string

--[Cached functions]--
local createtable: typeof(table.create) = table.create
local cleartable: typeof(table.clear) = table.clear
local getcreatetime: typeof(os.clock) = os.clock
local floor: typeof(math.floor) = math.floor

local function Log(Reason: Reason): Reason
	print(string.format("[Basin]: %s", Reason))
	return Reason
end

export type ObjectProperties = {
	--[Properties]--
	InUse: boolean,
	ParentBasin: BasinClass,
	IsUnanchored: boolean,
	IsInstance: boolean,
	IsPhysical: boolean,
	IsNPC: boolean,
	isParticles: boolean,
	ToggleAnchor: boolean,
	Item: any,

	--[Methods]--
	New:	(ItemType: any, Pool: BasinClass) -> (Success, ObjectClass?, Reason?),
	Push: () -> (Success, Reason?)
}
export type ObjectClass = typeof(setmetatable(
	{} :: ObjectProperties,
	{}
))

export type BasinProperties = {
	--[Properties]--
	Size: number,
	Pool: {ObjectClass},
	AvaliableObjs: {ObjectClass},
	ItemType: any,
	Directory: Folder?,
	
	--[Methods]--
	New:			(ItemType: any, Amount: number, isShared: boolean?) -> (BasinClass?, Success, Reason?),
	Pull:			(Amount: number?) -> (ObjectClass? | {ObjectClass}?, Success, Reason?),
	Reserve:	(Amount: number) -> (Success, Reason?),
	Destroy:	()							 -> (Success, Reason?)
}
export type BasinClass = typeof(setmetatable(
	{} :: BasinProperties,
	{}
))

local Object = {} 
Object.__index = Object

--[[
	Creates a new object in the specified object pool.
	This is not intended to be used manually, as it can cause
	bugs if used.
]]
function Object.New(ItemType: any, Basin: BasinClass): (Success, ObjectClass?, Reason?)
	local self: ObjectClass = setmetatable({} :: ObjectProperties, Object)

	self.ParentBasin = Basin
	self.Item = ItemType:Clone()
	self.Item.Parent = Basin.Directory
	self.InUse = false
	self.IsUnanchored = false
	self.IsPhysical = ItemType:IsA("Physical")
	self.IsInstance = self.IsPhysical or ItemType:IsA("Instance")
	self.IsNPC = ItemType:IsA("NPC")
	self.isParticles = ItemType:IsA("Particles")

	if self.IsPhysical then
		self.IsUnanchored = ItemType.Anchored
		self.Item.Anchored = true
		self.ToggleAnchor = not self.IsUnanchored
	end
	
	return true, self
end

--[[
	Pushes the object back into its parent object pool.
	Also pushes the item back to its parent object pool directory.

	If the object's item is an NPC, it will respawn it after
	being moved to the directory. If the object's item is a
	particle, then it will stop the particle after being moved
	to the directory.
]]
function Object:Push(): (Success, Reason?)
	if not self.IsUnanchored and self.IsPhysical then self.Item.Anchored = false end

	self.Item.Parent = self.ParentBasin.Directory
	self.InUse = false
	
	if self.IsNPC then self.Item:Respawn() end
	if self.isParticles then self.Item:Stop() end

	local AvaliableObjs: {ObjectClass} = self.ParentBasin.AvaliableObjs
	AvaliableObjs[#AvaliableObjs + 1] = self

	return true
end

local Basin = {}
Basin.__index = Basin

--[[
	Creates a new basin with the specified item type and the amount of objects.
	Returns nil and false if it goes wrong.

	Setting a objectpool to be shared will place it into Hidden instead of
	ServerHidden, if made on the server.

	Default isShared value is false.
]]
function Basin.New(ItemType: any, Amount: number, isShared: boolean?): (BasinClass?, Success, Reason?)
	local self: BasinClass = setmetatable(
		{} :: BasinProperties,
		Basin
	)
	
	local isClient: boolean = if Players.LocalPlayer then true else false
	local Shared: boolean = isShared or false

	if not world.Hidden.ObjectPools and isClient then 
		local ObjectPoolsFolder = Folder.New()	
		ObjectPoolsFolder.Name = "ObjectPools"
		ObjectPoolsFolder.Parent = world.Hidden
	elseif not world.Hidden.ObjectPoolsFolder and not isClient then
		local ObjectPoolsFolder = Folder.New()	
		ObjectPoolsFolder.Name = "ObjectPools"
		ObjectPoolsFolder.Parent = world.ServerHidden
	end

	local CreationTime: number = floor(getcreatetime() * 1000)
	local Directory: Folder = Folder.New()
	Directory.Parent = if isClient or Shared then world.Hidden.ObjectPools else world.ServerHidden.ObjectPools
	Directory.Name = tostring(CreationTime)

	self.Size = Amount
	self.Directory = Directory
	self.ItemType = ItemType
	
	local CurrentObjectCount: number = 0
	self.Pool = {}
	self.AvaliableObjs = {}
	while CurrentObjectCount < Amount do
		local 
			ObjSuccess: Success, 
			Obj: ObjectClass? = Object.New(ItemType, self)
		if not ObjSuccess then return nil, false, Log("Failed to create object of item type '" .. tostring(ItemType) .. "'!") end
		self.Pool[#self.Pool + 1] = Obj :: ObjectClass
		self.AvaliableObjs[#self.AvaliableObjs + 1] = Obj :: ObjectClass
		CurrentObjectCount += 1
	end

	return self, true, Log("Created object pool with size " .. tostring(#self.Pool) .. " with item type " .. tostring(ItemType))
end

--[[
	Pulls a specified number of objects from the basin. Will skip Objects that are InUse.
	Default amount is 1, so the first and only argument can remain empty if the user desires.
]]
function Basin:Pull(Amount: number?): (ObjectClass? | {ObjectClass}?, Success, Reason?)
	if not self.AvaliableObjs then return nil, false, Log("No avaliable objects found in the object pool!") end
	local AvaliableObjs: {ObjectClass} = self.AvaliableObjs

	local AvaliableObjsCount: number = #AvaliableObjs
	local AmountToPull: number = Amount or 1
	if Amount < 0 then return nil, false, Log("Cannot pull a negative number of objects!") end
	if AmountToPull > AvaliableObjsCount then return nil, false, Log("Not enough avaliable objects in pool to pull " .. tostring(Amount) .. " objects!") end
	
	if AmountToPull == 1 then
		local Obj: ObjectClass = AvaliableObjs[AvaliableObjsCount]
		AvaliableObjs[AvaliableObjsCount] = nil
		Obj.InUse = true
		if Obj.ToggleAnchor then Obj.Item.Anchored = false end
		return Obj, true
	end
	
	local Pulled: {ObjectClass} | ObjectClass = createtable(AmountToPull)
	for index = 1, AmountToPull do
		local Obj: ObjectClass = AvaliableObjs[AvaliableObjsCount - index + 1]
		AvaliableObjs[AvaliableObjsCount - index + 1] = nil
		Obj.InUse = true
		if Obj.ToggleAnchor then Obj.Item.Anchored = false end
		Pulled[#Pulled + 1] = Obj
	end

	return Pulled, true
end

--[[
	Updates the size of the basin. Note that shrinking the basin will result in objects
	being destroyed if they do not fit into the new basin size.	

	Note that by "update", this means the size of the basin will be set to the new amount.
]]
function Basin:Reserve(Amount: number): (Success, Reason?)
	if not Amount or Amount < 1 then return false, Log("Reserve amount cannot be set to a value less than one.") end

	local Pool: {ObjectClass} = self.Pool
	if Amount > self.Size then
		local ItemType: any = self.ItemType
		local ObjCreated: number = 0

		while ObjCreated < (Amount - self.Size) do
			local ObjSuccess: Success, Obj: ObjectClass? = Object.New(ItemType, self)
			if not ObjSuccess then return false, Log("Failed to create object of item type '" .. tostring(self.ItemType) .. "' while changing reserve size.") end
			Pool[#Pool + 1] = Obj :: ObjectClass
			ObjCreated += 1
		end
		
		self.Size = Amount
		return true
	end

	local remove: typeof(table.remove) = table.remove

	local ObjRemoved: number = 0
	local ToRemove: number = (#Pool - Amount)
	local Index: number = #Pool

	while ObjRemoved < ToRemove and Index >= 1 do
		local Obj = Pool[Index]
		
		if Obj.IsInstance then Obj.Item:Destroy() end
		Obj.Item = nil

		remove(Pool, Index)
		ObjRemoved += 1
		Index -= 1
	end

	if ObjRemoved == ToRemove then
		self.Size = Amount
		return true
	end

	return false, Log("Failed to change the reserves of the target ObjectPool to " .. tostring(Amount) .. "!")
end

--[[
	Destroys the basin's contents, directory, and itself.
]]
function Basin:Destroy(): (Success, Reason?)
	for Index: number, Obj: ObjectClass in ipairs(self.Pool) do
		if Obj.IsInstance then Obj.Item:Destroy() end
		Obj.Item = nil
	end

	cleartable(self.Pool)
	self.Directory:Destroy()
	cleartable(self)
	return true
end

return Basin
