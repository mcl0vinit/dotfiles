-- Neovim Configuration Entry Point
-- This file just loads other modules for organization

-- Load core settings first (leader key, options)
require("config.options")

-- Load key mappings
require("config.keymaps")

-- Load plugin manager and plugins
require("config.lazy")