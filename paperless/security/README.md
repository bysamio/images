# Paperless patch and outstanding findings

Updated 16 October 2026; next vendor/applicability review due 18 October 2026.

The base index is pinned in the Dockerfile. Revision 3.3.2-r1 adds the reviewed
[AI corrections](../README.md#complete-prompt-budgeting-in-332-r1), including a
checksum-pinned public tokenizer. It retains the non-root contract and full
scan metadata. Native provider/UI validation remains a consumer deployment gate.

| Change | Evidence |
| --- | --- |
| Ghostscript and all three libgs packages to `10.05.1~dfsg-1+deb13u3` | Debian fixes [CVE-2026-101258](https://security-tracker.debian.org/tracker/CVE-2026-101258) and [CVE-2026-103226](https://security-tracker.debian.org/tracker/CVE-2026-103226); parser/OCR/PDF-A tests pass. |
| Curl and both installed libcurl variants to `8.14.1-2+deb13u7` | Debian Trixie security backport [DSA-6558](https://security-tracker.debian.org/tracker/DSA-6558-1) fixes CVE-2026-8286, CVE-2026-8924, CVE-2026-8927 and CVE-2026-92392. Package floors and inherited curl health/startup behavior are verified. |
| librsvg2-2 to `2.60.0+dfsg-1+deb13u1` | Debian Trixie backport [DSA-6555](https://security-tracker.debian.org/tracker/DSA-6555-1) fixes CVE-2026-96889. Verify the installed package floor and full parser/startup suite. |
| fsspec `2026.6.0`, wheel SHA-256 pinned | Fix for CVE-2026-104851; `uv pip check --system` passes for the application environment. |
| Remove unused pip and its bootstrap wheel | pip 26.2.1 vendors msgpack 1.1.2 (GHSA-6v7p-g79w-8964), setuptools 70.3.0 (CVE-2025-47273) and urllib3 2.7.0 (CVE-2026-97687 / CVE-2026-97689). Updating the global application copies does not update these bundled copies. Tests assert pip absence and preserve uv. |
| Default UID/GID `1000:1000` | Default and explicit UID startup pass with all capabilities dropped and no-new-privileges. Data paths must be owned by the selected UID. |

## Scan evidence

The initial full HIGH/CRITICAL scan of the patched native ARM64 image with
Trivy 0.71.1 and its 11 October database reports **209 HIGH, 9 CRITICAL**, representing
**73 distinct advisories**, with **zero vendor-listed fixes**. These counts include
package occurrences; they are not 218 independent reachable exploits. The official
AMD64 baseline had 222 HIGH / 9 CRITICAL / 13 fixable occurrences. Architecture and
image provenance differ, so the AMD64 CI scan is the authoritative release report.

The full ARM64 filesystem was scanned with no analysis exclusions; database
updates were skipped only to keep the same cached database during comparison.
CI updates its database, retains all severities and generates an SBOM. A later
database can introduce new findings or fixes and must be assessed again.

## Deployment decisions still required

| Finding | Scope, evidence and disposition |
| --- | --- |
| CVE-2026-49261, four MariaDB package occurrences | [MariaDB server advisory](https://github.com/MariaDB/server/security/advisories/GHSA-3p3m-4x7c-p4pw) requires `wsrep_notify_cmd`. No `mariadbd`/`mysqld` executable is installed in the tested image. The intended database is PostgreSQL. Inapplicable to that server path; reassess if MariaDB integrations are introduced. |
| CVE-2026-44172, four MariaDB package occurrences | [MariaDB client advisory](https://github.com/MariaDB/server/security/advisories/GHSA-pv9p-5w55-55jm) is rated moderate by MariaDB and requires Big5 with `mysql_real_escape_string()` and the text protocol. Expected to be outside the PostgreSQL connection path. Verify the effective backend/integrations on the deployed digest before acceptance. |
| CVE-2026-6653, libxml2 | [Debian tracker](https://security-tracker.debian.org/tracker/CVE-2026-6653) describes XML-parser denial of service, marks Trixie minor and lists no stable fix. The package remains vulnerable. Application/parser reachability and a bounded mitigation or deferral still need review. |
| CVE-2026-81726, NLTK | No fix is listed in this scan for installed 3.10.3. Review model-artifact path handling in the actual application; do not treat absence of a fix as absence of risk. |
| Remaining HIGH package findings | Kept in full reports. Complete vendor/applicability triage before accepting the image for personal documents. |

For phase-1 development, use only synthetic documents and disposable state.
The intended consumer has loopback-only web access, an internal network,
non-root execution, no extra capabilities, no-new-privileges, limited OCR workers
and CPU/memory limits. These controls bound exposure; they do not fix parser bugs.
No family documents should be ingested until image triage, host mount/runtime
guards and backup/restore gates pass. Publication is for reproducible review and
future consumption, and is not a declaration of personal-data readiness.

## Historical 3.3.0 candidate verification, 16 October 2026

The final combined ARM64 candidate passes the complete image suite and the
unchanged fixable HIGH/CRITICAL publication gate. A refreshed Trivy 0.71.1 scan
retains **200 HIGH / 9 CRITICAL**, **68 distinct advisories**, and **zero listed
fixes**. The curl/librsvg security updates remove the ten previously fixable
package occurrences; no advisory is suppressed. These counts describe package
findings, not distinct reachable exploits. The [validation record](ai-fixes-validation-3.3.0.json)
retains the local image ID and full report checksum. Native AMD64 CI and its
retained scan/SBOM remain authoritative for a registry release.

The tokenizer is fixed public data from Qwen's named model revision, not model
weights or executable code. Its source/hash/license are recorded separately;
the build verifies both artifact and license, and runtime needs no downloader
or new Python dependency. The AI patches preserve permissions, trust-boundary
instructions and candidate-ID validation. Provider token framing and actual
answer/suggestion quality remain deployment checks, alongside a fresh assessment
of the final digest and its unchanged/unfixed parser advisories.

## Stable 3.3.2 candidate verification

The operator requested the latest stable release on 16 October. Official 3.3.2
is pinned by multi-platform digest. It includes upstream fixes for document
version content/permissions and [ownerless AI classification disclosure](https://github.com/paperless-ngx/paperless-ngx/security/advisories/GHSA-c8f3-pqr2-rr24).
Exact-image inspection confirms those source changes are preserved. Untouched
3.3.2 still reproduces the duplicate retrieval/generation and combined context
budget failures; the adapted correction passes against this version. Effective-content and
ownerless vector/full-text permission regressions pass with real disposable ORM
state, including stale private retrieval results. The full local ARM64 image
suite, German/English OCR, inherited health and fixable HIGH/CRITICAL gate pass.
The fresh full scan retains 200 HIGH / 9 CRITICAL, 68 distinct advisories and
zero listed fixes; no findings are suppressed. The [current validation record](ai-fixes-validation.json)
records the new image ID and report checksum. Native AMD64 CI remains required
before publication; native provider and ordinary-account UI acceptance remain
consumer deployment gates. Historical 3.3.0 results do not accept this artifact.
