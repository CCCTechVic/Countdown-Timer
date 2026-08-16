-- show_countdown.lua for Q-SYS
-- Countdown timer: type in Hours/Minutes/Seconds, then Start/Pause/Reset
-- counts down to zero and latches a "Complete" output when it hits 0.
-- Author: Greg Neil and Stuart Sinclair

--------------------------------------------------------------------------
-- PLUGIN INFO (design-time)
--------------------------------------------------------------------------
PluginInfo = {
  Name = "Show Countdown",
  Version = "1.0.0",
  BuildVersion = "1.0.0",
  Id = "com.gregneilstuartsinclair.showcountdown",
  Author = "Greg Neil and Stuart Sinclair",
  Description = "Countdown clock: type in H/M/S, then Start/Pause/Reset"
}

function GetColor(props)
  return { 200, 76, 76 }
end

function GetPrettyName(props)
  return "Show Countdown"
end

function GetProperties()
  return {}
end

function RectifyProperties(props)
  return props
end

--------------------------------------------------------------------------
-- CONTROLS (design-time)
--------------------------------------------------------------------------
function GetControls(props)
  return {
    { Name = "Hours",   ControlType = "Text", PinStyle = "Both", UserPin = true },
    { Name = "Minutes", ControlType = "Text", PinStyle = "Both", UserPin = true },
    { Name = "Seconds", ControlType = "Text", PinStyle = "Both", UserPin = true },

    { Name = "Time",    ControlType = "Indicator", IndicatorType = "Text",
      PinStyle = "Output", UserPin = true },

    { Name = "Start",   ControlType = "Button", ButtonType = "Momentary",
      PinStyle = "Input", UserPin = true },
    { Name = "Pause",   ControlType = "Button", ButtonType = "Momentary",
      PinStyle = "Input", UserPin = true },
    { Name = "Reset",   ControlType = "Button", ButtonType = "Momentary",
      PinStyle = "Input", UserPin = true },

    { Name = "Complete", ControlType = "Indicator", IndicatorType = "Led",
      PinStyle = "Output", UserPin = true },
  }
end

--------------------------------------------------------------------------
-- LAYOUT (design-time)
--------------------------------------------------------------------------
function GetControlLayout(props)
  local layout = {}
  local graphics = {}

  graphics[1] = {
    Type = "GroupBox",
    Text = "Show Countdown",
    HTextAlign = "Left",
    Position = { 8, 8 },
    Size = { 620, 140 },
  }

  -- Heading labels above each text box (plain graphics text, not bound
  -- to a control)
  graphics[2] = {
    Type = "Text", Text = "Hours",
    HTextAlign = "Center",
    Position = { 16, 24 }, Size = { 60, 20 },
    FontSize = 12, Color = { 200, 200, 200 },
  }
  graphics[3] = {
    Type = "Text", Text = "Minutes",
    HTextAlign = "Center",
    Position = { 86, 24 }, Size = { 60, 20 },
    FontSize = 12, Color = { 200, 200, 200 },
  }
  graphics[4] = {
    Type = "Text", Text = "Seconds",
    HTextAlign = "Center",
    Position = { 156, 24 }, Size = { 60, 20 },
    FontSize = 12, Color = { 200, 200, 200 },
  }

  -- Duration entry boxes (sit below their headings)
  layout["Hours"] = {
    PrettyName = "Hours",
    Style = "Text",
    Position = { 16, 46 },
    Size = { 60, 34 },
    HTextAlign = "Center",
    IsReadOnly = false,
  }
  layout["Minutes"] = {
    PrettyName = "Minutes",
    Style = "Text",
    Position = { 86, 46 },
    Size = { 60, 34 },
    HTextAlign = "Center",
    IsReadOnly = false,
  }
  layout["Seconds"] = {
    PrettyName = "Seconds",
    Style = "Text",
    Position = { 156, 46 },
    Size = { 60, 34 },
    HTextAlign = "Center",
    IsReadOnly = false,
  }

  -- Live countdown display + complete LED
  layout["Time"] = {
    PrettyName = "Time Remaining",
    Style = "Text",
    Position = { 236, 46 },
    Size = { 200, 34 },
    Font = "Monospace",
    TextSize = 22,
    Color = { 230, 230, 230 },
    IsReadOnly = true,
  }
  layout["Complete"] = {
    PrettyName = "Complete",
    Style = "Indicator",
    Position = { 446, 46 },
    Size = { 34, 34 },
    OffColor = { 60, 60, 60 },
    OnColor = { 230, 76, 76 },
  }

  -- Transport buttons (bottom row)
  layout["Start"] = {
    PrettyName = "Start",
    Style = "Button",
    ButtonStyle = "Momentary",
    Position = { 16, 96 },
    Size = { 90, 38 },
    Legend = "Start",
    UnlinkOffColor = true,
    OffColor = { 76, 230, 76 },
  }
  layout["Pause"] = {
    PrettyName = "Pause",
    Style = "Button",
    ButtonStyle = "Momentary",
    Position = { 116, 96 },
    Size = { 90, 38 },
    Legend = "Pause",
    UnlinkOffColor = true,
    OffColor = { 230, 153, 0 },
  }
  layout["Reset"] = {
    PrettyName = "Reset",
    Style = "Button",
    ButtonStyle = "Momentary",
    Position = { 216, 96 },
    Size = { 90, 38 },
    Legend = "Reset",
    UnlinkOffColor = true,
    OffColor = { 230, 76, 76 },
  }

  return layout, graphics
end

--------------------------------------------------------------------------
-- RUNTIME CODE (only executes once the plugin is placed in a live/
-- emulated design)
--------------------------------------------------------------------------
if Controls then

  local remaining = 0       -- whole seconds left, ticks down while running
  local isRunning = false
  local lastTick = nil      -- os.time() at the last 1-second tick

  -- Q-SYS requires named (non-local-scoped) timers so the GC doesn't
  -- reclaim them -- see Q-SYS Timer docs.
  CountdownTimer = Timer.New()

  local function formatTime(seconds)
    local s = math.max(0, math.floor(seconds + 0.5))
    return string.format("%02d:%02d:%02d",
      math.floor(s / 3600),
      math.floor((s % 3600) / 60),
      s % 60)
  end

  -- Reads a text box, clamps it to [lo, hi], writes the sanitized value
  -- back into the box (so garbage input like "abc" or "99" gets fixed
  -- up visibly), and returns the clamped number.
  local function clampField(control, lo, hi)
    local n = tonumber(control.String)
    if n == nil then n = 0 end
    n = math.floor(n)
    if n < lo then n = lo end
    if n > hi then n = hi end
    control.String = tostring(n)
    return n
  end

  local function setDuration()
    local h = clampField(Controls.Hours, 0, 23)
    local m = clampField(Controls.Minutes, 0, 59)
    local sec = clampField(Controls.Seconds, 0, 59)
    remaining = (h * 3600) + (m * 60) + sec
  end

  local function updateDisplay()
    Controls.Time.String = formatTime(remaining)
  end

  local function lockInputs(locked)
    Controls.Hours.IsDisabled = locked
    Controls.Minutes.IsDisabled = locked
    Controls.Seconds.IsDisabled = locked
  end

  local function stopCountdown()
    isRunning = false
    CountdownTimer:Stop()
  end

  local function tick()
    if not isRunning then return end

    local now = os.time()
    local delta = now - lastTick
    lastTick = now
    remaining = remaining - delta

    if remaining <= 0 then
      remaining = 0
      stopCountdown()
      lockInputs(false)
      Controls.Complete.Boolean = true
    end

    updateDisplay()
  end

  local function startTimer()
    if isRunning then return end
    if remaining <= 0 then
      setDuration()
      if remaining <= 0 then return end -- nothing to count down
    end

    Controls.Complete.Boolean = false
    lockInputs(true)
    isRunning = true
    lastTick = os.time()
    CountdownTimer:Start(1) -- tick once a second
    updateDisplay()
  end

  local function pauseTimer()
    if not isRunning then return end
    stopCountdown()
    updateDisplay()
  end

  local function resetTimer()
    if isRunning then return end
    Controls.Complete.Boolean = false
    lockInputs(false)
    setDuration()
    updateDisplay()
  end

  -- Sanitize the boxes as soon as the user tabs out / commits an edit,
  -- so bad input doesn't sit around looking valid.
  Controls.Hours.EventHandler   = function() clampField(Controls.Hours, 0, 23) end
  Controls.Minutes.EventHandler = function() clampField(Controls.Minutes, 0, 59) end
  Controls.Seconds.EventHandler = function() clampField(Controls.Seconds, 0, 59) end

  Controls.Start.EventHandler = startTimer
  Controls.Pause.EventHandler = pauseTimer
  Controls.Reset.EventHandler = resetTimer
  CountdownTimer.EventHandler = tick

  -- initialize display from whatever the boxes are set to at load
  setDuration()
  updateDisplay()
end
