#!/usr/bin/env python3
"""Read-only color reference: WCAG sRGB luminance ratio and circular HSV hue distance.
No acceptance thresholds; hue distance alone is not a perceptual color difference.
"""
from pathlib import Path
import colorsys
import re

ROOT = Path(__file__).resolve().parents[1]


def luminance(rgb):
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return sum(c * w for c, w in zip(linear, (0.2126, 0.7152, 0.0722)))


def main():
    settings = (ROOT / 'content/shared/style_settings.gd').read_text()
    markers = {}
    for role, value in re.findall(r'@export var (climb_color|jump_color): Color = Color\("([0-9a-fA-F]{6})"\)', settings):
        markers[role] = tuple(int(value[i:i+2], 16) / 255 for i in (0, 2, 4))
    if len(markers) != 2:
        raise ValueError('Cannot read both fixed mechanism colors')
    print('Reference only; source albedo, no lighting/fog/toon. No pass/fail thresholds.')
    print('palette,role,mechanism,role_luminance,mechanism_luminance,contrast_ratio,hue_distance_degrees')
    for label, filename in [('A', 'palette_warm_courtyard.tres'), ('B', 'palette_cool_architecture.tres')]:
        text = (ROOT / 'content/shared' / filename).read_text()
        for role, fields in re.findall(r'^(building|platform|ground|highlight|ink) = Color\(([^)]+)\)', text, re.M):
            rgb = tuple(float(v) for v in fields.split(',')[:3])
            for marker, color in markers.items():
                first, second = luminance(rgb), luminance(color)
                ratio = (max(first, second) + 0.05) / (min(first, second) + 0.05)
                h1, s1, _ = colorsys.rgb_to_hsv(*rgb)
                h2, s2, _ = colorsys.rgb_to_hsv(*color)
                hue = min(abs(h1-h2), 1-abs(h1-h2)) * 360
                distance = f'{hue:.2f}' if s1 > 0 and s2 > 0 else 'undefined'
                print(f'{label},{role},{marker},{first:.6f},{second:.6f},{ratio:.3f},{distance}')


if __name__ == '__main__':
    main()
