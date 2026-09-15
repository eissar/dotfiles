local iron = require 'iron.core'

iron.setup {
    config = {
        -- Whether a repl should be discarded or not
        scratch_repl = true,

        -- If the repl buffer is listed. Set to true so we can navigate more easily
        buflisted = true,
        -- Automatically closes the repl window on process end
        -- close_window_on_exit = true,
        -- Your repl definitions come here
        repl_definition = {
            ps1 = {
                -- Can be a table or a function that returns a table (see below)
                command = { 'pwsh.exe', '-NoLogo' },
                ignore_eval = true, -- Hide echoing of typed (executed) lines TODO: Does not work.
            },
            python = {
                command = { 'python3' }, -- or { "ipython", "--no-autoindent" }
                --format = require("iron.fts.common").bracketed_paste_python
            },
        },
        -- How the repl window will be displayed
        -- See below for more information
        -- repl_open_cmd = require('iron.view').bottom(30),
        --

        repl_open_cmd = require('iron.view').split('40%', {
            number = false,
            relativenumber = false,
        }),
        ignore_blank_lines = true,
        ignore_eval = true, -- Hide echoing of typed (executed) lines TODO: Does not work.
    },
    keymaps = {
        send_motion = '<leader>sc',
        visual_send = '<leader>sc',
        send_file = '<leader>isf',
        send_line = '<leader>isl',
        -- TODO: Move this to keymaps
    },
}

vim.api.nvim_set_keymap('n', '<leader>iF', ':lua require("iron.core").focus_on("ps1") <cr>', { noremap = true, silent = true, desc = '[I]ron [F]ocus' })
