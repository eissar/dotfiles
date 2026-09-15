-- [[ Basic Keymaps ]] See `:help vim.keymap.set()`
local M = {}
-- There is a popular mapping that will show the :ls result above a prompt: <https://vi.stackexchange.com/questions/14829/close-multiple-buffers-interactively>
-- TODO: this seems to be broken.
vim.keymap.set('n', '<leader>ls', ':ls<CR>:b<space>')
vim.api.nvim_set_keymap('n', '<C-v>', '"+p', { noremap = true })

-- goto start/end of line
vim.api.nvim_set_keymap('n', 'gs', '^', { noremap = true, silent = true, desc = '[G]oto Start' })
vim.keymap.set('n', 'ge', '$') -- go to end of line
-- Also consider, Goto Append or Goto Insert gA / gI to mirror insert/ append

vim.api.nvim_set_keymap('n', '<M-j>', ':m +1<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-k>', ':m -2<cr>', { noremap = true, silent = true })

-- vim.keymap.set("n", "<leader>po",":lua showPopupPickList('/OneDrive/Catalog/note-taking.notebook/hom.md')<cr>", { noremap = true, silent = true })

-- netrw sucks so open file under cursor. gX until I find a better hotkey.
vim.keymap.set('n', 'gX', function()
    local filepath = vim.fn.expand '<cfile>:p'
    local modified_path = filepath:gsub('\\', '/')
    vim.cmd('!start "" "' .. modified_path .. '"')
end, { desc = 'Open file under cursor, (not really working)' })

vim.keymap.set('n', '<leader>ts', function()
    -- Get row and column cursor,
    -- use unpack because it's a tuple.
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local current_time = os.date '%I:%M %p' -- Get current time in 12-hour format with AM/PM
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { tostring(current_time) })
end, { desc = 'Insert timestamp' })

-- Filename Completion
vim.keymap.set('i', '<C-f>', '<C-x><C-f>', { desc = '[F]ilename completion' })

-- vim.api.nvim_set_keymap('n',
--'<leader><Ctrl>v',":lua insertFilename()<cr>",
--{ noremap = true, silent = true })

--[[ misc user function keybindings ]]
vim.api.nvim_set_keymap('n', 'gX', ':lua getNodeAsUrl()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>prf', ':lua PrintFile()<cr>',
    { noremap = true, silent = true, desc = 'Print markdown file and open in webbrowser.' })
vim.api.nvim_set_keymap('n', '<leader>id', ':lua insertDate()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>ifn', ':lua insertFilename()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>it', ':lua InsertAbbreviatedTime()<cr>', { noremap = true, silent = true })


local function scroll_preview(keys)
    local cur_win = vim.api.nvim_get_current_win()

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.wo[win].previewwindow then
            vim.api.nvim_win_call(win, function()
                vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes(keys, true, false, true))
            end)

            vim.api.nvim_set_current_win(cur_win)
            return
        end
    end

    vim.notify('No preview window', vim.log.levels.WARN)
end

vim.keymap.set('n', '<leader>pd', function()
    scroll_preview('<C-d>')
end, { desc = 'Scroll preview window half-page down' })

vim.keymap.set('n', '<leader>pu', function()
    scroll_preview('<C-u>')
end, { desc = 'Scroll preview window half-page up' })
-- Keybinding for opening Ex file browser
vim.keymap.set('n', '<leader>pv', ':Ex<cr>', { noremap = true, silent = true, desc = '[P]roject [V]iew' })
-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>gq', ':copen<cr>', { desc = '[G]oto [Q]uickfix' })

vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, { desc = '[G]oto [D]efinition' })
vim.keymap.set('n', '<leader>gD', vim.lsp.buf.declaration, { desc = '[G]oto [D]eclaration' })
vim.keymap.set('n', '<leader>gi', vim.lsp.buf.implementation, { desc = '[G]oto [I]mplementation' })
vim.keymap.set('n', '<leader>td', vim.lsp.buf.type_definition, { desc = '[G]oto [I]mplementation' })
vim.keymap.set('n', '<leader>cc', vim.lsp.codelens.refresh, { desc = 'Run Codelens' })

--vim.keymap.set('n', '<leader>ow', vim.cmd 'only', { desc = '[O]nly [I]mplementation' })
vim.keymap.set('n', '<leader>zo', function()
    -- Save the current cursor position
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    -- Get the current file's path.  `%` expands to the current file path.
    local current_file = vim.fn.expand '%'

    -- Check if we have a filename (not an unnamed buffer)
    if current_file ~= '' then
        -- Open the current file in a new tab.
        vim.cmd('tabnew ' .. current_file)

        -- Restore the cursor position in the *new* tab.
        vim.api.nvim_win_set_cursor(0, { row, col })
        vim.cmd 'normal! zz' -- make cursor centered
    end
end, { noremap = true, desc = '[Z]oom [O]pen' })

vim.keymap.set('n', '<leader>zc', ':tabclose<cr>', { desc = '[Z]oom [C]lose' })

-- marks

-- Exit terminal mode in the builtin terminal. This won't work in all terminal emulators/tmux/etc.
--  You normally need to press <C-\><C-n>
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- open powershell in a new tab
vim.keymap.set('n', '<leader>pwsh', function()
    vim.cmd [[:vsp term://pwsh -nol]]
end, { desc = 'PowerShell' })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
--vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
--vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
--vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
--vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

do -- Telescope bindings; see `:help telescope.builtin`
    local builtin = require 'telescope.builtin'
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>ps', builtin.live_grep, { desc = '[P]roject [S]earch' })
    vim.keymap.set('n', '<leader>pf', builtin.find_files, { desc = '[P]roject [F]iles' })

    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader>sm', builtin.marks, { desc = '[S]earch [M]arks' })

    vim.keymap.set('n', '<leader>su', builtin.commands, { desc = '[S]earch [U]ser commands' })

    local lsfn = function()
        builtin.buffers {
            sort_mru = true,

            attach_mappings = function(_, map)
                map({ 'i', 'n' }, '<C-d>', function(bufnr) -- _prompt_bufnr,
                    -- TODO: try to close picker automatically on zero results
                    -- results;
                    -- local selections = current_picker
                    -- local current_picker = action_state.get_current_picker(bufnr)

                    actions.delete_buffer(bufnr)
                end)

                return true -- return true to apply map to default_mappings
            end,
        }
    end

    -- vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
    vim.keymap.set('n', '<leader><leader>', lsfn, { desc = '[ ] Find existing buffers' })

    -- vim.keymap.set('n', '<C-p>', builtin.git_files, {})
    -- Slightly advanced example of overriding default behavior and theme
    vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            winblend = 10,
            previewer = false,
        })
    end, { desc = '[/] Fuzzily search in current buffer' })

    -- It's also possible to pass additional configuration options.
    --  See `:help telescope.builtin.live_grep()` for information about particular keys
    vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
        }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })

    vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })

    -- require('telescope.builtin').find_files {
    --     cwd = os.getenv 'CLOUD_DIR',
    --     prompt_title = 'Markdown search',
    --     find_command = {
    --         'fd',
    --         '--extension',
    --         'md',
    --     },
    -- }
    -- it is too slow because my dropbox directory is
    -- on a hard drive!
    --
    -- we need to use a search program that allows
    -- indexing. by default, everything does. (sadly not FOSS.)
    --
    -- TODO: research NowGrep when mature.
    --
    -- everything has a commandline : <https://github.com/voidtools/es>
    local function find_markdown()
        require('telescope.builtin').find_files {
            cwd = os.getenv 'CLOUD_DIR',
            prompt_title = 'Markdown search',
            find_command = {
                'es',
                '/a-d', -- only files not directories
                '-path',
                os.getenv 'CLOUD_DIR',
            },
        }
    end

    vim.keymap.set('n', '<leader>md', find_markdown, { desc = 'search [M]ark[D]own files' })

    -- custom picker function: colors
    -- local colors = function(opts)
    --     local pickers = require 'telescope.pickers'
    --     local finders = require 'telescope.finders'
    --     local conf = require('telescope.config').values
    --     opts = opts or {}
    --     pickers
    --         .new(opts, {
    --             prompt_title = 'colors',
    --             finder = finders.new_table {
    --                 results = GetMarkdownCatalog(),
    --             },
    --             sorter = conf.generic_sorter(opts),
    --         })
    --         :find()
    -- end
    -- vim.keymap.set('n', '<leader>sc', colors)
end

do -- CodeCompanion <https://github.com/search?q=repo%3Aolimorris%2Fcodecompanion.nvim%20keymap&type=code>
    local cc = require 'codecompanion'
    vim.keymap.set('n', '<A-c>', '<cmd>CodeCompanionChat Toggle<cr>', { desc = 'CodeCompanion' })
    vim.keymap.set('n', '<C-a>', '<cmd>CodeCompanionActions<cr>')
    vim.keymap.set('v', '<C-a>', '<cmd>CodeCompanionActions<cr>')
    -- vim.keymap.set("n", "<M-a>", "<cmd>CodeCompanionChat Toggle<cr>")
    -- vim.keymap.set("v", "<M-a>", "<cmd>CodeCompanionChat Toggle<cr>")
    -- vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>")
    vim.cmd [[cab cc CodeCompanion]]
end



--- @type vim.api.keyset.create_autocmd
M.LspAttachAutoCmd = { -- ./lazy-plugins/lsp.lua
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach-keymap', { clear = true }),
    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        ---@param desc string
        local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = desc })
        end

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

        -- Find references for the word under your cursor.
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', 'v')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        map('<leader>dl', function()
            --[[ This script inspects all active Neovim LSP clients and prints their full server capabilities into a new, read-only scratch buffer. ]]
            -- Get all currently active LSP clients attached to the buffer.
            local clients = vim.lsp.get_active_clients()
            local output_lines = {}
            --- Checks if a table is a sequence (array-like).
            -- A table is considered a sequence if its keys are a continuous
            -- set of integers starting from 1.
            -- @param tbl The table to check.
            -- @return boolean True if the table is a sequence.
            local function is_sequence(tbl)
                if type(tbl) ~= 'table' then
                    return false
                end
                local i = 0
                for _ in pairs(tbl) do
                    i = i + 1
                    if tbl[i] == nil then
                        return false
                    end
                end
                return true
            end

            --- Recursively formats a table of capabilities and adds them to the output.
            -- @param caps_table The table of capabilities to format.
            -- @param indent_level The current indentation level for pretty-printing.
            local function format_capabilities(caps_table, indent_level)
                -- Default to the base indentation level if not provided.
                indent_level = indent_level or 0
                local indent = string.rep('  ', indent_level)

                -- Sort keys for consistent and readable output.
                local sorted_keys = {}
                for key, _ in pairs(caps_table) do
                    table.insert(sorted_keys, key)
                end
                table.sort(sorted_keys)

                -- Iterate over the sorted keys to process each capability.
                for _, key in ipairs(sorted_keys) do
                    local value = caps_table[key]

                    if type(value) == 'table' then
                        if is_sequence(value) then
                            -- It's an array-like table. Format it on a single line.
                            local items = {}
                            for _, item in ipairs(value) do
                                if type(item) == 'table' then
                                    table.insert(items, '{...}')                     -- Avoid deep nesting in single-line format
                                elseif type(item) == 'string' then
                                    table.insert(items, string.format('"%s"', item)) -- Add quotes for clarity
                                else
                                    table.insert(items, tostring(item))
                                end
                            end
                            if #items == 0 then
                                table.insert(output_lines, string.format('%s%s = {}', indent, key))
                            else
                                table.insert(output_lines,
                                    string.format('%s%s = { %s }', indent, key, table.concat(items, ', ')))
                            end
                        else
                            -- It's an object/map-like table. Recurse into it.
                            table.insert(output_lines, string.format('%s%s:', indent, key))
                            format_capabilities(value, indent_level + 1)
                        end
                    else
                        -- If it's a primitive value (boolean, string, number), print it directly.
                        table.insert(output_lines, string.format('%s%s = %s', indent, key, tostring(value)))
                    end
                end
            end

            --- Displays the output lines in a new, non-editable scratch buffer.
            -- @param lines A table of strings to display.
            local function show_in_scratch_buffer(lines)
                -- Create a new scratch buffer (not listed, scratch type).
                local buf = vim.api.nvim_create_buf(false, true)

                -- Open the buffer in a new vertical split window.
                vim.api.nvim_open_win(buf, true, {
                    split = 'right',
                    width = 80, -- Set a reasonable default width
                })

                -- Set buffer options for a clean, read-only experience.
                vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe') -- Close buffer when window is closed
                vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile') -- Not a file-backed buffer
                vim.api.nvim_buf_set_option(buf, 'swapfile', false)   -- No swap file
                vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')   -- Set filetype for syntax highlighting

                -- Write the collected lines to the new buffer.
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                -- Make the buffer read-only *after* inserting the content.
                vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            end

            -- Main execution logic.
            if #clients == 0 then
                table.insert(output_lines, 'No active LSP clients found.')
            else
                table.insert(output_lines, 'Server capabilities for active LSP _clients:')
                for _, _client in ipairs(clients) do
                    table.insert(output_lines, '') -- Add a blank line for spacing between _clients.
                    table.insert(output_lines, string.format('--- _client: %s ---', _client.name))

                    -- Check if the _client reported any server capabilities.
                    if _client.server_capabilities and next(_client.server_capabilities) then
                        format_capabilities(_client.server_capabilities, 1)
                    else
                        table.insert(output_lines, '  No server capabilities found for this _client.')
                    end
                end
            end

            -- Display the final formatted output in the scratch buffer.
            show_in_scratch_buffer(output_lines)
        end, '[d]ebug [l]sp')

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        --

        local inlay_hint = vim.lsp.protocol.Methods.textDocument_inlayHint
        -- This may be unwanted, since they displace some of your code
        if client and client.supports_method(client, inlay_hint) then
            map('<leader>th', function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
        end

        vim.keymap.set('n', '<leader>dh', function()
            local params = vim.lsp.util.make_position_params(0, 'utf-8')
            vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
                border = 'rounded',
            })

            vim.lsp.buf_request_all(0, 'textDocument/hover', params, function(results)
                for _, res in pairs(results) do
                    if res.result and res.result.contents then
                        local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(res.result.contents)
                        markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
                        if not vim.tbl_isempty(markdown_lines) then
                            vim.lsp.util.open_floating_preview(markdown_lines, 'markdown', { border = 'single' })
                            return
                        end
                    end
                end
                vim.notify('No hover info available', vim.log.levels.INFO)
            end)
        end, { desc = 'Show hover docs (all clients)' })

        vim.keymap.set('n', '<leader>wc', function()
            -- Define the configuration sections you want to query.
            -- You must know the specific keys for your language servers.
            local params = {
                items = {
                    { section = 'powershell.workspace' }, -- Example for lua-language-server
                    { section = 'powershell.settings' },  -- Example for lua-language-server
                    -- { section = "pyright.analysis" }, -- Example for pyright
                    -- Add any other sections you want to inspect
                },
            }

            -- Request the configuration from all attached LSP servers.
            vim.lsp.buf_request_all(0, 'workspace/configuration', params, function(results)
                local all_configs = {}
                local found_config = false

                for client_id, res in pairs(results) do
                    -- The result is an array of the requested configuration values.
                    if res.result and not vim.tbl_isempty(res.result) then
                        found_config = true
                        local client = vim.lsp.get_client_by_id(client_id)
                        local client_name = client and client.name or tostring(client_id)
                        all_configs[client_name] = res.result
                    end
                end

                if not found_config then
                    vim.notify('No server returned a configuration.', vim.log.levels.WARN)
                    return
                end

                -- Use vim.inspect() to convert the Lua table to a readable string.
                local output_lines = vim.split(vim.inspect(all_configs), '\n')

                -- Display the raw configuration result in a floating preview window.
                vim.lsp.util.open_floating_preview(output_lines, 'lua', { border = 'single' })
            end)
        end, { desc = '[W]orkspace [C]onfiguration' })
    end,
}

vim.keymap.set('n', '<leader>B', function() require('gitsigns').blame_line() end, { desc = 'Git blame line' })
-- # KEYMAPS SET IN OTHER FILES:
-- <leader>
--
-- map commands in lua/lazy-plugins/lsp.lua
--
return M
