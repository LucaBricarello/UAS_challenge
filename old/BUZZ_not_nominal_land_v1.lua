local landing_center = Location()
landing_center:lat(44.123456 * 1e7)
landing_center:lng(9.123456 * 1e7)
landing_center:alt(0)

local LANDING_RADIUS = 100 -- metri
local has_beeped = false

local function update()
  local now = millis()
  local armed = arming:is_armed()

  -- Se disarmato (a terra presumibilmente)
  if not armed and not has_beeped then
    local loc = ahrs:get_location()
    if loc then
      local dist = landing_center:get_distance(loc)
      if dist > LANDING_RADIUS then
        gcs:send_text(0, string.format(
          "Landing OUTSIDE permitted zone (%.1f m)!", dist
        ))
        -- Suono: 880 Hz per 2 secondi
        notify:play_tune( "MFT240L8 O4aO5dc O4aO5dc L16ababababefefefef" )
        has_beeped = true
      end
    end
  end

  -- Reset beep flag se si arma di nuovo
  if armed then
    has_beeped = false
  end

  return update, 1000
end

return update, 1000