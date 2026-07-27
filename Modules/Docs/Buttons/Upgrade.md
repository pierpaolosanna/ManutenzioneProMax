# UPGRADE - ISTRUZIONI

Questa sezione gestisce l'aggiornamento di programmi, sistema operativo, driver e repository dello script.
## 🔑 Eleva Admin
Riavvia lo script con privilegi amministrativi.  
**Necessario** per tutte le operazioni che richiedono permessi elevati.
## 💾 Crea Ripristino
Crea un punto di ripristino del sistema.  
**Esegui sempre** questa operazione prima di qualsiasi modifica importante.
## 🔄 Winget
Aggiorna tutti i programmi installati tramite **Winget** (Windows Package Manager).  
Comando: `winget upgrade --all --force --accept-package-agreements --accept-source-agreements --include-unknown`.  
**Prerequisito:** Winget installato.  
Mostra l’avanzamento e l’esito dell’operazione.
## 📦 Store
Aggiorna le app del **Microsoft Store** tramite Winget.  
Comando: `winget upgrade --source msstore --all ...`.  
Al termine, apre automaticamente la finestra dello Store per eventuali aggiornamenti manuali.  
**Prerequisito:** Winget installato.
## 🔍 Cerca WU
Cerca aggiornamenti **Windows Update** disponibili (solo software, non driver).  
Utilizza l’oggetto COM `Microsoft.Update.Session`.  
Mostra l’elenco degli aggiornamenti trovati con i relativi numeri KB.  
**Richiede privilegi amministrativi.**  
Il risultato viene memorizzato per essere usato da **Installa WU**.
## ⬇️ Installa WU
Installa gli aggiornamenti Windows trovati (software).  
Se non è stata eseguita prima una ricerca, la esegue automaticamente.  
Scarica e installa gli aggiornamenti, mostrando il progresso per ciascuno.  
Segnala se è richiesto un riavvio.  
**Richiede privilegi amministrativi.**
## 🔧 Driver
Cerca e installa aggiornamenti **driver** tramite Windows Update.  
Mostra l’elenco dei driver disponibili e chiede conferma prima dell’installazione.  
Segnala se è richiesto un riavvio.  
**Richiede privilegi amministrativi.**
## 📦 Full Update Script
Aggiorna **TUTTI i file del repository GitHub** (script, moduli, librerie, ecc.).  
Se non forzato, verifica la versione remota e chiede conferma.  
Crea automaticamente un **backup** della cartella corrente (escludendo le cartelle `backup*`).  
Scarica ricorsivamente tutti i file dal repository (escluse `Prompt` e `Docs`).  
Al termine, offre di riavviare lo script con la nuova versione.  
**Può essere eseguito anche senza privilegi admin** (ma per installare nuovi moduli potrebbe servirli).
## ▶️ UPGRADE TOTAL
Esegue la **sequenza completa** di aggiornamento:
1. **Winget** – aggiorna tutti i programmi
2. **Store** – aggiorna le app dello Store
3. **Cerca WU** – cerca aggiornamenti Windows
4. **Installa WU** – installa gli aggiornamenti trovati
5. **Pulizia Temp** – rimuove file temporanei
6. **Flush DNS** – svuota la cache DNS
Al termine, mostra il messaggio di completamento.  
**Richiede privilegi amministrativi** per le fasi di Windows Update.
## 📌 Note Generali
- **Winget** deve essere installato per `Winget` e `Store`. Se non presente, lo script lo segnala.
- Le funzioni **WU**, **Driver** e **Full Update** richiedono **privilegi amministrativi**.
- **Crea Ripristino** e **Eleva Admin** sono disponibili per essere eseguiti prima di qualsiasi modifica.
- `UPGRADE TOTAL` è consigliato per una manutenzione completa del sistema.
- Dopo l’installazione di aggiornamenti Windows, **riavvia** il PC se richiesto.
