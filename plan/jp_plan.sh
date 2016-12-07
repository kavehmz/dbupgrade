#!/bin/bash
# jp-dbpri02

# jp-dbpri01-9.6 (rep jp-dbpri02) 34.194.23.132
# jp-dbpri02-9.6 (rep jp-dbpri01-9.6)

# 34.194.23.132 eipalloc-0a44ae34
# 34.193.219.201 eipalloc-705bb14e

. ./common.sh
. ./server.sh

setup jp-dbpri01-9.6 upgradetest-jp-dbpri02 jp-dbpri02 jp-dbpri02.regentmarkets.com eipalloc-0a44ae34

setup jp-dbpri02-9.6 upgradetest-jp-dbpri02 jp-dbpri02 jp-dbpri02.regentmarkets.com eipalloc-0a44ae34