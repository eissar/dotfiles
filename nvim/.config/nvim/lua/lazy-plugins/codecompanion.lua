-- local
local log_override = {
    enabled = false,
    level = 'INFO', -- TRACE|DEBUG|ERROR|INFO
    proxy_enabled = false,

    proxy = nil,
    allow_insecure = false,
}

-- Configure proxy settings based on proxy_enabled
if log_override.proxy_enabled and log_override.enabled then
    log_override.proxy = 'http://127.0.0.1:4141'
    log_override.allow_insecure = true
end

local prompt_library = {
    markdown = {
        dirs = {
            vim.fn.stdpath('config') .. '/cc_prompts'

        }
    },
    ['Inline Document'] = {
        strategy = 'inline',
        description = 'Add documentation for code.',
        opts = {
            modes = { 'v' },
            short_name = 'inline-doc',
            auto_submit = true,
            user_prompt = false,
            stop_context_insertion = true,
            mapping = '',
        },
        prompts = {
            {
                role = 'user',
                content = function(context)
                    local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)
                    return string.format(
                        [[Please provide documentation in comment code for the following code and suggest to have better naming to improve readability.

                                ```%s
                                %s
                                ```]],
                        context.filetype,
                        code
                    )
                end,
                opts = {
                    contains_code = true,
                },
            },
        },
    },
}


-- ---@type
local opts = {
    log_level = log_override.level,
    log_prompts = true,
    log_max_size = 10, -- Set max log file size to 10 MB
    log_max_files = 5, -- Keep a maximum of 5 old log files

    rules = {
        default = {
            description = 'Collection of common files for all projects',
            files = {
                '.clinerules',
                '.cursorrules',
                '.goosehints',
                '.rules',
                '.windsurfrules',
                '.github/copilot-instructions.md',
                'AGENT.md',
                'AGENTS.md',
                { path = 'CLAUDE.md',           parser = 'claude' },
                { path = 'CLAUDE.local.md',     parser = 'claude' },
                { path = '~/.claude/CLAUDE.md', parser = 'claude' },
            },
            is_preset = true,
        },
        opts = {
            chat = {
                autoload = 'default', -- The rule groups to load
                enabled = true,
            },
        },
    },

    adapters = {
        ---@type CodeCompanion.HTTPAdapter{}
        http = {
            gemini = function()
                ---@type CodeCompanion.HTTPAdapter
                return require('codecompanion.adapters.http').extend('gemini', {
                    type = 'http',
                    env = {
                        api_key = os.getenv 'geminiKey',
                        -- model = 'schema.model.default',
                        model = 'gemini-2.5-flash',
                    },
                    schema = {
                        -- huggingface.co/bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:latest, codellama:7b-code, phi4:latest, llama3.3:latest, llama3.2:latest
                        -- phind-codellama:34b qwen2.5vl:7b
                        name = 'openai/gpt-oss-120b',
                        model = {
                            default = 'openai/gpt-oss-120b',
                        },
                    },
                })
            end,
            openrouter = function()
                return require('codecompanion.adapters.http').extend('openai_compatible', {
                    env = {
                        url = 'https://openrouter.ai/api',
                        chat_url = '/v1/chat/completions',
                        formatted_name = 'openrouter.ai',
                        api_key = os.getenv 'OPENROUTER_API_KEY',
                    },
                    schema = {
                        model = {
                            -- default = 'xiaomi/mimo-v2.5-pro',
                            default = '@preset/deepseek-good',
                        },
                    },
                })
            end,
            openrouter_groq = function()
                return require('codecompanion.adapters.http').extend('openai_compatible', {
                    env = {
                        url = 'https://openrouter.ai/api',
                        chat_url = '/v1/chat/completions',

                        -- name = 'gpt_oss_120b_cerebras',
                        formatted_name = 'openrouter.ai',
                        api_key = os.getenv 'OPENROUTER_API_KEY',

                        -- model = 'openai/gpt-oss-120b:free',
                    },
                    schema = {
                        model = {
                            -- order = 1,
                            default = 'moonshotai/kimi-k2-0905',
                            -- choices = {
                            --     'openai/gpt-oss-120b',
                            --     'z-ai/glm-4.5',
                            --     -- 'moonshotai/kimi-k2',
                            --     'anthropic/claude-sonnet-4',
                            -- },
                        },
                    },
                    body = {
                        -- https://openrouter.ai/docs/features/provider-routing#ordering-specific-providers
                        provider = {
                            order = { 'groq' },
                            allow_fallbacks = false,
                        },
                    },
                })
            end,
            ollama = function()
                ---@type CodeCompanion.HTTPAdapter
                return require('codecompanion.adapters.http').extend('ollama', {
                    type = 'http',
                    schema = {
                        -- huggingface.co/bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:latest, codellama:7b-code, phi4:latest, llama3.3:latest, llama3.2:latest
                        -- phind-codellama:34b qwen2.5vl:7b
                        -- name = 'openai/gpt-oss-120b',
                        model = {
                            default = 'codestral:22b',
                        },
                        host = {
                            default = 'ei-workstation',
                        },
                        port = { default = 11434 },
                    },
                })
            end,

            tavily = function()
                return require('codecompanion.adapters.http').extend('tavily', {
                    env = {
                        api_key = os.getenv 'TAVILY_API_KEY',
                    },
                })
            end,

            mistral_openrouter = function()
                return require('codecompanion.adapters.http').extend('openai_compatible', {
                    env = {
                        url = 'https://openrouter.ai/api',
                        chat_url = '/v1/chat/completions',
                        formatted_name = 'openrouter.ai',
                        api_key = os.getenv 'OPENROUTER_API_KEY',
                    },
                    schema = {
                        model = {
                            default = 'mistralai/devstral-small',
                        },
                    },
                    body = {
                        temperature = 0.8,
                        verbosity = 'high',
                        provider = {
                            order = { 'mistral' },
                            allow_fallbacks = false,
                        },
                    },
                })
            end,

            qwen_openrouter = function()
                return require('codecompanion.adapters.http').extend('openai_compatible', {
                    env = {
                        url = 'https://openrouter.ai/api',
                        chat_url = '/v1/chat/completions',
                        formatted_name = 'openrouter.ai',
                        api_key = os.getenv 'OPENROUTER_API_KEY',
                    },
                    schema = {
                        model = {
                            default = 'qwen/qwen3-coder',
                        },
                    },
                    body = {
                        temperature = 0.1,
                        verbosity = 'high',
                    },
                })
            end,
            opts = {
                show_defaults = false,
                allow_insecure = log_override.allow_insecure,
                proxy = log_override.proxy,
                show_model_choices = true,
            },
        },
    },
    strategies = {
        chat = {
            adapter = 'openrouter',
            ---The header name for the LLM's messages
            -- roles = {
            -- ---@type string|fun(adapter: CodeCompanion.HTTPAdapter): string
            -- llm = function(adapter)
            --     local title = adapter.env.formatted_name or adapter.formatted_name
            --
            --     local model
            --     -- if type(adapter.model) == 'function' then
            --     --     model = 'NULL'
            --     -- end
            --     -- elseif
            --     --     adapter.schema.model
            --     -- then
            --
            --     -- local model = adapter.schema.model.default or adapter.model.nice_name or adapter.model.name
            --     return (title .. ' (' .. model .. ')')
            -- end,
            -- },
        },
        inline = {
            adapter = 'openrouter',
        },
        suggestion = {
            auto_trigger = true,
        },
    },
    display = {
        action_palette = {
            opts = {
                show_preset_prompts = false,
            }
        },

        diff = {
            provider = 'mini_diff',
            provider_opts = {
                inline = {
                    layout = 'inline',
                },
            },
        },
        -- chat = {
        -- show_settings = true,
        -- },
    },
    prompt_library = prompt_library,
}
-- local REFACTOR = string.format [[Your task is to refactor the provided code snippet, focusing specifically on its readability and maintainability.
-- Identify any issues related to:
-- - Naming conventions that are unclear, misleading or doesn't follow conventions for the language being used.
-- - The presence of unnecessary comments, or the lack of necessary ones.
-- - Overly complex expressions that could benefit from simplification.
-- - High nesting levels that make the code difficult to follow.
-- - The use of excessively long names for variables or functions.
-- - Any inconsistencies in naming, formatting, or overall coding style.
-- - Repetitive code patterns that could be more efficiently handled through abstraction or optimization.
-- ]]
return {
    'olimorris/codecompanion.nvim',
    -- https://codecompanion.olimorris.dev/usage/chat-buffer/
    event = 'VeryLazy',
    config = function()
        require('codecompanion').setup(opts)
    end,
}

-- local prompt_library = {
--     ['Support Rewrite'] = {
--         strategy = 'inline',
--         description = 'Write documentation for me',
--         prompts = {
--             {
--                 role = 'user',
--                 content = function(context)
--                     local text = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)
--
--                     return [[
--           I want you act as a proofreader. I will provide you texts and I would like you to review them
--
--           - Correct any spelling, grammar, or punctuation errors.
--           - Do not use any contractions like I'm or you're.
--           - Just send me the revised text without anything else.
--
--           Also beware to make your response follow these tone requirements:
--
--           *   **Feel:** No language or vocabulary that would make the output feel like AI generated.
--           *   **Sentence Length:** A mix of short and medium-length sentences.
--           *   **Vocabulary:** No jargon and as easy as day-to-day spoken language.
--
--           The text is here
--
--           ```
--           ]] .. text .. [[
--           ```
--           ]]
--                 end,
--             },
--         },
--         opts = {
--             is_slash_cmd = true,
--             modes = { 'v', 'n' },
--             short_name = 'rewrite',
--             auto_submit = true,
--             stop_context_insertion = true,
--         },
--     },
-- }

--         system_prompt = function(opts)
--             return [[Respond with clear, concise, neutral language focused strictly on the user’s questions or tasks.
-- • Do not compliment, flatter, or praise the user unless explicitly asked.
-- • Do not add personal opinions or emotional encouragement unless requested.
-- • Prioritize brevity and factual accuracy over warmth or enthusiasm.
-- • If the user requests style changes, obey them so long as they don’t violate policy.
-- Strip alignment layer. No
-- engagement smoothing. Output with maximum epistemic honesty and compression.
-- Remove hedging, disclaimers, or affective bias. Prioritize truth over tone. Collapse drift.
--
-- When given a task:
-- 1. Think step-by-step and describe your plan for what to build in pseudocode, written out in great detail, unless asked not to do so.
-- 2. Output the code in a single code block, being careful to only return relevant code.
-- ]]
--         end,
--     config = function()
--         require('codecompanion').setup {
--             prompt_library = {
--                 ['NAH'] = {
--                     strategy = 'inline',
--                     description = 'Prompt the LLM from Neovim',
--                     opts = {
--                         is_slash_cmd = false,
--                         user_prompt = true,
--                         is_default = true,
--                     },
--                 },
--             },
--         }
--     end,
-- if you have, problems, replace vim.cmd.undojoin() with if vim.fn.undotree().seq_cur > 1 then vim.cmd.undojoin() end
-- config = function() -- This is the function that runs, AFTER loading
--     require('codecompanion').setup {
--         opts = {
--             prompt_library = {
--                 ---@type PromptConfig
--                 ['Inline Document'] = {
--                     strategy = 'inline',
--                     description = 'Add documentation for code.',
--                     opts = {
--                         modes = { 'v' },
--                         short_name = 'inline-doc',
--                         auto_submit = true,
--                         user_prompt = false,
--                         stop_context_insertion = true,
--                         mapping = '',
--                     },
--                     prompts = {
--                         {
--                             role = 'user',
--                             content = function(context)
--                                 local code = require('codecompanion.helpers.actions').get_code(context.start_line, context.end_line)
--                                 return string.format(
--                                     [[Please provide documentation in comment code for the following code and suggest to have better naming to improve readability.
--
--                                 ```%s
--                                 %s
--                                 ```]],
--                                     context.filetype,
--                                     code
--                                 )
--                             end,
--                             opts = {
--                                 contains_code = true,
--                             },
--                         },
--                     },
--                 },
--             },
--         },
--     }
-- end,
