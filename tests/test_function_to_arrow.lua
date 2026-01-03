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

T["can_convert_to_arrow()"] = MiniTest.new_set()

T["can_convert_to_arrow()"]["returns true for function declaration"] = function()
    child.set_lines("function foo(x) { return x + 1 }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns true when cursor on const keyword"] = function()
    child.set_lines("const foo = function(x) { return x + 1 }")

    child.set_cursor(1, 0)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 0)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns true when cursor on variable name"] = function()
    child.set_lines("const foo = function(x) { return x + 1 }")

    child.set_cursor(1, 6)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 6)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns true for function expression"] = function()
    child.set_lines("const f = function(x) { return x + 1 }")

    child.set_cursor(1, 15)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 15)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns true for method definition"] = function()
    child.set_lines("const obj = { method() { return 1 } }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 20)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns false for generator function"] = function()
    child.set_lines("function* foo() { yield 1 }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, false)
end

T["can_convert_to_arrow()"]["returns false for function using this"] = function()
    child.set_lines("function foo() { return this.value }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, false)
end

T["can_convert_to_arrow()"]["returns false for function using arguments"] = function()
    child.set_lines("function foo() { return arguments[0] }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, false)
end

T["can_convert_to_arrow()"]["returns true for named function expression"] = function()
    child.set_lines("const f = function bar() { return 1 }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 20)
    ]])

    MiniTest.expect.equality(result, true)
end

T["can_convert_to_arrow()"]["returns false when not on function"] = function()
    child.set_lines("const x = 1")

    child.set_cursor(1, 5)

    local result = child.lua_get([[
        require("js.refactor.regular_function").can_convert_to_arrow(0, 0, 5)
    ]])

    MiniTest.expect.equality(result, false)
end

T["create_arrow_conversion_edit()"] = MiniTest.new_set()

T["create_arrow_conversion_edit()"]["converts function declaration"] = function()
    child.set_lines("function foo(x) { return x + 1 }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = (x) => x + 1")
end

T["create_arrow_conversion_edit()"]["converts async function declaration"] = function()
    child.set_lines("async function foo() { return 1 }")

    child.set_cursor(1, 15)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 15)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = async () => 1")
end

T["create_arrow_conversion_edit()"]["converts function expression"] = function()
    child.set_lines("const f = function(x) { return x + 1 }")

    child.set_cursor(1, 15)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 15)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "(x) => x + 1")
end

T["create_arrow_conversion_edit()"]["converts named function expression dropping name"] = function()
    child.set_lines("const f = function bar(x) { return x + 1 }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 20)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "(x) => x + 1")
end

T["create_arrow_conversion_edit()"]["converts method definition"] = function()
    child.set_lines("const obj = { method() { return 1 } }")

    child.set_cursor(1, 20)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 20)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "method: () => 1")
end

T["create_arrow_conversion_edit()"]["wraps object return in parens"] = function()
    child.set_lines("function foo() { return { a: 1 } }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = () => ({ a: 1 })")
end

T["create_arrow_conversion_edit()"]["handles multiline body"] = function()
    child.set_lines({
        "function foo(x) {",
        "  console.log(x)",
        "  return x + 1",
        "}",
    })

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    local expected = "const foo = (x) => {\n  console.log(x)\n  return x + 1\n}"

    MiniTest.expect.equality(result, expected)
end

T["create_arrow_conversion_edit()"]["works with TypeScript type annotations"] = function()
    child.bo.filetype = "typescript"
    child.set_lines("function foo(x: number): number { return x + 1 }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = (x: number): number => x + 1")
end

T["create_arrow_conversion_edit()"]["handles no parameters"] = function()
    child.set_lines("function foo() { return 1 }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = () => 1")
end

T["create_arrow_conversion_edit()"]["handles single parameter with parens"] = function()
    child.set_lines("function foo(x) { return x }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = (x) => x")
end

T["create_arrow_conversion_edit()"]["handles expression statement"] = function()
    child.set_lines("function foo(x) { console.log(x) }")

    child.set_cursor(1, 5)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 5)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "const foo = (x) => console.log(x)")
end

T["create_arrow_conversion_edit()"]["handles async method"] = function()
    child.set_lines("const obj = { async method() { return 1 } }")

    child.set_cursor(1, 25)

    local result = child.lua_get([[(function()
        local rf = require("js.refactor.regular_function")
        local can, node = rf.can_convert_to_arrow(0, 0, 25)
        if can then return rf.create_arrow_conversion_edit(node, 0) end
    end)()]])

    MiniTest.expect.equality(result, "method: async () => 1")
end

return T
