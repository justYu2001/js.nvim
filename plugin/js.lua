-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.JsLoaded then
    return
end

_G.JsLoaded = true

vim.api.nvim_create_user_command("Js", function()
    require("js").toggle()
end, {})
