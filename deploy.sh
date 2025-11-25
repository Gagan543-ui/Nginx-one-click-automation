
#!/bin/bash

set -e

echo "=============================="
echo " NGINX One-Click Deployment"
echo "=============================="

echo "[1/6] → Terraform Init"
cd terraform
terraform init -input=false

echo "[2/6] → Terraform Apply (auto-approve)"
terraform apply -auto-approve

echo "Extracting Terraform Outputs…"
BASTION_IP=$(terraform output -raw bastion_public_ip)
NGINX_IP=$(terraform output -raw nginx_private_ip)
KEY_PATH=$(terraform output -raw private_key_path)

echo "Terraform Outputs:"
echo "Bastion Public IP: $BASTION_IP"
echo "NGINX Private IP:  $NGINX_IP"
echo "Key Path:          $KEY_PATH"

cd ../ansible

echo "[3/6] → Installing Ansible Galaxy Roles"
ansible-galaxy install -r requirements.yml

echo "[4/6] → Validating Dynamic Inventory"
ansible-inventory -i inventory.aws_ec2.yml --graph

echo "[5/6] → Running Ansible Playbook"
ansible-playbook site.yml

echo "[6/6] → Deployment Complete!"

echo "======================================"
echo " NGINX Server Successfully Deployed"
echo "======================================"

echo "SSH Access Instructions:"
echo "Laptop → Bastion:"
echo "ssh -i $KEY_PATH ubuntu@$BASTION_IP"
echo
echo "Bastion → NGINX Node:"
echo "ssh -i ~/.ssh/nginx-demo-key.pem ubuntu@$NGINX_IP"
echo
echo "Verify NGINX:"
echo "curl -I http://$NGINX_IP"
