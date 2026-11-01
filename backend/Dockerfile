# syntax=docker/dockerfile:1
# Build outside the shared VPS. Pass --platform=linux/amd64 for staging.
ARG BUILD_IMAGE=eclipse-temurin:21-jdk-jammy@sha256:4b1a74fbffbe6b4e7b6f0171a472478282fb463790a51edf10e465d578f22b69
ARG RUNTIME_IMAGE=eclipse-temurin:21-jre-jammy@sha256:1eac8b8fee11ca7d6725a48bc5d41992ed1561504ebae25490d2d062847e8269
FROM ${BUILD_IMAGE} AS build
WORKDIR /workspace
COPY mvnw pom.xml ./
COPY .mvn/wrapper/maven-wrapper.properties .mvn/wrapper/maven-wrapper.properties
COPY src/main/ src/main/
COPY docker/Healthcheck.java docker/Healthcheck.java
RUN chmod 0755 mvnw \
    && ./mvnw -B -ntp -Dmaven.test.skip=true package \
    && mkdir /health \
    && javac --release 21 -d /health docker/Healthcheck.java

FROM ${RUNTIME_IMAGE} AS runtime
ARG VCS_REF=uncommitted
LABEL org.opencontainers.image.title="weDO backend" \
      org.opencontainers.image.source="https://github.com/HuyGiang1/weDO-app" \
      org.opencontainers.image.revision="${VCS_REF}"
RUN groupadd --gid 10001 wedo \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin wedo \
    && mkdir -p /opt/wedo/.local-media \
    && chown 10001:10001 /opt/wedo/.local-media
WORKDIR /opt/wedo
COPY --from=build /workspace/target/backend-0.0.1-SNAPSHOT.jar app.jar
COPY --from=build /health/ health/
USER 10001:10001
ENV SPRING_PROFILES_ACTIVE=staging \
    JAVA_TOOL_OPTIONS="-Xms128m -Xmx768m -XX:+ExitOnOutOfMemoryError"
EXPOSE 8080
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=20s --timeout=8s --start-period=120s --retries=4 \
    CMD ["java", "-Xms8m", "-Xmx32m", "-cp", "/opt/wedo/health", "Healthcheck"]
ENTRYPOINT ["java", "-jar", "/opt/wedo/app.jar"]
