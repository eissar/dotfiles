-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text; See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- create autocmd for terminal so we can set config with ftplugin
vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = 'term://*',
    command = 'set filetype=term',
    group = vim.api.nvim_create_augroup('BufFiletypes', { clear = true }),
})
-- set .gohtml ft = html
vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = '*.gohtml',
    command = 'set filetype=html',
    group = vim.api.nvim_create_augroup('BufFiletypes', { clear = true }),
})
-- set hujson ft = json
vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = '*.hujson',
    command = 'set filetype=jsonc',
    group = vim.api.nvim_create_augroup('BufFiletypes', { clear = true }),
})

-- set filetype for sql files
-- vim.api.nvim_create_autocmd('BufWinEnter', {
--     pattern = '*.tsql',
--     command = '',
--     group = vim.api.nvim_create_augroup('BufFiletypes', { clear = true }),
-- })

-- removes trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.md',
    callback = function()
        local save_cursor = vim.fn.getpos '.'
        vim.cmd [[%s/\s\+$//e]]
        vim.fn.setpos('.', save_cursor)
    end,
})

-- don't auto fold preview buffers
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
    group = vim.api.nvim_create_augroup('PreviewFolds', { clear = true }),
    callback = function()
        if vim.wo.previewwindow then
            vim.wo.foldlevel = 999
        end
    end,
})


-- Automatically update winbar when the cwd changes
vim.api.nvim_create_autocmd({ 'DirChanged', 'BufWinEnter', 'CmdlineLeave' }, {
    callback = function()
        vim.opt.winbar = vim.fn.getcwd()
    end,
})

-- Auto resize splits when the terminal's window is resized
vim.api.nvim_create_autocmd('VimResized', {
    command = 'wincmd =',
})

vim.api.nvim_create_autocmd('User', {
    pattern = 'LazyReload',
    callback = function()
        require('fidget').notify('Lazy Config reloaded', vim.log.levels.INFO)
    end,
})

-- for markdown files which are
vim.api.nvim_create_autocmd('BufReadPost', {
    pattern = '*.md',
    callback = function()
        -- require('plugins.github').fetch(require('plugins.github').check_revision)

        local buf_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':.'):gsub('^%.[/\\]', ''):gsub('\\\\', '/')
        if buf_path == '' then
            return
        end

        require('plugins.github').fetch(function() -- fetch has built in throttling
            require('plugins.github').check_remote_changes(buf_path)
        end)
    end,
})

-- update codelens
vim.api.nvim_create_autocmd({ 'CursorHold', 'InsertLeave' }, {
    callback = function()
        vim.lsp.codelens.refresh()
    end,
})

-- hide inlay hints on the cursor line (shown again when the cursor leaves)
do
    local _ = vim.lsp.inlay_hint -- load the built-in provider first so ours runs after it
    local hint_ns = vim.api.nvim_create_namespace('nvim.lsp.inlayhint')
    local saved = {} -- { buf, row, items = { id, col, text }[] }

    vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace('user.inlayhint_hide'), {
        on_win = function(_, win, buf)
            if win ~= vim.api.nvim_get_current_win() then return end
            local row = vim.api.nvim_win_get_cursor(win)[1] - 1
            if saved.buf ~= buf or saved.row ~= row then
                for _, m in ipairs(saved.items or {}) do
                    -- skip marks the built-in already deleted (e.g. after an edit) to avoid duplicates
                    local pos = vim.api.nvim_buf_is_valid(saved.buf)
                        and vim.api.nvim_buf_get_extmark_by_id(saved.buf, hint_ns, m.id, {}) or {}
                    if pos[1] then
                        pcall(vim.api.nvim_buf_set_extmark, saved.buf, hint_ns, pos[1], pos[2],
                            { id = m.id, virt_text = m.text, virt_text_pos = 'inline' })
                    end
                end
                saved = { buf = buf, row = row, items = {} }
            end
            -- re-checked every redraw so hints that arrive/refresh while on this line are hidden too
            for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hint_ns, { row, 0 }, { row, -1 }, { details = true })) do
                if m[4].virt_text then
                    table.insert(saved.items, { id = m[1], col = m[3], text = m[4].virt_text })
                    pcall(vim.api.nvim_buf_set_extmark, buf, hint_ns, row, m[3], { id = m[1] })
                end
            end
        end,
    })
end
