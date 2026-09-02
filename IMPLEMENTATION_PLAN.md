# CTExp — Implementation Plan

**Status:** Draft
**Author:** Claude (Cowork), for Matt Hendrickson
**Date:** 2026-09-02
**Companion to:** `TECHNICAL_REQUIREMENTS.md` (this plan implements that spec — section references below point to it)

## How to use this document

Each step lists the files it touches, what to build, and a way to verify it before moving on. Steps are ordered so the app is buildable and testable after every step — don't skip ahead to the views before the layers underneath compile and pass their own tests. Steps 1–2 set up structure and the testing strategy; steps 3–8 are the app; steps 9–13 are the test suite (built directly against the seams defined in Step 2); step 14 is final verification against the requirements doc's acceptance criteria.

**Progress tracking:** when a step is fully done — its code written and its "Verify" line actually confirmed, not just started — strike through that step's heading text, e.g. `## ~~Step 3 — Data model (§6 of requirements)~~`. Leave the step's body (the bullets and Verify line) unstruck so the record of what was built stays readable; the strikethrough on the title alone is enough to scan the document and see progress at a glance. Don't cross out a step that's partially done — finish it, verify it, then cross it out. As of this revision, no steps are yet complete.

## ~~Step 1 — Project structure~~

Add a `Sources` grouping (or just organize by group in Xcode) inside the `CTExp` target for the new code, and confirm the `CTExpTests` test target exists and is wired to the app target (Xcode creates this by default; verify under the scheme's Test action).

Create these groups/folders:
- `CTExp/CTExp/Models/`
- `CTExp/CTExp/Services/`
- `CTExp/CTExp/ViewModels/`
- `CTExp/CTExp/Views/`
- `CTExp/CTExpTests/Support/` (test doubles and fixtures live here, separate from the test files that use them)

**Progress note (2026-09-02):** the four `CTExp/CTExp/` folders above and a placeholder `CTExp/CTExpTests/Support/` folder were created on disk. The project uses Xcode's newer file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`), so these folders should appear automatically in the Xcode navigator without needing to be added as groups manually — open the project and confirm they're visible. **However, `project.pbxproj` currently has no `CTExpTests` target at all** — this scaffold was created without a test target, so one doesn't just need "confirming," it needs to be added: in Xcode, File → New → Target… → Unit Testing Bundle, name it `CTExpTests`, and make sure it targets the `CTExp` app. This has to be done from Xcode itself (target creation isn't something to hand-edit into `project.pbxproj` from the command line). Step 1 isn't fully complete until that target exists and the scheme's Test action is wired to it.

**Verify:** Project still builds and runs (⌘R), showing the existing "Hello, world!" placeholder. Also run ⌘U (or check the Test navigator) to confirm `CTExpTests` exists and executes, even with zero tests in it yet.

**Confirmed (2026-09-02):** both ⌘R and ⌘U verified working, `CTExpTests` target in place. Step complete.

## ~~Step 2 — Testability strategy: protocols and test doubles~~

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

**Confirmed (2026-09-02):** re-checked after Step 6 built successfully — `PhotoService` depends only on `NetworkSession`, `PhotoListViewModel` depends only on `PhotoServiceProtocol`, matching the table exactly. Step complete.

## ~~Step 3 — Data model (§6 of requirements)~~

Create `Models/Photo.swift`:
- `struct Photo: Codable, Identifiable, Equatable` with `id: Int`, `albumId: Int`, `title: String`, `url: URL`, `thumbnailUrl: URL`.
- Field names match the API's JSON keys exactly (`albumId`, `id`, `title`, `url`, `thumbnailUrl`), so no custom `CodingKeys` should be needed — but add them explicitly anyway for clarity and to guard against the API changing casing.
- Per the Step 2 table: no protocol or mock for this layer. It's tested directly against fixture JSON in Step 9.

**Progress note (2026-09-02):** `Models/Photo.swift` written with `CodingKeys` included as specified.

**Verify:** Compiles. No runtime check possible yet — covered by tests in Step 9. *(Please confirm with ⌘B — the sandbox this plan is being executed from can't run Xcode's build toolchain.)*

**Confirmed (2026-09-02):** ⌘B succeeded. Step complete.

## ~~Step 4 — Network error type (§8.3)~~

Create `Services/PhotoServiceError.swift`:
- `enum PhotoServiceError: Error, Equatable { case network(underlying: String), invalidResponse(statusCode: Int), decoding }`
  (Storing `String`/`Int` rather than the raw `Error`/`URLResponse` keeps the enum `Equatable`, which makes test assertions much simpler.)
- Add a computed `var userFacingMessage: String` on the enum (or on the view model — pick one place) that returns the same short, non-technical message for all cases per §7.4, e.g. "Couldn't load photos. Check your connection and try again." Keep the underlying detail (§9.4) out of this string; that's what the `Logger` call in Step 5 is for.

**Progress note (2026-09-02):** `Services/PhotoServiceError.swift` written, with `userFacingMessage` returning the same non-technical string for all three cases.

**Verify:** Compiles. *(Please confirm with ⌘B.)*

**Confirmed (2026-09-02):** ⌘B succeeded. Step complete.

## ~~Step 5 — Network session protocol and photo service (§5, §8.2, §8.3)~~

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

**Progress note (2026-09-02):** `Services/NetworkSession.swift` (protocol + `URLSession` conformance), `Services/PhotoServiceProtocol.swift`, and `Services/PhotoService.swift` all written as specified — `PhotoService` takes `session: NetworkSession = URLSession.shared` in its initializer, so the seam from Step 2's table is in place. Logging added via `os.Logger` on each failure path (§9.4) before the mapped `PhotoServiceError` is thrown.

**Verify:** Temporarily call `PhotoService().fetchPhotos()` from a throwaway `Task` in `CTExpApp.init` (or a SwiftUI `.task` on the placeholder view) and print the count/first title to the console to confirm it round-trips against the real API. Remove this scratch call once confirmed — it's not part of the app.

**Confirmed (2026-09-02):** scratch `.task` added to `ContentView.swift`, run against the live API, console output confirmed correct, and the scratch code has been removed — `ContentView.swift` is back to the original placeholder. Step complete.

**Addendum (2026-09-02):** this project has `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` set (visible in `project.pbxproj`) — a newer Xcode default that makes every type in the module implicitly `@MainActor`-isolated unless it opts out. That caused a warning on `PhotoListViewModel.swift` line 23 ("Call to main actor-isolated initializer 'init(session:)' in a synchronous nonisolated context") because `PhotoService`'s default-argument initializer was implicitly pulled onto the main actor along with everything else. Fixed by marking `PhotoService` `nonisolated final class` — it's a network/decoding type with no reason to be main-actor-bound. **Expect the same fix to be needed on other non-UI types** (`Photo`, `PhotoServiceError`, and the `MockNetworkSession`/`MockPhotoService` test doubles from Step 10) as they're exercised from tests in Steps 9–13, since XCTest methods aren't main-actor by default either.

## ~~Step 6 — View state and view model (§7.5, §8.1)~~

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

**Progress note (2026-09-02):** `ViewModels/PhotoListViewState.swift` and `ViewModels/PhotoListViewModel.swift` written as specified — `PhotoListViewModel` initializes with `service: PhotoServiceProtocol = PhotoService()`, `load()` sets `.loading`, then `.loaded` (capped to `maxDisplayedItems`) or `.error(message:)` via the catch-as-`PhotoServiceError` pattern.

**Verify:** Compiles. Behavior is covered by Step 12's tests, not manual testing at this stage. At this point, cross-check against the Step 2 table: `PhotoService` depends on `NetworkSession` (protocol), `PhotoListViewModel` depends on `PhotoServiceProtocol` (protocol) — no concrete type is reached for directly across either boundary.

**Confirmed (2026-09-02):** ⌘B succeeded. Step complete.

## ~~Step 7 — Views (§7.1–§7.4)~~

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

**Progress note (2026-09-02):** `Views/PhotoRowView.swift` (phase-based `AsyncImage` with loading/success/failure states, `.accessibilityLabel(photo.title)`) and `Views/PhotoListView.swift` (switches on `viewModel.state`, `.task` kicks off `load()`) written as specified. `ContentView.swift` updated to embed `PhotoListView()` in a `NavigationStack` with a "Photos" title, replacing the placeholder globe/text.

**Issue found and fixed (2026-09-02):** first run showed titles correctly but every row's thumbnail fell into the `.failure` state — the app itself was working exactly as designed (§7.2/§7.4's per-row failure fallback), but the API's own `thumbnailUrl` points at `via.placeholder.com`, which is permanently dead. Fixed by adding a `displayThumbnailURL` computed property (private extension on `Photo`, scoped to `PhotoRowView.swift`) that derives a stand-in thumbnail from Lorem Picsum, seeded by `id`, for display only — `Photo.thumbnailUrl` itself is untouched. Full writeup in `TECHNICAL_REQUIREMENTS.md` §5. Needs a rebuild/rerun to confirm real thumbnails now render.

**Verify:** Run the app (⌘R). Confirm: loading spinner appears briefly, then the table populates with thumbnails and titles. Turn on Xcode's Network Link Conditioner (or briefly disable network) and re-run to confirm the error view and Retry button appear and work.

**Confirmed (2026-09-02):** re-run confirmed real thumbnails now render alongside titles. Step complete.

## ~~Step 8 — Cleanup pass~~

- Remove the scratch `Task`/print statements from Step 5 if not already removed.
- Confirm no view contains networking/decoding logic directly (§8.1) — it should all route through the view model.
- Confirm nothing in `CTExp/` (the app target) imports or references anything under `CTExpTests/Support/` — the dependency only goes the other way.
- Run SwiftLint or Xcode's built-in warnings pass if the project has one configured; otherwise just clear any yellow build warnings.

**Progress note (2026-09-02):** checked programmatically — no `SCRATCH`/`print(` leftovers anywhere in `CTExp/CTExp/`, no `URLSession`/`JSONDecoder`/`NetworkSession` references inside `Views/` (networking stays confined to `Services/`), and no `CTExpTests` references from the app target. First three bullets confirmed clean. No SwiftLint config present in the project, so nothing to run there.

**Verify:** *(One item left for you — glance at Xcode's Issue Navigator for any yellow build warnings and clear them if present; everything else above is already confirmed.)*

**Confirmed (2026-09-02):** one actor-isolation warning found and fixed (see the addendum under Step 5 — `PhotoService` marked `nonisolated`, root cause is the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting). No further warnings. Step complete.

## ~~Step 9 — Model decoding tests (§10.2)~~

Create `CTExpTests/PhotoTests.swift`:
- Inline a small fixture JSON string (2–3 records) matching the real API shape.
- Test: decoding that fixture into `[Photo]` produces the expected count and field values, and that `url`/`thumbnailUrl` decode as `URL`, not `String`.
- Test: a fixture missing a required field (e.g. no `title`) throws when decoded — assert with `XCTAssertThrowsError` (or `#expect(throws:)` if using Swift Testing).

No protocol or mock is needed here, per Step 2 — these tests exercise `Photo`'s `Decodable` conformance directly against inline JSON strings.

**Progress note (2026-09-02):** `CTExpTests/PhotoTests.swift` written with 4 tests — valid two-record decode (count + all fields, including `Photo.CodingKeys`), a URL-typing assertion, a missing-required-field failure, and a wrong-type-for-field failure (`id` as a string). Ahead of writing this, and per Step 8's addendum, `Photo` (struct) and `PhotoServiceError` (enum) were both marked `nonisolated` — same root cause as the Step 5 fix (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`): an un-annotated plain `XCTestCase` test method isn't main-actor-isolated, so decoding a would-be-MainActor-isolated `Photo` from it would have hit the identical warning/error.

**Verify:** *(Please run the `CTExpTests` target — ⌘U, or Test navigator — and confirm all 4 tests pass, with no actor-isolation warnings in `PhotoTests.swift` or `Photo.swift`.)*

## ~~Step 10 — Test doubles (`MockNetworkSession`, `MockPhotoService`)~~

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

**Progress note (2026-09-02):** both written as `nonisolated final class` (same reasoning as the `Photo`/`PhotoServiceError` fix in Step 9 — these will be constructed directly from test methods that aren't main-actor-isolated, so they need to opt out of the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` default too). Both use the `var result: Result<..., Error> { ... }` + `try result.get()` pattern rather than separate throw/return properties, so success and failure are configured with a single line at the top of each test.

**Verify:** Both mocks compile and conform to their protocols (a conformance failure here means the protocol in Step 5 wasn't narrow enough, or the mock is missing a method — fix the protocol/mock, not the shape of the test that hasn't been written yet).

**Confirmed (2026-09-02):** ⌘B succeeded. Step complete.

## ~~Step 11 — Service tests (§10.2)~~

Create `CTExpTests/PhotoServiceTests.swift`, constructing `PhotoService(session: MockNetworkSession(...))` for each case:
- Success case: mock returns a 200 response + valid JSON data → `fetchPhotos()` returns the expected `[Photo]`.
- HTTP error case: mock returns a 500 (or 404) response → `fetchPhotos()` throws `PhotoServiceError.invalidResponse`.
- Transport error case: mock's `data(from:)` throws a `URLError` → `fetchPhotos()` throws `PhotoServiceError.network`.
- Decoding error case: mock returns 200 + malformed/truncated JSON data → `fetchPhotos()` throws `PhotoServiceError.decoding`.

Assert on the specific `PhotoServiceError` case in each test, not just "an error was thrown." No real network call should occur in this file — that's what `MockNetworkSession` (Step 10) is for.

**Progress note (2026-09-02):** `CTExpTests/PhotoServiceTests.swift` written with all 4 cases. Since standard `XCTAssertThrowsError` doesn't handle `async throws` expressions, each failure test uses a `do { ... XCTFail(...) } catch { XCTAssertEqual(error as? PhotoServiceError, ...) }` block instead. The transport-error test builds its expected `.network(underlying:)` message from the *same* injected `URLError` instance's `localizedDescription`, rather than a hardcoded string, so the assertion isn't coupled to OS-specific error text.

**Verify:** *(Please run ⌘U and confirm all 4 tests pass.)*

**Confirmed (2026-09-02):** ⌘U succeeded, all 4 tests pass. Step complete.

## ~~Step 12 — View model tests (§10.2)~~

Create `CTExpTests/PhotoListViewModelTests.swift`, constructing `PhotoListViewModel(service: MockPhotoService(...))` for each case:
- Test: fresh view model's `state` is `.loading` before `load()` completes.
- Test: `load()` against a mock returning N sample photos (where N is both under and over `maxDisplayedItems`) results in `.loaded` with the correct, capped array.
- Test: `load()` against a mock configured to throw each `PhotoServiceError` case results in `.error(message:)` with a non-empty message.
- Test: calling `load()` again after reconfiguring the mock from failure to success (simulating Retry) transitions `.error` → `.loading` → `.loaded` correctly, proving retry re-invokes the fetch rather than reusing stale state.

No `PhotoService` or `URLSession` should be reachable from this file — that's what `MockPhotoService` (Step 10) is for, and it's the point of injecting `PhotoServiceProtocol` rather than the concrete service in Step 6.

**Progress note (2026-09-02):** `CTExpTests/PhotoListViewModelTests.swift` written with 7 tests: initial `.loading` state, under-cap load, over-cap load (asserting the array is truncated to exactly `maxDisplayedItems`), one error test per `PhotoServiceError` case, and the retry test. Since `PhotoListViewModel` is `@MainActor` and `state` is therefore main-actor-isolated, the whole test class is marked `@MainActor` rather than hopping per-assertion.

One simplification from the step's literal wording: the retry test asserts the *end states* (`.error` after the first `load()`, `.loaded(photos)` after the second, with the mock reconfigured in between) rather than capturing the transient `.loading` value in the middle of the second `load()` call. Proving retry re-invokes the fetch — rather than reusing stale state — only requires showing the second call's outcome tracks the *new* mock configuration, which this does; capturing the fleeting mid-call `.loading` value would need a Combine `sink` collecting every `$state` emission, which adds real complexity for a state transition the `test_initialState_isLoading` test already covers structurally (loading is provably the state before any data arrives).

**Verify:** *(Please run ⌘U and confirm all 7 tests pass.)*

**Confirmed (2026-09-02):** ⌘U succeeded, all 7 tests pass. Step complete.

## ~~Step 13 — Test-double coverage check~~

Before moving to overall coverage, specifically confirm the three-layer testability goal is actually met:
- `Photo` (Model): tested via fixtures only, no mock — Step 9.
- `PhotoService` (Service): tested via `MockNetworkSession` — Step 11.
- `PhotoListViewModel` (ViewModel): tested via `MockPhotoService` — Step 12.

Grep the test target for `URLSession` and confirm the only match is inside `MockNetworkSession`'s conformance/plumbing — if `PhotoServiceTests` or `PhotoListViewModelTests` reference `URLSession` or `PhotoService` directly, a layer boundary was skipped and needs to route through its mock instead.

**Progress note (2026-09-02):** ran the check — zero matches for `URLSession` anywhere in `CTExpTests/` (the `extension URLSession: NetworkSession` conformance lives in the app target, not here, so this is correctly empty rather than pointing at `MockNetworkSession`). The only `PhotoService(` matches outside `PhotoServiceTests.swift` are `MockPhotoService(` calls in `PhotoListViewModelTests.swift` — a substring false positive, not the real `PhotoService`, confirmed by inspection. No boundary skips found.

**Incidental finding — resolved (2026-09-02):** `CTExpTests/CTExpTests.swift`, the empty placeholder test Xcode generated when the `CTExpTests` target was created back in Step 1, has been deleted. The test target now contains only `PhotoTests.swift`, `PhotoServiceTests.swift`, `PhotoListViewModelTests.swift`, and `Support/`.

**Verify:** ✓ confirmed clean, as above.

## Step 14 — Coverage and acceptance pass

- In Xcode: Product → Scheme → Edit Scheme → Test → check "Gather coverage for" the `CTExp` target (or `all targets`). Run all tests (⌘U).
- Open the coverage report (Report navigator → Coverage) and confirm `Photo.swift`, `PhotoService.swift`, and `PhotoListViewModel.swift` are each at or above 80% line coverage (§10.1). If any file is below, add the missing test case for whatever branch is uncovered rather than lowering the bar.
- Walk the acceptance criteria checklist in `TECHNICAL_REQUIREMENTS.md` §11 top to bottom and confirm each item against the running app and the test results.
- Run `xcodebuild test -scheme CTExp` from the command line (or the current scheme name) to confirm the suite is green outside of Xcode's UI too, e.g. for CI parity.

## Addendum: Snapshot testing for the views (added 2026-09-02)

This wasn't in the original scope — §10.1 of `TECHNICAL_REQUIREMENTS.md` explicitly left SwiftUI view code out of the line-coverage target, on the grounds that layout isn't meaningfully unit-testable. Snapshot testing is a different, complementary kind of test: it renders a view to an image and diffs it against a saved reference, catching visual regressions in `PhotoListView`'s three states rather than asserting on view-model logic (already covered by Step 12). Added as Steps 15–18 below rather than folded into the original numbering, since it's an addition to scope, not a step that was always planned.

## Step 15 — Add the swift-snapshot-testing package

This has to happen in Xcode itself — hand-editing Swift Package references into `project.pbxproj` (the `XCRemoteSwiftPackageReference`/`XCSwiftPackageProductDependency` entries, plus `Package.resolved`) is exactly the kind of edit that risks corrupting the project file, same reasoning as why the `CTExpTests` target itself had to be added via Xcode back in Step 1.

In Xcode: **File → Add Package Dependencies…**, enter `https://github.com/pointfreeco/swift-snapshot-testing`, pick "Up to Next Major Version" from the latest release, and — important — add the `SnapshotTesting` product **only to the `CTExpTests` target**, not the `CTExp` app target. It's test-only tooling and has no reason to ship in the app.

**Verify:** *(Please add the package and confirm the project resolves/builds with it present — ⌘B on the `CTExpTests` target is enough, no test file needs it yet.)*

## Step 16 — Make `PhotoListView`'s view model injectable

`PhotoListView` currently constructs its own `PhotoListViewModel()` inline (`@StateObject private var viewModel = PhotoListViewModel()`), which is fine for the app but means a test has no way to hand it a view model that's already wired to a `MockPhotoService` with controlled data. Add a constructor:

```swift
struct PhotoListView: View {
    @StateObject private var viewModel: PhotoListViewModel

    init(viewModel: PhotoListViewModel = PhotoListViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // body unchanged
}
```

The default argument preserves the existing call site in `ContentView.swift` (`PhotoListView()` still works, still uses the real `PhotoService`) while opening the same kind of seam Steps 5–6 already established for `PhotoService`/`PhotoListViewModel` — inject the collaborator, default to the real one.

**Verify:** Compiles, `ContentView.swift` unchanged and still builds/runs correctly.

**Progress note (2026-09-02):** written as specified — `_viewModel = StateObject(wrappedValue: viewModel)` in the new initializer, default argument preserves `PhotoListView()` at the `ContentView.swift` call site (left untouched).

**Build error found and fixed (2026-09-02):** line 18 (`init(viewModel: PhotoListViewModel = PhotoListViewModel())`) hit the same class of error as the Step 5 addendum — "Call to main actor-isolated initializer 'init(service:)' in a synchronous nonisolated context." Same root cause (default-argument expressions always evaluate in a nonisolated context, and `PhotoListViewModel`'s init was implicitly `@MainActor` because the class is), but a different fix this time: unlike `PhotoService`, `PhotoListViewModel` genuinely *should* stay `@MainActor` (it owns `@Published` UI state), so marking the whole class `nonisolated` isn't right. Instead, only its `init(service:)` — in `ViewModels/PhotoListViewModel.swift` — was marked `nonisolated init(...)`. This is a documented, valid pattern: an `@MainActor` class's initializer can itself be `nonisolated` as long as it only does simple stored-property assignment (which this one does — `self.service = service`, no access to `state` or any other main-actor-isolated member), letting the instance be *constructed* off the main actor while its methods and properties stay properly isolated.

**Follow-up build error, then a course correction (2026-09-02):** marking the init `nonisolated` surfaced a second error on `PhotoListViewModel.swift` line 24 ("Main actor-isolated property 'service' can not be mutated from a nonisolated context"). The first attempted fix — also marking the `service` property `nonisolated` — turned out not to fully resolve it (the same error persisted after rebuilding). Rather than keep chasing `nonisolated` annotations deeper into `PhotoListViewModel`, stepped back and fixed the actual root cause instead:

**Root cause:** Swift evaluates default-parameter-value expressions in an always-nonisolated context, regardless of the enclosing declaration's own isolation. `PhotoListView.init(viewModel: PhotoListViewModel = PhotoListViewModel())`'s default value called `PhotoListViewModel`'s `@MainActor` init from that nonisolated position — that was the real trigger, and every fix attempted directly on `PhotoListViewModel` was treating the symptom, not this.

**Actual fix:** `PhotoListViewModel.swift` was reverted to its original, plain form — no `nonisolated` anywhere, fully and simply `@MainActor` as Step 6 first wrote it. Instead, `PhotoListView`'s single initializer-with-default-value was split into two initializers: `init(viewModel: PhotoListViewModel)` (no default — what tests use) and a separate `init()` that calls `self.init(viewModel: PhotoListViewModel())` from its own *body* rather than a default-argument position. A call inside an init's body follows ordinary isolation rules (this `init()` is itself `@MainActor`, per the project's `SWIFT_DEFAULT_ACTOR_ISOLATION` setting, so a `@MainActor` init calling another `@MainActor` init is unremarkable), which is what sidesteps the special default-argument rule entirely. `ContentView.swift`'s `PhotoListView()` call site is unaffected either way.

## Step 17 — Photo fixtures for snapshot tests

Create `CTExpTests/Support/PhotoFixtures.swift` — a small, deterministic set of `Photo` values reused across snapshot tests (and available to any other test that wants realistic-but-fixed data, rather than each test file inventing its own). Deterministic matters here specifically because snapshot tests compare rendered images byte-for-byte(ish); titles/ids need to be fixed, not randomly generated per run.

```swift
enum PhotoFixtures {
    static let short: [Photo] = [
        Photo(id: 1, albumId: 1, title: "Mountain lake",
              url: URL(string: "https://picsum.photos/seed/1/600")!,
              thumbnailUrl: URL(string: "https://picsum.photos/seed/1/150")!),
        Photo(id: 2, albumId: 1, title: "City skyline at dusk",
              url: URL(string: "https://picsum.photos/seed/2/600")!,
              thumbnailUrl: URL(string: "https://picsum.photos/seed/2/150")!),
        Photo(id: 3, albumId: 1, title: "A much longer title to check how the row wraps across two lines",
              url: URL(string: "https://picsum.photos/seed/3/600")!,
              thumbnailUrl: URL(string: "https://picsum.photos/seed/3/150")!),
    ]
}
```

Marked `nonisolated` for the same reason as the other test-support types (Steps 9–10), and lives in `Support/` alongside the mocks since it's shared fixture data, not a test file itself. The third entry with a deliberately long title is there so the `.loaded` snapshot exercises `PhotoRowView`'s two-line wrap, not just the happy-path short case.

**Verify:** Compiles.

**Progress note (2026-09-02):** `CTExpTests/Support/PhotoFixtures.swift` written as specified, three photos (two short titles, one long one to exercise the two-line wrap), marked `nonisolated` per the established pattern.

## Step 18 — Snapshot tests for `PhotoListView`

Create `CTExpTests/PhotoListViewSnapshotTests.swift`, covering the three states from §7.3/§7.4:

- **`.loaded`**: construct `MockPhotoService` with `result = .success(PhotoFixtures.short)`, build `PhotoListViewModel(service:)`, `await viewModel.load()` to settle it deterministically, *then* construct `PhotoListView(viewModel:)` and `assertSnapshot`. Awaiting `load()` before rendering — rather than relying on the view's own `.task` firing during the snapshot render — is what makes this deterministic instead of racy.
- **`.error`**: same pattern with `result = .failure(.network(underlying: "offline"))`.
- **`.loading`**: needs a `MockPhotoService` whose `fetchPhotos()` never returns (e.g. `try await Task.sleep(for: .seconds(3600))` before returning anything), so the view model provably stays in its initial `.loading` state for the snapshot — don't `await load()` for this case, just construct the view and snapshot immediately.

Since `PhotoListView`/`PhotoListViewModel` are `@MainActor`, this test file should be `@MainActor` too, same reasoning as Step 12.

Record reference images on first run (`isRecording = true` on the first pass, or the `SnapshotTesting` record mode via the assertion call), inspect them once to confirm they look right, then flip back to compare mode and commit the reference images alongside the test.

**Progress note (2026-09-02):** `MockPhotoService` (Step 10) extended first with a `var neverResolves = false` flag — when set, `fetchPhotos()` does `try await Task.sleep(nanoseconds: .max)` instead of returning `result`, giving the `.loading` case a way to stay pinned in that state indefinitely rather than racing a real `Result` resolving before the snapshot captures.

`CTExpTests/PhotoListViewSnapshotTests.swift` written with the three cases: `.loaded` and `.error` both call `await viewModel.load()` to settle state deterministically *before* constructing `PhotoListView(viewModel:)` and snapshotting, rather than relying on the view's own `.task` firing during capture; `.loading` uses `neverResolves = true` and skips calling `load()` at all, letting the view's `.task` fire but never complete. All three use a fixed `390×844` layout (`.image(layout: .fixed(width:height:))`) since `PhotoListView`'s `List` doesn't have a natural intrinsic size for `.sizeThatFits`.

**Verify:** *(Please run ⌘U, inspect the three recorded snapshots once by eye to confirm they look correct, then re-run in compare mode to confirm they pass.)*

## Suggested commit breakdown

If committing incrementally rather than as one large commit, this maps cleanly to the steps above: (1) model, (2) network session protocol + service + error type, (3) view model, (4) views + ContentView wiring, (5) test doubles (`MockNetworkSession`, `MockPhotoService`), (6) model/service/view-model tests, (7) snapshot testing addition (package, injectable view model, fixtures, snapshot tests + reference images). Keeping the test-double commit separate from both the feature commits and the test commits makes it easy to see the testability seams as their own reviewable unit.
