#!/usr/bin/env python3
"""Verify that the committed generated conformance data is in sync with the
httpwg JSON snapshots in `testdata/httpwg/`.

The check:
  1. verifies each snapshot still matches the SHA-256 recorded in
     `SOURCE.json` at import time;
  2. backs up the committed generated files, re-runs the importer in-place
     (so `moon fmt` applies within the project), diffs the regeneration
     against the committed files, and restores the committed files
     afterwards.

It exits non-zero when the snapshots have drifted or the generated data
would change. Run as part of `verify_all.ps1`; no network access is
required.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
IMPORTER = os.path.join(HERE, "import_httpwg_tests.py")
DATA_DIR = os.path.join(ROOT, "testdata", "httpwg")
SOURCE_JSON = os.path.join(DATA_DIR, "SOURCE.json")
GENERATED_PREFIX = "httpwg_conformance_data"


def list_generated() -> list[str]:
    return sorted(
        name
        for name in os.listdir(ROOT)
        if name.startswith(GENERATED_PREFIX) and name.endswith(".mbt")
    )


def main() -> int:
    problems: list[str] = []

    # 1. Snapshots must match the hashes recorded at import time.
    if not os.path.exists(SOURCE_JSON):
        problems.append("missing %s (run import_httpwg_tests.py first)" % SOURCE_JSON)
    else:
        with open(SOURCE_JSON, encoding="utf-8") as f:
            source = json.load(f)
        recorded = source.get("files", {})
        for name, expected_hash in recorded.items():
            path = os.path.join(DATA_DIR, name)
            if not os.path.exists(path):
                problems.append("snapshot missing: %s" % name)
                continue
            actual = hashlib.sha256(open(path, "rb").read()).hexdigest()
            if actual != expected_hash:
                problems.append(
                    "snapshot changed since import: %s (rerun import_httpwg_tests.py)"
                    % name
                )

    # 2. Regeneration must reproduce the committed generated files exactly.
    committed = list_generated()
    if not committed:
        problems.append("no generated data files committed; run import_httpwg_tests.py")
    else:
        with tempfile.TemporaryDirectory() as backup:
            for name in committed:
                shutil.copy2(os.path.join(ROOT, name), os.path.join(backup, name))
            env = dict(os.environ)
            env.pop("MOON_SFV_IMPORT_TARGET", None)
            proc = subprocess.run(
                [sys.executable, IMPORTER],
                capture_output=True,
                text=True,
                env=env,
                cwd=ROOT,
            )
            if proc.returncode != 0:
                problems.append("importer failed: %s" % proc.stderr.strip())
            else:
                for name in committed:
                    regenerated = os.path.join(ROOT, name)
                    if not os.path.exists(regenerated):
                        problems.append("regeneration missing: %s" % name)
                        continue
                    new = open(regenerated, encoding="utf-8").read()
                    old = open(os.path.join(backup, name), encoding="utf-8").read()
                    if new != old:
                        problems.append(
                            "generated data out of sync: %s (rerun import_httpwg_tests.py)"
                            % name
                        )
            # Restore the committed files regardless of the outcome.
            for name in committed:
                shutil.copy2(os.path.join(backup, name), os.path.join(ROOT, name))

    if problems:
        print("verify_httpwg_snapshot: FAILED")
        for p in problems:
            print("  - %s" % p)
        return 1

    print(
        "verify_httpwg_snapshot: OK (%d snapshots, generated data in sync)"
        % len(os.listdir(DATA_DIR))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
