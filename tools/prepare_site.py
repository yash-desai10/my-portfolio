#!/usr/bin/env python3
"""Copy the site into a staging directory and set the deployment's metadata URL."""
import html
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import urlparse


def prepare_site(source: Path, destination: Path, website_url: str) -> None:
    parsed = urlparse(website_url)
    if parsed.scheme != 'https' or not parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError('Website URL must be an absolute HTTPS URL without query or fragment.')
    if not (source / 'index.html').is_file():
        raise FileNotFoundError('The website source must contain index.html.')
    if source.resolve() == destination.resolve() or source.resolve() in destination.resolve().parents:
        raise ValueError('Staging directory must be outside the website source.')
    destination.mkdir(parents=True, exist_ok=True)
    if any(destination.iterdir()):
        raise ValueError('Staging directory must be empty.')
    for item in source.iterdir():
        target = destination / item.name
        if item.is_dir():
            shutil.copytree(item, target)
        else:
            shutil.copy2(item, target)
    url = html.escape(website_url.rstrip('/') + '/', quote=True)
    page = destination / 'index.html'
    content = page.read_text(encoding='utf-8')
    content, count = re.subn(r'<meta\s+property="og:url"\s+content="[^"]*"\s*/?>',
                             '<meta property="og:url" content="' + url + '">', content)
    if count != 1:
        raise ValueError('Expected exactly one og:url metadata element in index.html.')
    content = content.replace('</head>', '  <link rel="canonical" href="' + url + '">\n</head>', 1)
    page.write_text(content, encoding='utf-8')


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('Usage: prepare_site.py SOURCE STAGING_DIRECTORY HTTPS_URL')
    prepare_site(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
