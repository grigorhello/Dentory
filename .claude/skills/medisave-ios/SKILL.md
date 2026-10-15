---
name: medisave-ios
description: MediSave iOS architecture and coding standard (SwiftUI, MVVM, feature folders, SOLID). Use for every MediSave ticket that adds or changes Swift code, and when reviewing a MediSave pull request.
---

# MediSave iOS: how to build a ticket

MediSave is a native iPhone and iPad app (SwiftUI, iOS 17+, Swift 6) on Supabase. This skill is the house standard. It is deliberately small: clean MVVM in feature folders, SOLID where it pays, nothing more. When this skill and a ticket disagree, the ticket wins for product behaviour and this skill wins for code structure.

Other skills in this repo, load them when the task calls for it:
- `swiftui-pro` (Paul Hudson, MIT): modern SwiftUI API, accessibility, layout and performance review. Run its review on your diff before opening the PR.
- `swift-concurrency` (Antoine van der Lee, MIT): actors, `Sendable`, `@MainActor`, Swift 6 strict-concurrency errors.

## 1. Workflow for every ticket

1. Read `CLAUDE.md`, the GitHub issue, every frame it lists (`design/frames/fNN*.png`), its prototype screen key and its PRD section. Decisions in MS-100 override the PRD.
2. Check the issue's **Build step** and **Blocked by** line. Do not start a ticket whose blockers are still open.
3. Branch `ms-1NN-short-name` from `main`. One ticket, one branch, one PR.
4. Put new code in the feature folder the ticket belongs to (section 2). Create the folder if it is the first ticket for that feature.
5. Write or update the view model tests first (section 7), then the view model, then the view.
6. Set the PRD Appendix B element id as `.accessibilityIdentifier(...)` on every interactive element.
7. Run `make lint test` (or the commands in `CLAUDE.md`). Build for the iPhone 16 and iPad Pro 11" simulators.
8. Run the `swiftui-pro` review on your diff and fix genuine findings.
9. Open the PR: title `MS-1NN · …`, body `Closes #N`, simulator screenshots next to the frame images, and a note for any place you followed the frame over the PRD.
10. When CI finishes, run the `pr-reviewer` agent on the PR and follow the review loop in `CLAUDE.md`: fix its findings on the same branch until it merges, at most 3 rounds.

## 2. Project layout (feature folders)

```
project.yml                     XcodeGen spec (the .xcodeproj is generated, not committed)
MediSave/
  App/                          MediSaveApp, AppDependencies (composition root), RootView, AppTab
  Core/
    DesignSystem/               Tokens + reusable components (MS-102). The only place colors, fonts, sizes live.
    Domain/                     Shared value types: Product, Batch, ProductStatus, Money, ExpiryMonth, Role
    Data/                       SupabaseClientProvider, DTO decoding helpers, RPC caller, AppError
    Navigation/                 Router, Sheet and Toast presenters (MS-103)
    Support/                    Formatters, Clock, NetworkMonitor, Logger
  Features/
    Inventory/
      InventoryListView.swift
      InventoryListViewModel.swift
      ProductRow.swift
      InventoryRepository.swift          protocol
      SupabaseInventoryRepository.swift  implementation
      InventoryRoute.swift
    ProductDetail/  Procedures/  Receiving/  ToBuy/  Activity/  Home/  Auth/  Onboarding/  Team/  Settings/  Billing/
  Resources/                    Assets, Localizable.xcstrings, fonts
MediSaveTests/Features/<Feature>/   mirrors Features/
MediSaveUITests/                    end-to-end flows using the Appendix B ids
supabase/                           migrations, functions, seed, SQL tests
```

Rules:
- A feature folder owns its views, view models, repository protocol + implementation and routes. Keep it flat; add subfolders (`Views/`, `ViewModels/`) only when a feature passes about 12 files.
- One type per file, file named after the type.
- A feature never imports another feature's internals. Shared types move to `Core/Domain`; shared UI moves to `Core/DesignSystem`.
- Navigation between features goes through route values (`InventoryRoute.product(id)`), not by constructing another feature's view model.

## 3. The layers

```
View  ──owns──▶  ViewModel  ──calls──▶  Repository (protocol)  ◀──implements──  Supabase<Name>Repository
 (SwiftUI)        (@Observable)          (Features/<F>/)                        (supabase-swift, DTOs)
```

**View** (`struct …View: View`)
- Renders state and forwards user intent. No business rules, no networking, no formatting logic beyond calling a formatter.
- Owns its view model with `@State private var viewModel: …ViewModel` created from injected dependencies.
- Loads with `.task { await viewModel.load() }` so work is cancelled when the view disappears.
- Uses only `Core/DesignSystem` tokens and components. No `Color(red:…)`, hex, raw font names or magic paddings.
- Keep `body` short. Extract subviews (`ProductRow`, `BatchTable`) as separate `struct`s, not computed properties returning `some View`.

**ViewModel** (`@MainActor @Observable final class …ViewModel`)
- One per screen (or per sheet when the sheet has its own logic).
- Holds screen state as plain stored properties, plus a `state` enum when the screen loads data:
  `enum LoadState { case loading, loaded, empty, failed(AppError) }`.
- Exposes intent methods named after the user action: `startProcedure()`, `increment(productID:)`, `applyCount()`.
- Depends only on protocols passed into `init`. Never reaches for a global or a singleton.
- Imports `Foundation` and `Observation`, not `SwiftUI`. That keeps it unit-testable and stops view code leaking in.
- Derived values are computed properties (`var canStart: Bool`), not duplicated state.

**Repository** (`protocol InventoryRepository: Sendable`)
- The boundary to Supabase, one per aggregate the feature reads or writes. Methods are `async throws` and return domain types, never DTOs or JSON.
- Stock changes call the Postgres RPC functions from MS-106 (`stock_adjust`, `procedure_start`, …) with an idempotency key. Never insert into `batches`, `transactions` or `open_items` directly.
- The Supabase implementation decodes `Codable` DTOs and maps them to domain types in one place (`init(dto:)` on the domain type or a small mapper).

**Domain** (`struct`, `Sendable`, `Equatable`)
- Value types with the business rules that belong to the data itself, e.g. `ProductStatus.evaluate(...)` (MS-107), `ExpiryMonth.daysLeft(on:in:)`.
- No Supabase or SwiftUI imports.

**Composition root** (`App/AppDependencies.swift`)
- A `struct AppDependencies` holding one instance of each repository and service (`clock`, `networkMonitor`, `analytics`).
- Built once in `MediSaveApp` (live) and in tests or previews (fakes). Passed down with a custom `EnvironmentKey`; views read it and hand the pieces their view model needs to its `init`.
- No third-party DI container, no service locator called from inside view models.

## 4. SOLID, applied (and where to stop)

- **Single responsibility:** view renders, view model decides, repository fetches, domain type computes. If a view model needs a comment like "// MARK: networking", the networking belongs in a repository.
- **Open/closed:** new status, invoice line state or alert type means a new `enum` case handled with `switch` (the compiler finds every place). Do not build plugin registries.
- **Liskov:** fakes and Supabase implementations must behave the same for the same input (same errors for the same failure). Tests rely on it.
- **Interface segregation:** small protocols per feature (`ProcedureRepository` has the 4 calls Procedures needs), not one `APIClient` protocol with 60 methods.
- **Dependency inversion:** view models depend on protocols; only `AppDependencies` knows the concrete Supabase types.

OOP choices:
- `final class` for view models and services (identity, observation). `struct` for models, DTOs, views and routes. `enum` for states, routes and closed sets.
- Composition over inheritance. No `BaseViewModel`, no abstract superclasses. Share behaviour through small protocol extensions or helper types.
- Encapsulate: stored properties `private(set)` unless the view binds to them.

## 5. Keep it simple (things we do not do)

- No VIPER, Clean-architecture use-case layer, Coordinators, TCA, Redux stores or Combine pipelines.
- A protocol exists only at a real boundary: repositories, `Clock`, `NetworkMonitor`, `Analytics`, `ImagePicker`. Not for view models, views, formatters or models.
- No generic `Repository<T>`, no `ViewModelProtocol`, no factories for things built once.
- No new third-party package without a ticket saying so. Allowed: `supabase-swift`; later tickets add Sentry (MS-108) and PostHog (MS-147).
- No speculative features, flags or settings the ticket does not ask for.
- Soft limits: view file about 150 lines, view model about 250. Past that, split by responsibility.

## 6. Swift and SwiftUI conventions

- Build settings (set in `project.yml` by MS-101, do not change per ticket): Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, deployment target iOS 17.0, iPhone + iPad. Mark heavy pure work `nonisolated` or `@concurrent` only when profiling shows it matters.
- `async`/`await` only; no completion handlers, no Combine.
- Observation (`@Observable`, `@Bindable`, `@State`, `@Environment`); never `ObservableObject`/`@Published`/`@StateObject` in new code.
- `NavigationStack` per tab with a typed path (`[InventoryRoute]`); sheets via `.sheet(item:)` driven by an optional enum on the view model.
- Errors: throw `AppError` (`.network`, `.notFound`, `.forbidden`, `.readOnly`, `.validation(field:message:)`, `.unknown`). The view model maps it to UI copy from MS-108 ("Couldn't save. Try again.").
- Copy rules from `CLAUDE.md`: sentence case, numbers first, no exclamation marks, no emoji, no "please". Strings live in `Localizable.xcstrings` (English only in V1.1).
- Accessibility: every control has a label; `.accessibilityIdentifier` uses the Appendix B id verbatim; support Dynamic Type up to the Large step.
- iPad: same tabs and screens, content capped at 720 pt and centred (MS-103 provides the container). iPhone portrait only.
- Format money, dates and quantities through `Core/Support` formatters using the clinic currency and time zone.

## 7. Tests

- **Unit (Swift Testing, `@Test`)**: every view model and every domain rule. Use hand-written fakes (`FakeInventoryRepository` with canned results and a recorded-calls array). No mocking frameworks.
- Test names read as behaviour: `@Test func startIsDisabledWhenNoItemsSelected()`.
- **UI (XCUITest)**: one flow per user journey the ticket changes, finding elements by Appendix B id. Runs against the local Supabase seeded with the demo clinic (MS-109).
- **Database**: SQL tests in `supabase/tests` for any migration, RLS policy or RPC.
- A ticket is not done while any test is red or skipped.

## 8. Examples

```swift
// Features/Inventory/InventoryRepository.swift
protocol InventoryRepository: Sendable {
    func products(clinicID: Clinic.ID) async throws -> [ProductSummary]
}
```

```swift
// Features/Inventory/InventoryListViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class InventoryListViewModel {
    enum LoadState: Equatable { case loading, loaded, empty, failed(AppError) }

    private(set) var state: LoadState = .loading
    private(set) var products: [ProductSummary] = []
    var searchText = ""
    var filter: InventoryFilter = .all

    private let repository: InventoryRepository
    private let clinicID: Clinic.ID

    init(repository: InventoryRepository, clinicID: Clinic.ID) {
        self.repository = repository
        self.clinicID = clinicID
    }

    var visibleProducts: [ProductSummary] {
        products
            .filter { filter.includes($0.status) }
            .filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
    }

    func load() async {
        do {
            products = try await repository.products(clinicID: clinicID)
            state = products.isEmpty ? .empty : .loaded
        } catch {
            state = .failed(AppError(error))
        }
    }
}
```

```swift
// Features/Inventory/InventoryListView.swift
import SwiftUI

struct InventoryListView: View {
    @State private var viewModel: InventoryListViewModel

    init(viewModel: InventoryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List(viewModel.visibleProducts) { product in
            NavigationLink(value: InventoryRoute.product(product.id)) {
                ProductRow(product: product)
            }
            .accessibilityIdentifier("inv.row[\(product.id)]")
        }
        .searchable(text: $viewModel.searchText)
        .task { await viewModel.load() }
    }
}
```

```swift
// MediSaveTests/Features/Inventory/InventoryListViewModelTests.swift
import Testing
@testable import MediSave

@MainActor
struct InventoryListViewModelTests {
    @Test func lowFilterIncludesOutOfStock() async {
        let repository = FakeInventoryRepository(products: [.fixture(status: .low), .fixture(status: .outOfStock), .fixture(status: .healthy)])
        let viewModel = InventoryListViewModel(repository: repository, clinicID: .demo)
        await viewModel.load()
        viewModel.filter = .low
        #expect(viewModel.visibleProducts.count == 2)
    }
}
```

## 9. Pull request checklist

- [ ] Code sits in the right feature folder; no cross-feature imports.
- [ ] View has no business logic; view model has no `SwiftUI` import; repository returns domain types.
- [ ] Stock changes only through MS-106 RPCs with an idempotency key.
- [ ] Only design-system tokens and components in feature code.
- [ ] Appendix B ids on every interactive element.
- [ ] Unit tests for the view model and domain rules; UI test updated when a flow changed; SQL tests for database changes.
- [ ] Builds clean with zero warnings in Swift 6 mode; SwiftLint clean.
- [ ] Nothing in section 5 was introduced.
