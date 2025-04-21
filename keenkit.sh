#!/bin/sh
# translated via chatgpt and disabled some lines that sends logs to "spatiumstas" url.
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[0;36m'
NC='\033[0m'

USERNAME="spatiumstas"
USER='root'
REPO="KeenKit"
SCRIPT="keenkit.sh"
OTA_REPO="osvault"
TMP_DIR="/tmp"
OPT_DIR="/opt"
STORAGE_DIR="/storage"
SCRIPT_VERSION="2.1.5"
MIN_RAM_SIZE="256"
PACKAGES_LIST="python3-base python3 python3-light libpython3"
DATE=$(date +%Y-%m-%d_%H-%M)

print_menu() {
  printf "\033c"
  printf "${CYAN}"
  cat <<'EOF'
  _  __               _  ___ _
 | |/ /___  ___ _ __ | |/ (_) |_
 | ' // _ \/ _ \ '_ \| ' /| | __|
 | . \  __/  __/ | | | . \| | |_
 |_|\_\___|\___|_| |_|_|\_\_|\__|

EOF
  printf "${RED}Model:          ${NC}%s\n" "$(get_device) | $(get_architecture)"
  printf "${RED}OS Version:     ${NC}%s\n" "$(get_fw_version)"
  printf "${RED}RAM:            ${NC}%s\n" "$(get_ram_usage)"
  printf "${RED}Uptime:         ${NC}%s\n" "$(get_uptime)"
  printf "${RED}Script Version: ${NC}%s\n\n" "$SCRIPT_VERSION by ${USERNAME}"
  echo "1. Update firmware from file"
  echo "2. Backup partitions"
  echo "3. Backup Entware"
  echo "4. Replace partition"
  echo "5. OTA Update"
  echo "6. Replace service data"
  if get_country; then
    printf "${RED}7. 7. Change region${NC}\n"
  fi
  printf "\n88. Remove used packages\n"
  echo "99. Update script"
  echo "00. Exit"
  echo ""
}

main_menu() {
  print_menu
  read -p "Select an action: " choice
  echo ""
  choice=$(echo "$choice" | tr -d '\032' | tr -d '[A-Z]')

  if [ -z "$choice" ]; then
    main_menu
  else
    case "$choice" in
    1) firmware_manual_update ;;
    2) backup_block ;;
    3) backup_entware ;;
    4) rewrite_block ;;
    5) ota_update ;;
    6) service_data_generator ;;
    7) change_country ;;
    00) exit ;;
    88) packages_delete ;;
    99) script_update "main" ;;
    #999) script_update "dev" ;;
    *)
      echo "Invalid choice. Please try again."
      sleep 1
      main_menu
      ;;
    esac
  fi
}

print_message() {
  local message="$1"
  local color="${2:-$NC}"
  local border=$(printf '%0.s-' $(seq 1 $((${#message} + 2))))
  printf "${color}\n+${border}+\n| ${message} |\n+${border}+\n${NC}\n"
}

get_device() {
  ndmc -c show version | grep "device" | awk -F": " '{print $2}' 2>/dev/null
}

get_fw_version() {
  ndmc -c show version | grep "title" | awk -F": " '{print $2}' 2>/dev/null
}

get_device_id() {
  ndmc -c show version | grep "hw_id" | awk -F": " '{print $2}' 2>/dev/null
}

get_uptime() {
  local uptime=$(ndmc -c show system | grep "uptime" | awk '{print $2}' 2>/dev/null)
  local days=$((uptime / 86400))
  local hours=$(((uptime % 86400) / 3600))
  local minutes=$(((uptime % 3600) / 60))
  local seconds=$((uptime % 60))

  if [ "$days" -gt 0 ]; then
    printf "%d day. %02d:%02d:%02d\n" "$days" "$hours" "$minutes" "$seconds"
  else
    printf "%02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
  fi
}

get_ram_usage() {
  local memory=$(ndmc -c show system | grep "memory:" | awk '{print $2}' 2>/dev/null)
  local used=$(echo "$memory" | cut -d'/' -f1)
  local total=$(echo "$memory" | cut -d'/' -f2)
  printf "%d / %d MB\n" "$((used / 1024))" "$((total / 1024))"
}

get_ram_size() {
  ndmc -c show system | grep "memtotal" | awk '{print int($2 / 1024)}' 2>/dev/null
}

get_architecture() {
  arch=$(opkg print-architecture | grep -oE 'mips-3|mipsel-3|aarch64-3|armv7' | head -n 1)

  case "$arch" in
  "mips-3") echo "mips" ;;
  "mipsel-3") echo "mipsel" ;;
  "aarch64-3") echo "aarch64" ;;
  "armv7") echo "armv7" ;;
  *) echo "unknown_arch" ;;
  esac
}

packages_checker() {
  if ! opkg list-installed | grep -q "^curl"; then
    print_message "Installing curl..." "$GREEN"
    opkg update && opkg install curl
    echo ""
  fi
}

packages_delete() {
  delete_log=$(opkg remove $PACKAGES_LIST --autoremove 2>&1)
  removed_packages=""
  failed_packages=""

  for package in $PACKAGES_LIST; do
    if echo "$delete_log" | grep -q "Removing package $package"; then
      removed_packages="$removed_packages $package"
    elif echo "$delete_log" | grep -q "Package $package is depended upon by packages"; then
      failed_packages="$failed_packages $package"
    fi
  done

  if [ -n "$removed_packages" ]; then
    print_message "Packages successfully removed: $removed_packages" "$GREEN"
  fi

  if [ -n "$failed_packages" ]; then
    print_message "The following packages were not removed due to dependencies: $failed_packages" "$RED"
  fi

  if [ -z "$removed_packages" ] && [ -z "$failed_packages" ]; then
    print_message "he packages used are not installed." "$CYAN"
  fi

  exit_function
}

perform_dd() {
  local input_file="$1"
  local output_file="$2"

  output=$(dd if="$input_file" of="$output_file" conv=fsync 2>&1 | tee /dev/tty)

  if echo "$output" | grep -iq "error\|can't"; then
    print_message "Error while overwriting the partition" "$RED"
    exit_function
  fi
}

identify_external_drive() {
  local message=$1
  local message2=$2
  local special_message=$3
  labels=""
  uuids=""
  index=1
  media_found=0
  media_output=$(ndmc -c show media)
  current_manufacturer=""

  if [ -z "$media_output" ]; then
    print_message "Failed to retrieve the list of drives." "$RED"
    return 1
  fi

  while IFS= read -r line; do
    case "$line" in
    *"name: Media"*)
      media_found=1
      echo "0. Built-in storage $message2"
      current_manufacturer=""
      ;;
    *"manufacturer:"*)
      if [ "$media_found" = "1" ]; then
        current_manufacturer=$(echo "$line" | cut -d ':' -f2- | sed 's/^ *//g')
      fi
      ;;
    *"uuid:"*)
      if [ "$media_found" = "1" ]; then
        uuid=$(echo "$line" | cut -d ':' -f2- | sed 's/^ *//g')
        read -r label_line
        read -r fstype_line
        read -r state_line
        read -r total_line
        read -r free_line

        label=$(echo "$label_line" | cut -d ':' -f2- | sed 's/^ *//g')
        fstype=$(echo "$fstype_line" | cut -d ':' -f2- | sed 's/^ *//g')
        free_bytes=$(echo "$free_line" | cut -d ':' -f2- | sed 's/^ *//g')

        if [ "$fstype" = "swap" ]; then
          uuid=""
          continue
        fi

        free_mb=$((free_bytes / 1024 / 1024))
        free_gb=$((free_mb / 1024))

        if [ "$free_mb" -lt 1024 ]; then
          free_display="$free_mb"
          unit="MB"
        else
          free_display="$free_gb"
          unit="GB"
        fi

        if [ -n "$label" ]; then
          display_name="$label"
        elif [ -n "$current_manufacturer" ]; then
          display_name="$current_manufacturer"
        else
          display_name="Unknown"
        fi

        echo "$index. $display_name ($fstype, ${free_display}${unit})"
        labels="$labels \"$display_name\""
        uuids="$uuids $uuid"
        index=$((index + 1))
        uuid=""
      fi
      ;;
    esac
  done <<EOF
$media_output
EOF

  if [ -z "$labels" ]; then
    selected_drive="$STORAGE_DIR"
    if [ "$special_message" = "true" ]; then
      echo ""
      read -p "Only built-in storage found $message2, continue to backup? (y/n) " item_rc1
      item_rc1=$(echo "$item_rc1" | tr -d ' \n\r')
      case "$item_rc1" in
      y | Y) ;;
      n | N) exit_function ;;
      *) ;;
      esac
    fi
    return
  fi

  echo ""
  read -p "$message " choice
  choice=$(echo "$choice" | tr -d ' \n\r')
  echo ""
  if [ "$choice" = "0" ]; then
    selected_drive="$STORAGE_DIR"
  else
    selected_drive=$(echo "$uuids" | awk -v choice="$choice" '{split($0, a, " "); print a[choice]}')
    if [ -z "$selected_drive" ]; then
      print_message "Invalid choice" "$RED"
      exit_function
    fi
    selected_drive="/tmp/mnt/$selected_drive"
  fi
}

has_an_external_storage() {
  for line in $(mount | grep "/dev/sd"); do
    if echo "$line" | grep -q "$OPT_DIR"; then
      echo ""
    else
      return 0
    fi
  done
  return 1
}

get_country() {
  output=$(ndmc -c show system country)
  country=$(echo "$output" | awk '/factory:/ {print $2}')

  if [ "$country" = "RU" ]; then
    return 0
  else
    return 1
  fi
}

change_country() {
  if get_country; then
    print_message "Router region is RU, it needs to be changed to EA" "$CYAN"
    read -p "Change region? (y/n) " user_input
    user_input=$(echo "$user_input" | tr -d ' \n\r')

    case "$user_input" in
    y | Y)
      service_data_generator "country"
      ;;
    n | N)
      echo ""
      ;;
    *) ;;
    esac
  fi
  exit_function
}

backup_config() {
  if has_an_external_storage; then
    print_message "External storage devices detected" "$CYAN"
    read -p "Create a backup of startup-config? (y/n) " user_input
    user_input=$(echo "$user_input" | tr -d ' \n\r')

    case "$user_input" in
    y | Y)
      echo ""
      identify_external_drive "Select a storage device for backup:"

      if [ -n "$selected_drive" ]; then
        local device_uuid=$(echo "$selected_drive" | awk -F'/' '{print $NF}')
        local folder_path="$device_uuid:/backup$DATE"
        local backup_file="$folder_path/$(get_device_id)_$(get_fw_version)_startup-config.txt"
        mkdir -p "$selected_drive/backup$DATE"
        ndmc -c "copy startup-config $backup_file"

        if [ $? -eq 0 ]; then
          print_message "Startup-config saved to $backup_file" "$GREEN"
        else
          print_message "Error saving backup" "$RED"
        fi
      else
        echo "Backup not performed, no drive selected."
      fi
      ;;
    *)
      echo ""
      ;;
    esac
  fi
}

exit_function() {
  echo ""
  read -n 1 -s -r -p "Press any key to return..."
  main_menu
}

exit_main_menu() {
  printf "\n${CYAN}00. Exit to main menu${NC}\n\n"
}

script_update() {
  BRANCH="$1"
  packages_checker
  curl -L -s "https://raw.githubusercontent.com/emre1393/KeenKit_English/$BRANCH/$SCRIPT" --output $TMP_DIR/$SCRIPT
  #curl -L -s "https://raw.githubusercontent.com/$USERNAME/$REPO/$BRANCH/$SCRIPT" --output $TMP_DIR/$SCRIPT

  if [ -f "$TMP_DIR/$SCRIPT" ]; then
    mv "$TMP_DIR/$SCRIPT" "$OPT_DIR/$SCRIPT"
    chmod +x $OPT_DIR/$SCRIPT
    cd $OPT_DIR/bin
    ln -sf $OPT_DIR/$SCRIPT $OPT_DIR/bin/keenkit
    print_message "Script successfully updated" "$GREEN"
    $OPT_DIR/$SCRIPT post_update
  else
    print_message "Error downloading script" "$RED"
  fi
}

url() {
  #PART1="aHR0cHM6Ly9sb2c"
  #PART2="uc3BhdGl1bS5rZWVuZXRpYy5wcm8="
  #PART3="${PART1}${PART2}"
  #URL=$(echo "$PART3" | base64 -d)
  #echo "${URL}"
  # why you are trying to hide it. 
  echo "https://log.spatium.keenetic.pro"
}

post_update() {
  URL=$(url)
  JSON_DATA="{\"script_update\": \"$SCRIPT_VERSION\"}"
  # i don't want to send any info, sorry.
  #curl -X POST -H "Content-Type: application/json" -d "$JSON_DATA" "$URL" -o /dev/null -s
  main_menu
}

internet_checker() {
  if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    print_message "No internet access. Please check your connection." "$RED"
    exit_function
  fi
}

mountFS() {
  mount -t tmpfs tmpfs /tmp
  print_message "LockFS: true"
}

umountFS() {
  umount /tmp
  print_message "UnlockFS: true"
}

show_progress() {
  local total_size="$1"
  local downloaded=0
  local progress=0
  local file_path="$2"
  local file_name="$3"

  while [ "$downloaded" -lt "$total_size" ]; do
    if [ -f "$file_path" ]; then
      downloaded=$(ls -l "$file_path" | awk '{print $5}')
      progress=$((downloaded * 100 / total_size))
      printf "\Downloading $file_name... (%d%%)" "$progress"
    fi
    sleep 1
  done
  printf "\n"
}

get_ota_fw_name() {
  local FILE=$1
  URL=$(url)
  JSON_DATA="{\"filename\": \"$FILE\", \"version\": \"$SCRIPT_VERSION\"}"
  # i still don't want to send any data, sorry.
  #curl -X POST -H "Content-Type: application/json" -d "$JSON_DATA" "$URL" -o /dev/null -s
}

ota_update() {
  packages_checker
  internet_checker
  REQUEST=$(curl -s "https://api.github.com/repos/$USERNAME/$OTA_REPO/contents/")
  DIRS=$(echo "$REQUEST" | grep -Po '"name":.*?[^\\]",' | awk -F'"' '{print $4}' | grep -v '^\.\(github\)$')

  if [ -z "$DIRS" ]; then
    MESSAGE=$(echo "$REQUEST" | grep -Po '"message":.*?[^\\]",' | awk -F'"' '{print $4}')
    print_message "Error fetching data from GitHub, try again later or use VPN" "$RED"
    echo "$MESSAGE"
    exit_function
  fi

  echo "Available models:"
  i=1
  IFS=$'\n'
  for DIR in $DIRS; do
    printf "$i. $DIR\n"
    i=$((i + 1))
  done
  exit_main_menu
  read -p "Select model: " DIR_NUM
  if [ "$DIR_NUM" = "00" ]; then
    main_menu
  fi
  DIR=$(echo "$DIRS" | sed -n "${DIR_NUM}p")

  BIN_FILES=$(curl -s "https://api.github.com/repos/$USERNAME/$OTA_REPO/contents/$(echo "$DIR" | sed 's/ /%20/g')" | grep -Po '"name":.*?[^\\]",' | awk -F'"' '{print $4}' | grep ".bin")
  if [ -z "$BIN_FILES" ]; then
    printf "${RED}No files in directory $DIR.${NC}\n"
  else
    printf "\nFirmwares for $DIR:\n"
    i=1
    for FILE in $BIN_FILES; do
      printf "$i. $FILE\n"
      i=$((i + 1))
    done
    exit_main_menu
    read -p "Select firmware: " FILE_NUM
    if [ "$FILE_NUM" = "00" ]; then
      main_menu
    fi
    FILE=$(echo "$BIN_FILES" | sed -n "${FILE_NUM}p")

    ram_size=$(get_ram_size)
    if [ "$ram_size" -lt $MIN_RAM_SIZE ]; then
      DOWNLOAD_PATH="$OPT_DIR"
      use_mount=true
    else
      DOWNLOAD_PATH="$TMP_DIR"
      use_mount=false
    fi
    mkdir -p "$DOWNLOAD_PATH"
    echo ""
    total_size=$(curl -sI "https://raw.githubusercontent.com/$USERNAME/$OTA_REPO/master/$(echo "$DIR" | sed 's/ /%20/g')/$(echo "$FILE" | sed 's/ /%20/g')" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    show_progress "$total_size" "$DOWNLOAD_PATH/$FILE" "$FILE" &
    progress_pid=$!

    curl -L --silent \
      "https://raw.githubusercontent.com/$USERNAME/$OTA_REPO/master/$(echo "$DIR" | sed 's/ /%20/g')/$(echo "$FILE" | sed 's/ /%20/g')" \
      --output "$DOWNLOAD_PATH/$FILE"
    wait $progress_pid

    if [ ! -f "$DOWNLOAD_PATH/$FILE" ]; then
      printf "${RED}File $FILE was not downloaded/found.${NC}\n"
      read -n 1 -s -r -p "Press any key to return..."
    fi

    curl -L -s "https://raw.githubusercontent.com/$USERNAME/$OTA_REPO/master/$(echo "$DIR" | sed 's/ /%20/g')/md5sum" --output "$DOWNLOAD_PATH/md5sum"

    MD5SUM=$(grep "$FILE" "$DOWNLOAD_PATH/md5sum" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
    FILE_MD5SUM=$(md5sum "$DOWNLOAD_PATH/$FILE" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

    if [ "$MD5SUM" != "$FILE_MD5SUM" ]; then
      printf "${RED}MD5 hash does not match.${NC}"
      echo "Expected: $MD5SUM"
      echo "Actual: $FILE_MD5SUM"
      rm -f "$DOWNLOAD_PATH/$FILE"
      return
    fi

    printf "${GREEN}MD5 hash matches${NC}\n\n"
    rm -f "$DOWNLOAD_PATH/md5sum"
    read -p "$(printf "Selected ${GREEN}$FILE${NC} for update, is this correct? (y/n) ")" CONFIRM
    case "$CONFIRM" in
    y | Y)
      get_ota_fw_name "$FILE"
      update_firmware_block "$DOWNLOAD_PATH/$FILE" "$use_mount"
      print_message "Firmware successfully updated" "$GREEN"
      ;;
    n | N)
      rm -f "$DOWNLOAD_PATH/$FILE"
      main_menu
      ;;
    *) ;;
    esac
    rm -f "$DOWNLOAD_PATH/$FILE"
    print_message "Rebooting the device..." "${CYAN}"
    sleep 1
    reboot
    main_menu
  fi
}

update_firmware_block() {
  local firmware="$1"
  local use_mount="$2"
  if get_country; then
    print_message "Router region needs to be changed to EA"
  fi
  echo ""
  backup_config
  if [ "$use_mount" = true ] || [[ "$firmware" == *"$STORAGE_DIR"* ]]; then
    mountFS
  fi

  for partition in Firmware Firmware_1 Firmware_2; do
    mtdSlot="$(grep -w '/proc/mtd' -e "$partition")"
    if [ -z "$mtdSlot" ]; then
      sleep 1
    else
      result=$(echo "$mtdSlot" | grep -oP '.*(?=:)' | grep -oE '[0-9]+')
      echo "$partition on mtd${result} partition, updating..."
      perform_dd "$firmware" "/dev/mtdblock$result"
      echo ""
    fi
  done

  if [ "$use_mount" = true ] || [[ "$firmware" == *"$STORAGE_DIR"* ]]; then
    umountFS
  fi
}

firmware_manual_update() {
  ram_size=$(get_ram_size)

  if [ "$ram_size" -lt $MIN_RAM_SIZE ]; then
    print_message "Update is only possible from the built-in Entware storage" "$CYAN"
    selected_drive="$STORAGE_DIR"
    use_mount=true
  else
    output=$(mount)
    identify_external_drive "Select the drive with the update file:"
    selected_drive="$selected_drive"
    use_mount=false
  fi

  files=$(find "$selected_drive" -name '*.bin' -size +1M)
  count=$(echo "$files" | wc -l)

  if [ -z "$files" ]; then
    print_message "Update file not found on the drive" "$RED"
    exit_function
  fi

  echo "$files" | sed "s|$selected_drive/||" | awk '{print NR".", $0}'

  exit_main_menu
  read -p "Select update file (from 1 to $count): " choice
  choice=$(echo "$choice" | tr -d ' \n\r')
  if [ "$choice" = "00" ]; then
    main_menu
  fi
  if [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
    print_message "Invalid file selection" "$RED"
    exit_function
  fi

  Firmware=$(echo "$files" | awk "NR==$choice")
  FirmwareName=$(basename "$Firmware")
  echo ""
  read -p "$(printf "Selected ${GREEN}$FirmwareName${NC} for update, is that correct? (y/n) ")" item_rc1
  item_rc1=$(echo "$item_rc1" | tr -d ' \n\r')
  case "$item_rc1" in
  y | Y)
    update_firmware_block "$Firmware" "$use_mount"
    print_message "Firmware successfully updated" "$GREEN"
    printf "${NC}"
    read -p "Delete update file? (y/n) " item_rc2
    item_rc2=$(echo "$item_rc2" | tr -d ' \n\r')
    case "$item_rc2" in
    y | Y)
      rm "$Firmware"
      sleep 2
      ;;
    n | N)
      echo ""
      ;;
    *) ;;
    esac
    print_message "Rebooting the device..." "${CYAN}"
    sleep 1
    reboot
    ;;
  esac
  main_menu
}

backup_block() {
  output=$(mount)
  identify_external_drive "Select the drive for backup:"
  output=$(cat /proc/mtd)
  printf "${GREEN}Available partitions:${NC}\n"
  echo "$output" | awk 'NR>1 {print $0}'
  printf "99. Backup all partitions${NC}\n"
  exit_main_menu
  folder_path="$selected_drive/backup$DATE"
  read -p "Enter the partition number(s) separated by spaces: " choice
  echo ""
  choice=$(echo "$choice" | tr -d '\n\r')

  if [ "$choice" = "00" ]; then
    main_menu
  fi

  error_occurred=0
  non_existent_parts=""
  valid_parts=0

  if [ "$choice" = "99" ]; then
    output_all_mtd=$(cat /proc/mtd | grep -c "mtd")
    for i in $(seq 0 $(($output_all_mtd - 1))); do
      mtd_name=$(echo "$output" | awk -v i=$i 'NR==i+2 {print substr($0, index($0,$4))}' | grep -oP '(?<=\").*(?=\")')
      echo "Copying mtd$i.$mtd_name.bin..."
      if [ $valid_parts -eq 0 ]; then
        mkdir -p "$folder_path"
        valid_parts=1
      fi

      if ! cat "/dev/mtdblock$i" >"$folder_path/mtd$i.$mtd_name.bin"; then
        error_occurred=1
        print_message "Error: Not enough space to save mtd$i.$mtd_name.bin" "$RED"
        echo ""
        read -n 1 -s -r -p "Press any key to return..."
        break
      fi
    done
  else
    for part in $choice; do
      if ! echo "$output" | awk -v i=$part 'NR==i+2 {print $1}' | grep -q "mtd$part"; then
        non_existent_parts="$non_existent_parts $part"
        continue
      fi

      selected_mtd=$(echo "$output" | awk -v i=$part 'NR==i+2 {print substr($0, index($0,$4))}' | grep -oP '(?<=\").*(?=\")')

      if [ $valid_parts -eq 0 ]; then
        mkdir -p "$folder_path"
        valid_parts=1
      fi

      printf "Selected ${GREEN}mtd$part.$selected_mtd.bin${NC}, copying..."
      sleep 1
      echo ""
      if ! dd if="/dev/mtd$part" of="$folder_path/mtd$part.$selected_mtd.bin" 2>&1; then
        error_occurred=1
        print_message "Error: Not enough space to save mtd$part.$selected_mtd.bin" "$RED"
        echo ""
        read -n 1 -s -r -p "To return, press any key..."
        break
      fi
      echo ""
    done
  fi

  if [ -n "$non_existent_parts" ]; then
    print_message "Error: Partition ${non_existent_parts} does not exist!" "$RED"
    error_occurred=1
  fi

  if [ "$error_occurred" -eq 0 ] && [ $valid_parts -eq 1 ]; then
    print_message "Partition(s) successfully saved to $folder_path" "$GREEN"
  else
    print_message "Errors occurred while saving the partition(s). Check the output above." "$RED"
  fi
  exit_function
}

backup_entware() {
  output=$(mount)
  identify_external_drive "Select storage:" "(there might not be enough space)" "true"
  print_message "Performing backup..." "$CYAN"

  backup_file="$selected_drive/$(get_architecture)_entware_backup_$DATE.tar.gz"
  tar_output=$(tar cvzf "$backup_file" -C "$OPT_DIR" --exclude="$backup_file" . 2>&1)
  log_operation=$(echo "$tar_output" | tail -n 2)

  if echo "$log_operation" | grep -iq "error\|no space left on device"; then
    print_message "Error while creating backup:" "$RED"
    echo "$log_operation"
  else
    print_message "Backup successfully saved to $backup_file" "$GREEN"
  fi
  exit_function
}

rewrite_block() {
  output=$(mount)
  identify_external_drive "Select the drive with the located file:"
  files=$(find $selected_drive -name '*.bin' -size +60k)
  count=$(echo "$files" | wc -l)
  if [ -z "$files" ]; then
    print_message "Couldn't find a bin file in the selected storage" "$RED"
    exit_function
  fi
  echo ""
  echo "Found files:"
  echo "$files" | sed "s|$selected_drive/||" | awk '{print NR".", $0}'
  exit_main_menu
  read -p "Select file to replace: " choice
  choice=$(echo "$choice" | tr -d ' \n\r')
  if [ "$choice" = "00" ]; then
    main_menu
  fi
  if [ $choice -lt 1 ] || [ $choice -gt $count ]; then
    print_message "Invalid file selection" "$RED"
    exit_function
  fi

  mtdFile=$(echo "$files" | awk "NR==$choice")
  mtdName=$(basename "$mtdFile")
  echo ""
  output=$(cat /proc/mtd)
  echo "$output" | awk 'NR>1 {print $0}'
  exit_main_menu
  print_message "Warning! Bootloader will not be overwritten!" "$RED"
  read -p "Select the partition to overwrite (e.g., for mtd2 it is 2): " choice
  choice=$(echo "$choice" | tr -d ' \n\r')
  if [ "$choice" = "00" ]; then
    main_menu
  fi
  if [ "$choice" = "0" ]; then
    print_message "The bootloader cannot be overwritten!" "$RED"
    exit_function
  fi
  selected_mtd=$(echo "$output" | awk -v i=$choice 'NR==i+2 {print substr($0, index($0,$4))}' | grep -oP '(?<=\").*(?=\")')
  echo ""
  read -r -p "$(printf "Overwrite partition ${CYAN}mtd$choice.$selected_mtd${NC} with your ${GREEN}$mtdName${NC}? (y/n) ")" item_rc1
  item_rc1=$(echo "$item_rc1" | tr -d ' \n\r')
  echo ""
  case "$item_rc1" in
  y | Y)
    if [[ "$mtdFile" == *"$STORAGE_DIR"* ]]; then
      mountFS
    fi
    perform_dd "$mtdFile" "/dev/mtdblock$choice"
    print_message "Partition successfully overwritten" "$GREEN"
    if [[ "$mtdFile" == *"$STORAGE_DIR"* ]]; then
      umountFS
    fi
    read -r -p "Reboot the router? (y/n) " item_rc3
    item_rc3=$(echo "$item_rc3" | tr -d ' \n\r')
    case "$item_rc3" in
    y | Y)
      reboot
      ;;
    n | N)
      echo ""
      ;;
    *) ;;
    esac
    ;;
  n | N)
    echo ""
    ;;
  esac
  exit_function
}

service_data_generator() {
  folder_path="$OPT_DIR/backup$DATE"
  SCRIPT_PATH="$TMP_DIR/service_data_generator.py"
  target_flag=$1

  internet_checker && opkg update && echo "" && {
    output=$(opkg install curl python3-base python3 python3-light libpython3 --nodeps 2>&1) || {
      print_message "Error during installation:" "$RED" >&2
      echo "$output" >&2
      exit_function
    }

    if echo "$output" | grep -q "error"; then
      print_message "Error detected in the output:" "$RED" >&2
      echo "$output" >&2
      exit_function
    fi
  }

  curl -L -s "https://raw.githubusercontent.com/emre1393/KeenKit_English/refs/heads/main/service_data_generator.py" --output "$SCRIPT_PATH"
  if [ $? -ne 0 ]; then
    print_message "Script loading error in $SCRIPT_PATH" "$RED"
    exit_function
  fi

  mkdir -p "$folder_path"
  mtdSlot=$(grep -w 'U-Config' /proc/mtd | awk -F: '{print $1}' | grep -oE '[0-9]+')
  mtdSlot_res=$(grep -w 'U-Config_res' /proc/mtd | awk -F: '{print $1}' | grep -oE '[0-9]+')
  if [ -n "$mtdSlot" ]; then
    perform_dd "/dev/mtd$mtdSlot" "$folder_path/U-Config.bin"
    if [ $? -eq 0 ]; then
      print_message "Current U-Config backup saved in $folder_path" "$GREEN"
    else
      print_message "Error creating U-Config backup" "$RED"
    fi
  fi

  if [ -n "$target_flag" ]; then
    python3 "$SCRIPT_PATH" "$folder_path/U-Config.bin" "$target_flag"
  else
    python3 "$SCRIPT_PATH" "$folder_path/U-Config.bin"
  fi

  mtdFile=$(find "$folder_path" -type f -name 'U-Config_*.bin' | head -n 1)
  if [ -n "$mtdFile" ]; then
    print_message "New service data saved to $mtdFile" "$GREEN"
  fi
  read -p "Continue replacement? (y/n) " item_rc1
  item_rc1=$(echo "$item_rc1" | tr -d ' \n\r')
  case "$item_rc1" in
  y | Y)
    echo ""
    printf "${CYAN}Overwriting the first partition...${NC}\n"
    perform_dd "$mtdFile" "/dev/mtdblock$mtdSlot"
    if [ -n "$mtdSlot_res" ]; then
      echo ""
      printf "${CYAN}Found second partition, overwriting...${NC}\n"
      perform_dd "$mtdFile" "/dev/mtdblock$mtdSlot_res"
    fi
    if [ $? -eq 0 ]; then
      print_message "Service data successfully replaced" "$GREEN"
    else
      print_message "Error during replacement" "$RED"
    fi
    ;;
  esac
  if [ -z "$target_flag" ]; then
    read -p "Reboot the router? (y/n) " item_rc2
    item_rc2=$(echo "$item_rc2" | tr -d ' \n\r')
    case "$item_rc2" in
    y | Y)
      echo ""
      reboot
      ;;
    n | N)
      echo ""
      ;;
    *) ;;
    esac
    exit_function
  fi
  exit_function
}

if [ "$1" = "script_update" ]; then
  script_update
elif [ "$1" = "post_update" ]; then
  post_update
else
  main_menu
fi