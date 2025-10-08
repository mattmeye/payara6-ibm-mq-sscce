plugins {
    id("war")
    java
}

group = "test"
version = "1.0.0"

repositories {
    mavenCentral()
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

dependencies {
    // Jakarta EE 10 API (provided by Payara)
    compileOnly("jakarta.platform:jakarta.jakartaee-api:10.0.0")
}

tasks.war {
    archiveFileName.set("test-mdb.war")
}
