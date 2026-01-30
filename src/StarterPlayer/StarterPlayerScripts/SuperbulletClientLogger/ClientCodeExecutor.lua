-- AI NOTE: Client-side code executor for run_lua_code client context.
-- Mirrors server-side CodeExecutor: loadstring + pcall with print capture via LogService.
-- Runs in client context so LocalPlayer, PlayerGui, and client-only APIs are accessible.

local LogService = game:GetService("LogService")

local ClientCodeExecutor = {}

function ClientCodeExecutor.execute(code)
	local capturedOutput = {}

	local logConnection = LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageOutput then
			table.insert(capturedOutput, message)
		end
	end)

	local startTime = os.clock()

	local fn, compileError = loadstring(code)
	if not fn then
		logConnection:Disconnect()
		return {
			success = false,
			error = "Compile error: " .. tostring(compileError),
		}
	end

	local execSuccess, execResult = pcall(fn)
	local executionTime = math.floor((os.clock() - startTime) * 1000)

	logConnection:Disconnect()

	if not execSuccess then
		return {
			success = false,
			error = tostring(execResult),
		}
	end

	local output = table.concat(capturedOutput, "\n")
	if execResult ~= nil then
		if output ~= "" then
			output = output .. "\n" .. tostring(execResult)
		else
			output = tostring(execResult)
		end
	end

	return {
		success = true,
		output = output,
		executionTime = executionTime,
	}
end

return ClientCodeExecutor
