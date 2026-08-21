--!optimize 2
const buffer_len = buffer.len
const buffer_readstring = buffer.readstring
const buffer_readu32 = buffer.readu32
const buffer_readu8 = buffer.readu8

return @native function(buf1, buf2)
	local size = buffer_len(buf1)
	if size ~= buffer_len(buf2) then
		return false
	end
	
	if size < 256 * 1024 then 
		return buffer_readstring(buf1, 0, size) == buffer_readstring(buf2, 0, size)
	end
	
	local i = 0
	while i + 4 <= size do
		if buffer_readu32(buf1, i) ~= buffer_readu32(buf2, i) then
			return false
		end
		i += 4
	end
	
	while i < size do
		if buffer_readu8(buf1, i) ~= buffer_readu8(buf2, i) then
			return false
		end
		i += 1
	end
	
	return true
end
