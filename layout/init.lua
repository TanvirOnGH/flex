-----------------------------------------------------------------------------------------------------------------------
--                                                  awsmx library                                                  --
-----------------------------------------------------------------------------------------------------------------------

local wrequire = require("awsmx.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "awsmx.layout" }

return setmetatable(lib, { __index = wrequire })
