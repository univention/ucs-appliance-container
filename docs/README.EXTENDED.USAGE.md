# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

## Extended usage

First fo all, you have to understand the structure of all the important running parts. The container starts with the process identifier ( PID ) number one by the command/entrypoint ``` /bin/systemd ``` or better ``` systemd ```. From now controlls systemd all type of service units and will start a service unit called [univention-container-mode-firstboot](../root/usr/lib/systemd/system/univention-container-mode-firstboot.service) for the first start/boot process with some depencies like the environment service unit [univention-container-mode-environment](../root/usr/lib/systemd/system/univention-container-mode-environment.service).

### Basic syntax for script naming

| **ID** | TYPE AND DESCRIPTION         |
| ------:|:---------------------------- |
| **00** | *system and defaults*        |
| **10** | **free to use**              |
| **20** | -                            |
| **30** | service units preprocessing  |
| **40** | setup preprocessing          |
| **50** | setup and join processing    |
| **60** | setup postprocessing         |
| **70** | service units postprocessing |
| **80** | -                            |
| **90** | **free to use**              |
| **99** | *system and cleanups*        |

### Structure of join based system roles like [primary](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) directory node or [managed](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node) node.

A closer look into [univention-container-mode-firstboot](../root/usr/lib/systemd/system/univention-container-mode-firstboot.service) will explain that the command ``` ( run-parts --verbose -- join ) ``` runs all scripts from the [join](../root/usr/lib/univention-container-mode/join) directory. Finaly copy, rename and modify the [template](../root/usr/lib/univention-container-mode/template) into the directory ``` root/usr/lib/univention-container-mode/join/ ``` and run your own container build to deploy the new feature on your local registry.
