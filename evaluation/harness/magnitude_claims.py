import json


SCALAR_UNITS = {
    "parameter_abs_user_units": "local_user_units",
    "parameter_signed_user_units": "local_user_units",
    "symmetric_relative": "ratio",
    "parameter_abs_css_px": "css_px",
    "parameter_viewport_fraction": "viewport_diagonal_fraction",
    "parameter_entity_fraction": "entity_diagonal_fraction",
    "geometry_displacement_css_px": "css_px",
    "geometry_viewport_fraction": "viewport_diagonal_fraction",
    "presence_painted_viewport_fraction": "viewport_fraction",
    "raster_changed_pixel_fraction": "pixel_fraction",
    "raster_rgba8_rmse": "rgba8_rmse",
    "raster_linear_premultiplied_rgba_rmse": "linear_premultiplied_rgba_rmse",
}

BOUNDARY_UNITS = {
    "method_id": None,
    "before_sample_count": "boundary_pixel_samples",
    "after_sample_count": "boundary_pixel_samples",
    "mean_css_px": "css_px",
    "p95_css_px": "css_px",
    "max_css_px": "css_px",
}

COVERAGE_UNITS = {
    "method_id": None,
    "before_coverage_css_px2": "css_px2",
    "after_coverage_css_px2": "css_px2",
    "absolute_difference_css_px2": "css_px2",
    "union_coverage_css_px2": "css_px2",
    "fraction": "coverage_union_fraction",
}

INTRINSIC_RASTER_UNITS = {
    "before_width": "intrinsic_pixels",
    "before_height": "intrinsic_pixels",
    "after_width": "intrinsic_pixels",
    "after_height": "intrinsic_pixels",
    "compared_pixels": "pixels",
    "changed_pixels": "pixels",
    "changed_pixel_fraction": "pixel_fraction",
    "rgba8_rmse": "rgba8_rmse",
    "linear_premultiplied_rgba_rmse": "linear_premultiplied_rgba_rmse",
}

PRESENCE_UNITS = {
    "affected_entity_count": "entities",
    "bounds_area_css_px2": "css_px2",
    "bounds_viewport_fraction": "viewport_area_fraction",
    "painted_area_css_px2": "css_px2",
    "painted_viewport_fraction": "viewport_area_fraction",
}

TRANSFORM_UNITS = {
    "kind": None,
    "before_x_css_px": "css_px",
    "before_y_css_px": "css_px",
    "after_x_css_px": "css_px",
    "after_y_css_px": "css_px",
    "delta_x_css_px": "css_px",
    "delta_y_css_px": "css_px",
    "norm_css_px": "css_px",
    "before_degrees": "degrees",
    "after_degrees": "degrees",
    "signed_delta_degrees": "degrees",
    "abs_delta_degrees": "degrees",
    "before_x": "scale_factor",
    "before_y": "scale_factor",
    "after_x": "scale_factor",
    "after_y": "scale_factor",
    "max_abs_delta": "scale_factor",
    "before_matrix": "affine_matrix_coefficients",
    "after_matrix": "affine_matrix_coefficients",
    "before_determinant": "determinant",
    "after_determinant": "determinant",
}


def claim(field, value, unit, status=None):
    return {
        "field": field,
        "status": status or ("measured" if value is not None else "not_computed"),
        "value": value,
        "unit": unit,
    }


def object_claims(prefix, value, units):
    return [
        claim(f"{prefix}.{field}", value[field], unit)
        for field, unit in units.items()
        if field in value
    ]


def difference_magnitude_claims(difference):
    magnitude = difference["magnitude"]
    claims = [
        claim(f"magnitude.{field}", magnitude[field], unit)
        for field, unit in SCALAR_UNITS.items()
    ]

    boundary = magnitude["painted_boundary_displacement"]
    if boundary is None:
        claims.append(
            claim(
                "magnitude.painted_boundary_displacement",
                None,
                "symmetric_nearest_boundary_pixels/v1",
            )
        )
    else:
        claims.extend(
            object_claims(
                "magnitude.painted_boundary_displacement",
                boundary,
                BOUNDARY_UNITS,
            )
        )

    coverage = magnitude["painted_coverage_difference"]
    if coverage is None:
        claims.append(
            claim(
                "magnitude.painted_coverage_difference",
                None,
                "symmetric_alpha_coverage_l1_over_union/v1",
            )
        )
    else:
        claims.extend(
            object_claims(
                "magnitude.painted_coverage_difference",
                coverage,
                COVERAGE_UNITS,
            )
        )

    intrinsic = magnitude["intrinsic_raster"]
    if intrinsic is None:
        claims.append(
            claim(
                "magnitude.intrinsic_raster",
                None,
                "intrinsic_decoded_raster/v1",
            )
        )
    else:
        claims.extend(
            object_claims(
                "magnitude.intrinsic_raster",
                intrinsic,
                INTRINSIC_RASTER_UNITS,
            )
        )

    transform = magnitude.get("transform_effect")
    if transform is not None:
        claims.extend(
            object_claims(
                "magnitude.transform_effect",
                transform,
                TRANSFORM_UNITS,
            )
        )

    if difference.get("parameter_delta_css_px") is not None:
        claims.append(
            claim(
                "parameter_delta_css_px",
                difference["parameter_delta_css_px"],
                "css_px",
            )
        )

    presence = difference.get("presence_magnitude")
    if presence is not None:
        claims.extend(object_claims("presence_magnitude", presence, PRESENCE_UNITS))

    return claims


def claim_key(value):
    return (
        value["field"],
        value["status"],
        json.dumps(value["value"], sort_keys=True, separators=(",", ":")),
        value["unit"],
    )
