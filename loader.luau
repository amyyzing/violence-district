local BASE = "https://raw.githubusercontent.com/amyyzing/violence-district/v0.1.10/"
local globalState = getgenv and getgenv() or _G

globalState.ViolenceDistrictBaseUrl = BASE

local chunk, err = loadstring(game:HttpGet(BASE .. "gui/gui.luau"))
if not chunk then
	error("Failed to load GUI: " .. tostring(err), 0)
end

chunk()
