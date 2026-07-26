// Script kOS - Déploiement de Satellite de Communication
GLOBAL runmode IS 0.

CLEARSCREEN.
PRINT "=== Déploiement de Satellite de Communication ===".

IF runmode = 0 {
    PRINT "Phase 1 : Stabilisation et Orientation Prograde..." AT (0, 2).
    RCS ON.
    LOCK STEERING TO SHIP:PROGRADE.
    
    // Attendre que l'alignement soit stabilisé
    WAIT 6.
    RCS OFF.
    SET runmode TO 1.
}

IF runmode = 1 {
    PRINT "Phase 2 : Déploiement des Panneaux et Antennes..." AT (0, 2).
    
    // Déploiement des panneaux solaires par défaut
    PANELS ON.
    PRINT "Panneaux solaires : DEPLOYÉS" AT (0, 3).
    
    // Recherche et déploiement de toutes les antennes de communication
    LOCAL parts_list IS LIST().
    LIST PARTS IN parts_list.
    LOCAL antenna_count IS 0.
    
    FOR p IN parts_list {
        // Déploiement des antennes stock KSP (ModuleDeployableAntenna)
        IF p:HASMODULE("ModuleDeployableAntenna") {
            LOCAL mod IS p:GETMODULE("ModuleDeployableAntenna").
            // Essayer d'activer via l'action standard ou le champ de déploiement
            IF mod:HASFIELD("deploy") {
                mod:SETFIELD("deploy", true).
            }
            IF mod:HASACTION("extend") {
                mod:DOACTION("extend", true).
            }
            SET antenna_count TO antenna_count + 1.
            PRINT "Antenne activée : " + p:TITLE AT (0, 4 + antenna_count).
        }
        // Compatibilité avec d'autres mods d'antenne (ex: RemoteTech)
        ELSE IF p:HASMODULE("ModuleRTAntenna") {
            LOCAL mod IS p:GETMODULE("ModuleRTAntenna").
            IF mod:HASACTION("activate") {
                mod:DOACTION("activate", true).
            }
            SET antenna_count TO antenna_count + 1.
            PRINT "Antenne RT activée : " + p:TITLE AT (0, 4 + antenna_count).
        }
    }
    
    WAIT 3.0.
    SET runmode TO 2.
}

IF runmode = 2 {
    PRINT "Phase 3 : Largage du satellite..." AT (0, 2).
    
    // Déclencher le découplage
    STAGE.
    
    PRINT "Largage effectué !" AT (0, 8).
    WAIT 2.0.
    
    // Libération des commandes
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    SET runmode TO 3.
}

PRINT "=== Mission de Déploiement Terminée avec Succès ===".
