FROM node:24-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Clone ClaudeClaw+ at the ref specified by CLAUDECLAW_PLUS_REF.
# Override at build time with --build-arg CLAUDECLAW_PLUS_REF=<branch|tag|sha> to pin.
WORKDIR /app
ARG CLAUDECLAW_PLUS_REF=main
RUN git clone https://github.com/TerrysPOV/ClaudeClaw-Plus . \
    && git checkout "${CLAUDECLAW_PLUS_REF}" \
    && bun install --frozen-lockfile

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /backup.sh
RUN chmod +x /entrypoint.sh /backup.sh

# Persist Claude Code config, ClaudeClaw+ settings/logs/jobs, and whisper models
VOLUME /root/.claude

EXPOSE 4632

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
