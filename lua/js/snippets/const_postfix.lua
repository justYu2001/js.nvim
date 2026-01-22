local M = {}

function M.get_snippets()
    local ls = require("luasnip")
    local ts_postfix = require("luasnip.extras.treesitter_postfix").treesitter_postfix
    local d = ls.dynamic_node
    local sn = ls.snippet_node
    local i = ls.insert_node
    local t = ls.text_node
    local postfix_utils = require("js.snippets.postfix_utils")
    local scope_analyzer = require("js.snippets.scope_analyzer")
    local const_multi_replacer = require("js.snippets.const_multi_replacer")

    return {
        ts_postfix({
            trig = ".const",
            dscr = "const x = expr",
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

                -- Get buffer and matched text
                local bufnr = vim.api.nvim_get_current_buf()
                local matched_text = table.concat(matched, "\n")

                -- Defer async flow
                vim.schedule(function()
                    -- Get TSNode at cursor
                    local parser = vim.treesitter.get_parser(bufnr, "javascript")

                    if not parser then
                        return
                    end

                    local tree = parser:parse()[1]

                    if not tree then
                        return
                    end

                    local root = tree:root()

                    -- Find expression node matching the matched text
                    -- We search backwards from cursor to find the node
                    local function find_expr_node(node)
                        local node_text = vim.treesitter.get_node_text(node, bufnr)

                        if node_text == matched_text then
                            return node
                        end

                        for child in node:iter_children() do
                            local result = find_expr_node(child)

                            if result then
                                return result
                            end
                        end

                        return nil
                    end

                    local expr_node = find_expr_node(root)

                    if not expr_node then
                        return
                    end

                    -- Find all identical expressions in entire file first
                    local occurrences =
                        scope_analyzer.find_identical_expressions(expr_node, root, bufnr)

                    -- If single occurrence, keep current snippet behavior
                    if #occurrences <= 1 then
                        return
                    end

                    -- Find common ancestor scope for all occurrences
                    local occurrence_nodes = {}

                    for _, occ in ipairs(occurrences) do
                        table.insert(occurrence_nodes, occ.node)
                    end

                    local scope_node = scope_analyzer.find_common_scope(occurrence_nodes)

                    if not scope_node then
                        return
                    end

                    -- Multiple occurrences - show menu
                    const_multi_replacer.show_replacement_menu(#occurrences, function(choice)
                        -- User cancelled or chose "this_only"
                        if not choice or choice == "this_only" then
                            -- Position cursor after "const " (6 chars) and enter insert mode
                            local cursor = vim.api.nvim_win_get_cursor(0)

                            local line = vim.api.nvim_buf_get_lines(
                                bufnr,
                                cursor[1] - 1,
                                cursor[1],
                                false
                            )[1]

                            local indent = line:match("^%s*") or ""

                            -- Cursor should be at: indent + "const " (6 chars)
                            vim.api.nvim_win_set_cursor(0, { cursor[1], #indent + 6 })
                            vim.cmd("startinsert")

                            return
                        end

                        -- User chose "all" - prompt for variable name
                        const_multi_replacer.prompt_variable_name(
                            scope_node,
                            bufnr,
                            function(var_name)
                                if not var_name then
                                    return
                                end

                                -- Exit snippet mode
                                ls.unlink_current()

                                -- Apply multi-replacement
                                const_multi_replacer.apply_multi_replacement(
                                    occurrences,
                                    var_name,
                                    matched_text,
                                    bufnr
                                )
                            end
                        )
                    end)
                end)

                -- Return standard snippet (may be replaced if multi-replace chosen)
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
