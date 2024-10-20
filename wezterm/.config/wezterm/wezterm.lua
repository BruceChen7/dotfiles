local function enable_wayland()
	local wayland = os.getenv("XDG_SESSION_TYPE")
	if wayland ~= "wayland" then
		return false
	end
	return true
end
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
config.leader = { key = "Grave", timeout_milliseconds = 1000 }
config.enable_wayland = enable_wayland()
-- config.enable_tab_bar = false
config.keys = {
	-- splitting
	{ mods = "LEADER", key = "s", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ mods = "LEADER", key = "v", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ mods = "LEADER", key = "LeftArrow", action = wezterm.action.ActivatePaneDirection("Left") },
	{ mods = "LEADER", key = "RightArrow", action = wezterm.action.ActivatePaneDirection("Right") },
	{ mods = "LEADER", key = "UpArrow", action = wezterm.action.ActivatePaneDirection("Up") },
	{ mods = "LEADER", key = "DownArrow", action = wezterm.action.ActivatePaneDirection("Down") },
	-- { mods = "LEADER", key = "j", action = wezterm.action.ActivatePaneDirection("Down") },
	-- { mods = "LEADER", key = "k", action = wezterm.action.ActivatePaneDirection("Up") },
	-- { mods = "LEADER", key = "h", action = wezterm.action.ActivatePaneDirection("Left") },
	-- { mods = "LEADER", key = "l", action = wezterm.action.ActivatePaneDirection("Right") },
	{ mods = "LEADER", key = "p", action = wezterm.action.ActivateTabRelative(-1) },
	{ mods = "LEADER", key = "n", action = wezterm.action.ActivateTabRelative(1) },
	{ mods = "LEADER", key = "x", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
	{ mods = "LEADER", key = "X", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
	{ mods = "LEADER", key = "c", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{
		mods = "LEADER",
		key = "!",
		action = wezterm.action_callback(function(_win, pane)
			local _tab, _ = pane:move_to_new_tab()
		end),
	},
}

for i = 1, 9 do
	-- ALT + number to activate that tab
	table.insert(config.keys, {
		key = tostring(i),
		mods = "ALT",
		action = wezterm.action.ActivateTab(i - 1),
	})
end

config.font = wezterm.font({ family = "Iosevka Nerd Font Mono" })
config.font_size = 20
config.hide_tab_bar_if_only_one_tab = true
config.initial_cols = 180
config.initial_rows = 45
config.line_height = 1.2
config.macos_window_background_blur = 40
config.send_composed_key_when_left_alt_is_pressed = true -- MacOS Fix
config.use_fancy_tab_bar = false
config.warn_about_missing_glyphs = false
config.window_background_opacity = 0.94
config.window_close_confirmation = "NeverPrompt"
-- config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
-- config.window_padding = {
-- 	top = "1.5cell",
-- }
local w = require("wezterm")
local a = w.action

local function is_inside_vim(pane)
	local tty = pane:get_tty_name()
	if tty == nil then
		return false
	end

	local success, stdout, stderr = w.run_child_process({
		"sh",
		"-c",
		"ps -o state= -o comm= -t"
			.. w.shell_quote_arg(tty)
			.. " | "
			.. "grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)?$'",
	})

	return success
end

local function is_outside_vim(pane)
	return not is_inside_vim(pane)
end

local function bind_if(cond, key, mods, action)
	local function callback(win, pane)
		if cond(pane) then
			win:perform_action(action, pane)
		else
			win:perform_action(a.SendKey({ key = key, mods = mods }), pane)
		end
	end
	return { key = key, mods = mods, action = w.action_callback(callback) }
end
local jump_keys = {
	bind_if(is_outside_vim, "h", "CTRL", a.ActivatePaneDirection("Left")),
	bind_if(is_outside_vim, "l", "CTRL", a.ActivatePaneDirection("Right")),
	bind_if(is_outside_vim, "j", "CTRL", a.ActivatePaneDirection("Down")),
	bind_if(is_outside_vim, "k", "CTRL", a.ActivatePaneDirection("Up")),
}

for _, key in ipairs(jump_keys) do
	table.insert(config.keys, key)
end

-- config.color_scheme = "Builtin Solarized Dark"
-- config.tab_bar_at_bottom = true
config.color_scheme = "zenbones_dark"
return config
