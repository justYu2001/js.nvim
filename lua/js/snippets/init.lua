local M = {}

local registered = false

function M.setup()
    if registered then
        return
    end

    local ok, luasnip = pcall(require, "luasnip")

    if not ok then
        return
    end

    registered = true

    local const_snippets = require("js.snippets.const_postfix").get_snippets()

    local filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" }

    for _, ft in ipairs(filetypes) do
        luasnip.add_snippets(ft, const_snippets)
    end
end

return M
