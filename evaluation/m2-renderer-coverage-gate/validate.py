#!/usr/bin/env python3

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = Path(__file__).with_name("gate.v1.json")
EXPECTED_PROFILE = "svgdiff-renderer-conformance-profile/29"
EXPECTED_CHAINS = {
    "renderer_observation",
    "divergence_disposition",
    "capability_projection",
    "coverage_proof",
    "status_composition",
    "unsupported_equality_property",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load(relative: str) -> object:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def validate(document: object) -> None:
    require(isinstance(document, dict), "gate must be an object")
    require(document.get("schema_version") == "svgdiff-m2-renderer-coverage-gate/1", "gate identity drifted")
    require(document.get("milestone") == "M2", "milestone drifted")
    require(document.get("renderer_conformance_profile_id") == EXPECTED_PROFILE, "gate profile drifted")

    baseline_spec = document.get("baseline")
    dispositions_spec = document.get("dispositions")
    require(isinstance(baseline_spec, dict), "baseline specification missing")
    require(isinstance(dispositions_spec, dict), "disposition specification missing")
    baseline = load(baseline_spec["path"])
    dispositions = load(dispositions_spec["path"])
    require(baseline.get("conformance_profile_id") == EXPECTED_PROFILE, "baseline profile drifted")
    require(dispositions.get("conformance_profile_id") == EXPECTED_PROFILE, "disposition profile drifted")
    cases = baseline.get("cases")
    require(isinstance(cases, list), "baseline cases missing")
    exact = [case for case in cases if case.get("comparison") == "exact"]
    divergent = [case for case in cases if case.get("comparison") == "divergent"]
    require(len(cases) == baseline_spec.get("total_cases") == 141, "baseline case count drifted")
    require(len(exact) == baseline_spec.get("exact_cases") == 98, "exact count drifted")
    require(len(divergent) == baseline_spec.get("divergent_cases") == 43, "divergence count drifted")
    disposition_cases = dispositions.get("cases")
    require(isinstance(disposition_cases, list), "disposition cases missing")
    require(len(disposition_cases) == dispositions_spec.get("required_cases") == 43, "disposition count drifted")
    divergent_ids = {case.get("id") for case in divergent}
    disposition_ids = [case.get("id") for case in disposition_cases]
    require(len(disposition_ids) == len(set(disposition_ids)), "duplicate disposition")
    require(set(disposition_ids) == divergent_ids, "divergence disposition closure failed")
    allowed = set(dispositions_spec.get("allowed_kinds", []))
    require(allowed == {"diagnostic", "normalizer", "compositor"}, "disposition kinds drifted")
    require(all(case.get("disposition") in allowed for case in disposition_cases), "unknown disposition kind")

    production = (
        ROOT / "modules" / "svgdiff" / "engine" / "model" / "comparison_profile.mbt"
    ).read_text(encoding="utf-8")
    require(f'renderer_conformance_profile_id: "{EXPECTED_PROFILE}"' in production, "production profile drifted")
    chains = document.get("safety_chains")
    require(isinstance(chains, list), "safety chains missing")
    chain_ids: set[str] = set()
    for chain in chains:
        require(isinstance(chain, dict), "chain must be an object")
        chain_id = chain.get("id")
        require(isinstance(chain_id, str) and chain_id not in chain_ids, "bad or duplicate chain id")
        chain_ids.add(chain_id)
        require(isinstance(chain.get("contract"), str) and chain["contract"], f"{chain_id}: contract missing")
        evidence = chain.get("evidence")
        require(isinstance(evidence, list) and evidence, f"{chain_id}: evidence missing")
        for relative in evidence:
            require(isinstance(relative, str) and (ROOT / relative).is_file(), f"{chain_id}: missing {relative}")
    require(chain_ids == EXPECTED_CHAINS, "safety chain inventory drifted")
    forbidden = document.get("forbidden_inferences")
    require(isinstance(forbidden, list) and len(set(forbidden)) >= 5, "forbidden inference inventory incomplete")


def negative_controls(document: dict) -> None:
    missing_chain = copy.deepcopy(document)
    missing_chain["safety_chains"].pop()
    wrong_profile = copy.deepcopy(document)
    wrong_profile["renderer_conformance_profile_id"] = "svgdiff-renderer-conformance-profile/mismatch"
    wrong_count = copy.deepcopy(document)
    wrong_count["dispositions"]["required_cases"] = 46
    for index, mutation in enumerate([missing_chain, wrong_profile, wrong_count]):
        try:
            validate(mutation)
        except ValueError:
            continue
        raise AssertionError(f"negative control {index} was accepted")


def main() -> None:
    document = json.loads(ARTIFACT.read_text(encoding="utf-8"))
    validate(document)
    negative_controls(document)
    print("M2 renderer and coverage gate: 141 observations, 43 dispositions, and 6 false-equality safety links validated")


if __name__ == "__main__":
    main()
