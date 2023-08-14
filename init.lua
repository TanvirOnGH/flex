-----------------------------------------------------------------------------------------------------------------------
--                                                   awsmx library                                                 --
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable

return setmetatable(
	{ _NAME = "awsmx" },
	{ __index = function(table, key)
		local module = rawget(table, key)
		return module or require(table._NAME .. '.' .. key)
	end }
)
