QuadProps = QuadProps or {}


CreateConVar( "sbox_maxquad_prop", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of quad props per player.", 1, 1000 )

if cleanup then
    cleanup.Register( "quad_prop" )
end


AddCSLuaFile( "quad_props/create_meta.lua" )

AddCSLuaFile( "quad_props/client/url_images.lua" )
AddCSLuaFile( "quad_props/client/url_whitelist.lua" )
AddCSLuaFile( "quad_props/client/utils.lua" )
AddCSLuaFile( "quad_props/client/settings.lua" )


if CLIENT then
    include( "quad_props/create_meta.lua" )

    include( "quad_props/client/url_images.lua" )
    include( "quad_props/client/url_whitelist.lua" )
    include( "quad_props/client/utils.lua" )
    include( "quad_props/client/settings.lua" )
end
