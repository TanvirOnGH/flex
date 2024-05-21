local wrequire = require("flex.util").wrequire
local setmetatable = setmetatable

local lib = { _NAME = "flex.desktop" }

return setmetatable(lib, { __index = wrequire })
