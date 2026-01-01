local M = {}

---@class TSNode
---@field range fun(self: TSNode): number, number, number, number
---@field start fun(self: TSNode): number, number
---@field type fun(self: TSNode): string
---@field field fun(self: TSNode, name: string): TSNode[]
---@field parent fun(self: TSNode): TSNode|nil
---@field named_child fun(self: TSNode, index: number): TSNode|nil
---@field named_child_count fun(self: TSNode): number

---@param bufnr number Buffer number
---@param row number 0-indexed row
---@param col number 0-indexed column
---@return TSNode|nil The arrow_function node if found
local function find_arrow_function_node(bufnr, row, col)
    -- Ensure tree is parsed
    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if parser_ok and parser then
        parser:parse()
    end

    local ok, node = pcall(vim.treesitter.get_node, {
        bufnr = bufnr,
        pos = { row, col },
    })

    if not ok or not node then
        return nil
    end

    while node do
        if node:type() == "arrow_function" then
            return node
        end

        node = node:parent()
    end

    return nil
end

---@param bufnr number Buffer number
---@param row number 0-indexed row
---@param col number 0-indexed column
---@return boolean, TSNode|nil, TSNode|nil Returns can_transform, expression node, arrow_function node
function M.can_remove_braces(bufnr, row, col)
    local node = find_arrow_function_node(bufnr, row, col)

    if not node then
        return false, nil, nil
    end

    local body = node:field("body")[1]

    if not body or body:type() ~= "statement_block" then
        return false, nil, nil
    end

    if body:named_child_count() ~= 1 then
        return false, nil, nil
    end

    local stmt = body:named_child(0)
    if not stmt then
        return false, nil, nil
    end
    local stmt_type = stmt:type()

    if stmt_type == "return_statement" then
        local expr = stmt:named_child(0)

        if not expr then
            return false, nil, nil
        end

        return true, expr, node
    elseif stmt_type == "expression_statement" then
        local expr = stmt:named_child(0)

        if not expr then
            return false, nil, nil
        end

        return true, expr, node
    end

    return false, nil, nil
end

---@param node TSNode
---@param bufnr number
---@return string
local function get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr)
end

---@param arrow_node TSNode The arrow_function node
---@param expr_node TSNode The expression node
---@param bufnr number Buffer number
---@return string|nil The new arrow function text
function M.create_brace_removal_edit(arrow_node, expr_node, bufnr)
    local body = arrow_node:field("body")[1]

    -- Find where the body starts in the arrow function text
    local body_start_row, body_start_col = body:start()
    local arrow_start_row, arrow_start_col = arrow_node:start()

    -- Get everything before the body (async, params, =>)
    local prefix_lines = {}
    local lines = vim.api.nvim_buf_get_lines(bufnr, arrow_start_row, body_start_row + 1, false)

    if arrow_start_row == body_start_row then
        -- Single line: extract prefix from same line
        local line = lines[1]
        local prefix = line:sub(arrow_start_col + 1, body_start_col)
        table.insert(prefix_lines, prefix)
    else
        -- Multi-line: get all lines up to body
        for i, line in ipairs(lines) do
            if i == 1 then
                table.insert(prefix_lines, line:sub(arrow_start_col + 1))
            elseif i == #lines then
                table.insert(prefix_lines, line:sub(1, body_start_col))
            else
                table.insert(prefix_lines, line)
            end
        end
    end

    local prefix = table.concat(prefix_lines, "\n")

    local expr_text = get_node_text(expr_node, bufnr)

    if expr_node:type() == "object" then
        expr_text = "(" .. expr_text .. ")"
    end

    return prefix .. expr_text
end

return M
