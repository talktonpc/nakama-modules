local nk = require("nakama")

-- ===========================================================================
local function create_or_join_match(context, payload)
    -- example input:
    -- { "level": 15 }
    payload = nk.json_decode(payload)
  
    local limit = 10
    local authoritative = true
    local label = "world"
    local min_size = 0
    local max_size = 9
    local matches = nk.match_list(limit, authoritative, label, min_size, max_size)
  
    local match_id
    if (#matches > 0) then
      -- sort tables by number of players
      table.sort(matches, function(a, b)
        return a.size > b.size
      end)
      match_id = matches[1].match_id
    else

        local state = {
            presences = {{
                node = "nakama-metatop",
                reason = 0,
                session_id = 0,
                user_id = "00000000-0000-0000-0000-000000000000",
                username = label
            }},
            inputs = {},
            positions = {},
            jumps = {},
            colors = {},
            names = {},
            tickrate = 5,
            label = label,
            match_count = 100000
        }

        match_id = nk.match_create(label, state)
    end
  
    local response = nk.json_encode({ matchID = match_id })
    return response
  end
  nk.register_rpc(create_or_join_match, "rpc.machoo.world.join")

-- ===========================================================================
-- Gets the array of names currently in circulation out of non-user-owned storage.
-- @return A table in the format {names = {}}, with names being an array of strings.
local function _get_name_collection()
    local object_ids = {
        {
            collection = "global_data",
            key = "names"
        }
    }

    local objects = nakama.storage_read(object_ids)

    local names
    for _, object in pairs(objects) do
        names = object.value
        if names ~= nil then
            break
        end
    end

    if names ~= nil then
        return names
    else
        return {["names"] = {}}
    end
end

-- ===========================================================================
-- Writes an array of names to the non-user-owned storage.
-- @param names An array of strings
local function _write_names(names)
    local new_objects = {
        {
            collection = "global_data",
            key = "names",
            value = {["names"] = names},
            permission_read = 2,
            permission_write = 0
        }
    }

    nakama.storage_write(new_objects)
end

-- ===========================================================================
-- Finds the ID of the first match in the listings. If no match is found, creates one.
-- @return The ID of the match found or created.
local function _get_first_world()
    local matches = nakama.match_list()
    local current_match = matches[1]

    if current_match == nil then
        return nakama.match_create("world_control", {})
    else
        return current_match.match_id
    end
end

-- ===========================================================================
-- Below are RPC definitions.
-- These functions are exposed to Nakama's client through Remote Procedure Calls.
-- See nakama.register_rpc() calls at the end of the file.

-- ===========================================================================
-- Removes a name from inside non-user-owned storage, freeing it for re-use if it was taken.
-- @param payload A string representing the name to remove.
-- @return "1"
local function remove_character_name(_, payload)
    local names = _get_name_collection().names

    local name = payload

    local idx
    for k, current_name in ipairs(names) do
        if current_name == name then
            idx = k
            break
        end
    end

    if idx ~= nil then
        table.remove(names, idx)

        _write_names(names)
    end

    return "1"
end

-- ===========================================================================
-- Returns the ID of the world match so users can join it.
-- @return ID as a string
local function get_world_id(_, _)
    return _get_first_world()
end

-- ===========================================================================
-- Register a name inside non-user-owned storage that contains all names so
-- far, if the name is available.
-- @param payload A string representing the name to register.
-- @return "0" if the name is already taken, "1" if it's been registered successfully.
local function register_character_name(_, payload)
    local names = _get_name_collection().names

    local name = payload

    for _, current_name in ipairs(names) do
        if current_name == name then
            return "0"
        end
    end

    table.insert(names, name)

    _write_names(names)

    return "1"
end

-- ===========================================================================
-- RPC registered to Nakama
nakama.register_rpc(get_world_id, "get_world_id")
nakama.register_rpc(register_character_name, "register_character_name")
nakama.register_rpc(remove_character_name, "remove_character_name")

nk.run_once(function(ctx)
end)

-- ========================================================================END