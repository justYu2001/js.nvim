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

T["can_remove_braces()"] = MiniTest.new_set()

T["can_remove_braces()"]["returns true for return statement"] = function()
    child.set_lines("const f = (x) => { return x + 1 }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[
        require("js.refactor.arrow_function").can_remove_braces(0, 0, 20)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_remove_braces()"]["returns true for expression statement"] = function()
    child.set_lines("const f = (x) => { console.log(x) }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[
        require("js.refactor.arrow_function").can_remove_braces(0, 0, 20)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_remove_braces()"]["returns false for multiple statements"] = function()
    child.set_lines("const f = (x) => { console.log(x); return x }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[
        require("js.refactor.arrow_function").can_remove_braces(0, 0, 20)
    ]])

    MiniTest.expect.equality(result, false)
end

T["can_remove_braces()"]["returns false for bare return"] = function()
    child.set_lines("const f = () => { return }")

    child.set_cursor(1, 18)

    local result = child.lua_get([[
        require("js.refactor.arrow_function").can_remove_braces(0, 0, 18)
    ]])

    MiniTest.expect.equality(result, false)
end

T["can_remove_braces()"]["returns false when not on arrow function"] = function()
    child.set_lines("const x = 1")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.arrow_function").can_remove_braces(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, false)
end

T["create_brace_removal_edit()"] = MiniTest.new_set()

T["create_brace_removal_edit()"]["transforms return statement"] = function()
    child.set_lines("const f = (x) => { return x + 1 }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[(function()
        local af = require("js.refactor.arrow_function")
        local can, expr, arrow = af.can_remove_braces(0, 0, 20)
        if can then return af.create_brace_removal_edit(arrow, expr, 0) end
    end)()]])

    MiniTest.expect.equality(result, "(x) => x + 1")
end

T["create_brace_removal_edit()"]["transforms expression statement"] = function()
    child.set_lines("const f = (x) => { console.log(x) }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[(function()
        local af = require("js.refactor.arrow_function")
        local can, expr, arrow = af.can_remove_braces(0, 0, 20)
        if can then return af.create_brace_removal_edit(arrow, expr, 0) end
    end)()]])

    MiniTest.expect.equality(result, "(x) => console.log(x)")
end

T["create_brace_removal_edit()"]["wraps object return in parens"] = function()
    child.set_lines("const f = () => { return { a: 1 } }")

    child.set_cursor(1, 18)

    local result = child.lua_get([[(function()
        local af = require("js.refactor.arrow_function")
        local can, expr, arrow = af.can_remove_braces(0, 0, 18)
        if can then return af.create_brace_removal_edit(arrow, expr, 0) end
    end)()]])

    MiniTest.expect.equality(result, "() => ({ a: 1 })")
end

T["create_brace_removal_edit()"]["handles multiline object"] = function()
    child.set_lines({
        "const f = () => {",
        "  return {",
        "    a: 1,",
        "    b: 2,",
        "  }",
        "}",
    })

    child.set_cursor(1, 10)

    local result = child.lua_get([[(function()
        local af = require("js.refactor.arrow_function")
        local can, expr, arrow = af.can_remove_braces(0, 0, 10)
        if can then return af.create_brace_removal_edit(arrow, expr, 0) end
    end)()]])

    local expected = "() => ({\n    a: 1,\n    b: 2,\n  })"

    MiniTest.expect.equality(result, expected)
end

T["create_brace_removal_edit()"]["works with TypeScript type annotations"] = function()
    child.bo.filetype = "typescript"
    child.set_lines("const f = (x: number): number => { return x + 1 }")

    child.set_cursor(1, 35)

    local result = child.lua_get([[(function()
        local af = require("js.refactor.arrow_function")
        local can, expr, arrow = af.can_remove_braces(0, 0, 35)
        if can then return af.create_brace_removal_edit(arrow, expr, 0) end
    end)()]])

    MiniTest.expect.equality(result, "(x: number): number => x + 1")
end

return T
