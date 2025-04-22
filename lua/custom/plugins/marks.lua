-- https://github.com/chentoast/marks.nvim

return {
  'chentoast/marks.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  opts = {
    default_mappings = false,
    sign_priority = 20,
  },
  config = function(_, opts)
    local marks = require 'marks'
    local telescope = require 'telescope.builtin'
    local set = vim.keymap.set

    marks.setup(opts)

    set('n', '<leader>mt', marks.toggle, { desc = '[M]arks [T]oggle at cursor' })
    set('n', '<leader>mn', marks.next, { desc = '[M]arks goto [N]ext' })
    set('n', '<leader>mp', marks.prev, { desc = '[M]arks goto [P]revious' })

    set('n', '<leader>md', function()
      vim.cmd 'delmarks!'
    end, { desc = '[M]arks [D]elete all' })

    set('n', '<leader>ms', function()
      telescope.marks {
        attach_mappings = function(prompt_bufnr)
          local actions = require 'telescope.actions'
          vim.keymap.set({ 'i', 'n' }, '<del>', function()
            actions.delete_mark(prompt_bufnr)
          end)
          return true
        end,
      }
    end, { desc = '[M]arks [S]earch' })
  end,
}
