local function order_commits(commit1, commit2)
  local ts1 = tonumber(vim.fn.trim(vim.fn.system('git log -1 --format=%ct ' .. commit1))) or 0
  local ts2 = tonumber(vim.fn.trim(vim.fn.system('git log -1 --format=%ct ' .. commit2))) or 0
  if ts1 <= ts2 then
    return commit1, commit2
  else
    return commit2, commit1
  end
end

local function diffview_picker(mode, option)
  -- mode should be one of "commit" or "branch"
  -- option can be "diff", "diff_range" or "show"
  local telescope = require 'telescope.builtin'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  -- Pick the proper telescope picker function and define the candidate extractor.
  local picker_func, extract_commit

  if mode == 'commit' then
    picker_func = telescope.git_commits
    extract_commit = function(selection)
      return selection.value:match '^(%w+)'
    end
  elseif mode == 'branch' then
    picker_func = telescope.git_branches
    extract_commit = function(selection)
      local branch = selection.value or selection.ordinal
      if not branch or branch == '' then
        return nil
      end
      return vim.fn.trim(vim.fn.system('git rev-parse ' .. branch))
    end
  end

  if not picker_func then
    vim.notify('Invalid mode for diffview picker', vim.log.levels.ERROR)
    return
  end

  picker_func {
    sorting_strategy = 'ascending',
    multi_select = option == 'diff_range',
    attach_mappings = function(prompt_bufnr, _)
      local on_select = function()
        if option == 'diff_range' then
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection() or {}

          if #selections ~= 2 then
            vim.notify('Please select exactly 2 commits for a diff range. ' .. #selections .. ' is currently selected', vim.log.levels.INFO)
            return
          end
          actions.close(prompt_bufnr)
          local first_commit_selected = extract_commit(selections[1])
          local second_commit_selected = extract_commit(selections[2])
          if first_commit_selected and second_commit_selected then
            local earliest_commit, latest_commit = order_commits(first_commit_selected, second_commit_selected)
            vim.cmd('DiffviewOpen ' .. earliest_commit .. '..' .. latest_commit)
          else
            vim.notify('Invalid commits selected', vim.log.levels.INFO)
          end
        else
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          local commit_hash = extract_commit(selection)
          if commit_hash and commit_hash ~= '' then
            if option == 'diff' then
              vim.cmd('DiffviewOpen ' .. commit_hash)
            elseif option == 'show' then
              vim.cmd('DiffviewOpen ' .. commit_hash .. '^!')
            else
              vim.notify('Invalid diffview option', vim.log.levels.INFO)
            end
          else
            vim.notify('No commit selected', vim.log.levels.INFO)
          end
        end
      end

      actions.select_default:replace(on_select)
      return true
    end,
  }
end

local function get_filepath_and_commit()
  -- Get the absolute path, in diffview buffers it starts with "diffview://"
  local filepath = vim.fn.expand '%:p'
  filepath = filepath:gsub('^diffview://', '')
  filepath = vim.fn.fnamemodify(filepath, ':p')

  local repo_root = vim.fn.trim(vim.fn.system 'git rev-parse --show-toplevel')
  if repo_root == '' then
    vim.notify('Could not determine repository root.', vim.log.levels.INFO)
    return nil, nil
  end
  repo_root = vim.fn.fnamemodify(repo_root, ':p')

  if not filepath:find(repo_root, 1, true) then
    vim.notify('File is not inside the repository.\nFilepath: ' .. filepath .. '\nRepo root: ' .. repo_root, vim.log.levels.INFO)
    return nil, nil
  end

  local rel = filepath:sub(#repo_root + 1)
  local commit, new_rel = rel:match '^%.git/([^/]+)/(.+)$'

  if commit then
    return new_rel, commit
  else
    return rel, nil
  end
end

local blame_and_diff = function()
  local relative_path, commit = get_filepath_and_commit()
  if not relative_path then
    return
  end

  local line = vim.fn.line '.'
  local blame_cmd = { 'git', 'blame', '--porcelain', '-L', line .. ',' .. line }

  if commit then
    table.insert(blame_cmd, 3, commit)
  end
  table.insert(blame_cmd, relative_path)

  vim.system(blame_cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify('Blame failed: ' .. (obj.stderr or 'unknown error'), vim.log.levels.INFO)
      end)
      return
    end

    local hash = obj.stdout:match '^(%w+)'
    if not hash or hash:match '^0+$' then
      vim.schedule(function()
        vim.notify('No valid commit found on current line', vim.log.levels.INFO)
      end)
      return
    end

    vim.schedule(function()
      vim.cmd('DiffviewOpen ' .. hash .. '^!')
    end)
  end)
end

return {
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = {
      'DiffviewOpen',
      'DiffviewFileHistory',
    },
    opts = function()
      local actions = require 'diffview.actions'

      return {
        enhanced_diff_hl = true,
        keymaps = {
          view = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>' },
            { 'n', '\\', '<cmd>DiffviewFocusFiles<CR>' },
          },
          file_panel = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>' },
            { 'n', '\\', '<cmd>DiffviewToggleFiles<CR>' },
            { 'n', '<c-u>', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
            { 'n', '<c-d>', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
          },
          file_history_panel = {
            { 'n', 'q', '<cmd>DiffviewClose<CR>' },
            { 'n', '\\', '<cmd>DiffviewToggleFiles<CR>' },
            { 'n', '<c-u>', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
            { 'n', '<c-d>', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
          },
        },
      }
    end,
    config = function(_, opts)
      require('diffview').setup(opts)
    end,
    keys = {
      { '<leader>gdi', '<cmd>DiffviewOpen<CR>', desc = '[G]it [D]iff current [I]ndex' },
      { '<leader>gdd', '<cmd>DiffviewOpen develop<CR>', desc = '[G]it [D]iff [D]evelop' },
      {
        '<leader>gdc',
        function()
          diffview_picker('commit', 'diff')
        end,
        desc = '[G]it [D]iff against [C]ommit',
      },
      {
        '<leader>gdr',
        function()
          diffview_picker('commit', 'diff_range')
        end,
        desc = '[G]it [D]iff commit [R]ange',
      },
      {
        '<leader>gdb',
        function()
          diffview_picker('branch', 'diff')
        end,
        desc = '[G]it [D]iff against [B]ranch',
      },
      {
        '<leader>gds',
        function()
          diffview_picker('commit', 'show')
        end,
        desc = '[G]it [D]iff [S]how commit',
      },
      {
        '<leader>gdl',
        blame_and_diff,
        desc = '[G]it [D]iff [L]ine',
      },
      {
        '<leader>ghf',
        function()
          local path, _ = get_filepath_and_commit()
          vim.cmd('DiffviewFileHistory ' .. path)
        end,
        desc = '[G]it [H]istory this [F]ile',
      },
      { '<leader>gha', '<cmd>DiffviewFileHistory<CR>', desc = '[G]it [H]istory [A]ll files' },
    },
  },
}
