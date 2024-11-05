FROM tomcat:9.0-jdk17
RUN groupadd -r appgroup && useradd -r -g appgroup -m -d /app appuser
RUN chown -R appuser:appgroup /usr/local/tomcat
WORKDIR /app
COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw
USER appuser
COPY src ./src
EXPOSE 8080
CMD ["./mvnw", "jetty:run-war"]
