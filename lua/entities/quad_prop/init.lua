AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "base_gmodentity" )


local THICKNESS = 1

local THICKNESS_HALF = THICKNESS / 2

local entMeta = nil
local entity_SetCollisionGroup = nil
local classMeta = nil

local wrapMeta
local makeQuadProp


function ENT:Initialize()
    wrapMeta( self )

    self.BaseClass.Initialize( self )

    self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
    self:SetModel( self.Model )
    self:DrawShadow( false )
    self:SetCollisionGroup( COLLISION_GROUP_WORLD )
    self:SetSquare( self:IsSquare() ) -- gmod moment
    self:SetSize( self:GetSize() )
    self:SetMaterial( "" )
end

function ENT:SpawnFunction( ply, tr )
    if not tr.Hit then return end

    local normal = tr.HitNormal
    local pos = tr.HitPos + normal * THICKNESS_HALF

    local ent = makeQuadProp( ply, {
        Pos = pos,
        Angle = normal:Angle(),
    } )

    if IsValid( ent ) then
        ent:SetSize( 50, 50 )
        ent:SetSquare( true )
    end

    return ent
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:SetCollisionGroup()
    -- Always force this collision group
    entity_SetCollisionGroup( self, COLLISION_GROUP_WORLD )
end

function ENT:SetMaterial( path )
    self:SetNWQuadMaterial( path or "" )
end

function ENT:GetMaterial()
    return self:GetNWQuadMaterial()
end

function ENT:_SizeChanged()
    local oldPhysObj = self:GetPhysicsObject()
    local motionEnabled = false

    if IsValid( oldPhysObj ) then
        motionEnabled = oldPhysObj:IsMotionEnabled()
    end

    self:PhysicsInitBox( self:GetQuadBounds() )
    self:SetSolid( SOLID_OBB )
    self:EnableCustomCollisions()

    local physObj = self:GetPhysicsObject()

    if IsValid( physObj ) then
        physObj:EnableMotion( motionEnabled )
        physObj:Wake()
    end
end

function ENT:OnDuplicated( data )
    local DT = data.DT
    if not DT then return end

    self:SetSquare( DT.NWQuadSquare or false )
    self:SetSize( DT.NWQuadWidth or 50, DT.NWQuadHeight or 50 )
end


----- PRIVATE FUNCTIONS -----

-- Sadly, this is the only way to wrap :SetCollisionGroup() and similar function without wrapping the entire Entity metatable.
wrapMeta = function( quadProp )
    if not entMeta then
        entMeta = FindMetaTable( "Entity" )
        entity_SetCollisionGroup = entMeta.SetCollisionGroup

        classMeta = baseclass.Get( "quad_prop" )
    end

    local index = rawget( entMeta, "__index" ) or function() end
    local newindex = rawget( entMeta, "__newindex" ) or function() end
    local meta = {
        __tostring = rawget( entMeta, "__tostring" ),

        SetCollisionGroup = classMeta.SetCollisionGroup,
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

makeQuadProp = function( ply, data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "quad_prop" ) then return end

    local ent = ents.Create( "quad_prop" )
    if not ent:IsValid() then return end

    duplicator.DoGeneric( ent, data )
    ent:Spawn()
    ent:Activate()

    duplicator.DoGenericPhysics( ent, ply, data )

    if validPly then
        ply:AddCount( "quad_prop", ent )
        ply:AddCleanup( "quad_prop", ent )
    end

    return ent
end


----- SETUP -----

duplicator.RegisterEntityClass( "quad_prop", makeQuadProp, "Data" )


hook.Add( "CanEditVariable", "QuadProps_CanEdit", function( ent, ply, key, val )
    if not IsValid( ent ) or ent:GetClass() ~= "quad_prop" then return end
    if key == "quad_material" and string.len( val ) > 400 then return false end -- length limit for urls
    if ply:IsSuperAdmin() then return true end
    if ent.CPPICanTool then return ent:CPPICanTool( ply, "" ) end

    return ent:GetOwner() == ply
end )
