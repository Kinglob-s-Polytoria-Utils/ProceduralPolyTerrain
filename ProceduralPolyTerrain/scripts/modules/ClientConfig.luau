-- [ Client Config ] --
--[[
  Hi, If you're changing the structure of where modules and events go
  regarding ProcedualPolyTerrain, you can change file paths here.

  File names must remain untouched, because I am a bad programmer.
--]]
local Config = {}
Config.ChunkDataBus = world.Hidden.ChunkDataBus -- change this to where your chunkdatabus parent is

Config.SharedConfigBus = world.Hidden.SharedConfigBus -- change this to where your sharedconfigbus parent is

Config.ChangeRenderDistance = script.Parent.ChangeRenderDistance -- change this to where your changerenderdistance parent is

Config.ClientTriangle = script.Parent.Triangle -- change this to where your template wedge part parent is

Config.Triangle3DModule = script.Parent.Triangle3D -- change this to where your triangle3d module parent is

Config.BasinModule = script.Parent.Basin -- change this to where your Basin module parent is

return Config