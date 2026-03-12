#!/bin/bash
# Ikhtiar (usaha yang sesuai syariat) untuk menginisiasi dan menyempurnakan environment Linux (VPS)
# untuk AverroesTeam Backend (Aset Kripto & Kajian Syariah).
# Gunakan Ubuntu 22.04 ke atas

echo "=========================================================="
echo "✨ Bismillah, memulai ikhtiar pemasangan backend Averroes ✨"
echo "=========================================================="

# 1. Perbarui daftar paket dan perbaiki resiko celah keamanan (Mitigasi Risiko)
echo "1. Memperbarui repositori dan mengamankan env server..."
sudo apt update && sudo apt upgrade -y

# 2. Pemasangan bahasa pemrograman Python (Urf Teknis) dan Web Server (Nginx)
echo "2. Pemasangan Python3, Nginx, dan utilitas dasar..."
sudo apt install python3 python3-pip python3-venv nginx curl wget git unzip ufw -y

# 3. Pemasangan basis data MongoDB (Amanah penyimpanan data)
echo "3. Pemasangan basis data MongoDB..."
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

# Jalankan mongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# 4. Keamanan Dasar: Firewall (UFW) untuk mitigasi celah keamanan peladen
echo "4. Mengaktifkan tembok apai (Firewall / UFW) untuk mitigasi akses ilegal..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
echo "y" | sudo ufw enable

# 5. Siapkan struktur untuk rilis (Menjalankan amanah repository Aplikasi)
echo "5. Menyiapkan ikatan (directory) untuk Averroes..."
sudo mkdir -p /var/log/averroes
sudo touch /var/log/averroes/access.log /var/log/averroes/error.log
sudo chown -R www-data:www-data /var/log/averroes
sudo mkdir -p /var/www/AverroesTeam
sudo chown -R $USER:$USER /var/www/AverroesTeam

echo "=========================================================="
echo "✅ Alhamdulillah proses instalasi Nginx, MongoDB, Python, dan Firewall selesai."
echo "   Status MongoDB: $(systemctl is-active mongod)"
echo "   Status Nginx: $(systemctl is-active nginx)"
echo "   Status UFW: Aktif (Hanya membuka Port SSH, HTTP, dan HTTPS)"
echo "=========================================================="
