# SSCCE Updates und Korrekturen

## Wichtige Änderungen

### 1. TestMessageBean.java - Property hinzugefügt ✅

Die fehlende `connectionFactoryLookup` Property wurde hinzugefügt:

```java
@ActivationConfigProperty(
    propertyName = "connectionFactoryLookup",
    propertyValue = "jms/MQConnectionFactory"
)
```

**Grund:** Ohne diese Property versucht der MDB, sich mit Default-Einstellungen (localhost:1414) zu verbinden,
anstatt die konfigurierte ConnectionFactory (jms/MQConnectionFactory → ibm-mq:1414) zu verwenden.

### 2. IBM MQ Docker Setup

#### Für Apple Silicon (ARM64)

Custom Image muss gebaut werden. Siehe `docker/ibm-mq/README.md`.

**Quick Start:**
```bash
cd /tmp
git clone --depth 1 https://github.com/ibm-messaging/mq-container.git
cd mq-container
make build-devserver
```

#### Für AMD64 (Intel/AMD)

Siehe Anleitung in `docker/ibm-mq/README.md` wie das Dockerfile anzupassen ist.

### 3. IBM MQ Security-Konfiguration (Manueller Schritt)

Nach dem Container-Start muss IBM MQ für Development konfiguriert werden:

```bash
docker exec ibm-mq bash -c "cat > /tmp/config.mqsc << 'EOF'
ALTER QMGR CHLAUTH(DISABLED)
ALTER QMGR CONNAUTH(' ')
REFRESH SECURITY TYPE(CONNAUTH)
DEFINE CHANNEL('DEV.APP.SVRCONN') CHLTYPE(SVRCONN) REPLACE
EOF
runmqsc QM1 < /tmp/config.mqsc"

# Payara neu starten
docker-compose restart payara
```

⚠️ **Warnung:** Diese Konfiguration deaktiviert Authentifizierung. Nur für Development!

## Verwendung

### Schnellstart

```bash
# 1. Projekt bauen
./gradlew build

# 2. Container starten
env DOCKER_BUILDKIT=0 docker-compose up -d

# 3. Auf MQ warten und konfigurieren
sleep 30
docker exec ibm-mq bash -c "cat > /tmp/config.mqsc << 'EOF'
ALTER QMGR CHLAUTH(DISABLED)
ALTER QMGR CONNAUTH(' ')
REFRESH SECURITY TYPE(CONNAUTH)
DEFINE CHANNEL('DEV.APP.SVRCONN') CHLTYPE(SVRCONN) REPLACE
EOF
runmqsc QM1 < /tmp/config.mqsc"

# 4. Payara neu starten
docker-compose restart payara

# 5. Warten und prüfen
sleep 30
docker logs payara 2>&1 | grep -i TestMessageBean
```

### Automatischer Test

```bash
./test.sh
```

Das Skript führt alle Schritte automatisch aus und zeigt den Status an.

## Ergebnis der Analyse

### ❌ Ursprüngliche Behauptung

> "MDB is completely ignored (silent failure)"

### ✅ Tatsächliches Verhalten

Der MDB wird **NICHT ignoriert**. Payara:
- ✅ Erkennt den MDB
- ✅ Versucht ihn zu aktivieren
- ✅ Bindet ihn an den Resource Adapter
- ❌ Scheitert an **Konfigurationsproblemen** (nicht an Payara Bugs)

### Probleme die behoben wurden

1. ✅ Fehlende `connectionFactoryLookup` Property → **BEHOBEN**
2. ✅ ARM64 Docker Image Kompatibilität → **BEHOBEN**
3. ⚠️ IBM MQ Security-Konfiguration → **Workaround vorhanden**

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `test.sh` | Automatischer Test-Durchlauf |
| `docker/ibm-mq/README.md` | IBM MQ Docker Setup (ARM64 + AMD64) |
| `ANALYSIS.md` | Detaillierte Analyse der Probleme |
| `README-UPDATES.md` | Dieses Dokument |

## Nächste Schritte

### Option A: SSCCE optimieren

Für ein sauberes SSCCE sollte:
1. IBM MQ Security-Konfiguration automatisiert werden
2. Original README aktualisiert werden
3. Deployment-Reihenfolge-Probleme gelöst werden

### Option B: Alternativen-Check

Falls das Problem trotz aller Fixes weiterhin besteht:
1. Prüfen ob es ein Timing-Problem ist
2. Prüfen ob andere ActivationConfig Properties benötigt werden
3. Payara Debug-Logs aktivieren für detailliertere Informationen

## Kontakt

Bei Fragen zum Setup oder zu den Änderungen:
- Siehe `ANALYSIS.md` für technische Details
- Siehe `docker/ibm-mq/README.md` für Docker Setup
- Siehe `test.sh` für automatische Tests

---

**Hinweis:** Diese Analyse zeigt, dass kein Payara Bug vorliegt, sondern Konfigurationsprobleme im ursprünglichen SSCCE.
