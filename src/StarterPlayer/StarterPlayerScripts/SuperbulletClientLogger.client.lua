-- SuperbulletClientLogger.client.lua
-- Captures client-side logs and sends them to server via RemoteEvent
-- NOTE: Only runs in Roblox Studio, not in production

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

-- Only run in Studio (useless in production)
if not RunService:IsStudio() then
	return
end

-- Wait for RemoteEvent (created by server logger)
local clientLogEvent = ReplicatedStorage:WaitForChild("SuperbulletClientLog", 10)
if not clientLogEvent then
	warn("[SuperbulletLogger] Could not find client log event")
	return
end

-- Rate limiting
local LOG_RATE_LIMIT = 10 -- max logs per second
local logCount = 0
local lastResetTime = tick()

local function canSendLog()
	local now = tick()
	if now - lastResetTime >= 1 then
		logCount = 0
		lastResetTime = now
	end

	if logCount >= LOG_RATE_LIMIT then
		return false
	end

	logCount = logCount + 1
	return true
end

-- Send log to server
local function sendLog(level, message, traceback)
	if not canSendLog() then return end

	clientLogEvent:FireServer({
		level = level,
		message = message,
		traceback = traceback
	})
end

-- Map MessageType to log level
local function getLogLevel(messageType)
	if messageType == Enum.MessageType.MessageError then
		return "error"
	elseif messageType == Enum.MessageType.MessageWarning then
		return "warning"
	elseif messageType == Enum.MessageType.MessageInfo then
		return "info"
	elseif messageType == Enum.MessageType.MessageOutput then
		return "debug" -- print() statements
	end
	return "info"
end

-- Listen for client-side log messages
LogService.MessageOut:Connect(function(message, messageType)
	local level = getLogLevel(messageType)
	sendLog(level, message)
end)

print("[SuperbulletLogger] Client logger initialized (Studio only)")
