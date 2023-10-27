local TurboCourier = {}
TurboCourier.optionEnable = Menu.AddOptionBool({"Utility", "Courier Gem Stealer [Turbo]"}, "Включен", true)

local TURBO_MODE_ID = 23

local PLAYER_DATA = {
    courier = false,
    targetEntity = false,
    state = false,
}

local LAST_POSITION = Vector()
local LAST_TICK = os.clock()
local INTERVAL_TICK = 1

local ITEMS_FROM_TAKED = {}
local SUCCESS_ITEMS = {
    [ "item_gem" ] = true
}


-- Локализация --
local GetAbsOrigin = Entity.GetAbsOrigin
local IsEntity = Entity.IsEntity
----------------

--получаем данные не меняющиейся со временем
function TurboCourier.init()
    if not Engine.IsInGame() then
        return
    end

    if TURBO_MODE_ID ~= GameRules.GetGameMode() then
        return
    end

    local hero = Heroes.GetLocal()
    local player = Players.GetLocal()

    for idx, entity in pairs( Couriers.GetAll() ) do
        if entity and IsEntity( entity ) and Entity.IsSameTeam( hero, entity ) and NPC.GetUnitName( entity ) == "npc_dota_courier" then
            if player == Entity.GetOwner( entity ) then
                PLAYER_DATA.courier = entity
                break
            end
        end
    end

    PLAYER_DATA.CourierToBase = NPC.GetAbilityByIndex( PLAYER_DATA.courier, 0 )
end

function TurboCourier.OnGameStart()
    TurboCourier.init()
end;

TurboCourier.init()

local function getDist( startPosition, endPosition )
    return ( endPosition - startPosition ):Length2D()
end

local function IsCourierMoving()
    local startPosition = GetAbsOrigin( PLAYER_DATA.courier )
    local prevPosition = LAST_POSITION
    LAST_POSITION = startPosition
    return getDist( startPosition, prevPosition ) > 0
end

local function getNearestObject()
    local minimalDist = false
    local selectedItem = false

    for _physicalItem, _item in pairs( ITEMS_FROM_TAKED ) do
        if IsEntity( _physicalItem ) then
            local dist = getDist( GetAbsOrigin( PLAYER_DATA.courier ), GetAbsOrigin( _physicalItem ))
            if not minimalDist or minimalDist > dist then
                minimalDist = dist
                selectedItem = _physicalItem
            end
        else
            ITEMS_FROM_TAKED[ _physicalItem ] = nil
        end
    end

    if not minimalDist or not selectedItem then
        return false
    end

    return selectedItem
end

function TurboCourier.OnUpdate()
    if not PLAYER_DATA.courier or not Menu.IsEnabled(TurboCourier.optionEnable) then return end

    foreach( PhysicalItems.GetAll(), function( idx, physicalItem )
        if not IsEntity( physicalItem ) or not PhysicalItems.Contains( physicalItem ) then
            return
        end

        local item = PhysicalItem.GetItem( physicalItem )
        if not item or not SUCCESS_ITEMS[ Ability.GetName( item ) ] then 
            return 
        end

        if ITEMS_FROM_TAKED[ physicalItem ] then
            return
        end

        ITEMS_FROM_TAKED[ physicalItem ] = item
    end )

    if PLAYER_DATA.targetEntity and ITEMS_FROM_TAKED[ PLAYER_DATA.targetEntity ] and not IsEntity( PLAYER_DATA.targetEntity ) then
        if PLAYER_DATA.CourierToBase then
            -- Отправляем курьера домой
            Ability.CastNoTarget( PLAYER_DATA.CourierToBase )
        end

        PLAYER_DATA.targetEntity = false
        return
    end

    PLAYER_DATA.targetEntity = getNearestObject()

    if not PLAYER_DATA.targetEntity or not IsEntity( PLAYER_DATA.targetEntity ) then
        return
    end

    local state = Courier.GetCourierState( PLAYER_DATA.courier )
    
    -- Сдооох?, -- Сначала мы доставляем предмет, который нужен игроку
    if state == Enum.CourierState.COURIER_STATE_DEAD or state == Enum.CourierState.COURIER_STATE_DELIVERING_ITEMS then
        return
    end

    if IsCourierMoving() then
        return
    end


    Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM, PLAYER_DATA.targetEntity, Vector(), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, PLAYER_DATA.courier, true, false, true )
end



function foreach(table, func)
    for key, value in pairs(table) do
      func(key, value)
    end
end



return TurboCourier