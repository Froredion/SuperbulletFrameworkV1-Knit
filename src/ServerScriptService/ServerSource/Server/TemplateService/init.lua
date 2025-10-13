local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local TemplateService = Knit.CreateService({
	Name = "TemplateService",
	Instance = script, -- Automatically initializes components
})

---- Knit Services

function TemplateService:KnitStart() 

end

function TemplateService:KnitInit() 
	
end

return TemplateService
