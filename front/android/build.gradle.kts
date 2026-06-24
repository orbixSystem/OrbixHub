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

// Força Java 21 em todos os subprojetos (plugins incluídos) para evitar
// "Inconsistent JVM-target compatibility" quando um plugin define
// Kotlin jvmTarget=21 mas deixa Java no padrão 17.
subprojects {
    tasks.configureEach {
        if (this is JavaCompile) {
            sourceCompatibility = "21"
            targetCompatibility = "21"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
