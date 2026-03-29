-- This file contains all custom key mappings
-- It's loaded by init.lua via require("config.keymaps")

-- Shorten function name
local keymap = vim.keymap.set

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize windows with arrows
keymap("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
keymap("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

-- Move text up and down
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })

-- Better paste (keep register when pasting over selection)
keymap("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Stay in indent mode
keymap("v", "<", "<gv", { desc = "Indent left" })
keymap("v", ">", ">gv", { desc = "Indent right" })

-- Clear search highlighting with ESC
keymap("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search highlight" })

-- Better navigation for wrapped lines
keymap("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Move down" })
keymap("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Move up" })

-- Quick save
keymap("n", "<leader>w", ":w<CR>", { desc = "Save file" })

-- Quick quit
keymap("n", "<leader>q", ":q<CR>", { desc = "Quit" })

-- Neo-tree
keymap("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle file explorer" })
keymap("n", "<leader>fe", ":Neotree focus<CR>", { desc = "Focus file explorer" })

-- Telescope (fuzzy finder)
local tb = function()
  return require("telescope.builtin")
end
keymap("n", "<leader>ff", function() tb().find_files() end, { desc = "Find files" })
keymap("n", "<leader>fg", function() tb().live_grep() end, { desc = "Live grep" })
keymap("n", "<leader>fb", function() tb().buffers() end, { desc = "Buffers" })
keymap("n", "<leader>fh", function() tb().help_tags() end, { desc = "Help tags" })
keymap("n", "<leader>fd", function() tb().diagnostics() end, { desc = "Diagnostics" })
keymap("n", "<leader>/", function() tb().current_buffer_fuzzy_find() end, { desc = "Search in buffer" })
