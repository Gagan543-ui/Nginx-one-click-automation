
pipeline {

    agent any

    environment {
        AWS_REGION = "eu-west-2"
    }

    stages {

        /* ------------------ CHECKOUT ------------------ */
        stage('Checkout Repo') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Gagan543-ui/Nginx-one-click-automation'
            }
        }

        /* ------------------ TERRAFORM ------------------ */
        stage('Terraform Apply') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'jenkinsdemo',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        cd terraform
                        terraform init
                        terraform apply -auto-approve
                    '''
                }
            }
        }

        /* ------------------ GENERATE INVENTORY ------------------ */
        stage('Generate Inventory') {
            steps {
                script {
                    def nginx_ip  = sh(script: "cd terraform && terraform output -raw nginx_private_ip", returnStdout: true).trim()
                    def bastion_ip = sh(script: "cd terraform && terraform output -raw bastion_public_ip", returnStdout: true).trim()

                    writeFile file: "ansible/inventory/hosts.ini", text: """
[nginx]
${nginx_ip}

[bastion]
${bastion_ip}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=../terraform/nginx-demo-key.pem
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../terraform/nginx-demo-key.pem ubuntu@${bastion_ip}"'
"""
                }
            }
        }

        /* ------------------ ANSIBLE INSTALL ------------------ */
        stage('Install NGINX via Ansible') {
            steps {
                sh '''
                    cd ansible
                    ansible-galaxy install -r requirements.yml
                    ansible-playbook site.yml -i inventory/hosts.ini \
                      --ssh-common-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
                '''
            }
        }

        /* ------------------ NGINX TEST ------------------ */
        stage('NGINX Test') {
            steps {
                sh '''
                cd terraform
                NGINX=$(terraform output -raw nginx_private_ip)
                BASTION=$(terraform output -raw bastion_public_ip)
                cd ..

                echo "TEST → Checking NGINX Response Headers"
                ssh -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    -o "ProxyCommand=ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i terraform/nginx-demo-key.pem ubuntu@$BASTION -W %h:%p" \
                    -i terraform/nginx-demo-key.pem \
                    ubuntu@$NGINX "curl -I http://localhost"
                '''
            }
        }
    }

    post {
        success {
            echo "✔ NGINX Deployment Successful!"
        }
        failure {
            echo "❌ Pipeline FAILED! Check error logs."
        }
    }
}
