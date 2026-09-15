function PrintFile()
    local filename = vim.fn.expand '%:p' -- Get the current filename
    local outfile = 'C:/Users/eshaa/Dropbox/Documents/output.html'
    local pdoc = 'C:/Program Files/Pandoc/pandoc.exe'

    local home = os.getenv 'USERPROFILE'

    --local cssfile = 'C:/Users/eshaa/Downloads/tufte.css'
    local cssfile = home .. '/Dropbox/Application_Files/css/pico.blue.css'

    local function file_exists(name)
        local f = io.open(name, 'r')
        if f ~= nil then
            io.close(f)
            return true
        else
            return false
        end
    end

    local function executePrintFile()
        assert(file_exists(cssfile), 'css file does not exist!')

        -- create pandoc string
        local pandoc_cmd = string.format([[pandoc -c %s -f gfm+hard_line_breaks '%s' -o '%s']], cssfile, filename, outfile)
        -- local pandoc_cmd = pdoc .. ' --version'
        -- print(pandoc_cmd)

        vim.fn.setreg('*', pandoc_cmd)

        -- Execute the Pandoc command
        local job_pandoc = vim.fn.jobstart({ 'pwsh.exe', '-NoLogo', '-Command', pandoc_cmd }, {
            on_stdout = function(_, data, _)
                if data then
                    for _, line in ipairs(data) do
                        if line and line ~= '' then
                            local output = vim.trim(line)
                            vim.notify(output)
                        end
                    end
                end
            end,
            on_stderr = function(_, data, _)
                if data then
                    for _, line in ipairs(data) do
                        if line and line ~= '' then
                            vim.notify('Error: ' .. line, vim.log.levels.ERROR)
                        end
                    end
                end
            end,
            on_exit = function(_, exit_code, _)
                if exit_code == 0 then
                    vim.notify 'Pandoc job completed successfully!'
                else
                    vim.notify('Pandoc job failed with exit code: ' .. exit_code, vim.log.levels.ERROR)
                end
            end,
        })
        vim.fn.jobwait { job_pandoc, 100000 }

        -- Open the file
        -- local open_cmd = string.format([[!start '%s']], outfile)
        local open_cmd = string.format('Start-Process -FilePath msedge -argumentList %s', outfile)
        print(outfile)
        local job_open = vim.fn.jobstart { 'powershell', '-Command', open_cmd }
        vim.fn.jobwait { job_open }

        -- vim.notify('HTML conversion completed: ' .. outfile)
    end

    -- if outfile already exists, ask for confirmation
    if file_exists(outfile) == false then
        executePrintFile()
    else
        vim.ui.input({
            prompt = outfile .. ' already exists, continue? (y/n)',
        }, function(input)
            if input == 'y' then
                assert(os.remove(outfile))
                executePrintFile()
            end
        end)
    end
end
