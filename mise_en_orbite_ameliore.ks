// Script kOS - Mise en Orbite Automatique (Fusée 2 Étages + Capsule)
// v2 : correction du seuil carburant incohérent + filtrage des ressources de propulsion
GLOBAL target_apoapsis IS 80000. // Altitude cible de l'orbite (80 km)
GLOBAL target_direction IS 90.   // Direction équatoriale (Est)
GLOBAL runmode IS 0.             // 0: Pré-lancement, 1: Décollage, 2: Gravity Turn, 3: Attente Apoapsis, 4: Circularisation, 5: Orbite atteinte

// CORRIGÉ : le commentaire d'origine annonçait un "seuil de freinage (320 unités)"
// mais le code utilisait 1120 en dur, exactement la même incohérence commentaire/valeur
// que dans le script RTLS (où le commentaire disait 100 et le code utilisait 1120 aussi -
// probablement copié-collé d'un test sans être remis à jour). On fixe ici une constante
// nommée cohérente avec la description : 320 unités.
GLOBAL BOOSTER_FUEL_THRESHOLD IS 320.

// CORRIGÉ : liste explicite des ressources considérées comme "carburant" pour le calcul
// du seuil de séparation. Avant, le code sommait TOUTES les ressources trouvées dans
// les réservoirs tagués "booster_tank" (y compris ElectricCharge, Monopropellant, etc.
// si présents dans la même part), ce qui pouvait fausser le calcul du carburant restant.
GLOBAL PROPELLANT_RESOURCES IS LIST("LiquidFuel", "Oxidizer", "SolidFuel").

CLEARSCREEN.
PRINT "=== Script de Mise en Orbite Initialisé ===".
PRINT "Orbite cible : " + (target_apoapsis / 1000) + " km".

UNTIL runmode = 5 {
    IF runmode = 0 {
        PRINT "Prêt pour le lancement. Lancement dans 3 secondes..." AT (0, 2).
        FROM {local i is 3.} UNTIL i = 0 STEP {set i to i - 1.} DO {
            PRINT "Compte à rebours : " + i + "   " AT (0, 3).
            WAIT 1.
        }
        SET runmode TO 1.
        CLEARSCREEN.
    }

    IF runmode = 1 {
        PRINT "Phase 1 : Décollage !" AT (0, 2).
        RCS ON.
        LOCK THROTTLE TO 1.0.
        LOCK STEERING TO UP.
        STAGE.
        SET runmode TO 2.
        WAIT 2.
        CLEARSCREEN.
    }

    IF runmode = 2 {
        PRINT "Phase 2 : Gravity Turn (Guidage de montée)" AT (0, 2).

        LOCK target_pitch TO MAX(5, 90 * (1 - (SHIP:ALTITUDE / 45000))).
        LOCK STEERING TO HEADING(target_direction, target_pitch).

        // Détection du carburant restant dans les boosters pour le RTLS (nécessite le tag "booster_tank")
        LOCAL booster_fuel IS 0.
        LOCAL tanks_found IS SHIP:PARTSTAGGED("booster_tank").
        FOR tank IN tanks_found {
            FOR res IN tank:RESOURCES {
                // CORRIGÉ : on ne compte que les ressources de propulsion listées,
                // pas n'importe quelle ressource présente dans la part.
                IF PROPELLANT_RESOURCES:CONTAINS(res:NAME) {
                    SET booster_fuel TO booster_fuel + res:AMOUNT.
                }
            }
        }

        // Détection de secours par flameout
        LOCAL has_flameout IS FALSE.
        LOCAL eng_list IS LIST().
        LIST ENGINES IN eng_list.
        FOR eng IN eng_list {
            IF eng:FLAMEOUT {
                SET has_flameout TO TRUE.
            }
        }

        // Séparation si le fuel des boosters est sous le seuil de freinage (BOOSTER_FUEL_THRESHOLD unités)
        // Ou en secours si un moteur s'éteint et qu'aucun tag n'est configuré
        LOCAL should_separate IS FALSE.
        IF tanks_found:LENGTH > 0 {
            IF booster_fuel < BOOSTER_FUEL_THRESHOLD {
                SET should_separate TO TRUE.
            }
        } ELSE {
            IF has_flameout {
                SET should_separate TO TRUE.
            }
        }

        IF should_separate {
            PRINT "Carburant bas boosters ! Séparation..." AT (0, 4).
            LOCK THROTTLE TO 0.0.
            STAGE. // Découplage du premier étage (Le booster lance son script RTLS sur sa CPU)
            WAIT 2.0.
            LOCK THROTTLE TO 1.0.

            // NOTE : cette étape suppose que l'allumage du second étage est une action
            // de staging séparée de celle du découplage des boosters. Si dans ton
            // arbre de staging le moteur du second étage s'allume automatiquement au
            // même cran que le découplage, ce second STAGE. déclenchera l'étape
            // suivante (ex: coiffe) au lieu du moteur. Vérifie ton ordre de staging
            // dans le VAB/SPH si besoin.
            IF SHIP:MAXTHRUST = 0 {
                STAGE.
            }
            PRINT "Moteur du second étage allumé." AT (0, 5).
        }

        PRINT "Apoapsis actuelle : " + ROUND(SHIP:APOAPSIS) + " m   " AT (0, 3).

        IF SHIP:APOAPSIS >= target_apoapsis {
            LOCK THROTTLE TO 0.
            SET runmode TO 3.
            CLEARSCREEN.
        }
        WAIT 0.1.
    }

    IF runmode = 3 {
        PRINT "Phase 3 : Coasting vers l'Apoapsis" AT (0, 2).
        IF SHIP:ALTITUDE > 50000 {
            PANELS ON.
            PRINT "Panneaux solaires déployés." AT (0, 4).
        }

        RCS ON.
        LOCK STEERING TO SHIP:PROGRADE.

        LOCAL time_to_ap IS ETA:APOAPSIS.
        PRINT "Temps avant Apoapsis : " + ROUND(time_to_ap) + " s   " AT (0, 3).

        IF time_to_ap < 20 {
            SET runmode TO 4.
            CLEARSCREEN.
        }
        WAIT 0.5.
    }

    IF runmode = 4 {
        PRINT "Phase 4 : Circularisation" AT (0, 2).
        RCS ON.
        LOCK STEERING TO SHIP:PROGRADE.

        LOCAL mu IS SHIP:BODY:MU.
        LOCAL orbit_radius IS SHIP:APOAPSIS + SHIP:BODY:RADIUS.
        LOCAL v_target IS SQRT(mu / orbit_radius).

        LOCAL v_ap IS VELOCITYAT(SHIP, TIME + ETA:APOAPSIS):ORBIT:MAG.
        LOCAL dv IS v_target - v_ap.

        LOCAL max_accel IS SHIP:MAXTHRUST / SHIP:MASS.
        IF max_accel = 0 { SET max_accel TO 10. }
        LOCAL burn_duration IS dv / max_accel.

        PRINT "Delta-V requis : " + ROUND(dv, 1) + " m/s" AT (0, 3).
        PRINT "Durée estimée du burn : " + ROUND(burn_duration, 1) + " s" AT (0, 4).

        LOCAL burn_start_time IS ETA:APOAPSIS - (burn_duration / 2).
        IF burn_start_time > 0 {
            PRINT "Attente du point de burn : " + ROUND(burn_start_time) + " s   " AT (0, 5).
            WAIT burn_start_time.
        }

        PRINT "Allumage pour circularisation !" AT (0, 6).
        LOCK THROTTLE TO 1.0.

        UNTIL SHIP:PERIAPSIS >= target_apoapsis - 2000 OR SHIP:VELOCITY:ORBIT:MAG >= v_target {
            PRINT "Périapsis actuelle : " + ROUND(SHIP:PERIAPSIS) + " m   " AT (0, 7).
            WAIT 0.05.
        }

        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        RCS OFF.
        SET runmode TO 5.
        CLEARSCREEN.
    }
}

PRINT "Félicitations ! Orbite stable établie.".
PRINT "Apoapsis : " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
PRINT "Périapsis : " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
RCS OFF.
