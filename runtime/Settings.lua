-- Local settings contain data only. Never load them as Lua code.
local M={}
M.keys={'W','S','A','D','Tab','E','G','One','Two','Three','Four','Five','V',
    'LeftMouseButton','RightMouseButton','R','B','LeftShift','LeftControl','C','F6',
    'MiddleMouseButton','LeftAlt','RightAlt'}
local allowed={LeftMouseButton=true,RightMouseButton=true,MiddleMouseButton=true,
    ThumbMouseButton=true,ThumbMouseButton2=true,SpaceBar=true,Tab=true,Enter=true,
    LeftShift=true,RightShift=true,LeftControl=true,RightControl=true,LeftAlt=true,RightAlt=true,
    Up=true,Down=true,Left=true,Right=true,Home=true,End=true,PageUp=true,PageDown=true,
    Insert=true,Delete=true,BackSpace=true}
for n=65,90 do allowed[string.char(n)]=true end
for _,n in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'}) do allowed[n]=true end
for n=1,12 do if n~=7 and n~=8 then allowed['F'..n]=true end end
function M.defaults()
    local result={mouse=2.5,aim=1,fov=80,ui_scale=1,ui_opacity=1,experimental_start=false,keys={}}
    for _,key in ipairs(M.keys) do result.keys[key]=key end
    return result
end
function M.validate(value)
    if type(value)~='table' or type(value.keys)~='table' then return nil,'Settings are missing.' end
    for _,name in ipairs({'mouse','aim'}) do
        local v=value[name]
        if type(v)~='number' or v~=v or v<.1 or v>10 then return nil,'Mouse speeds must be from 0.1 to 10.' end
    end
    local scale=value.ui_scale==nil and 1 or value.ui_scale
    local opacity=value.ui_opacity==nil and 1 or value.ui_opacity
    local fov=value.fov==nil and 80 or value.fov
    if type(fov)~='number' or fov~=fov or fov<80 or fov>120 then return nil,'Field of view must be from 80 to 120 degrees.' end
    if type(scale)~='number' or scale~=scale or scale<.5 or scale>1.5 then return nil,'HUD size must be from 50% to 150%.' end
    if type(opacity)~='number' or opacity~=opacity or opacity<.1 or opacity>1 then return nil,'HUD opacity must be from 10% to 100%.' end
    local experimental=value.experimental_start
    if experimental==nil then experimental=false end
    if type(experimental)~='boolean' then return nil,'Experimental start must be on or off.' end
    local result={mouse=value.mouse,aim=value.aim,fov=fov,ui_scale=scale,ui_opacity=opacity,experimental_start=experimental,keys={}}
    local used={}
    for _,key in ipairs(M.keys) do
        local assigned=value.keys[key]
        if not allowed[assigned] then return nil,'Choose a keyboard or mouse key. F7, F8 and Escape are reserved.' end
        if used[assigned] then return nil,'Two actions use '..assigned..'. Choose a different key.' end
        used[assigned]=true
        result.keys[key]=assigned
    end
    return result
end
function M.parse(text)
    if type(text)~='string' or #text>8192 then return nil,'Settings file is too large.' end
    local result=M.defaults()
    local seen={}
    for line in text:gmatch('[^\r\n]+') do
        local name,value=line:match('^([%w_]+)=([%w_.]+)$')
        if not name or seen[name] then return nil,'Settings file has a bad or repeated entry.' end
        seen[name]=true
        if name=='mouse' or name=='aim' or name=='fov' or name=='ui_scale' or name=='ui_opacity' then
            result[name]=tonumber(value)
            if not result[name] then return nil,'Settings file has a bad number.' end
        elseif name=='experimental_start' then
            if value~='0' and value~='1' then return nil,'Experimental start must be 0 or 1.' end
            result.experimental_start=value=='1'
        elseif result.keys[name] then result.keys[name]=value
        else return nil,'Settings file has an unknown entry.' end
    end
    return M.validate(result)
end
function M.encode(value)
    local checked,message=M.validate(value)
    if not checked then return nil,message end
    local lines={'mouse='..checked.mouse,'aim='..checked.aim,'fov='..checked.fov,'ui_scale='..checked.ui_scale,'ui_opacity='..checked.ui_opacity,
        'experimental_start='..(checked.experimental_start and '1' or '0')}
    for _,key in ipairs(M.keys) do lines[#lines+1]=key..'='..checked.keys[key] end
    return table.concat(lines,'\n')..'\n'
end
function M.load(folder,keep_current)
    local file=io.open(folder..'settings.ini','r')
    if not file then
        if keep_current then return nil,'Settings file is not ready.' end
        return M.defaults()
    end
    local text=file:read(8193); file:close()
    return M.parse(text)
end
return M
