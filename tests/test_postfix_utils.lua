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

T["is_braceless_arrow_body()"] = MiniTest.new_set()

T["is_braceless_arrow_body()"]["returns true for simple braceless arrow"] = function()
    child.set_lines("const f = (x) => x + 1")
    child.set_cursor(1, 18) -- cursor in "x + 1"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns false for braced arrow body"] = function()
    child.set_lines("const f = (x) => { return x + 1 }")
    child.set_cursor(1, 24) -- cursor in statement_block

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, false)
end

T["is_braceless_arrow_body()"]["returns false when not in arrow function"] = function()
    child.set_lines("const x = 1 + 2")
    child.set_cursor(1, 10)

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, false)
end

T["is_braceless_arrow_body()"]["returns true for braceless arrow in map"] = function()
    child.set_lines("[1,2,3].map((n) => n * 2)")
    child.set_cursor(1, 20) -- cursor in "n * 2"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns false for braced arrow in map"] = function()
    child.set_lines("[1,2,3].map((n) => { return n * 2 })")
    child.set_cursor(1, 28) -- cursor in statement_block

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, false)
end

T["is_braceless_arrow_body()"]["returns true for nested braceless arrow"] = function()
    child.set_lines("const f = (x) => (y) => y + 1")
    child.set_cursor(1, 26) -- cursor in inner arrow "y + 1"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns true for braceless arrow with object return"] = function()
    child.set_lines("const f = (x) => ({ a: x })")
    child.set_cursor(1, 23) -- cursor in object

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns true when cursor in parameters of braceless arrow"] = function()
    child.set_lines("const f = (x) => x + 1")
    child.set_cursor(1, 12) -- cursor in "(x)"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns true for multiline braceless arrow"] = function()
    child.set_lines({
        "const f = (x) => (",
        "  x + 1",
        ")",
    })
    child.set_cursor(2, 2) -- cursor in "x + 1"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns true for binary expression in braceless arrow"] = function()
    child.set_lines("const f = (x) => x + 1")
    child.set_cursor(1, 21) -- cursor at "1" in "x + 1"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns true for TypeScript braceless arrow with types"] = function()
    child.bo.filetype = "typescript"
    child.set_lines("const f = (x: number): number => x + 1")
    child.set_cursor(1, 36) -- cursor in "x + 1"

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

T["is_braceless_arrow_body()"]["returns false for TypeScript braced arrow with types"] = function()
    child.bo.filetype = "typescript"
    child.set_lines("const f = (x: number): number => { return x + 1 }")
    child.set_cursor(1, 44) -- cursor in statement_block

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, false)
end

T["is_braceless_arrow_body()"]["returns false for empty buffer"] = function()
    child.set_lines("")
    child.set_cursor(1, 0)

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, false)
end

T["is_braceless_arrow_body()"]["returns true for ternary in braceless arrow"] = function()
    child.set_lines("const f = (x) => x > 0 ? x : -x")
    child.set_cursor(1, 25) -- cursor in ternary

    local result = child.lua_get([[
        require("js.snippets.postfix_utils").is_braceless_arrow_body()
    ]])

    MiniTest.expect.equality(result, true)
end

return T
