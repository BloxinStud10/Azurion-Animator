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

const table_insert = table.insert

export type PoseNode = {
	Path: string,
	Type: "Root" | "Category" | "Object" | "Property",
	Value: any,
	Parent: PoseNode?,
}

const PoseTree = {}
PoseTree.__index = PoseTree

function PoseTree.new(animationName: string): PoseTree
	const self = setmetatable({}, PoseTree)
	
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
	
	return self
end

function PoseTree:AddCategory(categoryName: string, parentPath: string)
	const parentPath = parentPath or self._tree.RootNode.Value.Path
	const parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	const fullPath = `{parentPath}/{categoryName}`
	
	const categoryValue = {
		Path = fullPath,
		Type = "Category",
		Value = nil,
		Parent = parentNode.Value
	}
	
	const node = self._tree:CreateNode(categoryValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:AddObject(objectName: string, parentPath: string)
	const parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	const fullPath = `{parentPath}/{objectName}`
	
	const objectValue = {
		Path = fullPath,
		Type = "Object",
		Value = nil,
		Parent = parentNode.Value
	}
	
	const node = self._tree:CreateNode(objectValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:AddProperty(propertyName: string, parentPath: string, defaultValue: any)
	const parentNode = self._nodesByPath[parentPath]
	
	if not parentNode then
		return warn(`Parent path "{parentPath}" not found`)
	end
	
	const fullPath = `{parentPath}/{propertyName}`
	
	const propertyValue = {
		Path = fullPath,
		Type = "Property",
		Value = defaultValue,
		Parent = parentNode.Value
	}
	
	const node = self._tree:CreateNode(propertyValue)
	if node then
		self._nodesByPath[fullPath] = node
	end
	
	return node
end

function PoseTree:GetNodeByPath(path: string)
	return self._nodesByPath[path]
end

function PoseTree:SetPropertyValue(path: string, value: any)
	const node = self._nodesByPath[path]
	if node and node.Value.Type == "Property" then
		node.Value.Value = value
	end
end

function PoseTree:GetObjectProperties(objectPath: string): {PoseNode}
	const objectNode = self._nodesByPath[objectPath]
	if not objectNode then return {} end
	
	const properties = {}
	for _, childNode in next, objectNode.Children do
		if childNode.Value.Type == "Property" then
			table_insert(properties, childNode.Value)
		end
	end
	
	return properties
end

function PoseTree:GetAllProperties(): {PoseNode}
	const allNodes = self._tree:FlattenAll()
	const properties = {}
	
	for _, node in next, allNodes do
		if node.Value.Type == "Property" then
			table_insert(properties, node.Value)
		end
	end
	
	return properties
end

return PoseTree
