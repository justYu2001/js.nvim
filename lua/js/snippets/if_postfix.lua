local M = {}

function M.get_snippets()
    local ls = require("luasnip")
    local ts_postfix = require("luasnip.extras.treesitter_postfix").treesitter_postfix
    local d = ls.dynamic_node
    local sn = ls.snippet_node
    local i = ls.insert_node
    local t = ls.text_node
    local postfix_utils = require("js.snippets.postfix_utils")

    return {
        ts_postfix({
            trig = ".if",
            dscr = "if (expr) { }",
            reparseBuffer = "live",
            matchTSNode = postfix_utils.get_match_tsnode(),
            wordTrig = false,
            show_condition = postfix_utils.not_in_braceless_arrow,
        }, {
            d(1, function(_, parent)
                local matched = parent.snippet.env.LS_TSMATCH

                if not matched or type(matched) ~= "table" or #matched == 0 then
                    matched = { "" }
                end

                return sn(nil, {
                    t("if ("),
                    t(matched),
                    t(") {"),
                    t({ "", "  " }),
                    i(1),
                    t({ "", "}" }),
                })
            end, {}),
        }),
    }
end

return M
