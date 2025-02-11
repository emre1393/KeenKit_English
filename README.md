# KeenKit
### Multifunctional script that simplifies interaction with a router based on KeeneticOS

![image_2025-02-02_17-32-41](https://github.com/user-attachments/assets/315deac4-6144-48fc-b8d3-b1107b4b1ba6)

# Installation
1. Connect via `SSH` to [Entware](https://keen-prt.github.io/wiki/helpful/entware)

2. Install the script
```
opkg update && opkg install curl && curl -L -s "https://raw.githubusercontent.com/emre1393/KeenKit_English/main/install.sh" > /tmp/install.sh && sh /tmp/install.sh
```
Run via:
`keenkit` or `/opt/keenkit.sh`

#  Command Descriptions
- ## **Update Firmware**
    - Searches for a .bin file on the internal/external storage and installs it to the Firmware partitions.
- ## **Backup Partitions**
    - Backs up selected partition(s) to the chosen storage.
- ## **Backup Entware**
    - Creates a full backup of the storage from which the script is run. It can be used as an installation backup for [new installations](https://keen-prt.github.io/wiki/helpful/entware).
    - https://bin.entware.net/mipssf-k3.4/installer/EN_mips-installer.tar.gz
    - https://bin.entware.net/mipselsf-k3.4/installer/EN_mipsel-installer.tar.gz
- ## **Replace Partition**
    - Replaces the system partition with a user-selected partition.
- ## **OTA Update**
    - Online firmware update/downgrade.
- ## **Replace Service Data**
    - Creates a new U-Config with modified service data and overwrites the current one.
