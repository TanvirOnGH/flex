-- Grab environment
local unpack = unpack or table.unpack

local beautiful = require("beautiful")
local awful = require("awful")
local wibox = require("wibox")

local modutil = require("flex.util")
local modtitle = require("flex.titlebar")
local modtip = require("flex.float.hotkeys")
local svgbox = require("flex.gauge.svgbox")

-- Initialize tables for module
local bartip = {}

-- Generate default theme vars
local function default_style()
	local style = {
		geometry = { width = 400, height = 60 },
		border_width = 2,
		font = "Fira Code 14",
		set_position = nil,
		names = {},
		keytip = { geometry = { width = 600 } },
		shape = nil,
		margin = { icon = { title = { 10, 10, 2, 2 }, state = { 10, 10, 2, 2 } } },
		icon = {
			title = modutil.base.placeholder({ txt = "[]" }),
			active = modutil.base.placeholder({ txt = "+" }),
			absent = modutil.base.placeholder({ txt = "!" }),
			disabled = modutil.base.placeholder({ txt = "X" }),
			hidden = modutil.base.placeholder({ txt = "*" }),
			unknown = modutil.base.placeholder({ txt = "?" }),
		},
		color = {
			border = "#575757",
			text = "#aaaaaa",
			main = "#C38F8F",
			wibox = "#202020",
			gray = "#575757",
			icon = "#a0a0a0",
		},
	}

	return modutil.table.merge(style, modutil.table.check(beautiful, "float.bartip") or {})
end

-- key bindings
bartip.keys = {}
bartip.keys.bar = {
	{
		{ "Mod4" },
		"b",
		function()
			modtitle.toggle(client.focus)
			bartip:update()
		end,
		{ description = "Show/hide titlebar for focused client", group = "Titlebar control" },
	},
	{
		{ "Mod4" },
		"a",
		function()
			modtitle.toggle_all()
			bartip:update()
		end,
		{ description = "Show/hide titlebar for all clients", group = "Titlebar control" },
	},
	--{
	--	{ "Mod4" }, "v", function() modtitle.switch(client.focus); bartip:update() end,
	--	{ description = "Switch titlebar view for focused client", group = "Titlebar control" }
	--},
	{
		{ "Mod4" },
		"n",
		function()
			modtitle.global_switch()
			bartip:update()
		end,
		{ description = "Switch titlebar view for all clients", group = "Titlebar control" },
	},
}
bartip.keys.action = {
	{
		{ "Mod4" },
		"Super_L",
		function()
			bartip:hide()
		end,
		{ description = "Close top list widget", group = "Action" },
	},
	{
		{ "Mod4" },
		"F1",
		function()
			modtip:show()
		end,
		{ description = "Show hotkeys helper", group = "Action" },
	},
}

bartip.keys.all = awful.util.table.join(bartip.keys.bar, bartip.keys.action)

-- Initialize widget
function bartip:init()
	-- Initialize vars
	local style = default_style()
	self.style = style

	-- Create floating wibox for top widget
	self.wibox = wibox({
		ontop = true,
		bg = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border,
		shape = style.shape,
	})

	self.wibox:geometry(style.geometry)

	-- Widget layout setup
	self.label = wibox.widget.textbox()
	self.label:set_align("center")
	self.label:set_font(style.font)

	local title_icon = svgbox(self.style.icon.title)
	title_icon:set_color(self.style.color.icon)

	self.state_icon = svgbox()

	--self.wibox:set_widget(self.label)
	self.wibox:setup({
		wibox.container.margin(title_icon, unpack(self.style.margin.icon.title)),
		self.label,
		wibox.container.margin(self.state_icon, unpack(self.style.margin.icon.state)),
		layout = wibox.layout.align.horizontal,
	})

	-- Keygrabber
	self.keygrabber = function(mod, key, event)
		if event == "release" then
			for _, k in ipairs(self.keys.action) do
				if modutil.key.match_grabber(k, mod, key) then
					k[3]()
					return
				end
			end
		else
			for _, k in ipairs(self.keys.all) do
				if modutil.key.match_grabber(k, mod, key) then
					k[3]()
					return
				end
			end
		end
	end

	-- First run actions
	self:set_keys()
end

-- Widget actions
local function get_title_state(c)
	if not c then
		return "unknown"
	end

	local model = modtitle.get_model(c)
	local state = not model and "absent" or model.hidden and "disabled" or model.cutted and "hidden" or "active"

	return state, model and model.size or nil
end

-- Update
function bartip:update()
	local name = self.style.names[modtitle._index] or "Unknown"
	local state, size = get_title_state(client.focus)
	local size_mark = size and string.format(" [%d]", size) or ""

	self.label:set_markup(
		string.format(
			'<span color="%s">%s</span><span color="%s">%s</span>',
			self.style.color.text,
			name,
			self.style.color.gray,
			size_mark
		)
	)

	self.state_icon:set_image(self.style.icon[state])
	self.state_icon:set_color(state == "absent" and self.style.color.main or self.style.color.icon)
end

-- Show
function bartip:show()
	if not self.wibox then
		self:init()
	end

	if not self.wibox.visible then
		if self.style.set_position then
			self.style.set_position(self.wibox)
		else
			modutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
		end
		modutil.placement.no_offscreen(self.wibox, self.style.screen_gap, screen[mouse.screen].workarea)

		self:update()
		self.wibox.visible = true
		awful.keygrabber.run(self.keygrabber)
		modtip:set_pack("Titlebar", self.tip, self.style.keytip.column, self.style.keytip.geometry, function()
			self:hide()
		end)
	end
end

-- Hide
function bartip:hide()
	self.wibox.visible = false
	awful.keygrabber.stop(self.keygrabber)
	modtip:remove_pack()
end

-- Set user hotkeys
function bartip:set_keys(keys, layout)
	layout = layout or "all"
	if keys then
		self.keys[layout] = keys
		if layout ~= "all" then
			self.keys.all = awful.util.table.join(self.keys.bar, self.keys.action)
		end
	end

	self.tip = self.keys.all
end

return bartip
