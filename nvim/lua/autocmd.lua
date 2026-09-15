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
