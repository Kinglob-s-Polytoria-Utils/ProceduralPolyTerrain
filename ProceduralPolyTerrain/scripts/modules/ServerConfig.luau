-- [ Server Config ] --
--[[
  Hi, If you're changing the structure of where modules and events go
  regarding ProcedualPolyTerrain, you can change file paths here.

  File names must remain untouched, because I am a bad programmer.
--]]
local Config = {}
Config.ChunkDataBus = world.Hidden.ChunkDataBus -- change this to where your chunkdatabus parent is
Config.SharedConfigBus = world.Hidden.SharedConfigBus -- change this to where your sharedconfigbus parent is

return Config