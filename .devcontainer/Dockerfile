# Dev container: where Claude Code runs. Carries a PHP 8.3 CLI (matching the
# stock wordpress:php8.3 web image) + wp-cli so Claude can drive the site:
# user/plugin/option changes, search-replace on URLs, upgrades, and the
# first-boot `wp core install`.
#
# Profiles add extras at build time via ARGs (no second Dockerfile): the civicrm
# profile sets EXTRA_PHP_EXTS (CiviCRM's PHP extensions) and INSTALL_CV=true
# (the `cv` CLI). Plain WordPress leaves both at their inert defaults.
FROM node:20-bookworm

ARG TZ
ENV TZ="$TZ"
ARG CLAUDE_CODE_VERSION=latest
ARG GIT_DELTA_VERSION=0.18.2
ARG ZSH_IN_DOCKER_VERSION=1.2.0
# Profile switches (set by e.g. the civicrm overlay's build.args).
ARG INSTALL_CV=false
ARG EXTRA_PHP_EXTS=""

# Base tools + firewall tooling (iptables/ipset/dig/aggregate) copied from the
# spades-dev-environment pattern.
RUN apt-get update && apt-get install -y --no-install-recommends \
  less git procps sudo fzf zsh man-db unzip gnupg2 gh \
  iptables ipset iproute2 dnsutils aggregate jq \
  nano vim curl wget ca-certificates default-mysql-client \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# PHP 8.3 CLI for wp-cli, pinned to match the wordpress:php8.3 web image.
# Debian bookworm ships PHP 8.2, so add the sury.org repo to get 8.3.
RUN apt-get update && apt-get install -y --no-install-recommends lsb-release apt-transport-https \
  && curl -sSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/sury-php.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php $(lsb_release -sc) main" \
     > /etc/apt/sources.list.d/sury-php.list \
  && apt-get update && apt-get install -y --no-install-recommends \
     php8.3-cli php8.3-mysql php8.3-mbstring php8.3-curl \
     php8.3-zip php8.3-gd php8.3-xml php8.3-opcache \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional extra PHP extensions for a profile (e.g. civicrm: php8.3-intl
# php8.3-soap php8.3-bcmath php8.3-imagick php8.3-gettext). The sury.org source
# added above persists, so these resolve to 8.3. No-op for plain WordPress.
RUN if [ -n "$EXTRA_PHP_EXTS" ]; then \
      apt-get update && apt-get install -y --no-install-recommends $EXTRA_PHP_EXTS \
      && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# wp-cli — Claude's primary lever for driving the site: user/plugin/option
# changes, search-replace on URLs, upgrades, and the first-boot core install.
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
  && chmod +x /usr/local/bin/wp

# Optional CiviCRM CLI (cv), enabled by the civicrm profile (INSTALL_CV=true).
RUN if [ "$INSTALL_CV" = "true" ]; then \
      curl -fsSL https://download.civicrm.org/cv/cv.phar -o /usr/local/bin/cv \
      && chmod +x /usr/local/bin/cv; \
    fi

# git-delta for readable diffs.
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Persist shell history across rebuilds (named volume mounted in devcontainer.json).
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory && touch /commandhistory/.bash_history \
  && chown -R node /commandhistory

ENV DEVCONTAINER=true
# npm's default global dir (/usr/local/lib/node_modules) is root-owned, so
# `npm install -g` below fails as the node user. Point the global prefix at a
# node-owned dir and put its bin on PATH (persists at runtime too).
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:$PATH
RUN mkdir -p /workspace /home/node/.claude /usr/local/share/npm-global \
  && chown -R node:node /workspace /home/node/.claude /usr/local/share/npm-global
WORKDIR /workspace

USER node
ENV SHELL=/bin/zsh EDITOR=nano VISUAL=nano
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git -p fzf \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" -x

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Warm-seed Claude Code plugins (superpowers + claude-hud) into the image so a
# fresh config volume starts pre-populated; postCreateCommand re-runs these
# against the live volume to stay rebuild-proof.
COPY --chown=node:node bake-plugins.sh configure-claude-settings.js /tmp/
RUN chmod +x /tmp/bake-plugins.sh && /tmp/bake-plugins.sh \
  && node /tmp/configure-claude-settings.js "$(command -v node)" \
  && rm /tmp/bake-plugins.sh /tmp/configure-claude-settings.js

# Firewall: run at every container start via sudo (NOPASSWD, single script).
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh \
  && echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall \
  && chmod 0440 /etc/sudoers.d/node-firewall
USER node
