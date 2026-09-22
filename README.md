# Git-based Configuration Management Lab

Ett enkelt configuration management-projekt byggt med Git, Bash, cron och Apache på openSUSE Leap 16.

Projektet automatiserar deployment av en webbsida från ett GitHub-repository till en Apache-webbserver.

## Mål

Målet är att skapa ett enkelt automatiserat flöde där:

1. En ändring görs lokalt eller direkt i GitHub-repot.
2. Ändringen committas och pushas till GitHub.
3. Servern hämtar senaste versionen automatiskt.
4. Ett Bash-script deployar filen till Apache.
5. Cron kör deploymenten enligt ett schema.

Flödet ser ut så här:

```text
lokal ändring
  ↓
git add / commit / push
  ↓
GitHub
  ↓
cron
  ↓
deploy.sh
  ↓
git pull
  ↓
/srv/www/htdocs/index.html
  ↓
Apache
```

För att tydligt testa automationen kan en ändring också göras direkt på GitHub. Då verifieras att servern kan uppdateras utan manuell handpåläggning lokalt.

## Teknik

Projektet använder:

- openSUSE Leap 16
- Git
- GitHub
- Bash
- cron
- Apache
- SSH
- sudoers

## Projektstruktur

```text
config-project/
├── deploy.sh
├── index.html
└── README.md
```

## Deployment-script

`deploy.sh` hämtar senaste versionen från GitHub och kopierar sedan `index.html` till Apaches DocumentRoot.

```bash
#!/bin/bash
set -e

/usr/bin/git -C /home/db/config-project pull --ff-only origin main
/usr/bin/sudo /usr/bin/cp /home/db/config-project/index.html /srv/www/htdocs/index.html
```

### Förklaring

`set -e` gör att scriptet avslutas direkt om ett kommando misslyckas.

`git pull --ff-only` hämtar senaste ändringarna från GitHub men försöker inte automatiskt skapa en merge om Git-historiken har divergerat.

## Cron

Deploymenten körs automatiskt var femte minut.

```cron
*/5 * * * * /home/db/config-project/deploy.sh >> /home/db/config-project/deploy.log 2>&1
```

Cron-raden betyder:

```text
*/5  = var femte minut
*    = varje timme
*    = varje dag
*    = varje månad
*    = varje veckodag
```

All output och eventuella fel sparas i:

```text
/home/db/config-project/deploy.log
```

Loggen kan kontrolleras med:

```bash
tail -20 ~/config-project/deploy.log
```

eller följas live med:

```bash
tail -f ~/config-project/deploy.log
```

## SSH och GitHub

VM:n använder en separat SSH-nyckel för kommunikation med GitHub.

SSH-konfigurationen ligger i:

```text
~/.ssh/config
```

Exempel:

```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_config_project
    IdentitiesOnly yes
```

Det gör att Git automatiskt använder rätt SSH-nyckel vid kommunikation med GitHub.

SSH-anslutningen kan testas med:

```bash
ssh -T git@github.com
```

## Begränsad sudo

Apache-katalogen `/srv/www/htdocs/` kräver förhöjda rättigheter för att skriva filer.

Eftersom cron inte kan skriva in ett sudo-lösenord används en begränsad sudoers-regel.

```text
db ALL=(root) NOPASSWD: /usr/bin/cp /home/db/config-project/index.html /srv/www/htdocs/index.html
```

Regeln tillåter endast det specifika `cp`-kommandot som behövs för deploymenten.

Regeln ligger i:

```text
/etc/sudoers.d/config-project
```

och kan redigeras med:

```bash
sudo visudo -f /etc/sudoers.d/config-project
```

## Test av lösenordsfri sudo

För att verifiera att cron kan köra kopieringen utan manuell lösenordsinmatning användes:

```bash
sudo -k
sudo -n /usr/bin/cp /home/db/config-project/index.html /srv/www/htdocs/index.html
```

`sudo -k` rensar eventuell cachad sudo-autentisering.

`sudo -n` gör att sudo inte får fråga efter lösenord.

Om kommandot körs utan output eller fel fungerar sudoers-regeln som tänkt.

## GitHub-repository

Det lokala Git-repot kopplades till ett remote repository på GitHub.

Remote kan kontrolleras med:

```bash
git remote -v
```

Projektet pushades med:

```bash
git push -u origin main
```

Det lokala repot spårar därefter `origin/main`.

## Manuellt deployment-test

Innan cron aktiverades testades hela flödet manuellt.

`index.html` ändrades i GitHub till:

```html
<h1>Version 3 automatiskt från GitHub</h1>
```

På VM:n kördes sedan:

```bash
./deploy.sh
```

och resultatet verifierades med:

```bash
curl http://localhost
```

Resultat:

```html
<h1>Version 3 automatiskt från GitHub</h1>
```

Det visade att flödet fungerade:

```text
GitHub
  ↓
git pull
  ↓
deploy.sh
  ↓
Apache
```

## Automatisk deployment med cron

Efter att den manuella deploymenten fungerade lades scriptet in i användaren `db`:s crontab.

Crontab öppnades med:

```bash
crontab -e
```

Cronjobbet:

```cron
*/5 * * * * /home/db/config-project/deploy.sh >> /home/db/config-project/deploy.log 2>&1
```

Cron-tjänsten kontrollerades med:

```bash
systemctl status cron
```

och var:

```text
active (running)
```

## Sluttest

För att verifiera att deploymenten fungerade helt automatiskt ändrades `index.html` direkt på GitHub till:

```html
<h1>Version 4 automatiskt via cron</h1>
```

Ingen manuell `git pull` eller körning av `deploy.sh` gjordes på servern.

Efter nästa cron-körning verifierades resultatet med:

```bash
curl http://localhost
```

Resultat:

```html
<h1>Version 4 automatiskt via cron</h1>
```

Loggen visade samtidigt att cron hade hämtat den nya committen och gjort en fast-forward update.

Det bekräftade att hela kedjan fungerade automatiskt.

## Felsökning

### Git kördes som root

Ett problem uppstod när `deploy.sh` tidigare kördes med:

```bash
sudo ./deploy.sh
```

Det innebar att `git pull` kördes som root.

Filen:

```text
.git/FETCH_HEAD
```

blev då ägd av:

```text
root root
```

vilket gjorde att användaren `db` inte längre kunde köra `git pull`.

Problemet identifierades med:

```bash
ls -ld .git
ls -l .git/FETCH_HEAD
```

och löstes genom att återställa ägarskapet:

```bash
sudo chown -R db:db /home/db/config-project/.git
```

Efter detta fungerade:

```bash
git pull --ff-only origin main
```

igen.

Det blev ett tydligt exempel på varför Git-operationer normalt inte bör köras som root.

Endast de kommandon som faktiskt kräver förhöjda rättigheter bör använda `sudo`.

## Lärdomar

Projektet gav praktisk erfarenhet av:

- Git för versionshantering
- GitHub som remote repository
- SSH-nycklar för autentisering
- Git över SSH
- `git pull`
- `git push`
- Bash-script
- `set -e`
- `git pull --ff-only`
- schemaläggning med cron
- Apache
- DocumentRoot
- Linux filrättigheter
- filägarskap
- sudo
- sudoers
- begränsad lösenordsfri sudo
- loggning av automatiserade jobb
- felsökning av SSH och Git
- varför Git-operationer inte bör köras som root

Projektet visar också hur flera separata Linux-komponenter kan kombineras till ett enkelt automatiserat configuration management-flöde.

## Säkerhetsaspekter

Några säkerhetsprinciper som används i projektet:

- SSH används i stället för lösenordsbaserad Git-autentisering.
- En separat SSH-nyckel används för projektets GitHub-kommunikation.
- Privat SSH-nyckel lagras inte i Git-repot.
- Lösenordsfri sudo begränsas till ett specifikt kommando.
- Git körs som vanlig användare.
- Endast kopieringen till Apaches DocumentRoot körs med förhöjda rättigheter.
- Deployment-scriptet avbryts om ett kommando misslyckas.
- `git pull --ff-only` används för att undvika automatiska merge-operationer i deployment-scriptet.

## Möjlig vidareutveckling

### Steg 2

Deploya webbsidan till en separat Linux-server via SSH.

Planerat upplägg:

```text
Dell / VM
   ↓
GitHub
   ↓
cron + Bash
   ↓
SSH
   ↓
MSI-lab
   ↓
Apache
```

Det gör lösningen mer realistisk eftersom deployment då sker till en annan fysisk maskin.

### Steg 3

Byta ut GitHub mot en egen Git-server med Gitea.

```text
Gitea
  ↓
cron
  ↓
Bash
  ↓
Apache
```

### Vidare utveckling

Möjliga framtida förbättringar:

- Gitea
- MySQL
- Nginx reverse proxy
- separat deployment-server
- flera Linux-servrar
- central configuration management
- rollback vid fel
- validering innan deployment
- backup innan deployment
- bättre loggning
- notifiering vid misslyckad deployment
- systemd timer i stället för cron
- deployment till flera servrar via SSH

## Sammanfattning

Projektet demonstrerar ett enkelt automatiserat configuration management-flöde där GitHub används som central källa för konfigurationen.

En ändring kan göras lokalt och pushas till GitHub, eller göras direkt på GitHub för att tydligt testa automationen. Servern hämtar sedan ändringen automatiskt via cron och Git, varefter ett Bash-script deployar filen till Apache.

```text
GitHub
  ↓
cron
  ↓
Bash
  ↓
Git
  ↓
sudo
  ↓
Apache
```

Slutresultatet är en fungerande automatiserad deployment där en ändring i GitHub kan publiceras på webbservern utan manuell handpåläggning på servern.
