-- FTS_disarm_fulldefl.lua
-- ArduPlane 4.6:
--  • se geofence breach, RC loss >5s o GCS loss >10s → DISARM + superfici a full deflection

-- (1) Ottengo gli handle ai canali RC (1=roll, 2=pitch, 3=throttle, 4=yaw)
local chan_roll     = rc:get_channel(1)   -- aileron
local chan_pitch    = rc:get_channel(2)   -- elevator
local chan_throttle = rc:get_channel(3)   -- throttle
local chan_yaw      = rc:get_channel(4)   -- rudder

-- (2) Variabili per lo stato dei failsafe
local rc_lost_time           = nil
local rc_failsafe_triggered  = false
local gcs_failsafe_triggered = false

-- (3) Funzione che disarma e imposta le superfici a full deflection
local function do_disarm_full(reason)
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
end

-- (4) Converte in stringa il bitmask di breach (senza usare 'bit')
local function get_breach_names_safe(raw_b)
  local names   = {}
  local breaches = tonumber(raw_b) or 0
  if breaches == 0 then
    return ""
  end
  -- bit 0 (1) = breach orizzontale
  if (breaches % 2) == 1 then
    table.insert(names, "orizzontale")
  end
  -- bit 1 (2) = breach alt min
  if (math.floor(breaches / 2) % 2) == 1 then
    table.insert(names, "alt min")
  end
  -- bit 2 (4) = breach alt max
  if (math.floor(breaches / 4) % 2) == 1 then
    table.insert(names, "alt max")
  end
  return table.concat(names, " & ")
end

-- (5) Ciclo principale: controlla ogni 1000 ms geofence, RC loss e GCS loss
local function update()
  local now = tonumber(millis()) or 0

  -- 5.1) Geofence breach
  if fence then
    local raw_b    = fence:get_breaches()        -- uint32_t o nil
    local breaches = tonumber(raw_b) or 0
    if breaches ~= 0 then
      local btime   = tonumber(fence:get_breach_time()) or 0
      local names   = get_breach_names_safe(raw_b)
      local elapsed = (now - btime) / 1000.0
      gcs:send_text(0, string.format(
        "Geofence breach: %s (%.1f s fa)",
        (names ~= "" and names) or "sconosciuto",
        elapsed
      ))
      do_disarm_full("Geofence breach")
      return update, 1000
    end
  end

  -- 5.2) RC failsafe: segnale RC assente > 5000 ms
  if rc:has_valid_input() == false then
    if rc_lost_time == nil then
      rc_lost_time = now
    elseif (not rc_failsafe_triggered) and ((now - rc_lost_time) > 5000) then
      rc_failsafe_triggered = true
      do_disarm_full("RC signal lost >5s")
      return update, 1000
    end
  else
    -- RC presente → resetto timer e flag
    rc_lost_time = nil
    rc_failsafe_triggered = false
  end

  -- 5.3) GCS failsafe: assenza di heartbeat > 10000 ms
  local last_gcs = tonumber(gcs:last_seen()) or 0
  if (now - last_gcs) > 10000 then
    if not gcs_failsafe_triggered then
      gcs_failsafe_triggered = true
      do_disarm_full("GCS link lost >10s")
      return update, 1000
    end
  else
    gcs_failsafe_triggered = false
  end

  return update, 1000
end

return update()