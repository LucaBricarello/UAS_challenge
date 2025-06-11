local LANDING_RADIUS = 100 -- metri
local has_beeped = false

local function get_mission_location(index)

  local cmd = mission:get_item(index)
  if not cmd then
    gcs:send_text(3, "Errore: comando missione non trovato")
    error("Errore: comando missione non trovato", 0)
  end

  local loc = Location()
  loc:lat(cmd:x()) -- lat in 1e7
  loc:lng(cmd:y()) -- lon in 1e7
  loc:alt(cmd:z()) -- alt in cm (circa)
  return loc

end

-- Recupera le ultime coordinate della missione
local num_commands = mission:num_commands()
if not num_commands or num_commands <= 0 then
  gcs:send_text(3, "Errore: missione vuota")
  error("Errore: missione vuota", 0)
end

local landing_center = get_mission_location(num_commands - 1)

gcs:send_text(6, string.format("Landing WP: lat=%.6f, lon=%.6f",
  landing_center:lat() / 1e7, landing_center:lng() / 1e7))

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