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

    vim.api.nvim_set_keymap('n', '<leader>p', '<cmd>Telescope neoclip<CR>', { noremap = true, silent = true, desc = 'Clipboard [P]aste' })
  end,
}
