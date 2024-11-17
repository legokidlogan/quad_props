# quad_props

3D quads and props, all in one!

These can be arbitrarily resized through the context menu, given materials and colors via toolgun, and the context menu allows for url images to be used.

Materials will be remade as fullbright when displayed as quad props. Because glua cannot read material proxies, this means animated materials are unsupported. \
However, developers can use `:SetCustomMaterial( mat )` clientside to use their own material objects. \
Developers can also use `:UseCustomRT( rtName, rtWidth, rtHeight )` and override `:DrawRT()` for super easy RT drawing.

Per-player quad_prop limits can be set with the `sbox_maxquad_prop` serverside convar, 10 by default.

To protect against players loading IP grabbers on other clients, there is a simplistic, non-configurable url whitelist built in.
If your server uses [CFC HTTP Whitelist](https://github.com/CFC-Servers/cfc_cl_http_whitelist), then it will defer to that instead, allowing for whitelist customization.


## Server Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| sbox_maxquad_prop | The max number of quad props per player. | 10 |
| quad_props_size_limit_mode | 0 To always enforce size limit, 1 to ignore it on world-owned or superadmin-owned quad props (requires a prop protection addon), 2 to always ignore it. | 0 |
| sf_quadprops_max | The max number of serverside quad props per player spawned via Starfall scripts. | 10 |
| quad_props_starfall_blocked_groups | A case-sensitive, comma-separated list of group/rank names to deny quadprop creation through Starfall. Example: 'user,regular' |  |


## Client Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| quad_props_block_all_urls | If enabled, url quads will not load at all. This also includes your quads and world-owned quads. | 0 |
| quad_props_whitelist_mode | If enabled, url quads will load only from listed players. Otherwise, the list acts as a blacklist. | 0 |
| sf_quadprops_max_cl | The max number of clientside quad props per player spawned via Starfall scripts. | 10 |


## Hooks

- `QuadProps_Starfall_DisallowQuadPropCreate( ply, pos, ang, width, height, frozen )`
  - SERVER and CLIENT realms.
  - Return true (or a reason string) to prevent someone from creating a quad prop through Starfall.
- `QuadProps_SetMaterial( ent, path )`
  - SERVER realm.
  - Return a string to override the path.


## StarfallEX Support

Quad props can be spawned both serverside and clientside in Starfall using `quadprop.create( pos, ang, width, height )`
Full documentation can be read using the in-game SF Helper.

Clientside quad props in Starfall can also make use of `:setCustomMaterial()`
Here's an example script which creates some helper functions and then creates a quad prop which shows an orbiting circle:

```lua
--@name Quad Prop RT
--@author TwoLemons (aka legokidlogan)
--@client


-- CONFIG
local quadSize = 50

local backgroundColor = Color( 0, 0, 0, 100 )

local circleRadius = 40
local circleSpeed = 3
local circleOrbitRadius = 200
local circleColor = Color( 255, 255, 255, 255 )
-- END CONFIG


local rtMats = {}

--[[
    - Helper function for making custom quadprop materials from rendertargets.

    rtName: (string)
        - Name of the rendertarget to create.
    renderFunc: (function)
        - The function to use for drawing to the rendertarget.
        - Will be called inside a renderoffscreen hook with the rendertarget already selected.

    RETURNS: mat
        mat: (Material)
            - A material tied to the rendertarget.
            - To apply to a quadprop, use quadProp:setCustomMaterial( mat )
--]]
local function makeQuadPropRT( rtName, renderFunc )
    if not render.renderTargetExists( rtName ) then
        render.createRenderTarget( rtName )
    end

    local mat = rtMats[rtName]

    if not mat then
        mat = material.create( "UnlitGeneric" )
        mat:setInt( "$flags", 16 + 32 )
        mat:setTextureRenderTarget( "$basetexture", rtName )

        rtMats[rtName] = mat
    end

    hook.add( "renderoffscreen", "DrawQuadPropRT_" .. rtName, function()
        render.selectRenderTarget( rtName )
            renderFunc()
        render.selectRenderTarget()
    end )

    return mat
end

-- Destroys a custom rendertarget and material.
local function destroyQuadPropRT( rtName )
    if not render.renderTargetExists( rtName ) then return end

    hook.remove( "renderoffscreen", "DrawQuadPropRT_" .. rtName )
    render.destroyRenderTarget( rtName )

    local mat = rtMats[rtName]
    if not mat then return end

    mat:destroy()
    rtMats[rtName] = nil
end


-- Example usage:

local myMat = makeQuadPropRT( "test_rt", function()
    local t = timer.curtime() * circleSpeed
    local x = 512 + math.cos( t ) * circleOrbitRadius
    local y = 512 + math.sin( t ) * circleOrbitRadius

    render.clear( backgroundColor )

    render.setColor( circleColor )
    render.drawFilledCircle( x, y, circleRadius )
end )

local quadProp = quadprop.create( chip():localToWorld( Vector( 0, 0, quadSize / 2 ) ), chip():getAngles(), quadSize, quadSize )
quadProp:setCustomMaterial( myMat )
quadProp:setParent( chip() )
```
