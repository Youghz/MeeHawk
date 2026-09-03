---
name: moov-livraison:security-review
description: >
  Perform a security-focused code review aligned with OWASP Top 10:2025 and
  generate a report in docs/reviews/. Use when: (1) Auditing a codebase for
  security vulnerabilities, (2) Reviewing authentication, authorization, input
  validation, secrets management, (3) Preparing for a security audit or
  compliance review. Triggers on: security review, security audit, vulnerability
  review, OWASP review.
---

# Security Review

Review the full codebase for security vulnerabilities unless the user specifies
a narrower scope. This review is aligned with OWASP Top 10:2025.

Focus on **finding real vulnerabilities**, not listing theoretical risks. Every
recommendation must point to specific code, not generic advice.

## What to Review

### 1. Input Validation & Injection

- **SQL injection**: string concatenation in queries? Use parameterized queries.
- **Command injection**: calls to `os.system()`, `subprocess` with `shell=True`,
  `exec()`, `eval()`? Use parameterized APIs.
- **Path traversal**: user input in file paths without sanitization?
- **XSS**: user input rendered in HTML without encoding?
- **Deserialization**: use of `pickle.loads()`, `yaml.load()` (unsafe),
  `json.loads()` on untrusted data without schema validation?
- Server-side validation present (not just client-side)?
- Input length restrictions and type validation?
- File uploads: content-type validation, size limits, stored outside webroot?

### 2. Authentication & Session Management

- Password hashing: bcrypt, scrypt, or argon2? (flag MD5, SHA-1, plain SHA-256)
- Account lockout or rate limiting on login attempts?
- Session tokens: sufficient entropy (≥128 bits), regenerated after login?
- Cookie flags: `Secure`, `HttpOnly`, `SameSite=Strict`?
- Session timeout: absolute (2-8h) and idle (15-30min)?
- Re-authentication required for sensitive operations (password change, payment)?
- JWT: algorithm explicitly set (reject `none`)? Keys ≥256 bits HMAC or ≥2048 RSA?

### 3. Authorization & Access Control

- All access controls enforced server-side?
- Default-deny policy (fail closed)?
- IDOR prevention: ownership checks on every resource access?
- Horizontal privilege escalation: can user A access user B's data?
- Vertical privilege escalation: can a regular user reach admin endpoints?
- API endpoints: authorization checked after authentication?
- Role/permission assignments: can they be manipulated client-side?

### 4. Secrets & Cryptography

- **Hardcoded secrets**: grep for API keys, tokens, passwords, connection strings
  in source code, config files, and git history
- Secrets loaded from environment variables or a secret manager?
- `.env` files in `.gitignore`?
- Algorithms: AES-256, RSA ≥2048, ECC P-256+ (flag DES, 3DES, RC4, MD5, SHA-1)
- TLS: strong cipher suites, certificate validation, no self-signed in prod?
- Random number generation: `secrets` module, not `random`?

### 5. Dependencies & Supply Chain

- Known vulnerabilities in dependencies? (run `pip audit`, `safety check`,
  or check with `uv` tooling)
- Dependencies pinned to specific versions?
- Are dependencies actively maintained?
- Lockfile (`uv.lock`, `poetry.lock`) committed and up to date?
- Any dependency doing something unexpected? (post-install scripts, network calls)

### 6. Error Handling & Information Disclosure

- Stack traces or debug info exposed to users in production?
- Error messages revealing internal paths, database structure, or versions?
- Generic error responses for auth failures (no "user not found" vs "wrong password")?
- Exception handling: fail closed, not open?
- Exceptions in security-critical paths: caught and handled, not swallowed?

### 7. Logging & Monitoring

- Authentication attempts logged (successes and failures)?
- Authorization denials logged?
- **Never logged**: passwords, tokens, PII, credit card numbers
- Log entries sanitized against injection?
- Audit trail for sensitive operations (data access, config changes)?

### 8. Configuration & Deployment

- Debug mode disabled in production config?
- CORS: restrictive origins, not `*`?
- HTTP security headers: CSP, X-Content-Type-Options, X-Frame-Options,
  Strict-Transport-Security?
- Default credentials replaced?
- Unnecessary endpoints/services disabled?
- Environment separation (dev/staging/prod) with different secrets?

## Python-Specific Checks

These are common Python security pitfalls — flag if found:

| Pattern | Risk | Fix |
|---|---|---|
| `pickle.loads(untrusted)` | Remote code execution | Use JSON or msgpack |
| `yaml.load(f)` | Code execution | `yaml.safe_load(f)` |
| `eval()` / `exec()` on user input | Code execution | Never |
| `subprocess.run(cmd, shell=True)` | Command injection | `shell=False` + list args |
| `os.system(user_input)` | Command injection | `subprocess.run()` with list |
| `random.random()` for tokens | Predictable | `secrets.token_urlsafe()` |
| `hashlib.md5(password)` | Weak hash | `bcrypt` or `argon2` |
| `request.args` used in SQL | SQL injection | Parameterized query |
| `open(user_path)` | Path traversal | Validate against allowed base path |
| `DEBUG = True` in prod | Info disclosure | Env-based config |
| Bare `except:` in auth code | Fail open | Explicit exception types, fail closed |

## Output

Save to `docs/reviews/[YYYY-MM-DD]-security.md`. Create `docs/reviews/` if it
doesn't exist. Override if a file with the same name already exists.

Each recommendation must be **atomic and actionable** — one vulnerability per
checkbox.

```markdown
# Security Review

**Date**: [YYYY-MM-DD]
**Scope**: [Full codebase / specific area]
**OWASP Alignment**: Top 10:2025

## Summary
[2-3 sentences: overall security posture, critical findings count]

## Strengths
- [Security practices already in place]

## Recommendations

### Critical (Exploitable Vulnerabilities)
- [ ] **S1** — [Title]: [What's vulnerable, how it can be exploited, fix.
  File(s): `path:line`]

### Important (Security Weaknesses)
- [ ] **S2** — [Title]: [What's weak, risk, fix. File(s): `path:line`]

### Suggestions (Hardening)
- [ ] **S3** — [Title]: [What to harden, why. File(s): `path`]

*Sequential numbering (S1, S2, S3…) across all categories.*
*Use S prefix (not R) to distinguish from code review recommendations.*
```

## After the Review

Provide a brief chat summary:
- **Findings**: X critical, Y important, Z suggestions
- Top 2-3 most urgent issues
- Suggest running `moov-livraison:improve-after-review` to fix findings.
  Always wait for explicit user confirmation before invoking it.
