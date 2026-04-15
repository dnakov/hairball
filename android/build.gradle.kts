plugins {
    id("com.android.application") version "8.13.0" apply false
    id("com.android.library") version "8.13.0" apply false
    id("com.vanniktech.maven.publish") version "0.36.0" apply false
    kotlin("android") version "2.2.21" apply false
    kotlin("jvm") version "2.2.21" apply false
    kotlin("plugin.compose") version "2.2.21" apply false
}

allprojects {
    group = providers.gradleProperty("POM_GROUP_ID").get()
    version = providers.gradleProperty("VERSION_NAME").get()
}
