local function componentsInitializer(selectedScript)
	local componentsFolder = selectedScript:FindFirstChild("Components")
	if not componentsFolder then
		warn("No Components folder found in " .. selectedScript:GetFullName())
		return
	end

	for _, v in pairs(componentsFolder:GetDescendants()) do
		if v:IsA("ModuleScript") then
			local success, module = pcall(require, v)
			if success and typeof(module) == "table" then
				-- Check if already initialized (prevents double initialization with new Knit system)
				if v:GetAttribute("Initialized") then
					continue
				end

				if module.Init and typeof(module.Init) == "function" then
					v:SetAttribute("Initialized", true)

					local succ, err = pcall(function()
						module.Init()
					end)

					if not succ then
						warn("Error initializing component " .. v:GetFullName() .. ": " .. err)
					end
				elseif not module.Init then
					warn("Component " .. v.Name .. " does not have an Init function")
					continue
				end

				if module.Start and typeof(module.Start) == "function" then
					-- Check if already started (prevents double starting with new Knit system)
					if not v:GetAttribute("Started") then
						v:SetAttribute("Started", true)
						task.spawn(function()
							local startSuccess, err = pcall(function()
								module.Start()
							end)

							if not startSuccess then
								warn("Error starting component " .. v:GetFullName() .. ": " .. err)
							end
						end)
					end
				end
			end
		end
	end
end

return componentsInitializer
