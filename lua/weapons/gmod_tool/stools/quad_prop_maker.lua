TOOL.Category = "Construction"
TOOL.Name = "Quad Prop Maker"

TOOL.ClientConVar["wall_dist"] = 1

TOOL.Information = {
    { name = "left_0", stage = 0, op = 0 },
    { name = "left_1", stage = 1, op = 1 },
    { name = "left_1_use", stage = 1, op = 1 },
    { name = "right_0", stage = 0, op = 0 },
    { name = "right_1", stage = 1, op = 2 },
    { name = "right_1_use", stage = 1, op = 2 },
    { name = "right_2", stage = 2, op = 2 },
    { name = "reload" },
}


if CLIENT then
    language.Add( "tool.quad_prop_maker.name", "Quad Prop Maker" )
    language.Add( "tool.quad_prop_maker.desc", "Creates quad props" )
    language.Add( "tool.quad_prop_maker.left_0", "Select the first corner (aligns with the surface)" )
    language.Add( "tool.quad_prop_maker.left_1", "Select the second corner" )
    language.Add( "tool.quad_prop_maker.left_1_use", "Select the second corner (rotates with your aim, use on floors/ceilings)" )
    language.Add( "tool.quad_prop_maker.right_0", "Select the first corner (aligns vertically)" )
    language.Add( "tool.quad_prop_maker.right_1", "Determine the width" )
    language.Add( "tool.quad_prop_maker.right_1_use", "Determine the width (ignore line of sight)" )
    language.Add( "tool.quad_prop_maker.right_2", "Determine the height" )
    language.Add( "tool.quad_prop_maker.reload", "Remove a quad prop" )

    language.Add( "tool.quad_prop_maker.wall_dist", "Wall Distance" )
    language.Add( "tool.quad_prop_maker.wall_dist.help", "How far away from the wall/floor to spawn the quad prop" )
end


local VECTOR_ZERO = Vector( 0, 0, 0 )
local VECTOR_UP = Vector( 0, 0, 1 )
local VECTOR_UP_LONGER = Vector( 0, 0, 10 )
local ANGLE_ZERO = Angle( 0, 0, 0 )
local SIZE_MAX = QuadProps.SIZE_MAX
local THICKNESS = QuadProps.THICKNESS

local PREVIEW_MAT = CLIENT and Material( "color" )
local PREVIEW_COLOR_BOX = Color( 255, 255, 255, 50 )
local PREVIEW_COLOR_BOX_WIREFRAME = Color( 255, 255, 255, 255 )
local PREVIEW_COLOR_PLANE = Color( 0, 255, 255, 25 )
local PREVIEW_COLOR_LINE = Color( 255, 255, 0, 255 )

local PREVIEW_PLANE_MINS = Vector( -SIZE_MAX, -SIZE_MAX, 0 )
local PREVIEW_PLANE_MAXS = Vector( SIZE_MAX, SIZE_MAX, 0 )

local mathAbs = math.abs
local mathMin = math.min


local function mathSign( x )
    return x > 0 and 1 or x < 0 and -1 or 0
end

local function getTraceStartAndDir( tr )
    local startPos = tr.StartPos
    local fromTo = tr.HitPos - startPos
    local fromToLength = fromTo:Length()
    if fromToLength == 0 then return end

    return startPos, fromTo / fromToLength
end

local function lineIntersectPlane( lineOrigin, lineDir, planeOrigin, planeNormal )
    local lineDotNormal = lineDir:Dot( planeNormal )

    if lineDotNormal == 0 then
        if ( planeOrigin - lineOrigin ):Dot( planeNormal ) == 0 then
            return lineOrigin
        else
            return false
        end
    end

    local dist = ( planeOrigin - lineOrigin ):Dot( planeNormal ) / lineDotNormal

    return lineOrigin + lineDir * dist
end

local function resetStencil()
    render.SetStencilWriteMask( 0xFF )
    render.SetStencilTestMask( 0xFF )
    render.SetStencilReferenceValue( 0 )
    render.SetStencilCompareFunction( STENCIL_ALWAYS )
    render.SetStencilPassOperation( STENCIL_KEEP )
    render.SetStencilFailOperation( STENCIL_KEEP )
    render.SetStencilZFailOperation( STENCIL_KEEP )
    render.ClearStencil()
end


function TOOL:LeftClick( tr )
    if self:GetOperation() == 2 then return false end

    if self:GetStage() == 0 then
        local hitNormal = tr.HitNormal
        if hitNormal == VECTOR_ZERO then return false end

        self:SetObject( 0, game.GetWorld(), tr.HitPos, nil, 0, hitNormal )
        self:SetOperation( 1 )
        self:SetStage( 1 )
    else
        if CLIENT then return true end

        local ent = self:MakeQuadProp( tr )
        if not ent then return false end
    end

    return true
end

function TOOL:RightClick( tr )
    if self:GetOperation() == 1 then return false end

    local stage = self:GetStage()

    if stage == 0 then
        self:SetObject( 0, game.GetWorld(), tr.HitPos, nil, 0, tr.HitNormal )
        self:SetOperation( 2 )
        self:SetStage( 1 )
    elseif stage == 1 then
        local eyePos, eyeDir = getTraceStartAndDir( tr )
        if not eyePos then return false end

        local cornerPos1 = self:GetPos( 0 )
        local cornerPos3

        if self:GetOwner():KeyDown( IN_USE ) then
            cornerPos3 = lineIntersectPlane( eyePos, eyeDir, cornerPos1, VECTOR_UP )
        else
            local hitPos = tr.HitPos

            cornerPos3 = Vector( hitPos[1], hitPos[2], cornerPos1[3] )
        end

        local corner1To3 = cornerPos3 - cornerPos1
        local corner1To3Length = corner1To3:Length()
        if corner1To3Length < 1 then return false end

        local corner1To3Dir = corner1To3 / corner1To3Length
        local cornerNormal3 = corner1To3Dir:Angle():Right()

        self:SetObject( 1, game.GetWorld(), cornerPos3, nil, 0, cornerNormal3 )
        self:SetOperation( 2 )
        self:SetStage( 2 )
    else
        if CLIENT then return true end

        local ent = self:MakeQuadProp( tr )
        if not ent then return false end
    end

    return true
end

function TOOL:Reload( tr )
    local ent = tr.Entity
    if not IsValid( ent ) then return false end
    if ent:GetClass() ~= "quad_prop" then return false end

    if CLIENT then return true end

    ent:Remove()

    return true
end

function TOOL:Holster()
    self:ClearObjects()
    self:StopPreview()
end

function TOOL:Deploy()
    self:StartPreview()

    return true
end

function TOOL.BuildCPanel( cPanel )
    cPanel:AddControl( "Slider", { Label = "#tool.quad_prop_maker.wall_dist", Command = "quad_prop_maker_wall_dist", Type = "Float", Min = 0, Max = 10000, Help = true } )
end


function TOOL:CalcSpawnInfo( tr )
    local op = self:GetOperation()
    if op == 0 then return end

    local stage = self:GetStage()
    if stage == 0 then return end

    tr = tr or self:GetOwner():GetEyeTrace()

    local wallDist = self:GetClientNumber( "wall_dist", 1 )
    local cornerPos1 = self:GetPos( 0 )
    local cornerNormal1 = self:GetNormal( 0 )
    local pos, ang, width, height
    local cornerPos2, corner1To2

    local eyePos, eyeDir = getTraceStartAndDir( tr )
    if not eyePos then return end

    if op == 1 then
        -- Use the first surface to orient the quad
        cornerPos2 = lineIntersectPlane( eyePos, eyeDir, cornerPos1, cornerNormal1 )
        if not cornerPos2 then return end

        corner1To2 = cornerPos2 - cornerPos1

        local upDir

        if self:GetOwner():KeyDown( IN_USE ) then
            -- Project the eye direction onto the plane and use it as the up direction
            -- Ideal for use on floors and ceilings
            upDir = eyeDir - eyeDir:Dot( cornerNormal1 ) * cornerNormal1 -- Project eyeDir onto the plane

            local upDirLength = upDir:Length()
            if upDirLength == 0 then return end

            upDir = upDir / upDirLength
        else
            -- Use default up direction according to gmod
            -- Ideal for use on walls
            upDir = cornerNormal1:Angle():Up()
        end

        ang = cornerNormal1:AngleEx( upDir )
    else
        -- Force the quad to always stand up vertically, using three corners
        local cornerPos3

        if stage == 1 then
            if self:GetOwner():KeyDown( IN_USE ) then
                cornerPos3 = lineIntersectPlane( eyePos, eyeDir, cornerPos1, VECTOR_UP )
            else
                local hitPos = tr.HitPos

                cornerPos3 = Vector( hitPos[1], hitPos[2], cornerPos1[3] )
            end

            if not cornerPos3 then return end

            cornerPos2 = cornerPos3 + VECTOR_UP_LONGER
        else
            local cornerNormal3 = self:GetNormal( 1 )

            cornerPos3 = self:GetPos( 1 )
            local heightPoint = lineIntersectPlane( eyePos, eyeDir, cornerPos3, cornerNormal3 )
            if not heightPoint then return end

            cornerPos2 = Vector( cornerPos3[1], cornerPos3[2], heightPoint[3] )
        end

        corner1To2 = cornerPos2 - cornerPos1
        local corner1To2Length = corner1To2:Length()
        if corner1To2Length < 1 then return end

        local corner1To2Dir = corner1To2 / corner1To2Length

        -- The quad's forward (the normal of the plane it represents) could either be the right or left of the corner diff.
        local forwardDirA = corner1To2Dir:Angle():Right()
        local forwardDirB = -forwardDirA

        -- Choose a forward based on whichever opposes the player's eyes more
        local forwardDirDotA = forwardDirA:Dot( eyeDir )
        local forwardDirDotB = forwardDirB:Dot( eyeDir )
        local forwardDir = forwardDirDotA <= forwardDirDotB and forwardDirA or forwardDirB

        ang = forwardDir:Angle()
    end

    local rightDir = ang:Right()
    local upDir = ang:Up()
    local corner1To2DotRight = corner1To2:Dot( rightDir )
    local corner1To2DotUp = corner1To2:Dot( upDir )

    pos = ( cornerPos1 + cornerPos2 ) / 2
    width = mathAbs( corner1To2DotRight )
    height = mathAbs( corner1To2DotUp )

    if width < 1 or height < 1 then return end

    -- Clamp the size and adjust the position accordingly
    if width > SIZE_MAX or height > SIZE_MAX then
        width = mathMin( width, SIZE_MAX )
        height = mathMin( height, SIZE_MAX )

        pos = cornerPos1 + rightDir * mathSign( corner1To2DotRight ) * width / 2
        pos = pos + upDir * mathSign( corner1To2DotUp ) * height / 2
    end

    pos = pos + ang:Forward() * wallDist

    return pos, ang, width, height
end

function TOOL:MakeQuadProp( tr )
    local pos, ang, width, height = self:CalcSpawnInfo( tr )
    if not pos then return false end

    local owner = self:GetOwner()
    if not owner:CheckLimit( "quad_prop" ) then return false end

    local ent = ents.Create( "quad_prop" )
    if not IsValid( ent ) then return false end

    ent:SetPos( pos )
    ent:SetAngles( ang )
    ent:Spawn()

    ent:SetSquare( false )
    ent:SetSize( width, height )
    ent:SetDoubleSided( false )
    if CPPI then ent:CPPISetOwner( owner ) end

    owner:AddCount( "quad_prop", ent )
    owner:AddCleanup( "quad_prop", ent )

    undo.Create( "quad_prop" )
        undo.SetPlayer( owner )
        undo.AddEntity( ent )
    undo.Finish( "quad_prop" )

    self:ClearObjects()

    return ent
end

function TOOL:StartPreview()
    if SERVER then return end

    local selfObj = self

    hook.Add( "PostDrawOpaqueRenderables", "QuadProps_Toolgun_QuadPropMaker_DrawPreview", function( _, skybox, skybox3d )
        if skybox or skybox3d then return end

        local wep = selfObj:GetWeapon()
        if not IsValid( wep ) or wep:GetMode() ~= "quad_prop_maker" then
            selfObj:StopPreview()

            return
        end

        if selfObj:GetStage() == 0 then return end

        local tr = LocalPlayer():GetEyeTrace()
        local pos, ang, width, height = selfObj:CalcSpawnInfo( tr )
        if not pos then return end

        local maxs = Vector( THICKNESS / 2, width / 2, height / 2 )

        render.SetMaterial( PREVIEW_MAT )

        -- Extra preview helpers
        if selfObj:GetOperation() == 2 and selfObj:GetStage() == 1 then
            local cornerPos1 = selfObj:GetPos( 0 )

            render.DrawBox( cornerPos1 + VECTOR_UP, ANGLE_ZERO, PREVIEW_PLANE_MINS, PREVIEW_PLANE_MAXS, PREVIEW_COLOR_PLANE )

            if not LocalPlayer():KeyDown( IN_USE ) then
                local cornerPos1ToCenter = pos - cornerPos1
                cornerPos1ToCenter[3] = 0
                local cornerPos3 = cornerPos1 + cornerPos1ToCenter * 2

                render.DrawLine( tr.HitPos, cornerPos3, PREVIEW_COLOR_LINE, false )
            end
        end

        resetStencil()

        render.SetStencilEnable( true )
        render.SetStencilReferenceValue( 1 )
        render.SetStencilCompareFunction( STENCIL_ALWAYS )
        render.SetStencilZFailOperation( STENCIL_REPLACE )

        -- Draw preview
        render.DrawBox( pos, ang, -maxs, maxs, PREVIEW_COLOR_BOX )
        render.DrawWireframeBox( pos, ang, -maxs, maxs, PREVIEW_COLOR_BOX_WIREFRAME, false )

        render.SetStencilCompareFunction( STENCIL_EQUAL )
        render.ClearBuffersObeyStencil( 255, 0, 0, 255, false )

        render.SetStencilEnable( false )
    end )
end

function TOOL:StopPreview()
    if SERVER then return end

    hook.Remove( "PostDrawOpaqueRenderables", "QuadProps_Toolgun_QuadPropMaker_DrawPreview" )
end
