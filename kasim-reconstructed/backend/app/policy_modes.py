"""Canonical exam policy modes and their enforcement semantics.

The product deliberately stores mode names instead of relying on a browser or
AI catalogue.  Resource names, executable aliases, and domains are supplied by
the lecturer for each session and are registered on demand.
"""

from dataclasses import dataclass
from typing import Final


SPECIFIC_BROWSER: Final = "SPECIFIC_BROWSER"
SPECIFIC_AI: Final = "SPECIFIC_AI"
SPECIFIC_BROWSER_NO_AI: Final = "SPECIFIC_BROWSER_NO_AI"
ANY_BROWSER_NO_AI: Final = "ANY_BROWSER_NO_AI"
SPECIFIC_BROWSER_AND_AI: Final = "SPECIFIC_BROWSER_AND_AI"

ALL_POLICY_MODES: Final = {
    SPECIFIC_BROWSER,
    SPECIFIC_AI,
    SPECIFIC_BROWSER_NO_AI,
    ANY_BROWSER_NO_AI,
    SPECIFIC_BROWSER_AND_AI,
}


@dataclass(frozen=True)
class PolicySemantics:
    browser_mode: str
    ai_mode: str
    web_access_scope: str
    needs_browser: bool
    needs_ai: bool


MODE_SEMANTICS: Final[dict[str, PolicySemantics]] = {
    # A named browser is the only browser permitted. Web destinations are not
    # otherwise filtered, so this is the deliberately least restrictive mode.
    SPECIFIC_BROWSER: PolicySemantics(
        browser_mode="ALLOW_SELECTED",
        ai_mode="ALLOW_ANY",
        web_access_scope="ANY_SITE",
        needs_browser=True,
        needs_ai=False,
    ),
    # Any browser may be used, but only the lecturer-named AI destination is
    # permitted. Standard web traffic is denied.
    SPECIFIC_AI: PolicySemantics(
        browser_mode="ALLOW_ANY",
        ai_mode="ALLOW_SELECTED",
        web_access_scope="AI_ONLY",
        needs_browser=False,
        needs_ai=True,
    ),
    # A named browser may access normal websites. Every AI destination known to
    # the signed policy is denied.
    SPECIFIC_BROWSER_NO_AI: PolicySemantics(
        browser_mode="ALLOW_SELECTED",
        ai_mode="BLOCK_ALL",
        web_access_scope="ANY_SITE",
        needs_browser=True,
        needs_ai=False,
    ),
    # Any browser may access normal websites while AI destinations are denied.
    ANY_BROWSER_NO_AI: PolicySemantics(
        browser_mode="ALLOW_ANY",
        ai_mode="BLOCK_ALL",
        web_access_scope="ANY_SITE",
        needs_browser=False,
        needs_ai=False,
    ),
    # A named browser may access normal websites and exactly one named AI.
    SPECIFIC_BROWSER_AND_AI: PolicySemantics(
        browser_mode="ALLOW_SELECTED",
        ai_mode="ALLOW_SELECTED",
        web_access_scope="ANY_SITE",
        needs_browser=True,
        needs_ai=True,
    ),
}


def semantics_for(mode: str) -> PolicySemantics:
    try:
        return MODE_SEMANTICS[mode]
    except KeyError as exc:
        raise ValueError(f"Unsupported exam policy mode: {mode}") from exc
