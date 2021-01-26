# Univention Corporate Server - Container Mode

This is a self deploying container for running a [Univention Corporate Server](https://www.univention.com/products/ucs/) ([UCS](https://docs.software-univention.de/manual.html)) with the role of [master](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_master), [slave](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_slave), [backup](https://docs.software-univention.de/manual.html#domain-ldap:Domain_controller_backup), [member](https://docs.software-univention.de/manual.html#domain-ldap:Member_server) or [basesystem](https://docs.software-univention.de/manual.html#domain-ldap:Base_system).

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

## [Clean sensitive credentials from container environment](docs/README.ENVIRONMENT.CLEANUP.md)
You don't wan't sensitive credentials in your environment variables after an succeeded firt start/boot, take a look into this section to cleanup your container.