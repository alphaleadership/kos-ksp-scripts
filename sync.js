const fs = require('fs');
const path = require('path');

const CONFIG_FILE = path.join(__dirname, 'config.json');
const DEFAULT_KSP_PATH = "C:\\Program Files\\Epic Games\\KerbalSpaceProgram\\French\\Ships\\Script";

// Charger ou créer la configuration
let kspPath = DEFAULT_KSP_PATH;
if (fs.existsSync(CONFIG_FILE)) {
    try {
        const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
        if (config.kspPath) {
            kspPath = config.kspPath;
        }
    } catch (err) {
        console.error("Erreur lors de la lecture de config.json, utilisation du chemin par défaut.");
    }
} else {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ kspPath: DEFAULT_KSP_PATH }, null, 4), 'utf-8');
    console.log(`Fichier de configuration créé : ${CONFIG_FILE}`);
    console.log(`Veuillez l'éditer si votre dossier KSP se trouve ailleurs.`);
}

console.log(`Dossier kOS cible : ${kspPath}`);

// Fonction pour copier un fichier
function copyFile(srcFile) {
    let destDir = kspPath;
    const filename = path.basename(srcFile);
    
    // Si c'est un script de boot, on le place dans le sous-dossier boot/
    if (filename.startsWith('boot_') || filename === 'boot.ks') {
        destDir = path.join(kspPath, 'boot');
    }

    if (!fs.existsSync(destDir)) {
        try {
            fs.mkdirSync(destDir, { recursive: true });
        } catch (err) {
            console.error(`Impossible de créer le dossier cible: ${err.message}`);
            return;
        }
    }

    const destFile = path.join(destDir, filename);
    fs.copyFile(srcFile, destFile, (err) => {
        if (err) {
            console.error(`Erreur de copie pour ${filename}:`, err.message);
        } else {
            console.log(`[OK] Transféré: ${filename} -> ${destFile}`);
        }
    });
}

// Fonction pour scanner et copier tous les scripts .ks
function syncAll() {
    console.log("\nSynchronisation en cours...");
    fs.readdir(__dirname, (err, files) => {
        if (err) {
            console.error("Erreur de lecture du dossier source :", err.message);
            return;
        }
        files.forEach(file => {
            if (file.endsWith('.ks')) {
                copyFile(path.join(__dirname, file));
            }
        });
    });
}

// Lancement initial
syncAll();

// Mode Watcher si l'argument --watch est passé
if (process.argv.includes('--watch')) {
    console.log("\nMode surveillance activé. En attente de modifications...");
    fs.watch(__dirname, (eventType, filename) => {
        if (filename && filename.endsWith('.ks')) {
            const fullPath = path.join(__dirname, filename);
            // Vérifier que le fichier existe toujours (pas supprimé)
            if (fs.existsSync(fullPath)) {
                console.log(`Modification détectée sur ${filename}`);
                copyFile(fullPath);
            }
        }
    });
}
