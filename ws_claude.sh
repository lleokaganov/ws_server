#!/bin/bash
# Launcher for the aguardia project.
#
# Opens Claude Code in the unified project root /home/opt/Claude/aguardia/, which
# contains all three subprojects so Claude has access to every part of the system:
#   - aguardia_front/     frontend (public via /home/work/www/aguardia3 symlink,
#                         git stored externally in aguardia_front.git/, see front-git)
#   - aguardia_server/    Rust WebSocket backend deployed to Hetzner
#   - aguardia_firmware/  ESP-IDF firmware (component aguardia_ws)
#
# Symlinked to ~/bin/aguardia, so just run `aguardia` from anywhere.

#cd /home/opt/Claude/Golota || exit 1

clear

re WS

exec claude --chrome --continue "$@"
