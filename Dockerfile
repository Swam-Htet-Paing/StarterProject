# ============================================================================
# TODO - Session 6: Containers and Secure Image Build
# ============================================================================
# Rename this file to `Dockerfile` and implement it. Requirements you must meet:
#
#   1. Multi-stage build
#        Stage 1 (build):   mcr.microsoft.com/dotnet/sdk:8.0    restore, build, publish
#        Stage 2 (runtime): a minimal ASP.NET 8.0 runtime image
#
#   2. Choose and JUSTIFY a base image
#        - `-noble-chiseled` : no shell, no package manager, non-root by default.
#                              Smallest attack surface, but you cannot `docker exec`
#                              into it to debug - document how you diagnose instead.
#        - `-alpine`         : has a shell, musl-based. Watch out for ICU /
#                              globalization settings.
#        Write your decision and the trade-off in docs/adr-0001-base-image.md.
#
#   3. Run as a non-root user and prove it (`docker run --rm <image> id`).
#
#   4. Order layers so that a source-only change does not invalidate the
#      restore layer.
#
#   5. Keep the final image free of the SDK, tests, .git and any secret.
#
# Acceptance (Lab 3, Session 6):
#   - `docker build` succeeds
#   - the container runs as a non-root user
#   - /healthz/live and /healthz/ready respond from inside the container
# ============================================================================
# syntax=docker/dockerfile:1

# --- Stage 1: build ----------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# 1. Project files first. This layer changes only when a dependency changes.
COPY DevOpsLab.sln ./
COPY src/DevOpsLab.Domain/DevOpsLab.Domain.csproj                 src/DevOpsLab.Domain/
COPY src/DevOpsLab.Application/DevOpsLab.Application.csproj       src/DevOpsLab.Application/
COPY src/DevOpsLab.Infrastructure/DevOpsLab.Infrastructure.csproj src/DevOpsLab.Infrastructure/
COPY src/DevOpsLab.WebApi/DevOpsLab.WebApi.csproj                 src/DevOpsLab.WebApi/

# 2. Restore only the web project's graph. Test projects never enter the image.
RUN dotnet restore src/DevOpsLab.WebApi/DevOpsLab.WebApi.csproj

# 3. Now the source. A one-character change here invalidates from this line down.
COPY src/ src/

# 4. Publish. --no-restore asserts that step 2 really did the work.
RUN dotnet publish src/DevOpsLab.WebApi/DevOpsLab.WebApi.csproj \
        --configuration Release \
        --no-restore \
        --output /app/publish \
        /p:UseAppHost=false

        # --- Stage 2: runtime --------------------------------------------------------
# noble-chiseled: Ubuntu 24.04, no shell, no package manager, non-root by default.
FROM mcr.microsoft.com/dotnet/aspnet:8.0-noble-chiseled AS runtime
WORKDIR /app

# 8080, not 80: a non-root process cannot bind a port below 1024.
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

# Only the published output crosses from the build stage.
COPY --from=build /app/publish .

# The chiseled image already defaults to `app` (UID 1654). Say it anyway, so the
# intent survives a change of base image.
USER app

ENTRYPOINT ["dotnet", "DevOpsLab.WebApi.dll"]

# No HEALTHCHECK on purpose: it would run INSIDE the container, and this image
# has no shell and no curl. See docs/adr-0001-base-image.md.