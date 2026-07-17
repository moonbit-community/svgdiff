#!/usr/bin/env python3

import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import codex_report_only_agent as adapter


def task(case_id="case-1"):
    return {
        "case_id": case_id,
        "acceptance_version": "agent-acceptance/1",
        "prompt": "Read the report.",
        "report": {},
    }


def answer(case_id="case-1"):
    return {
        "case_id": case_id,
        "acceptance_version": "agent-acceptance/1",
        "coverage": {
            "analysis_status": "complete",
            "equality_conclusion": "established",
            "diagnostic_ids": [],
        },
        "differences": [],
        "main_changes": [],
        "limitations": [],
    }


def model_case_id(kwargs):
    model_task = json.loads(kwargs["input"].split("TASK JSON:\n", 1)[1])
    return model_task["case_id"]


class CodexReportOnlyAgentTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="svgdiff-adapter-test-")
        self.root = Path(self.temporary.name)
        self.codex_home = self.root / "source-codex-home"
        self.codex_home.mkdir()
        (self.codex_home / "auth.json").write_text("{}\n", encoding="utf-8")
        self.profile = self.root / "profile.json"
        self.profile.write_text(
            json.dumps(
                {
                    "schema_version": "svgdiff-language-model-benchmark-profile/1",
                    "model": "test-model",
                    "reasoning_effort": "low",
                    "sandbox": "read-only",
                    "disabled_codex_features": ["shell_tool", "unified_exec"],
                    "per_case_timeout_seconds": 1,
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temporary.cleanup()

    def run_adapter(self, result_factory, input_task=None):
        stdin = io.StringIO(json.dumps(input_task or task()))
        stdout = io.StringIO()
        argv = ["adapter", "--profile", str(self.profile), "--codex", "fake-codex"]
        with (
            mock.patch.object(sys, "argv", argv),
            mock.patch.object(sys, "stdin", stdin),
            mock.patch.object(sys, "stdout", stdout),
            mock.patch.dict(os.environ, {"CODEX_HOME": str(self.codex_home)}),
            mock.patch.object(subprocess, "run", side_effect=result_factory),
        ):
            adapter.run()
        return json.loads(stdout.getvalue())

    def successful_result(self, command, **kwargs):
        isolated_home = Path(kwargs["env"]["CODEX_HOME"])
        working_directory = Path(command[command.index("--cd") + 1])
        self.assertIn("--strict-config", command)
        self.assertEqual(command.count("--disable"), 2)
        self.assertIn("shell_tool", command)
        self.assertIn("unified_exec", command)
        exposed_case_id = model_case_id(kwargs)
        self.assertRegex(exposed_case_id, r"^case-[0-9a-f]{16}$")
        self.assertNotEqual(exposed_case_id, "case-1")
        self.assertNotIn('"case_id":"case-1"', kwargs["input"])
        self.assertNotEqual(isolated_home, self.codex_home)
        self.assertEqual([path.name for path in isolated_home.iterdir()], ["auth.json"])
        self.assertEqual(list(working_directory.iterdir()), [])
        output = Path(command[command.index("--output-last-message") + 1])
        output.write_text(json.dumps(answer(exposed_case_id)), encoding="utf-8")
        return subprocess.CompletedProcess(
            command,
            0,
            stdout=json.dumps({"type": "turn.completed"}) + "\n",
            stderr="",
        )

    def test_accepts_schema_valid_tool_free_answer_in_isolated_home(self):
        self.assertEqual(self.run_adapter(self.successful_result), answer())

    def test_rejects_malformed_task(self):
        with mock.patch.object(sys, "stdin", io.StringIO("[]")):
            with self.assertRaisesRegex(ValueError, "task must be an object"):
                adapter.load_task()

    def test_rejects_case_mismatch(self):
        def mismatch(command, **_kwargs):
            output = Path(command[command.index("--output-last-message") + 1])
            output.write_text(json.dumps(answer("wrong-case")), encoding="utf-8")
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps({"type": "turn.completed"}) + "\n",
                stderr="",
            )

        with self.assertRaisesRegex(ValueError, "does not match"):
            self.run_adapter(mismatch)

    def test_rejects_invalid_model_json(self):
        def malformed(command, **_kwargs):
            output = Path(command[command.index("--output-last-message") + 1])
            output.write_text("{", encoding="utf-8")
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps({"type": "turn.completed"}) + "\n",
                stderr="",
            )

        with self.assertRaisesRegex(ValueError, "invalid answer JSON"):
            self.run_adapter(malformed)

    def test_rejects_tool_event(self):
        def tool_event(command, **_kwargs):
            output = Path(command[command.index("--output-last-message") + 1])
            output.write_text(json.dumps(answer()), encoding="utf-8")
            event = {"type": "item.completed", "item": {"type": "command_execution"}}
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps(event) + "\n",
                stderr="",
            )

        with self.assertRaisesRegex(ValueError, "forbidden tool"):
            self.run_adapter(tool_event)

    def test_rejects_nonzero_exit(self):
        def failed(command, **_kwargs):
            return subprocess.CompletedProcess(command, 7, stdout="", stderr="failed")

        with self.assertRaisesRegex(RuntimeError, "Codex exited 7"):
            self.run_adapter(failed)

    def test_rejects_timeout(self):
        def timed_out(command, **_kwargs):
            raise subprocess.TimeoutExpired(command, 1)

        with self.assertRaisesRegex(RuntimeError, "timed out after 1 seconds"):
            self.run_adapter(timed_out)


if __name__ == "__main__":
    unittest.main()
