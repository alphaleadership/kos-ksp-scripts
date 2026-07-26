// Script kOS - Désorbitation Automatique de la Capsule
GLOBAL target_periapsis IS 25000. // Altitude cible de la périapsis pour la rentrée (25 km)
GLOBAL runmode IS 0.             // 0: Attente du signal de désorbitation, 1: Burn retrograde, 2: Séparation & Rentrée, 3: Déploiement des parachutes

CLEARSCREEN.
PRINT "=== Script de Désorbitation Initialisé ===".
PRINT "Appuyez sur la touche FREIN (Brakes) pour déclencher le retour.".

UNTIL runmode = 3 {
    IF runmode = 0 {
        // Détection de l'activation des freins par le joueur
        IF BRAKES {
            BRAKES OFF. // Réinitialise l'état du bouton
            SET runmode TO 1.
            CLEARSCREEN.
        }
        WAIT 0.5.
    }
    
    IF runmode = 1 {
        PRINT "Phase 1 : Orientation Rétrograde" AT (0, 2).
        RCS ON. // Active le RCS pour accélérer le pivotement rétrograde dans l'espace
        LOCK STEERING TO SHIP:RETROGRADE.
        
        // Attente que le vaisseau soit correctement aligné
        WAIT 5.
        
        PRINT "Allumage des moteurs pour désorbitation..." AT (0, 3).
        LOCK THROTTLE TO 1.0.
        
        // On pousse rétrograde jusqu'à ce que la Périapsis descende sous le seuil de rentrée
        UNTIL SHIP:PERIAPSIS <= target_periapsis OR SHIP:PERIAPSIS < 0 {
            PRINT "Périapsis actuelle : " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km   " AT (0, 4).
            WAIT 0.1.
        }
        
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        RCS OFF.
        SET runmode TO 2.
        CLEARSCREEN.
    }
    
    IF runmode = 2 {
        PRINT "Phase 2 : Séparation du module de service" AT (0, 2).
        
        // Séparation de la capsule
        STAGE.
        WAIT 2.
        
        // Verrouillage de l'orientation sur le vecteur retrograde pour que le bouclier thermique prenne l'échauffement
        RCS ON. // Maintient le RCS actif pour forcer l'orientation du bouclier thermique
        LOCK STEERING TO SHIP:RETROGRADE.
        
        PRINT "Entrée dans l'atmosphère en cours..." AT (0, 3).
        UNTIL SHIP:ALTITUDE < 35000 {
            PRINT "Altitude : " + ROUND(SHIP:ALTITUDE) + " m   " AT (0, 4).
            WAIT 1.
        }
        
        RCS OFF. // Désactivation du RCS une fois dans la zone dense pour laisser l'aérodynamique stabiliser la capsule
        SET runmode TO 3.
        CLEARSCREEN.
    }
}


// Phase 3 : Déploiement sécurisé des parachutes
PRINT "Phase 3 : Descente sous parachute" AT (0, 2).
UNLOCK STEERING. // On laisse l'aérodynamique stabiliser la capsule naturellement

// Attente d'une altitude et d'une vitesse sûre pour ouvrir les parachutes
UNTIL SHIP:ALTITUDE < 3000 AND SHIP:VELOCITY:SURFACE:MAG < 250 {
    PRINT "Altitude : " + ROUND(SHIP:ALTITUDE) + " m | Vitesse : " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s   " AT (0, 3).
    WAIT 0.5.
}

PRINT "Déploiement des parachutes !" AT (0, 5).
CHUTES ON. // Déploie tous les parachutes disponibles sur le vaisseau

// Attente du toucher final
WAIT UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED".
PRINT "Capsule au sol en sécurité ! Mission accomplie.".
