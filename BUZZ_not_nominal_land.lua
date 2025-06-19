local LANDING_RADIUS = 100 -- metri
local TAKEOFF_RADIUS = 100 -- metri
local on_land_time = nil

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
local takeoff_center = get_mission_location(0)
gcs:send_text(7, string.format("Takeoff WP: lat=%.6f, lon=%.6f", takeoff_center:lat() / 1e7, takeoff_center:lng() / 1e7))
local landing_center = get_mission_location(num_commands - 1)
gcs:send_text(7, string.format("Landing WP: lat=%.6f, lon=%.6f", landing_center:lat() / 1e7, landing_center:lng() / 1e7))

local function update()

  if vehicle:get_likely_flying() == false then

    local now = tonumber(millis()) or 0

    if on_land_time == nil then
      on_land_time = now
    elseif ((now - on_land_time) > 5000) then

      local loc = ahrs:get_location()
      if not loc then
        return update, 1000
      end
      local landing_dist = landing_center:get_distance(loc)
      local takeoff_dist = takeoff_center:get_distance(loc)

      if landing_dist > LANDING_RADIUS and takeoff_dist > TAKEOFF_RADIUS then
        gcs:send_text(1, string.format(
          "⚠️ Landing fuori zona (%.1f m)!", landing_dist
        ))
        notify:play_tune("MFT240L8 O4aO5dc O4aO5dc O4aO5dc O4aO5dc")
        return update, 4000
      end

    end

  else
    -- L'aereo non è più a terra → resetto timer
    on_land_time = nil
  end

  return update, 1000

end

return update()