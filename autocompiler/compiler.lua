local config = {
    ignore = {
        [getResourceName(getThisResource())] = true,
    }
}

local temp = {}

function compile(path, file, resourceName)
	fetchRemote( "http://luac.mtasa.com/?compile=1&debug=0&obfuscate=3",
	function(data)
        local meta = xmlLoadFile(":"..resourceName.."/meta.xml")
		local newFile = fileCreate(path)
		if newFile then
			fileWrite(newFile, data)
			fileFlush(newFile)
			fileClose(newFile)
		end

        for _, node in pairs(xmlNodeGetChildren(meta)) do
            if xmlNodeGetName(node) == "script" then
                local name = xmlNodeGetAttribute(node, "src")
                local type = xmlNodeGetAttribute(node, 'type')
                if name and name ~= "" and (type=='client' or type=='shared') then
                    name = name:gsub(".luac",".lua") -- '.luac' to '.lua', in case the file is already compiled
                    if name and name ~= "" then
                        xmlNodeSetAttribute(node, "src", name .. "c")
                    end
                end
            end
        end
        xmlSaveFile(meta)
        xmlUnloadFile(meta)

        temp[resourceName] = temp[resourceName] - 1

        if temp[resourceName] == 0 then
            temp[resourceName] = nil
            outputDebugString("[LUAC] '"..resourceName.."' is now fully compiled!", 4)
            refreshResources(false, getResourceFromName(resourceName))
            startResource(getResourceFromName(resourceName),true)
        end
	end, file, true)
end

function getResourceFiles(resourceName)
    local meta = xmlLoadFile(":"..resourceName.."/meta.xml")
    if not meta then return false end

    if not fileExists("hash.json") then
        fileCreate("hash.json")
    end
    local hashFile = fileOpen("hash.json")
    local hashTable = {}
    if fileGetSize(hashFile) > 0 then
        hashTable = fromJSON( fileRead(hashFile, fileGetSize(hashFile)) ) or {}
    end
    fileClose(hashFile)

    local files = {}

    for _, node in pairs(xmlNodeGetChildren(meta)) do
        if xmlNodeGetName(node) == "script" then
            local name = xmlNodeGetAttribute(node, 'src')
            local type = xmlNodeGetAttribute(node, 'type')
            if name and name ~= "" and (type=='client' or type=='shared') then
                local lua = ":"..resourceName.."/"..name
                lua = lua:gsub(".luac",".lua")-- '.luac' to '.lua', in case the file is already compiled

                local luac = lua.."c"

                local script = fileOpen(lua)
                local file = fileRead(script, fileGetSize(script))
                local hash = hash("md5", file)
                if hash ~= hashTable[lua] then -- if actual hash is different from previous hash
                    hashTable[lua] = hash
                    files[luac] = file
                end
                fileClose(script)
            end
        end
    end

    hashFile = fileCreate("hash.json")
    fileWrite(hashFile,toJSON(hashTable))
    fileFlush(hashFile)
    fileClose(hashFile)

    return files
end

function table.size(tab)
    local length = 0
    for _ in pairs(tab) do length = length + 1 end
    return length
end

local function prepareResource(res)
    local resourceName = getResourceName(res)
    if config.ignore[resourceName] or isResourceProtected(res) then
        return false
    end
    local files = getResourceFiles(resourceName)
    local size = table.size(files)
    if size == 0 then
        return false
    end
    cancelEvent(true, "[LUAC]")
    outputDebugString("[LUAC] '"..resourceName.."' has "..size.." files that needs to be compiled.", 4)
    temp[resourceName] = size
    for fileName, file in pairs(files) do
        compile(fileName, file, resourceName)
    end
end
addEventHandler("onResourcePreStart", root, prepareResource)
