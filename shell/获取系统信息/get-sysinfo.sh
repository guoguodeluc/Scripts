#!/bin/bash
## Author: lujianguo
## Email：lujianguo0128@126.com
## Date: 20220916
## Version: v1.1
## Description:  v1.0  获取系统信息并以json格式显示。
##               v1.1  添加主机完整ipv4，并添加挂载盘和盘类型，完善网络ESTABLISHED部分
##               
############################################################

############################################################
### Environmental configuration ###
############################################################
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

############################################################
### Define globle variables ###
############################################################

############################################################
### Define functions ###
############################################################
function get_system() {
  # 获取系统信息
  classis=$(hostnamectl |awk '/Chassis/{print $2}' 2>/dev/null)
  hostname=$(hostname 2>/dev/null)
  default_ipv4=$(ip -4 route get 114.114.114.114 2>/dev/null | head -1 | awk '{print $7}')
  all_ipv4=$(hostname -I 2>/dev/null)
  distribution=$(awk '/^ID=/' /etc/*-release 2>/dev/null | awk -F'=' '{gsub("\"","");print $2}')
  distribution_version=$(python -c 'import platform; print platform.linux_distribution()[1]' 2>/dev/null)
  [ -z $distribution_version ] && distribution_version=$(awk '/^VERSION_ID=/' /etc/*-release 2>/dev/null | awk -F'=' '{gsub("\"","");print $2}')
  os_pretty_name=$(awk '/^PRETTY_NAME=/' /etc/*-release 2>/dev/null | awk -F'=' '{gsub("\"","");print $2 }')
  kernel=$(uname -r 2>/dev/null)
  os_time=$(date +"%F %T" 2>/dev/null)
  uptime=$(uptime 2>/dev/null |awk '{print $3}'|awk -F, '{print $1}')
  
  system_facts=$(cat << EOF
  { 
    "classis": "${classis:-}",
    "hostname": "${hostname:-}",
    "default_ipv4": "${default_ipv4:-}",
    "all_ipv4": "${all_ipv4:-}",
    "distribution": "${distribution:-}",
    "distribution_version": "${distribution_version:-}",
    "os_pretty_name": "${os_pretty_name:-}",
    "kernel": "${kernel:-}",
    "os_time": "${os_time:-}",
    "uptime": "${uptime:-}"
  }
EOF
)
  echo $system_facts
}

function get_cpu() {
  # 获取cpu使用信息
  cpu_usedutilization=$(cat <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat) | awk -v RS="" '{printf ("%.2f\n", ($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5))}')
  cpu_loadavg1=$(awk '{print $1}' /proc/loadavg)
  cpu_loadavg5=$(awk '{print $2}' /proc/loadavg)
  cpu_loadavg15=$(awk '{print $3}' /proc/loadavg)
  
  cpu_facts=$(cat << EOF
  {
    "cpu_usedutilization": "${cpu_usedutilization:-0}",
    "cpu_loadavg1": "${cpu_loadavg1:-0}",
    "cpu_loadavg5": "${cpu_loadavg5:-0}",
    "cpu_loadavg15": "${cpu_loadavg15:-0}"
  }
EOF
)
  echo $cpu_facts
}

function get_mem() {
  # 获取内存使用信息
  memfree=$(awk -F":|kB" '$1~/^MemFree/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  memavailable=$(awk -F":|kB" '$1~/^MemAvailable/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  memtotal=$(awk -F":|kB" '$1~/^MemTotal/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  memcache=$(awk -F":|kB" '$1~/^Cached/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  membuffer=$(awk -F":|kB" '$1~/^Buffers/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  swaptotal=$(awk -F":|kB" '$1~/^SwapTotal/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  swapfree=$(awk -F":|kB" '$1~/^SwapFree/{gsub(/ +/,"",$0);print $2/1024/1024 }' /proc/meminfo)
  [ "${memtotal:-0}" != "0" ] && mem_usedutilization=$(echo "${memtotal:-0} ${memfree:-0} ${memcache:-0} ${membuffer:-0}" | awk '{printf ("%.2f\n", ($1-$2-$3-$4)*100/$1)}') 
  [ "${swaptotal:-0}" != "0" ] && swap_usedutilization=$(echo "${swaptotal:-0} ${swapfree:-0}"| awk '{printf ("%.2f\n", ($1-$2)*100/$1)}')
  mem_facts=$(cat << EOF
  {  
    "memtotal": "${memtotal:-}",
    "memfree": "${memfree:-}",
    "memavailable": "${memavailable:-}",
    "memcache": "${memcache:-}",
    "membuffer": "${membuffer:-}",
    "mem_usedutilization": "${mem_usedutilization:-0}",
    "swaptotal": "${swaptotal:-}",
    "swapfree": "${swapfree:-}",
    "swap_usedutilization": "${swap_usedutilization:-0}"
  }
EOF
)
  echo $mem_facts
}

function get_disk() {
  # 获取磁盘使用信息  
  mount=$(grep '^/dev/' /proc/mounts | grep -v -E 'docker|containers|iso9660|kubelet' | awk '{print $2}')
  for m in ${mount:-}; do
    mount_block=$(df -hP $m |awk 'END{print $1}')
    mount_type=$(df -ThP $m |awk 'END{print $2}')
    size_total=$(df -hP $m 2>/dev/null | awk 'END{print $2}')
    size_use=$(df -hP $m 2>/dev/null | awk 'END{print $3}')
    size_available=$(df -hP $m 2>/dev/null | awk 'END{print $4}')
    size_usedutilization=$(df -hP $m 2>/dev/null | awk 'END{sub(/'%'/,"");print $5}')
    block_total=$(df -hPBM $m 2>/dev/null | awk 'END{print $2}')
    block_use=$(df -hPBM $m 2>/dev/null | awk 'END{print $3}')
    block_available=$(df -hPBM $m 2>/dev/null | awk 'END{print $4}')
    block_usedutilization=$(df -hPBM $m 2>/dev/null | awk 'END{sub(/'%'/,"");print $5}')
    inode_total=$(df -hPi $m 2>/dev/null | awk 'END{print $2}')
    inode_use=$(df -hPi $m 2>/dev/null | awk 'END{print $3}')
    inode_available=$(df -hPi $m 2>/dev/null | awk 'END{print $4}')
    inode_usedutilization=$(df -hPi $m 2>/dev/null | awk 'END{sub(/'%'/,"");print $5}')
    mount_facts=${mount_facts:-''}$(cat <<EOF
    {
      "mount": "${m:-}",
      "mount_block": "${mount_block:-}",
      "mount_type": "${mount_type:-}",
      "size_total": "${size_total:-}",
      "size_use": "${size_use:-}",
      "size_available": "${size_available:-}",
      "size_usedutilization": "${size_usedutilization:-0}",
      "block_total": "${block_total:-}",
      "block_use": "${block_use:-}",
      "block_available": "${block_available:-}",
      "block_usedutilization": "${block_usedutilization:-0}",
      "inode_total": "${inode_total:-}",
      "inode_use": "${inode_use:-}",
      "inode_available": "${inode_available:-}",
      "inode_usedutilization": "${inode_usedutilization:-0}"
    },
EOF
    )
  done
  disk_facts="["${mount_facts%?}"]"
  echo $disk_facts
}

function get_network() {
  # 获取网络信息
  established=$(netstat -natp 2>/dev/null | awk '/^tcp/&&/ESTABLISHED/{print $4,$5,$7}' |awk -F'[ :/]' '{printf "{\"local_ip\":\"%s\",\"local_port\":\"%s\",\"foreign_ip\":\"%s\",\"foreign_port\":\"%s\",\"app_pid\":\"%s\",\"app_name\":\"%s\"},\n",$1,$2,$3,$4,$5,$6 }')
  stat=$(netstat -nat 2>/dev/null | awk '/^tcp/{++S[$NF]}END{for(m in S) print "\"" m "\":",S[m] ","}')
  network_facts=$(cat << EOF
  {
    "tcp_stat": {${stat%?}},
    "established": [ ${established%?} ]
  }
EOF
  )
  echo $network_facts
}

function get_program() {
  # 获取占用内存前10的程序信息
  #ps -eo pid,pcpu,pmem,stat,comm --sort=-pmem  |head |sed 1d | while read app_pid app_cpu app_mem app_stat app_comm ; 
  all_pid=$(ps -eo pid,pcpu,pmem,stat,comm --sort=-pmem  |head |awk '{print $1}' |sed 1d ) 
  for app_pid in ${all_pid} ; 
  do
    app_cpu=$(ps -p $app_pid -o pcpu |sed 1d)
    app_mem=$(ps -p $app_pid -o pmem |sed 1d)
    app_stat=$(ps -p $app_pid -o stat |sed 1d)
    app_comm=$(ps -p $app_pid -o comm |sed 1d)
    app_dir=$(cat /proc/$app_pid/cmdline)
    app_env_tmp=$(cat /proc/$app_pid/environ)
    app_env=$(echo $app_env_tmp |sed  's@\\@@g')
    ps_facts=${ps_facts:-''}$(cat << EOF
  {
    "app_pid": "${app_pid:-}",
    "app_cpu": "${app_cpu:-}",
    "app_mem": "${app_mem:-}",
    "app_stat": "${app_stat:-}",
    "app_comm": "${app_comm:-}",
    "app_dir": "${app_dir:-}",
    "app_env": "${app_env:-}"
  },
EOF
  ) 
  done
  program_facts="["${ps_facts%?}"]"
  echo -e $program_facts
}

function main(){
echo "{"
echo ' "sys": ' &&  get_system && echo ","
echo ' "cpu": '&&  get_cpu  && echo ","
echo ' "mem": ' &&  get_mem && echo ","
echo ' "disk": ' &&  get_disk && echo ","
echo '  "net": ' &&  get_network && echo ","
echo '  "app": ' &&  get_program
echo "}"
}
############################################################
### Run Functions ###
############################################################
main "$@"
