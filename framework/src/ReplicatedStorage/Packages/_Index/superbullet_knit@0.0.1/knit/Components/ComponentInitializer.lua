--[[
	ComponentInitializer.lua

	Handles initialization and starting of service/controller components.
	Shared between KnitServer and KnitClient.

	Part of SuperbulletFrameworkV1-Knit (2025)
]]

local ComponentInitializer = {}

--- Set to true to enable [INITDBG] initialization profiling prints
ComponentInitializer.DebugInit = false

local function dbg(...)
	if ComponentInitializer.DebugInit then
		print("[INITDBG]", ...)
	end
end

--[=[
	Initializes components for a service or controller.
	Sets up Components table, Accessor, Mutator, and calls Init() on all component modules.

	@param serviceOrController table -- The service or controller to initialize components for
	@param instance Instance -- The instance containing the Components folder
]=]
function ComponentInitializer.Initialize(serviceOrController, instance: Instance)
	local componentsFolder = instance:WaitForChild("Components", 1)
	if not componentsFolder then
		return
	end

	-- Step 1: Set up Components table and utility functions
	dbg("  Step1: setup START for", instance:GetFullName(), "at", os.clock())
	local othersFolder = componentsFolder:WaitForChild("Others", 1)
	if othersFolder then
		serviceOrController.Components = {}
		for _, v in pairs(othersFolder:GetDescendants()) do
			if v:IsA("ModuleScript") then
				dbg("    require START:", v:GetFullName(), "at", os.clock())
				serviceOrController.Components[v.Name] = require(v)
				dbg("    require END:", v:GetFullName(), "at", os.clock())
			end
		end
	end

	-- Set up Accessor (new) with Get() fallback for backward compatibility
	local accessorComponent = componentsFolder:FindFirstChild("Accessor")
		or componentsFolder:FindFirstChild("Get()")
	if accessorComponent and accessorComponent:IsA("ModuleScript") then
		serviceOrController.Accessor = require(accessorComponent)
		serviceOrController.GetComponent = serviceOrController.Accessor -- Backward compatibility alias
	end

	-- Set up Mutator (new) with Set() fallback for backward compatibility
	local mutatorComponent = componentsFolder:FindFirstChild("Mutator")
		or componentsFolder:FindFirstChild("Set()")
	if mutatorComponent and mutatorComponent:IsA("ModuleScript") then
		serviceOrController.Mutator = require(mutatorComponent)
		serviceOrController.SetComponent = serviceOrController.Mutator -- Backward compatibility alias
	end
	dbg("  Step1: setup END for", instance:GetFullName(), "at", os.clock())

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
					dbg("  >>> Component Init START:", v:GetFullName(), "at", os.clock())
					local initSuccess, err = pcall(function()
						module.Init()
					end)
					dbg("  <<< Component Init END:", v:GetFullName(), "at", os.clock(), if initSuccess then "OK" else "FAIL: " .. tostring(err))

					if not initSuccess then
						warn(`Error initializing component {v:GetFullName()}: {err}`)
					end
				end
			end
		end
	end
end

--[=[
	Starts components for a service or controller.
	Calls Start() on all component modules that have it.

	@param serviceOrController table -- The service or controller (unused, kept for API consistency)
	@param instance Instance -- The instance containing the Components folder
]=]
function ComponentInitializer.Start(serviceOrController, instance: Instance)
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

return ComponentInitializer
