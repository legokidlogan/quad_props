QuadProps = QuadProps or {}
QuadProps.SIZE_MAX = 1000
QuadProps.THICKNESS = 1


CreateConVar( "sbox_maxquad_prop", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of quad props per player.", 1, 1000 )
CreateConVar( "quad_props_size_limit_mode", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "0 To always enforce size limit, 1 to ignore it on world-owned or superadmin-owned quad props (requires a prop protection addon), 2 to always ignore it.", 1, 2 )

if cleanup then
    cleanup.Register( "quad_prop" )
end


AddCSLuaFile( "quad_props/utils.lua" )
AddCSLuaFile( "quad_props/create_meta.lua" )

AddCSLuaFile( "quad_props/client/url_images.lua" )
AddCSLuaFile( "quad_props/client/url_whitelist.lua" )
AddCSLuaFile( "quad_props/client/utils.lua" )
AddCSLuaFile( "quad_props/client/settings.lua" )


include( "quad_props/utils.lua" )
include( "quad_props/create_meta.lua" )

if CLIENT then
    include( "quad_props/create_meta.lua" )

    include( "quad_props/client/url_images.lua" )
    include( "quad_props/client/url_whitelist.lua" )
    include( "quad_props/client/utils.lua" )
    include( "quad_props/client/settings.lua" )
end
