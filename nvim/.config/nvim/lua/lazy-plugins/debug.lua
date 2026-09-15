return {
    'mfussenegger/nvim-dap',
    dependencies = {
        'williamboman/mason.nvim',
        'jay-babu/mason-nvim-dap.nvim',
        'leoluz/nvim-dap-go',
    },
    keys = function(_, keys)
        local dap = require 'dap'
        vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
        vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
        vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
        vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
        vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end,
            { desc = 'Debug: Toggle Breakpoint' })
        vim.keymap.set('n', '<leader>B',
            function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
            { desc = 'Debug: Set Breakpoint' })
    end,
    config = function()
        local dap = require 'dap'

        require('mason-nvim-dap').setup {
            automatic_installation = true,
            handlers = {},
            ensure_installed = {
                'delve',
                'js'
            },
        }

        -- Official native configuration (Let Neovim handle the random port)
        dap.adapters['pwa-node'] = {
            type = 'server',
            host = 'localhost',
            port = '${port}',
            executable = {
                command = 'node',
                args = {
                    vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js',
                    '${port}',
                },
            },
        }

        -- Global fallback for standard file debugging via <F5>
        dap.configurations.typescript = {
            {
                name = 'Deno: Debug Current File',
                type = 'pwa-node',
                request = 'launch',
                runtimeExecutable = 'deno',
                runtimeArgs = { 'run', '--inspect-wait', '--no-check', '-A', '${file}' },
                cwd = '${workspaceFolder}',
                attachSimplePort = 9229,
                sourceMaps = true,
                localRoot = '${workspaceFolder}',
                remoteRoot = '${workspaceFolder}',
            }
        }
        dap.configurations.javascript = dap.configurations.typescript

        require('dap-go').setup {
            delve = { detached = vim.fn.has 'win32' == 0 },
        }
    end,
}
