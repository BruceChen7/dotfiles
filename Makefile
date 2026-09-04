# Dotfiles root Makefile: stow the managed config packages + nvim plugin tests.
#
#   make stow               stow all managed packages (whitelist below)
#   make stow PACKAGE=nvim  stow a single package (must be in the whitelist)
#   make dryrun             preview what stow would create/conflict (no changes)
#   make list               show the managed packages
#   make test               run the nvim pi.cr plenary busted specs
#   make test-file FILE=... run one nvim spec file
#   make check              stylua check + full nvim test run
#   make format             stylua format pi.cr + tests

.PHONY: stow dryrun list test test-file check format

# Managed packages (whitelist; everything else in the repo is NOT stowed —
# .ssh/.pi/.git and tool docs stay out on purpose).
PACKAGES := nvim starship tig ghostty dot-local kitty

STOW := stow --dotfiles -t $(HOME)

stow:
	@if [ -n "$(PACKAGE)" ]; then \
		case " $(PACKAGES) " in *" $(PACKAGE) "*) ;; *) \
			echo "unknown package: $(PACKAGE)"; echo "valid packages: $(PACKAGES)"; exit 1;; \
		esac; \
		$(STOW) $(PACKAGE); \
	else \
		$(STOW) $(PACKAGES); \
	fi

dryrun:
	$(STOW) -n $(PACKAGES)

list:
	@echo "$(PACKAGES)"

test:
	$(MAKE) -C nvim/.config/nvim test

test-file:
	@test -n "$(FILE)" || (echo "usage: make test-file FILE=tests/pi_cr/xxx_spec.lua" && exit 1)
	$(MAKE) -C nvim/.config/nvim test-file FILE=$(FILE)

check:
	$(MAKE) -C nvim/.config/nvim check

format:
	$(MAKE) -C nvim/.config/nvim format
