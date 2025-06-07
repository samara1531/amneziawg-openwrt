#!/bin/sh

#set -x

# Цветовые переменные
GREEN="\033[32;1m"
YELLOW="\033[33;1m"
RED="\033[31;1m"
RESET="\033[0m"

# Проверка наличия доступа к репозиторию OpenWRT
check_repo() {
    echo -e "${GREEN}Проверка доступности репозитория OpenWRT...${RESET}"
    opkg update | grep -q "Failed to download" && {
        echo -e "${RED}Не удалось выполнить opkg update. Проверьте подключение к интернету или дату. Для синхронизации времени: ntpd -p ptbtime1.ptb.de${RESET}"
        exit 1
    }
}

# Установка всех необходимых пакетов
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

    for PACKAGE in kmod-amneziawg amneziawg-tools luci-app-amneziawg; do
        if opkg list-installed | grep -q "$PACKAGE"; then
            echo -e "${GREEN}${PACKAGE} уже установлен${RESET}"
        else
            echo -e "${YELLOW}Загрузка пакета ${PACKAGE}...${RESET}"
            FILE="${PACKAGE}${PKGPOSTFIX}"
            wget -O "$AWG_DIR/$FILE" "${BASE_URL}v${VERSION}/${FILE}"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${PACKAGE} загружен успешно${RESET}"
            else
                echo -e "${RED}Ошибка загрузки ${PACKAGE}. Установите вручную и повторите${RESET}"
                exit 1
            fi

            opkg install "$AWG_DIR/$FILE"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${PACKAGE} установлен успешно${RESET}"
            else
                echo -e "${RED}Ошибка установки ${PACKAGE}. Установите вручную и повторите${RESET}"
                exit 1
            fi
        fi
    done

    rm -rf "$AWG_DIR"
}

# Настройка интерфейса
configure_amneziawg_interface() {
    INTERFACE_NAME="awg1"
    CONFIG_NAME="amneziawg_awg1"
    PROTO="amneziawg"
    ZONE_NAME="awg1"

    echo -e "${YELLOW}Настройка интерфейса AmneziaWG...${RESET}"

    read -r -p "Введите PrivateKey ([Interface]):"$'\n' AWG_PRIVATE_KEY_INT
    read -r -p "Введите IP с маской, например 192.168.100.5/24 ([Interface]):"$'\n' AWG_IP
    while ! echo "$AWG_IP" | egrep -q '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; do
        echo -e "${RED}IP неверен. Повторите ввод.${RESET}"
        read -r -p "Введите IP с маской, например 192.168.100.5/24 ([Interface]):"$'\n' AWG_IP
    done

    read -r -p "Введите PublicKey ([Peer]):"$'\n' AWG_PUBLIC_KEY_INT
    read -r -p "Введите PresharedKey ([Peer]), если используется. Иначе оставьте пустым:"$'\n' AWG_PRESHARED_KEY_INT
    read -r -p "Введите Endpoint (домен или IP без порта) ([Peer]):"$'\n' AWG_ENDPOINT_INT
    read -r -p "Введите порт Endpoint ([Peer], по умолчанию 51820):"$'\n' AWG_ENDPOINT_PORT_INT
    AWG_ENDPOINT_PORT_INT=${AWG_ENDPOINT_PORT_INT:-51820}

    read -r -p "Введите значение Jc ([Interface]):"$'\n' AWG_JC
    read -r -p "Введите значение Jmin ([Interface]):"$'\n' AWG_JMIN
    read -r -p "Введите значение Jmax ([Interface]):"$'\n' AWG_JMAX
    read -r -p "Введите значение S1 ([Interface]):"$'\n' AWG_S1
    read -r -p "Введите значение S2 ([Interface]):"$'\n' AWG_S2
    read -r -p "Введите значение H1 ([Interface]):"$'\n' AWG_H1
    read -r -p "Введите значение H2 ([Interface]):"$'\n' AWG_H2

    uci set network."$CONFIG_NAME"="interface"
    uci set network."$CONFIG_NAME".proto="$PROTO"
    uci set network."$CONFIG_NAME".private_key="$AWG_PRIVATE_KEY_INT"
    uci set network."$CONFIG_NAME".ipaddr="$AWG_IP"
    uci set network."$CONFIG_NAME".public_key="$AWG_PUBLIC_KEY_INT"
    [ -n "$AWG_PRESHARED_KEY_INT" ] && uci set network."$CONFIG_NAME".preshared_key="$AWG_PRESHARED_KEY_INT"
    uci set network."$CONFIG_NAME".endpoint_host="$AWG_ENDPOINT_INT"
    uci set network."$CONFIG_NAME".endpoint_port="$AWG_ENDPOINT_PORT_INT"
    uci set network."$CONFIG_NAME".jc="$AWG_JC"
    uci set network."$CONFIG_NAME".jmin="$AWG_JMIN"
    uci set network."$CONFIG_NAME".jmax="$AWG_JMAX"
    uci set network."$CONFIG_NAME".s1="$AWG_S1"
    uci set network."$CONFIG_NAME".s2="$AWG_S2"
    uci set network."$CONFIG_NAME".h1="$AWG_H1"
    uci set network."$CONFIG_NAME".h2="$AWG_H2"

    uci commit network

    echo -e "${GREEN}Интерфейс настроен.${RESET}"

    echo -e "${YELLOW}Настройка firewall...${RESET}"
    if ! uci show firewall | grep -q "zone.*'$ZONE_NAME'"; then
        uci add firewall zone
        uci set firewall.@zone[-1].name="$ZONE_NAME"
        uci set firewall.@zone[-1].network="$INTERFACE_NAME"
        uci set firewall.@zone[-1].input="ACCEPT"
        uci set firewall.@zone[-1].output="ACCEPT"
        uci set firewall.@zone[-1].forward="REJECT"
        uci commit firewall
        echo -e "${GREEN}Зона '$ZONE_NAME' добавлена в firewall.${RESET}"
    else
        echo -e "${GREEN}Зона '$ZONE_NAME' уже существует.${RESET}"
    fi
}

# Главная функция
main() {
    echo -e "${YELLOW}===== Запуск скрипта настройки AmneziaWG на OpenWRT =====${RESET}"
    check_repo
    install_awg_packages
    configure_amneziawg_interface
    echo -e "${GREEN}===== Скрипт завершён успешно =====${RESET}"
}

main

main

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
