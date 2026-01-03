local M = {}

function M.get_snippets()
    local ls = require("luasnip")
    local ts_postfix = require("luasnip.extras.treesitter_postfix").treesitter_postfix
    local d = ls.dynamic_node
    local sn = ls.snippet_node
    local i = ls.insert_node
    local t = ls.text_node

    return {
        ts_postfix({
            trig = ".const",
            reparseBuffer = "live",
            matchTSNode = {
                query = [[
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
                ]],
                query_lang = "javascript", -- Works for TS too
            },
            wordTrig = false,
        }, {
            d(1, function(_, parent)
                local matched = parent.snippet.env.LS_TSMATCH

                if not matched or type(matched) ~= "table" or #matched == 0 then
                    matched = { "" }
                end

                return sn(nil, {
                    t("const "),
                    i(1),
                    t(" = "),
                    t(matched),
                })
            end, {}),
        }),
    }
end

return M
