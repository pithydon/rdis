local tplist = {}

local on_hold = {}

local add_tp = function(pos)
	local pos_string = minetest.pos_to_string(pos)
	for _,v in ipairs(tplist) do
		local v_string = minetest.pos_to_string(v)
		if pos_string == v_string then
			return
		end
	end
	table.insert(tplist, pos)
end

local remove_tp = function(pos)
	local pos_string = minetest.pos_to_string(pos)
	for i,v in ipairs(tplist) do
		local v_string = minetest.pos_to_string(v)
		if pos_string == v_string then
			table.remove(tplist, i)
		end
	end
end

local remove_name = function(name)
	for i,v in ipairs(on_hold) do
		if v == name then
			table.remove(on_hold, i)
		end
	end
end

local contains = function(t, e)
	for _,v in pairs(t) do
		if v == e then
			return true
		end
	end
	return false
end

minetest.register_node("rdis:control_panel", {
	description = "RDIS Control Panel",
	drawtype = "nodebox",
	tiles = {"rdis_control_panel_top.png", "rdis_control_panel_side.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.25, -0.5, 0.5, 0.5, 0.5},
			{-0.375, -0.5, -0.375, 0.375, 0.25, 0.375}
		}
	},
	groups = {cracky = 1, level = 1},
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local name = clicker:get_player_name()
		if minetest.is_protected(pos, name) then
			minetest.chat_send_player(name, "Control panel is locked.")
		else
			local meta = minetest.get_meta(pos)
			local door = minetest.string_to_pos(meta:get_string("door"))
			local pos_string = minetest.pos_to_string(pos)
			if door then
				minetest.show_formspec(name, "rdis:set_pos_s_"..pos_string, "field[text;x,y,z:facedir    Enter \"help\" without quotes for more info.;]")
			else
				minetest.show_formspec(name, "rdis:set_door_s_"..pos_string, "field[text;place door at;]")
			end
		end
	end,
	on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		local door = minetest.string_to_pos(meta:get_string("door"))
		local to_pos = minetest.string_to_pos(meta:get_string("to_pos"))
		if door then
			remove_tp(door)
		end
		if to_pos then
			remove_tp(to_pos)
			minetest.remove_node(to_pos)
		end
	end
})

minetest.register_craft({
	output = "rdis:control_panel",
	recipe = {
		{"default:steelblock", "default:diamondblock", "default:steelblock"},
		{"default:steelblock", "default:mese", "default:steelblock"},
		{"farming:seed_wheat", "farming:seed_wheat", "farming:seed_wheat"}
	}
})

local materialize = function(name, pos, place_pos_string, place_pos, facedir)
	local old_node = minetest.get_node_or_nil(place_pos)
	local under_node = minetest.get_node_or_nil({x = place_pos.x, y = place_pos.y + 1, z = place_pos.z})
	if old_node and under_node then
		local old_node_def = minetest.registered_nodes[old_node.name]
		local under_node_def = minetest.registered_nodes[under_node.name]
		if old_node_def.buildable_to and under_node_def.buildable_to then
			local panel_meta = minetest.get_meta(pos)
			local door_string = panel_meta:get_string("door")
			local door = minetest.string_to_pos(door_string)
			local door_meta = minetest.get_meta(door)
			local old_to_pos = minetest.string_to_pos(panel_meta:get_string("to_pos"))
			if old_to_pos then
				remove_tp(old_to_pos)
				minetest.remove_node(old_to_pos)
			end
			panel_meta:set_string("to_pos", place_pos_string)
			door_meta:set_string("to_pos", place_pos_string)
			minetest.set_node(place_pos, {name = "rdis:stall", param2 = facedir})
			local meta = minetest.get_meta(place_pos)
			meta:set_string("to_pos", door_string)
			add_tp(place_pos)
		else
			minetest.chat_send_player(name, "Could not materialize at "..place_pos_string..".")
		end
	else
		minetest.chat_send_player(name, "Could not materialize at "..place_pos_string..".")
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:split(":")[1] == "rdis" then
		if not fields.text then
			return true
		end
		local name = player:get_player_name()
		local pos = minetest.string_to_pos(formname:split("_s_")[2])
		if formname:split("_s_")[1] == "rdis:set_door" then
			local field_pos = minetest.string_to_pos(fields.text)
			if field_pos then
				if vector.distance(pos, field_pos) > 16 then
					minetest.chat_send_player(name, "Can not place door more than 16 blocks away.")
				else
					local dir = vector.direction(pos, field_pos)
					local facedir = minetest.dir_to_facedir(dir)
					local meta = minetest.get_meta(pos)
					local door_meta = minetest.get_meta(field_pos)
					meta:set_string("door", fields.text)
					meta:set_int("face", facedir)
					door_meta:set_int("face", facedir)
					add_tp(field_pos)
				end
			end
		else
			local panel_meta = minetest.get_meta(pos)
			local fields_text = fields.text:split(" ")
			if fields_text[1] == "help" then
				if fields_text[2] == "close" then
					minetest.chat_send_player(name, "RDIS command \"close\", closes the portal.")
				elseif fields_text[2] == "open" then
					minetest.chat_send_player(name, "RDIS command \"open\", opens a bookmark. usage: open \"bookmark name\"")
				elseif fields_text[2] == "bookmark" then
					minetest.chat_send_player(name, "RDIS command \"bookmark\", bookmarks a position. usage: bookmark \"bookmark name\" \"position\"")
				elseif fields_text[2] == "delete" then
					minetest.chat_send_player(name, "RDIS command \"delete\", deletes a bookmark. usage: delete \"bookmark name\"")
				elseif fields_text[2] == "list" then
					minetest.chat_send_player(name, "RDIS command \"list\", lists all bookmarks.")
				else
					minetest.chat_send_player(name, "Enter a position or use a command.\n"..
							"Position format is \"x,y,z:facedir\" without quotes.\n"..
							"Available commands are: close open bookmark delete list.\n"..
							"Use \"help \"command name\"\" to for more info on commands.")
				end
			elseif fields.text == "close" then
				local old_to_pos = minetest.string_to_pos(panel_meta:get_string("to_pos"))
				if old_to_pos then
					local door = minetest.string_to_pos(panel_meta:get_string("door"))
					local door_meta = minetest.get_meta(door)
					panel_meta:set_string("to_pos", "")
					door_meta:set_string("to_pos", "")
					remove_tp(old_to_pos)
					minetest.remove_node(old_to_pos)
				end
			elseif fields_text[1] == "open" then
				if not fields_text[2] then
					minetest.chat_send_player(name, "Can NOT open null.")
					return true
				end
				local bookmark = panel_meta:get_string("bookmark_"..fields_text[2])
				local place_pos_string = bookmark:split(":")[1]
				local place_pos = minetest.string_to_pos(place_pos_string)
				local facedir = tonumber(bookmark:split(":")[2])
				if place_pos and facedir and facedir >= 0 and facedir <= 3 then
					if not minetest.is_protected(place_pos, name) and not minetest.is_protected({x = place_pos.x, y = place_pos.y + 1, z = place_pos.z}, name) then
						minetest.emerge_area(place_pos, {x = place_pos.x, y = place_pos.y + 1, z = place_pos.z})
						minetest.after(0.01, materialize, name, pos, place_pos_string, place_pos, facedir)
					else
						minetest.chat_send_player(name, "Could not materialize at "..place_pos_string..". Protection field found.")
					end
				else
					minetest.chat_send_player(name, "Bookmark not found.")
				end
			elseif fields_text[1] == "bookmark" then
				if not fields_text[2] then
					minetest.chat_send_player(name, "Bookmarked null island.")
					return true
				elseif not fields_text[3] then
					minetest.chat_send_player(name, "Bookmarked null island as "..fields_text[2]..".")
					return true
				end
				panel_meta:set_string("bookmark_"..fields_text[2], fields_text[3])
			elseif fields_text[1] == "delete" then
				if not fields_text[2] then
					minetest.chat_send_player(name, "Deleted null island.")
					return true
				end
				panel_meta:set_string("bookmark_"..fields_text[2], "")
			elseif fields_text[1] == "list" then
				local meta_table = panel_meta:to_table()
				local bookmarks_table = {}
				for k,v in pairs(meta_table.fields) do
					if k:split("_")[1] == "bookmark" then
						table.insert(bookmarks_table, k:split("_")[2])
					end
				end
				local bookmarks = "RDIS bookmarks:"
				for _,v in ipairs(bookmarks_table) do
					bookmarks = bookmarks.." "..v
				end
				minetest.chat_send_player(name, bookmarks)
			else
				local place_pos_string = fields.text:split(":")[1]
				local place_pos = minetest.string_to_pos(place_pos_string)
				local facedir = tonumber(fields.text:split(":")[2])
				if place_pos and facedir and facedir >= 0 and facedir <= 3 then
					if not minetest.is_protected(place_pos, name) and not minetest.is_protected({x = place_pos.x, y = place_pos.y + 1, z = place_pos.z}, name) then
						minetest.emerge_area(place_pos, {x = place_pos.x, y = place_pos.y + 1, z = place_pos.z})
						minetest.after(0.01, materialize, name, pos, place_pos_string, place_pos, facedir)
					else
						minetest.chat_send_player(name, "Could not materialize at "..place_pos_string..". Protection field found.")
					end
				else
					minetest.chat_send_player(name, "RDIS format error.")
				end
			end
		end
		return true
	else
		return false
	end
end)

minetest.register_node("rdis:stall", {
	description = "Honey Bucket",
	drawtype = "nodebox",
	tiles = {"default_wood.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
			{-0.5, 1.4375, -0.5, 0.5, 1.5, 0.5},
			{-0.5, -0.4375, 0.4375, 0.5, 1.4375, 0.5},
			{-0.5, -0.4375, -0.5, -0.4375, 1.4375, 0.4375},
			{0.4375, -0.4375, -0.5, 0.5, 1.4375, 0.4375}
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 1.5, 0.5}
	},
	groups = {not_in_creative_inventory = 1},
	diggable = false,
	on_construct = function(pos)
		minetest.swap_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "rdis:stall_ghost"})
	end,
	on_destruct = function(pos)
		minetest.remove_node({x = pos.x, y = pos.y + 1, z = pos.z})
	end,
	on_blast = function(pos, intensity)
	end
})

minetest.register_node("rdis:stall_ghost", {
	description = "This is not an easter egg.",
	walkable = true,
	drawtype = "nodebox",
	tiles = {"blank.png"},
	inventory_image = "unknown_node.png",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5}
	},
	groups = {not_in_creative_inventory = 1},
	pointable = false,
	diggable = false,
	on_blast = function(pos, intensity)
	end
})

local globalstep_next = function(v, meta, objs, to_pos)
	local node = minetest.get_node(v)
	local face
	local to_face
	if node.name == "rdis:stall" then
		local meta = minetest.get_meta(to_pos)
		face = node.param2
		to_face = meta:get_int("face")
	else
		local node = minetest.get_node(to_pos)
		face = meta:get_int("face")
		to_face = node.param2
	end
	local yaw_diff = 0 - ((1.5708 * to_face) - (1.5708 * face)) - 4.7124
	for _,v in ipairs(objs) do
		if v:is_player() then
			local name = v:get_player_name()
			if not contains(on_hold, name) then
				local yaw = v:get_look_yaw()
				table.insert(on_hold, name)
				v:setpos(to_pos)
				v:set_look_yaw(yaw + yaw_diff)
				minetest.after(1.3, remove_name, name)
			end
		end
	end
end

minetest.register_globalstep(function(dtime)
	for _,v in ipairs(tplist) do
		local meta = minetest.get_meta(v)
		local to_pos = minetest.string_to_pos(meta:get_string("to_pos"))
		if to_pos then
			local objs = minetest.get_objects_inside_radius(v, 0.7)
			if objs[1] then
				minetest.emerge_area(to_pos, to_pos)
				minetest.after(0.1, globalstep_next, v, meta, objs, to_pos)
			end
		end
	end
end)

minetest.register_lbm({
	name = "rdis:index_panels",
	nodenames = {"rdis:control_panel"},
	run_at_every_load = true,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		local to_pos_string = meta:get_string("to_pos")
		local to_pos = minetest.string_to_pos(to_pos_string)
		local door = minetest.string_to_pos(meta:get_string("door"))
		if door then
			local facedir = meta:get_int("face")
			local door_meta = minetest.get_meta(door)
			door_meta:set_string("to_pos", to_pos_string)
			door_meta:set_int("face", facedir)
			add_tp(door)
		end
	end
})

minetest.register_lbm({
	name = "rdis:remove_old_ghosts",
	nodenames = {"rdis:stall_ghost"},
	run_at_every_load = true,
	action = function(pos)
		local node = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if node and node.name ~= "rdis:stall" then
			minetest.remove_node(pos)
		end
	end
})

minetest.register_lbm({
	name = "rdis:index_chameleon",
	nodenames = {"rdis:stall"},
	run_at_every_load = true,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		local to_pos = minetest.string_to_pos(meta:get_string("to_pos"))
		if to_pos then
			add_tp(pos)
		else
			minetest.remove_node(pos)
		end
	end
})

if (minetest.get_modpath("mesecons_mvps")) then
	mesecon.register_mvps_stopper("rdis:control_panel")
	mesecon.register_mvps_stopper("rdis:stall")
	mesecon.register_mvps_stopper("rdis:stall_ghost")
end
