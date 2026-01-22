local Helpers = dofile("tests/helpers.lua")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.bo.filetype = "javascript"
        end,
        post_once = child.stop,
    },
})

T["setup()"] = MiniTest.new_set()

T["setup()"]["loads without errors"] = function()
    local result = child.lua_get("pcall(require, 'js.snippets.scope_analyzer')")
    MiniTest.expect.equality(result, true)
end

T["normalize_expression_text"] = MiniTest.new_set()

T["normalize_expression_text"]["collapses whitespace"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "foo.bar(  1,   2  )" })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()
            local node = root:named_child(0):named_child(0) -- expression statement -> call expression

            return analyzer.normalize_expression_text(node, 0)
        end)()
    ]])

    MiniTest.expect.equality(result, "foo.bar( 1, 2 )")
end

T["expressions_equal"] = MiniTest.new_set()

T["expressions_equal"]["matches identical expressions"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "foo.bar()", "foo.bar()" })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            local expr1 = root:named_child(0):named_child(0)
            local expr2 = root:named_child(1):named_child(0)

            return analyzer.expressions_equal(expr1, expr2, 0)
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["expressions_equal"]["ignores whitespace differences"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "foo.bar(1,2)", "foo.bar( 1 , 2 )" })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            local expr1 = root:named_child(0):named_child(0)
            local expr2 = root:named_child(1):named_child(0)

            return analyzer.expressions_equal(expr1, expr2, 0)
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["expressions_equal"]["distinguishes different expressions"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "foo.bar()", "foo.baz()" })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            local expr1 = root:named_child(0):named_child(0)
            local expr2 = root:named_child(1):named_child(0)

            return analyzer.expressions_equal(expr1, expr2, 0)
        end)()
    ]])

    MiniTest.expect.equality(result, false)
end

T["find_identical_expressions"] = MiniTest.new_set()

T["find_identical_expressions"]["finds multiple occurrences"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const a = foo.bar() + foo.bar()",
    })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            -- Get first foo.bar() call
            local var_decl = root:named_child(0)
            local init = var_decl:named_child(0):field("value")[1]
            local binary = init
            local left = binary:field("left")[1]

            local occurrences = analyzer.find_identical_expressions(left, root, 0)
            return #occurrences
        end)()
    ]])

    MiniTest.expect.equality(result, 2)
end

T["find_enclosing_scope"] = MiniTest.new_set()

T["find_enclosing_scope"]["finds function scope"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "function test() {",
        "  const x = foo.bar()",
        "}",
    })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            -- Get foo.bar() node
            local func = root:named_child(0)
            local body = func:field("body")[1]
            local var_decl = body:named_child(0)
            local init = var_decl:named_child(0):field("value")[1]

            local scope = analyzer.find_enclosing_scope(init)
            return scope:type()
        end)()
    ]])

    MiniTest.expect.equality(result, "statement_block")
end

T["check_variable_exists"] = MiniTest.new_set()

T["check_variable_exists"]["detects existing variable"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const result = 1",
        "const x = 2",
    })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            return analyzer.check_variable_exists(root, "result", 0)
        end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["check_variable_exists"]["returns false for non-existent variable"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const result = 1",
    })

    local result = child.lua_get([[
        (function()
            local analyzer = require("js.snippets.scope_analyzer")
            local parser = vim.treesitter.get_parser(0, "javascript")
            local tree = parser:parse()[1]
            local root = tree:root()

            return analyzer.check_variable_exists(root, "nothere", 0)
        end)()
    ]])

    MiniTest.expect.equality(result, false)
end

return T
