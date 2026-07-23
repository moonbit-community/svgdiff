UNITS = {
    "parameter_abs_user_units": "local_user_units",
    "parameter_signed_user_units": "local_user_units",
    "symmetric_relative": "ratio",
    "parameter_abs_css_px": "css_px",
    "parameter_viewport_fraction": "viewport_diagonal_fraction",
    "parameter_entity_fraction": "entity_diagonal_fraction",
    "geometry_displacement_css_px": "css_px",
    "geometry_viewport_fraction": "viewport_diagonal_fraction",
    "presence_painted_viewport_fraction": "viewport_fraction",
    "raster_changed_fraction": "pixel_fraction",
    "raster_linear_rgba_rmse": "linear_premultiplied_rgba_rmse",
    "before_size": "pixel_dimensions",
    "after_size": "pixel_dimensions",
    "compared_pixels": "pixels",
    "changed_pixels": "pixels",
    "changed_fraction": "pixel_fraction",
    "linear_rgba_rmse": "linear_premultiplied_rgba_rmse",
    "before_css_px2": "css_px2",
    "after_css_px2": "css_px2",
    "absolute_difference_css_px2": "css_px2",
    "union_css_px2": "css_px2",
    "fraction": "coverage_union_fraction",
    "affected_entity_count": "entities",
    "bounds_area_css_px2": "css_px2",
    "bounds_viewport_fraction": "viewport_area_fraction",
    "painted_area_css_px2": "css_px2",
    "painted_viewport_fraction": "viewport_area_fraction",
    "before_sample_count": "boundary_pixel_samples",
    "after_sample_count": "boundary_pixel_samples",
    "mean_css_px": "css_px",
    "p95_css_px": "css_px",
    "max_css_px": "css_px",
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


def claim(field, value, unit):
    return {
        "field": field,
        "status": "measured",
        "value": value,
        "unit": unit,
    }


def flatten_claims(prefix, value):
    if isinstance(value, dict):
        result = []
        for field, item in value.items():
            result.extend(flatten_claims(f"{prefix}.{field}", item))
        return result
    leaf = prefix.rsplit(".", 1)[-1]
    return [claim(prefix, value, UNITS.get(leaf))]


def difference_magnitude_claims(difference):
    magnitude = difference.get("magnitude")
    if not isinstance(magnitude, dict):
        return []
    return flatten_claims("magnitude", magnitude)


def claim_key(value):
    import json

    return (
        value["field"],
        value["status"],
        json.dumps(value["value"], sort_keys=True, separators=(",", ":")),
        value["unit"],
    )
