AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "base_gmodentity" )


include( "quad_props/globals.lua" )


local THICKNESS = QuadProps.THICKNESS
local RESIZE_COOLDOWN = QuadProps.RESIZE_COOLDOWN

local THICKNESS_HALF = THICKNESS / 2

local quadPropMeta = nil
local entity_SetCollisionGroup = nil

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
    self:SetDoubleSided( self:IsDoubleSided() )
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
    path = path or ""
    path = hook.Run( "QuadProps_SetMaterial", self, path ) or path

    self:SetNWQuadMaterial( path )
end

function ENT:GetMaterial()
    return self:GetNWQuadMaterial()
end

function ENT:_SizeChanged()
    if not self:_ResizeCooldownCheck() then return end

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

-- Resize cooldown to prevent spamming the server with physics updates.
function ENT:_ResizeCooldownCheck()
    -- Already on full cooldown, disallow.
    if self._quadProps_resizeCooldownFull then return false end

    local resizeCooldownEndTime = self._quadProps_resizeCooldownEndTime
    local now = CurTime()

    if resizeCooldownEndTime then
        -- Cooldown has expired, add cooldown and allow.
        if now > resizeCooldownEndTime then
            self._quadProps_resizeCooldownEndTime = now + RESIZE_COOLDOWN

            return true
        end

        -- First time trying while on cooldown, mark as full and make a timer to update size when the cooldown ends.
        self._quadProps_resizeCooldownFull = true

        timer.Simple( resizeCooldownEndTime - now, function()
            if not IsValid( self ) then return end

            self._quadProps_resizeCooldownEndTime = nil
            self._quadProps_resizeCooldownFull = nil
            self:_SizeChanged()
        end )
    else
        -- Hasn't been put on cooldown yet, add cooldown and allow.
        self._quadProps_resizeCooldownEndTime = now + RESIZE_COOLDOWN
    end

    return true
end

function ENT:OnDuplicated( data )
    local DT = data.DT
    if not DT then return end

    self:SetSquare( DT.NWQuadSquare or false )
    self:SetSize( DT.NWQuadWidth or 50, DT.NWQuadHeight or 50 )
    self:SetDoubleSided( DT.NWQuadDoubleSided or false )
end


----- PRIVATE FUNCTIONS -----

-- Sadly, this is the only way to wrap :SetCollisionGroup() and similar function without wrapping the entire Entity metatable.
wrapMeta = function( quadProp )
    if not quadPropMeta then
        local entMeta = FindMetaTable( "Entity" )
        entity_SetCollisionGroup = entMeta.SetCollisionGroup

        local classMeta = baseclass.Get( "quad_prop" )

        quadPropMeta = QuadProps._QuadPropMeta
        rawset( quadPropMeta, "SetCollisionGroup", classMeta.SetCollisionGroup )
        rawset( quadPropMeta, "SetMaterial", classMeta.SetMaterial )
        rawset( quadPropMeta, "GetMaterial", classMeta.GetMaterial )
    end

    debug.setmetatable( quadProp, quadPropMeta )
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
