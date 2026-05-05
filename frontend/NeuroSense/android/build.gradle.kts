allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    plugins.withId("com.android.library") {
        tasks.configureEach {
            if (name.contains("extractDebugAnnotations") || name.contains("extractReleaseAnnotations")) {
                actions.clear()
                doLast {
                    for (file in outputs.files) {
                        if (file.name.endsWith(".zip")) {
                            file.parentFile.mkdirs()
                            java.util.zip.ZipOutputStream(java.io.FileOutputStream(file)).close()
                        } else if (!file.exists() && file.isDirectory) {
                            file.mkdirs()
                        } else if (!file.exists()) {
                            file.parentFile.mkdirs()
                            file.createNewFile()
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
