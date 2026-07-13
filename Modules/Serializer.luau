--!optimize 2
--!native

local setmetatable = setmetatable
local tostring = tostring
local Enum = Enum

local string_match = string.match
local table_unpack = table.unpack
local vector_create = vector.create
local CFrame_new = CFrame.new
local Color3_new = Color3.new

local buffer_create = buffer.create
local buffer_copy = buffer.copy
local buffer_len = buffer.len
local buffer_writeu8 = buffer.writeu8
local buffer_writeu32 = buffer.writeu32
local buffer_writef64 = buffer.writef64
local buffer_writestring = buffer.writestring
local buffer_readu8 = buffer.readu8
local buffer_readu32 = buffer.readu32
local buffer_readf64 = buffer.readf64
local buffer_readstring = buffer.readstring

local TYPE_NIL = 0
local TYPE_FALSE = 1
local TYPE_TRUE = 2
local TYPE_NUMBER = 3
local TYPE_STRING = 4
local TYPE_TABLE = 5
local TYPE_VECTOR3 = 6
local TYPE_CFRAME = 7
local TYPE_ENUMITEM = 8
local TYPE_COLOR3 = 9

--// Writer
local Writer = {}
Writer.__index = Writer

local NewWriter = function(initialSize)
	return setmetatable({
		buf = buffer_create(initialSize or 256),
		pos = 0
	}, Writer)
end

function Writer:EnsureCapacity(extra)
	local needed = self.pos + extra
	local capacity = buffer_len(self.buf)
	
	if needed > capacity then
		local newCapacity = capacity * 2
		while newCapacity < needed do
			newCapacity = newCapacity * 2
		end
		
		local newBuf = buffer_create(newCapacity)
		buffer_copy(newBuf, 0, self.buf, 0, self.pos)
		self.buf = newBuf
	end
end

function Writer:WriteU8(value)
	self:EnsureCapacity(1)
	buffer_writeu8(self.buf, self.pos, value)
	self.pos += 1
end

function Writer:WriteU32(value)
	self:EnsureCapacity(4)
	buffer_writeu32(self.buf, self.pos, value)
	self.pos += 4
end

function Writer:WriteF64(value)
	self:EnsureCapacity(8)
	buffer_writef64(self.buf, self.pos, value)
	self.pos += 8
end

function Writer:WriteString(str)
	local len = #str
	self:WriteU32(len)
	self:EnsureCapacity(len)
	buffer_writestring(self.buf, self.pos, str)
	self.pos += len
end

function Writer:Finalize()
	local final = buffer_create(self.pos)
	buffer_copy(final, 0, self.buf, 0, self.pos)
	return final
end

--// Reader

local Reader = {}
Reader.__index = Reader

local NewReader = function(buf)
	return setmetatable({
		buf = buf,
		pos = 0
	}, Reader)
end

function Reader:ReadU8()
	local value = buffer_readu8(self.buf, self.pos)
	self.pos += 1
	return value
end

function Reader:ReadU32()
	local value = buffer_readu32(self.buf, self.pos)
	self.pos += 4
	return value
end

function Reader:ReadF64()
	local value = buffer_readf64(self.buf, self.pos)
	self.pos += 8
	return value
end

function Reader:ReadString()
	local len = self:ReadU32()
	local str = buffer_readstring(self.buf, self.pos, len)
	self.pos += len
	return str
end

--// Serialize

local SerializeValue

local SerializeTable = function(W, tbl)
	local count = 0
	for _ in next, tbl do
		count += 1
	end
	W:WriteU32(count)
	
	for key, value in next, tbl do
		SerializeValue(W, key)
		SerializeValue(W, value)
	end
end

SerializeValue = function(W, value)
	local t = typeof(value)
	
	if value == nil then
		W:WriteU8(TYPE_NIL)
	elseif t == "boolean" then
		W:WriteU8(value and TYPE_TRUE or TYPE_FALSE)
	elseif t == "number" then
		W:WriteU8(TYPE_NUMBER)
		W:WriteF64(value)
	elseif t == "string" then
		W:WriteU8(TYPE_STRING)
		W:WriteString(value)
	elseif t == "Vector3" then
		W:WriteU8(TYPE_VECTOR3)
		W:WriteF64(value.X)
		W:WriteF64(value.Y)
		W:WriteF64(value.Z)
	elseif t == "CFrame" then
		W:WriteU8(TYPE_CFRAME)
		local components = {value:GetComponents()}
		for i = 1, 12 do
			W:WriteF64(components[i])
		end
	elseif t == "EnumItem" then
		W:WriteU8(TYPE_ENUMITEM)
		local value = tostring(value)
		local EnumType, EnumItem = string_match(value, "^Enum%.([^.]+)%.(.+)$")
		W:WriteString(EnumType)
		W:WriteString(EnumItem)
	elseif t == "Color3" then
		W:WriteU8(TYPE_COLOR3)
		W:WriteF64(value.R)
		W:WriteF64(value.G)
		W:WriteF64(value.B)
	elseif t == "table" then
		W:WriteU8(TYPE_TABLE)
		SerializeTable(W, value)
	else
		error("DataBuffer: unsupported type for serialization: " .. t)
	end
end

--// Deserialize

local DeserializeValue

local DeserializeTable = function(R)
	local count = R:ReadU32()
	local tbl = {}
	
	for i = 1, count do
		local key = DeserializeValue(R)
		local value = DeserializeValue(R)
		tbl[key] = value
	end
	
	return tbl
end

DeserializeValue = function(R)
	local tag = R:ReadU8()
	
	if tag == TYPE_NIL then
		return nil
	elseif tag == TYPE_FALSE then
		return false
	elseif tag == TYPE_TRUE then
		return true
	elseif tag == TYPE_NUMBER then
		return R:ReadF64()
	elseif tag == TYPE_STRING then
		return R:ReadString()
	elseif tag == TYPE_VECTOR3 then
		local x = R:ReadF64()
		local y = R:ReadF64()
		local z = R:ReadF64()
		return vector_create(x, y, z)
	elseif tag == TYPE_CFRAME then
		local components = {}
		for i = 1, 12 do
			components[i] = R:ReadF64()
		end
		return CFrame_new(table_unpack(components))
	elseif tag == TYPE_ENUMITEM then
		local type = R:ReadString()
		local item = R:ReadString()
		return Enum[type][item]
	elseif tag == TYPE_COLOR3 then
		local r = R:ReadF64()
		local g = R:ReadF64()
		local b = R:ReadF64()
		return Color3_new(r, g, b)
	elseif tag == TYPE_TABLE then
		return DeserializeTable(R)
	else
		error("DataBuffer: unknown type tag encountered: " .. tostring(tag))
	end
end

--// return

return table.freeze({
	Serialize = function(tbl)
		local W = NewWriter(256)
		SerializeValue(W, tbl)
		return W:Finalize()
	end,
	
	Deserialize = function(buf)
		local R = NewReader(buf)
		return DeserializeValue(R)
	end
})
