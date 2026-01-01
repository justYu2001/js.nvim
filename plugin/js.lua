-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.JsLoaded then
    return
end

_G.JsLoaded = true

vim.api.nvim_create_user_command("Js", function()
    require("js").toggle()
end, {})

-- Auto-register code actions with none-ls after plugins are loaded
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

-- Fallback for non-lazy.nvim users
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
