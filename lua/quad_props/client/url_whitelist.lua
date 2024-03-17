QuadProps = QuadProps or {}


-- Hard-coded whitelist for servers not using CFCHTTP.
-- https://github.com/CFC-Servers/cfc_cl_http_whitelist
local ADDRESS_WHITELIST = {
    -- Steam
    ["api.steampowered.com"] = true,
    ["steamcommunity.com"] = true,
    ["developer.valvesoftware.com"] = true,
    ["avatars.cloudflare.steamstatic.com"] = true,
    ["avatars.akamai.steamstatic.com"] = true,
    ["steamuserimages-a.akamaihd.net"] = true,
    ["images.akamai.steamusercontent.com"] = true,
    ["steamcdn-a.akamaihd.net"] = true,

    -- GitHub
    ["github.com"] = true,
    ["api.github.com"] = true,
    ["raw.githubusercontent.com"] = true,
    ["gist.githubusercontent.com"] = true,

    -- Dropbox
    ["dl.dropboxusercontent.com"] = true,
    ["dl.dropbox.com"] = true,
    ["www.dropbox.com"] = true,

    -- OneDrive
    ["onedrive.live.com"] = true,
    ["api.onedrive.com"] = true,

    -- Google Drive
    ["drive.google.com"] = true,
    ["docs.google.com"] = true,

    -- Imgur
    ["i.imgur.com"] = true,
    ["imgur.com"] = true,

    -- Reddit
    ["i.redditmedia.com"] = true,
    ["i.redd.it"] = true,

    -- Misc
    ["wiki.garrysmod.com"] = true,
    ["en.wikipedia.org"] = true,
    ["cdn.discordapp.com"] = true,
}

local getAddress


function QuadProps.IsURLWhitelisted( url )
    if CFCHTTP then return true end -- Hand off checks to CFC HTTP's wrapper if it exists.

    local address = getAddress( url )
    if not address then return false end

    return ADDRESS_WHITELIST[address] or false
end


----- PRIVATE FUNCTIONS -----

getAddress = function( url )
    local _, _, _protocol, address, _port, _remainder = string.find( url, "(%a+)://([^:/ \t]+):?(%d*)/?.*" )

    return address
end
