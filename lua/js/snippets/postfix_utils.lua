local M = {}

-- Expression types to match for postfix snippets
M.expression_types = {
    "number",
    "string",
    "template_string",
    "true",
    "false",
    "null",
    "undefined",
    "identifier",
    "call_expression",
    "member_expression",
    "subscript_expression",
    "object",
    "array",
    "arrow_function",
    "function_expression",
    "binary_expression",
    "ternary_expression",
    "parenthesized_expression",
    "jsx_element",
    "jsx_fragment",
    "unary_expression",
    "new_expression",
    "await_expression",
    "update_expression",
}

-- Get matchTSNode function for postfix snippets (default: always topmost)
function M.get_match_tsnode()
    local builtin = require("luasnip.extras.treesitter_postfix").builtin
    return builtin.tsnode_matcher.find_topmost_types(M.expression_types)
end

-- Get matchTSNode for .log snippet specifically
-- In braceless arrow: match body to avoid matching arrow itself
-- Otherwise: use topmost for full expression
function M.get_match_tsnode_log()
    -- Return custom matcher that checks context at trigger time
    return function(bufinfo, pos)
        -- bufinfo is TSParser with trigger text restored
        -- pos is {row, col} at end of trigger (before deletion)

        -- Get node at pos-1 using TSParser method (handles tree with trigger restored)
        local node = bufinfo:get_node_at_pos({ pos[1], pos[2] - 1 })
        if not node then
            return nil, nil
        end

        -- Check if in braceless arrow using this node
        local is_braceless = false
        local arrow_body = nil
        local current = node
        while current do
            local node_type_ok, node_type = pcall(function()
                return current:type()
            end)
            if node_type_ok then
                if node_type == "arrow_function" then
                    local body_ok, body = pcall(function()
                        return current:field("body")[1]
                    end)
                    if body_ok and body then
                        local body_type_ok, body_type = pcall(function()
                            return body:type()
                        end)
                        if body_type_ok then
                            is_braceless = body_type ~= "statement_block"
                            if is_braceless then
                                arrow_body = body
                            end
                            break
                        end
                    end
                -- Special case: if at arguments node, look for arrow_function child containing cursor
                elseif node_type == "arguments" then
                    for child in current:iter_children() do
                        local child_type_ok, child_type = pcall(function()
                            return child:type()
                        end)
                        if child_type_ok and child_type == "arrow_function" then
                            -- Check if cursor position is within this arrow
                            local sr, sc, er, ec = child:range()
                            if
                                (pos[1] > sr or (pos[1] == sr and pos[2] >= sc))
                                and (pos[1] < er or (pos[1] == er and pos[2] <= ec))
                            then
                                local body_ok, body = pcall(function()
                                    return child:field("body")[1]
                                end)
                                if body_ok and body then
                                    local body_type_ok, body_type = pcall(function()
                                        return body:type()
                                    end)
                                    if body_type_ok then
                                        is_braceless = body_type ~= "statement_block"
                                        if is_braceless then
                                            arrow_body = body
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if is_braceless then
                        break
                    end
                end
            end
            local parent_ok, parent = pcall(function()
                return current:parent()
            end)
            if parent_ok and parent then
                current = parent
            else
                break
            end
        end

        -- If in braceless arrow, return the body node
        if is_braceless and arrow_body then
            local _, _, ber, bec = arrow_body:range()

            -- Check if body ends at pos (before trigger)
            if ber == pos[1] and bec == pos[2] then
                return {}, arrow_body -- Return (best_match, prefix_node)
            end
        end

        -- Otherwise, walk up to find topmost expression from current node
        local topmost = node
        current = node
        while current do
            local parent_ok, parent = pcall(function()
                return current:parent()
            end)
            if not parent_ok or not parent then
                break
            end

            local parent_type_ok, parent_type = pcall(function()
                return parent:type()
            end)
            if not parent_type_ok then
                break
            end

            local _, _, per, pec = parent:range()

            -- Check if parent ends at pos (like builtin matcher does)
            if per ~= pos[1] or pec ~= pos[2] then
                break
            end

            -- Check if parent is an expression type
            local is_expr = false
            for _, expr_type in ipairs(M.expression_types) do
                if parent_type == expr_type then
                    is_expr = true
                    break
                end
            end

            if is_expr then
                topmost = parent
                current = parent
            else
                break
            end
        end

        if topmost then
            local _, _, ter, tec = topmost:range()

            -- Check if topmost ends at pos (before trigger)
            if ter == pos[1] and tec == pos[2] then
                return {}, topmost -- Return (best_match, prefix_node)
            end
        end

        return nil, nil
    end
end

-- Condition: hide snippet if in braceless arrow
-- Called at menu visibility time - checks position BEFORE trigger
function M.not_in_braceless_arrow()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1 -- 0-indexed
    local col = cursor[2]

    -- Parse buffer
    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not parser_ok or not parser then
        return true
    end

    local trees = parser:parse()
    if not trees or #trees == 0 then
        return true
    end

    local root = trees[1]:root()

    -- Look backwards from cursor to find expression
    -- Try positions: col-1, col-2, ... col-20 (before trigger chars)
    for offset = 1, 20 do
        local check_col = col - offset
        if check_col < 0 then
            break
        end

        local node = root:named_descendant_for_range(row, check_col, row, check_col)
        if node and node:type() ~= "program" then
            -- Walk up to check for arrow
            local current = node
            while current do
                local node_type_ok, node_type = pcall(function()
                    return current:type()
                end)
                if not node_type_ok then
                    break
                end

                if node_type == "arrow_function" then
                    local body_ok, body = pcall(function()
                        return current:field("body")[1]
                    end)
                    if body_ok and body then
                        local body_type_ok, body_type = pcall(function()
                            return body:type()
                        end)
                        if body_type_ok and body_type ~= "statement_block" then
                            return false
                        end
                    end
                    break
                elseif node_type == "arguments" then
                    for child in current:iter_children() do
                        local child_type_ok, child_type = pcall(function()
                            return child:type()
                        end)
                        if child_type_ok and child_type == "arrow_function" then
                            local sr, sc, er, ec = child:range()
                            if
                                (row > sr or (row == sr and check_col >= sc))
                                and (row < er or (row == sr and check_col <= ec))
                            then
                                local body_ok, body = pcall(function()
                                    return child:field("body")[1]
                                end)
                                if body_ok and body then
                                    local body_type_ok, body_type = pcall(function()
                                        return body:type()
                                    end)
                                    if body_type_ok and body_type ~= "statement_block" then
                                        return false
                                    end
                                end
                            end
                        end
                    end
                end

                local parent_ok, parent = pcall(function()
                    return current:parent()
                end)
                if parent_ok and parent then
                    current = parent
                else
                    break
                end
            end

            -- Found expression node, checked parents, not in braceless arrow
            break
        end
    end

    return true
end

-- Matcher for snippets that should be HIDDEN in braceless arrows
-- (.const, .if, .return - declaring/controlling flow in expression is invalid)
function M.get_match_tsnode_hide_in_braceless()
    local builtin = require("luasnip.extras.treesitter_postfix").builtin
    local topmost_matcher = builtin.tsnode_matcher.find_topmost_types(M.expression_types)

    return function(bufinfo, pos)
        -- Get node at pos-1 (same approach as get_match_tsnode_log)
        local node = bufinfo:get_node_at_pos({ pos[1], pos[2] - 1 })
        if not node then
            return nil, nil
        end

        -- Walk up to check for braceless arrow
        local current = node
        while current do
            local node_type_ok, node_type = pcall(function()
                return current:type()
            end)
            if not node_type_ok then
                break
            end

            if node_type == "arrow_function" then
                local body_ok, body = pcall(function()
                    return current:field("body")[1]
                end)
                if body_ok and body then
                    local body_type_ok, body_type = pcall(function()
                        return body:type()
                    end)
                    if body_type_ok then
                        local is_braceless = body_type ~= "statement_block"
                        if is_braceless then
                            -- Check if arrow body ends at pos (trigger typed right after body)
                            local _, _, ber, bec = body:range()
                            if ber == pos[1] and bec == pos[2] then
                                -- In braceless arrow - hide snippet
                                return nil, nil
                            end
                        end
                        break
                    end
                end
            elseif node_type == "arguments" then
                -- Check children for arrow containing cursor
                for child in current:iter_children() do
                    local child_type_ok, child_type = pcall(function()
                        return child:type()
                    end)
                    if child_type_ok and child_type == "arrow_function" then
                        local sr, sc, er, ec = child:range()
                        -- Check if pos is within or just after arrow (for trigger)
                        if
                            (pos[1] > sr or (pos[1] == sr and pos[2] >= sc))
                            and (pos[1] < er or (pos[1] == er and pos[2] <= ec))
                        then
                            local body_ok, body = pcall(function()
                                return child:field("body")[1]
                            end)
                            if body_ok and body then
                                local body_type_ok, body_type = pcall(function()
                                    return body:type()
                                end)
                                if body_type_ok then
                                    local is_braceless = body_type ~= "statement_block"
                                    if is_braceless then
                                        return nil, nil
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local parent_ok, parent = pcall(function()
                return current:parent()
            end)
            if parent_ok and parent then
                current = parent
            else
                break
            end
        end

        -- Not in braceless arrow - use topmost matcher
        return topmost_matcher(bufinfo, pos)
    end
end

return M
