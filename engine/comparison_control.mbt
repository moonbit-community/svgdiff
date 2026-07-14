///|
/// Cooperative controls for one embedded comparison.
///
/// `should_cancel` is evaluated at deterministic engine checkpoints.
/// `max_elapsed_milliseconds = None` disables elapsed-time interruption.
pub(all) struct ComparisonControl {
  should_cancel : () -> Bool
  max_elapsed_milliseconds : Int?
}

///|
/// The comparison stopped before a Structured Report was established.
pub(all) suberror ComparisonInterrupted {
  Cancelled
  TimeBudgetExceeded(max_elapsed_milliseconds~ : Int)
} derive(Debug, Eq)

///|
/// Construct a control that never interrupts comparison work.
pub fn ComparisonControl::unlimited() -> ComparisonControl {
  let should_cancel : () -> Bool = () => false
  { should_cancel, max_elapsed_milliseconds: None }
}

///|
priv struct ComparisonGuard {
  control : ComparisonControl
  started_at_milliseconds : Int64
}

///|
fn ComparisonGuard::new(control : ComparisonControl) -> ComparisonGuard {
  { control, started_at_milliseconds: @async.now() }
}

///|
fn ComparisonGuard::checkpoint(
  self : ComparisonGuard,
) -> Unit raise ComparisonInterrupted {
  if (self.control.should_cancel)() {
    raise Cancelled
  }
  match self.control.max_elapsed_milliseconds {
    Some(maximum) =>
      if maximum <= 0 ||
        @async.now() - self.started_at_milliseconds >= maximum.to_int64() {
        raise TimeBudgetExceeded(max_elapsed_milliseconds=maximum)
      }
    None => ()
  }
}
