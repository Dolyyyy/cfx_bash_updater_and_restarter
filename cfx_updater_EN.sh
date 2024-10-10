#!/bin/bash

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# CONFIGURABLE VARIABLES
SERVER_START_COMMAND="bash run.sh"  # Add your server start command here like: bash run.sh +set serverProfile default +set gamename rdr3, bash run.sh, bash run.sh +set txAdminPort 40121...
INSTALL_PATH=$(dirname "$0")
ARTIFACT_PAGE_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
LATEST_ARTIFACT="" 
FULL_ARTIFACT_URL=""

# 
# Finds the latest artifact on the artifact page and sets the LATEST_ARTIFACT and
# FULL_ARTIFACT_URL variables.
# If no artifact is found, it will print a message and exit the function.
# Otherwise, it will extract the latest artifact's URL and set the
# LATEST_ARTIFACT_URL variable.
check_new_artifact() {
    ARTIFACT_HTML=$(curl -s $ARTIFACT_PAGE_URL)

    ARTIFACT_LINKS=$(echo "$ARTIFACT_HTML" | grep -oP 'href="\./\d{4,}[^"]+fx\.tar\.xz"' | sed 's/href=".\/\([^"]*\)"/\1/')

    if [ -z "$ARTIFACT_LINKS" ]; then
        echo -e "${RED}No artifact found on the page.${NC}"
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
    echo -e "${CYAN}Latest version found: ${YELLOW}$LATEST_ARTIFACT${NC}"
    echo -e "${CYAN}URL: ${YELLOW}$FULL_ARTIFACT_URL${NC}"

    read -p "Do you want to download and install this version? (Y/N): " confirm
    if [[ $confirm == "Y" || $confirm == "y" ]]; then
        clear
        echo -e "${CYAN}Downloading the artifact from $FULL_ARTIFACT_URL...${NC}"
        echo -e "${CYAN}Removing the 'alpine' directory in $INSTALL_PATH...${NC}"
        rm -rf "$INSTALL_PATH/alpine"
        wget -O "$INSTALL_PATH/fx.tar.xz" "$FULL_ARTIFACT_URL"
        echo -e "${CYAN}Extracting the artifact...${NC}"
        tar -xvf "$INSTALL_PATH/fx.tar.xz" -C "$INSTALL_PATH"
        echo -e "${CYAN}Cleaning up temporary files...${NC}"
        rm -f "$INSTALL_PATH/fx.tar.xz"
        echo -e "${GREEN}Update completed in directory $INSTALL_PATH with version $LATEST_ARTIFACT.${NC}"
    else
        echo -e "${YELLOW}Update canceled.${NC}"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Press any key to return to the menu..." pause
    echo -e "${NC}"
}

# 
# Prints a list of all currently running screen sessions to the console.
# The list is numbered for easy reference when stopping a screen session.
#
list_screens() {
    clear
    echo -e "${CYAN}Here are the currently running screen sessions:${NC}"
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
        echo -e "${YELLOW}No screen session to stop.${NC}"
        return
    fi

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${screen_number}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Invalid screen number.${NC}"
        return
    fi

    echo -e "${YELLOW}You have chosen to stop the session: $screen_name${NC}"
    read -p "Are you sure you want to stop this session? (Y/N): " confirm
    if [[ $confirm == "Y" || $confirm == "y" ]]; then
        echo -e "${CYAN}Stopping screen session $screen_name...${NC}"
        screen -S "$screen_name" -X quit
        echo -e "${GREEN}Screen session $screen_name stopped.${NC}"
    else
        echo -e "${YELLOW}Stop operation canceled.${NC}"
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

    echo -e "${CYAN}Starting the server in a new screen session named '$screen_name'...${NC}"
    screen -L -Logfile "$LOG_FILE" -dmS "$screen_name" bash -c "$SERVER_START_COMMAND"
    sleep 2
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}Server successfully started in screen session '$screen_name'.${NC}"
    else
        echo -e "${RED}Error: Screen session '$screen_name' could not be started.${NC}"
        echo -e "${CYAN}Here are the error details:${NC}"
        cat "$LOG_FILE"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Press any key to return to the menu..." pause
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
    echo -e "${YELLOW}Press 'Enter' if you don't want to stop an existing screen session.${NC}"
    read -p "Select the number of the screen session to stop (or press Enter to skip): " selected_screen

    if [ -n "$selected_screen" ]; then
        stop_screen "$selected_screen"
    else
        echo -e "${YELLOW}No screen session stopped. Creating a new screen...${NC}"
    fi

    start_server
}

# Attach to an existing screen session.
# The function asks the user to select a screen session number from the list of
# currently open screen sessions.
# If the screen session number is valid, the function will attach to that screen
# session. If the screen session number is invalid, the function will print an
# error message and stop.
# The function also prints a message indicating how to detach from the screen
# session without closing it (press CTRL + A then D).
attach_screen() {
    list_screens
    read -p "Select the number of the screen session you want to attach to: " selected_screen

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${selected_screen}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Invalid screen number.${NC}"
        return
    fi

    echo -e "${CYAN}Attaching to screen session: $screen_name${NC}"
    echo -e "${YELLOW}To detach from the screen session without closing it, press CTRL + A then D.${NC}"
    screen -r "$screen_name"
}

# Displays the main menu and waits for the user to choose an option.
# The options are:
# 1. Update the artifact (new version: $LATEST_ARTIFACT)
# 2. Restart the server in a new screen
# 3. View an existing screen session. ATTENTION: CTRL + A + D to exit, CTRL + C = stop the server
# 4. Quit
show_menu() {
    clear
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}   CFX Updater/Restart by Doly   ${NC}"
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}1. Update the artifact (new version: ${YELLOW}$LATEST_ARTIFACT${CYAN})${NC}"
    echo -e "${CYAN}2. Restart the server in a new screen${NC}"
    echo -e "${CYAN}3. View an existing screen session. ${RED}ATTENTION: CTRL + A + D to exit, CTRL + C = stop the server${NC}"
    echo -e "${CYAN}4. Quit${NC}"
}

main() {
    # Server management.
    #
    # This function is the main entry point of the tool.
    # It calls the check_new_artifact function to check if a new version of the
    # artifact is available, then enters an infinite loop that displays the
    # main menu and waits for the user to choose an option:
    #   1. Update the artifact (new version: $LATEST_ARTIFACT)
    #   2. Restart the server in a new screen
    #   3. View an existing screen session. ATTENTION: CTRL + A + D
    #      to exit, CTRL + C = stop the server
    #   4. Quit
    #
    # Depending on the chosen option, the function will call the corresponding function:
    #   update_artifact, restart_server, attach_screen, or exit 0.
    # If the user enters an invalid option, the function will display an error
    # message and continue the loop.
    check_new_artifact
    while true; do
        show_menu
        read -p "Select an option: " option
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
                echo -e "${CYAN}Thanks for using the tool! :)${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please choose a valid option.${NC}"
                ;;
        esac
    done
}

main
