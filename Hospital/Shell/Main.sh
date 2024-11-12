#!/bin/bash

#wget -q -O- https://downloads.opennebula.org/repo/repo.key | sudo apt-key add -
#echo "deb [trusted=yes] https://downloads.opennebula.org/repo/5.6/Ubuntu/18.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list
#sudo apt update

#sudo apt install -y opennebula-tools
#sudo apt install -y ansible
#sudo apt install -y sshpass

rm ~/.ssh/known_hosts
rm ../Misc/hosts

CLIENT_TEMPLATE="debian12-lxde"
ENDPOINT="https://grid5.mif.vu.lt/cloud3/RPC2"

ansible-vault view ../Misc/vault.yml --ask-vault-pass > decrypted_vault.yml

#change to better method
CLIENT_USER=$(grep 'CLIENT_USER:' decrypted_vault.yml | awk '{print $2}' | tr -d '"'| tr -s '[:space:]')
DB_USER=$(grep 'DB_USER:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')
WEB_USER=$(grep 'WEB_USER:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')
CLIENT_PASS=$(grep 'CLIENT_PASS:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')
DB_PASS=$(grep 'DB_PASS:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')
WEB_PASS=$(grep 'WEB_PASS:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')
SUDO_PASS=$(grep 'SUDO:' decrypted_vault.yml | awk '{print $2}' | tr -d '"' | tr -s '[:space:]')

rm -f decrypted_vault.yml


DB_REZ=$(onetemplate instantiate "$CLIENT_TEMPLATE" --name "db-vm" --user "$DB_USER" --password "$DB_PASS" --endpoint "$ENDPOINT")
DBVM_ID=$(echo $DB_REZ | cut -d ' ' -f 3)
echo "Waiting for VM to start..."
sleep 50

onevm show "$DBVM_ID" --user "$DB_USER" --password "$DB_PASS" --endpoint "$ENDPOINT" > "$DBVM_ID.txt"
DB_IP=$(grep PRIVATE_IP "$DBVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
DB_PUBLIC_IP=$(grep PUBLIC_IP "$DBVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
rm "$DBVM_ID.txt"
printf "[db]\n$DB_USER@$DB_IP ansible_become_password=222\n\n" >> ../Misc/hosts
sshpass -p "$SUDO_PASS" ssh-copy-id -o StrictHostKeyChecking=no "$DB_USER@$DB_IP"

echo "localhost" > ../Misc/db_ip


WEB_REZ=$(onetemplate instantiate "$CLIENT_TEMPLATE" --name "webserver-vm" --user "$WEB_USER" --password "$WEB_PASS" --endpoint "$ENDPOINT")
WEBVM_ID=$(echo $WEB_REZ | cut -d ' ' -f 3)
echo "Waiting for VM to start..."
sleep 50

onevm show "$WEBVM_ID" --user "$WEB_USER" --password "$WEB_PASS" --endpoint "$ENDPOINT" > "$WEBVM_ID.txt"
WEB_IP=$(grep PRIVATE_IP "$WEBVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
WEB_PUBLIC_IP=$(grep PUBLIC_IP "$WEBVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
rm "$WEBVM_ID.txt"
printf "[webserver]\n$WEB_USER@$WEB_IP ansible_become_password=222\n\n" >> "../Misc/hosts"
sshpass -p "$SUDO_PASS" ssh-copy-id -o StrictHostKeyChecking=no "$WEB_USER@$WEB_IP"

echo "localhost" > ../Misc/ws_ip


CLIENT_REZ=$(onetemplate instantiate "$CLIENT_TEMPLATE" --name "client-vm" --user "$CLIENT_USER" --password "$CLIENT_PASS" --endpoint "$ENDPOINT")
CLIENTVM_ID=$(echo $CLIENT_REZ | cut -d ' ' -f 3)
echo "Waiting for VM to start..."
sleep 50

onevm show "$CLIENTVM_ID" --user "$CLIENT_USER" --password "$CLIENT_PASS" --endpoint "$ENDPOINT" > "$CLIENTVM_ID.txt"
CLIENT_IP=$(grep PRIVATE_IP "$CLIENTVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
CLIENT_PUBLIC_IP=$(grep PUBLIC_IP "$CLIENTVM_ID.txt" | cut -d '=' -f 2 | tr -d '"')
rm "$CLIENTVM_ID.txt"
printf "[client]\n$CLIENT_USER@$CLIENT_IP ansible_become_password=222\n\n" >> ../Misc/hosts
sshpass -p "$SUDO_PASS" ssh-copy-id -o StrictHostKeyChecking=no "$CLIENT_USER@$CLIENT_IP"


ansible-playbook -i ../Misc/hosts ../Ansible/DB.yaml -K --ask-vault-pass
ansible-playbook -i ../Misc/hosts ../Ansible/WS.yaml -K --ask-vault-pass
ansible-playbook -i ../Misc/hosts ../Ansible/C.yaml -K --ask-vault-pass

exit 0
