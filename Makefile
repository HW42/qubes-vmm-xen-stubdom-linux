.DEFAULT_GOAL = get-sources
.SECONDEXPANSION:

.PHONY: get-sources verify-sources clean clean-sources

SHELL := bash

include Makefile.vars

UNTRUSTED_SUFF := .UNTRUSTED

FETCH_CMD := wget --no-use-server-timestamps -q -O

URLS := \
    http://download.qemu-project.org/qemu-$(QEMU_VERSION).tar.xz.sig \
    https://kernel.org/pub/linux/kernel/v$(firstword $(subst ., ,$(LINUX_VERSION))).x/linux-$(LINUX_VERSION).tar.sign

ALL_FILES := $(addprefix dl/,$(notdir $(patsubst %.sign,%.xz,$(patsubst %.sig,%,$(URLS))) $(filter %.sig, $(URLS)) $(filter %.sign, $(URLS))))
ALL_URLS := $(patsubst %.sign,%.xz,$(patsubst %.sig,%,$(URLS))) $(filter %.sig, $(URLS)) $(filter %.sign, $(URLS))

$(filter %.sig, $(ALL_FILES)) $(filter %.sign, $(ALL_FILES)): dl/%:
	@mkdir -p dl
	@$(FETCH_CMD) $@ $(filter %/$*,$(ALL_URLS))

keys/%.gpg: $$(sort $$(wildcard keys/$$*/*.asc))
	@cat $^ | gpg --dearmor >$@

dl/%: dl/%.sig keys/$$(firstword $$(subst -, ,$$*)).gpg
	@$(FETCH_CMD) $@$(UNTRUSTED_SUFF) $(filter %/$*,$(ALL_URLS))
	@gpgv --keyring $(word 2,$^) $< $@$(UNTRUSTED_SUFF) 2>/dev/null || \
		{ echo "Wrong signature on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	@mv $@$(UNTRUSTED_SUFF) $@

dl/%.xz: dl/%.sign keys/$$(firstword $$(subst -, ,$$*)).gpg
	@$(FETCH_CMD) $@$(UNTRUSTED_SUFF) $(filter %/$*.xz,$(ALL_URLS))
	@gpgv --keyring $(word 2,$^) $< <(xzcat $@$(UNTRUSTED_SUFF)) 2>/dev/null || \
		{ echo "Wrong signature on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	@mv $@$(UNTRUSTED_SUFF) $@

dl/%: checksums/%.sha512
	@$(FETCH_CMD) $@$(UNTRUSTED_SUFF) $(filter %/$*,$(ALL_URLS))
	@sha512sum --status -c <(printf "$$(cat $<)  -\n") <$@$(UNTRUSTED_SUFF) || \
		{ echo "Wrong SHA512 checksum on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	@mv $@$(UNTRUSTED_SUFF) $@

get-sources: $(ALL_FILES)
	git submodule update --init

verify-sources:
	@true

clean:
	$(MAKE) -f Makefile.stubdom clean

clean-sources:
	rm -rf dl
