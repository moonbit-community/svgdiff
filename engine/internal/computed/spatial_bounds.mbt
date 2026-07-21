///|
pub(all) struct CssBounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn union_bounds(left : CssBounds?, right : CssBounds?) -> CssBounds? {
  match (left, right) {
    (None, None) => None
    (Some(bounds), None) | (None, Some(bounds)) => Some(bounds)
    (Some(left), Some(right)) => {
      let min_x = left.x.min(right.x)
      let min_y = left.y.min(right.y)
      let max_x = (left.x + left.width).max(right.x + right.width)
      let max_y = (left.y + left.height).max(right.y + right.height)
      Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
    }
  }
}

///|
pub fn intersect_bounds(left : CssBounds, right : CssBounds) -> CssBounds? {
  let min_x = left.x.max(right.x)
  let min_y = left.y.max(right.y)
  let max_x = (left.x + left.width).min(right.x + right.width)
  let max_y = (left.y + left.height).min(right.y + right.height)
  if max_x <= min_x || max_y <= min_y {
    None
  } else {
    Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
  }
}

///|
pub fn inflate_bounds(bounds : CssBounds, expansion : Double) -> CssBounds {
  {
    x: bounds.x - expansion,
    y: bounds.y - expansion,
    width: bounds.width + expansion * 2.0,
    height: bounds.height + expansion * 2.0,
  }
}

///|
pub fn transform_bounds(
  bounds : CssBounds,
  transform : @affine_transform.AffineTransform,
) -> CssBounds {
  let points = [
    (bounds.x, bounds.y),
    (bounds.x + bounds.width, bounds.y),
    (bounds.x, bounds.y + bounds.height),
    (bounds.x + bounds.width, bounds.y + bounds.height),
  ]
  let mut min_x = 1.7976931348623157e308
  let mut min_y = 1.7976931348623157e308
  let mut max_x = -1.7976931348623157e308
  let mut max_y = -1.7976931348623157e308
  for point in points {
    let (x, y) = point
    let transformed_x = transform.a * x + transform.c * y + transform.e
    let transformed_y = transform.b * x + transform.d * y + transform.f
    min_x = min_x.min(transformed_x)
    min_y = min_y.min(transformed_y)
    max_x = max_x.max(transformed_x)
    max_y = max_y.max(transformed_y)
  }
  { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
}
