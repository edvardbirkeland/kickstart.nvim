-- Plugin: Unsaved Buffers Overview

vim.api.nvim_set_hl(0, 'ChangeHighlight', { bg = '#3E3E3E' })
vim.api.nvim_set_hl(0, 'DeleteHighlight', { bg = '#5E2E2E' })

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local previewers = require 'telescope.previewers'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local conf = require('telescope.config').values

local M = {}

local ns = vim.api.nvim_create_namespace 'unsaved_preview'

local function define_preview(self, entry)
  local bufnr = entry.value.bufnr
  local fname = vim.api.nvim_buf_get_name(bufnr)

  -- Adding spaces on empty lines so that they can be highlighted
  local function map_space(line)
    return (line == '') and ' ' or line
  end
  local new = vim.tbl_map(map_space, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  local old = vim.tbl_map(map_space, fname ~= '' and vim.fn.readfile(fname) or {})

  -- Set preview buffer lines and filetype
  local pbuf = self.state.bufnr
  vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, new)
  vim.bo[pbuf].filetype = vim.bo[bufnr].filetype
  vim.api.nvim_buf_clear_namespace(pbuf, ns, 0, -1)

  -- Compute diff hunks
  local old_txt = table.concat(old, '\n')
  local new_txt = table.concat(new, '\n')
  local hunks = vim.diff(old_txt, new_txt, {
    result_type = 'indices',
    algorithm = 'minimal',
    linematch = true,
  })

  -- Debug tool:
  -- print(vim.inspect(hunks))

  -- Highlight added/changed lines
  local changed = {}
  local line_offset = 0

  ---@diagnostic disable-next-line:param-type-mismatch
  for _, h in ipairs(hunks) do
    local start_old, count_old, start_new, count_new = unpack(h)
    local start_line = start_new + line_offset

    -- Deletes
    if count_old > 0 and count_new == 0 then
      table.insert(changed, start_line)

      local to_insert = vim.list_slice(old, start_old, start_old + count_old - 1)
      vim.api.nvim_buf_set_lines(pbuf, start_line, start_line, false, to_insert)
      vim.hl.range(pbuf, ns, 'DeleteHighlight', { start_line, 0 }, { start_line + #to_insert - 1, -1 }, {})
      line_offset = line_offset + #to_insert
    end

    -- Changes and additions
    if count_new > 0 then
      local end_line = start_line + count_new - 1
      table.insert(changed, start_line)

      vim.hl.range(pbuf, ns, 'ChangeHighlight', { start_line - 1, 0 }, { end_line - 1, -1 }, {})
    end
  end

  -- Store for navigation
  self.state.changed_lines = changed
  self.state.current_idx = 1

  -- Jump to first change
  if changed[1] then
    vim.schedule(function()
      local w = self.state.winid
      pcall(vim.api.nvim_win_set_cursor, w, { changed[1], 0 })
      vim.api.nvim_win_call(w, function()
        vim.cmd 'normal! zz'
      end)
    end)
  end
end

-- Telescope picker for unsaved buffers with diff-like preview
function M.pick_unsaved()
  local bufs = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified
  end, vim.api.nvim_list_bufs())

  if vim.tbl_isempty(bufs) then
    vim.notify('No unsaved buffers', vim.log.levels.INFO)
    return
  end

  local entries = vim.tbl_map(function(b)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ':~:.')
    return { bufnr = b, display = name ~= '' and name or '[No Name]' }
  end, bufs)

  pickers
    .new({
      prompt_title = 'Unsaved Buffers',
      previewer = previewers.new_buffer_previewer {
        title = 'Preview',
        define_preview = define_preview,
      },
    }, {
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          return { value = entry, display = entry.display, ordinal = entry.display }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        -- Open buffer
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry().value
          actions.close(prompt_bufnr)
          vim.api.nvim_set_current_buf(entry.bufnr)
        end)

        -- Save buffer changes
        map({ 'n', 'i' }, '<C-s>', function()
          local entry = action_state.get_selected_entry().value
          vim.api.nvim_buf_call(entry.bufnr, function()
            vim.cmd 'write'
          end)
          actions.close(prompt_bufnr)
          M.pick_unsaved()
        end)

        -- Discard buffer changes
        map({ 'n', 'i' }, '<Del>', function()
          local entry = action_state.get_selected_entry().value
          vim.api.nvim_buf_call(entry.bufnr, function()
            vim.cmd 'edit!'
          end)
          actions.close(prompt_bufnr)
          M.pick_unsaved()
        end)

        -- Previous change
        map({ 'n', 'i' }, '<Up>', function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local ch, idx = picker.previewer.state.changed_lines or {}, picker.previewer.state.current_idx or 1
          idx = idx - 1
          if idx < 1 then
            idx = #ch
          end
          picker.previewer.state.current_idx = idx
          if ch[idx] then
            local w = picker.previewer.state.winid
            pcall(vim.api.nvim_win_set_cursor, w, { ch[idx], 0 })
            vim.api.nvim_win_call(w, function()
              vim.cmd 'normal! zz'
            end)
          end
        end)

        -- Next change
        map({ 'n', 'i' }, '<Down>', function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local ch, idx = picker.previewer.state.changed_lines or {}, picker.previewer.state.current_idx or 1
          idx = idx + 1
          if idx > #ch then
            idx = 1
          end
          picker.previewer.state.current_idx = idx
          if ch[idx] then
            local w = picker.previewer.state.winid
            pcall(vim.api.nvim_win_set_cursor, w, { ch[idx], 0 })
            vim.api.nvim_win_call(w, function()
              vim.cmd 'normal! zz'
            end)
          end
        end)

        return true
      end,
    })
    :find()
end

-- Save all modified buffers
function M.save_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified then
      vim.api.nvim_buf_call(b, function()
        vim.cmd 'write'
      end)
    end
  end
  vim.notify('All changes saved', vim.log.levels.INFO)
end

-- Discard all unsaved edits in every buffer
function M.discard_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified then
      vim.api.nvim_buf_call(b, function()
        vim.cmd 'edit!'
      end)
    end
  end
  vim.notify('All changes discarded', vim.log.levels.INFO)
end

-- Setup keymaps
function M.setup()
  vim.keymap.set('n', '<leader>us', M.pick_unsaved, { noremap = true, silent = true, desc = '[U]nsaved buffers [S]earch' })
  vim.keymap.set('n', '<leader>ua', M.save_all, { noremap = true, silent = true, desc = '[U]nsaved save [A]ll' })
  vim.keymap.set('n', '<leader>ud', M.discard_all, { noremap = true, silent = true, desc = '[U]nsaved [D]iscard all' })
end

return M
