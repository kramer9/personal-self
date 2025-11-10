#!/usr/bin/env bash
##
## rm popos.sh && wget https://raw.githubusercontent.com/kramer9/Self/master/popcosmicbeta.sh && chmod +x popcosmicbeta.sh && ./popcosmicbeta.sh
##
set -e ## exit on any error
## sudo adduser osint vboxsf
##
echo '######'
echo '## remove image stuff ##'
echo '######'
sudo apt purge -y apport
sudo apt remove -y popularity-contest
sudo apt remove -y --purge libreoffice* ## remove libre in favor of onlyoffice
sudo apt-get clean -y
sudo apt-get autoremove -y
sudo apt remove 
sudo apt update -y && sudo apt upgrade -y
echo '######'
echo '## needed for cut/paste utils with qemu ##'
echo '######'
sudo apt install spice-vdagent
## sudo apt install -y build-essential dkms gcc make perl
## sudo rcvboxadd setup
echo '######'
echo '## yubico stuff ##'
echo '######'
sudo apt install -y pcscd ## for yubico authenticator
sudo systemctl enable pcscd ## for yubico authenticator
sudo systemctl start pcscd ## for yubico authenticator
echo '######'
echo '## install apps ##'
echo '######'
sudo apt install -y khotkeys ## needed for flameshot
flatpak list
flatpak update -y
exit 0
## flatpak uninstall org.gimp.GIMP
##flatpak install flathub io.atom.Atom org.audacityteam.Audacity com.calibre_ebook.calibre org.gnome.DejaDup org.gnome.EasyTAG org.electrum.electrum  im.riot.Riot org.mozilla.firefox org.freefilesync.FreeFileSync org.gimp.GIMP org.gnucash.GnuCash fr.handbrake.ghb org.keepassxc.KeePassXC tv.kodi.Kodi com.getmailspring.Mailspring com.gitlab.newsflash org.onlyoffice.desktopeditors ch.protonmail.protonmail-bridge org.signal.Signal org.standardnotes.standardnotes com.github.micahflee.torbrowser-launcher com.transmissionbt.Transmission org.videolan.VLC com.wire.WireDesktop -y
flatpak install flathub org.mozilla.firefox org.freefilesync.FreeFileSync fr.handbrake.ghb org.onlyoffice.desktopeditors com.github.micahflee.torbrowser-launcher com.transmissionbt.Transmission org.videolan.VLC com.yubico.yubioath org.flameshot.Flameshot bitwarden -y
echo '######'
echo '## vistudio ##'
echo '######'
git config --global user.name "kramer9"
git config --global user.email "kramer92002@gmail.com"
sudo apt-get install wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo apt install apt-transport-https
sudo apt update
sudo apt install code # or code-insiders

echo '######'
echo '## calibre ##'
echo '######'
sudo apt install calibre
echo '######'
echo '## pcloud ##'
echo '######'
sudo add-apt-repository universe
sudo apt install libfuse2
wget https://raw.githubusercontent.com/kramer9/Self/master/pcloud
chmod +x pcloud 
./pcloud


exit 0
sudo snap install vlc
sudo apt install -y ffmpeg
sudo apt install -y python3-pip
sudo pip install youtube-dl
sudo pip install yt-dlp
sudo pip install youtube-tool
cd ~/Desktop
sudo apt install -y curl
curl -O https://inteltechniques.com/data/osintbook9/vm-files.zip
unzip vm-files.zip -d ~/Desktop/
mkdir ~/Documents/scripts
mkdir ~/Documents/icons
cd ~/Desktop/vm-files/scripts
cp * ~/Documents/scripts
cd ~/Desktop/vm-files/icons
cp * ~/Documents/icons
cd ~/Desktop/vm-files/shortcuts
sudo cp * /usr/share/applications/
cd ~/Desktop
rm vm-files.zip
rm -rf vm-files
sudo pip install streamlink
sudo pip install Instalooter
sudo pip install Instaloader
sudo pip install toutatis
mkdir ~/Downloads/Programs
cd ~/Downloads/Programs
sudo apt install -y git
sudo apt install -y python3-venv
git clone https://github.com/Datalux/Osintgram.git
cd Osintgram
python3 -m venv OsintgramEnvironment
source OsintgramEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo apt install libncurses5-dev libffi-dev -y
sudo snap install gallery-dl
sudo snap connect gallery-dl:removable-media
cd ~/Downloads
sudo apt install default-jre -y
wget https://github.com/ripmeapp/ripme/releases/latest/download/ripme.jar
chmod +x ripme.jar
cd ~/Downloads/Programs
git clone https://github.com/sherlock-project/sherlock.git
cd sherlock
python3 -m venv SherlockEnvironment
source SherlockEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo pip install socialscan
sudo pip install holehe
cd ~/Downloads/Programs
git clone https://github.com/WebBreacher/WhatsMyName.git
cd WhatsMyName/whatsmyname
python3 -m venv WhatsMyNameEnvironment
source WhatsMyNameEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
cd ~/Downloads/Programs
git clone https://github.com/martinvigo/email2phonenumber.git
cd email2phonenumber
python3 -m venv email2phonenumberEnvironment
source email2phonenumberEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
cd ~/Downloads/Programs
git clone https://github.com/ChrisTruncer/EyeWitness.git
cd EyeWitness/Python/setup
sudo ./setup.sh
sudo snap install amass
cd ~/Downloads/Programs
git clone https://github.com/aboul3la/Sublist3r.git
cd Sublist3r
python3 -m venv Sublist3rEnvironment
source Sublist3rEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
cd ~/Downloads/Programs
git clone https://github.com/s0md3v/Photon.git
cd Photon
python3 -m venv PhotonEnvironment
source PhotonEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
cd ~/Downloads/Programs
git clone https://github.com/laramies/theHarvester.git
cd theHarvester
python3 -m venv theHarvesterEnvironment
source theHarvesterEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo pip install testresources
sudo pip install webscreenshot
cd ~/Downloads/Programs
git clone https://github.com/Lazza/Carbon14
cd Carbon14
python3 -m venv Carbon14Environment
source Carbon14Environment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo apt install tor torbrowser-launcher -y
cd ~/Downloads/Programs
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
sudo rm google-chrome-stable_current_amd64.deb
sudo apt install -y mediainfo-gui
sudo apt install -y libimage-exiftool-perl
sudo apt install -y mat2
sudo pip install xeuledoc
cd ~/Downloads/Programs
sudo apt install subversion -y
git clone https://github.com/GuidoBartoli/sherloq.git
cd sherloq/gui
python3 -m venv sherloqEnvironment
source sherloqEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo pip install matplotlib
sudo apt install -y webhttrack
sudo apt install -y libcanberra-gtk-module
cd ~/Downloads/Programs
git clone https://github.com/opsdisk/metagoofil.git
cd metagoofil
python3 -m venv metagoofilEnvironment
source metagoofilEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
sudo apt install software-properties-common -y
sudo pip install bdfr
sudo pip install redditsfinder
cd ~/Downloads/Programs
git clone https://github.com/MalloyDelacroix/DownloaderForReddit.git
cd DownloaderForReddit
python3 -m venv DownloaderForRedditEnvironment
source DownloaderForRedditEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
wget http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb
sudo apt install -y ./google-earth-stable_current_amd64.deb
sudo rm google-earth-stable_current_amd64.deb
sudo apt install -y kazam
sudo snap install keepassxc
sudo apt update --fix-missing
sudo apt -y upgrade
sudo apt --fix-broken install
cd ~/Desktop
firefox &
sleep 30
pkill -f firefox
curl -O https://inteltechniques.com/data/osintbook9/ff-template.zip
unzip ff-template.zip -d ~/snap/firefox/
cd ~/snap/firefox/ff-template/
cp -R * ~/snap/firefox/common/.mozilla/firefox/*.default
cd ~/Desktop
curl -O https://inteltechniques.com/data/osintbook9/tools.zip
unzip tools.zip -d ~/Desktop/
rm tools.zip ff-template.zip
cd ~/Downloads/Programs
git clone https://github.com/lanmaster53/recon-ng.git
cd recon-ng
python3 -m venv recon-ngEnvironment
source recon-ngEnvironment/bin/activate
sudo pip install -r REQUIREMENTS
deactivate
cd ~/Downloads/Programs
git clone https://github.com/smicallef/spiderfoot.git
cd spiderfoot
python3 -m venv spiderfootEnvironment
source spiderfootEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
cd ~/Downloads/Programs
git clone https://github.com/AmIJesse/Elasticsearch-Crawler.git
sudo pip install nested-lookup
sudo pip install internetarchive
sudo apt install -y ripgrep
sudo pip install waybackpy
sudo pip install search-that-hash
sudo pip install h8mail
cd ~/Downloads
h8mail -g
sed -i 's/\;leak\-lookup\_pub/leak\-lookup\_pub/g' h8mail_config.ini
cd ~/Downloads/Programs
git clone https://github.com/mxrch/ghunt
cd ghunt
python3 -m venv ghuntEnvironment
source ghuntEnvironment/bin/activate
sudo pip install -r requirements.txt
deactivate
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background primary-color 'rgb(66, 81, 100)'
gsettings set org.gnome.shell favorite-apps []
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
gsettings set org.gnome.shell favorite-apps "['firefox_firefox.desktop', 'google-chrome.desktop', 'torbrowser.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'updates.desktop', 'tools.desktop', 'youtube_dl.desktop', 'ffmpeg.desktop', 'streamlink.desktop', 'instagram.desktop', 'gallery.desktop', 'usertool.desktop', 'eyewitness.desktop', 'domains.desktop', 'metadata.desktop', 'httrack.desktop', 'metagoofil.desktop', 'elasticsearch.desktop', 'reddit.desktop', 'internetarchive.desktop', 'spiderfoot.desktop', 'recon-ng.desktop', 'mediainfo-gui.desktop', 'google-earth-pro.desktop', 'kazam.desktop', 'keepassxc_keepassxc.desktop', 'gnome-control-center.desktop']"
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
cd ~/Documents/scripts
sudo apt autoremove -y
echo
read -rsp $'Press enter to continue...\n'
echo
