-- Grab environment
local setmetatable = setmetatable
local math = math
local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require("gears.color")

local modutil = require("flex.util")

-- Initialize tables for module
local counter = { mt = {} }

-- Generate default theme vars
local function default_style()
	local style = {
		column_num = { 2, 5 }, -- {min, max}
		row_num = 3,
		dot_size = 5,
		dot_gap_h = 5,
		color = { main = "#C38F8F", gray = "#575757" },
	}
	return modutil.table.merge(style, modutil.table.check(beautiful, "gauge.graph.dots") or {})
end

-- Create a new counter widget
-- @param style Table containing colors and geometry parameters for all elemets
function counter.new(style)
	-- Initialize vars
	style = modutil.table.merge(default_style(), style or {})

	-- Create custom widget
	local widg = wibox.widget.base.make_widget()
	widg._data = {
		count_num = 0,
		column_num = style.column_num[1],
	}

	-- User functions
	function widg:set_num(num)
		if num ~= self._data.count_num then
			self._data.count_num = num
			self._data.column_num =
				math.min(math.max(style.column_num[1], math.ceil(num / style.row_num)), style.column_num[2])
			self:emit_signal("widget::redraw_needed")
		end
	end

	-- Fit
	function widg:fit(_, _, height)
		local width = (style.dot_size + style.dot_gap_h) * self._data.column_num - style.dot_gap_h
		return width, height
	end

	-- Draw
	function widg:draw(_, cr, width, height)
		--		local maxnum = style.row_num * data.column_num
		local gap_v = (height - style.row_num * style.dot_size) / (style.row_num - 1)

		cr:translate(0, height)
		for i = 1, style.row_num do
			for j = 1, self._data.column_num do
				local cc = (j + (i - 1) * self._data.column_num) <= self._data.count_num and style.color.main
					or style.color.gray
				cr:set_source(color(cc))

				cr:rectangle(0, 0, style.dot_size, -style.dot_size)
				cr:fill()

				cr:translate(style.dot_size + style.dot_gap_h, 0)
			end
			cr:translate(-(style.dot_gap_h + width), -(style.dot_size + gap_v))
		end
	end

	return widg
end

-- Config metatable to call dotcount module as function
function counter.mt:__call(...)
	return counter.new(...)
end

return setmetatable(counter, counter.mt)
