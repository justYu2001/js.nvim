-- Known limitation: Does not work in concise arrow function bodies without braces
-- Works: () => { expr.log }
-- Broken: () => expr.log
-- This is a treesitter limitation - invalid syntax breaks parsing in expression bodies

local M = {}

function M.get_snippets()
    local ls = require("luasnip")
    local ts_postfix = require("luasnip.extras.treesitter_postfix").treesitter_postfix
    local d = ls.dynamic_node
    local sn = ls.snippet_node
    local t = ls.text_node
    local queries = require("js.snippets.queries")

    return {
        ts_postfix({
            trig = ".log",
            reparseBuffer = "live",
            matchTSNode = {
                query = queries.postfix_expression,
                query_lang = "javascript",
            },
            wordTrig = false,
        }, {
            d(1, function(_, parent)
                local matched = parent.snippet.env.LS_TSMATCH

                if not matched or type(matched) ~= "table" or #matched == 0 then
                    matched = { "" }
                end

                -- Unwrap parenthesized expressions for multi-arg support
                -- (a, b) -> a, b
                local text = table.concat(matched, "\n")
                local unwrapped = text:match("^%((.+)%)$") or text

                return sn(nil, {
                    t("console.log("),
                    t(vim.split(unwrapped, "\n", { plain = true })),
                    t(")"),
                })
            end, {}),
        }),
    }
end

return M
