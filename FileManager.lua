--[[

	Module that handles operations on file system.
	Has additional functions for encoding and decoding strings

]]--
local fileManager = {};

--------------------------------------------------------------------------------
--	Properties
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Methods declarations
--------------------------------------------------------------------------------
local encode, decode, writeString, readString, writeBytes, readBytes;

function fileManager:encode(string)
	return encode(string);
end

function fileManager:decode(string)
	return decode(string);
end

function fileManager:writeString(fileName, filePath, string)
	writeString(fileName, filePath, string);
end

function fileManager:readString(fileName, filePath)
	return readString(fileName, filePath);
end

function fileManager:writeBytes(fileName, filePath, bytes)
	writeBytes(fileName, filePath, bytes);
end

function fileManager:readBytes(fileName, filePath)
	return readBytes(fileName, filePath);
end

--------------------------------------------------------------------------------
--	Methods initializations
--------------------------------------------------------------------------------

-- character table string for crypting
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

encode = function(data)
	return ((data:gsub('.', function(x)
	    local r,b='',x:byte()
	    for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
	    return r;
	  end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
	    if (#x < 6) then return '' end
	    local c=0
	    for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
	    return b:sub(c+1,c+1)
	  end)..({ '', '==', '=' })[#data%3+1])
end

decode = function(data)
	data = string.gsub(data, '[^'..b..'=]', '');
	return (data:gsub('.', function(x)
    	if (x == '=') then return '' end
    	local r,f='',(b:find(x)-1)
    	for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
    	return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    	if (#x ~= 8) then return '' end
    	local c=0
    	for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end

writeString = function(fileName, filePath, string)
	local path = system.pathForFile(fileName, filePath);

	local file, errorString = io.open(path, "w");

	if file then
		-- write and close file
	    file:write(string);
	    io.close(file);
	else
	    -- handle error
		print( "Error: " .. errorString );
	end

	file = nil;
end

readString = function(fileName, filePath)
	local outputString;
	local path = system.pathForFile(fileName, filePath);

	local file, errorString = io.open(path, "r");

	if file then
		-- read and close file
		outputString = file:read("*all")
	    io.close( file )
	else
	    -- handle error
		print( "Error: " .. errorString );
	end

	file = nil;

	return outputString;
end

writeBytes = function(fileName, filePath, bytes)
	local path = system.pathForFile(fileName, filePath);

	local file, errorString = io.open(path, "wb");

	if file then
		-- write and close file
	    file:write(bytes);
	    io.close(file);
	else
	    -- handle error
		print( "Error: " .. errorString );
	end

	file = nil;
end

readBytes = function(fileName, filePath)
	local bytes;
	local path = system.pathForFile(fileName, filePath);

	local file, errorString = io.open(path, "rb");

	if file then
		-- read and close file
		bytes = file:read("*all");
	    io.close( file )
	else
	    -- handle error
		print( "Error: " .. errorString );
	end

	file = nil;

	return bytes;
end

return fileManager;
