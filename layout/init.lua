local wrequire = require("flex.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "flex.layout" }

return setmetatable(lib, { __index = wrequire })
