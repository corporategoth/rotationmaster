-- Inverse of the Stop step rename (3943b4fa: a Stop step is type 'stop', it was 'none') for the module the
-- persisted-runtime fixtures pin whole: the current Core/rotation_sequence.lua becomes the text restore_active_runtime_plan.lua
-- records. Applied before every older layer; a text that is already undone passes through.
local patches={
 ['Core/rotation_sequence.lua']={
 {current=[[                if step.type=="stop" then
]],old=[[                if step.type=="none" then
]]},
 },
}
return function(text,path)
 local list=patches[path]
 if not list then return text end
 for _,patch in ipairs(list) do
  local first,last=text:find(patch.current,1,true)
  if first then
   assert(not text:find(patch.current,last+1,true),'repeated recorded change: '..path)
   text=text:sub(1,first-1)..patch.old..text:sub(last+1)
  else
   -- Several suites compose this layer more than once on the way down; a text already undone passes through.
   assert(text:find(patch.old,1,true),'unrelated change to '..path)
  end
 end
 return text
end
