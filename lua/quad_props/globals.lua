QuadProps = QuadProps or {}

if QuadProps._globalsLoaded then return end
QuadProps._globalsLoaded = true

QuadProps.SIZE_MAX = 1000
QuadProps.SIZE_ROUNDING = 3
QuadProps.THICKNESS = 1
QuadProps.RESIZE_COOLDOWN = 0.1


CreateConVar( "sbox_maxquad_prop", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of quad props per player.", 0, 1000 )
CreateConVar( "quad_props_size_limit_mode", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "0 To always enforce size limit, 1 to ignore it on world-owned or superadmin-owned quad props (requires a prop protection addon), 2 to always ignore it.", 0, 2 )
