# CI/CD-Pipeline der Luftschmaus GmbH

Installationsanleitung für eine containerbasierte CI/CD-Pipeline, die den vollständigen DevOps-Zyklus (von Code-Commit über automatisierte Tests und Container-Builds bis zum GitOps-Deployment auf Kubernetes) abbildet.

>[!IMPORTANT]
>Die gesamte Infrastruktur wurde auf **macOS** entwickelt und getestet. Unter Linux und Windows ist die Funktionsfähigkeit nicht vollständig verifiziert. Insbesondere müssen auf anderen Betriebssystemen ggf. alternative Tools eingesetzt werden (z.B. Docker Desktop und Minikube statt Colima)

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Phase 1: Umgebungsvariablen vorbereiten](#phase-1-umgebungsvariablen-vorbereiten)
- [Phase 2: Colima starten](#phase-2-colima-starten)
- [Phase 3: Forgejo starten und konfigurieren](#phase-3-forgejo-starten-und-konfigurieren)
  - [3.1 Admin-Benutzer erstellen](#31-admin-benutzer-erstellen)
  - [3.2 OAuth2-App für Woodpecker erstellen](#32-oauth2-app-für-woodpecker-erstellen)
  - [3.3 Repository von GitHub migrieren](#33-repository-von-github-migrieren)
- [Phase 4: Alle Docker-Compose-Services starten](#phase-4-alle-docker-compose-services-starten)
- [Phase 5: Woodpecker CI konfigurieren](#phase-5-woodpecker-ci-konfigurieren)
  - [5.1 In Woodpecker einloggen](#51-in-woodpecker-einloggen)
  - [5.2 Repository aktivieren](#52-repository-aktivieren)
  - [5.3 Agent-Verbindung prüfen](#53-agent-verbindung-prüfen)
  - [5.4 Harbor-Secrets in Woodpecker anlegen](#54-harbor-secrets-in-woodpecker-anlegen)
  - [5.5 Pipeline-Test](#55-pipeline-test)
- [Phase 6: Kubernetes (k3s) prüfen](#phase-6-kubernetes-k3s-prüfen)
  - [6.1 kubectl-Kontext prüfen](#61-kubectl-kontext-prüfen)
  - [6.2 Cluster verifizieren](#62-cluster-verifizieren)
- [Phase 7: Flux installieren](#phase-7-flux-installieren)
  - [7.1 Flux mit Image-Automation installieren](#71-flux-mit-image-automation-installieren)
  - [7.2 Warten bis alle Controller bereit sind](#72-warten-bis-alle-controller-bereit-sind)
  - [7.3 Installation prüfen](#73-installation-prüfen)
- [Phase 8: Kubernetes-Namespaces und Secrets erstellen](#phase-8-kubernetes-namespaces-und-secrets-erstellen)
  - [8.1 Namespaces erstellen](#81-namespaces-erstellen)
  - [8.2 Harbor-Pull-Secrets erstellen](#82-harbor-pull-secrets-erstellen)
- [Phase 9: External Secrets Operator und 1Password](#phase-9-external-secrets-operator-und-1password)
  - [9.1 1Password Service Account erstellen](#91-1password-service-account-erstellen)
  - [9.2 Secret-Item in 1Password anlegen](#92-secret-item-in-1password-anlegen)
  - [9.3 1Password-Token im Cluster hinterlegen](#93-1password-token-im-cluster-hinterlegen)
  - [9.4 ESO-Operator installieren](#94-eso-operator-installieren)
  - [9.5 ESO Custom Resources anwenden](#95-eso-custom-resources-anwenden)
  - [9.6 Secrets verifizieren](#96-secrets-verifizieren)
- [Phase 10: Flux-Source konfigurieren](#phase-10-flux-source-konfigurieren)
  - [10.1 Colima-Host-IP ermitteln](#101-colima-host-ip-ermitteln)
  - [10.2 Source-Manifest mit korrekter IP anwenden](#102-source-manifest-mit-korrekter-ip-anwenden)
  - [10.3 Konnektivität testen](#103-konnektivität-testen)
- [Phase 11: Flux-Manifeste anwenden](#phase-11-flux-manifeste-anwenden)
  - [11.1 Restliche Flux-Ressourcen erstellen](#111-restliche-flux-ressourcen-erstellen)
  - [11.2 Git-Source reconciliieren](#112-git-source-reconciliieren)
  - [11.3 Alle Flux-Ressourcen prüfen](#113-alle-flux-ressourcen-prüfen)
- [Phase 12: Deployment verifizieren](#phase-12-deployment-verifizieren)
  - [12.1 Pods prüfen](#121-pods-prüfen)
  - [12.2 Services prüfen](#122-services-prüfen)
  - [12.3 Anwendung im Browser aufrufen](#123-anwendung-im-browser-aufrufen)
- [Phase 13: End-to-End-Test](#phase-13-end-to-end-test)
  - [13.1 Code-Änderung durchführen](#131-code-änderung-durchführen)
  - [13.2 CI-Pipeline beobachten](#132-ci-pipeline-beobachten)
  - [13.3 Flux-Deployment beobachten](#133-flux-deployment-beobachten)
- [Phase 14: Teardown -- Alles zurücksetzen](#phase-14-teardown----alles-zurücksetzen)
  - [14.1 ESO-Ressourcen entfernen](#141-eso-ressourcen-entfernen)
  - [14.2 Flux deinstallieren](#142-flux-deinstallieren)
  - [14.3 Kubernetes-Namespaces löschen](#143-kubernetes-namespaces-löschen)
  - [14.4 Docker-Compose-Services stoppen](#144-docker-compose-services-stoppen)
  - [14.5 Colima stoppen und löschen](#145-colima-stoppen-und-löschen)
  - [14.6 Harbor aufräumen (optional)](#146-harbor-aufräumen-optional)
- [Zusammenfassung der Phasen](#zusammenfassung-der-phasen)
- [Monitoring mit Prometheus und Grafana (Optional)](#monitoring-mit-prometheus-und-grafana-optional)

## Voraussetzungen

Folgende Tools müssen installiert sein:

```
brew install colima docker kubectl fluxcd/tap/flux 1password-cli
```

Optional:
```
brew install jq watch
```

Zusätzlich wird ein [1Password-Account](https://1password.com/) mit einem Service Account benötigt (siehe Phase 9). Die `op` CLI muss mit dem Service Account authentifiziert sein (`op service-account ...`) oder über die 1Password-Desktop-App eingeloggt sein.

Zusätzlich werden `git` und `curl` benötigt, die auf macOS in der Regel vorinstalliert sind.

Außerdem wird benötigt:

- Ein Account auf https://demo.goharbor.io mit einem angelegten Projekt `luftschmaus`. Anleitung (Schritte 1-6) unter https://goharbor.io/docs/1.10/install-config/demo-server/ (Accounts werden nach zwei Tagen automatisch gelöscht).

---

## Phase 1: Umgebungsvariablen prüfen

Die `.env`-Datei ist Teil des Repositories und enthält `op://`-Referenzen auf 1Password. Alle Secrets werden zur Laufzeit von der `op` CLI aufgelöst.

```
WOODPECKER_AGENT_SECRET="op://luftschmaus/woodpecker/WOODPECKER_AGENT_SECRET"
WOODPECKER_FORGEJO_CLIENT="op://luftschmaus/woodpecker/WOODPECKER_FORGEJO_CLIENT"
WOODPECKER_FORGEJO_SECRET="op://luftschmaus/woodpecker/WOODPECKER_FORGEJO_SECRET"
```

Die Werte `WOODPECKER_FORGEJO_CLIENT` und `WOODPECKER_FORGEJO_SECRET` werden in Phase 3 in 1Password eingetragen.

Alle Befehle, die Umgebungsvariablen benötigen, werden mit `op run --env-file=.env --` ausgeführt. Damit löst die `op` CLI die `op://`-Referenzen auf und injiziert die Werte als Umgebungsvariablen. Für einzelne Werte (z.B. Harbor-Credentials) wird `op read` verwendet.

---

## Phase 2: Colima starten

```
colima start --kubernetes --cpu 4 --memory 8 --disk 40
```

Die Werte für CPU, Memory (GB) und Disk (GB) können je nach System angepasst werden. 4 CPUs und 8 GB RAM sind empfohlene Mindestwerte. 40 GB Disk reichen für die CI/CD-Pipeline ohne Monitoring. Bei Nutzung von Prometheus und Grafana (siehe [Monitoring](#monitoring-mit-prometheus-und-grafana-optional)) sollte der Wert auf 60 GB erhöht werden.

Prüfen:
```
docker info
kubectl get nodes
```

---

## Phase 3: Forgejo starten und konfigurieren

Zunächst nur Forgejo starten, da die OAuth2-Konfiguration vor Woodpecker erfolgen muss:

```
op run --env-file=.env -- docker compose up -d forgejo
```

Prüfen: http://localhost:3000 im Browser öffnen.

### 3.1 Admin-Benutzer erstellen

Vorab im 1Password-Vault `luftschmaus` ein Login-Item `Forgejo` mit folgenden Feldern anlegen:

- `username`
- `password`
- `E-Mail`

```
docker compose exec -T forgejo forgejo admin user create \
    --admin \
    --username "$(op read op://luftschmaus/Forgejo/username)" \
    --password "$(op read op://luftschmaus/Forgejo/password)" \
    --email "$(op read 'op://luftschmaus/Forgejo/E-Mail')" \
    --must-change-password=false
```

### 3.2 OAuth2-App für Woodpecker erstellen

```
OAUTH_RESPONSE=$(curl -sf -X POST "http://localhost:3000/api/v1/user/applications/oauth2" \
    -u "$(op read op://luftschmaus/Forgejo/username):$(op read op://luftschmaus/Forgejo/password)" \
    -H 'Content-Type: application/json' \
    -d '{"name":"Woodpecker","redirect_uris":["http://localhost:8000/authorize"],"confidential_client":true}')

echo "$OAUTH_RESPONSE" | jq .
```

Aus der Antwort `client_id` und `client_secret` auslesen und in 1Password im Item `woodpecker` (Vault `luftschmaus`) eintragen:

- `WOODPECKER_FORGEJO_CLIENT` = `client_id`
- `WOODPECKER_FORGEJO_SECRET` = `client_secret`

### 3.3 Repository von GitHub migrieren

```
curl -sf -X POST "http://localhost:3000/api/v1/repos/migrate" \
    -u "$(op read op://luftschmaus/Forgejo/username):$(op read op://luftschmaus/Forgejo/password)" \
    -H 'Content-Type: application/json' \
    -d '{"clone_addr":"https://github.com/hansdoebel/luftschmaus-webapp.git","repo_name":"luftschmaus-webapp","repo_owner":"luftschmaus","service":"github"}'
```

Prüfen: http://localhost:3000/luftschmaus/luftschmaus-webapp im Browser öffnen.

---

## Phase 4: Alle Docker-Compose-Services starten

Alle Services starten. `op run` löst die `op://`-Referenzen in `.env` auf und übergibt sie an Docker Compose:

```
op run --env-file=.env -- docker compose up -d
```

Prüfen ob alle Services laufen:
```
docker compose ps
```

Erwartete Services:
- `forgejo` (Port 3000)
- `woodpecker` (Port 8000)
- `woodpecker-agent`

Woodpecker benötigt eine funktionierende OAuth-Verbindung zu Forgejo. Falls Woodpecker nicht korrekt startet, die Logs prüfen:
```
docker compose logs woodpecker
```

---

## Phase 5: Woodpecker CI konfigurieren

### 5.1 In Woodpecker einloggen

http://localhost:8000 öffnen und über Forgejo-OAuth einloggen (Benutzer und Passwort entsprechen den in 1Password hinterlegten Forgejo-Credentials).

### 5.2 Repository aktivieren

In Woodpecker `luftschmaus/luftschmaus-webapp` über "Repositorys" > "Repository hinzufügen" aktivieren.

### 5.3 Agent-Verbindung prüfen

Der Agent verbindet sich über das `WOODPECKER_AGENT_SECRET` (Shared Secret, in Phase 1 gesetzt) automatisch mit dem Server. Unter http://localhost:8000/admin/agents sollte ein verbundener Agent sichtbar sein.

Falls der Agent dort nicht erscheint, kann alternativ ein agent-spezifischer Token verwendet werden:
1. http://localhost:8000/admin/agents öffnen
2. Neuen Agent erstellen
3. Den angezeigten Token kopieren und in 1Password im Item `woodpecker` (Vault `luftschmaus`) als `WOODPECKER_AGENT_TOKEN` eintragen. Zusätzlich in `.env` die Zeile `WOODPECKER_AGENT_TOKEN="op://luftschmaus/woodpecker/WOODPECKER_AGENT_TOKEN"` ergänzen.
4. Agent neu starten: `op run --env-file=.env -- docker compose up -d woodpecker-agent`

### 5.4 Harbor-Secrets in Woodpecker anlegen

In Woodpecker unter "Repository-Einstellungen" > "Geheimnisse" zwei Secrets erstellen:

| Name | Wert | Events |
|---|---|---|
| `harbor_username` | Harbor-Benutzername | Push, Manuell |
| `harbor_password` | Harbor-Passwort | Push, Manuell |

oder über die CLI. Dafür muss die CLI zunächst konfiguriert werden:

```
export WOODPECKER_SERVER=http://localhost:8000
export WOODPECKER_TOKEN=<API-Token aus http://localhost:8000/user#api>
```

Secrets anlegen:

```
woodpecker-cli repo secret add \
    --repository luftschmaus/luftschmaus-webapp \
    --name harbor_username \
    --value "$(op read op://luftschmaus/harbor/username)" \
    --event push --event manual

woodpecker-cli repo secret add \
    --repository luftschmaus/luftschmaus-webapp \
    --name harbor_password \
    --value "$(op read op://luftschmaus/harbor/password)" \
    --event push --event manual
```

### 5.5 Pipeline-Test

Einen Test-Commit in Forgejo erstellen (z.B. README bearbeiten) oder die Pipeline manuell über die Woodpecker-Oberfläche starten.

Prüfen ob die Pipeline durchläuft: http://localhost:8000

---

## Phase 6: Kubernetes prüfen

Der k3s-Cluster wurde bereits mit Colima in Phase 2 gestartet.

### 6.1 kubectl-Kontext prüfen

```
kubectl config get-contexts
```

Der aktive Kontext muss `colima` sein. Falls nicht:
```
kubectl config use-context colima
```

### 6.2 Cluster verifizieren

```
kubectl cluster-info
kubectl get nodes
```

---

## Phase 7: Flux installieren

### 7.1 Flux mit Image-Automation installieren

```
flux install --components-extra=image-reflector-controller,image-automation-controller
```

### 7.2 Warten bis alle Controller bereit sind

```
kubectl -n flux-system wait --for=condition=ready pod --all --timeout=120s
```

### 7.3 Installation prüfen

```
flux check
```

Alle Controller müssen `deployment ready` anzeigen:
- `helm-controller`
- `image-automation-controller`
- `image-reflector-controller`
- `kustomize-controller`
- `notification-controller`
- `source-controller`

>[!NOTE]
>Falls `flux check` eine Warnung zur Kubernetes-Version anzeigt (z.B. "does not match >=1.33.0"), kann diese ignoriert werden, solange alle Controller `deployment ready` melden. Die Versionsabweichung entsteht, weil Colima eine eigene k3s-Version bündelt, die nicht zwingend der von Flux geforderten Mindestversion entspricht.

---

## Phase 8: Kubernetes-Namespaces und Secrets erstellen

### 8.1 Namespaces erstellen

```
kubectl create namespace luftschmaus-dev
kubectl create namespace luftschmaus-staging
kubectl create namespace luftschmaus-production
```

### 8.2 Harbor-Pull-Secrets erstellen

Secrets werden in allen Namespaces benötigt (`flux-system` für Image-Scanning, die drei Umgebungs-Namespaces für Pod-Image-Pull). Die Harbor-Credentials werden per `op read` direkt aus 1Password gelesen:

```
for ns in flux-system luftschmaus-dev luftschmaus-staging luftschmaus-production; do
    kubectl create secret docker-registry harbor-credentials \
        --docker-server=demo.goharbor.io \
        --docker-username="$(op read op://luftschmaus/harbor/username)" \
        --docker-password="$(op read op://luftschmaus/harbor/password)" \
        -n "$ns"
done
```

---

## Phase 9: External Secrets Operator und 1Password

Der External Secrets Operator (ESO) synchronisiert Secrets aus dem 1Password Service Account in den Kubernetes-Cluster. Das Datenbank-Secret `database-credentials` wird damit automatisch erstellt und aktuell gehalten.

### 9.1 1Password Service Account erstellen

1. In der 1Password-Admin-Konsole unter "Developer" > "Infrastructure Secrets" einen neuen **Service Account** erstellen (z.B. `luftschmaus-eso`)
2. Einen **Vault** `luftschmaus` erstellen und dem Service Account Zugriff gewähren
3. Den **Service-Account-Token** kopieren (beginnt mit `ops_...`)

### 9.2 Secret-Items in 1Password anlegen

Im Vault `luftschmaus` zwei Items erstellen:

**Item `luftschmaus-database`**:
- `POSTGRES_USER` = `luftschmaus`
- `POSTGRES_PASSWORD` = das gewünschte DB-Passwort
- `POSTGRES_DB` = `luftschmaus`

**Login-Item `harbor`**:
- `user` = Harbor-Benutzername
- `password` = Harbor-Passwort

**Item `woodpecker`:**
- `WOODPECKER_AGENT_SECRET` = Shared Secret für den Woodpecker-Agent
- `WOODPECKER_FORGEJO_CLIENT` = OAuth2 Client-ID (wird in Phase 3.2 eingetragen)
- `WOODPECKER_FORGEJO_SECRET` = OAuth2 Client-Secret (wird in Phase 3.2 eingetragen)

### 9.3 1Password-Token im Cluster hinterlegen

```
for ns in luftschmaus-dev luftschmaus-staging luftschmaus-production; do
    kubectl create secret generic onepassword-token \
        --namespace="$ns" \
        --from-literal=token="$(op read op://dev/service-account-token-devops/credential)"
done
```

Dies ist der einzige manuelle Secret-Schritt. Alle weiteren Secrets werden von ESO automatisch verwaltet.

### 9.4 ESO-Operator installieren

Die Flux-Ressourcen für den ESO-Operator anwenden:

```
kubectl apply -f kubernetes/infrastructure/external-secrets/repositories.yml
kubectl apply -f kubernetes/infrastructure/external-secrets/deployment-crds.yml
kubectl apply -f kubernetes/infrastructure/external-secrets/deployment.yml
kubectl apply -f kubernetes/infrastructure/external-secrets/deployment-crs.yml
```

Warten bis die CRDs und der Operator bereit sind:

```
kubectl -n flux-system wait --for=condition=ready helmrelease/external-secrets --timeout=120s
```

### 9.5 ESO Custom Resources anwenden

SecretStore und ExternalSecret erstellen:

```
kubectl apply -f kubernetes/infrastructure/external-secrets/crs/secret-store.yml
kubectl apply -f kubernetes/infrastructure/external-secrets/crs/database-credentials.yml
```

### 9.6 Secrets verifizieren

```
kubectl get externalsecret -A
kubectl get secret database-credentials -n luftschmaus-dev
```

Der ExternalSecret-Status sollte `SecretSynced` anzeigen. Die Secret-Werte sollten den in 1Password hinterlegten Werten entsprechen:

```
kubectl get secret database-credentials -n luftschmaus-dev -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

---

## Phase 10: Flux-Source konfigurieren

### 10.1 Colima-Host-IP ermitteln

Flux-Pods können Docker-Compose-Services nicht über deren Service-Namen erreichen. Stattdessen wird die Colima-Host-IP verwendet:

```
COLIMA_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Colima-IP: ${COLIMA_IP}"
```

### 10.2 Source-Manifest mit korrekter IP anwenden

Die Datei `kubernetes/flux/source.yml` enthält die Platzhalter `COLIMA_IP`, `FORGEJO_USERNAME` und `FORGEJO_PASSWORD`. Statt die Datei permanent zu ändern, werden die Platzhalter per Pipe ersetzt und direkt angewendet:

```
sed "s|COLIMA_IP|${COLIMA_IP}|; s|FORGEJO_USERNAME|$(op read op://luftschmaus/Forgejo/username)|; s|FORGEJO_PASSWORD|$(op read op://luftschmaus/Forgejo/password)|" \
    kubernetes/flux/source.yml | kubectl apply -f -
```

So bleibt die Originaldatei unverändert und enthält weiterhin die Platzhalter für zukünftige Installationen.

### 10.3 Konnektivität testen

Prüfen ob Forgejo von K8s-Pods aus erreichbar ist:

```
kubectl run test --rm -it --restart=Never --image=busybox -- wget -q -O - --timeout=5 http://${COLIMA_IP}:3000 2>&1 | head -5
```

Es sollten die ersten Zeilen von Forgejos HTML-Seite zurückkommen.

---

## Phase 11: Flux-Manifeste anwenden

### 11.1 Restliche Flux-Ressourcen erstellen

Die Git-Source wurde bereits in Phase 10.2 angewendet. Die restlichen Manifeste einzeln anwenden, dabei `source.yml` auslassen (da sie den Platzhalter `COLIMA_IP` enthält):

```
kubectl apply -f kubernetes/flux/image-backend.yml
kubectl apply -f kubernetes/flux/image-frontend.yml
kubectl apply -f kubernetes/flux/image-update-automation.yml
kubectl apply -f kubernetes/flux/kustomization-dev.yml
kubectl apply -f kubernetes/flux/kustomization-staging.yml
kubectl apply -f kubernetes/flux/kustomization-production.yml
```

### 11.2 Git-Sources reconciliieren

```
flux reconcile source git luftschmaus-webapp-dev -n flux-system
flux reconcile source git luftschmaus-webapp-main -n flux-system
```

Erwartete Ausgabe:
```
✔ fetched revision develop@sha1:<commit-hash>
✔ fetched revision main@sha1:<commit-hash>
```

### 11.3 Alle Flux-Ressourcen prüfen

```
flux get all -n flux-system
```

Alle Ressourcen müssen `READY: True` anzeigen:
- `gitrepository/luftschmaus-webapp-dev`
- `gitrepository/luftschmaus-webapp-main`
- `imagerepository/backend`
- `imagerepository/frontend`
- `imagepolicy/backend-dev`, `imagepolicy/backend-staging`, `imagepolicy/backend-production`
- `imagepolicy/frontend-dev`, `imagepolicy/frontend-staging`, `imagepolicy/frontend-production`
- `imageupdateautomation/luftschmaus-dev`, `imageupdateautomation/luftschmaus-staging`
- `kustomization/luftschmaus-dev`, `kustomization/luftschmaus-staging`, `kustomization/luftschmaus-production`

---

## Phase 12: Deployment verifizieren

### 12.1 Pods prüfen

```
kubectl get pods -n luftschmaus-dev
kubectl get pods -n luftschmaus-staging
kubectl get pods -n luftschmaus-production
```

Erwartete Pods pro Namespace (alle `Running`):
- `backend-<hash>`
- `db-<hash>`
- `frontend-<hash>`

In `luftschmaus-production` jeweils 2 Replicas für Frontend und Backend.

### 12.2 Services prüfen

```
kubectl get svc -n luftschmaus-dev
```

### 12.3 Anwendung im Browser aufrufen

Die Umgebungen sind über NodePort-Services erreichbar:
- Development: http://COLIMA_IP:30080
- Staging: http://COLIMA_IP:30081
- Production: http://COLIMA_IP:30082

Alternativ per Port-Forward:

```
kubectl port-forward svc/frontend 8080:80 -n luftschmaus-dev
```

Luftschmaus-Webanwendung öffnen: http://localhost:8080

>[!NOTE]
>Der Port-Forward wird beendet, sobald Flux neue Pods ausrollt. Nach einem Update den Befehl erneut ausführen.

---

## Phase 13: End-to-End-Test

### 13.1 Code-Änderung durchführen

Eine Datei im Forgejo-Repository bearbeiten (z.B. frontend/app.js über die Web-Oberfläche unter: http://localhost:3000/luftschmaus/luftschmaus-webapp/src/branch/main/frontend/src/App.jsx)

### 13.2 CI-Pipeline beobachten

http://localhost:8000 öffnen. Die Pipeline sollte automatisch starten und folgende Schritte durchlaufen:
1. `clone` -- Repository klonen
2. `lint` -- ESLint ausführen
3. `test-frontend` + `test-backend` (parallel) -- Tests ausführen
4. `build-and-push-backend` + `build-and-push-frontend` -- Docker-Images bauen und nach Harbor pushen

### 13.3 Flux-Deployment beobachten

Flux erkennt die neuen Image-Tags in Harbor, aktualisiert die Kubernetes-Manifeste in Git und rollt neue Pods aus. Um den Prozess zu beschleunigen, kann manuell reconciliert werden:

```
flux reconcile image repository backend -n flux-system
flux reconcile image repository frontend -n flux-system
flux reconcile image update luftschmaus-dev -n flux-system
flux reconcile image update luftschmaus-staging -n flux-system
flux reconcile kustomization luftschmaus-dev -n flux-system
flux reconcile kustomization luftschmaus-staging -n flux-system
flux reconcile kustomization luftschmaus-production -n flux-system
```

Prüfen ob die neuen Pods ausgerollt wurden:

```
flux get image policy -n flux-system
kubectl get pods -n luftschmaus-dev
kubectl get pods -n luftschmaus-staging
```

Die Image-Tags der Pods sollten dem neuesten CI-Pipeline-Tag entsprechen (Format: `<Pipeline-Nr>-<Commit-SHA>`).

---

## Phase 14: Teardown -- Alles zurücksetzen

Zum vollständigen Aufräumen alle Ressourcen in umgekehrter Reihenfolge entfernen.

### 14.1 ESO-Ressourcen entfernen

```
kubectl delete -f kubernetes/infrastructure/external-secrets/crs/
kubectl delete -f kubernetes/infrastructure/external-secrets/deployment-crs.yml
kubectl delete -f kubernetes/infrastructure/external-secrets/deployment.yml
kubectl delete -f kubernetes/infrastructure/external-secrets/deployment-crds.yml
kubectl delete -f kubernetes/infrastructure/external-secrets/repositories.yml
kubectl delete secret onepassword-token -n luftschmaus-dev
kubectl delete secret onepassword-token -n luftschmaus-staging
kubectl delete secret onepassword-token -n luftschmaus-production
```

### 14.2 Flux deinstallieren

```
flux uninstall --silent
```

### 14.3 Kubernetes-Namespaces löschen

```
kubectl delete namespace luftschmaus-dev luftschmaus-staging luftschmaus-production
```

Alternativ kann mit `colima kubernetes reset` der gesamte k3s-Cluster zurückgesetzt werden, ohne Colima selbst zu löschen.

### 14.4 Docker-Compose-Services stoppen

```
docker compose down -v
```

Das Flag `-v` entfernt alle zugehörigen Volumes (Forgejo-Daten, Woodpecker-Daten). Ohne `-v` bleiben die Volumes erhalten und können beim nächsten Start wiederverwendet werden.

### 14.5 Colima stoppen und löschen

```
colima stop
colima delete
```

`colima delete` entfernt die gesamte VM inklusive k3s-Cluster. Bei einem erneuten Setup muss Colima in Phase 2 neu gestartet werden.

### 14.6 Harbor aufräumen (optional)

Images im Harbor-Projekt `luftschmaus` können über die Web-Oberfläche unter https://demo.goharbor.io manuell gelöscht werden.

---

## Zusammenfassung der Phasen

| Phase | Beschreibung | Prüfung |
|---|---|---|
| 1 | Umgebungsvariablen | `.env` mit `op://`-Referenzen vorhanden |
| 2 | Colima starten | `kubectl get nodes` -- Ready |
| 3 | Forgejo starten und konfigurieren | Admin-User, OAuth-App, Repository |
| 4 | Alle Services starten | `docker compose ps` -- 3 Services |
| 5 | Woodpecker konfigurieren | Pipeline in http://localhost:8000 sichtbar |
| 6 | Kubernetes prüfen | `kubectl get nodes` -- Ready |
| 7 | Flux installieren | `flux check` -- alle Controller Ready |
| 8 | Namespaces + Secrets | `kubectl get ns` -- drei luftschmaus-Namespaces |
| 9 | ESO + 1Password | `kubectl get externalsecret -A` -- SecretSynced |
| 10 | Flux-Source konfigurieren | Konnektivitätstest erfolgreich |
| 11 | Flux-Manifeste anwenden | `flux get all` -- alle Ready |
| 12 | Deployment verifizieren | 3 Pods Running, Frontend im Browser |
| 13 | End-to-End-Test | Code-Änderung löst CI + CD aus |
| 14 | Teardown | Alle Ressourcen entfernt, sauberer Zustand |

---

## Monitoring mit Prometheus und Grafana (Optional)

Die CI/CD-Pipeline funktioniert ohne Monitoring. Um Prometheus und Grafana zu ergänzen, folgende Services in `docker-compose.yml` unter `services:` hinzufügen:

```yaml
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - luftschmaus
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_USER: ${GF_SECURITY_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GF_SECURITY_ADMIN_PASSWORD}
    depends_on:
      - prometheus
    networks:
      - luftschmaus
    restart: unless-stopped
```

Zusätzlich die Volumes `prometheus_data` und `grafana_data` unter `volumes:` ergänzen. Die mitgelieferte `prometheus.yml` im Root-Verzeichnis enthält eine vorkonfigurierte Konfiguration.

Nach `op run --env-file=.env -- docker compose up -d` sind die Services erreichbar:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (Login mit den in 1Password hinterlegten Grafana-Credentials)
