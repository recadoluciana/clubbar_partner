import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()

val keystorePropertiesFile =
    rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile)
    )
}

android {
    namespace = "br.com.clubbar.partner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "br.com.clubbar.partner"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "ambiente"

    productFlavors {
        create("dev") {
            dimension = "ambiente"

            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"

            resValue(
                type = "string",
                name = "app_name",
                value = "Clubbar Partner",
            )
        }

        create("prod") {
            dimension = "ambiente"

            resValue(
                type = "string",
                name = "app_name",
                value = "Clubbar Partner",
            )
        }
    }

    signingConfigs {
        create("release") {
            keyAlias =
                keystoreProperties["keyAlias"] as String

            keyPassword =
                keystoreProperties["keyPassword"] as String

            storeFile = file(
                keystoreProperties["storeFile"] as String
            )

            storePassword =
                keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig =
                signingConfigs.getByName("debug")
        }

        getByName("release") {
            signingConfig =
                signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    applicationVariants.all {
        val flavor = flavorName
        val build = buildType.name
        val apkName = "partner-$flavor-$build.apk"

        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = apkName
        }

        assembleProvider.configure {
            doLast {
                val sourceApk = layout.buildDirectory
                    .file("outputs/apk/$flavor/$build/$apkName")
                    .get()
                    .asFile
                val flutterOutputDir = layout.buildDirectory
                    .dir("outputs/flutter-apk")
                    .get()
                    .asFile

                flutterOutputDir.mkdirs()
                sourceApk.copyTo(flutterOutputDir.resolve(apkName), overwrite = true)
            }
        }
    }
}

flutter {
    source = "../.."
}
