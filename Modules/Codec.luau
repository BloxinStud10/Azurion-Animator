--!optimize 2
--!native

const buffer_fromstring = buffer.fromstring
const buffer_tostring = buffer.tostring
const min = math.min

const EncodingService = game:GetService("EncodingService")
const Algorithm = Enum.CompressionAlgorithm.Zstd

local Module = {}
Module.Compress = function(data: string?, level: number?, returnstring: boolean?)
	data = type(data) == "string" and buffer_fromstring(data) or data
	local buf = EncodingService:CompressBuffer(data, Algorithm, min(level or 1, 20))
	return returnstring and buffer_tostring(buf) or buf
end
Module.Decompress = function(data: string?, returnstring: boolean?)
	data = type(data) == "string" and buffer_fromstring(data) or data
	local buf = EncodingService:DecompressBuffer(data, Algorithm)
	return returnstring and buffer_tostring(buf) or buf
end
Module.Decode = function(data: string?, returnstring: boolean?)
	data = type(data) == "string" and buffer_fromstring(data) or data
	local buf = EncodingService:Base64Decode(data)
	return returnstring and buffer_tostring(buf) or buf
end
Module.Encode = function(data: string?, returnstring: boolean?)
	data = type(data) == "string" and buffer_fromstring(data) or data
	local buf = EncodingService:Base64Encode(data)
	return returnstring and buffer_tostring(buf) or buf
end

return table.freeze(Module)