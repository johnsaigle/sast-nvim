local M = {}

--- Parse JSON output from tool
---@param stdout string Standard output from tool
---@param tool_name string Name of the tool (for error messages)
---@return table|nil Parsed JSON results
function M.parse_json_output(stdout, tool_name)
	if not stdout or stdout == "" then
		return nil
	end

	local ok, parsed = pcall(vim.json.decode, stdout)
	if not ok or not parsed then
		vim.notify(
			string.format("Failed to parse %s JSON output", tool_name),
			vim.log.levels.WARN
		)
		return nil
	end

	return parsed
end

--- Transform tool results to Neovim diagnostics
---@param results table Parsed JSON results
---@param validate_fn function(result) -> boolean Validation function
---@param transform_fn function(result, config) -> table Transform function
---@param config table Adapter configuration
---@param tool_name string Name of the tool (for diagnostic source)
---@return table Neovim diagnostics
function M.transform_results(results, validate_fn, transform_fn, config, tool_name)
	local diags = {}

	-- Handle different result structures - some tools wrap in a results array
	local results_array = results.results or results

	-- If results_array is not a table, wrap it
	if type(results_array) ~= "table" then
		return diags
	end

	for _, result in ipairs(results_array) do
		if validate_fn(result) then
			local diag = transform_fn(result, config)

			-- Set source if not already set
			if not diag.source then
				diag.source = tool_name
			end

			-- Apply minimum severity filter if configured
			if config.minimum_severity then
				if diag.severity and diag.severity <= config.minimum_severity then
					table.insert(diags, diag)
				end
			else
				table.insert(diags, diag)
			end
		end
	end

	return diags
end

--- Update diagnostics in buffer
---@param namespace integer Diagnostic namespace
---@param bufnr integer Buffer number
---@param diags table Diagnostics to set
function M.update_diagnostics(namespace, bufnr, diags)
	vim.schedule(function()
		-- Verify buffer is still valid
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		-- Clear old diagnostics first
		vim.diagnostic.reset(namespace, bufnr)

		-- Set new diagnostics
		vim.diagnostic.set(namespace, bufnr, diags)
	end)
end

return M
