#!/bin/bash
set -euo pipefail

claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add jarrodwatts/claude-hud
claude plugin install superpowers@superpowers-marketplace
claude plugin install claude-hud@claude-hud
