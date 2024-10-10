#!/bin/bash

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# CONFIGURATIONS VARIABLES
SERVER_START_COMMAND="bash run.sh" # Add your server start command here like : bash run.sh +set serverProfile default +set gamename rdr3, bash run.sh, bash run.sh +set txAdminPort 40121...
INSTALL_PATH=$(dirname "$0")
ARTIFACT_PAGE_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
LATEST_ARTIFACT="" 
FULL_ARTIFACT_URL=""

# 
# Finds the latest artifact on the artifact page and set the LATEST_ARTIFACT and
# FULL_ARTIFACT_URL variables.
# If no artifact is found, it will print a message and exit the function.
# Otherwise, it will extract the latest artifact's URL and set the
# LATEST_ARTIFACT_URL variable.
check_new_artifact() {
    ARTIFACT_HTML=$(curl -s $ARTIFACT_PAGE_URL)

    ARTIFACT_LINKS=$(echo "$ARTIFACT_HTML" | grep -oP 'href="\./\d{4,}[^"]+fx\.tar\.xz"' | sed 's/href=".\/\([^"]*\)"/\1/')

    if [ -z "$ARTIFACT_LINKS" ]; then
        echo -e "${RED}Aucun artefact trouvé sur la page.${NC}"
        return
    fi

    LATEST_ARTIFACT=$(echo "$ARTIFACT_LINKS" | grep -oP '^\d{4,}' | sort -nr | head -n 1)
    LATEST_ARTIFACT_URL=$(echo "$ARTIFACT_LINKS" | grep "^$LATEST_ARTIFACT")
    FULL_ARTIFACT_URL="${ARTIFACT_PAGE_URL}${LATEST_ARTIFACT_URL}"
}

# 
# Checks if a newer version of the artifact is available and prompts the user to update.
# If the user chooses to update, it downloads the latest artifact, extracts it into the
# $INSTALL_PATH directory, and removes the temporary files.
#
update_artifact() {
    clear
    echo -e "${CYAN}Dernière version trouvée : ${YELLOW}$LATEST_ARTIFACT${NC}"
    echo -e "${CYAN}URL : ${YELLOW}$FULL_ARTIFACT_URL${NC}"

    read -p "Voulez-vous télécharger et installer cette version ? (Y/N) : " confirm
    if [[ $confirm == "Y" || $confirm == "y" ]]; then
        clear
        echo -e "${CYAN}Téléchargement de l'artefact depuis $FULL_ARTIFACT_URL...${NC}"
        echo -e "${CYAN}Suppression du répertoire 'alpine' dans $INSTALL_PATH...${NC}"
        rm -rf "$INSTALL_PATH/alpine"
        wget -O "$INSTALL_PATH/fx.tar.xz" "$FULL_ARTIFACT_URL"
        echo -e "${CYAN}Extraction de l'artefact...${NC}"
        tar -xvf "$INSTALL_PATH/fx.tar.xz" -C "$INSTALL_PATH"
        echo -e "${CYAN}Nettoyage des fichiers temporaires...${NC}"
        rm -f "$INSTALL_PATH/fx.tar.xz"
        echo -e "${GREEN}Mise à jour terminée dans le dossier $INSTALL_PATH avec la version $LATEST_ARTIFACT.${NC}"
    else
        echo -e "${YELLOW}Mise à jour annulée.${NC}"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Appuyez sur une touche pour revenir au menu..." pause
    echo -e "${NC}"
}

# 
# Prints a list of all currently running screen sessions to the console.
# The list is numbered for easy reference when stopping a screen session.
#
list_screens() {
    clear
    echo -e "${CYAN}Voici les sessions screen en cours :${NC}"
    screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | nl
}

# Stopping a screen session.
#
# This function prompts the user to choose a screen session to stop, and
# then asks for confirmation before stopping it. If the user chooses to
# stop the session, it will be stopped and the user will be informed of
# its name. If the user cancels the stop, a message will be printed to
# that effect.
#
# The screen session to stop is specified by its number in the list of
# running screen sessions, as printed by list_screens().
#
# If the user does not specify a screen session, or if the number is
# invalid, the function will print a message to that effect and return.
#
stop_screen() {
    local screen_number=$1
    if [ -z "$screen_number" ]; then
        echo -e "${YELLOW}Aucune session screen à stopper.${NC}"
        return
    fi

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${screen_number}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Numéro de screen invalide.${NC}"
        return
    fi

    echo -e "${YELLOW}Vous avez choisi de stopper la session : $screen_name${NC}"
    read -p "Voulez-vous vraiment arrêter cette session ? (Y/N) : " confirm
    if [[ $confirm == "Y" || $confirm == "y" ]]; then
        echo -e "${CYAN}Arrêt de la session screen $screen_name...${NC}"
        screen -S "$screen_name" -X quit
        echo -e "${GREEN}Session screen $screen_name arrêtée.${NC}"
    else
        echo -e "${YELLOW}Annulation de l'arrêt du screen.${NC}"
    fi
}

# Starting a server in a screen session.
#
# This function starts a server in a new screen session, named according to
# the current hostname. The server is started with the command specified in
# the SERVER_START_COMMAND variable. If the server fails to start, the
# function will print an error message and the contents of the screen log
# file. If the server starts successfully, the function will print a
# success message and return. After starting the server, the function will
# wait for the user to press a key before returning.
start_server() {
    local MACHINE_NAME=$(hostname)
    local screen_name="${MACHINE_NAME}_server_session"
    local LOG_FILE="screen_log.txt"

    rm -f "$LOG_FILE"

    echo -e "${CYAN}Lancement du serveur dans une nouvelle session screen nommée '$screen_name'...${NC}"
    screen -L -Logfile "$LOG_FILE" -dmS "$screen_name" bash -c "$SERVER_START_COMMAND"
    sleep 2
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}Serveur lancé avec succès dans la session screen '$screen_name'.${NC}"
    else
        echo -e "${RED}Erreur : la session screen '$screen_name' n'a pas pu être lancée.${NC}"
        echo -e "${CYAN}Voici les détails de l'erreur :${NC}"
        cat "$LOG_FILE"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Appuyez sur une touche pour revenir au menu..." pause
    echo -e "${NC}"
}


# Restart a server in a screen session.
#
# This function first lists all running screen sessions, then asks the user to
# select a screen session to stop. If the user selects a screen session, the
# function will stop that screen session and start a new one. If the user does
# not select a screen session, the function will start a new one without
# stopping any existing screens. After starting the server, the function will
# wait for the user to press a key before returning.
restart_server() {
    list_screens
    echo -e "${YELLOW}Appuyez sur 'Entrée' si vous ne souhaitez pas stopper une session screen existante.${NC}"
    read -p "Sélectionnez le numéro de la session screen à arrêter (ou appuyez sur Entrée pour ignorer) : " selected_screen

    if [ -n "$selected_screen" ]; then
        stop_screen "$selected_screen"
    else
        echo -e "${YELLOW}Aucune session screen n'a été arrêtée. Création d'un nouveau screen...${NC}"
    fi

    start_server
}

# Attachez-vous à une session screen existante.
# La fonction demande à l'utilisateur de choisir un numéro de session screen
# parmi la liste des sessions screen actuellement ouvertes.
# Si le numéro de session screen est valide, la fonction se connecte à cette
# session screen. Si le numéro de session screen est invalide, la fonction
# affiche un message d'erreur et s'arrête.
# La fonction affiche également un message indiquant comment quitter la
# session screen sans la fermer (appuyer sur CTRL + A puis D).
attach_screen() {
    list_screens
    read -p "Sélectionnez le numéro de la session screen à laquelle vous souhaitez vous attacher : " selected_screen

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${selected_screen}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Numéro de screen invalide.${NC}"
        return
    fi

    echo -e "${CYAN}Attachement à la session screen : $screen_name${NC}"
    echo -e "${YELLOW}Pour quitter la session screen sans la fermer, appuyez sur CTRL + A puis D.${NC}"
    screen -r "$screen_name"
}

# Affiche le menu principal et attend que l'utilisateur choisisse une option.
# Les options sont :
# 1. Mettre à jour l'artefact (nouvelle version : $LATEST_ARTIFACT)
# 2. Redémarrer le serveur dans un nouveau screen
# 3. Voir une session screen existante. ATTENTION : CTRL + A + D pour en sortir, CTRL + C = arrêt du serveur
# 4. Quitter
show_menu() {
    clear
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}   CFX Updater/Restart by Doly   ${NC}"
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}1. Mettre à jour l'artefact (nouvelle version : ${YELLOW}$LATEST_ARTIFACT${CYAN})${NC}"
    echo -e "${CYAN}2. Redémarrer le serveur dans un nouveau screen${NC}"
    echo -e "${CYAN}3. Voir une session screen existante. ${RED}ATTENTION : CTRL + A + D pour en sortir, CTRL + C = arrêt du serveur${NC}"
    echo -e "${CYAN}4. Quitter${NC}"
}

main() {
    # Gestionnaire du serveur.
    #
    # Cette fonction est le point d'entrée principal de l'outil.
    # Elle appelle la fonction check_new_artifact pour vérifier si une
    # nouvelle version de l'artefact est disponible, puis entre dans une
    # boucle infinie qui affiche le menu principal et attend que l'utilisateur
    # choisisse une option :
    #   1. Mettre à jour l'artefact (nouvelle version : $LATEST_ARTIFACT)
    #   2. Redémarrer le serveur dans un nouveau screen
    #   3. Voir une session screen existante. ATTENTION : CTRL + A + D
    #      pour en sortir, CTRL + C = arrêt du serveur
    #   4. Quitter
    #
    # Selon l'option choisie, la fonction appelle la fonction correspondante :
    #   update_artifact, restart_server, attach_screen ou exit 0.
    # Si l'utilisateur entre une option invalide, la fonction affiche un message
    # d'erreur et continue la boucle.
    check_new_artifact
    while true; do
        show_menu
        read -p "Sélectionnez une option : " option
        case $option in
            1)
                update_artifact
                ;;
            2)
                restart_server
                ;;
            3)
                attach_screen
                ;;
            4)
                echo -e "${CYAN}Merci d'avoir utilisé l'outil :) !${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Option invalide. Veuillez choisir une option valide.${NC}"
                ;;
        esac
    done
}

main
