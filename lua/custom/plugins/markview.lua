return {
  'OXY2DEV/markview.nvim',
  lazy = false,

  dependencies = {
    'saghen/blink.cmp',
  },
  config = function()
    vim.api.nvim_set_keymap('n', '<leader>Mt', '<cmd>Markview toggle<CR>', { noremap = true, silent = true, desc = '[M]arkview [T]oggle' })
    vim.api.nvim_set_keymap('n', '<leader>Ms', '<cmd>Markview splitToggle<CR>', { noremap = true, silent = true, desc = '[M]arkview toggle [S]plit' })
  end,
}
