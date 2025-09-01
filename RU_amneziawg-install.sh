#!/bin/sh

#set -x

# Цветовые переменные
GREEN="\033[32;1m"
YELLOW="\033[33;1m"
RED="\033[31;1m"
RESET="\033[0m"

# Репозиторий OpenWrt должен быть доступен для установки пакетов
check_repo() {
    printf "${GREEN}Проверка доступности репозитория OpenWrt...${RESET}\n\n"
    opkg update | grep -q "Failed to download" && printf "${RED}Ошибка: opkg не смог обновиться. Проверьте интернет или дату/время.\nПример синхронизации: ntpd -p ptbtime1.ptb.de${RESET}\n" && exit 1
}

install_awg_packages() {
    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')

    TARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 1)
    SUBTARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 2)
    VERSION=$(ubus call system board | jsonfilter -e '@.release.version')
    PKGPOSTFIX="_v${VERSION}_${PKGARCH}_${TARGET}_${SUBTARGET}.ipk"
    BASE_URL="https://github.com/samara1531/amneziawg-openwrt/releases/download/"

    AWG_DIR="/tmp/amneziawg"
    mkdir -p "$AWG_DIR"
    
    if opkg list-installed | grep -q kmod-amneziawg; then
        printf "${YELLOW}kmod-amneziawg уже установлен${RESET}\n\n"
    else
        KMOD_AMNEZIAWG_FILENAME="kmod-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${KMOD_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            printf "${GREEN}Файл kmod-amneziawg успешно загружен${RESET}\n\n"
        else
            printf "${RED}Ошибка загрузки kmod-amneziawg. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi
        
        opkg install "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            printf "${GREEN}kmod-amneziawg успешно установлен${RESET}\n\n"
        else
            printf "${RED}Ошибка установки kmod-amneziawg. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi
    fi

    if opkg list-installed | grep -q amneziawg-tools; then
        printf "${YELLOW}amneziawg-tools уже установлен${RESET}\n\n"
    else
        AMNEZIAWG_TOOLS_FILENAME="amneziawg-tools${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${AMNEZIAWG_TOOLS_FILENAME}"
        wget -O "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            printf "${GREEN}Файл amneziawg-tools успешно загружен${RESET}\n\n"
        else
            printf "${RED}Ошибка загрузки amneziawg-tools. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi

        opkg install "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME"

        if [ $? -eq 0 ]; then
            printf "${GREEN}amneziawg-tools успешно установлен${RESET}\n\n"
        else
            printf "${RED}Ошибка установки amneziawg-tools. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi
    fi
    
    if opkg list-installed | grep -q luci-app-amneziawg; then
        printf "${YELLOW}luci-app-amneziawg уже установлен${RESET}\n\n"
    else
        LUCI_APP_AMNEZIAWG_FILENAME="luci-app-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${LUCI_APP_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            printf "${GREEN}Файл luci-app-amneziawg успешно загружен${RESET}\n\n"
        else
            printf "${RED}Ошибка загрузки luci-app-amneziawg. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi

        opkg install "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            printf "${GREEN}luci-app-amneziawg успешно установлен${RESET}\n\n"
        else
            printf "${RED}Ошибка установки luci-app-amneziawg. Установите вручную и запустите снова${RESET}\n\n"
            exit 1
        fi
    fi

    rm -rf "$AWG_DIR"
}

configure_amneziawg_interface() {
    local cfg_file="$1"

    INTERFACE_NAME="awg3"
    CONFIG_NAME="amneziawg_awg3"
    PROTO="amneziawg"
    ZONE_NAME="awg3"

    if [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        printf "${YELLOW}Парсинг конфигурационного файла${RESET}\n\n"

        # Interface
        AWG_PRIVATE_KEY_INT=$(awk -F= '/PrivateKey/ {val=substr($0,index($0,$2)); gsub(/^[ \t]+|[ \t\r\n]+$/,"",val); print val}' "$cfg_file")
        AWG_IP=$(awk -F' *= *' '/Address/ {print $2}' "$cfg_file")

        AWG_JC=$(awk -F' *= *' '/Jc/ {print $2}' "$cfg_file")
        AWG_JMIN=$(awk -F' *= *' '/Jmin/ {print $2}' "$cfg_file")
        AWG_JMAX=$(awk -F' *= *' '/Jmax/ {print $2}' "$cfg_file")
        AWG_S1=$(awk -F' *= *' '/S1/ {print $2}' "$cfg_file")
        AWG_S2=$(awk -F' *= *' '/S2/ {print $2}' "$cfg_file")
        AWG_H1=$(awk -F' *= *' '/H1/ {print $2}' "$cfg_file")
        AWG_H2=$(awk -F' *= *' '/H2/ {print $2}' "$cfg_file")
        AWG_H3=$(awk -F' *= *' '/H3/ {print $2}' "$cfg_file")
        AWG_H4=$(awk -F' *= *' '/H4/ {print $2}' "$cfg_file")

        # Peer
        endpoint_val=$(awk -F= '/Endpoint/ {val=substr($0,index($0,$2)); gsub(/^[ \t]+|[ \t\r\n]+$/,"",val); print val}' "$cfg_file")
        AWG_ENDPOINT_INT="${endpoint_val%%:*}"
        AWG_ENDPOINT_PORT_INT="${endpoint_val##*:}"
        AWG_ENDPOINT_PORT_INT=${AWG_ENDPOINT_PORT_INT:-51820}

        AWG_PUBLIC_KEY_INT=$(awk -F= '/PublicKey/ {val=substr($0,index($0,$2)); gsub(/^[ \t]+|[ \t\r\n]+$/,"",val); print val}' "$cfg_file")
        AWG_PRESHARED_KEY_INT=$(awk -F= '/PresharedKey/ {val=substr($0,index($0,$2)); gsub(/^[ \t]+|[ \t\r\n]+$/,"",val); print val}' "$cfg_file")
    else
        printf "${YELLOW}Файл не указан или не найден, переход в интерактивный режим${RESET}\n\n"

        read -r -p "Введите PrivateKey ([Interface]):"$'\n' AWG_PRIVATE_KEY_INT

        while true; do
            read -r -p "Введите IP с маской, например 192.168.100.5/24 ([Interface]):"$'\n' AWG_IP
            if echo "$AWG_IP" | egrep -oq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; then
                break
            else
                printf "${RED}IP введён неверно. Повторите ввод${RESET}\n\n"
            fi
        done

        read -r -p "Введите PublicKey ([Peer]):"$'\n' AWG_PUBLIC_KEY_INT
        read -r -p "Если используется PresharedKey, введите его ([Peer]). Если нет — оставьте пустым:"$'\n' AWG_PRESHARED_KEY_INT
        read -r -p "Введите Endpoint (домен или IP, без порта) ([Peer]):"$'\n' AWG_ENDPOINT_INT

        read -r -p "Введите порт Endpoint ([Peer]) [51820]:"$'\n' AWG_ENDPOINT_PORT_INT
        AWG_ENDPOINT_PORT_INT=${AWG_ENDPOINT_PORT_INT:-51820}

        read -r -p "Введите значение Jc ([Interface]):"$'\n' AWG_JC
        read -r -p "Введите значение Jmin ([Interface]):"$'\n' AWG_JMIN
        read -r -p "Введите значение Jmax ([Interface]):"$'\n' AWG_JMAX
        read -r -p "Введите значение S1 ([Interface]):"$'\n' AWG_S1
        read -r -p "Введите значение S2 ([Interface]):"$'\n' AWG_S2
        read -r -p "Введите значение H1 ([Interface]):"$'\n' AWG_H1
        read -r -p "Введите значение H2 ([Interface]):"$'\n' AWG_H2
        read -r -p "Введите значение H3 ([Interface]):"$'\n' AWG_H3
        read -r -p "Введите значение H4 ([Interface]):"$'\n' AWG_H4
    fi
    
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

    printf "${GREEN}Интерфейс настроен.${RESET}\n\n"

    printf "${YELLOW}Настройка firewall...${RESET}\n\n"
    if ! uci show firewall | grep -q "@zone.*name='${ZONE_NAME}'"; then
        printf "${GREEN}Зона firewall создана${RESET}\n\n"
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
        printf "${GREEN}Настроен forwarding${RESET}\n\n"
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

read -r -p "Укажите путь к конфигурационному файлу (пусто = ручной ввод, например ~/amnezia_for_awg.conf): " AWG_CONFIG_FILE
AWG_CONFIG_FILE=$(eval echo "$AWG_CONFIG_FILE")

if [ -n "$AWG_CONFIG_FILE" ] && [ -f "$AWG_CONFIG_FILE" ]; then
    printf "${GREEN}Используется конфигурационный файл: $AWG_CONFIG_FILE${RESET}\n\n"
    configure_amneziawg_interface "$AWG_CONFIG_FILE"
else
    printf "${YELLOW}Настроить интерфейс amneziawg сейчас? (y/n): ${RESET}"
    read IS_SHOULD_CONFIGURE_AWG_INTERFACE

    if [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "y" ] || [ "$IS_SHOULD_CONFIGURE_AWG_INTERFACE" = "Y" ]; then
        configure_amneziawg_interface
    else
        printf "${RED}Настройка интерфейса amneziawg пропущена.${RESET}\n\n"
    fi
fi

printf "${YELLOW}Для запуска интерфейса AWG требуется перезапустить роутер. Сделать это сейчас? (y/n): ${RESET}"
read RESTART_ROUTER

if [ "$RESTART_ROUTER" = "y" ] || [ "$RESTART_ROUTER" = "Y" ]; then
    printf "${GREEN}Перезапуск роутера...${RESET}\n\n"
    reboot
else
    printf "${YELLOW}Вы можете вручную перезапустить командой: ${GREEN}reboot${RESET}\n\n"
fi
