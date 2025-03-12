#!/bin/bash

# Массив контейнеров
containers=(
  "library/caddy"  # Основной контейнер caddy
  "metgen/caddy-cf-tf"  # Кастомный контейнер caddy
)

# Ассоциативный массив для версий
declare -A imageVersions

# Получаем версии каждого контейнера
for container in "${containers[@]}"; do
  echo "Calling Docker Hub to get $container Versions..."

  # Инициализируем переменные для получения версий
  versions=()

  # Запрос на получение тегов с Docker Hub
  request=$(curl -s "https://hub.docker.com/v2/repositories/$container/tags")

  # Извлекаем версии с помощью jq
  while [[ -n "$request" ]]; do
    # Используем jq для фильтрации тегов, которые соответствуют формату x.y.z
    versions+=( $(echo "$request" | jq -r '.results[].name' | grep -E '^\d+\.\d+\.\d+$') )

    # Проверка на наличие следующей страницы
    next_url=$(echo "$request" | jq -r '.next')
    if [[ "$next_url" != "null" ]]; then
      request=$(curl -s "$next_url")
    else
      break
    fi
  done

  # Сохраняем версии в массив
  imageVersions[$container]=("${versions[@]}")

  # Выводим найденные версии
  echo Found the following $container Versions:"
  printf "%s\n" "${imageVersions[$container]}"
done

# Получаем последние версии
latestOfficialVersion="${imageVersions["library/caddy"][0]}"
latestmetgenVersion="${imageVersions["metgen/caddy-cf-tf"][0]}"

echo "Latest Offical version: $latestOfficialVersion"
echo "Latest metgen version: $latestmetgenVersion"

# Сравниваем версии
if [[ "${imageVersions["library/caddy"]}" =~ ${imageVersions["metgen/caddy-cf-tf"][0]} ]]; then
  echo "Docker image metgen/caddy-cf-tf:${imageVersions["metgen/caddy-cf-tf"][0]} matches image library/caddy:${imageVersions["library/caddy"][0]}"
else
  echo "Docker image metgen/caddy-cf-tf:${imageVersions["metgen/caddy-cf-tf"][0]} version behind image library/caddy:${imageVersions["library/caddy"][0]}"

  # Читаем Dockerfile и заменяем старую версию на новую
  dockerfilePath="./Dockerfile"
  if [[ -f "$dockerfilePath" ]]; then
    oldVersion="${imageVersions["metgen/caddy-cf-tf"][0]}"
    newVersion="$latestOfficialVersion"

    echo "Обновление версии в Dockerfile: $oldVersion -> $newVersion"

    # Заменяем старую версию на новую
    sed -i "s/$oldVersion/$newVersion/g" "$dockerfilePath"
  fi
fi

echo ""
echo "***************************************"
echo "Performing Git Operations..."

# Настройки Git
git config user.email "metalnikov.gennadiy@gmail.com"
git config user.name "metgen"

# Стадирование изменений
echo "Staging all changed files..."
git add .

# Проверка наличия изменений
if git diff --quiet; then
  echo "No changes have been made. Skipping Git Push."
else
  echo "Committing changes..."
  git commit -m "GitHub Actions commit: Updated caddy to $latestOfficialVersion [skip ci]"

  echo "Applying git tag v$latestOfficialVersion..."
  git tag -a "v$latestOfficialVersion" -m "Caddy release v$latestOfficialVersion"

  echo "Pushing changes to main repository.."
  git push -q origin HEAD:main
  git push --tags -q origin HEAD:main
fi

echo "Git Operations Complete..."
echo "***************************************"

