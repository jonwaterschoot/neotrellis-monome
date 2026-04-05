"""
minify.py — archive and release a versioned Lua script.

Usage (run from the scripts/ directory):
  python minify.py "short description of changes"
  python minify.py  ← prompts for description

What it does:
  1. Auto-detects the next version number from temparchive/
  2. Copies serpentineSeqr/serpentine_dev.lua → temparchive/serpentine_vX-Y.lua (full archive)
  3. Strips comments/blanks  → serpentine_vX-Y.lua  (minified release at scripts/ root)
  4. Appends an entry to     → temparchive/CHANGELOG.md
"""
import re, io, sys, os, glob, datetime

DEV_FILE    = 'serpentineSeqr/serpentine_dev.lua'
ARCHIVE_DIR = 'serpentineSeqr/temparchive'
CHANGELOG   = os.path.join(ARCHIVE_DIR, 'CHANGELOG.md')


def next_version():
    """Return (major, minor) for the next version, based on what's in temparchive/."""
    pattern = os.path.join(ARCHIVE_DIR, 'serpentine_v*.lua')
    versions = []
    for f in glob.glob(pattern):
        m = re.match(r'serpentine_v(\d+)-(\d+)\.lua$', os.path.basename(f))
        if m:
            versions.append((int(m.group(1)), int(m.group(2))))
    if not versions:
        return (1, 1)
    major, minor = max(versions)
    return (major, minor + 1)


def minify_lines(lines):
    """Strip full-line comments and blank lines; strip inline comments."""
    out = []
    for line in lines:
        stripped = line.rstrip()
        if re.match(r'^\s*--', stripped):
            continue
        if stripped == '':
            continue
        result = ''
        i = 0
        in_str = None
        while i < len(stripped):
            c = stripped[i]
            if in_str:
                result += c
                if c == in_str:
                    in_str = None
            elif c in ('"', "'"):
                in_str = c
                result += c
            elif c == '-' and i + 1 < len(stripped) and stripped[i + 1] == '-':
                break
            else:
                result += c
            i += 1
        result = result.rstrip()
        if result:
            out.append(result + '\n')
    return out


if __name__ == '__main__':
    # Get description
    if len(sys.argv) > 1:
        description = ' '.join(sys.argv[1:])
    else:
        description = input('Change description (or Enter to skip): ').strip() or '(no description)'

    major, minor = next_version()
    version_str  = f'v{major}-{minor}'

    archive_path = os.path.join(ARCHIVE_DIR, f'serpentine_{version_str}.lua')
    release_path = f'serpentine_{version_str}.lua'

    with io.open(DEV_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # 1. Archive full dev copy
    with io.open(archive_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'Archived : {archive_path}')

    # 2. Minified release
    minified = minify_lines(lines)
    with io.open(release_path, 'w', encoding='utf-8') as f:
        f.writelines(minified)
    print(f'Released : {release_path}  ({len(lines)} lines -> {len(minified)} lines)')

    # 3. Changelog entry
    date_str = datetime.date.today().isoformat()
    entry = f'\n## {version_str} — {date_str}\n{description}\n'
    with io.open(CHANGELOG, 'a', encoding='utf-8') as f:
        f.write(entry)
    print(f'Changelog: {CHANGELOG}')

    print(f'\nDone. Remember to add the new entry to manifest.json if you want it listed in the app.')
