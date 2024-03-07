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


local SIZE_MAX = 1000
local THICKNESS = 1

local THICKNESS_HALF = THICKNESS / 2

local delaySizeUpdate


function ENT:SetupDataTables()
    self:NetworkVar( "Int",     0, "NWQuadWidth",    { KeyName = "quad_width",    Edit = { type = "Int",     title = "Width",        order = 1, min = 1, max = SIZE_MAX } } )
    self:NetworkVar( "Int",     1, "NWQuadHeight",   { KeyName = "quad_height",   Edit = { type = "Int",     title = "Height",       order = 2, min = 1, max = SIZE_MAX } } )
    self:NetworkVar( "Bool",    0, "NWQuadSquare",   { KeyName = "quad_square",   Edit = { type = "Boolean", title = "Square",       order = 3,                         } } )
    self:NetworkVar( "String",  0, "NWQuadMaterial", { KeyName = "quad_material", Edit = { type = "Generic", title = "Material/URL", order = 4, waitforenter = true     } } )

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
                ent:SetNWQuadHeight( math.min( width, height ) )
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
            ent:_SetMaterial( path )
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

    local hitPos, hitNormal, frac = util.IntersectRayWithOBB( startPos, delta, self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs() )
    if not hitPos then return end

    return {
        HitPos = hitPos,
        Normal = hitNormal,
        Fraction = frac,
    }
end


----- PRIVATE FUNCTIONS -----

delaySizeUpdate = function( ent )
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end

        ent:_SizeChanged()
    end )
end
