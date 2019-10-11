#!/usr/bin/make -f
#
# Copyright (c) 2013-2019, Timothy Baldwin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

HARDDISC4=$(HOME)/Downloads/HardDisc4.5.24.util
QEMU_SRC=$(HOME)/Downloads/qemu-4.0.0.tar.xz
RPCEMU=$(HOME)/Downloads/rpcemu-0.8.15.tar.gz
IOMD=$(HOME)/Downloads/IOMD-Soft.5.24.zip

LINUX_ROM=./RISC_OS
VERBOSE=

# From: https://www.gnu.org/software/make/manual/html_node/Call-Function.html#Call-Function
pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))

QEMU1:=$(call pathsearch,qemu-arm)
BASH:=$(call pathsearch,bash)
BWRAP:=$(call pathsearch,bwrap)
export BWRAP
export QEMU1

SHELL=$(BASH)
JOBS:=$(shell getconf _NPROCESSORS_ONLN)
export JOBS

SHELL=$(warning Building $@)$(BASH)
.SHELLFLAGS:=-e -c $(if $(VERBOSE), -x)
BASHF:=$(BASH) $(.SHELLFLAGS)
.ONESHELL:
.SILENT:

.SUFFIXES:
.DELETE_ON_ERROR:
.PHONY: all script-all

all: comma2attr

ifeq ($(INSECURE), YES)
QEMU:=/usr/bin/env
else
include Built/sandbox_config_make
all: Built/sandbox_config_sh
script-all: Built/sandbox_config_sh
endif

robind = $(foreach dir,$(wildcard $(1)),--ro-bind $(dir) $(dir))
sandbox_misc := $(call robind,/bin /lib* /usr/bin /usr/lib* /etc/alternatives)
sandbox_build := $(call robind,/bin /lib* /usr /etc/alternatives) --dev /dev --tmpfs /usr/local
sandbox_base = $(BWRAP) --unsetenv TMPDIR --unshare-all $(if $(use_seccomp), --seccomp 9 9< <(Built/gen_seccomp $(1)), --new-session) --proc /proc --dir /tmp --dir /dev/shm
ldd2sandbox = env -i $(sandbox_base) $(sandbox_misc) --ro-bind $(1) /exe ldd /exe < /dev/null | sed -nr 's:^(.*[ \t])?((/usr)?/lib[-A-Za-z_0-9]*(/[-A-Za-z_0-9][-A-Za-z._0-9\+]*)+)([ \t].*)?$$:--ro-bind \2 \2:p'  | sort -u | tr '\n' ' '
lib_depends := $(wildcard /etc/alternatives /etc/ld.so.* Unix/LinuxSupport/*.mk)

include $(wildcard Unix/LinuxSupport/build.mk)

script-all: RISC_OS HardDisc4 Built/wrapper

RISC_OS:

comma2attr: Built/comma2attr
	ln -sf Built/comma2attr comma2attr

Built/comma2attr: Unix/LinuxSupport/comma2attr.c $(lib_depends) | Built
	gcc -std=gnu99 -Wall -g Unix/LinuxSupport/comma2attr.c -o Built/comma2attr

Built/wrapper: Unix/LinuxSupport/wrapper.c $(lib_depends) | Built
	gcc -std=gnu99 -Wall -Os Unix/LinuxSupport/wrapper.c -o Built/wrapper

Built/gen_seccomp: Unix/LinuxSupport/gen_seccomp.c $(lib_depends) | Built
	gcc -std=c99 -Wall -Os Unix/LinuxSupport/gen_seccomp.c -o Built/gen_seccomp -lseccomp

Built/seccomp%: Built/gen_seccomp
	Built/gen_seccomp $* > $@

Built/rpcemu/stamp2: $(RPCEMU) Unix/LinuxSupport/rpcemu_exit.diff | Built/gen_seccomp
	rm -rf Built/rpcemu*
	mkdir -p Built/rpcemu_files
	unpack() {
	  echo "3f092e6000b5d50984e63768a74cdc9a40284d55c984e26df44c7d5875ced6e9 /rpcemu.tar.gz" | sha256sum -c
	  tar -zxf /rpcemu.tar.gz
	  cd rpcemu-0.8.15
	  patch -p1 < /d
	  touch stamp2
	}
	export -f unpack
	$(sandbox_base) $(sandbox_misc) --file 8 8<'$(RPCEMU)' /rpcemu.tar.gz --ro-bind Unix/LinuxSupport/rpcemu_exit.diff /d --bind Built/rpcemu_files /r --chdir /r $(BASHF) unpack </dev/null |& cat
	mv Built/rpcemu_files/rpcemu-0.8.15 Built/rpcemu

Built/rpcemu/src/Makefile: Built/rpcemu/stamp2
	configure() {
	  if uname -m | grep -E -q 'x86|i386'; then
	    ./configure --enable-dynarec CFLAGS="-no-pie -fno-pie"
	  else
	    ./configure
	  fi
	  touch Makefile
	}
	export -f configure
	$(sandbox_base) $(sandbox_build) --bind Built/rpcemu /r --chdir /r/src $(BASHF) configure </dev/null |& cat

Built/rpcemu/rpcemu: Built/rpcemu/src/Makefile
	+cp Unix/LinuxSupport/rpcemu.cfg Built/rpcemu/rpc.cfg
	build() {
	  touch hd4.hdf roms/ROM
	  $(MAKE) -C src
	  ! rm poduleroms/SyncClock,ffa
	  echo H4sIAISQCFUCA2NgYDNTuO7MAAdlTAEM+Q4MDgwaNgxoQABdgOHVGoZ/DK8ZZoJlQxQ4uHQmMDGw\
	wWSZGWgP+EUYGJb8FXD8z5jIIAgV+0CMRm5GBgYTBgYAXYSkcwABAAA= | base64 -d | gzip -d > cmos.ram
	  touch rpcemu
	}
	export -f build
	$(sandbox_base) $(sandbox_build) --bind Built/rpcemu /r --chdir /r $(BASHF) build </dev/null |& cat

Built/qemu_stamp-v4.0.0: ${QEMU_SRC} Unix/LinuxSupport/qemu_swi.diff | Built/gen_seccomp
	rm -rf Built/qemu*
	mkdir -p Built/qemu_files
	unpack() {
	  echo "13a93dfe75b86734326f8d5b475fde82ec692d5b5a338b4262aeeb6b0fa4e469 /qemu.tar.xz" | sha256sum -c
	  tar -Jxf /qemu.tar.xz
	  cd qemu-4.0.0
	  patch -p1 < /d
	}
	export -f unpack
	$(call sandbox_base,-s) $(sandbox_misc) --file 8 8<'${QEMU_SRC}' /qemu.tar.xz --ro-bind Unix/LinuxSupport/qemu_swi.diff /d --bind Built/qemu_files /q --chdir /q $(BASHF) unpack </dev/null |& cat
	mv Built/qemu_files/qemu-4.0.0 Built/qemu
	touch Built/qemu_stamp-v4.0.0

Built/qemu_Makefile_stamp: Built/qemu_stamp-v4.0.0
	$(call sandbox_base,-s) $(sandbox_build) --bind Built/qemu /q --chdir /q ./configure --enable-attr --target-list=arm-linux-user --disable-werror </dev/null |& cat
	touch Built/qemu_Makefile_stamp

Built/qemu-arm: Built/qemu_Makefile_stamp
	+$(call sandbox_base,-s) $(sandbox_build) --bind Built/qemu /q --chdir /q $(MAKE) </dev/null |& cat
	test ! -L Built/qemu/arm-linux-user
	test ! -L Built/qemu/arm-linux-user/qemu-arm
	ln -f Built/qemu/arm-linux-user/qemu-arm Built/qemu-arm
	touch Built/qemu-arm

Built/sandbox_config_sh: $(QEMU) Built/gen_seccomp
	set -o pipefail
	exec > Built/sandbox_config_sh
	echo use_seccomp=$(use_seccomp)
ifeq ($(QEMU),/usr/bin/env)
	echo QEMU=

	echo -n 'auto_bwrap_args=( '
else
	echo QEMU=/qemu-arm
	echo -n 'auto_bwrap_args=( '
	$(call ldd2sandbox,$(QEMU))
	echo -n '--ro-bind $(QEMU) /qemu-arm '
endif
	for i in --die-with-parent --as-pid-1 "--cap-drop ALL"; do
	  if $(BWRAP) --unshare-all $$i --dev-bind / / true; then
	    echo -n "$$i "
	  fi
	done
	echo \)

Built/sandbox_config_make: Built/gen_seccomp $(LINUX_ROM) /bin
	set -o pipefail
	$(BWRAP) --ro-bind / /  true
	#
	if $(BWRAP) --seccomp 9 9< <(Built/gen_seccomp) --ro-bind / /  true; then
	  use_seccomp=true
	  seccomp_bits='--seccomp 9 9< <(Built/gen_seccomp)'
	fi
	#
	export RISC_OS_Alias_IXFSBoot='BASIC -quit IXFS:$$.Finish'
	if $(sandbox_base) --ro-bind '$(LINUX_ROM)' /RISC_OS /RISC_OS --help </dev/null |& cat; then
	  eval $(sandbox_base) $$seccomp_bits --ro-bind Unix/LinuxSupport/Finish /Finish --ro-bind '$(LINUX_ROM)' /RISC_OS /RISC_OS --abort-on-input </dev/null |& cat;
	  QEMU1=/usr/bin/env
	elif ! eval $(sandbox_base) $$seccomp_bits  --ro-bind Unix/LinuxSupport/Finish /Finish --ro-bind '$(LINUX_ROM)' /RISC_OS $$($(call ldd2sandbox,"$$QEMU1")) --ro-bind "$$QEMU1" /qemu-arm /qemu-arm /RISC_OS --abort-on-input </dev/null |& cat; then
	  QEMU1=Built/qemu-arm
	fi
	echo "use_seccomp:=$$use_seccomp
	QEMU:=$$QEMU1" > $@

HardDisc4: | $(HARDDISC4) Built/sandbox_config_sh $(LINUX_ROM)
	set -o pipefail
	! rm -rf HardDisc4_files
	mkdir HardDisc4_files
	cp --reflink=auto '$(HARDDISC4)' HardDisc4_files/hd4,ffc
	echo 'c6e19fcc9a9783cbb8ebf5d1c52464ca810bf94ad6509bbe4818391c6bc8d4f4 *HardDisc4_files/hd4,ffc' | sha256sum -c
ifeq ($(INSECURE), YES)
	env -i RISC_OS_Alias_IXFSBoot='/IXFS:$$.proc.self.cwd.HardDisc4_files.hd4
	BASIC -quit IXFS:$$.proc.self.cwd.Unix.LinuxSupport.Finish' '$(LINUX_ROM)'
else
	. Built/sandbox_config_sh
	env -i RISC_OS_Alias_IXFSBoot='/IXFS:$$.HardDisc4_files.hd4
	BASIC -quit IXFS:$$.Finish' $(sandbox_base) \
	 --ro-bind Unix/LinuxSupport/Finish /Finish --bind HardDisc4_files /HardDisc4_files \
	 --ro-bind '$(LINUX_ROM)' /RISC_OS "$${auto_bwrap_args[@]}" \
	 $$QEMU /RISC_OS  --abort-on-input </dev/null |& cat
endif
	cp -a --reflink=auto 'HardDisc4_files/HardDisc4/!Boot/RO520Hook/Boot' 'HardDisc4_files/HardDisc4/!Boot/Choices/Boot'
	printf 'X AddTinyDir IXFS:$$\nX AddTinyDir <IXFS$$HardDisc4>\n' > 'HardDisc4_files/HardDisc4/!Boot/Choices/Boot/Tasks/Pinboard,feb'
	mv HardDisc4_files/HardDisc4 .

Built/boot_iomd_rom: $(IOMD) | Built
	echo 'a9eb33be72f0ead8c6263dd15da5648639094e6b34001739363571fe08fc9d91 *$(IOMD)' | sha256sum -c
	$(sandbox_base) $(sandbox_misc) --ro-bind '$(IOMD)' /iomd.zip unzip -p iomd.zip "soft/!Boot/Choices/Boot/PreDesk/!!SoftLoad/riscos" > $@
	echo '8d51bc41f479ebdaa2ceb2a2ba3bab59473dced135881685a0ae0b5ea89f1491 *$@' | sha256sum -c
	setfattr -n user.RISC_OS.LoadExec -v 0x00e5ffff00000000 $@ || true

$(HARDDISC4):
	sh Unix/LinuxSupport/download.sh '$(HARDDISC4)' "https://www.riscosopen.org/zipfiles/platform/common/HardDisc4.5.24.util" "c6e19fcc9a9783cbb8ebf5d1c52464ca810bf94ad6509bbe4818391c6bc8d4f4"
	setfattr -n user.RISC_OS.LoadExec -v 0x00fcffff00000000 $@ || true

$(IOMD):
	sh Unix/LinuxSupport/download.sh '$(IOMD)' "https://www.riscosopen.org/zipfiles/platform/riscpc/IOMD-Soft.5.24.zip" "a9eb33be72f0ead8c6263dd15da5648639094e6b34001739363571fe08fc9d91"
	setfattr -n user.RISC_OS.LoadExec -v 0x0091faff00000000 $@ || true

${QEMU_SRC}:
	sh Unix/LinuxSupport/download.sh '${QEMU_SRC}' "https://download.qemu.org/qemu-4.0.0.tar.xz" "13a93dfe75b86734326f8d5b475fde82ec692d5b5a338b4262aeeb6b0fa4e469"
	setfattr -n user.RISC_OS.LoadExec -v 0x00fdffff00000000 $@ || true

$(RPCEMU):
	sh Unix/LinuxSupport/download.sh '$(RPCEMU)' "http://www.marutan.net/rpcemu/cgi/download.php?sFName=0.8.15/rpcemu-0.8.15.tar.gz" "3f092e6000b5d50984e63768a74cdc9a40284d55c984e26df44c7d5875ced6e9"
	setfattr -n user.RISC_OS.LoadExec -v 0x0089ffff00000000 $@ || true
