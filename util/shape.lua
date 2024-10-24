-- Based on: <https://github.com/BlingCorp/bling/blob/master/helpers/shape.lua>
local gears = require("gears")

local shape = {}

-- Create rounded rectangle shape (in one line)
function shape.rrect(radius)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

-- Create partially rounded rect
function shape.prrect(radius, tl, tr, br, bl)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

return shape
