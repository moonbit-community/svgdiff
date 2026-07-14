#!/usr/bin/env python3

import json
from pathlib import Path
import unittest

from classify_failures import diagnostic_domain, metric_domain


POLICY = json.loads(
    (Path(__file__).resolve().parent.parent / "failure-classification.v1.json").read_text(
        encoding="utf-8"
    )
)


class FailureClassificationTest(unittest.TestCase):
    def test_renderer_conformance_is_not_feature_coverage(self):
        self.assertEqual(
            diagnostic_domain("renderer_style_precedence_unresolved", POLICY),
            "renderer_conformance",
        )

    def test_unsupported_semantics_are_feature_coverage(self):
        self.assertEqual(
            diagnostic_domain("unsupported_visual_subject", POLICY),
            "feature_coverage",
        )
        self.assertEqual(
            diagnostic_domain("css_variable_syntax_unsupported", POLICY),
            "feature_coverage",
        )

    def test_report_and_agent_metrics_have_different_domains(self):
        self.assertEqual(
            metric_domain("report_region_overlap_macro", POLICY), "report_model"
        )
        self.assertEqual(
            metric_domain("agent_region_overlap_macro", POLICY),
            "agent_interpretation",
        )

    def test_unknown_values_remain_unclassified(self):
        self.assertEqual(diagnostic_domain("new_unknown_gap", POLICY), "unclassified")
        self.assertEqual(metric_domain("new_unknown_metric", POLICY), "unclassified")


if __name__ == "__main__":
    unittest.main()
