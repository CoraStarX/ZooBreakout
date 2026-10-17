#!/usr/bin/env python3
"""Fail-fast negative CLI tests; mutate art/kit copies only under /tmp.

Run: python3 tools/test_kit_box_aabbs.py
Each case runs the production checker once and expects exit=1 plus its own
specific diagnostic. Expected child failures are PASS test outcomes. Any
unexpected result stops this runner immediately; no automatic retries.
Fixtures are retained in /tmp for inspection. No Godot or project writes.
"""
from pathlib import Path
from decimal import Decimal
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art" / "kit"
CHECKER = ROOT / "tools" / "check_kit_box_aabbs.py"
CORNER = "wall_corner_w2_h5_d2.tscn"
ROOT_HEADER = '[node name="KitPiece" type="Node3D"]\n'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Fixture mutation must match exactly once: {old!r}")
    return text.replace(old, new, 1)


def main():
    snapshots = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in KIT.iterdir() if p.is_file()}
    cases = [
        ("box_shift_0_1m", "position = Vector3(0.75, 1.25, 0.25)", "position = Vector3(0.85, 1.25, 0.25)", "outer boundary off 0.5m grid"),
        ("two_boxes_overlap", "position = Vector3(0.75, 1.25, 0.25)", "position = Vector3(0.25, 1.25, 0.25)", "positive-volume overlap"),
        ("node_rotation", ROOT_HEADER, ROOT_HEADER + "rotation = Vector3(0, 1.570796, 0)\n", "unsupported node property rotation"),
        ("node_scale", ROOT_HEADER, ROOT_HEADER + "scale = Vector3(1, 1, 1)\n", "unsupported node property scale"),
        ("scripted_dimensions", ROOT_HEADER, ROOT_HEADER + 'script = ExtResource("99")\n', "unsupported node property script"),
        ("size_expression", "size = Vector3(0.5, 2.5, 1)", "size = Vector3(0.5, 2.5 * 1, 1)", "unsupported Vector3"),
        ("external_shape", 'shape = SubResource("ShapeA")', 'shape = ExtResource("99")', "external/missing shape unsupported"),
    ]
    try:
        for name, old, new, expected in cases:
            directory = Path(tempfile.mkdtemp(prefix="borrowed_shapes_aabb_", dir="/tmp"))
            fixture = directory / "art" / "kit"
            shutil.copytree(KIT, fixture)
            fixture_tools = directory / "tools"
            fixture_tools.mkdir()
            shutil.copy2(ROOT / "tools" / "kit_box_combinations.json", fixture_tools)
            path = fixture / CORNER
            path.write_text(replace_once(path.read_text(encoding="utf-8"), old, new), encoding="utf-8")
            result = subprocess.run([sys.executable, str(CHECKER), "--fixture-kit", str(fixture)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=15,
                                    env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
            output = result.stdout + result.stderr
            if result.returncode != 1 or "FAIL:" not in output or expected not in output:
                raise ValueError(f"{name}: unexpected exit={result.returncode}; fixture={fixture}\n{output}")
            diagnostic = next(line for line in output.splitlines() if line.startswith("FAIL:"))
            print(f"PASS negative {name} | expected exit=1, actual={result.returncode} | {diagnostic}")
            print(f"  fixture: {fixture}")
        directory = Path(tempfile.mkdtemp(prefix="borrowed_shapes_aabb_", dir="/tmp"))
        fixture = directory / "art" / "kit"
        shutil.copytree(KIT, fixture)
        fixture_tools = directory / "tools"
        fixture_tools.mkdir()
        manifest = json.loads((ROOT / "tools" / "kit_box_combinations.json").read_text(encoding="utf-8"))
        wall = next(item for item in manifest["combinations"][0]["instances"] if item["id"] == "wall")
        wall["position"][1] = "0.6"  # floor top 0.5 + deliberate seam gap 0.1m
        (fixture_tools / "kit_box_combinations.json").write_text(json.dumps(manifest), encoding="utf-8")
        result = subprocess.run([sys.executable, str(CHECKER), "--fixture-kit", str(fixture)],
                                cwd=ROOT, text=True, capture_output=True, timeout=15,
                                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        output = result.stdout + result.stderr
        gap_match = re.search(r"seam floor->wall gap=([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)m \(expected 0\)", output)
        gap_value = Decimal(gap_match.group(1)) if gap_match else None
        if (result.returncode == 0 or "FAIL:" not in output or gap_value is None
                or not gap_value.is_finite() or abs(gap_value - Decimal("0.1")) > Decimal("1e-6")):
            raise ValueError(f"combination_wall_lift_0_1m: unexpected exit={result.returncode}; fixture={fixture}\n{output}")
        diagnostic = next(line for line in output.splitlines() if line.startswith("FAIL:"))
        print(f"PASS negative combination_wall_lift_0_1m | gap={gap_value}m, tolerance=1e-6 | expected exit!=0, actual={result.returncode} | {diagnostic}")
        print(f"  fixture: {fixture}")
        if any(hashlib.sha256(p.read_bytes()).hexdigest() != digest for p, digest in snapshots.items()):
            raise ValueError("Original art/kit asset changed during testing")
        print(f"PASS: {len(cases)+1} negative tests; original assets unchanged; no retries")
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"FAIL negative runner: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
