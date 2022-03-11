
export FW_VER := 3.30

PROJ := FlashFloppy
VER := v$(FW_VER)

PYTHON := python3

export ROOT := $(CURDIR)

.PHONY: FORCE

.DEFAULT_GOAL := all

prod-%: FORCE
	$(MAKE) target mcu=$* target=bootloader level=prod
	$(MAKE) target mcu=$* target=floppy level=prod
	$(MAKE) target mcu=$* target=quickdisk level=prod
	$(MAKE) target mcu=$* target=bl_update level=prod
	$(MAKE) target mcu=$* target=io_test level=prod

debug-%: FORCE
	$(MAKE) target mcu=$* target=bootloader level=debug
	$(MAKE) target mcu=$* target=floppy level=debug
	$(MAKE) target mcu=$* target=quickdisk level=debug
	$(MAKE) target mcu=$* target=bl_update level=debug
	$(MAKE) target mcu=$* target=io_test level=debug

logfile-%: FORCE
	$(MAKE) target mcu=$* target=bootloader level=logfile
	$(MAKE) target mcu=$* target=floppy level=logfile
	$(MAKE) target mcu=$* target=quickdisk level=logfile

all-%: FORCE prod-% debug-% logfile-% ;

all: FORCE all-stm32f105 all-at32f435 ;

clean: FORCE
	rm -rf out

mrproper: FORCE clean
	rm -rf ext

out: FORCE
	mkdir -p out/$(mcu)/$(level)/$(target)
	rsync -a --include="*/" --exclude="*" src/ out/$(mcu)/$(level)/$(target)

target: FORCE out
	$(MAKE) -C out/$(mcu)/$(level)/$(target) -f $(ROOT)/Rules.mk target.bin target.hex target.dfu $(mcu)=y $(level)=y $(target)=y

HXC_FF_URL := https://www.github.com/keirf/flashfloppy-hxc-file-selector
HXC_FF_URL := $(HXC_FF_URL)/releases/download
HXC_FF_VER := v9-FF

_legacy_dist: FORCE
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/FF_Gotek-$(VER).upd \
	  out/$(mcu)/$(level)/floppy/target.bin & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/alt/bootloader/FF_Gotek-bootloader-$(VER).upd \
	  out/$(mcu)/$(level)/bl_update/target.bin & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/alt/io-test/FF_Gotek-io-test-$(VER).upd \
	  out/$(mcu)/$(level)/io_test/target.bin & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/alt/logfile/FF_Gotek-logfile-$(VER).upd \
	  out/$(mcu)/logfile/floppy/target.bin & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/alt/quickdisk/FF_Gotek-quickdisk-$(VER).upd \
	  out/$(mcu)/$(level)/quickdisk/target.bin & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py old \
	  $(t)/alt/quickdisk/logfile/FF_Gotek-quickdisk-logfile-$(VER).upd \
	  out/$(mcu)/logfile/quickdisk/target.bin & \
	wait

_dist: FORCE
	cd out/$(mcu)/$(level)/floppy; \
	  cp -a target.dfu $(t)/dfu/flashfloppy-$(mcu)-$(VER).dfu; \
	  cp -a target.hex $(t)/hex/flashfloppy-$(mcu)-$(VER).hex
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/flashfloppy-$(VER).upd \
	  out/$(mcu)/$(level)/floppy/target.bin $(mcu) & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/alt/bootloader/flashfloppy-bootloader-$(VER).upd \
	  out/$(mcu)/$(level)/bl_update/target.bin $(mcu) & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/alt/io-test/flashfloppy-io-test-$(VER).upd \
	  out/$(mcu)/$(level)/io_test/target.bin $(mcu) & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/alt/logfile/flashfloppy-logfile-$(VER).upd \
	  out/$(mcu)/logfile/floppy/target.bin $(mcu) & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/alt/quickdisk/flashfloppy-quickdisk-$(VER).upd \
	  out/$(mcu)/$(level)/quickdisk/target.bin $(mcu) & \
	$(PYTHON) $(ROOT)/scripts/mk_update.py new \
	  $(t)/alt/quickdisk/logfile/flashfloppy-quickdisk-logfile-$(VER).upd \
	  out/$(mcu)/logfile/quickdisk/target.bin $(mcu) & \
	wait

dist: level := prod
dist: t := $(ROOT)/out/flashfloppy-$(VER)
dist: FORCE all
	rm -rf out/flashfloppy-*
	mkdir -p $(t)/hex
	mkdir -p $(t)/dfu
	mkdir -p $(t)/alt/bootloader
	mkdir -p $(t)/alt/logfile
	mkdir -p $(t)/alt/io-test
	mkdir -p $(t)/alt/quickdisk/logfile
	$(MAKE) _legacy_dist mcu=stm32f105 level=$(level) t=$(t)
	$(MAKE) _dist mcu=stm32f105 level=$(level) t=$(t)
	$(MAKE) _dist mcu=at32f435 level=$(level) t=$(t)
	$(PYTHON) scripts/mk_qd.py --window=6.5 $(t)/alt/quickdisk/Blank.qd
	cp -a COPYING $(t)/
	cp -a README.md $(t)/
	cp -a RELEASE_NOTES $(t)/
	cp -a examples $(t)/
	[ -e ext/HxC_Compat_Mode-$(HXC_FF_VER).zip ] || \
	(mkdir -p ext ; cd ext ; wget -q --show-progress $(HXC_FF_URL)/$(HXC_FF_VER)/HxC_Compat_Mode-$(HXC_FF_VER).zip ; rm -rf index.html)
	(cd $(t) && unzip -q ../../ext/HxC_Compat_Mode-$(HXC_FF_VER).zip)
	mkdir -p $(t)/scripts
	cp -a scripts/edsk* $(t)/scripts/
	cp -a scripts/mk_hfe.py $(t)/scripts/
	cd out && zip -r flashfloppy-$(VER).zip flashfloppy-$(VER)

BAUD=115200
DEV=/dev/ttyUSB0
SUDO=sudo
STM32FLASH=stm32flash

ocd: FORCE all
	$(PYTHON) scripts/openocd/flash.py $(target)/target.hex

flash: FORCE all
	$(SUDO) $(STM32FLASH) -b $(BAUD) -w $(target)/target.hex $(DEV)

start: FORCE
	$(SUDO) $(STM32FLASH) -b $(BAUD) -g 0 $(DEV)

serial: FORCE
	$(SUDO) miniterm.py $(DEV) 3000000
