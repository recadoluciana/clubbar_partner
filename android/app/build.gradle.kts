plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.clubbar_admin"
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
        applicationId = "br.com.clubbar.admin"

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
                value = "Clubbar Admin DEV",
            )
        }

        create("prod") {
            dimension = "ambiente"

            resValue(
                type = "string",
                name = "app_name",
                value = "Clubbar Admin",
            )
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            /*
             * Temporariamente assina o release com a chave de debug.
             *
             * Isso permite gerar e instalar o APK para testes.
             * Antes de publicar na Play Store, configure uma chave
             * própria de produção.
             */
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}