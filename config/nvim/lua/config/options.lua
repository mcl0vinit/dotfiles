-- This file contains all Neovim options/settings
-- It's loaded by init.lua via require("config.options")

-- Set leader key to space (must be before other mappings)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.clipboard = "unnamedplus" -- Use system clipboard

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = false -- Keep absolute line numbers for numberG navigation

-- Indentation 
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true -- Smart auto-indenting

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false -- Don't highlight search results after searching

-- UI improvements
vim.opt.termguicolors = true -- Better colors
vim.opt.signcolumn = "yes" -- Always show sign column (for git/diagnostics)
vim.opt.cursorline = true -- Highlight current line
vim.opt.scrolloff = 8 -- Keep 8 lines visible above/below cursor
vim.opt.sidescrolloff = 8 -- Keep 8 columns visible left/right of cursor

-- Better editing experience
vim.opt.updatetime = 50 -- Faster completion
vim.opt.timeoutlen = 300 -- Faster key sequence completion
vim.opt.undofile = true -- Persistent undo
vim.opt.backup = false -- Don't create backup files
vim.opt.swapfile = false -- Don't create swap files
vim.opt.wrap = false -- Don't wrap lines

-- Split windows
vim.opt.splitbelow = true -- New horizontal splits go below
vim.opt.splitright = true -- New vertical splits go right

-- Better completion experience
vim.opt.completeopt = "menuone,noselect"