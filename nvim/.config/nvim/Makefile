# Pi CR / nvim config test & format tasks
#
#   make test         run the pi.cr plenary busted specs
#   make test-file FILE=tests/pi_cr/map_spec.lua   run one spec file
#   make format       stylua format pi.cr + tests
#   make check        stylua check + full test run

.PHONY: test test-file format check

test:
	./scripts/test-pi-cr.sh

test-file:
	@test -n "$(FILE)" || (echo "usage: make test-file FILE=tests/pi_cr/xxx_spec.lua" && exit 1)
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

# Only the code this repo tests/owns; other lua/ files predate stylua config.
format:
	stylua lua/pi/cr/ tests/

check:
	stylua --check lua/pi/cr/ tests/
	./scripts/test-pi-cr.sh
