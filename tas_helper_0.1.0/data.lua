
-- Styles
local styles = data.raw["gui-style"].default

-- copied from default button style
local default_dirt_color = {15, 7, 3, 100}
local function default_glow(tint_value, scale_value)
    return {
        position = {200, 128},
        corner_size = 8,
        tint = tint_value,
        scale = scale_value,
        draw_type = "outer"
    }
end
local default_dirt = default_glow(default_dirt_color, 0.5)
styles["tas_helper_button_selected"] = {
    type = "button_style",
    parent = "button",
    default_font_color = {},
    default_graphical_set = {
        base = {position = {225, 17}, corner_size = 8},
        shadow = default_dirt
    },
    hovered_font_color = {},
    hovered_graphical_set = {
        base = {position = {369, 17}, corner_size = 8},
        shadow = default_dirt
    },
    clicked_font_color = {},
    clicked_graphical_set = {
        base = {position = {352, 17}, corner_size = 8},
        shadow = default_dirt
    },
}

-- from Raiguard's style guide
styles["tas_helper_title_bar_draggable_space"] = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    height = 24,
    right_margin = 4,
}

styles["tas_helper_export_textbox"] = {
    type = "textbox_style",
    width = 500,
    height = 250,
}

styles["tas_helper_total_lines_flow"] = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    height = 28,
    vertical_align = "center",
}

styles["tas_helper_total_lines_label"] = {
    type = "label_style",
    parent = "label",
    width = 180,
}

styles["tas_helper_number_textfield"] = {
    type = "textbox_style",
    parent = "textbox",
    width = 60,
}

styles["tas_helper_invalid_value_number_textfield"] = {
    type = "textbox_style",
    parent = "invalid_value_textfield",
    width = 60,
}

-- Sprites
-- rotate_anticlockwise.png is just reset_white.png and rotate_clockwise.png is just rotate_anticlockwise.png flipped horizontally
data:extend{
    { type = "sprite", name = "tas_helper_record", filename = "__tas_helper__/graphics/record.png", flags = {"gui-icon"}, size = 32, scale = 0.5, },
    { type = "sprite", name = "tas_helper_rotate_anticlockwise", filename = "__tas_helper__/graphics/rotate_anticlockwise.png", size = 32, scale = 0.5, mipmap_count = 2, flags = {"gui-icon"}, },
    { type = "sprite", name = "tas_helper_rotate_clockwise", filename = "__tas_helper__/graphics/rotate_clockwise.png", size = 32, scale = 0.5, mipmap_count = 2, flags = {"gui-icon"}, },
}


-- Sounds
-- Apparently gui-red-button.ogg isn't added as a UtilitySound and is only manually added on the red button style
data:extend{
    -- 'category' changes which volume slider affects this sound
    { type = "sound", name = "tas_helper_gui_red_button", category = "gui-effect", filename = "__core__/sound/gui-red-button.ogg", volume = 0.5, }
}


-- Shortcut
data.raw.shortcut["tas_helper_toggle_gui"] = {
    type = "shortcut",
    name = "tas_helper_toggle_gui",
    toggleable = true,
    action = "lua",
    localised_name = {"tas_helper.toggle_gui"},
    associated_control_input = "tas_helper_toggle_gui",
    icon = {
        filename = "__tas_helper__/graphics/record.png",
        size = 32,
    },
}

-- Hotkeys
local function add_hotkey(name, key_sequence, order)
    data:extend{
        { type = "custom-input", name = name, key_sequence = key_sequence, consuming = "game-only", order = order, },
    }
end

add_hotkey("tas_helper_toggle_gui", "CONTROL + T", "a")
add_hotkey("tas_helper_toggle_recording", "CONTROL + R", "b")
add_hotkey("tas_helper_previous", "CONTROL + mouse-wheel-up", "c")
add_hotkey("tas_helper_next", "CONTROL + mouse-wheel-down", "d")
add_hotkey("tas_helper_move_up", "CONTROL + SHIFT + mouse-wheel-up", "e")
add_hotkey("tas_helper_move_down", "CONTROL + SHIFT + mouse-wheel-down", "f")
add_hotkey("tas_helper_delete", "DELETE", "g")
add_hotkey("tas_helper_add_walk_action", "CONTROL + W", "h")

