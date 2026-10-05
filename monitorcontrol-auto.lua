-- =========================================================
-- MonitorControl Auto
--
-- Main display = monitor eksternal  -> buka MonitorControl
-- Main display = MacBook (Built-in) -> tutup MonitorControl
-- =========================================================

local MC_NAME = "MonitorControl"

local mcDebounce = nil


local function isBuiltin(screen)
    local name = screen:name() or ""
    return name:find("Built%-in")
        or name:find("Color LCD")
        or name:find("Liquid Retina")
        or name:find("Retina Display")
end


local function applyMonitorControl()

    local primary = hs.screen.primaryScreen()
    local useExternal = not isBuiltin(primary)
    local app = hs.application.get(MC_NAME)

    if useExternal then
        if not app then
            -- -g = buka di latar belakang, tidak merebut fokus
            hs.execute("/usr/bin/open -g -a MonitorControl")
            print("MonitorControl dibuka")
        end
    else
        if app then
            app:kill()   -- graceful
            print("MonitorControl ditutup")
        end
    end
end


-- Semua GLOBAL agar tidak di-garbage-collect
mcScreenWatcher = hs.screen.watcher.new(function()
    if mcDebounce then mcDebounce:stop() end
    -- 3 detik: beri waktu macOS mendeteksi monitor sebelum MonitorControl start
    mcDebounce = hs.timer.doAfter(3, applyMonitorControl)
end)
mcScreenWatcher:start()

mcWakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidWake
        or event == hs.caffeinate.watcher.systemDidWake then
        if mcDebounce then mcDebounce:stop() end
        mcDebounce = hs.timer.doAfter(5, applyMonitorControl)
    end
end)
mcWakeWatcher:start()

-- Saat Hammerspoon start / reload
hs.timer.doAfter(2, applyMonitorControl)