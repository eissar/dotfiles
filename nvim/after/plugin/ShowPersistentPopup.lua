function ShowPersistentPopup(file)
  vim.notify('This buffer has autosaving enabled.', vim.log.levels.ERROR, {
    timeout = false,
    title = 'Open in Neovim',
    icon = ' ',
    replace = false,
  })
end
