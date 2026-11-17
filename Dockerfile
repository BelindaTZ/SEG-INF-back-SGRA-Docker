FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml ./
COPY src ./src
RUN mvn -B -ntp -DskipTests package \
    && cp target/Backend-*.jar /app/sgra.jar

FROM eclipse-temurin:21-jre-noble
ARG PG_MAJOR=18
ENV TZ=America/Guayaquil
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl fontconfig fonts-dejavu-core \
    && install -d -m 0755 /usr/share/postgresql-common/pgdg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    && printf '%s\n' 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main' \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "postgresql-client-${PG_MAJOR}" \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system sgra \
    && useradd --system --gid sgra --home-dir /app sgra \
    && install -d -o sgra -g sgra /var/lib/sgra/backups
WORKDIR /app
COPY --from=build /app/sgra.jar ./sgra.jar
USER sgra
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s \
  CMD curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/auth/me | grep -qx 401
ENTRYPOINT ["java", "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED", "-jar", "/app/sgra.jar"]
