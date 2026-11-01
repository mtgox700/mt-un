#!/bin/zsh
cd -- "${0:A:h}"
export PATH="/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS:$PATH"
exec /usr/bin/python3 server.py
