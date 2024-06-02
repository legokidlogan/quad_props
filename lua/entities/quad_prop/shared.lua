ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "QuadProp"
ENT.Author          = "legokidlogan"
ENT.Contact         = "https://github.com/legokidlogan/quad_props"
ENT.Purpose         = "A resizable quad which can display any material or url image."
ENT.Instructions    = ""
ENT.Category        = "Other"

ENT.Spawnable       = true
ENT.Model           = "models/hunter/blocks/cube1x1x1.mdl"
ENT.Editable        = true


local SIZE_MAX = QuadProps.SIZE_MAX
local THICKNESS = QuadProps.THICKNESS

local THICKNESS_HALF = THICKNESS / 2

local delaySizeUpdate


function ENT:SetupDataTables()
    self:NetworkVar( "Float",   0, "NWQuadWidth",          { KeyName = "quad_width",        Edit = { type = "Float",   title = "Width",        order = 1, min = 1, max = SIZE_MAX } } )
    self:NetworkVar( "Float",   1, "NWQuadHeight",         { KeyName = "quad_height",       Edit = { type = "Float",   title = "Height",       order = 2, min = 1, max = SIZE_MAX } } )
    self:NetworkVar( "Bool",    0, "NWQuadSquare",         { KeyName = "quad_square",       Edit = { type = "Boolean", title = "Square",       order = 3,                         } } )
    self:NetworkVar( "Bool",    1, "NWQuadDoubleSided",    { KeyName = "quad_double_sided", Edit = { type = "Boolean", title = "Double Sided", order = 4,                         } } )
    self:NetworkVar( "String",  0, "NWQuadMaterial",       { KeyName = "quad_material",     Edit = { type = "Generic", title = "Material/URL", order = 5, waitforenter = true     } } )

    if SERVER then
        -- gmod jank forcing my hand with all these timers...
        self:NetworkVarNotify( "NWQuadWidth", function( ent, _, _, width )
            if ent:GetNWQuadSquare() then
                if ent:GetNWQuadHeight() == width then return end

                timer.Simple( 0, function()
                    if not IsValid( ent ) then return end

                    ent:SetNWQuadHeight( width )
                    ent:_SizeChanged()
                end )
            else
                delaySizeUpdate( ent )
            end
        end )

        self:NetworkVarNotify( "NWQuadHeight", function( ent, _, _, height )
            if ent:GetNWQuadSquare() then
                if ent:GetNWQuadWidth() == height then return end

                timer.Simple( 0, function()
                    if not IsValid( ent ) then return end

                    ent:SetNWQuadWidth( height )
                    ent:_SizeChanged()
                end )
            else
                delaySizeUpdate( ent )
            end
        end )

        self:NetworkVarNotify( "NWQuadSquare", function( ent, _, _, isSquare )
            if not isSquare then return end

            local width = ent:GetNWQuadWidth()
            local height = ent:GetNWQuadHeight()

            if width ~= height then
                local size = math.min( width, height )

                ent:SetNWQuadWidth( size )
                ent:SetNWQuadHeight( size )
            end
        end )
    else
        self:NetworkVarNotify( "NWQuadWidth", function( ent )
            delaySizeUpdate( ent )
        end )

        self:NetworkVarNotify( "NWQuadHeight", function( ent )
            delaySizeUpdate( ent )
        end )

        self:NetworkVarNotify( "NWQuadMaterial", function( ent, _, _, path )
            ent:_SetMaterialInternal( path )
        end )
    end
end

function ENT:GetQuadBounds()
    local width = self:GetNWQuadWidth()
    local height = self:GetNWQuadHeight()

    if self._boundsWidth == width and self._boundsHeight == height then
        return self._boundsMin, self._boundsMax
    end

    local widthHalf = width / 2
    local heightHalf = height / 2

    local boundsMin = Vector( -THICKNESS_HALF, -widthHalf, -heightHalf )
    local boundsMax = Vector( THICKNESS_HALF, widthHalf, heightHalf )

    self._boundsWidth = width
    self._boundsHeight = height

    self._boundsMin = boundsMin
    self._boundsMax = boundsMax

    return boundsMin, boundsMax
end

function ENT:TestCollision( startPos, delta, isbox )
    if isbox then return end

    local ang = self:GetAngles()

    local hitPos, hitNormal, frac = util.IntersectRayWithOBB( startPos, delta, self:GetPos(), ang, self:OBBMins(), self:OBBMaxs() )
    if not hitPos then return end

    hitNormal:Rotate( ang ) -- Fix bug with util.IntersectRayWithOBB()

    return {
        HitPos = hitPos,
        Normal = hitNormal,
        Fraction = frac,
    }
end

function ENT:SetWidth( width )
    if self:IsSquare() then
        self:SetSize( width, width )

        return
    end

    width = math.Clamp( width, 1, SIZE_MAX )

    self:SetNWQuadWidth( width )
    self:_SizeChanged()
end

function ENT:GetWidth()
    return self:GetNWQuadWidth()
end

function ENT:SetHeight( height )
    if self:IsSquare() then
        self:SetSize( height, height )

        return
    end

    height = math.Clamp( height, 1, SIZE_MAX )

    self:SetNWQuadHeight( height )
    self:_SizeChanged()
end

function ENT:GetHeight()
    return self:GetNWQuadHeight()
end

function ENT:SetSize( width, height )
    if QuadProps.ShouldLimitSizeForQuadProp( self ) then
        width = math.Clamp( width, 1, SIZE_MAX )
        height = math.Clamp( height, 1, SIZE_MAX )
    else
        width = math.max( width, 1 )
        height = math.max( height, 1 )
    end

    if self:IsSquare() then
        local minSize = math.min( width, height )
        width = minSize
        height = minSize
    end

    self:SetNWQuadWidth( width )
    self:SetNWQuadHeight( height )

    self:_SizeChanged()
end

function ENT:GetSize()
    return self:GetWidth(), self:GetHeight()
end

function ENT:SetSquare( isSquare )
    if isSquare == self:GetNWQuadSquare() then return end

    self:SetNWQuadSquare( isSquare )

    if isSquare then
        local minSize = math.min( self:GetSize() )
        self:SetSize( minSize, minSize )
    end
end

function ENT:IsSquare()
    return self:GetNWQuadSquare()
end

function ENT:SetDoubleSided( state )
    self:SetNWQuadDoubleSided( state )
end

function ENT:IsDoubleSided()
    return self:GetNWQuadDoubleSided()
end

----- PRIVATE FUNCTIONS -----

delaySizeUpdate = function( ent )
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end

        ent:_SizeChanged()
    end )
end
