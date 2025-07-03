return function()
	local global_container
	do
		local finder_code, global_container_obj = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/UniversalMethodFinder.luau", true), "UniversalMethodFinder")()
		global_container = global_container_obj
		finder_code({
			getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"bytecode",nil,true)',
			hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")'
		}, true, 10)
	end
	
	local getscriptbytecode = global_container.getscriptbytecode
	local sha384
	
	if global_container.hash then
		sha384 = function(data)
			return global_container.hash(data, "sha384")
		end
	end
	
	if not sha384 then
		pcall(function()
			local require_online = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/RequireOnlineModule.luau", true), "RequireOnlineModule")
			if require_online then
				sha384 = require_online()(4544052033).sha384
			end
		end)
	end
	
	local decompile = decompile
	local setclipboard = setclipboard
	local genv = getgenv()
	if not genv.scriptcache then
		genv.scriptcache = {}
	end
	local ldeccache = genv.scriptcache
	
	local function construct_TimeoutHandler(timeout, func, timeout_return_value)
		return function(...)
			local args = {...}
			if not func then return false, "Function is nil" end
			if timeout < 0 then
				return pcall(func, table.unpack(args))
			end
			local thread = coroutine.running()
			local timeoutThread, isCancelled
			timeoutThread = task.delay(timeout, function()
				isCancelled = true
				coroutine.resume(thread, nil, timeout_return_value)
			end)
			task.spawn(function()
				local success, result = pcall(func, table.unpack(args))
				if isCancelled then
					return
				end
				task.cancel(timeoutThread)
				while coroutine.status(thread) ~= "suspended" do
					task.wait()
				end
				coroutine.resume(thread, success, result)
			end)
			return coroutine.yield()
		end
	end
	
	local function findInstanceAndWait(path, waitTimeout)
		if type(path) ~= "string" then return nil end
		local waitTime = waitTimeout or 10
		local parts = path:split(".")
		local current = game

		if parts[1] and parts[1]:lower() == "game" then
			table.remove(parts, 1)
		end

		for i = 1, #parts do
			local partName = parts[i]
			if not current or typeof(current) ~= "Instance" then
				warn("Path is invalid at: " .. partName)
				return nil
			end
			local success, found
			if partName == "LocalPlayer" and current == game:GetService("Players") then
				found = current.LocalPlayer
				success = true
			else
				success, found = pcall(current.WaitForChild, current, partName, waitTime)
			end
			if success and found then
				current = found
			else
				warn("Could not find child '"..partName.."' in '"..current:GetFullName().."'")
				return nil
			end
		end
		return current
	end
	
	local function copyScriptSource(target, timeout)
		if not (decompile and setclipboard and getscriptbytecode and sha384) then
			warn("Error: Required functions are missing. This may be a network issue or an incompatible executor.")
			return
		end
		local scriptInstance = (typeof(target) == "Instance" and target) or findInstanceAndWait(target)
		if not (scriptInstance and scriptInstance:IsA("LuaSourceContainer")) then
			warn("Error: Invalid target. Please provide a valid script instance or a string path to it.")
			return
		end
		local decompileTimeout = timeout or 10
		local getbytecode_h = construct_TimeoutHandler(3, getscriptbytecode)
		local decompiler_h = construct_TimeoutHandler(decompileTimeout, decompile, "-- Decompiler timed out after " .. tostring(decompileTimeout) .. " seconds.")
		print("Attempting to get source for: " .. scriptInstance:GetFullName())
		local success, bytecode = getbytecode_h(scriptInstance)
		local hashed_bytecode
		local cached_source
		if success and bytecode and bytecode ~= "" then
			hashed_bytecode = sha384(bytecode)
			cached_source = ldeccache[hashed_bytecode]
		elseif success then
			setclipboard("-- The script is empty.")
			print("Script is empty. Copied to clipboard.")
			return
		end
		if cached_source then
			setclipboard(cached_source)
			print("Success! Script source copied from cache to clipboard.")
			return
		end
		print("Decompiling script...")
		local decompile_success, decompiled_source = decompiler_h(scriptInstance)
		local output
		if decompile_success and decompiled_source then
			output = string.gsub(decompiled_source, "\0", "\\0")
		else
			output = "--[[ Failed to decompile. Reason: " .. tostring(decompiled_source) .. " ]]"
		end
		if output:match("^%s*%-%- Decompiled with") then
			local first_newline = output:find("\n")
			if first_newline then
				output = output:sub(first_newline + 1)
			else
				output = ""
			end
			output = output:gsub("^%s*\n", "")
		end
		if hashed_bytecode then
			ldecache[hashed_bytecode] = output
		end
		setclipboard(output)
		print("Success! Decompiled script source copied to clipboard.")
	end

	local user_path = getgenv().path
	if not user_path or type(user_path) ~= "string" or user_path == "" then
		warn("Please set the global 'path' variable to the script's path before loading.")
		return
	end

	copyScriptSource(user_path)
end
