# go-style banword list

Leakage / credentials
- `(password|passwd|secret|token|api_key)\s*[:=]\s*["'][^"']+["']`
- FQDNs under private-use TLDs (`.internal`, `.corp`, `.intranet`, `.lan`) in string literals; import paths are exempt
- organisation-specific domains and e-mail suffixes: declared per repo in `.go-style-banwords` (one ERE per line, `#` comments), never hardcoded in the skill

AI markers outside commit footer
- `🤖`, `Generated with Claude`, `Co-Authored-By: Claude` in code comments or source strings
- Acceptable only in git commit message footer when applicable

Overclaiming in commit messages
- `perfect`, `flawless`, `guaranteed`, `zero bugs`, `100% correct`
- superlatives without evidence

Sloppy markers in production paths
- `TODO` without `(#issue)` reference
- `XXX`, `FIXME` in production code (acceptable in test or experimental paths)
- "just" in comments ("just a quick fix", "just refactoring")
- "probably", "should work", "seems to work"
