# UTILITY - ISTRUZIONI
Questa sezione raccoglie strumenti di utilità generale: gestione remota (RDP, VNC, RustDesk), controllo dell'alimentazione, e accesso ad altre funzionalità come AI Chat, Ricerca File e MAS Activation.
## ⚙️ Riavvia su BIOS
Riavvia il computer e avvia direttamente nel firmware UEFI/BIOS.  
Comando: `shutdown /r /fw /f /t 0`.  
Utile per accedere rapidamente alle impostazioni del BIOS senza premere tasti durante l'avvio.
## 🔄 Riavvia PC
Riavvia il computer immediatamente.  
Comando: `shutdown -r -t 00`.
## 👤 Disconnetti Utente
Disconnette l'utente corrente dalla sessione di Windows.  
Comando: `shutdown /l`.  
Tutte le applicazioni aperte verranno chiuse.
## ⏻ Arresta PC
Spegne il computer forzatamente.  
Comando: `shutdown -s -f -t 00`.
## ⏰ Shutdown Schedulato
Crea un'attività pianificata che esegue lo spegnimento forzato del PC ogni giorno a un'ora specificata.  
**Procedura:**
- Inserisci l'ora nel formato `HH:mm` (es. `22:30`)
- L'attività viene creata con nome `ShutdownGiornalieroForzato` e viene eseguita come `SYSTEM` con privilegi elevati
**Richiede privilegi amministrativi.**  
Per rimuovere l'attività, usa **"Rimuovi Shutdown"**.
## ❌ Rimuovi Shutdown
Rimuove l'attività pianificata di spegnimento creata con **"Shutdown Schedulato"**.  
**Richiede privilegi amministrativi.**
## 💬 AI Chat
Apre la finestra di **AI Chat** (modulo `AICHAT.ps1`).  
Permette di dialogare con un assistente AI per domande e supporto.
## 🔍 Ricerca File
Apre la finestra di **Ricerca File** (modulo `Search.ps1`).  
Permette di cercare file e cartelle sul sistema con filtri avanzati.
## 🔑 MAS Activation
Avvia **Microsoft Activation Scripts (MAS)** per attivare Windows e/o Office.  
**Richiede:**
- **Password** fornita su richiesta (contatta l'amministratore)
- **Disattivazione temporanea** dell'antivirus (MAS può essere rilevato come falso positivo)
Per maggiori dettagli, consulta la sezione **MAS** dedicata.
## 🖥️ Assistenza Remota (RustDesk)
Scarica e avvia **RustDesk** (versione portable) per assistenza remota.  
**Procedura:**
- Scarica automaticamente l'eseguibile da GitHub nella cartella `C:\Temp\RustDeskPortable`
- Se già presente, lo avvia direttamente
- Mostra **ID** e **Password** per la connessione remota (se disponibili)
## 🌐 Assistenza LAN (TightVNC)
Avvia **TightVNC Viewer** (portatile) per connettersi a un PC in rete locale.  
**Procedura:**
- Inserisci l'IP del PC remoto
- Viene avviato `lib\tvnviewer.exe` con l'IP specificato
**Prerequisito:** Il file `lib\tvnviewer.exe` deve essere presente.
## 🖥️ RDP LAN (Gestore Sessioni RDP)
Apre un'interfaccia grafica per gestire le sessioni **Remote Desktop (RDP)**.  
**Funzionalità:**
- **Salva sessioni** – memorizza IP, utente e password (cifrata in chiaro nel file JSON) nella cartella `Prompt\`
- **Connetti** – avvia una sessione RDP con le credenziali salvate
- **Elimina** – rimuove una sessione salvata
- **Nuova connessione** – crea un nuovo profilo RDP e si connette automaticamente
**Come funziona:**
1. Inserisci un nome descrittivo, IP, utente e password
2. Clicca su **"Salva e Connetti"**
3. Viene creato un file `.rdp` e un file `.json` con le credenziali
4. La sessione RDP viene avviata immediatamente
## 📌 Note Generali
- **Assistenza Remota (RustDesk)** richiede connessione Internet per il download iniziale.
- **Assistenza LAN (TightVNC)** richiede che il file `lib\tvnviewer.exe` sia presente. Se manca, scaricalo manualmente da [TightVNC](https://www.tightvnc.com/download.php).
- **RDP Manager** memorizza le password in chiaro nel file JSON; usalo solo in ambienti sicuri.
- Le operazioni di **shutdown/riavvio** sono immediate e chiudono tutte le applicazioni senza salvare.
