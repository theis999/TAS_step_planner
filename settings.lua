local prefix = "tas_step_planner_"
local prefix_action = "tas_step_planner_action_"
local prefix_other = "tas_step_planner_other_"

data:extend(
    {
        {
            type = "int-setting",
            name = prefix.."gui-width",
            setting_type = "startup",
            default_value = 375,
            minimum_value = 240,
            maximum_value = 800,
            order = "s0",
        },
        {
            type = "int-setting",
            name = prefix.."x",
            setting_type = "runtime-global",
            default_value = 1250,
            order = "ax",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix.."y",
            setting_type = "runtime-global",
            default_value = 240,
            order = "ay",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix.."open",
            setting_type = "runtime-global",
            default_value = true,
            order = "ab",
            hidden = true,
        },

        -- capture actions

        {
            type = "bool-setting",
            name = prefix_action.."walk",
            setting_type = "runtime-global",
            default_value = true,
            order = "a1",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."build",
            setting_type = "runtime-global",
            default_value = true,
            order = "a2",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."rotate",
            setting_type = "runtime-global",
            default_value = true,
            order = "a3",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."craft",
            setting_type = "runtime-global",
            default_value = true,
            order = "a4",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."put",
            setting_type = "runtime-global",
            default_value = true,
            order = "a5",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."take",
            setting_type = "runtime-global",
            default_value = true,
            order = "a6",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."mine",
            setting_type = "runtime-global",
            default_value = true,
            order = "a7",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."limit",
            setting_type = "runtime-global",
            default_value = true,
            order = "a8",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."recipe",
            setting_type = "runtime-global",
            default_value = true,
            order = "a9",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."priority",
            setting_type = "runtime-global",
            default_value = true,
            order = "a10",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."filter",
            setting_type = "runtime-global",
            default_value = true,
            order = "a11",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."research",
            setting_type = "runtime-global",
            default_value = true,
            order = "a12",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."equip",
            setting_type = "runtime-global",
            default_value = true,
            order = "a13",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_action.."enter",
            setting_type = "runtime-global",
            default_value = true,
            order = "a15",
            hidden = true,
        },

        -- capture_ghost

        {
            type = "bool-setting",
            name = prefix_other.."capture_ghost",
            setting_type = "runtime-global",
            default_value = true,
            order = "o1",
            hidden = true,
        },

        -- other

        {
            type = "bool-setting",
            name = prefix_other.."always_add_to_end",
            setting_type = "runtime-global",
            default_value = true,
            order = "o2",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_other.."always_put_amount_bool",
            setting_type = "runtime-global",
            default_value = true,
            order = "o3",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix_other.."always_put_amount_value",
            setting_type = "runtime-global",
            default_value = 0,
            order = "o4",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_other.."always_put_half_amount_bool",
            setting_type = "runtime-global",
            default_value = true,
            order = "o3a",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix_other.."always_put_half_amount_value",
            setting_type = "runtime-global",
            default_value = 0,
            order = "o4a",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_other.."always_take_amount_bool",
            setting_type = "runtime-global",
            default_value = true,
            order = "o5",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix_other.."always_take_amount_value",
            setting_type = "runtime-global",
            default_value = 0,
            order = "o6",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_other.."always_take_half_amount_bool",
            setting_type = "runtime-global",
            default_value = true,
            order = "o5a",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix_other.."always_take_half_amount_value",
            setting_type = "runtime-global",
            default_value = 0,
            order = "o6a",
            hidden = true,
        },
        {
            type = "bool-setting",
            name = prefix_other.."combine_actions",
            setting_type = "runtime-global",
            default_value = true,
            order = "o7",
            hidden = true,
        },
        {
            type = "int-setting",
            name = prefix_other.."max_build_size",
            setting_type = "runtime-global",
            default_value = true,
            order = "o8",
            hidden = true,
        },
        {
            type = "string-setting",
            name = prefix_other.."color_export",
            setting_type = "runtime-global",
            default_value = "#afafaf",
            allow_blank = true,
            order = "o9",
            hidden = true,
        },
    }
)
