#!/usr/bin/env python3

import argparse
import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path


PREVIEW_CSP = "default-src 'none'; style-src 'unsafe-inline'"
REPORT_CSP = (
    "default-src 'none'; style-src 'unsafe-inline'; "
    "script-src 'unsafe-inline'; frame-src 'self'"
)


class OuterDocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.csp: list[str] = []
        self.iframes: list[dict[str, str | None]] = []
        self.script_count = 0

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        values = dict(attrs)
        if tag == "meta" and values.get("http-equiv") == "Content-Security-Policy":
            self.csp.append(values.get("content") or "")
        elif tag == "iframe":
            self.iframes.append(values)
        elif tag == "script":
            self.script_count += 1


class PreviewDocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.csp: list[str] = []

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        values = dict(attrs)
        if tag == "meta" and values.get("http-equiv") == "Content-Security-Policy":
            self.csp.append(values.get("content") or "")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate static hostile-source HTML isolation invariants."
    )
    parser.add_argument("html", type=Path)
    parser.add_argument("report", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    document = args.html.read_text(encoding="utf-8")
    report = json.loads(args.report.read_text(encoding="utf-8"))

    outer = OuterDocumentParser()
    outer.feed(document)
    if outer.csp != [REPORT_CSP]:
        raise ValueError(f"unexpected report CSP: {outer.csp!r}")
    if outer.script_count != 1:
        raise ValueError(f"expected one fixed report script, got {outer.script_count}")
    if len(outer.iframes) != 2:
        raise ValueError(f"expected two preview iframes, got {len(outer.iframes)}")

    for index, iframe in enumerate(outer.iframes):
        if iframe.get("sandbox") != "":
            raise ValueError(f"preview {index} does not have an empty sandbox")
        source = iframe.get("srcdoc")
        if source is None:
            raise ValueError(f"preview {index} has no srcdoc")
        preview = PreviewDocumentParser()
        preview.feed(source)
        if preview.csp != [PREVIEW_CSP]:
            raise ValueError(f"preview {index} has unexpected CSP: {preview.csp!r}")
        if "https://svgdiff.invalid/" not in source:
            raise ValueError(f"preview {index} lost the hostile external resource probe")

    breakout = '<script id="outer-breakout">'
    if breakout in document:
        raise ValueError("hostile source created an outer script element")
    textarea_match = re.search(
        r'<textarea id="report-data" readonly>(.*?)</textarea>',
        document,
        flags=re.DOTALL,
    )
    if textarea_match is None:
        raise ValueError("embedded report textarea is missing")
    embedded = json.loads(html.unescape(textarea_match.group(1)))
    if embedded != report:
        raise ValueError("embedded report differs from the CLI JSON")

    print("HTML security static validation: sandbox, CSP, escaping, JSON: ok")


if __name__ == "__main__":
    main()
