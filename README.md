AmneziaWG for → [ImmortalWrt](https://github.com/samara15321/amneziawg-immortalwrt/releases)
--------------------------
Source Code [AmneziaVPN/WG for OpenWrt](https://github.com/amnezia-vpn/amneziawg-openwrt)

------------------------------
Краткое инфо см. в [WiKi](https://github.com/samara1531/amneziawg-openwrt/wiki)

-----------------------------
Autoinstall
```
sh <(wget -O - https://raw.githubusercontent.com/samara1531/amneziawg-openwrt/refs/heads/master/amneziawg-install.sh)
```
Rus lang (на русском)
```
sh <(wget -O - https://raw.githubusercontent.com/samara1531/amneziawg-openwrt/refs/heads/master/RU_amneziawg-install.sh)
```

что-бы весь трафик пошел через интерфейс awg выполните.
so that all traffic goes through the awg interface
```
uci set network.awg3.defaultroute='1'
uci set network.awg3.route_allowed_ips='1'
service network stop && service network start
```
