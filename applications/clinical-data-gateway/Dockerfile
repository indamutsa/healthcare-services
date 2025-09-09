# Clinical Data Gateway Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /app

# Copy Maven wrapper + pom first for better caching
COPY mvnw .
COPY mvnw.cmd .
COPY .mvn .mvn
COPY pom.xml .

# Pre-download deps (cached if pom.xml unchanged)
RUN chmod +x ./mvnw && ./mvnw -B dependency:go-offline

# Copy sources and build
COPY src src
RUN ./mvnw -B clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-jammy AS runtime

# Add non-root user
RUN useradd -u 1001 -m -s /usr/sbin/nologin clinical

# Install curl for health checks
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mkdir -p /app/logs && chown -R clinical:clinical /app

# Copy the built JAR
COPY --from=build /app/target/*.jar /app/app.jar
RUN chown clinical:clinical /app/app.jar

USER clinical

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENV SPRING_PROFILES_ACTIVE=development
ENV JAVA_OPTS="-Xmx512m -Xms256m"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
