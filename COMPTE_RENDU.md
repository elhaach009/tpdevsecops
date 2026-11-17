# Compte rendu – TP3 : Analyse statique (SAST) avec SonarCloud

Projet : `democyber` (Spring Boot 3.3, Java 21) – dépôt `elhaach009/tpdevsecops`

## 1. Rôle de SonarQube / SonarCloud dans une pipeline DevSecOps

SonarCloud est l'outil de **SAST** (Static Application Security Testing) et de qualité de code de la pipeline. Il analyse le **code source** sans l'exécuter et détecte :

- les **vulnérabilités** (injections, crypto faible, désérialisation, etc.) et les **Security Hotspots** (code sensible à revoir manuellement) ;
- les **bugs** (erreurs de logique, NullPointerException potentielles, ressources non fermées) ;
- les **code smells** (dette technique, complexité, duplication) ;
- la **couverture de tests**, ici grâce au rapport JaCoCo.

Son intérêt en DevSecOps est le **shift-left** : les problèmes sont détectés à chaque push / Pull Request, avant la construction de l'image et le déploiement. Le **Quality Gate** sert de point de contrôle automatique. Avec `-Dsonar.qualitygate.wait=true`, un Quality Gate en échec fait échouer le job `sonarcloud`, ce qui **bloque** le job `build-and-deploy` (build et push Docker). L'analyse des PR (décoration de la PR GitHub) se concentre sur le **nouveau code** (approche « Clean as You Code »).

## 2. Statut final de l'analyse

| Analyse | Quality Gate | Détail |
|---|---|---|
| Pull Request #2 | ✅ **Passed** (`OK`) | Les 5 conditions du Quality Gate sont respectées |
| Branche `main` (après merge) | ✅ **Passed** (`OK`) | Mêmes 5 conditions respectées, mêmes valeurs |

Conditions évaluées sur le nouveau code (API `qualitygates/project_status`) :

| Condition | Seuil d'échec | Valeur obtenue | Statut |
|---|---|---|---|
| Reliability Rating (nouveau code) | pire que A | A | OK |
| Security Rating (nouveau code) | pire que A | A | OK |
| Maintainability Rating (nouveau code) | pire que A | A | OK |
| Lignes dupliquées (nouveau code) | > 3 % | 0,0 % | OK |
| Security Hotspots revus | < 100 % | 100 % | OK |

**Pourquoi Passed :** l'application est très petite (une classe principale avec un contrôleur « Bonjour » imbriqué). Elle ne contient aucune vulnérabilité, aucun bug, aucun code smell, aucun hotspot de sécurité et aucune duplication. Toutes les notes sont donc à A.

## 3. Notes Security / Reliability / Maintainability

Valeurs issues de l'API `measures/component` (notes 1–5 converties en A–E). Elles sont identiques pour la PR #2 et pour la branche `main` après le merge :

| Domaine | Note | Nombre de problèmes |
|---|---|---|
| Security | **A** (1.0) | 0 vulnérabilité, 0 Security Hotspot |
| Reliability | **A** (1.0) | 0 bug |
| Maintainability | **A** (1.0) | 0 code smell |
| Couverture de tests | 60,0 % | – |
| Duplication | 0,0 % | – |

La couverture de 60 % vient des deux tests : `contextLoads()` démarre le contexte Spring et `rootReturnsGreeting()` appelle `GET /` via MockMvc. Le contrôleur est donc couvert. Les lignes non couvertes correspondent à la méthode `main()` (`SpringApplication.run`), qui n'est jamais exécutée par les tests `@SpringBootTest`.

## 4. Règles à ajouter au Quality Gate (point de vue responsable sécurité)

Le Quality Gate actuel (dérivé de « Sonar way ») ne contient **aucune condition de couverture**. De plus, il ne porte que sur le nouveau code. En tant que responsable sécurité, j'ajouterais :

| Règle proposée | Justification |
|---|---|
| **Vulnérabilités (code global) = 0**, ou Security Rating global = A | Le gate actuel ne regarde que le nouveau code. Une vulnérabilité ancienne pourrait rester en production indéfiniment. |
| **Coverage sur nouveau code ≥ 80 %** | Un code non testé est un code dont on ne vérifie pas le comportement, y compris les contrôles de sécurité (authentification, validation des entrées). Aujourd'hui une PR sans aucun test passerait. |
| **Security Hotspots Reviewed = 100 % sur tout le code** (pas seulement le nouveau) | Garantit qu'aucun point sensible (crypto, CORS, regex, cookies…) n'a été ignoré. |
| **Blocker / Critical issues = 0** | Toute issue bloquante ou critique, qu'elle soit de sécurité ou de fiabilité, doit stopper le déploiement. |
| **Reliability Rating global = A** | Un bug (NPE, ressource non fermée) peut provoquer un déni de service. |
| Garder **Duplication nouveau code ≤ 3 %** | Le code dupliqué duplique aussi les failles et rend les correctifs incomplets. |

Ces conditions restent compatibles avec le blocage automatique : un échec fait tomber le job `sonarcloud`, donc il n'y a pas de push d'image Docker.

## 5. Différence Trivy / Gitleaks / SonarCloud

| Critère | Gitleaks | SonarCloud | Trivy |
|---|---|---|---|
| Type | Secret scanning | SAST + qualité de code | SCA + scan d'images / IaC |
| Ce qui est analysé | Historique Git et fichiers (texte) | Code source Java (et autres langages) | Dépendances (pom.xml, jar), image Docker, OS de base, Dockerfile, IaC |
| Ce qui est détecté | Clés API, tokens, mots de passe commités | Vulnérabilités dans **notre** code, bugs, code smells, hotspots, couverture | CVE connues dans les **composants tiers** et l'image, mauvaises configurations, secrets |
| Moment dans la pipeline | Tout premier job (`secret-scan`) | Après le scan de secrets, avant le build Docker | Après le build de l'image, avant le push |
| Exemple | Un `SONAR_TOKEN` en clair dans un fichier | Requête SQL concaténée, NPE, mot de passe codé en dur | CVE de Log4Shell dans une dépendance, OpenSSL vulnérable dans l'image de base |
| Dans ce TP | ✅ en place (TP2) | ✅ en place (TP3) | Non encore intégré |

Les trois outils sont **complémentaires** : Gitleaks protège les secrets, SonarCloud protège le code que l'on écrit, Trivy protège ce que l'on embarque (dépendances et image).

## 6. Étapes réalisées

1. **SonarCloud** : création de l'organisation `elhaach009` et du projet `elhaach009_tpdevsecops`. L'*Automatic Analysis* est désactivée, car l'analyse est faite par la CI.
2. **Secrets GitHub** : `SONAR_TOKEN`, `SONAR_ORGANIZATION` et `SONAR_PROJECT_KEY` sont créés avec `gh secret set` et ne sont jamais écrits en clair dans le dépôt.
3. **`pom.xml`** : ajout du plugin **JaCoCo** (`prepare-agent` + `report` en phase `verify`), de `sonar.host.url`, de `sonar.coverage.jacoco.xmlReportPaths` et de la version du `sonar-maven-plugin`.
4. **Workflow `.github/workflows/ci.yml`** : ajout du job `sonarcloud`, puis chaînage `secret-scan` → `sonarcloud` → `build-and-deploy`.
5. **Correction** : le premier run a échoué avec une erreur `403` (token / projet SonarCloud non configuré). Après correction côté SonarCloud et nouveau token, le run est passé. `actions/cache` a aussi été mis à jour en v5 (fin de Node 20 sur les runners).
6. **Pull Request #2** : analyse de la PR, Quality Gate **Passed**.
7. **Merge dans `main`** : nouvelle analyse de la branche principale, Quality Gate **Passed**, puis build et push de l'image Docker.

Workflow final (job SonarCloud) :

```yaml
  sonarcloud:
    needs: secret-scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: '21'
          cache: maven
      - uses: actions/cache@v5
        with:
          path: ~/.sonar/cache
          key: ${{ runner.os }}-sonar
          restore-keys: ${{ runner.os }}-sonar
      - name: Build, tests, couverture et analyse SonarCloud
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_ORGANIZATION: ${{ secrets.SONAR_ORGANIZATION }}
          SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
        run: >
          mvn -B verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar
          -Dsonar.organization="$SONAR_ORGANIZATION"
          -Dsonar.projectKey="$SONAR_PROJECT_KEY"
          -Dsonar.qualitygate.wait=true

  build-and-deploy:
    needs: sonarcloud
    # ... build Maven, build/test/push de l'image Docker
```

Liens :

- Pull Request : https://github.com/elhaach009/tpdevsecops/pull/2
- Run GitHub Actions (PR, Quality Gate Passed) : https://github.com/elhaach009/tpdevsecops/actions/runs/44058577229
- Run GitHub Actions (`main` après merge, Quality Gate Passed + push Docker) : https://github.com/elhaach009/tpdevsecops/actions/runs/44059750471
- Projet SonarCloud : https://sonarcloud.io/project/overview?id=elhaach009_tpdevsecops
- Analyse SonarCloud de la PR : https://sonarcloud.io/dashboard?id=elhaach009_tpdevsecops&pullRequest=2
