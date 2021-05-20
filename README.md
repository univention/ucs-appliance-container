# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [primary node](https://docs.software-univention.de/manual.html#domain-ldap:Primary_Directory_Node), [backup node](https://docs.software-univention.de/manual.html#domain-ldap:Backup_Directory_Node), [replica node](https://docs.software-univention.de/manual.html#domain-ldap:Replica_Directory_Node) or [managed node](https://docs.software-univention.de/manual.html#domain-ldap:Managed_Node).

## [Build your own bootstrap container image](docs/README.BUILD.md) ```( optionally )```
If you like, you can build your own minbase container image from scratch. You find a script called [bootstrap.sh](bootstrap/bootstrap.sh), this works for docker or podman.

## [Build your own container image or take a look on Docker Hub](docs/README.BUILD.md)
```bash
docker search univention/univention-corporate-server
```

## [Container privileges](docs/README.PRIVILEGES.md)
There are four options to deploy, it's recommended to study the examples too.

## [Container options and environment variables](docs/README.ENVIRONMENT.md)
This section will explaine the container environment with the minimum and/or maximum amount settings.

## [Basic examples](docs/README.BASIC.EXAMPLES.md)
Here you will find all basic examples for running a ucs with different systems roles.

## [Advanced examples](docs/README.ADVANCED.EXAMPLES.md)
Here you will find advanced example(s) for running a ucs with different systems roles and some additional options, like networking and external certificate(s).

## [Extended usage](docs/README.EXTENDED.USAGE.md)
Would you like to expand the project for yourself? Have a look at the section [extended usage](docs/README.EXTENDED.USAGE.md) and read about the possibilities with a [template](root/usr/lib/univention-container-mode/template) file and how to place it. But if you think, that will be great for all of us, check [this on](CONTRIBUTING.md) too.

## [Clean sensitive credentials from container environment](docs/README.ENVIRONMENT.CLEANUP.md)
You don't wan't sensitive credentials in your environment variables after an succeeded first start/boot, take a look into this section to cleanup your container.

## [Contributing](CONTRIBUTING.md)

Please read the [contributing guide](./CONTRIBUTING.md) to find more information about the UCS development process, how to propose bugfixes and improvements.
The [Code of Conduct contains guidelines](./CONTRIBUTING.md#code-of-conduct) we expect project participants to adhere to.

## [License](LICENSE)

Univention Corporate Server is built on top of many existing open source projects which use their own licenses.
The source code of all parts written by Univention like the management system is licensed under the AGPLv3 if not stated otherwise directly in the source code.
Please see the [license file](./LICENSE) for more information.
