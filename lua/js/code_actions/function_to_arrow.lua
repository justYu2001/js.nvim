local regular_function = require("js.refactor.regular_function")

local M = {}

function M.get_source(null_ls)
    return {
        name = "js-function-to-arrow",
        filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
        method = null_ls.methods.CODE_ACTION,
        generator = {
            fn = function(params)
                local bufnr = params.bufnr
                local row = params.row - 1
                local col = params.col

                local can_convert, function_node =
                    regular_function.can_convert_to_arrow(bufnr, row, col)

                if not can_convert then
                    return nil
                end

                ---@cast function_node TSNode

                return {
                    {
                        title = "Convert to arrow function",
                        action = function()
                            local edit =
                                regular_function.create_arrow_conversion_edit(function_node, bufnr)

                            if edit then
                                local start_row, start_col, end_row, end_col = function_node:range()

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
