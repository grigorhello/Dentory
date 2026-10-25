#if DEBUG
import SwiftUI

struct CatalogFormsSection: View {
    @State private var name = "Septocaine 4% 1:100,000"
    @State private var email = ""
    @State private var password = "hunter2hunter2"
    @State private var minimum = "20"
    @State private var category: String? = "Anesthetic"
    @State private var supplier: String?
    @State private var expiry: YearMonth?
    @State private var optionalExpiry: YearMonth?
    @State private var isOptionalExpiryOpen = false

    var body: some View {
        CatalogSection("Text fields") {
            MSTextField("Name", text: $name, hint: "Shown in lists and procedures.")
            MSTextField(
                "Email", text: $email, placeholder: "you@clinic.com", error: "No account with this email.",
                keyboard: .emailAddress, contentType: .emailAddress
            )
            MSTextField("Password", text: $password, isSecure: true, contentType: .password)
            MSTextField("Search", text: .constant(""), placeholder: "Search products", icon: .search)
            MSTextField("Expiry", text: .constant(""), placeholder: "- - - - - -", trailingIcon: .calendar)
            MSTextField("Minimum", text: $minimum, suffix: "cartridges", keyboard: .numberPad)
            MSTextField("Cost per box", text: .constant(""), placeholder: "0.00", prefix: "$", keyboard: .decimalPad)
            MSTextField("Disabled", text: .constant("Read only")).disabled(true)
            MSReadOnlyField("Email", value: "priya@smiledental.ca")
        }
        CatalogSection("Picker") {
            MSPicker("Category", selection: $category, options: ["Anesthetic", "Endodontics", "PPE"]) { $0 }
            MSPicker(
                "Supplier", selection: $supplier, options: ["Patterson", "Benco", "Henry Schein"],
                placeholder: "Choose a supplier", hint: "Optional"
            ) { $0 }
            MSPicker("Unit", selection: .constant(String?.none), options: ["box"], error: "Choose a unit.") { $0 }
            MSPicker("Disabled", selection: .constant("box"), options: ["box"]) { $0 }.disabled(true)
        }
        CatalogSection("Select on a sheet") {
            MSSelectField("Product", value: nil, placeholder: "Choose a product") {}
            MSSelectField(
                "Product", value: "Septocaine 4% 1:100,000", caption: "Anesthetic · 54 cartridges in stock",
                placeholder: "Choose a product"
            ) {}
        }
        CatalogSection("Month") {
            // Tap to open the month and year wheels; they start on `opening` when nothing is chosen.
            MSMonthField(
                "Expires", selection: $expiry, years: 2023...2036, opening: YearMonth(year: 2026, month: 10)
            ) { "\($0.month)/\($0.year)" }
            MSMonthField(
                "Expires", selection: .constant(nil), years: 2023...2036, opening: YearMonth(year: 2026, month: 10),
                error: "Choose a month."
            ) { "\($0.month)/\($0.year)" }
            // In a row of two (f24): the wheels open full width under the row, and × clears an optional month.
            HStack(alignment: .top, spacing: Spacing.md) {
                MSTextField("Lot", text: .constant(""), placeholder: "Optional")
                MSMonthField(
                    "Expiry", selection: $optionalExpiry, years: 2023...2036,
                    opening: YearMonth(year: 2026, month: 10), placeholder: "Optional", trailingIcon: .calendar,
                    clearLabel: "Clear expiry", wheelsOpen: $isOptionalExpiryOpen
                ) { "\($0.month)/\($0.year)" }
            }
            if isOptionalExpiryOpen {
                MSMonthWheels(
                    selection: $optionalExpiry, years: 2023...2036, opening: YearMonth(year: 2026, month: 10)
                )
            }
        }
    }
}
#endif
