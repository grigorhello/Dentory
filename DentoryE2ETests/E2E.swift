import XCTest

/// The app on the local stack seeded with the demo clinic (MS-109), for the end-to-end flows `make e2e` runs (MS-136):
/// a Debug build without `-uiTesting`, so the real repositories, Edge Functions and database behind every screen. Each
/// flow launches with `-signedOut`, which signs the device out first, so it starts on Sign in whatever the flow before
/// left behind; the flows share one seeded database and keep to products the others do not touch.
@MainActor
enum E2E {
    /// Smile Dental's admin and Staff member (supabase/seed-demo.sql).
    static let admin = "sarah@smiledental.ca"
    static let staff = "michael@smiledental.ca"
    static let password = "smiledental"

    /// How long a flow waits for a screen or the server's answer: a slower Mac, or a stack busy with another flow's
    /// writes, takes longer than this one.
    static let patience: TimeInterval = 20

    /// A product of the demo clinic by its number in the seed (`pg_temp.pid`).
    nonisolated static func product(_ number: Int) -> String {
        "d0000000-0000-4000-8000-0000000002" + twoDigits(number)
    }

    /// A procedure template of the demo clinic by its number in the seed (`pg_temp.tid`).
    nonisolated static func template(_ number: Int) -> String {
        "d0000000-0000-4000-8000-0000000003" + twoDigits(number)
    }

    /// The seed's `lpad(n, 2, '0')`.
    private nonisolated static func twoDigits(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }

    /// Northbridge's invoice INV-10092 (f23's four lines), one of MS-129's fixture PDFs, which the local stack reads
    /// from its recorded answer (supabase/functions/extract_invoice/replay.ts).
    static let invoiceFixture = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "supabase/functions/extract_invoice/fixtures/northbridge-inv-10092.pdf")
        .path(percentEncoded: false)

    /// The app on Sign in, with `arguments` besides.
    static func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-signedOut"] + arguments
        app.launch()
        app.buttons["signin.submit"].appears("Sign in did not show")
        return app
    }

    /// The app signed in as `email`, on Home.
    static func signedIn(_ email: String, arguments: [String] = []) -> XCUIApplication {
        let app = launch(arguments)
        signIn(email, in: app)
        return app
    }

    /// Signs `email` in and waits for Home.
    static func signIn(_ email: String, in app: XCUIApplication) {
        let field = app.textFields["signin.email"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No email field")
        field.tap()
        app.typeText(email)
        app.secureTextFields["signin.password"].firstMatch.tap()
        app.typeText(password)
        app.buttons["signin.submit"].tap()
        app.buttons["home.header.account"].appears("Home did not show")
        dismissNotificationsExplainer(in: app)
    }

    /// Not now on the notifications explainer, which the device offers after its first sign-in and then every 30 days.
    static func dismissNotificationsExplainer(in app: XCUIApplication) {
        let notNow = app.buttons["push.notNow"]
        guard notNow.waitForExistence(timeout: 3) else { return }
        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5), "The notifications explainer stayed")
    }

    /// Waits until `element`'s label contains `text`.
    static func expect(
        _ element: XCUIElement, toRead text: String, _ message: String, timeout: TimeInterval = patience
    ) {
        let label = NSPredicate(format: "label CONTAINS %@", text)
        let reads = XCTNSPredicateExpectation(predicate: label, object: element)
        let waited = XCTWaiter().wait(for: [reads], timeout: timeout)
        XCTAssertEqual(waited, .completed, "\(message): \"\(element.label)\"")
    }

    /// The element whose identifier starts with `prefix` and whose label starts with `name`: a row keyed by an id the
    /// seed leaves random (a batch, a To buy line, a past procedure).
    static func element(_ prefix: String, labelled name: String, in app: XCUIApplication) -> XCUIElement {
        let match = NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", prefix, name)
        return app.descendants(matching: .any).matching(match).firstMatch
    }

    /// Types `text` into the search of the Inventory on screen, in place of what it held.
    static func searchInventory(for text: String, in app: XCUIApplication) {
        let search = app.textFields["inv.search"].firstMatch
        search.appears("Inventory did not open")
        search.tap()
        if let typed = search.value as? String, !typed.isEmpty, typed != search.placeholderValue {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
        }
        search.typeText("\(text)\n")
    }

    /// Inventory's row for a product, found through the search: the list only holds the rows on screen.
    static func inventoryRow(_ productID: String, searching name: String, in app: XCUIApplication) -> XCUIElement {
        searchInventory(for: name, in: app)
        return app.descendants(matching: .any)["inv.row[\(productID)]"]
    }

    /// The toast once it shows, with its title and detail.
    static func expectToast(_ title: String, _ detail: String, in app: XCUIApplication) {
        let toast = app.descendants(matching: .any)["toast"]
        toast.appears("No toast \"\(title)\"")
        XCTAssertTrue(toast.staticTexts[title].exists, "The toast is not \"\(title)\"")
        XCTAssertTrue(toast.staticTexts[detail].exists, "The toast's detail is not \"\(detail)\"")
    }
}
