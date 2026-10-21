# users/email_templates.py
"""
FoGo email templates (v2)
==========================

Built to survive real email clients (Gmail web/app, Outlook desktop/web, Apple Mail,
Yahoo, Samsung Mail, Thunderbird) instead of looking right only in a browser.

Rules this file follows (and why the v1 templates broke)
--------------------------------------------------------
* Layout is nested <table role="presentation"> only. Padding lives on <td>, never on
  <table>/<div> (Outlook ignores it). Spacing between blocks uses spacer rows, not margins.
* Every style that matters is INLINE. The <style> blocks only add progressive
  enhancement (mobile layout, dark mode, motion). v1 used `class="btn-primary"` that was
  never defined, so every button rendered as a bare link.
* Anything a client may not support has a solid fallback:
    - gradients / background images  -> bgcolor attribute + background-color
    - rounded corners                -> square corners in Outlook (still fully usable)
    - buttons                        -> "bulletproof" buttons (VML for Outlook desktop)
    - CSS animation                  -> static layout that already looks finished
* Patterns that work everywhere: a gingham ("tablecloth") strip built from table cells,
  plus a subtle dot grid on hero blocks (progressive; plain tint where unsupported).
* Motion is CSS-only, wrapped in `prefers-reduced-motion: no-preference`, and used
  sparingly (one entrance, plus meaningful live-state motion such as the delivery
  progress bar and the scooter). Gmail and Outlook ignore CSS animation; Apple Mail,
  iOS Mail, Samsung Mail, Thunderbird and many others play it.
* All dynamic values are HTML-escaped (v1 interpolated names/addresses/URLs raw).
* Dark mode: `color-scheme` + `prefers-color-scheme` overrides (Apple Mail, Outlook.com/
  Outlook apps). Gmail applies its own automatic inversion.
* Output is kept compact because Gmail clips messages above ~102 KB.

Convention for the private helpers: they accept HTML-safe strings. Escape every dynamic
value with `cls._t(...)` before passing it in (`_code_box` is the one exception: it
escapes its own `code`).

Optional settings
-----------------
COMPANY_NAME, CUSTOMER_APP_URL, EMAIL_REPLY_TO, DEFAULT_FROM_EMAIL   (already used)
EMAIL_LOGO_URL            absolute https URL of a square logo (PNG, ~132x132). Falls back to a
                          built-in "F" mark.
RESTAURANT_HUB_NAME       name of the restaurant workspace (default "Fudz Hub").
EMAIL_UNSUBSCRIBE_URL     default unsubscribe link for promotional emails.
"""

from __future__ import annotations

import re
from datetime import datetime
from html import escape
from typing import Any, Dict, List, Optional
from urllib.parse import quote, urljoin, urlparse

from django.conf import settings

__all__ = ["EmailTemplates", "get_email_template"]

FONT = "'Segoe UI',Roboto,'Helvetica Neue',Helvetica,Arial,sans-serif"
MONO = "'SFMono-Regular',Menlo,Consolas,'Courier New',monospace"


class EmailTemplates:
    """Transactional and promotional email templates for FoGo food delivery."""

    # ------------------------------------------------------------------
    # Design tokens
    # ------------------------------------------------------------------
    ORANGE = "#FF6B00"
    ORANGE_DEEP = "#C2410C"   # orange for text on light backgrounds (AA contrast)
    PEACH = "#FFD2AD"
    CREAM = "#FFF7F0"
    SOFT = "#FFF1E5"
    INK = "#24170D"
    BODY = "#4A3F37"
    MUTED = "#6F635B"
    LINE = "#F0E1D4"
    FOOTER = "#2B1D14"

    TONES: Dict[str, Dict[str, str]] = {
        "orange": {"bg": "#FFF1E5", "dot": "rgba(255,107,0,0.16)", "accent": "#C2410C", "soft": "#FFF1E5", "border": "#FFD2AD"},
        "green": {"bg": "#ECFDF3", "dot": "rgba(21,128,61,0.13)", "accent": "#15803D", "soft": "#DCFCE7", "border": "#86EFAC"},
        "amber": {"bg": "#FFF8E6", "dot": "rgba(180,83,9,0.13)", "accent": "#92400E", "soft": "#FEF3C7", "border": "#FCD34D"},
        "violet": {"bg": "#F5F0FF", "dot": "rgba(109,40,217,0.11)", "accent": "#6D28D9", "soft": "#EDE9FE", "border": "#C4B5FD"},
        "blue": {"bg": "#EFF6FF", "dot": "rgba(29,78,216,0.11)", "accent": "#1D4ED8", "soft": "#DBEAFE", "border": "#93C5FD"},
        "red": {"bg": "#FEF2F2", "dot": "rgba(185,28,28,0.11)", "accent": "#B91C1C", "soft": "#FEE2E2", "border": "#FCA5A5"},
    }

    # Text styles: name -> (css class used for dark mode, colour)
    TEXT = {
        "ink": ("txt", "#24170D"),
        "body": ("txt-body", "#4A3F37"),
        "muted": ("txt-muted", "#6F635B"),
        "accent": ("txt-accent", "#C2410C"),
        "white": ("", "#FFFFFF"),
    }

    # ------------------------------------------------------------------
    # Style blocks. Three separate <style> tags on purpose: if a client chokes
    # on one (e.g. Gmail on unsupported at-rules) the others still apply.
    # ------------------------------------------------------------------
    BASE_STYLES = """
    html,body{margin:0!important;padding:0!important;width:100%!important;height:100%!important}
    *{-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important}
    table{border-collapse:collapse;border-spacing:0}
    img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;display:block}
    a{text-decoration:none}
    a[x-apple-data-detectors],.unstyle-auto-detected-links a,.aBn{border-bottom:0!important;cursor:default!important;color:inherit!important;text-decoration:none!important;font-size:inherit!important;font-family:inherit!important;font-weight:inherit!important;line-height:inherit!important}
    u+#body a{color:inherit;text-decoration:none;font-size:inherit;font-family:inherit;font-weight:inherit;line-height:inherit}
    #MessageViewBody a{color:inherit;text-decoration:none;font-size:inherit;font-family:inherit;font-weight:inherit;line-height:inherit}
    @media only screen and (max-width:620px){
      .gutter{padding:12px 8px!important}
      .px{padding-left:20px!important;padding-right:20px!important}
      .hero-title{font-size:25px!important;line-height:31px!important}
      .stack{display:block!important;width:100%!important}
      .code-text{font-size:28px!important;letter-spacing:5px!important}
      .big-num{font-size:40px!important;line-height:44px!important}
      .btn{display:block!important}
      .hide-m{display:none!important}
    }
    """

    MOTION_STYLES = """
    @keyframes fg-pop{0%{transform:scale(.55);opacity:0}70%{transform:scale(1.08);opacity:1}100%{transform:scale(1);opacity:1}}
    @keyframes fg-pulse{0%{box-shadow:0 0 0 0 currentColor}70%{box-shadow:0 0 0 14px transparent}100%{box-shadow:0 0 0 0 transparent}}
    @keyframes fg-grow{0%{transform:scaleX(0)}100%{transform:scaleX(1)}}
    @keyframes fg-drive{0%{transform:translateX(-14px)}50%{transform:translateX(14px)}100%{transform:translateX(-14px)}}
    @keyframes fg-shine{0%{background-position:160% 0}100%{background-position:-60% 0}}
    @keyframes fg-blink{0%,100%{opacity:1}50%{opacity:.4}}
    @media (prefers-reduced-motion:no-preference){
      .m-pop{animation:fg-pop .7s cubic-bezier(.2,1.3,.4,1) both}
      .m-pulse{animation:fg-pulse 2.2s ease-out infinite}
      .m-grow{transform-origin:left center;animation:fg-grow .9s .4s ease-out both}
      .m-late{animation-delay:1.3s}
      .m-drive{animation:fg-drive 3.4s ease-in-out infinite}
      .m-blink{animation:fg-blink 1.6s ease-in-out infinite}
      .m-shine{background-image:linear-gradient(110deg,rgba(255,255,255,0) 35%,rgba(255,255,255,.5) 50%,rgba(255,255,255,0) 65%)!important;background-size:250% 100%;animation:fg-shine 3.6s 1s ease-in-out infinite}
      .m-s1{animation-delay:.2s}.m-s2{animation-delay:.3s}.m-s3{animation-delay:.4s}.m-s4{animation-delay:.5s}.m-s5{animation-delay:.6s}
    }
    """

    DARK_STYLES = """
    @media (prefers-color-scheme:dark){
      .bg-page{background-color:#17110D!important}
      .bg-card{background-color:#221913!important}
      .bg-soft{background-color:#2D2119!important}
      .bg-hero{background-color:#2A1D14!important}
      .txt{color:#FFF3E8!important}
      .txt-body{color:#E3D6CC!important}
      .txt-muted{color:#B9AA9E!important}
      .txt-accent{color:#FFA057!important}
      .bdr{border-color:#3D2D21!important}
    }
    [data-ogsb] .bg-page{background-color:#17110D!important}
    [data-ogsb] .bg-card{background-color:#221913!important}
    [data-ogsb] .bg-soft{background-color:#2D2119!important}
    [data-ogsb] .bg-hero{background-color:#2A1D14!important}
    [data-ogsc] .txt{color:#FFF3E8!important}
    [data-ogsc] .txt-body{color:#E3D6CC!important}
    [data-ogsc] .txt-muted{color:#B9AA9E!important}
    [data-ogsc] .txt-accent{color:#FFA057!important}
    """

    # ------------------------------------------------------------------
    # Small utilities
    # ------------------------------------------------------------------
    @staticmethod
    def _t(value: Any) -> str:
        """HTML-escape any dynamic value."""
        return escape("" if value is None else str(value), quote=True)

    @staticmethod
    def _oneline(value: Any) -> str:
        """Strip line breaks so a value can never inject extra email headers via the subject."""
        return re.sub(r"[\r\n]+", " ", str(value or "")).strip()

    @classmethod
    def _name(cls, user_name: Any) -> str:
        return cls._t(str(user_name or "").strip() or "there")

    @staticmethod
    def _get_year() -> int:
        return datetime.now().year

    @staticmethod
    def _get_company_name() -> str:
        return getattr(settings, "COMPANY_NAME", "FoGo")

    @classmethod
    def _get_customer_app_url(cls, *parts: str) -> str:
        base_url = str(getattr(settings, "CUSTOMER_APP_URL", "https://fudgo.com") or "https://fudgo.com").rstrip("/")
        suffix = "/".join(quote(str(part).strip("/"), safe="") for part in parts if str(part).strip("/"))
        return f"{base_url}/{suffix}" if suffix else base_url

    @classmethod
    def _get_support_url(cls) -> str:
        reply_to = getattr(settings, "EMAIL_REPLY_TO", None) or getattr(settings, "DEFAULT_FROM_EMAIL", None)
        return f"mailto:{reply_to}" if reply_to else cls._get_customer_app_url()

    @classmethod
    def _safe_url(cls, value: Any, fallback: Optional[str] = None) -> str:
        """Return an attribute-safe URL. Only http(s), mailto and site-relative paths are allowed."""
        raw = str(value or "").strip()
        parsed = urlparse(raw)
        if parsed.scheme in {"http", "https"} and parsed.netloc:
            return escape(raw, quote=True)
        if parsed.scheme == "mailto" and parsed.path:
            return escape(raw, quote=True)
        if raw.startswith("/") and not raw.startswith("//"):
            return escape(urljoin(cls._get_customer_app_url() + "/", raw), quote=True)
        return escape(str(cls._get_customer_app_url() if fallback is None else fallback), quote=True)

    @classmethod
    def _plain_footer(cls) -> str:
        return f"© {cls._get_year()} {cls._get_company_name()}"

    # ------------------------------------------------------------------
    # Primitives
    # ------------------------------------------------------------------
    @staticmethod
    def _gap(h: int = 16) -> str:
        """A spacer table row (margins are unreliable in email, spacer rows are not)."""
        return f'<tr><td height="{h}" style="height:{h}px;font-size:0;line-height:0;mso-line-height-rule:exactly;">&nbsp;</td></tr>'

    @classmethod
    def _p(cls, text: str, kind: Any = "body", size: int = 15, weight: int = 400, align: str = "left",
           mb: int = 0, extra: str = "", lh: Optional[int] = None) -> str:
        """Paragraph. `kind` is a TEXT key or a (css_class, colour) tuple. `text` must be HTML-safe."""
        css_class, color = kind if isinstance(kind, tuple) else cls.TEXT.get(kind, ("", kind))
        lh = lh or int(round(size * 1.55))
        cls_attr = f' class="{css_class}"' if css_class else ""
        return (f'<p{cls_attr} style="margin:0 0 {mb}px;padding:0;font-family:{FONT};font-size:{size}px;'
                f'line-height:{lh}px;font-weight:{weight};color:{color};text-align:{align};{extra}">{text}</p>')

    @classmethod
    def _stack(cls, blocks: List[str], gap: int = 16, align: str = "left") -> str:
        """Vertical stack of blocks separated by spacer rows."""
        rows: List[str] = []
        for block in blocks:
            if not block:
                continue
            if rows:
                rows.append(cls._gap(gap))
            rows.append(f'<tr><td align="{align}">{block}</td></tr>')
        return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{"".join(rows)}</table>'

    @classmethod
    def _body(cls, inner: str, pad: str = "32px 32px 34px") -> str:
        return f'<tr><td class="px" style="padding:{pad};">{inner}</td></tr>'

    @classmethod
    def _gingham(cls, cells: int = 25, h: int = 5, a: Optional[str] = None, b: Optional[str] = None) -> str:
        """
        Gingham 'tablecloth' strip built from table cells, so it renders in every client
        (no background images needed). Two rows offset by one cell make a checkerboard.
        """
        a = a or cls.ORANGE
        b = b or cls.PEACH
        w = 100 // cells

        def row(offset: int) -> str:
            tds = "".join(
                f'<td width="{w}%" height="{h}" bgcolor="{a if (i + offset) % 2 == 0 else b}" '
                f'style="width:{w}%;height:{h}px;font-size:0;line-height:0;mso-line-height-rule:exactly;">&nbsp;</td>'
                for i in range(cells)
            )
            return f"<tr>{tds}</tr>"

        return ('<tr><td style="font-size:0;line-height:0;">'
                '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="table-layout:fixed;">'
                f'{row(0)}{row(1)}</table></td></tr>')

    @classmethod
    def _dashed_separator(cls) -> str:
        """Receipt-style dashed rule (works in every client; border on <td>)."""
        return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
                f'{cls._gap(10)}<tr><td class="bdr" style="border-top:1px dashed #E7D0BC;font-size:0;line-height:0;">&nbsp;</td></tr>{cls._gap(10)}</table>')

    @classmethod
    def _button(cls, label: str, url: Any, kind: str = "primary") -> str:
        """Bulletproof button: VML roundrect for Outlook desktop, styled <a> everywhere else."""
        href = cls._safe_url(url)
        width = max(210, min(380, len(re.sub(r"<[^>]+>", "", label)) * 10 + 76))
        if kind == "secondary":
            bg, fg, border = "#FFFFFF", cls.INK, "#D9BFA8"
            vml_line, shadow, shine = 'strokecolor="#D9BFA8" strokeweight="2px"', "", ""
        else:
            bg, fg, border = cls.ORANGE, cls.INK, cls.ORANGE
            vml_line, shadow, shine = 'stroke="f"', "box-shadow:0 6px 16px rgba(255,107,0,0.30);", " m-shine"
        return f"""<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr><td align="center">
<!--[if mso]>
<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="{href}" style="height:50px;v-text-anchor:middle;width:{width}px;" arcsize="24%" {vml_line} fillcolor="{bg}"><w:anchorlock/><center style="font-family:Arial,sans-serif;font-size:16px;font-weight:bold;color:{fg};">{label}</center></v:roundrect>
<![endif]-->
<!--[if !mso]><!-->
<a class="btn{shine}" href="{href}" target="_blank" rel="noopener" style="display:inline-block;padding:14px 34px;background-color:{bg};border:2px solid {border};border-radius:12px;color:{fg};font-family:{FONT};font-size:16px;line-height:20px;font-weight:800;text-decoration:none;text-align:center;{shadow}">{label}</a>
<!--<![endif]-->
</td></tr></table>"""

    @classmethod
    def _chip(cls, html_text: str, tone: str = "amber", icon: str = "⏱️") -> str:
        t = cls.TONES[tone]
        return (f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>'
                f'<td align="center" bgcolor="{t["soft"]}" style="padding:8px 16px;background-color:{t["soft"]};border:1px solid {t["border"]};'
                f'border-radius:999px;font-family:{FONT};font-size:13px;line-height:18px;font-weight:600;color:{t["accent"]};">{icon}&nbsp; {html_text}</td></tr></table>')

    @classmethod
    def _notice(cls, title: str, message: str, tone: str = "amber", icon: str = "⚠️") -> str:
        """Callout with a coloured left edge. Title and message must be HTML-safe."""
        t = cls.TONES[tone]
        return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                f'<td width="4" bgcolor="{t["accent"]}" style="width:4px;background-color:{t["accent"]};font-size:0;line-height:0;">&nbsp;</td>'
                f'<td bgcolor="{t["soft"]}" style="padding:14px 16px;background-color:{t["soft"]};">'
                f'<p style="margin:0 0 4px;font-family:{FONT};font-size:14px;line-height:20px;font-weight:700;color:{t["accent"]};">{icon}&nbsp; {title}</p>'
                f'<p style="margin:0;font-family:{FONT};font-size:13px;line-height:20px;color:#4A3F37;">{message}</p>'
                f'</td></tr></table>')

    @classmethod
    def _icon_badge(cls, icon: str, size: int = 44) -> str:
        return (f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                f'<td class="bg-soft bdr" align="center" valign="middle" width="{size}" height="{size}" bgcolor="{cls.SOFT}" '
                f'style="width:{size}px;height:{size}px;background-color:{cls.SOFT};border:1px solid {cls.PEACH};border-radius:12px;'
                f'font-size:{int(size * 0.5)}px;line-height:1;text-align:center;">{icon}</td></tr></table>')

    @classmethod
    def _feature_list(cls, items: List[tuple]) -> str:
        """Rows of (icon, title, description). Strings must be HTML-safe."""
        rows: List[str] = []
        for icon, title, text in items:
            if rows:
                rows.append(cls._gap(10))
            rows.append(
                f'<tr><td class="bg-soft bdr" bgcolor="#FFF9F4" style="padding:14px 16px;background-color:#FFF9F4;border:1px solid {cls.LINE};border-radius:12px;">'
                f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                f'<td width="58" valign="top" style="width:58px;">{cls._icon_badge(icon)}</td>'
                f'<td valign="middle">{cls._p(title, "ink", 15, 700, mb=2)}{cls._p(text, "muted", 13)}</td>'
                f'</tr></table></td></tr>'
            )
        return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;">{"".join(rows)}</table>'

    @classmethod
    def _info_row(cls, label: str, value: str) -> str:
        return (f'<tr><td class="bdr" style="padding:12px 0;border-bottom:1px solid {cls.LINE};">'
                f'{cls._p(label, "muted", 14)}</td>'
                f'<td class="bdr" align="right" style="padding:12px 0;border-bottom:1px solid {cls.LINE};">'
                f'{cls._p(value, "ink", 14, 700, align="right")}</td></tr>')

    @classmethod
    def _code_box(cls, code: Any, label: str = "Your code") -> str:
        """High-contrast verification code card. Escapes `code` itself."""
        return (f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>'
                f'<td class="bg-soft" align="center" bgcolor="#FFF7ED" style="padding:20px 34px 22px;background-color:#FFF7ED;border:2px dashed #FF9A4D;border-radius:14px;">'
                f'{cls._p(cls._t(label), "muted", 13, 600, "center", 8)}'
                f'<p class="code-text txt" style="margin:0;padding:0 0 0 8px;font-family:{MONO};font-size:34px;line-height:40px;font-weight:800;'
                f'letter-spacing:8px;color:{cls.INK};text-align:center;">{cls._t(code)}</p></td></tr></table>')

    # ------------------------------------------------------------------
    # Page sections
    # ------------------------------------------------------------------
    @classmethod
    def _header(cls, tag: str = "") -> str:
        """Brand bar: logo mark, wordmark and an optional context tag (e.g. 'Order #123')."""
        company = cls._t(cls._get_company_name())
        logo_url = getattr(settings, "EMAIL_LOGO_URL", "")
        if logo_url:
            mark = (f'<img src="{cls._safe_url(logo_url, "")}" width="44" height="44" alt="{company}" '
                    f'style="display:block;width:44px;height:44px;border-radius:12px;">')
        else:
            initial = cls._t((cls._get_company_name() or "F")[:1].upper())
            mark = (f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                    f'<td align="center" valign="middle" width="44" height="44" bgcolor="{cls.ORANGE}" '
                    f'style="width:44px;height:44px;background-color:{cls.ORANGE};border-radius:12px;font-family:{FONT};font-size:24px;line-height:1;font-weight:900;color:{cls.INK};text-align:center;">{initial}</td></tr></table>')
        tag_html = ""
        if tag:
            tag_html = (f'<td class="hide-m" align="right" valign="middle"><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>'
                        f'<td class="bg-soft bdr" bgcolor="{cls.SOFT}" style="padding:6px 12px;background-color:{cls.SOFT};border:1px solid {cls.PEACH};border-radius:999px;'
                        f'font-family:{FONT};font-size:12px;line-height:16px;font-weight:700;color:{cls.ORANGE_DEEP};">{tag}</td></tr></table></td>')
        return (f'<tr><td class="px bg-card" bgcolor="#FFFFFF" style="padding:20px 32px 18px;background-color:#FFFFFF;">'
                f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                f'<td width="44" valign="middle" style="width:44px;">{mark}</td>'
                f'<td valign="middle" style="padding-left:12px;">'
                f'<p class="txt" style="margin:0;font-family:{FONT};font-size:19px;line-height:22px;font-weight:800;color:{cls.INK};">{company}</p>'
                f'<p class="txt-muted" style="margin:2px 0 0;font-family:{FONT};font-size:12px;line-height:16px;color:{cls.MUTED};">Food, made effortless</p></td>'
                f'{tag_html}</tr></table></td></tr>')

    @classmethod
    def _hero(cls, icon: str, title: str, subtitle: str = "", tone: str = "orange", live: bool = False) -> str:
        """
        Tinted hero with a dot-grid pattern and an icon badge.
        `live=True` adds a pulsing ring (used for in-progress states such as 'on the way').
        """
        t = cls.TONES.get(tone, cls.TONES["orange"])
        pulse = " m-pulse" if live else ""
        badge = (f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" class="m-pop" style="margin:0 auto;"><tr><td align="center">'
                 f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" class="{pulse.strip()}" style="border-collapse:separate;border-radius:50%;color:{t["accent"]};"><tr>'
                 f'<td class="bg-card" align="center" valign="middle" width="76" height="76" bgcolor="#FFFFFF" '
                 f'style="width:76px;height:76px;background-color:#FFFFFF;border:2px solid {t["accent"]};border-radius:50%;font-size:34px;line-height:1;text-align:center;">{icon}</td>'
                 f'</tr></table></td></tr></table>')
        heading = (f'<h1 class="hero-title txt" style="margin:0;padding:0;font-family:{FONT};font-size:28px;line-height:34px;'
                   f'font-weight:800;letter-spacing:-0.3px;color:{cls.INK};text-align:center;">{title}</h1>')
        sub = cls._p(subtitle, "body", 15, align="center", lh=23) if subtitle else ""
        rows = f'<tr><td align="center">{badge}</td></tr>{cls._gap(18)}<tr><td align="center">{heading}</td></tr>'
        if sub:
            rows += f'{cls._gap(10)}<tr><td align="center">{sub}</td></tr>'
        return (f'<tr><td class="px bg-hero" align="center" bgcolor="{t["bg"]}" '
                f'style="padding:34px 32px 32px;background-color:{t["bg"]};'
                f'background-image:radial-gradient(circle,{t["dot"]} 1.4px,transparent 1.8px);background-size:16px 16px;">'
                f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{rows}</table></td></tr>')

    @classmethod
    def _footer(cls, message: str = "", note: str = "", unsubscribe_url: Optional[str] = None) -> str:
        """Dark footer with a gingham edge. `message`/`note` must be HTML-safe."""
        company = cls._t(cls._get_company_name())
        app_url = cls._safe_url(cls._get_customer_app_url())
        support_url = cls._safe_url(cls._get_support_url())
        link = "color:#FFD2AD;text-decoration:underline;"
        links = [f'<a href="{app_url}" style="{link}">Open {company}</a>', f'<a href="{support_url}" style="{link}">Help &amp; support</a>']
        if unsubscribe_url:
            links.append(f'<a href="{cls._safe_url(unsubscribe_url)}" style="{link}">Unsubscribe</a>')
        msg = cls._p(message, "#F4E8DF", 14, 600, "center", 10) if message else ""
        note_html = cls._p(note, "#CFC4BD", 12, align="center", mb=8) if note else ""
        return (f'<tr><td><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{cls.FOOTER}" '
                f'style="background-color:{cls.FOOTER};border-radius:16px;border-collapse:separate;overflow:hidden;">'
                f'{cls._gingham(h=4, a=cls.ORANGE, b="#5A3A24")}'
                f'<tr><td class="px" align="center" style="padding:24px 28px 26px;">{msg}'
                f'{cls._p(company, "white", 17, 800, "center", 6)}'
                f'{note_html}'
                f'{cls._p(" &nbsp;·&nbsp; ".join(links), "#E7DED8", 12, align="center", mb=10)}'
                f'{cls._p(f"© {cls._get_year()} {company}. All rights reserved.", "#CFC4BD", 11, align="center")}'
                f'</td></tr></table></td></tr>')

    @classmethod
    def _base_template(cls, content: str, preheader: str = "") -> str:
        """Document shell: head (meta, Outlook settings, styles), preheader and centred 600px column."""
        company = cls._t(cls._get_company_name())
        pre = cls._t(preheader)
        filler = "&#847;&zwnj;&nbsp;" * 60  # stops mail clients pulling body text into the inbox preview
        return f"""<!doctype html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="x-apple-disable-message-reformatting">
<meta name="format-detection" content="telephone=no,address=no,email=no,date=no,url=no">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>{company}</title>
<!--[if mso]>
<noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
<style>table,td,div,p,a,h1{{font-family:Arial,Helvetica,sans-serif !important;}}</style>
<![endif]-->
<style type="text/css">{cls.BASE_STYLES}</style>
<style type="text/css">{cls.MOTION_STYLES}</style>
<style type="text/css">{cls.DARK_STYLES}</style>
</head>
<body id="body" class="bg-page" bgcolor="{cls.CREAM}" style="margin:0;padding:0;width:100%;background-color:{cls.CREAM};word-spacing:normal;">
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">{pre}{filler}</div>
<div role="article" aria-roledescription="email" aria-label="{company}" lang="en">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg-page" bgcolor="{cls.CREAM}" style="width:100%;background-color:{cls.CREAM};">
<tr><td class="gutter" align="center" style="padding:24px 12px;">
<!--[if mso]><table role="presentation" width="600" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" class="container" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;">
{content}
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr>
</table>
</div>
</body>
</html>"""

    @classmethod
    def _layout(cls, preheader: str, hero: str, body: str, footer_message: str = "", tag: str = "",
                footer_note: str = "", unsubscribe_url: Optional[str] = None) -> str:
        """Standard email: [gingham strip, brand bar, hero, body] card + footer."""
        card = (f'<tr><td><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg-card bdr" bgcolor="#FFFFFF" '
                f'style="background-color:#FFFFFF;border:1px solid {cls.LINE};border-radius:16px;border-collapse:separate;overflow:hidden;">'
                f'{cls._gingham()}{cls._header(tag)}{hero}{body}</table></td></tr>')
        return cls._base_template(card + cls._gap(14) + cls._footer(footer_message, footer_note, unsubscribe_url), preheader)

    # ============================================================
    # VERIFICATION
    # ============================================================
    @classmethod
    def email_verification(cls, user_name: str, verification_code: str, expires_minutes: int = 30) -> Dict[str, str]:
        name, company, minutes = cls._name(user_name), cls._t(cls._get_company_name()), int(expires_minutes)
        hero = cls._hero("🔐", f"Hey {name}, verify your email",
                         "Enter this code in the app to confirm your email address and start ordering.")
        body = cls._body(cls._stack([
            cls._code_box(verification_code, "Verification code"),
            cls._chip(f"Expires in <strong>{minutes} minutes</strong>"),
            cls._p("Didn't create an account? You can safely ignore this email.", "muted", 13, align="center"),
        ], gap=20, align="center"))
        html = cls._layout(f"Your verification code is {verification_code}", hero, body, tag="Email verification")
        plain = (f"Hey {user_name},\n\nWelcome to {cls._get_company_name()}! Your verification code is: {verification_code}\n\n"
                 f"This code expires in {minutes} minutes.\n\nDidn't create an account? You can safely ignore this email.\n\n{cls._plain_footer()}")
        return {"subject": f"🔐 Verify your email – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    @classmethod
    def resend_verification(cls, user_name: str, verification_code: str, expires_minutes: int = 30) -> Dict[str, str]:
        name, minutes = cls._name(user_name), int(expires_minutes)
        hero = cls._hero("🔄", "Here's your new code", f"No worries, <strong>{name}</strong>. Use this latest code to finish verifying.")
        body = cls._body(cls._stack([
            cls._code_box(verification_code, "New verification code"),
            cls._chip(f"Valid for <strong>{minutes} minutes</strong>"),
            cls._p("If you asked for more than one code, always use the most recent one.", "muted", 13, align="center"),
        ], gap=20, align="center"))
        html = cls._layout(f"Your new verification code is {verification_code}", hero, body, tag="Email verification")
        plain = (f"Hi {user_name},\n\nYour new verification code: {verification_code}\n\nValid for {minutes} minutes. "
                 f"If you asked for more than one code, use the most recent one.\n\n{cls._plain_footer()}")
        return {"subject": f"🔄 New verification code – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    @classmethod
    def password_reset(cls, user_name: str, reset_code: str, expires_minutes: int = 15) -> Dict[str, str]:
        name, company, minutes = cls._name(user_name), cls._t(cls._get_company_name()), int(expires_minutes)
        hero = cls._hero("🔒", "Reset your password", f"Hi <strong>{name}</strong>, we received a request to reset your password.", tone="amber")
        body = cls._body(cls._stack([
            cls._code_box(reset_code, "Password reset code"),
            cls._chip(f"Expires in <strong>{minutes} minutes</strong>"),
            cls._notice("Didn't request this?",
                        f"Ignore this email and your password stays the same. Never share this code: {company} will never ask you for it."),
        ], gap=20, align="center"))
        html = cls._layout(f"Your password reset code is {reset_code}", hero, body, tag="Security")
        plain = (f"Hi {user_name},\n\nYour password reset code: {reset_code}\n\nThis code expires in {minutes} minutes.\n"
                 f"If you didn't request this, ignore this email. Never share this code with anyone.\n\n{cls._plain_footer()}")
        return {"subject": f"🔒 Password reset code – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    @classmethod
    def password_reset_success(cls, user_name: str) -> Dict[str, str]:
        name = cls._name(user_name)
        app = cls._get_customer_app_url()
        hero = cls._hero("✅", "Password updated", f"<strong>{name}</strong>, your password was changed successfully.", tone="green")
        body = cls._body(cls._stack([
            cls._notice("You're all set", "You can now log in with your new password.", tone="green", icon="🎉"),
            cls._p("A few ways to keep your account safe", "ink", 16, 700),
            cls._feature_list([
                ("📱", "Turn on two-factor authentication", "Adds a second check when you sign in."),
                ("🔑", "Use a unique password", "Don't reuse it on other sites."),
                ("👀", "Review recent activity", "Look for anything you don't recognise."),
            ]),
            cls._button("Open the app", app),
            cls._p(f'Wasn\'t you? <a href="{cls._safe_url(cls._get_support_url())}" style="color:{cls.ORANGE_DEEP};font-weight:700;">Contact support</a> right away.',
                   "muted", 13, align="center"),
        ], gap=20))
        html = cls._layout("Your password has been successfully updated", hero, body, tag="Security")
        plain = (f"Hi {user_name},\n\nYour {cls._get_company_name()} password has been changed. You can now log in with your new password.\n\n"
                 f"Stay safe:\n- Turn on two-factor authentication\n- Use a unique password\n- Review recent activity\n\n"
                 f"Wasn't you? Contact support right away.\n\n{cls._plain_footer()}")
        return {"subject": f"✅ Password updated – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    @classmethod
    def welcome_verified(cls, user_name: str, username: str) -> Dict[str, str]:
        name, company = cls._name(user_name), cls._t(cls._get_company_name())
        initial = cls._t((str(user_name or "")[:1] or "F").upper())
        hero = cls._hero("🎉", f"Welcome to {company}, {name}", "Your email is verified. Let's get you fed.", tone="orange")
        user_card = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                     f'<td class="bg-soft bdr" bgcolor="{cls.SOFT}" style="padding:16px 18px;background-color:{cls.SOFT};border:1px solid {cls.PEACH};border-radius:14px;">'
                     f'<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>'
                     f'<td width="52" valign="middle" style="width:52px;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                     f'<td align="center" valign="middle" width="44" height="44" bgcolor="{cls.ORANGE}" style="width:44px;height:44px;background-color:{cls.ORANGE};border-radius:50%;'
                     f'font-family:{FONT};font-size:20px;line-height:1;font-weight:800;color:{cls.INK};text-align:center;">{initial}</td></tr></table></td>'
                     f'<td valign="middle" style="padding-left:12px;">{cls._p("@" + cls._t(username), "ink", 16, 700)}{cls._p("✓ Verified account", "muted", 13)}</td>'
                     f'</tr></table></td></tr></table>')
        body = cls._body(cls._stack([
            user_card,
            cls._feature_list([
                ("🍕", "Thousands of restaurants", "From local gems to your favourites."),
                ("⚡", "Fast delivery", "Hot food at your door, quickly."),
                ("🎁", "Exclusive deals", "Members-only discounts."),
                ("📍", "Real-time tracking", "Watch your food come to you."),
            ]),
            cls._button("Start ordering", cls._get_customer_app_url()),
        ], gap=22))
        html = cls._layout(f"Welcome to {cls._get_company_name()}, {user_name}! Your email is verified.", hero, body, "Made with care for food lovers.", tag="Welcome")
        plain = (f"Welcome to {cls._get_company_name()}, {user_name}!\n\nYour email is verified. Username: @{username}\n\n"
                 f"- Browse thousands of restaurants\n- Fast delivery\n- Exclusive deals\n- Real-time order tracking\n\n"
                 f"Start ordering: {cls._get_customer_app_url()}\n\n{cls._plain_footer()}")
        return {"subject": f"🎉 Welcome to {cls._oneline(cls._get_company_name())}, {cls._oneline(user_name)}!", "html": html, "plain": plain}

    # ============================================================
    # ORDERS
    # ============================================================
    @classmethod
    def order_confirmation(cls, user_name: str, order_id: str, items: list, subtotal: str, delivery_fee: str, total: str,
                           delivery_address: str, estimated_time: str = "30-45 mins", restaurant_name: str = "") -> Dict[str, str]:
        oid, eta = cls._t(order_id), cls._t(estimated_time)
        item_rows, items_text = [], ""
        for item in items or []:
            name, qty, price = cls._t(item.get("name", "")), cls._t(item.get("quantity", 1)), cls._t(item.get("price", ""))
            original = cls._t(item.get("original_price", ""))
            img_url = cls._safe_url(item.get("image_url"), "") if item.get("image_url") else ""
            image = (f'<img src="{img_url}" width="56" height="56" alt="{name}" style="display:block;width:56px;height:56px;border-radius:10px;">'
                     if img_url else cls._icon_badge("🍽️", 56))
            old = (f'{cls._p(original, "muted", 12, align="right", extra="text-decoration:line-through;")}' if original and original != price else "")
            item_rows.append(
                f'<tr><td class="bdr" style="padding:12px 0;border-bottom:1px solid {cls.LINE};"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                f'<td width="68" valign="top" style="width:68px;">{image}</td>'
                f'<td valign="top" style="padding:0 12px 0 0;">{cls._p(name, "ink", 15, 700, mb=2)}{cls._p(f"Qty {qty}", "muted", 13)}</td>'
                f'<td valign="top" align="right" style="white-space:nowrap;">{cls._p(price, "ink", 15, 700, align="right")}{old}</td>'
                f'</tr></table></td></tr>')
            items_text += f"  {item.get('name', '')} x {item.get('quantity', 1)} - {item.get('price', '')}\n"

        eta_card = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                    f'<td class="bg-soft bdr" align="center" bgcolor="{cls.SOFT}" style="padding:18px;background-color:{cls.SOFT};border:1px solid {cls.PEACH};border-radius:14px;">'
                    f'{cls._p("Estimated delivery", "muted", 13, 600, "center", 4)}{cls._p(f"🕐 {eta}", "ink", 28, 800, "center", lh=34, extra="letter-spacing:-0.3px;")}</td></tr></table>')
        items_block = (f'{cls._p("Your order", "ink", 17, 700, mb=4)}'
                       f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{"".join(item_rows)}</table>')
        totals = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
                  f'<tr><td style="padding:4px 0;">{cls._p("Subtotal", "muted", 14)}</td><td align="right" style="padding:4px 0;">{cls._p(cls._t(subtotal), "body", 14, align="right")}</td></tr>'
                  f'<tr><td style="padding:4px 0;">{cls._p("Delivery fee", "muted", 14)}</td><td align="right" style="padding:4px 0;">{cls._p(cls._t(delivery_fee), "body", 14, align="right")}</td></tr>'
                  f'<tr><td colspan="2">{cls._dashed_separator()}</td></tr>'
                  f'<tr><td style="padding:2px 0;">{cls._p("Total", "ink", 19, 800)}</td><td align="right" style="padding:2px 0;">{cls._p(cls._t(total), "accent", 22, 800, "right")}</td></tr></table>')
        address = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                   f'<td class="bg-soft bdr" bgcolor="#FFF9F4" style="padding:16px 18px;background-color:#FFF9F4;border:1px solid {cls.LINE};border-radius:12px;">'
                   f'{cls._p("📍 Delivering to", "ink", 14, 700, mb=4)}{cls._p(cls._t(delivery_address), "muted", 14)}</td></tr></table>')
        sub = f"Order <strong>#{oid}</strong>" + (f" from <strong>{cls._t(restaurant_name)}</strong>" if restaurant_name else "")
        hero = cls._hero("✅", "Order confirmed", sub, tone="green")
        body = cls._body(cls._stack([eta_card, items_block, totals, address,
                                     cls._button("Track your order", cls._get_customer_app_url())], gap=22))
        html = cls._layout(f"Order #{order_id} confirmed. Arriving in {estimated_time}", hero, body,
                           f"Thank you for ordering, {cls._t(user_name)}!", tag=f"Order #{oid}")
        plain = (f"Order confirmed\n\nOrder #{order_id}\n{('Restaurant: ' + restaurant_name) if restaurant_name else ''}\n"
                 f"Estimated delivery: {estimated_time}\n\nORDER DETAILS:\n{items_text}\nSubtotal: {subtotal}\nDelivery: {delivery_fee}\nTOTAL: {total}\n\n"
                 f"DELIVERY ADDRESS:\n{delivery_address}\n\nThank you, {user_name}!\n{cls._plain_footer()}")
        return {"subject": f"✅ Order confirmed #{cls._oneline(order_id)} – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    # --- order status -------------------------------------------------
    STATUS_ALIASES = {
        "placed": "confirmed", "accepted": "confirmed", "ready": "preparing",
        "picked_up": "on_the_way", "out_for_delivery": "on_the_way",
        "completed": "delivered", "canceled": "cancelled",
    }
    STATUSES = {
        "confirmed": {"icon": "✅", "tone": "green", "step": 1, "title": "Order confirmed"},
        "preparing": {"icon": "👨‍🍳", "tone": "amber", "step": 2, "title": "Your food is being prepared"},
        "on_the_way": {"icon": "🛵", "tone": "violet", "step": 3, "title": "Your order is on the way"},
        "delivered": {"icon": "🎉", "tone": "green", "step": 5, "title": "Delivered"},
        "cancelled": {"icon": "✖️", "tone": "red", "step": 0, "title": "Order cancelled"},
    }

    @classmethod
    def _seg(cls, color: Optional[str], animate: bool = False, late: bool = False) -> str:
        """
        One half of a tracker connector. It lives in its own nested table so the 4px bar stays 4px
        and vertically centred even though the neighbouring dot cell is 36px tall (a bare bgcolor
        <td> would stretch to the full row height).
        """
        if color is None:
            return '<td width="40%" style="font-size:0;line-height:0;">&nbsp;</td>'
        track = "#EADBCF"
        if animate:
            inner = (f'<div class="m-grow{" m-late" if late else ""}" style="height:4px;background-color:{color};font-size:0;line-height:0;">&nbsp;</div>')
            bar_bg = track
        else:
            inner, bar_bg = "&nbsp;", color
        return (f'<td width="40%" valign="middle" style="font-size:0;line-height:0;">'
                f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                f'<td height="4" bgcolor="{bar_bg}" style="height:4px;background-color:{bar_bg};font-size:0;line-height:0;">{inner}</td></tr></table></td>')

    @classmethod
    def _tracker(cls, step: int, accent: str, live: bool) -> str:
        """Four-step progress tracker. Table-based, readable with no CSS, animated where supported."""
        labels = ["Confirmed", "Preparing", "On the way", "Delivered"]
        done, track = "#15803D", "#EADBCF"
        cols = []
        for i, label in enumerate(labels, start=1):
            if i < step:
                dot_bg, dot_fg, dot = done, "#FFFFFF", "✓"
            elif i == step:
                dot_bg, dot_fg, dot = accent, "#FFFFFF", str(i)
            else:
                dot_bg, dot_fg, dot = "#EFE4DA", cls.MUTED, str(i)
            if i == 1:
                left = cls._seg(None)
            elif i < step:
                left = cls._seg(done)
            elif i == step:
                left = cls._seg(done, animate=True, late=True)
            else:
                left = cls._seg(track)
            if i == len(labels):
                right = cls._seg(None)
            elif i + 1 < step:
                right = cls._seg(done)
            elif i + 1 == step:
                right = cls._seg(done, animate=True)
            else:
                right = cls._seg(track)
            ring = "m-pulse" if (live and i == step) else ""
            dot_html = (f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" class="{ring}" style="border-collapse:separate;border-radius:50%;color:{accent};"><tr>'
                        f'<td align="center" valign="middle" width="36" height="36" bgcolor="{dot_bg}" style="width:36px;height:36px;background-color:{dot_bg};border-radius:50%;'
                        f'font-family:{FONT};font-size:15px;line-height:1;font-weight:800;color:{dot_fg};text-align:center;">{dot}</td></tr></table>')
            lbl_color = "#15803D" if i < step else (accent if i == step else cls.MUTED)
            cols.append(f'<td width="25%" align="center" valign="top"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
                        f'<tr>{left}<td width="36" align="center" valign="middle" style="width:36px;">{dot_html}</td>{right}</tr></table>'
                        f'{cls._p(label, lbl_color, 12, 700 if i == step else 600, "center", extra="padding-top:8px;")}</td>')
        return f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>{"".join(cols)}</tr></table>'

    @classmethod
    def order_status_update(cls, user_name: str, order_id: str, status: str, status_message: str,
                            estimated_time: Optional[str] = None) -> Dict[str, str]:
        key = str(status or "").lower().strip()
        key = cls.STATUS_ALIASES.get(key, key)
        known = key in cls.STATUSES
        s = cls.STATUSES.get(key, cls.STATUSES["confirmed"])
        title = s["title"] if known else cls._t(key.replace("_", " ").title())
        oid = cls._t(order_id)
        live = key in {"preparing", "on_the_way"}
        hero = cls._hero(s["icon"], title, f"Order <strong>#{oid}</strong>", tone=s["tone"], live=live)
        blocks = [cls._p(cls._t(status_message), "body", 15, align="center", lh=24)]
        if s["step"] > 0:
            accent = cls.TONES[s["tone"]]["accent"]
            blocks.append(cls._tracker(s["step"], accent, live))
        if estimated_time and key != "delivered":
            blocks.append(cls._chip(f"Estimated arrival: <strong>{cls._t(estimated_time)}</strong>", "green"))
        blocks.append(cls._button("Open the app", cls._get_customer_app_url()))
        html = cls._layout(f"Order #{order_id}: {re.sub('<[^>]+>', '', title)}", hero, cls._body(cls._stack(blocks, gap=26, align="center")), tag=f"Order #{oid}")
        eta_text = f"\nETA: {estimated_time}" if estimated_time else ""
        plain = (f"{re.sub('<[^>]+>', '', title)} - Order #{order_id}\n\n{status_message}{eta_text}\n\n"
                 f"Track your order in the {cls._get_company_name()} app.\n\n{cls._plain_footer()}")
        return {"subject": f"{s['icon']} {re.sub('<[^>]+>', '', title)} – Order #{cls._oneline(order_id)}", "html": html, "plain": plain}

    @classmethod
    def order_delivered(cls, user_name: str, order_id: str, restaurant_name: str, items: list = None) -> Dict[str, str]:
        oid, app = cls._t(order_id), cls._get_customer_app_url()
        app_href = cls._safe_url(app)
        shots = []
        for item in (items or [])[:4]:
            img_url = cls._safe_url(item.get("image_url"), "") if item.get("image_url") else ""
            shot = (f'<img src="{img_url}" width="72" height="72" alt="{cls._t(item.get("name", ""))}" style="display:block;width:72px;height:72px;border-radius:12px;">'
                    if img_url else cls._icon_badge("🍽️", 72))
            shots.append(f'<td style="padding:0 5px;">{shot}</td>')
        gallery = (f'{cls._p("What you ordered", "muted", 13, 600, "center", 10)}<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>{"".join(shots)}</tr></table>'
                   if shots else "")
        restaurant = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                      f'<td class="bg-soft bdr" align="center" bgcolor="#FFF9F4" style="padding:16px;background-color:#FFF9F4;border:1px solid {cls.LINE};border-radius:12px;">'
                      f'{cls._p("Delivered from", "muted", 13, align="center", mb=2)}{cls._p("🏪 " + cls._t(restaurant_name), "ink", 18, 700, "center")}</td></tr></table>')
        stars = "".join(
            f'<td style="padding:0 3px;"><a href="{app_href}" style="color:#F59E0B;text-decoration:none;font-family:Arial,sans-serif;font-size:36px;line-height:40px;">'
            f'<span class="m-pop m-s{i}" style="display:inline-block;">★</span></a></td>' for i in range(1, 6))
        rating = (f'{cls._p("How was your food?", "ink", 18, 700, "center", 8)}'
                  f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>{stars}</tr></table>')
        hero = cls._hero("🍽️", "Enjoy your meal", f"Order <strong>#{oid}</strong> has been delivered.", tone="green")
        body = cls._body(cls._stack([restaurant, gallery, rating,
                                     cls._button("Rate your order", app),
                                     f'<p style="margin:0;text-align:center;font-family:{FONT};font-size:14px;"><a href="{app_href}" style="color:{cls.ORANGE_DEEP};font-weight:700;">Order again</a></p>'],
                                    gap=24, align="center"))
        html = cls._layout(f"Your order from {restaurant_name} has been delivered!", hero, body,
                           f"Thanks for choosing {cls._t(cls._get_company_name())}, {cls._t(user_name)}!", tag=f"Order #{oid}")
        items_text = ("\nYour order:\n" + "\n".join(f"  - {i.get('name', '')}" for i in (items or [])[:4])) if items else ""
        plain = (f"Enjoy your meal!\n\nOrder #{order_id} has been delivered from {restaurant_name}.\n{items_text}\n\n"
                 f"How was your food? Rate your order in the app: {app}\n\nThanks for choosing {cls._get_company_name()}, {user_name}!\n{cls._plain_footer()}")
        return {"subject": f"🍽️ Delivered! Rate your order – #{cls._oneline(order_id)}", "html": html, "plain": plain}

    # ============================================================
    # PROMOTIONS
    # ============================================================
    @classmethod
    def promotion_discount(cls, user_name: str, discount_amount: str, description: str, expiry_date: str,
                           hero_image_url: str = None, hero_title: str = "HUNGRY?",
                           hero_subtitle: str = "Let us deliver the best food",
                           food_items: list = None, restaurants: list = None, min_order: str = None,
                           cta_text: str = "Order Now", cta_link: str = None, contact_phone: str = None,
                           contact_address: str = None, contact_hours: str = None,
                           unsubscribe_url: str = None) -> Dict[str, str]:
        t = cls._t
        user, discount, desc, expiry = t(user_name or "there"), t(discount_amount), t(description), t(expiry_date)
        title = t(hero_title or "A delicious deal is waiting")
        subtitle = t(hero_subtitle or "A little something for your next meal")
        action_url = cls._get_customer_app_url() if not cta_link else cta_link
        unsub = unsubscribe_url or getattr(settings, "EMAIL_UNSUBSCRIBE_URL", None)

        image_row = ""
        if hero_image_url:
            src = cls._safe_url(hero_image_url, "")
            if src:
                image_row = (f'<tr><td style="font-size:0;line-height:0;"><img src="{src}" width="600" alt="Featured food from {t(cls._get_company_name())}" '
                             f'style="display:block;width:100%;max-width:600px;height:auto;"></td></tr>')
        hero = image_row + cls._hero("🍔", title, f"Hi <strong>{user}</strong>. {subtitle}")

        offer = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                 f'<td class="bg-soft" align="center" bgcolor="{cls.SOFT}" style="padding:26px 18px;background-color:{cls.SOFT};border:2px dashed {cls.ORANGE};border-radius:16px;">'
                 f'<p class="big-num txt" style="margin:0;font-family:{FONT};font-size:48px;line-height:52px;font-weight:900;letter-spacing:-1px;color:{cls.INK};text-align:center;">{discount} off</p>'
                 f'{cls._p(desc, "body", 15, align="center", extra="padding-top:8px;", lh=24)}</td></tr></table>')
        terms = []
        if expiry:
            terms.append(f"<strong>Offer ends {expiry}</strong>")
        if min_order:
            terms.append(f"Minimum order {t(min_order)}")
        terms_html = cls._p(" &nbsp;·&nbsp; ".join(terms), "muted", 13, align="center") if terms else ""

        food_html = ""
        cards = []
        for item in (food_items or [])[:4]:
            name, price, orig = t(item.get("name")), t(item.get("price")), t(item.get("original_price"))
            img_url = cls._safe_url(item.get("image_url"), "") if item.get("image_url") else ""
            image = (f'<img src="{img_url}" width="72" height="72" alt="{name}" style="display:block;width:72px;height:72px;border-radius:10px;">'
                     if img_url else cls._icon_badge("🍲", 72))
            old = f'<span style="text-decoration:line-through;color:{cls.MUTED};font-weight:400;">{orig}</span>&nbsp; ' if orig and orig != price else ""
            cards.append(
                f'<td class="stack" width="50%" valign="top" style="width:50%;padding:6px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" '
                f'class="bg-card bdr" bgcolor="#FFFFFF" style="background-color:#FFFFFF;border:1px solid {cls.LINE};border-radius:12px;border-collapse:separate;"><tr>'
                f'<td width="84" valign="top" style="width:84px;padding:12px 0 12px 12px;">{image}</td>'
                f'<td valign="middle" style="padding:12px;">{cls._p(name, "ink", 14, 700, mb=4, lh=19)}{cls._p(old + price, "accent", 14, 800)}</td></tr></table></td>')
        if cards:
            rows = ""
            for i in range(0, len(cards), 2):
                pair = cards[i:i + 2]
                if len(pair) == 1:
                    pair.append('<td class="stack" width="50%" style="width:50%;padding:6px;">&nbsp;</td>')
                rows += f'<tr>{"".join(pair)}</tr>'
            food_html = (f'{cls._p("A few favourites", "ink", 18, 700, mb=6)}'
                         f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-left:-6px;">{rows}</table>')

        rest_rows = []
        for r in (restaurants or [])[:4]:
            name, cuisines = t(r.get("name")), t(r.get("cuisines"))
            link = cls._safe_url(r.get("link"))
            img_url = cls._safe_url(r.get("image_url"), "") if r.get("image_url") else ""
            image = (f'<img src="{img_url}" width="64" height="64" alt="{name}" style="display:block;width:64px;height:64px;border-radius:10px;">'
                     if img_url else cls._icon_badge("🍽️", 64))
            rest_rows.append(
                f'<tr><td style="padding:5px 0;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg-card bdr" bgcolor="#FFFFFF" '
                f'style="background-color:#FFFFFF;border:1px solid {cls.LINE};border-radius:12px;border-collapse:separate;"><tr>'
                f'<td width="78" style="width:78px;padding:10px;">{image}</td>'
                f'<td valign="middle" style="padding:10px 8px 10px 0;">{cls._p(name, "ink", 14, 700, mb=2, lh=19)}{cls._p(cuisines, "muted", 12)}</td>'
                f'<td align="right" valign="middle" style="padding:10px 14px;white-space:nowrap;"><a href="{link}" style="color:{cls.ORANGE_DEEP};font-family:{FONT};font-size:13px;font-weight:700;">Explore &rsaquo;</a></td>'
                f'</tr></table></td></tr>')
        rest_html = (f'{cls._p("Explore restaurants", "ink", 18, 700, mb=6)}<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">{"".join(rest_rows)}</table>'
                     if rest_rows else "")

        contact = [cls._p(f"{icon} {t(val)}", "muted", 12, mb=3) for icon, val in (("📍", contact_address), ("🕒", contact_hours), ("☎", contact_phone)) if val]
        contact_html = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td class="bdr" style="padding-top:16px;border-top:1px solid {cls.LINE};">'
                        f'{"".join(contact)}</td></tr></table>') if contact else ""

        body = cls._body(cls._stack([offer, cls._button(t(cta_text or "Order now"), action_url), terms_html, food_html, rest_html, contact_html], gap=22, align="center"))
        html = cls._layout(f"{discount_amount} off your next order. {description}", hero, body, "A good meal is always a good idea.", tag="Offer",
                           footer_note="You are receiving this because you have an account with us." if unsub else "", unsubscribe_url=unsub)

        items_text = ("\n\nFEATURED ITEMS:\n" + "\n".join(f"  - {i.get('name', '')}: {i.get('price', '')}" for i in food_items[:4])) if food_items else ""
        rest_text = ("\n\nRESTAURANTS:\n" + "\n".join(f"  - {r.get('name', '')} ({r.get('cuisines', '')})" for r in restaurants[:4])) if restaurants else ""
        terms_text = (f"\nOffer ends: {expiry_date}" if expiry_date else "") + (f"\nMinimum order: {min_order}" if min_order else "")
        contact_text = "\n".join(str(v) for v in (contact_address, contact_hours, contact_phone) if v)
        contact_text = f"\n\nRestaurant details:\n{contact_text}" if contact_text else ""
        unsub_text = f"\n\nUnsubscribe: {unsub}" if unsub else ""
        plain = (f"Hi {user_name},\n\n{hero_title}\n{hero_subtitle}\n\n{discount_amount} OFF\n{description}{terms_text}{items_text}{rest_text}{contact_text}\n\n"
                 f"{cta_text or 'Order now'}: {action_url}{unsub_text}\n\n{cls._plain_footer()}")
        return {"subject": f"🍽️ {cls._oneline(discount_amount)} off your next order", "html": html, "plain": plain}

    @classmethod
    def welcome_promo(cls, user_name: str, promo_code: str, discount_amount: str,
                      terms: str = "Valid on your first order only.", unsubscribe_url: str = None) -> Dict[str, str]:
        discount = cls._t(discount_amount)
        unsub = unsubscribe_url or getattr(settings, "EMAIL_UNSUBSCRIBE_URL", None)
        hero = cls._hero("🎁", "A gift for you", f"Welcome to the {cls._t(cls._get_company_name())} family.")
        ticket = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                  f'<td class="bg-soft" align="center" bgcolor="{cls.SOFT}" style="padding:26px 18px;background-color:{cls.SOFT};border:2px dashed {cls.ORANGE};border-radius:16px;">'
                  f'<p class="big-num txt" style="margin:0;font-family:{FONT};font-size:52px;line-height:56px;font-weight:900;letter-spacing:-1px;color:{cls.INK};text-align:center;">{discount}</p>'
                  f'{cls._p("off your first order", "body", 15, align="center", mb=16)}'
                  f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>'
                  f'<td class="bg-card" align="center" bgcolor="#FFFFFF" style="padding:10px 24px;background-color:#FFFFFF;border:1px solid {cls.PEACH};border-radius:10px;">'
                  f'<p class="code-text txt" style="margin:0;padding:0 0 0 4px;font-family:{MONO};font-size:26px;line-height:32px;font-weight:800;letter-spacing:4px;color:{cls.INK};text-align:center;">{cls._t(promo_code)}</p></td></tr></table>'
                  f'{cls._p(cls._t(terms), "muted", 13, align="center", extra="padding-top:12px;")}</td></tr></table>')
        steps = cls._feature_list([
            ("🛒", "Add your favourites", "Pick a restaurant and fill your basket."),
            ("🏷️", "Enter the code at checkout", "The discount is applied automatically."),
            ("😋", "Enjoy", "Sit back while we bring it to you."),
        ])
        body = cls._body(cls._stack([ticket, cls._p("How to use it", "ink", 17, 700), steps,
                                     cls._button("Claim your gift", cls._get_customer_app_url())], gap=22))
        html = cls._layout(f"Get {discount_amount} off your first order with code {promo_code}", hero, body,
                           f"Welcome aboard, {cls._t(user_name)}!", tag="Welcome gift", unsubscribe_url=unsub)
        plain = (f"A gift for you, {user_name}!\n\nGet {discount_amount} off your first order.\n\nPROMO CODE: {promo_code}\n{terms}\n\n"
                 f"Start ordering: {cls._get_customer_app_url()}\n\n{cls._plain_footer()}")
        return {"subject": f"🎁 Your welcome gift: {cls._oneline(discount_amount)} off", "html": html, "plain": plain}

    # ============================================================
    # DELIVERY
    # ============================================================
    @classmethod
    def delivery_driver_assigned(cls, user_name: str, order_id: str, driver_name: str, estimated_time: str) -> Dict[str, str]:
        oid, driver, eta = cls._t(order_id), cls._t(driver_name), cls._t(estimated_time)
        initial = cls._t((str(driver_name or "")[:1] or "D").upper())
        route = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                 f'<td width="64" align="center" valign="bottom" style="width:64px;"><p style="margin:0;font-size:28px;line-height:32px;">🍳</p>{cls._p("Restaurant", "muted", 11, 600, "center")}</td>'
                 f'<td valign="middle" style="padding:0 6px 14px;"><div class="m-drive" style="text-align:center;font-size:28px;line-height:32px;">🛵</div>'
                 f'<div style="border-top:2px dashed #FFB27A;font-size:0;line-height:0;height:0;">&nbsp;</div></td>'
                 f'<td width="64" align="center" valign="bottom" style="width:64px;"><p style="margin:0;font-size:28px;line-height:32px;">🏠</p>{cls._p("You", "muted", 11, 600, "center")}</td>'
                 f'</tr></table>')
        driver_card = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                       f'<td class="bg-soft bdr" bgcolor="{cls.SOFT}" style="padding:16px 18px;background-color:{cls.SOFT};border:1px solid {cls.PEACH};border-radius:14px;">'
                       f'<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td width="56" valign="middle" style="width:56px;">'
                       f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;"><tr>'
                       f'<td align="center" valign="middle" width="46" height="46" bgcolor="{cls.ORANGE}" style="width:46px;height:46px;background-color:{cls.ORANGE};border-radius:50%;'
                       f'font-family:{FONT};font-size:20px;line-height:1;font-weight:800;color:{cls.INK};text-align:center;">{initial}</td></tr></table></td>'
                       f'<td valign="middle">{cls._p(driver, "ink", 17, 700)}{cls._p("Your delivery partner", "muted", 13)}</td></tr></table></td></tr></table>')
        info = (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
                f'{cls._info_row("📦 Order", "#" + oid)}{cls._info_row("⏱️ Arriving in", eta)}</table>')
        hero = cls._hero("🛵", "Your driver is on the way", f"Order <strong>#{oid}</strong>", tone="violet", live=True)
        body = cls._body(cls._stack([route, driver_card, info, cls._button("Track delivery", cls._get_customer_app_url())], gap=22, align="center"))
        html = cls._layout(f"{driver_name} is delivering your order. Arriving in {estimated_time}", hero, body, tag=f"Order #{oid}")
        plain = (f"Your driver is on the way!\n\nOrder #{order_id}\n\n{driver_name} has picked up your order.\nArriving in: {estimated_time}\n\n"
                 f"Track it in the {cls._get_company_name()} app.\n\n{cls._plain_footer()}")
        return {"subject": f"🛵 {cls._oneline(driver_name)} is delivering your order", "html": html, "plain": plain}

    @classmethod
    def delivery_arriving_soon(cls, user_name: str, order_id: str, minutes_away: int = 5) -> Dict[str, str]:
        mins, oid = int(minutes_away), cls._t(order_id)
        ring = (f'<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" class="m-pulse" style="margin:0 auto;border-collapse:separate;border-radius:50%;color:{cls.ORANGE};"><tr>'
                f'<td class="bg-soft" align="center" valign="middle" width="150" height="150" bgcolor="{cls.SOFT}" '
                f'style="width:150px;height:150px;background-color:{cls.SOFT};border:6px solid {cls.ORANGE};border-radius:50%;">'
                f'<p class="big-num txt" style="margin:0;font-family:{FONT};font-size:56px;line-height:58px;font-weight:900;color:{cls.INK};text-align:center;">{mins}</p>'
                f'{cls._p("minutes", "muted", 14, 700, "center")}</td></tr></table>')
        hero = cls._hero("🏃", "Almost there", "Your order is just around the corner.", tone="orange")
        body = cls._body(cls._stack([
            ring,
            cls._p("Please be ready to receive your order.", "body", 16, 600, "center"),
            cls._notice("Keep your phone nearby", "Your driver may call if they can't find you.", tone="blue", icon="📱"),
            cls._p(f"Order #{oid}", "muted", 13, align="center"),
        ], gap=22, align="center"))
        html = cls._layout(f"Your order arrives in {mins} minutes!", hero, body, tag=f"Order #{oid}")
        plain = f"Almost there!\n\nYour order will arrive in {mins} minutes.\n\nOrder #{order_id}\n\nPlease be ready to receive it.\n\n{cls._plain_footer()}"
        return {"subject": f"🏃 {mins} min away – get ready!", "html": html, "plain": plain}

    # ============================================================
    # ACCOUNT
    # ============================================================
    @classmethod
    def account_deactivated(cls, user_name: str, reactivation_days: int = 30) -> Dict[str, str]:
        name, company, days = cls._name(user_name), cls._t(cls._get_company_name()), int(reactivation_days)
        hero = cls._hero("👋", f"We'll miss you, {name}", f"Your {company} account has been deactivated, as you requested.")
        body = cls._body(cls._stack([
            cls._notice("Changed your mind?",
                        f"Log in within {days} days to reactivate your account. All your data will be restored.", tone="blue", icon="💡"),
            cls._p("If there is anything we could have done better, we'd love to hear from you.", "body", 15, align="center", lh=24),
            cls._button("Log in to reactivate", cls._get_customer_app_url()),
            cls._button("Share feedback", cls._get_support_url(), kind="secondary"),
        ], gap=22, align="center"))
        html = cls._layout(f"Your {cls._get_company_name()} account has been deactivated", hero, body,
                           f"Thank you for being part of {company}.", tag="Account")
        plain = (f"We'll miss you, {user_name}.\n\nYour {cls._get_company_name()} account has been deactivated.\n\n"
                 f"Changed your mind? Log in within {days} days to reactivate it: {cls._get_customer_app_url()}\n\n{cls._plain_footer()}")
        return {"subject": f"👋 Account deactivated – {cls._oneline(cls._get_company_name())}", "html": html, "plain": plain}

    @classmethod
    def restaurant_invitation(cls, user_name: str, restaurant_name: str, activation_url: str,
                              role: str = "restaurant owner", expires_minutes: int = 30) -> Dict[str, str]:
        name, rest, role_h, minutes = cls._name(user_name), cls._t(restaurant_name), cls._t(role), int(expires_minutes)
        hub = cls._t(getattr(settings, "RESTAURANT_HUB_NAME", "Fudz Hub"))
        href = cls._safe_url(activation_url)
        hero = cls._hero("🍽️", "Your restaurant workspace is ready", f"<strong>{rest}</strong> invited you to join its {hub} workspace.")
        body = cls._body(cls._stack([
            cls._p(f"Hi <strong>{name}</strong>, you have been invited to join <strong>{rest}</strong> as <strong>{role_h}</strong>. "
                   "Choose a password on the secure activation page to get started.", "body", 15, align="center", lh=24),
            cls._button("Activate your account", activation_url),
            cls._chip(f"Link expires in <strong>{minutes} minutes</strong>"),
            cls._p(f'Button not working? Copy and paste this link into your browser:<br><a href="{href}" style="color:{cls.ORANGE_DEEP};word-break:break-all;">{href}</a>',
                   "muted", 12, align="center"),
            cls._p("If you were not expecting this invitation, you can safely ignore it.", "muted", 12, align="center"),
        ], gap=22, align="center"))
        html = cls._layout(f"Activate your {cls._get_company_name()} restaurant workspace", hero, body,
                           "Welcome to your restaurant workspace.", tag="Invitation")
        plain = (f"Hi {user_name},\n\nYou have been invited to join {restaurant_name} as {role}. Activate your account and choose a password here:\n"
                 f"{activation_url}\n\nThis invitation link expires after {minutes} minutes.\n\n"
                 f"If you were not expecting this invitation, you can safely ignore it.\n\n{cls._plain_footer()}")
        return {"subject": f"🍽️ Activate your {cls._oneline(getattr(settings, 'RESTAURANT_HUB_NAME', 'Fudz Hub'))} restaurant workspace", "html": html, "plain": plain}


# ============================================================
# CONVENIENCE FUNCTION (unchanged public API)
# ============================================================
def get_email_template(template_type: str, **kwargs) -> Dict[str, Any]:
    """Get email template by type"""
    templates = {
        # Auth
        "email_verification": EmailTemplates.email_verification,
        "resend_verification": EmailTemplates.resend_verification,
        "password_reset": EmailTemplates.password_reset,
        "password_reset_success": EmailTemplates.password_reset_success,
        "welcome_verified": EmailTemplates.welcome_verified,
        "restaurant_invitation": EmailTemplates.restaurant_invitation,
        # Orders
        "order_confirmation": EmailTemplates.order_confirmation,
        "order_status_update": EmailTemplates.order_status_update,
        "order_delivered": EmailTemplates.order_delivered,
        # Promos
        "promotion_discount": EmailTemplates.promotion_discount,
        "welcome_promo": EmailTemplates.welcome_promo,
        # Delivery
        "delivery_driver_assigned": EmailTemplates.delivery_driver_assigned,
        "delivery_arriving_soon": EmailTemplates.delivery_arriving_soon,
        # Account
        "account_deactivated": EmailTemplates.account_deactivated,
    }
    template_func = templates.get(template_type)
    if not template_func:
        raise ValueError(f"Unknown template type: {template_type}")
    return template_func(**kwargs)
