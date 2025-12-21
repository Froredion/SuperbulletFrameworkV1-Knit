local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local TemplateController = Knit.CreateController({
	Name = "TemplateController",
	Instance = script, -- Automatically initializes components
})

--- Knit Services

--- Knit Controllers

function TemplateController:KnitStart() 

end

function TemplateController:KnitInit()

end

return TemplateController
