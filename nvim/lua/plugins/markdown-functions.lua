-- ../after/ftplugin/markdown.lua

local function openFile(applicationPath, filePath)
    local command = [[pwsh -c "Start-Process ']] .. applicationPath .. [[' -ArgumentList ']] .. filePath .. [['" ]]
    print(command)

    -- Execute the command
    local result = os.execute(command)
    if result == 0 then
        print 'File opened successfully.'
    else
        print 'Error opening file.'
    end
end

function MarkdownLink()
    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))

    -- Check if it's a multi-line selection (not supported for this example)
    if start_row ~= end_row then
        vim.api.nvim_err_writeln 'Multi-line selection is not supported.'
        return
    end

    -- Handle no selection
    if start_col == end_col then
        local current_line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
        local new_text = current_line .. '[Link text](link_url)'
        vim.api.nvim_buf_set_lines(0, start_row - 1, start_row, false, { new_text })
        return
    end

    -- Get the selected text
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
    local selected_text = lines[1]:sub(start_col + 1, end_col + 1) -- Include the last character

    -- Construct the new text with the link format
    -- local new_text = '() [' .. selected_text .. ']'
    local new_text = '(' .. selected_text .. '](Link_'

    -- Replace the selected text with the new text
    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, start_row - 1, end_col + 1, { new_text })

    -- Calculate the new cursor position to select "Link".
    local new_start_col = start_col + #selected_text + 2 -- +2 for the ](
    local new_end_col = new_start_col + 4 -- 4 for the length of "Link"

    -- Set the visual selection.

    local link_start_col = start_col + #selected_text + 3 -- Position after the closing parenthesis and '['
    vim.api.nvim_win_set_cursor(0, { start_row, link_start_col })
    vim.cmd 'normal! v'
    vim.api.nvim_win_set_cursor(0, { start_row, link_start_col + 3 }) -- Assuming 'Link' is 4 characters long
end

function InsertMarkdownLink()
    local current_line = vim.fn.getline '.'

    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) -- Get row and col
    local new_text = '[Link text](link_url)'

    vim.api.nvim_buf_set_text(0, row - 1, col - 1, row - 1, col - 1, { new_text })
end

function CheckPowershellCommandAvailable(scriptName)
    local command = [[pwsh.exe -c "(Get-Command -Name ']] .. scriptName .. [[' -ErrorAction SilentlyContinue) -and $?"]]
    -- Execute the command and capture the output
    local handle = io.popen(command)
    local out = handle:read '*a'
    handle:close()

    print(out)

    -- Trim whitespace and convert to lowercase for comparison
    available = out:gsub('%s+', ''):lower()
    return available == 'true'
end

local function trim(s)
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end

function GetDefaultBrowser()
    if CheckPowershellCommandAvailable 'Get-DefaultBrowser' then
        local command = [[pwsh.exe -c Get-DefaultBrowser]]

        local handle = io.popen(command)
        local out = handle:read '*a'
        handle:close()

        return trim(out)
    end
end

function OpenMarkdownInBrowser()
    local currentFilename = vim.fn.expand '%:p' -- Get the current filename
    local browser = GetDefaultBrowser()
    openFile(browser, currentFilename)
end

--   function MarkdownLink()
--     -- Get the current visual selection
--     local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
--     local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
--
--     -- Check if it's a multi-line selection (not supported for this example)
--     if start_row ~= end_row then
--       vim.api.nvim_err_writeln 'Multi-line selection is not supported.'
--       return
--     end
--
--     -- Get the selected text
--     local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
--     local selected_text = lines[1]:sub(start_col + 1, end_col)
--
--     -- Construct the new text with the link format
--     local new_text = '(Link text)[' .. selected_text .. ']'
--
--     local line_length = #lines[1]
--     if end_col == line_length then
--       -- If at the end of the line, insert the new text and a newline
--       vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, { new_text })
--     else
--       -- Replace the selected text with the new text (normal case)
--       vim.api.nvim_buf_set_text(0, start_row - 1, start_col, start_row - 1, end_col, { new_text })
--     end
--   end
