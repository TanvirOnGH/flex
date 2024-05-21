local wrequire = require("flex.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "flex.float" }

return setmetatable(lib, { __index = wrequire })
