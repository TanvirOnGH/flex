local setmetatable = setmetatable
local os = os
local textbox = require("wibox.widget.textbox")
local beautiful = require("beautiful")
local gears = require("gears")

local tooltip = require("flex.float.tooltip")
local modutil = require("flex.util")

-- Initialize tables and vars for module
local textclock = { mt = {} }

-- Generate default theme vars
local function default_style()
	local style = {
		font = "Fira Code 12",
		tooltip = {},
		color = { text = "#aaaaaa" },
	}
	return modutil.table.merge(style, modutil.table.check(beautiful, "widget.textclock") or {})
end

-- Create a textclock widget. It draws the time it is in a textbox.
-- @param format The time format. Default is " %a %b %d, %I:%M %p ".
-- @param timeout How often update the time. Default is 60.
-- @return A textbox widget
function textclock.new(args, style)
	-- Initialize vars
	args = args or {}
	local timeformat = args.timeformat or " %a %b %d, %I:%M %p "
	local timeout = args.timeout or 60
	style = modutil.table.merge(default_style(), style or {})

	-- Create widget
	local widg = textbox()
	widg:set_font(style.font)

	-- Set tooltip if need
	local tp
	if args.dateformat then
		tp = tooltip({ objects = { widg } }, style.tooltip)
	end

	-- Set update timer
	local timer = gears.timer({ timeout = timeout })
	timer:connect_signal("timeout", function()
		widg:set_markup('<span color="' .. style.color.text .. '">' .. os.date(timeformat) .. "</span>")
		if args.dateformat then
			tp:set_text(os.date(args.dateformat))
		end
	end)
	timer:start()
	timer:emit_signal("timeout")

	return widg
end

-- Config metatable to call textclock module as function
function textclock.mt:__call(...)
	return textclock.new(...)
end

return setmetatable(textclock, textclock.mt)
