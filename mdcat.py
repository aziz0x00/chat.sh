import os
import select
import sys
from rich.live import Live
from rich.markdown import Markdown, TextElement, MarkdownContext
from rich.text import Text
from rich.theme import Theme
from rich.console import Console, ConsoleOptions, RenderResult
from rich.padding import Padding
from markdown_it.token import Token


# inspired from the cool https://github.com/charmbracelet/glow
class Heading(TextElement):
    """A heading."""

    @classmethod
    def create(cls, markdown: Markdown, token: Token):
        return cls(token.tag)

    def on_enter(self, context: MarkdownContext) -> None:
        self.text = Text()
        context.enter_style(self.style_name)

    def __init__(self, tag: str) -> None:
        self.tag = tag
        self.style_name = f"markdown.{tag}"
        super().__init__()

    def __rich_console__(
        self, console: Console, options: ConsoleOptions
    ) -> RenderResult:
        text = self.text
        if self.tag == "h1":
            text.style = ""
            text.end = ""
            yield Text(" ", style="markdown.h1", end="")
            yield text
            yield Text(" ", style="markdown.h1")
        else:
            yield Text("#" * (int(self.tag[1:])) + " ", end="", style=self.style_name)
            yield text


Markdown.elements["heading_open"] = Heading

THEME = {
    "markdown.h1": "#f7faf7 bold on #2aa198",
    "markdown.h2": "bold #01aefd",
    "markdown.h3": "bold #01aefd",
    "markdown.h4": "bold #01aefd",
    "markdown.h5": "bold #01aefd",
    "markdown.h6": "bold #01aefd",
    "markdown.text": "#d0d0d0",
    "markdown.text": " #d0d0d0",
    "markdown.strong": "bold #d0d0d0",
    "markdown.emphasis": "italic #d0d0d0",
    "markdown.code": "#ff936f on #303030",
    "markdown.code_block": "on #303030",
    "markdown.link": "underline #00afff",
    "markdown.block_quote": "#5fff00",
    "markdown.list": "#d0d0d0",
    "markdown.item": "#d0d0d0",
    "markdown.item_bullet": "#00afff",
    "markdown.item_number": "#00afff",
    "none": "#d0d0d0",
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
