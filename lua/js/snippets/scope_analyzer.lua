local M = {}

local SCOPE_TYPES = {
    "program",
    "function_declaration",
    "arrow_function",
    "function_expression",
    "method_definition",
    "class_declaration",
    "statement_block",
}

---@param node TSNode
---@return TSNode
function M.find_enclosing_scope(node)
    local current = node:parent()

    while current do
        for _, scope_type in ipairs(SCOPE_TYPES) do
            if current:type() == scope_type then
                return current
            end
        end

        current = current:parent()
    end

    -- Fallback to root
    local root = node

    ---@diagnostic disable-next-line: need-check-nil
    while root:parent() do
        ---@diagnostic disable-next-line: cast-local-type
        root = root:parent()
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return root
end

--- Normalize expression text (collapse whitespace)
---@param node TSNode
---@param bufnr number
---@return string
function M.normalize_expression_text(node, bufnr)
    local text = vim.treesitter.get_node_text(node, bufnr)

    return text:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

--- Compare two nodes for equality (type + normalized text recursively)
---@param node1 TSNode
---@param node2 TSNode
---@param bufnr number
---@return boolean
function M.expressions_equal(node1, node2, bufnr)
    if node1:type() ~= node2:type() then
        return false
    end

    -- Terminal nodes: compare normalized text
    ---@diagnostic disable-next-line: undefined-field
    if node1:child_count() == 0 then
        return M.normalize_expression_text(node1, bufnr)
            == M.normalize_expression_text(node2, bufnr)
    end

    -- Non-terminal: recursively compare structure
    if node1:named_child_count() ~= node2:named_child_count() then
        return false
    end

    for i = 0, node1:named_child_count() - 1 do
        ---@diagnostic disable-next-line: param-type-mismatch
        if not M.expressions_equal(node1:named_child(i), node2:named_child(i), bufnr) then
            return false
        end
    end

    return true
end

--- Find all identical expressions in scope
---@param expr_node TSNode expression to match
---@param scope_node TSNode scope to search in
---@param bufnr number
---@return table[] Array of {node, row, col, end_row, end_col}
function M.find_identical_expressions(expr_node, scope_node, bufnr)
    local matches = {}
    local expr_type = expr_node:type()

    local function traverse(node)
        -- Check if this node matches
        if node:type() == expr_type and M.expressions_equal(node, expr_node, bufnr) then
            local row, col = node:start()
            local end_row, end_col = node:end_()

            table.insert(matches, {
                node = node,
                row = row,
                col = col,
                end_row = end_row,
                end_col = end_col,
            })
        end

        -- Traverse children
        for child in node:iter_children() do
            traverse(child)
        end
    end

    traverse(scope_node)

    return matches
end

--- Find where to insert const declaration
---@param scope_node TSNode
---@return number row, number col
function M.find_const_insertion_point(scope_node)
    local scope_type = scope_node:type()

    -- Statement block: after opening brace
    if scope_type == "statement_block" then
        local first_stmt = scope_node:named_child(0)

        if first_stmt then
            return first_stmt:start()
        end
    end

    -- Function: start of body
    if scope_type:match("function") or scope_type == "method_definition" then
        for child in scope_node:iter_children() do
            if child:type() == "statement_block" then
                local first_stmt = child:named_child(0)

                if first_stmt then
                    return first_stmt:start()
                end

                -- Empty block - after opening brace
                local row, col = child:start()

                return row, col + 1
            end
        end
    end

    -- Program: beginning
    if scope_type == "program" then
        local first_stmt = scope_node:named_child(0)

        if first_stmt then
            return first_stmt:start()
        end
    end

    -- Fallback to scope start
    return scope_node:start()
end

--- Check if variable exists in scope
---@param scope_node TSNode
---@param var_name string
---@param bufnr number
---@return boolean
function M.check_variable_exists(scope_node, var_name, bufnr)
    -- Search for declarations matching var_name
    local query_str = [[
    (variable_declarator name: (identifier) @name)
    (function_declaration name: (identifier) @name)
    (formal_parameters (required_parameter (identifier) @name))
    (formal_parameters (optional_parameter (identifier) @name))
  ]]

    local ok, query = pcall(vim.treesitter.query.parse, "javascript", query_str)

    if not ok then
        -- Fallback to simple traversal
        local function check_node(node)
            if node:type() == "identifier" then
                local text = vim.treesitter.get_node_text(node, bufnr)

                if text == var_name then
                    local parent = node:parent()

                    -- Check if it's a declaration context
                    if
                        parent
                        and (
                            parent:type() == "variable_declarator"
                            or parent:type() == "function_declaration"
                            or parent:type() == "required_parameter"
                            or parent:type() == "optional_parameter"
                        )
                    then
                        return true
                    end
                end
            end

            for child in node:iter_children() do
                if check_node(child) then
                    return true
                end
            end

            return false
        end
        return check_node(scope_node)
    end

    for _, node in query:iter_captures(scope_node, bufnr) do
        local text = vim.treesitter.get_node_text(node, bufnr)

        if text == var_name then
            return true
        end
    end

    return false
end

--- Find common ancestor scope for multiple nodes
---@param nodes TSNode[]
---@return TSNode
function M.find_common_scope(nodes)
    if #nodes == 0 then
        ---@diagnostic disable-next-line: return-type-mismatch
        return nil
    end

    if #nodes == 1 then
        return M.find_enclosing_scope(nodes[1])
    end

    -- Get all ancestors for first node
    local function get_scope_ancestors(node)
        local scopes = {}
        local current = M.find_enclosing_scope(node)
        local seen = {}

        while current do
            -- Prevent infinite loop by checking if we've seen this node
            local node_id = tostring(current)

            if seen[node_id] then
                break
            end

            seen[node_id] = true

            table.insert(scopes, current)
            local next_scope = M.find_enclosing_scope(current)

            -- If next scope is same as current, we're at root
            if next_scope == current then
                break
            end

            current = next_scope
        end
        return scopes
    end

    -- Get ancestors of first node
    local first_ancestors = get_scope_ancestors(nodes[1])

    -- Find deepest common ancestor
    for _, scope in ipairs(first_ancestors) do
        local is_common = true

        for i = 2, #nodes do
            local node_scope = M.find_enclosing_scope(nodes[i])

            -- Check if this scope contains the node
            local function contains(parent, child)
                local current = child

                while current do
                    if current == parent then
                        return true
                    end

                    current = current:parent()
                end

                return false
            end

            if not contains(scope, node_scope) then
                is_common = false

                break
            end
        end

        if is_common then
            return scope
        end
    end

    -- Fallback to root
    local root = nodes[1]

    ---@diagnostic disable-next-line: need-check-nil
    while root:parent() do
        ---@diagnostic disable-next-line: cast-local-type
        root = root:parent()
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return root
end

return M
