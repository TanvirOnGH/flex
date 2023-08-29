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
local purpletag = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		width = 50,
		base = { pad = 5, height = 12, thickness = 2 },
		mark = { pad = 10, height = 4 },
		color = { main = "#C38F8F", gray = "#575757", icon = "#a0a0a0", urgent = "#CE9C9C" },
	}

	return modutil.table.merge(style, modutil.table.check(beautiful, "gauge.tag.rosybrown") or {})
end

-- Create a new tag widget
-- @param style Table containing colors and geometry parameters for all elemets
-----------------------------------------------------------------------------------------------------------------------
function purpletag.new(style)
	-- Initialize vars
	--------------------------------------------------------------------------------
	style = modutil.table.merge(default_style(), style or {})

	-- updating values
	local data = {
		width = style.width or nil,
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
	function widg:draw(_, cr, width, height)
		-- state
		local cl = data.state.active and style.color.main or style.color.gray
		cr:set_source(color(cl))

		cr:rectangle(
			style.base.pad,
			math.floor((height - style.base.height) / 2),
			width - 2 * style.base.pad,
			style.base.height
		)
		cr:set_line_width(style.base.thickness)
		cr:stroke()

		-- focus
		cl = data.state.focus and style.color.main
			or data.state.urgent and style.color.urgent
			or (data.state.occupied and style.color.icon or style.color.gray)
		cr:set_source(color(cl))

		cr:rectangle(
			style.mark.pad,
			math.floor((height - style.mark.height) / 2),
			width - 2 * style.mark.pad,
			style.mark.height
		)

		cr:fill()
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call purpletag module as function
-----------------------------------------------------------------------------------------------------------------------
function purpletag.mt:__call(...)
	return purpletag.new(...)
end

return setmetatable(purpletag, purpletag.mt)
