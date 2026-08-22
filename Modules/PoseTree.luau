--!optimize 2
--!strict
--!native

const global = shared or _G
local ccontainer = rawget(global, "Azurion")
if not ccontainer then
	repeat
		ccontainer = rawget(global, "Azurion")
		wait()
	until ccontainer
end

local waitForModule = rawget(rawget(ccontainer, "functions"), "waitForModule")
const Tree = waitForModule("Tree")

local table_insert = table.insert

export type PoseNode = {
	Path: string,
	Type: "Root" | "Category" | "Object" | "Property",
	Value: any,
	Parent: PoseNode?,
}

export type RigConfig = {
	Name: string,
	Categories: {
		{
			Name: string,
			Type: "Bones" | "Motors" | "Constraints" | "Properties",
			Selector: ((rig: Instance) -> {Instance})?, -- Custom selector function
			PropertyNames: {string}?, -- Properties to track per bone
		}
	}
}

local PoseTree = {}
PoseTree.__index = PoseTree

function PoseTree.new(rigOrName: Instance | string, config: RigConfig?): PoseTree
	local self = setmetatable({}, PoseTree)
	
	local animationName = if typeof(rigOrName) == "Instance" then rigOrName.Name else rigOrName
	
	self._tree = Tree.new({
		Path = animationName,
		Type = "Root",
		Value = nil
	}, {
		GetParent = function(node)
			return node.Parent
		end,
		GetKey = function(node)
			return node.Path
		end,
	})
	
	self._nodesByPath = {}
	self._nodesByPath[animationName] = self._tree.RootNode
	self._config = config
	self._rig = if typeof(rigOrName) == "Instance" then rigOrName else nil
	
	if self._rig and config then
		self:_GenerateFromRig(self._rig, config)
	end
	
	return self
end

function PoseTree:_GenerateFromRig(rig: Instance, config: RigConfig)
	local rootPath = self._tree.RootNode.Value.Path
	
	for _, category in config.Categories do
		self:AddCategory(category.Name, rootPath)
		local categoryPath = `{rootPath}/{category.Name}`
		
		local objects = self:_GetObjectsForCategory(rig, category)
		
		for _, object in objects do
			local objectName = object.Name
			self:AddObject(objectName, categoryPath)
			local objectPath = `{categoryPath}/{objectName}`
			
			local propertyNames = category.PropertyNames
			
			if not propertyNames then
				if object:IsA("JointInstance") then
					propertyNames = object:IsA("Motor6D") and {"Transform"} or {"C0", "C1"}
				elseif object:IsA("BasePart") then
					propertyNames = {"CFrame", "Size", "Color", "Transparency", "Reflectance"}
				else
					propertyNames = {}
				end
			end
			
			for _, propName in propertyNames do
				local value = self:_GetDefaultValue(object, propName)
				self:AddProperty(propName, objectPath, value)
			end
		end
	end
end

function PoseTree:_GetObjectsForCategory(rig: Instance, category)
	if category.Selector then
		return category.Selector(rig)
	end
	
	if category.Type == "Bones" then
		return rig:QueryDescendants("Bone")
	elseif category.Type == "Motors" then
		return rig:QueryDescendants("Motor6D")
	elseif category.Type == "Constraints" then
		return rig:QueryDescendants("AnimationConstraint")
	end
	
	return {}
end

function PoseTree:_GetDefaultValue(object: Instance, propertyName: string)
	if object:IsA("JointInstance") then
		if propertyName == "C0" then
			return object.C0
		elseif propertyName == "Transform" then
			return CFrame.identity
		end
	elseif object:IsA("BasePart") then
		if propertyName == "CFrame" then
			return object.CFrame
		elseif propertyName == "Size" then
			return object.Size
		elseif propertyName == "Color" then
			return object.Color
		elseif propertyName == "Transparency" then
			return object.Transparency
		elseif propertyName == "Reflectance" then
			return object.Reflectance
		end
	end
end

function PoseTree:AddCategory(categoryName: string, parentPath: string)
	local parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	local fullPath = `{parentPath}/{categoryName}`
	
	if self._nodesByPath[fullPath] then
		return self._nodesByPath[fullPath]
	end
	
	local categoryValue = {
		Path = fullPath,
		Type = "Category",
		Value = nil,
		Parent = parentNode.Value
	}
	
	local node = self._tree:CreateNode(categoryValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:AddObject(objectName: string, parentPath: string)
	local parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	local fullPath = `{parentPath}/{objectName}`
	
	if self._nodesByPath[fullPath] then
		return self._nodesByPath[fullPath]
	end
	
	local objectValue = {
		Path = fullPath,
		Type = "Object",
		Value = nil,
		Parent = parentNode.Value
	}
	
	local node = self._tree:CreateNode(objectValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:AddProperty(propertyName: string, parentPath: string, defaultValue: any)
	local parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	local fullPath = `{parentPath}/{propertyName}`
	
	if self._nodesByPath[fullPath] then
		return self._nodesByPath[fullPath]
	end
	
	local propertyValue = {
		Path = fullPath,
		Type = "Property",
		Value = defaultValue,
		Parent = parentNode.Value
	}
	
	local node = self._tree:CreateNode(propertyValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:GetNodeByPath(path: string)
	return self._nodesByPath[path]
end

function PoseTree:SetPropertyValue(path: string, value: any)
	local node = self._nodesByPath[path]
	if node and node.Value.Type == "Property" then
		node.Value.Value = value
	end
end

function PoseTree:GetPropertyValue(path: string)
	local node = self._nodesByPath[path]
	if node and node.Value.Type == "Property" then
		return node.Value.Value
	end
	return nil
end

function PoseTree:GetObjectProperties(objectPath: string): {PoseNode}
	local objectNode = self._nodesByPath[objectPath]
	if not objectNode then return {} end
	
	local properties = {}
	for _, childNode in objectNode.Children do
		if childNode.Value.Type == "Property" then
			table_insert(properties, childNode.Value)
		end
	end
	
	return properties
end

function PoseTree:GetAllProperties(): {PoseNode}
	local allNodes = self._tree:FlattenAll()
	local properties = {}
	
	for _, node in allNodes do
		if node.Value.Type == "Property" then
			table_insert(properties, node.Value)
		end
	end
	
	return properties
end

function PoseTree:GetTree()
	return self._tree
end

function PoseTree:Flatten()
	return self._tree:Flatten()
end

return PoseTree
