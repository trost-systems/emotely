package de.emotely.emotely

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Rule
import org.junit.runner.RunWith

// Runs a Dart integration test as an Android instrumentation test, so that
// Firebase Test Lab can run it on a phone with no host attached: the
// performance survey (integration_test/survey_test.dart, #242). Which test
// runs is chosen at build time (`./gradlew app:assembleProfile
// -Ptarget=...`); `.claude/skills/run-app/scripts/survey.sh` builds both
// APKs.
@RunWith(FlutterTestRunner::class)
class MainActivityTest {
    // ActivityTestRule is deprecated, but FlutterTestRunner looks for exactly
    // this rule and launches the activity through it.
    @Suppress("DEPRECATION")
    @Rule
    @JvmField
    val rule: ActivityTestRule<MainActivity> =
        ActivityTestRule(MainActivity::class.java, true, false)

    init {
        // The survey writes survey.json under the app's own external files
        // directory, which Test Lab pulls (--directories-to-pull). Android
        // creates that directory only when the app first asks for it.
        InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir(null)
    }
}
