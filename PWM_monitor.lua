-- PWM_monitor_extended.lua
-- Stampa PWM e funzione assegnata per canali 1–8

local function update()
  for ch = 0, 8 do
    local pwm = SRV_Channels:get_output_pwm(ch)
    local func = param:get("SERVO" .. ch .. "_FUNCTION")
    local label = func and tostring(func) or "?"
    if pwm then
      gcs:send_text(0, string.format("Servo %d: PWM=%d  FUNCTION=%s", ch, pwm, label))
    else
      gcs:send_text(0, string.format("Servo %d: N/D      FUNCTION=%s", ch, label))
    end
  end
  return update, 1000
end

return update, 1000