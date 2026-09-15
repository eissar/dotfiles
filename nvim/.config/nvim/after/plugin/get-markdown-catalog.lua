function GetMarkdownCatalog()
    local catalogCategories = {}

    local job_pandoc = vim.fn.jobstart({
        'pwsh.exe',
        '-NoLogo',
        '-Command',
        [[ 
            $items = Get-ChildItem "$env:CLOUD_DIR/Catalog/*.md" | Where-Object {
                $_.Name -match '.*\..*\.md'
            }
            $matches = ($items | ForEach-Object {
                $bn = $_.BaseName
                $parts = $bn -split '\.';
                $cat = $parts[1]
                if ([String]::IsNullOrWhitespace($cat)) {
                    return;
                };
                if ( -NOT $parts.Length -eq 2 ) {
                    return; # case: too many periods; not a category note
                };
                return $cat | Get-Unique
            }) | Select -Unique
            Write-Output $matches
        ]],
    }, {
        on_stdout = function(_, data, _)
            if data then
                for _, line in ipairs(data) do
                    if line and line ~= '' then
                        local output = vim.trim(line)
                        table.insert(catalogCategories, output)
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
            if exit_code ~= 0 then
                vim.notify('Pwsh job failed with exit code: ' .. exit_code, vim.log.levels.ERROR)
            end
        end,
    })
    vim.fn.jobwait { job_pandoc, 100000 } -- 100000 ms
    return catalogCategories
end
