#!/bin/sh

#set -x

# Цветовые переменные
GREEN="\033[32;1m"
YELLOW="\033[33;1m"
RED="\033[31;1m"
RESET="\033[0m"

#Репозиторий OpenWRT должен быть доступен для установки зависимостей пакета kmod-amneziawg
check_repo() {
    printf "${RED}Проверка доступности репозитория OpenWRT..ожидайте....${RESET}"
    opkg update | grep -q "Ошибка загрузки" && printf "\033[32;1mopkg failed. Проверьте подключение к интернету, либо установленную дату\033[0m\n" && exit 1
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
        echo "kmod-amneziawg уже установлен"
    else
        KMOD_AMNEZIAWG_FILENAME="kmod-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${KMOD_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "kmod-amneziawg загружен успешно"
        else
            echo "Ошибка загрузки kmod-amneziawg. Установите вручную и повторите"
            exit 1
        fi
        
        opkg install "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "kmod-amneziawg загружен успешно"
        else
            echo "Ошибка загрузки kmod-amneziawg. Установите вручную и повторите"
            exit 1
        fi
    fi

    if opkg list-installed | grep -q amneziawg-tools; then
        echo "amneziawg-tools уже установлен"
    else
        AMNEZIAWG_TOOLS_FILENAME="amneziawg-tools${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${AMNEZIAWG_TOOLS_FILENAME}"
        wget -O "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "amneziawg-tools загружен успешно"
        else
            echo "Ошибка загрузки amneziawg-tools. Установите вручную и повторите"
            exit 1
        fi

        opkg install "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME"

        if [ $? -eq 0 ]; then
            echo "amneziawg-tools загружен успешно"
        else
            echo "Ошибка загрузки amneziawg-tools. Установите вручную и повторите"
            exit 1
        fi
    fi
    
    if opkg list-installed | grep -q luci-app-amneziawg; then
        echo "luci-app-amneziawg уже установлен"
    else
        LUCI_APP_AMNEZIAWG_FILENAME="luci-app-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${LUCI_APP_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "luci-app-amneziawg загружен успешно"
        else
            echo "Ошибка загрузки luci-app-amneziawg. Установите вручную и повторите"
            exit 1
        fi

        opkg install "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "luci-app-amneziawg загружен успешно"
        else
            echo "Ошибка загрузки luci-app-amneziawg. Установите вручную и повторите"
            exit 1
        fi
    fi

    rm -rf "$AWG_DIR"
}

configure_amneziawg_interface() {
    INTERFACE_NAME="awg3"
    CONFIG_NAME="amneziawg_awg3"
    PROTO="amneziawg"
    ZONE_NAME="awg3"

    read -r -p "Введите PrivateKey ([Interface]):"$'\n' AWG_PRIVATE_KEY_INT

    while true; do
        read -r -p "Введите IP с маской, например 10.2.0.2/32 ([Interface]):"$'\n' AWG_IP
        if echo "$AWG_IP" | egrep -oq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; then
            break
        else
            echo "IP неверен. Повторите ввод."
        fi
    done

    read -r -p "Введите PublicKey ([Peer])::"$'\n' AWG_PUBLIC_KEY_INT
    read -r -p "Если используется PresharedKey, Введите (из раздела [Peer]). Если не используется, пропустите нажав ентер:"$'\n' AWG_PRESHARED_KEY_INT

    read -r -p "Введите Endpoint (домен или IP без порта, который до знака двоеточия : ) ([Peer]):"$'\n' AWG_ENDPOINT_INT
    read -r -p "Введите порт Endpoint (который после знака двоеточия : ):"$'\n' AWG_ENDPOINT_PORT_INT
    AWG_ENDPOINT_PORT_INT=${AWG_ENDPOINT_PORT_INT:-51820}

    read -r -p "Введите значение Jc :"$'\n' AWG_JC
    read -r -p "Введите значение Jmin :"$'\n' AWG_JMIN
    read -r -p "Введите значение Jmax :"$'\n' AWG_JMAX
    read -r -p "Введите значение S1 :"$'\n' AWG_S1
    read -r -p "Введите значение S2 :"$'\n' AWG_S2
    read -r -p "Введите значение H1 :"$'\n' AWG_H1
    read -r -p "Введите значение H2 :"$'\n' AWG_H2
    read -r -p "Введите значение H3 :"$'\n' AWG_H3
    read -r -p "Введите значение H4 :"$'\n' AWG_H4
    
    uci set network.${INTERFACE_NAME}=interface
    uci set network.${INTERFACE_NAME}.proto=$PROTO
    uci set network.${INTERFACE_NAME}.private_key=$AWG_PRIVATE_KEY_INT
    uci set network.${INTERFACE_NAME}.addresses=$AWG_IP

    uci set network.${INTERFACE_NAME}.defaultroute='0' 

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
    uci set network.@${CONFIG_NAME}[0].route_allowed_ips='0'
    uci set network.@${CONFIG_NAME}[0].persistent_keepalive='25'
    uci set network.@${CONFIG_NAME}[0].endpoint_host=$AWG_ENDPOINT_INT
    uci set network.@${CONFIG_NAME}[0].allowed_ips='0.0.0.0/0'
    uci add_list network.@${CONFIG_NAME}[0].allowed_ips='::/0'
    uci set network.@${CONFIG_NAME}[0].endpoint_port=$AWG_ENDPOINT_PORT_INT
    uci commit network

    echo -e "${GREEN}Интерфейс настроен.${RESET}"

    echo -e "${YELLOW}Настройка firewall...${RESET}"
    if ! uci show firewall | grep -q "@zone.*name='${ZONE_NAME}'"; then
        printf "Zone Create"
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
        printf "${GREEN)Configured forwarding ${RESET}"
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

printf "${GREEN}Вы хотите настроить amneziawg interface? (y/n): ${RESET}"
read IS_SHOULD_CONFIGURE_AWG_INTERFACE

if [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "y" ] || [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "Y" ]; then
    configure_amneziawg_interface
else
    printf "${GREEN}===== Скрипт завершён успешно =====${RESET}"
fi

echo -e "${YELLOW}Требуется перезапустить сетевые службы, сделать это сейчас? (y/n): ${RESET}"
read RESTART_NETWORK

if [ "$RESTART_NETWORK" = "y" ] || [ "$RESTART_NETWORK" = "Y" ]; then
    echo -e "Перезапуск сети..."
    service network stop
    sleep 2
    service network start
else
    echo -e "${YELLOW}Вы можете вручную перезапустить сеть командой: ${GREEN}service network stop && service network start${RESET}"
fi
