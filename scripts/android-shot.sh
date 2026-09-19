#!/usr/bin/env bash
#
# android-shot.sh — a picture of the Compose UI the android surface generates.
#
# Generates a one-surface Android project with ranger-starter, compiles the Ranger
# module to Kotlin, renders AppScreen with Paparazzi on the JVM (no emulator), and
# saves a PNG. Same role as desktop-shot.sh: proof that the host and module draw
# something real, on a machine that may not have KVM for the Android emulator.
#
# Set RANGER_ANDROID_SHOT=emulator to install on a running AVD and use adb screencap
# instead (needs adb, emulator, KVM on Linux x86_64, and RANGER_ANDROID_AVD).
#
# Needs JDK 17+, ANDROID_HOME (for the Android Gradle plugin), and Pillow for the
# phone frame. The first run downloads the Gradle wrapper JAR.
#
#   scripts/android-shot.sh [out.png]
#
# Default output: docs/wizard/41-android-app.png
#
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
out="${1:-$here/docs/wizard/41-android-app.png}"
if [[ "$out" != /* ]]; then
    out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"
fi
work=$(mktemp -d)
emu_log="$work/emulator.log"
trap 'if [[ -n "${emu_pid:-}" ]]; then kill "$emu_pid" 2>/dev/null || true; fi; rm -rf "$work"' EXIT

if ! command -v java >/dev/null 2>&1; then
    echo "error: java is not installed (JDK 17+)" >&2
    exit 1
fi

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
    if [[ -d "$HOME/Android/Sdk" ]]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
        export ANDROID_SDK_ROOT="$ANDROID_HOME"
    else
        echo "error: set ANDROID_HOME to the Android SDK" >&2
        exit 1
    fi
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

cd "$work"
node "$here/bin/ranger-starter.js" init --name androidtest --surfaces android --apply >/dev/null
ln -s "$here/node_modules" node_modules

# A deliberately tiny app: one Ranger class, two strings shown in Compose.
cat > src/Shared.rgr <<'EOF'
; SPDX-License-Identifier: MIT
; androidtest — small Ranger module for the generated Compose host.

class Shared {

    Constructor () {
    }

    fn greeting:string () {
        return "Hello from Ranger on Android"
    }

    fn subtitle:string () {
        return "androidtest · kotlin · compose"
    }
}
EOF

cat > platforms/android/app/src/main/kotlin/com/example/androidtest/MainActivity.kt <<'EOF'
package com.example.androidtest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { AppScreen() } }
    }
}

@Composable
fun AppScreen() {
    val model = Shared()
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(text = model.greeting(), style = MaterialTheme.typography.headlineSmall)
            Text(
                text = model.subtitle(),
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
EOF

npm run android:compile >/dev/null

shot_mode="${RANGER_ANDROID_SHOT:-paparazzi}"
if [[ "$shot_mode" == "emulator" ]]; then
    for cmd in adb emulator avdmanager; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "error: $cmd not found" >&2
            exit 1
        fi
    done
    avd_name="${RANGER_ANDROID_AVD:-ranger_androidtest}"
    if ! avdmanager list avd 2>/dev/null | grep -q "Name: $avd_name"; then
        echo "error: AVD '$avd_name' not found" >&2
        exit 1
    fi
    npm run android:build >/dev/null
    adb start-server >/dev/null
    "$ANDROID_HOME/emulator/emulator" -avd "$avd_name" -no-window -no-audio -no-boot-anim \
        -gpu swiftshader_indirect -no-snapshot-save >"$emu_log" 2>&1 &
    emu_pid=$!
    boot_deadline=$((SECONDS + 300))
    adb wait-for-device
    while true; do
        boot=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
        if [[ "$boot" == "1" ]]; then
            break
        fi
        if (( SECONDS > boot_deadline )); then
            echo "error: emulator did not finish booting within 300s" >&2
            tail -20 "$emu_log" >&2
            exit 1
        fi
        sleep 2
    done
    npm run android:install >/dev/null
    adb shell am start -n com.example.androidtest/.MainActivity >/dev/null
    sleep 3
    adb exec-out screencap -p >"$work/screen.png"
else
    root_gradle="platforms/android/build.gradle.kts"
    app_gradle="platforms/android/app/build.gradle.kts"
    python3 - <<'PY'
from pathlib import Path

root = Path("platforms/android/build.gradle.kts")
app = Path("platforms/android/app/build.gradle.kts")
rt = root.read_text()
if "app.cash.paparazzi" not in rt:
    rt = rt.replace(
        'id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false',
        'id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false\n'
        '    id("app.cash.paparazzi") version "1.3.5" apply false',
        1,
    )
    root.write_text(rt)

text = app.read_text()
if "app.cash.paparazzi" not in text:
    text = text.replace(
        'id("org.jetbrains.kotlin.plugin.compose")',
        'id("org.jetbrains.kotlin.plugin.compose")\n    id("app.cash.paparazzi")',
        1,
    )
    text = text.replace(
        "buildFeatures { compose = true }",
        "buildFeatures { compose = true }\n"
        "    testOptions {\n"
        "        unitTests.isIncludeAndroidResources = true\n"
        "    }",
        1,
    )
    text = text.replace(
        "dependencies {",
        "dependencies {\n"
        '    testImplementation("app.cash.paparazzi:paparazzi:1.3.5")\n'
        '    testImplementation("junit:junit:4.13.2")',
        1,
    )
    app.write_text(text)
PY
    mkdir -p platforms/android/app/src/test/kotlin/com/example/androidtest
    cat > platforms/android/app/src/test/kotlin/com/example/androidtest/AppScreenshotTest.kt <<'EOF'
package com.example.androidtest

import app.cash.paparazzi.Paparazzi
import org.junit.Rule
import org.junit.Test

class AppScreenshotTest {
    @get:Rule
    val paparazzi = Paparazzi()

    @Test
    fun appScreen() {
        paparazzi.snapshot { AppScreen() }
    }
}
EOF
    node scripts/android-gradle.js :app:recordPaparazziDebug >/dev/null
    snap=$(find platforms/android/app/src/test/snapshots -name '*.png' | head -1)
    if [[ -z "$snap" || ! -f "$snap" ]]; then
        echo "error: Paparazzi did not write a snapshot PNG" >&2
        exit 1
    fi
    cp "$snap" "$work/screen.png"
fi

mkdir -p "$(dirname "$out")"
python3 "$here/scripts/wizard-shots/phone.py" \
    "$work/screen.png" "$out" \
    "androidtest — Compose"
