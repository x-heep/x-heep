# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza
# Description: Graphical visualization utilities for X-HEEP padring generation.

from x_heep_gen.pads.pad_ring import *
from x_heep_gen.pads.floorplan import *
from x_heep_gen.pads.pad import *


def object_to_tree(obj, name=None, indent="", is_last=True):
    if name is None:
        name = obj.__class__.__name__

    marker = "└─ " if is_last else "├─ "
    new_indent = indent + ("   " if is_last else "│  ")

    # 1. Handle Lists/Tuples (The Pins case)
    if isinstance(obj, (list, tuple)):
        result = [f"{indent}{marker}{name}"]
        for i, item in enumerate(obj):
            last_item = i == len(obj) - 1
            # We label list items by their index [0], [1], etc.
            result.extend(
                object_to_tree(
                    item, name=f"[{i}]", indent=new_indent, is_last=last_item
                )
            )
        return result

    # 2. Check if the object is "Expandable" (Dict or Class instance)
    has_dict = hasattr(obj, "__dict__") and len(getattr(obj, "__dict__")) > 0
    is_dict = isinstance(obj, dict) and len(obj) > 0

    if not (has_dict or is_dict):
        # This is where your Input/Output objects land if they have no __dict__
        # but have a __str__ method.
        return [f"{indent}{marker}{name}: {str(obj)}"]

    # 3. Handle Dictionaries or Objects with __dict__
    result = [f"{indent}{marker}{name}"]
    items = list(obj.items()) if isinstance(obj, dict) else list(obj.__dict__.items())

    # Filter internal logic
    valid_items = [
        (k, v)
        for k, v in items
        if not k.startswith("_") and k not in ["iocell", "bondpad"]
    ]

    for i, (key, value) in enumerate(valid_items):
        last_child = i == len(valid_items) - 1

        # Determine if we should branch or print as string
        if isinstance(value, (list, tuple, dict)) or hasattr(value, "__dict__"):
            # Recurse for complex structures
            result.extend(
                object_to_tree(value, name=key, indent=new_indent, is_last=last_child)
            )
        else:
            # Leaf node
            child_marker = "└─ " if last_child else "├─ "
            result.append(f"{new_indent}{child_marker}{key}: {str(value)}")

    return result


def get_cell_tree(obj):
    return "\n".join(object_to_tree(obj))


def generate_floorplan_visuals(floorplan, padring, filename_base="floorplan"):
    W, H = floorplan.die_dimensions.width, floorplan.die_dimensions.height

    # 1. Collect all cell types for the legend and color mapping
    standard_names = set()
    physical_names = set()
    for pad in padring.pad_list:
        if isinstance(pad, Corner):
            continue
        if isinstance(pad, Physical):
            if pad.iocell:
                physical_names.add(pad.iocell.name)
            if pad.bondpad:
                physical_names.add(pad.bondpad.name)
            # If it's a generic physical pad with no cell name
            if not pad.iocell and not pad.bondpad:
                physical_names.add("Physical_Filler")
        else:
            if pad.iocell:
                standard_names.add(pad.iocell.name)
            if pad.bondpad:
                standard_names.add(pad.bondpad.name)

    standard_names = sorted(list(standard_names))
    physical_names = sorted(list(physical_names))

    # 2. Palette Mapping (Matte)
    color_map = {}
    # Standard: Matte Rainbow
    for i, name in enumerate(standard_names):
        hue = int((i / max(1, len(standard_names))) * 360)
        color_map[name] = f"hsl({hue}, 60%, 70%)"
    # Physical: Matte Muted Blue/Greys
    for i, name in enumerate(physical_names):
        color_map[name] = f"hsl(210, 20%, {60 + (i*5)%30}%)"

    corner_color = "hsl(0, 0%, 75%)"  # Neutral Matte Grey

    # 3. Drawing Engine Logic
    def generate_svg_elements(is_html=False):
        elements = []

        # Rings
        def r_par(m):
            return (
                m[Side.LEFT],
                m[Side.TOP],
                W - m[Side.LEFT] - m[Side.RIGHT],
                H - m[Side.TOP] - m[Side.BOTTOM],
            )

        elements.append(
            f'<rect x="0" y="0" width="{W}" height="{H}" fill="white" stroke="black" stroke-width="15" />'
        )
        elements.append(
            '<rect x="{}" y="{}" width="{}" height="{}" fill="none" stroke="#ff9999" stroke-width="8" />'.format(
                *r_par(floorplan.iocell_margin)
            )
        )
        elements.append(
            '<rect x="{}" y="{}" width="{}" height="{}" fill="none" stroke="#9999ff" stroke-width="8" />'.format(
                *r_par(floorplan.bondpad_margin)
            )
        )
        elements.append(
            '<rect x="{}" y="{}" width="{}" height="{}" fill="none" stroke="#99cc99" stroke-width="8" />'.format(
                *r_par(floorplan.core_margin)
            )
        )

        # Pads
        for pad in padring.pad_list:
            # Tooltip Data
            for c_type in ["iocell", "bondpad"]:
                cell = getattr(pad, c_type, None)
                tip_str = f"{get_cell_tree(pad)}\n{get_cell_tree(cell)}"
                tip_str = tip_str.replace("'", "\\'").replace("\n", "\\n")

                if not cell:
                    # Handle Physical pads that might not have cell objects
                    if isinstance(pad, Physical) and c_type == "iocell":
                        name, color = "Physical_Filler", color_map.get(
                            "Physical_Filler"
                        )
                        # Size logic for generic physical fillers (placeholder size)
                        cw, ch = 50, 100
                    else:
                        continue
                else:
                    name, color = cell.name, color_map.get(cell.name, corner_color)
                    cw, ch = cell.dimension.width, cell.dimension.height

                m = (
                    floorplan.iocell_margin
                    if c_type == "iocell"
                    else floorplan.bondpad_margin
                )
                rl, rt, rr, rb = (
                    m[Side.LEFT],
                    m[Side.TOP],
                    W - m[Side.RIGHT],
                    H - m[Side.BOTTOM],
                )

                if isinstance(pad, Corner):
                    color = corner_color
                    if pad.side == Side.LEFT:
                        px, py = rl, rt
                    elif pad.side == Side.BOTTOM:
                        px, py = rl, rb - ch
                    elif pad.side == Side.RIGHT:
                        px, py = rr - cw, rb - ch
                    elif pad.side == Side.TOP:
                        px, py = rr - cw, rt
                    pw, ph = cw, ch
                else:
                    pos = getattr(pad, f"{c_type}_center_to_ring_edge", 0)
                    if pad.side == Side.LEFT:
                        px, py, pw, ph = rl, rt + pos - cw / 2, ch, cw
                    elif pad.side == Side.BOTTOM:
                        px, py, pw, ph = rl + pos - cw / 2, rb - ch, cw, ch
                    elif pad.side == Side.RIGHT:
                        px, py, pw, ph = rr - ch, rb - pos - cw / 2, ch, cw
                    elif pad.side == Side.TOP:
                        px, py, pw, ph = rr - pos - cw / 2, rt, cw, ch

                extra = (
                    f'onmouseover="showTip(event, \'{tip_str}\')" onmouseout="hideTip()"'
                    if is_html
                    else ""
                )
                elements.append(
                    f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" fill="{color}" stroke="black" stroke-width="2" {extra} />'
                )
        return "\n".join(elements)

    # 4. Generate Flattened SVG
    with open(f"{filename_base}.svg", "w") as f:
        f.write(
            f'<svg width="1200" height="{(1200*H)/W}" viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg">'
        )
        f.write(generate_svg_elements(is_html=False))
        f.write("</svg>")

    # 5. Generate Interactive HTML
    legend_html = []
    for title, names, is_spec in [
        ("Active Cells", standard_names, False),
        ("Physical/Fillers", physical_names, True),
        ("Fixed", ["Corner"], False),
    ]:
        legend_html.append(
            f"<h3 style='margin-top:20px;'>{title}</h3><div style='display:flex; flex-wrap:wrap;'>"
        )
        for n in names:
            c = corner_color if n == "Corner" else color_map[n]
            legend_html.append(
                f"<div style='margin:8px; display:flex; align-items:center;'><div style='width:24px; height:24px; background:{c}; border:1px solid #333; margin-right:8px;'></div><span style='font-size:16px;'>{n}</span></div>"
            )
        legend_html.append("</div>")

    html_template = f"""
    <html>
    <head>
        <style>
            body {{ font-family: 'Segoe UI', sans-serif; padding: 40px; background: #eee; }}
            .container {{ background: white; padding: 20px; border-radius: 12px; max-width: 1200px; margin: auto; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }}
            #tooltip {{ position: absolute; display: none; background: #222; color: #fff; padding: 15px; border-radius: 8px; font-size: 16px; pointer-events: none; z-index: 100; line-height: 1.5; white-space: pre; box-shadow: 0 5px 15px rgba(0,0,0,0.3); }}
            svg {{ width: 100%; height: auto; border: 1px solid #ddd; }}
            rect:hover {{ stroke-width: 10; opacity: 0.8; }}
        </style>
    </head>
    <body>
        <div id="tooltip"></div>
        <div class="container">
            <h2>Floorplan Visualizer</h2>
            <svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg">{generate_svg_elements(is_html=True)}</svg>
            <div class="legend">{''.join(legend_html)}</div>
        </div>
        <script>
            const tip = document.getElementById('tooltip');
            function showTip(e, txt) {{
                tip.innerHTML = txt.replace(/\\\\n/g, '<br>');
                tip.style.display = 'block';
                tip.style.left = (e.pageX + 20) + 'px';
                tip.style.top = (e.pageY + 20) + 'px';
            }}
            function hideTip() {{ tip.style.display = 'none'; }}
        </script>
    </body>
    </html>
    """
    with open(f"{filename_base}.html", "w") as f:
        f.write(html_template)

    print(f"Success: Generated {filename_base}.svg and {filename_base}.html")
