function PopupWindow()
    -- Define the size of the floating window
    local width_percentage = 0.5
    local height_percentage = 0.5

    -- Get the current UI
    local uis = vim.api.nvim_list_uis()
    local ui = nil
    if #uis > 0 then
        ui = uis[1]
    else
        print 'No UI attached'
        return
    end

    -- Calculate width and height based on percentages
    local width = math.floor(ui.width * width_percentage)
    local height = math.floor(ui.height * height_percentage)

    -- Create the scratch buffer displayed in the floating window
    -- In Lua, we use vim.api to interact with Neovim's API
    local buf = vim.api.nvim_create_buf(false, true)

    -- Get the current UI
    local uis = vim.api.nvim_list_uis()
    local ui = nil
    if #uis > 0 then
        ui = uis[1]
    else
        print 'No UI attached'
        return
    end

    -- Create the floating window
    local opts = {
        relative = 'editor',
        width = width,
        height = height,
        col = (ui.width / 2) - (width / 2),
        row = (ui.height / 2) - (height / 2),
        anchor = 'NW',
        style = 'minimal',
        focusable = true, -- Allow the window to receive focus
    }
    local win = vim.api.nvim_open_win(buf, true, opts)
end
