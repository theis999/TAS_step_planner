require("util")

local localised_entity_names_en = require "src.entities"
local localised_item_names_en = require "src.items"
local localised_recipe_names_en = require "src.recipes"
local localised_technology_names_en = require "src.technologies"

local prefix = "tas_step_planner_"
local gui_width = settings.startup[prefix.."gui-width"].value

-- constants
local start_recording_text = {"", {"tas_helper.record"}, "[img=tas_helper_record]"}
local stop_recording_text = {"", {"tas_helper.pause"}, "[img=utility/pause]"}
local ezr_build_orientation_names = {
    [defines.direction.north] = "North",
    [defines.direction.east] = "East",
    [defines.direction.south] = "South",
    [defines.direction.west] = "West",
}
-- chest list is necessary because EZR doesn't recognise the ship wreckage as a 'chest' so they need to be
-- handled separately
local chest_list = {
    ["wooden-chest"] = 1,
    ["iron-chest"] = 1,
    ["steel-chest"] = 1,
    ["logistic-chest-active-provider"] = 1,
    ["logistic-chest-passive-provider"] = 1,
    ["logistic-chest-storage"] = 1,
    ["logistic-chest-buffer"] = 1,
    ["logistic-chest-requester"] = 1,
}

local function position_to_string(position)
    -- round to 2 decimal places
    local x = tonumber(string.format("%.2f", position.x))
    local y = tonumber(string.format("%.2f", position.y))
    return "[font=default-bold][" .. x .. ", " .. y .. "][/font]"
end

local function entity_to_string(entity)
    return "[entity=" .. entity.name .. "] " .. position_to_string(entity.position)
end

local function get_filter_slots(entity)
    -- entity is a filter inserter
    local slots = {}
    for i = 1, entity.filter_slot_count do
        slots[i] = entity.get_filter(i)
    end
    return slots
end

local function build_gui()
    -- build the mod gui for the player
    local player = game.get_player(1)
    if not player then return end
    local screen = player.gui.screen

    -- references to 'LuaGuiElement's
    global.elements = {}

    local main_frame = screen.add{ type = "frame", caption = {"tas_helper.title"}, direction = "horizontal", }
    global.elements.main_frame = main_frame
    main_frame.location = {settings.global.tas_step_planner_x.value, settings.global.tas_step_planner_y.value}
    main_frame.style.width = gui_width
    
    -- start with GUI visible and shortcut toggled on / or not
    local open = settings.global.tas_step_planner_open.value
    player.set_shortcut_toggled("tas_helper_toggle_gui", open)
    main_frame.visible = open

    local actions_listbox = main_frame.add{ type = "list-box", }
    actions_listbox.style.width = gui_width - 135
    actions_listbox.style.minimal_height = 140
    actions_listbox.style.maximal_height = 560
    global.elements.actions_listbox = actions_listbox

    local buttons_flow = main_frame.add{ type = "flow", direction = "vertical" }
    global.elements.buttons_flow = buttons_flow

    buttons_flow.add{ type = "button", name = "start_stop_recording_button", caption = start_recording_text, tooltip = {"tas_helper.record_tooltip"}, }
    global.recording = false
    buttons_flow.add{ type = "line" }
    buttons_flow.add{ type = "button", name = "prev_button", caption = {"tas_helper.previous"}, tooltip = {"tas_helper.previous_tooltip"}, }
    buttons_flow.add{ type = "button", name = "next_button", caption = {"tas_helper.next"}, tooltip = {"tas_helper.next_tooltip"}, }
    buttons_flow.add{ type = "button", name = "move_up_button", caption = {"tas_helper.move_up"}, tooltip = {"tas_helper.move_up_tooltip"}, }
    buttons_flow.add{ type = "button", name = "move_down_button", caption = {"tas_helper.move_down"}, tooltip = {"tas_helper.move_down_tooltip"}, }
    buttons_flow.add{ type = "button", name = "delete_button", style = "red_button", caption = {"tas_helper.delete"}, tooltip = {"tas_helper.delete_tooltip"}, }
    buttons_flow.add{ type = "line" }
    buttons_flow.add{ type = "button", name = "add_walk_action_button", caption = {"tas_helper.add_walk_action"}, tooltip = {"tas_helper.add_walk_action_tooltip"} }
    buttons_flow.add{ type = "line" }
    buttons_flow.add{ type = "button", name = "export_ezr_button", caption = {"tas_helper.export_ezr"}, tooltip = {"tas_helper.export_ezr_tooltip"}, }
    buttons_flow.add{ type = "line" }
    buttons_flow.add{ type = "button", name = "settings_button", caption = {"tas_helper.settings"}, }

    -- add title bar (from raiguard's style guide)
    local function add_title_bar(frame, title)
        local title_bar = frame.add{ type = "flow", direction = "horizontal", name = "title_bar", }
        title_bar.drag_target = frame
        title_bar.add{ type = "label", style = "frame_title", caption = title, ignored_by_interaction = true, }
        title_bar.add{ type = "empty-widget", style = "tas_helper_title_bar_draggable_space", ignored_by_interaction = true, }
        local frame_close_button = title_bar.add{ type = "sprite-button", style = "frame_action_button", sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black", }
        return frame_close_button
    end

    local export_frame = screen.add{ type = "frame", direction = "vertical", visible = false, }
    global.elements.export_frame = export_frame
    export_frame.force_auto_center()

    global.elements.export_frame_close_button = add_title_bar(export_frame, {"tas_helper.export_to_ezr_title"})

    local export_task_list_label = export_frame.add{ type = "label", style = "caption_label", caption = {"tas_helper.export_task_list_label"}, tooltip = {"tas_helper.export_task_list_label_tooltip"}, }
    export_task_list_label.style.top_margin = 6

    local export_textbox = export_frame.add{ type = "text-box", style = "tas_helper_export_textbox", }
    global.elements.export_textbox = export_textbox
    export_textbox.read_only = true

    local export_buttons_flow = export_frame.add{ type = "flow", name = "buttons", }
    export_buttons_flow.style.horizontally_stretchable = true
    export_buttons_flow.add{ type = "button", style = "dialog_button", caption = {"tas_helper.export_select_all"}, name = "select_all_button", }
    local export_buttons_flow_filler = export_buttons_flow.add{ type = "empty-widget", }
    export_buttons_flow_filler.style.horizontally_stretchable = true
    export_buttons_flow.add{ type = "button", style = "dialog_button", caption = {"tas_helper.export_ok"}, name = "ok", }

    -- add settings frame
    do
        local frame = screen.add{ type = "frame", direction = "vertical", visible = false, }
        global.elements.settings_frame = frame
        frame.force_auto_center()

        local prefix = "tas_step_planner_action_"
        local function setting(name)
            return settings.global[prefix..name].value
        end
        
        global.elements.settings_frame_close_button = add_title_bar(frame, "Settings")

        -- emulating style = "blueprint_settings_frame" with no minimal_width
        local inside_shallow_frame = frame.add{ type = "frame", style = "inside_shallow_frame", direction = "vertical", }
        inside_shallow_frame.style.top_padding = 6
        inside_shallow_frame.style.bottom_padding = 6
        local settings = inside_shallow_frame.add{ type = "frame", style = "bordered_frame_with_extra_side_margins", direction = "vertical", }
        settings.style.horizontally_stretchable = true
        settings.style.minimal_width = 250
        global.elements.settings = settings
        settings.add{ type = "label", style = "caption_label", caption = "Action types to capture", }
        settings.add{ type = "checkbox", caption = "Walk", state = setting("walk"), name = "capture_walk" }
        settings.add{ type = "checkbox", caption = "Build", state = setting("build"), name = "capture_build" }
        settings.add{ type = "checkbox", caption = "Rotate", state = setting("rotate"), name = "capture_rotate" }
        settings.add{ type = "checkbox", caption = "Craft", state = setting("craft"), name = "capture_craft" }
        settings.add{ type = "checkbox", caption = "Put", state = setting("put"), name = "capture_put" }
        settings.add{ type = "checkbox", caption = "Take", state = setting("take"), name = "capture_take" }
        settings.add{ type = "checkbox", caption = "Mine", state = setting("mine"), name = "capture_mine" }
        settings.add{ type = "checkbox", caption = "Limit", state = setting("limit"), name = "capture_limit" }
        settings.add{ type = "checkbox", caption = "Set recipe", state = setting("recipe"), name = "capture_recipe" }
        settings.add{ type = "checkbox", caption = "Set priority", state = setting("priority"), name = "capture_splitter" }
        settings.add{ type = "checkbox", caption = "Set filter", state = setting("filter"), name = "capture_filter_inserter" }
        settings.add{ type = "checkbox", caption = "Research technology", state = setting("research"), name = "capture_research" }

        settings.add{ type = "line" }
        settings.add{ type = "checkbox", caption = "Auto-build ghost", state = true, name = "capture_ghost" }

        --change prefix
        prefix = "tas_step_planner_other_"

        settings.add{ type = "line" }
        settings.add{ type = "label", style = "caption_label", caption = "Other settings", }
        settings.add{ type = "checkbox", caption = "Always add action to end of list [img=info]", tooltip = "If this is unchecked, actions will be added after the currently selected action.", state = setting("always_add_to_end"), name = "always_add_to_end" }
        settings.add{ type = "flow", direction = "horizontal", name = "always_put_amount", }
        settings.always_put_amount.add{ type = "checkbox", caption = "Always put amount [img=info]: ", tooltip = "Always record this amount for 'Put' actions.\nSet to 0 for 'Put all'.", state = setting("always_put_amount_bool"), name = "checkbox" }
        settings.always_put_amount.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.always_put_amount.add{ type = "textfield", style = "very_short_number_textfield", text = setting("always_put_amount_value"), numeric = true, name = "textfield", }
        settings.always_put_amount.textfield.style.horizontal_align = "right"
        settings.add{ type = "flow", direction = "horizontal", name = "always_take_amount", }
        settings.always_take_amount.add{ type = "checkbox", caption = "Always take amount [img=info]: ", tooltip = "Always record this amount for 'Take' actions.\nSet to 0 for 'Take all'.", state = setting("always_take_amount_bool"), name = "checkbox" }
        settings.always_take_amount.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.always_take_amount.add{ type = "textfield", style = "very_short_number_textfield", text = setting("always_take_amount_value"), numeric = true, name = "textfield", }
        settings.always_take_amount.textfield.style.horizontal_align = "right"
        settings.add{ type = "checkbox", caption = "Combine related actions [img=info]", tooltip = "When adding an action, merge it with the previous action if possible.\nFor example, crafting the same item twice will be merged and mining then building belt (which happens automatically when belt dragging and rotating) will be merged.", state = setting("combine_actions"), name = "combine_actions", }

        settings.add{ type = "flow", direction = "horizontal", name = "max_build_size", }
        settings.max_build_size.add{ type = "label", caption = "Max build size [img=info]: ", tooltip = "The size in tiles, used for multibuild", name = "label" }
        settings.max_build_size.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.max_build_size.add{ type = "textfield", style = "very_short_number_textfield", text = setting("max_build_size"), numeric = true, name = "textfield", }
        settings.max_build_size.textfield.style.horizontal_align = "right"

        settings.add{ type = "flow", direction = "horizontal", name = "color_export", }
        settings.color_export.add{ type = "label", caption = "Export colour [img=info]: ", tooltip = "Export colour of steps. Acceptable formats are [<name:Red>, <rgb:rgb(255,0,132)> or <hex:#00ffa1>]", state = true, name = "label" }
        settings.color_export.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.color_export.add{ type = "textfield", style = "tas_helper_color_textfield", text = setting("color_export"), numeric = false, name = "textfield", }
        settings.color_export.textfield.style.horizontal_align = "right"
    end

    global.action_types = {
        walk = global.elements.settings.capture_walk,
        build = global.elements.settings.capture_build,
        rotate = global.elements.settings.capture_rotate,
        craft = global.elements.settings.capture_craft,
        put = global.elements.settings.capture_put,
        take = global.elements.settings.capture_take,
        mine = global.elements.settings.capture_mine,
        limit = global.elements.settings.capture_limit,
        recipe = global.elements.settings.capture_recipe,
        priority = global.elements.settings.capture_splitter,
        filter = global.elements.settings.capture_filter_inserter,
        research = global.elements.settings.capture_research,
    }
    global.other_types = {
        capture_ghost = global.elements.settings.capture_ghost,
        always_add_to_end = global.elements.settings.always_add_to_end,
        always_put_amount_bool = global.elements.settings.always_put_amount.checkbox,
        always_put_amount_value = global.elements.settings.always_put_amount.textfield,
        always_take_amount_bool = global.elements.settings.always_take_amount.checkbox,
        always_take_amount_value = global.elements.settings.always_take_amount.textfield,
        combine_actions = global.elements.settings.combine_actions,
        max_build_size = global.elements.settings.max_build_size.textfield,
        color_export = global.elements.settings.color_export.textfield,
    }
end

local function update_highlight_box()
    if global.current_highlight_box then
        global.current_highlight_box.destroy()
    end

    local index = global.elements.actions_listbox.selected_index
    if index > 0 then
        local action = global.actions[index]
        if action.highlight_box_bounds then
            local surface = game.get_surface(1)
            local highlight_box = surface and surface.create_entity{
                name = "highlight-box",
                position = {0, 0}, -- ignored
                bounding_box = action.highlight_box_bounds,
            } or nil
            global.current_highlight_box = highlight_box
        end
    end
end

local function ezr_action_to_string(action)
    local function make_string(info)
        local x = info.position and string.format("%.6f", info.position.x) or ""
        local y = info.position and string.format("%.6f", info.position.y) or ""
        local units = info.units and (tonumber(info.units) and string.format("%.6f", info.units) or info.units) or ""
        local size = info.size and string.format("%d", info.size) or ""
        local amount = info.amount and string.format("%d", info.amount) or ""
        local colour = global.elements.settings.color_export.textfield.text or ""
        return string.format("%s;%s;%s;%s;%s;%s;%s;%s;%s;;%s;", info.task, x, y, units, info.item or "", info.orientation or "", info.direction or "", size, amount, colour)
    end

    if action.type == "put" then
        return make_string{
            task = "Put",
            position = action.position,
            units = action.count == 0 and "All" or action.count,
            item = localised_item_names_en[action.item_name],
            orientation = action.inventory,
            direction = ezr_build_orientation_names[action.direction or defines.direction.north],
            size = action.size or 1,
            amount = action.amount or 1,
        }
    elseif action.type == "take" then
        return make_string{
            task = "Take",
            position = action.position,
            units = action.count == 0 and "All" or action.count,
            item = localised_item_names_en[action.item_name],
            orientation = action.inventory,
            direction = ezr_build_orientation_names[action.direction or defines.direction.north],
            size = action.size or 1,
            amount = action.amount or 1,
        }
    elseif action.type == "build" then
        return make_string{
            task = "Build",
            position = action.position,
            item = localised_entity_names_en[action.entity_name],
            -- EZR always expects a direction even if the entity doesn't support direction.
            -- It uses north by default
            orientation = ezr_build_orientation_names[action.orientation or defines.direction.north],
            direction = ezr_build_orientation_names[action.direction or defines.direction.north],
            size = action.size or 1,
            amount = action.amount or 1,
        }
    elseif action.type == "rotate" then
        return make_string{
            task = "Rotate",
            position = action.position,
            units = action.is_clockwise and 1 or 3,
            item = localised_entity_names_en[action.entity_name],
            direction = "North",
            size = 1,
            amount = 1,
        }
    elseif action.type == "research" then
        return make_string{
            task = "Tech",
            item = localised_technology_names_en[action.technology_name],
        }
    elseif action.type == "craft" then
        return make_string{
            task = "Craft",
            units = action.count,
            item = localised_recipe_names_en[action.recipe_name],
        }
    elseif action.type == "mine" then
        return make_string{
            task = "Mine",
            position = action.position,
            units = action.mining_time * 60 * 2 + 5, -- assume starting mining speed of 0.5 and add 5 for safety
            -- EZR only displays the entity being mined if it is a building
            -- TODO: remove entity_prototypes access
            item = game.entity_prototypes[action.entity_name].items_to_place_this and localised_entity_names_en[action.entity_name] or nil
        }
    elseif action.type == "set_recipe" then
        return make_string{
            task = "Recipe",
            position = action.position,
            item = localised_recipe_names_en[action.recipe_name],
            direction = "North",
            size = 1,
            amount = 1,
        }
    elseif action.type == "set_limit" then
        return make_string{
            task = "Limit",
            position = action.position,
            units = action.limit,
            orientation = "Chest",
            direction = "North",
            size = 1,
            amount = 1,
        }
    elseif action.type == "set_input_priority" then
        return make_string{
            task = "Priority",
            position = action.position,
            orientation = string.format("%s,%s", action.input_priority, action.output_priority or "None"),
            direction = "North",
        }
    elseif action.type == "set_output_priority" then
        return make_string{
            task = "Priority",
            position = action.position,
            orientation = string.format("%s,%s", action.input_priority or "None", action.output_priority),
            direction = "North",
        }
    elseif action.type == "set_splitter_filter" then
        return make_string{
            task = "Filter",
            position = action.position,
            units = "1.0",
            item = localised_item_names_en[action.item_name],
            direction = "North",
        }
    elseif action.type == "set_filter_mode" then
        return make_string{
            task = "Filter",
            position = action.position,
            units = action.slot_index,
            item = localised_item_names_en[action.item_name],
            direction = "North",
        }
    elseif action.type == "set_filter_slot" then
        return make_string{
            task = "Filter",
            position = action.position,
            units = action.slot_index,
            item = localised_item_names_en[action.item_name],
            direction = "North",
            size = 1,
            amount = 1,
        }
    elseif action.type == "walk" then
        return make_string{
            task = "Walk",
            position = action.position,
        }
    elseif action.type == "drop" then
        return make_string{
            task = "Drop",
            item = localised_item_names_en[action.item_name],
            position = action.position,
        }
    else
        game.print("Error: Tried to export unknown action type: " .. (action.type or "nil"))
        return nil
    end
end

-- try merging the previous and current action
-- return whether to delete (because the actions cancel out), merge, or add (because the actions are unrelated)
-- and returns the new action and description if merging (otherwise returns nils)
local function try_merging_actions(prev_action, action)
    --no previous action or combine is turned off
    if prev_action == nil or global.elements.settings.combine_actions.state == false then
        return "add"

    --combine walk
    elseif prev_action.type == "walk" and action.type == "walk" and (prev_action.position.x ~= action.position.x or prev_action.position.y ~= action.position.y) then
        local new_description = {"tas_helper.description_walk", position_to_string(action.position)}
        local new_action = {
            type = "walk",
            position = {x = action.position.x, y = action.position.y},
            highlight_box_bounds = {{action.position.x - 0.5, action.position.y - 0.5}, {action.position.x + 0.5, action.position.y + 0.5}},
        }
        return "merge", new_description, new_action
        
    --combine mine <-> build on when it could be fast-replace
    elseif prev_action.type == "mine" and action.type == "build" and
            prev_action.position.x == action.position.x and prev_action.position.y == action.position.y and
            prev_action.fast_replace_group == action.fast_replace_group
    then
        local new_description = {"tas_helper.description_build", 1, entity_to_string(action.entity)}
        return "merge", new_description, action

    --remove build if it was cancelled by being mined immediately afterwards
    elseif prev_action.type == "build" and action.type == "mine" and prev_action.position.x == action.position.x and prev_action.position.y == action.position.y then
        if prev_action.amount and prev_action.amount > 1 then
            --TODO: allow shrinking of multibuild
        else
            return "delete"
        end

    --merge 2 crafts of the same item into 1
    elseif prev_action.type == "craft" and action.type == "craft" and prev_action.recipe_name == action.recipe_name then
        local new_count = prev_action.count + action.count
        local new_description = {"tas_helper.description_craft", new_count, action.recipe_name}
        local new_action = {
            type = "craft",
            recipe_name = action.recipe_name,
            count = new_count,
        }
        return "merge", new_description, new_action

    --merge 2 priority changes on the same splitter
    elseif prev_action.type:sub(-string.len("priority")) == "priority" and action.type:sub(-string.len("priority")) == "priority" and prev_action.position.x == action.position.x and prev_action.position.y == action.position.y then
        local new_description = {"tas_helper.description_set_setting", {"tas_helper.keyword_"..action.type}, entity_to_string(action.entity)}
        local new_action = {
            type = action.type,
            position = {x = action.position.x, y = action.position.y},
            highlight_box_bounds = {{action.position.x - 0.5, action.position.y - 0.5}, {action.position.x + 0.5, action.position.y + 0.5}},
            input_priority = action.input_priority,
            output_priority = action.output_priority,
        }
        return "merge", new_description, new_action

    --merge multibuild
    elseif  prev_action.type == action.type and -- same type
        ((action.type == "build" and prev_action.orientation == action.orientation and prev_action.entity_name == action.entity_name) or --either build or put/take
        ((action.type == "put" or action.type == "take") and prev_action.count == action.count and prev_action.item_name == action.item_name and prev_action.inventory == action.inventory))
        and
            (prev_action.position.x == action.position.x and prev_action.position.y ~= action.position.y or --different position in only one axis
            prev_action.position.x ~= action.position.x and prev_action.position.y == action.position.y)
    then
        local direction, size, amount, highlight_box_bounds = defines.direction.north, 1, 1, util.copy(prev_action.highlight_box_bounds)
        if prev_action.position.x ~= action.position.x then
            if not prev_action.direction then --new merge
                direction = prev_action.position.x < action.position.x and defines.direction.east or defines.direction.west
                size = math.abs(prev_action.position.x - action.position.x)
                amount = 2
                highlight_box_bounds[direction == defines.direction.west and "left_top" or "right_bottom"].x = 
                    highlight_box_bounds[direction == defines.direction.west and "left_top" or "right_bottom"].x + (direction == defines.direction.west and -size or size)
            elseif --old merge
                (prev_action.direction == defines.direction.east or prev_action.direction == defines.direction.west) and
                prev_action.position.x + prev_action.size * prev_action.amount * (prev_action.direction == defines.direction.east and 1 or -1) == action.position.x
            then
                direction = prev_action.direction
                size = prev_action.size
                amount = prev_action.amount + 1
                highlight_box_bounds[direction == defines.direction.west and "left_top" or "right_bottom"].x = 
                    highlight_box_bounds[direction == defines.direction.west and "left_top" or "right_bottom"].x + (direction == defines.direction.west and -size or size)
            else
                return "add"
            end
        else
            if not prev_action.direction then --new merge
                direction = prev_action.position.y < action.position.y and defines.direction.south or defines.direction.north
                size = math.abs(prev_action.position.y - action.position.y)
                amount = 2
                highlight_box_bounds[direction == defines.direction.north and "left_top" or "right_bottom"].y = 
                    highlight_box_bounds[direction == defines.direction.north and "left_top" or "right_bottom"].y + (direction == defines.direction.north and -size or size)
            elseif --old merge
                (prev_action.direction == defines.direction.south or prev_action.direction == defines.direction.north) and
                prev_action.position.y + prev_action.size * prev_action.amount * (prev_action.direction == defines.direction.south and 1 or -1) == action.position.y
            then
                direction = prev_action.direction
                size = prev_action.size
                amount = prev_action.amount + 1
                highlight_box_bounds[direction == defines.direction.north and "left_top" or "right_bottom"].y = 
                    highlight_box_bounds[direction == defines.direction.north and "left_top" or "right_bottom"].y + (direction == defines.direction.north and -size or size)
            else
                return "add"
            end
        end

        if size  * amount > tonumber(global.elements.settings.max_build_size.textfield.text) then
            return "add"
        end
        local new_description = action.type == "build" and {"tas_helper.description_build", amount, entity_to_string(prev_action.entity)}
            or {"tas_helper.description_"..action.type, action.count == 0 and "all" or action.count .. " x", action.item_name, entity_to_string(prev_action.entity)}
        local new_action = {
            type = action.type,
            position = prev_action.position,
            highlight_box_bounds = highlight_box_bounds,
            entity_name = prev_action.entity_name,
            entity = prev_action.entity,
            fast_replace_group = prev_action.fast_replace_group,
            orientation = prev_action.orientation,
            direction = direction,
            size = size,
            amount = amount,
            count = action.count,
            item_name = action.item_name,
            inventory = action.inventory,
        }
        return "merge", new_description, new_action

    else
        return "add"
    end
end

local function add_action(description, action, force_add)
    -- add action after the currently selected action, or at the end if no action is selected somehow
    -- does nothing if not currently recording
    -- description is a LocalisedString
    
    if not global.recording and force_add ~= true then
        return
    end

    local listbox = global.elements.actions_listbox

    -- If no item is selected (somehow) then append action to the end of the list
    if listbox.selected_index == 0 then
        listbox.selected_index = #listbox.items
    end

    -- If 'always add to end' checkbox is ticked, then add to end
    if global.elements.settings.always_add_to_end.state then
        listbox.selected_index = #listbox.items
    end

    local index = listbox.selected_index

    local prev_action = index > 0 and global.actions[index] or nil
    prev_action = not force_add and prev_action or nil
    local what_to_do, new_description, new_action = try_merging_actions(prev_action, action)
    new_description = new_description or description

    if what_to_do == "delete" then
        listbox.remove_item(index)
        table.remove(global.actions, index)
        listbox.selected_index = index > 1 and index - 1 or (#listbox.items == 0 and 0 or 1)
    elseif what_to_do == "merge" then
        listbox.set_item(index, new_description)
        global.actions[index] = new_action
        listbox.selected_index = index
    else
        listbox.add_item(description, index + 1)
        table.insert(global.actions, index + 1, action)
        listbox.selected_index = index + 1
    end
    listbox.scroll_to_item(listbox.selected_index)
    update_highlight_box()
end

local function handle_toggle_recording()
    local element = global.elements.buttons_flow.start_stop_recording_button
    global.recording = not global.recording
    element.caption = global.recording and stop_recording_text or start_recording_text
    element.tooltip = global.recording and {"tas_helper.pause_tooltip"} or {"tas_helper.record_tooltip"}
    element.style = global.recording and "tas_helper_button_selected" or "button"
end

local function handle_prev()
    local listbox = global.elements.actions_listbox
    if listbox.selected_index > 1 then
        listbox.selected_index = listbox.selected_index - 1
        listbox.scroll_to_item(listbox.selected_index)
        update_highlight_box()
    end
end

local function handle_next()
    local listbox = global.elements.actions_listbox
    if listbox.selected_index < #listbox.items then
        listbox.selected_index = listbox.selected_index + 1
        listbox.scroll_to_item(listbox.selected_index)
        update_highlight_box()
    end
end

local function table_swap(table, i, j)
    table[i], table[j] = table[j], table[i]
end

local function handle_move_up()
    local listbox = global.elements.actions_listbox
    local i = listbox.selected_index
    if i > 1 then
        local tmp = listbox.get_item(i-1)
        listbox.set_item(i-1, listbox.get_item(i))
        listbox.set_item(i, tmp)
        table_swap(global.actions, i-1, i)
        listbox.selected_index = i-1
        listbox.scroll_to_item(listbox.selected_index)
        update_highlight_box()
    end
end

local function handle_move_down()
    local listbox = global.elements.actions_listbox
    local i = listbox.selected_index
    if i < #listbox.items then
        local tmp = listbox.get_item(i+1)
        listbox.set_item(i+1, listbox.get_item(i))
        listbox.set_item(i, tmp)
        table_swap(global.actions, i, i+1)
        listbox.selected_index = i+1
        listbox.scroll_to_item(listbox.selected_index)
        update_highlight_box()
    end
end

local function handle_delete()
    local listbox = global.elements.actions_listbox

    if listbox.selected_index == 0 then
        return
    end

    local index = listbox.selected_index
    table.remove(global.actions, index)
    listbox.remove_item(index)
    listbox.selected_index = index > 1 and index - 1 or (#listbox.items == 0 and 0 or 1)
    listbox.scroll_to_item(listbox.selected_index)
    update_highlight_box()
end

script.on_init(function()
    if game.get_player(1) then
        build_gui()
    end

    -- list of recorded actions
    global.actions = {}

    -- last player.opened entity
    global.last_opened = {
        entity = nil,
        info = nil,
    }

    -- current highlight box entity (on currently selected action)
    global.current_highlight_box = nil
end)

script.on_configuration_changed(function(event)
    --maybe do stuff
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function (event)
    local prefix = "tas_step_planner_action_"
    for action,element in pairs(global.action_types) do
        local setting = prefix..action
        if event.setting == setting then
            element.state = settings.global[setting].value
        end
    end
end)

script.on_event(defines.events.on_player_created, function(event)
    if event.player_index == 1 then
        build_gui()
    end
end)

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
    local player = game.get_player(1)
    local inventory = player.get_main_inventory()
    global.main_inventory_contents = inventory.get_contents()
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(1)
    local item_stack = player.cursor_stack
    global.cursor_stack_contents = item_stack.valid_for_read and { name = item_stack.name, count = item_stack.count } or nil
end)

script.on_event(defines.events.on_player_toggled_map_editor, function(event)
    -- when the player toggles editor mode, their inventory and cursor stack change
    local player = game.get_player(1)
    local inventory = player.get_main_inventory()
    global.main_inventory_contents = inventory.get_contents()
    local item_stack = player.cursor_stack
    global.cursor_stack_contents = item_stack.valid_for_read and { name = item_stack.name, count = item_stack.count } or nil
end)

local function ingredients_contains(ingredients, item_name)
    for _, ingredient in pairs(ingredients) do
        if ingredient.name == item_name then
            return true
        end
    end
    return false
end

---@param event EventData.on_player_fast_transferred
local function handle_fast_transfer_from_player(event)
    local player = game.get_player(1)
    if player == nil or not global.elements.settings.capture_put.state then return end
    local entity = event.entity

    -- count total amount of item in cursor and main inventory before and after transfer
    local prev_cursor_contents = global.cursor_stack_contents
    if not prev_cursor_contents then
        game.print("Error: fast transfer from player to entity but nothing recorded in cursor stack")
        return
    end
    local prev_inventory_contents = global.main_inventory_contents
    local item_name = prev_cursor_contents.name
    local prev_count = prev_cursor_contents.count + (prev_inventory_contents[item_name] or 0)

    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid_for_read and cursor_stack.name ~= item_name then
        game.print("Error: unexpected item during fast transfer")
    end
    local cursor_count = cursor_stack and cursor_stack.valid_for_read and cursor_stack.count or 0
    local inventory_count = player.get_main_inventory().get_item_count(item_name)

    local transfer_count = prev_count - (cursor_count + inventory_count)

    if transfer_count == 0 then
        -- nothing transferred
        return
    end

    -- check 'always put amount' settings
    local always_put_amount = global.elements.settings.always_put_amount
    if always_put_amount.checkbox.state then
        transfer_count = tonumber(always_put_amount.textfield.text) or 0
    end

    local inventory = nil
    -- TODO: remove/optimise usages of game.item_prototypes
    if entity.get_fuel_inventory() and game.item_prototypes[item_name].fuel_category then
        inventory = "Fuel"
    elseif entity.type == "lab" then
        if game.item_prototypes[item_name].type == "module" then
            inventory = "Modules"
        else
            inventory = "Input"
        end
    elseif entity.type == "mining-drill" then
        inventory = "Modules"
    elseif chest_list[entity.name] ~= nil then
        inventory = "Chest"
    elseif entity.type == "container" then
        inventory = "Wreck"
    elseif entity.type == "beacon" then
        -- Beacon input inventory is defines.inventory.beacon_modules but EZR doesn't handle
        -- beacon module inventory correctly so you have to use Wreck instead (which maps to the
        -- same integer as beacon_modules)
        inventory = "Wreck"
    elseif game.item_prototypes[item_name].type == "module" then
        local recipe = entity.type == "assembling-machine" and entity.get_recipe() or nil
        local ingredients = recipe and recipe.ingredients
        if ingredients and ingredients_contains(ingredients, item_name) then
            inventory = "Input"
        elseif entity.get_module_inventory() == entity.get_inventory(defines.inventory.assembling_machine_modules) then
            inventory = "Modules"
        end
        -- otherwise, ??? don't know which inventory this module goes in
    else
        -- assume that the correct inventory is defines.inventory.assembling_machine_input
        inventory = "Input"
    end

    if inventory then
        local transfer_count_description = transfer_count == 0 and "all" or transfer_count .. " x"
        add_action({"tas_helper.description_put", transfer_count_description, item_name, entity_to_string(entity)}, {
            type = "put",
            entity = entity,
            position = entity.position,
            item_name = item_name,
            count = transfer_count,
            inventory = inventory,
            highlight_box_bounds = entity.selection_box,
        })
    else
        game.print("Error: Couldn't identify correct inventory when exporting action 'Put' with entity " .. entity.name .. " and item " .. item_name)
    end
end

local function handle_fast_transfer_to_player(event)
    local player = game.get_player(1)
    if player == nil or not global.elements.settings.capture_take.state then return end
    local entity = event.entity

    local main_inventory = player.get_main_inventory()
    local prev = global.main_inventory_contents
    for item_name, count in pairs(main_inventory.get_contents()) do
        local prev_count = prev[item_name] or 0
        if count > prev_count then
            local transfer_count = count - prev_count

            local always_take_amount = global.elements.settings.always_take_amount
            if always_take_amount.checkbox.state then
                transfer_count = tonumber(always_take_amount.textfield.text) or 0
            end

            local inventory = nil
            if entity.get_fuel_inventory() and entity.get_fuel_inventory() == entity.get_output_inventory() then
                inventory = "Fuel"
            elseif entity.type == "lab" then
                -- Lab output inventory is defines.inventory.lab_input
                -- and EZR converts "Input" on lab to defines.inventory.lab_input
                inventory = "Input"
            elseif entity.type == "beacon" then
                -- Beacon output inventory is defines.inventory.beacon_modules but EZR doesn't handle
                -- beacon module inventory correctly so you have to use Wreck instead (which maps to the
                -- same integer as beacon_modules)
                inventory = "Wreck"
            elseif chest_list[entity.name] ~= nil then
                inventory = "Chest"
            elseif entity.type == "container" or entity.type == "logistic-container" then
                -- EZR doesn't allow you to take from 'Chest' unless it's one of the standard chests
                inventory = "Wreck"
            elseif entity.get_output_inventory() == entity.get_inventory(defines.inventory.assembling_machine_input) then
                -- not sure if this ever triggers
                inventory = "Input"
            elseif entity.get_output_inventory() == entity.get_inventory(defines.inventory.assembling_machine_output) then
                inventory = "Output"
            elseif entity.get_output_inventory() == entity.get_inventory(defines.inventory.assembling_machine_modules) then
                -- not sure if this triggers either
                inventory = "Modules"
            elseif entity.get_output_inventory() == entity.get_inventory(defines.inventory.chest) then
                -- works with roboports I guess
                inventory = "Wreck"
            end
            if inventory then
                local transfer_count_description = transfer_count == 0 and "all" or transfer_count .. " x"
                add_action({"tas_helper.description_take", transfer_count_description, item_name, entity_to_string(entity)}, {
                    type = "take",
                    position = entity.position,
                    entity = entity,
                    item_name = item_name,
                    count = transfer_count,
                    inventory = inventory,
                    highlight_box_bounds = entity.selection_box,
                })
            else
                game.print("Error: Couldn't identify correct inventory when exporting action 'Take' with entity " .. entity.name .. " and item " .. item_name)
            end
        elseif count < prev_count then
            game.print("Error: player lost item " .. item_name .. " during fast transfer from entity to player")
        end
    end
end

script.on_event(defines.events.on_player_fast_transferred, function(event)
    if event.from_player then
        handle_fast_transfer_from_player(event)
    else
        handle_fast_transfer_to_player(event)
    end
end)

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    if entity.type == "entity-ghost" then
        global.ghosts = global.ghosts or {}
        table.insert(global.ghosts, entity)
        return
    end
    if not global.elements.settings.capture_build.state then return end

    local dir = entity.supports_direction and entity.direction or nil
    local suffix = "underground-belt"
    if dir and entity.name:sub(-string.len(suffix)) == suffix and entity.belt_to_ground_type and entity.belt_to_ground_type == "output" then
        dir = (dir + 4) % 8
    end
    add_action({"tas_helper.description_build", 1, entity_to_string(entity)}, {
        type = "build",
        position = entity.position,
        entity_name = entity.name,
        entity = entity,
        orientation = dir,
        fast_replace_group = entity.prototype.fast_replaceable_group,
        highlight_box_bounds = entity.selection_box,
    })

    --UPGRADE ghost ->
    local recipe = global.elements.settings.capture_recipe.state and entity.type == "assembling-machine" and entity.get_recipe()
    if recipe then
        local keyword = recipe and {"tas_helper.keyword_set_recipe", recipe.name} or {"tas_helper.keyword_clear_recipe"}
        add_action({"tas_helper.description_set_setting", keyword, entity_to_string(entity)}, {
            type = "set_recipe",
            position = entity.position,
            recipe_name = recipe.name,
            highlight_box_bounds = entity.selection_box,
        })
    end

    local inventory = global.elements.settings.capture_limit.state and entity.type == "container" and entity.get_inventory(defines.inventory.chest)
    if inventory and inventory.supports_bar() then
        local bar = inventory.get_bar()
        if bar < #entity.get_output_inventory() + 1 then
            local keyword = {"tas_helper.keyword_set_limit", bar - 1}
            add_action({"tas_helper.description_set_setting", keyword, entity_to_string(entity)}, {
            type = "set_limit",
            position = entity.position,
            limit = bar - 1,
            highlight_box_bounds = entity.selection_box,
        })
        end
    end

    if global.elements.settings.capture_splitter.state and entity.type == "splitter" and
        entity.splitter_input_priority ~= "none" and entity.splitter_output_priority ~= "none"
    then
        add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_input_priority"}, entity_to_string(entity)}, {
            type = "set_input_priority",
            position = entity.position,
            entity = entity,
            input_priority = entity.splitter_input_priority:gsub("^%l", string.upper),
            output_priority = entity.splitter_output_priority:gsub("^%l", string.upper),
            highlight_box_bounds = entity.selection_box,
        })
    end

    if global.elements.settings.capture_filter_inserter.state and (entity.type == "splitter" or entity.type == "inserter" and entity.inserter_filter_mode)
    then
        if entity.type == "splitter" and entity.splitter_filter then
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter"}, entity_to_string(entity)}, {
                type = "set_splitter_filter",
                position = entity.position,
                item_name = entity.splitter_filter,
                highlight_box_bounds = entity.selection_box,
            })

        elseif entity.type == "inserter" then
            --[[ if entity.inserter_filter_mode ~= whitelist 
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter_mode"}, entity_to_string(entity)}, {
                type = "set_filter_mode",
                position = entity.position,
                mode = entity.inserter_filter_mode,
                highlight_box_bounds = entity.selection_box,
            })]]

            local slots = get_filter_slots(entity)
            for i = 1, entity.filter_slot_count do
                if slots[i] then
                    add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter"}, entity_to_string(entity)}, {
                        type = "set_filter_slot",
                        position = entity.position,
                        item_name = slots[i],
                        slot_index = i,
                        highlight_box_bounds = entity.selection_box,
                    })
                end
            end
        end
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    if not game or not global.recording then return end
    local player = game.players[event.player_index]
    if not player or not player.character then return end
    local position = player.position
    local cur_item_name, cur_item_count
    if player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
        cur_item_name, cur_item_count = player.cursor_stack.name, player.cursor_stack.count
    end
    global.ghosts = global.ghosts or {}

    if global.elements.settings.capture_ghost.state then
        for index, entity in pairs(global.ghosts) do
            if not entity.valid then
                table.remove(global.ghosts, index)
            else
                local dist = math.sqrt((math.abs(entity.position.x - player.position.x) - (entity.bounding_box.right_bottom.x-entity.bounding_box.left_top.x))^2 + (math.abs(entity.position.y - player.position.y) - (entity.bounding_box.right_bottom.y-entity.bounding_box.left_top.y))^2)
                if dist < 10 and player.can_reach_entity(entity) then
                    player.cursor_stack.set_stack({name = entity.ghost_name, count = 200})
                    local inv = entity.ghost_type == "underground-belt" and entity.belt_to_ground_type == "output" or false
                    if player.can_build_from_cursor{position = entity.position, direction = entity.direction} and
                        player.build_from_cursor{position = entity.position, direction = inv and (entity.direction + 4) % 8 or entity.direction}
                    then
                        table.remove(global.ghosts, index)
                        break
                    end
                end
            end
        end
        if cur_item_name then player.cursor_stack.set_stack({name = cur_item_name, count = cur_item_count}) else player.cursor_stack.clear() end
    end

    if global.elements and not global.elements.settings.capture_walk.state then
        return
    end

    add_action({"tas_helper.description_walk", position_to_string(position)}, {
        type = "walk",
        position = {x = position.x, y = position.y},
        highlight_box_bounds = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}},
    }, false)

end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
    local entity = event.entity
    if entity.type == "entity-ghost" or not global.elements.settings.capture_rotate.state then
        return
    end

    local previous_direction = event.previous_direction
    local rotation_amount = (entity.direction + 8 - previous_direction) % 8
    local is_clockwise = rotation_amount == 2
    local rotation_direction_img = is_clockwise and "tas_helper_rotate_clockwise" or "tas_helper_rotate_anticlockwise"
    add_action({"tas_helper.description_rotate", rotation_direction_img, entity_to_string(entity)}, {
        type = "rotate",
        position = entity.position,
        is_clockwise = is_clockwise,
        entity_name = entity.name, -- necessary for ezr
        highlight_box_bounds = entity.selection_box,
    })
end)

script.on_event(defines.events.on_research_started, function(event)
    if not global.elements.settings.capture_research.state then
        return
    end
    local research = event.research
    add_action({"tas_helper.description_research", research.name}, {
        type = "research",
        technology_name = research.name,
    })
end)

script.on_event(defines.events.on_pre_player_crafted_item, function(event)
    if not global.elements.settings.capture_craft.state then
        return
    end

    local recipe = event.recipe
    local count = event.queued_count
    add_action({"tas_helper.description_craft", count, recipe.name}, {
        type = "craft",
        recipe_name = recipe.name,
        count = count,
    })
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    local entity = event.entity
    if entity.type == "entity-ghost" then
        for _,ent in pairs(global.ghosts or {}) do
            if ent == entity then table.remove(global.ghosts, _) end
        end

        return
    end
    if not global.elements.settings.capture_mine.state then return end

    local mining_time = entity.prototype.mineable_properties.mining_time
    add_action({"tas_helper.description_mine", entity_to_string(entity)}, {
        type = "mine",
        position = entity.position,
        mining_time = mining_time,
        entity_name = entity.name, -- sometimes necessary for ezr
        fast_replace_group = entity.prototype.fast_replaceable_group,
        highlight_box_bounds = entity.selection_box,
    })
end)

script.on_event(defines.events.on_player_dropped_item, function (event)
    if not global.elements.settings.capture_mine.state then return end
    local item = event.entity
    add_action({"tas_helper.description_drop", item.stack.name, position_to_string(item.position)}, {
        type = "drop",
        position = item.position,
        entity = item,
        item_name = item.stack.name,
        highlight_box_bounds = item.selection_box,
    })
end)

local function get_entity_info(entity)
    return entity and {
        recipe = entity.type == "assembling-machine" and entity.get_recipe() and entity.get_recipe().name or nil,
        bar = entity.get_output_inventory() and entity.get_output_inventory().supports_bar() and entity.get_output_inventory().get_bar() or nil,
        splitter = entity.type == "splitter" and {
            input_priority = entity.splitter_input_priority,
            output_priority = entity.splitter_output_priority,
            filter = entity.splitter_filter and entity.splitter_filter.name or nil,
        } or nil,
        inserter_filter = entity.type == "inserter" and entity.inserter_filter_mode and {
            mode = entity.inserter_filter_mode,
            slots = get_filter_slots(entity),
        } or nil
    } or nil
end

local function check_for_setting_changes(entity, last_info, info)
    -- check for certain changes on 'entity' using the previous settings ('last_info') and the new settings ('info')
    if info.recipe ~= last_info.recipe and global.elements.settings.capture_recipe.state then
        local keyword = info.recipe and {"tas_helper.keyword_set_recipe", info.recipe} or {"tas_helper.keyword_clear_recipe"}
        add_action({"tas_helper.description_set_setting", keyword, entity_to_string(entity)}, {
            type = "set_recipe",
            entity = entity,
            position = entity.position,
            recipe_name = info.recipe,
            highlight_box_bounds = entity.selection_box,
        })
    end
    if info.bar and info.bar ~= last_info.bar and global.elements.settings.capture_limit.state  then
        local unlimited = info.bar == #entity.get_output_inventory() + 1
        local keyword = unlimited and {"tas_helper.keyword_remove_limit"} or {"tas_helper.keyword_set_limit", info.bar - 1}
        add_action({"tas_helper.description_set_setting", keyword, entity_to_string(entity)}, {
            type = "set_limit",
            entity = entity,
            position = entity.position,
            limit = info.bar - 1,
            highlight_box_bounds = entity.selection_box,
        })
    end
    -- TODO: Add more info to descriptions for these actions
    if info.splitter then
        assert(last_info.splitter)
        if info.splitter.input_priority ~= last_info.splitter.input_priority and global.elements.settings.capture_splitter.state then
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_input_priority"}, entity_to_string(entity)}, {
                type = "set_input_priority",
                position = entity.position,
                entity = entity,
                input_priority = info.splitter.input_priority:gsub("^%l", string.upper),
                output_priority = info.splitter.output_priority and info.splitter.output_priority:gsub("^%l", string.upper) or nil,
                highlight_box_bounds = entity.selection_box,
            })
        end
        if info.splitter.output_priority ~= last_info.splitter.output_priority and global.elements.settings.capture_splitter.state then
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_output_priority"}, entity_to_string(entity)}, {
                type = "set_output_priority",
                position = entity.position,
                entity = entity,
                input_priority = info.splitter.input_priority and info.splitter.input_priority:gsub("^%l", string.upper) or nil,
                output_priority = info.splitter.output_priority:gsub("^%l", string.upper),
                highlight_box_bounds = entity.selection_box,
            })
        end
        if info.splitter.filter ~= last_info.splitter.filter and global.elements.settings.capture_filter_inserter.state then
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter"}, entity_to_string(entity)}, {
                type = "set_splitter_filter",
                entity = entity,
                position = entity.position,
                item_name = info.splitter.filter,
                highlight_box_bounds = entity.selection_box,
            })
        end
    end
    if info.inserter_filter and global.elements.settings.capture_filter_inserter.state then
        assert(last_info.inserter_filter)
        if info.inserter_filter.mode ~= last_info.inserter_filter.mode then
            add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter_mode"}, entity_to_string(entity)}, {
                type = "set_filter_mode",
                entity = entity,
                position = entity.position,
                mode = info.inserter_filter.mode,
                highlight_box_bounds = entity.selection_box,
            })
        end
        local slots = info.inserter_filter.slots
        local last_slots = last_info.inserter_filter.slots
        for i = 1, entity.filter_slot_count do
            if slots[i] ~= last_slots[i] then
                add_action({"tas_helper.description_set_setting", {"tas_helper.keyword_set_filter"}, entity_to_string(entity)}, {
                    type = "set_filter_slot",
                    entity = entity,
                    position = entity.position,
                    item_name = slots[i],
                    slot_index = i,
                    highlight_box_bounds = entity.selection_box,
                })
            end
        end
    end
end

script.on_event(defines.events.on_tick, function(event)
    local player = game.get_player(1)
    if not player then return end

    local entity = player.opened and player.opened.object_name == "LuaEntity" and player.opened or nil
    local info = get_entity_info(entity)

    if entity and entity == global.last_opened.entity then
        local last_info = global.last_opened.info
        check_for_setting_changes(entity, last_info, info)
    end

    global.last_opened = {
        entity = entity,
        info = info,
    }
end)

script.on_event(defines.events.on_pre_entity_settings_pasted, function(event)
    local last_info = get_entity_info(event.destination)
    local info = get_entity_info(event.source)
    check_for_setting_changes(event.destination, last_info, info)
end)

local function handle_add_walk_action()
    local player = game.get_player(1)
    local position = player and player.position or {x = 0, y = 0}

    -- TODO: add rounding options

    -- force add this action even if not recording
    add_action({"tas_helper.description_walk", position_to_string(position)}, {
        type = "walk",
        position = {x = position.x, y = position.y},
        highlight_box_bounds = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}},
    }, true)
end

-- returns number of lines
local function do_export_to_textbox()
    local export_textbox = global.elements.export_textbox
    local lines = {}
    for _, action in pairs(global.actions) do
        local string = ezr_action_to_string(action)
        if string then
            table.insert(lines, string)
        end
    end
    export_textbox.text = table.concat(lines, "\n")
    return #lines
end

local function handle_open_dialog(frame)
    local player = game.get_player(1)
    if not player then return end

    frame.visible = true
    frame.bring_to_front()
    player.opened = frame

    local settings_window_width = 290

    local location = global.elements.main_frame.location
    if location.x + math.floor((gui_width + settings_window_width) * player.display_scale) < player.display_resolution.width then
        -- position settings to the right of the helper window
        location.x = location.x + math.floor(gui_width * player.display_scale)
    else
        -- position settings to the left
        location.x = location.x - math.floor(settings_window_width * player.display_scale)
    end
    global.elements.settings_frame.location = location
end

local function handle_close_dialog(frame)
    local player = game.get_player(1)
    frame.visible = false
    if player.opened == frame then
        player.opened = nil
    end
end

local function handle_toggle_dialog(frame)
    if frame.visible then
        handle_close_dialog(frame)
    else
        handle_open_dialog(frame)
    end
end

local function handle_toggle_gui()
    local main_frame = global.elements.main_frame
    main_frame.visible = not main_frame.visible
    if main_frame.visible then
        main_frame.bring_to_front()
    end

    -- toggle shortcut
    local player = game.get_player(1)
    player.set_shortcut_toggled("tas_helper_toggle_gui", main_frame.visible)
    settings.global.tas_step_planner_open = {value = main_frame.visible}

    handle_close_dialog(global.elements.export_frame)
    handle_close_dialog(global.elements.settings_frame)
end

local function handle_export_ezr()
    local num_lines = do_export_to_textbox()
    handle_open_dialog(global.elements.export_frame)
    local textbox = global.elements.export_textbox
    textbox.focus()
    textbox.select_all()
end

script.on_event(defines.events.on_gui_closed, function(event)
    local element = event.element
    if element == global.elements.export_frame then
        handle_close_dialog(element)
    elseif element == global.elements.settings_frame then
        handle_close_dialog(element)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    local buttons_flow = global.elements.buttons_flow
    if element == buttons_flow.start_stop_recording_button then
        handle_toggle_recording()
    elseif element == buttons_flow.prev_button then
        handle_prev()
    elseif element == buttons_flow.next_button then
        handle_next()
    elseif element == buttons_flow.move_up_button then
        handle_move_up()
    elseif element == buttons_flow.move_down_button then
        handle_move_down()
    elseif element == buttons_flow.delete_button then
        handle_delete()
    elseif element == buttons_flow.add_walk_action_button then
        handle_add_walk_action()
    elseif element == buttons_flow.export_ezr_button then
        handle_export_ezr()
    elseif element == buttons_flow.settings_button then
        handle_toggle_dialog(global.elements.settings_frame)
    elseif element == global.elements.export_frame_close_button then
        handle_close_dialog(global.elements.export_frame)
    elseif element == global.elements.settings_frame_close_button then
        handle_close_dialog(global.elements.settings_frame)
    elseif element == global.elements.export_frame.buttons.select_all_button then
        local textbox = global.elements.export_textbox
        textbox.focus()
        textbox.select_all()
    elseif element == global.elements.export_frame.buttons.ok then
        handle_close_dialog(global.elements.export_frame)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    local prefix = "tas_step_planner_other_"
    for setting, element in pairs(global.other_types) do
        if event.element == element then
            settings.global[prefix..setting] = {value = element.text}
            return
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    do -- Update GUI
        local settings = global.elements.settings
        local element = event.element
        if element == settings.always_put_amount.checkbox then
            settings.always_put_amount.textfield.enabled = element.state
        elseif element == settings.always_take_amount.checkbox then
            settings.always_take_amount.textfield.enabled = element.state
        end
    end

    do -- Update settings
        local prefix = "tas_step_planner_action_"
        for action, element in pairs(global.action_types) do
            if event.element == element then
                settings.global[prefix..action] = {value = element.state}
                return
            end
        end

        prefix = "tas_step_planner_other_"
        for setting, element in pairs(global.other_types) do
            if event.element == element then
                settings.global[prefix..setting] = {value = element.state}
                return
            end
        end
    end
end)

local has_main_frame_moved = nil
script.on_event(defines.events.on_gui_location_changed, function (event)
    if event.element == global.elements.main_frame then
        has_main_frame_moved = {x = event.element.location.x, y = event.element.location.y}
    end
end)

script.on_nth_tick(59, function (param1)
    if has_main_frame_moved then
        settings.global.tas_step_planner_x, settings.global.tas_step_planner_y =
            {value = has_main_frame_moved.x}, {value = has_main_frame_moved.y}
        has_main_frame_moved = nil
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local element = event.element
    if element == global.elements.actions_listbox then
        update_highlight_box()
    end
end)

script.on_event("tas_helper_toggle_gui", handle_toggle_gui)
script.on_event("tas_helper_toggle_recording", function()
    local player = game.get_player(1)
    player.play_sound{ path = "utility/gui_click", }
    handle_toggle_recording()
end)
script.on_event("tas_helper_previous", handle_prev)
script.on_event("tas_helper_next", handle_next)
script.on_event("tas_helper_move_up", handle_move_up)
script.on_event("tas_helper_move_down", handle_move_down)
script.on_event("tas_helper_delete", function()
    local player = game.get_player(1)
    player.play_sound{ path = "tas_helper_gui_red_button", }
    handle_delete()
end)
script.on_event("tas_helper_add_walk_action", function()
    local player = game.get_player(1)
    player.play_sound{ path = "utility/gui_click", }
    handle_add_walk_action()
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "tas_helper_toggle_gui" then
        handle_toggle_gui()
    end
end)

