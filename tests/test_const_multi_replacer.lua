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
    local result = child.lua_get("pcall(require, 'js.snippets.const_multi_replacer')")
    MiniTest.expect.equality(result, true)
end

T["apply_multi_replacement"] = MiniTest.new_set()

T["apply_multi_replacement"]["updates existing const declaration with variable name"] = function()
    -- Simulate the state after LuaSnip creates "const  = 0" (with empty var name)
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "const x = 0 + 1",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },  -- The "0" in const declaration
            { row = 1, col = 10, end_row = 1, end_col = 11 }, -- The "0" in second line
        }
        -- Mock scope_node (not used in the fixed implementation for const row detection)
        local scope_node = nil
        replacer.apply_multi_replacement(occurrences, "myVar", "0", 0)
    ]])

    local lines = child.get_lines()

    -- First line should have variable name inserted
    MiniTest.expect.equality(lines[1], "const myVar = 0")
    -- Second line should have occurrence replaced
    MiniTest.expect.equality(lines[2], "const x = myVar + 1")
end

T["apply_multi_replacement"]["does not insert new const declaration"] = function()
    -- Ensure no extra lines are added
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "const x = 0",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },
            { row = 1, col = 10, end_row = 1, end_col = 11 },
        }
        replacer.apply_multi_replacement(occurrences, "testVar", "0", 0)
    ]])

    local lines = child.get_lines()

    -- Should still be exactly 2 lines (no new line inserted)
    MiniTest.expect.equality(#lines, 2)
    MiniTest.expect.equality(lines[1], "const testVar = 0")
    MiniTest.expect.equality(lines[2], "const x = testVar")
end

T["apply_multi_replacement"]["filters out trigger occurrence from replacements"] = function()
    -- The occurrence on the const declaration row should not be replaced
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "console.log(0)",
        "return 0",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },  -- In const decl - should be filtered
            { row = 1, col = 12, end_row = 1, end_col = 13 }, -- In console.log
            { row = 2, col = 7, end_row = 2, end_col = 8 },   -- In return
        }
        replacer.apply_multi_replacement(occurrences, "val", "0", 0)
    ]])

    local lines = child.get_lines()

    -- Const line gets var name but expression stays as "0"
    MiniTest.expect.equality(lines[1], "const val = 0")
    -- Other occurrences get replaced
    MiniTest.expect.equality(lines[2], "console.log(val)")
    MiniTest.expect.equality(lines[3], "return val")
end

T["apply_multi_replacement"]["handles indented const declaration"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "function test() {",
        "    const  = 0",
        "    return 0",
        "}",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 1, col = 13, end_row = 1, end_col = 14 },  -- "0" in const
            { row = 2, col = 11, end_row = 2, end_col = 12 },  -- "0" in return
        }
        replacer.apply_multi_replacement(occurrences, "num", "0", 0)
    ]])

    local lines = child.get_lines()

    MiniTest.expect.equality(lines[2], "    const num = 0")
    MiniTest.expect.equality(lines[3], "    return num")
end

T["apply_multi_replacement"]["replaces multiple occurrences on same line"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "const sum = 0 + 0",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },   -- In const decl
            { row = 1, col = 12, end_row = 1, end_col = 13 },  -- First 0
            { row = 1, col = 16, end_row = 1, end_col = 17 },  -- Second 0
        }
        replacer.apply_multi_replacement(occurrences, "zero", "0", 0)
    ]])

    local lines = child.get_lines()

    MiniTest.expect.equality(lines[1], "const zero = 0")
    MiniTest.expect.equality(lines[2], "const sum = zero + zero")
end

T["apply_multi_replacement"]["handles complex expressions"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = foo.bar()",
        "const x = foo.bar() + 1",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 18 },   -- foo.bar() in const
            { row = 1, col = 10, end_row = 1, end_col = 19 },  -- foo.bar() in second line
        }
        replacer.apply_multi_replacement(occurrences, "result", "foo.bar()", 0)
    ]])

    local lines = child.get_lines()

    MiniTest.expect.equality(lines[1], "const result = foo.bar()")
    MiniTest.expect.equality(lines[2], "const x = result + 1")
end

T["apply_multi_replacement"]["positions cursor at end of const line"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "return 0",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },
            { row = 1, col = 7, end_row = 1, end_col = 8 },
        }
        replacer.apply_multi_replacement(occurrences, "num", "0", 0)
    ]])

    local cursor = child.get_cursor()
    local line = child.get_lines()[1]

    -- Cursor should be at end of first line (1-indexed row, 0-indexed col)
    MiniTest.expect.equality(cursor[1], 1)
    MiniTest.expect.equality(cursor[2], #line)
end

T["apply_multi_replacement"]["enters insert mode"] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "const  = 0",
        "return 0",
    })

    child.lua([[
        local replacer = require("js.snippets.const_multi_replacer")
        local occurrences = {
            { row = 0, col = 9, end_row = 0, end_col = 10 },
            { row = 1, col = 7, end_row = 1, end_col = 8 },
        }
        replacer.apply_multi_replacement(occurrences, "num", "0", 0)
    ]])

    local mode = child.lua_get("vim.api.nvim_get_mode().mode")

    -- Mode should be insert ("i")
    MiniTest.expect.equality(mode, "i")
end

return T
