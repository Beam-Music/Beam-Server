# ================================
# Build image
# ================================
FROM swift:5.10-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Set up a build area
WORKDIR /build

# Copy Package manifest and lock file first to leverage Docker cache
COPY Package.* ./
RUN swift package resolve

# Copy the rest of the source code
COPY Sources ./Sources

# Build everything, with optimizations, with static linking, and using jemalloc
RUN swift build -c release \
    --static-swift-stdlib \
    -Xlinker -ljemalloc \
    && echo "Build completed, listing build directory:" \
    && ls -la /build/.build/release \
    && echo "Build path:" \
    && swift build --package-path /build -c release --show-bin-path

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN BUILD_PATH=$(swift build --package-path /build -c release --show-bin-path) \
    && echo "Build path: $BUILD_PATH" \
    && ls -la $BUILD_PATH \
    && cp "$BUILD_PATH/App" ./App \
    && chmod +x ./App \
    && echo "Staging directory contents:" \
    && ls -la

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public and resources directories if they exist
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      libjemalloc2 \
      ca-certificates \
      tzdata \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      # libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      # libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /App

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /App

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
