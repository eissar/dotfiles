-- Import required modules
-- local fmt = require('luasnip.extras.fmt').fmt
local luasnip = require 'luasnip'
local snippet = luasnip.snippet
local snippet_node = luasnip.snippet_node
local txt = luasnip.text_node
local insert = luasnip.insert_node
-- local func = luasnip.
-- local utilEvents = require 'luasnip.util.events'
-- local absoluteIndexer = require 'luasnip.nodes.absolute_indexer'

-- NOTE: Helper function from: <https://github.com/L3MON4D3/LuaSnip/issues/420#issuecomment-1356853267>
local function new_multisnip1(snip_name, triggers, snip)
    for _, trigger in pairs(triggers) do
        local arr = {}
        local s = snippet({ trig = trigger, name = snip_name }, vim.deepcopy(snip))
        table.insert(arr, s)
    end
end

-- others{name=,description=,}
local function new_snippet_with_alias(trigger, snip, others)
    if not trigger then
        error 'trigger cannot be empty on call to new_snippet_with_alias'
    end
    local opts = {
        trig = trigger,
    }
    if others then
        if others['name'] then
            opts['name'] = others['name']
        end
    end
    snippet_node(0, {
        txt('--[' .. '['),
        txt { '', '\t' }, --newline and tab
        insert(1, 'multiline comment'),
        txt { '', '' }, --newline
        txt(']' .. ']'),
    })

    local s = snippet(opts, vim.deepcopy(snip))
    return s
end

do --#region LUA
    local lua_snips = {}
    do -- add snippets
        --[[ alias fun, fn; function ]]
        local snip = snippet_node(0, {
            txt 'local function ',
            insert(1, ''),
            txt { '(' },
            insert(2, ''),
            txt ')',
            txt { '', '\t' }, --newline and tab
            insert(3, ''),
            txt { '', 'end' }, --newline and end
        })
        local a1 = new_snippet_with_alias('fun', snip)
        local a2 = new_snippet_with_alias('fn', snip)
        table.insert(lua_snips, a1)
        table.insert(lua_snips, a2)
    end
    table.insert(
        lua_snips, --[[ multiline comment ]]
        snippet(
            'multiline comment',
            snippet_node(0, {
                txt('--[' .. '['),
                txt { '', '\t' }, --newline and tab
                insert(1, 'multiline comment'),
                txt { '', '' }, --newline
                txt(']' .. ']'),
            })
        )
    )
    table.insert(
        lua_snips, --[[ singleline comment ]]
        snippet(
            'singleline comment',
            snippet_node(0, {
                txt('--[' .. '['),
                txt ' ',
                insert(1, 'multiline comment'),
                txt ' ',
                txt(']' .. ']'),
            })
        )
    )

    do
        --[[ alias il, inline link; inline link ]]
        local snip = {
            txt '--#region ',
            insert(1, 'REGION'),
            txt { '', '' }, -- newline
            insert(2, 'do end'),
            txt { '', '' }, -- newline
            txt '--#endregion',
        }
        table.insert(lua_snips, new_snippet_with_alias('region', snip))
    end

    luasnip.add_snippets('lua', lua_snips)
end --#endregion

do --#region MARKDOWN
    local markdown_snips = {}
    --[[
        new_multisnip(filetype, snip_name, triggers, snip)('tex', 'glqq', { 'glqq', '\\glqq' }, {
        t { '\\glqq ' },
        i(1),
        t { '\\grqq{}' },
        })
    --]]

    do -- alias wl, wikilinks; wikilink
        local snip = {
            txt '[[',
            insert(1, ''),
            txt ']]',
        }
        table.insert(markdown_snips, new_snippet_with_alias('wikilink', snip))
        table.insert(markdown_snips, new_snippet_with_alias('wl', snip))
    end

    do -- alias il, inline link; inline link
        local snip = {
            txt '[',
            insert(1, ''),
            txt ']',
            txt '(',
            insert(2, ''),
            txt ')',
        }
        table.insert(markdown_snips, new_snippet_with_alias('il', snip))
        table.insert(markdown_snips, new_snippet_with_alias('inline link', snip))
    end

    do -- alias <, ll, automatic link, link; automatic link
        local snip = {
            txt '<',
            insert(1, ''),
            txt '>',
        }
        table.insert(markdown_snips, new_snippet_with_alias('al', snip))
        table.insert(markdown_snips, new_snippet_with_alias('<', snip))
        table.insert(markdown_snips, new_snippet_with_alias('automatic link', snip))
        table.insert(markdown_snips, new_snippet_with_alias('link', snip))
    end

    table.insert(markdown_snips, snippet('cmt', { txt '<!---->' }))
    table.insert(markdown_snips, snippet('tag', { txt '|#', insert(1, ''), txt '|' }))
    table.insert(markdown_snips, snippet('t', { txt '|#', insert(1, ''), txt '|' }))

    do -- alias fl, file link; file link
        local snip = {
            txt '["',
            insert(1, ''),
            txt '"]',
        }
        table.insert(markdown_snips, new_snippet_with_alias('fl', snip))
        table.insert(markdown_snips, new_snippet_with_alias('file link', snip))
    end

    table.insert(
        markdown_snips, --[[ Folding Heading ]]
        snippet(
            { trig = 'folding heading', dscr = 'markdown heading with weird syntax so I can fold easily.' },
            snippet_node(0, {
                txt '# ',
                insert(1, 'Heading '),
                txt { '', '- <!---->' },
                txt { '', '\t' }, --newline and tab
                insert(2, '<!-- Summary -->'),
                txt { '', '\t' },
                insert(3, '<!-- Explanation -->'),
                txt { '', '\t' },
                insert(4, '<!-- Sources and References -->'),
            })
        )
    )

    table.insert(markdown_snips, snippet('raindrop', { txt 'https://app.raindrop.io/my/0', insert(1, '') }))

    luasnip.add_snippets('markdown', markdown_snips)
end --#endregion

do --#region PWSH
    local pwsh_snips = {}

    do -- alias cmt; multiline comment
        local snip = {
            txt '<#',
            txt { '', '\t' }, --newline and tab
            insert(1, ''),
            txt { '', '' }, --newline
            txt '#>',
        }
        table.insert(pwsh_snips, new_snippet_with_alias('cmt', snip))
    end

    do -- alias [arr], array; [System.Collections.ArrayList]
        local snip = snippet_node(0, {
            txt '[System.Collections.ArrayList]',
        })
        table.insert(pwsh_snips, new_snippet_with_alias('[arr]', snip))
        table.insert(pwsh_snips, new_snippet_with_alias('array', snip))
    end

    do -- alias iife, array; (&{})
        local snip = snippet_node(0, {
            txt '(&{',
            txt { '', '\t' }, --newline and tab
            insert(1, ''),
            txt { '', '})' }, --newline and end
        })
        table.insert(pwsh_snips, new_snippet_with_alias('iife', snip))
    end

    luasnip.add_snippets('ps1', pwsh_snips)
end --#endregion

do --#region HTML
    local html_snips = {}

    do -- alias cmt; multiline comment
        local snip = {
            txt '<!--',
            txt { '', '\t' }, --newline and tab
            insert(1, ''),
            txt { '', '' }, --newline
            txt '-->',
        }
        table.insert(html_snips, new_snippet_with_alias('cmt', snip))
    end

    table.insert(html_snips, snippet('cmt', { txt '<!---->' }))
    luasnip.add_snippets('html', html_snips)
end --#endregion

do --#region JS/TS
    local js_snips = {}
    do -- alias iife; immediately invoked function expression
        local snip = {
            txt '(() => {',
            txt { '', '\t' }, --newline and tab
            insert(1, ''),
            txt { '', '' }, --newline
            txt '})();',
        }
        table.insert(js_snips, new_snippet_with_alias('iife', snip))
    end

    -- table.insert(html_snips, snippet('cmt', { txt '<!---->' }))
    luasnip.add_snippets('javascript', js_snips)
    luasnip.add_snippets('typescript', js_snips)
end --#endregion

do --#region Go
    local go_snips = {}
    do -- immediately invoked function expression
        local snip = {
            txt 'func() {',
            txt { '', '\t' },
            insert(1, ''),
            txt { '', '' },
            txt '}()',
        }
        table.insert(go_snips, new_snippet_with_alias('iife', snip))
    end

    luasnip.add_snippets('go', go_snips)
end --#endregion

--[[
    --#region ALL
    local term_snips = {}
    table.insert(term_snips, snippet('cmt', { txt '<!---->' }))
    luasnip.add_snippets('all', term_snips)
--]]
--
--
--

--[[
--     local function new_snip_with_aliases(cfg, snip)
--         for alias, config in pairs(cfg) do
--             vim.notify(alias)
--             -- You can add more logic here if needed
--         end
--     end
--     local this_cfg = { ['test'] = {}, ['test1'] = 1 }
--     new_snip_with_aliases(this_cfg)
-- [[]]
