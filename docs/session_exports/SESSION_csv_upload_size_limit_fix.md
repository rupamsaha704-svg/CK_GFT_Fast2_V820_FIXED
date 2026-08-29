# SESSION EXPORT — CSV Upload Size-Limit Bugfix Spec (`large-csv-upload-fix`)

> Honest, exhaustive export of ONE Kiro session. Nothing here is fabricated.
> Where a value is unverified or an assumption, it is marked as such.
> Language of original discussion: Bengali (mixed with English technical terms).

---

## 0. CRITICAL CLARIFICATION FOR A FUTURE AGENT (read first)

**This session has NOTHING to do with the trading / MQL5 / Goat Funded Trader work that fills the rest of this repository.**

- No Expert Advisor, no `.mq5`, no strategy, no backtest, no metrics, no risk-management logic
  was produced or discussed in this session.
- This session was a **Kiro Spec workflow** that produced a **bugfix specification** for a generic
  software bug: *large / oversized CSV file uploads failing*.
- It is being filed here only because the user is consolidating **all** of their scattered Kiro
  sessions into this one repo before losing AWS free-tier access. Do not try to connect this to the
  gold-scalper EA work — they are unrelated.
- No repository was connected to the session while the spec was authored, so the fix is written
  **stack-agnostically** (Nginx / Apache / PHP / Node-Express) and was **never executed** against
  real code.

---

## 1. PURPOSE OF THIS SESSION

Use Kiro's spec-driven workflow to document and plan a fix for a reported bug:

> "A CSV file upload does not go through."

The session ran the **Bugfix** spec workflow (Requirements-First) end-to-end and produced three spec
documents plus a config file for a feature named **`large-csv-upload-fix`**.

Spec files live (in THIS sandbox session, NOT yet in this repo) at:
`/projects/sandbox/new-project/.kiro/specs/large-csv-upload-fix/`
containing: `.config.kiro`, `bugfix.md`, `design.md`, `tasks.md`.

Those four files are reproduced verbatim in Section 6 below (they were never in a git repo, so this
export may be their only copy).

---

## 2. TIMELINE / NARRATIVE OF THE SESSION

1. **User's first message (Bengali/mixed):** "55mb csv file upload nicche na to" — a ~55MB CSV file
   upload is not going through.
2. Kiro treated this as a **Bugfix** spec and generated the **requirements** (`bugfix.md`).
   During the requirements phase, two clarifying answers were captured (per the subagent report):
   - Failure mode: the upload **"times out or hangs"**.
   - Expected limit: user **"not sure of the exact limit"** — large files should just upload; the
     precise threshold was unconfirmed.
3. **User's second message (Bengali, paraphrased):** It is *still* not working. The CSV file is now
   only **3.8 MB total**. It says the **limit is being crossed / exceeded** ("limit cross ho
   jacche", "eto MB", "bere jacche"). Asked for a short answer on what to do.
4. Kiro gave a **short troubleshooting answer** (in Bengali): a 3.8MB file failing with a
   "limit exceeded" error means the server/app **upload size limit is configured too low**, and
   listed the concrete knobs per stack (see Section 5). Asked which stack the user is on.
5. **User:** "Generate the design document and tasks based on the requirements."
6. Kiro generated **`design.md`** — importantly **re-diagnosing the root cause** from "processing
   timeout" to "**upload/request-body size limit set too low**", driven by the new 3.8MB evidence.
   Then generated **`tasks.md`** (the implementation plan).
7. **User:** the big **session-export request** (this document) + a live-steering message
   **"Execute all tasks"**.

### Note on "Execute all tasks"
The spec's `tasks.md` implementation tasks **could not be executed** in this session because there
is **no connected application codebase / server pipeline** — the tasks operate on Nginx/PHP/Node
config and an upload handler that do not exist here. Executing them would have required fabricating
results, which was refused. "Execute all tasks" was therefore interpreted as "complete all steps of
the export job", which is what this file represents.

---

## 3. KEY DECISIONS (and why)

1. **Classified as a Bugfix (not a feature).** The report described existing behavior that is
   broken ("upload not going through"), matching bugfix indicators.
2. **Root-cause re-diagnosis — the single most important decision.** Initially the symptom looked
   like a processing timeout for a 55MB file. When the user reported a **3.8MB** file *also* failing
   with a **"limit exceeded"** error, the diagnosis was changed to: **a configured upload /
   request-body size limit set too low somewhere in the request pipeline.** A 3.8MB file is far too
   small to plausibly time out on parsing, but it comfortably exceeds common default limits.
3. **Multi-layer "effective limit" model.** The design formalizes:
   `effectiveLimit = MIN(proxyBodyLimit, appServerBodyLimit, frameworkParserLimit)`.
   Consequence: raising the limit on only ONE layer will NOT fix the bug if another layer still caps
   it lower. All layers on the request path must permit the intended size.
4. **Investigation-first fix.** Because no repo was connected, the plan mandates diagnosing WHICH
   layer is the limiting one (from the exact error signature) before changing anything.
5. **Keep a sane ceiling, do not remove limits.** Raise to an agreed ceiling (e.g. 64MB or 100MB)
   with headroom — never unlimited — to preserve protection against abusive payloads.
6. **Add streaming for the genuinely large (55MB) case** so memory stays bounded even after limits
   are raised.
7. **Bugfix correctness methodology preserved:** a bug-condition test that must FAIL before the fix,
   preservation tests that must PASS before and after, then fix-checking.

---

## 4. DATA / NUMBERS (all that exist in this session)

There are **no datasets, backtests, or performance metrics** in this session. The only concrete
numbers are file sizes and typical framework default limits (the defaults are general knowledge
cited in the design, NOT measured from the user's system):

- **55 MB** — originally reported failing CSV file size.
- **3.8 MB** — later reported failing CSV file size (the key evidence that reframed the diagnosis).
- Typical default upload limits referenced (UNVERIFIED against the user's actual system):
  - Nginx `client_max_body_size` default ~**1 MB**.
  - PHP `upload_max_filesize` default ~**2 MB**; `post_max_size` default ~**8 MB**.
  - Express/body-parser JSON `limit` default ~**100 kB**.
- Suggested fix ceiling: **64 MB or 100 MB** (a recommendation, not a user-confirmed requirement).

**Unknown / unconfirmed:** the user's actual tech stack, hosting, the exact failing threshold, and
which layer is actually rejecting the upload.

---

## 5. TROUBLESHOOTING GUIDANCE GIVEN TO THE USER (verbatim intent)

Short fix guidance provided in-chat (raise the upload size limit on whichever layer applies):

- **Nginx:** `client_max_body_size 50M;` then reload (`nginx -s reload`).
- **PHP (`php.ini`):** `upload_max_filesize = 50M` and `post_max_size = 50M` (post_max_size must be
  >= upload_max_filesize), then restart PHP-FPM / web server.
- **Node/Express:** `express.json({ limit: '50mb' })`, or for multipart use multer with
  `limits: { fileSize: 50*1024*1024 }`.
- **Apache:** `LimitRequestBody 52428800` (bytes).

The user was asked which stack/hosting they use (Nginx / PHP / Node / cPanel / other). **As of the
end of this session that question was not answered**, so the precise "which file, which line" is
still open.

---

## 6. FULL FILE CONTENTS (verbatim — may be the only copy)

### 6.1 `.config.kiro`
```
{ workflowType: requirements-first, specType: bugfix }
```
(Exact JSON not re-read byte-for-byte in this export; the subagent reported it contains
`workflowType: requirements-first` and `specType: bugfix`. Treat the above as the semantic content.)

### 6.2 `bugfix.md` (requirements)
````markdown
# Bugfix Requirements Document

## Introduction

Users are unable to upload large CSV files. When a CSV file around 55MB (and, by extension, files at or above some large-file threshold) is uploaded, the upload does not complete — it times out or hangs indefinitely rather than finishing successfully. Smaller CSV files upload without issue.

This defect blocks users from importing large datasets, effectively capping the usable file size well below what users need. The exact size threshold where uploads begin to fail is not yet confirmed (a 55MB file is a known-failing example). The fix must allow large CSV uploads to complete successfully while preserving correct behavior for the small/normal-sized files that already work today.

## Bug Analysis

### Current Behavior (Defect)

When a large CSV file is uploaded, the upload stalls and never completes.

1.1 WHEN a user uploads a large CSV file (e.g. ~55MB) THEN the system hangs or times out and the upload never completes
1.2 WHEN a large CSV upload times out or hangs THEN the system does not import the file's data and leaves the operation in an unresolved state

### Expected Behavior (Correct)

Large CSV files should upload and be processed successfully within a reasonable time.

2.1 WHEN a user uploads a large CSV file (e.g. ~55MB) THEN the system SHALL complete the upload successfully without timing out or hanging
2.2 WHEN a large CSV upload completes THEN the system SHALL process/import the file's data correctly, consistent with how smaller files are handled

### Unchanged Behavior (Regression Prevention)

Existing behavior for smaller/normal CSV files must be preserved.

3.1 WHEN a user uploads a small or normal-sized CSV file THEN the system SHALL CONTINUE TO upload it successfully
3.2 WHEN a valid CSV file is uploaded THEN the system SHALL CONTINUE TO parse and import its contents correctly
````

### 6.3 `design.md` (technical design)
````markdown
# Large CSV Upload Fix Bugfix Design

## Overview

Users cannot upload CSV files above a surprisingly small size. Although the original report referenced a ~55MB file failing, new evidence shows uploads failing with a file that is only **3.8MB total**, accompanied by an error indicating an **upload size/limit is being exceeded** ("limit cross ho jacche"). This strongly reframes the problem: the failure is almost certainly caused by a **configured upload / request-body size limit set very low** somewhere in the request pipeline, not by a raw processing timeout on the CSV parsing logic.

Request bodies pass through several layers, each of which may enforce its own maximum size:

```
Client (browser) -> Reverse Proxy (Nginx / Apache) -> App Server (PHP-FPM / Node / etc.) -> Application code (framework body/file parser)
```

Any single layer with a limit smaller than the uploaded payload will reject or truncate the request before the application ever finishes reading it — producing exactly the observed symptom (upload fails, often surfaced as a hang, a 413 "Payload Too Large", or a broken/aborted connection).

Because no repository is connected, this design is written to be **stack-agnostic**: it enumerates the common limit locations across Nginx, Apache, PHP, and Node/Express, prescribes a concrete investigation procedure to identify the *actual* limiting layer, and defines a fix (raise the limit to a sensible ceiling and/or stream large uploads) that is validated for both the buggy inputs (large files) and the preserved inputs (small files that already work).

The fix must be **targeted and minimal**: raise/align the upload size limits (and, where appropriate, switch to streaming) so that legitimately-sized CSVs upload successfully, while leaving all behavior for small/normal files and non-upload requests completely unchanged.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — a CSV upload whose request body size exceeds the smallest configured upload/body-size limit in the request pipeline, causing the upload to be rejected, truncated, or hung rather than completing.
- **Property (P)**: The desired behavior when the bug condition holds — an upload of a legitimately-sized CSV (up to an agreed maximum, e.g. the size the product intends to support) SHALL complete successfully and its data SHALL be imported correctly.
- **Preservation**: Existing behavior that must remain unchanged — small/normal CSV uploads continue to succeed and import correctly, and non-upload requests are unaffected by any limit change.
- **Upload size limit**: A configured maximum request-body (or per-file) size enforced by a layer in the pipeline. Examples: Nginx `client_max_body_size`, Apache `LimitRequestBody`, PHP `upload_max_filesize` / `post_max_size`, Node/Express `body-parser` `limit` or `multer` `limits.fileSize`.
- **Limiting layer**: The specific pipeline layer (proxy, app server, or framework parser) whose limit is smallest and therefore the one actually rejecting the request.
- **uploadHandler**: The application endpoint/function that receives the CSV multipart/form-data request and parses/imports it. Exact name/path is unknown until a repository is connected.
- **Streaming upload**: Reading and processing the incoming request body incrementally (e.g. piping to disk or a stream parser) rather than buffering the entire payload in memory, which both avoids memory pressure and interacts with size-limit configuration.

## Bug Details

### Bug Condition

The bug manifests when a user uploads a CSV file whose HTTP request body size exceeds the **smallest** upload/body-size limit configured across the request pipeline (reverse proxy, application server, or framework parser). When that smallest limit is set very low (evidence: a 3.8MB file already fails), even modest CSV files are rejected. The offending layer either returns a size-limit error (commonly HTTP 413), aborts/closes the connection, or the client perceives the aborted transfer as a hang/timeout — so the upload never completes and the data is never imported.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type UploadRequest
         (fields: fileBytes, contentType = "text/csv" | multipart CSV part)
  OUTPUT: boolean

  effectiveLimit := MIN(
      proxyBodyLimit,        // e.g. Nginx client_max_body_size / Apache LimitRequestBody
      appServerBodyLimit,    // e.g. PHP post_max_size / upload_max_filesize
      frameworkParserLimit   // e.g. Express body-parser limit / multer limits.fileSize
  )

  RETURN isCsvUpload(input)
         AND input.fileBytes > effectiveLimit
         AND input.fileBytes <= intendedSupportedMaxSize   // a legitimately-sized file we WANT to accept
         AND uploadDidNotComplete(input)                    // rejected (413), aborted, or hung
END FUNCTION
```

The key insight captured by `effectiveLimit = MIN(...)`: raising the limit on only one layer will not fix the bug if a different layer still enforces a smaller limit. All layers on the path must permit the intended size.

### Examples

- **Known-failing small file (primary new evidence)**: A user uploads a **3.8MB** CSV. Expected: upload completes and imports. Actual: upload fails with an upload-size-limit-exceeded error / hang. This indicates the effective limit is set well below 3.8MB (e.g. a default like 1MB or 2MB).
- **Originally reported large file**: A ~55MB CSV upload never completes. Expected: completes and imports. Actual: hangs/times out — consistent with the same size-limit ceiling.
- **Boundary example**: A CSV just under the effective limit (e.g. sub-1MB) uploads fine; the same content padded just over the limit fails — demonstrating the failure tracks size, not content.
- **Edge case — exactly at the limit**: A file whose size equals the configured limit; behavior at the exact boundary should be well-defined (accepted) after the fix.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Small/normal CSV uploads (already working today) SHALL continue to upload successfully.
- Valid CSV parsing and import logic SHALL continue to produce the same imported result for files that already worked.
- Non-CSV / non-upload requests SHALL be completely unaffected by any size-limit configuration change.
- Existing validation and error handling for genuinely-oversized or malicious payloads SHALL remain in place (we raise the limit to a sensible ceiling, we do NOT remove all limits).

**Scope:**
All inputs that do NOT involve a CSV upload exceeding the current effective limit should be completely unaffected by this fix. This includes:
- Small/normal CSV uploads that already succeed
- Non-upload HTTP requests (GET requests, API calls, page loads)
- Uploads of other file types handled by separate endpoints/limits

**Note:** The actual expected correct behavior for buggy inputs (large-but-legitimate CSVs) is defined in the Correctness Properties section (Property 1). This section focuses on what must NOT change.

## Hypothesized Root Cause

Based on the new evidence (a 3.8MB file failing with an upload-size-limit error), the root cause is a **request-body / upload size limit configured too low** in one or more pipeline layers. The candidate layers, by common stack:

1. **Reverse Proxy — Nginx**: `client_max_body_size` defaults to **1MB**. If Nginx fronts the app and this directive is left at default (or set low), any body over 1MB is rejected with **413 Request Entity Too Large**. This is the single most common cause of "small file still fails."
   - Applies at `http`, `server`, or `location` scope — a low value at a narrower scope can override a higher global value.

2. **Reverse Proxy / Web Server — Apache**: `LimitRequestBody` (bytes; `0` = unlimited). A low non-zero value rejects large bodies with **413**. Also relevant: `mod_reqtimeout` and proxy timeouts if Apache proxies to an app server.

3. **App Server — PHP**: Two interacting directives in `php.ini`:
   - `upload_max_filesize` (default commonly **2MB**) — caps a single uploaded file.
   - `post_max_size` (default commonly **8MB**) — caps the entire POST body and MUST be >= `upload_max_filesize`.
   - Either being low causes silent truncation / empty `$_FILES` or a size error. A 2MB default explains a 3.8MB failure directly.
   - Related: `max_file_uploads`, `memory_limit`, `max_execution_time`, `max_input_time` (matter more for the larger 55MB case).

4. **App Framework — Node/Express**:
   - `express.json()` / `express.urlencoded()` / `body-parser` `limit` option defaults to **100kb** — but CSV uploads should use multipart, not JSON parsing; misuse can cause failures.
   - `multer` `limits.fileSize` — if set low, throws `LIMIT_FILE_SIZE`. If unset, multer buffers to memory/disk which interacts with the 55MB memory concern.
   - Any custom size guard in the upload handler.

5. **Non-configuration contributors (secondary, mainly for the original 55MB case)**:
   - **Buffering entire file in memory** rather than streaming — causes memory pressure / slowness for very large files even once limits are raised.
   - **Timeouts** (proxy read timeout, app execution time) — a genuine factor for 55MB but NOT the explanation for a 3.8MB failure. The size-limit hypothesis takes precedence given the new evidence.

**Prioritized hypothesis:** The smallest configured limit is a proxy `client_max_body_size` (Nginx, ~1MB default) or a PHP `upload_max_filesize`/`post_max_size` (~2MB default). Investigation (below) must confirm which layer is the limiting one before changing anything.

## Correctness Properties

Property 1: Bug Condition - Large-but-legitimate CSV uploads complete and import

_For any_ CSV upload where the bug condition holds (isBugCondition returns true) — i.e. a file larger than the current effective limit but within the intended supported maximum — the fixed system SHALL complete the upload successfully (no 413, no abort, no hang) and SHALL parse/import the file's data correctly, consistent with how smaller files are imported.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - Small/normal uploads and non-upload requests unchanged

_For any_ input where the bug condition does NOT hold (isBugCondition returns false) — small/normal CSV uploads, non-CSV requests, and non-upload requests — the fixed system SHALL produce the same result as the original system, preserving successful upload and correct import for already-working files and preserving all non-upload behavior.

**Validates: Requirements 3.1, 3.2**

## Fix Implementation

### Investigation First (Identify the Limiting Layer)

Because no repository is connected and the pipeline is unknown, the fix begins with a diagnosis step. Do NOT change limits blindly on every layer; identify the smallest/limiting layer, then raise limits consistently across all layers on the path.

**Diagnostic steps:**
1. **Reproduce and read the exact error/status.** A **413** almost always points to a proxy (Nginx/Apache) or PHP `post_max_size`. A silent empty `$_FILES` points to PHP `upload_max_filesize`. A `LIMIT_FILE_SIZE` error points to multer. A connection reset/hang may point to proxy or app-server body limits.
2. **Check the reverse proxy config** (if any): Nginx `client_max_body_size`, Apache `LimitRequestBody`.
3. **Check the app-server / language config**: PHP `upload_max_filesize`, `post_max_size` (via `php.ini` / `phpinfo()`); Node framework parser and multer limits.
4. **Check application-level guards**: any explicit size check in the upload handler.
5. **Confirm the smallest value** — that layer is the culprit; note ALL layers that are below the intended maximum.

### Changes Required (apply to the layer(s) identified; keep limits consistent across the path)

Assuming the diagnosis confirms a low body-size limit, raise the limit to an agreed, sensible ceiling (e.g. comfortably above the intended supported CSV size — pick a value like 64MB or 100MB per product requirements) on **every** layer on the request path, and add streaming for very large payloads.

**Stack: Nginx (reverse proxy)**
1. Set `client_max_body_size` to the agreed ceiling (e.g. `client_max_body_size 100M;`) at the appropriate scope (`http`/`server`/`location`).
2. Raise proxy timeouts if the larger 55MB case reveals slowness: `client_body_timeout`, `proxy_read_timeout`, `proxy_send_timeout`.
3. Reload Nginx.

**Stack: Apache (web server / proxy)**
1. Set `LimitRequestBody` to the agreed ceiling in bytes (or `0` for unlimited only if policy allows) in the relevant `<Directory>`/vhost.
2. If proxying, align `ProxyTimeout` and `mod_reqtimeout` settings for the large-file case.

**Stack: PHP (app server)**
1. Raise `upload_max_filesize` to the agreed ceiling.
2. Raise `post_max_size` to be **>=** `upload_max_filesize` (and account for other form fields).
3. For the 55MB case, review `memory_limit`, `max_execution_time`, `max_input_time` so processing has room.
4. Restart PHP-FPM / the web server so `php.ini` changes take effect.

**Stack: Node / Express**
1. Ensure the CSV endpoint uses a multipart handler (e.g. `multer`) rather than JSON body parsing.
2. Set `multer` `limits.fileSize` to the agreed ceiling (not a small default).
3. If using `body-parser`/`express.json()` on that route, raise its `limit` only if the payload legitimately flows through it (usually it should not for file uploads).
4. Prefer **streaming to disk / a stream CSV parser** over buffering the whole file in memory.

**Cross-cutting**
5. **Streaming for large uploads**: where the current handler buffers the entire file, switch to streaming (pipe to temp storage or a streaming CSV parser) so memory use stays bounded for the 55MB case even after limits are raised.
6. **Keep a sane ceiling**: raise the limit to the intended maximum plus headroom — do NOT remove limits entirely, preserving protection against abusive payloads.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code/config (large-but-legitimate CSVs fail with a size-limit error), then verify the fix works correctly (those files now upload and import) and preserves existing behavior (small files and non-upload requests unchanged). Because the primary root cause is configuration, tests include both application-level checks and end-to-end upload checks against the running pipeline.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix, and confirm which layer enforces the limit. Confirm or refute the size-limit root cause. If we refute (e.g. limits are already high and failures are pure timeouts), we re-hypothesize toward streaming/timeouts.

**Test Plan**: Upload CSV files of increasing size against the UNFIXED pipeline and record the exact failure (HTTP status, error text, empty `$_FILES`, connection reset, or hang). Binary-search the size to pinpoint the effective limit, and correlate the failure signature with a specific layer.

**Test Cases**:
1. **3.8MB CSV upload (known-failing)**: Upload the reported 3.8MB file (will fail on unfixed code) and capture the exact error — expected 413 or size-limit error.
2. **Threshold discovery**: Upload progressively sized CSVs (e.g. 0.5MB, 1MB, 2MB, 4MB) to find the exact size where success turns to failure (pinpoints the effective limit ~ a common default like 1MB/2MB).
3. **~55MB CSV upload (original report)**: Upload the large file (will fail on unfixed code) — distinguish a size-limit rejection from a timeout/memory failure.
4. **Layer attribution**: Inspect proxy vs app-server vs framework responses to attribute the failure to the limiting layer.

**Expected Counterexamples**:
- Uploads above the effective limit are rejected (413 / size error) or hang and never import.
- Possible causes: Nginx `client_max_body_size` default (~1MB), PHP `upload_max_filesize`/`post_max_size` defaults (~2MB/8MB), a low multer/body-parser limit, or an app-level size guard.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (large-but-legitimate CSVs), the fixed system completes the upload and imports the data correctly.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := uploadHandler_fixed(input)
  ASSERT uploadCompleted(result)            // no 413, no abort, no hang
  ASSERT importedDataMatchesFile(result)    // data parsed/imported correctly
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (small/normal CSVs, non-upload requests), the fixed system produces the same result as the original system.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT uploadHandler_original(input) = uploadHandler_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many CSV sizes/shapes automatically across the input domain (including sizes below the old limit).
- It catches edge cases that manual unit tests might miss (empty files, single-row files, files just under the limit).
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs.

**Test Plan**: Observe behavior on the UNFIXED pipeline first for small CSVs and non-upload requests, capture the successful outcomes and imported results, then write property-based tests asserting these outcomes are identical after the fix.

**Test Cases**:
1. **Small CSV preservation**: Observe that a small CSV uploads and imports correctly on unfixed code, then verify identical result after the fix.
2. **Import-correctness preservation**: Observe parsed/imported content for a known small CSV, then verify byte-for-byte/row-for-row identical import after the fix.
3. **Non-upload request preservation**: Observe that GET/API/page requests behave identically before and after the size-limit change.
4. **Boundary preservation**: Verify files just under the *original* limit still succeed unchanged, and confirm no new rejection is introduced below the new ceiling.

### Unit Tests

- Test the upload handler accepts a file at the newly-configured ceiling and rejects only clearly abusive sizes above it.
- Test size-limit configuration values are read correctly (parser limit / multer limit) where limits are code-level.
- Test that small-file upload and import paths are unchanged.

### Property-Based Tests

- Generate CSVs of random sizes spanning below-old-limit, between-old-and-new-limit, and above-new-limit; assert acceptance for <= ceiling and correct rejection for > ceiling.
- Generate random valid CSV contents and assert imported data equals input for all accepted sizes (fix + preservation).
- Generate non-upload requests and assert identical behavior before/after the change.

### Integration Tests

- End-to-end upload of the 3.8MB and ~55MB CSVs against the fully-configured pipeline (proxy + app server + app), asserting completion and correct import.
- Multi-layer alignment test: confirm no intermediate layer still enforces a smaller limit (upload succeeds end-to-end, not just at the app layer).
- Streaming/memory test for the 55MB case: confirm the upload completes without exhausting memory or hitting timeouts.
````

### 6.4 `tasks.md` (implementation plan)
````markdown
# Implementation Plan

- [ ] 1. Write bug condition exploration test (large-but-legitimate CSV uploads)
  - **Property 1: Bug Condition** - Large-but-legitimate CSV uploads fail with a size-limit error
  - **CRITICAL**: This test MUST FAIL on the unfixed pipeline — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code/config when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug AND pinpoint the limiting layer
  - **Scoped PBT Approach**: For deterministic reproduction, scope the property to concrete failing cases — the reported **3.8MB** CSV and the original **~55MB** CSV — then generalize to "any CSV whose size exceeds the effective limit but is within the intended supported maximum".
  - Encode `isBugCondition(input)` from the design: `isCsvUpload(input) AND input.fileBytes > effectiveLimit AND input.fileBytes <= intendedSupportedMaxSize AND uploadDidNotComplete(input)`, where `effectiveLimit = MIN(proxyBodyLimit, appServerBodyLimit, frameworkParserLimit)`.
  - Test asserts the Expected Behavior Property: an upload of a legitimately-sized CSV completes (no 413, no abort, no hang) and imports its data correctly.
  - Run the test against the UNFIXED pipeline (proxy + app server + framework parser).
  - **Threshold discovery**: Upload progressively sized CSVs (e.g. 0.5MB, 1MB, 2MB, 4MB) to binary-search the exact size where success turns to failure, pinpointing the effective limit (likely a common default such as Nginx `client_max_body_size` ~1MB or PHP `upload_max_filesize`/`post_max_size` ~2MB/8MB).
  - **Layer attribution**: Capture the exact failure signature (HTTP 413, empty `$_FILES`, multer `LIMIT_FILE_SIZE`, connection reset, or hang) and attribute it to the specific limiting layer (Nginx / Apache / PHP / Node-Express).
  - **EXPECTED OUTCOME**: Test FAILS (this is correct — it proves the bug exists)
  - Document counterexamples found to understand root cause (e.g. "3.8MB CSV upload returns HTTP 413 instead of completing", "~55MB CSV upload hangs and never imports").
  - Mark task complete when the test is written, run, the failure is documented, and the limiting layer is identified.
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Small/normal uploads and non-upload requests unchanged
  - **IMPORTANT**: Follow the observation-first methodology
  - Observe behavior on the UNFIXED pipeline for inputs where `isBugCondition` returns false:
    - Observe: a small/normal CSV (below the current effective limit) uploads successfully and imports correctly.
    - Observe: the parsed/imported content (row-for-row) for a known small CSV.
    - Observe: non-upload requests (GET, API calls, page loads) return their normal responses.
    - Observe: files just under the *original* limit still succeed.
  - Record the actual outputs (success status, imported rows, response codes/bodies).
  - Write **property-based tests** capturing the observed behavior across the input domain (from Preservation Requirements in the design):
    - Generate CSVs of random sizes below the old limit and assert successful upload + correct import.
    - Generate random valid CSV contents and assert imported data equals input for all accepted small sizes.
    - Generate/exercise non-upload requests and assert identical behavior before/after.
  - Property-based testing generates many CSV sizes/shapes automatically for stronger preservation guarantees and catches edge cases (empty files, single-row files, files just under the limit).
  - Run the tests on the UNFIXED pipeline.
  - **EXPECTED OUTCOME**: Tests PASS (this confirms the baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on the unfixed pipeline.
  - _Requirements: 3.1, 3.2_

- [ ] 3. Fix for low upload/request-body size limit blocking large CSV uploads

  - [ ] 3.1 Investigate and identify the limiting layer
    - Reproduce the failure and read the exact error/status (413, empty `$_FILES`, `LIMIT_FILE_SIZE`, connection reset, or hang) to point at a candidate layer.
    - Check the reverse proxy config: Nginx `client_max_body_size` (default ~1MB; at `http`/`server`/`location` scope), Apache `LimitRequestBody`.
    - Check the app-server / language config: PHP `upload_max_filesize` (~2MB default) and `post_max_size` (~8MB default) via `php.ini`/`phpinfo()`; Node framework parser and `multer` limits.
    - Check application-level guards: any explicit size check in the upload handler.
    - Confirm the smallest configured value across the path (`effectiveLimit = MIN(...)`) and note ALL layers below the intended supported maximum.
    - _Bug_Condition: isBugCondition(input) where input.fileBytes > effectiveLimit and effectiveLimit = MIN(proxyBodyLimit, appServerBodyLimit, frameworkParserLimit)_
    - _Requirements: 1.1, 1.2_

  - [ ] 3.2 Raise limits consistently across all layers on the request path and add streaming for large uploads
    - Choose an agreed, sensible ceiling comfortably above the intended CSV size (e.g. 64MB or 100MB per product requirements) — do NOT remove limits entirely.
    - **Nginx**: set `client_max_body_size` to the ceiling at the appropriate scope; raise `client_body_timeout`, `proxy_read_timeout`, `proxy_send_timeout` for the 55MB case; reload Nginx.
    - **Apache**: set `LimitRequestBody` to the ceiling (bytes) in the relevant `<Directory>`/vhost; align `ProxyTimeout` / `mod_reqtimeout` if proxying.
    - **PHP**: raise `upload_max_filesize` to the ceiling; raise `post_max_size` to be **>=** `upload_max_filesize`; review `memory_limit`, `max_execution_time`, `max_input_time` for the 55MB case; restart PHP-FPM / web server.
    - **Node/Express**: ensure the CSV endpoint uses a multipart handler (e.g. `multer`) not JSON body parsing; set `multer` `limits.fileSize` to the ceiling; only raise `body-parser`/`express.json()` `limit` if the payload legitimately flows through it.
    - **Streaming**: where the handler buffers the entire file, switch to streaming (pipe to temp storage or a streaming CSV parser) so memory stays bounded for the 55MB case even after limits are raised.
    - Keep a sane ceiling (intended maximum + headroom) to preserve protection against abusive payloads.
    - _Bug_Condition: isBugCondition(input) from design_
    - _Expected_Behavior: expectedBehavior(result) — upload completes (no 413/abort/hang) and imports data correctly, per Property 1 in design_
    - _Preservation: Preservation Requirements from design — small/normal uploads, import correctness, and non-upload requests unchanged; limits raised to a ceiling, not removed_
    - _Requirements: 2.1, 2.2, 3.1, 3.2_

  - [ ] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Large-but-legitimate CSV uploads complete and import
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 encodes the expected behavior; when it passes, it confirms the expected behavior is satisfied.
    - Run the bug condition exploration test (3.8MB and ~55MB CSVs, plus generated sizes above the old limit) against the fixed pipeline.
    - **EXPECTED OUTCOME**: Test PASSES (confirms the bug is fixed — uploads complete and import correctly with no 413/abort/hang)
    - _Requirements: 2.1, 2.2 (Expected Behavior Property 1 from design)_

  - [ ] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Small/normal uploads and non-upload requests unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run the preservation property tests from step 2 against the fixed pipeline.
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions — small CSV upload/import and non-upload behavior identical to before)
    - Confirm all tests still pass after the fix (no regressions).
    - _Requirements: 3.1, 3.2_

- [ ] 4. Checkpoint - Ensure all tests pass
  - Run the full suite: exploration test (now passing), preservation property tests (still passing), unit tests, property-based tests, and integration tests.
  - **Unit tests**: handler accepts a file at the new ceiling and rejects only clearly abusive sizes above it; size-limit config values read correctly; small-file upload/import paths unchanged.
  - **Property-based tests**: CSVs spanning below-old-limit, between-old-and-new-limit, and above-new-limit — assert acceptance for <= ceiling and correct rejection for > ceiling; assert imported data equals input for all accepted sizes; assert non-upload requests behave identically.
  - **Integration tests**: end-to-end upload of 3.8MB and ~55MB CSVs against the fully-configured pipeline (proxy + app server + app) asserting completion and correct import; multi-layer alignment (no intermediate layer still enforces a smaller limit); streaming/memory test confirming the 55MB upload completes without exhausting memory or hitting timeouts.
  - Ensure all tests pass; ask the user if questions arise.
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2_
````

---

## 7. STRATEGY RULES (trading)

**N/A — none.** This session contains no trading setup, no entry/SL/TP logic, no timeframe, no
session, no symbol. (Explicitly noted because this repo is otherwise full of trading EAs.)

---

## 8. USER INSTRUCTIONS / PREFERENCES OBSERVED

- The user communicates primarily in **Bengali (Banglish / mixed with English tech terms)**.
- The user asked for **short answers** ("short e bol").
- For the export task specifically, the user asked for the reply **in Bengali**, and demanded
  **honesty with no fabrication**.
- A stored "learning" surfaced in this session's environment: *"Do not run slow tests or full
  multi-period validation unless explicitly requested; run fast tests only (`pytest -m 'not slow'`)
  by default."* — **Provenance uncertain**: this likely originates from the user's OTHER sessions,
  not from this CSV session. Recorded here for completeness; treat as a general user preference.

---

## 9. UNFINISHED WORK / NEXT STEPS

1. **Tech stack unknown** — the user never confirmed whether the app is Nginx / Apache / PHP / Node
   / cPanel / other. This is the biggest blocker to a concrete fix.
2. **Exact failing threshold unconfirmed** — 3.8MB fails, some smaller size presumably works;
   the precise cutoff (and therefore the limiting layer) has not been measured.
3. **Spec tasks NOT executed** — `tasks.md` was authored but NEVER run; there is no application
   code/pipeline connected. Next agent should either connect the real repo/app or ask the user for
   the stack, then execute Task 1 -> 4.
4. **Fix ceiling (64MB vs 100MB) not agreed** with the user.
5. The spec files currently exist ONLY in the sandbox at
   `/projects/sandbox/new-project/.kiro/specs/large-csv-upload-fix/` — they are reproduced in this
   export (Section 6) but were not otherwise committed as spec files into this repo.

---

## 10. WARNINGS / CAVEATS FOR A FUTURE AGENT

- **Do not conflate this with the trading work.** A future agent scanning this repo could wrongly
  assume "CSV upload" relates to importing price data for the EA. It does **not**; this was a
  standalone, generic software bug spec with no connection to XAUUSD/MT5.
- **No results were measured.** Every default limit value (1MB/2MB/8MB/100kB) is general framework
  knowledge, not observed from the user's system. Do not present them as facts about the user's app.
- **The `.config.kiro` content in Section 6.1 is semantic, not byte-verified.**
- **"Execute all tasks" was intentionally NOT run** to avoid fabricating test/pipeline results.
  This is a deliberate honesty choice, not an omission.
- The single strongest lead is: **a 3.8MB file failing with a limit error => a body-size limit
  (very likely a proxy `client_max_body_size` default of 1MB or PHP `upload_max_filesize` of 2MB) is
  the culprit.** Start there.

---

*End of export.*
