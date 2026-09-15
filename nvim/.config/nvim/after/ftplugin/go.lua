vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = false
vim.opt_local.list = false

vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--vim.opt_local.foldtext = 'v:lua.parse_line'
vim.opt_local.foldtext = ''

-- vim.treesitter.query.add_predicate('match-region', match_region_predicate, nil)
-- -- prints <userdata>
-- (
--  [
--   (comment) @_a
--   (#lua-match? @_a "^// #region.*")
--   ] @_start
--   (#match-region? @_a @_start)
-- )
-- Predicate handler receive the following arguments
-- (match, pattern, bufnr, predicate)
-- TODO: make nice
---@return boolean
local function match_region_predicate(match, _, source, predicate)
    local start_node = match[predicate[2]] -- #region_start
    local end_node = match[predicate[3]] -- #endregion

    if not #start_node == 1 and #end_node == 1 then
        print 'ERROR'
        return false
    end

    local start_text = vim.treesitter.get_node_text(start_node[1], source)
    local end_text = vim.treesitter.get_node_text(end_node[1], source)
    if (#start_text < 11) and (#end_text < 11) then
        print 'invalid #range tag(s)'
        return false
    end

    start_text = string.sub(start_text, 12)
    end_text = string.sub(end_text, 15)
    return (start_text ~= nil) and (start_text == end_text)
end

vim.treesitter.query.add_predicate('match_region?', match_region_predicate, { force = true, all = true })

-- TODO:
-- <https://github.com/Wansmer/nvim-config/blob/main/lua/modules/foldtext.lua>

do -- MONKEY PATCH HACK TODO REMOVE LATER
    local og_convert = vim.lsp.util.convert_input_to_markdown_lines

    -- Override it
    vim.lsp.util.convert_input_to_markdown_lines = function(input)
        local lines = og_convert(input)
        for i, line in ipairs(lines) do
            if line:match '^%s*```' then
                lines[i] = line:gsub('^%s+', '')
            end
        end
        return lines
    end
end
