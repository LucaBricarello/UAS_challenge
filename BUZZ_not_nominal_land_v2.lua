local LANDING_RADIUS = 100 -- metri
local has_beeped = false

-- Recupera le ultime coordinate della missione
local function get_landing_point()

  local num = mission:num_commands()
  if not num or num <= 0 then
    gcs:send_text(3, "Errore: missione vuota")
    error("Errore: missione vuota", 0)
  end

  local cmd = mission:get_item(num - 1)
  if not cmd then
    gcs:send_text(3, "Errore: comando missione finale non trovato")
    error("Errore: comando missione finale non trovato", 0)
  end

  local landing_center = Location()
  landing_center:lat(cmd:x()) -- lat in 1e7
  landing_center:lng(cmd:y()) -- lon in 1e7
  landing_center:alt(cmd:z()) -- alt in cm (circa)
  gcs:send_text(6, string.format("Landing WP: lat=%.6f, lon=%.6f",
    cmd:x() / 1e7, cmd:y() / 1e7))
  return landing_center

end

local landing_center = get_landing_point()

local function update()

  if arming:is_armed() then
    -- Reset flag se si arma di nuovo
    has_beeped = false
    return update, 1000
  end

  -- Se disarmato (a terra presumibilmente)
  if not has_beeped then

    local loc = ahrs:get_location()
    if not loc then
      return update, 1000
    end

    local dist = landing_center:get_distance(loc)
    if dist > LANDING_RADIUS then
      gcs:send_text(1, string.format(
        "⚠️ Landing fuori zona (%.1f m)!", dist
      ))
      -- Se vuoi far suonare qualcosa, qui va il comando futuro
      has_beeped = true
    end

  end

  return update, 1000

end

return update()