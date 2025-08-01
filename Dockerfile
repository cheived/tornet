FROM python:3.9-slim

# Set Docker environment variable
ENV DOCKER_ENV=true

# Install dependencies with retry mechanism to handle repository issues
RUN apt-get update && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/lib/apt/lists/partial && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        tor \
        python3-pip \
        sudo \
        procps \
	snowflake-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Fix permissions for Tor directories
RUN chmod 700 /var/lib/tor && \
    mkdir -p /var/run/tor && \
    chmod 700 /var/run/tor && \
    chown -R debian-tor:debian-tor /var/lib/tor && \
    chown -R debian-tor:debian-tor /var/run/tor && \
    chmod 700 /var/log/tor

# Set working directory
WORKDIR /app

# Copy the package files
COPY . .

# Install the package
RUN pip3 install --no-cache-dir .

# Create a configuration file for Tor that sets the SOCKS port to 9050
RUN echo "SocksPort 0.0.0.0:9050" > /etc/tor/torrc \
    && echo "SocksPolicy accept *" >> /etc/tor/torrc \
    && echo "Log notice stdout" >> /etc/tor/torrc \
    && echo "DataDirectory /var/lib/tor" >> /etc/tor/torrc \
    && echo "RunAsDaemon 0" >> /etc/tor/torrc \
    && echo "UseBridges 1

ClientTransportPlugin snowflake exec /usr/bin/snowflake-client -url https://snowflake-broker.torproject.net/ -ampcache https://cdn.ampproject.org/ -front www.google.com -ice stun:stun.l.google.com:19302,stun:stun.antisip.com:3478,stun:stun.bluesip.net:3478,stun:stun.dus.net:3478,stun:stun.epygi.com:3478,stun:stun.sonetel.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.voys.nl:3478 utls-imitate=hellorandomizedalpn -log /var/log/tor/snowflake-client.log

Bridge snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72
#Bridge snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA" >> /etc/tor/torrc

# Expose the Tor SOCKS proxy port
EXPOSE 9050

# Create a startup script that properly starts Tor
RUN echo '#!/bin/bash\necho "Starting Tor..."\nchown -R debian-tor:debian-tor /var/lib/tor\n\n# Start Tor as the debian-tor user\nsudo -u debian-tor tor -f /etc/tor/torrc &\n\n# Wait for Tor to establish connections\nsleep 5\n\n# Run tornet in the foreground\necho "Starting TorNet IP rotation service..."\ntornet --interval 60 --count 0' > /app/start.sh \
    && chmod +x /app/start.sh

# Run the startup script when the container starts
CMD ["/app/start.sh"]