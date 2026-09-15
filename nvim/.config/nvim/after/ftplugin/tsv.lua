vim.cmd('setlocal nowrap')
vim.opt_local.expandtab = false

-- "asdf" "3 2"

-- https://www.reddit.com/r/neovim/comments/oo97pq/how_to_get_the_visual_selection_range/
-- ^ references vim.inspect(vim.api.nvim_buf_get_mark(0, ">")) doesn't seem to work
 
function getSelectionTest()
	


	-- getpos = vim.fn.getpos('v') -- https://github.com/neovim/neovim/pull/13896#issuecomment-774680224
	-- print(vim.inspect(getpos))
	-- -- (:h getpos) --> Get the position for String {expr}.  For possible values of ... The result is a |List| with four numbers: [bufnum, lnum, col, off]


	-- local gethl = vim.api.nvim_get_hl(-1, {})
	-- print(vim.inspect(gethl))
	-- -- prints vim.empty_dict()

	-- local asdf = vim.api.nvim_get_namespaces()
	-- print(vim.inspect(asdf))
	-- -- prints{["treesitter/highlighter"] = 1}  

	-- local all = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {})
  	-- print(vim.inspect(all))
	-- -- prints {}

	-- local asdf = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {type="highlight",details=true})
  	-- print(vim.inspect(asdf))
	-- -- this also prints {}
end



