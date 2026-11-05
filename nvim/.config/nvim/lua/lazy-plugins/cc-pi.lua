-- cc-pi.nvim: inline editing driven by the Pi coding agent.
-- https://github.com/eissar/cc-pi.nvim (private)
--
-- Nothing here is strictly required: the plugin defaults to the `pi` adapter on
-- the inline strategy. Everything below is preference.
return {
    'eissar/cc-pi.nvim',
    -- Private repo, so lazy must clone over SSH rather than https.
    url = 'git@github.com:eissar/cc-pi.nvim.git',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-treesitter/nvim-treesitter',
    },
    cmd = 'CodeCompanion',
    config = function(_, opts)
        require('codecompanion').setup(opts)
    end,
    keys = {
        { '<leader>cc', '<cmd>CodeCompanion<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion inline' },
    },
    opts = {
        adapters = {
            pi = {
                pi = {
                    defaults = {
                        -- Append --no-skills/--no-extensions/--no-mcp/--no-context-files
                        -- for fast, tool-free inline edits. Set false to let Pi use
                        -- its own skills, extensions, MCP servers and AGENTS.md.
                        isolated = true,
                        -- hooks/configs are resolved at runtime; pick a cheap model
                        -- here if you want inline edits to be fast.
                        model = nil,
                        thinking = nil, -- off|minimal|low|medium|high|xhigh|max
                        timeout = 120000,
                    },
                },
            },
        },
        display = {
            diff = {
                -- One provider ships in this fork.
                provider = 'inline',
                enabled = true,
            },
        },
    },
}
