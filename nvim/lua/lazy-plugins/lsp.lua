local nvim_data = vim.fn.stdpath('data')
return {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
            library = {
                -- Load luvit types when the `vim.uv` word is found
                { path = 'luvit-meta/library', words = { 'vim%.uv' } },
            },
        },
    },
    {
        'Bilal2453/luvit-meta',
        lazy = true,
    },

    -- Main LSP Configuration
    {
        'neovim/nvim-lspconfig',
        opts = {
            inlay_hints = { enabled = true },
            codelens = {
                enabled = true,
            },
        },
        dependencies = {
            -- Automatically install LSPs and related tools to stdpath for Neovim
            { 'mason-org/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
            -- 'mason-org/mason-lspconfig.nvim',
            'WhoIsSethDaniel/mason-tool-installer.nvim',

            -- Useful status updates for LSP.
            -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
            { 'j-hui/fidget.nvim',    opts = {} },

            -- Allows extra capabilities provided by nvim-cmp
            'hrsh7th/cmp-nvim-lsp',
        },
        config = function()
            -- diagnostic virtual text, see `:help vim.diagnostic.config`
            vim.diagnostic.config({
                virtual_text = {
                    prefix = '■',
                    format = function(diagnostic)
                        return string.format('%s [%s] ', diagnostic.message, diagnostic.source)
                    end,
                    spacing = 4,
                },
            })
            --only run once per buffer
            local notified = {}
            local function get_clients_and_notify(buf)
                if notified[buf] then
                    return
                end
                notified[buf] = true
                -- print(vim.inspect(notified))
                -- print(vim.inspect(buf))
                local clients = vim.lsp.get_clients({ bufnr = buf })
                local names_set = {}
                for _, client in ipairs(clients) do
                    if type(client.name) == 'string' then
                        -- ignore the specified servers
                        if client.name ~= 'lua_ls' and client.name ~= 'gopls' then
                            names_set[client.name] = true
                        end
                    end
                end

                local names = {}
                for name, _ in pairs(names_set) do
                    table.insert(names, name)
                end

                if #names == 0 then
                    return
                end

                table.sort(names); -- optional: stable ordering
                local message = (#names == 1) and names[1] or table.concat(names, ', ')
                require('fidget').notify('[LSP]: ' .. message, vim.log.levels.INFO, { ttl = 0 })
            end
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
                callback = function(event)
                    local buf = event.buf

                    vim.defer_fn(function()
                        get_clients_and_notify(buf)
                    end, 2000)
                end,
            })

            -- define keymaps in remap
            vim.api.nvim_create_autocmd('LspAttach', require('remap').LspAttachAutoCmd)

            -- LSP servers and clients are able to communicate to each other what features they support.
            --  By default, Neovim doesn't support everything that is in the LSP specification.
            --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
            --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities.textDocument.foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
            }
            capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

            -- .setup will auto download
            require('mason').setup()
            -- do NOT call mason setup handlers.

            vim.lsp.config('gopls', {
                capabilities = capabilities,
                filetypes = { 'go', 'gomod' },
                cmd = { nvim_data .. '/mason/bin/gopls' },
                settings = {
                    gopls = {
                        -- buildFlags = { '' },
                        gofumpt = true,
                        analyses = {
                            nilness = true,
                            unusedparams = true,
                            unusedwrite = true,
                            useany = true,
                        },
                        hints = {
                            assignVariableTypes = true,
                            compositeLiteralFields = true,
                            compositeLiteralTypes = true,
                            constantValues = true,
                            functionTypeParameters = true,
                            parameterNames = true,
                            rangeVariableTypes = true,
                        },
                        experimentalPostfixCompletions = true,
                        staticcheck = true,
                        linksInHover = 'gopls',
                        usePlaceholders = true,
                        directoryFilters = { '-.git', '-.vscode', '-.idea', '-.vscode-test', '-node_modules' },
                    },
                },
            })

            vim.lsp.enable('gopls')
            vim.lsp.config('emmet_ls', {})
            vim.lsp.enable('emmet_ls')

            vim.lsp.config('vale_ls', {
                cmd = { 'vale-ls' },
                filetypes = { 'markdown', 'text', 'tex', 'rst' },
                root_dir = require('lspconfig.util').root_pattern('.vale.ini'),
                single_file_support = true,
            })
            vim.lsp.enable('vale_ls')

            -- vim.lsp.config('pyright', {})
            vim.lsp.enable('pyright')

            vim.lsp.config('marksman', {
                cmd = { nvim_data .. '/mason/bin/marksman.cmd', 'server' },
                filetypes = { 'markdown', 'markdown.mdx' },
                -- settings = {
                -- root_dir = require('lspconfig.util').root_pattern('.marksman.toml'),
                -- },
                -- root_dir = function(fname)
                --     local root_files = { '.marksman.toml' }
                --     return require('lspconfig.util').root_pattern(unpack(root_files))(fname)
                --         or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
                -- end,
                -- single_file_support = true,

            })

            vim.lsp.enable('ols')

            require('lspconfig')
            vim.lsp.enable('marksman')
            -- vim.lsp.config('marksman', require('lspconfig.configs').)
            -- vim.lsp.enable 'marksman'
            vim.lsp.config('lua_ls', {

                cmd = vim.fn.has('win32') == 1 and { nvim_data .. '/mason/bin/lua-language-server.cmd' } or
                    { nvim_data .. '/mason/bin/lua-language-server' },

                -- capabilities = {},
                settings = {
                    Lua = {
                        completion = {
                            callSnippet = 'Replace',
                        },
                        format = {
                            enable = true,
                            defaultConfig = {
                                ---@type "keep"|"always"|"same_line"|"replace_with_newline"|"never"
                                end_statement_with_semicolon = 'never',
                                quote_style = 'single',
                            },
                        },
                        -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
                        -- diagnostics = { disable = { 'missing-fields' } },
                    },
                },
            })




            vim.lsp.enable('lua_ls')

            vim.lsp.config('jsonls', {
                cmd = vim.fn.has('win32') == 1 and { nvim_data .. '/mason/bin/vscode-json-language-server.cmd', 'lsp' } or
                    { nvim_data .. '/mason/bin/vscode-json-language-server', '--stdio' },

                settings = {
                    json = {
                        validate = { enable = true },
                        keepLines = { enable = true },
                        schemas = {
                            {
                                fileMatch = { 'deno.json', 'deno.jsonc' },
                                url =
                                'https://raw.githubusercontent.com/denoland/deno/refs/heads/main/cli/schemas/config-file.v1.json',
                            },
                            {
                                fileMatch = { '*.hujson' },
                                schema = {
                                    -- url = 'C:/Users/eshaa/.config/nvim/tailscale-acl.json-schema.json',
                                    allowTrailingCommas = true,
                                    keepLines = { enable = true },
                                },
                            },
                            {
                                fileMatch = { 'openapi.json', 'openapi.yaml', 'openapi.yml' },
                                url = 'https://spec.openapis.org/oas/3.0/schema/2024-10-18',
                            },
                        },
                    },
                },
            })
            vim.lsp.enable('jsonls')

            vim.lsp.config('eslint', {
                filetypes = { 'javascript' },
            })
            vim.lsp.enable('eslint')

            vim.lsp.config('html', {})
            vim.lsp.enable('html')

            do
                ---@type vim.lsp.Config
                local opts = {
                    settings = {
                        deno = {
                            enable = true,
                            completeFunctionCalls = true,
                        }
                    },
                    cmd = vim.fn.has('win32') == 1 and { nvim_data .. '/mason/bin/deno.cmd', 'lsp' } or
                        { nvim_data .. '/mason/bin/deno', 'lsp' },
                    root_markers = { 'deno.json', 'deno.jsonc', '.git' },
                    filetypes = {
                        'javascript',
                        'javascriptreact',
                        'javascript.jsx',
                        'typescript',
                        'typescriptreact',
                        'typescript.tsx',
                    },
                }
                vim.lsp.config('denols', opts)
                vim.lsp.enable('denols')
            end

            vim.lsp.config('fsautocomplete', {
                cmd = { 'fsautocomplete', '--adaptive-lsp-server-enabled' },
                settings = {
                    FSharp = {
                        EnableReferenceCodeLens = true,
                        ExternalAutocomplete = true,
                        InterfaceStubGeneration = true,
                        InterfaceStubGenerationMethodBody = 'failwith "Not Implemented"',
                        InterfaceStubGenerationObjectIdentifier = 'this',
                        Linter = true,
                        RecordStubGeneration = true,
                        RecordStubGenerationBody = 'failwith "Not Implemented"',
                        ResolveNamespaces = true,
                        SimplifyNameAnalyzer = true,
                        UnionCaseStubGeneration = true,
                        UnionCaseStubGenerationBody = 'failwith "Not Implemented"',
                        UnusedDeclarationsAnalyzer = true,
                        UnusedOpensAnalyzer = true,
                        UseSdkScripts = true,
                        keywordsAutocomplete = true,
                    },
                },
            })
        end,
    },

    { -- Autoformat
        'stevearc/conform.nvim',
        event = { 'BufWritePre' },
        cmd = { 'ConformInfo' },
        keys = {
            {
                '<leader>f',
                function()
                    require('conform').format({ async = true, lsp_fallback = true })
                end,
                mode = '',
                desc = '[F]ormat buffer',
            },
        },
        opts = {
            log_level = vim.log.levels.TRACE,
            notify_on_error = true,
            format_on_save = function(bufnr)
                -- Disable "format_on_save lsp_fallback" for languages that don't
                -- have a well standardized coding style. You can add additional
                -- languages here or re-enable it for the disabled ones.
                local disable_filetypes = { c = true, cpp = true, templ = true }
                return {
                    timeout_ms = 500,
                    lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
                }
            end,
            formatters_by_ft = {
                lua = { nvim_data .. '/mason/bin/stylua.cmd' },
                -- sql = { 'sleek' }, -- works
                sql = { 'sqlfluff' },
                -- Conform can also run multiple formatters sequentially
                -- You can use 'stop_after_first' to run the first available formatter from the list
                javascript = { 'prettierd', 'prettier', stop_after_first = true },
            },
            -- <https://github.com/m0lson84/neovim/blob/2f01d16fe9ac2a736428dec56bf23edd3f10d3c5/lua/plugins/linters/sqlfluff.lua#L24>
            formatters = {
                sqlfluff = {
                    -- sqlfluff = { args = { 'fix', '--dialect', 'ansi', '-' } },
                    -- args = { 'fix', '--show-lint-violations', '-p', '6', '--ignore', 'parsing', '-' },
                    -- args = { 'fix', '--ignore', 'parsing', '-' },
                    args = { 'fix', '-' },
                    exit_codes = { 0, 1 }, -- TODO: add to conform settings
                    stdin = true,
                },
            },
        },
    },

    { -- Autocompletion
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        dependencies = {
            -- Snippet Engine & its associated nvim-cmp source
            {
                'L3MON4D3/LuaSnip',
                build = (function()
                    -- Build Step is needed for regex support in snippets.
                    -- This step is not supported in many windows environments.
                    -- Remove the below condition to re-enable on windows.
                    if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
                        return
                    end
                    return 'make install_jsregexp'
                end)(),
                dependencies = {
                    -- `friendly-snippets` contains a variety of premade snippets.
                    --    See the README about individual language/framework/plugin snippets:
                    --    https://github.com/rafamadriz/friendly-snippets
                    -- {
                    --   'rafamadriz/friendly-snippets',
                    --   config = function()
                    --     require('luasnip.loaders.from_vscode').lazy_load()
                    --   end,
                    -- },
                },
            },
            'saadparwaiz1/cmp_luasnip',

            -- Adds other completion capabilities.
            --  nvim-cmp does not ship with all sources by default. They are split
            --  into multiple repos for maintenance purposes.
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-path',
        },
        config = function()
            -- See `:help cmp`
            local cmp = require('cmp')
            local luasnip = require('luasnip')
            luasnip.config.setup({})

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                completion = { completeopt = 'menu,menuone,noinsert' },
                view = { docs = { auto_open = true } }, -- https://github.com/hrsh7th/nvim-cmp/issues/1088
                experimental = {
                    ghost_text = true,
                },

                -- For an understanding of why these mappings were
                -- chosen, you will need to read `:help ins-completion`
                --
                -- No, but seriously. Please read `:help ins-completion`, it is really good!
                mapping = cmp.mapping.preset.insert({
                    -- Select the [n]ext item
                    ['<C-n>'] = cmp.mapping.select_next_item(),

                    -- Select the [p]revious item
                    ['<C-p>'] = cmp.mapping.select_prev_item(),

                    -- Scroll the documentation window [b]ack / [f]orward
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),

                    -- Accept ([y]es) the completion.
                    --  This will auto-import if your LSP supports it.
                    --  This will expand snippets if the LSP sent a snippet.
                    ['<C-y>'] = cmp.mapping.confirm({ select = true }),

                    ['<C-g>'] = function()
                        if cmp.visible_docs() then
                            cmp.close_docs()
                        else
                            cmp.open_docs()
                        end
                    end,

                    -- Manually trigger a completion from nvim-cmp.
                    --  Generally you don't need this, because nvim-cmp will display
                    --  completions whenever it has completion options available.
                    ['<C-Space>'] = cmp.mapping.complete({}),

                    -- Think of <c-l> as moving to the right of your snippet expansion.
                    --  So if you have a snippet that's like:
                    --  function $name($args)
                    --    $body
                    --  end
                    --
                    -- <c-l> will move you to the right of each of the expansion locations.
                    -- <c-h> is similar, except moving you backwards.
                    ['<C-l>'] = cmp.mapping(function()
                        if luasnip.expand_or_locally_jumpable() then
                            luasnip.expand_or_jump()
                        end
                    end, { 'i', 's' }),
                    ['<C-h>'] = cmp.mapping(function()
                        if luasnip.locally_jumpable(-1) then
                            luasnip.jump(-1)
                        end
                    end, { 'i', 's' }),

                    -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
                    --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
                }),
                sources = {
                    {
                        name = 'lazydev',
                        -- set group index to 0 to skip loading LuaLS completions as lazydev recommends it
                        group_index = 0,
                    },
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'path' },
                    { name = 'jupynium' },
                },
            })
        end,
    },
}
