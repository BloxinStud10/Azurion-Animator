--!optimize 2
--!strict

local table_create = table.create
local table_move = table.move
local table_sort = table.sort
local table_clear = table.clear

--// Types

export type Node<T> = {
	Value: T,
	Parent: Node<T>?,
	Children: { Node<T> },
	Depth: number,
	Index: number,
	Expanded: boolean,
}

export type Config<T> = {
	RootChildCapacity: number?, -- 8
	NodeChildCapacity: number?, -- 4
	VisibleCapacity: number?, -- 256
	FlattenStackCapacity: number?, -- 128
	RemoveStackCapacity: number?, -- 16

	RootExpanded: boolean?, -- true
	NodesExpanded: boolean?, -- false

	GetParent: ((value: T) -> T?)?,

	GetKey: ((value: T) -> any)?,

	OnNodeCreated: ((node: Node<T>) -> ())?,
	OnNodeRemoving: ((node: Node<T>) -> ())?,
	OnToggled: ((node: Node<T>, expanded: boolean) -> ())?,

	FlattenFilter: ((node: Node<T>) -> boolean)?,
	ChildSorter: ((a: Node<T>, b: Node<T>) -> boolean)?,
}

--// Defaults

local DEFAULTS = {
	RootChildCapacity = 8,
	NodeChildCapacity = 4,
	VisibleCapacity = 256,
	FlattenStackCapacity = 128,
	RemoveStackCapacity = 16,
	RootExpanded = true,
	NodesExpanded = false,
}

local function resolveConfig<T>(cfg: Config<T>?): Config<T>
	if not cfg then
		return DEFAULTS :: any
	end
	return {
		RootChildCapacity = cfg.RootChildCapacity or DEFAULTS.RootChildCapacity,
		NodeChildCapacity = cfg.NodeChildCapacity or DEFAULTS.NodeChildCapacity,
		VisibleCapacity = cfg.VisibleCapacity or DEFAULTS.VisibleCapacity,
		FlattenStackCapacity = cfg.FlattenStackCapacity or DEFAULTS.FlattenStackCapacity,
		RemoveStackCapacity = cfg.RemoveStackCapacity or DEFAULTS.RemoveStackCapacity,
		RootExpanded = if cfg.RootExpanded ~= nil then cfg.RootExpanded else DEFAULTS.RootExpanded,
		NodesExpanded = if cfg.NodesExpanded ~= nil then cfg.NodesExpanded else DEFAULTS.NodesExpanded,
		GetParent = cfg.GetParent,
		GetKey = cfg.GetKey,
		OnNodeCreated = cfg.OnNodeCreated,
		OnNodeRemoving = cfg.OnNodeRemoving,
		OnToggled = cfg.OnToggled,
		FlattenFilter = cfg.FlattenFilter,
		ChildSorter = cfg.ChildSorter
	}
end

--// Helpers

local function defaultKey<T>(value: T): any
	return value
end

local function instanceParent(value: any): any?
	local ok, parent = pcall(function() return value.Parent end)
	return if ok then parent else nil
end

--// Tree

local Tree = {}
Tree.__index = Tree

function Tree.new<T>(root: T, cfg: Config<T>?)
	local self = setmetatable({}, Tree)

	local config = resolveConfig(cfg)
	self._cfg = config

	-- Decide key + parent strategies
	local getKey = config.GetKey or defaultKey
	local getParent = config.GetParent or instanceParent

	self._getKey = getKey
	self._getParent = getParent

	local rootNode: Node<T> = {
		Value = root,
		Parent = nil,
		Children = table_create(config.RootChildCapacity),
		Depth = 0,
		Index = 1,
		Expanded = config.RootExpanded :: boolean,
	}

	self.RootNode = rootNode
	self.Nodes = { [getKey(root)] = rootNode } :: { [any]: Node<T> }
	self.Visible = table_create(config.VisibleCapacity)
	self.NodeCount = 1

	if config.OnNodeCreated then
		config.OnNodeCreated(rootNode)
	end

	return self
end

--// Lookup

function Tree:GetNode<T>(value: T): Node<T>?
	return self.Nodes[self._getKey(value)]
end

--// Mutation

function Tree:CreateNode<T>(value: T): Node<T>?
	local cfg = self._cfg
	local getKey = self._getKey
	local getParent = self._getParent

	local key = getKey(value)

	-- Don't double-register
	if self.Nodes[key] then
		return self.Nodes[key]
	end

	local parentValue = getParent(value)
	if parentValue == nil then
		return
	end

	local parentNode: Node<T>? = self.Nodes[getKey(parentValue)]
	if not parentNode then
		return
	end

	local children = parentNode.Children
	local index = #children + 1

	local node: Node<T> = {
		Value = value,
		Parent = parentNode,
		Children = table_create(cfg.NodeChildCapacity),
		Depth = parentNode.Depth + 1,
		Index = index,
		Expanded = cfg.NodesExpanded :: boolean,
	}

	children[index] = node
	self.Nodes[key] = node
	self.NodeCount += 1

	if cfg.OnNodeCreated then
		cfg.OnNodeCreated(node)
	end

	return node
end

function Tree:RemoveNode<T>(value: T)
	local getKey = self._getKey
	local key = getKey(value)
	local node = self.Nodes[key]

	if not node then return end

	local parent = node.Parent
	if parent then
		local children = parent.Children
		local idx = node.Index
		local lastIdx = #children

		if idx ~= lastIdx then
			local last = children[lastIdx]
			children[idx] = last
			last.Index = idx
		end

		children[lastIdx] = nil
	end

	local cfg = self._cfg
	local stack = table_create(cfg.RemoveStackCapacity)
	local size = 1
	stack[1] = node

	while size > 0 do
		local current = stack[size]
		stack[size] = nil
		size -= 1

		if cfg.OnNodeRemoving then
			cfg.OnNodeRemoving(current)
		end

		self.Nodes[getKey(current.Value)] = nil
		self.NodeCount -= 1

		for i = 1, #current.Children do
			size += 1
			stack[size] = current.Children[i]
		end
	end
end

function Tree:MoveNode<T>(value: T, newParentValue: T)
	local getKey = self._getKey
	local node = self.Nodes[getKey(value)]
	if not node then return end

	local newParent = self.Nodes[getKey(newParentValue)]
	if not newParent then return end

	local oldParent = node.Parent
	if oldParent then
		local children = oldParent.Children
		local idx = node.Index
		local lastIdx = #children

		if idx ~= lastIdx then
			local last = children[lastIdx]
			children[idx] = last
			last.Index = idx
		end

		children[lastIdx] = nil
	end

	local newChildren = newParent.Children
	local newIndex = #newChildren + 1
	newChildren[newIndex] = node
	node.Parent = newParent
	node.Index = newIndex

	local stack = table_create(16)
	local size = 1
	stack[1] = node

	while size > 0 do
		local current = stack[size]
		stack[size] = nil
		size -= 1

		current.Depth = current.Parent and (current.Parent.Depth + 1) or 0

		for i = 1, #current.Children do
			size += 1
			stack[size] = current.Children[i]
		end
	end
end

--// Toggle helpers

function Tree:Toggle<T>(node: Node<T>)
	local expanded = not node.Expanded
	node.Expanded = expanded
	local cfg = self._cfg
	if cfg.OnToggled then cfg.OnToggled(node, expanded) end
end

function Tree:Expand<T>(node: Node<T>)
	if node.Expanded then return end
	node.Expanded = true
	local cfg = self._cfg
	if cfg.OnToggled then cfg.OnToggled(node, true) end
end

function Tree:Collapse<T>(node: Node<T>)
	if not node.Expanded then return end
	node.Expanded = false
	local cfg = self._cfg
	if cfg.OnToggled then cfg.OnToggled(node, false) end
end

function Tree:RevealNode<T>(node: Node<T>)
	local cursor = node.Parent
	while cursor do
		cursor.Expanded = true
		cursor = cursor.Parent
	end
end

--// Flatten

function Tree:Flatten<T>(): { Node<T> }
	local cfg = self._cfg
	local filter = cfg.FlattenFilter
	local sorter = cfg.ChildSorter
	local visible = self.Visible

	table_clear(visible)

	local stack = table_create(cfg.FlattenStackCapacity)
	local size = 1
	stack[1] = self.RootNode

	local count = 0

	while size > 0 do
		local node = stack[size]
		stack[size] = nil
		size -= 1

		if filter and not filter(node) then
			continue
		end

		count += 1
		visible[count] = node

		if node.Expanded then
			local children = node.Children
			local n = #children

			if sorter then
				local sorted = table_move(children, 1, n, 1, table_create(n))
				table_sort(sorted, sorter)
				for i = n, 1, -1 do
					size += 1
					stack[size] = sorted[i]
				end
			else
				for i = n, 1, -1 do
					size += 1
					stack[size] = children[i]
				end
			end
		end
	end

	return visible
end

return Tree
