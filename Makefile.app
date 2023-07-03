include Makefile

lib-deps = $(foreach T, $(subst :, ,$(LIBS)), $(lastword $(subst /, ,$(T))))

GITHUB-BASE = https://github.com/unikraft

QEMU_ARGS := -nographic
QEMU_ARGS += -fsdev local,id=myid,path=$(PWD)/fs0,security_model=none
QEMU_ARGS += -device virtio-9p-pci,fsdev=myid,mount_tag=fs0,disable-modern=on,disable-legacy=off
QEMU_ARGS += -netdev bridge,id=en0,br=virbr0 -device virtio-net-pci,netdev=en0
QEMU_ARGS += -append "netdev.ipv4_addr=172.44.0.2 netdev.ipv4_gw_addr=172.44.0.1 netdev.ipv4_subnet_mask=255.255.255.0 --"

ifeq ($(findstring x86_64,$(MAKECMDGOALS)),x86_64)
ARCH = x86_64
QEMU_ARGS += -kernel build/nginx_qemu-x86_64
else ifeq ($(findstring aarch64,$(MAKECMDGOALS)),aarch64)
ARCH = aarch64
QEMU_ARGS += -machine virt -cpu cortex-a57 -kernel build/nginx_qemu-arm64
endif

setup:
	$(shell git clone $(GITHUB-BASE)/unikraft $(UK_ROOT))
	$(foreach LIB, $(lib-deps),	\
		$(shell git clone $(GITHUB-BASE)/lib-$(LIB) $(UK_LIBS)/$(LIB)))

config-$(ARCH): setup
	@UK_DEFCONFIG=$(PWD)/config-qemu-$(ARCH) $(MAKE) -C $(UK_ROOT) A=$(PWD) L=$(LIBS) defconfig

setup-netw:
	@sudo ip link set dev virbr0 down 2> /dev/null
	@sudo ip link del dev virbr0 2> /dev/null
	@sudo ip link add dev virbr0 type bridge
	@sudo ip address add 172.44.0.1/24 dev virbr0
	@sudo ip link set dev virbr0 up

run-$(ARCH): setup config-$(ARCH) all setup-netw
	@sudo /usr/bin/qemu-system-$(ARCH) $(QEMU_ARGS)
