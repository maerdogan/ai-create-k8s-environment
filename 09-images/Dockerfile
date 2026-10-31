# Base image for Java applications. The application adds /app/app.jar.
ARG ALPINE_VERSION=3.24.3
FROM alpine:${ALPINE_VERSION}

ARG IMAGE_ROLE=base
ARG JAVA_RAM_PCT=75

RUN apk add --no-cache openjdk17-jdk ca-certificates tzdata \
    && addgroup -S -g 10001 app \
    && adduser -S -D -H -u 10001 -G app app \
    && mkdir -p /app \
    && chown app:app /app

LABEL image.role="${IMAGE_ROLE}"
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=${JAVA_RAM_PCT} -XX:+ExitOnOutOfMemoryError"
WORKDIR /app
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
