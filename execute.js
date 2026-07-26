const net = require('net');

const HOST = '127.0.0.1';
const PORT = 5410;

// Récupérer la commande passée en argument
const scriptName = process.argv[2];
if (!scriptName) {
    console.error("Veuillez spécifier le script à exécuter. Exemple: node execute.js launch_orbit");
    process.exit(1);
}

const kosCommand = scriptName.endsWith('.') ? `run ${scriptName}` : `run ${scriptName}.`;

console.log(`Connexion au serveur kOS Telnet sur ${HOST}:${PORT}...`);

const client = new net.Socket();

client.connect(PORT, HOST, () => {
    console.log("Connecté avec succès ! Début de la séquence automatique...");
    
    // Séquence temporelle robuste pour laisser kOS s'initialiser et traiter chaque commande
    
    // 1. Sélectionner le CPU 1 après 1,5 seconde
    setTimeout(() => {
        console.log("[Execute] Sélection du CPU 1...");
        client.write("1\r\n");
        
        // 2. Envoyer une ligne vide après 1,5 seconde pour s'assurer que le prompt est propre
        setTimeout(() => {
            console.log("[Execute] Nettoyage du prompt...");
            client.write("\r\n");
            
            // 3. Basculer sur le volume archive (0) après 1,5 seconde
            setTimeout(() => {
                console.log("[Execute] Passage sur le volume Archive (0)...");
                client.write("switch to 0.\r\n");
                
                // 4. Lancer le script après 1,5 seconde
                setTimeout(() => {
                    console.log(`[Execute] Lancement de la commande : ${kosCommand}`);
                    client.write(`${kosCommand}\r\n`);
                    console.log("[Execute] Script lancé. Suivi de la console (Ctrl+C pour quitter) :\n");
                }, 1500);
                
            }, 1500);
            
        }, 1500);
        
    }, 1500);
});

// Relayer tout ce que kOS envoie vers la console locale
client.on('data', (data) => {
    process.stdout.write(data.toString());
});

client.on('close', () => {
    console.log('\nConnexion Telnet fermée.');
});

client.on('error', (err) => {
    console.error('\nErreur de connexion Telnet :', err.message);
    console.log("Assurez-vous que KSP est lancé, qu'un vaisseau équipé d'un kOS CPU est actif, et que Telnet est activé.");
});
