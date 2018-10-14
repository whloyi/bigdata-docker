#!/bin/bash

# Set up ssh keys
rm -f /etc/ssh/*key
ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

# Passwordless ssh
rm -f ~/.ssh/id_dsa
ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa
cat ~/.ssh/id_dsa.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

# make sure the NameNode has started
echo "Waiting for NameNode to start..."
timeout 60 bash -c 'until echo > /dev/tcp/namenode/8020; do sleep 0.5; done' &>/dev/null || \
{
        echo -e "#######################################################";
        echo -e "ERROR: Hadoop NameNode did not start within 60 seconds.";
        echo -e "#######################################################";
        exit;
}
echo "NameNode Started."

exec /usr/sbin/sshd -D &

# start datanode
nohup hdfs datanode &

# Start Node Manager
/opt/hadoop/sbin/yarn-daemon.sh --config $YARN_CONF_DIR start nodemanager

# Full permissions for hdfs user
hdfs dfs -chown hdfs:supergroup /
hdfs dfs -chmod 777 /
hdfs dfs -chmod 777 /tmp

# Leave safe mode
#hadoop dfsadmin -safemode leave

echo
echo "================================================="
echo "================ DataNode Started ===============" 
echo "================================================="
echo

# Run health check on running processes
# [TODO] Health check for all processes
while sleep 60; do
  ps aux |grep sshd |grep -q -v grep
  PROCESS_1_STATUS=$?
  if [ $PROCESS_1_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    exit 1
  fi
done

