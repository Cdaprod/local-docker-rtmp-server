class GPSFrame:
    def __init__(self, timestamp, lat, lon, alt=None, bearing=None, speed=None):
        self.timestamp = timestamp
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.bearing = bearing
        self.speed = speed

class CameraState:
    def __init__(self, gps_frame: GPSFrame):
        self.gps = gps_frame
        self.position_xyz = self.latlon_to_xyz(gps_frame.lat, gps_frame.lon)
        self.rotation_euler = self.bearing_to_rotation(gps_frame.bearing)

    def latlon_to_xyz(self, lat, lon):
        # Your projection logic here
        return (x, y, z)

    def bearing_to_rotation(self, bearing_deg):
        return (0, 0, math.radians(-bearing_deg))