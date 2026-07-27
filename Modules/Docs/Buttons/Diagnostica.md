# DIAGNOSTICA - ISTRUZIONI

Questa sezione fornisce strumenti per analizzare lo stato del sistema: hardware, prestazioni, processi, spazio su disco e servizi.  
Tutti i comandi sono eseguiti in locale sul PC.
## 💻 Info Sistema
Mostra un riepilogo delle caratteristiche hardware e del sistema operativo:
- **OS** – edizione e versione di Windows
- **CPU** – modello, numero di core fisici e logici
- **RAM** – memoria totale installata (GB)
- **GPU** – scheda video principale
- **Spazio disco** – per ogni unità, spazio usato / totale (GB)
## 🔋 Batteria
Genera un report dettagliato sulla salute della batteria (se presente).  
Il report viene salvato come file HTML e aperto automaticamente nel browser.  
Contiene: capacità di progetto, capacità attuale, cicli di carica, utilizzo storico.
## ⏰ Uptime
Mostra da quanto tempo il sistema è in esecuzione:
- Data e ora dell’ultimo avvio
- Giorni e ore di uptime
- **Avviso** se l’uptime supera i 7 giorni (consiglia un riavvio)
## 📈 Top Processi
Elenca i **12 processi** che hanno consumato più CPU dall’avvio del sistema.  
Per ciascuno mostra:
- Nome del processo
- Tempo CPU (in secondi)
- Memoria utilizzata (in MB)
## 🚀 Startup
Visualizza i programmi configurati per l’avvio automatico:
- Da **HKLM\...\Run** (per tutti gli utenti)
- Da **HKCU\...\Run** (per l’utente corrente)
Utile per identificare software che rallentano l’avvio.
## 💿 Spazio Disco
Analizza lo spazio occupato dalle principali cartelle utente e di sistema:
- `Downloads`
- `Desktop`
- `Documents`
- `AppData\Local`
- `Program Files`
I risultati sono ordinati dalla cartella più grande alla più piccola, con dimensioni in GB o MB.
## ⚙️ Servizi
Verifica lo stato di alcuni servizi chiave di Windows:
- **WinUpdate** (wuauserv) – aggiornamenti Windows
- **Defender** (WinDefend) – antivirus
- **Firewall** (mpssvc) – protezione rete
- **BITS** – trasferimento file in background
- **DNS** (Dnscache) – risoluzione nomi
Per ogni servizio viene indicato se è in esecuzione (`OK`) o fermo (`--`).
## 📌 Note Generali
- Tutte le funzioni sono **non invasive** – leggono informazioni, non modificano il sistema.
- Se un comando non trova dati (es. batteria assente), viene segnalato con un messaggio informativo.
- Per ottenere metriche più accurate, esegui i comandi in momenti di basso carico.
===============================================================================================
Per eseguire una funzione, clicca sul pulsante corrispondente a sinistra.
===============================================================================================