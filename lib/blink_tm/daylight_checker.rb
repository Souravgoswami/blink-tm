require 'date'

class DaylightChecker
	attr_reader :latitude, :longitude, :time, :date, :offset_in_hours
	# Each day earth moves across sun about 360 / 365.24 = 0.9856
	EARTH_ORBITAL_DEGREE_PER_DAY = 0.9856

	# Is a constant that adjusts the mean anomaly based on the time of year.
	# It's derived from a more complex formula involving the Earth's orbital eccentricity
	# and the position of perihelion (the point in Earth's orbit that's closest to the Sun).
	MEAN_ANOMALY_ADJUSTMENT = 3.289

	AXIAL_TILT = 0.39782
	TIME_CORRECTION_FACTOR = 0.06571
	DEGREES_TO_RADIANS = Math::PI / 180
	RADIANS_TO_DEGREES = 180 / Math::PI

	# Math.cos(23.44 (angle in degrees) * (Math::PI / 180))
	COSINE_OBLIQUITY_ECLIPTIC = 0.91747

	def initialize(latitude, longitude, time)
		@latitude = latitude
		@longitude = longitude
		@time = time
		@date = time.to_date
		@offset_in_hours = time.utc_offset / 3600.0
	end

	def is_it_dark?
		sunrise_time, sunset_time = sun_times(date, latitude, longitude, offset_in_hours)
		current_time = time.utc.hour + offset_in_hours

		current_time < sunrise_time or current_time > sunset_time
	end

	private

	def sun_times(date, latitude, longitude, offset_in_hours)
		# Calculation of the sun rise/set is based on the papers:
		#    http://williams.best.vwh.net/sunrise_sunset_algorithm.htm
		#    http://aa.quae.nl/en/reken/zonpositie.html

		# Convert the longitude to hour value and calculate an approximate time
		lng_hour = longitude / 15.0

		t_rise = date.yday + ((6 - lng_hour) / 24)
		t_set = date.yday + ((18 - lng_hour) / 24)

		# Calculate the Sun's mean anomaly
		m_rise = (EARTH_ORBITAL_DEGREE_PER_DAY * t_rise) - MEAN_ANOMALY_ADJUSTMENT
		m_set = (EARTH_ORBITAL_DEGREE_PER_DAY * t_set) - MEAN_ANOMALY_ADJUSTMENT

		# Calculate the Sun's true longitude, and adjust angle to be between 0 and 360
		l_rise = (m_rise + (1.916 * Math.sin(m_rise * DEGREES_TO_RADIANS)) + (0.020 * Math.sin(2 * m_rise * DEGREES_TO_RADIANS)) + 282.634) % 360
		l_set = (m_set + (1.916 * Math.sin(m_set * DEGREES_TO_RADIANS)) + (0.020 * Math.sin(2 * m_set * DEGREES_TO_RADIANS)) + 282.634) % 360

		# Calculate the Sun's right ascension, and adjust angle to be between 0 and 360
		ra_rise = RADIANS_TO_DEGREES * Math.atan(COSINE_OBLIQUITY_ECLIPTIC * Math.tan(l_rise * DEGREES_TO_RADIANS))
		ra_rise = (ra_rise + 360) % 360
		ra_set = RADIANS_TO_DEGREES * Math.atan(COSINE_OBLIQUITY_ECLIPTIC * Math.tan(l_set * DEGREES_TO_RADIANS))
		ra_set = (ra_set + 360) % 360

		# Right ascension value needs to be in the same quadrant as L
		l_quadrant_rise  = (l_rise / 90).floor * 90
		ra_quadrant_rise = (ra_rise / 90).floor * 90
		ra_rise = ra_rise + (l_quadrant_rise - ra_quadrant_rise)

		l_quadrant_set  = (l_set / 90).floor * 90
		ra_quadrant_set = (ra_set / 90).floor * 90
		ra_set = ra_set + (l_quadrant_set - ra_quadrant_set)

		# Right ascension value needs to be converted into hours
		ra_rise = ra_rise / 15
		ra_set = ra_set / 15

		# Calculate the Sun's declination
		sin_dec_rise = AXIAL_TILT * Math.sin(l_rise * DEGREES_TO_RADIANS)
		cos_dec_rise = Math.cos(Math.asin(sin_dec_rise))

		sin_dec_set = AXIAL_TILT * Math.sin(l_set * DEGREES_TO_RADIANS)
		cos_dec_set = Math.cos(Math.asin(sin_dec_set))

		# Calculate the Sun's local hour angle
		cos_h_rise = (Math.sin(-0.83 * DEGREES_TO_RADIANS) - (sin_dec_rise * Math.sin(latitude * DEGREES_TO_RADIANS))) / (cos_dec_rise * Math.cos(latitude * DEGREES_TO_RADIANS))
		h_rise = (360 - RADIANS_TO_DEGREES * Math.acos(cos_h_rise)) / 15

		cos_h_set = (Math.sin(-0.83 * DEGREES_TO_RADIANS) - (sin_dec_set * Math.sin(latitude * DEGREES_TO_RADIANS))) / (cos_dec_set * Math.cos(latitude * DEGREES_TO_RADIANS))
		h_set = RADIANS_TO_DEGREES * Math.acos(cos_h_set) / 15

		# Calculate local mean time of rising/setting
		t_rise = h_rise + ra_rise - (TIME_CORRECTION_FACTOR * t_rise) - 6.622
		t_set = h_set + ra_set - (TIME_CORRECTION_FACTOR * t_set) - 6.622

		# Adjust back to UTC, and keep the value between 0 and 24
		ut_rise = (t_rise - lng_hour) % 24
		ut_set = (t_set - lng_hour) % 24

		# Convert UT value to local time zone of latitude/longitude
		local_t_rise = (ut_rise + offset_in_hours) % 24
		local_t_set = (ut_set + offset_in_hours) % 24

		return local_t_rise, local_t_set
	end
end
