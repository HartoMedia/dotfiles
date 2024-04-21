local sqlite = require('sqlite')
local db_path = vim.fn.stdpath('data') .. '/neostats.db'
local db = sqlite.open(db_path)

local M = {}

function M.setup()
  -- Ensure the database and the sessions table exists
  db:with_open(function()
    db:eval([[
      CREATE TABLE IF NOT EXISTS sessions (
        date TEXT PRIMARY KEY,
        duration INTEGER NOT NULL
      );
    ]])
  end)

  vim.g.start_time = vim.loop.now()

  -- Define the command NeoStats
  vim.api.nvim_create_user_command('NeoStats', function()
    db:with_open(function()
      local stats = db:select('sessions', {
        keys = 'date, SUM(duration) as total_duration',
        where = { group_by = 'date' },
        order_by = 'date DESC'
      })
      if #stats == 0 then
        print("No data available.")
      else
        for _, stat in ipairs(stats) do
          print(string.format("Date: %s, Total Time: %d seconds", stat.date, stat.total_duration))
        end
      end
    end)
  end, {})
end

-- Autocommand to handle exiting Neovim
vim.api.nvim_create_autocmd({"VimLeavePre"}, {
  callback = function()
    local duration = math.floor((vim.loop.now() - vim.g.start_time) / 1000)
    local date = os.date("%Y-%m-%d")
    db:with_open(function()
      -- Update if exists, otherwise insert
      local existing = db:select('sessions', { where = { date = date } })
      if existing and #existing > 0 then
        local new_duration = existing[1].duration + duration
        db:update('sessions', { duration = new_duration }, { where = { date = date } })
      else
        db:insert('sessions', { date = date, duration = duration })
      end
    end)
  end,
})

return M

