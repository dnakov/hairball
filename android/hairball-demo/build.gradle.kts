import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.compose")
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_21)
    }
}

android {
    namespace = "io.github.sigkitten.hairball.demo"
    compileSdk = providers.gradleProperty("ANDROID_COMPILE_SDK").get().toInt()

    defaultConfig {
        applicationId = "io.github.sigkitten.hairball.demo"
        minSdk = providers.gradleProperty("ANDROID_MIN_SDK").get().toInt()
        targetSdk = providers.gradleProperty("ANDROID_TARGET_SDK").get().toInt()
        versionCode = 1
        versionName = providers.gradleProperty("VERSION_NAME").get()
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    packaging {
        resources {
            excludes += "/META-INF/DEPENDENCIES"
            excludes += "/META-INF/LICENSE"
            excludes += "/META-INF/LICENSE*"
            excludes += "/META-INF/NOTICE"
            excludes += "/META-INF/NOTICE*"
        }
    }
}

dependencies {
    implementation(project(":hairball-core"))
    implementation(project(":hairball-compose"))

    implementation(platform("androidx.compose:compose-bom:2026.01.00"))
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.0")
}
