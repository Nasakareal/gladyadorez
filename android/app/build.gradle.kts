plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")      // <-- Firebase
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "mx.utmorelia.sistema_afiliados_app"

    // Usa los valores que expone el plugin de Flutter
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    // ===== Firma release desde key.properties =====
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] ?: "")
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            } else {
                // Fallback para compilar si no hay keystore (NO subir a tienda así)
                storeFile = null
            }
        }
    }

    defaultConfig {
        applicationId = "mx.utmorelia.sistema_afiliados_app"

        // Firebase Messaging requiere minSdk >= 23
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion

        // Toma versionCode/versionName del pubspec.yaml
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            // debug firmado con debug (por defecto)
        }
        getByName("release") {
            // Activa cuando tengas keystore:
            signingConfig = signingConfigs.getByName("release")

            // Ajusta cuando quieras ofuscar
            isMinifyEnabled = false
            isShrinkResources = false

            // (Opcional) reglas proguard si activas minify:
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    // (Opcional) evitar conflictos de empaquetado
    packaging {
        resources {
            // excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // (No necesitas agregar libs de Firebase aquí: FlutterFire las trae vía Gradle)
}
