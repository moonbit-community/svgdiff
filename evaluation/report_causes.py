from typing import Any, Iterable


def report_differences(report: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        item
        for group in report["difference_groups"]
        for item in group["items"]
    ]


def report_difference_ids(report: dict[str, Any]) -> set[str]:
    return {item["id"] for item in report_differences(report)}


def cause_candidate_difference_ids(
    causes: dict[str, Any],
    comparison_difference_ids: Iterable[str],
) -> set[str]:
    difference_ids = set(comparison_difference_ids)
    scope = causes.get("scope")
    if scope == "comparison":
        if "candidate_difference_ids" in causes:
            raise ValueError(
                "comparison-scoped causes must not repeat candidate IDs"
            )
        return difference_ids
    if scope != "event_region":
        raise ValueError(f"unknown possible-cause scope: {scope!r}")
    candidates = causes.get("candidate_difference_ids")
    if not isinstance(candidates, list) or not candidates:
        raise ValueError("event-region causes require candidate IDs")
    if not all(isinstance(identifier, str) for identifier in candidates):
        raise ValueError("possible-cause candidate IDs must be strings")
    if len(candidates) != len(set(candidates)):
        raise ValueError("possible-cause candidate IDs must be unique")
    result = set(candidates)
    if not result <= difference_ids:
        raise ValueError("dangling possible cause")
    return result
