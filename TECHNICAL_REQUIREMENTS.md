# CTExp — Technical Requirements Document

**Status:** Draft
**Author:** Claude (Cowork), for Matt Hendrickson
**Date:** 2026-09-02
**Repo:** CTExp (Xcode project, bundle id `mhen909.CTExp`)

## 1. Overview

CTExp is a SwiftUI app that fetches a list of photo records from the public JSONPlaceholder API and displays each record's image (thumbnail) and title in a table. The app must show a loading indicator while the fetch is in flight and a clear error state if the network call fails. The codebase must ship with unit tests that achieve high line coverage of the non-UI logic.

This document describes what the app must do and how it should be built. It does not include implementation code; it is the spec an implementer (or Claude, in a follow-up session) works from.

## 2. Goals

- Fetch a list of photo entries from JSONPlaceholder and render each as a row containing a thumbnail image and its title, in a table/list view.
- Represent three UI states explicitly: **loading**, **loaded** (with data), and **error** (network/decoding failure).
- Allow the user to retry the fetch after an error.
- Cover the data layer and view-model layer with unit tests; achieve high line coverage (target: **≥ 80%** line coverage on non-view code, measured via Xcode's code coverage report).

## 3. Non-Goals

- No pagination, search, sort, or filter UI (can be listed as future enhancements).
- No persistence/offline cache is required for v1 (see §9.3 for the recommended follow-up).
- No editing, creating, or deleting of records — JSONPlaceholder is a read-only mock API and writes are not persisted server-side, so CRUD is out of scope.
- No design system / branding work beyond native SwiftUI components.
- No UI/snapshot tests are required for this iteration; only logic-level unit tests are in scope for the coverage target.

## 4. Platform & Tech Stack

Matches the existing Xcode project scaffold already in this repo:

| Aspect | Value |
|---|---|
| Language | Swift 5.0+ (project currently targets Swift 5.0; recommend bumping to Swift 6 language mode if the team is ready, but not required) |
| UI framework | SwiftUI |
| Deployment targets | iOS, iPadOS, macOS (project is a multiplatform target; `TARGETED_DEVICE_FAMILY = "1,2,7"`, `SDKROOT = auto`) |
| Minimum OS version | As currently configured in the project (`IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` = 26.5). Confirm this is intentional before shipping — it is unusually high and may need to be lowered to support real-world devices. |
| Networking | `URLSession` with Swift Concurrency (`async`/`await`), no third-party networking library required |
| JSON decoding | `Codable` / `JSONDecoder` |
| Dependency management | None required for v1; do not add third-party packages unless a concrete need arises |
| Test framework | XCTest (ships with Xcode; use the existing `CTExpTests` target, or the `Swift Testing` framework if the team prefers — either satisfies the coverage requirement) |

## 5. Data Source

**Endpoint:** `GET https://jsonplaceholder.typicode.com/photos`

This returns a JSON array of 5,000 photo records. Each record has the shape:

```json
{
  "albumId": 1,
  "id": 1,
  "title": "accusamus beatae ad facilis cum similique qui sunt",
  "url": "https://via.placeholder.com/600/92c952",
  "thumbnailUrl": "https://via.placeholder.com/150/92c952"
}
```

Requirements on the data layer:

- Use the `thumbnailUrl` field for the image shown in the table row (it's sized for list/thumbnail display; `url` is a larger image and is not needed for this table view).
- Because the endpoint returns 5,000 records with no server-side pagination, the app should cap what it requests/displays for v1. Recommended approach: fetch the full list once (JSONPlaceholder is a static mock, so this is cheap) and render only the **first 100 records** client-side, to keep the table responsive without adding pagination complexity. This limit and its rationale should be documented in code as a named constant (e.g. `maxDisplayedItems`), not a magic number.
- No API key or auth is required; no request headers beyond the default are needed.
- No local write-back to the API — this is read-only.

**Known issue (discovered during implementation, September 2026):** JSONPlaceholder's sample data points `url` and `thumbnailUrl` at `via.placeholder.com`, which has been permanently shut down — every request to it fails, so every row's thumbnail hits `AsyncImage`'s failure state if `thumbnailUrl` is rendered directly. This isn't a defect in the app; it's stale sample data upstream, and the per-row failure fallback (§7.2/§7.4) is the correct, working behavior for it. Decision made: `PhotoRowView` derives a display-only image URL from `Photo.id` via a still-live placeholder service (Lorem Picsum, seeded by id) instead of rendering `thumbnailUrl` directly, so the table shows real thumbnails rather than fallback icons on every row. The model's own `thumbnailUrl`/`url` fields are left untouched and still decode exactly what the API returns (§6) — this substitution lives entirely in the view layer and does not change the data contract or the model tests in §10.

## 6. Data Model

Define a `Codable` struct mirroring the API shape exactly, e.g.:

- `Photo`: `albumId: Int`, `id: Int`, `title: String`, `url: URL`, `thumbnailUrl: URL`

`id` should be used as the `Identifiable` conformance for use in SwiftUI `List`/`ForEach`. Malformed or missing fields in a given record should cause that record to fail decoding gracefully (see §8.3) rather than crash the app.

## 7. Functional Requirements

### 7.1 Fetch on launch
The app fetches the photo list once when the table view first appears. A manual refresh/retry affordance (see §7.4) re-triggers the same fetch.

### 7.2 Table display
Once data has loaded successfully, display each photo as a row containing:
- The thumbnail image, loaded asynchronously from `thumbnailUrl` (e.g. via `AsyncImage`), with a placeholder (system icon or gray box) shown while that individual image loads, and a fallback placeholder if the image itself fails to load (image-load failure is independent of and must not trigger the list-level error state — see §7.4).
- The `title` text, displayed next to or below the thumbnail.

Use SwiftUI's `List` (or `Table` on macOS/iPadOS, where a `Table` gives a more native multi-column look) to render the rows.

### 7.3 Loading state
While the initial fetch is in progress, the table content is replaced with a loading indicator (e.g. `ProgressView`) and no partial/empty table is shown. The loading state must be visually distinct from the empty/error states.

### 7.4 Error state
If the network call fails (no connectivity, non-2xx response, timeout, or JSON decoding failure), the table content is replaced with:
- A short, human-readable error message (do not surface raw `Error` descriptions or stack traces to the user).
- A **Retry** button that re-runs the fetch and transitions the view back to the loading state.

A failure loading one row's thumbnail image must **not** put the whole screen into the error state — only a failure of the top-level list fetch does that.

### 7.5 Explicit state representation
The view model must represent state as a single, explicit enum (not a combination of independent booleans/optionals), e.g.:

```swift
enum ViewState {
    case loading
    case loaded([Photo])
    case error(message: String)
}
```

This is a testability requirement as much as a UI one: an explicit state enum is what makes the view model's behavior unit-testable without standing up the UI (see §10).

## 8. Architecture

### 8.1 Pattern
MVVM:
- **Model**: `Photo` (Codable struct, §6).
- **Service**: a `PhotoService` (protocol + concrete implementation) responsible only for the network call and decoding. The protocol boundary (e.g. `PhotoServiceProtocol`) exists specifically so it can be swapped for a fake/mock in tests.
- **ViewModel**: an `ObservableObject` (e.g. `PhotoListViewModel`) owning the `ViewState` (§7.5), exposing an async `load()` method, and depending on `PhotoServiceProtocol` via constructor injection (not a singleton) so tests can inject a fake.
- **View**: a SwiftUI view that reads the view model's published state and renders one of loading / table / error accordingly. Views contain no networking or decoding logic.

### 8.2 Networking
Use `URLSession.shared.data(from:)` (or a testable wrapper around it) with Swift Concurrency. Do not use completion-handler-based APIs for new code.

### 8.3 Error handling
Define an app-level error enum (e.g. `PhotoServiceError`) distinguishing at least:
- `network` (transport-level failure, e.g. no connectivity, timeout)
- `invalidResponse` (non-2xx HTTP status)
- `decoding` (payload didn't match the expected shape)

The view model maps any of these to the single user-facing error message required in §7.4 — the distinction matters for testing (§10) and logging, not for different UI treatments, unless product wants differentiated copy later.

## 9. Non-Functional Requirements

### 9.1 Performance
The table must remain scrollable at 60fps with up to the capped item count (§5). `AsyncImage` (or an equivalent lazy image loader) must be used so all 100 thumbnails are not fetched eagerly at once outside of what's visible — SwiftUI's `AsyncImage` inside a `List`/`Table` already provides this via view lifecycle, so no custom lazy-loading logic is required unless profiling shows otherwise.

### 9.2 Accessibility
Each row's image must have an appropriate accessibility label (falling back to the title if no better description exists) so VoiceOver users get the title read out; the loading and error states must also be legible to VoiceOver (e.g. the `ProgressView` and error message are not accessibility-hidden).

### 9.3 Caching (future enhancement, not required for v1)
Flagging here so it's a conscious decision rather than an oversight: this spec does not require persisting fetched data or caching images to disk. If the app needs to work offline or reduce repeat network/image traffic later, add `URLCache`-based image caching and/or a local persistence layer (e.g. SwiftData) as a follow-up.

### 9.4 Logging
Failures should be logged (e.g. via `os.Logger`) with enough detail to debug (status code, underlying error), without putting that detail in front of the user (§7.4).

## 10. Testing Requirements

### 10.1 Scope and target
Unit tests must cover the **Model** and **Service** and **ViewModel** layers. Target: **≥ 80% line coverage** on these layers combined, measured via Xcode's built-in code coverage (enable "Gather coverage" for the test scheme). SwiftUI view code itself is exempt from the line-coverage target, since UI layout isn't meaningfully unit-testable — but it must contain no logic that isn't already covered by testing the view model.

### 10.2 What to test

**Model (`Photo`) decoding**
- A well-formed JSON array decodes into the expected `[Photo]`.
- A single well-formed object decodes into the expected fields (including that `url`/`thumbnailUrl` decode as `URL`, not `String`).
- Malformed JSON (missing required field, wrong type) throws/fails decoding rather than silently producing garbage data.

**Service (`PhotoService`)**
- Given a mocked successful HTTP response with valid JSON, the service returns the decoded `[Photo]`.
- Given a mocked non-2xx HTTP response, the service throws `PhotoServiceError.invalidResponse`.
- Given a mocked transport-level failure (e.g. `URLError`), the service throws `PhotoServiceError.network`.
- Given a mocked response with malformed JSON, the service throws `PhotoServiceError.decoding`.
- Mock the network using `URLProtocol` stubbing (a custom `URLProtocol` subclass registered on a test `URLSessionConfiguration`) so tests make no real network calls. Do not hit the live JSONPlaceholder API from unit tests — it makes CI flaky and slow.

**ViewModel (`PhotoListViewModel`)**
- Initial state is `.loading` (or an explicit `.idle` prior to the first `load()`, if that's added).
- After `load()` succeeds against a fake service returning sample photos, state becomes `.loaded([...])` with the expected items (including that the item count is capped per §5, if the cap is enforced in the view model rather than the service).
- After `load()` fails against a fake service throwing each `PhotoServiceError` case, state becomes `.error(message:)` with a non-empty, user-appropriate message (not the raw error description).
- Calling `load()` again after an error (simulating the Retry button) transitions back through `.loading` and can succeed if the fake service is reconfigured to succeed — i.e. retry actually re-invokes the fetch rather than replaying stale state.
- Inject the fake service via the protocol from §8.1 (`PhotoServiceProtocol`) — no test should need to touch `URLSession` directly to test the view model.

### 10.3 Test data
Use small, hand-written fixture JSON (inline strings or a bundled test-only `.json` fixture file) rather than depending on the live API's actual current payload, so tests are deterministic and independent of JSONPlaceholder's uptime or content changes.

## 11. Acceptance Criteria

- [ ] Launching the app shows a loading indicator, then either the populated table or an error view — never a blank/empty screen with no state indicator.
- [ ] The table shows a thumbnail image and title for each fetched photo, up to the documented cap.
- [ ] Disconnecting the network (or otherwise forcing a failure) results in the error view with a Retry button, and tapping Retry re-attempts the fetch.
- [ ] A single thumbnail image failing to load does not put the app in the error state.
- [ ] `xcodebuild test` (or Xcode's Test navigator) runs the full unit test suite with zero failures.
- [ ] Code coverage report shows ≥ 80% line coverage on the Model + Service + ViewModel code.
- [ ] No production code path makes network calls during unit test execution.

## 12. Open Questions / Assumptions

These were resolved with reasonable defaults to keep this spec actionable; flag any of them if a different answer is wanted before implementation starts:

1. **Display cap of 100 items** (§5) — assumed, since the API returns 5,000 records with no pagination and no cap was specified. Alternative: add pull-to-refresh/pagination instead of a hard cap.
2. **Deployment target of 26.5** — this is what's currently in the Xcode project (likely a placeholder from project creation); confirm the real minimum OS version to support before release, since 26.5 will exclude the vast majority of real devices if left as-is.
3. **No offline caching for v1** (§9.3) — assumed acceptable since JSONPlaceholder is a demo/mock API and this reads like a technical exercise rather than a production app with offline requirements.
4. **Coverage target of 80%** — a reasonable "high coverage" bar for logic-heavy, UI-light code; adjust up or down if the team has a different house standard.
