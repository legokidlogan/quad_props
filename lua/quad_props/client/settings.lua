QuadProps = QuadProps or {}


local PLAYER_LIST_FILE_NAME = "quad_props_player_list.json"

local BLOCK_ALL_URLS = CreateClientConVar( "quad_props_block_all_urls", "0", true, false, "If enabled, url quads will not load at all. This includes your quads and world-owned quads." )
local WHITELIST_MODE = CreateClientConVar( "quad_props_whitelist_mode", "0", true, false, "If enabled, url quads will load only from listed players. Otherwise, the list acts as a blacklist." )

local whitelistMode = WHITELIST_MODE:GetBool()
local blockAllURLs = BLOCK_ALL_URLS:GetBool()
local steamIDLookup = {}

local getOwner
local reloadURLs
local savePlayerList
local loadPlayerList
local rebuildListPanels
local getSteamIDFromLine


function QuadProps.CanLoadURLFromPlayer( requestingPlayer )
    if blockAllURLs then return false end
    if not IsValid( requestingPlayer ) then return true end -- Allow world-owned urls

    local isInList = steamIDLookup[requestingPlayer:SteamID()]

    if whitelistMode then
        return isInList
    else
        return not isInList
    end
end


----- PRIVATE FUNCTIONS -----

local selectedPlayerList = nil
local selectedPlayerListTitlePanel = nil
local unselectedPlayerList = nil


getOwner = function( ent )
    local cppiGetOwner = ent.CPPIGetOwner

    if cppiGetOwner then
        return cppiGetOwner( ent )
    end

    return ent:GetOwner()
end

reloadURLs = function( ply )
    local quadProps = ents.FindByClass( "quad_prop" )

    if not ply then
        for _, quadProp in ipairs( quadProps ) do
            if quadProp:IsUsingURL() then
                QuadProps.LoadMaterialURL( quadProp:GetMaterialObject(), quadProp:GetMaterial(), getOwner( quadProp ) )
            end
        end

        return
    end

    for _, quadProp in ipairs( quadProps ) do
        if quadProp:IsUsingURL() and getOwner( quadProp ) == ply then
            QuadProps.LoadMaterialURL( quadProp:GetMaterialObject(), quadProp:GetMaterial(), ply )
        end
    end
end

savePlayerList = function()
    local strData = util.TableToJSON( steamIDLookup )
    file.Write( PLAYER_LIST_FILE_NAME, strData )
end

loadPlayerList = function()
    local strData = file.Read( PLAYER_LIST_FILE_NAME, "DATA" )

    if not strData then
        if whitelistMode then
            steamIDLookup = { [LocalPlayer():SteamID()] = true }
        else
            steamIDLookup = {}
        end
    else
        steamIDLookup = util.JSONToTable( strData )
    end

    rebuildListPanels()
end

rebuildListPanels = function()
    if not selectedPlayerList then return end

    local allHumans = player.GetHumans()
    local steamIDToPlayer = {}
    local playerToSelected = {}

    for _, ply in ipairs( allHumans ) do
        steamIDToPlayer[ply:SteamID()] = ply
    end

    selectedPlayerList:Clear()

    for _, steamID in pairs( steamIDLookup ) do
        local ply = steamIDToPlayer[steamID]

        if IsValid( ply ) then
            playerToSelected[ply] = true
            selectedPlayerList:AddLine( ply:Nick() .. " - " .. steamID )
        else
            selectedPlayerList:AddLine( steamID )
        end
    end

    unselectedPlayerList:Clear()

    for _, ply in ipairs( allHumans ) do
        if not playerToSelected[ply] then
            unselectedPlayerList:AddLine( ply:Nick() .. " - " .. ply:SteamID() )
        end
    end
end

getSteamIDFromLine = function( lineStr )
    local parts = string.Split( lineStr, " - " )

    return parts[#parts] -- Always the last part
end


----- SETUP -----

local function addListView( panel, name, onLeftClick )
    local listView = vgui.Create( "DListView", panel )
    listView.Stretch = true
    listView:SetSize( 100, 100 )
    listView:SetMultiSelect( false )

    local titlePanel = listView:AddColumn( name )

    panel:AddItem( listView )

    function listView:OnRowSelected( idx, row )
        timer.Simple( 0, function()
            if not row:IsValid() then return end

            self:ClearSelection()

            local steamID = getSteamIDFromLine( row:GetColumnText( 1 ) )

            self:RemoveLine( idx )

            onLeftClick( steamID )
            --rebuildListPanels()
        end )
    end

    return listView, titlePanel
end


cvars.AddChangeCallback( "quad_props_block_all_urls", function( _, _, new )
    blockAllURLs = new ~= "0"
    reloadURLs()
end )

cvars.AddChangeCallback( "quad_props_whitelist_mode", function( _, _, new )
    whitelistMode = new ~= "0"

    if selectedPlayerList then
        local selectedPlayerListTitle = whitelistMode and "Only show URLS from these players" or "Don't show URLS from these players"

        selectedPlayerListTitlePanel:SetName( selectedPlayerListTitle )
    end

    reloadURLs()
end )


hook.Add( "InitPostEntity", "QuadProps_LoadPlayerList", loadPlayerList )

hook.Add( "AddToolMenuCategories", "QuadProps_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory( "Options", "QuadProps", "#QuadProps" )
end )

hook.Add( "PopulateToolMenu", "QuadProps_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "QuadProps", "quad_props", "#Quad Props", "", "", function( panel )
        panel:CheckBox( "Block all URLs", "quad_props_block_all_urls" )
        panel:CheckBox( "Use player list as a whitelist", "quad_props_whitelist_mode" )

        local selectedPlayerListTitle = whitelistMode and "Only show URLS from these players" or "Don't show URLS from these players"

        selectedPlayerList, selectedPlayerListTitlePanel = addListView( panel, selectedPlayerListTitle, function( steamID )
            steamIDLookup[steamID] = nil

            local ply = player.GetBySteamID( steamID )

            if IsValid( ply ) then
                unselectedPlayerList:AddLine( ply:Nick() .. " - " .. steamID )
                reloadURLs( ply )
            end

            savePlayerList()
        end )

        unselectedPlayerList = addListView( panel, "Other online players", function( steamID )
            steamIDLookup[steamID] = true

            local ply = player.GetBySteamID( steamID )

            if IsValid( ply ) then
                selectedPlayerList:AddLine( ply:Nick() .. " - " .. steamID )
                reloadURLs( ply )
            end

            savePlayerList()
        end )

        rebuildListPanels()
    end )
end )

gameevent.Listen( "player_disconnect" )
hook.Add( "player_disconnect", "QuadProps_RebuildPlayerList", function( data )
    if data.bot == 1 then return end

    rebuildListPanels()
end )

gameevent.Listen( "player_connect_client" )
hook.Add( "player_connect_client", "QuadProps_RebuildPlayerList", function( data )
    if data.bot == 1 then return end

    timer.Simple( 0, rebuildListPanels )
end )
