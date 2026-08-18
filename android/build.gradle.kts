buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

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
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.matching { it.name == "compileDebugJavaWithJavac" }.configureEach {
        dependsOn(project.tasks.matching { it.name == "compileDebugKotlin" })
    }
    tasks.matching { it.name == "compileReleaseJavaWithJavac" }.configureEach {
        dependsOn(project.tasks.matching { it.name == "compileReleaseKotlin" })
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
