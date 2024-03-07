include( "shared.lua" )

DEFINE_BASECLASS( "base_gmodentity" )

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT


local entMeta = nil
local classMeta = nil
local rtIncr = 0

local wrapMeta
local isRTInUse


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
    self:_SetMaterial( path )
    self:SetNWQuadMaterial( path )
end

function ENT:_SetMaterial( path )
    local rtName = self._rtName

    if rtName then
        hook.Remove( "PreRender", "QuadProps_DrawCustomRT_" .. rtName )
    end

    self._usingCustomMaterial = false
    self._usingCustomRT = false
    self._rtName = nil
    self._materialObject = QuadProps.AcquireMaterial( self, path or "" )
end

function ENT:GetMaterial()
    return self:GetNWQuadMaterial()
end

function ENT:GetMaterialObject()
    return self._materialObject
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
        - Must be different from the RT name of any other quad prop.
        - If not provided, a unique name will be generated.
            - Old auto-generated RTs will not be reused, thus creating a memory leak as RTs are not garbage collected.
            - It is HIGHLY recommended to provide a name to avoid said leak, or guarantee this RT gets used permanently.
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

    if isRTInUse( rtName ) then
        error( "RT name already in use", 1 )
    end

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

isRTInUse = function( rtName )
    local quadProps = ents.FindByClass( "quad_prop" )

    -- Check manually every time instead of tracking manually to avoid potential miscounts (lua autorefresh, EntityRemoved hook breaking from an addon, etc)
    -- The added perf cost is a non-issue since this function will be very rarely called.
    for _, quadProp in ipairs( quadProps ) do
        if quadProp:GetRTName() == rtName then
            return true
        end
    end

    return false
end
