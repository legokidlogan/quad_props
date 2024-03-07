include( "shared.lua" )

DEFINE_BASECLASS( "base_gmodentity" )

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT


local entMeta = nil
local classMeta = nil

local wrapMeta


function ENT:Initialize()
    wrapMeta( self )

    self.BaseClass.Initialize( self )

    self:SetMaterial( self:GetMaterial() )
    self:_SizeChanged()
end

function ENT:GetWidth()
    return self:GetNWQuadWidth()
end

function ENT:GetHeight()
    return self:GetNWQuadHeight()
end

function ENT:GetSize()
    return self:GetWidth(), self:GetHeight()
end

function ENT:_SizeChanged()
    self:SetRenderBounds( self:GetQuadBounds() )
end

function ENT:IsSquare()
    return self:GetNWQuadSquare()
end

function ENT:SetMaterial( path )
    self:_SetMaterial( path )
    self:SetNWQuadMaterial( path )
end

function ENT:_SetMaterial( path )
    self._materialObject = QuadProps.AcquireMaterial( self, path or "" )
end

function ENT:GetMaterial()
    return self:GetNWQuadMaterial()
end

function ENT:GetMaterialObject()
    return self._materialObject
end

function ENT:Draw()
    self:DrawQuad()
end

function ENT:DrawTranslucent()
    self:DrawQuad()
end

function ENT:DrawQuad()
    local mat = self:GetMaterialObject()
    local pos = self:GetPos()
    local ang = self:GetAngles()
    local width, height = self:GetSize()
    local color = self:GetColor()

    local normal = ang:Forward()
    local roll = ang[3] + 180

    render.SetMaterial( mat )
    render.DrawQuadEasy( pos, normal, width, height, color, roll )
end


----- PRIVATE FUNCTIONS -----

-- Sadly, this is the only way to wrap :SetCollisionGroup() and similar function without wrapping the entire Entity metatable.
wrapMeta = function( quadProp )
    if not entMeta then
        entMeta = FindMetaTable( "Entity" )
        entity_SetMaterial = entMeta.SetMaterial

        classMeta = baseclass.Get( "quad_prop" )
    end

    local index = rawget( entMeta, "__index" ) or function() end
    local newindex = rawget( entMeta, "__newindex" ) or function() end
    local meta = {
        __tostring = rawget( entMeta, "__tostring" ),

        SetMaterial = classMeta.SetMaterial,
        GetMaterial = classMeta.GetMaterial,
    }

    meta.__index = function( self, key )
        local override = meta[key]
        if override ~= nil then return override end

        return index( self, key )
    end

    meta.__newindex = function( self, key, value )
        local override = meta[key]
        if override ~= nil then return override( self, key, value ) end

        return newindex( self, key, value )
    end

    debug.setmetatable( quadProp, meta )
end

