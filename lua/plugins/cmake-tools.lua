local function genKeys()
  local map = LazyVim.safe_keymap_set
  local wk = require("which-key")
  wk.add({
    -- cmake tools
    { "<leader>cm", desc = "cmake" },
  })
  -- map in leader c, m, g to generate cmake configuration
  map("n", "<leader>cmg", "<cmd>CMakeGenerate<CR>", { desc = "Generate CMake configuration" })
  -- map in leader c, m, b to build cmake configuration
  map("n", "<leader>cmb", "<cmd>CMakeBuild<CR>", { desc = "Build CMake configuration" })
  -- map in leader c m r to run 'cmake run'
  map("n", "<leader>cmr", "<cmd>CMakeRun<CR>", { desc = "Run current target" })
  -- map in leader c m s to select the target
  map("n", "<leader>cms", "<cmd>CMakeSelectLaunchTarget<CR>", { desc = "Select launch target" })
  -- map in leader c m t to run tests
  map("n", "<leader>cmt", "<cmd>CMakeRunTest<CR>", { desc = "Run tests" })
end

-- Copied and overrided from the official lazyvim configuration about cmake-tools
return {
  {
    "Civitasv/cmake-tools.nvim",
    lazy = true,
    init = function()
      local loaded = false
      local function check()
        local cwd = vim.uv.cwd()
        if vim.fn.filereadable(cwd .. "/CMakeLists.txt") == 1 then
          require("lazy").load({ plugins = { "cmake-tools.nvim" } })
          loaded = true
          genKeys()
        end
      end
      check()
      vim.api.nvim_create_autocmd("DirChanged", {
        callback = function()
          if not loaded then
            check()
          end
        end,
      })
    end,
  },
}
