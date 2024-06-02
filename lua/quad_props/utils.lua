QuadProps = QuadProps or {}


local CVAR_LIMIT_MODE = GetConVar( "quad_props_size_limit_mode" )


function QuadProps.ShouldLimitSizeForPlayer( ply )
    local mode = CVAR_LIMIT_MODE:GetInt()
    if mode == 0 then return true end
    if mode == 2 then return false end

    if not IsValid( ply ) then return false end

    return not ply:IsSuperAdmin()
end

function QuadProps.ShouldLimitSizeForQuadProp( qp )
    if not CPPI then return CVAR_LIMIT_MODE:GetInt() ~= 2 end

    return QuadProps.ShouldLimitSizeForPlayer( qp:CPPIGetOwner() )
end
