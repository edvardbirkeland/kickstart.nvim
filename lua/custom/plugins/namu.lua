return {
  'bassamsdata/namu.nvim',
  config = function()
    require('namu').setup {
      namu_symbols = {
        enable = true,
        options = {
          display = {
            mode = 'icon',
            format = 'tree_guides',
            tree_guides = {
              style = 'unicode',
            },
          },
        },
      },
      ui_select = { enable = true },
    }

    vim.keymap.set('n', '<leader>sss', ':Namu symbols<cr>', { silent = true, desc = '[S]earch [S]ymbols [S]elected buffer' })
    vim.keymap.set('n', '<leader>ssa', ':Namu watchtower<cr>', { silent = true, desc = '[S]earch [S]ymbols [A]ll buffers' })
  end,
}
