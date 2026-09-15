function InsertAbbreviatedTime()
    local time = os.date '%H:%M'
    -- go to beginning of line
    vim.cmd.normal '^'
    -- Insert the filename before the cursor position
    vim.api.nvim_put({ time }, '', true, true)
end
