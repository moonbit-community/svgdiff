// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
pub(all) struct ComparisonGuard {
  control : ComparisonControl
  mut completed_checkpoints : Int
}

///|
pub fn ComparisonGuard::new(control : ComparisonControl) -> ComparisonGuard {
  { control, completed_checkpoints: 0 }
}

///|
pub fn ComparisonGuard::checkpoint(
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

///|
pub extend ComparisonInterrupted with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ComparisonInterrupted with Eq::{not_equal, equal}
