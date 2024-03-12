include( "shared.lua" )

DEFINE_BASECLASS( "base_gmodentity" )

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT


local MATERIAL_ERROR = Material( "error" )

local entMeta = nil
local classMeta = nil
local rtIncr = 0

local wrapMeta
local getQuadCorners


function ENT:Initialize()
    wrapMeta( self )

    self.BaseClass.Initialize( self )

    self:SetMaterial( self:GetMaterial() )
    self:_SizeChanged()
end

function ENT:_SizeChanged()
    self:SetRenderBounds( self:GetQuadBounds() )
end

function ENT:SetMaterial( path )
    self:_SetMaterialInternal( path )
    self:SetNWQuadMaterial( path )
end

function ENT:_SetMaterialInternal( path )
    local rtName = self._rtName
    path = path or ""

    if rtName then
        hook.Remove( "PreRender", "QuadProps_DrawCustomRT_" .. rtName )
    end

    self._usingCustomMaterial = false
    self._usingCustomRT = false
    self._rtName = nil
    self._usingURL = string.StartsWith( path, "http" )
    self._materialObject = QuadProps.AcquireMaterial( self, path )
end

function ENT:GetMaterial()
    return self:GetNWQuadMaterial()
end

function ENT:GetMaterialObject()
    return self._materialObject
end

function ENT:IsUsingURL()
    return self._usingURL
end

--[[
    - Sets a custom material object instead of a material/url path.
    - Make sure your material has $vertexcolor and $vertexalpha.
        - These can be set during material creation or with mat:SetInt( "$flags", 16 + 32 )
    - Make sure your material doesn't have lighting (e.g. don't use the VertexLitGeneric shader)
--]]
function ENT:SetCustomMaterial( mat )
    self:SetMaterial( "" )

    if not mat then return end

    self._usingCustomMaterial = true
    self._materialObject = mat
end

function ENT:IsUsingCustomMaterial()
    return self._usingCustomMaterial
end

--[[
    - Sets up this quad prop with a rendertarget, accompanying material, and PreRender hook for custom RT drawing.
    - Override this entity's :DrawRT() function to draw to the RT.

    rtName: (optional) (string)
        - The name of the RT. Does nothing if it's the same as the current RT name.
        - If not provided, a unique name will be generated.
            - Old auto-generated RTs will not be reused, thus creating a memory leak as RTs are not garbage collected.
            - It is HIGHLY recommended to provide a name to avoid said leak, or guarantee this RT gets used permanently.
        - Strange behavior may occur if the RT name is not unique.
            - Only one quad prop's :DrawRT() will be called per unique RT name.
            - Render hook removal is tied to the RT name, so if the most recent quad prop is removed or changes names, the hook will be removed for all quad props using that RT.
            - As such, only share RT names if you know they will never be removed or changed.
    rtWidth: (optional) (number)
        - The width of the RT. Defaults to 1024.
        - If not a power of 2, will become the nearest power of 2, as per GetRenderTarget()'s behavior.
    rtHeight: (optional) (number)
        - The height of the RT. Defaults to rtWidth.
--]]
function ENT:UseCustomRT( rtName, rtWidth, rtHeight )
    rtWidth = rtWidth or 1024
    rtHeight = rtHeight or rtWidth

    if not rtName then
        rtIncr = rtIncr + 1
        rtName = "quad_prop_rt_" .. rtIncr
    end

    if self._rtName == rtName then return end

    self:SetMaterial( "" )

    local hookName = "QuadProps_DrawCustomRT_" .. rtName
    local rt = GetRenderTarget( rtName, rtWidth, rtHeight )
    local mat = CreateMaterial( rtName, "UnlitGeneric", {
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = 1,
    } )

    mat:SetTexture( "$basetexture", rt )

    self._usingCustomRT = true
    self._rtName = rtName
    self._materialObject = mat

    hook.Add( "PreRender", hookName, function()
        local drawRT = self.DrawRT

        -- No longer a valid entity. Since quad props always transmit, forceupdate won't cause this to trigger prematurely.
        if not drawRT then
            hook.Remove( "PreRender", hookName )

            return
        end

        local oldW, oldH = ScrW(), ScrH()

        render.PushRenderTarget( rt )
            render.SetViewPort( 0, 0, rtWidth, rtHeight )
            cam.Start2D()
            drawRT( self )
            cam.End2D()
            render.SetViewPort( 0, 0, oldW, oldH )
        render.PopRenderTarget()
    end )
end

function ENT:IsUsingCustomRT()
    return self._usingCustomRT
end

function ENT:GetRTName()
    return self._rtName
end

function ENT:Draw()
    self:DrawQuad()
end

function ENT:DrawTranslucent()
    self:DrawQuad()
end

function ENT:DrawQuad()
    local mat = self:GetMaterialObject() or MATERIAL_ERROR
    local color = self:GetColor()
    local topLeft, topRight, bottomRight, bottomLeft = getQuadCorners( self )

    render.SetMaterial( mat )
    render.DrawQuad( topLeft, topRight, bottomRight, bottomLeft, color )

    if self:IsDoubleSided() then
        render.DrawQuad( topRight, topLeft, bottomLeft, bottomRight, color )
    end
end


----- OVERRIDEABLE FUNCTIONS -----

--[[
    - Called during PreRender for quad props using a custom rendertarget.
    - This will be a 2D rendering context with the quad prop's RT already selected.
--]]
function ENT:DrawRT()

end


----- PRIVATE FUNCTIONS -----

-- Sadly, this is the only way to wrap :SetCollisionGroup() and similar function without wrapping the entire Entity metatable.
wrapMeta = function( quadProp )
    if not entMeta then
        entMeta = FindMetaTable( "Entity" )
        entity_SetMaterialInternal = entMeta.SetMaterial

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

getQuadCorners = function( quad )
    local pos = quad:GetPos()
    local width, height = quad:GetSize()
    local ang = quad:GetAngles()

    local topLeftX = -width * 0.5
    local topLeftY = -height * 0.5

    local rectRight = -ang:Right()
    local rectDown = -ang:Up()

    return
        pos + rectRight * topLeftX + rectDown * topLeftY, -- Top left (from viewer's perspective)
        pos + rectRight * ( topLeftX + width ) + rectDown * topLeftY, -- Top right
        pos + rectRight * ( topLeftX + width ) + rectDown * ( topLeftY + height ), -- Bottom right
        pos + rectRight * topLeftX + rectDown * ( topLeftY + height ) -- Bottom left
end
