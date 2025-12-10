# sast-nvim

A Lua library for building Neovim diagnostic plugins for static analysis security testing (SAST) tools.

## Overview

`sast-nvim` provides a framework for creating Neovim plugins that integrate static analysis tools with Neovim's native diagnostics system. It handles the common patterns:

1. Running a binary and capturing JSON output
2. Parsing and validating results
3. Transforming tool-specific output to Neovim diagnostics
4. Managing async execution, debouncing, and none-ls integration

## Architecture

The library is structured in modules:

- **init.lua** - Core adapter creation and management
- **runner.lua** - Binary execution and async handling
- **diagnostics.lua** - JSON parsing and diagnostic transformation
- **config.lua** - Base configuration utilities

## Creating an Adapter

To create a plugin for a new tool, you need to provide an adapter specification:

```lua
local sast = require('sast-nvim')

local adapter = sast.create_adapter({
  name = "your-tool",
  executable = "tool-binary", -- or {"primary", "fallback"}
  build_args = function(config, filepath)
    -- Return table of command arguments
    return { "--json", filepath }
  end,
  validate_result = function(result)
    -- Return true if result is valid
    return result.message ~= nil
  end,
  transform_result = function(result, config)
    -- Transform tool result to nvim diagnostic
    return {
      lnum = result.line - 1,
      col = result.column - 1,
      severity = vim.diagnostic.severity.ERROR,
      message = result.message,
      source = "your-tool",
    }
  end,
})
```

## Adapter Specification

### Required Fields

#### `name` (string)
The name of your tool. Used for namespace creation and logging.

#### `executable` (string or table)
The executable to run. Can be:
- A single string: `"revive"`
- A table of fallbacks: `{"semgrep", "opengrep"}`

The library will search for each executable in order and use the first one found.

#### `build_args` (function)
Function that builds command arguments.

**Parameters:**
- `config` (table) - The adapter configuration
- `filepath` (string) - Path to the file being analyzed

**Returns:** table of command arguments

**Example:**
```lua
build_args = function(config, filepath)
  local args = { "--json", "--quiet" }
  for _, arg in ipairs(config.extra_args) do
    table.insert(args, arg)
  end
  table.insert(args, filepath)
  return args
end
```

#### `validate_result` (function)
Function that validates a single result from the tool's JSON output.

**Parameters:**
- `result` (table) - A single result object from the parsed JSON

**Returns:** boolean - true if the result should be processed

**Example:**
```lua
validate_result = function(result)
  return result.message ~= nil and 
         result.line ~= nil
end
```

#### `transform_result` (function)
Function that transforms a tool result into a Neovim diagnostic.

**Parameters:**
- `result` (table) - A validated result object
- `config` (table) - The adapter configuration

**Returns:** table - A Neovim diagnostic object

**Example:**
```lua
transform_result = function(result, config)
  return {
    lnum = result.line - 1,           -- 0-indexed
    col = result.column - 1,          -- 0-indexed
    end_lnum = result.end_line - 1,   -- optional
    end_col = result.end_column - 1,  -- optional
    severity = vim.diagnostic.severity.ERROR,
    message = result.message,
    source = "tool-name",
    user_data = {                     -- optional
      rule_id = result.rule,
    }
  }
end
```

## Adapter Methods

Once created, the adapter provides these methods:

### `adapter.setup(opts)`
Initialize the adapter with user configuration.

```lua
adapter.setup({
  enabled = true,
  filetypes = { "go" },
  run_mode = "save",
  on_attach = function(bufnr, adapter)
    -- Setup keymaps, etc.
  end,
})
```

### `adapter.toggle()`
Toggle the adapter on/off.

### `adapter.print_config()`
Print the current configuration.

### `adapter.set_minimum_severity(level)`
Set the minimum severity level for diagnostics.

```lua
adapter.set_minimum_severity(vim.diagnostic.severity.WARN)
```

### `adapter.run_scan(params)`
Manually trigger a scan (advanced usage).

## Configuration Options

The library provides these standard configuration options:

```lua
{
  enabled = true,                           -- Enable/disable the adapter
  filetypes = {},                          -- List of filetypes to process
  run_mode = "save",                       -- "save" or "change"
  debounce_ms = 1000,                      -- Debounce delay (change mode)
  minimum_severity = vim.diagnostic.severity.HINT,
  extra_args = {},                         -- Extra CLI arguments
  on_attach = nil,                         -- Called when attaching to buffer
  run_on_setup = false,                    -- Run scan on setup
}
```

## Tool-Specific Configuration

Each adapter can extend the base configuration with tool-specific options:

```lua
adapter.setup({
  -- Base options
  enabled = true,
  filetypes = { "go" },
  
  -- Tool-specific options
  semgrep_config = "auto",
  exclude_patterns = { "vendor/" },
  -- ... etc
})
```

## JSON Output Requirements

Tools must output JSON that can be parsed as an array or an object with a `results` array:

```json
[
  {
    "message": "Error message",
    "line": 10,
    "column": 5
  }
]
```

or:

```json
{
  "results": [
    {
      "message": "Error message",
      "line": 10,
      "column": 5
    }
  ]
}
```

The library handles both formats automatically.

## Dependencies

- Neovim >= 0.8.0
- [none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) or [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim)

## Usage in Plugins

To use sast-nvim in your plugin, vendor the library by copying it into your plugin directory:

```
your-plugin.nvim/
  lua/
    sast-nvim/        # Copied from sast-nvim
      init.lua
      runner.lua
      diagnostics.lua
      config.lua
    your-plugin/
      init.lua        # Your adapter implementation
```

Then require it:

```lua
local sast = require('sast-nvim')
```
