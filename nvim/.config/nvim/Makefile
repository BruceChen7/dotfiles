# Pi CR / nvim config test & format tasks
#
#   make test         run the pi.cr plenary busted specs
#   make test-file FILE=tests/pi_cr/map_spec.lua   run one spec file
#   make format       stylua format pi.cr + tests
#   make check        stylua check + full test run

.PHONY: test test-file format check

test:
	./scripts/test-pi-cr.sh
	./scripts/test-pi-cr-first-hunk-e2e.sh
	./scripts/test-netrw-e117.sh

test-file:
	@test -n "$(FILE)" || (echo "usage: make test-file FILE=tests/pi_cr/xxx_spec.lua" && exit 1)
	@# PlenaryBustedFile 不带 minimal_init 时会回落到用户自己的 init.lua，
	@# 测试结果会随本机配置漂移；直接跑 plenary.busted.run，与 make test 的子进程环境一致。
	nvim --headless -u tests/minimal_init.lua \
		-c 'lua require("plenary.busted").run("$(FILE)")'

# Only the code this repo tests/owns; other lua/ files predate stylua config.
format:
	stylua lua/pi/cr/ tests/

check:
	stylua --check lua/pi/cr/ tests/
	./scripts/test-pi-cr.sh
	./scripts/test-pi-cr-first-hunk-e2e.sh
