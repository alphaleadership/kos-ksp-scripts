// boot_airplane.ks - Script de démarrage Avion avec Décollage Automatique & Fly-By-Wire (FBW)
// Gère le décollage automatique de l'avion puis active un système de stabilisation FBW.
// Supporte le maintien d'assiette, le maintien d'altitude ciblé (touches I/K), 
// le guidage automatique vers l'aérodrome insulaire (touches J/L) et la sécurité GPWS.

// Fonction pour obtenir le cap compas actuel du vaisseau
DECLARE FUNCTION compass_heading {
    LOCAL north_pole IS LATLNG(90, 0).
    LOCAL h IS 360 - north_pole:BEARING.
    IF h >= 360 { SET h TO h - 360. }
    RETURN h.
}

CLEARSCREEN.
PRINT "=== Séquence de démarrage Avion (kOS) ===".
PRINT "Préparation au décollage automatique...".
WAIT 2.

// Coordonnées de la piste de l'Island Airfield (Aérodrome Insulaire)
GLOBAL target_island IS LATLNG(-1.5293, -71.8853).

// 1. Décollage Automatique
LOCAL runway_heading IS compass_heading().
LOCAL rotation_speed IS 80. // Vitesse de rotation en m/s

PRINT "Phase 1 : Roulage et mise en poussée".
RCS OFF.
GEAR ON.
BRAKES ON. // Garder les freins serrés pendant la mise en poussée

// Activation du SAS de KSP pour stabiliser parfaitement le roulage au sol
SAS ON.
WAIT 0.5.

LOCK THROTTLE TO 1.0.

// Attente des moteurs et montée en régime
LOCAL eng_list IS LIST().
LIST ENGINES IN eng_list.
FOR eng IN eng_list {
    eng:ACTIVATE.
}
STAGE. // Allumage si nécessaire
PRINT "Attente de la poussée des réacteurs..." AT (0, 4).
WAIT 1.5. 

BRAKES OFF. // Relâche les freins
PRINT "Roulage au sol (Stabilisé par le SAS)...             " AT (0, 4).

// L'avion s'élance droit sous le contrôle du SAS de KSP (pas de verrou de direction kOS au sol)
UNTIL SHIP:VELOCITY:SURFACE:MAG >= rotation_speed {
    PRINT "Vitesse au sol : " + ROUND(SHIP:VELOCITY:SURFACE:MAG):TOSTRING + " / " + rotation_speed:TOSTRING + " m/s    " AT (0, 5).
    WAIT 0.1.
}

PRINT "Phase 2 : Rotation (Décollage)".
SAS OFF. // Désactivation du SAS pour donner le contrôle du steering à kOS
LOCK STEERING TO HEADING(runway_heading, 12, 0). // Cabrage à 12 degrés pour décoller

UNTIL ALT:RADAR > 20 AND SHIP:VERTICALSPEED > 5 {
    PRINT "Altitude Radar : " + ROUND(ALT:RADAR):TOSTRING + " m | VSpeed : " + ROUND(SHIP:VERTICALSPEED):TOSTRING + " m/s    " AT (0, 5).
    WAIT 0.1.
}

PRINT "Phase 3 : Rentrée du train d'atterrissage".
GEAR OFF.
WAIT 1.5.

CLEARSCREEN.
PRINT "=== Système Fly-By-Wire (FBW) ACTIVÉ ===".

// 2. Initialisation du Fly-By-Wire (FBW)
GLOBAL target_pitch IS 8. // Assiette de montée par défaut après envol
GLOBAL target_roll IS 0.
GLOBAL target_heading IS runway_heading.
GLOBAL target_altitude IS 0.
GLOBAL alt_hold IS FALSE.
GLOBAL island_nav IS FALSE.
GLOBAL fbw_active IS TRUE.

// Sécurité gaz post-décollage : on force 100% de poussée au début du FBW
GLOBAL fbw_throttle IS 1.0.
LOCK STEERING TO HEADING(target_heading, target_pitch, target_roll).
LOCK THROTTLE TO fbw_throttle.

UNTIL NOT fbw_active {
    LOCAL input_active IS FALSE.

    // 2.1 SÉCURITÉ GPWS (TERRAIN AVOIDANCE)
    // Si les freins sont desserrés (vol normal) et qu'on descend sous les 200m, on force la remontée
    LOCAL gpws_active IS FALSE.
    IF NOT BRAKES AND ALTITUDE < 200 {
        SET gpws_active TO TRUE.
        SET target_pitch TO 18.  // Cabrage de sécurité important
        SET target_roll TO 0.    // Rétablir les ailes à plat
        SET fbw_throttle TO 1.0. // Poussée d'urgence maximale
        SET alt_hold TO FALSE.   // Coupe le maintien d'altitude
        SET island_nav TO FALSE. // Coupe le guidage vers l'île
    }

    // Si la sécurité GPWS n'est pas active, le pilote garde le contrôle
    IF NOT gpws_active {
        // Transition sécurisée des gaz vers la manette du pilote une fois à altitude de sécurité (> 150m)
        IF ALTITUDE < 150 {
            SET fbw_throttle TO 1.0.
        } ELSE {
            SET fbw_throttle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
        }

        // Interception et contrôle du roulis (Roll) via Q / D (PILOTROLL)
        IF ABS(SHIP:CONTROL:PILOTROLL) > 0.05 {
            SET target_roll TO target_roll - (SHIP:CONTROL:PILOTROLL * 3.5).
            SET target_roll TO MAX(-45, MIN(45, target_roll)). // Limite d'inclinaison à 45°
            SET input_active TO TRUE.
        }

        // Interception et contrôle du tangage (Pitch) via Z / S (PILOTPITCH)
        IF ABS(SHIP:CONTROL:PILOTPITCH) > 0.05 {
            // En cas d'input manuel de tangage, on désactive le maintien d'altitude automatique
            IF alt_hold {
                SET alt_hold TO FALSE.
                SET target_pitch TO SHIP:PITCH. // Reprend l'assiette courante
            }
            SET target_pitch TO target_pitch + (SHIP:CONTROL:PILOTPITCH * 1.5).
            SET target_pitch TO MAX(-15, MIN(25, target_pitch)). // Limite tangage de -15° à +25°
            SET input_active TO TRUE.
        }

        // Interception et contrôle du lacet (Yaw) via A / E (PILOTYAW)
        IF ABS(SHIP:CONTROL:PILOTYAW) > 0.05 {
            // En cas d'input de lacet manuel, on désactive la navigation automatique vers l'île
            IF island_nav {
                SET island_nav TO FALSE.
                SET target_heading TO compass_heading(). // Conserve le cap actuel
            }
            SET target_heading TO target_heading + (SHIP:CONTROL:PILOTYAW * 2.0).
            IF target_heading >= 360 { SET target_heading TO target_heading - 360. }
            IF target_heading < 0 { SET target_heading TO target_heading + 360. }
            SET input_active TO TRUE.
        }

        // Contrôle d'altitude par translation verticale I / K (PILOTTRANSLATION:Y)
        IF ABS(SHIP:CONTROL:PILOTTRANSLATION:Y) > 0.05 {
            IF NOT alt_hold {
                SET alt_hold TO TRUE.
                SET target_altitude TO ROUND(ALTITUDE / 100) * 100.
            }
            SET target_altitude TO target_altitude + (SHIP:CONTROL:PILOTTRANSLATION:Y * 150).
            SET target_altitude TO MAX(100, target_altitude). // Plancher d'altitude de sécurité
            SET input_active TO TRUE.
            WAIT 0.1.
        }

        // NOUVEAU : Contrôle du cap vers l'aérodrome insulaire par translation horizontale J / L (PILOTTRANSLATION:X)
        IF ABS(SHIP:CONTROL:PILOTTRANSLATION:X) > 0.05 {
            IF NOT island_nav {
                SET island_nav TO TRUE.
            } ELSE {
                SET island_nav TO FALSE.
                SET target_heading TO compass_heading().
            }
            SET input_active TO TRUE.
            WAIT 0.3. // Délai pour éviter de basculer trop rapidement
        }

        // Gestion du calcul du cap vers l'aérodrome insulaire
        IF island_nav {
            // target_island:BEARING donne le cap direct géographique vers l'île
            SET target_heading TO target_island:BEARING.
            IF target_heading < 0 { SET target_heading TO target_heading + 360. }
        }

        // Gestion du calcul de tangage si le maintien d'altitude est activé
        IF alt_hold {
            LOCAL alt_error IS target_altitude - ALTITUDE.
            SET target_pitch TO alt_error / 25.
            SET target_pitch TO MAX(-10, MIN(15, target_pitch)). // Limite d'attitude en maintien automatique
        } ELSE {
            // Stabilisation automatique en vol rectiligne si pas d'input de roulis
            IF NOT input_active {
                IF ABS(target_roll) < 5 {
                    SET target_roll TO 0.
                }
            }
        }
    }

    // Affichage des informations de vol et des commandes (touches)
    PRINT "=== STATUT DU VOL FBW ===" AT (0, 2).
    IF alt_hold {
        PRINT "Tangage (Calculé): " + ROUND(target_pitch, 1):TOSTRING + " deg   " AT (0, 3).
    } ELSE {
        PRINT "Tangage cible    : " + ROUND(target_pitch, 1):TOSTRING + " deg   " AT (0, 3).
    }
    PRINT "Roulis cible     : " + ROUND(target_roll, 1):TOSTRING + " deg   " AT (0, 4).
    
    // Affichage du cap (manuel ou ciblé vers l'île)
    IF island_nav {
        PRINT "Cap cible        : " + ROUND(target_heading, 1):TOSTRING + " deg (Cible: ÎLE) [ACTIF]   " AT (0, 5).
    } ELSE {
        PRINT "Cap cible        : " + ROUND(target_heading, 1):TOSTRING + " deg [MANUEL]               " AT (0, 5).
    }
    
    PRINT "Vitesse          : " + ROUND(SHIP:VELOCITY:SURFACE:MAG):TOSTRING + " m/s   " AT (0, 6).
    
    // Affichage de l'état GPWS ou de l'altitude
    IF gpws_active {
        PRINT "Altitude         : " + ROUND(ALTITUDE):TOSTRING + " m [GPWS: REMONTÉE D'URGENCE (<200m)]" AT (0, 7).
        PRINT "Gaz              : 100% [SÉCURITÉ SOL ENGAGÉE]                     " AT (0, 8).
    } ELSE {
        IF alt_hold {
            PRINT "Altitude         : " + ROUND(ALTITUDE):TOSTRING + " m (Cible: " + ROUND(target_altitude):TOSTRING + " m) [ACTIF]   " AT (0, 7).
        } ELSE {
            PRINT "Altitude         : " + ROUND(ALTITUDE):TOSTRING + " m [MANUEL]                             " AT (0, 7).
        }
        
        IF ALTITUDE < 150 {
            PRINT "Gaz              : 100% [SÉCURITÉ MONTÉE INITIALE]                 " AT (0, 8).
        } ELSE {
            PRINT "Gaz              : " + ROUND(SHIP:CONTROL:PILOTMAINTHROTTLE * 100):TOSTRING + "% [PILOTE]                       " AT (0, 8).
        }
    }
    
    PRINT "=== TOUCHES DE RÉGLAGE FBW ===" AT (0, 10).
    PRINT "[Z] / [S] : Modifier Tangage Cible (Désactive Alt Hold)" AT (0, 11).
    PRINT "[Q] / [D] : Modifier Roulis Cible" AT (0, 12).
    PRINT "[A] / [E] : Modifier Cap Cible (Désactive Island Nav)" AT (0, 13).
    PRINT "[I] / [K] : Activer/Modifier l'Altitude Cible (Alt Hold)" AT (0, 14).
    PRINT "[J] / [L] : Basculer le Cap Automatique vers l'Île (Island Nav)" AT (0, 15).
    PRINT "Contrôle des gaz : Manette KSP classique (Maj/Ctrl)" AT (0, 16).

    WAIT 0.04.
}

UNLOCK STEERING.
UNLOCK THROTTLE.
PRINT "Fly-By-Wire désactivé. Commandes rendues au pilote.".
