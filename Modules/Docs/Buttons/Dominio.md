# DOMINIO - ISTRUZIONI
Questa sezione fornisce strumenti per la gestione e diagnostica di ambienti **Active Directory** e dominio Windows.  
Alcuni comandi richiedono il modulo **ActiveDirectory** (RSAT-AD-PowerShell) installato e privilegi amministrativi.
## 🏢 Informazioni Dominio
- **Info Dominio** – Mostra nome PC, dominio, stato (membro/workgroup), utente corrente e, se disponibile, nome dominio, DC primario e foresta tramite modulo AD.
- **Ultimo Login** – Recupera data ultimo login, ultimo cambio password e scadenza account per l'utente corrente (richiede modulo AD).
- **Gruppi Utente** – Elenca tutti i gruppi di dominio a cui appartiene l'utente corrente (richiede modulo AD).
- **Info Sito AD** – Mostra i primi 5 siti AD con le relative subnet (richiede modulo AD).
## 🖥️ Test Connettività
- **Test DC** – Esegue un ping verso tutti i Domain Controller del dominio (replica e PDC) e mostra il tempo di risposta medio.
- **Test DNS** – Risolve il nome del dominio tramite nslookup per verificare la corretta risoluzione DNS.
- **Test LDAP** – Verifica la connettività LDAP al dominio, restituendo il Distinguished Name (richiede modulo AD).
## ⏱️ Gestione Tempo e Cache
- **Sincronizza Ora** – Forza la sincronizzazione dell'orario con il Domain Controller tramite `w32tm /resync`. Richiede privilegi amministrativi.
- **Flush Kerberos** – Svuota la cache dei ticket Kerberos (utile per risolvere problemi di autenticazione). Comando `klist purge`.
## 📋 Policy e Profili
- **Info GPO** – Mostra le GPO applicate al computer e all'utente corrente tramite `gpresult /r`.
- **Reset Profilo Rete** – Reimposta lo stack di rete (Winsock, TCP/IP) e rilascia/rinnova l'IP. **Attenzione:** causa una breve disconnessione di rete (1-2 secondi). Richiede privilegi amministrativi.
## 🔑 Gestione Account
- **Cambia Password** – Avvia la procedura interattiva per cambiare la password di dominio dell'utente corrente tramite `net user * /domain`.
## 📌 Note Generali
- Per le funzioni che richiedono **ActiveDirectory**, assicurati di avere il modulo installato:
  ```powershell
  Install-WindowsFeature RSAT-AD-PowerShell