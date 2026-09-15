require 'plugins.markdown-functions'
-- vim.api.nvim_set_keymap('v', '<C-k>', ':lua MarkdownLink()<cr>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '<C-k>', ':lua InsertMarkdownLink()<cr>', { noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<leader>prm', ':lua openMarkdownInBrowser()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>prm', ':lua OpenMarkdownInBrowser()<cr>', { noremap = true, silent = true })

-- require('telescope.themes').get_dropdown {
--             winblend = 10,
--             previewer = false,
--         }
-- ???

-- vim.keymap.set("n", "<leader>gt", ":lua moveCursorToTagsMarkdown()<cr>", { noremap = true, buffer = true})
-- vim.keymap.set("n", "<leader>ih",":lua insertHeadingsFromMarkdownFile()<cr>", { noremap = true, buffer = true })
-- vim.keymap.set("n", "<leader>[", ":lua insertWikiLink()<cr>", { noremap = true, buffer = true })
-- vim.keymap.set("n", "<leader>]", ":lua insertWikiLinkWithCurrentWorkingDirectoryPath()<cr>", { noremap = true, buffer = true })

-- removes trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
    callback = function()
        local save_cursor = vim.fn.getpos '.'
        vim.cmd [[%s/\s\+$//e]]
        vim.fn.setpos('.', save_cursor)
    end,
})

vim.keymap.set('n', '<leader>gh', function()
    local conf = require('telescope.config').values
    local finders = require 'telescope.finders'
    local make_entry = require 'telescope.make_entry'
    local pickers = require 'telescope.pickers'
    local utils = require 'telescope.utils'
    local entry_display = require 'telescope.pickers.entry_display'

    local opts = {}
    local params = vim.lsp.util.make_position_params(opts.winnr, 'utf-32')

    vim.lsp.buf_request(opts.bufnr, 'textDocument/documentSymbol', params, function(err, result, _, _)
        if err then
            vim.api.nvim_err_writeln('Error when finding document symbols: ' .. err.message)
            return
        end

        if not result or vim.tbl_isempty(result) then
            utils.notify('builtin.lsp_document_symbols', {
                msg = 'No results from textDocument/documentSymbol',
                level = 'INFO',
            })
            return
        end

        local locations = vim.lsp.util.symbols_to_items(result or {}, opts.bufnr, 'utf-32') or {}
        locations = utils.filter_symbols(locations, opts)
        if locations == nil then
            return
        end

        if vim.tbl_isempty(locations) then
            utils.notify('builtin.lsp_document_symbols', {
                msg = 'No document_symbol locations found',
                level = 'INFO',
            })
            return
        end

        -- Custom displayer from your settings
        local displayer = entry_display.create {
            separator = ' ',
            items = {
                {
                    width = function(_, cols)
                        return math.floor(cols * 0.8)
                    end,
                },
                { remaining = true, right_justify = true },
            },
        }

        local entry_maker_lsp_symbols = function(entry)
            local default_maker = make_entry.gen_from_lsp_symbols(opts)
            local entry_tbl = default_maker(entry)
            if entry_tbl then
                local filename_short = vim.fn.fnamemodify(entry.filename or '', ':t')
                local lnum = (entry.lnum or 0)
                local display_text = entry.text:gsub('^%[.-%]%s*', '')
                local right_col = string.format('%s:%d', filename_short, lnum)
                entry_tbl.display = function()
                    return displayer { display_text, right_col }
                end
                entry_tbl.filename = entry.filename
            end
            return entry_tbl
        end

        local picker = pickers.new(opts, {
            prompt_title = 'LSP Document Symbols',
            finder = finders.new_table {
                results = locations,
                entry_maker = entry_maker_lsp_symbols,
            },
            previewer = conf.qflist_previewer(opts),
            sorter = conf.prefilter_sorter {
                tag = 'symbol_type',
                sorter = conf.generic_sorter(opts),
            },
            -- every time a picker is created
            -- attach_mappings = function(bufnr, map)
            --     return true -- use default mappings
            -- end,
            layout_strategy = 'horizontal',
            -- layout_config = { width = 0.8, height = 0.55 },
            push_cursor_on_edit = true,
            push_tagstack_on_edit = true,
        })
        local Picker = require('telescope.pickers')._Picker
        local og_refresh_previewer = Picker.refresh_previewer -- store the original

        picker.refresh_previewer = function(self)
            vim.schedule(function() -- wrap with schedule to avoid race issue?
                local preview_bufnr = self.previewer.state.bufnr
                vim.api.nvim_buf_call(preview_bufnr, function()
                    vim.opt_local.scrolloff = 0
                    vim.cmd 'normal! zt'
                end)
            end)
            og_refresh_previewer(self)
        end

        picker:find()
    end)
end, { desc = '[G]et [H]eadings' })
