"""Generates docs/preview.svg: an illustration of the menu bar item and its menu."""
from pathlib import Path

W, H = 760, 540
MENU_X, MENU_W, ROW = 330, 400, 22
FONT = "-apple-system, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif"

memory_rows = [
    ("Google Chrome", "3.1 GB", "#4285F4"),
    ("Xcode", "2.4 GB", "#1C8CF0"),
    ("Safari", "1.8 GB", "#1E90FF"),
    ("Slack", "1.2 GB", "#611F69"),
    ("Spotify", "640 MB", "#1DB954"),
    ("Figma", "590 MB", "#F24E1E"),
    ("node", "410 MB", "#5F6368"),
    ("Finder", "180 MB", "#3FA9F5"),
]
cpu_rows = [
    ("Xcode", "84.2%", "#1C8CF0"),
    ("Google Chrome", "31.5%", "#4285F4"),
    ("node", "12.0%", "#5F6368"),
    ("Spotify", "4.3%", "#1DB954"),
    ("Slack", "2.1%", "#611F69"),
]


def text(x, y, s, size=13, fill="#F2F2F7", weight=400, anchor="start"):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}">{s}</text>')


def cpu_icon(x, y, c):
    pins = "".join(f'<rect x="{x + 3 + i * 4}" y="{y - 1}" width="1.6" height="2" fill="{c}"/>'
                   f'<rect x="{x + 3 + i * 4}" y="{y + 12}" width="1.6" height="2" fill="{c}"/>' for i in range(3))
    return (f'<rect x="{x + 1}" y="{y + 1}" width="12" height="11" rx="2.5" fill="none" stroke="{c}" stroke-width="1.6"/>'
            f'<rect x="{x + 4.5}" y="{y + 4.5}" width="5" height="4" rx="1" fill="{c}"/>{pins}')


def ram_icon(x, y, c):
    notches = "".join(f'<rect x="{x + 2 + i * 3.6}" y="{y + 10}" width="1.6" height="3" fill="{c}"/>' for i in range(4))
    return (f'<rect x="{x}" y="{y + 2}" width="16" height="8" rx="1.5" fill="none" stroke="{c}" stroke-width="1.6"/>'
            f'{notches}')


def disk_icon(x, y, c):
    return (f'<rect x="{x}" y="{y + 1}" width="17" height="11" rx="3" fill="none" stroke="{c}" stroke-width="1.6"/>'
            f'<line x1="{x}" y1="{y + 7}" x2="{x + 17}" y2="{y + 7}" stroke="{c}" stroke-width="1.4"/>'
            f'<circle cx="{x + 13.5}" cy="{y + 9.7}" r="1" fill="{c}"/>')


def app_icon(x, y, color):
    return f'<rect x="{x}" y="{y}" width="16" height="16" rx="4" fill="{color}"/>'


parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <linearGradient id="wall" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#1B1F4B"/><stop offset="0.55" stop-color="#3A2A7A"/><stop offset="1" stop-color="#0E5BA8"/>
  </linearGradient>
  <filter id="shadow" x="-20%" y="-10%" width="140%" height="130%">
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity="0.45"/>
  </filter>
</defs>
<rect width="{W}" height="{H}" rx="16" fill="url(#wall)"/>
<rect width="{W}" height="30" fill="#000" opacity="0.35"/>''']

# Menu bar: our status item, then a few system items.
parts.append(f'<rect x="{MENU_X + 8}" y="4" width="214" height="22" rx="6" fill="#FFFFFF" opacity="0.18"/>')
x = MENU_X + 16
for icon, value, color in [(cpu_icon, "23%", "#F2F2F7"), (ram_icon, "81%", "#FFD60A"), (disk_icon, "92%", "#FF453A")]:
    parts.append(icon(x, 8, color))
    parts.append(text(x + 21, 20, value, 13, color, 500))
    x += 68
parts.append(text(W - 24, 20, "Tue Oct 6  5:55 PM", 13, "#F2F2F7", 500, "end"))

# Dropdown menu.
rows = 1 + 1 + len(memory_rows) + 1 + len(cpu_rows) + 3
menu_h = rows * ROW + 3 * 11 + 12
menu_y = 36
parts.append(f'<g filter="url(#shadow)"><rect x="{MENU_X}" y="{menu_y}" width="{MENU_W}" height="{menu_h}" rx="11" '
             f'fill="#2B2B30" fill-opacity="0.96" stroke="#FFFFFF" stroke-opacity="0.12"/></g>')

y = menu_y + 6
left, right = MENU_X + 14, MENU_X + MENU_W - 14


def separator():
    global y
    parts.append(f'<line x1="{left}" y1="{y + 5.5}" x2="{right}" y2="{y + 5.5}" stroke="#FFFFFF" stroke-opacity="0.12"/>')
    y += 11


def header(label):
    global y
    parts.append(text(left, y + 15, label, 11, "#8E8E93", 600))
    y += ROW


def process_row(name, value, color, highlighted=False):
    global y
    if highlighted:
        parts.append(f'<rect x="{MENU_X + 5}" y="{y}" width="{MENU_W - 10}" height="{ROW}" rx="5" fill="#0A84FF"/>')
    parts.append(app_icon(left, y + 3, color))
    parts.append(text(left + 24, y + 15.5, name))
    parts.append(text(right, y + 15.5, value, 13, "#FFFFFF" if highlighted else "#98989D", 400, "end"))
    y += ROW


parts.append(text(left + 24, y + 15.5, "RAM 12.9 GB / 16 GB   ·   Disk 461 GB / 500 GB"))
parts.append(f'<rect x="{left + 2}" y="{y + 9}" width="3" height="8" fill="#F2F2F7"/>'
             f'<rect x="{left + 7}" y="{y + 5}" width="3" height="12" fill="#F2F2F7"/>'
             f'<rect x="{left + 12}" y="{y + 11}" width="3" height="6" fill="#F2F2F7"/>')
y += ROW
separator()
header("Top memory — click to force quit")
for i, row in enumerate(memory_rows):
    process_row(*row, highlighted=(i == 0))
separator()
header("Top CPU")
for row in cpu_rows:
    process_row(*row)
separator()
parts.append(text(left, y + 15.5, "✓", 13, "#F2F2F7", 600))
parts.append(text(left + 24, y + 15.5, "Open at Login"))
y += ROW
parts.append(text(left + 24, y + 15.5, "Language"))
parts.append(text(right, y + 15.5, "›", 15, "#98989D", 400, "end"))
y += ROW
parts.append(text(left + 24, y + 15.5, "Quit"))
parts.append(text(right, y + 15.5, "⌘Q", 13, "#98989D", 400, "end"))

# Callouts.
parts.append(text(40, 120, "Real time", 26, "#FFFFFF", 700))
parts.append(text(40, 148, "CPU, RAM and disk in", 15, "#D1D1F0"))
parts.append(text(40, 168, "your Mac menu bar.", 15, "#D1D1F0"))
for i, (color, label) in enumerate([("#F2F2F7", "normal"), ("#FFD60A", "≥ 75%"), ("#FF453A", "≥ 90%")]):
    parts.append(f'<circle cx="48" cy="{210 + i * 26}" r="6" fill="{color}"/>')
    parts.append(text(62, 215 + i * 26, label, 14, "#E5E5F7"))
parts.append(text(40, 330, "Click an app to", 15, "#D1D1F0"))
parts.append(text(40, 350, "force quit it.", 15, "#D1D1F0"))
parts.append('</svg>')

Path(__file__).resolve().parent.parent.joinpath("docs/preview.svg").write_text("\n".join(parts), encoding="utf-8")
print("docs/preview.svg written")
