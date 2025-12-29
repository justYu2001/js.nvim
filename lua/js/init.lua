local main = require("js.main")
local config = require("js.config")

local Js = {}

--- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function Js.toggle()
    if _G.Js.config == nil then
        _G.Js.config = config.options
    end

    main.toggle("public_api_toggle")
end

--- Initializes the plugin, sets event listeners and internal state.
function Js.enable(scope)
    if _G.Js.config == nil then
        _G.Js.config = config.options
    end

    main.toggle(scope or "public_api_enable")
end

--- Disables the plugin, clear highlight groups and autocmds, closes side buffers and resets the internal state.
function Js.disable()
    main.toggle("public_api_disable")
end

-- setup Js options and merge them with user provided ones.
function Js.setup(opts)
    _G.Js.config = config.setup(opts)
end

_G.Js = Js

return _G.Js
