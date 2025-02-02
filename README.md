# KeenKit
### Многофункциональный скрипт, упрощающий взаимодействие с роутером на портированной KeeneticOS

![image_2024-10-06_10-58-00](https://github.com/user-attachments/assets/aca16161-29c0-4eeb-8e08-63216f740bd2)   

# Установка
1. Через `SSH` попасть в заранее устанлвенный [Entware](https://keen-prt.github.io/wiki/helpful/entware)

2. Установить скрипт
```
opkg update && opkg install curl && curl -L -s "https://raw.githubusercontent.com/spatiumstas/KeenKit/main/install.sh" > /tmp/install.sh && sh /tmp/install.sh
```
Запуск через:
>keenkit, KeenKit или /opt/keenkit.sh

#  Описание команд
- ## **Обновить прошивку**
    - Ищет файл с расширением .bin на встроенном/внешнем накопителе с последующей установкой на разделы Firmware или Firmware_1/Firmware_2
- ## **Бэкап разделов**
    - Бэкапит раздел/ы на выбранный накопитель
- ## **Бэкап Entware**
    - Создаёт полный бэкап накопителя, из которого запущен скрипт. Его можно использовать как установочный при [новой установке](https://keen-prt.github.io/wiki/helpful/entware).
- ## **Заменить раздел**
    - Замена раздела системы на раздел, выбранный пользователем
- ## **OTA Update**
    - Онлайн обновление/даунгрейд портированных прошивок Keenetic
- ## **Заменить сервисные данные**
    - Создаёт новый U-Config с изменёнными сервисными данными, а так же перезаписывает текущий
