
if cleanup then
    cleanup.Register( "quad_prop" )
end


AddCSLuaFile( "quad_props/globals.lua" )
AddCSLuaFile( "quad_props/utils.lua" )
AddCSLuaFile( "quad_props/create_meta.lua" )

AddCSLuaFile( "quad_props/client/url_images.lua" )
AddCSLuaFile( "quad_props/client/url_whitelist.lua" )
AddCSLuaFile( "quad_props/client/utils.lua" )
AddCSLuaFile( "quad_props/client/settings.lua" )


include( "quad_props/globals.lua" )
include( "quad_props/utils.lua" )
include( "quad_props/create_meta.lua" )

if CLIENT then
    include( "quad_props/create_meta.lua" )

    include( "quad_props/client/url_images.lua" )
    include( "quad_props/client/url_whitelist.lua" )
    include( "quad_props/client/utils.lua" )
    include( "quad_props/client/settings.lua" )
end
