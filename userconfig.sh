#!/bin/bash
arch-chroot /mnt /bin/bash <<EOF
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

echo "Additional packages are installed and Bluetooth service is enabled."

#Вход в нового пользователя и сборка AUR пакетов
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

echo "The configuration files were successfully copied."

echo "The script is complete. The system is ready for use."
