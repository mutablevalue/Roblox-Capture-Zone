--[[ VARIABLES ]]--
-- Services

-- Constants

-- Variables
local module = {}
local thread = {}

--[[ FUNCTIONS ]]--
-- Module functions
function module.new()
	local t = {}
	t.running = false
	t.c = nil
	
	setmetatable(t, thread)
	return t
end

function thread:Start(func)
	self.c = coroutine.create(function()
		while self.running do
			local waittime = func()
			
			if typeof(waittime) == "number" then
				wait(waittime)
			else
				if waittime == false then
					self.running = false
					break
				end
				
				wait()
			end
		end
	end)
	
	self.running = true
	coroutine.resume(self.c)
end

function thread:Stop()
	self.running = false
end

--[[ INITIALIZATION ]]--
thread.__index = thread
return module
