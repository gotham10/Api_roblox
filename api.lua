local global_container
do
	local finder_code, global_container_obj = (function()
		local globalenv = getgenv and getgenv() or _G or shared
		local globalcontainer = globalenv.globalcontainer
		if not globalcontainer then
			globalcontainer = {}
			globalenv.globalcontainer = globalcontainer
		end
		local genvs = { _G, shared }
		if getgenv then
			table.insert(genvs, getgenv())
		end
		local calllimit = 0
		do
			local function determineCalllimit()
				calllimit = calllimit + 1
				determineCalllimit()
			end
			pcall(determineCalllimit)
		end
		local function isEmpty(dict)
			for _ in next, dict do
				return
			end
			return true
		end
		local depth, printresults, hardlimit, query, antioverflow, matchedall
		local function recurseEnv(env, envname)
			if globalcontainer == env then
				return
			end
			if antioverflow[env] then
				return
			end
			antioverflow[env] = true
			depth = depth + 1
			for name, val in next, env do
				if matchedall then
					break
				end
				local Type = type(val)
				if Type == "table" then
					if depth < hardlimit then
						recurseEnv(val, name)
					end
				elseif Type == "function" then
					name = string.lower(tostring(name))
					local matched
					for methodname, pattern in next, query do
						if pattern(name, envname) then
							globalcontainer[methodname] = val
							if not matched then
								matched = {}
							end
							table.insert(matched, methodname)
							if printresults then
								print(methodname, name)
							end
						end
					end
					if matched then
						for _, methodname in next, matched do
							query[methodname] = nil
						end
						matchedall = isEmpty(query)
						if matchedall then
							break
						end
					end
				end
			end
			depth = depth - 1
		end
		local function finder(Query, ForceSearch, CustomCallLimit, PrintResults)
			antioverflow = {}
			query = {}
			do
				local function Find(String, Pattern)
					return string.find(String, Pattern, nil, true)
				end
				for methodname, pattern in next, Query do
					if not globalcontainer[methodname] or ForceSearch then
						if not Find(pattern, "return") then
							pattern = "return " .. pattern
						end
						query[methodname] = loadstring(pattern)
					end
				end
			end
			depth = 0
			printresults = PrintResults
			hardlimit = CustomCallLimit or calllimit
			recurseEnv(genvs)
			do
				local env = getfenv()
				for methodname in next, Query do
					if not globalcontainer[methodname] then
						globalcontainer[methodname] = env[methodname]
					end
				end
			end
			hardlimit = nil
			depth = nil
			printresults = nil
			antioverflow = nil
			query = nil
		end
		return finder, globalcontainer
	end)()
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
		local require_online = (function()
			local RequireCache = {}
			local function ARequire(ModuleScript)
				local Cached = RequireCache[ModuleScript]
				if Cached then
					return Cached
				end
				local Source = ModuleScript.Source
				local LoadedSource = loadstring(Source)
				local fenv = getfenv(LoadedSource)
				fenv.script = ModuleScript
				fenv.require = ARequire
				local Output = LoadedSource()
				RequireCache[ModuleScript] = Output
				return Output
			end
			local function ARequireController(AssetId)
				local ModuleScript = game:GetObjects("rbxassetid://" .. AssetId)[1]
				return ARequire(ModuleScript)
			end
			return ARequireController
		end)()
		if require_online then
			sha384 = require_online(4544052033).sha384
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
		local args = { ... }
		if not func then
			return false, "Function is nil"
		end
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
	if type(path) ~= "string" then
		return nil
	end
	local waitTime = waitTimeout or 10
	local parts = path:split(".")
	local current = getfenv()
	for i = 1, #parts do
		local partName = parts[i]
		if current and type(current) == "table" and partName:lower() == "game" then
			current = current[partName]
		elseif current and typeof(current) == "Instance" then
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
				warn("Could not find child '" .. partName .. "' in '" .. current:GetFullName() .. "'")
				return nil
			end
		else
			warn("Path is invalid at: " .. partName)
			return nil
		end
	end
	return current
end

function copyScriptSource(target, timeout)
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
		ldeccache[hashed_bytecode] = output
	end
	setclipboard(output)
	print("Success! Decompiled script source copied to clipboard.")
end

if path and type(path) == "string" and path:gsub("%s*", "") ~= "" then
	copyScriptSource("game." .. path)
else
	warn("Path is not defined or is empty. Please set the 'path' variable before running the script.")
	print("Example: path = 'Players.LocalPlayer.PlayerScripts'")
end
