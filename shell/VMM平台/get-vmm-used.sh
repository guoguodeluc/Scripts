#!/bin/bash
## Author: lujianguo
## Email：guoguodelu@126.com
## Date: 2022/11/14
## Version: v1.0
## Description:  v1.0  获取vmm平台资源使用情况
##               
## 共识: 变量-大写字母加下划线，函数-小写字母写加下划线
############################################################

############################################################
### Environmental configuration ###
############################################################
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

############################################################
### Define globle variables ###
############################################################
## 单位T
LONGHORN_TOTAL=202
CPU_ALLOCATE_RATIO=16
RAM_ALLOCATE_RATIO=1.5

############################################################
### Define functions ###
############################################################
## 获取vmm物理节点信息
function get_node_info(){
	NODE_NUM=$(kubectl get no --selector longhorn=longhorn |grep Ready |wc -l)
	## awk '{for(n=2;n<=NF;n++)t[n]+=$n}END{for(n=1;n<=NF;n++)printf t[n]" ";print"\n"}'
	NODE_CPU=$(kubectl get no --selector longhorn=longhorn -o=jsonpath='{range .items[*]}{.status.addresses[0].address}{","}{.status.capacity.cpu}{","}{.status.capacity.memory}{"\n"}{end}' |awk -F'[,]' '{sum+=$2} END {print sum}')
	NODE_VCPU=$(($CPU_ALLOCATE_RATIO*$NODE_CPU))
	NODE_RAM=$(kubectl get no --selector longhorn=longhorn -o=jsonpath='{range .items[*]}{.status.addresses[0].address}{","}{.status.capacity.cpu}{","}{.status.capacity.memory}{"\n"}{end}' |awk -F'[,]' '{sum+=$3} END {printf ("%d",  sum/1024/1024)}')
	NODE_VRAM=$( echo  |awk '{ printf ("%d", '$RAM_ALLOCATE_RATIO'*'$NODE_RAM') }')
	#NODE_LOCAL=$(kubectl get no --selector longhorn=longhorn -o=jsonpath='{range .items[*]}{.status.capacity.ephemeral-storage}{"\n"}{end}' | awk '{sum+=$1} END { printf ("%d", sum/1024/1024) }' )
	echo "物理机信息: $NODE_NUM"台",$NODE_CPU"核",$NODE_RAM"G",$LONGHORN_TOTAL"T""
}
## 获取vmm虚拟机的信息
function get_vm_info(){
	VM_NUM=$(kubectl get vm -A |sed 1d |wc -l)
	VM_CPU=$(kubectl get vm -A -o=jsonpath='{range .items[*]}{.spec.template.spec.domain.resources.limits.cpu}{","}{.spec.template.spec.domain.resources.limits.memory}{"\n"}{end}' |awk -F '[,]' '{sum+=$1} END {print sum}')
	VM_RAM=$(kubectl get vm -A -o=jsonpath='{range .items[*]}{.spec.template.spec.domain.resources.limits.cpu}{","}{.spec.template.spec.domain.resources.limits.memory}{"\n"}{end}' |awk -F '[,]' '{sum+=$2} END {print sum}')
	LONGHORN_G=$(kubectl get pvc -o wide -A  |awk '/longhorn-image-/{a+=/Ti/?$5*1024:(/Mi/?$5/1024:(/Ki/?$5/(1024^2):$5))}END{print a}')
	SCALIO_G=$(kubectl get pvc -o wide -A  |awk '/vxflexos-sp-hdd01-vmm/{a+=/Ti/?$5*1024:(/Mi/?$5/1024:(/Ki/?$5/(1024^2):$5))}END{print a}')
	VM_PVC=$(echo |awk '{printf ( "%d", ('$LONGHORN_G'+'$SCALIO_G')/1024 )}')
	echo "虚拟机信息: $VM_NUM"台",$VM_CPU"核",$VM_RAM"G",$VM_PVC"T"(longhorn$LONGHORN_G+scalio$SCALIO_G)"
}
## 平台整体资源使用比例
function used_rate(){
	#echo $VM_CPU,$NODE_VCPU
	#echo $VM_RAM,$NODE_VRAM
	RATIO_OVERSOLD=$(echo |awk '{printf ("%.2f", '$VM_NUM'/'$NODE_NUM')}')
	RATIO_CPU=$(echo |awk '{printf ("%.2f", '$VM_CPU'/'$NODE_VCPU')}' )
	RATIO_RAM=$(echo |awk '{printf ("%.2f", '$VM_RAM'/'$NODE_VRAM')}')
	TATIO_LONGHORN=$(echo | awk '{printf ("%.2f", ('$LONGHORN_G'/1024)/'$LONGHORN_TOTAL')}' )
	echo "VMM使用率;  $RATIO_OVERSOLD,$RATIO_CPU,$RATIO_RAM,$TATIO_LONGHORN"
}
## 主函数
function main(){
	get_node_info && get_vm_info
	used_rate
}
############################################################
### Run Functions ###
############################################################
main "$@"
