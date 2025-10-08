# How to Upload This SSCCE to GitHub

## Option 1: Create New GitHub Repository

```bash
cd ~/projects/payara6-ibm-mq-sscce

# Initialize git
git init
git add .
git commit -m "Initial commit: Payara 6 MDB + External RA SSCCE"

# Create GitHub repository (via gh CLI or web interface)
gh repo create payara6-ibm-mq-sscce --public --source=. --remote=origin

# Push to GitHub
git push -u origin main
```

## Option 2: Create GitHub Gist

```bash
cd ~/projects/payara6-ibm-mq-sscce

# Create a tarball
tar -czf payara6-mdb-sscce.tar.gz \
  --exclude='.gradle' \
  --exclude='build' \
  --exclude='docker/payara/wmq.jakarta.jmsra.rar' \
  .

# Upload to GitHub Gist (via web interface)
# https://gist.github.com/
```

## Option 3: Attach to Payara Issue

1. Create tarball:
```bash
cd ~/projects/payara6-ibm-mq-sscce
tar -czf ../payara6-mdb-sscce.tar.gz \
  --exclude='.gradle' \
  --exclude='build' \
  --exclude='docker/payara/wmq.jakarta.jmsra.rar' \
  .
```

2. Attach `payara6-mdb-sscce.tar.gz` to GitHub issue

## Files Included in SSCCE

✅ Minimal MDB implementation (TestMessageBean.java)
✅ Standard deployment descriptors (ejb-jar.xml, glassfish-ejb-jar.xml)
✅ Docker Compose setup (Payara + IBM MQ)
✅ Gradle build configuration
✅ IBM MQ RA download script
✅ Verification commands
✅ Complete documentation (README.md)

## Files NOT Included (Downloaded Automatically)

- Gradle wrapper JAR (gradle-wrapper.jar) - Downloaded by gradlew
- IBM MQ Resource Adapter (.rar) - Downloaded by download-mq-rar.sh
- Docker images - Pulled by docker-compose

Total compressed size: ~10 KB (without build artifacts and RAR)

## Verification After Clone

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/payara6-ibm-mq-sscce.git
cd payara6-ibm-mq-sscce

# Download IBM MQ RAR
cd docker/payara && ./download-mq-rar.sh && cd ../..

# Build WAR
./gradlew build

# Start services
docker-compose up -d

# Wait for deployment
sleep 30

# Check if MDB was activated (EXPECTED TO FAIL)
docker logs payara 2>&1 | grep -i "TestMessageBean"
```

**Expected Result:** No output (MDB is silently ignored)

This confirms the bug is reproducible.
