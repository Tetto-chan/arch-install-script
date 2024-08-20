#!/bin/bash

# Устанавливаем устройство, с которым будем работать 
DISK="/dev/nvme0n1"

# Очищаем все сигнатуры файловых систем на диске
wipefs --all $DISK

echo "The drive data has been cleared, partitioning is in progress"

# Создаём новую таблицу разделов GPT
parted $DISK --script mklabel gpt

# Создаём EFI раздел (1гб)
parted $DISK --script mkpart "''" fat32 1MiB 1GiB
parted $DISK --script set 1 esp on

# Создаём Swap раздел (8гб)
parted $DISK --script mkpart "''" linux-swap 1GiB 9GiB

# Создаём корневой раздел на оставшемся пространстве 
parted $DISK --script mkpart "''" ext4 9GiB 100%

# Форматируем разделы 
mkfs.fat -F32 "${DISK}p1" # EFI раздел
mkswap "${DISK}p2" # Swap раздел
swapon "${DISK}p2" # Активируем swap
mkfs.ext4 "${DISK}p3" # Корневой раздел

# Монтируем разделы
mount "${DISK}p3" /mnt
mount --mkdir "${DISK}p1" /mnt/boot

echo "Partitions created and mounted"

# Подключение к сети 
iwctl station wlan0 connect <имя_сети>

# Установка базовых пакетов с использованием pacstrap
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware intel-ucode networkmanager realtime-privileges micro neovim ntfs-3g git

# Генерация файла fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "The basic installation is complete and fstab has been created."

# Входим в chroot окружение
arch-chroot /mnt /bin/bash <<EOF
echo "setting up dpi blocking bypass"
sudo pacman -S dnscrypt-proxy dnsutils

cd /opt
#git clone https://github.com/bol-va n/zapret.git
#cd zapret
#./install_bin.sh
#./install_prereq.sh
#./blockcheck.sh
#./install_easy.sh
#
#echo "hiding traffic was successful"

# Настройка системного времени
ln -sf /usr/share/zoneinfo/Asia/Krasnoyarsk /etc/localtime

# Настройка локализации
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Настройка консольного шрифта
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

# Настройка hostname 
echo "MerCore" > /etc/hostname

# Настройка hosts файла 
cat <<EOT > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 MerCore
EOT

echo "System time and localization are configured."

# Запуск службы NetworkManager
systemctl enable NetworkManager.service

# Установка и настройка загрузчика systemd-boot
bootctl install

# Создание загрузочной записи для Arch Linux
cat <<EOL > /boot/loader/entries/arch.conf
title Nyarch! >w<
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=/dev/nvme0n1p3 rw
EOL

# Настройка загрузчика
cat <<EOL > /boot/loader/loader.conf
default arch.conf
timeout 0
console-mode auto
editor no
EOL

echo "The NetworkManager service is running and the systemd-boot boot loader is installed."

# Проверка и настройка fmask и dmask в /etc/fstab
if grep -q ',[fd]mask=0044' /etc/fstab; then
  sed -i 's_\(,[fd]mask=\)0044_\10077_g' /etc/fstab
fi

echo "Installation is complete. The system is ready to boot."

# Установка пароля для root
echo "Set a password for the root user:"
passwd

# Добавление нового пользователя с правами sudo
USERNAME="tetto"  
useradd -m -G wheel -s /bin/bash \$USERNAME

# Установка пароля для нового пользователя
echo "Set the password for the user \$USERNAME:"
passwd \$USERNAME

# Настройка прав для группы wheel
sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers

echo "User and rights settings have been successfully completed."
