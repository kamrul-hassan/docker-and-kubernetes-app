# syntax=docker/dockerfile:1

# ---- build ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first so this layer stays cached until a project file changes
COPY global.json Directory.Build.props ./
COPY src/TaskFlow.Api/TaskFlow.Api.csproj src/TaskFlow.Api/
RUN dotnet restore src/TaskFlow.Api/TaskFlow.Api.csproj

COPY src/ src/
RUN dotnet publish src/TaskFlow.Api/TaskFlow.Api.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

# ---- runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true
COPY --from=build /app/publish .
# Non-root user built into the .NET images
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "TaskFlow.Api.dll"]
