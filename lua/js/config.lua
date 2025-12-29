local log = require("js.util.log")

local Js = {}

--- Js configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Js.options = {
    -- Prints useful logs about what event are triggered, and reasons actions are executed.
    debug = false,
}

---@private
local defaults = vim.deepcopy(Js.options)

--- Defaults Js options by merging user provided options with the default plugin values.
---
---@param options table Module config table. See |Js.options|.
---
---@private
function Js.defaults(options)
    Js.options =
        vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, defaults or {}))

    -- let your user know that they provided a wrong value, this is reported when your plugin is executed.
    assert(
        type(Js.options.debug) == "boolean",
        "`debug` must be a boolean (`true` or `false`)."
    )

    return Js.options
end

--- Define your js setup.
---
---@param options table Module config table. See |Js.options|.
---
---@usage `require("js").setup()` (add `{}` with your |Js.options| table)
function Js.setup(options)
    Js.options = Js.defaults(options or {})

    log.warn_deprecation(Js.options)

    return Js.options
end

return Js
