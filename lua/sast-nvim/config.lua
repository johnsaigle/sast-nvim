local M = {}

--- Create default configuration for a tool
---@param tool_name string Name of the tool
---@return table Default configuration
function M.create_config(tool_name)
	return {
		enabled = true,
		filetypes = {},
		run_mode = "save", -- "save" or "change"
		debounce_ms = 1000,
		minimum_severity = vim.diagnostic.severity.HINT,
		extra_args = {},
		on_attach = nil,
		run_on_setup = false,
	}
end

--- Merge user configuration with defaults
---@param base_config table Base configuration
---@param user_config table User configuration
---@return table Merged configuration
function M.merge_config(base_config, user_config)
	return vim.tbl_deep_extend("force", base_config, user_config)
end

--- Print current configuration
---@param config table Configuration to print
---@param tool_name string Name of the tool
function M.print_config(config, tool_name)
	local config_lines = { string.format("Current %s Configuration:", tool_name) }
	for k, v in pairs(config) do
		if type(v) == "table" and type(k) == "string" then
			table.insert(config_lines, string.format("%s: %s", k, vim.inspect(v)))
		elseif type(k) == "string" and type(v) ~= "function" then
			table.insert(config_lines, string.format("%s: %s", k, tostring(v)))
		end
	end
	vim.notify(table.concat(config_lines, "\n"), vim.log.levels.INFO)
end

--- Set minimum severity level
---@param config table Configuration to update
---@param level integer vim.diagnostic.severity level
function M.set_minimum_severity(config, level)
	if not vim.tbl_contains(vim.tbl_values(vim.diagnostic.severity), level) then
		vim.notify("Invalid severity level", vim.log.levels.ERROR)
		return
	end
	config.minimum_severity = level
	vim.notify(
		string.format("Minimum severity set to: %s", level),
		vim.log.levels.INFO
	)
end

return M
