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

vim.api.nvim_create_user_command('CodeCompanionSwitchAdapter', function(opts)
    local config = require 'codecompanion.config'
    -- require('codecompanion.strategies.chat.keymaps').change_adapter.callback()

    local adapters = config.adapters.http
    local adapters_list = vim.iter(adapters)
        :filter(function(adapter)
            -- Clear out the acp and http keys
            return adapter ~= 'opts' and adapter ~= 'acp' and adapter ~= 'http' and adapter ~= current_adapter
        end)
        :map(function(adapter, _)
            return adapter
        end)
        :totable()

    table.sort(adapters_list)
    -- table.insert(adapters_list, 1, current_adapter)

    vim.ui.select(adapters_list, {}, function(selected) -- on select callback
        if not selected then
            return
        end

        local adapter = require('codecompanion.adapters').resolve(adapters[selected])

        -- if type(adapter.schema.default) == 'function' then
        --     adapter.schema.default = adapter.schema.choices and adapter.schema.choices[1] or nil
        -- end
        -- adaptera = require('codecompanion.adapters').make_safe(adapter)
        adapter = require('codecompanion.adapters.http').set_model(adapter)

        print(vim.inspect(adapter))
        -- print(vim.inspect(adapter))
        -- goto ret

        require('codecompanion.strategies.chat').new {
            adapter = adapter,
            -- buffer_context = context,
            -- messages = has_messages and messages or nil,
            -- auto_submit = has_messages,
        }

        ::ret::
        if true then
            return
        end

        if current_adapter ~= selected then
            chat.acp_connection = nil
            chat.adapter = require('codecompanion.adapters').resolve(adapters[selected])
            util.fire('ChatAdapter',
                { bufnr = chat.bufnr, adapter = require('codecompanion.adapters').make_safe(chat.adapter) })
            chat.ui.adapter = chat.adapter
            chat:update_metadata()
            chat:apply_settings()
        end

        -- Update the system prompt
        local system_prompt = config.opts.system_prompt
        if type(system_prompt) == 'function' then
            if chat.messages[1] and chat.messages[1].role == 'system' then
                local opts = { adapter = chat.adapter, language = config.opts.language }
                chat.messages[1].content = system_prompt(opts)
            end
        end

        local models = chat.adapter.schema.model.choices
        if not config.adapters.http.opts.show_model_choices then
            models = { chat.adapter.schema.model.default }
        end
        if type(models) == 'function' then
            models = models(chat.adapter, { async = false })
        end
        if not models or vim.tbl_count(models) < 2 then
            return
        end

        local new_model = chat.adapter.schema.model.default
        if type(new_model) == 'function' then
            new_model = new_model(chat.adapter)
        end

        models = vim.iter(models)
            :map(function(model, value)
                if type(model) == 'string' then
                    return model
                else
                    return value; -- This is for the table entry case
                end
            end)
            :filter(function(model)
                return model ~= new_model
            end)
            :totable()
        table.sort(models)
        table.insert(models, 1, new_model)

        vim.ui.select(models, select_opts('Select Model', new_model), function(selected_model)
            if not selected_model then
                return
            end

            if current_model ~= selected_model then
                util.fire('ChatModel', { bufnr = chat.bufnr, model = selected_model })
            end

            chat:apply_model(selected_model)
            chat:update_metadata()
            chat:apply_settings()
        end)
    end)
end, { desc = 'Switch CodeCompanion adapter (cycle through available adapters)' })

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

vim.api.nvim_create_user_command('ScreenshotMode', function()
    if vim.opt.number:get() == true then
        -- Turn OFF 'number' and 'list' (Enter screenshot mode)
        vim.opt.relativenumber = false
        vim.opt.number = false
        vim.opt.list = false
        vim.notify('Screenshot Mode: ON', vim.log.levels.INFO)
        vim.opt.foldenable = false
    else
        vim.opt.relativenumber = true
        vim.opt.number = true
        vim.opt.list = true
        vim.opt.foldenable = true
        vim.notify('Screenshot Mode: OFF', vim.log.levels.INFO)
    end
end, {
    desc = 'Toggle screenshot mode (no numbers, no whitespace)'
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
