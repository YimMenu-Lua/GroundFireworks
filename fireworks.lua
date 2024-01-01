-- This script add fireworks like on old gen GTA Online.
-- The UI is in the lua scripts tab.

local firework_debug = false -- Enable debug logs.
local setting_up_firework
local current_firework = { object = 0, type = 0, r = 0, g = 0, b = 0 }

local fireworks = {} -- A table of all currently placed fireworks.

-- Turns out we can't just add a table to a table because that will just be a ptr to the original table.
-- This function should actually copy the table.
-- Source: http://lua-users.org/wiki/CopyTable
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function load_fireworks()
	STREAMING.REQUEST_ANIM_DICT("anim@mp_fireworks")

	STREAMING.REQUEST_MODEL(joaat("IND_PROP_FIREWORK_01"))
	STREAMING.REQUEST_MODEL(joaat("IND_PROP_FIREWORK_02"))
	STREAMING.REQUEST_MODEL(joaat("IND_PROP_FIREWORK_03"))
	STREAMING.REQUEST_MODEL(joaat("IND_PROP_FIREWORK_04"))

	STREAMING.REQUEST_NAMED_PTFX_ASSET("scr_indep_fireworks")
	
	if not STREAMING.HAS_ANIM_DICT_LOADED("anim@mp_fireworks") then
		return false
	end

	if not STREAMING.HAS_MODEL_LOADED(joaat("IND_PROP_FIREWORK_01")) then
		return false
	end
	if not STREAMING.HAS_MODEL_LOADED(joaat("IND_PROP_FIREWORK_02")) then
		return false
	end
	if not STREAMING.HAS_MODEL_LOADED(joaat("IND_PROP_FIREWORK_03")) then
		return false
	end
	if not STREAMING.HAS_MODEL_LOADED(joaat("IND_PROP_FIREWORK_04")) then
		return false
	end

	if not STREAMING.HAS_NAMED_PTFX_ASSET_LOADED("scr_indep_fireworks") then
		return false
	end

	return true
end

function get_firework_model_from_type(type)
	if type == 0 then
		return joaat("IND_PROP_FIREWORK_04")
	elseif type == 1 then
		return joaat("IND_PROP_FIREWORK_02")
	elseif type == 2 then
		return joaat("IND_PROP_FIREWORK_03")
	elseif type == 3 then
		return joaat("IND_PROP_FIREWORK_01")
	end
	
	return joaat("IND_PROP_FIREWORK_01")
end

function get_firework_anim_from_type(type)
	if type == 0 then
		return "PLACE_FIREWORK_4_CONE"
	elseif type == 1 then
		return "PLACE_FIREWORK_3_BOX"
	elseif type == 2 then
		return "PLACE_FIREWORK_2_CYLINDER"
	elseif type == 3 then
		return "PLACE_FIREWORK_1_ROCKET"
	end
	
	return "PLACE_FIREWORK_1_ROCKET"
end

function get_firework_ptfx_from_type(type)
	if type == 0 then
		return "scr_indep_firework_fountain"
	elseif type == 1 then
		return "scr_indep_firework_shotburst"
	elseif type == 2 then
		return "scr_indep_firework_starburst"
	elseif type == 3 then
		return "scr_indep_firework_trailburst"
	end

	return "scr_indep_firework_fountain"
end

function get_firework_name_from_type(type)
	if type == 0 then
		return "Cone"
	elseif type == 1 then
		return "Cylinder"
	elseif type == 2 then
		return "Box"
	elseif type == 3 then
		return "Rocket"
	end

	return "Invalid"
end

function place_firework_anim(type)
	if firework_debug then
		log.debug("Playing placement anim")
	end
	setting_up_firework = true

	if not ENTITY.IS_ENTITY_PLAYING_ANIM(PLAYER.PLAYER_PED_ID(), "anim@mp_fireworks", get_firework_anim_from_type(type), 3) then
		TASK.TASK_PLAY_ANIM(PLAYER.PLAYER_PED_ID(), "anim@mp_fireworks", get_firework_anim_from_type(type), 8.0, -8.0, -1, 1048576, 0, false, false, false)
	end
end

function fire_firework(firework)
	if firework_debug then
		log.debug("Firing firework: " .. firework.object .. " Type: " .. firework.type)
	end
	if firework.object == 0 or not ENTITY.DOES_ENTITY_EXIST(firework.object) then
		if firework_debug then
			log.debug("Firework: " .. firework.object .. " Does not exist so it will never be deleted!")
		end
		gui.show_error("Firework", "Error firework " .. firework.object .. " so it will never be deleted!")
		table.remove(fireworks, firework) -- This is bad this firework will never be deleted now.
		return
	end

	local firework_coords = ENTITY.GET_ENTITY_COORDS(firework.object, true)
	GRAPHICS.USE_PARTICLE_FX_ASSET("scr_indep_fireworks")
	GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR(firework.r, firework.g, firework.b)
	GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD(get_firework_ptfx_from_type(firework.type), firework_coords.x, firework_coords.y, firework_coords.z, 0,0,0, 1, false, false, false, false)

	-- Let the player mess around with the used firework
	ENTITY.SET_ENTITY_COLLISION(firework.object, true, true)
	ENTITY.FREEZE_ENTITY_POSITION(firework.object, false)
	ENTITY.SET_ENTITY_DYNAMIC(firework.object, true)

	-- If it's a rocket launch it.
	if firework.type == 3 then
		ENTITY.SET_ENTITY_VELOCITY(firework.object, 0,0,70)
	end

	delete_firework(firework, false)
end

function delete_firework(firework, delete)
	if ENTITY.DOES_ENTITY_EXIST(firework.object) then
		if delete then
			OBJECT.DELETE_OBJECT(firework.object)
		else
			ENTITY.SET_ENTITY_AS_NO_LONGER_NEEDED(firework.object)
		end
	end
	table.remove(fireworks, k)
end


-- Load all the firework stuff when the script starts.
-- There is currently no way to unload it, because there is no way to hook script unloading.
script.run_in_fiber(function()
	load_fireworks()
end)

script.register_looped("update_fireworks", function(script)
	if setting_up_firework then
		-- Create firework prop
		if ENTITY.HAS_ANIM_EVENT_FIRED(PLAYER.PLAYER_PED_ID(), joaat("CREATE_PROP")) then
			local player_coords = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), true)
			current_firework.object = OBJECT.CREATE_OBJECT(get_firework_model_from_type(current_firework.type), player_coords.x,player_coords.y,player_coords.z, true, false, false)
			ENTITY.SET_ENTITY_INVINCIBLE(current_firework.object, true)
			ENTITY.ATTACH_ENTITY_TO_ENTITY(current_firework.object, PLAYER.PLAYER_PED_ID(), PED.GET_PED_BONE_INDEX(PLAYER.PLAYER_PED_ID(), 28422), 0,0,0, 0,0,0, true, true, false, false, 0, true, 0)
			table.insert(fireworks, shallowcopy(current_firework))
			if firework_debug then
				log.debug("Created firework object: " .. current_firework.object)
			end
		end

		-- Detach firework prop
		if ENTITY.HAS_ANIM_EVENT_FIRED(PLAYER.PLAYER_PED_ID(), joaat("RELEASE_PROP")) then
			if ENTITY.DOES_ENTITY_EXIST(current_firework.object) then 
				ENTITY.DETACH_ENTITY(current_firework.object, false, false)
				ENTITY.FREEZE_ENTITY_POSITION(current_firework.object, true)
				ENTITY.SET_ENTITY_COLLISION(current_firework.object, false, false)
			end

			setting_up_firework = false

			if firework_debug then
				log.debug("Detached firework object: " .. current_firework.object)
			end
		end

		if PED.IS_PED_RAGDOLL(PLAYER.PLAYER_PED_ID())
		or PED.IS_PED_RUNNING_RAGDOLL_TASK(PLAYER.PLAYER_PED_ID())
		or PED.IS_PED_DEAD_OR_DYING(PLAYER.PLAYER_PED_ID(), false)
		or PED.IS_PED_IN_MELEE_COMBAT(PLAYER.PLAYER_PED_ID())
			then
				delete_firework(current_firework, true)
			end
		end
end)

local lua_tab = gui.get_tab("GUI_TAB_LUA_SCRIPTS")
local type_input
local color_input_r
local color_input_g
local color_input_b
lua_tab:add_separator()
lua_tab:add_text("Fireworks\nSupported types are:\n0 - Fountain\n1 - Shotburst\n2 - Starburst\n3 - Trailburst")
lua_tab:add_button("Place Firework", function()
	current_firework.type = type_input:get_value()
	current_firework.r = color_input_r:get_value()
	current_firework.g = color_input_g:get_value()
	current_firework.b = color_input_b:get_value()
	
	script.run_in_fiber(function()
		if(load_fireworks()) then
			place_firework_anim(current_firework.type)
		end
	end)
end)
type_input = lua_tab:add_input_int("Firework type")
color_input_r = lua_tab:add_input_float("Color R")
color_input_g = lua_tab:add_input_float("Color G")
color_input_b = lua_tab:add_input_float("Color B")

lua_tab:add_imgui(function()
	ImGui.Text("Currently Spawned: " .. #fireworks)
	if ImGui.Button("Fire All") then
		for k,v in ipairs(fireworks) do -- For some reason i can't put the for loop inside the fiber pool or it won't fire all fireworks.
			script.run_in_fiber(function()
				fire_firework(v)
			end)
		end
	end

	if #fireworks > 0 then
		ImGui.Separator()
	end

	for k,v in ipairs(fireworks) do
		if ImGui.Button("Fire Firework - " .. k .. " (" .. get_firework_name_from_type(v.type) .. ")") then
			script.run_in_fiber(function()
				fire_firework(v)
			end)
		end
	end
end)
