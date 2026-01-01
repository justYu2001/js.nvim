local arrow_function = require("js.refactor.arrow_function")

local M = {}

function M.get_source(null_ls)
    return {
        name = "js-remove-arrow-braces",
        filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
        method = null_ls.methods.CODE_ACTION,
        generator = {
        fn = function(params)
            local bufnr = params.bufnr
            local row = params.row - 1
            local col = params.col

            local can_remove, expr_node, arrow_node = arrow_function.can_remove_braces(bufnr, row, col)

            if not can_remove then
                return nil
            end

            ---@cast arrow_node TSNode
            ---@cast expr_node TSNode

            return {
                {
                    title = "Remove braces around arrow function body",
                    action = function()
                        local edit = arrow_function.create_brace_removal_edit(arrow_node, expr_node, bufnr)

                        if edit then
                            local start_row, start_col, end_row, end_col = arrow_node:range()

                            vim.api.nvim_buf_set_text(
                                bufnr,
                                start_row,
                                start_col,
                                end_row,
                                end_col,
                                vim.split(edit, "\n")
                            )
                        end
                    end,
                },
            }
        end,
    },
    }
end

return M
