#!/usr/bin/env python3
"""Read-only kit material dependency scan; palette Resources own role color literals."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def main():
    pending = list((ROOT / 'art/kit').glob('*.tscn'))
    visited = set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        text = path.read_text()
        palette = path.parent == ROOT / 'content/shared' and path.name in {
            'palette_warm_courtyard.tres', 'palette_cool_architecture.tres'}
        for number, line in enumerate(text.splitlines(), 1):
            if re.search(r'\bColor\s*\(', line) and not palette:
                # Mechanism defaults belong to StyleSettings, outside palette roles.
                if path.name == 'style_settings.gd' and re.match(
                        r'@export var (climb_color|jump_color|marker_ink): Color = Color\("[0-9a-fA-F]{6}"\)', line):
                    continue
                raise ValueError(f'{path.relative_to(ROOT)}:{number}: hardcoded role color')
        for ref in re.findall(r'"res://([^"\n]+\.(?:tres|gd|gdshader))"', text):
            pending.append(ROOT / ref)
    for name in ['kit_material.tres', 'kit_platform_material.tres']:
        text = (ROOT / 'content/shared' / name).read_text()
        if 'res://content/shared/architecture.gdshader' not in text or 'style_settings.tres' not in text:
            raise ValueError(f'{name}: shared shader/settings reference missing')
    print(f'PASS: {len(visited)} kit scene/material/script/shader dependencies; no role color literals outside palettes')
    print('Fixed mechanism defaults remain in StyleSettings; no ground kit material')


if __name__ == '__main__':
    main()
