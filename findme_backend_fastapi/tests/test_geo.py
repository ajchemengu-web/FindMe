from app.services.geo import lonlat_to_point, point_to_lonlat, snap_to_grid


def test_snap_to_grid_rounds_to_nearest_grid_cell():
    lon, lat = snap_to_grid(36.821946, -1.292066, grid=0.05)
    assert lon == round(36.821946 / 0.05) * 0.05
    assert lat == round(-1.292066 / 0.05) * 0.05


def test_snap_to_grid_is_coarser_than_raw_coordinates():
    raw = (36.821946, -1.292066)
    snapped = snap_to_grid(*raw)
    # ~5km grid should move the point measurably unless it happened to land exactly
    # on a grid line -- assert the snapped value is a clean multiple of the grid size.
    assert round(snapped[0] / 0.05, 6) == round(snapped[0] / 0.05)
    assert round(snapped[1] / 0.05, 6) == round(snapped[1] / 0.05)


def test_point_roundtrip_via_shapely():
    point = lonlat_to_point(36.821946, -1.292066)
    lon, lat = point_to_lonlat(point)
    assert round(lon, 6) == round(36.821946, 6)
    assert round(lat, 6) == round(-1.292066, 6)
