---Config [temporary, for the beta]
local rootLocations = { -- Put any additional locations for blocks (e.x. "disk","disk1") here. Upon full release, adding disks will be through an FS call.
    "rootFS", -- do remove this one
    "disk",
    "disk2",
    "disk3",
    "disk4",
    "disk5",
    "disk6",
    "disk7",
    "disk8",
    "disk9",
    "disk10",
    "disk11",
    "disk12",
    "disk13",
    "disk14",
    "disk15",
    "disk16",
    "disk17",
    "disk18",
    "disk19",
    "disk20",
    "disk21",
    "disk22",
    "disk23",
    "disk24",
    "disk25",
    "disk26",
    "disk27",
    "disk28",
    "disk29",
    "disk30",
    "disk31",
    "disk32",
    "disk33",
    "disk34",
    "disk35",
    "disk36",
    "disk37",
    "disk38",
    "disk39",
    "disk40",
    "disk41",
    "disk42",
    "disk43",
    "disk44",
    "disk45",
    "disk46",
    "disk47",
    "disk48",
    "disk49",
    "disk50",
    "disk51",
    "disk52",
    "disk53",
    "disk54",
    "disk55",
    "disk56",
    "disk57",
    "disk58",
    "disk59",
    "disk60",
    "disk61",
    "disk62",
    "disk63",
    "disk64",
    "disk65",
    "disk66",
    "disk67",
    "disk68",
    "disk69",
    "disk70",
    "disk71",
    "disk72",
    "disk73",
    "disk74",
    "disk75",
    "disk76",
    "disk77",
    "disk78",
    "disk79",
    "disk80",
    "disk81",
    "disk82",
    "disk83",
    "disk84",
    "disk85",
    "disk86",
    "disk87",
    "disk88",
    "disk89",
    "disk90",
    "disk91",
    "disk92",
    "disk93",
    "disk94",
    "disk95",
    "disk96",
    "disk97",
    "disk98",
    "disk99",
    "disk100",
    "disk101",
    "disk102",
    "disk103",
    "disk104",
    "disk105",
    "disk106",
    "disk107",
    "disk108",
    "disk109",
    "disk110",
    "disk111",
    "disk112",
    
}





local dev = false
--if dev then
local log = {} -- dev feature, makes my life easier if not local.
--end

--enable once done making startup fileV

--multishell = nil --  your stupid multishell(okay, it's fine and all, but it uses the window API...)
--term.redirect(term.native()) --  your slow window API

local cfs = {}--_G.fs -- create a reference to the current filesystem
for i,o in pairs(fs) do
    cfs[i] = o
end

--TODO: Symlinks, users & groups, permissions, and some error logs and ext2al error logs, AND STANDARDIZE THE INDENTATION

--Implementation of ext2CC. Note that we dont
--want to just go passing this arround. Pass 
--arround a wrapper to this so that this itself
--cannot ever see unwanted modification.
        
        
--[[
    The allmighty inode
    Some random notes:
    *2 is always the directory for /
    
    The stuff in there and what it means

    fileSize - The size of the file we're talking about here. Total size. 
    blocks - The blocks this file is on
    blocksSize - A ext2CC exclusive, real-world filesystems will have a standard size for every block. The reason this exists in ext2CC is because of the lack of a standardize block size(if I could've used a single file and jumped arround to byte numbers, I would've had a standard block size. But, with the way it is currently, it's pointless.)




]]

local function subOutFirstDir(_path)
    ----Input: String- the path that the first directory shall be extracted from
    ----Output: String- the first directory with no / after it, String- the rest of the path with no / prefix
    
    --if there is a / in the front of this directory then we can just return /. CC's default filesystem does not work like this, however, we aren't CC's default filesystem.
    
    if string.sub(_path,1,1) == "/" then -- fs.combine removes a / at the first part of the directory. easiest to just handle / on its own.
        return "/",string.sub(_path,2,#_path)
    end 
    _path=cfs.combine(_path,"")--get rid of any BS
    local spot = string.find(_path,"/")
    if not spot then
        return _path
    end
    return string.sub(_path,1,spot-1),string.sub(_path,spot+1,#_path)
    
end
local function charTableToString(_chartable)
    local str = ""
    for i=1,table.maxn(_chartable) do
        str = str..string.char(_chartable[i])
    end
    return str
end
local function stringToCharTable(_string)
    local char = {}
    for i=1,#_string do
        char[i] = string.byte(string.sub(_string,i,i))
    end
    return char
end
local function getRealFileSize(_file)
    local file = cfs.open(_file,"r")
    if not file then
        return 0
    end
    local len = #file.readAll()
    file.close()
    return len
end

local ext2CC = { --Takes inspiration from EXT2, but is different in many ways. Its most prominent ext2 feature would be the inode table, present on all unix-style filesytems.
new = function(s,_locations)
    ----Input: String location, Number block size
    ----Output: Me
    assert(tostring(_location),"ExCC.new - #1 must be String")
    --assert(cfs.exists(iLocation),"ExCC.new - #1 must exist on filesystem")
        
    
    local self = {}
    setmetatable(self,{__index=s})
    
    self.locations = _locations
    --open inode
    --print(self.location)
    local file = cfs.open(cfs.combine(self.locations[1],"inode"),"r") -- first location should always have the inode
    --print(file)
    local fInode = file.readAll()
    file.close()
    fInode = textutils.unserialize(fInode)
    
    if not fInode then
        printError("Filesytem is corrupt (missing or invalid inode table)")
    end
    
    
    self.inode = fInode[1] --whoever made lua's tables start at 1, I sware to
    self.blockInfo = fInode[2]
    
    
    

    return self
    end,

    writeToBlock = function(self,_blocknum,_ammount,_what,__startAt) --maybe move this and its following function to be outside and local?
        ----Input: Number- The block number
        --Number ammount - Ammount to write
        --Table of Numbers - Binary of what to write
        --to the block, 
        ----Output: Number - 0 for success, 1 for 
        --out of space 2 for insufficient 
        --permissions 3 for file not found, 
        --Table of Numbers - what is 
        --left that couldnt fit
        
        --~Notes:
        --Does NOT allocate a block for you. 
        --Doesn't check anything about the block. It just writes to it, no questions asked.
        local realpath = self.blockInfo.blockLocations[_blocknum]
        if not realpath then
            return 3 
        end
        local file = cfs.open(realpath,"wb")
        for i=1,_ammount do
            file.write(_what[i+(_startAt or 0)])
            if i % 100000 == 0 then -- if dividing 10000 by i will have no remainder then yield
                os.queueEvent"oneYield"
                os.pullEvent"oneYield"
            end

        end
        --[[for o=1,_ammount do  -- remove chars weve gone over
            table.remove(_what,1)
        end]]
        file.close()
        return 0
    end,
    readFromBlock = function(self,_blocknum,_ammount)
        ----Input: Number- The block number
        --Number - Ammount of bytes to read
        ----Output: Number - 0 for success, 
        --2 for insufficient 
        --permissions, 3 for file not found
        --Table of Numbers - what is 
        
        
        local file = cfs.open(self.blockInfo.blockLocations[_blocknum] or "","rb")
        if not file then --file not found
            return 3
        end
        local contents = {}
        for i=1,_ammount do
            contents[i] = file.read()
            if contents[i] == nil then
                break
            end 
        end
        file.close()
        --print(tostring(_ammount)..tostring(contents))sleep(2)
        return 0,contents
    end,
    allocateBlock = function(self)
        ----Input: Nothing
        ----Output: A free block, if there is one.
        for i=1,#self.blockInfo.freeBlocks do
            if cfs.getFreeSpace(self.blockInfo.blockLocations[self.blockInfo.freeBlocks[i]]) > 3000 then
                return table.remove(self.blockInfo.freeBlocks,i) --note that table.remove returns what was removed.
            end
        end
        return false
    end,
    getDirectory = function(self,_fakePath) 
        _fakePath = cfs.combine(_fakePath,"")
        if _fakePath == "" then
            return 0,2
        end
        local err,folderInode = self:locateInInode(_fakePath)
        if err ~= 0 then
        -- print"ExtErr"
            return err --pass on the error
        elseif (self.inode[(folderInode or -1)] or {}).type ~= 1 then
        -- print"intErr"
            return 4
        end
        return 0,folderInode
    end,
        
    listInDirectory_wInode = function(self,_folderInode)
        ----Input: String- the "fake" path of the directory
        ----Output: Table-The directory table, which is formatted: filename:inode# 

        log[#log+1] = "folderInode: "..tostring(_folderInode)
        local err,directory = self:read_wInode(_folderInode)
        log[#log+1]="alive"
        if err ~= 0 then
            return er
        end
        directory = charTableToString(directory)
        log[#log+1] = directory
        directory = textutils.unserialize(directory)
        return 0,directory

    end,

    locateInInode = function(self,_fakePath)
        ----Input: String- the "fake" path of the file
        ----Output: Number - You know the drill here see readFromBlock if you don't--but this adds 4, which is using file as directory,  Table - The inode for this file
        _fakePath = cfs.combine(_fakePath,"")
        
        local _,iLimiter = string.gsub(_fakePath,"/","")
        local currentFile,currentInode,currentDirTable,isUsingFileAsDir
        currentInode = 2 --Root is always 2. Otherwise, we would never be able to find anything
        
        for i=1,iLimiter+2 do
                
            local dircontents = ""
            if not self.inode[currentInode] then
                return 3
            end
            for i=1,#self.inode[currentInode].blocks do -- almost always runs just once unless a rarer case where a folders's split across drives
                local ok,charTable = self:readFromBlock(self.inode[currentInode].blocks[i],self.inode[currentInode].blocksSize[i]) -- read the folder's file
                dircontents = dircontents..charTableToString(charTable)
            end
            
            currentDirTable = textutils.unserialize(dircontents)
            if not currentDirTable then --if this directory is empty
                currentDirTable = {}
            end
            if (not currentDirTable[currentFile]) and i ~= 1 then
                return 3
            end
            currentInode = currentDirTable[currentFile] or currentInode
            
            if _fakePath then --We check this because, upon reaching a final, non-directory path, there will be nothing left of _fakePath
                currentFile, _fakePath = subOutFirstDir(_fakePath)
                if self.inode[currentInode].type ~= 1 then --Since there is stuff left in this directory, this needs to come up as a file. 
                --print("fa "..self.inode[currentInode].type)
                return 4
                end
            end
            --print("f".._fakePath)
        
        end
        --print("returning "..textutils.serialize(currentInodeTable))
        return 0,currentInode
        
    end,
        
    write_wInode = function(self,_inodeID,_what)
        ----Input: Number - Inode ID of what to write to.
        ----Ouput: Number - Error code
        local myInode = self.inode[_inodeID]
        
        myInode.fileSize = #_what

        
        myInode.blocks = myInode.blocks or {} -- Make a list of blocks potentially availiable for writing to.
        local blocks,hasUsedBlock = {}
        if myInode.blocks[1] then--if there's anything in here
            table.insert(blocks,myInode.blocks[#myInode.blocks]) -- Add the last block of this current file
            hasUsedBlock = true -- Make sure they know that this block doesn't need to be allocated  | Maybe redo this to delete everything this file has, add its blocks to freeBlocks, then probably reuse most of them
        end
        for i=1,#(self.blockInfo.freeBlocks or {}) do
            table.insert(blocks,self.blockInfo.freeBlocks[i]) -- Add all the free blocks
        end
        local left = 0 -- funny story about accidently having this set to 1 here...
        for i=1,#blocks do
            local freeSpace = cfs.getFreeSpace(self.blockInfo.blockLocations[blocks[i]])  +  getRealFileSize(self.blockInfo.blockLocations[blocks[i]]) -- for blocks that where previously occupied but then the file was deleted, and that block is on an almost-full drive. 
            if (freeSpace > 3000)   then
                local ammountWrite = math.min(#_what-left,freeSpace-3000)
                local err
                --print("1 write: "..tostring(ammountWrite))
                err = self:writeToBlock(blocks[i],ammountWrite,_what,left)
                if err ~= 0 then --If there's an error, pass it on 
                    --print("errCode:"..tostring(err))
                    return err 
                end
                left = left+ammountWrite

                if hasUsedBlock then
                    myInode.blocksSize[#myInode.blocksSize] = ammountWrite
                else
                    myInode.blocks[#myInode.blocks+1] = blocks[i]
                    myInode.blocksSize = myInode.blocksSize or {}
                    myInode.blocksSize[#myInode.blocks] = ammountWrite
                end
                for f=1,#self.blockInfo.freeBlocks do
                    if self.blockInfo.freeBlocks[f] == blocks[i] then
                        table.remove(self.blockInfo.freeBlocks,f)
                    end
                end
                if left >= #_what then -- if the _what table has been all written
                    --print"allDone"
                    self:writeInode() -- save the inode to disk
                    return 0
                end

                
                hasUsedBlock = false --This will set this to false after the first for loop, because the only block we'll use is the last one.
            end
        end
        for i=1,#self.locations do 
            if cfs.getFreeSpace(self.locations[i]) > 3000 then
                --print"NEWBLOCKS"
                for i=1,10 do --make 10 new blocks because this saves time
                    local newBlockNum = #self.blockInfo.blockLocations+1
                    self.blockInfo.blockLocations[newBlockNum] = cfs.combine(self.locations[i],"blocks/"..tostring(newBlockNum))
                    self.blockInfo.freeBlocks[#self.blockInfo.freeBlocks+1] = newBlockNum
                end
                self:writeInode()
                if left > 0 then
                    if not self:write_wInode(_inodeID,_what) == 1 then
                        return 0 -- If this worked then we're good
                    end--write the rest of it
                end
            end
        end
        return 1
    end,
    putInDir = function(self,_fakePath)
        local name = cfs.getName(_fakePath)
        local fakeDirPath = string.sub(_fakePath,1,#_fakePath-(#name) ) --TODO : switch to fs.getDir ?
        log[#log+1] = "dirPath "..tostring(fakeDirPath)
        log[#log+1] = "nam "..tostring(name)
        local err,dirInode = self:getDirectory(fakeDirPath)
        if err ~= 0 then
            return err
        end
        local err,dirList = self:listInDirectory_wInode(dirInode)
        log[#log+1]="m"
        if err ~= 0 then
            return err
        end
        local inodeID = dirList[cfs.getName(_fakePath)]
        
        --print(name.." : "..tostring(inodeID))
        
        if not inodeID then --need to make one!
            inodeID = #self.inode+1
            self.inode[inodeID] = {}
            dirList[name] = inodeID 
            --print(textutils.serialize(dirList))
            
            self:write_wInode(dirInode,stringToCharTable(textutils.serialize(dirList)))
            --print"d"
            
            
        end
        return inodeID,dirInode
    end,
    write = function(self,_fakePath,_what,_type) ---Maybe make this return the inode ID?
        ----Input: String - The "fake" path to the file
        --String - The text to write.
        ----Output: Number - 0  for success,
        --1 for out of space
        --2 for insufficient perms. 
        --
        local inodeID,dirInode = self:putInDir(_fakePath)
            --print(name.." : "..tostring(inodeID))
        self.inode[inodeID] = self.inode[inodeID] or {}
        self.inode[inodeID].type = _type or 0
        --self.inode[inodeID].temp = true --debug to see what inodes this was writing
        self.inode[inodeID].hardLinks = self.inode[inodeID].hardLinks or {}
        self.inode[inodeID].hardLinks[#self.inode[inodeID].hardLinks+1] = dirInode
        
        
        --print"B4"
        return self:write_wInode(inodeID,_what)
    end,
    read = function(self,_fakePath,_ammount)
        local err,inodeID = self:locateInInode(_fakePath)
        if err ~= 0 then --we've come across an error. pass it on down.
                return err
        end
        --print("in "..tostring(inodeID))
        return self:read_wInode(inodeID,_ammount)
    end,
    read_wInode = function(self, _inodeID,_ammount)
        ----Input: String - the "fake" path to the file
        ---Number - Ammount of bytes to read
        ----Output: Table of Numbers - The resulting character codes

        local chars,ammountRead = {},0
        for i=1,#self.inode[_inodeID].blocks do
            local file = cfs.open(self.blockInfo.blockLocations[  self.inode[_inodeID].blocks[i]  ],"rb")
            if not file then
                return 3
            end
            for i=1,self.inode[_inodeID].blocksSize[i] do
                chars[#chars+1] = file.read()
                ammountRead=ammountRead+1
                if ammountRead >= (_ammount or ammountRead+1) then
                    file.close()
                    return 0,chars
                end
            end
            file.close()
        end
        --sleep(3)
        --print(textutils.serialize(chars).." + "..textutils.serialize(self.inode[_inodeID].blocksSize))
        return 0,chars
        
            
        
    end,
    delete_wInode = function(self,inodeID) -- rip --TODO make this only delete it from inode if all hard links are gone.
        if inodeID == 2 then--um... no.
            return 6
        end
        --print"del"
        if not self.inode[inodeID] then --well
            return 
        end
        
        local hardLinks = self.inode[inodeID].hardLinks
        for i,link in pairs(hardLinks) do
            --print("h"..tostring(link))
            local err,dirTable = self:listInDirectory_wInode(link)
            for y,u in pairs(dirTable) do
                --print("y: "..tostring(y))
                --print("u"..tostring(u))
                if u == inodeID then
                    dirTable[y] = nil
                    break
                end
            end
            dirTable = stringToCharTable(textutils.serialize(dirTable))
            self:write_wInode(link,dirTable)
        end
        local blocks = self.inode[inodeID].blocks
        for i=1,#blocks do
            self.blockInfo.freeBlocks[#self.blockInfo.freeBlocks+1] = blocks[i]
        end
        self.inode[inodeID] = nil
        self:writeInode()
        return 0
    end,
            
            
    writeInode = function(self) -- TODO : Open in append mode for effeciency
        ----Input:
        ----Output:
        ----Notes:
        ---Writes the current inode to the inode table file.
        local file = cfs.open(cfs.combine(self.locations[1],"inode"),"w")
        if not file then
            return 3
        end
        local inodeSerialized =textutils.serialize({self.inode,self.blockInfo})
        if not inodeSerialized then
            return 5
        end 
        --print("WROTEINODE "..textutils.serialize(inodeSerialized))
        file.write(inodeSerialized)
        file.close()

        return 0
    end

}
local rootFS = ext2CC:new(rootLocations)






local function fsAssert(beTrue,errIfIsnt) -- a CC FS-style assert, errors at the program calling the function rather than in this one
    ----Input: Boolean- the variable to be checked, String- the error if it's false
    ----Output: An error message if it's false
    if not beTrue then
        error(errIfIsnt,4)
    end
end

local tEmpty = {} -- A variable for fs.complete
local filesys = rootFS --implement other fses later
local fs = {
    
    open = function(_fakePath,_mode)
        ----Input: String The "fake" path, String the mode to use
        ----Output: Your typical CC-style open table, if no errors occured.
        ----Notes: The file systems only support writing and reading in char tables, but conversion is easy and functions are provided to do it.
        ----Close() doesn't really do anything for read modes except throw an error if you try to read more. I'd still recommend calling it in case a different filesystem works differently
        ---TODO: Add support for different file systems, don't allow them to open a directory, check for permissions, check for symlinks. An implied requirement of this is to use the inode # rather than string when read/writing to the filesys
        local wrongArgs = "Expected string, string"
        local notOpen = "Stream closed"
        fsAssert(tostring(_fakePath),wrongArgs) -- These error messages must be 100% identical to the normal ones.
        fsAssert(tostring(_mode),wrongArgs)
        --Local variables for use inside the returned tables
        --local remainingText,remainingChar,currentWriteText,currentWriteChar
        
        if checkIfNotExists then ---implement this
            return
        end
        
        if _mode == "r" then
            local err,char = filesys:read(_fakePath)
            --print(err)
            --print(textutils.serialize(char))
            if not char then
                return
            end
            local remainingText,isOpen,bytesRead = charTableToString(char),true,0
            local bytesToRead = #remainingText
            return {
                readLine = function()
                    fsAssert(isOpen,notOpen)
                    local area = (string.find(remainingText,"\n") or #remainingText)
                    local returnThis = string.sub(remainingText,1,area)
                    remainingText = string.sub(remainingText,area,#remainingText)
                    
                   bytesRead = bytesRead+#returnThis
                    if bytesRead > bytesToRead then
                        return false
                    end
                    
                    return returnThis
                end,
                readAll = function()
                    fsAssert(isOpen,notOpen)
                    local returnThis = remainingText
                    remainingText = ""
                    return returnThis
                end,
                close = function()
                    isOpen = false
                    return
                end
            }
        elseif _mode == "w" then
            local currentWriteText,isOpen = "",true
            return {
                write = function(_what)
                    fsAssert(isOpen,notOpen)
                    currentWriteText = currentWriteText.._what
                end,
                writeLine = function(_what)
                    fsAssert(isOpen,notOpen)
                    currentWriteText = currentWriteText.._what.."\n"
                end,
                close = function()
                    isOpen = false
                    --print(_fakePath,stringToCharTable(currentWriteText))
                    local a=filesys:write(_fakePath,stringToCharTable(currentWriteText))
                    --print("er"..tostring(a))
                end,
            }
        elseif _mode == "a" then
            local currentWriteText,isOpen = "",true
            return {
                write = function(_what)
                    fsAssert(isOpen,notOpen)
                    currentWriteText = currentWriteText.._what
                end,
                writeLine = function(_what)
                    fsAssert(isOpen,notOpen)
                    currentWriteText = currentWriteText.._what.."\n"
                end,
                close = function()
                    isOpen = false
                    filesys:write(_fakePath,stringToCharTable(currentWriteText))
                end,
                flush = function()
                    filesys:write(_fakePath,stringToCharTable(currentWriteText))
                end
            }
        elseif _mode == "wb" then
            local currentWriteChar,isOpen = {},true
            return {
                write = function(_char)
                    fsAssert(isOpen,notOpen)
                    if _char then
                        currentWriteChar[#currentWriteChar+1] = _char
                    end
                end,
                flush = function()
                    filesys:write(_fakePath,currentWriteChar)
                end,
                close = function()
                    isOpen = false
                    filesys:write(_fakePath,currentWriteChar)
                end
            }
        elseif _mode == "rb" then --easiest one.
            local err,remainingChar = filesys:read(_fakePath)
            local isOpen = true
            return {
                read = function()
                    fsAssert(isOpen,notOpen)
                    return table.remove(remainingChar,1)
                end,
                close = function()
                    isOpen = false
                end
            }
        end
                    
            
                    
                
        
        fsAssert(false,"Unsupported mode") -- if we haven't returned anything yet, they're not giving us the right mode.
    end,
    list = function(_dir)
        ----Input: String- directory
        ----Output: Linear table-files in directory
        local err,folderInode = rootFS:getDirectory(_dir)
        --print(folderInode)
        fsAssert(err == 0,"Not a directory")
        local err,dirList = filesys:listInDirectory_wInode(folderInode)
        fsAssert(err == 0,"Not a directory")
        fsAssert(type(dirList)=="table","Not a directory")
        
        local linearDirList = {}
        for i,o in pairs(dirList) do --List directory gives us name:inode#. This converts to a linear table.
            linearDirList[#linearDirList+1]=i
        end
        return linearDirList
    
    end,
    isDir = function(_dir)
        _dir = _dir or ""
        --print("isDir ".._dir)
        if filesys:getDirectory(_dir) == 0 then
            return true
        else
            return false
        end
    end,
    isReadOnly = function(_file)--TODO
        _file = _file or ""
        return false
    end,
    exists = function(_file)
        _file = cfs.combine(_file,"")
        if _file == "" then --Hey man, does the ground I'm standing on exist?
            return true --...uh, yeah?
        end
        local err,inodeID = filesys:locateInInode(_file)
        if inodeID then
            return true
        else
            return false
        end
    end,
    delete = function(_file)
        local err,inodeID = rootFS:locateInInode(_file)
        if not inodeID then
            return
        end
        if rootFS.inode[inodeID].type == 1 then --TODO
            local err,dirList = rootFS:listInDirectory_wInode(inodeID)
            if not err then
                
            end
        end 
        local err = rootFS:delete_wInode(inodeID)
        if err == 6 then
            fsAssert(false,"Access denied")
        end
    end,
    makeDir = function(_file) -- directories are just files
        rootFS:write(_file,{123,125},1) --123 = "{", 125 = "}". 1 is type for directory.
    end,
    getSize = function(_file)
        local err,inodeID = rootFS:locateInInode(_file)
        if not inodeID then
            return
        end
        return rootFS.inode[inodeID].fileSize
    end,
    --move = function(_file,_file2) --TODO
        
        
    
    
    
    
    
}
    

local romFS = {}
                            
local romFS_meta = {}
romFS_meta.__index = function(tab,key)
    --[[
        Metatables are called when an operation is being done on the table. This specific operation, __index (so things like myTable[myKey] would result in this function being called with the inputs myTable and myKey as table and key), is called when the table in indexed and no variables are found.
    ]]
    return function(...) ---Note that there is no reason to validate the path because realFS does that for us
        local args=  {...}
        --print("r"..textutils.serialize(args))
        --local pos = string.find(args[1],"/")
        --args[1] = string.sub(args[1],1,(pos or 4)-1)
        return cfs[key](table.unpack(args)) --funny story about the original variable nam for tab and this line...
    end
end
setmetatable(romFS,romFS_meta)

local ccFS = {}
                            
local ccFS_meta = {}
ccFS_meta.__index = function(tab,key)
    return function(...)
        local args=  {...}
        local pos = string.find(args[1],"/")
        args[1] = string.sub(args[1],(pos or 5)+1,#args[1])
        return cfs[key](table.unpack(args)) --funny story about the original variable nam for tab and this line...
    end
end
setmetatable(ccFS,ccFS_meta)



    


local fileSystems = {    --Mount dir : filesytem
    [""] = fs,
    ["ccFS"] = ccFS,
    ["rom"] = romFS, -- for compatibility reasons we'll go ahead and mount it at /rom
}

local function getFileSystemAndRealPath(_fakePath) -- figure out which fs to return them. This means that each filesystem needs to re-implement its own "fs" API. 
    --print"a"
    _fakePath = cfs.combine((_fakePath or ""),"")
    local _fakeDir = _fakePath
    while true do 
        --[[if _fakeDir == "" then
            return rootFS,_fakePath
        elseif _fakeDir == "rom" then --redo this later, rom will be mounted to something like /mnt/ccrom
            return cfs,_fakePath
        elseif _fakeDir == "realworldfs"
        end]]
        
        for i,o in pairs(fileSystems) do
            if _fakeDir == i then --if this full path is something we have in our filesystem database
                if i=="rom" then
                    --print"rom"
                    --sleep(0.2)
                end
                return _fakePath,o --return the fake fs library
            end
        end
        _fakeDir = cfs.getDir(_fakeDir)
        if _fakeDir == ".." then -- this shouldn't ever be true
            printError"We got problems"
            sleep(100)
        end
            
    end
end

local realFS = {} --the fs we pass to programs

--------------------------------------------
--THE FOLLOWING ARE SNIPPETS FROM BIOS.LUA--
--------------------------------------------

local function complete( _thefs, sPath, sLocation, bIncludeFiles, bIncludeDirs)
    bIncludeFiles = (bIncludeFiles ~= false)
    bIncludeDirs = (bIncludeDirs ~= false)
    local sDir = sLocation
    local nStart = 1
    local nSlash = string.find( sPath, "[/\\]", nStart )
    if nSlash == 1 then
        sDir = ""
        nStart = 2
    end
    local sName
    while not sName do
        local nSlash = string.find( sPath, "[/\\]", nStart )
        if nSlash then
            local sPart = string.sub( sPath, nStart, nSlash - 1 )
            sDir = cfs.combine( sDir, sPart )
            nStart = nSlash + 1
        else
            sName = string.sub( sPath, nStart )
        end
    end
    
    if _thefs.isDir( sDir ) then
        local tResults = {}
        if bIncludeDirs and sPath == "" then
            table.insert( tResults, "." )
        end
        if sDir ~= "" then
            if sPath == "" then
                table.insert( tResults, (bIncludeDirs and "..") or "../" )
            elseif sPath == "." then
                table.insert( tResults, (bIncludeDirs and ".") or "./" )
            end
        end
        local tFiles = _thefs.list( sDir )
        for n=1,#tFiles do
            local sFile = tFiles[n]
            if #sFile >= #sName and string.sub( sFile, 1, #sName ) == sName then
                local bIsDir = _thefs.isDir( cfs.combine( sDir, sFile ) )
                local sResult = string.sub( sFile, #sName + 1 )
                if bIsDir then
                    table.insert( tResults, sResult .. "/" )
                    if bIncludeDirs and #sResult > 0 then
                        table.insert( tResults, sResult )
                    end
                else
                    if bIncludeFiles and #sResult > 0 then
                        table.insert( tResults, sResult )
                    end
                end
            end
        end
        return tResults
    end
    return tEmpty
end

---------------------------------
--END OF SNIPPETS FROM BIOS.LUA--
--------------------------------- 
 
 
local function find(_path,wildcard,_mustBePath)
    local wildcard,hasOne = string.gsub(wildcard,"*","")
    if (not hasOne) or (not fs.isDir(_path)) then 
        return {cfs.combine(_path,wildcard)}
    end
    local finds = fs.list(_path)
    --print("wildcard is "..wildcard)
    local result = {}
    for i=1,#finds do --if (not requring to be dir, or is dir) and it meets the wildcard, then
        --print(tostring(finds[i]))
        if  ( (not _mustBePath) or realFS.isDir(finds[i]) )   and string.find(finds[i],wildcard)  then
            result[#result+1] = cfs.combine(_path,finds[i])
        else
            --table.remove(finds,i)
        end
    end
    return result
end
 
 
 
local realFS_meta = {}
realFS_meta.__index = function(tab,key)
    if true then -- We have functions other than what is in type(cfs[key]) == "function" then -- Everything in fs is a function...
        --print(key)
        --sleep(0)
        return function(...)
            local args,filesys=  {...}
            args[1],filesys = getFileSystemAndRealPath(args[1])
            if key == "getDir" or key == "getName" then
                return cfs[key](table.unpack(args))
            elseif key == "complete" then
                args[2],filesys = getFileSystemAndRealPath(args[2])
                return complete(filesys,table.unpack(args))
            elseif key == "find" then
                
                local totalTable = {}
                local curTable = {args[1]}
                while true do
                    local wildcardWPath = string.sub(curTable[1],1,(string.find(curTable[1],"*") or #curTable[1]))
                                        --print"1"

                    if wildcardWPath == "" then
                        wildcard = ""
                    else
                        wildcard = cfs.getName(wildcardWPath)
                    end

                    local path = cfs.getDir(wildcardWPath)--print(curTable[1],1,(string.find(wildcard,"/") or #wildcard)+(#wildcardWPath-#wildcard))
                    --[[print("Wildcard w path" .. tostring(wildcardWPath))
                                        print("Wildcard " .. tostring(wildcard))
                                                            print("path " .. tostring(path))]]


                    
                    local smallTable = find(path,wildcard,string.find(wildcard,"/"))
                    for i=1,#smallTable do
                        local pos = 1
                        local further = false
                        --while true do -- validate if this should be taken further
                            
                        if string.find(smallTable[i],"*") then
                            --print"aded"
                            curTable[#curTable+1] = smallTable[i] -- add results to the next input
                        end
                        totalTable[#totalTable+1] = smallTable[i] -- add to total output
                    end
                    table.remove(curTable,1) -- remove what we've already done
                    --local spot = string.find(args[1],"/",spot+11)
                    if not curTable[1] then --spot then
                        break
                    end
                end
                return totalTable
            elseif key == "list" then
                local list = filesys[key](args[1])
                --[[for i,_ in pairs(fileSystems) do
                    if (cfs.getDir(i) == args[1]) and i ~= "" then
                        list[#list+1] = i
                    end
                end]]
                return list
            elseif (not args[2]) or key == "open" then
                --print("returning")
                return filesys[key](args[1],args[2])
            elseif key == "move" then --non-fs.open and has 2 args(move,copy,combine,complete)
                
            elseif key == "copy" then
                args[2],filesys2 = getFileSystemAndRealPath(args[2])
                local file = filesys.open(args[1],"rb")
                local file2 = filesys2.open(args[2],"wb")
                local res = true
                while res do
                    res = file.read()
                    if res then
                        file2.write(res)
                    end
                end
                file.close()
                file2.close()
            else
                --print("strOp")
                --sleep(0)
                return cfs[key](table.unpack(args))
            end
        end
    else
        --print"NAF"
        return nil --Everything in fs is a function
    end
end

setmetatable(realFS,realFS_meta)
    


























--
local function vt(is,shouldBe) -- verifyTable
if type(is) ~= "table" then --...
    return true
end
for i=1,#shouldBe do
    if is[i] ~= shouldBe[i] then
    return i
    end
end
return false
end 

----[[
local function bigolunittest() -- shoddy unit tests

--ininiation
autolog = {} -- self-checks
--cfs.delete("testFS")
cfs.makeDir("testFS")
cfs.makeDir("testFS/blocks")
local f=cfs.open("testFS/inode","w")
--f.write('{   {  },{ freeBlocks={2,3,4},blockLocations={[ 2 ]="/testFS/blocks/2",[ 3 ]="/testFS/blocks/3",[ 4 ]="/testFS/blocks/4"} }   }')
writeTable = {
    {
        [ 2 ] = { 
            ["fileSize"] = 99,["type"]=1,["blocks"]={4},["blocksSize"] ={999} 
        }, 
        [ 5 ] = {
            ["fileSize"] = 99,["type"] = 1, ["blocks"]={5},["blocksSize"] ={999}
        }, 
        [ 6 ] = {
            ["fileSize"] = 1337,["blocks"] = {6},["type"]=1,["blocksSize"] ={999}
        }, 
        [ 7 ] = {
            ["fileSize"] = 99, ["type"] = 0,["blocks"] = {7},["blocksSize"] ={999}
        } 
    },
    {
    freeBlocks={3,4,5,6,7},
    blockLocations={
            [ 1 ] = "/testFS/blocks/1",
            [ 2 ]="/testFS/blocks/2",
            [ 3 ]="/testFS/blocks/3",
            [ 4 ]="/testFS/blocks/4", 
            [ 5 ]="/testFS/blocks/5", 
            [ 6 ]="/testFS/blocks/6", 
            [ 7 ] = "/testFS/blocks/7",
            [ 8 ] = "/testFS/blocks/8",
            [ 9 ] = "/testFS/blocks/9",
        },   
    }
}
f.write(textutils.serialize(writeTable))
f.close()
local ok,err = pcall( function()
    local err, res,rerr,werr -- common variables
    testFS = ext2CC:new("/testFS")
        
    --log[#log+1] = textutils.serialize(testFS.blockInfo)
    
    res = subOutFirstDir("/proc/cpuinfo")
    if res ~= "/" then --#0
        autolog[#autolog+1] = "subOutFirstDir isn't working properly with return '/' on a directory that starts at root. Results of test #0: "..tostring(res)
    end

    res = subOutFirstDir("proc/cpuinfo")
    if res ~="proc" then --#1
    autolog[#autolog+1] = "subOutFirstDir isn't working properly with a non-'/' prefixed directory. Results of test #1: "..tostring(res)
    end
    
    testFS:writeToBlock(1,3,{106,107,108,127})
    err,res = testFS:readFromBlock(1,3)
    if vt(res,{106,107,108}) then --#2                               --Test of both readFromBlock and writeFromBlock. This really needs to be improved.
        autolog[#autolog+1] = "readFromBlock or writeFromBlock are not working properly. #2"
    end

    err,res=testFS:readFromBlock(1,1)--Test to see if read is stopping at its limitor. This block *should* contain 3 bytes,we just want 1
    if vt(res,{106}) then --#3
        autolog[#autolog+1] = "readFromBlock is most likely reading over its limitor. Results of self-test #3: "..textutils.serialize(res)
    end
    
    local writeTable = textutils.serialize({["look a distraction"]=666,["hi"]=5})
    testFS:writeToBlock(4,#writeTable,stringToCharTable(writeTable))
    writeTable = textutils.serialize({["bye"]=6,["ignorethisplz"]=1337,})
    testFS:writeToBlock(5,#writeTable,stringToCharTable(writeTable))
    writeTable = textutils.serialize({["guy"]=7})
    testFS:writeToBlock(6,#writeTable,stringToCharTable(writeTable))
    
    
    err,res=testFS:locateInInode("/hi/bye/guy")
    --log[#log+1]=textutils.serialize(res)
    if res ~= 7 then --#4
    autolog[#autolog+1] = "locateInInode isn't working properly for some complicated reason. May $deity have mercy on your soul. Results of self-test #4 code:"..tostring(err).." result:"..textutils.serialize(res)
    end

    werr = testFS:write("test1",{32,33,34,45,46}) --Test write.
    err,res=testFS:readFromBlock(3,5)
    log[#log+1] = textutils.serialize(res)
    if vt(res,{32,33,34,45,46}) then --#6
        autolog[#autolog+1] = "write is either writing to the wrong block, or isn't working at all. Results of self-test #5: (reader code) "..tostring(err)..", (writer code) "..tostring(werr)..", result: "..textutils.serialize(res)    
    end
    log[#log+1]=textutils.serialize(testFS.blockInfo.freeBlocks)
    
    err,res=testFS:locateInInode("/doesntexist")
    if err ~= 3 then --#6
    autolog[#autolog+1] = "locateInInode isn't returning error code 3 when using a file as a directory. Results of self-test #6: code:"..tostring(err).." result:"..textutils.serialize(res)
    end
    writeTable = "This is going to be used to test read()."
    testFS:writeToBlock(7,#writeTable,stringToCharTable(writeTable))
    
    err,res = testFS:read("hi/bye/guy")
    if charTableToString(res or {}) ~= writeTable then
        autolog[#autolog+1] = "read isn't reading properly. Results of self-test #7: error:"..tostring(err)..", result: "..textutils.serialize(res)
    end
        
    end
    )
    print("ok: "..tostring(ok))
    print("err: "..tostring(err))



    local strLog = ""
    for i=1,#log do
        strLog=strLog..log[i].."\n"
    end
    print("============================")
    textutils.pagedPrint(strLog)

    strLog = ""
    for i=1,#autolog do
        strLog=strLog..autolog[i].."\n"
    end
    print("==============AUTOLOG==============")
    textutils.pagedPrint(strLog)
        
        --write to inode so we can see it
    testFS.inode[99] = {["a"]="writeInode works"}
    print(testFS:writeInode())

end
if dev then
    bigolunittest()
end
--]]



--TEMP:


--loadAPI"/rom/apis/io"
--fs = cfs -- for testing
-- Install the rest of the OS api
local loadfile = function( _sFile, _tEnv )
    local file = realFS.open( _sFile, "r" )
    if file then
        local func, err = load( file.readAll(), cfs.getName( _sFile ), "t", _tEnv )
        file.close()
        return func, err
    end
    return nil, "File not found"
end

function io.open( _sPath, _sMode )
	local sMode = _sMode or "r"
	local file = realFS.open( _sPath, sMode )
	if not file then
		return nil
	end
	
	if sMode == "r"then
		return {
			bFileHandle = true,
			bClosed = false,				
			close = function( self )
				file.close()
				self.bClosed = true
			end,
			read = function( self, _sFormat )
				local sFormat = _sFormat or "*l"
				if sFormat == "*l" then
                                        --print"1 read"
					return file.readLine()
				elseif sFormat == "*a" then
					return file.readAll()
				else
					error( "Unsupported format" )
				end
				return nil
			end,
			lines = function( self )
				return function()
					local sLine = file.readLine()
					if sLine == nil then
						file.close()
						self.bClosed = true
					end
					return sLine
				end
			end,
		}
	elseif sMode == "w" or sMode == "a" then
		return {
			bFileHandle = true,
			bClosed = false,				
			close = function( self )
				file.close()
				self.bClosed = true
			end,
			write = function( self, _sText )
				file.write( _sText )
			end,
			flush = function( self )
				file.flush()
			end,
		}
	
	elseif sMode == "rb" then
		return {
			bFileHandle = true,
			bClosed = false,				
			close = function( self )
				file.close()
				self.bClosed = true
			end,
			read = function( self )
				return file.read()
			end,
		}
		
	elseif sMode == "wb" or sMode == "ab" then
		return {
			bFileHandle = true,
			bClosed = false,				
			close = function( self )
				file.close()
				self.bClosed = true
			end,
			write = function( self, _number )
				file.write( _number )
			end,
			flush = function( self )
				file.flush()
			end,
		}
	
	else
		file.close()
		error( "Unsupported mode" )
		
	end
end
local _oldFSRun = os.run
function os.run( _tEnv, _sPath, ... )
    local tArgs = { ... }
    local tEnv = _tEnv
    setmetatable( tEnv, { __index = _G } )
    tEnv.fs = realFS
    tEnv.loadfile = loadfile
    tEnv.os = os
    tEnv.io = io
    local fnFile, err = loadfile( _sPath, tEnv )
    if fnFile then
        local ok, err = pcall( function()
            fnFile( table.unpack( tArgs ) )
        end )
        if not ok then
            if err and err ~= "" then
                printError( err )
            end
            return false
        end
        return true
    end
    if err and err ~= "" then
        printError( err )
    end
    return false
end



if not dev then
    --[[local file = cfs.open("/rom/programs/shell","r")
    local shell = file.readAll()
    file.close()
    f=load(shell,"shell","t",_G)
    f()]]
    --term.redirect(term.native()) -- for my ridiculous print calls
    os.run({fs=realFS,loadfile = loadfile,os=os},"/rom/programs/shell")
end
os.run = _oldFSRun