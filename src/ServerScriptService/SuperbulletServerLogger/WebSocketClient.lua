-- AI NOTE: WebSocket client for connecting to the Cloudflare backend during playtesting.
-- Handles run_lua_code message routing from the backend to the CodeExecutor.
-- Cloud mode only — in localhost mode there is no WebSocket endpoint.
-- No reconnection logic — if the connection drops, the backend falls back to plugin HTTP polling.

local HttpService = game:GetService("HttpService")

local BACKEND_BASE_URL = "wss://superbullet-backend-3948693.superbulletstudios.com"

local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

function WebSocketClient.new(config)
	local self = setmetatable({}, WebSocketClient)
	self._config = config
	self._wsClient = nil
	self._connected = false
	self._messageHandler = nil
	self._connections = {} -- RBXScriptConnection cleanup list
	return self
end

function WebSocketClient:setMessageHandler(handler)
	self._messageHandler = handler
end

function WebSocketClient:connect()
	local url = self:_buildWebSocketUrl()
	if not url then
		warn("[SuperbulletLogger] WebSocket: Cannot build URL (missing cloudToken)")
		return
	end

	local success, wsClient = pcall(function()
		return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
			Url = url,
		})
	end)

	if not success then
		warn("[SuperbulletLogger] WebSocket: Failed to create client:", wsClient)
		return
	end

	self._wsClient = wsClient

	-- Connection opened
	table.insert(self._connections, wsClient.Opened:Connect(function(statusCode, headers)
		self._connected = true
		print("[SuperbulletLogger] WebSocket: Connected (status " .. tostring(statusCode) .. ")")
		self:_send({ type = "framework_ready" })
	end))

	-- Message received
	table.insert(self._connections, wsClient.MessageReceived:Connect(function(message)
		self:_handleMessage(message)
	end))

	-- Error
	table.insert(self._connections, wsClient.Error:Connect(function(statusCode, errorMessage)
		warn("[SuperbulletLogger] WebSocket error (status " .. tostring(statusCode) .. "):", errorMessage)
		self._connected = false
	end))

	-- Closed
	table.insert(self._connections, wsClient.Closed:Connect(function()
		print("[SuperbulletLogger] WebSocket: Closed")
		self._connected = false
	end))
end

function WebSocketClient:disconnect()
	if not self._wsClient then
		return
	end

	-- Send graceful disconnect message directly (bypass _send to avoid state issues)
	if self._connected then
		pcall(function()
			self._wsClient:Send(HttpService:JSONEncode({ type = "framework_disconnecting" }))
		end)
	end

	pcall(function()
		self._wsClient:Close()
	end)

	-- Clean up signal connections
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	self._wsClient = nil
	self._connected = false
end

function WebSocketClient:sendResponse(message)
	self:_send(message)
end

function WebSocketClient:getConnected()
	return self._connected
end

-- Internal: Send a JSON-encoded message over WebSocket
function WebSocketClient:_send(message)
	if not self._wsClient or not self._connected then
		return
	end

	local success, err = pcall(function()
		self._wsClient:Send(HttpService:JSONEncode(message))
	end)

	if not success then
		warn("[SuperbulletLogger] WebSocket: Failed to send:", err)
	end
end

-- Internal: Parse and route incoming messages by type
function WebSocketClient:_handleMessage(data)
	local success, message = pcall(function()
		return HttpService:JSONDecode(data)
	end)

	if not success then
		warn("[SuperbulletLogger] WebSocket: Failed to parse message:", data)
		return
	end

	if message.type == "ping" then
		self:_send({ type = "pong" })
	elseif message.type == "run_lua_code" then
		if self._messageHandler then
			self._messageHandler(message)
		end
	end
end

-- Internal: Build the WebSocket URL from config
function WebSocketClient:_buildWebSocketUrl()
	if not self._config.cloudToken then
		return nil
	end
	return BACKEND_BASE_URL .. "/api/superbullet/ws?token=" .. self._config.cloudToken
end

return WebSocketClient
