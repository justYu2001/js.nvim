local M = {}

--- @param line_to_cursor string The line content up to cursor position
--- @param matched_trigger string The trigger that was matched (e.g., ".log")
--- @return string The extracted expression, or "" if no match
local function extract_prefix(line_to_cursor, matched_trigger)
    -- Remove trigger from end
    local line = line_to_cursor:sub(1, -1 - #matched_trigger)

    -- Regex patterns for simple expressions (no operators/ternaries)
    -- Ordered by specificity, but we use longest match
    local patterns = {
        [[[%w_$][%w%d_$%.]*%b()%s*$]], -- func(), obj.method()
        [[[%w_$][%w%d_$%.]*%b[]%s*$]], -- arr[0], obj[key]
        [[[%w_$][%w%d_$%.]*$]], -- obj.prop, identifier
        [[%b()%s*$]], -- (a, b)
        [[%b[]%s*$]], -- [1, 2]
        [[%b{}%s*$]], -- {a:1}
        [[["'].-["']%s*$]], -- "string"
        [[`[^`]*`%s*$]], -- `template`
        [[%d+%.?%d*%s*$]], -- 123, 45.6
    }

    -- Find longest match across all patterns
    local longest = ""
    for _, pat in ipairs(patterns) do
        local match = line:match(pat)

        if match and #match > #longest then
            longest = match
        end
    end

    -- Trim whitespace
    return longest:match("^%s*(.-)%s*$") or ""
end

--- @param line_to_cursor string The line content up to cursor position
--- @param matched_trigger string The trigger that was matched
--- @param captures table Captures from snippet trigger
--- @return table|nil Resolver result with trigger, captures, clear_region, env_override
local function regex_resolver(line_to_cursor, matched_trigger, captures)
    local prefix = extract_prefix(line_to_cursor, matched_trigger)

    if prefix == "" then
        return nil
    end

    local util = require("luasnip.util.util")
    local cursor = util.get_cursor_0ind()

    return {
        trigger = matched_trigger,
        captures = captures,
        clear_region = {
            from = { cursor[1], cursor[2] - #prefix - #matched_trigger },
            to = { cursor[1], cursor[2] },
        },
        env_override = {
            LS_TSMATCH = vim.split(prefix, "\n"),
        },
    }
end

--- Wrapper around ts_postfix that adds regex fallback capability
--- Creates a TS-based postfix snippet and wraps its resolver to fallback to regex
--- when tree-sitter fails (e.g., due to syntax errors)
--- @param context table Snippet context (trig, matchTSNode, reparseBuffer, etc.)
--- @param nodes table Snippet nodes
--- @param opts table|nil Optional snippet options
--- @return table LuaSnip snippet with regex fallback
function M.hybrid_postfix(context, nodes, opts)
    local ts_postfix = require("luasnip.extras.treesitter_postfix").treesitter_postfix
    local postfix_snippet = ts_postfix(context, nodes, opts)

    -- Wrap its resolveExpandParams to add regex fallback
    local ts_resolver = postfix_snippet.resolveExpandParams

    postfix_snippet.resolveExpandParams = function(
        snippet,
        line_to_cursor,
        matched_trigger,
        captures
    )
        local result = ts_resolver(snippet, line_to_cursor, matched_trigger, captures)

        if result then
            return result
        end

        return regex_resolver(line_to_cursor, matched_trigger, captures)
    end

    return postfix_snippet
end

return M.hybrid_postfix
