# ANDROID - ISTRUZIONI
Benvenuto nella sezione **Android** di Manutenzione PRO MAX.  
Questa sezione ti permette di gestire e controllare un dispositivo Android tramite **ADB** (Android Debug Bridge).
> **Nota:** La maggior parte dei comandi richiede che il dispositivo abbia il **debug USB attivato** e che i driver siano installati correttamente. Se è la prima volta, esegui prima **"🔌 Installa Driver ADB"**.
## 🔌 Installazione e Configurazione
- **Installa Driver ADB** – Scarica e installa automaticamente ADB (Platform Tools) e i driver USB di Google. Se `winget` è disponibile, lo usa; altrimenti scarica i file manualmente. Da eseguire la prima volta o se ADB non viene trovato.
## 📱 Gestione Dispositivi
- **Controlla Dispositivi** – Elenca tutti i dispositivi connessi via USB (o rete) e mostra lo stato (online/offline/unauthorized). Se c'è un solo dispositivo, lo seleziona automaticamente; altrimenti chiede quale usare.
- **Info Dispositivo** – Mostra informazioni dettagliate su hardware, software, batteria e memoria del dispositivo selezionato.
## 📦 Gestione Pacchetti
Questa sezione apre una finestra dedicata per gestire le app installate.
- **Gestione Pacchetti** (pulsante principale) – Apre una finestra con filtro (Tutti / Sistema / Terze parti), pulsanti per caricare la lista, esportare in .txt e azioni multiple: **Disabilita**, **Abilita**, **Disinstalla**, **Pulizia Cache**, **Pulisci Tutto (cache)**.  
  *Attenzione:* Disinstallare app di sistema può causare instabilità. Usa con cautela.
## 💾 Backup e Ripristino
- **Backup Completo** – Backup completo del dispositivo (APK, dati condivisi, sistema e tutte le app). Salva in formato `.ab` sul PC. Richiede conferma sul dispositivo.
- **Backup Dati App** – Backup dei soli dati di una specifica app (senza APK). Utile per salvare progressi o configurazioni.
- **Backup APK** – Estrae gli APK di tutti i pacchetti installati (o solo terze parti) e li salva in una cartella sul desktop. Può richiedere tempo.
- **Ripristina Backup** – Seleziona un file `.ab` e lo ripristina sul dispositivo. Richiede conferma sul dispositivo.
## 📂 Gestione File
- **Pull File (Phone → PC)** – Copia un file dal telefono al PC. Chiede il percorso remoto (es. `/sdcard/Download/file.txt`) e la destinazione locale.
- **Push File (PC → Phone)** – Copia un file dal PC al telefono. Chiede il file locale e la cartella di destinazione sul telefono (es. `/sdcard/Download/`).
## 📊 Diagnostica e Monitoraggio
- **Info Dispositivo** (già descritta) – riepilogo hardware/software/batteria/memoria.
- **Stato Batteria** – Mostra in tempo reale: livello %, temperatura (°C / °F), voltaggio, stato (carica/scarica/piena) e salute della batteria.
- **Top Processi** – Mostra i processi che consumano più CPU e memoria. Puoi scegliere il numero di processi (default 20, max 50).
- **Registra Schermo** – Avvia una registrazione video dello schermo. Parametri configurabili: durata (0=illimitata), risoluzione (es. `1280x720`), bitrate (default 4 Mbps). Il video viene salvato sul desktop in `.mp4`.
## 🔧 Amministrazione Avanzata
- **Riavvia Dispositivo** – Riavvia normalmente il dispositivo.
- **Riavvio Fastboot** – Riavvia in modalità Fastboot (per sblocco bootloader, flashing).
- **Riavvio Recovery** – Riavvia in modalità Recovery (per wipe cache, factory reset, aggiornamenti manuali).
- **Reset Dati App** – Cancella *tutti* i dati di un'app selezionata (equivale a "Cancella Dati" nelle impostazioni). **Attenzione:** i dati sono persi definitivamente.
- **Reset Impostazioni Rete** – Resetta WiFi, Bluetooth, Dati mobili e VPN. Le reti salvate vengono cancellate.
## 🔒 Sicurezza e Privacy
- **Blocca Schermo** – Simula la pressione del tasto Power.
- **Sblocca Schermo** – Tenta di sbloccare lo schermo (utile se il dispositivo è sbloccato ma lo schermo è spento). Se protetto da PIN/pattern, sblocca manualmente.
- **Invia Testo** – Invia una stringa di testo al dispositivo come se fosse digitata da tastiera. Richiede che un campo di input sia attivo.
- **Scatta Foto** – Apre l'app fotocamera e scatta una foto (salvata nella galleria).
## 📩 SMS e Chiamate
- **Leggi SMS** – Mostra gli ultimi 20 SMS ricevuti (data, mittente, corpo). Richiede il permesso di lettura SMS.
- **Effettua Chiamata** – Avvia una chiamata verso il numero inserito. Richiede il permesso di effettuare chiamate.
## ⚙️ Utility Varie
- **Screenshot** – Acquisisce uno screenshot e lo salva sul desktop.
- **Installa APK** – Apri un file `.apk` dal PC e lo installa sul dispositivo.
- **Logcat** – Mostra le ultime 100 righe del log di sistema (utile per debugging). Il log viene aperto in un file di testo.
- **Comando ADB** – Esegui un comando ADB personalizzato (es. `shell ls /sdcard`). Per operazioni non coperte dai pulsanti predefiniti.
## 📱 Scrcpy – Controllo Smartphone da PC
**A cosa serve:**  
Scrcpy è uno strumento che permette di **visualizzare e controllare lo schermo del telefono Android** direttamente dal PC tramite cavo USB. È utile per:
- Assistere a distanza un utente
- Eseguire presentazioni o dimostrazioni
- Giocare a giochi mobile con mouse e tastiera
- Testare app in ambiente controllato
- Eseguire operazioni di screenshot/registrazione senza toccare il dispositivo
**Prerequisiti:**  
- ADB installato e funzionante (se non lo è, esegui prima **"Installa Driver ADB"**)  
- Debug USB attivato sul telefono (si attiva nelle Opzioni sviluppatore)  
- Cavo USB funzionante e consenso alla connessione ADB sul dispositivo
**Come usarlo:**  
Clicca sul pulsante **"📱 Avvia Scrcpy"** nella sezione Android.  
Se Scrcpy non è ancora estratto, lo script lo farà automaticamente dal file `lib\scrcpy.zip`.  
Si aprirà una finestra che mostra lo schermo del telefono: puoi interagire con mouse e tastiera come se stessi toccando lo schermo.
**⚠️ Problema comune: "Non riesco a controllare il telefono"**  
Se Scrcpy mostra il video ma non risponde ai clic/tocchi, e vedi errori come `INJECT_EVENTS`, significa che il telefono blocca i comandi di input per sicurezza.
**Come risolvere:**  
1. **Abilita le Opzioni sviluppatore** (se non già fatto):  
   - Vai in **Impostazioni** → **Informazioni sul telefono** (o "Info sul dispositivo")  
   - Tocca **"Numero build"** (o "Versione MIUI") **7 volte** finché non vedi il messaggio *"Ora sei uno sviluppatore!"*  
2. **Attiva le impostazioni di sicurezza**:  
   - Torna al menu principale e apri **Impostazioni aggiuntive** → **Opzioni sviluppatore**  
   - Assicurati che **"USB Debugging"** sia attivo (lo è se Scrcpy mostra il video)  
   - Cerca e attiva l'opzione **"USB Debugging (Security Settings)"**  
     Su alcuni dispositivi Xiaomi/HyperOS potrebbe chiamarsi **"Consenti di simulare i tocchi"** o **"Simulate touch events"**  
3. **Riavvia il telefono** – necessario per applicare le modifiche  
4. **Ricollega il telefono al PC**, accetta le autorizzazioni ADB e riprova a lanciare Scrcpy
**Se il problema persiste, prova anche:**  
- Modalità USB: imposta su **"Trasferimento file (MTP)"**  
- Riavvia ADB: da terminale esegui `adb kill-server` e `adb start-server`  
- Disabilita temporaneamente "MIUI Optimization" nelle Opzioni sviluppatore  
- Aggiorna Scrcpy all'ultima versione da [sito ufficiale](https://github.com/Genymobile/scrcpy)  
- Prova da terminale: `scrcpy --no-clean`
## 📌 Note Generali
- Prima di usare i comandi, assicurati che il dispositivo sia connesso e che il debug USB sia attivato.
- Se il dispositivo non viene riconosciuto, esegui **"Installa Driver ADB"**.
- Per i comandi che richiedono interazione, tieni il telefono sbloccato e segui le istruzioni sullo schermo.
- La selezione multipla nella Gestione Pacchetti permette di agire su più app contemporaneamente (utile per disabilitare bloatware in blocco).
- **Suggerimento:** Crea sempre un punto di ripristino del sistema prima di disinstallare o modificare app di sistema.
===============================================================================================
Per eseguire una funzione, clicca sul pulsante corrispondente a sinistra.
===============================================================================================
