-- Preserve the original held3A test and all of its source assertions.
local h=assert(io.open('tests/transfer_help_predecessor.lua','rb'));local source=h:read('*a');h:close()
local function hash(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return n end
assert(#source==2014 and hash(source)==316453000,'original held3A predecessor test changed')
local needle="local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end"
local first,last=assert(source:find(needle,1,true));assert(not source:find(needle,last+1,true))
source="local restore=dofile('tests/fixtures/restore_help_report_request.lua')\n"..source:sub(1,first-1).."local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return restore(s,path)end"..source:sub(last+1)
assert(loadstring(source,'@held3A-after-exact-report-amendment-inverse'))()
