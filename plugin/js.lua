-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.JsLoaded then
    return
end

_G.JsLoaded = true

vim.api.nvim_create_user_command("Js", function()
    require("js").toggle()
end, {})

vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
        local ok, null_ls = pcall(require, "null-ls")

        if ok then
            require("js.code_actions").setup(null_ls)
        end
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        vim.schedule(function()
            local ok, null_ls = pcall(require, "null-ls")

            if ok then
                require("js.code_actions").setup(null_ls)
            end
        end)
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
        local ok = pcall(require, "luasnip")

        if ok then
            require("js.snippets").setup()
        end
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        vim.schedule(function()
            local ok = pcall(require, "luasnip")

            if ok then
                require("js.snippets").setup()
            end
        end)
    end,
})
