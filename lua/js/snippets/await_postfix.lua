local M = {}

function M.get_snippets()
    local ls = require("luasnip")
    local hybrid_postfix = require("js.snippets.hybrid_postfix")
    local d = ls.dynamic_node
    local sn = ls.snippet_node
    local t = ls.text_node
    local queries = require("js.snippets.queries")

    return {
        hybrid_postfix({
            trig = ".await",
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

                return sn(nil, {
                    t("await "),
                    t(matched),
                })
            end, {}),
        }),
    }
end

return M
