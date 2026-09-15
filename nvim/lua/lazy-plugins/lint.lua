return {
    'mfussenegger/nvim-lint',
    config = function()
        local lint = require 'lint'

        vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
            group = vim.api.nvim_create_augroup('user.plugin.lint', { clear = true }),
            callback = function()
                lint.try_lint()
            end,
        })

        vim.api.nvim_create_user_command('LintInfo', function()
            local linters = lint.get_running()
            if #linters == 0 then
                return vim.notify 'No linters running'
            end
            vim.notify('Linters: ' .. table.concat(linters, ', '))
        end, { desc = 'Lint info' })

        lint.linters_by_ft = {
            -- make = { 'checkmake' },
            sql = { 'sqlfluff' },
        }
        lint.linters.sqlfluff.args = {
            'lint',
            '--format=json',
            -- '--dialect=tsql', -- read instead from project .sqlfluff file.
        }
    end,
}
