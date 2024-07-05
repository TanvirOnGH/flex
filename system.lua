-- Grab environment
local tonumber = tonumber
local io = io
local os = os
local string = string
local math = math

local timer = require("gears.timer")
local awful = require("awful")
local modutil = require("flex.util")

-- Initialize tables for module
local system = { thermal = {}, dformatted = {}, pformatted = {} }

-- Async settlers generator
function system.simple_async(command, pattern)
	return function(setup)
		awful.spawn.easy_async_with_shell(command, function(output)
			local value = tonumber(string.match(output, pattern))
			setup(value and { value } or { 0 })
		end)
	end
end

-- Disk usage
function system.fs_info(args)
	local fs_info = {}
	args = args or "/"

	-- Get data from df
	local line = modutil.read.output("LC_ALL=C df -kP " .. args .. " | tail -1")

	-- Parse data
	fs_info.size = string.match(line, "^.-[%s]([%d]+)")
	fs_info.mount = string.match(line, "%%[%s]([%p%w]+)")
	fs_info.used, fs_info.avail, fs_info.use_p = string.match(line, "([%d]+)[%D]+([%d]+)[%D]+([%d]+)%%")

	-- Format output special for flex desktop widget
	return { tonumber(fs_info.use_p) or 0, tonumber(fs_info.used) or 0 }
end

-- Qemu image check
local function q_format(size, k)
	if not size or not k then
		return 0
	end
	return k == "K" and tonumber(size) or k == "M" and size * 1024 or k == "G" and size * 1024 ^ 2 or 0
end

function system.qemu_image_size(args)
	local img_info = {}

	-- Get data from qemu-ima
	local line = modutil.read.output("LC_ALL=C qemu-img info " .. args)

	-- Parse data
	local size, k = string.match(line, "disk%ssize:%s([%.%d]+)%s(%w)")
	img_info.size = q_format(size, k)
	local vsize, vk = string.match(line, "virtual%ssize:%s([%.%d]+)%s(%w)")
	img_info.virtual_size = q_format(vsize, vk)
	img_info.use_p = img_info.virtual_size > 0 and math.floor(img_info.size / img_info.virtual_size * 100) or 0

	-- Format output special for flex desktop widget
	return { img_info.use_p, img_info.size, off = img_info.size == 0 }
end

-- Traffic check with vnstat (async)
local vnstat_pattern = "%s+(%d+,%d+)%s(%w+)%s+%|%s+(%d+,%d+)%s(%w+)%s+%|%s+(%d+,%d+)%s(%w+)%s+%|%s+.+"
local vnstat_index = { rx = 1, tx = 3, total = 5 }

local function vnstat_format(value, unit)
	if not value or not unit then
		return 0
	end
	local v = value:gsub(",", ".")
	return unit == "B" and tonumber(v)
		or unit == "KiB" and v * 1024
		or unit == "MiB" and v * 1024 ^ 2
		or unit == "GiB" and v * 1024 ^ 3
end

local function vnstat_parse(output, traffic)
	local statistic = { string.match(output, vnstat_pattern) }
	local index = vnstat_index[traffic]
	local x, u = statistic[index], statistic[index + 1]
	local result = vnstat_format(x, u)
	return result
end

function system.vnstat_check(args)
	args = type(args) == "table" and args or {} -- backward capability
	args.options = args.options or "-d"
	args.traffic = args.traffic or "total"

	local command = string.format("vnstat %s | tail -n 3 | head -n 1", args.options)
	return function(setup)
		awful.spawn.easy_async_with_shell(command, function(output)
			local result = vnstat_parse(output, args.traffic)
			setup({ result })
		end)
	end
end

-- Get network speed
function system.net_speed(interface, storage)
	local up, down = 0, 0

	-- Get network info
	for line in io.lines("/proc/net/dev") do
		-- Match wmaster0 as well as rt0 (multiple leading spaces)
		local name = string.match(line, "^[%s]?[%s]?[%s]?[%s]?([%w]+):")

		-- Calculate speed for given interface
		if name == interface then
			-- received bytes, first value after the name
			local recv = tonumber(string.match(line, ":[%s]*([%d]+)"))
			-- transmited bytes, 7 fields from end of the line
			local send = tonumber(string.match(line, "([%d]+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d$"))

			local now = os.time()

			if not storage[interface] then
				-- default values on the first run
				storage[interface] = { recv = 0, send = 0 }
			else
				-- net stats are absolute, substract our last reading
				local interval = now - storage[interface].time
				if interval <= 0 then
					interval = 1
				end

				down = (recv - storage[interface].recv) / interval
				up = (send - storage[interface].send) / interval
			end

			-- store totals
			storage[interface].time = now
			storage[interface].recv = recv
			storage[interface].send = send
		end
	end

	return { up, down }
end

-- Get disk speed
function system.disk_speed(disk, storage)
	local up, down = 0, 0

	-- Get i/o info
	for line in io.lines("/proc/diskstats") do
		-- parse info
		-- linux kernel documentation: Documentation/iostats.txt
		local device, read, write = string.match(line, "([^%s]+) %d+ %d+ (%d+) %d+ %d+ %d+ (%d+)")

		-- Calculate i/o for given device
		if device == disk then
			local now = os.time()
			local stats = { read, write }

			if not storage[disk] then
				-- default values on the first run
				storage[disk] = { stats = stats }
			else
				-- check for overflows and counter resets (> 2^32)
				if stats[1] < storage[disk].stats[1] or stats[2] < storage[disk].stats[2] then
					storage[disk].stats[1], storage[disk].stats[2] = stats[1], stats[2]
				end

				-- diskstats are absolute, substract our last reading
				-- * divide by timediff because we don't know the timer value
				local interval = now - storage[disk].time
				if interval <= 0 then
					interval = 1
				end

				up = (stats[1] - storage[disk].stats[1]) / interval
				down = (stats[2] - storage[disk].stats[2]) / interval
			end

			-- store totals
			storage[disk].time = now
			storage[disk].stats = stats
		end
	end

	return { up, down }
end

-- Get MEM info
function system.memory_info()
	local mem = { buf = {}, swp = {} }

	-- Get MEM info
	for line in io.lines("/proc/meminfo") do
		for k, v in string.gmatch(line, "([%a]+):[%s]+([%d]+).+") do
			if k == "MemTotal" then
				mem.total = math.floor(v / 1024)
			elseif k == "MemFree" then
				mem.buf.f = math.floor(v / 1024)
			elseif k == "Buffers" then
				mem.buf.b = math.floor(v / 1024)
			elseif k == "Cached" then
				mem.buf.c = math.floor(v / 1024)
			elseif k == "SwapTotal" then
				mem.swp.t = math.floor(v / 1024)
			elseif k == "SwapFree" then
				mem.swp.f = math.floor(v / 1024)
			end
		end
	end

	-- Calculate memory percentage
	mem.free = mem.buf.f + mem.buf.b + mem.buf.c
	mem.inuse = mem.total - mem.free
	mem.bcuse = mem.total - mem.buf.f
	mem.usep = math.floor(mem.inuse / mem.total * 100)

	-- calculate swap percentage
	mem.swp.inuse = mem.swp.t - mem.swp.f
	mem.swp.usep = mem.swp.t > 0 and math.floor(mem.swp.inuse / mem.swp.t * 100) or 0

	return mem
end

-- Get swap usage info
function system.swap_usage()
	local swap_info = { used = 0, total = 0 }

	-- Get Swap info from /proc/meminfo
	for line in io.lines("/proc/meminfo") do
		for k, v in string.gmatch(line, "([%a]+):[%s]+([%d]+).+") do
			if k == "SwapTotal" then
				swap_info.total = math.floor(v / 1024)
			elseif k == "SwapFree" then
				swap_info.free = math.floor(v / 1024)
			end
		end
	end

	-- Calculate used swap
	swap_info.used = swap_info.total - swap_info.free

	return swap_info
end

-- Get gpu usage info
function system.gpu_usage()
	local gpu_info = { usage = 0 }

	-- Get GPU usage using nvidia-smi (NVIDIA GPUs only)
	local command = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"
	local handle = io.popen(command)
	local output = handle:read("*a")
	handle:close()

	-- Parse the output to get GPU usage
	local gpu_usage = tonumber(output)
	if gpu_usage then
		gpu_info.usage = gpu_usage
	end

	return gpu_info
end

-- Get vram usage info
function system.vram_usage()
	local vram_info = { used = 0, total = 0 }

	-- Get used and total vram usage using nvidia-smi (NVIDIA GPUs only)
	local used_command = "nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits"
	local total_command = "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits"

	local used_handle = io.popen(used_command)
	local used_output = used_handle:read("*a")
	used_handle:close()

	local total_handle = io.popen(total_command)
	local total_output = total_handle:read("*a")
	total_handle:close()

	-- Parse the outputs to get VRAM usage and total
	local used = tonumber(used_output)
	local total = tonumber(total_output)

	if used and total then
		vram_info.used = used
		vram_info.total = total
	end

	return vram_info
end

-- Get cpu usage info
--local storage = { cpu_total = {}, cpu_active = {} } -- storage structure

function system.cpu_usage(storage)
	local cpu_lines = {}
	local cpu_usage = {}
	local diff_time_total

	-- Get CPU stats
	for line in io.lines("/proc/stat") do
		if string.sub(line, 1, 3) == "cpu" then
			local digits_in_line = {}

			for i in string.gmatch(line, "[%s]+([^%s]+)") do
				table.insert(digits_in_line, i)
			end

			table.insert(cpu_lines, digits_in_line)
		end
	end

	-- Calculate usage
	for i, line in ipairs(cpu_lines) do
		-- calculate totals
		local total_new = 0
		for _, value in ipairs(line) do
			total_new = total_new + value
		end

		local active_new = total_new - (line[4] + line[5])

		-- calculate percentage
		local diff_total = total_new - (storage.cpu_total[i] or 0)
		local diff_active = active_new - (storage.cpu_active[i] or 0)

		if i == 1 then
			diff_time_total = diff_total
		end
		if diff_total == 0 then
			diff_total = 1E-6
		end

		cpu_usage[i] = math.floor((diff_active / diff_total) * 100)

		-- store totals
		storage.cpu_total[i] = total_new
		storage.cpu_active[i] = active_new
	end

	-- Format output special for flex widgets and other system functions
	local total_usage = cpu_usage[1]
	local core_usage = awful.util.table.clone(cpu_usage)
	table.remove(core_usage, 1)

	return { total = total_usage, core = core_usage, diff = diff_time_total }
end

-- Temperature measure
-- Using lm-sensors
system.lmsensors = { storage = {}, patterns = {}, delay = 1, time = 0 }

function system.lmsensors:update(output)
	for name, pat in pairs(self.patterns) do
		local value = string.match(output, pat.match)
		if value and pat.posthook then
			value = pat.posthook(value)
		end
		value = tonumber(value)
		self.storage[name] = value and { value } or { 0 }
	end
	self.time = os.time()
end

function system.lmsensors:start(timeout)
	if self.timer then
		return
	end

	self.timer = timer({ timeout = timeout })
	self.timer:connect_signal("timeout", function()
		awful.spawn.easy_async("sensors", function(output)
			system.lmsensors:update(output)
		end)
	end)

	self.timer:start()
	self.timer:emit_signal("timeout")
end

function system.lmsensors:soft_start(timeout, shift)
	if self.timer then
		return
	end

	timer({
		timeout = timeout - (shift or 1),
		autostart = true,
		single_shot = true,
		callback = function()
			self:start(timeout)
		end,
	})
end

function system.lmsensors.get(name)
	if os.time() - system.lmsensors.time > system.lmsensors.delay then
		local output = modutil.read.output("sensors")
		system.lmsensors:update(output)
	end
	return system.lmsensors.storage[name] or { 0 }
end

-- Legacy
--function system.thermal.sensors(args)
--	local args = args or "'Physical id 0'"
--	local output = modutil.read.output("sensors | grep " .. args)
--
--	local temp = string.match(output, "%+(%d+%.%d)°[CF]")
--
--	return temp and { math.floor(tonumber(temp)) } or { 0 }
--end
--
--local sensors_store
--
--function system.thermal.sensors_core(args)
--	args = args or {}
--	local index = args.index or 0
--
--	if args.main then sensors_store = modutil.read.output("sensors | grep Core") end
--	local line = string.match(sensors_store, "Core " .. index .."(.-)\r?\n")
--
--	if not line then return { 0 } end
--
--	local temp = string.match(line, "%+(%d+%.%d)°[CF]")
--	return temp and { math.floor(tonumber(temp)) } or { 0 }
--end

-- Using hddtemp
function system.thermal.hddtemp(args)
	args = args or {}
	local port = args.port or "7634"
	local disk = args.disk or "/dev/sdb"

	local output = modutil.read.output("echo | curl --connect-timeout 1 -fsm 3 telnet://127.0.0.1:" .. port)

	for mnt, _, temp, _ in output:gmatch("|(.-)|(.-)|(.-)|(.-)|") do
		if mnt == disk then
			return temp and { tonumber(temp) }
		end
	end

	return { 0 }
end

-- Using nvidia-settings on sysmem with optimus (bumblebee)
-- Async
function system.thermal.nvoptimus(setup)
	local nvidia_on = string.find(modutil.read.output("cat /proc/acpi/bbswitch"), "ON")
	if not nvidia_on then
		setup({ 0, off = true })
	else
		awful.spawn.easy_async_with_shell(
			"optirun -b none nvidia-settings -c :8 -q gpucoretemp -t | tail -1",
			function(output)
				local value = tonumber(string.match(output, "[^\n]+"))
				setup({ value or 0, off = false })
			end
		)
	end
end

-- Direct call of nvidia-smi
function system.thermal.nvsmi()
	local temp =
		string.match(modutil.read.output("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader"), "%d%d")
	-- checks that local temp is not null then returns the convert string to number or if fails returns null
	return temp and { tonumber(temp) } or { 0 }
end

-- Using nvidia-smi on sysmem with optimus (nvidia-prime)
function system.thermal.nvprime()
	local temp = 0
	local nvidia_on = string.find(modutil.read.output("prime-select query"), "nvidia")

	if nvidia_on ~= nil then
		-- reuse function nvsmi
		temp = system.thermal.nvsmi()[1]
	end

	return { temp, off = nvidia_on == nil }
end

-- Get processes list and cpu and memory usage for every process
-- TODO: Broken function, need to be fixed or removed
local proc_storage = {}

function system.proc_info(cpu_storage)
	local process = {}
	local mem_page_size = 4

	local function get_process_list()
		local pids = {}
		local proc_dir = "/proc/"
		for pid in io.popen("ls -1 " .. proc_dir):lines() do
			if tonumber(pid) then
				table.insert(pids, tonumber(pid))
			end
		end
		return pids
	end

	local pids = get_process_list()

	local cpu_diff = system.cpu_usage(cpu_storage).diff

	for _, pid in ipairs(pids) do
		-- try to get info from /proc
		local stat = modutil.read.file("/proc/" .. pid .. "/stat")
		local statm = modutil.read.file("/proc/" .. pid .. "/statm")

		if stat and statm then
			-- get process name
			local name = string.match(stat, ".+%((.+)%).+")
			local proc_stat = { name }

			stat = stat:gsub("%s%(.+%)", "", 1)

			-- the rest of 'stat' data can be splitted by whitespaces
			-- first chunk is pid so just skip it
			for m in string.gmatch(stat, "[%s]+([^%s]+)") do
				table.insert(proc_stat, m)
			end

			-- get memory usage from statm file
			local statm_values = {}
			for value in string.gmatch(statm, "%S+") do
				table.insert(statm_values, tonumber(value))
			end

			local mem = (statm_values[2] - statm_values[3]) * mem_page_size

			-- calculate cpu usage for process
			local proc_time = proc_stat[13] + proc_stat[14]
			local pcpu = (proc_time - (proc_storage[pid] or 0)) / cpu_diff

			-- save current cpu time for future
			proc_storage[pid] = proc_time

			-- save results
			table.insert(process, { pid = pid, name = name, mem = mem, pcpu = pcpu })
		end
	end

	return process
end

-- Output format functions
-- CPU and memory usage formatted special for desktop widget
function system.dformatted.cpumem(storage)
	local mem = system.memory_info()
	local cores = {}
	for i, v in ipairs(system.cpu_usage(storage).core) do
		table.insert(cores, { value = v, text = string.format("CORE%d %s%%", i - 1, v) })
	end

	return {
		bars = cores,
		lines = { { mem.usep, mem.inuse }, { mem.swp.usep, mem.swp.inuse } },
	}
end

-- GPU usage formatted special for panel widget
function system.pformatted.gpu(crit)
	crit = crit or 75

	return function()
		local gpu_usage = system.gpu_usage().usage
		return {
			value = gpu_usage / 100,
			text = "GPU: " .. gpu_usage .. "%",
			alert = gpu_usage > crit,
		}
	end
end

-- VRAM usage formatted special for panel widget
function system.pformatted.vram(crit)
	crit = crit or 85

	return function()
		local vram_info = system.vram_usage()
		local vram_usage = math.floor(vram_info.used / vram_info.total * 100)
		return {
			value = vram_usage / 100,
			text = "VRAM: " .. vram_usage .. "%",
			alert = vram_usage > crit,
		}
	end
end

-- CPU usage formatted special for panel widget
function system.pformatted.cpu(crit)
	crit = crit or 75
	local storage = { cpu_total = {}, cpu_active = {} }

	return function()
		local usage = system.cpu_usage(storage).total
		return {
			value = usage / 100,
			text = "CPU: " .. usage .. "%",
			alert = usage > crit,
		}
	end
end

-- Memory usage formatted special for panel widget
function system.pformatted.mem(crit)
	crit = crit or 75

	return function()
		local usage = system.memory_info().usep
		return {
			value = usage / 100,
			text = "RAM: " .. usage .. "%",
			alert = usage > crit,
		}
	end
end

-- SWAP usage formatted special for panel widget
function system.pformatted.swap(crit)
	crit = crit or 50

	return function()
		local swap_info = system.swap_usage()
		local swap_usage = math.floor(swap_info.used / swap_info.total * 100)
		return {
			value = swap_usage / 100,
			text = "SWAP: " .. swap_usage .. "%",
			alert = swap_usage > crit,
		}
	end
end

return system
