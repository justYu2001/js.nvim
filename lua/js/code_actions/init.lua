local M = {}

local registered = false

---@param null_ls table The null-ls module
function M.setup(null_ls)
    if registered then
        return
    end

    registered = true

    local sources = M.get_sources(null_ls)

    for _, source in ipairs(sources) do
        null_ls.register(source)
    end
end

---@param null_ls table The null-ls module
---@return table[] List of source definitions
function M.get_sources(null_ls)
    return {
        require("js.code_actions.remove_arrow_braces").get_source(null_ls),
        require("js.code_actions.function_to_arrow").get_source(null_ls),
    }
end

return M
