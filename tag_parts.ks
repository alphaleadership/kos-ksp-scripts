// Script kOS - Étiquetage Automatique des Pièces du Vaisseau
CLEARSCREEN.
PRINT "=== Étiquetage des pièces en cours ===".

LOCAL counter IS 0.
FOR p IN SHIP:PARTS {
    // Le nom de tag sera basé sur le nom interne de la pièce (ex: liquidEngine2, decoupler1...)
    LOCAL tag_name IS p:NAME.
    
    // Assigner le tag
    SET p:TAG TO tag_name.
    
    SET counter TO counter + 1.
    PRINT "Pièce " + counter + " : " + p:TITLE + " -> Tag : '" + tag_name + "'   " AT (0, 2).
    WAIT 0.01. // Légère pause pour l'affichage
}

PRINT "Terminé ! " + counter + " pièces ont été étiquetées avec succès.".
