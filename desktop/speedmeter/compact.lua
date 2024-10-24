-- Grab environment
local setmetatable = setmetatable

local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")
local unpack = unpack or table.unpack

local system = require("flex.system")
local modutil = require("flex.util")
local dcommon = require("flex.desktop.common")
local svgbox = require("flex.gauge.svgbox")

-- Initialize tables for module
local speedmeter = { mt = {} }

-- Generate default theme vars
local function default_style()
	local style = {
		icon = { margin = { 0, 0, 0, 0 } },
		label = { width = 100 },
		margins = { label = { 0, 0, 0, 0 }, chart = { 0, 0, 2, 2 } },
		progressbar = { chunk = { width = 10, gap = 5 }, height = 4 },
		chart = {},
		height = { chart = 50 },
		digits = 2,
		unit = { { "B", -1 }, { "KB", 1024 }, { "MB", 1024 ^ 2 }, { "GB", 1024 ^ 3 } },
		color = { main = "#C38F8F", wibox = "#161616", gray = "#404040" },
	}
	return modutil.table.merge(style, modutil.table.check(beautiful, "desktop.speedmeter.compact") or {})
end

local default_args = {
	autoscale = true,
	label = "NETWORK",
	timeout = 5,
	interface = "enp42s0",
	meter_function = system.net_speed,
}

local default_maxspeed = { up = 10 * 1024, down = 10 * 1024 }

-- Support functions
-- Construct chart with support elements
local function value_chart(style, image, maxspeed)
	local chart = dcommon.chart(modutil.table.merge(style.chart, { maxm = maxspeed }))
	local progressbar = dcommon.bar.plain(modutil.table.merge(style.progressbar, { maxm = maxspeed }))

	local text = dcommon.textbox("", style.label)
	local icon = image and svgbox(image) or nil

	local area = wibox.widget({
		progressbar,
		{
			{
				nil,
				wibox.container.margin(text, unpack(style.margins.label)),
				nil,
				expand = "outside",
				layout = wibox.layout.align.vertical,
			},
			wibox.container.margin(chart, unpack(style.margins.chart)),
			nil,
			layout = wibox.layout.align.horizontal,
		},
		progressbar,
		forced_height = style.height.chart,
		layout = wibox.layout.align.vertical,
	})

	if image then
		icon:set_color(style.color.gray)
		area = wibox.widget({
			wibox.container.margin(icon, unpack(style.icon.margin)),
			area,
			nil,
			forced_height = style.height.chart,
			layout = wibox.layout.align.horizontal,
		})
	end

	return { chart = chart, progressbar = progressbar, text = text, icon = icon, area = area }
end

-- Create a new speed meter widget
function speedmeter.new(args, style)
	-- Initialize vars
	local dwidget = {}
	local storage = {}
	local last_state = { false, false }

	args = modutil.table.merge(default_args, args or {})
	style = modutil.table.merge(default_style(), style or {})
	local maxspeed = modutil.table.merge(default_maxspeed, args.maxspeed or {})

	style.chart = modutil.table.merge(style.chart, { autoscale = args.autoscale, color = style.color.gray })
	style.progressbar = modutil.table.merge(style.progressbar, { autoscale = args.autoscale, color = style.color })
	style.label = modutil.table.merge(style.label, { draw = "by_edges", color = style.color.gray })

	dwidget.style = style

	-- Construct indicators
	local widg = { {}, {} }
	local placement = { "up", "down" }

	for i = 1, 2 do
		widg[i] = value_chart(style, style.icon[placement[i]], maxspeed[placement[i]])
	end

	dwidget.area = wibox.widget({
		widg[1].area,
		nil,
		widg[2].area,
		layout = wibox.layout.align.vertical,
	})

	-- Update info
	local function update()
		local state = args.meter_function(args.interface, storage)

		for i = 1, 2 do
			widg[i].chart:set_value(state[i])
			widg[i].progressbar:set_value(state[i])
			widg[i].text:set_text(modutil.text.dformat(state[i], style.unit, style.digits))

			if widg[i].icon and args.crit then
				local st = state[i] > args.crit[placement[i]]
				if st ~= last_state[i] then
					local newc = st and style.color.main or style.color.gray
					widg[i].icon:set_color(newc)
					widg[i].text:set_color(newc)
					last_state[i] = st
				end
			end
		end
	end

	-- Set update timer
	local t = timer({ timeout = args.timeout })
	t:connect_signal("timeout", update)
	t:start()
	t:emit_signal("timeout")

	return dwidget
end

-- Config metatable to call module as function
function speedmeter.mt:__call(...)
	return speedmeter.new(...)
end

return setmetatable(speedmeter, speedmeter.mt)
