#!/bin/bash

install_devopsos10_infra () {
  echo "Installing devops OS10 infrastructure"
  if [ "$2" == "remote" ]; then
    # parse the remote url from the script argument.
    # The URL should be compatible with the curl url format
    if [[ "$1" == "standby_partition" ]]; then
      url=`echo $@ | sed  -e 's/\<standby_partition remote\> //g'`
    else
       url=`echo $@ | sed  -e 's/\<active_partition remote\> //g'`
    fi
    curl $url -o os10-devops-ruby-utils-1.0.0.deb
  else
    cd $3
  fi

  if [[ "$1" == "standby_partition" ]]; then
    # Install the devops os10 infra debian package in the standby partition
    cp os10-devops-ruby-utils-1.0.0.deb /alt

    # update the kernel, only if it is not done already by chef or puppet
    if [ $RUN_DIRECTLY == true ]; then
      chroot /alt apt-get update
    fi

    DEP_MODULE=$DEVOPS_TYPE PARTITION=$1 chroot /alt dpkg -i ./os10-devops-ruby-utils-1.0.0.deb
    chroot /alt apt-get install -f -y
    rm -rf /alt/os10-devops-ruby-utils-1.0.0.deb
    rm -rf /alt/usr/bin/ruby_devops

    if [ "$DEVOPS_TYPE" == 'chef' ]; then
      # For chef install libxml-ruby only if the partition is standby and
      # it is not already installed.
      ln -s /opt/chef/embedded/bin/ruby /alt/usr/bin/ruby_devops
      if ! /alt/opt/chef/embedded/bin/gem query -i -n libxml-ruby > /dev/null 2>&1; then
        /alt/opt/chef/embedded/bin/gem install libxml-ruby
      fi
    else
      # For Puppet install libxml-ruby only if the partition is standby and
      # it is not already installed.
      ln -s /opt/puppetlabs/puppet/bin/ruby /alt/usr/bin/ruby_devops
      if ! /alt/opt/puppetlabs/puppet/bin/gem query -i -n libxml-ruby > /dev/null 2>&1; then
        /alt/opt/puppetlabs/puppet/bin/gem install libxml-ruby
      fi
    fi
  else
    # update the kernel, only if it is not done already by chef or puppet
    if [ $RUN_DIRECTLY == true ]; then
      apt-get update
    fi
    DEP_MODULE=$DEVOPS_TYPE PARTITION=$1 dpkg -i os10-devops-ruby-utils-1.0.0.deb
    apt-get install -f -y
    rm -rf /usr/bin/ruby_devops

    if [ "$DEVOPS_TYPE" == 'chef' ]; then
      # For chef install libxml-ruby only if the partition is active and
      # it is not already installed.
      ln -s /opt/chef/embedded/bin/ruby /usr/bin/ruby_devops
      if ! /opt/chef/embedded/bin/gem query -i -n libxml-ruby > /dev/null 2>&1; then
        /opt/chef/embedded/bin/gem install libxml-ruby
      fi
    else
      # For puppet install libxml-ruby only if the partition is active and
      # it is not already installed.
      ln -s /opt/puppetlabs/puppet/bin/ruby /usr/bin/ruby_devops
      if ! /opt/puppetlabs/puppet/bin/gem query -i -n libxml-ruby > /dev/null 2>&1; then
        /opt/puppetlabs/puppet/bin/gem install libxml-ruby
      fi
    fi
  fi 
}

install_puppet_client () {
  echo "Installing puppet client"
  if [ "$2" == "remote" ]; then
    # parse the remote url from the script argument.
    # The URL should be compatible with the curl url format
    if [[ "$1" == "standby_partition" ]]; then
      url=`echo $@ | sed  -e 's/\<standby_partition remote\> //g'`
    else
       url=`echo $@ | sed  -e 's/\<active_partition remote\> //g'`
    fi
    curl $url -o puppet5-release-jessie.deb
  else
    cd $3
  fi

  # Install puppet in the box with the necessary configurations
  if [[ "$1" == "standby_partition" ]]; then 
    cp puppet5-release-jessie.deb /alt
    chroot /alt dpkg -i ./puppet5-release-jessie.deb
    chroot /alt apt-get update
    chroot /alt apt-get install puppet-agent
    cp /etc/puppetlabs/puppet/puppet.conf /alt/etc/puppetlabs/puppet/puppet.conf
    mkdir -p /alt/etc/puppetlabs/puppet/ssl/
    cp -rf /etc/puppetlabs/puppet/ssl/*  /alt/etc/puppetlabs/puppet/ssl/ 
    bash_str='export PATH=/opt/puppetlabs/bin:$PATH'
    echo "$bash_str" >> /alt/root/.bashrc
    rm -rf /alt/puppet5-release-jessie.deb
  else  
    dpkg -i puppet5-release-jessie.deb
    apt-get update
    apt-get install puppet-agent
    bash_str='export PATH=/opt/puppetlabs/bin:$PATH'
    echo "$bash_str" >> ~/.bashrc
    source ~/.bashrc
    puppet --version
  fi   
}

install_chef_client () {
  echo "Installing chef client"
  if [ "$2" == "remote" ]; then
    # parse the remote url from the script argument.
    # The URL should be compatible with the curl url format
    if [[ "$1" == "standby_partition" ]]; then
      url=`echo $@ | sed  -e 's/\<standby_partition remote\> //g'`
    else
       url=`echo $@ | sed  -e 's/\<active_partition remote\> //g'`
    fi
    curl $url -o chef_13.8.5-1_amd64.deb
  else
    cd $3
  fi

  # Install chef in the box with the necessary configurations
  if [[ "$1" == "standby_partition" ]]; then
    cp chef_13.8.5-1_amd64.deb /alt
    chroot /alt dpkg -i ./chef_13.8.5-1_amd64.deb
    chroot /alt apt-get update
    rm -rf /alt/chef_13.8.5-1_am64.deb
    mkdir /alt/etc/chef
    cp -rf /etc/chef/* /alt/etc/chef  
  else
    dpkg -i chef_13.8.5-1_amd64.deb
    apt-get update
  fi
}

change_standby_rw () {
  if [ "$1" == "standby_partition" ]; then
    mount -o remount,rw /alt
  fi
}

change_standby_ro () {
  if [ "$1" == "standby_partition" ]; then
    mount -o remount,ro /alt
  fi
}
validate_generic_param () {
  if [[ "$1" != "active_partition"  && "$1" != "standby_partition" ]]; then
    echo "The second argument should be either active_partition or standby_partition"
    exit 1
  fi

  if [ "$2" != "local" ] && [ "$2" != "remote" ]; then
    echo "The third argument should be either local or remote"
    exit 1
  fi
}
validate_devops_param () {
  validate_generic_param $1 $2
  if [ "$3" != "local" ] && [ "$3" != "remote" ]; then
    echo "The fifth argument should be either local or remote"
    exit 1
  fi
}

if [[ "$1" == "chef" ]]; then
  if [ $# -ne 6 ]; then
    echo "Usage: os10_devops_infra_install.sh chef active_partition/standby_partition local/remote <chef_client_url> local/remote <os10_devops_ruby_url>"
    exit 1
  fi
  validate_devops_param $2 $3 $5
  change_standby_rw $2
  install_chef_client $2 $3 $4
  DEVOPS_TYPE='chef'
  RUN_DIRECTLY=false
  install_devopsos10_infra $2 $5 $6
  change_standby_ro $2
elif [[ "$1" == "puppet" ]]; then
  if [ $# -ne 6 ]; then
    echo "Usage: os10_devops_infra_install.sh puppet active_partition/standby_partition local/remote <puppet clicnet url> local/remote <os10_devops_ruby_url>"
    exit 1
  fi
  validate_devops_param $2 $3 $5
  change_standby_rw $2
  install_puppet_client $2 $3 $4
  DEVOPS_TYPE='puppet'
  RUN_DIRECTLY=false
  install_devopsos10_infra $2 $5 $6
  change_standby_ro $2
elif [ "$1" == "chef_ruby_utils" ] || [ "$1" == "puppet_ruby_utils" ]; then
  if [ $# -ne 4 ]; then
    echo "Usage: os10_devops_infra_install.sh chef_ruby_utils/puppet_ruby_utils active_partition/standby_partition local/remote <os10_devops_ruby_url>"
    exit 1
  fi
  validate_generic_param $2 $3
  change_standby_rw $2
  RUN_DIRECTLY=true
  if [ "$1" == "chef_ruby_utils" ]; then
    DEVOPS_TYPE='chef'
  else
    DEVOPS_TYPE='puppet'
  fi
  install_devopsos10_infra $2 $3 $4
  change_standby_ro $2
else
  echo -e "Usage: os10_devops_infra_install.sh chef active_partition/standby_partition local/remote <chef_client_url> local/remote <os10_devops_ruby_url> or \n os10_devops_infra_install.sh puppet active_partition/standby_partition local/remote <puppet_client_url> local/remote <os10_devops_ruby_url> or \n os10_devops_infra_install.sh chef_ruby_utils/puppet_ruby_utils active_partition/standby_partition local/remote <os10_devops_ruby_url>"
  exit 1
fi
