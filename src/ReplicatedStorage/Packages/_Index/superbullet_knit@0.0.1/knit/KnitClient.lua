--[=[
	@interface Middleware
	.Inbound ClientMiddleware?
	.Outbound ClientMiddleware?
	@within KnitClient
]=]
type Middleware = {
	Inbound: ClientMiddleware?,
	Outbound: ClientMiddleware?,
}

--[=[
	@type ClientMiddlewareFn (args: {any}) -> (shouldContinue: boolean, ...: any)
	@within KnitClient

	For more info, see [ClientComm](https://sleitnick.github.io/RbxUtil/api/ClientComm/) documentation.
]=]
type ClientMiddlewareFn = (args: { any }) -> (boolean, ...any)

--[=[
	@type ClientMiddleware {ClientMiddlewareFn}
	@within KnitClient
	An array of client middleware functions.
]=]
type ClientMiddleware = { ClientMiddlewareFn }

--[=[
	@type PerServiceMiddleware {[string]: Middleware}
	@within KnitClient
]=]
type PerServiceMiddleware = { [string]: Middleware }

--[=[
	@interface ControllerDef
	.Name string
	.Instance Instance?
	.[any] any
	@within KnitClient
	Used to define a controller when creating it in `CreateController`.
	
	If `Instance` is provided (typically `script`), Knit will automatically
	initialize components found in a `Components` folder within that instance.
]=]
type ControllerDef = {
	Name: string,
	Instance: Instance?,
	[any]: any,
}

--[=[
	@interface Controller
	.Name string
	.[any] any
	@within KnitClient
]=]
type Controller = {
	Name: string,
	[any]: any,
}

--[=[
	@interface Service
	.[any] any
	@within KnitClient
]=]
type Service = {
	[any]: any,
}

--[=[
	@interface KnitOptions
	.ServicePromises boolean?
	.Middleware Middleware?
	.PerServiceMiddleware PerServiceMiddleware?
	@within KnitClient

	- `ServicePromises` defaults to `true` and indicates if service methods use promises.
	- Each service will go through the defined middleware, unless the service
	has middleware defined in `PerServiceMiddleware`.
]=]
type KnitOptions = {
	ServicePromises: boolean,
	Middleware: Middleware?,
	PerServiceMiddleware: PerServiceMiddleware?,
}

local defaultOptions: KnitOptions = {
	ServicePromises = true,
	Middleware = nil,
	PerServiceMiddleware = {},
}

local selectedOptions = nil

--[=[
	@class KnitClient
	@client
]=]
local KnitClient = {}

--[=[
	@prop Player Player
	@within KnitClient
	@readonly
	Reference to the LocalPlayer.
]=]
KnitClient.Player = game:GetService("Players").LocalPlayer

--[=[
	@prop Util Folder
	@within KnitClient
	@readonly
	References the Util folder. Should only be accessed when using Knit as
	a standalone module. If using Knit from Wally, modules should just be
	pulled in via Wally instead of relying on Knit's Util folder, as this
	folder only contains what is necessary for Knit to run in Wally mode.
]=]
KnitClient.Util = (script.Parent :: Instance).Parent

local Promise = require(KnitClient.Util.Promise)
local Comm = require(KnitClient.Util.Comm)
local ClientComm = Comm.ClientComm
local KnitErrorHelper = require(script.Parent.KnitErrorHelper)

local controllers: { [string]: Controller } = {}
local services: { [string]: Service } = {}
local servicesFolder = nil

local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local function DoesControllerExist(controllerName: string): boolean
	local controller: Controller? = controllers[controllerName]

	return controller ~= nil
end

local function InitializeComponents(serviceOrController, instance: Instance)
	local componentsFolder = instance:WaitForChild("Components", 1)
	if not componentsFolder then
		return
	end

	-- Step 1: Set up Components table and utility functions
	local othersFolder = componentsFolder:WaitForChild("Others", 1)
	if othersFolder then
		serviceOrController.Components = {}
		for _, v in pairs(othersFolder:GetChildren()) do
			if v:IsA("ModuleScript") then
				serviceOrController.Components[v.Name] = require(v)
			end
		end
	end

	-- Set up GetComponent and SetComponent utilities
	local getComponent = componentsFolder:WaitForChild("Get()", 1)
	if getComponent and getComponent:IsA("ModuleScript") then
		serviceOrController.GetComponent = require(getComponent)
	end

	local setComponent = componentsFolder:WaitForChild("Set()", 1)
	if setComponent and setComponent:IsA("ModuleScript") then
		serviceOrController.SetComponent = require(setComponent)
	end

	-- Step 2: Initialize all component modules
	for _, v in pairs(componentsFolder:GetDescendants()) do
		if v:IsA("ModuleScript") then
			local success, module = pcall(require, v)
			if success and typeof(module) == "table" then
				-- Check if already initialized (backwards compatibility)
				if v:GetAttribute("Initialized") then
					continue
				end

				if module.Init and typeof(module.Init) == "function" then
					v:SetAttribute("Initialized", true)
					local initSuccess, err = pcall(function()
						module.Init()
					end)

					if not initSuccess then
						warn(`Error initializing component {v:GetFullName()}: {err}`)
					end
				end
			end
		end
	end
end

local function StartComponents(serviceOrController, instance: Instance)
	local componentsFolder = instance:WaitForChild("Components", 1)
	if not componentsFolder then
		return
	end

	-- Start all component modules
	for _, v in pairs(componentsFolder:GetDescendants()) do
		if v:IsA("ModuleScript") then
			local success, module = pcall(require, v)
			if success and typeof(module) == "table" then
				if module.Start and typeof(module.Start) == "function" then
					-- Check if already started (backwards compatibility)
					if not v:GetAttribute("Started") then
						v:SetAttribute("Started", true)
						task.spawn(function()
							module.Start()
						end)
					end
				end
			end
		end
	end
end

local function GetServicesFolder()
	if not servicesFolder then
		servicesFolder = (script.Parent :: Instance):WaitForChild("Services", 30)
		if not servicesFolder then
			error(
				"\n━━━━━━━━━━━━━━━━━━━━\n"
					.. "❌ Knit Error: Services folder not found\n"
					.. "━━━━━━━━━━━━━━━━━━━━\n"
					.. "The server has not finished initializing yet.\n"
					.. "\n"
					.. "Most common cause:\n"
					.. "⚠️  A KnitInit error occurred on the server\n"
					.. "    Check the server console for KnitInit errors above.\n"
					.. "━━━━━━━━━━━━━━━━━━━━"
			)
		end
	end

	return servicesFolder
end

local function GetMiddlewareForService(serviceName: string)
	local knitMiddleware = if selectedOptions.Middleware ~= nil then selectedOptions.Middleware else {}
	local serviceMiddleware = selectedOptions.PerServiceMiddleware[serviceName]

	return if serviceMiddleware ~= nil then serviceMiddleware else knitMiddleware
end

local function BuildService(serviceName: string)
	local folder = GetServicesFolder()
	local middleware = GetMiddlewareForService(serviceName)
	local clientComm = ClientComm.new(folder, selectedOptions.ServicePromises, serviceName)
	local service = clientComm:BuildObject(middleware.Inbound, middleware.Outbound)

	services[serviceName] = service

	return service
end

--[=[
	Creates a new controller.

	:::caution
	Controllers must be created _before_ calling `Knit.Start()`.
	:::
	```lua
	-- Create a controller
	local MyController = Knit.CreateController {
		Name = "MyController",
	}

	function MyController:KnitStart()
		print("MyController started")
	end

	function MyController:KnitInit()
		print("MyController initialized")
	end
	```
	
	With automatic component initialization:
	```lua
	local MyController = Knit.CreateController {
		Name = "MyController",
		Instance = script,  -- Automatically initializes components
	}
	```
]=]
function KnitClient.CreateController(controllerDef: ControllerDef): Controller
	assert(type(controllerDef) == "table", `Controller must be a table; got {type(controllerDef)}`)
	assert(type(controllerDef.Name) == "string", `Controller.Name must be a string; got {type(controllerDef.Name)}`)
	assert(#controllerDef.Name > 0, "Controller.Name must be a non-empty string")
	assert(not DoesControllerExist(controllerDef.Name), `Controller {controllerDef.Name} already exists`)
	assert(not started, `Controllers cannot be created after calling "Knit.Start()"`)

	local controller = controllerDef :: Controller

	controllers[controller.Name] = controller

	return controller
end

--[=[
	Requires all the modules that are children of the given parent. This is an easy
	way to quickly load all controllers that might be in a folder.
	```lua
	Knit.AddControllers(somewhere.Controllers)
	```
]=]
function KnitClient.AddControllers(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Knit.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	Requires all the modules that are descendants of the given parent.
]=]
function KnitClient.AddControllersDeep(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Knit.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	Returns a Service object which is a reflection of the remote objects
	within the Client table of the given service. Throws an error if the
	service is not found.

	If a service's Client table contains RemoteSignals and/or RemoteProperties,
	these values are reflected as
	[ClientRemoteSignals](https://sleitnick.github.io/RbxUtil/api/ClientRemoteSignal) and
	[ClientRemoteProperties](https://sleitnick.github.io/RbxUtil/api/ClientRemoteProperty).

	```lua
	-- Server-side service creation:
	local MyService = Knit.CreateService {
		Name = "MyService",
		Client = {
			MySignal = Knit.CreateSignal(),
			MyProperty = Knit.CreateProperty("Hello"),
		},
	}
	function MyService:AddOne(player, number)
		return number + 1
	end

	-------------------------------------------------

	-- Client-side service reflection:
	local MyService = Knit.GetService("MyService")

	-- Call a method:
	local num = MyService:AddOne(5) --> 6

	-- Fire a signal to the server:
	MyService.MySignal:Fire("Hello")

	-- Listen for signals from the server:
	MyService.MySignal:Connect(function(message)
		print(message)
	end)

	-- Observe the initial value and changes to properties:
	MyService.MyProperty:Observe(function(value)
		print(value)
	end)
	```

	:::caution
	Services are only exposed to the client if the service has remote-based
	content in the Client table. If not, the service will not be visible
	to the client. `KnitClient.GetService` will only work on services that
	expose remote-based content on their Client tables.
	:::
]=]
function KnitClient.GetService(serviceName: string): Service
	local service = services[serviceName]
	if service then
		return service
	end

	assert(started, KnitErrorHelper.GetStartErrorMessage(started, "GetService", controllers, true)) -- true = client-side
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	-- Warn if GetService is called during initialization and takes too long
	if not startedComplete then
		task.spawn(function()
			task.wait(5)
			if not startedComplete then
				warn(
					string.format(
						"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
							.. "⚠️  Knit Initialization Warning (Client)\n"
							.. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
							.. "GetService('%s') called during initialization, and Knit has been\n"
							.. "initializing for more than 5 seconds.\n"
							.. "\n"
							.. "Possible causes:\n"
							.. "• Service '%s' does not exist on the server\n"
							.. "• Service has no Client table exposed\n"
							.. "• Server has not finished initializing (check server console)\n"
							.. "• A KnitInit or component Init() is yielding\n"
							.. "\n"
							.. "This is blocking Knit from completing initialization.\n"
							.. "\n"
							.. "💡 If none of these are the issue, scroll up in the console\n"
							.. "   to find any other warnings or errors that might be the cause.\n"
							.. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
						serviceName,
						serviceName
					)
				)
			end
		end)
	end

	return BuildService(serviceName)
end

--[=[
	Gets the controller by name. Throws an error if the controller
	is not found.
]=]
function KnitClient.GetController(controllerName: string): Controller
	local controller = controllers[controllerName]
	if controller then
		return controller
	end

	assert(started, KnitErrorHelper.GetStartErrorMessage(started, "GetController", controllers, true)) -- true = client-side
	assert(type(controllerName) == "string", `ControllerName must be a string; got {type(controllerName)}`)
	error(`Could not find controller "{controllerName}". Check to verify a controller with this name exists.`, 2)
end

--[=[
	Gets a table of all controllers.
]=]
function KnitClient.GetControllers(): { [string]: Controller }
	assert(started, KnitErrorHelper.GetStartErrorMessage(started, "GetControllers", controllers, true)) -- true = client-side

	return controllers
end

--[=[
	@return Promise
	Starts Knit. Should only be called once per client.
	```lua
	Knit.Start():andThen(function()
		print("Knit started!")
	end):catch(warn)
	```

	By default, service methods exposed to the client will return promises.
	To change this behavior, set the `ServicePromises` option to `false`:
	```lua
	Knit.Start({ServicePromises = false}):andThen(function()
		print("Knit started!")
	end):catch(warn)
	```
]=]
function KnitClient.Start(options: KnitOptions?)
	if started then
		return Promise.reject("Knit already started")
	end

	started = true

	table.freeze(controllers)

	if options == nil then
		selectedOptions = defaultOptions
	else
		assert(typeof(options) == "table", `KnitOptions should be a table or nil; got {typeof(options)}`)
		selectedOptions = options
		for k, v in defaultOptions do
			if selectedOptions[k] == nil then
				selectedOptions[k] = v
			end
		end
	end
	if type(selectedOptions.PerServiceMiddleware) ~= "table" then
		selectedOptions.PerServiceMiddleware = {}
	end

	return Promise.new(function(resolve)
		-- Init:
		local promisesStartControllers = {}

		for _, controller in controllers do
			if type(controller.KnitInit) == "function" then
				table.insert(
					promisesStartControllers,
					Promise.new(function(r, reject)
						debug.setmemorycategory(controller.Name)
						local success, err = pcall(function()
							controller:KnitInit()
						end)
						if success then
							r()
						else
							-- Get the source path using debug.info
							local source = debug.info(controller.KnitInit, "s")
							local controllerPath = source:match("^@?(.+)$") or controller.Name
							reject(string.format("", controller.Name, controllerPath, tostring(err)))
						end
					end)
				)
			end
		end

		resolve(Promise.all(promisesStartControllers))
	end):andThen(function()
		-- Initialize Components (setup and init before KnitStart):
		local controllersWithComponents = {}
		for _, controller in controllers do
			if controller.Instance then
				InitializeComponents(controller, controller.Instance)
				table.insert(controllersWithComponents, { controller = controller, instance = controller.Instance })
				controller.Instance = nil -- Clean up, no longer needed
			end
		end

		-- Start:
		for _, controller in controllers do
			if type(controller.KnitStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(controller.Name)
					controller:KnitStart()
				end)
			end
		end

		-- Start Components (after all controllers have started):
		task.defer(function()
			for _, data in controllersWithComponents do
				StartComponents(data.controller, data.instance)
			end
		end)

		startedComplete = true
		onStartedComplete:Fire()

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

--[=[
	@return Promise
	Returns a promise that is resolved once Knit has started. This is useful
	for any code that needs to tie into Knit controllers but is not the script
	that called `Start`.
	```lua
	Knit.OnStart():andThen(function()
		local MyController = Knit.GetController("MyController")
		MyController:DoSomething()
	end):catch(warn)
	```
]=]
function KnitClient.OnStart()
	if startedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(onStartedComplete.Event)
	end
end

return KnitClient
