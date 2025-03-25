#!/bin/bash

set -e  # Прекращаем выполнение при ошибках

# Массив контейнеров
containers=(
  "library/caddy"  # Основной контейнер caddy
  "metgen/caddy-plus"  # Кастомный контейнер caddy
)

declare -A imageVersions  # Ассоциативный массив для версий

# Функция для получения версий
get_versions() {
  local container=$1
  echo "Fetching versions for $container from Docker Hub..."

  local versions=()
  local request=$(curl -s "https://hub.docker.com/v2/repositories/$container/tags")

  if [[ -z "$request" || "$request" == "null" ]]; then
    echo "Error: No response from Docker Hub. Check network or rate limits."
    return
  fi

  while [[ -n "$request" && "$request" != "null" ]]; do
    local new_versions=$(echo "$request" | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [[ -z "$new_versions" ]]; then
      echo "No valid version tags found for $container."
      return
    fi
    
    versions+=($new_versions)

    next_url=$(echo "$request" | jq -r '.next')
    [[ -z "$next_url" || "$next_url" == "null" ]] && break
    request=$(curl -s "$next_url")
  done

  imageVersions[$container]="${versions[0]}"
  echo "Latest version for $container: ${imageVersions[$container]}"
}

# Получаем версии
for container in "${containers[@]}"; do
  get_versions "$container"
done

latestOfficialVersion="${imageVersions["library/caddy"]}"
latestCustomVersion="${imageVersions["metgen/caddy-plus"]}"

# Сравниваем версии
if [[ "$latestCustomVersion" == "$latestOfficialVersion" ]]; then
  echo "metgen/caddy-plus:$latestCustomVersion is up to date with library/caddy:$latestOfficialVersion"
else
  echo "Updating metgen/caddy-plus from $latestCustomVersion to $latestOfficialVersion"

  # Обновляем Dockerfile
  dockerfilePath="./Dockerfile"
  if [[ -f "$dockerfilePath" ]]; then
    sed -i "s/$latestCustomVersion/$latestOfficialVersion/g" "$dockerfilePath"
    echo "Dockerfile updated: $latestCustomVersion -> $latestOfficialVersion"
  fi

  echo "***************************************"
  echo "Performing Git Operations..."

  git config user.email "metalnikov.gennadiy@gmail.com"
  git config user.name "metgen"

  git add .
  if git status --porcelain | grep -q .; then
    echo "Changes detected, committing..."
    git commit -m "Updated Caddy to $latestOfficialVersion [skip ci]"
    git tag -a "v$latestOfficialVersion" -m "Caddy release v$latestOfficialVersion"
    git push -q origin HEAD:main
    git push --tags -q origin HEAD:main
  else
    echo "No changes detected, skipping Git push."
  fi

  echo "Git Operations Complete..."
  echo "***************************************"
fi
