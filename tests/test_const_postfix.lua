local Helpers = dofile("tests/helpers.lua")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })

            child.bo.filetype = "javascript"

            child.lua([[require("js.snippets").setup()]])
        end,
        post_once = child.stop,
    },
})

T["setup()"] = MiniTest.new_set()

T["setup()"]["loads without errors"] = function()
    local result = child.lua_get("pcall(require, 'js.snippets.const_postfix')")

    MiniTest.expect.equality(result, true)
end

T["setup()"]["get_snippets returns table"] = function()
    local result = child.lua_get([[
        (function()
            local snippets = require("js.snippets.const_postfix").get_snippets()
            return type(snippets) == "table" and #snippets > 0
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet registration"] = MiniTest.new_set()

T["snippet registration"]["registers for javascript"] = function()
    local result = child.lua_get([[
        (function()
            local ls = require("luasnip")
            local snippets = ls.get_snippets("javascript")
            return snippets ~= nil and #snippets > 0
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet registration"]["registers for typescript"] = function()
    child.bo.filetype = "typescript"
    child.lua([[require("js.snippets").setup()]])

    local result = child.lua_get([[
        (function()
            local ls = require("luasnip")
            local snippets = ls.get_snippets("typescript")
            return snippets ~= nil and #snippets > 0
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet registration"]["registers for javascriptreact"] = function()
    child.bo.filetype = "javascriptreact"
    child.lua([[require("js.snippets").setup()]])

    local result = child.lua_get([[
        (function()
            local ls = require("luasnip")
            local snippets = ls.get_snippets("javascriptreact")
            return snippets ~= nil and #snippets > 0
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet registration"]["registers for typescriptreact"] = function()
    child.bo.filetype = "typescriptreact"
    child.lua([[require("js.snippets").setup()]])

    local result = child.lua_get([[
        (function()
            local ls = require("luasnip")
            local snippets = ls.get_snippets("typescriptreact")
            return snippets ~= nil and #snippets > 0
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet structure"] = MiniTest.new_set()

T["snippet structure"]["snippet is valid"] = function()
    local result = child.lua_get([[
        (function()
            local snippets = require("js.snippets.const_postfix").get_snippets()
            if not snippets or #snippets == 0 then return false end
            local snippet = snippets[1]
            -- Check that snippet has basic required fields
            return type(snippet) == "table" and snippet ~= nil
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["snippet structure"]["can be registered without error"] = function()
    local result = child.lua_get([[
        (function()
            local ok = pcall(function()
                local ls = require("luasnip")
                local snippets = require("js.snippets.const_postfix").get_snippets()
                ls.add_snippets("javascript", snippets)
            end)
            return ok
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

return T
