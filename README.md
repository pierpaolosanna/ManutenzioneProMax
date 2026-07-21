PRO MAX Maintenance v3.1.0
⚠️ Utilizzare a proprio rischio. Nessuna garanzia espressa o implicita.
Use at your own risk. No warranties expressed or implied.

All-in-one Windows maintenance and diagnostics tool with a modern dark GUI.
Portable, no installation required. Now with modular architecture for easier maintenance and updates.

https://img.shields.io/badge/PowerShell-7.x-blue?logo=powershell
https://img.shields.io/badge/Platform-Windows%252010%2520%257C%252011-0078D6?logo=windows
https://img.shields.io/badge/License-MIT-green
https://img.shields.io/badge/Version-3.1.0-brightgreen

📋 Descrizione
Manutenzione PRO MAX è uno strumento completo di manutenzione e diagnostica per Windows, progettato con un'interfaccia moderna e scura. Tutte le funzionalità sono organizzate in categorie con tooltip esplicativi per guidare l'utente.

🆕 Novità della v3.1.0 (Architettura Modulare)
✅ Architettura modulare: Script suddiviso in moduli separati (.psm1) per ogni area funzionale

✅ Nuovo modulo Core: Centralizza logging, UI e utility di base

✅ Scansione Rete Pro: Nuovo strumento avanzato con supporto SNMP per MAC su reti multi-subnet

✅ Blacklist Check: Modalità fallback integrata (senza download automatico da GitHub)

✅ Colori nei log: I risultati Blacklist Check mostrano "SEGNALATO" in rosso e "PULITO" in verde

✅ Ping Test: Risolto il problema di visualizzazione dei tempi di risposta

✅ Full Update: Esclusione automatica delle cartelle backup* durante il backup

✅ Modulo Sicurezza: Corretto il caricamento e tutte le funzioni associate

✅ Manutenzione semplificata: Ogni modulo è indipendente e facilmente aggiornabile

✨ Caratteristiche Principali
🔄 Aggiornamenti (Modulo Upgrade.psm1)
Funzione	Descrizione	Tooltip
Eleva Admin	Riavvia lo script con privilegi amministrativi per sbloccare tutte le funzionalità	✅
Crea Ripristino	Crea un punto di ripristino del sistema prima di eseguire modifiche	✅
Winget	Aggiorna tutti i programmi installati tramite Winget (gestore pacchetti Windows)	✅
Store	Aggiorna tutte le app del Microsoft Store	✅
Cerca WU	Cerca gli aggiornamenti disponibili per Windows Update	✅
Installa WU	Scarica e installa tutti gli aggiornamenti di Windows in sospeso	✅
Driver	Aggiorna driver via Windows Update	✅
Full Update Script	Aggiorna FORZATAMENTE TUTTI i file del repository (script, moduli, batch, README, license)	✅
UPGRADE TOTAL	Esegue la sequenza completa di aggiornamento (Winget, Store, WU, Pulizia, Flush DNS)	✅
🧹 Pulizia (Modulo Pulizia.psm1)
Funzione	Descrizione	Tooltip
Temp	Pulisce le cartelle temporanee del sistema e dell'utente	✅
Disk Cleanup	Avvia lo strumento di pulizia disco di Windows (richiede admin)	✅
Pulisci Log	Pulisce i file di log e dump di sistema	✅
Analisi Disco	Analisi dettagliata dello spazio occupato su tutti i dischi	✅
🌐 Rete (Modulo Rete.psm1)
Funzione	Descrizione	Tooltip
Flush DNS	Svuota la cache DNS per risolvere problemi di risoluzione dei nomi	✅
Renew IP	Rinnova l'indirizzo IP della scheda di rete	✅
Info IP	Mostra tutte le informazioni di configurazione di rete	✅
Winsock	Resetta lo stack Winsock e il protocollo IP	✅
Reset Rete	Reset completo dello stack di rete con backup delle configurazioni	✅
Wi-Fi Pass	Visualizza le password salvate delle reti Wi-Fi	✅
Ping Test	Esegue un test di latenza verso Google, Cloudflare e OpenDNS	✅
Speed Internet	Test velocità Cloudflare (ping, download, upload)	✅
Speed Ookla	Test approfondito Ookla (download, upload, latenza, jitter, packet loss)	✅
Traceroute	Traccia il percorso dei pacchetti verso un IP o dominio	✅
Cambia DNS	Modifica i server DNS (Google, Cloudflare, OpenDNS, Quad9 o personalizzato)	✅
Whois	Mostra informazioni sul proprietario di un IP o dominio	✅
Blacklist Check	Verifica se un dominio/IP è segnalato in blacklist (con colori rosso/verde)	✅
Scansione Rete Pro	Avvia lo strumento avanzato di scansione rete con supporto SNMP	✅
🔧 Riparazione (Modulo Riparazione.psm1)
Funzione	Descrizione	Tooltip
SFC + DISM	Esegue SFC /scannow e DISM per riparare i file di sistema danneggiati	✅
Pt. Ripristino	Crea un punto di ripristino del sistema (limite 24 ore)	✅
🛡️ Sicurezza (Modulo Sicurezza.psm1)
Funzione	Descrizione	Tooltip
Scan Defender	Avvia una scansione rapida con Windows Defender	✅
Event Log	Mostra gli ultimi errori critici del registro eventi (7gg)	✅
Health Check	Verifica integrità critica del sistema (SFC, DISM, eventi, memoria)	✅
📊 Diagnostica (Modulo Diagnostica.psm1)
Funzione	Descrizione	Tooltip
Info Sistema	Mostra informazioni dettagliate su hardware e sistema operativo	✅
Batteria	Genera un report sulla salute della batteria (solo su portatili)	✅
Uptime	Visualizza da quanto tempo il sistema è in esecuzione	✅
Top Processi	Elenca i processi che consumano più CPU	✅
Startup	Elenca i programmi avviati automaticamente all'avvio	✅
Spazio Disco	Analizza lo spazio occupato dalle cartelle principali dell'utente	✅
Servizi	Controlla lo stato dei servizi di sistema principali	✅
⚙️ Sistema (Modulo Sistema.psm1)
Funzione	Descrizione	Tooltip
Ottimizza Visivi	Ottimizza gli effetti visivi di Windows per migliorare le prestazioni	✅
Ottimizza Avvio	Ottimizza servizi e avvio del sistema	✅
CPU Unlock	Sblocca le opzioni avanzate di gestione energia della CPU	✅
TPM CPU RAM	Rimuove le limitazioni per l'upgrade a Windows 11 su hardware non supportato	✅
Riavvia PC	Riavvia il sistema dopo 5 secondi	✅
🏢 Dominio (Modulo Dominio.psm1)
Funzione	Descrizione	Tooltip
Info Dominio	Mostra informazioni sul dominio e PC (nome, DC, foresta)	✅
Test DC	Test ping ai Domain Controller	✅
Sincronizza Ora	Sincronizza orario con Domain Controller	✅
Flush Kerberos	Svuota cache ticket Kerberos	✅
Info GPO	Mostra le GPO applicate al computer e all'utente	✅
Reset Profilo	Reimposta profilo di rete (Winsock, TCP/IP, IP)	⚠️ Disconnette brevemente
Test DNS	Verifica risoluzione DNS del dominio	✅
Info Sito AD	Mostra il sito Active Directory corrente	✅
Test LDAP	Verifica connettività LDAP al dominio	✅
Cambia Password	Cambia password dell'utente nel dominio	✅
Ultimo Login	Mostra ultimo login, data password e scadenza	✅
Gruppi Utente	Mostra i gruppi di cui l'utente è membro	✅
💾 Backup (Modulo Backup.psm1)
Funzione	Descrizione	Tooltip
Backup Files	Backup .zip con esclusione automatica delle cartelle backup*	✅
Backup Avanzato (7z)	Backup 7-Zip con compressione massima, esclude backup*	✅
Crea Ripristino	Crea un punto di ripristino del sistema	✅
🔒 Privacy (Modulo Privacy.psm1)
Funzione	Descrizione	Tooltip
Privacy Windows	Disabilita telemetria, Cortana, segnalazione errori Windows	✅
Privacy Office	Disabilita telemetria e invio dati di Office	✅
Privacy Edge	Disabilita telemetria, suggerimenti e personalizzazione di Edge	✅
Privacy Task	Disabilita attività pianificate di telemetria	✅
DISABILITA TUTTO	Esegue TUTTE le privacy in sequenza e propone riavvio	✅
🧰 Utility (Modulo Utility.psm1)
Funzione	Descrizione	Tooltip
Riavvia su BIOS	Riavvia il PC direttamente nel BIOS/UEFI	✅
Riavvia PC	Riavvia il computer immediatamente	✅
Disconnetti Utente	Disconnette l'utente corrente	✅
Arresta PC	Spegne il computer immediatamente	✅
Shutdown Sched.	Programma lo spegnimento forzato del PC ogni giorno	✅
Rimuovi Shutdown	Rimuove il task di spegnimento programmato	✅
AI Chat	Apre il dialogo AI Chat (Gemini, Groq, Cloudflare, Bynara)	✅
Ricerca File	Apre il dialogo di ricerca rapida file e contenuti	✅
Annulla	Annulla l'operazione in corso in modo sicuro	✅
Assist. Remota	Scarica e avvia RustDesk per assistenza remota	✅
Assist. LAN	Avvia TightVNC Viewer portatile per assistenza in LAN	✅
RDP LAN	Gestisce, salva e avvia sessioni Desktop Remoto	✅
🤖 AI Chat (Modulo AICHAT.ps1)
Funzione	Descrizione
Provider	Supporto per Gemini, Groq, Cloudflare e Bynara
Modelli	Ogni provider ha una lista di modelli selezionabili
Agenti	Carica automaticamente i file .md dalla cartella Prompt/ come System Prompt
Salva Agente	Salva il prompt corrente come nuovo agente su disco
Ricerca Web	Integra DDG e Wikipedia per risposte aggiornate
Allegati	Supporta PDF, DOC, DOCX, XLS, XLSX e testuali
Statistiche	Mostra i token utilizzati per sessione e per modello
🔍 Ricerca File (Modulo Search.ps1)
Funzione	Descrizione
Ricerca per Nome	Cerca file in base al pattern del nome
Ricerca per Contenuto	Cerca testo all'interno dei file
Ricerca Duplicati	Trova file duplicati tramite hash MD5
Ricerca File Grandi	Trova file con dimensione superiore a una soglia (default 100 MB)
Ricorsiva	Opzione per cercare nelle sottocartelle
Esporta	Esporta i risultati in CSV
📡 Scansione Rete Pro (rete.ps1)
Il nuovo strumento di scansione rete avanzato include:

Funzione	Descrizione
Scansione subnet	Supporto per /24, /23, /16
Ping + Porte TCP	Rilevamento ibrido per superare i firewall
Hostname	4 metodi: NetBIOS, ping -a, nslookup, DNS inverso
MAC Address	3 metodi: Get-NetNeighbor, arp -a, SNMP sul gateway
Vendor	Chiamata a macvendors.com (se Internet disponibile)
Tempi di risposta	Misurati in ms con colorazione delle righe
Esporta CSV	Salva i risultati sul desktop
Interfaccia	Moderna, scura, con tabella interattiva
📸 Screenshots
Interfaccia principale con menu a tendina e layout a due colonne

Sezione Dominio con utility per ambienti Active Directory

Sezione Privacy per disabilitare telemetria

Nuovo strumento Scansione Rete Pro con supporto SNMP

📁 Struttura del repository (v3.1.0)
text
ManutenzioneProMax/
├── Manutenzione_PRO_MAX.ps1        # Script principale (orchestratore)
├── AICHAT.ps1                      # Modulo AI Chat (invariato)
├── Search.ps1                      # Modulo Ricerca File (invariato)
├── rete.ps1                        # Scansione Rete Pro (invariato)
├── Modules/                        # NUOVA - Moduli funzionali
│   ├── Core.psm1                   # Utility base (logging, UI, processi)
│   ├── Upgrade.psm1                # Aggiornamenti (Winget, Store, WU, Driver)
│   ├── Pulizia.psm1                # Pulizia (Temp, DiskCleanup, Logs)
│   ├── Rete.psm1                   # Rete (DNS, IP, WiFi, SpeedTest, Blacklist)
│   ├── Riparazione.psm1            # Riparazione (SFC, DISM, RestorePoint)
│   ├── Sicurezza.psm1              # Sicurezza (Defender, EventLog, HealthCheck)
│   ├── Diagnostica.psm1            # Diagnostica (Info, Batteria, Uptime, Processi)
│   ├── Sistema.psm1                # Sistema (Visivi, Avvio, CPU, TPM)
│   ├── Dominio.psm1                # Dominio (AD, DC, GPO, LDAP)
│   ├── Backup.psm1                 # Backup (Files, Avanzato)
│   ├── Privacy.psm1                # Privacy (Windows, Office, Edge, Tasks)
│   └── Utility.psm1                # Utility (RDP, VNC, RustDesk, Shutdown)
├── Prompt/                         # Agenti AI (creata automaticamente)
├── ManutenzioneProMax.bat          # Batch per esecuzione semplificata
├── README.md                       # Documentazione
├── LICENSE                         # Licenza MIT
└── version.txt                     # Versione corrente (3.1.0)
📦 Requisiti
Windows 10 o 11

PowerShell 7.x (auto-installato se mancante)

Privilegi amministrativi (per la maggior parte delle funzionalità)

Winget (per gli aggiornamenti pacchetti)

Modulo ActiveDirectory (per le funzioni dominio, opzionale)

🛠️ Utilizzo
Esecuzione
Scaricare tutti i file nella stessa cartella (inclusa la cartella Modules/)

Eseguire Manutenzione_PRO_MAX.ps1 con PowerShell (tasto destro → "Esegui con PowerShell")

Per tutte le funzionalità, cliccare su "Eleva Admin" per ottenere privilegi amministrativi

Se PowerShell 7 non è presente, verrà installato automaticamente

Auto-aggiornamento
Full Update Script: Aggiorna TUTTI i file del repository (script, moduli, batch, README, LICENSE)

Backup automatico: Prima di ogni aggiornamento viene creato un backup nella cartella backup_*

Esclusione: Le cartelle che iniziano con backup vengono automaticamente escluse dal backup

📈 Versioni
Versione	Data	Novità
3.1.0	2024-07-21	Architettura modulare, Scansione Rete Pro, correzioni Blacklist, Ping Test, colori log
3.0.5	2024-07-15	Correzioni e ottimizzazioni
3.0.4	2024-07-10	Aggiunto Full Update Script, migliorato Upgrade Total
3.0.3	2024-07-05	Modularità, AI Chat, Ricerca File, DPI Scaling
🤝 Contributi
Segnalazioni di bug e richieste di funzionalità sono benvenute tramite GitHub Issues.

📄 Licenza
MIT License - vedi il file LICENSE per i dettagli.

© 2024 Pierpaolo Sanna
Manutenzione PRO MAX - All-in-one Windows maintenance tool

