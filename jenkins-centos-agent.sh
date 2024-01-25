#!/bin/bash

# Use Canonical, Ubuntu, 20.04 LTS, amd64 focal image build on 2023-10-25 to avoid any prompt

# ubuntu = Ubuntu
# redhat = Red Hat Enterprise Linux
# centos = CentOS Linux
# amazon-ec2 = Amazon Linux

OS_NAME=$(cat /etc/*release | grep -w NAME | awk -F'"' '{print$2}')
UBUNTU_VERSION=$(cat /etc/*release | grep DISTRIB_RELEASE | awk -F"=" '{print$2}' | awk -F"." '{print$1}')

function install_packages {
    local packages=(
        curl 
        wget 
        vim 
        git 
        make 
        python3-pip 
        openssl 
        rsync 
        postgresql-client 
        mariadb-client
        mysql-client-8.0
        mysql-client 
        unzip 
        tree 
        openjdk-11-jdk
        default-jre 
        default-jdk 
        fontconfig 
        maven 
        npm
    )

    echo "Installing packages on $OS_NAME..."

    for package in "${packages[@]}"; do
        case $OS_NAME in
            "Ubuntu")
                sudo apt-get install -y "$package"
                ;;
            "Red Hat Enterprise Linux" | "CentOS Linux")
                sudo yum install -y "$package"
                ;;
            "Amazon Linux")
                sudo amazon-linux-extras install -y "$package"
                ;;
            *)
                echo "Unsupported OS: $OS_NAME"
                exit 1
                ;;
        esac
    done

    echo "Package installation complete."
}

# Check the OS
check_os
# Install packages
install_packages

yum install epel-release -y
yum install jq -y
jq --version
yum install ansible -y
ansible --version

function install_software_centos {
    ## Install AWS CLI
    which aws
    if [ "$?" -eq 0 ]; then
        echo "AWS CLI is installed already. Nothing to do."
    else
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip
        rm -rf aws
    fi

    ## Install Terraform version 1.0.0
    TERRAFORM_VERSION="1.0.0"
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    mv terraform /usr/local/bin/
    terraform --version
    rm -rf terraform_${TERRAFORM_VERSION}_linux_amd64.zip

    ## Install grype
    GRYPE_VERSION="0.66.0"
    wget https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.tar.gz
    tar -xzf grype_${GRYPE_VERSION}_linux_amd64.tar.gz
    chmod +x grype
    sudo mv grype /usr/local/bin/
    grype version

    ## Install Gradle
    GRADLE_VERSION="4.10"
    wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
    unzip gradle-${GRADLE_VERSION}-bin.zip
    mv gradle-${GRADLE_VERSION} /opt/gradle-${GRADLE_VERSION}
    /opt/gradle-${GRADLE_VERSION}/bin/gradle --version

    ## Install kubectl
    sudo curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/kubectl 
    sudo chmod +x ./kubectl 
    sudo mv kubectl /usr/local/bin/

    ## Install kubectx and kubens
    sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx 
    sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens 
    sudo chmod +x kubectx kubens 
    sudo mv kubens kubectx /usr/local/bin

    ## Install Helm 3
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    sudo  chmod 700 get_helm.sh
    sudo ./get_helm.sh
    sudo helm version

    ## Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version

    ## Install Terragrunt
    TERRAGRUNT_VERSION="v0.38.0"
    sudo wget https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 
    sudo mv terragrunt_linux_amd64 terragrunt 
    sudo chmod u+x terragrunt 
    sudo mv terragrunt /usr/local/bin/terragrunt
    terragrunt --version

    ## Install Packer
    sudo wget https://releases.hashicorp.com/packer/1.7.4/packer_1.7.4_linux_amd64.zip -P /tmp
    sudo unzip /tmp/packer_1.7.4_linux_amd64.zip -d /usr/local/bin
    chmod +x /usr/local/bin/packer
    packer --version

    ## Install ArgoCD agent
    wget https://github.com/argoproj/argo-cd/releases/download/v2.8.5/argocd-linux-amd64
    chmod +x argocd-linux-amd64
    sudo mv argocd-linux-amd64 /usr/local/bin/argocd

    ## Install Docker
    sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker

    ## Change permissions for Docker socket
    sudo chown root:docker /var/run/docker.sock
    sudo chmod 666 /var/run/docker.sock

    ## Install Sonar-scanner CLI
    sonar_scanner_version="5.0.1.3006"                 
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${sonar_scanner_version}-linux.zip
    unzip sonar-scanner-cli-${sonar_scanner_version}-linux.zip
    sudo mv sonar-scanner-${sonar_scanner_version}-linux sonar-scanner
    sudo rm -rf  /var/opt/sonar-scanner || true
    sudo mv sonar-scanner /var/opt/
    sudo rm -rf /usr/local/bin/sonar-scanner || true
    sudo ln -s /var/opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/ || true
    sonar-scanner -v
}

# Run the function
install_software_centos


function jenkins_installation {
    sudo apt update
    ## Set vim as default text editor
    sudo update-alternatives --set editor /usr/bin/vim.basic
    sudo update-alternatives --set vi /usr/bin/vim.basic
    java -version
    sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum upgrade -y
    sudo yum install jenkins -y
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
    INSTANCE_PUBLIC_IP=$(curl -s ifconfig.me)
    ADMIN_KEY=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    JENKINS_URL="http://$INSTANCE_PUBLIC_IP:8080"
    echo "Jenkins is installed and running. You can access it at $JENKINS_URL"
    echo "This is the initialAdminPassword: $ADMIN_KEY"
}
jenkins_installation


function user_setup {
cat << EOF > /usr/users.txt
jenkins
ansible 
automation
EOF
    username=$(cat /usr/users.txt | tr '[A-Z]' '[a-z]')
    GROUP_NAME="tools"

    # cat /etc/group |grep -w tools &>/dev/nul || sudo groupadd $GROUP_NAME

    if grep -q "^$GROUP_NAME:" /etc/group; then
        echo "Group '$GROUP_NAME' already exists."
    else
        sudo groupadd "$GROUP_NAME"
        echo "Group '$GROUP_NAME' created."
    fi

    if sudo grep -q "^%$GROUP_NAME" /etc/sudoers; then
        echo "Group '$GROUP_NAME' is already in sudoers."
    else
        echo "%$GROUP_NAME ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
        echo "Group '$GROUP_NAME' added to sudoers with NOPASSWD: ALL."
    fi

    ## allow automation tools to access docker
    for i in $username
    do 
        if grep -q "^$i" /etc/sudoers; then
            echo "User '$i' is already in sudoers."
        else
            echo "$i ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee -a /etc/sudoers
        fi
    done

    for users in $username
    do
        ls /home |grep -w $users &>/dev/nul || mkdir -p /home/$users
        cat /etc/passwd |awk -F: '{print$1}' |grep -w $users &>/dev/nul ||  useradd $users
        chown -R $users:$users /home/$users
        usermod -s /bin/bash -aG tools $users
        usermod -s /bin/bash -aG docker $users
        echo -e "$users\n$users" |passwd "$users"
    done

    ## Set vim as default text editor
    sudo update-alternatives --set editor /usr/bin/vim.basic
    sudo update-alternatives --set vi /usr/bin/vim.basic
}
user_setup

# function enable_password_authentication {
#     # Check if password authentication is already enabled
#     if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
#         echo "Password authentication is already enabled."
#     else
#         # Enable password authentication by modifying the SSH configuration file
#         sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
#         echo "Password authentication has been enabled in /etc/ssh/sshd_config."

#         # Restart the SSH service to apply changes
#         sudo systemctl restart ssh
#         echo "SSH service has been restarted."
#     fi
# }
# enable_password_authentication

# function ssh_key {
#     sudo su - jenkins 
#     ssh-keygen -t rsa -f /home/jenkins/.ssh/id_rsa -N "" || true
#     echo
#     echo
#     echo 'Below is ssh private key that you need in jenkins for ssh repo checkout -------------------------------' 
#     cat /home/$USER/.ssh/id_rsa
#     echo
#     echo
#     echo 'Below is ssh public key that you need in jenkins for ssh repo checkout --------------------------------' 
#     cat /home/$USER/.ssh/id_rsa.pub
# }
# ssh_key


