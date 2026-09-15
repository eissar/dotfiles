function GetGoModules()
  local command = [[pwsh -c "Get-GoMod" ]]

  -- Execute the command and capture the output
  local file = io.popen(command, "r") -- "r" for reading

  if file then
    local output = file:read("*a") -- Read all content
    file:close()

    if output then
      print(output)
    else
      print("Command returned no output.")
    end
  else
    print("Error executing command.")
  end
end

local function open_string_in_split_scratch_buffer(text)
  local buf = vim.api.nvim_create_buf(false, true) -- Changed to false (listed)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Split the window *before* setting the buffer
  vim.cmd [[vsplit]]

  -- Get the window ID of the newly created window
  local new_win = vim.api.nvim_get_current_win()

  -- Set the buffer for the new window using its ID
  vim.api.nvim_win_set_buf(new_win, buf)
end



local function getGoHelp(modName)


  local helpUri = [[https://pkg.go.dev/]] .. modName
  local command = [[pwsh -c "Get-GoModHelp -Uri ]] .. helpUri .. [[" ]]

  -- Execute the command and capture the output
  local file = io.popen(command, "r") -- "r" for reading

  if file then
    local output = file:read("*a") -- Read all content
    file:close()

    if output then
      open_string_in_split_scratch_buffer(output)
      print(output)
    else
      print("Command returned no output.")
    end
  else
    print("Error executing command.")
  end

end

function HookTelescope()
  local modulesArr = {
    "github.com/BurntSushi/toml@v0.3.1",
    "github.com/adrg/frontmatter@v0.2.0",
    "go@1.22.4","gopkg.in/yaml.v2@v2.3.0"
  }

  local pickers = require('telescope.pickers');
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require('telescope.actions')
  local action_state = require "telescope.actions.state"
  -- Use functions as keys to map to which function to execute when called.

  actions.select_default:replace(
    print
  )


  local colors = function(opts)
    opts = opts or {
      initial_mode = 'normal'
    }
    local pick = pickers.new(opts, {
      prompt_title = "colors",
      finder = finders.new_table {
        results = modulesArr
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- print(vim.inspect(selection))
          -- vim.api.nvim_put({ selection[1] }, "", false, true)
          -- Get Help for this function from the web
          getGoHelp(selection[1])
        end)
        return true
      end,
    })
    pick:find()
  end

  -- to execute the function
  colors()
end
