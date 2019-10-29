#!/bin/bash

SLURM_VERSION=18.08.3
set -x

yum -y install epel-release

source /etc/os-release
if [ "$VERSION_ID" = "8" ]; then
    LIBCGROUP="libcgroup"
    which munge 1>/dev/null 2>&1
    if [ $? -ne 0 ]; then
        yum -y install rpm-build bzip2-devel openssl-devel
        pushd /tmp
        wget https://github.com/dun/munge/releases/download/munge-0.5.13/munge-0.5.13.tar.xz
        rpmbuild -tb --clean munge-0.5.13.tar.xz
        yum -y install ~/rpmbuild/RPMS/x86_64/munge-0.5.13* ~/rpmbuild/RPMS/x86_64/munge-libs-0.5.13* ~/rpmbuild/RPMS/x86_64/munge-devel-0.5.13* 
        popd
    fi
    yum -y install python2
    alternatives --set python /usr/bin/python2
else
    LIBCGROUP="libcgroup-devel"
    yum -y install munge munge-devel
fi

# Install munge
install -o munge -g munge -m 0600 /vagrant/munge.key /etc/munge/munge.key
systemctl enable munge
systemctl start munge

# Install SLURM
yum -y install readline-devel numactl-devel pam-devel glib2-devel hwloc-devel openssl-devel curl-devel $LIBCGROUP
if [ ! -f /opt/slurm/sbin/slurmctld -a -f /vagrant/slurm/sbin/slurmctld ]; then
    [ ! -d /opt/slurm ] && mkdir /opt/slurm
    cp -r /vagrant/slurm/* /opt/slurm/
fi
if [ ! -f /opt/slurm/sbin/slurmctld ]; then
    cd /tmp
    curl -o slurm-${SLURM_VERSION}.tar.bz2 https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
    tar xf slurm-${SLURM_VERSION}.tar.bz2
    cd slurm-${SLURM_VERSION}
    ./configure --prefix=/opt/slurm --sysconfdir=/opt/slurm/etc
    make
    make install
    mkdir /opt/slurm/etc
    install -D -m644 etc/slurmctld.service /opt/slurm/etc/
    install -D -m644 etc/slurmd.service /opt/slurm/etc/
    systemctl daemon-reload
    cp etc/cgroup.conf.example /opt/slurm/etc/cgroup.conf
    cp -r /opt/slurm/* /vagrant/slurm/
fi

install -D -m644 /opt/slurm/etc/slurmctld.service /etc/systemd/system/
install -D -m644 /opt/slurm/etc/slurmd.service /etc/systemd/system/

cat > /etc/profile.d/slurm.sh <<EOF
export PATH=/opt/slurm/bin:$PATH
export MANPATH=/opt/slurm/share/man:$MANPATH
EOF

groupadd -r slurm
useradd -r -g slurm -d /var/spool/slurm -s /sbin/nologin slurm
install -d -o slurm -g slurm /var/spool/slurm
[ ! -d /var/spool/slurmd ] && mkdir /var/spool/slurmd
cat >/opt/slurm/etc/slurm.conf <<EOF
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ControlMachine=head
#BackupController=
#BackupAddr=
# 
AuthType=auth/munge
#CheckpointType=checkpoint/none 
CryptoType=crypto/munge
#DisableRootJobs=NO 
#EnforcePartLimits=NO 
#Epilog=
#EpilogSlurmctld= 
#FirstJobId=1 
#MaxJobId=999999 
#GresTypes= 
#GroupUpdateForce=0 
#GroupUpdateTime=600 
#JobCheckpointDir=/var/slurm/checkpoint 
#JobCredentialPrivateKey=
#JobCredentialPublicCertificate=
#JobFileAppend=0 
#JobRequeue=1 
#JobSubmitPlugins=1 
#KillOnBadExit=0 
#LaunchType=launch/slurm 
#Licenses=foo*4,bar 
#MailProg=/bin/mail 
#MaxJobCount=5000 
#MaxStepCount=40000 
#MaxTasksPerNode=128 
MpiDefault=none
#MpiParams=ports=#-# 
#PluginDir= 
#PlugStackConfig= 
#PrivateData=jobs 
ProctrackType=proctrack/cgroup
#Prolog=
#PrologFlags= 
#PrologSlurmctld= 
#PropagatePrioProcess=0 
#PropagateResourceLimits= 
#PropagateResourceLimitsExcept= 
#RebootProgram= 
ReturnToService=1
#SallocDefaultCommand= 
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
#SlurmdUser=root 
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/var/spool/slurm
SwitchType=switch/none
#TaskEpilog=
TaskPlugin=task/cgroup
TaskPluginParam=Sched
#TaskProlog=
#TopologyPlugin=topology/tree 
#TmpFS=/tmp 
#TrackWCKey=no 
#TreeWidth= 
#UnkillableStepProgram= 
#UsePAM=0 
# 
# 
# TIMERS 
#BatchStartTimeout=10 
#CompleteWait=0 
#EpilogMsgTime=2000 
#GetEnvTimeout=2 
#HealthCheckInterval=0 
#HealthCheckProgram= 
InactiveLimit=0
KillWait=30
#MessageTimeout=10 
#ResvOverRun=0 
MinJobAge=300
#OverTimeLimit=0 
SlurmctldTimeout=120
SlurmdTimeout=300
#UnkillableStepTimeout=60 
#VSizeFactor=0 
Waittime=0
# 
# 
# SCHEDULING 
#DefMemPerCPU=0 
FastSchedule=1
#MaxMemPerCPU=0 
#SchedulerTimeSlice=30 
SchedulerType=sched/backfill
SelectType=select/cons_res
SelectTypeParameters=CR_Core
# 
# 
# JOB PRIORITY 
#PriorityFlags= 
#PriorityType=priority/basic 
#PriorityDecayHalfLife= 
#PriorityCalcPeriod= 
#PriorityFavorSmall= 
#PriorityMaxAge= 
#PriorityUsageResetPeriod= 
#PriorityWeightAge= 
#PriorityWeightFairshare= 
#PriorityWeightJobSize= 
#PriorityWeightPartition= 
#PriorityWeightQOS= 
# 
# 
# LOGGING AND ACCOUNTING 
#AccountingStorageEnforce=0 
#AccountingStorageHost=
#AccountingStorageLoc=
#AccountingStoragePass=
#AccountingStoragePort=
AccountingStorageType=accounting_storage/none
#AccountingStorageUser=
AccountingStoreJobComment=YES
ClusterName=cluster
#DebugFlags= 
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=job_container/none 
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/cgroup
SlurmctldDebug=3
#SlurmctldLogFile=
SlurmdDebug=3
#SlurmdLogFile=
#SlurmSchedLogFile= 
#SlurmSchedLogLevel= 
# 
# 
# POWER SAVE SUPPORT FOR IDLE NODES (optional) 
#SuspendProgram= 
#ResumeProgram= 
#SuspendTimeout= 
#ResumeTimeout= 
#ResumeRate= 
#SuspendExcNodes= 
#SuspendExcParts= 
#SuspendRate= 
#SuspendTime= 
# 
# 
# COMPUTE NODES 
NodeName=head CPUs=1 State=UNKNOWN 
PartitionName=batch Nodes=head Default=YES MaxTime=INFINITE State=UP
EOF