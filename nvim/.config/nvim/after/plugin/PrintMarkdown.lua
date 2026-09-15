function PrintMarkdown()
  local filename = vim.fn.expand '%:p' -- Get the current filename
  local marktext = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
  local function openFileWithApplication(filePath, applicationPath)
    local command = [[pwsh -c "Start-Process ']] .. applicationPath .. [[' -ArgumentList ']] .. filePath .. [['" ]]

    -- Execute the command
    local result = os.execute(command)
    if result == 0 then
      print 'File opened successfully.'
    else
      print 'Error opening file.'
    end
  end

  openFileWithApplication(filename, marktext)
end
