QuadProps = QuadProps or {}

if QuadProps._QuadPropMeta then return end

local entMeta = FindMetaTable( "Entity" )
local index = rawget( entMeta, "__index" ) or function() end
local newindex = rawget( entMeta, "__newindex" ) or function() end

local meta
meta = {
    __tostring = rawget( entMeta, "__tostring" ),

    __index = function( self, key )
        local override = meta[key]
        if override ~= nil then return override end

        return index( self, key )
    end,

    __newindex = function( self, key, value )
        local override = meta[key]
        if override ~= nil then return override( self, key, value ) end

        return newindex( self, key, value )
    end,
}

QuadProps._QuadPropMeta = meta
