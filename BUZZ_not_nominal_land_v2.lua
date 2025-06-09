local landing_center = Location()
local LANDING_RADIUS = 100 -- metri
local has_beeped = false

-- Recupera l'ultimo comando della missione
local function init_landing_point()
  local num = mission:num_commands()
  if num and num > 0 then
    local cmd = mission:get_item(num - 1)
    if cmd then
      landing_center:lat(cmd:x()) -- lat in 1e7
      landing_center:lng(cmd:y()) -- lon in 1e7
      landing_center:alt(cmd:z()) -- alt in cm (circa)
      gcs:send_text(6, string.format("Landing WP: lat=%.6f, lon=%.6f",
        cmd:x() / 1e7, cmd:y() / 1e7))
    else
      gcs:send_text(3, "Errore: comando missione finale non trovato")
    end
  else
    gcs:send_text(3, "Errore: missione vuota")
  end
end

init_landing_point()

local function update()
  local armed = arming:is_armed()

  -- Se disarmato (a terra presumibilmente)
  if not armed and not has_beeped then
    local loc = ahrs:get_location()
    if loc then
      local dist = landing_center:get_distance(loc)
      if dist > LANDING_RADIUS then
        gcs:send_text(0, string.format(
          "⚠️ Landing fuori zona (%.1f m)!", dist
        ))
        -- Se vuoi far suonare qualcosa, qui va il comando futuro
        has_beeped = true
      end
    end
  end

  -- Reset flag se si arma di nuovo
  if armed then
    has_beeped = false
  end

  return update, 1000
end

return update, 1000