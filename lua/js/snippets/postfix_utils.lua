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

-- Get matchTSNode function for postfix snippets
-- Dynamically selects matcher based on context:
-- - In braceless arrow: use find_first_types (innermost) to avoid matching arrow function
-- - Otherwise: use find_topmost_types (outermost) to match full expressions
function M.get_match_tsnode()
    local builtin = require("luasnip.extras.treesitter_postfix").builtin

    -- Create matchers upfront
    local topmost_matcher = builtin.tsnode_matcher.find_topmost_types(M.expression_types)
    local first_matcher = builtin.tsnode_matcher.find_first_types(M.expression_types)

    -- Return custom matcher that checks context at trigger time
    return function(...)
        local is_braceless = M.is_braceless_arrow_body()

        if is_braceless then
            return first_matcher(...)
        else
            return topmost_matcher(...)
        end
    end
end

-- Helper: find arrow function nearest to (before or at) cursor in arguments
local function find_arrow_in_arguments(arguments_node, cursor_row, cursor_col)
    local best_arrow = nil
    local best_distance = math.huge

    for child in arguments_node:iter_children() do
        if child:type() == "arrow_function" then
            local start_row, _, _, end_col = child:range()

            -- Check if arrow is on same row and ends at or before cursor
            if start_row == cursor_row and end_col <= cursor_col then
                local distance = cursor_col - end_col

                -- Find closest arrow before cursor
                if distance < best_distance then
                    best_distance = distance
                    best_arrow = child
                end
            end
        end
    end

    return best_arrow
end

-- Detect if cursor in braceless arrow function body
-- Braceless: (x) => x + 1  (expression body)
-- Braced: (x) => { return x + 1 }  (statement_block body)
function M.is_braceless_arrow_body()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1 -- Convert to 0-indexed
    local col = cursor[2]

    -- Parse buffer
    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if parser_ok and parser then
        parser:parse()
    end

    -- Get node at cursor
    local ok, node = pcall(vim.treesitter.get_node, {
        bufnr = bufnr,
        pos = { row, col },
    })

    if not ok or not node then
        return false
    end

    -- Walk up parent tree
    local current = node
    while current do
        if current:type() == "arrow_function" then
            local body = current:field("body")[1]
            if body then
                return body:type() ~= "statement_block"
            end
        end

        -- Special case: if in arguments, search children for arrow function
        if current:type() == "arguments" then
            local arrow_fn = find_arrow_in_arguments(current, row, col)
            if arrow_fn then
                local body = arrow_fn:field("body")[1]
                if body then
                    return body:type() ~= "statement_block"
                end
            end
        end

        current = current:parent()
    end

    return false
end

-- Condition: snippet visible only if NOT in braceless arrow
function M.not_in_braceless_arrow()
    return not M.is_braceless_arrow_body()
end

return M
