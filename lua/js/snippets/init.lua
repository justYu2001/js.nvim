local M = {}

local registered = false

function M.setup()
    if registered then
        return
    end

    local ok, luasnip = pcall(require, "luasnip")

    if not ok then
        return
    end

    registered = true

    -- Get snippets dir path via debug.getinfo
    local snippets_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
    local all_snippets = {}

    -- Scan for *_postfix.lua files using vim.fs.dir
    for name, kind in vim.fs.dir(snippets_dir) do
        if kind == "file" and name:match("_postfix%.lua$") then
            local module_name = name:gsub("%.lua$", "")

            local module_ok, module = pcall(require, "js.snippets." .. module_name)

            if module_ok and module.get_snippets then
                local snippets = module.get_snippets()

                if type(snippets) == "table" then
                    for _, snippet in ipairs(snippets) do
                        table.insert(all_snippets, snippet)
                    end
                end
            end
        end
    end

    local filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" }

    for _, ft in ipairs(filetypes) do
        luasnip.add_snippets(ft, all_snippets)
    end
end

return M
