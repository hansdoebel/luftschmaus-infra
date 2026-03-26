# Luftschmaus CI/CD-Pipeline

Teil der Fallstudie "Konzeption, Implementierung und Evaluation einer CI/CD-Pipeline für den Webshop der Luftschmaus GmbH auf Basis von GitOps".

Infrastruktur für den Webshop der Luftschmaus GmbH. Dieses Repository enthält die Docker-Compose-Konfiguration und Kubernetes-Manifeste für die CI/CD-Toolchain. 

Die zugehörige Webanwendung, die von dieser Pipeline gebaut und bereitgestellt wird, befindet sich im separaten Repository: [luftschmaus-webapp](https://github.com/hansdoebel/luftschmaus-webapp)

## Installationsanleitung

Die vollständige Installationsanleitung befindet sich in der [INSTALL.md](INSTALL.md).

## DevOps-Phasen

Dieses Projekt bildet die folgenden Phasen des DevOps-Lebenszyklus ab:

| Phase       | Umsetzung                                                                            |
|-------------|--------------------------------------------------------------------------------------|
| **Plan**    | Anforderungsanalyse, Toolauswahl und Architekturentscheidungen im Bericht der Fallstudie dokumentiert |
| **Code**    | Versionierung auf Forgejo                                      |
| **Build**   | Multi-Stage Docker-Images für Frontend und Backend, gebaut in der CI-Pipeline        |
| **Test**    | Automatisierte Lint-, Frontend- und Backend-Tests via Woodpecker CI                  |
| **Release** | Container-Images werden zum Harbor Demo Server gepusht und versioniert               |
| **Deploy**  | Kubernetes-Deployments mit FluxCD für automatisches GitOps-basiertes Rollout         |
| **Operate** | Kubernetes orchestriert die Anwendung, Docker Compose für lokale Infrastruktur |
| **Monitor** | (Optional) Prometheus sammelt Metriken, Grafana visualisiert DORA-Metriken und Pipeline-KPIs |

## Services

| Service | Beschreibung |
|---|---|
| Forgejo | Self-hosted Git-Server (Repository-Management, Webhooks) |
| Woodpecker CI | Container-native CI-Engine mit Forgejo-Integration |
| Harbor | Container-Registry (Projekt `luftschmaus`) |
| Kubernetes (k3s) | Integrierter K8s-Cluster via Colima für CD-Deployments |
| FluxCD | GitOps-Controller für automatisches Deployment |
| External Secrets Operator | Synchronisiert Secrets aus 1Password in den Cluster |
| 1Password | Zentraler Secrets-Provider für alle Credentials |
| Prometheus | Metrik-Erfassung und Monitoring |
| Grafana | Visualisierung von DORA-Metriken und Pipeline-KPIs |


## Service-URLs

| Service | URL |
|---|---|
| Forgejo | http://localhost:3000 |
| Woodpecker CI | http://localhost:8000 |
| Frontend | http://localhost:8080 |
| Backend | http://localhost:3000/health |
| Grafana | http://localhost:3001 |
| Prometheus | http://localhost:9090 |
| Harbor Registry | https://demo.goharbor.io |

## Lizenz

MIT