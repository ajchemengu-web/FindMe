"""Small PostGIS <-> Python helpers -- geoalchemy2 gives us WKBElement objects on read;
these convert to/from plain (lon, lat) tuples the way st_x()/st_y() and
ST_SnapToGrid() did in the old RPCs."""
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point


def point_to_lonlat(geom) -> tuple[float, float]:
    shp = to_shape(geom)
    return shp.x, shp.y


def lonlat_to_point(lon: float, lat: float):
    return from_shape(Point(lon, lat), srid=4326)


def snap_to_grid(lon: float, lat: float, grid: float = 0.05) -> tuple[float, float]:
    """Ports ST_SnapToGrid(geom, 0.05) -- ~5km grid, the same "city-level" coarsening
    the original get_device_locations()/get_visible_device_locations() RPCs used.
    Deliberately the same rough v1 approximation, not a real population-weighted fuzz
    radius -- see this project's README for the caveat carried forward unchanged."""
    return round(lon / grid) * grid, round(lat / grid) * grid
