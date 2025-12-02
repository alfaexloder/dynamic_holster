- ============================================================
-- НАСТРОЙКИ - ЗАПОЛНИ СВОИ ДАННЫЕ
-- ============================================================
local Config = {}

-- Номер компонента кобуры (обычно 7 для аксессуаров)
Config.holsterComponent = 7  -- ⚠️ ЗАМЕНИТЬ НА СВОЙ НОМЕР КОМПОНЕНТА

-- ПАРЫ КОБУР (заполненная ↔ пустая)
-- ⚠️ ДОБАВИТЬ ВСЕ ПАРЫ КОБУР КОТОРЫЕ ЕСТЬ НА СЕРВЕРЕ
Config.holsterPairs = {
    -- Пара 1: Например, кобура на поясе
    {full = 0, empty = 1},
}

-- Задержка проверки оружия
Config.checkDelay = 300

-- Задержка проверки одежды 
Config.clothingCheckDelay = 1000

-- ============================================================
-- СПИСОК ОРУЖИЯ ДЛЯ КОБУРЫ
-- ⚠️ ДОБАВИТЬ СЮДА ВСЕ ПИСТОЛЕТЫ КОТОРЫЕ ИСПОЛЬЗУЮТСЯ НА СЕРВЕРЕ
-- ============================================================
Config.holsterWeapons = {
    -- Примеры (добавить/убрать нужные):
    [GetHashKey("WEAPON_PISTOL")] = true,
}

-- Оружие которое НЕ влияет на кобуру (нож, фонарик и т.д.)
Config.ignoreWeapons = {
    [GetHashKey("WEAPON_UNARMED")] = true,      -- Кулаки
    [GetHashKey("WEAPON_KNIFE")] = true,        -- Нож
    [GetHashKey("WEAPON_NIGHTSTICK")] = true,   -- Дубинка
    [GetHashKey("WEAPON_FLASHLIGHT")] = true,   -- Фонарик
    -- ⚠️ ДОБАВИТЬ ДРУГИЕ если нужно
}

-- Включить отладочные сообщения (true/false)
Config.debug = true  -- ⚠️ Поставить false когда всё заработает

-- ============================================================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ============================================================
local currentWeapon = nil          -- Текущее оружие в руках
local isHolsterEmpty = false       -- Состояние кобуры (false = заполнена, true = пуста)
local isScriptActive = false       -- Активен ли скрипт
local activePair = nil             -- Текущая пара кобуры на игроке
local currentTexture = nil 

-- ============================================================
-- ФУНКЦИЯ: Вывод отладки
-- ============================================================
local function DebugPrint(message)
    if Config.debug then
        print("[HOLSTER] " .. message)
    end
end

-- ============================================================
-- ФУНКЦИЯ: Проверка наличия кобуры и определение активной пары
-- ============================================================
local function HasHolster()
    local ped = PlayerPedId()
    local currentDrawable = GetPedDrawableVariation(ped, Config.holsterComponent)
    local currentTexture = GetPedTextureVariation(ped, Config.holsterComponent)
    
    -- Проверяем все пары кобур
    for index, pair in pairs(Config.holsterPairs) do
        -- Проверяем заполненную кобуру
        if currentDrawable == pair.full then
            DebugPrint("Найдена заполненная кобура (пара #" .. index .. ")")
            return true, pair, false, currentTexture
        end
        
        -- Проверяем пустую кобуру
        if currentDrawable == pair.empty then
            DebugPrint("Найдена пустая кобура (пара #" .. index .. ")")
            return true, pair, true, currentTexture   -- true = есть кобура, pair = активная пара, true = пустая
        end
    end
    
    DebugPrint("Кобура не найдена на игроке")
    return false, nil, nil, nil
end

-- ============================================================
-- ФУНКЦИЯ: Смена кобуры
-- ============================================================
local function ChangeHolster(isEmpty)
    -- Проверяем что активная пара определена
    if not activePair then
        DebugPrint("ОШИБКА: активная пара кобуры не определена!")
        return
    end
    
    -- Проверяем валидность ID кобур
    if isEmpty then
        if activePair.empty < 0 then
            DebugPrint("ОШИБКА: неверные ID пустой кобуры!")
            return
        end
    else
        if activePair.full < 0 then
            DebugPrint("ОШИБКА: неверные ID заполненной кобуры!")
            return
        end
    end
    
    -- Если кобура уже в нужном состоянии - ничего не делаем
    if isHolsterEmpty == isEmpty then
        return
    end
    
    local ped = PlayerPedId()
    
    if isEmpty then
        -- Ставим ПУСТУЮ кобуру из активной пары
        SetPedComponentVariation(ped, Config.holsterComponent, activePair.empty, currentTexture, 0)
        isHolsterEmpty = true
        DebugPrint("Кобура теперь ПУСТАЯ")
    else
        -- Ставим ЗАПОЛНЕННУЮ кобуру из активной пары
        SetPedComponentVariation(ped, Config.holsterComponent, activePair.full, currentTexture, 0)
        isHolsterEmpty = false
        DebugPrint("Кобура теперь ЗАПОЛНЕННАЯ")
    end
end

-- ============================================================
-- ФУНКЦИЯ: Проверка текущего оружия
-- ============================================================
local function CheckWeapon()
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    
    -- Если оружие не изменилось - ничего не делаем
    if weapon == currentWeapon then
        return
    end
    
    -- Оружие изменилось - обновляем
    currentWeapon = weapon
    
    -- Проверяем что это за оружие:
    if Config.ignoreWeapons[weapon] then
        -- Игнорируемое оружие (нож, фонарик) - не меняем кобуру
        DebugPrint("Игнорируемое оружие, кобура не меняется")
        return
        
    elseif Config.holsterWeapons[weapon] then
        -- Пистолет - делаем кобуру ПУСТОЙ
        DebugPrint("Достал пистолет - кобура пустая")
        ChangeHolster(true)
        
    else
        -- Любое другое оружие (винтовка, дробовик) или руки - кобура ЗАПОЛНЕНА
        DebugPrint("Другое оружие или руки - кобура заполнена")
        ChangeHolster(false)
    end
end

-- ============================================================
-- ФУНКЦИЯ: Запуск скрипта отслеживания
-- ============================================================
local function StartHolsterScript()
    if isScriptActive then
        return -- Скрипт уже запущен
    end
    
    -- Проверяем есть ли кобура на игроке
    local hasHolster, pair, isEmpty, texture = HasHolster()
    
    if not hasHolster then
        DebugPrint("Кобуры нет - скрипт НЕ запускается")
        return
    end
    
    -- Сохраняем активную пару и текущее состояние
    activePair = pair
    isHolsterEmpty = isEmpty
    isScriptActive = true
    currentTexture = texture
    
    DebugPrint("Скрипт кобуры ЗАПУЩЕН")
    DebugPrint("Активная пара определена, начальное состояние: " .. (isEmpty and "ПУСТАЯ" or "ЗАПОЛНЕННАЯ"))
    
    -- Сбрасываем текущее оружие
    currentWeapon = nil
    
    -- Главный цикл отслеживания оружия
    Citizen.CreateThread(function()
        while isScriptActive do
            Citizen.Wait(Config.checkDelay)
            
            -- Проверяем оружие
            CheckWeapon()
        end
    end)
end

-- ============================================================
-- ФУНКЦИЯ: Остановка скрипта
-- ============================================================
local function StopHolsterScript()
    if not isScriptActive then
        return -- Скрипт уже остановлен
    end
    
    isScriptActive = false
    DebugPrint("Скрипт кобуры ОСТАНОВЛЕН")
    
    -- Возвращаем заполненную кобуру если она была
    if activePair then
        ChangeHolster(false)
    end
    
    -- Сбрасываем активную пару
    activePair = nil
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ: Отслеживание смены одежды
-- ============================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.clothingCheckDelay)
        
        local hasHolster, currentPair, isEmpty, texture = HasHolster()
        
        -- Если кобуры нет и скрипт активен - останавливаем
        if not hasHolster and isScriptActive then
            DebugPrint("Кобура снята - останавливаем скрипт")
            StopHolsterScript()
        end
        
        -- Если кобура есть
        if hasHolster then
            -- Если скрипт не активен - запускаем
            if not isScriptActive then
                DebugPrint("Обнаружена кобура - запускаем скрипт")
                StartHolsterScript()
            else
                -- Скрипт активен - проверяем не сменилась ли кобура на другую пару
                if currentPair ~= activePair or texture ~= currentTexture then
                    DebugPrint("Кобура изменена на другую модель - перезапускаем с новой парой")
                    StopHolsterScript()
                    Citizen.Wait(100)
                    StartHolsterScript()
                end
            end
        end
    end
end)

-- ============================================================
-- СОБЫТИЕ: При спавне персонажа
-- ============================================================
AddEventHandler("playerSpawned", function()
    Citizen.Wait(2000) -- Ждём полной загрузки
    
    DebugPrint("Персонаж загружен, проверяем кобуру...")
    
    local hasHolster = HasHolster()
    if hasHolster then
        DebugPrint("Кобура обнаружена при спавне")
        StartHolsterScript()
    else
        DebugPrint("Кобуры нет при спавне")
    end
end)

-- ============================================================
-- КОМАНДА ДЛЯ ОТЛАДКИ 
-- ============================================================
RegisterCommand("testholster", function()
    print("=== ТЕСТ КОБУРЫ ===")
    print("isScriptActive: " .. tostring(isScriptActive))
    print("isHolsterEmpty: " .. tostring(isHolsterEmpty))
    print("currentWeapon: " .. tostring(currentWeapon))
    print("activePair: " .. tostring(activePair ~= nil))
    
    -- Проверяем текущую кобуру
    local hasHolster, pair, isEmpty, texture = HasHolster()
    print("На игроке кобура: " .. tostring(hasHolster))
    if hasHolster then
        print("Состояние: " .. (isEmpty and "ПУСТАЯ" or "ЗАПОЛНЕННАЯ"))
    end
    
    print("Текущая одежда в слоте " .. Config.holsterComponent .. ":")
    local ped = PlayerPedId()
    print("  Drawable: " .. GetPedDrawableVariation(ped, Config.holsterComponent))
    print("  Texture: " .. GetPedTextureVariation(ped, Config.holsterComponent))
end, false)

-- Команда для перезапуска скрипта
RegisterCommand("restartholster", function()
    print("[HOLSTER] Принудительный перезапуск...")
    StopHolsterScript()
    Citizen.Wait(500)
    StartHolsterScript()
end, false)



