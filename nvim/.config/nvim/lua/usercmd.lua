-- like this: 16:55
vim.api.nvim_create_user_command('InsertTime', function()
    vim.cmd.normal '^'; -- go to beginning of line
    -- Insert before the cursor position
    vim.api.nvim_put({ string(os.date '%H:%M') }, '', false, true)
end, { desc = 'create time like 16:56' })

vim.api.nvim_create_user_command('GetLspConfig', function(opts)
    local server_name = opts.fargs[1]
    if not server_name then
        vim.notify('Error: LSP server name not provided.', vim.log.levels.ERROR)
        return
    end

    local lspconfig = require 'lspconfig'
    local server_config = lspconfig[server_name]

    if not server_config then
        vim.notify('LSP server config not found: ' .. server_name, vim.log.levels.ERROR)
        return
    end

    -- Deep copy the table to avoid modifying the original lspconfig table in memory.
    local deepcopy
    deepcopy = function(original)
        if type(original) ~= 'table' then
            return original
        end
        local copy = {}
        for k, v in pairs(original) do
            copy[deepcopy(k)] = deepcopy(v)
        end
        return copy
    end
    local config_copy = deepcopy(server_config)

    -- This helper function traverses a table and replaces function objects
    -- with a descriptive string using the debug library.
    local function describe_functions(tbl, seen)
        seen = seen or {}
        if type(tbl) ~= 'table' or seen[tbl] then
            return
        end
        seen[tbl] = true

        for k, v in pairs(tbl) do
            if type(v) == 'function' then
                local info = debug.getinfo(v, 'S')
                if info and info.source and info.linedefined > 0 then
                    local source_path = info.source:gsub('^@', '')
                    -- We create a special string that we can find and unquote later.
                    tbl[k] = string.format('---FUNC---function() --[[ defined in %s:%d ]] end---ENDFUNC---', source_path,
                        info.linedefined)
                else
                    tbl[k] = '---FUNC---function() --[[ C function or unknown source ]] end---ENDFUNC---'
                end
            elseif type(v) == 'table' then
                describe_functions(v, seen); -- Recurse into sub-tables
            end
        end
    end

    describe_functions(config_copy)

    -- Format the modified table into a readable string using vim.inspect.
    local config_str = 'return ' .. vim.inspect(config_copy)

    -- Post-process the string to remove quotes and markers around our function descriptions,
    -- making the output appear as valid Lua code.
    config_str = config_str:gsub('"---FUNC---(.-)---ENDFUNC---"', '%1')

    -- Open a new scratch buffer to display the config.
    vim.cmd 'vnew'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(config_str, '\n'))

    -- Set buffer options for a clean, temporary view.
    vim.bo.bufhidden = 'wipe'
    vim.bo.buftype = 'nofile'
    vim.bo.swapfile = false
    vim.bo.filetype = 'lua'
end, {
    nargs = 1,
    desc = 'Get lspconfig settings for a server, with function descriptions.',
    complete = function()
        -- Provide completion for all available servers in lspconfig.
        local lspconfig = require 'lspconfig'
        local servers = {}
        for server, _ in pairs(lspconfig) do
            if type(lspconfig[server]) == 'table' and server:sub(1, 1) ~= '_' and lspconfig[server].cmd then
                table.insert(servers, server)
            end
        end
        table.sort(servers)
        return servers
    end,
})

vim.api.nvim_create_user_command('Notifications', function()
    require('fidget').notification.show_history()
end, { desc = 'Get fidget notification history' })

local function show_diff_since_last_saved()
    local current_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local file_path = vim.api.nvim_buf_get_name(0)

    if vim.fn.filereadable(file_path) == 1 then
        local saved_content = vim.fn.readfile(file_path)
        local diff = vim.diff(table.concat(current_content, '\n'), table.concat(saved_content, '\n'))
        print(diff)
    else
        print "File not saved yet or doesn't exist"
    end
end

vim.api.nvim_create_user_command('OpenOnGithub', function()
    local current_file = vim.fn.expand('%:p')
    local git_root = vim.fs.dirname(vim.fs.find('.git', { path = vim.fs.dirname(current_file), upward = true })[1])
    if git_root then
        vim.cmd('silent !cd "' .. git_root .. '" && gh browse %')
    else
        vim.notify('Not in a git repository', vim.log.levels.ERROR)
    end
end, {})

vim.api.nvim_create_user_command('DiffSinceSaved', show_diff_since_last_saved, {})

local screenshot_windows = {}
local screenshot_group
-- Native winbar expressions refresh on redraw, including scrolling. No scroll
-- callback, buffer edits, or persistent global Lua functions are needed.
local screenshot_winbar = "%{expand('%:p')} start_line=%{line('w0')}"

local function stop_screenshot_tracking()
    if next(screenshot_windows) == nil and screenshot_group then
        vim.api.nvim_del_augroup_by_id(screenshot_group)
        screenshot_group = nil
    end
end

vim.api.nvim_create_user_command('ScreenshotMode', function()
    local win = vim.api.nvim_get_current_win()
    local saved = screenshot_windows[win]
    if saved then
        for option, value in pairs(saved) do
            vim.wo[win][option] = value
        end
        screenshot_windows[win] = nil
        stop_screenshot_tracking()
        vim.notify('Screenshot Mode: OFF', vim.log.levels.INFO)
        return
    end

    saved = {}
    for _, option in ipairs({ 'number', 'relativenumber', 'list', 'signcolumn', 'foldenable', 'winbar', 'scrolloff' }) do
        saved[option] = vim.wo[win][option]
    end
    screenshot_windows[win] = saved

    if not screenshot_group then
        screenshot_group = vim.api.nvim_create_augroup('screenshot-winbar', { clear = true })
        -- Run after the existing cwd-header updater without modifying it.
        vim.api.nvim_create_autocmd({ 'DirChanged', 'BufWinEnter', 'CmdlineLeave' }, {
            group = screenshot_group,
            callback = function()
                for active_win in pairs(screenshot_windows) do
                    if vim.api.nvim_win_is_valid(active_win) then
                        if vim.wo[active_win].winbar ~= screenshot_winbar then
                            vim.wo[active_win].winbar = screenshot_winbar
                        end
                    end
                end
            end,
        })
        vim.api.nvim_create_autocmd('WinClosed', {
            group = screenshot_group,
            callback = function(event)
                screenshot_windows[tonumber(event.match)] = nil
                stop_screenshot_tracking()
            end,
        })
    end

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].list = false
    vim.wo[win].signcolumn = 'no'
    vim.wo[win].foldenable = false
    vim.wo[win].scrolloff = 0
    vim.wo[win].winbar = screenshot_winbar
    vim.notify('Screenshot Mode: ON', vim.log.levels.INFO)
end, {
    desc = 'Toggle screenshot mode with full path and viewport start line',
})

vim.api.nvim_create_user_command('Gbrowse', 'GBrowse', {})


vim.api.nvim_create_user_command('Tgrep', function(opts)
    -- Use the table form of vim.cmd which calls nvim_cmd() directly.
    -- Unlike the string form the table passes args directly
    -- without shell parsing
    --
    --  in combination with
    --  vim.opt.grepprg = 'rg --vimgrep --smart-case'
    --
    -- lets you call rg without quotes, for example:
    --
    -- :Tgrep -F html(
    -- replacing:
    -- :grep -F 'html(' | copen
    --
    vim.cmd({
        cmd  = 'grep',
        args = opts.fargs,
        bang = true,
        mods = { silent = true },
    })

    require('telescope.builtin').quickfix()
end, {
    nargs    = '+',
    desc     = 'Run :grep and show results in Telescope',
    complete = 'file',
})

vim.api.nvim_create_user_command('ReadCmd', function(opts)
    local lines = vim.split(vim.fn.execute(opts.args), '\n', { plain = true })
    vim.api.nvim_put(lines, 'l', true, true)
end, {
    nargs = '+',
})
