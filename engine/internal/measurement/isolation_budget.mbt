///|
fn isolated_render_budget_allows(
  comparisons : Int,
  raster_pixels : Int,
  pixels : Int,
) -> Bool {
  comparisons < 64 &&
  pixels <= 1_048_576 &&
  raster_pixels + pixels * 2 <= 4_194_304
}
