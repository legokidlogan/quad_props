QuadProps = QuadProps or {}

local MATERIAL_DEFAULT = CreateMaterial( "quad_props_white", "UnlitGeneric", {
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1,
    ["$translucent"] = 1,
    ["$color"] = "[1 1 1]",
} )

local materialBank = {}
local materialIncr = 0

local getOwner
local createFreeMaterial
local tallyMatUsages
local getFreeMaterial
local makeUnlitCopy


--[[
    - Finds or creates a free material in the material bank, modifies it with the new path, then returns the material.
    - Note: this function acquires the material, but does not apply it to the quad prop directly.
        - As such, manual usage of this function is not recommended.

    quadProp: (Entity)
        - The quad prop whose path is being changed.
    path: (string)
        - The new path (existing material path, or image url) to apply.
--]]
function QuadProps.AcquireMaterial( quadProp, path )
    path = path or ""
    if path == "" then return MATERIAL_DEFAULT end

    local cachedMat = materialBank[path]
    if cachedMat then return cachedMat end

    local curPath = quadProp:GetMaterial() -- Note that if curPath == path, the cachedMat check will have already caught it.

    local mat = getFreeMaterial( curPath )

    if string.StartsWith( path, "http" ) then
        mat:SetInt( "$flags", 16 + 32 )
        QuadProps.LoadMaterialURL( mat, path, getOwner( quadProp ) )
    else
        QuadProps.CancelMaterialURL( mat )
        makeUnlitCopy( mat, path )
    end

    materialBank[path] = mat

    return mat
end


----- PRIVATE FUNCTIONS -----

getOwner = function( ent )
    local cppiGetOwner = ent.CPPIGetOwner

    if cppiGetOwner then
        return cppiGetOwner( ent )
    end

    return ent:GetOwner()
end

createFreeMaterial = function()
    materialIncr = materialIncr + 1

    local mat = CreateMaterial( "quad_props_" .. materialIncr, "UnlitGeneric" )

    return mat
end

tallyMatUsages = function()
    local pathToUsageCount = {}
    local allQuadProps = ents.FindByClass( "quad_prop" )

    for _, quadProp in ipairs( allQuadProps ) do
        local path = quadProp:GetMaterial()

        if path and materialBank[path] then
            pathToUsageCount[path] = ( pathToUsageCount[path] or 0 ) + 1
        end
    end

    return pathToUsageCount
end

getFreeMaterial = function( curPath )
    local pathToUsageCount = tallyMatUsages()

    if curPath ~= "" then
        local curUsage = pathToUsageCount[curPath]

        -- The current quad is the only one using the path, so just reuse the material and remove the old path from the bank.
        if curUsage == 1 then
            local mat = materialBank[curPath]
            materialBank[curPath] = nil

            return mat
        end
    end

    -- Find a material in the bank that isn't currently being used.
    for path, mat in pairs( materialBank ) do
        if not pathToUsageCount[path] then
            materialBank[path] = nil

            return mat
        end
    end

    -- If no free materials are found, create a new one.
    return createFreeMaterial()
end

makeUnlitCopy = function( mat, path )
    local refMat = Material( path )
    local tex = refMat:GetTexture( "$basetexture" )

    local refFlags = refMat:GetInt( "$flags" ) or 0
    local selfillum = bit.band( refFlags, 64 )
    local additive = bit.band( refFlags, 128 )
    local alphatest = bit.band( refFlags, 256 )
    local translucent = bit.band( refFlags, 2097152 )

    local flags = selfillum + additive + alphatest + translucent
        + 16 -- vertexcolor
        + 32 -- vertexalpha

    mat:SetInt( "$flags", flags )

    if tex then
        mat:SetTexture( "$basetexture", tex )
        mat:SetMatrix( "$basetexturetransform", refMat:GetMatrix( "$basetexturetransform" ) )
    end

    mat:SetVector( "$color", refMat:GetVector( "$color" ) )
    mat:SetVector( "$color2", refMat:GetVector( "$color2" ) )
    mat:SetFloat( "$alpha", refMat:GetFloat( "$alpha" ) )
end
