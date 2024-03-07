# quad_props

3D quads and props, all in one!

These can be arbitrarily resized through the context menu, given materials and colors via toolgun, and the context menu allows for url images to be used.

Materials will be remade as fullbright when displayed as quad props. Because glua cannot read material proxies, this means animated materials are unsupported.
However, developers can use `:SetCustomMaterial( mat )` clientside to use their own material objects, allowing for custom-made animated materials or rendertarget-driven animations.
Developers can also use `:UseCustomRT( rtName, rtWidth, rtHeight )` and override the quad prop's `:DrawRT()` function for even easier RT drawing.

Per-player quad_prop limits can be set with the `sbox_maxquad_prop` serverside convar.
