--!optimize 2

const setmetatable = setmetatable
const tostring = tostring
const Enum = Enum

const string_match = string.match
const table_unpack = table.unpack
const vector_create = vector.create
const CFrame_new = CFrame.new
local Color3_new = Color3.new

const buffer_create = buffer.create
const buffer_copy = buffer.copy
const buffer_len = buffer.len
const buffer_writeu8 = buffer.writeu8
const buffer_writeu32 = buffer.writeu32
const buffer_writef64 = buffer.writef64
const buffer_writestring = buffer.writestring
const buffer_readu8 = buffer.readu8
const buffer_readu32 = buffer.readu32
const buffer_readf64 = buffer.readf64
const buffer_readstring = buffer.readstring

const TYPE_NIL = 0
const TYPE_FALSE = 1
const TYPE_TRUE = 2
const TYPE_NUMBER = 3
const TYPE_STRING = 4
const TYPE_TABLE = 5
const TYPE_VECTOR3 = 6
const TYPE_CFRAME = 7
const TYPE_ENUMITEM = 8
const TYPE_COLOR3 = 9

--// Writer
local Writer = {}
Writer.__index = Writer

const NewWriter = @native function(initialSize)
	return setmetatable({
		buf = buffer_create(initialSize or 256),
		pos = 0
	}, Writer)
end

@native function Writer:EnsureCapacity(extra)
	const needed = self.pos + extra
	const capacity = buffer_len(self.buf)
	
	if needed > capacity then
		local newCapacity = capacity * 2
		while newCapacity < needed do
			newCapacity = newCapacity * 2
		end
		
		const newBuf = buffer_create(newCapacity)
		buffer_copy(newBuf, 0, self.buf, 0, self.pos)
		self.buf = newBuf
	end
end

@native function Writer:WriteU8(value)
	self:EnsureCapacity(1)
	buffer_writeu8(self.buf, self.pos, value)
	self.pos += 1
end

@native function Writer:WriteU32(value)
	self:EnsureCapacity(4)
	buffer_writeu32(self.buf, self.pos, value)
	self.pos += 4
end

@native function Writer:WriteF64(value)
	self:EnsureCapacity(8)
	buffer_writef64(self.buf, self.pos, value)
	self.pos += 8
end

@native function Writer:WriteString(str)
	const len = #str
	self:WriteU32(len)
	self:EnsureCapacity(len)
	buffer_writestring(self.buf, self.pos, str)
	self.pos += len
end

@native function Writer:Finalize()
	const final = buffer_create(self.pos)
	buffer_copy(final, 0, self.buf, 0, self.pos)
	return final
end

--// Reader
local Reader = {}
Reader.__index = Reader

const NewReader = @native function(buf)
	return setmetatable({
		buf = buf,
		pos = 0
	}, Reader)
end

@native function Reader:ReadU8()
	const value = buffer_readu8(self.buf, self.pos)
	self.pos += 1
	return value
end

@native function Reader:ReadU32()
	const value = buffer_readu32(self.buf, self.pos)
	self.pos += 4
	return value
end

@native function Reader:ReadF64()
	const value = buffer_readf64(self.buf, self.pos)
	self.pos += 8
	return value
end

@native function Reader:ReadString()
	const len = self:ReadU32()
	const str = buffer_readstring(self.buf, self.pos, len)
	self.pos += len
	return str
end

--// Serialize
local SerializeValue

const SerializeTable = @native function(W, tbl)
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

SerializeValue = @native function(W, value)
	const t = typeof(value)
	
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
		const components = {value:GetComponents()}
		for i = 1, 12 do
			W:WriteF64(components[i])
		end
	elseif t == "EnumItem" then
		W:WriteU8(TYPE_ENUMITEM)
		const value = tostring(value)
		const EnumType, EnumItem = string_match(value, "^Enum%.([^.]+)%.(.+)$")
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

const DeserializeTable = @native function(R)
	const count = R:ReadU32()
	const tbl = {}
	
	for i = 1, count do
		const key = DeserializeValue(R)
		const value = DeserializeValue(R)
		tbl[key] = value
	end
	
	return tbl
end

DeserializeValue = @native function(R)
	const tag = R:ReadU8()
	
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
		const x = R:ReadF64()
		const y = R:ReadF64()
		const z = R:ReadF64()
		return vector_create(x, y, z)
	elseif tag == TYPE_CFRAME then
		const components = {}
		for i = 1, 12 do
			components[i] = R:ReadF64()
		end
		return CFrame_new(table_unpack(components))
	elseif tag == TYPE_ENUMITEM then
		const type = R:ReadString()
		const item = R:ReadString()
		return Enum[type][item]
	elseif tag == TYPE_COLOR3 then
		const r = R:ReadF64()
		const g = R:ReadF64()
		const b = R:ReadF64()
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