local mesecons_mvps_path = minetest.get_modpath("mesecons_mvps")

local rdis_boxes = {}

local file = io.open(minetest.get_modpath("rdis").."/rdis_boxes.txt", "r")
if file ~= nil then
	local list_string = file:read("*a")
	file:close()
	local list = list_string:split("\n")
	for _,v in ipairs(list) do
		local v = v:gsub(" = ", "=")
		local vt = v:split("=")
		local subname = string.lower(vt[1]:gsub(" ", "_"))

		minetest.register_node("rdis:box_"..subname, {
			description = "rdis box: "..vt[1],
			drawtype = "mesh",
			tiles = {vt[2]},
			paramtype = "light",
			paramtype2 = "facedir",
			mesh = "rdis_box.obj",
			collision_box = {
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
			groups = {rdis_box = 1, not_in_creative_inventory = 1},
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

		rdis_boxes[subname] = {"rdis:box_"..subname, vt[1], "[combine:22x30:-58,-32="..vt[2]}

		if mesecons_mvps_path then
			mesecon.register_mvps_stopper("rdis:box_"..subname)
		end
	end
else
	minetest.log("error", minetest.get_modpath("rdis").."/rdis_boxes.txt not found. mod [rdis] will not load")
	return
end

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

local good_box = function(box)
	for _,v in pairs(rdis_boxes) do
		if v[1] == box then
			return true
		end
	end
	return false
end

local random_box = function()
	local i = 0
	for _,_ in pairs(rdis_boxes) do
		i = i + 1
	end
	local x = math.random(i)
	i = 0
	for _,v in pairs(rdis_boxes) do
		i = i + 1
		if i == x then
			return v[1]
		end
	end
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
		local meta = minetest.get_meta(pos)
		local door = minetest.string_to_pos(meta:get_string("door"))
		local pos_string = minetest.pos_to_string(pos)
		if door then
			if meta:get_string("locked") ~= "false" and minetest.is_protected(pos, name) then
				minetest.chat_send_player(name, "Control panel is locked.")
			else
				minetest.show_formspec(name, "rdis:set_pos_s_"..pos_string,
						"background[0,0;0,0;rdis_control_panel_gui_bg.png;true]field[text;x,y,z:facedir    Enter \"help\" without quotes for more info.;]")
			end
		else
			if minetest.is_protected(pos, name) then
				minetest.chat_send_player(name, "Control panel is locked.")
			else
				minetest.show_formspec(name, "rdis:set_door_s_"..pos_string,
						"background[0,0;0,0;rdis_control_panel_gui_bg.png;true]field[text;place door at...;]")
			end
		end
	end,
	on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		local door = minetest.string_to_pos(meta:get_string("door"))
		local to_pos_string = meta:get_string("to_pos")
		local to_pos = minetest.string_to_pos(to_pos_string)
		if door then
			remove_tp(door)
		end
		if to_pos then
			remove_tp(to_pos)
			minetest.remove_node(to_pos)
			minetest.log("action", "destruction of \"rdis:control_panel\" at "..minetest.pos_to_string(pos).." dematerialized an rdis box at "..to_pos_string)
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

local materialize = function(name, pos, place_pos_string, place_pos, facedir, box)
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
			local old_to_pos_string = panel_meta:get_string("to_pos")
			local old_to_pos = minetest.string_to_pos(old_to_pos_string)
			if old_to_pos then
				remove_tp(old_to_pos)
				minetest.remove_node(old_to_pos)
				minetest.log("action", name.." dematerialized an rdis box at "..old_to_pos_string)
			end
			panel_meta:set_string("to_pos", place_pos_string)
			door_meta:set_string("to_pos", place_pos_string)
			minetest.set_node(place_pos, {name = box, param2 = facedir})
			local meta = minetest.get_meta(place_pos)
			meta:set_string("to_pos", door_string)
			add_tp(place_pos)
			minetest.log("action", name.." materialized an rdis box at "..place_pos_string)
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
				elseif fields_text[2] == "lock" then
					minetest.chat_send_player(name, "RDIS command \"lock\", lockes the control panel. \"Needs a protection field to work.\"")
				elseif fields_text[2] == "unlock" then
					minetest.chat_send_player(name, "RDIS command \"unlock\", unlockes the control panel.")
				elseif fields_text[2] == "skin" then
					minetest.chat_send_player(name, "RDIS command \"skin\", apply a theme to your box. usage: skin \"skin name\"")
				else
					minetest.chat_send_player(name, "Enter a position or use a command.\n"..
							"Position format is \"x,y,z:facedir\" without quotes.\n"..
							"Available commands are: close open bookmark delete list lock unlock skin\n"..
							"Use \"help \"command name\"\" to for more info on commands.")
				end
			elseif fields.text == "close" then
				local old_to_pos_string = panel_meta:get_string("to_pos")
				local old_to_pos = minetest.string_to_pos(old_to_pos_string)
				if old_to_pos then
					local door = minetest.string_to_pos(panel_meta:get_string("door"))
					local door_meta = minetest.get_meta(door)
					panel_meta:set_string("to_pos", "")
					door_meta:set_string("to_pos", "")
					remove_tp(old_to_pos)
					minetest.remove_node(old_to_pos)
					minetest.log("action", name.." dematerialized an rdis box at "..old_to_pos_string)
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
						local box = panel_meta:get_string("box")
						if not good_box(box) then
							box = random_box()
						end
						minetest.emerge_area(place_pos, {x = place_pos.x, y = place_pos.y + 1, z = place_pos.z})
						minetest.after(0.01, materialize, name, pos, place_pos_string, place_pos, facedir, box)
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
			elseif fields.text == "lock" then
				if minetest.is_protected(pos, name) then
					minetest.chat_send_player(name, "I don't want to lock my self out.")
				else
					panel_meta:set_string("locked", "true")
				end
			elseif fields.text == "unlock" then
				panel_meta:set_string("locked", "false")
			elseif fields_text[1] == "skin" then
				if not minetest.is_protected(pos, name) then
					if not fields_text[2] then
						minetest.chat_send_player(name, "Available skins are...")
						minetest.chat_send_player(name, "* none")
						for _,v in pairs(rdis_boxes) do
							minetest.chat_send_player(name, "* "..v[2])
						end
						return true
					else
						local skin = fields_text[2]
						if skin == "none" then
							panel_meta:set_string("box", "none")
							return true
						elseif fields_text[3] then
							for i = 3,#fields_text do
								skin = skin.." "..fields_text[i]
							end
						end
						local box = rdis_boxes[string.lower(skin:gsub(" ", "_"))]
						if box then
							panel_meta:set_string("box", box[1])
						else
							minetest.chat_send_player(name, "Skin not found")
						end
					end
				else
					minetest.chat_send_player(name, "I like it how it is.")
				end
			else
				local place_pos_string = fields.text:split(":")[1]
				local place_pos = minetest.string_to_pos(place_pos_string)
				local facedir = tonumber(fields.text:split(":")[2])
				if place_pos and facedir and facedir >= 0 and facedir <= 3 then
					if not minetest.is_protected(place_pos, name) and not minetest.is_protected({x = place_pos.x, y = place_pos.y + 1, z = place_pos.z}, name) then
						local box = panel_meta:get_string("box")
						if not good_box(box) then
							box = random_box()
						end
						minetest.emerge_area(place_pos, {x = place_pos.x, y = place_pos.y + 1, z = place_pos.z})
						minetest.after(0.01, materialize, name, pos, place_pos_string, place_pos, facedir, box)
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
	if minetest.get_item_group(node.name, "rdis_box") > 0 then
		local meta = minetest.get_meta(to_pos)
		face = node.param2
		to_face = meta:get_int("face")
	else
		local node = minetest.get_node(to_pos)
		face = meta:get_int("face")
		to_face = node.param2
	end
	local yaw_diff = 1.5708 * (to_face - face) + 4.7124
	for _,v in ipairs(objs) do
		if v:is_player() then
			local name = v:get_player_name()
			if not contains(on_hold, name) then
				table.insert(on_hold, name)
				v:setpos(to_pos)
				v:set_look_yaw(v:get_look_yaw() - yaw_diff)
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
		if node and minetest.get_item_group(node.name, "rdis_box") == 0 then
			minetest.remove_node(pos)
		end
	end
})

minetest.register_lbm({
	name = "rdis:index_boxes",
	nodenames = {"group:rdis_box"},
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

if mesecons_mvps_path then
	mesecon.register_mvps_stopper("rdis:control_panel")
	mesecon.register_mvps_stopper("rdis:stall_ghost")
end
