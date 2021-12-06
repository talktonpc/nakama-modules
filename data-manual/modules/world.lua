local nk = require("nakama")
local world = {}

-- Custom operation codes. Nakama specific codes are <= 0.
local OpCodes = {
    update_position = 1,
    update_input = 2,
    update_state = 3,
    update_jump = 4,
    do_spawn = 5,
    update_color = 6,
    initial_state = 7
}

-- Command pattern table for boiler plate updates that uses data and state.
local commands = {}

-- Updates the position in the game state
commands[OpCodes.update_position] = function(data, state)
    local id = data.id
    local position = data.pos
    if state.positions[id] ~= nil then
        state.positions[id] = position
    end
end

-- Updates the horizontal input direction in the game state
commands[OpCodes.update_input] = function(data, state)
    local id = data.id
    local input = data.inp
    if state.inputs[id] ~= nil then
        state.inputs[id].dir = input
    end
end

-- Updates whether a character jumped in the game state
commands[OpCodes.update_jump] = function(data, state)
    local id = data.id
    if state.inputs[id] ~= nil then
        state.inputs[id].jmp = 1
    end
end

-- Updates the character color in the game state once the player's picked a character
commands[OpCodes.do_spawn] = function(data, state)
    local id = data.id
    local color = data.col
    if state.colors[id] ~= nil then
        state.colors[id] = color
    end
end

-- Updates the character color in the game state after a player's changed colors
commands[OpCodes.update_color] = function(data, state)
    local id = data.id
    local color = data.col
    if state.colors[id] ~= nil then
        state.colors[id] = color
    end
end

function world.match_init(context, state)
    nk.logger_info("match_init ===========================")

    local tickrate = state["tickrate"]
    local label = state["label"]

    return state, tickrate, label
end

function world.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
    nk.logger_info("match_join_attempt ===========================")

    if state.presences[presence.user_id] ~= nil then
        return state, false, "User already logged in."
    end
    return state, true
end

function world.match_join(context, dispatcher, tick, state, presences)
    nk.logger_info("match_join ===========================")

    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = presence

        state.positions[presence.user_id] = {
            ["x"] = 0,
            ["y"] = 0,
            ["z"] = 0
        }

        state.inputs[presence.user_id] = {
            ["dir"] = 0,
            ["jmp"] = 0
        }

        state.colors[presence.user_id] = "1,1,1,1"

        state.names[presence.user_id] = "User"
    end

    return state
end

function world.match_leave(context, dispatcher, tick, state, presences)
    nk.logger_info("match_leave ===========================")

    for _, presence in ipairs(presences) do
        local new_objects = {
            {
                collection = "player_data",
                key = "position_" .. state.names[presence.user_id],
                user_id = presence.user_id,
                value = state.positions[presence.user_id]
            }
        }
        nk.storage_write(new_objects)

        state.presences[presence.user_id] = nil
        state.positions[presence.user_id] = nil
        state.inputs[presence.user_id] = nil
        state.jumps[presence.user_id] = nil
        state.colors[presence.user_id] = nil
        state.names[presence.user_id] = nil
    end
    return state
end

function world.match_loop(context, dispatcher, tick, state, messages)
    for _, message in ipairs(messages) do
        local op_code = message.op_code

        local decoded = nk.json_decode(message.data)

        -- Run boiler plate commands (state updates.)
        local command = commands[op_code]
        if command ~= nil then
            commands[op_code](decoded, state)
        end

        -- A client has selected a character and is spawning. Get or generate position data,
        -- send them initial state, and broadcast their spawning to existing clients.
        if op_code == OpCodes.do_spawn then
            local object_ids = {
                {
                    collection = "player_data",
                    key = "position_" .. decoded.nm,
                    user_id = message.sender.user_id
                }
            }

            local objects = nk.storage_read(object_ids)

            local position
            for _, object in ipairs(objects) do
                position = object.value
                if position ~= nil then
                    state.positions[message.sender.user_id] = position
                    break
                end
            end

            if position == nil then
                state.positions[message.sender.user_id] = {
                    ["x"] = SPAWN_POSITION[1],
                    ["y"] = SPAWN_POSITION[2]
                }
            end

            state.names[message.sender.user_id] = decoded.nm

            local data = {
                ["pos"] = state.positions,
                ["inp"] = state.inputs,
                ["col"] = state.colors,
                ["nms"] = state.names
            }

            local encoded = nk.json_encode(data)
            dispatcher.broadcast_message(OpCodes.initial_state, encoded, {message.sender})

            dispatcher.broadcast_message(OpCodes.do_spawn, message.data)
        elseif op_code == OpCodes.update_color then
            dispatcher.broadcast_message(OpCodes.update_color, message.data)
        end
    end
    
    local data = {
        ["pos"] = state.positions,
        ["inp"] = state.inputs
    }
    local encoded = nk.json_encode(data)

    dispatcher.broadcast_message(OpCodes.update_state, encoded)

    for _, input in pairs(state.inputs) do
        input.jmp = 0
    end

    return state
end

function world.match_terminate(context, dispatcher, tick, state, grace_seconds)
    nk.logger_info("match_terminate ===========================")

    local new_objects = {}
    for k, position in pairs(state.positions) do
        table.insert(
            new_objects,
            {
                collection = "player_data",
                key = "position_" .. state.names[k],
                user_id = k,
                value = position
            }
        )
    end

    nk.storage_write(new_objects)

    return state
end

function world.match_signal(context, dispatcher, tick, state, data)
    nk.logger_info("match_signal ===========================")

    return state, "signal received: " .. data
end

return world