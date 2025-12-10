local M = {}

local runner = require('sast-nvim.runner')
local diagnostics = require('sast-nvim.diagnostics')
local config_utils = require('sast-nvim.config')

--- Create a new SAST adapter instance
---@param spec table Adapter specification
---   - name: string - Name of the tool (e.g., "semgrep")
---   - executable: string|table - Executable name(s) to search for (supports fallbacks)
---   - build_args: function(config, filepath) -> table - Builds command arguments
---   - validate_result: function(result) -> boolean - Validates a single result from JSON
---   - transform_result: function(result, config) -> table - Transforms result to nvim diagnostic
---   - severity_map: table - Maps tool severities to vim.diagnostic.severity
---   - default_severity: integer - Default severity if unmapped (optional)
---@return table Adapter instance
function M.create_adapter(spec)
	-- Validate required fields
	local required = { "name", "executable", "build_args", "validate_result", "transform_result" }
	for _, field in ipairs(required) do
		if not spec[field] then
			error(string.format("Adapter spec missing required field: %s", field))
		end
	end

	local adapter = {
		spec = spec,
		namespace = vim.api.nvim_create_namespace(string.format("sast-nvim-%s", spec.name)),
		config = config_utils.create_config(spec.name),
		debounce_timers = {},
	}

	--- Run the SAST tool scan
	---@param params table Parameters from null-ls
	function adapter.run_scan(params)
		local filepath = vim.api.nvim_buf_get_name(params.bufnr)
		
		-- Build command using the adapter's build_args function
		local cmd, args = runner.build_command(spec, adapter.config, filepath)
		if not cmd then
			return -- Error already notified by build_command
		end

		-- Execute the command asynchronously
		runner.execute_async(cmd, args, function(stdout, stderr, exit_code)
			-- Parse JSON output
			local results = diagnostics.parse_json_output(stdout, spec.name)
			if not results then
				return
			end

			-- Transform results to diagnostics using adapter's transform function
			local diags = diagnostics.transform_results(
				results,
				spec.validate_result,
				spec.transform_result,
				adapter.config,
				spec.name
			)

			-- Update diagnostics in buffer
			diagnostics.update_diagnostics(adapter.namespace, params.bufnr, diags)
		end)
	end

	--- Setup the adapter with user configuration
	---@param opts table User configuration options
	function adapter.setup(opts)
		-- Merge user config with defaults
		if opts then
			adapter.config = config_utils.merge_config(adapter.config, opts)
		end

		-- Validate none-ls is available
		local null_ls_ok, null_ls = pcall(require, "null-ls")
		if not null_ls_ok then
			vim.notify(
				string.format("none-ls is required for %s", spec.name),
				vim.log.levels.ERROR
			)
			return
		end

		-- Create the none-ls source
		local generator = {
			method = adapter.config.run_mode == "save"
				and null_ls.methods.DIAGNOSTICS_ON_SAVE
				or null_ls.methods.DIAGNOSTICS,
			filetypes = adapter.config.filetypes,
			generator = {
				runtime_condition = function()
					return adapter.config.enabled
				end,
				fn = function(params)
					-- Handle debouncing for "change" mode
					if adapter.config.run_mode == "change" then
						-- Cancel any existing timer for this buffer
						if adapter.debounce_timers[params.bufnr] then
							adapter.debounce_timers[params.bufnr]:stop()
							adapter.debounce_timers[params.bufnr]:close()
						end

						-- Create a new timer that will run after debounce delay
						adapter.debounce_timers[params.bufnr] = vim.defer_fn(function()
							adapter.run_scan(params)
						end, adapter.config.debounce_ms)

						return {}
					else
						-- In save mode, run immediately
						adapter.run_scan(params)
						return {}
					end
				end
			}
		}

		null_ls.register(generator)

		-- Set up autocommands if needed
		if adapter.config.on_attach then
			local group = vim.api.nvim_create_augroup(
				string.format("SAST_%s", spec.name),
				{ clear = true }
			)
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				pattern = adapter.config.filetypes,
				callback = function(args)
					adapter.config.on_attach(args.buf, adapter)
				end,
			})
		end

		-- Run initial scan if enabled
		if adapter.config.enabled and adapter.config.run_on_setup then
			-- We need to trigger this properly, but for now just register
		end
	end

	--- Toggle the adapter on/off
	function adapter.toggle()
		adapter.config.enabled = not adapter.config.enabled
		
		if not adapter.config.enabled then
			-- Clear all diagnostics when disabling
			local bufs = vim.api.nvim_list_bufs()
			for _, buf in ipairs(bufs) do
				if vim.api.nvim_buf_is_valid(buf) then
					vim.diagnostic.reset(adapter.namespace, buf)
				end
			end
			vim.notify(
				string.format("%s diagnostics disabled", spec.name),
				vim.log.levels.INFO
			)
		else
			vim.notify(
				string.format("%s diagnostics enabled", spec.name),
				vim.log.levels.INFO
			)
		end
	end

	--- Print current configuration
	function adapter.print_config()
		config_utils.print_config(adapter.config, spec.name)
	end

	--- Set minimum severity level
	---@param level integer vim.diagnostic.severity level
	function adapter.set_minimum_severity(level)
		config_utils.set_minimum_severity(adapter.config, level)
	end

	return adapter
end

return M
