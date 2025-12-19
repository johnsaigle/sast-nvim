local M = {}

--- Build command from adapter spec and config
---@param spec table Adapter specification
---@param config table Adapter configuration
---@param filepath string File to analyze
---@return string|nil cmd Executable command
---@return table|nil args Command arguments
function M.build_command(spec, config, filepath)
	-- Find the executable
	local executables = type(spec.executable) == "table" and spec.executable or { spec.executable }
	local cmd = nil
	
	for _, exe in ipairs(executables) do
		local path = vim.fn.exepath(exe)
		if path ~= "" then
			cmd = exe
			break
		end
	end
	
	if not cmd then
		local exe_list = table.concat(executables, ", ")
		vim.notify(
			string.format("No executable found in PATH: %s", exe_list),
			vim.log.levels.WARN
		)
		return nil, nil
	end
	
	-- Build arguments using adapter's build_args function
	local args = spec.build_args(config, filepath)
	
	return cmd, args
end

--- Execute command asynchronously
---@param cmd string Command to execute
---@param args table Command arguments
---@param callback function(stdout, stderr, exit_code) Callback when complete
function M.execute_async(cmd, args, callback)
	local full_cmd = vim.list_extend({ cmd }, args)
	
	vim.system(
		full_cmd,
		{
			text = true,
			cwd = vim.fn.getcwd(),
			env = vim.env,
		},
		function(obj)
			vim.schedule(function()
				callback(obj.stdout or "", obj.stderr or "", obj.code or 0)
			end)
		end
	)
end

return M
