-- FTS.lua
-- ArduPlane 4.6:
--  • se geofence breach, RC loss >5s o GCS loss >10s → DISARM + superfici a full deflection

-- Ottengo gli handle ai canali RC (1=roll, 2=pitch, 3=throttle, 4=yaw)
local chan_roll     = rc:get_channel(1)   -- aileron
local chan_pitch    = rc:get_channel(2)   -- elevator
local chan_throttle = rc:get_channel(3)   -- throttle
local chan_yaw      = rc:get_channel(4)   -- rudder

-- Variabili per lo stato dei failsafe
local rc_lost_time = nil
local reason = "Unknown error"

-- Canale per attivazione manuale
local FTS_channel = 5

-- Funzione che disarma e imposta le superfici a full deflection
local function do_disarm_full()
  gcs:send_text(0, "FTS: " .. reason .. " → FULL DEFLECTION + DISARM")

  -- Modalità Manual (0) prima del disarmo
  vehicle:set_mode(0)

  -- Imposta override PRIMA del disarmo
  SRV_Channels:set_output_pwm_chan_timeout(3, 1100, 2000)  -- throttle
  SRV_Channels:set_output_pwm_chan_timeout(2, 2000, 2000)  -- vtail left
  SRV_Channels:set_output_pwm_chan_timeout(1, 2000, 2000)  -- flaperon left
  SRV_Channels:set_output_pwm_chan_timeout(4, 2000, 2000)  -- vtail right
  SRV_Channels:set_output_pwm_chan_timeout(5, 1100, 2000)  -- flaperon right

  -- Ora disarmo
  arming:disarm()

  return do_disarm_full, 1000
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

-- Ciclo principale: controlla ogni 1000 ms geofence, RC loss e GCS loss
local function update()
  local now = tonumber(millis()) or 0

  -- 1) Attivazione manuale
  local channel_value = tonumber(rc:get_pwm(FTS_channel)) or 0
  if channel_value > 3000 then
    reason = "Manual activation"
    return do_disarm_full()
  end

  -- 2) Geofence breach
  local breaches = tonumber(fence:get_breaches()) or 0
  if breaches ~= 0 then
    local btime   = tonumber(fence:get_breach_time()) or 0
    local names   = get_breach_names(breaches)
    local elapsed = (now - btime) / 1000.0
    gcs:send_text(0, string.format(
      "Geofence breach: %s (%.1f s ago)",
      names,
      elapsed
    ))
    reason = "Geofence breach"
    return do_disarm_full()
  end

  -- 3) RC failsafe: segnale RC assente > 5000 ms
  if rc:has_valid_input() == false then
    if rc_lost_time == nil then
      rc_lost_time = now
    elseif ((now - rc_lost_time) > 5000) then
      reason = "RC signal lost >5s"
      return do_disarm_full()
    end
  else
    -- RC presente → resetto timer
    rc_lost_time = nil
  end

  -- 4) GCS failsafe: assenza di heartbeat > 10000 ms
  local last_gcs = tonumber(gcs:last_seen()) or 0
  if (now - last_gcs) > 10000 then
    reason = "GCS link lost >10s"
    return do_disarm_full()
  end

  return update, 1000
end

return update()