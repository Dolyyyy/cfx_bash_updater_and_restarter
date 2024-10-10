#!/bin/bash

# COLORES
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# VARIABLES CONFIGURABLES
SERVER_START_COMMAND="bash run.sh"  # Añade tu comando de inicio del servidor aquí, por ejemplo: bash run.sh +set serverProfile default +set gamename rdr3, bash run.sh, bash run.sh +set txAdminPort 40121...
INSTALL_PATH=$(dirname "$0")
ARTIFACT_PAGE_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
LATEST_ARTIFACT="" 
FULL_ARTIFACT_URL=""

# 
# Encuentra el último artefacto en la página de artefactos y establece las variables
# LATEST_ARTIFACT y FULL_ARTIFACT_URL.
# Si no se encuentra ningún artefacto, imprimirá un mensaje y saldrá de la función.
# De lo contrario, extraerá la URL del artefacto más reciente y establecerá la variable
# LATEST_ARTIFACT_URL.
check_new_artifact() {
    ARTIFACT_HTML=$(curl -s $ARTIFACT_PAGE_URL)

    ARTIFACT_LINKS=$(echo "$ARTIFACT_HTML" | grep -oP 'href="\./\d{4,}[^"]+fx\.tar\.xz"' | sed 's/href=".\/\([^"]*\)"/\1/')

    if [ -z "$ARTIFACT_LINKS" ]; then
        echo -e "${RED}No se encontró ningún artefacto en la página.${NC}"
        return
    fi

    LATEST_ARTIFACT=$(echo "$ARTIFACT_LINKS" | grep -oP '^\d{4,}' | sort -nr | head -n 1)
    LATEST_ARTIFACT_URL=$(echo "$ARTIFACT_LINKS" | grep "^$LATEST_ARTIFACT")
    FULL_ARTIFACT_URL="${ARTIFACT_PAGE_URL}${LATEST_ARTIFACT_URL}"
}

# 
# Comprueba si hay una versión más reciente del artefacto disponible y pregunta al usuario si desea actualizar.
# Si el usuario elige actualizar, descargará el último artefacto, lo extraerá en el directorio
# $INSTALL_PATH y eliminará los archivos temporales.
#
update_artifact() {
    clear
    echo -e "${CYAN}Última versión encontrada: ${YELLOW}$LATEST_ARTIFACT${NC}"
    echo -e "${CYAN}URL: ${YELLOW}$FULL_ARTIFACT_URL${NC}"

    read -p "¿Deseas descargar e instalar esta versión? (S/N): " confirm
    if [[ $confirm == "S" || $confirm == "s" ]]; then
        clear
        echo -e "${CYAN}Descargando el artefacto desde $FULL_ARTIFACT_URL...${NC}"
        echo -e "${CYAN}Eliminando el directorio 'alpine' en $INSTALL_PATH...${NC}"
        rm -rf "$INSTALL_PATH/alpine"
        wget -O "$INSTALL_PATH/fx.tar.xz" "$FULL_ARTIFACT_URL"
        echo -e "${CYAN}Extrayendo el artefacto...${NC}"
        tar -xvf "$INSTALL_PATH/fx.tar.xz" -C "$INSTALL_PATH"
        echo -e "${CYAN}Limpiando los archivos temporales...${NC}"
        rm -f "$INSTALL_PATH/fx.tar.xz"
        echo -e "${GREEN}Actualización completada en el directorio $INSTALL_PATH con la versión $LATEST_ARTIFACT.${NC}"
    else
        echo -e "${YELLOW}Actualización cancelada.${NC}"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Presiona una tecla para volver al menú..." pause
    echo -e "${NC}"
}

# 
# Imprime una lista de todas las sesiones de screen que se están ejecutando actualmente.
# La lista está numerada para facilitar la referencia al detener una sesión de screen.
#
list_screens() {
    clear
    echo -e "${CYAN}Estas son las sesiones de screen en curso:${NC}"
    screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | nl
}

# Detener una sesión de screen.
#
# Esta función pide al usuario que elija una sesión de screen para detener y luego
# solicita confirmación antes de detenerla. Si el usuario elige detener la sesión, se
# detendrá y se informará al usuario de su nombre. Si el usuario cancela la operación, se
# imprimirá un mensaje a tal efecto.
#
# La sesión de screen a detener se especifica por su número en la lista de sesiones
# de screen en ejecución, como se imprime mediante list_screens().
#
# Si el usuario no especifica una sesión de screen, o si el número es inválido, la función
# imprimirá un mensaje y devolverá.
#
stop_screen() {
    local screen_number=$1
    if [ -z "$screen_number" ]; then
        echo -e "${YELLOW}No hay ninguna sesión de screen para detener.${NC}"
        return
    fi

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${screen_number}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Número de screen inválido.${NC}"
        return
    fi

    echo -e "${YELLOW}Has elegido detener la sesión: $screen_name${NC}"
    read -p "¿Estás seguro de que deseas detener esta sesión? (S/N): " confirm
    if [[ $confirm == "S" || $confirm == "s" ]]; then
        echo -e "${CYAN}Deteniendo la sesión de screen $screen_name...${NC}"
        screen -S "$screen_name" -X quit
        echo -e "${GREEN}Sesión de screen $screen_name detenida.${NC}"
    else
        echo -e "${YELLOW}Operación de detener cancelada.${NC}"
    fi
}

# Iniciar un servidor en una sesión de screen.
#
# Esta función inicia un servidor en una nueva sesión de screen, nombrada según
# el hostname actual. El servidor se inicia con el comando especificado en la
# variable SERVER_START_COMMAND. Si el servidor falla al iniciar, la función
# imprimirá un mensaje de error y el contenido del archivo de registro de la
# screen. Si el servidor se inicia correctamente, la función imprimirá un
# mensaje de éxito y devolverá. Después de iniciar el servidor, la función
# esperará a que el usuario presione una tecla antes de regresar.
start_server() {
    local MACHINE_NAME=$(hostname)
    local screen_name="${MACHINE_NAME}_server_session"
    local LOG_FILE="screen_log.txt"

    rm -f "$LOG_FILE"

    echo -e "${CYAN}Iniciando el servidor en una nueva sesión de screen llamada '$screen_name'...${NC}"
    screen -L -Logfile "$LOG_FILE" -dmS "$screen_name" bash -c "$SERVER_START_COMMAND"
    sleep 2
    if screen -list | grep -q "$screen_name"; then
        echo -e "${GREEN}Servidor iniciado con éxito en la sesión de screen '$screen_name'.${NC}"
    else
        echo -e "${RED}Error: No se pudo iniciar la sesión de screen '$screen_name'.${NC}"
        echo -e "${CYAN}Aquí están los detalles del error:${NC}"
        cat "$LOG_FILE"
    fi
    echo -e "${RED}"
    echo ""
    read -p "Presiona una tecla para volver al menú..." pause
    echo -e "${NC}"
}

# Reiniciar un servidor en una sesión de screen.
#
# Esta función primero lista todas las sesiones de screen que se están ejecutando y luego pide al usuario que
# seleccione una sesión de screen para detener. Si el usuario selecciona una sesión de screen, la función
# detendrá esa sesión de screen y luego iniciará una nueva. Si el usuario no selecciona ninguna sesión de screen,
# la función iniciará una nueva sin detener ninguna screen existente. Después de iniciar el servidor, la función
# esperará a que el usuario presione una tecla antes de regresar.
restart_server() {
    list_screens
    echo -e "${YELLOW}Presiona 'Enter' si no deseas detener una sesión de screen existente.${NC}"
    read -p "Selecciona el número de la sesión de screen para detener (o presiona Enter para ignorar): " selected_screen

    if [ -n "$selected_screen" ]; then
        stop_screen "$selected_screen"
    else
        echo -e "${YELLOW}No se ha detenido ninguna sesión de screen. Creando una nueva screen...${NC}"
    fi

    start_server
}

# Conectar a una sesión de screen existente.
# La función pide al usuario que seleccione un número de sesión de screen de la lista de
# sesiones de screen actualmente abiertas.
# Si el número de sesión de screen es válido, la función se conectará a esa sesión
# de screen. Si el número de sesión de screen es inválido, la función imprimirá un
# mensaje de error y se detendrá.
# La función también imprime un mensaje que indica cómo desconectarse de la sesión de
# screen sin cerrarla (presiona CTRL + A luego D).
attach_screen() {
    list_screens
    read -p "Selecciona el número de la sesión de screen a la que deseas conectarte: " selected_screen

    local screen_name=$(screen -ls | grep -Eo '[0-9]+\.[a-zA-Z0-9.-]+' | sed -n "${selected_screen}p")

    if [ -z "$screen_name" ]; then
        echo -e "${RED}Número de screen inválido.${NC}"
        return
    fi

    echo -e "${CYAN}Conectando a la sesión de screen: $screen_name${NC}"
    echo -e "${YELLOW}Para salir de la sesión de screen sin cerrarla, presiona CTRL + A luego D.${NC}"
    screen -r "$screen_name"
}

# Muestra el menú principal y espera a que el usuario elija una opción.
# Las opciones son:
# 1. Actualizar el artefacto (nueva versión: $LATEST_ARTIFACT)
# 2. Reiniciar el servidor en una nueva sesión de screen
# 3. Ver una sesión de screen existente. ATENCIÓN: CTRL + A + D para salir, CTRL + C = detener el servidor
# 4. Salir
show_menu() {
    clear
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}   CFX Updater/Restart por Doly   ${NC}"
    echo -e "${CYAN}==================================${NC}"
    echo -e "${CYAN}1. Actualizar el artefacto (nueva versión: ${YELLOW}$LATEST_ARTIFACT${CYAN})${NC}"
    echo -e "${CYAN}2. Reiniciar el servidor en una nueva sesión de screen${NC}"
    echo -e "${CYAN}3. Ver una sesión de screen existente. ${RED}ATENCIÓN: CTRL + A + D para salir, CTRL + C = detener el servidor${NC}"
    echo -e "${CYAN}4. Salir${NC}"
}

main() {
    # Gestión del servidor.
    #
    # Esta función es el punto de entrada principal de la herramienta.
    # Llama a la función check_new_artifact para verificar si una nueva versión del
    # artefacto está disponible, luego entra en un bucle infinito que muestra el
    # menú principal y espera a que el usuario elija una opción:
    #   1. Actualizar el artefacto (nueva versión: $LATEST_ARTIFACT)
    #   2. Reiniciar el servidor en una nueva sesión de screen
    #   3. Ver una sesión de screen existente. ATENCIÓN: CTRL + A + D
    #      para salir, CTRL + C = detener el servidor
    #   4. Salir
    #
    # Dependiendo de la opción elegida, la función llamará a la función correspondiente:
    #   update_artifact, restart_server, attach_screen o exit 0.
    # Si el usuario ingresa una opción inválida, la función mostrará un mensaje de error
    # y continuará el bucle.
    check_new_artifact
    while true; do
        show_menu
        read -p "Selecciona una opción: " option
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
                echo -e "${CYAN}¡Gracias por usar la herramienta! :)${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida. Por favor selecciona una opción válida.${NC}"
                ;;
        esac
    done
}

main
