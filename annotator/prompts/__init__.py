"""Prompt templates, stored as markdown so they can be edited and diffed
without touching Python.

Placeholders use ``str.format`` syntax — see :func:`load`.
"""
from __future__ import annotations

from importlib import resources


def load(name: str, **kwargs: object) -> str:
    """Return the prompt ``name`` (without extension), formatted with kwargs.

    >>> load("annotate_clip", rally_num=3, duration=12.0)[:20]
    'This clip shows beac'
    """
    text = resources.files(__package__).joinpath(f"{name}.md").read_text(encoding="utf-8")
    return text.format(**kwargs) if kwargs else text
