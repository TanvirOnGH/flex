-----------------------------------------------------------------------------------------------------------------------
--                                                  flex library                                                  --
-----------------------------------------------------------------------------------------------------------------------

local wrequire = require("flex.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "flex.service" }

return setmetatable(lib, { __index = wrequire })
