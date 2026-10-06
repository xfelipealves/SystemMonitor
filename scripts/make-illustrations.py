"""Generates the README illustrations in docs/ (simulated, not real screenshots).

    python3 scripts/make-illustrations.py
"""
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
FONT = "-apple-system, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif"
WHITE, YELLOW, RED, BLUE = "#F2F2F7", "#FFD60A", "#FF453A", "#0A84FF"


# MARK: - Primitives

def text(x, y, s, size=13, fill=WHITE, weight=400, anchor="start"):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}">{s}</text>')


def svg(width, height, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">\n<defs>{defs}</defs>\n' + "\n".join(body) + "\n</svg>\n")


SHADOW = ('<filter id="shadow" x="-20%" y="-10%" width="140%" height="130%">'
          '<feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity="0.45"/></filter>')
WALLPAPER = ('<linearGradient id="wall" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1B1F4B"/>'
             '<stop offset="0.55" stop-color="#3A2A7A"/><stop offset="1" stop-color="#0E5BA8"/></linearGradient>')


def cpu_icon(x, y, c):
    pins = "".join(f'<rect x="{x + 3 + i * 4}" y="{y - 1}" width="1.6" height="2" fill="{c}"/>'
                   f'<rect x="{x + 3 + i * 4}" y="{y + 12}" width="1.6" height="2" fill="{c}"/>' for i in range(3))
    return (f'<rect x="{x + 1}" y="{y + 1}" width="12" height="11" rx="2.5" fill="none" stroke="{c}" stroke-width="1.6"/>'
            f'<rect x="{x + 4.5}" y="{y + 4.5}" width="5" height="4" rx="1" fill="{c}"/>{pins}')


def ram_icon(x, y, c):
    notches = "".join(f'<rect x="{x + 2 + i * 3.6}" y="{y + 10}" width="1.6" height="3" fill="{c}"/>' for i in range(4))
    return f'<rect x="{x}" y="{y + 2}" width="16" height="8" rx="1.5" fill="none" stroke="{c}" stroke-width="1.6"/>{notches}'


def disk_icon(x, y, c):
    return (f'<rect x="{x}" y="{y + 1}" width="17" height="11" rx="3" fill="none" stroke="{c}" stroke-width="1.6"/>'
            f'<line x1="{x}" y1="{y + 7}" x2="{x + 17}" y2="{y + 7}" stroke="{c}" stroke-width="1.4"/>'
            f'<circle cx="{x + 13.5}" cy="{y + 9.7}" r="1" fill="{c}"/>')


def status_item(x, y, values, default_color, spacing=68):
    """The three menu bar indicators. `values` are percentages; colors follow the app's thresholds."""
    parts = []
    for icon, value in zip((cpu_icon, ram_icon, disk_icon), values):
        color = RED if value >= 90 else YELLOW if value >= 75 else default_color
        parts.append(icon(x, y, color))
        parts.append(text(x + 21, y + 12, f"{value}%", 13, color, 500))
        x += spacing
    return parts


def app_icon(x, y, color, size=16):
    return f'<rect x="{x}" y="{y}" width="{size}" height="{size}" rx="{size / 4}" fill="{color}"/>'


# MARK: - Preview: menu bar item with its menu open

def preview():
    width, height = 760, 540
    menu_x, menu_w, row = 330, 400, 22
    memory_rows = [("Google Chrome", "3.1 GB", "#4285F4"), ("Xcode", "2.4 GB", "#1C8CF0"),
                   ("Safari", "1.8 GB", "#1E90FF"), ("Slack", "1.2 GB", "#611F69"),
                   ("Spotify", "640 MB", "#1DB954"), ("Figma", "590 MB", "#F24E1E"),
                   ("node", "410 MB", "#5F6368"), ("Finder", "180 MB", "#3FA9F5")]
    cpu_rows = [("Xcode", "84.2%", "#1C8CF0"), ("Google Chrome", "31.5%", "#4285F4"),
                ("node", "12.0%", "#5F6368"), ("Spotify", "4.3%", "#1DB954"), ("Slack", "2.1%", "#611F69")]

    body = [f'<rect width="{width}" height="{height}" rx="16" fill="url(#wall)"/>',
            f'<rect width="{width}" height="30" fill="#000" opacity="0.35"/>',
            f'<rect x="{menu_x + 8}" y="4" width="214" height="22" rx="6" fill="#FFFFFF" opacity="0.18"/>',
            *status_item(menu_x + 16, 8, (23, 81, 92), WHITE),
            text(width - 24, 20, "Tue Oct 6  5:55 PM", 13, WHITE, 500, "end")]

    rows = 2 + len(memory_rows) + 1 + len(cpu_rows) + 3
    menu_y, menu_h = 36, rows * row + 3 * 11 + 12
    body.append(f'<g filter="url(#shadow)"><rect x="{menu_x}" y="{menu_y}" width="{menu_w}" height="{menu_h}" '
                f'rx="11" fill="#2B2B30" fill-opacity="0.96" stroke="#FFFFFF" stroke-opacity="0.12"/></g>')

    left, right = menu_x + 14, menu_x + menu_w - 14
    y = menu_y + 6

    def separator():
        nonlocal y
        body.append(f'<line x1="{left}" y1="{y + 5.5}" x2="{right}" y2="{y + 5.5}" stroke="#FFFFFF" stroke-opacity="0.12"/>')
        y += 11

    def header(label):
        nonlocal y
        body.append(text(left, y + 15, label, 11, "#8E8E93", 600))
        y += row

    def item(label, value="", icon_color=None, highlighted=False, mark=""):
        nonlocal y
        if highlighted:
            body.append(f'<rect x="{menu_x + 5}" y="{y}" width="{menu_w - 10}" height="{row}" rx="5" fill="{BLUE}"/>')
        if icon_color:
            body.append(app_icon(left, y + 3, icon_color))
        if mark:
            body.append(text(left, y + 15.5, mark, 13, WHITE, 600))
        body.append(text(left + 24, y + 15.5, label))
        body.append(text(right, y + 15.5, value, 13, "#FFFFFF" if highlighted else "#98989D", 400, "end"))
        y += row

    body.append(f'<rect x="{left + 2}" y="{y + 9}" width="3" height="8" fill="{WHITE}"/>'
                f'<rect x="{left + 7}" y="{y + 5}" width="3" height="12" fill="{WHITE}"/>'
                f'<rect x="{left + 12}" y="{y + 11}" width="3" height="6" fill="{WHITE}"/>')
    item("RAM 12.9 GB / 16 GB   ·   Disk 461 GB / 500 GB")
    separator()
    header("Top memory — click to quit")
    for i, (name, value, color) in enumerate(memory_rows):
        item(name, value, color, highlighted=(i == 0))
    separator()
    header("Top CPU")
    for name, value, color in cpu_rows:
        item(name, value, color)
    separator()
    item("Open at Login", mark="✓")
    item("Language", "›")
    item("Quit", "⌘Q")

    body += [text(40, 120, "Real time", 26, "#FFFFFF", 700),
             text(40, 148, "CPU, RAM and disk in", 15, "#D1D1F0"),
             text(40, 168, "your Mac menu bar.", 15, "#D1D1F0")]
    for i, (color, label) in enumerate([(WHITE, "normal"), (YELLOW, "≥ 75%"), (RED, "≥ 90%")]):
        body += [f'<circle cx="48" cy="{210 + i * 26}" r="6" fill="{color}"/>', text(62, 215 + i * 26, label, 14, "#E5E5F7")]
    body += [text(40, 330, "Click an app to quit", 15, "#D1D1F0"), text(40, 350, "or force quit it.", 15, "#D1D1F0")]

    return svg(width, height, body, WALLPAPER + SHADOW)


# MARK: - Quit dialog

def quit_dialog():
    width, height = 420, 360
    box_x, box_w = 70, 280
    body = [f'<rect width="{width}" height="{height}" rx="16" fill="url(#wall)"/>',
            f'<g filter="url(#shadow)"><rect x="{box_x}" y="24" width="{box_w}" height="312" rx="14" '
            f'fill="#2B2B30" fill-opacity="0.97" stroke="#FFFFFF" stroke-opacity="0.12"/></g>']

    # Safari-like icon: blue disc with a compass needle.
    cx, cy = width / 2, 78
    body += [f'<circle cx="{cx}" cy="{cy}" r="30" fill="#FFFFFF"/>',
             f'<circle cx="{cx}" cy="{cy}" r="26" fill="#1E90FF"/>',
             f'<polygon points="{cx + 16},{cy - 16} {cx + 4},{cy + 4} {cx - 4},{cy - 4}" fill="#FF3B30"/>',
             f'<polygon points="{cx - 16},{cy + 16} {cx + 4},{cy + 4} {cx - 4},{cy - 4}" fill="#FFFFFF"/>',
             text(cx, 136, "Quit “Safari”?", 15, "#FFFFFF", 700, "middle")]
    for i, line in enumerate(["This affects 20 processes. Quit closes it",
                              "normally, like ⌘Q. Force Quit ends it",
                              "immediately and unsaved changes are lost."]):
        body.append(text(cx, 160 + i * 16, line, 11.5, "#C7C7CC", 400, "middle"))

    for i, (label, fill, color) in enumerate([("Quit", BLUE, "#FFFFFF"),
                                              ("Force Quit", "#48484D", "#FF6961"),
                                              ("Cancel", "#48484D", "#FFFFFF")]):
        y = 222 + i * 36
        body += [f'<rect x="{box_x + 16}" y="{y}" width="{box_w - 32}" height="28" rx="7" fill="{fill}"/>',
                 text(cx, y + 18.5, label, 13, color, 500, "middle")]

    return svg(width, height, body, WALLPAPER + SHADOW)


# MARK: - Menu bar in light and dark mode

def menu_bar():
    width, height = 760, 132
    body = [f'<rect width="{width}" height="{height}" rx="14" fill="url(#wall)"/>']
    for i, (bar, ink, label) in enumerate([("#F6F6F8", "#1C1C1E", "Light"), ("#1C1C1E", WHITE, "Dark")]):
        y = 18 + i * 54
        body += [f'<rect x="16" y="{y}" width="{width - 32}" height="42" rx="10" fill="{bar}" fill-opacity="0.92"/>',
                 text(36, y + 26, label, 13, ink, 600)]
        for j, values in enumerate([(12, 48, 63), (35, 81, 70), (97, 92, 91)]):
            x = 112 + j * 212
            body.append(f'<rect x="{x - 10}" y="{y + 7}" width="196" height="28" rx="7" fill="{ink}" fill-opacity="0.07"/>')
            body += status_item(x, y + 15, values, ink, spacing=62)
    return svg(width, height, body, WALLPAPER)


for name, render in [("preview.svg", preview), ("quit-dialog.svg", quit_dialog), ("menu-bar.svg", menu_bar)]:
    (DOCS / name).write_text(render(), encoding="utf-8")
    print(f"docs/{name} written")
