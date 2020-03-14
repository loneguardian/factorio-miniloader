local circuit = require 'circuit'
local util = require 'util'

local M = {}

local function fast_replace_loader(loader_name, existing_loader)
  local last_user = existing_loader.last_user
  local new_loader = existing_loader.surface.create_entity{
    name = loader_name,
    position = existing_loader.position,
    direction = existing_loader.direction,
    force = existing_loader.force,
    fast_replace = true,
    spill = false,
    create_build_effect_smoke = false,
    type = existing_loader.loader_type,
  }
  new_loader.last_user = last_user
  return new_loader
end

local function create_new_loader(loader_name, inserter, orientation)
  local loader = inserter.surface.create_entity{
    name = loader_name,
    position = inserter.position,
    direction = orientation.direction,
    force = inserter.force,
    type = orientation.type,
  }
  loader.destructible = false
  return loader
end

local function ensure_loader(inserter, orientation)
  local surface = inserter.surface
  local position = inserter.position
  local loader_name = inserter.name:gsub("inserter$", "loader")
  local existing_loader = util.find_miniloaders{surface=surface, position=position}[1]
  if existing_loader then
    return fast_replace_loader(loader_name, existing_loader)
  end
  return create_new_loader(loader_name, inserter, orientation)
end

local function create_miniloader_inserter(main_inserter, fast_replace)
  local new_inserter = main_inserter.surface.create_entity{
    name = main_inserter.name,
    position = main_inserter.position,
    direction = main_inserter.direction,
    force = main_inserter.force,
    fast_replace = fast_replace,
    spill = false,
    create_build_effect_smoke = false,
  }
  new_inserter.last_user = main_inserter.last_user
  new_inserter.inserter_stack_size_override = 1
  return new_inserter
end

local function ensure_inserters(desired_count, main_inserter)
  local inserter_name = main_inserter.name
  local surface = main_inserter.surface
  local position = main_inserter.position

  local inserters = surface.find_entities_filtered{ type = "inserter", position = position }

  -- remove extra inserters
  for i=#inserters, desired_count+1, -1 do
    inserters[i].destroy()
    inserters[i] = nil
  end

  -- replace existing inserters
  for i=1, #inserters do
    if inserters[i].name ~= inserter_name then
      create_miniloader_inserter(main_inserter, true)
      inserters[i].destroy()
    end
  end

  -- create missing inserters
  for i=#inserters+1, desired_count do
    create_miniloader_inserter(main_inserter, false)
  end

  -- ensure only primary inserter can be damaged
  -- note that order may be different after destroy + create
  inserters = surface.find_entities_filtered{ type = "inserter", position = position }
  inserters[1].destructible = true
  for i=2,#inserters do
    inserters[i].destructible = false
  end
end

local function ensure_chest(main_inserter)
  local chest = main_inserter.surface.find_entity("miniloader-target-chest", main_inserter.position)
  if not chest then
    chest = main_inserter.surface.create_entity{
      name = "miniloader-target-chest",
      position = main_inserter.position,
      force = main_inserter.force,
    }
    chest.destructible = false
  end
  return chest
end

local function fixup(main_inserter, orientation)
  if not orientation then
    orientation = {direction = util.opposite_direction(main_inserter.direction), type = "input"}
  end
  local loader = ensure_loader(main_inserter, orientation)
  ensure_inserters(util.num_inserters(loader), main_inserter)
  ensure_chest(main_inserter)

  util.update_inserters(loader)
  circuit.sync_behavior(main_inserter)
  circuit.sync_filters(main_inserter)
  circuit.sync_partner_connections(main_inserter)

  return loader
end

return {
  fixup = fixup,
}