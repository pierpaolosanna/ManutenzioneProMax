# ⚡ Manutenzione PRO MAX v3.1.0

## 👨‍💻 Autore e Manutentore
Questo progetto è creato e mantenuto da **Pierpaolo Sanna**.
- **GitHub:** [@pierpaolosanna](https://github.com/pierpaolosanna)
- **Repository ufficiale:** [ManutenzioneProMax](https://github.com/pierpaolosanna/ManutenzioneProMax)

Se hai suggerimenti, segnalazioni di bug o vuoi contribuire allo sviluppo, apri pure una **Issue** o una **Pull Request** sul repository ufficiale. 
Lo script verifica automaticamente la presenza di nuove versioni direttamente da questo repository!

> ⚠️ **Utilizzare a proprio rischio. Nessuna garanzia espressa o implicita.**  
> Use at your own risk. No warranties expressed or implied.

[![PowerShell](https://img.shields.io/badge/PowerShell-7.x-blue?logo=powershell&style=flat-square)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows&style=flat-square)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-3.1.0-brightgreen?style=flat-square)](#)
[![Downloads](https://img.shields.io/github/downloads/pierpaolosanna/ManutenzioneProMax/total?style=flat-square)](https://github.com/pierpaolosanna/ManutenzioneProMax/releases)
[![Stars](https://img.shields.io/github/stars/pierpaolosanna/ManutenzioneProMax?style=flat-square)](https://github.com/pierpaolosanna/ManutenzioneProMax/stargazers)

---

## 🚀 **All-in-one Windows maintenance and diagnostics tool**

**Portable, modular, self-updating** – now with Android device management (ADB), Microsoft Activation Scripts (MAS), and contextual help for every category.
---

## 📑 **Indice**

- [🎯 Perché questo tool?](#-perché-questo-tool)
- [🆕 Novità della v3.1.0](#-novità-della-v310)
- [✨ Caratteristiche Principali](#-caratteristiche-principali)
  - [🔄 Aggiornamenti](#-aggiornamenti-modulo-upgradepsm1)
  - [🧹 Pulizia](#-pulizia-modulo-puliziapsm1)
  - [🌐 Rete](#-rete-modulo-retepsm1)
  - [📱 Android](#-android-modulo-adbpsm1)
  - [🔧 Riparazione](#-riparazione-modulo-riparazionepsm1)
  - [🛡️ Sicurezza](#-sicurezza-modulo-sicurezzapsm1)
  - [📊 Diagnostica](#-diagnostica-modulo-diagnosticapsm1)
  - [⚙️ Sistema](#️-sistema-modulo-sistemapsm1)
  - [🏢 Dominio](#-dominio-modulo-dominiopspm1)
  - [💾 Backup](#-backup-modulo-backuppsm1)
  - [🔒 Privacy](#-privacy-modulo-privacypm1)
  - [🧰 Utility](#-utility-modulo-utilitypsm1)
- [🤖 AI Chat](#-ai-chat-modulo-aichatps1)
- [🔍 Ricerca File](#-ricerca-file-modulo-searchps1)
- [🔑 MAS Activation](#-mas-activation-modulo-maspsm1)
- [📡 Scansione Rete Pro](#-scansione-rete-pro-reteps1)
- [📖 Istruzioni Contestuali](#-istruzioni-contestuali)
- [📁 Struttura del Repository](#-struttura-del-repository-v310)
- [📦 Requisiti](#-requisiti)
- [🛠️ Utilizzo](#️-utilizzo)
- [🧪 Test](#-test)
- [📈 Versioni](#-versioni)
- [🤝 Contributi](#-contributi)
- [📄 Licenza](#-licenza)
- [🙏 Ringraziamenti](#-ringraziamenti)
- [📞 Contatti](#-contatti)
- [⭐ Supporto](#-supporto)

---

## 🎯 **Perché questo tool?**

| **Problema** | **Soluzione di Manutenzione PRO MAX** |
|--------------|----------------------------------------|
| ❌ Strumenti di manutenzione sparsi e non integrati | ✅ **Tutto in un'unica interfaccia** – 12+ moduli funzionali |
| ❌ Difficoltà nel gestire dispositivi Android da PC | ✅ **Modulo ADB completo** – backup, gestione pacchetti, diagnostica |
| ❌ Windows/Office non attivati o scaduti | ✅ **MAS integrato** – HWID, Ohook, TSforge, KMS |
| ❌ Documentazione assente o difficile da trovare | ✅ **Istruzioni contestuali** – help automatico per ogni categoria |
| ❌ Interfaccia utente poco intuitiva | ✅ **GUI moderna, scura con scrollbar, tooltip e colori** |
| ❌ Script monolitici difficili da mantenere | ✅ **Architettura modulare** – aggiorna solo ciò che serve |

> 💡 **Il tool è pensato per tecnici, sistemisti e power user che vogliono uno strumento completo e portatile per la manutenzione di Windows e Android.**

---

## 🆕 **Novità della v3.1.0**

### 🏗️ **Architettura Modulare**
- Script suddiviso in **moduli separati** (`.psm1`) per ogni area funzionale
- Nuovo modulo **Core** che centralizza logging, UI e utility di base
- **Manutenzione semplificata**: ogni modulo è indipendente e facilmente aggiornabile

### 📱 **Modulo ADB (Android Debug Bridge)**
- ✅ **Installa Driver ADB**: scarica e installa automaticamente ADB e driver USB
- ✅ **Controlla Dispositivi**: rileva e seleziona i dispositivi Android connessi
- ✅ **Gestione Pacchetti**: visualizza, disabilita, abilita, disinstalla e pulisce cache delle app
- ✅ **Backup Completo**: backup di APK, dati, sistema e condivisioni
- ✅ **Backup Dati App**: backup dei dati di una specifica applicazione
- ✅ **Backup APK**: estrae tutti gli APK delle app installate
- ✅ **Ripristino Backup**: ripristina backup da file `.ab`
- ✅ **Pull/Push File**: copia file tra dispositivo e PC
- ✅ **Diagnostica**: info dispositivo, stato batteria, top processi, registrazione schermo
- ✅ **Riavvio Fastboot/Recovery**: avvia il dispositivo in modalità avanzate
- ✅ **Sicurezza**: blocco/sblocco schermo, invio testo, foto remota
- ✅ **SMS e Chiamate**: leggi SMS e avvia chiamate

### 🔑 **Modulo MAS (Microsoft Activation Scripts)**
- ✅ **MAS Activation**: avvia Microsoft Activation Scripts per attivare Windows/Office
- ✅ **Payload crittografato**: lo script MAS è protetto da password AES-256
- ✅ **Dialog password**: finestra modale non bloccante per l'inserimento della password

### 📖 **Istruzioni Contestuali**
- ✅ **Help contestuale**: quando selezioni una categoria, vengono mostrate le istruzioni nel log
- ✅ **File Markdown**: le istruzioni sono memorizzate in file `.md` nella cartella `Modules\Docs\Buttons\`
- ✅ **Formattazione colorata**: titoli in ciano, sottotitoli in giallo, testo in bianco

### 🎨 **Miglioramenti UI**
- ✅ **Scrollbar per i pulsanti**: barra di scorrimento verticale per categorie con molte funzioni
- ✅ **Bordo verde per il log**: pannello log con bordo verde acceso per maggiore visibilità
- ✅ **WordWrap nei log**: le righe troppo lunghe vanno a capo automaticamente
- ✅ **Pulsante "Pulisci Log"**: svuota il log con un clic

### 📡 **Scansione Rete Pro (rete.ps1)**
- ✅ Supporto per subnet `/24`, `/23`, `/16`
- ✅ Rilevamento ibrido (ping + porte TCP) per superare i firewall
- ✅ 4 metodi per il rilevamento hostname (NetBIOS, ping -a, nslookup, DNS inverso)
- ✅ 3 metodi per il rilevamento MAC (Get-NetNeighbor, arp -a, SNMP sul gateway)
- ✅ Risoluzione vendor tramite macvendors.com (se internet disponibile)
- ✅ Tempi di risposta in ms con colorazione delle righe
- ✅ Esportazione CSV

### 🐛 **Bug Fix e Ottimizzazioni**
- ✅ Colori nei log per Blacklist Check: "SEGNALATO" in rosso, "PULITO" in verde
- ✅ Ping Test: risolto il problema di visualizzazione dei tempi di risposta
- ✅ Full Update: esclusione automatica delle cartelle `backup*` durante il backup
- ✅ Modulo Sicurezza: corretto il caricamento e tutte le funzioni associate

---

## ✨ **Caratteristiche Principali**

### 🔄 **Aggiornamenti (Modulo `Upgrade.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🔑 **Eleva Admin** | Riavvia lo script con privilegi amministrativi | ❌ |
| 💾 **Crea Ripristino** | Crea un punto di ripristino del sistema | ✅ |
| 🔄 **Winget** | Aggiorna tutti i programmi tramite Winget | ❌ |
| 📦 **Store** | Aggiorna le app del Microsoft Store | ❌ |
| 🔍 **Cerca WU** | Cerca aggiornamenti Windows disponibili | ✅ |
| ⬇️ **Installa WU** | Installa gli aggiornamenti Windows | ✅ |
| 🔧 **Driver** | Aggiorna driver via Windows Update | ✅ |
| 📦 **Full Update Script** | Aggiorna TUTTI i file del repository GitHub | ❌ |
| ▶️ **UPGRADE TOTAL** | Esegue la sequenza completa di aggiornamento | ✅ |

### 🧹 **Pulizia (Modulo `Pulizia.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🧹 **Temp** | Pulisce le cartelle temporanee del sistema e dell'utente | ❌ |
| 💾 **Disk Cleanup** | Avvia lo strumento di pulizia disco di Windows | ✅ |
| 📝 **Pulisci Log** | Pulisce i file di log e dump di sistema | ❌ |
| 📊 **Analisi Disco** | Analisi dettagliata dello spazio su tutte le unità | ❌ |

### 🌐 **Rete (Modulo `Rete.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🌐 **Flush DNS** | Svuota la cache DNS | ✅ |
| 📶 **Renew IP** | Rinnova l'indirizzo IP tramite DHCP | ✅ |
| ℹ️ **Info IP** | Mostra IP pubblico e configurazione di rete | ❌ |
| 🔧 **Winsock** | Resetta lo stack Winsock | ✅ |
| 🔄 **Reset Rete** | Reset completo stack di rete con backup | ✅ |
| 🔑 **Wi-Fi Pass** | Visualizza password Wi-Fi salvate | ✅ |
| 📡 **Ping Test** | Test di latenza verso server DNS | ❌ |
| 🚀 **Speed Internet** | Test velocità Cloudflare | ❌ |
| 📊 **Speed Ookla** | Test approfondito Ookla | ❌ |
| 🗺️ **Traceroute** | Traccia il percorso verso un IP/dominio | ❌ |
| 🔄 **Cambia DNS** | Modifica i server DNS | ✅ |
| 🔍 **Whois** | Info su IP/dominio | ❌ |
| 🚫 **Blacklist Check** | Verifica blacklist con colori rosso/verde | ❌ |
| 📡 **Scansione Rete Pro** | Strumento avanzato con supporto SNMP | ❌ |

### 📱 **Android (Modulo `ADB.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🔌 **Installa Driver ADB** | Scarica e installa ADB e driver USB | ✅ |
| 📱 **Controlla Dispositivi** | Rileva i dispositivi Android connessi | ❌ |
| 📦 **Gestione Pacchetti** | Visualizza, disabilita, abilita, disinstalla, pulisci cache | ❌ |
| 💾 **Backup Completo** | Backup di APK, dati, sistema e condivisioni | ❌ |
| 💾 **Backup Dati App** | Backup dei dati di una specifica applicazione | ❌ |
| 📦 **Backup APK** | Estrae tutti gli APK delle app installate | ❌ |
| 🔄 **Ripristina Backup** | Ripristina backup da file `.ab` | ❌ |
| 📂 **Pull File (Phone→PC)** | Copia un file dal telefono al PC | ❌ |
| 📂 **Push File (PC→Phone)** | Copia un file dal PC al telefono | ❌ |
| ℹ️ **Info Dispositivo** | Info dettagliate su hardware e software | ❌ |
| 🔋 **Stato Batteria** | Stato dettagliato della batteria | ❌ |
| 📊 **Top Processi** | Processi che consumano più risorse | ❌ |
| 🎥 **Registra Schermo** | Registra video dello schermo | ❌ |
| ⚡ **Riavvio Fastboot** | Riavvia in modalità Fastboot | ❌ |
| 🔧 **Riavvio Recovery** | Riavvia in modalità Recovery | ❌ |
| 🗑️ **Reset Dati App** | Cancella tutti i dati di un'app | ❌ |
| 📶 **Reset Impostazioni Rete** | Resetta WiFi, Bluetooth, dati mobili | ❌ |
| 🔒 **Blocca/Sblocca Schermo** | Blocca o sblocca il dispositivo | ❌ |
| ⌨️ **Invia Testo** | Invia testo al dispositivo | ❌ |
| 📷 **Scatta Foto** | Scatta una foto con la fotocamera | ❌ |
| 📩 **Leggi SMS** | Mostra gli ultimi SMS ricevuti | ❌ |
| 📞 **Effettua Chiamata** | Avvia una chiamata verso un numero | ❌ |
| 📸 **Screenshot** | Acquisisce e salva screenshot | ❌ |
| 📥 **Installa APK** | Seleziona e installa un file APK | ❌ |
| 📋 **Logcat** | Mostra le ultime 100 righe del logcat | ❌ |
| ⚙️ **Comando ADB** | Esegui un comando ADB personalizzato | ❌ |
| 📱 **Avvia Scrcpy** | Esegue Scrcpy per il mirroring del dispositivo | ❌ |

### 🔧 **Riparazione (Modulo `Riparazione.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🔨 **SFC + DISM** | SFC /scannow e DISM per riparare file di sistema | ✅ |
| ⏱️ **Pt. Ripristino** | Crea un punto di ripristino del sistema | ❌ |

### 🛡️ **Sicurezza (Modulo `Sicurezza.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🛡️ **Scan Defender** | Scansione rapida con Windows Defender | ✅ |
| 📋 **Event Log** | Mostra errori critici degli ultimi 7 giorni | ❌ |
| 🏥 **Health Check** | Verifica integrità del sistema | ❌ |

### 📊 **Diagnostica (Modulo `Diagnostica.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 💻 **Info Sistema** | Info dettagliate su hardware e OS | ❌ |
| 🔋 **Batteria** | Report sulla salute della batteria | ❌ |
| ⏰ **Uptime** | Tempo di attività del sistema | ❌ |
| 📈 **Top Processi** | Processi che consumano più CPU | ❌ |
| 🚀 **Startup** | Programmi avviati all'avvio | ❌ |
| 💿 **Spazio Disco** | Spazio occupato dalle cartelle principali | ❌ |
| ⚙️ **Servizi** | Stato dei servizi di sistema principali | ❌ |

### ⚙️ **Sistema (Modulo `Sistema.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🎨 **Ottimizza Visivi** | Ottimizza effetti visivi di Windows | ❌ |
| ⚡ **Ottimizza Avvio** | Ottimizza servizi e avvio del sistema | ✅ |
| 🔓 **CPU Unlock** | Sblocca opzioni avanzate energia CPU | ✅ |
| 🖥️ **TPM CPU RAM** | Rimuove limiti per Windows 11 | ✅ |
| 🔄 **Riavvia PC** | Riavvia il sistema | ❌ |

### 🏢 **Dominio (Modulo `Dominio.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🏢 **Info Dominio** | Info su dominio e PC | ❌ |
| 🖥️ **Test DC** | Ping ai Domain Controller | ❌ |
| 🕐 **Sincronizza Ora** | Sincronizza orario con DC | ❌ |
| 🗑️ **Flush Kerberos** | Svuota cache ticket Kerberos | ❌ |
| 📋 **Info GPO** | Mostra le GPO applicate | ❌ |
| 🔄 **Reset Profilo** | Reimposta profilo di rete | ✅ |
| 🌐 **Test DNS** | Verifica risoluzione DNS dominio | ❌ |
| 📍 **Info Sito AD** | Mostra sito AD corrente | ❌ |
| 🔗 **Test LDAP** | Verifica connettività LDAP | ❌ |
| 🔑 **Cambia Password** | Cambia password dominio | ❌ |
| 📅 **Ultimo Login** | Mostra ultimo login dominio | ❌ |
| 👥 **Gruppi Utente** | Mostra gruppi dominio dell'utente | ❌ |

### 💾 **Backup (Modulo `Backup.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 💾 **Backup Files** | Backup .zip con compressione ottimale | ❌ |
| 📦 **Backup Avanzato (7z)** | Backup 7-Zip con compressione massima | ❌ |
| 💾 **Crea Ripristino** | Crea un punto di ripristino | ❌ |

### 🔒 **Privacy (Modulo `Privacy.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| 🔒 **Privacy Windows** | Disabilita telemetria Windows | ✅ |
| 📁 **Privacy Office** | Disabilita telemetria Office | ❌ |
| 🌐 **Privacy Edge** | Disabilita telemetria Edge | ❌ |
| ⏰ **Privacy Task** | Disabilita attività telemetria | ✅ |
| 🚀 **DISABILITA TUTTO** | Esegue TUTTE le privacy in sequenza | ✅ |

### 🧰 **Utility (Modulo `Utility.psm1`)**

| Funzione | Descrizione | Richiede Admin |
|----------|-------------|:--------------:|
| ⚙️ **Riavvia su BIOS** | Riavvia nel BIOS/UEFI | ❌ |
| 🔄 **Riavvia PC** | Riavvia il computer | ❌ |
| 👤 **Disconnetti Utente** | Disconnette l'utente | ❌ |
| ⏻ **Arresta PC** | Spegne il computer | ❌ |
| ⏰ **Shutdown Sched.** | Programma spegnimento forzato | ✅ |
| ❌ **Rimuovi Shutdown** | Rimuove lo spegnimento programmato | ✅ |
| 💬 **AI Chat** | Apre il dialogo AI Chat | ❌ |
| 🔍 **Ricerca File** | Apre il dialogo di ricerca file | ❌ |
| 🔑 **MAS Activation** | Avvia Microsoft Activation Scripts | ❌ |
| 🖥️ **Assist. Remota** | Scarica e avvia RustDesk | ❌ |
| 🌐 **Assist. LAN** | Avvia TightVNC Viewer | ❌ |
| 🖥️ **RDP LAN** | Gestore sessioni RDP | ❌ |

---

# 🤖 **Assistente AI Chat (Modulo AICHAT.ps1)**

L'assistente AI integrato è stato progettato per rispondere a domande specifiche sul software **Manutenzione PRO MAX**, sui suoi moduli e sulle sue funzionalità.

### 🧠 **Prompt di Sistema Personalizzabile**
Il comportamento e le conoscenze dell'assistente sono interamente definiti dal file `prompt.txt` situato in `Modules\Docs\Buttons\`. Puoi modificare questo file per adattare l'AI alle tue esigenze specifiche.

### ⚡ **Elaborazione Asincrona**
Le richieste vengono elaborate in background tramite `Start-Job`:
- **L'interfaccia rimane reattiva** mentre l'AI pensa e genera la risposta.
- Una barra di avanzamento e un indicatore di stato ti tengono aggiornato sull'elaborazione.
- Puoi interrompere la richiesta in qualsiasi momento tramite il pulsante **"⛔ Annulla"**.

### 🚀 **Interfaccia Pulita e Intuitiva**
- Finestra dedicata e ben organizzata con input testuale multiriga.
- **Tasto Invio** per inviare direttamente il messaggio (usa `Shift+Invio` per andare a capo).
- Pulsante **"🗑️ Cancella"** per azzerare la cronologia della chat e ripartire da zero.

### 🎨 **Log Colorato per una Lettura Immediata**
- I messaggi dell'utente sono visualizzati in **Ciano Grassetto+Corsivo**.
- Le risposte dell'assistente sono in **Verde Chiaro** con testo bianco normale.
- Ogni interazione è corredata da un timestamp per tenere traccia dei dialoghi.

---
> **Nota Tecnica:** Questa versione dell'AI Chat supporta attualmente un singolo provider API (`llm7.io`) e un modello predefinito. Le risposte sono generate esclusivamente sulla base del contenuto del file `prompt.txt` e della domanda dell'utente.

## 🔍 **Ricerca File (Modulo Search.ps1)**

| Funzione | Descrizione |
|----------|-------------|
| 📁 **Ricerca per Nome** | Cerca file in base al pattern del nome |
| 📄 **Ricerca per Contenuto** | Cerca testo all'interno dei file |
| 🔄 **Ricerca Duplicati** | Trova file duplicati tramite hash MD5 |
| 📊 **Ricerca File Grandi** | Trova file con dimensione superiore a una soglia |
| 🔄 **Ricorsiva** | Opzione per cercare nelle sottocartelle |
| 💾 **Esporta** | Esporta i risultati in CSV |

---

## 🔑 **MAS Activation (Modulo MAS.psm1)**

| Funzione | Descrizione |
|----------|-------------|
| 🔐 **Payload crittografato** | Lo script MAS è protetto da password AES-256 |
| 🔑 **Dialog password** | Finestra modale non bloccante per l'inserimento della password |
| 🚀 **Auto-decompressione** | Il payload viene decompresso ed eseguito in una finestra separata |
| 🗑️ **Rimozione automatica** | Il file temporaneo viene rimosso dopo l'esecuzione |
| 🛠️ **Supporto multi-metodo** | HWID, Ohook, TSforge, Online KMS |

---

## 📡 **Scansione Rete Pro (rete.ps1)**

Il nuovo strumento di scansione rete avanzato include:

| Funzione | Descrizione |
|----------|-------------|
| 🌐 **Scansione subnet** | Supporto per `/24`, `/23`, `/16` |
| 📶 **Ping + Porte TCP** | Rilevamento ibrido per superare i firewall |
| 🏷️ **Hostname** | 4 metodi: NetBIOS, ping -a, nslookup, DNS inverso |
| 🔌 **MAC Address** | 3 metodi: Get-NetNeighbor, arp -a, SNMP sul gateway |
| 🏭 **Vendor** | Chiamata a macvendors.com (se Internet disponibile) |
| ⏱️ **Tempi di risposta** | Misurati in ms con colorazione delle righe |
| 💾 **Esporta CSV** | Salva i risultati sul desktop |
| 🎨 **Interfaccia** | Moderna, scura, con tabella interattiva |

---

## 📖 **Istruzioni Contestuali**

| Funzione | Descrizione |
|----------|-------------|
| 🎯 **Help automatico** | Quando selezioni una categoria, le istruzioni vengono mostrate nel log |
| 📁 **File Markdown** | Le istruzioni sono memorizzate in file `.md` nella cartella `Modules\Docs\Buttons\` |
| 🎨 **Formattazione colorata** | Titoli in ciano, sottotitoli in giallo, testo in bianco |
| 📌 **Elenchi puntati** | Supporto per elenchi con pallini |
| ⚠️ **Etichette speciali** | "Nota:", "Attenzione:", "Importante:", "Suggerimento:" colorati |

**📝 Come creare le istruzioni**:

1. Crea un file `.md` nella cartella `Modules\Docs\Buttons\` con lo stesso nome della categoria (es. `Upgrade.md`, `Android.md`)
2. Usa `#` per i titoli, `##` per i sottotitoli, `-` per gli elenchi puntati
3. Usa `**grassetto**` per enfatizzare parole chiave
4. Usa etichette speciali come `Nota:`, `Attenzione:`, `Importante:`, `Suggerimento:`

**📂 File già presenti**:
Modules/Docs/Buttons/
├── Android.md
├── Backup.md
├── Diagnostica.md
├── Dominio.md
├── Privacy.md
├── Pulizia.md
├── Rete.md
├── Riparazione.md
├── Sicurezza.md
├── Sistema.md
├── Upgrade.md
└── Utility.md

## 📁 **Struttura del Repository (v3.1.0)**
ManutenzioneProMax/
│
├── 📄 Manutenzione_PRO_MAX.ps1 # Script principale (orchestratore)
├── 📄 ManutenzioneProMax.bat # Batch per esecuzione semplificata
├── 📄 AICHAT.ps1 # Modulo AI Chat (invariato)
├── 📄 Search.ps1 # Modulo Ricerca File (invariato)
├── 📄 rete.ps1 # Scansione Rete Pro (invariato)
│
├── 📁 Modules/ # Moduli funzionali (.psm1)
│ ├── 📄 Core.psm1 # Utility base (logging, UI, processi)
│ ├── 📄 Upgrade.psm1 # Aggiornamenti (Winget, Store, WU, Driver)
│ ├── 📄 Pulizia.psm1 # Pulizia (Temp, DiskCleanup, Logs)
│ ├── 📄 Rete.psm1 # Rete (DNS, IP, WiFi, SpeedTest, Blacklist)
│ ├── 📄 Riparazione.psm1 # Riparazione (SFC, DISM, RestorePoint)
│ ├── 📄 Sicurezza.psm1 # Sicurezza (Defender, EventLog, HealthCheck)
│ ├── 📄 Diagnostica.psm1 # Diagnostica (Info, Batteria, Uptime, Processi)
│ ├── 📄 Sistema.psm1 # Sistema (Visivi, Avvio, CPU, TPM)
│ ├── 📄 Dominio.psm1 # Dominio (AD, DC, GPO, LDAP)
│ ├── 📄 Backup.psm1 # Backup (Files, Avanzato)
│ ├── 📄 Privacy.psm1 # Privacy (Windows, Office, Edge, Tasks)
│ ├── 📄 Utility.psm1 # Utility (RDP, VNC, RustDesk, Shutdown)
│ ├── 📄 MAS.psm1 # Microsoft Activation Scripts (protetto da password)
│ ├── 📄 ADB.psm1 # Android Debug Bridge (gestione smartphone)
│ │
│ └── 📁 Docs/ # Documentazione contestuale
│ └── 📁 Buttons/ # Istruzioni per le categorie (file .md)
│ ├── 📄 Android.md
│ ├── 📄 Backup.md
│ ├── 📄 Diagnostica.md
│ ├── 📄 Dominio.md
│ ├── 📄 Privacy.md
│ ├── 📄 Pulizia.md
│ ├── 📄 Rete.md
│ ├── 📄 Riparazione.md
│ ├── 📄 Sicurezza.md
│ ├── 📄 Sistema.md
│ ├── 📄 Upgrade.md
│ └── 📄 Utility.md
│
├── 📁 Prompt/ # Agenti AI (creata automaticamente)
├── 📄 README.md # Documentazione
├── 📄 LICENSE # Licenza MIT
└── 📄 version.txt # Versione corrente (3.1.0)




---

## 📦 **Requisiti**

| **Requisito** | **Descrizione** |
|---------------|-----------------|
| 🖥️ **Sistema operativo** | Windows 10 o 11 (64-bit) |
| ⚡ **PowerShell** | 7.x (auto-installato se mancante) |
| 🔑 **Privilegi** | Amministrativi (per la maggior parte delle funzionalità) |
| 📦 **Winget** | Per gli aggiornamenti pacchetti (opzionale) |
| 🏢 **ActiveDirectory module** | Per le funzioni dominio (opzionale) |
| 📱 **ADB** | Per le funzioni Android (auto-installato dal modulo) |
| 🌐 **Connessione Internet** | Per aggiornamenti, SpeedTest, Whois, Blacklist Check, AI Chat |

---

## 🛠️ **Utilizzo**

### 🚀 **Esecuzione**

1. 📥 **Scaricare** tutti i file nella stessa cartella (inclusa la cartella `Modules/`)
2. ▶️ **Eseguire** `ManutenzioneProMax.bat` (doppio clic) per avviare lo strumento
   - Il batch avvia automaticamente PowerShell con i permessi necessari
   - Se PowerShell 7 non è presente, verrà installato automaticamente
3. 🔑 Per tutte le funzionalità, cliccare su **"Eleva Admin"** all'interno dello script per ottenere privilegi amministrativi

### ⚡ **Esecuzione alternativa (solo per sviluppatori)**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Manutenzione_PRO_MAX.ps1

🔄 Auto-aggiornamento
Full Update Script: Aggiorna TUTTI i file del repository (script, moduli, batch, README, LICENSE)

💾 Backup automatico: Prima di ogni aggiornamento viene creato un backup nella cartella backup_*

🚫 Esclusione: Le cartelle che iniziano con backup vengono automaticamente escluse dal backup

📖 Istruzioni contestuali
Ogni categoria ha un file .md in Modules\Docs\Buttons\ con le istruzioni

Le istruzioni vengono mostrate automaticamente nel log quando si seleziona una categoria

È possibile creare/modificare i file .md per personalizzare le istruzioni

🧪 Test
Il tool è stato testato su:

Sistema	Versione
🖥️ Windows 10	22H2 (Pro, Enterprise, Education)
🖥️ Windows 11	23H2 (Pro, Enterprise, Education)
🖥️ Windows Server	2019, 2022
⚡ PowerShell	7.0 – 7.4
📱 Android	Dispositivi con USB Debug attivo
🌐 Network scanner	Subnet /24, /23, /16
📈 Versioni
Versione	Data	Novità
3.1.0	2025-07-28	Modulo ADB completo, Modulo MAS, Istruzioni contestuali, Scrollbar per i pulsanti, Bordo verde per il log, WordWrap nei log, Pulsante "Pulisci Log", Aggiornato README
3.0.5	2025-07-21	Architettura modulare, Scansione Rete Pro, correzioni Blacklist, Ping Test, colori log
3.0.4	2025-07-15	Correzioni e ottimizzazioni
3.0.3	2025-07-10	Aggiunto Full Update Script, migliorato Upgrade Total
3.0.2	2025-07-05	Modularità, AI Chat, Ricerca File, DPI Scaling
🤝 Contributi
Segnalazioni di bug e richieste di funzionalità sono benvenute tramite GitHub Issues.

📌 Come contribuire
🍴 Fork il repository

🌿 Crea un branch per la tua funzionalità (git checkout -b feature/nuova-funzionalita)

💾 Commit le tue modifiche (git commit -am 'Aggiunta nuova funzionalità')

🚀 Push sul branch (git push origin feature/nuova-funzionalita)

🔄 Apri una Pull Request

📄 Licenza
MIT License – vedi il file LICENSE per i dettagli.

🙏 Ringraziamenti
🖥️ Microsoft per PowerShell e Windows

🤖 Google per i tool ADB

🌍 Comunità Open Source per le librerie utilizzate

🧪 Tutti i tester che hanno contribuito a migliorare lo strumento

📞 Contatti
🐙 GitHub: pierpaolosanna/ManutenzioneProMax

🌐 Homepage: massgrave.dev (per la documentazione MAS)

⭐ Supporto
Se questo strumento ti è utile, considera di mettere una stella ⭐ sul repository GitHub per supportare lo sviluppo continuo.

Manutenzione PRO MAX – Per una manutenzione completa del tuo sistema Windows e Android, tutto in un unico strumento. 🚀

text

---

## ✅ **Migliorie apportate**

| **Sezione** | **Miglioramento** |
|-------------|-------------------|
| 📊 **Badge** | Aggiunti badge per downloads, stars e versione |
| 📑 **Indice** | Creato un indice completo con link a tutte le sezioni |
| 🎯 **"Perché questo tool?"** | Nuova sezione comparativa (problema/soluzione) |
| 📊 **Tabelle** | Aggiunta colonna "Richiede Admin" con icone ✅/❌ |
| 🎨 **Icone** | Ogni funzione ha un'icona specifica (es. 📶, 🔧, 🛡️) |
| 📁 **Struttura** | Rappresentata con icone cartella/file per maggiore leggibilità |
| 📖 **Istruzioni** | Lista dei file `.md` già presenti nella cartella `Buttons/` |
| 🧪 **Test** | Tabella con sistemi e versioni testate |
| 📞 **Contatti** | Sezione con link diretti |
| 🎨 **Layout** | Più separatori visivi (`---`) e tabelle strutturate |

---

## 💾 **Come scaricare il file**

### Metodo 1: Copia e incolla
1. Seleziona tutto il testo qui sopra
2. Crea un nuovo file chiamato `README.md` nel tuo repository
3. Incolla il testo e salva

### Metodo 2: Download diretto
https://raw.githubusercontent.com/pierpaolosanna/ManutenzioneProMax/main/README.md


