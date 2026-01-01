-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up 'mini.test' and 'mini.doc' only when calling headless Neovim (like with `make test` or `make documentation`)
if #vim.api.nvim_list_uis() == 0 then
    -- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
    -- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
    vim.cmd("set rtp+=deps/mini.nvim")

    -- Add 'nvim-treesitter' for tree-sitter parsing in tests
    vim.cmd("set rtp+=deps/nvim-treesitter")

    -- Add user's parser directory to runtimepath
    vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")

    -- Install JavaScript parser for tests (blocking)
    require("nvim-treesitter.install").install({ "javascript" }):wait(60000)

    -- Wait for parser to be ready
    vim.wait(60000, function()
        local ok = pcall(vim.treesitter.language.add, "javascript")
        return ok
    end, 100)

    -- Set up 'mini.test'
    require("mini.test").setup()

    -- Set up 'mini.doc'
    require("mini.doc").setup()
end
