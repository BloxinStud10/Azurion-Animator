--// Cache //--

local module={}
local cache={}

module.get=function(class:string):Instance
	local classCache=cache[class]
	if not classCache then
		classCache={}
		cache[class]=classCache
	end
	return table.remove(classCache) or Instance.new(class)
end

module.release=function(instance:Instance)
	local class=instance.ClassName
	local classCache=cache[class]
	if not classCache then
		classCache={}
		cache[class]=classCache
	end
	table.insert(classCache,instance)
end

return module
