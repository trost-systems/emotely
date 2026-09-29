import XCTest
import integration_test

// Runs the Dart integration test the app was built with as an XCTest, so
// that Firebase Test Lab can run it on an iPhone with no host attached: the
// performance survey (integration_test/survey_test.dart, #242). Which Dart
// test runs is chosen at build time (`flutter build ios --config-only
// --target=...`); `.claude/skills/run-app/scripts/survey.sh build ios`
// builds and zips it.
//
// The Swift form of integration_test's INTEGRATION_TEST_IOS_RUNNER macro,
// with every Dart test reported as one XCTest.
class RunnerTests: XCTestCase {
  func testIntegrationTests() {
    var failures: [String] = []
    FLTIntegrationTestRunner().testIntegrationTest { selector, success, message in
      if !success {
        failures.append("\(NSStringFromSelector(selector)): \(message ?? "failed")")
      }
    }
    XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
  }
}
