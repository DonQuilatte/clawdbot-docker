
## Backlog Items

### Fix punycode deprecation warning

**Priority:** Low

**Description:**
Node.js `DeprecationWarning: The 'punycode' module is deprecated. Please use a userland alternative instead.`

**Context:**
- Warning from a dependency using deprecated built-in `punycode` module
- Common culprits: `whatwg-url`, `tr46`, `uri-js`, email/URL validation libs

**Steps to Fix:**
1. Run with `--trace-deprecation` flag to identify source
2. Update offending dependency or use userland `punycode` package

**Status:** Open
