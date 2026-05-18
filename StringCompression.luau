--!optimize 2
--!native

local EncodingService = game:GetService("EncodingService")
local Algorithm = Enum.CompressionAlgorithm.Zstd

return {
	Compress = function(data: string?, level: number?)
		data = typeof(data) == "string" and buffer.fromstring(data) or data
		local compressed = EncodingService:CompressBuffer(data, Algorithm, level or 1)
		return buffer.tostring(encoded)
	end,
	Decompress = function(data: string?)
		data = typeof(data) == "string" and buffer.fromstring(data) or data
		local decompressed = EncodingService:DecompressBuffer(data, Algorithm)
		return buffer.tostring(decompressed)
	end
}
