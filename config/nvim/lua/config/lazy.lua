-- This file handles the lazy.nvim plugin manager setup
-- It's loaded by init.lua via require("config.lazy")

-- Bootstrap lazy.nvim (auto-install if not present)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("Installing lazy.nvim plugin manager...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.nvim
require("lazy").setup({
  -- Neo-tree file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",      -- Common utilities
      -- "nvim-tree/nvim-web-devicons", -- File icons (optional, requires Nerd Font)
      "MunifTanjim/nui.nvim",        -- UI components
    },
    config = function()
      -- Neo-tree configuration
      require("neo-tree").setup({
        close_if_last_window = true, -- Close Neo-tree if it's the last window
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        default_component_configs = {
          icon = {
            default = "▸", -- Default icon for nodes
            folder_closed = "▸",
            folder_open = "▾",
            folder_empty = "▸",
          },
          name = {
            use_git_status_colors = true,
          },
          file_size = {
            enabled = false, -- Disable file size display
          },
          type = {
            enabled = false, -- Disable file type icons
          },
          git_status = {
            symbols = {
              -- Use text instead of icons
              added     = "[+]",
              modified  = "[M]",
              deleted   = "[D]",
              renamed   = "[R]",
              untracked = "[?]",
              ignored   = "[I]",
              unstaged  = "[U]",
              staged    = "[S]",
              conflict  = "[!]",
            },
            align = "right", -- Align git status to the right
          },
        },
        
        window = {
          position = "left",
          width = 30,
          mapping_options = {
            noremap = true,
            nowait = true,
          },
          mappings = {
            ["<space>"] = "toggle_node",
            ["<2-LeftMouse>"] = "open",
            ["<cr>"] = "open",
            ["l"] = "open",
            ["s"] = "open_split",
            ["v"] = "open_vsplit",
            ["t"] = "open_tabnew",
            ["h"] = "close_node",
            ["z"] = "close_all_nodes",
            ["Z"] = "expand_all_nodes",
            ["a"] = {
              "add",
              config = {
                show_path = "relative" -- "none", "relative", "absolute"
              }
            },
            ["d"] = "delete",
            ["r"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
            ["R"] = "refresh",
            ["?"] = "show_help",
          }
        },
        
        filesystem = {
          filtered_items = {
            visible = false, -- Show hidden files
            hide_dotfiles = false,
            hide_gitignored = true,
            hide_by_name = {
              ".DS_Store",
              "thumbs.db",
            },
          },
          follow_current_file = {
            enabled = true, -- This will find and focus the file in the active buffer
          },
          use_libuv_file_watcher = true, -- Auto-refresh on file changes
        },
        renderers = {
          directory = {
            { "indent" },
            { "icon" },
            { "name" },
            { "git_status", align = "right" }, -- Make sure git status is shown
          },
          file = {
            { "indent" },
            { "icon" },
            { "name" },
            { "git_status", align = "right" }, -- Make sure git status is shown
          },
        },
      })
    end,
  },

  -- Treesitter for better syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate", -- Auto-update parsers
    event = { "BufReadPost", "BufNewFile" }, -- Load on file open
    config = function()
      require("nvim-treesitter.configs").setup({
        -- List of parsers to auto-install
        ensure_installed = {
          "lua",
          "vim",
          "vimdoc",
          "javascript",
          "typescript",
          "python",
          "rust",
          "go",
          "java",
          "c",
          "cpp",
          "bash",
          "json",
          "yaml",
          "html",
          "css",
          "markdown",
          "markdown_inline",
        },
        
        -- Auto-install parsers when entering buffer
        auto_install = true,
        
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        
        -- Indentation based on treesitter
        indent = {
          enable = true,
        },
        
        -- Enable incremental selection
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
          },
        },
      })
    end,
  },

  -- LSP Support
  {
    "neovim/nvim-lspconfig", -- LSP configuration
    dependencies = {
      -- Completion capabilities for LSP
      "hrsh7th/cmp-nvim-lsp",
      -- LSP installer
      {
        "williamboman/mason.nvim",
        config = function()
          require("mason").setup({
            ui = {
              border = "rounded",
              icons = {
                package_installed = "✓",
                package_pending = "➜",
                package_uninstalled = "✗",
              },
            },
          })
        end,
      },
      -- Bridge between mason and lspconfig
      {
        "williamboman/mason-lspconfig.nvim",
        config = function()
          require("mason-lspconfig").setup({
            -- Auto-install these servers
            ensure_installed = {
              "lua_ls",        -- Lua
              "tsserver",      -- TypeScript/JavaScript
              "pyright",       -- Python
              "rust_analyzer", -- Rust
              "gopls",         -- Go
            },
            automatic_installation = true,
          })
        end,
      },
    },
    config = function()
      local lspconfig = require("lspconfig")
      
      -- Define on_attach function for keymaps
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, remap = false }
        
        -- Go to definition
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        -- Show hover information
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        -- Go to implementation
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        -- Show signature help
        vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
        -- Rename symbol
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        -- Code actions
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        -- Find references
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        -- Format code
        vim.keymap.set("n", "<leader>f", function()
          vim.lsp.buf.format({ async = true })
        end, opts)
        -- Show diagnostics
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
        -- Go to next diagnostic
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        -- Go to previous diagnostic
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
      end
      
      -- Configure diagnostic display
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })
      
      -- Define capabilities (for completion via nvim-cmp)
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end
      
      -- Setup servers
      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = { enable = false },
            },
          },
        },
        tsserver = {},
        pyright = {},
        rust_analyzer = {},
        gopls = {},
      }
      
      -- Setup each server
      for server, config in pairs(servers) do
        config.on_attach = on_attach
        config.capabilities = capabilities
        lspconfig[server].setup(config)
      end
    end,
  },

  -- Autocompletion (nvim-cmp)
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      -- Sources
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      -- Snippets
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Load community snippets lazily
      require("luasnip.loaders.from_vscode").lazy_load()
      luasnip.config.setup({})

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
        formatting = {
          fields = { "abbr", "kind", "menu" },
        },
        experimental = { ghost_text = false },
      })
    end,
  },

  -- Telescope (fuzzy finder)
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false, -- latest
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<C-n>"] = actions.cycle_history_next,
              ["<C-p>"] = actions.cycle_history_prev,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
          },
        },
      })
      pcall(telescope.load_extension, "fzf")
    end,
  },

  -- Gitsigns (inline git hunks)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { hl = "GitSignsAdd", text = "+", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
          change = { hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
          delete = { hl = "GitSignsDelete", text = "_", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
          topdelete = { hl = "GitSignsDelete", text = "‾", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
          changedelete = { hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local map = function(mode, lhs, rhs, opts)
            opts = opts or {}
            if type(opts) == "string" then
              opts = { desc = opts }
            end
            opts.buffer = bufnr
            vim.keymap.set(mode, lhs, rhs, opts)
          end
          -- Navigation
          map("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(function() gs.next_hunk() end)
            return "<Ignore>"
          end, { desc = "Next hunk", expr = true })
          map("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(function() gs.prev_hunk() end)
            return "<Ignore>"
          end, { desc = "Prev hunk", expr = true })
          -- Actions
          map({"n","v"}, "<leader>hs", gs.stage_hunk, "Stage hunk")
          map({"n","v"}, "<leader>hr", gs.reset_hunk, "Reset hunk")
          map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
          map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
          map("n", "<leader>hp", gs.preview_hunk_inline, "Preview hunk")
          map("n", "<leader>hb", gs.toggle_current_line_blame, "Toggle line blame")
          map("n", "<leader>hd", gs.diffthis, "Diff against index")
          map("n", "<leader>hD", function() gs.diffthis('~') end, "Diff against HEAD")
          -- Text object
          map({"o","x"}, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
        end,
      })
    end,
  },
}, {
  -- Lazy.nvim configuration options
  install = {
    -- Install missing plugins on startup
    missing = true,
    -- Try to load one of these colorschemes when starting an installation during startup
    colorscheme = { "habamax" },
  },
  ui = {
    -- Border style for lazy window
    border = "rounded",
    -- Icons (you can disable if you don't have a Nerd Font)
    icons = {
      cmd = "⌘",
      config = "🛠",
      event = "📅",
      ft = "📂",
      init = "⚙",
      keys = "🗝",
      plugin = "🔌",
      runtime = "💻",
      source = "📄",
      start = "🚀",
      task = "📌",
      lazy = "💤 ",
    },
  },
  performance = {
    rtp = {
      -- Disable some rtp plugins for better startup time
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
