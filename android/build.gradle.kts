allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// ── Normalize every plugin's compileSdk to 36 ──────────────────────────────
// Plugins pin conflicting SDK levels:
//   • `printing` pins compileSdk 30, but its AndroidX deps require 34+
//   • `sqflite_android` 2.4.3 uses API-36 symbols (VERSION_CODES.BAKLAVA,
//     Locale.of, Thread.threadId) and REQUIRES compileSdk 36
// 36 is the only value that satisfies all plugins (and is installed locally).
// Reflection keeps this compatible across AGP versions. This block MUST be
// registered before `evaluationDependsOn(":app")` triggers early evaluation.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            setter?.invoke(androidExt, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
