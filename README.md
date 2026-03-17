# Scalingo Buildpack for the JDK

This is the official [Scalingo
buildpack](https://doc.scalingo.com/platform/deployment/buildpacks) for
[OpenJDK](http://openjdk.java.net/). It only installs the JDK, and does not
build an application. It is used by the
[Java](https://github.com/Scalingo/java-buildpack),
[Java WAR](https://github.com/Scalingo/java-war-buildpack),
[Gradle](https://github.com/Scalingo/gradle-buildpack), and
[Scala](https://github.com/Scalingo/scala-buildpack) buildpacks.

## Standalone Usage

This buildpack is useful when your app needs OpenJDK installed but doesn't
require a build tool like Maven, Gradle, sbt, or Leiningen. Common use cases
include:

- Your app needs OpenJDK as a dependency (for example, to run Java-based tools)
- You're deploying a locally built JAR file to Scalingo (see [our
  documentation](https://doc.scalingo.com/platform/deployment/deploy-java-jar-war))

To set this buildpack for your app:

```shell
scalingo env-set BUILDPACK_URL=https://github.com/Scalingo/buildpack-jvm-common
```

Then it may be used by itself, or with another buildpack using [multiple
buildpacks](https://doc.scalingo.com/platform/deployment/buildpacks/multi).

## Usage from a Buildpack

> [!NOTE]
> This section is for buildpack developers, not buildpack users.

This buildpack can be used as a library by other buildpacks to install OpenJDK.
The official Scalingo buildpacks for JVM languages and build tools use this
buildpack in the same manner. This pattern is useful for third-party buildpacks
that need OpenJDK since there is no mechanism to declare buildpack
dependencies. Using this buildpack as a library ensures consistent OpenJDK
behavior and versioning on Scalingo.

```bash
# Determine the root directory of your own (host) buildpack
HOST_BUILDPACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

JVM_BUILDPACK_URL="https://buildpacks-repository.s3.eu-central-1.amazonaws.com/jvm.tgz"

mkdir -p /tmp/jvm-common
curl --silent --fail --retry 3 --retry-connrefused --connect-timeout 5 \
    --location "${JVM_BUILDPACK_URL}" \
    | tar --extract --gzip --touch --directory=/tmp/jvm-common --strip-components=1

# Source in a sub-shell to keep your buildpack's environment clean
( source /tmp/jvm-common/bin/java \
    && install_openjdk "${BUILD_DIR}" "${HOST_BUILDPACK_DIR}" )

# Source the export file to get environment variables like JAVA_HOME and PATH
source "${HOST_BUILDPACK_DIR}/export"
```

## License

Licensed under the MIT License. See LICENSE file.
