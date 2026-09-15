-- some vibecoded, some ripped from
-- https://github.com/sigmaSd/deno-nvim


local function virtual_text_document_handler(fname, res, client)
    if not res or not res.result then
        return nil
    end
    local result = res.result

    local bufnr = (function()
        vim.cmd.vsplit()
        vim.cmd.enew()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(bufnr, fname)
        return bufnr
    end)()

    local lines
    local filetype
    if type(result) == 'table' then
        lines = vim.split(vim.json.encode(result), '\n')
        filetype = 'json'
    else
        lines = vim.split(result, '\n')
        filetype = 'markdown'
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)
    vim.lsp.buf_attach_client(bufnr, client.id)

    -- format then set to readonly and remove modified flag
    vim.lsp.buf.format()
    vim.api.nvim_buf_set_option(bufnr, 'modified', false)
    vim.api.nvim_buf_set_option(bufnr, 'readonly', true)
end

vim.api.nvim_create_user_command('DenoStatus', function()
    for _, client in ipairs(vim.lsp.get_active_clients()) do
        if client.name == 'denols' then
            local result = client.request_sync('deno/virtualTextDocument', {
                textDocument = { uri = 'deno:/status.md' },
            })
            virtual_text_document_handler('status.md', result, client)
            break
        end
    end
end, {})

local deno_check_qf_running = false

local function normalize(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
end

local function is_within(path, root)
    path = normalize(path)
    root = normalize(root)

    local sep = package.config:sub(1, 1)
    return path == root or path:sub(1, #root + 1) == root .. sep
end

local function find_deno_root()
    local current = vim.api.nvim_buf_get_name(0)
    local start = current ~= '' and current or vim.uv.cwd()

    return vim.fs.root(start, { 'deno.json', 'deno.jsonc' })
        or vim.fs.root(vim.uv.cwd(), { 'deno.json', 'deno.jsonc' })
end

local function find_denols_client(root)
    local matches = {}

    for _, client in ipairs(vim.lsp.get_clients({ name = 'denols' })) do
        local client_root = client.root_dir or client.config.root_dir

        if client_root and is_within(root, client_root) then
            table.insert(matches, client)
        end
    end

    table.sort(matches, function(a, b)
        local ar = a.root_dir or a.config.root_dir or ''
        local br = b.root_dir or b.config.root_dir or ''
        return #ar > #br
    end)

    return matches[1]
end

local function collect_typescript_files(root)
    local ignored_dirs = {
        ['.git'] = true,
        ['node_modules'] = true,
    }

    local files = {}

    local function walk(dir)
        for name, kind in vim.fs.dir(dir) do
            local path = vim.fs.joinpath(dir, name)

            if kind == 'directory' then
                if not ignored_dirs[name] then
                    walk(path)
                end
            elseif kind == 'file' then
                if name:match('%.tsx?$')
                    or name:match('%.mts$')
                    or name:match('%.cts$')
                then
                    table.insert(files, normalize(path))
                end
            end
        end
    end

    walk(root)
    table.sort(files)

    return files
end


local function diagnostic_col(lines, position, client)
    local line = lines[position.line + 1] or ''
    local encoding = client.offset_encoding or 'utf-16'

    -- Nvim 0.11+ signature.
    local ok, byte_index = pcall(
        vim.str_byteindex,
        line,
        encoding,
        position.character,
        false
    )

    -- Compatibility fallback for older Nvim signatures.
    if not ok then
        if encoding == 'utf-8' then
            byte_index = position.character
        else
            ok, byte_index = pcall(
                vim.str_byteindex,
                line,
                position.character,

                encoding == 'utf-16'
            )

            if not ok then
                byte_index = position.character
            end
        end
    end

    return byte_index + 1
end

local severity_to_qf_type = {
    [1] = 'E',
    [2] = 'W',
    [3] = 'I',
    [4] = 'N',
}

local function diagnostic_to_qf_item(path, lines, diagnostic, client)
    local start = diagnostic.range and diagnostic.range.start
        or { line = 0, character = 0 }

    local message = (diagnostic.message or ''):gsub('[\r\n]+', ' ')

    if diagnostic.code ~= nil then
        message = message .. ' [' .. tostring(diagnostic.code) .. ']'
    end

    if diagnostic.source then
        message = diagnostic.source .. ': ' .. message
    end

    return {
        filename = path,
        lnum = start.line + 1,
        col = diagnostic_col(lines, start, client),
        text = message,
        type = severity_to_qf_type[diagnostic.severity] or 'E',
    }
end

vim.api.nvim_create_user_command('DenoCheck', function()
    if deno_check_qf_running then
        vim.notify('denols diagnostics are already running', vim.log.levels.WARN)
        return
    end

    local root = find_deno_root()
    if not root then
        vim.notify('No deno.json or deno.jsonc found', vim.log.levels.ERROR)
        return
    end

    root = normalize(root)

    local client = find_denols_client(root)
    if not client then
        vim.notify(
            'No running denols client found for ' .. root,
            vim.log.levels.ERROR
        )
        return
    end

    if not client:supports_method('textDocument/diagnostic') then
        vim.notify(
            'The existing denols client does not support textDocument/diagnostic',
            vim.log.levels.ERROR
        )
        return
    end

    local files = collect_typescript_files(root)
    if #files == 0 then
        vim.notify('No TypeScript files found under ' .. root, vim.log.levels.INFO)
        return
    end

    deno_check_qf_running = true

    local items = {}
    local failures = {}
    local index = 1

    local function process_next()
        local path = files[index]
        index = index + 1

        -- All files processed: sort results and populate quickfix.
        if not path then
            deno_check_qf_running = false

            table.sort(items, function(a, b)
                if a.filename ~= b.filename then
                    return a.filename < b.filename
                elseif a.lnum ~= b.lnum then
                    return a.lnum < b.lnum
                else
                    return a.col < b.col
                end
            end)

            vim.fn.setqflist({}, 'r', {
                title = 'denols diagnostics: ' .. root,
                items = items,
            })

            if #failures > 0 then
                vim.notify(
                    ('denols: %d file(s) failed; %d diagnostic(s) collected'):format(
                        #failures,
                        #items
                    ),
                    vim.log.levels.WARN
                )
            elseif #items == 0 then
                vim.notify(
                    ('denols: no diagnostics across %d TypeScript file(s)'):format(#files),
                    vim.log.levels.INFO
                )
            else
                vim.notify(
                    ('denols: %d diagnostic(s) across %d TypeScript file(s)'):format(
                        #items,
                        #files
                    ),
                    vim.log.levels.INFO
                )
            end

            vim.cmd('cwindow')
            return
        end

        -- Open (or reuse) a buffer for the file and attach denols.
        local bufnr = vim.fn.bufnr(path, false)
        local created_buf = false

        if bufnr == -1 then
            bufnr = vim.fn.bufadd(path)
            created_buf = true
        end

        vim.fn.bufload(bufnr)

        if not vim.lsp.buf_is_attached(bufnr, client.id) then
            vim.lsp.buf_attach_client(bufnr, client.id)
        end

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        local done = false
        local timer = vim.defer_fn(function()
            if done then return end
            done = true
            table.insert(failures, path .. ': timed out waiting for denols diagnostics')

            if created_buf and vim.api.nvim_buf_is_valid(bufnr) then
                pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end

            process_next()
        end, 5000)

        local request_id, request_err = client:request(
            'textDocument/diagnostic',
            {
                textDocument = {
                    uri = vim.uri_from_bufnr(bufnr),
                },
            },
            function(err, result)
                if done then return end
                done = true
                timer:stop()

                if err then
                    table.insert(failures, path .. ': ' .. (err.message or vim.inspect(err)))
                elseif result and result.kind == 'full' then
                    for _, diagnostic in ipairs(result.items or {}) do
                        table.insert(
                            items,
                            diagnostic_to_qf_item(path, lines, diagnostic, client)
                        )
                    end
                end

                if created_buf and vim.api.nvim_buf_is_valid(bufnr) then
                    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
                end

                process_next()
            end,
            bufnr
        )

        if not request_id then
            done = true
            timer:stop()

            table.insert(
                failures,
                path .. ': failed to send diagnostic request: ' .. tostring(request_err)
            )

            if created_buf and vim.api.nvim_buf_is_valid(bufnr) then
                pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end

            vim.schedule(process_next)
        end
    end

    process_next()
end, {
    desc = 'Collect denols diagnostics for all TypeScript files into quickfix',
})

local function dap_start(args)
    local dap = require('dap')

    local dap_config = {
        name = 'Deno: Debug Tests',
        type = 'pwa-node',
        request = 'launch',
        runtimeExecutable = 'deno',
        runtimeArgs = {
            'test',
            '--inspect-wait=127.0.0.1:9229', -- Tell Deno EXACTLY where to open the socket
            '--no-check',
            '-A',
            args.program,
            '--filter',
            args.test_filter,
        },
        attachSimplePort = 9229, -- Tell the debugger EXACTLY where to connect
        cwd = args.cwd or vim.fn.getcwd(),
        console = 'integratedTerminal',
        sourceMaps = true,
        localRoot = args.cwd or vim.fn.getcwd(),
        remoteRoot = args.cwd or vim.fn.getcwd(),
    }

    dap.run(dap_config)
end

vim.lsp.commands['deno.client.test'] = function(args)
    local file = vim.uri_to_fname(args.arguments[1])
    local cwd = vim.fs.root(file, { 'deno.json', 'deno.jsonc' })
        or vim.fs.dirname(file)
    local test_name = args.arguments[2]
    local escaped_test_name = test_name:gsub('([\\%^%$%.%|%?%*%+%(%)%[%]%{%}])', '\\%1')
    local test_filter = '/^' .. escaped_test_name .. '$/'

    if args.title == 'Debug' then
        -- we use dap here
        dap_start({
            program = file,
            cwd = cwd,
            test_filter = test_filter,
        })
    else
        -- run command
        vim.cmd.split()
        vim.fn.termopen({
            'deno',
            'test',
            '--no-check',
            '-A',
            file,
            '--filter',
            test_filter,
        }, {
            cwd = cwd,
        })
        vim.cmd.startinsert()
    end
end
