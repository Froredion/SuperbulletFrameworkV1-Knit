-- Backwards compatibility wrapper for ProfileStore
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore", 10))

-- Create a wrapper module
local ProfileService = {}

-- Copy over the original ProfileStore properties and methods
for key, value in pairs(ProfileStore) do
	ProfileService[key] = value
end

-- Add backwards compatibility method: GetProfileStore() -> New()
function ProfileService.GetProfileStore(store_name, template)
	local profileStore = ProfileStore.New(store_name, template)

	-- Add LoadProfileAsync as an alias for StartSessionAsync
	function profileStore:LoadProfileAsync(profile_key, params)
		local profile = profileStore:StartSessionAsync(profile_key, params)

		if profile then
			-- Add Release() as an alias for EndSession()
			if not profile.Release then
				profile.Release = function(_self)
					return profile:EndSession()
				end
			end

			-- Add ListenToRelease() as an alias for OnSessionEnd
			if not profile.ListenToRelease then
				profile.ListenToRelease = function(_self, callback)
					return profile.OnSessionEnd:Connect(callback)
				end
			end

			-- Add MetaData for backwards compatibility
			if not profile.MetaData then
				profile.MetaData = {
					ProfileCreateTime = profile.FirstSessionTime,
					SessionLoadCount = profile.SessionLoadCount,
					ActiveSession = profile.Session,
				}
			end
		end

		return profile
	end

	return profileStore
end

return ProfileService
