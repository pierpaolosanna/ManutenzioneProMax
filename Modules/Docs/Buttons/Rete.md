# RETE - ISTRUZIONI
Questa sezione raggruppa strumenti per la gestione e diagnostica della rete: DNS, IP, Wi‑Fi, speedtest, traceroute, whois e verifica blacklist.
## 🌐 Flush DNS
Svuota la cache DNS locale (`ipconfig /flushdns`).  
Utile per risolvere problemi di risoluzione nomi.
## 📶 Rinnovo IP
Rilascia e rinnova l’indirizzo IP tramite DHCP (`ipconfig /release` e `/renew`).  
*Breve disconnessione durante l’operazione.*
## ℹ️ Info IP
Mostra l’IP pubblico (tramite ipify.org) e la configurazione completa di rete (`ipconfig /all`).
## 🔧 Reset Winsock
Resetta lo stack Winsock e lo stack TCP/IP (`netsh winsock reset` e `netsh int ip reset`).  
**Richiede privilegi amministrativi.** Dopo il reset, è consigliato riavviare.
## 🔄 Reset Rete Completo
Esegue un reset approfondito:
- Winsock, TCP/IP, IPv6
- Cache DNS, proxy, autotuning TCP
- **Backup** della configurazione corrente in `%TEMP%\network_backup_*`  
**Richiede admin.** Riavvio consigliato.
## 🔑 Wi‑Fi Passwords
Elenca tutte le reti Wi‑Fi salvate e le relative password in chiaro (se disponibili).  
Legge i profili con `netsh wlan show profile name="..." key=clear`.
## 📡 Ping Test
Esegue un ping verso tre server DNS pubblici (Google, Cloudflare, OpenDNS) e mostra la latenza media.  
Test rapido di connettività.
## 🚀 Speed Internet (Cloudflare)
Test di velocità con Cloudflare:
- Ping (latenza)
- Download (20 MB)
- Upload (5 MB)  
Mostra velocità in Mbps.
## 📊 Speed Ookla
Test di velocità approfondito con **tre tentativi**:
1. **Ookla** – usa `speedtest.exe` (se presente in `lib\`) per risultati completi (latency, jitter, packet loss).
2. **Cloudflare** – fallback con HTTPS.
3. **Nativo** – download da provider multipli (Cloudflare, OVH, Tele2).  
Mostra IP pubblico, latenza, jitter, packet loss, velocità download/upload.  
**Nota:** Il test può richiedere fino a 60 secondi.
## 🗺️ Traceroute
Apre un dialogo per inserire IP o dominio, quindi esegue `tracert`.  
Mostra il percorso dei pacchetti fino alla destinazione.
## 🔄 Cambia DNS
Consente di impostare i server DNS su tutte le schede di rete attive.  
Opzioni predefinite: Google, Cloudflare, OpenDNS, Quad9 o personalizzato.  
**Richiede admin.** Dopo la modifica, esegue `ipconfig /flushdns`.
## 🔍 Whois
Cerca informazioni su un dominio o IP.  
Utilizza:
- **ipinfo.io** per IP
- **RDAP** per domini (con fallback manuale)
- Se il dominio non risponde via RDAP, risolve l’IP e interroga ipinfo.io  
Mostra: proprietario, paese, organizzazione, date di registrazione/scadenza, nameserver, ecc.
## 🚫 Blacklist Check
Verifica se un dominio o IP è segnalato in **oltre 100 blacklist DNSBL**.  
Procedura:
1. Risolve l’IP (se dominio)
2. Tenta con **PSBlackListChecker** (se i moduli sono installati)
3. Esegue **controllo manuale esteso** su 70+ DNSBL
4. Analizza **MultiRBL via web** (multirbl.valli.org)  
Mostra un riepilogo con il numero totale di segnalazioni e l’elenco dettagliato delle liste che hanno segnalato.
**Attenzione:** L’installazione automatica dei moduli PSBlackListChecker può richiedere 2‑5 minuti.  
**Nota:** La verifica completa può durare dai 30 ai 90 secondi a causa del gran numero di query DNS.
## 📌 Note Generali
- Le funzioni che modificano la rete (**Reset Winsock, Reset Rete, Cambia DNS**) richiedono **privilegi amministrativi**.
- **Blacklist Check** è la funzione più pesante: utilizza molte query DNS e una richiesta web. Pazientare.
- Per uno speedtest affidabile, si consiglia di chiudere altre applicazioni che usano banda.
