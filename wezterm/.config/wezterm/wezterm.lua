local wezterm = require("wezterm")
local function enable_wayland()
	local wayland = os.getenv("XDG_SESSION_TYPE")
	if wayland ~= "wayland" then
		return false
	end
	return true
end
return {
	enable_tab_bar = false,
	font_size = 15,
	use_ime = true,
	font = wezterm.font("JetBrainsMono Nerd Font"),
	enable_wayland = enable_wayland(),
	keys = {
		{ key = "c", mods = "CTRL", action = wezterm.action({ CopyTo = "ClipboardAndPrimarySelection" }) },
		{ key = " ", mods = "ALT", action = "Nop" },
	},

	window_background_opacity = 0.9,
}
