const fs = require('fs');
const path = require('path');

// Mots-clés principaux de kOS (pour information ou validation future)
const KOS_KEYWORDS = [
    'DECLARE', 'PARAMETER', 'LOCAL', 'GLOBAL', 'LOCK', 'SET', 'TO', 'IS',
    'IF', 'ELSE', 'UNTIL', 'FOR', 'IN', 'FROM', 'STEP', 'DO', 'RUN', 'WAIT',
    'STAGE', 'ON', 'OFF', 'PRINT', 'CLEARSCREEN', 'AND', 'OR', 'NOT', 'TRUE', 'FALSE'
];

/**
 * Analyse un fichier KerboScript pour détecter des erreurs de syntaxe courantes.
 * @param {string} filePath - Chemin du fichier à analyser
 * @returns {object} Résultat de l'analyse ({ success: boolean, errors: string[] })
 */
function verifyFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split(/\r?\n/);
    const errors = [];

    let openBraces = 0;
    let openParentheses = 0;
    let inCommentBlock = false; // kOS supporte principalement // mais au cas où

    // Pour l'analyse des instructions multi-lignes
    let currentStatement = '';
    let statementStartLine = 1;

    for (let i = 0; i < lines.length; i++) {
        const lineNum = i + 1;
        let line = lines[i].trim();

        // 1. Ignorer les commentaires de ligne entière et les lignes vides
        if (line.startsWith('//') || line === '') {
            continue;
        }

        // Nettoyer les commentaires en fin de ligne (en faisant attention aux chaînes de caractères)
        let cleanLine = '';
        let inString = false;
        for (let charIndex = 0; charIndex < line.length; charIndex++) {
            const char = line[charIndex];
            const nextChar = line[charIndex + 1];

            if (char === '"' && (charIndex === 0 || line[charIndex - 1] !== '\\')) {
                inString = !inString;
            }

            if (!inString && char === '/' && nextChar === '/') {
                break; // Début d'un commentaire de fin de ligne
            }
            cleanLine += char;
        }
        cleanLine = cleanLine.trim();
        if (cleanLine === '') continue;

        // Analyser caractère par caractère pour suivre les paires d'accolades/parenthèses et les chaînes
        inString = false;
        for (let charIndex = 0; charIndex < cleanLine.length; charIndex++) {
            const char = cleanLine[charIndex];
            if (char === '"' && (charIndex === 0 || cleanLine[charIndex - 1] !== '\\')) {
                inString = !inString;
                continue;
            }

            if (!inString) {
                if (char === '{') openBraces++;
                if (char === '}') {
                    openBraces--;
                    if (openBraces < 0) {
                        errors.push(`Ligne ${lineNum}: Accolade fermante '}' fermée mais aucune accolade ouverte correspondante.`);
                        openBraces = 0; // Réinitialisation pour éviter la cascade d'erreurs
                    }
                }
                if (char === '(') openParentheses++;
                if (char === ')') {
                    openParentheses--;
                    if (openParentheses < 0) {
                        errors.push(`Ligne ${lineNum}: Parenthèse fermante ')' fermée mais aucune parenthèse ouverte correspondante.`);
                        openParentheses = 0;
                    }
                }
            }
        }

        if (inString) {
            errors.push(`Ligne ${lineNum}: Chaîne de caractères non fermée (guillemet double manquant).`);
        }

        // Accumuler pour l'analyse d'instruction
        if (currentStatement === '') {
            statementStartLine = lineNum;
        }
        currentStatement += (currentStatement ? ' ' : '') + cleanLine;

        // Une instruction kOS complète se termine par :
        // - un point '.'
        // - ou une accolade ouvrante '{' (début de bloc de contrôle)
        // - ou une accolade fermante '}' (fin de bloc)
        // Note: les blocs internes comme FROM {...} UNTIL ... DO {...} se terminent par '{' (le DO) ou '}' (la fin de boucle)
        const lastChar = cleanLine[cleanLine.length - 1];
        
        // Si l'instruction semble complète, on la réinitialise
        if (lastChar === '.' || lastChar === '{' || lastChar === '}') {
            // Cas particulier : si c'est un point '.', on vérifie qu'on n'est pas juste après une accolade ouvrante/fermante hors contexte
            currentStatement = '';
        } else {
            // Si la ligne se termine sans terminateur de statement et qu'elle n'est pas suivie par une ligne qui continue (heuristic simple)
            // Dans kOS, il est courant d'écrire sur plusieurs lignes. On regarde donc si c'est la fin du fichier ou si on a accumulé trop de lignes sans terminateur.
            if (i === lines.length - 1) {
                errors.push(`Ligne ${lineNum}: L'instruction finale ne se termine ni par un point '.', ni par '{', ni par '}'.`);
            }
        }
    }

    if (openBraces > 0) {
        errors.push(`Fin de fichier: Il manque ${openBraces} accolade(s) fermante(s) '}'.`);
    }
    if (openParentheses > 0) {
        errors.push(`Fin de fichier: Il manque ${openParentheses} parenthèse(s) fermante(s) ')'.`);
    }

    return {
        success: errors.length === 0,
        errors
    };
}

// Récupération des arguments ou scan du répertoire courant
let filesToCheck = process.argv.slice(2);

if (filesToCheck.length === 0) {
    // Si aucun fichier spécifié, on scanne le dossier courant pour trouver les fichiers .ks
    const files = fs.readdirSync(__dirname);
    filesToCheck = files.filter(f => f.endsWith('.ks')).map(f => path.join(__dirname, f));
} else {
    filesToCheck = filesToCheck.map(f => path.isAbsolute(f) ? f : path.resolve(f));
}

if (filesToCheck.length === 0) {
    console.log("Aucun fichier .ks trouvé à analyser.");
    process.exit(0);
}

console.log(`=== Vérification syntaxique de ${filesToCheck.length} fichier(s) ===\n`);

let globalSuccess = true;

filesToCheck.forEach(file => {
    const relativePath = path.relative(__dirname, file);
    try {
        const result = verifyFile(file);
        if (result.success) {
            console.log(`\x1b[32m[SUCCÈS]\x1b[0m ${relativePath} : Aucune erreur détectée.`);
        } else {
            globalSuccess = false;
            console.error(`\x1b[31m[ERREUR]\x1b[0m ${relativePath} : ${result.errors.length} problème(s) détecté(s) :`);
            result.errors.forEach(err => {
                console.error(`  - ${err}`);
            });
        }
    } catch (err) {
        globalSuccess = false;
        console.error(`\x1b[31m[ÉCHEC]\x1b[0m ${relativePath} : Impossible de lire le fichier (${err.message})`);
    }
});

console.log("\n=== Fin de l'analyse ===");
process.exit(globalSuccess ? 0 : 1);
