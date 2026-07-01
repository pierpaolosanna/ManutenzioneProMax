# Manutenzione PRO MAX v3.0.3

All-in-one Windows maintenance and diagnostics tool with a modern dark GUI. Portable, no installation required.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-3.0.2-brightgreen)

## 📋 Descrizione

**Manutenzione PRO MAX** è uno strumento completo di manutenzione e diagnostica per Windows, progettato con un'interfaccia moderna e scura. Tutte le funzionalità sono organizzate in menu a tendina con **tooltip esplicativi** per guidare l'utente.

Il tool è modulare: oltre allo script principale, include moduli separati per la **Chat AI** e la **Ricerca File**, caricati dinamicamente all'avvio.

## ✨ Caratteristiche Principali

### 🔄 Aggiornamenti
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Eleva Admin** | Riavvia lo script con privilegi amministrativi per sbloccare tutte le funzionalità | ✅ |
| **Crea Ripristino** | Crea un punto di ripristino del sistema prima di eseguire modifiche | ✅ |
| **UPGRADE PROGRAMMI** | Avvia la sequenza completa di aggiornamenti: Winget, Store, Windows Update, Pulizia temp e Flush DNS | ✅ |
| **Winget** | Aggiorna tutti i programmi installati tramite Winget (gestore pacchetti Windows) | ✅ |
| **Store** | Aggiorna tutte le app del Microsoft Store | ✅ |
| **Cerca WU** | Cerca gli aggiornamenti disponibili per Windows Update | ✅ |
| **Installa WU** | Scarica e installa tutti gli aggiornamenti di Windows in sospeso | ✅ |
| **Driver** | Aggiorna driver via Windows Update | ✅ |
| **Aggiorna Script** | Controlla e installa automaticamente la nuova versione dello script da GitHub con backup | ✅ |
| **Full Update Script** | Aggiorna TUTTI i file del repository (script, batch, README, license) | ✅ |

### 🧹 Pulizia
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Temp** | Pulisce le cartelle temporanee del sistema e dell'utente liberando spazio su disco | ✅ |
| **Disk Cleanup** | Avvia lo strumento di pulizia disco di Windows (richiede privilegi admin) | ✅ |
| **Analisi Disco** | Analisi dettagliata dello spazio occupato su tutti i dischi | ✅ |
| **Pulisci Log** | Pulisce i file di log e dump di sistema | ✅ |

### 🌐 Rete
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Flush DNS** | Svuota la cache DNS per risolvere problemi di risoluzione dei nomi | ✅ |
| **Renew IP** | Rinnova l'indirizzo IP della scheda di rete | ✅ |
| **Info IP** | Mostra tutte le informazioni di configurazione di rete (ipconfig /all) | ✅ |
| **Winsock** | Resetta lo stack Winsock e il protocollo IP (utile per problemi di rete) | ✅ |
| **Reset Rete** | Reset completo dello stack di rete con backup delle configurazioni | ✅ |
| **Wi-Fi Pass** | Visualizza le password salvate delle reti Wi-Fi conosciute | ✅ |
| **Ping Test** | Esegue un test di latenza verso i server DNS principali (Google, Cloudflare, OpenDNS) | ✅ |
| **Speed Internet** | Esegue un test della velocità di connessione utilizzando i server Cloudflare (ping, download, upload) | ✅ |

### 🔧 Riparazione
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **SFC + DISM** | Esegue SFC /scannow e DISM per riparare i file di sistema danneggiati | ✅ |
| **Pt. Ripristino** | Crea un punto di ripristino del sistema (limite 24 ore) | ✅ |

### 🛡️ Sicurezza
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Scan Defender** | Avvia una scansione rapida con Windows Defender | ✅ |
| **Event Log** | Mostra gli ultimi errori critici del registro eventi di sistema (ultimi 7 giorni) | ✅ |
| **Health Check** | Verifica integrità critica del sistema (SFC, DISM, eventi, memoria) | ✅ |

### 📊 Diagnostica
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Info Sistema** | Mostra informazioni dettagliate su hardware e sistema operativo | ✅ |
| **Batteria** | Genera un report sulla salute della batteria (solo su portatili) | ✅ |
| **Uptime** | Visualizza da quanto tempo il sistema è in esecuzione senza riavvii | ✅ |
| **Top Processi** | Elenca i processi che consumano più CPU in tempo reale | ✅ |
| **Startup** | Elenca i programmi avviati automaticamente all'avvio del sistema | ✅ |
| **Spazio Disco** | Analizza e mostra lo spazio occupato dalle cartelle principali dell'utente | ✅ |
| **Servizi** | Controlla lo stato dei servizi di sistema principali (Windows Update, Defender, Firewall, BITS, DNS) | ✅ |
| **CPU Unlock** | Sblocca le opzioni avanzate di gestione energia della CPU nel Pannello di Controllo | ✅ |

### 🏢 Dominio
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Info Dominio** | Mostra informazioni sul dominio e PC (nome, DC, foresta) | ✅ |
| **Test DC** | Test ping ai Domain Controller | ✅ |
| **Sincronizza Ora** | Sincronizza orario con Domain Controller | ✅ |
| **Flush Kerberos** | Svuota cache ticket Kerberos | ✅ |
| **Info GPO** | Mostra le GPO applicate al computer e all'utente | ✅ |
| **Reset Profilo** | Reimposta profilo di rete (Winsock, TCP/IP, IP) | ⚠️ Disconnette brevemente |
| **Test DNS** | Verifica risoluzione DNS del dominio | ✅ |
| **Info Sito AD** | Mostra il sito Active Directory corrente | ✅ |
| **Test LDAP** | Verifica connettività LDAP al dominio | ✅ |
| **Cambia Password** | Cambia password dell'utente nel dominio | ✅ |
| **Ultimo Login** | Mostra ultimo login, data password e scadenza | ✅ |
| **Gruppi Utente** | Mostra i gruppi di cui l'utente è membro | ✅ |

### 💾 Backup
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Backup Files** | Comprimi e salva files in backup .zip con data/ora, dimensione e percentuale compressione | ✅ |

### 🔒 Privacy
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Privacy Windows** | Disabilita telemetria, Cortana, segnalazione errori, advertising ID, inventory collector | ✅ |
| **Privacy Office** | Disabilita telemetria e invio dati di Office (2016/2019/365) | ✅ |
| **Privacy Edge** | Disabilita telemetria, suggerimenti, riempimento automatico e personalizzazione di Edge | ✅ |
| **Privacy Task** | Disabilita attività pianificate di telemetria (Compatibilità, CEIP, SQM, ecc.) | ✅ |
| **DISABILITA TUTTO** | Esegue TUTTE le privacy in sequenza e propone riavvio | ✅ |

### ⚙️ Utility
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Riavvia su BIOS** | Riavvia il PC direttamente nel BIOS/UEFI | ✅ |
| **Riavvia PC** | Riavvia il computer immediatamente | ✅ |
| **Disconnetti Utente** | Disconnette l'utente corrente | ✅ |
| **Arresta PC** | Spegne il computer immediatamente | ✅ |
| **Shutdown Sched.** | Programma lo spegnimento forzato del PC ogni giorno all'ora impostata (attività pianificata) | ✅ |
| **Rimuovi Shutdown** | Rimuove il task di spegnimento programmato creato in precedenza | ✅ |
| **AI Chat** | Apre il dialogo AI Chat con supporto Gemini, Groq, Cloudflare e Bynara | ✅ |
| **Ricerca File** | Apre il dialogo di ricerca rapida file e contenuti (ricerca per nome, contenuto, duplicati, file grandi) | ✅ |
| **Annulla** | Annulla l'operazione in corso in modo sicuro | ✅ |
| **Esci** | Chiude l'applicazione di manutenzione | ✅ |

### 🤖 AI Chat (Modulo AICHAT.ps1)
| Funzione | Descrizione |
|----------|-------------|
| **Provider** | Supporto per Gemini, Groq, Cloudflare e Bynara |
| **Modelli** | Ogni provider ha una lista di modelli selezionabili |
| **Agenti** | Carica automaticamente i file `.md` dalla cartella `Prompt/` come System Prompt |
| **Salva Agente** | Salva il prompt corrente come nuovo agente su disco |
| **Ricerca Web** | Integra DDG e Wikipedia per risposte aggiornate |
| **Allegati** | Supporta file PDF, DOC, DOCX, XLS, XLSX e testuali; legge e analizza il contenuto |
| **Statistiche** | Mostra i token utilizzati per sessione e per modello |
| **Impostazioni** | Modifica System Prompt e chiavi Cloudflare |
| **Verifica Modelli** | Testa tutti i provider in sequenza |

### 🔍 Ricerca File (Modulo Search.ps1)
| Funzione | Descrizione |
|----------|-------------|
| **Ricerca per Nome** | Cerca file in base al pattern del nome |
| **Ricerca per Contenuto** | Cerca testo all'interno dei file |
| **Ricerca Duplicati** | Trova file duplicati tramite hash MD5 |
| **Ricerca File Grandi** | Trova file con dimensione superiore a una soglia (default 100 MB) |
| **Ricorsiva** | Opzione per cercare nelle sottocartelle |
| **Interfaccia** | Risultati in DataGridView, copia percorso, apri cartella, esporta risultati |

## 📸 Screenshots

<!-- Aggiorna i link con le tue immagini -->
<img width="995" height="592" alt="Manutenzione PRO MAX Main Interface" src="https://github.com/user-attachments/assets/b49f8f1a-0274-4e2e-9871-c8e2226b95a3" />
*Interfaccia principale con menu a tendina e layout a due colonne*

<img width="1009" height="601" alt="Domain Section" src="https://github.com/user-attachments/assets/b4d5062d-3f61-4117-b456-c9203d79bffa" />
*Sezione Dominio con 12 utility per ambienti Active Directory*

<img width="994" height="587" alt="Privacy Section" src="https://github.com/user-attachments/assets/a795d653-2164-4b53-aedc-715dcc51cc9a" />
*Sezione Privacy per disabilitare telemetria di Windows, Office, Edge e Task Scheduler*

## 🚀 Novità della v3.0.2

- ✅ **Modularità**: Script suddiviso in moduli separati (AICHAT.ps1, Search.ps1)
- ✅ **AI Chat**: Integrazione con Gemini, Groq, Cloudflare e Bynara con supporto agenti, allegati e ricerca web
- ✅ **Ricerca File**: Nuovo modulo per ricerca rapida file e contenuti, duplicati e file grandi
- ✅ **DPI Scaling**: Pulsanti e UI si adattano automaticamente agli schermi ad alta risoluzione
- ✅ **Documentazione**: Ogni pulsante ha una scheda informativa (clicca su ℹ️)
- ✅ **Punto Ripristino**: Aggiunto pulsante "Crea Ripristino" nella sezione Aggiornamenti
- ✅ **Icona personalizzata**: L'icona della finestra è l'avatar di GitHub

## 📦 Requisiti

- Windows 10 o 11
- PowerShell 5.1 (pre-installato) o PowerShell 7 (auto-installato se mancante)
- Privilegi amministrativi (per la maggior parte delle funzionalità)
- Winget (per gli aggiornamenti pacchetti)
- Modulo ActiveDirectory (per le funzioni dominio, opzionale)
- Moduli AICHAT.ps1 e Search.ps1 (presenti nella stessa directory)

## 🛠️ Utilizzo

### Esecuzione come script
1. Scaricare i file `Manutenzione_PRO_MAX_v3.ps1`, `AICHAT.ps1` e `Search.ps1` nella stessa cartella
2. Eseguire lo script principale con PowerShell (tasto destro → "Esegui con PowerShell")
3. Per avere tutte le funzionalità, cliccare su **"Eleva Admin"** per ottenere privilegi amministrativi
4. Se PowerShell 7 non è presente, verrà installato automaticamente

### Auto-aggiornamento
- Il pulsante **"Aggiorna Script"** verifica automaticamente la presenza di nuove versioni su GitHub
- Se disponibile, propone il download e il riavvio con backup automatico
- Il pulsante **"Full Update Script"** aggiorna TUTTI i file del repository (script, batch, README, LICENSE, version.txt)

## 📁 Struttura del repository
ManutenzioneProMax/
├── Manutenzione_PRO_MAX_v3.ps1 # Script principale
├── AICHAT.ps1 # Modulo AI Chat
├── Search.ps1 # Modulo Ricerca File
├── Prompt/ # Agenti AI (creata automaticamente)
├── Docs/Buttons/ # Documentazione pulsanti (creata automaticamente)
├── ManutenzioneProMax.bat # Batch per esecuzione semplificata
├── README.md # Questa documentazione
└── version.txt # Versione corrente (3.0.2)


## 🤝 Contributi

Segnalazioni di bug e richieste di funzionalità sono benvenute tramite [GitHub Issues](https://github.com/pierpaolosanna/ManutenzioneProMax/issues).

## 📄 Licenza

MIT License - vedi il file [LICENSE](LICENSE) per i dettagli.
