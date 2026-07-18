///|
/// Cooperative controls for one embedded comparison.
///
/// `should_cancel` is evaluated at deterministic engine checkpoints.
/// `max_checkpoints = None` disables deterministic work interruption.
pub(all) struct ComparisonControl {
  should_cancel : () -> Bool
  max_checkpoints : Int?
}

///|
/// The comparison stopped before a Structured Report was established.
pub(all) suberror ComparisonInterrupted {
  Cancelled
  CheckpointBudgetExceeded(max_checkpoints~ : Int)
} derive(Debug, Eq)

///|
/// Construct a control that never interrupts comparison work.
pub fn ComparisonControl::unlimited() -> ComparisonControl {
  let should_cancel : () -> Bool = () => false
  { should_cancel, max_checkpoints: None }
}

///|
priv struct ComparisonGuard {
  control : ComparisonControl
  mut completed_checkpoints : Int
}

///|
fn ComparisonGuard::new(control : ComparisonControl) -> ComparisonGuard {
  { control, completed_checkpoints: 0 }
}

///|
fn ComparisonGuard::checkpoint(
  self : ComparisonGuard,
) -> Unit raise ComparisonInterrupted {
  if (self.control.should_cancel)() {
    raise Cancelled
  }
  match self.control.max_checkpoints {
    Some(maximum) =>
      if maximum <= self.completed_checkpoints {
        raise CheckpointBudgetExceeded(max_checkpoints=maximum)
      }
    None => ()
  }
  self.completed_checkpoints += 1
}
