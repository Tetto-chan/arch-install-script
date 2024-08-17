#!/bin/bash

# Устанавливаем устройство, с которым будем работать 
DISK="/dev/nvme0n1"

# Очищаем все сигнатуры файловых систем на диске
wipefs --all $DISK

# Создаём новую таблицу разделов GPT
parted $DISK --script mklabel gpt

# Создаём EFI раздел (1гб)
parted $DISK --script mkpart primary fat32 1MiB 1GiB
parted $DISK --script set 1 esp on

# Создаём Swap раздел (8гб)
parted $DISK --script mkpart primary linux-swap 1GiB 9GiB

# Создаём корневой раздел на оставшемся пространстве 
parted $DISK --script mkpart primary ext4 9GiB 100%

# Форматируем разделы 
mkfs.fat -F32 "${DISK}p1" # EFI раздел
mkswap "${DISK}p2" # Swap раздел
swapon "${DISK}p2" # Активируем swap
mkfs.ext4 "${DISK}p3" # Корневой раздел

# Монтируем разделы
mount "${DISK}p3" /mnt
mount --mkdir "${DISK}p1" /mnt/boot

echo "Разделы созданы и смонтированы"

# Подключение к сети 
iwctl station wlan0 connect <имя_сети>

# Установка базовых пакетов с использованием pacstrap
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware intel-ucode networkmanager realtime-privileges micro neovim ntfs-3g git

# Генерация файла fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "Базовая установка завершена, fstab создан."

# Входим в chroot окружение
arch-chroot /mnt /bin/bash <<EOF

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

echo "Системное время и локализация настроены."

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

echo "Служба NetworkManager запущена, загрузчик systemd-boot установлен."

# Проверка и настройка fmask и dmask в /etc/fstab
if grep -q "fmask=" /etc/fstab; then
    sed -i 's/fmask=[0-9]\{4\}/fmask=0077/g' /etc/fstab
fi

if grep -q "dmask=" /etc/fstab; then
    sed -i 's/dmask=[0-9]\{4\}/dmask=0077/g' /etc/fstab
fi

if ! grep -q "fmask=" /etc/fstab; then
    sed -i '/vfat/ s/defaults/defaults,fmask=0077/' /etc/fstab
fi

if ! grep -q "dmask=" /etc/fstab; then
    sed -i '/vfat/ s/defaults/defaults,dmask=0077/' /etc/fstab
fi

echo "Установка завершена. Система готова к загрузке."

# Установка пароля для root
echo "Установите пароль для пользователя root:"
passwd

# Добавление нового пользователя с правами sudo
USERNAME="tetto"  
useradd -m -G wheel -s /bin/bash \$USERNAME

# Установка пароля для нового пользователя
echo "Установите пароль для пользователя \$USERNAME:"
passwd \$USERNAME

# Настройка прав для группы wheel
sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers

echo "Пользователь и настройки прав успешно настроены."

# Установка дополнительных пакетов
pacman -Syu --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    bluez \
    bluez-utils \
    hyprland \
    wl-clipboard \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    kitty \
    sddm \
    sudo \
    waybar \
    firefox \
    discord \
    wofi \
    lutris \
    hyprpaper

# Включение службы Bluetooth
systemctl enable bluetooth

# Включение службы SDDM
systemctl enable sddm

echo "Дополнительные пакеты установлены, служба Bluetooth включена."

# Вход в нового пользователя и сборка AUR пакетов
su - $USERNAME -c '
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

# Установка других пакетов через yay (пример)
yay -S hyprshot --noconfirm


# Установка vim-plug для neovim
# Загрузка и установка vim-plug для neovim
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \\
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


# Копирование моего конфига hyprland с гита
https://github.com/Tetto-chan/dotfiles.git

# Копирование конфигурационных файлов в ~/.config
cp -r ~/dotfiles/.config/* ~/.config/
'

EOF

echo "Конфигурационные файлы успешно скопированы."

echo "Скрипт завершен. Система готова к использованию."
