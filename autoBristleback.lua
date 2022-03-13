local Hedg = {}
Hedg.optionEnable = Menu.AddOptionBool({"Hero Specific", "Bristleback[Custom]"}, "Активировать скрипт", false)
Hedg.toggleKey = Menu.AddKeyOption({"Hero Specific", "Bristleback[Custom]"}, "Активация", Enum.ButtonCode.KEY_NONE)
Hedg.onViscous = Menu.AddOptionBool({"Hero Specific", "Bristleback[Custom]"}, "Viscous если враг находится в его зоне", Enum.ButtonCode.KEY_NONE)
Hedg.onSpray = Menu.AddOptionBool({"Hero Specific", "Bristleback[Custom]"}, "Quill Spray если враг находится в его зоне", Enum.ButtonCode.KEY_NONE)


local function _x( x )
    local screenW, y = Renderer.GetScreenSize();
	return x / 1920 * screenW
end

local function _y( y )
    local x, screenH = Renderer.GetScreenSize();
	return y / 1080 * screenH
end


-- 228 print Не брошу
-- local function print( ... )
--     local t = { ... }
--     for i = 1, #t do 
--         t[i] = tostring( t[i])
--     end
--     local s = table.concat( t, "\t")
--     Log.Write ( s )
-- end 



local font = Renderer.LoadFont( "Arial", 18, Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)

local isActived = false;

-- Local player data
local PlayerData = {};
PlayerData.Team = 0; -- 
PlayerData.Hero = false; 
PlayerData.isAghanim = false; -- Есть ли у героя аганим?
PlayerData.Ability = {};


-- Render
local tPosGUI = {};
tPosGUI.x = 0;
tPosGUI.y = 0;


-- При каких модификациях на себе мы не юзаем кнопки
local tBlockSpay = {
    Enum.ModifierState.MODIFIER_STATE_SILENCED,
    Enum.ModifierState.MODIFIER_STATE_MUTED,
    Enum.ModifierState.MODIFIER_STATE_STUNNED,
    Enum.ModifierState.MODIFIER_STATE_HEXED,
    Enum.ModifierState.MODIFIER_STATE_INVISIBLE,
}

-- При каких модификациях мы не используем спрей
local tBlockViscous = {
    Enum.ModifierState.MODIFIER_STATE_INVULNERABLE,
    Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE,
}

-- Интервалы КД на юз способностей
local lastTick = {
    [1] = GameRules.GetGameTime();
    [2] = GameRules.GetGameTime();
};

-- Скиллы
local spell = {
    'bristleback_viscous_nasal_goo', -- Первый скилл
    'bristleback_quill_spray', -- Второй скилл
}


function Hedg.init()
    PlayerData.Hero = false
    if Engine.IsInGame() then --только если мы в игре      
        if NPC.GetUnitName( Heroes.GetLocal() ) ~= "npc_dota_hero_bristleback" then return end      
        PlayerData.Hero = Heroes.GetLocal(); -- героя обычно в игре не меняют.
        PlayerData.Team = Entity.GetTeamNum( PlayerData.Hero );

        -- Записываем хэндл скиллов
        for i = 1, #spell do
            local object =  NPC.GetAbility( PlayerData.Hero, spell[i])
            PlayerData.Ability[i] = object 
        end 

        --расчет один раз по формуле, а не неивестными условиями и значениями.
        tPosGUI.x = _x( 1140 )
        tPosGUI.y = _y( 880 )
    end
end

--если игра уже стартанула и чит включили
Hedg.init();

--или на старте игры вызываем их
function Hedg.OnGameStart()
    Hedg.init();
end


-- Проверяем возможность нажатия на кнопку
local function isBadEvent( ) 
    local player = PlayerData.Hero 
    for k, mod in pairs( tBlockSpay ) do
        if NPC.HasState( player, mod ) then 
            return true 
        end 
    end 
    return false
end 

-- Есть ли у игрока какие-то бафы которые нам помешают?
local function isEnemyBlockViscous( hero )
    for k, mod in pairs( tBlockViscous ) do
        if NPC.HasState( hero, mod ) then 
            return true 
        end 
    end 
    return false
end 


function Hedg.OnUpdate()
    if not PlayerData.Hero or not Menu.IsEnabled( Hedg.optionEnable ) then return end
    
    if Menu.IsKeyDownOnce( Hedg.toggleKey ) then
        isActived = not isActived
    end


    if isActived and Entity.IsAlive( PlayerData.Hero ) then
        --локализация частого вызова
        local GameTime = GameRules.GetGameTime();

        -- Если игрок купил аганим или улучшенный аганим
        if not PlayerData.isAghanim and ( NPC.HasItem( PlayerData.Hero, 'item_ultimate_scepter') or NPC.HasModifier( PlayerData.Hero, 'modifier_item_ultimate_scepter_consumed') ) then
            PlayerData.isAghanim = true
        elseif PlayerData.isAghanim and not ( NPC.HasItem( PlayerData.Hero, 'item_ultimate_scepter') or NPC.HasModifier(PlayerData.Hero, 'modifier_item_ultimate_scepter_consumed') ) then
            PlayerData.isAghanim = false
        end 

        if not isBadEvent( ) then -- Если мы не в стане и т.п

            -- Второй скилл
            if Menu.IsEnabled( Hedg.onSpray ) then 
                if Ability.IsReady( PlayerData.Ability[2] ) and GameTime - lastTick[2] > 1 + NetChannel.GetAvgLatency( Enum.Flow.FLOW_OUTGOING ) then 
                    local casts = false 
                    local castRange = 700 -- Ability.GetCastRange( PlayerData.Ability[2] )
                    local tEnemy = Entity.GetHeroesInRadius( PlayerData.Hero, castRange , Enum.TeamType.TEAM_ENEMY )

                    if #tEnemy > 0 then
                        Ability.CastNoTarget( PlayerData.Ability[2] )
                        lastTick[2] = GameTime
                    end 
                end
            end

            -- Первый скилл
            if Menu.IsEnabled( Hedg.onViscous ) then 
                if PlayerData.isAghanim and Ability.IsReady( PlayerData.Ability[1] ) and GameTime - lastTick[1] > 1 + NetChannel.GetAvgLatency( Enum.Flow.FLOW_OUTGOING ) then 
                    local casts = false 
                    local castRange = 800 --Ability.GetCastRange( PlayerData.Ability[1] )
                    local tEnemy = Entity.GetHeroesInRadius( PlayerData.Hero, castRange , Enum.TeamType.TEAM_ENEMY )

                    for i = 1, #tEnemy do
                        if not isEnemyBlockViscous( tEnemy[i] ) then
                            casts = true 
                        end 
                    end 
                    if casts then
                        Ability.CastNoTarget( PlayerData.Ability[1] )
                        lastTick[1] = GameTime
                    end 
                end
            end
            
            
        end
    end
end


function Hedg.OnDraw()
    if not PlayerData.Hero then return end 
    if not Menu.IsEnabled( Hedg.optionEnable) or not Heroes.GetLocal() then return end

    if isActived then
        Renderer.SetDrawColor( 90, 255, 100)
        local Viscous = ( PlayerData.isAghanim and Menu.IsEnabled( Hedg.onViscous ) and 'ON' or not PlayerData.isAghanim and 'Нет Аганима' or 'OFF' )
        Renderer.DrawText( font, tPosGUI.x, tPosGUI.y, string.format("Auto Spray: %s | Auto Viscous: %s", Menu.IsEnabled( Hedg.onSpray ) and "ON" or "OFF", Viscous ))
    else
        Renderer.SetDrawColor( 255, 90, 100)
        Renderer.DrawText( font, tPosGUI.x, tPosGUI.y, string.format("Auto Spray and Viscous OFF", Menu.IsEnabled( Hedg.onSpray ) and "ON" or "OFF", Viscous ))
    end
end
return Hedg