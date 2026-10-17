#!/usr/bin/env python3
"""Exact, read-only checks of art/kit Box collisions; no Godot or physics queries.

Run: python3 tools/check_kit_box_aabbs.py
Tests: python3 tools/test_kit_box_aabbs.py
Supported TSCN subset:
* Plain, non-inherited scenes; one-line headers/properties; literal local
  BoxShape3D.size = Vector3(number, number, number), StaticBody3D children.
* Node3D/MeshInstance3D/StaticBody3D/CollisionShape3D nodes; literal translations.
* External visual meshes/materials are references only, never executed or loaded.
* Fixture list supports integer Y quarter-turns, separate from authored transforms.
  A ramp fixture compares saved high-edge endpoints only, never ramp collision.
  Asset floor_gap=4 means one bottom-face check for each of four rotations;
  grid=24 means six min/max coordinates per Box times four rotations.
Unsupported (FAIL, nonzero exit; never silently skip):
* Node rotation/rotation_degrees/quaternion/scale/transform, even identity values;
  node scripts anywhere (including visual scripts), runtime/export-driven sizes,
  AnimationPlayer or other node types, disabled colliders, expressions/multiline
  syntax, external shapes, inherited/instanced nodes, unknown collision types.
* Unknown headers/properties in nodes or Box shapes, duplicate keys, missing parents.
* Three literal visual instance uniforms are accepted on MeshInstance3D only;
  they never contribute to collision geometry.
The existing ramp_w4_h6_d12.tscn is explicitly excluded as NON-BOX scope, not
claimed checked. Its declared collider must remain ConvexPolygonShape3D; any Box
or other collider there is an error. No other non-Box exclusions are implicit.
--fixture-kit accepts only /tmp/borrowed_shapes_aabb_*/art/kit copies for negative
 tests. There is no arbitrary project/level input and no automatic retry.
"""
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from itertools import combinations, product
from pathlib import Path
import argparse
import json
import re
import sys

GRID = Decimal("0.5")
ZERO = Decimal(0)
ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art" / "kit"
FLOOR_NAME = "floor_w4_h1_d4.tscn"
RAMP_NAME = "ramp_w4_h6_d12.tscn"
COMBINATIONS = ROOT / "tools" / "kit_box_combinations.json"
NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
VECTOR = re.compile(rf"Vector3\(\s*({NUMBER})\s*,\s*({NUMBER})\s*,\s*({NUMBER})\s*\)")
ATTRIBUTE = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|[+-]?\d+)')
NODE_TYPES = {"Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"}
NODE_PROPERTIES = {"position", "mesh", "material_override", "collision_layer", "collision_mask", "shape", "disabled"}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def vector(value):
    match = VECTOR.fullmatch(value)
    require(match is not None, f"unsupported Vector3: {value}")
    return tuple(Decimal(n) for n in match.groups())


@dataclass(frozen=True)
class Box:
    name: str
    low: tuple
    high: tuple

    def placed(self, turns, position=(ZERO, ZERO, ZERO)):
        points = []
        for x, y, z in product(*zip(self.low, self.high)):
            for _ in range(turns):
                x, z = z, -x
            points.append(tuple(a + b for a, b in zip((x, y, z), position)))
        return Box(self.name, tuple(min(p[i] for p in points) for i in range(3)),
                   tuple(max(p[i] for p in points) for i in range(3)))


def parse_scene(path):
    sections = []
    current = None
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        context = f"{path.name}:{number}"
        if line.startswith("["):
            match = re.fullmatch(r"\[(\w+)(?:\s+(.*))?\]", line)
            require(match is not None, f"{context}: unsupported section syntax")
            kind, tail = match[1], match[2] or ""
            require(kind in {"gd_scene", "ext_resource", "sub_resource", "node"}, f"{context}: unsupported section {kind}")
            attrs = {}
            while tail:
                attr = ATTRIBUTE.match(tail)
                require(attr is not None, f"{context}: unsupported header field {tail}")
                require(attr[1] not in attrs, f"{context}: duplicate attribute {attr[1]}")
                attrs[attr[1]] = json.loads(attr[2])
                tail = tail[attr.end():].strip()
            current = (kind, attrs, {})
            sections.append(current)
        else:
            require(current is not None and "=" in line, f"{context}: unsupported property syntax")
            key, value = [s.strip() for s in line.split("=", 1)]
            require(re.fullmatch(r"[\w/]+", key) is not None and value, f"{context}: unsupported property {line}")
            require(key not in current[2], f"{context}: duplicate property {key}")
            current[2][key] = value
    require(sum(kind == "gd_scene" for kind, _, _ in sections) == 1, f"{path.name}: missing/duplicate scene header")
    resources, nodes = {}, {}
    for kind, attrs, props in sections:
        if kind == "sub_resource":
            require("id" in attrs and "type" in attrs and attrs["id"] not in resources, f"{path.name}: invalid/duplicate resource")
            resources[attrs["id"]] = (attrs, props)
        elif kind == "node":
            require("type" in attrs and "name" in attrs and "instance" not in attrs, f"{path.name}: inherited/instanced nodes unsupported")
            require("/" not in attrs["name"] and attrs["name"] not in {".", ".."}, f"{path.name}: unsupported node name")
            parent = attrs.get("parent")
            key = "." if parent is None else (attrs["name"] if parent == "." else parent + "/" + attrs["name"])
            require(key not in nodes, f"{path.name}: duplicate node {key}")
            nodes[key] = (attrs, props)
    require("." in nodes, f"{path.name}: missing root")
    for name, (attrs, _) in nodes.items():
        require(name == "." or attrs.get("parent") in nodes, f"{path.name}:{name}: missing parent")
    return resources, nodes


def read_boxes(path):
    resources, nodes = parse_scene(path)
    declared = []
    for name, (attrs, props) in nodes.items():
        if attrs["type"] == "CollisionShape3D":
            match = re.fullmatch(r'SubResource\("([^"\\]+)"\)', props.get("shape", ""))
            require(match is not None and match[1] in resources, f"{path.name}:{name}: external/missing shape unsupported")
            declared.append((name, props, resources[match[1]]))
    if path.name == RAMP_NAME:
        require(bool(declared) and all(shape[0].get("type") == "ConvexPolygonShape3D" for _, _, shape in declared),
                f"{path.name}: NON-BOX exclusion requires only declared convex colliders")
        return None
    for name, (attrs, props) in nodes.items():
        require(attrs["type"] in NODE_TYPES, f"{path.name}:{name}: unsupported node type {attrs['type']}")
        for key in props:
            if key.startswith("instance_shader_parameters/"):
                require(attrs["type"] == "MeshInstance3D", f"{path.name}:{name}: visual uniform on non-Mesh node")
                value = props[key]
                if key == "instance_shader_parameters/shape_size":
                    require(all(n > ZERO for n in vector(value)), "Invalid visual shape_size")
                elif key == "instance_shader_parameters/color_role":
                    require(value in {"0", "1"}, "Invalid kit color_role")
                elif key == "instance_shader_parameters/ramp_shape":
                    require(value in {"true", "false"}, "Invalid ramp_shape")
                else:
                    raise ValueError(f"{path.name}:{name}: unsupported visual uniform {key}")
                continue
            require(key in NODE_PROPERTIES or key.startswith("metadata/"), f"{path.name}:{name}: unsupported node property {key}")
    boxes = []
    for name, props, (resource, shape) in declared:
        require(resource.get("type") == "BoxShape3D", f"{path.name}:{name}: unsupported collision type {resource.get('type')}")
        require(set(shape) <= {"size", "margin", "resource_local_to_scene"}, f"{path.name}:{name}: unsupported Box property")
        require(props.get("disabled", "false") == "false", f"{path.name}:{name}: disabled Box")
        parent = nodes[name][0].get("parent")
        require(nodes[parent][0]["type"] == "StaticBody3D", f"{path.name}:{name}: Box must belong to StaticBody3D")
        size = vector(shape.get("size", ""))
        require(all(n > ZERO for n in size), f"{path.name}:{name}: non-positive size")
        center = (ZERO, ZERO, ZERO)
        ancestor = name
        visited = set()
        while True:
            require(ancestor not in visited, f"{path.name}:{name}: cyclic ancestry")
            visited.add(ancestor)
            attrs, ancestor_props = nodes[ancestor]
            center = tuple(a + b for a, b in zip(center, vector(ancestor_props.get("position", "Vector3(0,0,0)"))))
            if ancestor == ".":
                break
            ancestor = attrs["parent"]
        boxes.append(Box(name, tuple(c - n / 2 for c, n in zip(center, size)), tuple(c + n / 2 for c, n in zip(center, size))))
    require(bool(boxes), f"{path.name}: no authored Box colliders")
    return boxes


def on_grid(box, context):
    for value in box.low + box.high:
        require(value % GRID == ZERO, f"{context}:{box.name}: outer boundary off 0.5m grid")


def no_overlap(boxes, context):
    count = 0
    for a, b in combinations(boxes, 2):
        widths = [min(a.high[i], b.high[i]) - max(a.low[i], b.low[i]) for i in range(3)]
        require(not all(n > ZERO for n in widths), f"{context}: positive-volume overlap: {a.name} / {b.name}")
        count += 1
    return count


def check_asset(name, boxes, floor):
    pairs = 0
    for turns in range(4):
        turned = [box.placed(turns) for box in boxes]
        context = f"{name}/Y={turns * 90}deg"
        for box in turned:
            on_grid(box, context)
            require(box.low[1] + floor.high[1] == floor.high[1], f"{context}:{box.name}: floor gap/penetration")
            require(all(floor.low[i] <= box.low[i] < box.high[i] <= floor.high[i] for i in (0, 2)),
                    f"{context}:{box.name}: incomplete floor footprint")
        pairs += no_overlap(turned, context)
    n = len(boxes)
    pair_result = f"PASS({pairs})" if pairs else "N/A(0 pairs)"
    print(f"ASSET {name} | Box={n} | grid=PASS({24*n}) | overlap={pair_result} | floor_gap=PASS({4*n}) | footprint=PASS({4*n})")



def check_ramp_coordinates(group, assets, kit):
    """Compare the saved high-edge coordinates only; never infer a ramp collision."""
    require(set(group) == {"name", "kind", "ramp", "floor"}, "Invalid ramp-coordinate group")
    ramp, floor = group["ramp"], group["floor"]
    for item in (ramp, floor):
        require(set(item) == {"asset", "position", "turns"} and type(item["turns"]) is int and item["turns"] == 0,
                "Coordinate-only group supports explicit unrotated placements only")
    require(ramp["asset"] == RAMP_NAME and floor["asset"] == FLOOR_NAME, "Unexpected coordinate-only assets")
    resources, nodes = parse_scene(kit / RAMP_NAME)
    require(not any(k in nodes["."][1] for k in ("width", "height", "length")),
            "Saved ramp coordinate fixture does not support parameter overrides")
    props = nodes["Body/CollisionShape3D"][1]
    match = re.fullmatch(r'SubResource\("([^"\\]+)"\)', props["shape"])
    require(match is not None, "Coordinate-only ramp requires its saved local points")
    attrs, shape = resources[match[1]]
    require(attrs["type"] == "ConvexPolygonShape3D", "Expected saved ramp convex points")
    raw = shape.get("points", "")
    require(raw.startswith("PackedVector3Array(") and raw.endswith(")"), "Unsupported saved ramp point syntax")
    fields = [field.strip() for field in raw[len("PackedVector3Array("):-1].split(",")]
    require(len(fields) >= 6 and len(fields) % 3 == 0 and all(re.fullmatch(NUMBER, field) for field in fields),
            "Unsupported saved ramp coordinates")
    offset = tuple(Decimal(value) for value in ramp["position"])
    require(len(offset) == 3 and all(v.is_finite() for v in offset), "Invalid ramp position")
    for ancestor in (".", "Body", "Body/CollisionShape3D"):
        node_props = nodes[ancestor][1]
        require(not any(k in node_props for k in ("rotation", "rotation_degrees", "scale", "transform", "quaternion")),
                "Unsupported saved ramp coordinate transform")
        offset = tuple(a + b for a, b in zip(offset, vector(node_props.get("position", "Vector3(0,0,0)"))))
    points = [tuple(Decimal(fields[i+j]) + offset[j] for j in range(3)) for i in range(0, len(fields), 3)]
    high_y = max(p[1] for p in points)
    edge = [p for p in points if p[1] == high_y]
    require(len(edge) == 2 and edge[0][2] == edge[1][2] and edge[0][0] != edge[1][0], "High edge must have two distinct aligned endpoints")
    position = tuple(Decimal(v) for v in floor["position"])
    require(len(position) == 3 and all(v.is_finite() for v in position), "Invalid floor position")
    support = assets[FLOOR_NAME][0].placed(0, position)
    for point in edge:
        require(point[1] == support.high[1], f"{group['name']}: high-edge height differs from floor top")
        require(point[2] == support.high[2], f"{group['name']}: high edge differs from floor outer edge")
        require(support.low[0] <= point[0] <= support.high[0], f"{group['name']}: high edge outside floor width")
    print(f"COORD_GROUP {group['name']} | high_y_vs_top=PASS(2) | edge_z=PASS(2) | edge_x_range=PASS(2) | collision=NOT_CHECKED")


def check_combinations(assets, manifest, kit):
    data = json.loads(manifest.read_text(encoding="utf-8"), parse_float=Decimal)
    require(set(data) == {"combinations"} and bool(data["combinations"]), "Invalid combination list")
    for group in data["combinations"]:
        if group.get("kind") == "ramp_high_edge_coordinates":
            check_ramp_coordinates(group, assets, kit)
            continue
        require(set(group) == {"name", "instances", "seams"} and group["instances"] and group["seams"], "Invalid combination schema")
        context = group["name"]
        placed = {}
        for instance in group["instances"]:
            require(set(instance) == {"id", "asset", "position", "turns"}, f"{context}: invalid instance schema")
            name, asset, turns = instance["id"], instance["asset"], instance["turns"]
            require(name not in placed and asset in assets, f"{context}: duplicate id or non-Box asset")
            require(type(turns) is int and 0 <= turns <= 3, f"{context}: turns must be 0..3")
            position = tuple(Decimal(v) for v in instance["position"])
            require(len(position) == 3 and all(v.is_finite() for v in position), f"{context}: invalid placement")
            placed[name] = [Box(name + "/" + b.name, b.low, b.high).placed(turns, position) for b in assets[asset]]
        boxes = [box for group_boxes in placed.values() for box in group_boxes]
        pairs = no_overlap(boxes, context)
        seams = 0
        for seam in group["seams"]:
            require(set(seam) == {"from", "to", "axis", "area_m2"}, f"{context}: invalid seam schema")
            require(seam["from"] in placed and seam["to"] in placed and seam["from"] != seam["to"] and seam["axis"] in "xyz" and len(seam["axis"]) == 1, f"{context}: invalid seam")
            axis = "xyz".index(seam["axis"])
            area = ZERO
            gaps = []
            for first, second in product(placed[seam["from"]], placed[seam["to"]]):
                widths = [max(ZERO, min(first.high[i], second.high[i]) - max(first.low[i], second.low[i])) for i in range(3) if i != axis]
                projected_area = widths[0] * widths[1]
                if projected_area > ZERO:
                    gaps.append(second.low[axis] - first.high[axis])
                    if first.high[axis] == second.low[axis]:
                        area += projected_area
            require(bool(gaps), f"{context}: seam has no overlapping face projection")
            gap = min(gaps, key=abs)
            require(gap == ZERO, f"{context}: seam {seam['from']}->{seam['to']} gap={gap}m (expected 0)")
            expected = Decimal(seam["area_m2"])
            require(expected > ZERO and area == expected, f"{context}: zero-gap seam {seam['from']}->{seam['to']} requires area {expected}, got {area}")
            seams += 1
        # Diagnose a requested seam gap before secondary off-grid coordinates.
        for box in boxes:
            on_grid(box, context)
        print(f"GROUP {context} | Box={len(boxes)} | grid=PASS({6*len(boxes)}) | overlap=PASS({pairs}) | zero_gap_seam=PASS({seams})")
    return len(data["combinations"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-kit", type=Path, help="Only /tmp/borrowed_shapes_aabb_*/art/kit copies for tests")
    args = parser.parse_args()
    try:
        kit = KIT.resolve()
        manifest = COMBINATIONS
        if args.fixture_kit:
            kit = args.fixture_kit.resolve()
            tmp = Path("/tmp").resolve()
            relative = kit.relative_to(tmp)
            require(len(relative.parts) == 3 and relative.parts[0].startswith("borrowed_shapes_aabb_") and relative.parts[1:] == ("art", "kit"), "Fixture must be /tmp/borrowed_shapes_aabb_*/art/kit")
            manifest = kit.parents[1] / "tools" / COMBINATIONS.name
        paths = sorted(kit.glob("*.tscn"))
        require(bool(paths), "No art/kit scenes")
        assets = {}
        for path in paths:
            require(path.resolve().parent == kit, f"Outside kit via symlink: {path}")
            boxes = read_boxes(path)
            if boxes is None:
                print(f"EXCLUDED {path.name} | registered NON-BOX asset; 0 Box checks, not a PASS")
            else:
                assets[path.name] = boxes
        require(FLOOR_NAME in assets and len(assets[FLOOR_NAME]) == 1, "Missing single-Box floor reference")
        floor = assets[FLOOR_NAME][0]
        require(floor.low[1] == ZERO and floor.high[1] == GRID, "Floor reference must span Y=0..0.5m")
        print("COUNT_UNITS grid=scalar min/max coordinates; overlap=Box pairs; floor_gap=bottom faces; footprint=rectangles; seam=declared contact faces")
        for name, boxes in assets.items():
            check_asset(name, boxes, floor)
        group_count = check_combinations(assets, manifest, kit)
        print(f"PASS: {len(assets)} Box assets / {sum(map(len, assets.values()))} Boxes / {group_count} fixed groups (Box + coordinate-only); no Godot queries")
        return 0
    except (OSError, ValueError, InvalidOperation, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
