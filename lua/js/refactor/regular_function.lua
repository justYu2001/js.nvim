local M = {}

---@class TSNode
---@field range fun(self: TSNode): number, number, number, number
---@field start fun(self: TSNode): number, number
---@field type fun(self: TSNode): string
---@field field fun(self: TSNode, name: string): TSNode[]
---@field parent fun(self: TSNode): TSNode|nil
---@field named_child fun(self: TSNode, index: number): TSNode|nil
---@field named_child_count fun(self: TSNode): number

---@private
---@param bufnr number Buffer number
---@param row number 0-indexed row
---@param col number 0-indexed column
---@return TSNode|nil The function node if found
local function find_function_node(bufnr, row, col)
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
        local node_type = node:type()
        if
            node_type == "function_declaration"
            or node_type == "function_expression"
            or node_type == "method_definition"
        then
            return node
        end

        node = node:parent()
    end

    return nil
end

---@private
---@param node TSNode
---@param bufnr number
---@return string
local function get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr)
end

---@private
---Check if function uses 'this' keyword
---@param body_node TSNode
---@param bufnr number
---@return boolean
local function uses_this(body_node, bufnr)
    local query_string = [[
        (this) @this
    ]]

    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if not lang then
        return false
    end

    local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
    if not ok then
        return false
    end

    for _ in query:iter_captures(body_node, bufnr) do
        return true
    end

    return false
end

---@private
---Check if function uses 'arguments' object
---@param body_node TSNode
---@param bufnr number
---@return boolean
local function uses_arguments(body_node, bufnr)
    local query_string = [[(identifier) @id]]

    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if not lang then
        return false
    end

    local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
    if not ok then
        return false
    end

    for _, node in query:iter_captures(body_node, bufnr) do
        local text = get_node_text(node, bufnr)
        if text == "arguments" then
            return true
        end
    end

    return false
end

---@private
---Check if function is a generator
---@param node TSNode
---@return boolean
local function is_generator(node)
    local node_type = node:type()
    return node_type:find("generator") ~= nil
end

---@private
---Check if function expression has a name
---@param node TSNode
---@return boolean
local function is_named_function_expression(node)
    if node:type() ~= "function_expression" then
        return false
    end

    local name = node:field("name")[1]
    return name ~= nil
end

---@param bufnr number Buffer number
---@param row number 0-indexed row
---@param col number 0-indexed column
---@return boolean, TSNode|nil Returns can_convert, function_node
function M.can_convert_to_arrow(bufnr, row, col)
    local node = find_function_node(bufnr, row, col)

    if not node then
        return false, nil
    end

    -- Skip generators
    if is_generator(node) then
        return false, nil
    end

    -- Skip named function expressions
    if is_named_function_expression(node) then
        return false, nil
    end

    -- Get function body
    local body = node:field("body")[1]
    if not body then
        return false, nil
    end

    -- Skip if uses 'this'
    if uses_this(body, bufnr) then
        return false, nil
    end

    -- Skip if uses 'arguments'
    if uses_arguments(body, bufnr) then
        return false, nil
    end

    return true, node
end

---@private
---Check if body can be simplified (single return/expression)
---@param body TSNode
---@return boolean, TSNode|nil Returns can_simplify, expression_node
local function can_simplify_body(body)
    if body:type() ~= "statement_block" then
        return false, nil
    end

    if body:named_child_count() ~= 1 then
        return false, nil
    end

    local stmt = body:named_child(0)
    if not stmt then
        return false, nil
    end

    local stmt_type = stmt:type()

    if stmt_type == "return_statement" then
        local expr = stmt:named_child(0)
        if not expr then
            return false, nil
        end
        return true, expr
    elseif stmt_type == "expression_statement" then
        local expr = stmt:named_child(0)
        if not expr then
            return false, nil
        end
        return true, expr
    end

    return false, nil
end

---@private
---Check if function is async by looking for async child node
---@param function_node TSNode
---@return boolean
local function is_async_function(function_node)
    -- Check if any child node is the "async" keyword
    for child in function_node:iter_children() do
        if child:type() == "async" then
            return true
        end
    end
    return false
end

---@param function_node TSNode The function node
---@param bufnr number Buffer number
---@return string|nil The new arrow function text
function M.create_arrow_conversion_edit(function_node, bufnr)
    local node_type = function_node:type()

    -- Extract components
    local params = function_node:field("parameters")[1]
    local body = function_node:field("body")[1]

    if not params or not body then
        return nil
    end

    -- Check for async
    local is_async = is_async_function(function_node)

    -- Get parameter text
    local params_text = get_node_text(params, bufnr)

    -- Get return type annotation (TypeScript)
    local return_type_text = ""
    local type_annotation = function_node:field("return_type")[1]
    if type_annotation then
        return_type_text = get_node_text(type_annotation, bufnr)
    end

    -- Process body
    local body_text
    local can_simplify, expr_node = can_simplify_body(body)

    if can_simplify and expr_node then
        body_text = get_node_text(expr_node, bufnr)
        -- Wrap object literals in parens
        if expr_node:type() == "object" then
            body_text = "(" .. body_text .. ")"
        end
    else
        body_text = get_node_text(body, bufnr)
    end

    -- Build arrow function
    local async_prefix = is_async and "async " or ""
    local arrow_fn = async_prefix .. params_text .. return_type_text .. " => " .. body_text

    -- For function_declaration, wrap in const
    if node_type == "function_declaration" then
        local name = function_node:field("name")[1]
        if not name then
            return nil
        end
        local name_text = get_node_text(name, bufnr)
        return "const " .. name_text .. " = " .. arrow_fn
    elseif node_type == "method_definition" then
        -- Convert method to property with arrow function
        local name = function_node:field("name")[1]
        if not name then
            return nil
        end
        local name_text = get_node_text(name, bufnr)
        return name_text .. ": " .. arrow_fn
    else
        -- function_expression
        return arrow_fn
    end
end

return M
