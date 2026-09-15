function CopyFilePath()
  local fpath = vim.fn.expand '%:p'
  vim.api.nvim_set_vvar('*', fpath)

  vim.notify('filepath: ' .. fpath, vim.log.levels.INFO)
end
