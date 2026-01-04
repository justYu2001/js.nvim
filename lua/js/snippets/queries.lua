local M = {}

M.postfix_expression = [[
    [
        (number)
        (string)
        (template_string)
        (true)
        (false)
        (null)
        (undefined)
        (identifier)
        (call_expression)
        (member_expression)
        (subscript_expression)
        (object)
        (array)
        (arrow_function)
        (function_expression)
        (binary_expression)
        (ternary_expression)
        (parenthesized_expression)
    ] @prefix
]]

return M
