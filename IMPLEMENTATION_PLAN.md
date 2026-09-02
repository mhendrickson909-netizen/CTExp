# CTExp — Implementation Plan

**Status:** Draft
**Author:** Claude (Cowork), for Matt Hendrickson
**Date:** 2026-09-02
**Companion to:** `TECHNICAL_REQUIREMENTS.md` (this plan implements that spec — section references below point to it)

## How to use this document

Each step lists the files it touches, what to build, and a way to verify it before moving on. Steps are ordered so the app is buildable and testable after every step — don't skip ahead to the views before the layers underneath compile and pass their own tests. Steps 1–2 set up structure and the testing strategy; steps 3–8 are the app; steps 9–13 are the test suite (built directly against the seams defined in Step 2); step 14 is final verification against the requirements doc's acceptance criteria.

**Progress tracking:** when a step is fully done — its code written and its "Verify" line actually confirmed, not just started — strike through that step's heading text, e.g. `## ~~Step 3 — Data model (§6 of requirements)~~`. Leave the step's body (the bullets and Verify line) unstruck so the record of what was built stays readable; the strikethrough on the title alone is enough to scan the document and see progress at a glance. Don't cross out a step that's partially done — finish it, verify it, then cross it out. As of this revision, no steps are yet complete.

## Step 1 — Project structure

Add a `Sources` grouping (or just organize by group in Xcode) inside the `CTExp` target for the new code, and confirm the `CTExpTests` test target exists and is wired to the app target (Xcode creates this by default; verify under the scheme's Test action).

Create these groups/folders:
- `CTExp/CTExp/Models/`
- `CTExp/CTExp/Services/`
- `CTExp/CTExp/ViewModels/`
- `CTExp/CTExp/Views/`
- `CTExp/CTExpTests/Support/` (test doubles and fixtures live here, separate from the test files that use them)

**Verify:** Project still builds and runs (⌘R), showing the existing "Hello, world!" placeholder.

## Step 2 — Testability strategy: protocols and test doubles

Before writing any of the three layers, fix the seams they'll be tested through. This is a design decision, not a coding step — the table below is what Steps 3–13 build against, so every layer that has an external dependency gets a protocol in front of it and a fake/mock behind that protocol in the test target. Nothing in `CTExpTests` should reach past a protocol boundary into a concrete `URLSession` call or a concrete `PhotoService` call.

| Layer | External dependency | Protocol (production code) | Production conformer | Test double (test code) | Created in |
|---|---|---|---|---|---|
| **Model** (`Photo`) | None — it's a pure `Codable` value type | *None needed.* A model with no injected collaborator has nothing to mock; it's tested directly against fixture JSON, not through a protocol seam. | n/a | n/a (fixtures only) | Step 4, Step 9 |
| **Service** (`PhotoService`) | Network transport (`URLSession`) | `NetworkSession` — a narrow protocol exposing only the one method the service needs | `URLSession` (conforms via an `extension`) | `MockNetworkSession` | Protocol: Step 5. Conformance: Step 5. Mock: Step 10 |
| **ViewModel** (`PhotoListViewModel`) | Data fetching (`PhotoService`) | `PhotoServiceProtocol` — the service's own public interface | `PhotoService` | `MockPhotoService` | Protocol: Step 6. Mock: Step 10 |

Two consequences of this table that matter for the steps below:

- **Every dependency crossing a layer boundary is injected through its protocol via the initializer**, never reached for as a singleton (`URLSession.shared`, a shared `PhotoService()`) from inside `PhotoService` or `PhotoListViewModel`. A default-argument initializer (e.g. `init(session: NetworkSession = URLSession.shared)`) keeps call sites in the app itself simple while still leaving the seam open for tests.
- **All test doubles live in `CTExpTests/Support/`**, not inline in the test files that use them — `MockNetworkSession` is reused across every `PhotoServiceTests` case, and `MockPhotoService` is reused across every `PhotoListViewModelTests` case, so each is written once (Step 10) and configured per-test.

**Verify:** No code yet — this step is the contract the rest of the plan implements. Re-check it after Step 6: at that point every layer with an external dependency should have exactly one protocol in front of it, matching this table.

## Step 3 — Data model (§6 of requirements)

Create `Models/Photo.swift`:
- `struct Photo: Codable, Identifiable, Equatable` with `id: Int`, `albumId: Int`, `title: String`, `url: URL`, `thumbnailUrl: URL`.
- Field names match the API's JSON keys exactly (`albumId`, `id`, `title`, `url`, `thumbnailUrl`), so no custom `CodingKeys` should be needed — but add them explicitly anyway for clarity and to guard against the API changing casing.
- Per the Step 2 table: no protocol or mock for this layer. It's tested directly against fixture JSON in Step 9.

**Verify:** Compiles. No runtime check possible yet — covered by tests in Step 9.

## Step 4 — Network error type (§8.3)

Create `Services/PhotoServiceError.swift`:
- `enum PhotoServiceError: Error, Equatable { case network(underlying: String), invalidResponse(statusCode: Int), decoding }`
  (Storing `String`/`Int` rather than the raw `Error`/`URLResponse` keeps the enum `Equatable`, which makes test assertions much simpler.)
- Add a computed `var userFacingMessage: String` on the enum (or on the view model — pick one place) that returns the same short, non-technical message for all cases per §7.4, e.g. "Couldn't load photos. Check your connection and try again." Keep the underlying detail (§9.4) out of this string; that's what the `Logger` call in Step 5 is for.

**Verify:** Compiles.

## Step 5 — Network session protocol and photo service (§5, §8.2, §8.3)

This step builds the Service layer's testability seam from the Step 2 table, then the service itself.

Create `Services/NetworkSession.swift`:
```swift
protocol NetworkSession {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}
```
`URLSession` already implements a method with this exact signature, so the `extension` conformance is free — no wrapping logic needed. This is the protocol `MockNetworkSession` (Step 10) will implement in tests, so `PhotoService` never has to talk to the real network to be tested.

Create `Services/PhotoServiceProtocol.swift`:
```swift
protocol PhotoServiceProtocol {
    func fetchPhotos() async throws -> [Photo]
}
```
This is the Service layer's own public interface — the seam the ViewModel layer depends on (Step 6), separate from the `NetworkSession` seam above it depends on internally.

Create `Services/PhotoService.swift` implementing `PhotoServiceProtocol`:
- `init(session: NetworkSession = URLSession.shared)` — constructor-injects the protocol, not the concrete type, defaulting to the real `URLSession.shared` so app call sites don't pass anything.
- Endpoint: `https://jsonplaceholder.typicode.com/photos` (define the URL as a `static let`, not inline in the function body).
- `let (data, response) = try await session.data(from: url)`, wrapped so a thrown `URLError`/transport error is caught and rethrown as `PhotoServiceError.network`.
- Check `response` is an `HTTPURLResponse` with a 2xx status code; otherwise throw `PhotoServiceError.invalidResponse(statusCode:)`.
- Decode with `JSONDecoder().decode([Photo].self, from: data)`; catch decode failures and rethrow as `PhotoServiceError.decoding`.
- Log failures via `os.Logger` before rethrowing (§9.4) — one line, include the underlying error/status code.

**Verify:** Temporarily call `PhotoService().fetchPhotos()` from a throwaway `Task` in `CTExpApp.init` (or a SwiftUI `.task` on the placeholder view) and print the count/first title to the console to confirm it round-trips against the real API. Remove this scratch call once confirmed — it's not part of the app.

## Step 6 — View state and view model (§7.5, §8.1)

Create `ViewModels/PhotoListViewState.swift`:
```swift
enum PhotoListViewState: Equatable {
    case loading
    case loaded([Photo])
    case error(message: String)
}
```

Create `ViewModels/PhotoListViewModel.swift`:
- `@MainActor final class PhotoListViewModel: ObservableObject`
- `@Published private(set) var state: PhotoListViewState = .loading`
- `init(service: PhotoServiceProtocol = PhotoService())` — constructor-injects the protocol from Step 5, not the concrete `PhotoService`, so `MockPhotoService` (Step 10) can stand in during tests. This is the ViewModel layer's seam from the Step 2 table.
- `static let maxDisplayedItems = 100` (§5) — a named constant, not a magic number, as required.
- `func load() async`: sets `state = .loading`, calls `service.fetchPhotos()`, on success sets `state = .loaded(Array(photos.prefix(Self.maxDisplayedItems)))`, on failure catches the thrown `PhotoServiceError` and sets `state = .error(message: <mapped message>)`.

**Verify:** Compiles. Behavior is covered by Step 12's tests, not manual testing at this stage. At this point, cross-check against the Step 2 table: `PhotoService` depends on `NetworkSession` (protocol), `PhotoListViewModel` depends on `PhotoServiceProtocol` (protocol) — no concrete type is reached for directly across either boundary.

## Step 7 — Views (§7.1–§7.4)

Create `Views/PhotoRowView.swift`:
- Takes a `Photo`, renders `AsyncImage(url: photo.thumbnailUrl)` with a placeholder (e.g. `ProgressView()` or a system-icon `Image` while loading, and a broken-image system icon on failure — `AsyncImage`'s phase-based initializer gives you all three states) next to `Text(photo.title)`.
- Set `.accessibilityLabel(photo.title)` on the row per §9.2.

Create `Views/PhotoListView.swift`:
- `@StateObject private var viewModel = PhotoListViewModel()`
- `switch viewModel.state`:
  - `.loading` → centered `ProgressView("Loading photos…")`
  - `.loaded(let photos)` → `List(photos) { PhotoRowView(photo: $0) }` (use SwiftUI `Table` instead of `List` on macOS/iPadOS if you want the more explicit table look called for in §7.2 — `List` is the safe default that satisfies the requirement on every platform in the target list; upgrade to `Table` only if you want the platform-specific polish, it's not required).
  - `.error(let message)` → centered `Text(message)` plus a `Button("Retry") { Task { await viewModel.load() } }`
- `.task { await viewModel.load() }` on the top-level container so the fetch kicks off on first appearance (§7.1).

Update `ContentView.swift` to embed `PhotoListView()` (wrapped in a `NavigationStack` if you want a title bar) instead of the placeholder "Hello, world!" content, and delete the placeholder globe image/text.

Views are intentionally left out of the Step 2 testability table — they hold no logic to mock around (§8.1), only rendering of state the view model already owns, so they're exercised manually here rather than via a protocol seam.

**Verify:** Run the app (⌘R). Confirm: loading spinner appears briefly, then the table populates with thumbnails and titles. Turn on Xcode's Network Link Conditioner (or briefly disable network) and re-run to confirm the error view and Retry button appear and work.

## Step 8 — Cleanup pass

- Remove the scratch `Task`/print statements from Step 5 if not already removed.
- Confirm no view contains networking/decoding logic directly (§8.1) — it should all route through the view model.
- Confirm nothing in `CTExp/` (the app target) imports or references anything under `CTExpTests/Support/` — the dependency only goes the other way.
- Run SwiftLint or Xcode's built-in warnings pass if the project has one configured; otherwise just clear any yellow build warnings.

## Step 9 — Model decoding tests (§10.2)

Create `CTExpTests/PhotoTests.swift`:
- Inline a small fixture JSON string (2–3 records) matching the real API shape.
- Test: decoding that fixture into `[Photo]` produces the expected count and field values, and that `url`/`thumbnailUrl` decode as `URL`, not `String`.
- Test: a fixture missing a required field (e.g. no `title`) throws when decoded — assert with `XCTAssertThrowsError` (or `#expect(throws:)` if using Swift Testing).

No protocol or mock is needed here, per Step 2 — these tests exercise `Photo`'s `Decodable` conformance directly against inline JSON strings.

## Step 10 — Test doubles (`MockNetworkSession`, `MockPhotoService`)

This is the step that builds the mock side of every protocol seam defined in Step 2. Build both here, before writing the tests that consume them in Steps 11–12, so they're shared, reusable, and not duplicated per test file.

Create `CTExpTests/Support/MockNetworkSession.swift`, conforming to `NetworkSession` (Step 5):
- Settable properties the test configures beforehand, e.g. `var result: Result<(Data, URLResponse), Error> = .failure(...)` (or separate `dataToReturn`/`responseToReturn`/`errorToThrow` properties — either shape works).
- `func data(from url: URL) async throws -> (Data, URLResponse)` returns/throws whatever the test configured, ignoring the actual `url` (or optionally recording it, if a test wants to assert the request went to the right endpoint).
- Consumed by `PhotoServiceTests` (Step 11) to drive `PhotoService` through success, HTTP-error, transport-error, and decode-error paths without any real networking.

Create `CTExpTests/Support/MockPhotoService.swift`, conforming to `PhotoServiceProtocol` (Step 5):
- `var result: Result<[Photo], PhotoServiceError> = .success([])`, settable per test.
- `func fetchPhotos() async throws -> [Photo]` returns `result`'s value or throws its error.
- Consumed by `PhotoListViewModelTests` (Step 12) to drive `PhotoListViewModel` through loading/loaded/error/retry without touching `PhotoService` or the network at all.

Both mocks are plain, hand-written structs/classes — no mocking framework or code generation is required for a protocol this small.

**Verify:** Both mocks compile and conform to their protocols (a conformance failure here means the protocol in Step 5 wasn't narrow enough, or the mock is missing a method — fix the protocol/mock, not the shape of the test that hasn't been written yet).

## Step 11 — Service tests (§10.2)

Create `CTExpTests/PhotoServiceTests.swift`, constructing `PhotoService(session: MockNetworkSession(...))` for each case:
- Success case: mock returns a 200 response + valid JSON data → `fetchPhotos()` returns the expected `[Photo]`.
- HTTP error case: mock returns a 500 (or 404) response → `fetchPhotos()` throws `PhotoServiceError.invalidResponse`.
- Transport error case: mock's `data(from:)` throws a `URLError` → `fetchPhotos()` throws `PhotoServiceError.network`.
- Decoding error case: mock returns 200 + malformed/truncated JSON data → `fetchPhotos()` throws `PhotoServiceError.decoding`.

Assert on the specific `PhotoServiceError` case in each test, not just "an error was thrown." No real network call should occur in this file — that's what `MockNetworkSession` (Step 10) is for.

## Step 12 — View model tests (§10.2)

Create `CTExpTests/PhotoListViewModelTests.swift`, constructing `PhotoListViewModel(service: MockPhotoService(...))` for each case:
- Test: fresh view model's `state` is `.loading` before `load()` completes.
- Test: `load()` against a mock returning N sample photos (where N is both under and over `maxDisplayedItems`) results in `.loaded` with the correct, capped array.
- Test: `load()` against a mock configured to throw each `PhotoServiceError` case results in `.error(message:)` with a non-empty message.
- Test: calling `load()` again after reconfiguring the mock from failure to success (simulating Retry) transitions `.error` → `.loading` → `.loaded` correctly, proving retry re-invokes the fetch rather than reusing stale state.

No `PhotoService` or `URLSession` should be reachable from this file — that's what `MockPhotoService` (Step 10) is for, and it's the point of injecting `PhotoServiceProtocol` rather than the concrete service in Step 6.

## Step 13 — Test-double coverage check

Before moving to overall coverage, specifically confirm the three-layer testability goal is actually met:
- `Photo` (Model): tested via fixtures only, no mock — Step 9.
- `PhotoService` (Service): tested via `MockNetworkSession` — Step 11.
- `PhotoListViewModel` (ViewModel): tested via `MockPhotoService` — Step 12.

Grep the test target for `URLSession` and confirm the only match is inside `MockNetworkSession`'s conformance/plumbing — if `PhotoServiceTests` or `PhotoListViewModelTests` reference `URLSession` or `PhotoService` directly, a layer boundary was skipped and needs to route through its mock instead.

## Step 14 — Coverage and acceptance pass

- In Xcode: Product → Scheme → Edit Scheme → Test → check "Gather coverage for" the `CTExp` target (or `all targets`). Run all tests (⌘U).
- Open the coverage report (Report navigator → Coverage) and confirm `Photo.swift`, `PhotoService.swift`, and `PhotoListViewModel.swift` are each at or above 80% line coverage (§10.1). If any file is below, add the missing test case for whatever branch is uncovered rather than lowering the bar.
- Walk the acceptance criteria checklist in `TECHNICAL_REQUIREMENTS.md` §11 top to bottom and confirm each item against the running app and the test results.
- Run `xcodebuild test -scheme CTExp` from the command line (or the current scheme name) to confirm the suite is green outside of Xcode's UI too, e.g. for CI parity.

## Suggested commit breakdown

If committing incrementally rather than as one large commit, this maps cleanly to the steps above: (1) model, (2) network session protocol + service + error type, (3) view model, (4) views + ContentView wiring, (5) test doubles (`MockNetworkSession`, `MockPhotoService`), (6) model/service/view-model tests. Keeping the test-double commit separate from both the feature commits and the test commits makes it easy to see the testability seams as their own reviewable unit.
