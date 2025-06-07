#!/bin/sh

#set -x

# Цветовые переменные
GREEN="\033[32;1m"
YELLOW="\033[33;1m"
RED="\033[31;1m"
RESET="\033[0m"

#Репозиторий OpenWRT должен быть доступен для установки зависимостей пакета kmod-amneziawg
check_repo() {
    printf "\033[32;1mChecking OpenWrt repo availability...\033[0m\n"
    opkg update | grep -q "${RED}Не удалось выполнить opkg update. Проверьте подключение к интернету или дату. Для синхронизации времени: ntpd -p ptbtime1.ptb.de${RESET}" && exit 1
}

install_awg_packages() {
    echo -e "${YELLOW}Начинается установка пакетов AmneziaWG...${RESET}"
    
    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')

    TARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 1)
    SUBTARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 2)
    VERSION=$(ubus call system board | jsonfilter -e '@.release.version')
    PKGPOSTFIX="_v${VERSION}_${PKGARCH}_${TARGET}_${SUBTARGET}.ipk"
    BASE_URL="https://github.com/samara1531/amneziawg-openwrt/releases/download/"

    AWG_DIR="/tmp/amneziawg"
    mkdir -p "$AWG_DIR"
    
    if opkg list-installed | grep -q kmod-amneziawg; then
        echo "${GREEN}${PACKAGE} уже установлен${RESET}"
    else
        KMOD_AMNEZIAWG_FILENAME="kmod-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${KMOD_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi
        
        opkg install "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi
    fi

    if opkg list-installed | grep -q amneziawg-tools; then
        echo "${GREEN}${PACKAGE} уже установлен${RESET}"
    else
        AMNEZIAWG_TOOLS_FILENAME="amneziawg-tools${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${AMNEZIAWG_TOOLS_FILENAME}"
        wget -O "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi

        opkg install "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi
    fi
    
    if opkg list-installed | grep -q luci-app-amneziawg; then
        echo "${GREEN}${PACKAGE} уже установлен${RESET}"
    else
        LUCI_APP_AMNEZIAWG_FILENAME="luci-app-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${LUCI_APP_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi

        opkg install "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "${GREEN}${PACKAGE} загружен успешно${RESET}"
        else
            echo "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
            exit 1
        fi
    fi

    rm -rf "$AWG_DIR"
}

configure_amneziawg_interface() {
    INTERFACE_NAME="awg1"
    CONFIG_NAME="amneziawg_awg1"
    PROTO="amneziawg"
    ZONE_NAME="awg1"

    read -r -p "Введите PrivateKey ([Interface]):"$'\n' AWG_PRIVATE_KEY_INT

    while true; do
        read -r -p "Введите IP с маской, например 10.2.0.2/32 ([Interface]):"$'\n' AWG_IP
        if echo "$AWG_IP" | egrep -oq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; then
            break
        else
            echo "${RED}IP неверен. Повторите ввод.${RESET}"
        fi
    done

    read -r -p "Введите PublicKey ([Peer])::"$'\n' AWG_PUBLIC_KEY_INT
    read -r -p "If use PresharedKey, Enter this (from [Peer]). If your don't use leave blank:"$'\n' AWG_PRESHARED_KEY_INT
    read -r -p "Введите PresharedKey ([Peer]), если используется. Иначе оставьте пустым:"$'\n' AWG_ENDPOINT_INT

    read -r -p "Введите Endpoint (домен или IP без порта, который до знака двоеточия : ) ([Peer]):"$'\n' AWG_ENDPOINT_INT
    read -r -p "Введите порт Endpoint ([Peer], по умолчанию 51820):"$'\n' AWG_ENDPOINT_PORT_INT
    AWG_ENDPOINT_PORT_INT=${AWG_ENDPOINT_PORT_INT:-51820}

    read -r -p "Введите значение Jc value (from [Interface]):"$'\n' AWG_JC
    read -r -p "Введите значение Jmin value (from [Interface]):"$'\n' AWG_JMIN
    read -r -p "Введите значение Jmax value (from [Interface]):"$'\n' AWG_JMAX
    read -r -p "Введите значение S1 (from [Interface]):"$'\n' AWG_S1
    read -r -p "Введите значение S2 (from [Interface]):"$'\n' AWG_S2
    read -r -p "Введите значение H1 (from [Interface]):"$'\n' AWG_H1
    read -r -p "Введите значение H2 (from [Interface]):"$'\n' AWG_H2
    read -r -p "Введите значение H3 (from [Interface]):"$'\n' AWG_H3
    read -r -p "Введите значение H4 (from [Interface]):"$'\n' AWG_H4
    
    uci set network.${INTERFACE_NAME}=interface
    uci set network.${INTERFACE_NAME}.proto=$PROTO
    uci set network.${INTERFACE_NAME}.private_key=$AWG_PRIVATE_KEY_INT
    uci set network.${INTERFACE_NAME}.listen_port='51821'
    uci set network.${INTERFACE_NAME}.addresses=$AWG_IP

    uci set network.${INTERFACE_NAME}.awg_jc=$AWG_JC
    uci set network.${INTERFACE_NAME}.awg_jmin=$AWG_JMIN
    uci set network.${INTERFACE_NAME}.awg_jmax=$AWG_JMAX
    uci set network.${INTERFACE_NAME}.awg_s1=$AWG_S1
    uci set network.${INTERFACE_NAME}.awg_s2=$AWG_S2
    uci set network.${INTERFACE_NAME}.awg_h1=$AWG_H1
    uci set network.${INTERFACE_NAME}.awg_h2=$AWG_H2
    uci set network.${INTERFACE_NAME}.awg_h3=$AWG_H3
    uci set network.${INTERFACE_NAME}.awg_h4=$AWG_H4

    if ! uci show network | grep -q ${CONFIG_NAME}; then
        uci add network ${CONFIG_NAME}
    fi

    uci set network.@${CONFIG_NAME}[0]=$CONFIG_NAME
    uci set network.@${CONFIG_NAME}[0].name="${INTERFACE_NAME}_client"
    uci set network.@${CONFIG_NAME}[0].public_key=$AWG_PUBLIC_KEY_INT
    uci set network.@${CONFIG_NAME}[0].preshared_key=$AWG_PRESHARED_KEY_INT
    uci set network.@${CONFIG_NAME}[0].route_allowed_ips='1'
    uci set network.@${CONFIG_NAME}[0].persistent_keepalive='25'
    uci set network.@${CONFIG_NAME}[0].endpoint_host=$AWG_ENDPOINT_INT
    uci set network.@${CONFIG_NAME}[0].allowed_ips='0.0.0.0/0'
    uci add_list network.@${CONFIG_NAME}[0].allowed_ips='::/0'
    uci set network.@${CONFIG_NAME}[0].endpoint_port=$AWG_ENDPOINT_PORT_INT
    uci commit network

    echo -e "${GREEN}Интерфейс настроен.${RESET}"

    echo -e "${YELLOW}Настройка firewall...${RESET}"
    if ! uci show firewall | grep -q "@zone.*name='${ZONE_NAME}'"; then
        printf "\033[32;1mZone Create\033[0m\n"
        uci add firewall zone
        uci set firewall.@zone[-1].name=$ZONE_NAME
        uci set firewall.@zone[-1].network=$INTERFACE_NAME
        uci set firewall.@zone[-1].forward='REJECT'
        uci set firewall.@zone[-1].output='ACCEPT'
        uci set firewall.@zone[-1].input='REJECT'
        uci set firewall.@zone[-1].masq='1'
        uci set firewall.@zone[-1].mtu_fix='1'
        uci set firewall.@zone[-1].family='ipv4'
        uci commit firewall
    fi

    if ! uci show firewall | grep -q "@forwarding.*name='${ZONE_NAME}'"; then
        printf "\033[32;1mConfigured forwarding\033[0m\n"
        uci add firewall forwarding
        uci set firewall.@forwarding[-1]=forwarding
        uci set firewall.@forwarding[-1].name="${ZONE_NAME}-lan"
        uci set firewall.@forwarding[-1].dest=${ZONE_NAME}
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].family='ipv4'
        uci commit firewall
    fi
}

check_repo

install_awg_packages

printf "\033[32;1mDo Вы хотите настроить amneziawg interface? (y/n): \033[0m\n"
read IS_SHOULD_CONFIGURE_AWG_INTERFACE

if [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "y" ] || [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "Y" ]; then
    configure_amneziawg_interface
else
    printf "${GREEN}===== Скрипт завершён успешно =====${RESET}"
fi

echo -e "${YELLOW}Требуется перезапустить сетевые службы, сделать это сейчас? (y/n): ${RESET}"
read RESTART_NETWORK

if [ "$RESTART_NETWORK" = "y" ] || [ "$RESTART_NETWORK" = "Y" ]; then
    echo -e "${YELLOW}Перезапуск сети...${RESET}"
    service network stop
    sleep 2
    service network start
else
    echo -e "${YELLOW}Вы можете вручную перезапустить сеть командой: ${GREEN}service network stop && service network start${RESET}"
fi
