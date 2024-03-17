# quad_props

3D quads and props, all in one!

These can be arbitrarily resized through the context menu, given materials and colors via toolgun, and the context menu allows for url images to be used.

Materials will be remade as fullbright when displayed as quad props. Because glua cannot read material proxies, this means animated materials are unsupported. \
However, developers can use `:SetCustomMaterial( mat )` clientside to use their own material objects. \
Developers can also use `:UseCustomRT( rtName, rtWidth, rtHeight )` and override `:DrawRT()` for super easy RT drawing.

Per-player quad_prop limits can be set with the `sbox_maxquad_prop` serverside convar, 10 by default.

To protect against players loading IP grabbers on other clients, there is a simplistic, non-configurable url whitelist built in.
If your server uses [CFC HTTP Whitelist](https://github.com/CFC-Servers/cfc_cl_http_whitelist), then it will defer to that instead, allowing for whitelist customization.
