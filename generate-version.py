#!/usr/bin/env python3
"""
Generate Version.lua from CHANGELOG.md
Run this script after updating CHANGELOG.md to regenerate Version.lua
"""

import re
from pathlib import Path


def parse_changelog(content: str) -> list[dict]:
    """Parse CHANGELOG.md into structured version entries."""
    versions = []
    current_version = None
    current_changes = []

    for line in content.strip().split('\n'):
        line = line.strip()
        if not line:
            continue

        # New version header: ## 2.0.2
        version_match = re.match(r'^##\s+(\d+\.\d+\.\d+)$', line)
        if version_match:
            # Save previous version if exists
            if current_version:
                current_version['changes'] = current_changes
                versions.append(current_version)
            # Start new version
            current_version = {'id': version_match.group(1), 'message': '', 'changes': []}
            current_changes = []
            continue

        # Message line (first non-empty, non-list line after version)
        if current_version and not current_version['message'] and not line.startswith('-'):
            current_version['message'] = line
            continue

        # Change entry: - Something changed
        if line.startswith('- ') and current_version:
            current_changes.append(line[2:])

    # Save last version
    if current_version:
        current_version['changes'] = current_changes
        versions.append(current_version)

    return versions


def generate_lua(versions: list[dict]) -> str:
    """Generate Version.lua content from parsed versions."""
    lines = ['local _, Skada = ...', 'Skada.versions = {']

    for i, v in enumerate(versions):
        lines.append('\t{')
        lines.append(f'\t\tid = "{v["id"]}",')
        lines.append(f'\t\ttitle = "Skada {v["id"]}",')
        lines.append(f'\t\tmessage = "{v["message"]}",')
        lines.append('\t\tchanges = {')
        for change in v['changes']:
            # Escape double quotes in changes
            escaped = change.replace('"', '\\"')
            lines.append(f'\t\t\t"{escaped}",')
        lines.append('\t\t}')
        lines.append('\t},')

    lines.append('}')
    return '\n'.join(lines)


def main():
    changelog_path = Path('CHANGELOG.md')
    version_path = Path('Version.lua')

    if not changelog_path.exists():
        print(f"Error: {changelog_path} not found!")
        return 1

    content = changelog_path.read_text(encoding='utf-8')
    versions = parse_changelog(content)

    if not versions:
        print("Error: No versions found in CHANGELOG.md")
        return 1

    lua_content = generate_lua(versions)
    version_path.write_text(lua_content, encoding='utf-8')

    print(f"Generated {version_path} with {len(versions)} version(s)")
    for v in versions:
        print(f"  - {v['id']}: {v['message'][:50]}...")

    return 0


if __name__ == '__main__':
    exit(main())
