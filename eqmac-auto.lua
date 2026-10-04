-- =========================================================
-- eqMac Auto
--
-- Main display = monitor eksternal -> buka eqMac, output H24G30Q
-- Main display = MacBook (Built-in) -> tutup eqMac
-- =========================================================

local EQMAC_NAME     = "eqMac"
local AUDIO_EXTERNAL = "H24G30Q"

local eqTimer       = nil
local eqDebounce    = nil


local function isBuiltin(screen)
    local name = screen:name() or ""
    return name:find("Built%-in")
        or name:find("Color LCD")
        or name:find("Liquid Retina")
        or name:find("Retina Display")
end


local function manageEqMac(useExternal)

    if eqTimer then eqTimer:stop(); eqTimer = nil end

    -- Monitor dicabut -> tutup eqMac (graceful)
    if not useExternal then
        local app = hs.application.get(EQMAC_NAME)
        if app then
            app:kill()
            print("eqMac ditutup")
        end
        return
    end

    -- Monitor dicolok -> tunggu perangkat audio muncul (maks 15 detik)
    local tries = 0
    eqTimer = hs.timer.doEvery(1, function()
        tries = tries + 1

        local dev = hs.audiodevice.findOutputByName(AUDIO_EXTERNAL)

        if dev then
            eqTimer:stop()

            if not hs.application.get(EQMAC_NAME) then
                dev:setDefaultOutputDevice()
                hs.timer.doAfter(0.5, function()
                    hs.execute("/usr/bin/open -a eqMac")
                    print("eqMac dibuka dengan output", AUDIO_EXTERNAL)
                end)
            end

        elseif tries >= 15 then
            eqTimer:stop()
            print("Perangkat audio tidak ditemukan:", AUDIO_EXTERNAL)
        end
    end)
end


local function applyEqMac()
    local primary = hs.screen.primaryScreen()
    manageEqMac(not isBuiltin(primary))
end


-- Semua GLOBAL agar tidak di-garbage-collect
eqScreenWatcher = hs.screen.watcher.new(function()
    if eqDebounce then eqDebounce:stop() end
    eqDebounce = hs.timer.doAfter(2, applyEqMac)
end)
eqScreenWatcher:start()

eqWakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidWake
        or event == hs.caffeinate.watcher.systemDidWake then
        if eqDebounce then eqDebounce:stop() end
        eqDebounce = hs.timer.doAfter(4, applyEqMac)
    end
end)
eqWakeWatcher:start()

-- Saat Hammerspoon start / reload
hs.timer.doAfter(1, applyEqMac)