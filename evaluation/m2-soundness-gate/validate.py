#!/usr/bin/env python3

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = Path(__file__).with_name("gate.v1.json")
EXPECTED_GROUPS = {
    "subject_alignment",
    "difference_regions",
    "cause_envelopes",
    "report_reference_closure",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate(document: object) -> None:
    require(isinstance(document, dict), "gate must be an object")
    require(document.get("schema_version") == "svgdiff-m2-soundness-gate/1", "gate identity drifted")
    require(document.get("milestone") == "M2", "milestone drifted")
    require(document.get("claim_scope") == "declared_supported_profile_only", "claim scope widened")
    groups = document.get("obligation_groups")
    require(isinstance(groups, list), "obligation groups missing")
    group_ids: set[str] = set()
    for group in groups:
        require(isinstance(group, dict), "group must be an object")
        group_id = group.get("id")
        require(isinstance(group_id, str) and group_id not in group_ids, "bad or duplicate group id")
        group_ids.add(group_id)
        properties = group.get("required_properties")
        require(isinstance(properties, list) and len(properties) >= 5, f"{group_id}: obligations incomplete")
        require(all(isinstance(item, str) and item for item in properties), f"{group_id}: bad property")
        require(len(properties) == len(set(properties)), f"{group_id}: duplicate property")
        evidence = group.get("evidence")
        require(isinstance(evidence, list) and evidence, f"{group_id}: evidence missing")
        for relative in evidence:
            require(isinstance(relative, str) and (ROOT / relative).is_file(), f"{group_id}: missing {relative}")
    require(group_ids == EXPECTED_GROUPS, "soundness group inventory drifted")

    mutation = document.get("mutation_contract")
    require(isinstance(mutation, dict), "mutation contract missing")
    specs = json.loads((ROOT / mutation["specification"]).read_text(encoding="utf-8"))
    require(len(specs.get("cases", [])) == mutation.get("cases") == 59, "mutation case count drifted")
    coverage = specs.get("coverage_contract")
    require(isinstance(coverage, dict), "mutation coverage contract missing")
    require(len(coverage.get("subject_kinds", [])) == mutation.get("subject_kinds") == 6, "subject-kind count drifted")
    require(len(coverage.get("source_properties", [])) == mutation.get("source_properties") == 44, "source-property count drifted")
    require(mutation.get("complete_directional_reports") == 40, "complete directional count drifted")
    require(mutation.get("complete_regions") == 42, "complete region count drifted")

    commands = document.get("suite_commands")
    require(isinstance(commands, list) and len(commands) == 6, "suite command inventory drifted")
    for command in commands:
        require(isinstance(command, str) and command.startswith("sh scripts/"), "bad suite command")
        require((ROOT / command.removeprefix("sh ")).is_file(), f"missing suite command: {command}")
    forbidden = document.get("forbidden_claims")
    require(isinstance(forbidden, list) and len(set(forbidden)) >= 6, "forbidden claims incomplete")


def negative_controls(document: dict) -> None:
    missing_group = copy.deepcopy(document)
    missing_group["obligation_groups"].pop()
    widened = copy.deepcopy(document)
    widened["claim_scope"] = "all_svg"
    wrong_mutations = copy.deepcopy(document)
    wrong_mutations["mutation_contract"]["cases"] = 58
    for index, mutation in enumerate([missing_group, widened, wrong_mutations]):
        try:
            validate(mutation)
        except ValueError:
            continue
        raise AssertionError(f"negative control {index} was accepted")


def main() -> None:
    document = json.loads(ARTIFACT.read_text(encoding="utf-8"))
    validate(document)
    negative_controls(document)
    print("M2 soundness gate: 4 obligation groups and 59 mutation cases remain bounded and traceable")


if __name__ == "__main__":
    main()
