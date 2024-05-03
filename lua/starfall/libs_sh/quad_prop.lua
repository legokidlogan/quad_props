include( "quad_props/create_meta.lua" )


local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege
local IsValid = FindMetaTable( "Entity" ).IsValid

registerprivilege( "quadprop.modify", "Modify quadprops", "Allows the user to modify quadprops", { entities = {} } )
registerprivilege( "quadprop.create", "Create quadprop", "Allows the user to create quadprops", CLIENT and { client = {} } or nil )
registerprivilege( "quadprop.setRenderProperty", "RenderProperty", "Allows the user to change the rendering of an entity", { entities = {} } )

local entList = SF.EntManager( "quadprops", "quadprops", 10, "The number of quadprops allowed to spawn via Starfall scripts for a single player" )

SF.ResourceCounters.QuadProps = { icon = "icon16/bricks.png", count = function( ply ) return entList:get( ply ) end }

local realQuadPropMeta = QuadProps._QuadPropMeta

if CLIENT then
    SF.Cl_QuadProp_Meta = {
        __index = function( t, k, v )
            if k == "CPPIGetOwner" then return function( ent ) return ent.SFQuadPropOwner end
            elseif k == "CPPICanTool" then return function( ent, pl ) return ent.SFQuadPropOwner == pl end
            elseif k == "CPPICanPhysgun" then return function( ent, pl ) return ent.SFQuadPropOwner == pl end
            else return realQuadPropMeta.__index( t, k, v )
            end
        end,
        __newindex = realQuadPropMeta.__newindex,
        __concat = realQuadPropMeta.__concat,
        __tostring = realQuadPropMeta.__tostring,
        __eq = realQuadPropMeta.__eq,
    }
end


--- Library for creating resizable 2D-3D planes, AKA "Quad Props"
-- @name quadprop
-- @class library
-- @libtbl quadprop_library
SF.RegisterLibrary( "quadprop" )

--- QuadProp type
-- @name QuadProp
-- @class type
-- @libtbl quadprop_methods
SF.RegisterType( "QuadProp", true, false, realQuadPropMeta, "Entity" )



return function( instance )
local checkpermission = instance.player ~= SF.Superuser and SF.Permissions.check or function() end


local quadprop_library = instance.Libraries.quadprop
local quadprop_methods, quadprop_meta, wrap, unwrap = instance.Types.QuadProp.Methods, instance.Types.QuadProp, instance.Types.QuadProp.Wrap, instance.Types.QuadProp.Unwrap
local ents_methods, ent_meta, ewrap, eunwrap = instance.Types.Entity.Methods, instance.Types.Entity, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
local ang_meta, awrap, aunwrap = instance.Types.Angle, instance.Types.Angle.Wrap, instance.Types.Angle.Unwrap
local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap

local material_methods, material_meta, mwrap, munwrap
local lmunwrap

if CLIENT then
    material_methods, material_meta, mwrap, munwrap = instance.Types.Material.Methods, instance.Types.Material, instance.Types.Material.Wrap, instance.Types.Material.Unwrap
    lmunwrap = instance.Types.LockedMaterial.Unwrap
end

local getent
instance:AddHook( "initialize", function()
    getent = instance.Types.Entity.GetEntity
    quadprop_meta.__tostring = ent_meta.__tostring
end )

instance:AddHook( "deinitialize", function()
    if SERVER or not instance.data.render.isRendering then
        entList:deinitialize( instance, CLIENT or instance.data.props.clean )
    else
        -- Removing objects in render hook = crash
        timer.Simple( 0, function()
            entList:deinitialize( instance, true )
        end )
    end
end )

local function getQP( self )
    local ent = unwrap( self )
    if IsValid( ent ) then
        return ent
    else
        SF.Throw( "Entity is not valid.", 3 )
    end
end

--- Casts a quadprop entity into the quadprop type
-- @shared
-- @return QuadProp QuadProp instance
function ents_methods:toQuadProp()
    local ent = getent( self )
    if not ent.IsSFQuadProp then SF.Throw( "The entity isn't a quadprop", 2 ) end
    return wrap( eunwrap( self ) )
end


--- Creates a quadprop.
-- @param Vector pos The position to create the quadprop
-- @param Angle ang The angle to create the quadprop
-- @param number? width (Optional) The width to give the quadprop (Default 50)
-- @param number? height (Optional) The height to give the quadprop (Default width)
-- @param boolean? frozen (Optional, server only) Whether the quadprop should be frozen (Default false)
-- @return QuadProp The quadprop object
function quadprop_library.create( pos, ang, width, height, frozen )
    checkpermission( instance, nil, "quadprop.create" )

    local ply = instance.player
    pos = vunwrap( pos )
    ang = aunwrap( ang )

    if width == nil then
        width = 50
    else
        checkluatype( width, TYPE_NUMBER )
    end

    if height == nil then
        height = width
    else
        checkluatype( height, TYPE_NUMBER )
    end

    entList:checkuse( ply, 1 )

    local qpEnt
    if SERVER then
        qpEnt = ents.Create( "quad_prop" )
        if IsValid( qpEnt ) then
            qpEnt:SetPos( SF.clampPos( pos ) )
            qpEnt:SetAngles( ang )
            qpEnt:Spawn()

            if CPPI then qpEnt:CPPISetOwner( ply == SF.Superuser and NULL or ply ) end

            qpEnt:SetSquare( false )
            qpEnt:SetSize( width, height )

            if frozen then
                qpEnt:GetPhysicsObject():EnableMotion( false )
            end

            entList:register( instance, qpEnt )

            if instance.data.props.undo then
                undo.Create( "quad_prop" )
                    undo.SetPlayer( ply )
                    undo.AddEntity( qpEnt )
                undo.Finish( "quad_prop" )
            end

            ply:AddCleanup( "quad_prop", qpEnt )

            return wrap( qpEnt )
        end
    else
        qpEnt = ents.CreateClientside( "quad_prop" )
        if IsValid( qpEnt ) then
            qpEnt.SFQuadPropOwner = ply

            qpEnt:SetPos( SF.clampPos( pos ) )
            qpEnt:SetAngles( ang )
            qpEnt:Spawn()

            qpEnt:SetSquare( false )
            qpEnt:SetSize( width, height )

            debug.setmetatable( qpEnt, SF.Cl_QuadProp_Meta )

            entList:register( instance, qpEnt )

            return wrap( qpEnt )
        end
    end
end

--- Checks if a user can spawn anymore quadprops.
-- @return boolean True if user can spawn quadprops, False if not.
function quadprop_library.canSpawn()
    if not SF.Permissions.hasAccess( instance,  nil, "quadprop.create" ) then return false end
    return entList:check( instance.player ) > 0
end

--- Checks how many quadprops can be spawned
-- @return number Number of quadprops able to be spawned
function quadprop_library.quadpropsLeft()
    if not SF.Permissions.hasAccess( instance,  nil, "quadprop.create" ) then return 0 end
    return entList:check( instance.player )
end

if SERVER then
    --- Does nothing. This is a note, rather than a function.
    -- Unlike normal entities, quadprops are always forced to have WORLD as their collision group.
    -- As such, functions like :setNocollideAll() will do nothing as well.
    -- @server
    function quadprop_methods:setCollisionGroup()
    end
else
    --- Sets the quadprop's position.
    -- @shared
    -- @param Vector vec New position
    function quadprop_methods:setPos( vec )
        local quadProp = getQP( self )
        local pos = SF.clampPos( vunwrap( vec ) )
        checkpermission( instance, quadProp, "entities.setRenderProperty" )

        quadProp:SetPos( pos )

        local sfParent = quadProp.sfParent

        if sfParent and IsValid( sfParent.parent ) then
            sfParent:updateTransform()
        end
    end

    --- Sets the quadprop's angles.
    -- @shared
    -- @param Angle ang New angles
    function quadprop_methods:setAngles( ang )
        local quadProp = getQP( self )
        local angle = aunwrap( ang )
        checkpermission( instance, quadProp, "quadprop.setRenderProperty" )

        quadProp:SetAngles( angle )

        local sfParent = quadProp.sfParent

        if sfParent and IsValid( sfParent.parent ) then
            sfParent:updateTransform()
        end
    end

    --- Parents or unparents an entity. Only holograms can be parented to players and, in the CLIENT realm, only clientside holograms or quadprops can be parented.
    -- @param Entity? parent Entity parent (nil to unparent)
    -- @param number|string|nil attachment Optional attachment name or ID.
    -- @param number|string|nil bone Optional bone name or ID. Can't be used at the same time as attachment
    function quadprop_methods:setParent( parent, attachment, bone )
        local child = getQP( self )
        checkpermission( instance, child, "entities.setParent" )

        if CLIENT then
            local meta = debug.getmetatable( child )

            if meta ~= SF.Cl_Hologram_Meta and meta ~= SF.Cl_QuadProp_Meta then
                SF.Throw( "Only clientside holograms or quadprops can be parented in the CLIENT realm!", 2 )
            end
        end

        -- Code taken from starfall/libs_sh/entities.lua
        if attachment ~= nil and bone ~= nil then SF.Throw( "Arguments `attachment` and `bone` are mutually exclusive!", 2 ) end
        if parent ~= nil then
            parent = getent( parent )
            if parent:IsPlayer() and not child.IsSFHologram then SF.Throw( "Only holograms can be parented to players!", 2 ) end
            local param, type
            if bone ~= nil then
                if isstring( bone ) then
                    bone = parent:LookupBone( bone ) or -1
                elseif not isnumber( bone ) then
                    SF.ThrowTypeError( "string or number", SF.GetType( bone ), 2 )
                end
                if bone < 0 or bone > 255 then SF.Throw( "Invalid bone provided!", 2 ) end
                type = "bone"
                param = bone
            elseif attachment ~= nil then
                if CLIENT then SF.Throw( "Parenting to an attachment is not supported in clientside!", 2 ) end
            else
                type = "entity"
            end

            SF.Parent( child, parent, type, param )
        else
            SF.Parent( child )
        end
    end

    local render_GetColorModulation, render_GetBlend = render.GetColorModulation, render.GetBlend
    local render_SetColorModulation, render_SetBlend = render.SetColorModulation, render.SetBlend

    --- Manually draws a quadprop, requires a 3d render context
    -- @client
    -- @param boolean? noTint If true, renders the quadprop without its color and opacity. The default is for quadprops to render with color or opacity, so use this argument if you need that behavior.
    function quadprop_methods:draw( noTint )
        if not instance.data.render.isRendering then SF.Throw( "Not in rendering hook.", 2 ) end

        local quadProp = getQP( self )
        quadProp:SetupBones()

        if noTint then
            quadProp:DrawModel()
        else
            local cr, cg, cb, ca = quadProp:GetColor4Part()
            local ocr, ocg, ocb = render_GetColorModulation()
            local oca = render_GetBlend()

            render_SetColorModulation( cr / 255, cg / 255, cb / 255 )
            render_SetBlend( ca / 255 )

            quadProp:DrawModel()

            render_SetColorModulation( ocr, ocg, ocb )
            render_SetBlend( oca )
        end
    end

    --- Whether or not the quadprop is using a URL path.
    -- @client
    -- @return boolean Whether or not the quadprop is using a URL path.
    function quadprop_methods:isUsingURL()
        return getQP( self ):IsUsingURL()
    end

    --- Use a Material object for the quadprop, instead of a string path.
    -- Make sure the material has $vertexcolor and $vertexalpha, otherwise it may not render correctly. These are also equivalent to flags 16 + 32.
    -- Don't use the VertexLitGeneric shader, lighting does not work on quadprops. Use UnlitGeneric instead.
    -- @client
    -- @param Material? material Material object. If nil, will use the quadprop's default material.
    function quadprop_methods:setCustomMaterial( material )
        local quadProp = getQP( self )

        if not material then
            quadProp:SetMaterial( "" )

            return
        end

        material = lmunwrap( material )
        quadProp:SetCustomMaterial( material )
    end

    --- Whether or not the quadprop is using a custom material.
    -- @client
    -- @return boolean Whether or not the quadprop is using a custom material.
    function quadprop_methods:isUsingCustomMaterial()
        return getQP( self ):IsUsingCustomMaterial()
    end
end

--- Sets the quadprop width and height in game units
-- @shared
-- @param number width The new width.
-- @param number? height The new height. Defaults to width.
function quadprop_methods:setSize( width, height )
    local quadProp = getQP( self )
    checkluatype( width, TYPE_NUMBER )

    if height == nil then
        height = width
    else
        checkluatype( height, TYPE_NUMBER )
    end

    checkpermission( instance, quadProp, "quadprop.setRenderProperty" )

    quadProp:SetSize( width, height )
end

--- Sets the quadprop width in game units
-- @shared
-- @param number width The new width.
function quadprop_methods:setWidth( width )
    local quadProp = getQP( self )
    checkluatype( width, TYPE_NUMBER )

    checkpermission( instance, quadProp, "quadprop.setRenderProperty" )

    quadProp:SetWidth( width )
end

--- Sets the quadprop height in game units
-- @shared
-- @param number height The new height.
function quadprop_methods:setHeight( height )
    local quadProp = getQP( self )
    checkluatype( height, TYPE_NUMBER )

    checkpermission( instance, quadProp, "quadprop.setRenderProperty" )

    quadProp:SetHeight( height )
end

--- Gets the quadprop size.
-- @shared
-- @return number width The width.
-- @return number height The height.
function quadprop_methods:getSize()
    return getQP( self ):GetSize()
end

--- Gets the quadprop width.
-- @shared
-- @return number width The width.
function quadprop_methods:getWidth()
    return getQP( self ):GetWidth()
end

--- Gets the quadprop height.
-- @shared
-- @return number height The height.
function quadprop_methods:getHeight()
    return getQP( self ):GetHeight()
end

--- Sets whether or not the quadprop should be double-sided.
-- @shared
-- @param boolean doubleSided Self-explanatory.
function quadprop_methods:setDoubleSided( state )
    local quadProp = getQP( self )
    checkluatype( state, TYPE_BOOL )

    quadProp:SetDoubleSided( state )
end

--- Gets whether or not the quadprop is double-sided.
-- @shared
-- @return boolean doubleSided Self-explanatory.
function quadprop_methods:isDoubleSided()
    return getQP( self ):IsDoubleSided()
end

--- Sets the material path of a quadprop
-- Can be a regular material path or an image URL
-- @param string material string material path
function quadprop_methods:setMaterial( material )
    checkluatype( material, TYPE_STRING )

    if not string.StartsWith( material, "http" ) and SF.CheckMaterial( material ) == false then SF.Throw( "This material is invalid", 2 ) end

    local quadProp = getQP( self )

    if SERVER and quadProp == instance.player then
        checkpermission( instance, quadProp, "entities.setPlayerRenderProperty" )
    else
        checkpermission( instance, quadProp, "quadprop.setRenderProperty" )
    end

    quadProp:SetMaterial( material )

    if SERVER then duplicator.StoreEntityModifier( quadProp, "material", { MaterialOverride = material } ) end
end

--- Gets the material path of a quadprop
-- On client, this will be an empty string if the quadprop is using a custom material.
-- @return string material path
function quadprop_methods:getMaterial()
    return getQP( self ):GetMaterial()
end

--- Removes a quadprop
-- @shared
function quadprop_methods:remove()
    if CLIENT and instance.data.render.isRendering then SF.Throw( "Cannot remove while in rendering hook!", 2 ) end

    local quadProp = getQP( self )
    if not ( IsValid( quadProp ) and quadProp.IsSFQuadProp ) then SF.Throw( "Invalid quadprop!", 2 ) end

    checkpermission( instance, quadProp, "quadprop.create" )
    entList:remove( instance, quadProp )
end

--- Removes all quadprops created by the calling chip
-- @shared
function quadprop_library.removeAll()
    if CLIENT and instance.data.render.isRendering then SF.Throw( "Cannot remove while in rendering hook!", 2 ) end

    entList:clear( instance )
end


end