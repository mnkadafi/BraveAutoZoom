-- =========================================================
-- Dark Reader Auto
--
-- Main display = monitor eksternal  -> Dark Reader ON
-- Main display = MacBook (Built-in) -> Dark Reader OFF
-- =========================================================

local BRAVE_NAME = "Brave Browser"
local DR_ID      = "eimadpbcbfnmbkopoojfekhnkhdbieeh"

local drTask     = nil
local drDebounce = nil
local drLast     = nil

-- Kunci bersama (GLOBAL) dengan brave-zoom.lua
braveLock = braveLock or false


local function isBuiltin(screen)
    local name = screen:name() or ""
    return name:find("Built%-in")
        or name:find("Color LCD")
        or name:find("Liquid Retina")
        or name:find("Retina Display")
end


local function setDarkReader(enable, onDone)

    if braveLock then
        return false
    end

    if not hs.application.get(BRAVE_NAME) then
        print("Brave tidak berjalan, Dark Reader dilewati")
        if onDone then onDone(false) end
        return true
    end

    local want = enable and "true" or "false"

    local js = "(function(){"
        .. "function f(r,s){var e=r.querySelector(s);if(e)return e;"
        .. "var a=r.querySelectorAll('*');"
        .. "for(var i=0;i<a.length;i++){if(a[i].shadowRoot){var x=f(a[i].shadowRoot,s);if(x)return x;}}"
        .. "return null;}"
        .. "var item=f(document,'#" .. DR_ID .. "');"
        .. "if(!item||!item.shadowRoot)return 'NOT_FOUND';"
        .. "var card=item.shadowRoot.querySelector('#card');"
        .. "var t=item.shadowRoot.querySelector('#enableToggle');"
        .. "if(!card&&!t)return 'NOT_FOUND';"
        .. "var on=card?card.classList.contains('enabled'):!!t.checked;"
        .. "if(on===" .. want .. ")return 'OK:" .. want .. "';"
        .. "try{"
        .. "if(!window.__drSent){window.__drSent=true;"
        .. "chrome.management.setEnabled('" .. DR_ID .. "'," .. want .. ");}"
        .. "}catch(e){return 'NO_API';}"
        .. "return 'WAIT:'+on;"
        .. "})()"

    local jsEscaped = js:gsub("\\", "\\\\"):gsub('"', '\\"')

    local script = [[
tell application "Brave Browser"
    if (count of windows) = 0 then make new window
    set w to front window
    set t to make new tab at end of tabs of w with properties {URL:"brave://extensions"}
    set res to "NOT_FOUND"
    repeat 60 times
        delay 0.15
        try
            set res to (execute t javascript "]] .. jsEscaped .. [[") as text
        end try
        if res starts with "OK" then exit repeat
    end repeat
    if not (res starts with "OK") then
        delay 1
        try
            set res to (execute t javascript "]] .. jsEscaped .. [[") as text
        end try
    end if
    delay 0.4
    close t
    return res
end tell
]]

    braveLock = true

    local thisTask
    thisTask = hs.task.new("/usr/bin/osascript", function(exitCode, stdout, stderr)
        braveLock = false
        drTask = nil

        local out = (stdout or ""):gsub("%s+$", "")
        print("Dark Reader hasil:", exitCode, out, stderr)

        local success = (out == "OK:" .. want)

        if success then
            hs.alert.show("Dark Reader → " .. (enable and "ON" or "OFF"), 3)
        else
            hs.alert.show("Gagal mengubah Dark Reader", 3)
        end

        if onDone then onDone(success) end
    end, { "-e", script })

    drTask = thisTask
    thisTask:start()

    -- Pengaman: matikan task INI kalau menggantung
    hs.timer.doAfter(25, function()
        if drTask == thisTask and thisTask:isRunning() then
            print("Dark Reader: osascript timeout, dihentikan")
            thisTask:terminate()
        end
    end)

    return true
end


local function applyDarkReader(force)

    local primary = hs.screen.primaryScreen()
    local enable  = not isBuiltin(primary)

    if not force and enable == drLast then
        return
    end

    local started = setDarkReader(enable, function(success)
        if success then drLast = enable end
    end)

    -- Kalau Brave sedang dipakai script zoom, coba lagi sebentar lagi
    if not started then
        if drDebounce then drDebounce:stop() end
        drDebounce = hs.timer.doAfter(1.5, function() applyDarkReader(force) end)
    end
end


-- Semua GLOBAL agar tidak di-garbage-collect
drScreenWatcher = hs.screen.watcher.new(function()
    if drDebounce then drDebounce:stop() end
    drDebounce = hs.timer.doAfter(2.5, applyDarkReader)
end)
drScreenWatcher:start()

drWakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidWake
        or event == hs.caffeinate.watcher.systemDidWake then
        if drDebounce then drDebounce:stop() end
        drDebounce = hs.timer.doAfter(5, applyDarkReader)
    end
end)
drWakeWatcher:start()

drAppWatcher = hs.application.watcher.new(function(name, event)
    if name == BRAVE_NAME and event == hs.application.watcher.launched then
        hs.timer.doAfter(5, function() applyDarkReader(true) end)
    end
end)
drAppWatcher:start()

hs.timer.doAfter(3, function() applyDarkReader(true) end)