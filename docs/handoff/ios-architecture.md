# iOS architecture, explained

The rules live in `.claude/skills/dentory-ios/SKILL.md`; this file keeps the reasons and examples behind them, moved out of the skill on 2026-10-23 so the skill stays short. When the two disagree, the skill wins.

## Why this shape

Dentory is small: 38 frames, one backend, two roles. Clean MVVM in feature folders keeps each ticket inside one folder, keeps view models testable without SwiftUI, and lets a reviewer check a PR against a short checklist. The skill's "Do not" list rules out heavier patterns (VIPER, Clean-architecture use cases, Coordinators, TCA, Redux): at this size they add files without catching more bugs (decisions log, 2026-10-15: "no over-engineering").

## The folder tree

```
project.yml                     XcodeGen spec (the .xcodeproj is generated, not committed)
Dentory/
  App/                          DentoryApp, AppDependencies (composition root), RootView, AppTab
  Core/
    DesignSystem/               Tokens + reusable components (MS-102). The only place colors, fonts, sizes live.
                                `MS` is the design-system prefix (`MSButton`, `MSColor`, `MSSheet`), not the product name.
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
DentoryTests/Features/<Feature>/   mirrors Features/
DentoryUITests/                    end-to-end flows using the Appendix B ids
supabase/                           migrations, functions, seed, SQL tests
```


## The layers

```
View  ──owns──▶  ViewModel  ──calls──▶  Repository (protocol)  ◀──implements──  Supabase<Name>Repository
 (SwiftUI)        (@Observable)          (Features/<F>/)                        (supabase-swift, DTOs)
```


The view never talks to Supabase; the view model never imports SwiftUI; the repository never returns a DTO. Each boundary is where a test fake goes: views are checked by UI flows, view models and domain rules by unit tests against fake repositories, and the Supabase repositories by pgTAP tests of the RPCs they call.

## SOLID, applied (and where to stop)

- **Single responsibility:** view renders, view model decides, repository fetches, domain type computes. If a view model needs a comment like "// MARK: networking", the networking belongs in a repository.
- **Open/closed:** new status, invoice line state or alert type means a new `enum` case handled with `switch` (the compiler finds every place). Do not build plugin registries.
- **Liskov:** fakes and Supabase implementations must behave the same for the same input (same errors for the same failure). Tests rely on it.
- **Interface segregation:** small protocols per feature (`ProcedureRepository` has the 4 calls Procedures needs), not one `APIClient` protocol with 60 methods.
- **Dependency inversion:** view models depend on protocols; only `AppDependencies` knows the concrete Supabase types.

OOP choices: `final class` where identity and observation matter (view models, services); `struct` for anything copied (models, DTOs, views, routes); `enum` for closed sets the compiler can check. Composition over inheritance, because a base view model ends up holding every screen's half-shared state.

## Worked example: a list screen

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
// DentoryTests/Features/Inventory/InventoryListViewModelTests.swift
import Testing
@testable import Dentory

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
