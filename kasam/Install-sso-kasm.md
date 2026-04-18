
sudo dnf install -y curl tar openssl


cd /tmp

curl -LO https://kasm-static-content.s3.amazonaws.com/kasm_release_1.18.1.tar.gz
tar -xf kasm_release*.tar.gz
cd kasm_release

sudo bash install.sh --accept-eula