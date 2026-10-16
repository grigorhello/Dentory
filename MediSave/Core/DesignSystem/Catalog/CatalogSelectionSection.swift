#if DEBUG
import SwiftUI

struct CatalogSelectionSection: View {
    @State private var expiryAlerts = true
    @State private var lowStockAlerts = false
    @State private var endoSelected = true
    @State private var compositeSelected = false
    @State private var orderTab = "toBuy"
    @State private var window = 30
    @State private var filter = "all"
    @State private var quantity = 2
    @State private var changed = 3
    @State private var count = 0

    var body: some View {
        CatalogSection("Toggles") {
            MSToggle("Expiry alerts", isOn: $expiryAlerts)
            MSToggle("Low stock alerts", isOn: $lowStockAlerts)
            MSToggle("Disabled", isOn: .constant(true)).disabled(true)
        }
        CatalogSection("Checkboxes") {
            MSCheckbox("Endo file kit #15-40", description: "Current 1 · target 5 · Patterson", isOn: $endoSelected)
            MSCheckbox("Composite A2", description: "Current 2 · target 6 · Patterson", isOn: $compositeSelected)
            MSCheckbox("Disabled", isOn: .constant(true)).disabled(true)
        }
        CatalogSection("Segments") {
            SegmentedControl(selection: $orderTab, options: [
                SegmentOption("toBuy", label: "To buy", count: 3),
                SegmentOption("ordered", label: "Ordered", count: 3),
                SegmentOption("received", label: "Received", count: 1)
            ])
            SegmentedControl(selection: $window, options: [30, 60, 90].map { SegmentOption($0, label: "\($0) days") })
        }
        CatalogSection("Filter chips") {
            FilterChipRow(selection: $filter, options: [
                SegmentOption("all", label: "All"),
                SegmentOption("low", label: "Low", count: 3),
                SegmentOption("expiring", label: "Expiring", count: 2),
                SegmentOption("missing", label: "Missing expiry", count: 1),
                SegmentOption("healthy", label: "Healthy")
            ], inset: 0)
        }
        CatalogSection("Steppers") {
            HStack(spacing: Spacing.lg) {
                QuantityStepper(value: $quantity, reference: 2, identifier: "catalog.stepper[1]")
                CatalogCaption("at its reference of 2")
            }
            HStack(spacing: Spacing.lg) {
                QuantityStepper(value: $changed, reference: 2, identifier: "catalog.stepper[2]")
                CatalogCaption("differs from its reference of 2")
            }
            HStack(spacing: Spacing.lg) {
                QuantityStepper(value: $count, identifier: "catalog.stepper[3]")
                CatalogCaption("at the minimum of 0")
            }
        }
        .id("steppers")
    }
}
#endif
