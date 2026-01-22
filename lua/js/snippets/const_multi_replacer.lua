local scope_analyzer = require("js.snippets.scope_analyzer")

local M = {}

--- Show replacement menu using vim.ui.select
---@param occurrence_count number
---@param callback function(choice: string|nil)
function M.show_replacement_menu(occurrence_count, callback)
    local options = {
        "this_only",
        "all",
    }

    local labels = {
        this_only = "Replace this only",
        all = string.format("Replace all %d occurrences", occurrence_count),
    }

    vim.ui.select(options, {
        prompt = "Replace occurrences:",
        format_item = function(item)
            return labels[item]
        end,
    }, function(choice)
        callback(choice)
    end)
end

--- Prompt for variable name with validation loop
---@param scope_node TSNode
---@param bufnr number
---@param callback function(var_name: string|nil)
function M.prompt_variable_name(scope_node, bufnr, callback)
    local function prompt(suggestion)
        vim.ui.input({
            prompt = "Variable name:",
            default = suggestion,
        }, function(input)
            -- User cancelled
            if not input or input == "" then
                callback(nil)

                return
            end

            -- Validate name
            if scope_analyzer.check_variable_exists(scope_node, input, bufnr) then
                vim.notify(
                    string.format("Variable '%s' already exists in scope", input),
                    vim.log.levels.ERROR
                )

                -- Suggest alternative
                local alt = input .. "_1"

                vim.schedule(function()
                    prompt(alt)
                end)
            else
                callback(input)
            end
        end)
    end

    prompt(nil)
end

--- Apply multi-occurrence replacement
---@param occurrences table[] Array of {node, row, col, end_row, end_col}
---@param var_name string
---@param expr_text string Original expression text
---@param bufnr number
function M.apply_multi_replacement(occurrences, var_name, expr_text, bufnr)
    -- Find the const declaration line that LuaSnip created (looks like "const  = <expr>")
    -- We need to find and update it with the variable name
    local const_row = nil
    local escaped_expr = vim.pesc(expr_text)

    for row = 0, vim.api.nvim_buf_line_count(bufnr) - 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

        -- Match "const  = <expr>" pattern (with empty variable name from snippet)
        if line:match("const%s+=%s+" .. escaped_expr) then
            const_row = row

            break
        end
    end

    if const_row then
        -- Update the const declaration with the variable name
        local line = vim.api.nvim_buf_get_lines(bufnr, const_row, const_row + 1, false)[1]
        local new_line = line:gsub("const%s+=%s+", "const " .. var_name .. " = ")

        vim.api.nvim_buf_set_lines(bufnr, const_row, const_row + 1, false, { new_line })
    end

    -- Filter out the occurrence that became the const declaration
    local other_occurrences = {}

    for _, occ in ipairs(occurrences) do
        if occ.row ~= const_row then
            table.insert(other_occurrences, occ)
        end
    end

    -- Sort occurrences in reverse order to preserve offsets during replacement
    table.sort(other_occurrences, function(a, b)
        if a.row == b.row then
            return a.col > b.col
        end

        return a.row > b.row
    end)

    -- Replace all other occurrences with var_name
    for _, occ in ipairs(other_occurrences) do
        vim.api.nvim_buf_set_text(bufnr, occ.row, occ.col, occ.end_row, occ.end_col, { var_name })
    end

    -- Place cursor at end of const declaration line and enter insert mode (append)
    if const_row then
        local line = vim.api.nvim_buf_get_lines(bufnr, const_row, const_row + 1, false)[1]

        vim.api.nvim_win_set_cursor(0, { const_row + 1, #line })
    end

    vim.cmd("startinsert!")
end

return M
