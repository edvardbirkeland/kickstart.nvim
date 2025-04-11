-- https://github.com/AckslD/nvim-neoclip.lua

return {
  'AckslD/nvim-neoclip.lua',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    { 'kkharji/sqlite.lua', module = 'sqlite' },
  },
  config = function()
    require('neoclip').setup {
      enable_persistent_history = true,
      continuous_sync = true,
      default_register = '"+',
      keys = {
        telescope = {
          i = {
            paste = { '<cr>', '<c-y>' },
          },
          n = {
            paste = { '<cr>', '<c-y>' },
          },
        },
      },
    }

    vim.api.nvim_set_keymap('n', '<leader>p', ':Telescope neoclip<CR>', { noremap = true, silent = true })

    -- Autocmd to capture OS clipboard content and insert it into neoclip’s history.
    -- Limitation: This will only fetch the newest OS clipboard entry.
    -- TODO: This duplicates latest copy if it occured within Neovim
    vim.api.nvim_create_autocmd({ 'FocusGained' }, {
      callback = function()
        local clipboard_content = vim.fn.getreg '+'
        if clipboard_content and clipboard_content ~= '' then
          local storage = require 'neoclip.storage'
          local filetype = vim.bo.filetype or ''
          local data = {
            regtype = 'v',
            contents = vim.split(clipboard_content, '\n', { plain = true }),
            filetype = filetype,
          }
          storage.insert(data, 'yanks')
        end
      end,
    })
  end,
}
