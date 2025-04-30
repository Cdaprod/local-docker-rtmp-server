.PHONY: hosts firewall bootstrap

hosts:
	sudo ./infra/hosts/link-hosts.sh

firewall:
	sudo ./infra/firewall/apply-firewall.sh

bootstrap:
	sudo ./infra/bootstrap/init-dev-machine.sh