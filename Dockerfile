FROM  tomcat:9.0.96-jdk17
COPY target/petclinic.war /usr/local/tomcat/webapps
EXPOSE 8080
CMD ["catalina.sh", "run"]
