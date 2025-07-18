-- FTS.lua
-- ArduPlane 4.6:
--  • se geofence breach, RC loss >5s o GCS loss >10s → DISARM + superfici a full deflection

-- Ottengo i canali associati alle funzioni servo
local chan_throttle       = tonumber(SRV_Channels:find_channel(70)) or error("throttle not found", 0)
local chan_vtail_left     = tonumber(SRV_Channels:find_channel(79)) or error("vtail_left not found", 0)
local chan_vtail_right    = tonumber(SRV_Channels:find_channel(80)) or error("vtail_right not found", 0)
local chan_flaperon_left  = tonumber(SRV_Channels:find_channel(24)) or error("flaperon_left not found", 0)
local chan_flaperon_right = tonumber(SRV_Channels:find_channel(25)) or error("flaperon_right not found", 0)

-- Variabili per lo stato dei failsafe
local rc_lost_time = nil
local reason = "Unknown error"
local GCS_lost = false

-- Canale per attivazione manuale
local FTS_channel = 12
local FTS_channel_threshold = 1500

-- Forward declaration
local update

gcs:send_text(6, "FTS activated")

-- Funzione che disarma e imposta le superfici a full deflection
local function activate_FTS()
  gcs:send_text(0, "FTS: " .. reason .. " → FULL DEFLECTION + DISARM")

  -- Modalità Manual (0)
  vehicle:set_mode(0)

  -- Attivo Motor Emergency Stop
  rc:run_aux_function(31, '2')

  -- Imposta override
  SRV_Channels:set_output_pwm_chan_timeout(chan_throttle, 1100, 2000)       -- throttle
  SRV_Channels:set_output_pwm_chan_timeout(chan_vtail_left, 2000, 2000)     -- vtail left
  SRV_Channels:set_output_pwm_chan_timeout(chan_vtail_right, 1500, 2000)    -- vtail right
  SRV_Channels:set_output_pwm_chan_timeout(chan_flaperon_left, 2000, 2000)  -- flaperon left
  SRV_Channels:set_output_pwm_chan_timeout(chan_flaperon_right, 2000, 2000) -- flaperon right

  return update, 1000
end

-- Converte in stringa il bitmask di breach (senza usare 'bit')
local function get_breach_names(breaches)
  local names = {}
  if breaches == 0 then
    return "unknown"
  end
  if breaches & 1 then
    table.insert(names, "alt max")
  end
  if breaches & 2 then
    table.insert(names, "circular")
  end
  if breaches & 4 then
    table.insert(names, "poligonal")
  end
  if breaches & 8 then
    table.insert(names, "alt min")
  end
  return table.concat(names, " & ")
end

-- Funzione che attiva il loiter in caso di GCS failsafe
local function GCS_failsafe()
  GCS_lost = true

  -- Se non manuale passa a loiter (12)
  if vehicle:get_mode() ~= 0 then
    vehicle:set_mode(12)
  end
end

-- Ciclo principale: controlla ogni 1000 ms geofence, RC loss e GCS loss
update = function()
  if arming:is_armed() then

    local now = millis()

    -- 1) Attivazione manuale
    local channel_value = tonumber(rc:get_pwm(FTS_channel)) or 0
    if channel_value > FTS_channel_threshold then
      reason = "Manual activation"
      return activate_FTS()
    end

    -- 2) Geofence breach
    local breaches = fence:get_breaches()
    if breaches ~= 0 then
      local btime   = fence:get_breach_time()
      local names   = get_breach_names(breaches)
      local elapsed = (now - btime) / 1000.0
      gcs:send_text(0, string.format(
        "Geofence breach: %s (%.1f s ago)",
        names,
        elapsed
      ))
      reason = "Geofence breach"
      return activate_FTS()
    end

    -- 3) RC failsafe: segnale RC assente > 5000 ms
    if not rc:has_valid_input() then
      if rc_lost_time == nil then
        rc_lost_time = now
      elseif ((now - rc_lost_time) > 5000) then
        reason = "RC signal lost >5s"
        return activate_FTS()
      end
    else
      -- RC presente → resetto timer
      rc_lost_time = nil
    end

    -- 4) GCS failsafe: assenza di heartbeat > 10000 ms
    local last_gcs = gcs:last_seen()
    if (now - last_gcs) > 10000 or GCS_lost then
      if not GCS_lost then
        gcs:send_text(1, "FAILSAFE: GCS link lost >10s → LOITER MODE")
      end
      GCS_failsafe()
    end
  end

  -- Disabilito Motor Emergency Stop
  rc:run_aux_function(31, '0')

  return update, 1000
end

return update()