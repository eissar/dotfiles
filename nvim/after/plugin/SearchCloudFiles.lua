function SearchCloudFiles()
    local opts = {
        cwd = os.getenv 'CLOUD_DIR',
        prompt_title = 'Find Files',
        find_command = {
            'rg',
            '--color=never',
            '--type=md',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--files',
        },
    }
    require('telescope.builtin').find_files(opts)
end
