-- AI NOTE: Executes Lua code received from run_lua_code WebSocket messages.
-- Uses loadstring() + pcall() for safe execution with print output capture via LogService.
-- Runs in server context (ServerScriptService) so loadstring and server APIs are available.

local LogService = game:GetService("LogService")

local CodeExecutor = {}

-- Execute code and return a structured result table.
-- Print capture limitation: LogService.MessageOut captures ALL server prints during the
-- execution window, including from other scripts running concurrently. This is acceptable
-- for short, infrequent AI debug commands.
function CodeExecutor.execute(requestId, code)
	local capturedOutput = {}

	-- Hook LogService to capture print output during execution
	local logConnection = LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageOutput then
			table.insert(capturedOutput, message)
		end
	end)

	local startTime = os.clock()

	-- Compile the code
	local fn, compileError = loadstring(code)

	if not fn then
		logConnection:Disconnect()
		return {
			success = false,
			error = "Compile error: " .. tostring(compileError),
		}
	end

	-- Execute with pcall for safety
	local execSuccess, execResult = pcall(fn)

	local executionTime = math.floor((os.clock() - startTime) * 1000) -- milliseconds

	logConnection:Disconnect()

	if not execSuccess then
		return {
			success = false,
			error = tostring(execResult),
		}
	end

	-- Build output string from captured prints
	local output = table.concat(capturedOutput, "\n")

	-- If the code returned a value, append it to output
	if execResult ~= nil then
		if output ~= "" then
			output = output .. "\n" .. tostring(execResult)
		else
			output = tostring(execResult)
		end
	end

	return {
		success = true,
		data = {
			output = output,
			executionTime = executionTime,
		},
	}
end

return CodeExecutor
