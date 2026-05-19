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
subprojects {
    println("=== Subproject registered: ${project.name} ===")
    afterEvaluate {
        plugins.withId("com.android.library") {
            configure<com.android.build.gradle.BaseExtension> {
                println("=== Gradle Override (afterEvaluate): Setting compileSdkVersion to 36 for library subproject: ${project.name} ===")
                compileSdkVersion(36)
            }
        }
        plugins.withId("com.android.application") {
            configure<com.android.build.gradle.BaseExtension> {
                println("=== Gradle Override (afterEvaluate): Setting compileSdkVersion to 36 for application subproject: ${project.name} ===")
                compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
