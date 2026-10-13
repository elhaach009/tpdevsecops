# Image d'exécution : JRE 21 seulement (plus légère et avec moins de surface d'attaque qu'un JDK)
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

# Utilisateur non-root (bonne pratique de sécurité)
RUN groupadd --system spring && useradd --system --gid spring spring

# Le jar est produit au préalable par "mvn clean package"
COPY target/democyber-0.0.1-SNAPSHOT.jar app.jar

USER spring:spring

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
