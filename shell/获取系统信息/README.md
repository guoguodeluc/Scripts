---
title: 
---

# 脚本处理

## jq处理

```bash
curl -sfL http://xxx/shell/get-sysinfo.sh |bash |jq . 
```

## python json.tool模块处理

```bash
curl -sfL http://xxx/shell/get-sysinfo.sh |bash |python -m json.tool > /tmp/$(hostname)-sysinfo.json
```



# 执行脚本说明

脚本输出由**6部**分组成，分别是

- **sys** ：主要包括主机名，ip地址，操作系统，内核版本，启动时间等

- **cpu** ： uptime值和cpu平均负载

- **mem** ：内存使用情况，单位是G 

- **disk** ： 磁盘挂载情况，以及磁盘使用情况

- **net** ：tcp连接情况，主要收集tcp建立的情况

- **app** ：收集系统内内存占用最高的前10个进程
