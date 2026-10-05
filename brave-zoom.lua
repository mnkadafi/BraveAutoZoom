-- =========================================================
-- Brave Auto Zoom
--
-- Main display = MacBook (Built-in)  -> 100%
-- Main display = monitor eksternal   -> 125%
-- =========================================================

local BRAVE_NAME    = "Brave Browser"
local ZOOM_MACBOOK  = "100%"
local ZOOM_EXTERNAL = "125%"

local debounceTimer = nil
local braveTask     = nil
local lastApplied   = nil

-- Kunci bersama (GLOBAL) dengan darkreader-auto.lua
braveLock = braveLock or false


local function changeBraveZoom(targetZoom, onDone)

    if braveLock then
        return false
    end

    if not hs.application.get(BRAVE_NAME) then
        print("Brave tidak sedang berjalan, dilewati")
        if onDone then onDone(false) end
        return true
    end

    -- "125%" -> "1.25", "100%" -> "1" (%g menghindari "1.0")
    local value = string.format("%g", tonumber((targetZoom:gsub("%%", ""))) / 100)

    local js = "(function(){"
        .. "function f(r){var e=r.querySelector('#zoomLevel');if(e)return e;"
        .. "var a=r.querySelectorAll('*');"
        .. "for(var i=0;i<a.length;i++){if(a[i].shadowRoot){var x=f(a[i].shadowRoot);if(x)return x;}}"
        .. "return null;}"
        .. "var s=f(document);if(!s)return 'NOT_FOUND';"
        .. "s.value='" .. value .. "';"
        .. "s.dispatchEvent(new Event('change',{bubbles:true}));"
        .. "return 'OK:'+s.value;"
        .. "})()"

    local jsEscaped = js:gsub("\\", "\\\\"):gsub('"', '\\"')

    local script = [[
tell application "Brave Browser"
    if (count of windows) = 0 then make new window
    set w to front window
    set t to make new tab at end of tabs of w with properties {URL:"brave://settings/braveContent"}
    set res to "NOT_FOUND"
    repeat 40 times
        delay 0.15
        try
            set res to (execute t javascript "]] .. jsEscaped .. [[") as text
        end try
        if res starts with "OK" then exit repeat
    end repeat
    close t
    return res
end tell
]]

    braveLock = true

    local thisTask
    thisTask = hs.task.new("/usr/bin/osascript", function(exitCode, stdout, stderr)
        braveLock = false
        braveTask = nil

        local out = (stdout or ""):gsub("%s+$", "")
        print("Hasil:", exitCode, out, stderr)

        local success = (out == "OK:" .. value)

        print("Alert zoom dipanggil:", success)

        hs.timer.doAfter(0.4, function()
            local msg = success and ("Brave Zoom → " .. targetZoom)
                                 or "Gagal mengubah zoom Brave"
            hs.alert.show(msg, {}, hs.screen.primaryScreen(), 3)
        end)

        if onDone then onDone(success) end
    end, { "-e", script })

    braveTask = thisTask
    thisTask:start()

    -- Pengaman: matikan task INI kalau menggantung lebih dari 25 detik
    hs.timer.doAfter(25, function()
        if braveTask == thisTask and thisTask:isRunning() then
            print("osascript timeout, dihentikan")
            thisTask:terminate()
        end
    end)

    return true
end


-- =========================================================
-- Cek apakah layar adalah layar bawaan MacBook
-- =========================================================

local function isBuiltin(screen)
    local name = screen:name() or ""
    return name:find("Built%-in")
        or name:find("Color LCD")
        or name:find("Liquid Retina")
        or name:find("Retina Display")
end


-- =========================================================
-- Tentukan zoom berdasarkan main display
-- =========================================================

local function applyZoomForCurrentScreen(force)

    local primary = hs.screen.primaryScreen()

    print("Main display:", primary:name(), "| jumlah layar:", #hs.screen.allScreens())

    local target = isBuiltin(primary) and ZOOM_MACBOOK or ZOOM_EXTERNAL

    if not force and target == lastApplied then
        print("Zoom sudah", target, "- dilewati")
        return
    end

    local started = changeBraveZoom(target, function(success)
        if success then lastApplied = target end
    end)

    -- Kalau Brave sedang dipakai script lain, coba lagi sebentar lagi
    if not started then
        if debounceTimer then debounceTimer:stop() end
        debounceTimer = hs.timer.doAfter(1.5, function()
            applyZoomForCurrentScreen(force)
        end)
    end
end


-- =========================================================
-- Trigger otomatis (semua GLOBAL agar tidak di-garbage-collect)
-- =========================================================

local function screenChanged()
    if debounceTimer then debounceTimer:stop() end
    debounceTimer = hs.timer.doAfter(2, function()
        applyZoomForCurrentScreen()
    end)
end

screenWatcher = hs.screen.watcher.new(screenChanged)
screenWatcher:start()

wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidWake
        or event == hs.caffeinate.watcher.systemDidWake then
        if debounceTimer then debounceTimer:stop() end
        debounceTimer = hs.timer.doAfter(4, function()
            applyZoomForCurrentScreen()
        end)
    end
end)
wakeWatcher:start()

appWatcher = hs.application.watcher.new(function(name, event)
    if name == BRAVE_NAME and event == hs.application.watcher.launched then
        hs.timer.doAfter(4, function()
            applyZoomForCurrentScreen(true)
        end)
    end
end)
appWatcher:start()

hs.timer.doAfter(1, function()
    applyZoomForCurrentScreen(true)
end)