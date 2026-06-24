# Manutenzione PRO MAX v3.0

All-in-one Windows maintenance and diagnostics tool with a modern dark GUI. Portable, no installation required.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-3.0-brightgreen)

## 📋 Descrizione

**Manutenzione PRO MAX** è uno strumento completo di manutenzione e diagnostica per Windows, progettato con un'interfaccia moderna e scura. Tutte le funzionalità sono organizzate in pulsanti intuitivi con **tooltip esplicativi** per guidare l'utente.

## ✨ Caratteristiche Principali

### 🔄 Aggiornamenti
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **UPGRADE PROGRAMMI** | Avvia la sequenza completa di aggiornamenti: Winget, Store, Windows Update, Pulizia temp e Flush DNS | ✅ |
| **Winget** | Aggiorna tutti i programmi installati tramite Winget (gestore pacchetti Windows) | ✅ |
| **Store** | Aggiorna tutte le app del Microsoft Store | ✅ |
| **Cerca WU** | Cerca gli aggiornamenti disponibili per Windows Update | ✅ |
| **Installa WU** | Scarica e installa tutti gli aggiornamenti di Windows in sospeso | ✅ |

### 🧹 Pulizia
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Temp** | Pulisce le cartelle temporanee del sistema e dell'utente liberando spazio su disco | ✅ |
| **Disk Cleanup** | Avvia lo strumento di pulizia disco di Windows (richiede privilegi admin) | ✅ |

### 🌐 Rete
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Flush DNS** | Svuota la cache DNS per risolvere problemi di risoluzione dei nomi | ✅ |
| **Renew IP** | Rinnova l'indirizzo IP della scheda di rete | ✅ |
| **Info IP** | Mostra tutte le informazioni di configurazione di rete (ipconfig /all) | ✅ |
| **Winsock** | Resetta lo stack Winsock e il protocollo IP (utile per problemi di rete) | ✅ |
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
| **Assist. Remota** | Scarica e avvia RustDesk per assistenza remota (portatile) mostrando ID e password | ✅ |

### ⚙️ Sistema
| Funzione | Descrizione | Tooltip |
|----------|-------------|---------|
| **Shutdown Sched.** | Programma lo spegnimento forzato del PC ogni giorno all'ora impostata (attività pianificata) | ✅ |
| **Rimuovi Shutdown** | Rimuove il task di spegnimento programmato creato in precedenza | ✅ |
| **Ottimizza Visivi** | Ottimizza gli effetti visivi di Windows: disabilita animazioni inutili, mantiene Peek, anteprime e ombre | ✅ |
| **Annulla** | Annulla l'operazione in corso in modo sicuro | ✅ |
| **Export Report** | Esporta il contenuto del log in un file di testo sul desktop | ✅ |
| **Eleva Admin** | Riavvia lo script con privilegi amministrativi per sbloccare tutte le funzionalità | ✅ |
| **Riavvia PC** | Riavvia il sistema dopo 5 secondi con un messaggio di avviso | ✅ |
| **Esci** | Chiude l'applicazione di manutenzione | ✅ |

## 📸 Screenshots

<img width="995" height="592" alt="Manutenzione PRO MAX Main Interface" src="https://github.com/user-attachments/assets/b49f8f1a-0274-4e2e-9871-c8e2226b95a3" />
*Interfaccia principale con barra laterale compatta*

<img width="1009" height="601" alt="Updates Section" src="https://github.com/user-attachments/assets/b4d5062d-3f61-4117-b456-c9203d79bffa" />
*Sezione aggiornamenti e pulizia*

<img width="994" height="587" alt="Diagnostics Section" src="https://github.com/user-attachments/assets/a795d653-2164-4b53-aedc-715dcc51cc9a" />
*Sezione diagnostica e sistema*

## 🚀 Novità della v3.0

- ✅ **Tooltip esplicativi** per tutti i pulsanti
- ✅ **Auto-installazione PowerShell 7** se non presente
- ✅ **Auto-installazione certificato** per esecuzione firmata
- ✅ **Interfaccia ottimizzata** con layout compatto
- ✅ **Supporto PS5/PS7** con rilevamento automatico
- ✅ **Logging bufferizzato** per prestazioni fluide
- ✅ **Annullamento operazioni** in qualsiasi momento
- ✅ **Export report** del log completo

## 📦 Requisiti

- Windows 10 o 11
- PowerShell 5.1 (pre-installato) o PowerShell 7 (auto-installato se mancante)
- Privilegi amministrativi (per la maggior parte delle funzionalità)
- Winget (per gli aggiornamenti pacchetti)

## 🛠️ Utilizzo

### Esecuzione come script
- Eseguire il File ManutenzioneProMax.bat
- Per avere tutte le funzionalità scegliere l'opzione 2 come AMMINISTRATORE
- Se la Microsoft PowerShell 7 non è presente verrà installata
