# quad_props

3D quads and props, all in one!

These can be arbitrarily resized through the context menu, given materials and colors via toolgun, and the context menu allows for url images to be used.

Materials will be remade as fullbright when displayed as quad props. Because glua cannot read material proxies, this means animated materials are unsupported. However, developers can use `:SetCustomMaterial( IMaterial )` clientside to use their own materials, allowing for custom-made animated materials or rendertarget-driven animations.

Per-player quad_prop limits can be set with the `sbox_maxquad_prop` serverside convar.
