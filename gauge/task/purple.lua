-----------------------------------------------------------------------------------------------------------------------
--                                                   flex tag widget                                              --
-----------------------------------------------------------------------------------------------------------------------
-- Custom widget to display tag info
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local math = math

local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require("gears.color")

local modutil = require("flex.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local purpletask = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		width      = 80,
		font       = { font = "Fira Code", size = 16, face = 0, slant = 0 },
		text_shift = 26,
		point      = { size = 4, space = 3, gap = 3 },
		underline  = { height = 20, thickness = 4, gap = 36, dh = 4 },
		color      = { main  = "#5906D3", gray = "#575757", icon = "#a0a0a0", urgent = "#864DDC" }
	}

	return modutil.table.merge(style, modutil.table.check(beautiful, "gauge.task.purple") or {})
end


-- Create a new tag widget
-- @param style Table containing colors and geometry parameters for all elemets
-----------------------------------------------------------------------------------------------------------------------
function purpletask.new(style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	style = modutil.table.merge(default_style(), style or {})

	-- updating values
	local data = {
		state = { text = "TEXT" },
		width = style.width or nil
	}

	-- Create custom widget
	--------------------------------------------------------------------------------
	local widg = wibox.widget.base.make_widget()

	-- User functions
	------------------------------------------------------------
	function widg:set_state(state)
		data.state = state
		self:emit_signal("widget::redraw_needed")
	end

	function widg:set_width(width)
		data.width = width
		self:emit_signal("widget::redraw_needed")
	end

	-- Fit
	------------------------------------------------------------
	function widg:fit(_, width, height)
		if data.width then
			return math.min(width, data.width), height
		else
			return width, height
		end
	end

	-- Draw
	------------------------------------------------------------
	function widg:draw(_, cr, width)
		local n = #data.state.list

		-- text
		cr:set_source(color(
			data.state.active and style.color.main
			or data.state.minimized and style.color.gray
			or style.color.icon
		))
		modutil.cairo.set_font(cr, style.font)
		modutil.cairo.textcentre.horizontal(cr, { width / 2, style.text_shift }, data.state.text)

		-- underline
		cr:set_source(color(
			data.state.focus and style.color.main
			or data.state.minimized and style.color.gray
			or style.color.icon
		))

		cr:move_to(0, style.underline.gap)
		cr:rel_line_to(width, 0)
		cr:rel_line_to(0, -style.underline.height)
		cr:rel_line_to(-style.underline.thickness, style.underline.dh)
		cr:rel_line_to(0, style.underline.height - style.underline.dh - style.underline.thickness)
		cr:rel_line_to(2 * style.underline.thickness - width, 0)
		cr:rel_line_to(0, style.underline.thickness + style.underline.dh - style.underline.height)
		cr:rel_line_to(-style.underline.thickness, - style.underline.dh)
		cr:close_path(-style.underline.thickness, 0)
		cr:fill()

		-- clients counter
		local x = math.floor((width - style.point.size * n - style.point.space * (n - 1)) / 2)
		local l = style.point.size + style.point.space

		for i = 1, n do
			cr:set_source(color(
				data.state.list[i].focus and style.color.main or
				data.state.list[i].urgent and style.color.urgent or
				data.state.list[i].minimized and style.color.gray or
				style.color.icon
			))
			cr:rectangle(x + (i - 1) * l, style.point.gap, style.point.size, style.point.size)
			cr:fill()
		end
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call purpletask module as function
-----------------------------------------------------------------------------------------------------------------------
function purpletask.mt:__call(...)
	return purpletask.new(...)
end

return setmetatable(purpletask, purpletask.mt)
