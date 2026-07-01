# Manutenzione PRO MAX v3.0.3

All-in-one Windows maintenance and diagnostics tool with a modern dark GUI. Portable, no installation required.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-3.0.1-brightgreen)

## 📋 Descrizione

**Manutenzione PRO MAX** è uno strumento completo di manutenzione e diagnostica per Windows, progettato con un'interfaccia moderna e scura. Tutte le funzionalità sono organizzate in menu a tendina con **tooltip esplicativi** per guidare l'utente.

## ✨ Caratteristiche Principali

### 🔄 Aggiornamenti
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **UPGRADE PROGRAMMI** | Avvia la sequenza completa di aggiornamenti: Winget, Store, Windows Update, Pulizia temp e Flush DNS | ✅ |
| **Winget** | Aggiorna tutti i programmi installati tramite Winget (gestore pacchetti Windows) | ✅ |
| **Store** | Aggiorna tutte le app del Microsoft Store | ✅ |
| **Cerca WU** | Cerca gli aggiornamenti disponibili per Windows Update | ✅ |
| **Installa WU** | Scarica e installa tutti gli aggiornamenti di Windows in sospeso | ✅ |
| **Driver** | Aggiorna driver via Windows Update | ✅ |

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

### ⚙️ Sistema
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Shutdown Sched.** | Programma lo spegnimento forzato del PC ogni giorno all'ora impostata (attività pianificata) | ✅ |
| **Rimuovi Shutdown** | Rimuove il task di spegnimento programmato creato in precedenza | ✅ |
| **Ottimizza Visivi** | Ottimizza gli effetti visivi di Windows: disabilita animazioni inutili, mantiene Peek, anteprime e ombre | ✅ |
| **Ottimizza Avvio** | Ottimizza servizi di avvio (SysMain, MapsBroker, Xbox, ecc.) e abilita avvio veloce | ✅ |
| **Assist. Remota** | Scarica e avvia RustDesk per assistenza remota (portatile) mostrando ID e password | ✅ |
| **Eleva Admin** | Riavvia lo script con privilegi amministrativi per sbloccare tutte le funzionalità | ✅ |
| **Riavvia PC** | Riavvia il sistema dopo 5 secondi con un messaggio di avviso | ✅ |

### 📦 Utility
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Annulla** | Annulla l'operazione in corso in modo sicuro | ✅ |
| **Export Report** | Esporta il contenuto del log in un file di testo sul desktop | ✅ |
| **Aggiorna Script** | Controlla e installa automaticamente la nuova versione dello script da GitHub con backup | ✅ |
| **Esci** | Chiude l'applicazione di manutenzione | ✅ |

## 📸 Screenshots

<!-- Aggiorna i link con le tue immagini -->
<img width="995" height="592" alt="Manutenzione PRO MAX Main Interface" src="https://github.com/user-attachments/assets/b49f8f1a-0274-4e2e-9871-c8e2226b95a3" />
*Interfaccia principale con menu a tendina e layout a due colonne*

<img width="1009" height="601" alt="Domain Section" src="https://github.com/user-attachments/assets/b4d5062d-3f61-4117-b456-c9203d79bffa" />
*Sezione Dominio con 12 utility per ambienti Active Directory*

<img width="994" height="587" alt="Privacy Section" src="https://github.com/user-attachments/assets/a795d653-2164-4b53-aedc-715dcc51cc9a" />
*Sezione Privacy per disabilitare telemetria di Windows, Office, Edge e Task Scheduler*

## 🚀 Novità della v3.0.1

- ✅ **12 utility per DOMINIO**: Info, Test DC, Sincronizza Ora, Flush Kerberos, GPO, Reset Profilo, DNS, Sito AD, LDAP, Cambia Password, Ultimo Login, Gruppi Utente
- ✅ **Backup compresso**: Seleziona origine e destinazione, compressione ZIP con data/ora e percentuale
- ✅ **Privacy completa**: 5 funzioni per disabilitare telemetria Windows, Office, Edge e Task Scheduler
- ✅ **Ottimizzazione Avvio**: Gestione servizi e avvio veloce
- ✅ **Health Check**: Verifica integrata di SFC, DISM, eventi e memoria
- ✅ **Barra di progresso**: Ora raggiunge sempre il 100% al termine di ogni operazione
- ✅ **Interfaccia migliorata**: Linea separatrice verticale, icone Unicode, testo centrato

## 📦 Requisiti

- Windows 10 o 11
- PowerShell 5.1 (pre-installato) o PowerShell 7 (auto-installato se mancante)
- Privilegi amministrativi (per la maggior parte delle funzionalità)
- Winget (per gli aggiornamenti pacchetti)
- Modulo ActiveDirectory (per le funzioni dominio, opzionale)

## 🛠️ Utilizzo

### Esecuzione come script
1. Scaricare il file `Manutenzione_PRO_MAX_v3.ps1`
2. Eseguirlo con PowerShell (tasto destro → "Esegui con PowerShell")
3. Per avere tutte le funzionalità, cliccare su **"Eleva Admin"** per ottenere privilegi amministrativi
4. Se PowerShell 7 non è presente, verrà installato automaticamente

### Auto-aggiornamento
- Il pulsante **"Aggiorna Script"** verifica automaticamente la presenza di nuove versioni su GitHub
- Se disponibile, propone il download e il riavvio con backup automatico

## 📁 Struttura del repository

ManutenzioneProMax/
├── Manutenzione_PRO_MAX_v3.ps1 # Script principale
├── ManutenzioneProMax.bat # Batch per esecuzione semplificata
├── README.md # Questa documentazione
└── version.txt # Versione corrente (3.0.1)

## 🤝 Contributi

Segnalazioni di bug e richieste di funzionalità sono benvenute tramite [GitHub Issues](https://github.com/pierpaolosanna/ManutenzioneProMax/issues).

## 📄 Licenza

MIT License - vedi il file [LICENSE](LICENSE) per i dettagli.
