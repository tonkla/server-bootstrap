#!/usr/bin/env bash

add_super_user() {
  read -p "Username: " _USERNAME
  read -s -p "Password: " _PASSWORD
  if [[ -n $_USERNAME && -n $_PASSWORD ]]; then
    sudo useradd -m -s /bin/bash -G sudo $_USERNAME
    sudo echo $_USERNAME:$_PASSWORD | chpasswd
    sudo sed -i.bak "s/%sudo\tALL=(ALL:ALL) ALL/%sudo\tALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
  fi
}

init_ssh_keys() {
  if [[ ! -d ~/.ssh ]]; then
    mkdir ~/.ssh
    chmod 700 ~/.ssh
    if [[ ! -f ~/.ssh/authorized_keys ]]; then
      touch ~/.ssh/authorized_keys
      chmod 600 ~/.ssh/authorized_keys
      if [[ -f ~/id_rsa.pub ]]; then
        cat ~/id_rsa.pub >> ~/.ssh/authorized_keys
        if [[ ! -d ~/backup ]]; then
          mkdir ~/backup
        fi
        mv ~/id_rsa.pub ~/backup
      fi
    fi
  fi
}

reconfigure_sshd_config() {
  if [[ -f ./templates/sshd_config ]]; then
    sudo mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sudo cp ./templates/sshd_config /etc/ssh/sshd_config
    sudo service ssh restart
  fi
}

add_repositories() {
  if [[ -n $_OS && -n $_RELEASE ]]; then
    case $_OS in
      ubuntu)
        case $_RELEASE in
          trusty|14.04)
            if [[ -f ./templates/ubuntu-trusty-sources.list ]]; then
              sudo mv /etc/apt/sources.list /etc/apt/sources.list.bak
              sudo cp ./templates/ubuntu-trusty-sources.list /etc/apt/sources.list
            fi
          ;;
        esac
      ;;
      debian)
        case $_RELEASE in
          wheezy|7)
            if [[ -f ./templates/debian-wheezy-sources.list ]]; then
              sudo mv /etc/apt/sources.list /etc/apt/sources.list.bak
              sudo cp ./templates/debian-wheezy-sources.list /etc/apt/sources.list
            fi
          ;;
        esac
      ;;
    esac
  fi
}

update_safe_upgrade() {
  if [[ "ubuntu" == "$_OS" || "debian" == "$_OS" ]]; then
    sudo aptitude update
    sudo aptitude safe-upgrade -y
  fi
}

update_locale() {
  if [[ -f ./templates/locale && "ubuntu" == "$_OS" || "debian" == "$_OS" ]]; then
    sudo mv /etc/default/locale /etc/default/locale.bak
    sudo cp ./templates/locale /etc/default/locale
  fi
}

install_utils() {
  if [[ "ubuntu" == "$_OS" || "debian" == "$_OS" ]]; then
    sudo aptitude install -y vim htop byobu python-software-properties
  fi
}

install_ruby_prerequisites() {
  if [[ "ubuntu" == "$_OS" || "debian" == "$_OS" ]]; then
    sudo aptitude install -y git-core curl build-essential zlib1g-dev libssl-dev libreadline-dev \
          libyaml-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev libsqlite3-dev sqlite3
  fi
}

install_nginx() {
  if [[ "ubuntu" == "$_OS" ]]; then
    sudo add-apt-repository ppa:nginx/stable
    sudo aptitude update
    sudo aptitude install -y nginx
  elif [[ "debian" == "$_OS" ]]; then
    wget http://www.dotdeb.org/dotdeb.gpg -O /tmp/dotdeb.gpg
    sudo apt-key add /tmp/dotdeb.gpg
    if [[ "wheezy" == "$_RELEASE" ]]; then
      sudo echo "deb http://packages.dotdeb.org wheezy all" >> /etc/apt/sources.list
    fi
    sudo aptitude update
    sudo aptitude install -y nginx
  fi
}

install_apache() {
  echo "" > /dev/null
}

install_ruby_from_source() {
  _PWD=`pwd`
  mkdir ~/src
  cd ~/src
  wget http://ftp.ruby-lang.org/pub/ruby/2.1/ruby-2.1.3.tar.gz
  tar -xzvf ruby-2.1.3.tar.gz
  cd ruby-2.1.3/
  ./configure
  make
  sudo make install

  echo "gem: --no-ri --no-rdoc" > ~/.gemrc
  cd $_PWD
}

install_ruby_via_rbenv() {
  git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  echo '\nexport PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  exec $SHELL

  _version=2.1.3
  rbenv install $_version
  rbenv global $_version

  echo 'export PATH="$HOME/.rbenv/versions/'$_version'/bin:$PATH"' >> ~/.bashrc

  echo "gem: --no-ri --no-rdoc" > ~/.gemrc
}

install_appserver() {
  if [[ "rack" == "$_APP" ]]; then
    install_ruby_prerequisites
    install_ruby_via_rbenv
    gem install unicorn
  fi
}

install_webserver() {
  install_nginx
  # install_apache
}

create_project_dirs() {
  if [[ -z "$_DOMAIN" ]]; then
    read -p "Domain: " _DOMAIN
  fi
  if [[ -n "$_DOMAIN" ]]; then
    mkdir -p ~/projects/$_DOMAIN/htdocs
    mkdir ~/projects/$_DOMAIN/logs
    if [[ ! -d "/var/www" ]]; then
      sudo mkdir /var/www
    fi
    sudo ln -sf $HOME/projects/$_DOMAIN /var/www/
  fi
}

create_virtual_host() {
  if [[ ! -d "/etc/nginx/sites-available" ]]; then
    sudo mkdir /etc/nginx/sites-available
  fi
  if [[ ! -d "/etc/nginx/sites-enabled" ]]; then
    sudo mkdir /etc/nginx/sites-enabled
  fi

  if [[ -n "$_DOMAIN" ]]; then
    if [[ "rack" == "$_APP" ]]; then
      sudo cp ./templates/nginx-rack /etc/nginx/sites-available/$_DOMAIN
      sudo sed -i "s/DOMAIN/$_DOMAIN/g" /etc/nginx/sites-available/$_DOMAIN
      sudo ln -sf ../sites-available/$_DOMAIN /etc/nginx/sites-enabled/$_DOMAIN
      sudo service nginx reload
    fi
  fi
}

run_unicorn() {
  if [[ -z "$_DOMAIN" ]]; then
    read -p "Domain: " _DOMAIN
  fi
  cp ./templates/unicorn.rb ~/projects/$_DOMAIN/htdocs/unicorn.rb
  sed -i "s/DOMAIN/$_DOMAIN/g" ~/projects/$_DOMAIN/htdocs/unicorn.rb
  unicorn -c ~/projects/$_DOMAIN/htdocs/unicorn.rb -D
}

bootstrap() {
  # init_ssh_keys
  # reconfigure_sshd_config
  # update_locale
  # add_repositories
  # update_safe_upgrade
  # install_utils
  # install_appserver
  # install_webserver
  # create_project_dirs
  # create_virtual_host
  # run_unicorn
}

usage() {
  echo "Usage: ./run.sh --cmd=bootstrap --os=ubuntu --release=trusty --app=rack --domain=example.com"
}


for i in "$@"
do
  case $i in
    --cmd=*)
      _CMD="${i#*=}"
      shift
    ;;
    --os=*)
      _OS="${i#*=}"
      shift
    ;;
    --release=*)
      _RELEASE="${i#*=}"
      shift
    ;;
    --app=*)
      _APP="${i#*=}"
      shift
    ;;
    --domain=*)
      _DOMAIN="${i#*=}"
      shift
    ;;
  esac
done

case $_CMD in
  bootstrap)
    bootstrap
  ;;
  *)
    echo "Commands: bootstrap"
    read -p "command: " _CMD
    case $_CMD in
      bootstrap)
        bootstrap
      ;;
      *)
        usage
      ;;
    esac
  ;;
esac
