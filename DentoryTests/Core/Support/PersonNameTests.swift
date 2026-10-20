import Testing
@testable import Dentory

/// History rows, Procedures, Home's latest procedure and Product detail name people this way.
struct PersonNameTests {
    @Test func aPersonGoesByTheirFirstName() {
        #expect(PersonName.first(of: "Sarah Chen") == "Sarah")
        #expect(PersonName.first(of: "Michael") == "Michael")
        #expect(PersonName.first(of: "Drew Carter") == "Drew")
        #expect(PersonName.first(of: "") == "")
    }

    @Test func aDoctorGoesByTitleAndLastName() {
        #expect(PersonName.first(of: "Dr. Daniel Kim") == "Dr. Kim", "Not \"Dr.\" (the demo seed's dentist)")
        #expect(PersonName.first(of: "Dr. Kim") == "Dr. Kim")
        #expect(PersonName.first(of: "dr Ana Lopez") == "Dr. Lopez")
        #expect(PersonName.first(of: "Dr.") == "Dr.")
    }
}
