-----------------------------------------------------------------------------------------------------------------------
--                                                   flex library                                                 --
-----------------------------------------------------------------------------------------------------------------------

local wrequire = require("flex.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "flex.desktop.speedmeter" }

return setmetatable(lib, { __index = wrequire })
