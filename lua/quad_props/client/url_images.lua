QuadProps = QuadProps or {}

local imageQueue = {}

local doNextInQueue
local rescaleImage


-- Removes a material request from the queue.
function QuadProps.CancelMaterialURL( mat )
    local name = mat:GetName()

    for i = 1, #imageQueue do
        if imageQueue[i].Name == name then
            table.remove( imageQueue, i )

            return
        end
    end
end

-- Queues a material to be loaded from a URL.
function QuadProps.LoadMaterialURL( mat, url )
    if string.len( url ) > 400 then
        -- URL is too long
        mat:setTexture( "$basetexture", "error" )

        return
    end

    local name = mat:GetName()
    local rt = GetRenderTarget( name, 1024, 1024 )

    mat:SetTexture( "$basetexture", rt )

    QuadProps.CancelMaterialURL( mat )

    url = string.gsub( url, "[^%w _~%.%-/:=%?&]", function( str )
        return string.format( "%%%02X", string.byte( str ) )
    end )

    local requestTbl = {
        Name = name,
        RT = rt,
        URL = url,
        Material = mat,
        Callback = rescaleImage,
    }

    local inqueue = #imageQueue
    imageQueue[inqueue + 1] = requestTbl

    if inqueue == 0 then timer.Simple( 0, doNextInQueue ) end
end


rescaleImage = function( w, h, layoutFunc )
    if w == 1024 and h == 1024 then return end

    local widthBigger = w >= h
    local mult = widthBigger and ( 1024 / w ) or ( 1024 / h )
    local x = 0
    local y = 0

    w = w * mult
    h = h * mult

    if widthBigger then
        y = ( 1024 - h ) / 2
    else
        x = ( 1024 - w ) / 2
    end

    layoutFunc( x, y, w, h )
end


----- PRIVATE FUNCTIONS -----


local Panel
doNextInQueue = function() -- Taken and cleaned up from StarfallEX
    if not Panel then
        Panel = QuadProps._URLTextureLoader
        if not Panel then
            Panel = vgui.Create( "DHTML" )
            Panel:SetSize( 1024, 1024 )
            Panel:SetAlpha( 0 )
            Panel:SetMouseInputEnabled( false )
            Panel:SetHTML(
                [[<html style="overflow:hidden"><body><script>
                if (!requestAnimationFrame)
                    var requestAnimationFrame = webkitRequestAnimationFrame;
                function renderImage(){
                    requestAnimationFrame(function(){
                        requestAnimationFrame(function(){
                            document.body.offsetWidth
                            requestAnimationFrame(function(){
                                quadProps.imageLoaded(img.width, img.height);
                            });
                        });
                    });
                }
                var img = new Image();
                img.style.position="absolute";
                img.onload = renderImage;
                img.onerror = function (){quadProps.imageErrored();}
                document.body.appendChild(img);
                </script></body></html>]]
            )
            Panel:Hide()
            QuadProps._URLTextureLoader = Panel
            timer.Simple( 0.5, doNextInQueue )

            return
        end
    end

    local requestTbl = table.remove( imageQueue, 1 )

    if not requestTbl then
        timer.Remove( "QuadProps_URLTextureTimeout" )
        Panel:Hide()

        return
    end

    local function applyTexture( w, h )
        local function imageDone()
            if requestTbl.Loaded then return end

            requestTbl.Loaded = true

            hook.Add( "PreRender", "QuadProps_HTMLPanelCopyTexture", function()
                Panel:UpdateHTMLTexture()

                local mat = Panel:GetHTMLMaterial()
                if not mat then return end

                render.PushRenderTarget( requestTbl.RT )
                    render.Clear( 0, 0, 0, 0, false, false )
                    cam.Start2D()
                    surface.SetMaterial( mat )
                    surface.SetDrawColor( 255, 255, 255 )
                    surface.DrawTexturedRect( 0, 0, 1024, 1024 )
                    cam.End2D()
                render.PopRenderTarget()

                hook.Remove( "PreRender", "QuadProps_HTMLPanelCopyTexture" )
                timer.Simple( 0, doNextInQueue ) -- Timer to prevent being in javascript stack frame
            end )
        end

        if requestTbl.Usedlayout then
            imageDone()

            return
        end

        local function layout( x, y, w2, h2, pixelated )
            if requestTbl.Usedlayout then return end

            requestTbl.Usedlayout = true

            Panel:RunJavascript( [[
                img.style.left=']] .. x .. [[px';img.style.top=']] .. y .. [[px';img.width=]] .. w2 .. [[;img.height=]] .. h2 .. [[;img.style.imageRendering=']] .. ( pixelated and "pixelated" or "auto" ) .. [[';
                renderImage();
            ]] )
        end

        if requestTbl.Callback then requestTbl.Callback( w, h, layout, false ) end

        if not requestTbl.Usedlayout then
            requestTbl.Usedlayout = true
            imageDone()
        end
    end

    local function errorTexture()
        timer.Simple( 0, function() -- Timer to prevent being in javascript stack frame
            requestTbl.Material:SetTexture( "$basetexture", "error" )
            doNextInQueue()
        end )
    end

    Panel:AddFunction( "quadProps", "imageLoaded", applyTexture )
    Panel:AddFunction( "quadProps", "imageErrored", errorTexture )
    Panel:RunJavascript(
        [[img.removeAttribute("width");
        img.removeAttribute("height");
        img.style.left="0px";
        img.style.top="0px";
        img.src="]] .. string.JavascriptSafe( requestTbl.URL ) .. [[";]] ..
        ( BRANCH == "unknown" and "\nif(img.complete)renderImage();" or "" )
    )
    Panel:Show()

    timer.Create( "QuadProps_URLTextureTimeout", 10, 1, function()
        if requestTbl.Callback then requestTbl.Callback() end

        doNextInQueue()
    end )
end
