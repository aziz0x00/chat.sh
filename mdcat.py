import os
import select
import sys
from rich.live import Live
from rich.markdown import Markdown
from rich.theme import Theme
from rich.console import Console
from rich.padding import Padding

THEME = {
    "markdown.h1": "bold #00afff",  # Headers styled bold and cyan
    "markdown.h2": "bold #00afff",
    "markdown.h3": "bold #00afff",
    "markdown.h4": "bold #00afff",
    "markdown.h5": "bold #00afff",
    "markdown.h6": "bold #00afff",
    "markdown.text": "#d0d0d0",  # Regular text in light gray
    "markdown.strong": "bold #d0d0d0",  # Bold text
    "markdown.emphasis": "italic #d0d0d0",  # Italic text
    "markdown.code": "#d0d0d0 on #303030",  # Inline code
    "markdown.code_block": "on #303030",  # Code block background
    "markdown.link": "underline #00afff",  # Links underlined and cyan
    "markdown.block_quote": "#5fff00",  # Block quotes in green
    "markdown.list": "#d0d0d0",  # List text
    "markdown.item": "#d0d0d0",  # List items
    "markdown.item_bullet": "#00afff",  # Bullets in cyan
    "markdown.item_number": "#00afff",  # Numbers in cyan
}
console = Console(theme=Theme(THEME), width=90)

markdown_text = ""
buffer_size = 4096
timeout = 0.05  # Timeout for select in seconds


def render_markdown(text):
    """Render Markdown text"""
    return Padding(
        Markdown(text, code_theme="ansi_dark", hyperlinks=False), (1, 2)
    )  # Padding: 1 line top/bottom, 2 spaces left/right


with Live(console=console, auto_refresh=True) as live:
    while True:
        # Wait for input
        rlist, _, _ = select.select([sys.stdin], [], [], timeout)
        if sys.stdin in rlist:
            chunk = os.read(sys.stdin.fileno(), buffer_size)
            if not chunk:
                break  # EOF reached
            markdown_text += chunk.decode("utf-8", errors="replace")
            live.update(render_markdown(markdown_text))
