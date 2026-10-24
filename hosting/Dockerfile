FROM node:24-bookworm-slim AS engine
ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 && rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --retry 3 "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip && echo "${GODOT_SHA256}  /tmp/godot.zip" | sha256sum -c - && unzip -q /tmp/godot.zip -d /tmp && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm /tmp/godot.zip
WORKDIR /app
COPY . /app
RUN godot --headless --editor --path /app --import && mkdir -p /home/arena && chown -R node:node /home/arena /app
ENV XDG_DATA_HOME=/home/arena NODE_ENV=production
USER node
EXPOSE 10000
CMD ["node", "hosting/gateway/main.mjs"]
