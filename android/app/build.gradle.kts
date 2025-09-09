import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ok aquí con AGP 8+
}

android {
    namespace = "com.example.despedida_pau"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.despedida_pau" // <-- tu paquete final
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Si minSdk < 21 y pasas de 64K métodos, activa multidex:
        // multiDexEnabled = true
    }

    // --- Firma de RELEASE (lee key.properties) ---
    val keystoreProperties = Properties()
    val keystorePropertiesFile: File = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }


    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false       // empieza sin ofuscar
            isShrinkResources = false     // y sin shrink; ya optimizarás después
            // si activas proguard, añade reglas para Firebase/Glide/etc.
        }
        debug {
            signingConfig = signingConfigs.getByName("release") // opcional: firma debug con la misma, útil para pruebas FCM
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

    // NDK no es necesario a menos que lo uses explícitamente
    // ndkVersion = "27.0.12077973"
}

flutter { source = "../.." }

dependencies {
    // BoM de Firebase: alinea versiones
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // SDKs que usas
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics") // opcional, pero útil

    // Desugaring (ya activado arriba)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Multidex si lo activas en defaultConfig:
    // implementation("androidx.multidex:multidex:2.0.1")
}
