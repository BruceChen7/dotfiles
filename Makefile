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
#   make herdr-install      link all local herdr plugins under herdr/
#   make herdr-uninstall    unlink all local herdr plugins

.PHONY: stow dryrun list test test-file check format herdr-install herdr-uninstall

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

# herdr/ holds local herdr plugins (each dir has a herdr-plugin.toml).
HERDR_PLUGINS := $(wildcard herdr/*/herdr-plugin.toml)
HERDR_PLUGIN_DIRS := $(dir $(HERDR_PLUGINS))

herdr-install:
	@if [ -z "$(HERDR_PLUGINS)" ]; then \
		echo "no herdr plugins found under herdr/"; exit 1; \
	fi
	@for d in $(HERDR_PLUGIN_DIRS); do \
		echo "==> linking $$d"; \
		herdr plugin link $${d%/}; \
	done

herdr-uninstall:
	@if [ -z "$(HERDR_PLUGINS)" ]; then \
		echo "no herdr plugins found under herdr/"; exit 1; \
	fi
	@for d in $(HERDR_PLUGIN_DIRS); do \
		id=$$(sed -n 's/^id[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' $${d}herdr-plugin.toml | head -1); \
		[ -n "$$id" ] || { echo "!! no id in $${d}herdr-plugin.toml"; continue; }; \
		echo "==> unlinking $$id"; \
		herdr plugin unlink "$$id" || true; \
	done
