function RunSelection()
    local function get_visual_selection()
      local s_start = vim.fn.getpos("'<")
      local s_end = vim.fn.getpos("'>")
      local n_lines = math.abs(s_end[2] - s_start[2]) + 1
      local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
      lines[1] = string.sub(lines[1], s_start[3], -1)
      if n_lines == 1 then
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
      else
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
      end
      return table.concat(lines, '')
    end

    vim.ui.select({ "Confirm", "Cancel" }, { prompt = "Run selected text in powershell?" }, function(choice)
        if choice == "Confirm" then
            local selected_text = get_visual_selection()
            local run_command = [[:tabe term://powershell "]] .. selected_text .. [["]]
            vim.cmd(run_command)
            vim.cmd(':startinsert')
        end
    end)

    -- vim.fn.input(":" .. get_visual_selection() )
end
