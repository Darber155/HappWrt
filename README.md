# HappWRT

Клиент подписок формата Happ / v2ray для роутеров OpenWrt. Скачивает подписку,
разбирает share-ссылки в конфигурацию [sing-box](https://sing-box.sagernet.org/),
запускает её как сервис и поднимает прозрачный прокси-шлюз через TUN-интерфейс
с разделением трафика по правилам (split tunneling).

Оформлен как лента (feed) пакетов OpenWrt:

| Пакет | Назначение |
|-------|------------|
| `happwrt` | Ядро: парсер подписки, генератор конфига, CLI, init-скрипт |
| `luci-app-happwrt` | Веб-интерфейс в LuCI |

## Возможности

- Подписка по ссылке (`http(s)://`, `file://` или локальный файл), автоматическое
  обновление по cron с настраиваемым интервалом.
- Поддержка протоколов: VLESS (в т.ч. REALITY), VMess, Trojan, Shadowsocks,
  Hysteria2, TUIC, AnyTLS.
- Транспорты: TCP, WebSocket, gRPC, HTTP/2, QUIC, HTTPUpgrade; uTLS-отпечатки.
- Прозрачный прокси через TUN + `auto_route` (без ручных правил nftables).
- Режимы маршрутизации: «через VPN только заблокированное в РФ», «всё кроме РФ
  напрямую», «только выбранные домены/IP», «всё через прокси».
- Галочка **Keep games off the VPN** — игровые сервисы (Steam, Epic, PlayStation,
  Xbox, Nintendo, Riot, Blizzard и др.) и типовые игровые порты идут напрямую.
- Свои списки доменов и IP в обе стороны, блокировка рекламы, выбор сервера,
  авто-тест скорости (url-test), пинг серверов в интерфейсе.
- Веб-интерфейс LuCI и CLI.

## Требования

- Asus RT-AX53U (или другой роутер) с OpenWrt **25.12.x**.
- Архитектура `mipsel_24kc` (для RT-AX53U).
- Ядро `sing-box-tiny` устанавливается как зависимость автоматически.

## Сборка пакета

Готовый `.apk` собирается автоматически в GitHub Actions при пуше в репозиторий.

1. Запушьте репозиторий на GitHub.
2. Откройте **Actions → build → последний запуск**.
3. Скачайте артефакт `happwrt-mipsel_24kc` (содержит `happwrt-*.apk` и
   `luci-app-happwrt-*.apk`).

Сборка использует официальный OpenWrt SDK 25.12.5 через
[`openwrt/gh-action-sdk`](https://github.com/openwrt/gh-action-sdk).
Перед сборкой прогоняются ucode-тесты парсера и генератора.

## Установка на роутер (одной командой)

По SSH на роутере:

```sh
wget -qO- https://raw.githubusercontent.com/Darber155/HappWrt/master/install.sh | sh
```

Скрипт сам скачает готовые `.apk` из последнего GitHub Release и установит их
вместе с зависимостями (`apk add --allow-untrusted`). Только для архитектуры
`mipsel_24kc` (Asus RT-AX53U); принудительно — `HAPPWRT_FORCE=1`.

Можно сразу указать подписку и включить сервис:

```sh
wget -qO- https://raw.githubusercontent.com/Darber155/HappWrt/master/install.sh | sh -s "https://subs.example.com/xxxx"
```

После установки узел **Services → HappWRT**.

### Установка вручную

Скачайте из раздела **Releases** файлы `happwrt.apk` и `luci-app-happwrt.apk`:

```sh
scp happwrt.apk luci-app-happwrt.apk root@192.168.1.1:/tmp/
ssh root@192.168.1.1
apk add --allow-untrusted /tmp/happwrt.apk /tmp/luci-app-happwrt.apk
```

> Пакеты не подписаны доверенным ключом OpenWrt, поэтому нужен флаг
> `--allow-untrusted`. Ядро `sing-box-tiny` и зависимости подтянутся из
> официального репозитория.

Обновите кэш LuCI (или просто перелогиньтесь): пункт **Services → HappWRT**.

## Настройка

1. **Services → HappWRT**.
2. Вставьте ссылку на подписку в **Subscription URL**.
3. Выберите режим маршрутизации.
4. Включите **Enable** и нажмите **Save & Apply** (настройки применятся,
   конфиг перегенерируется и сервис перезапустится).
5. Нажмите **Update now**, чтобы скачать серверы из подписки.

### Режимы маршрутизации

- **bypass_blocked** (по умолчанию) — всё идёт напрямую, а **через прокси только
  ресурсы, заблокированные в РФ**. Используются rule-set'ы
  [`1andrevich/Re-filter-lists`](https://github.com/1andrevich/Re-filter-lists):
  домены (`refilter-domains`) и IP (`refilter-ips`). Они скачиваются через сам
  прокси и **обновляются автоматически раз в сутки**, кэшируются в
  `/etc/happwrt/cache.db`. DNS для этих доменов тоже идёт через прокси.
- **bypass_ru** — весь трафик идёт через прокси, кроме российских домен/IP
  (rule-set `geosite-category-ru` и `geoip-ru`), локальных сетей и всего, что
  указано в «Always direct».
- **rules_only** — напрямую идёт всё, через прокси — только домены/IP из списков
  «Always proxy». Удобно для точечного обхода.
- **global** — всё через прокси.

Списки **Always proxy/direct** добавляются поверх любого режима.

## CLI

```sh
happwrt update        # скачать подписку, собрать конфиг, перезапустить
happwrt update        # (крон вызывает autoupdate)
happwrt autoupdate    # обновить, если прошёл интервал
happwrt gen           # только перегенерировать config.json
happwrt apply         # перегенерировать и перезапустить
happwrt node node-3   # выбрать сервер по тегу
happwrt restart       # перезапустить сервис
happwrt status        # состояние
```

Конфигурация: `/etc/config/happwrt`. Сгенерированные файлы:
`/etc/happwrt/nodes.json`, `/etc/happwrt/config.json`.

## Rule-set и зеркала

В режиме `bypass_ru` sing-box скачивает `.srs` наборы с
`raw.githubusercontent.com` (с кэшированием в `/etc/happwrt/cache.db`). Если
GitHub недоступен, укажите зеркало в поле **Rule-set base URL** — например,
`https://ghproxy.com/https://raw.githubusercontent.com` или свой прокси.

После первого успешного запуска наборы кэшируются, и интернет для их загрузки
больше не нужен.

## Разработка

Тесты парсера и генератора (нужен `ucode`):

```sh
tests/run_tests.sh
```

Локальная сборка пакета (Linux, OpenWrt SDK 25.12.5):

```sh
# скачать SDK для ramips/mt7621 и распаковать
./scripts/build-local.sh /path/to/sdk
```

## Структура

```
happwrt/                      ядро
  files/usr/share/happwrt/    parse.uc, gen.uc, opts.uc
  files/usr/bin/happwrt       CLI
  files/etc/init.d/happwrt    procd-сервис
luci-app-happwrt/             веб-интерфейс
  htdocs/.../view/happwrt/    JS-вью
  root/usr/share/rpcd/ucode/  rpcd-бэкенд
tests/                        ucode-тесты и фикстуры
```

## Лицензия

MIT
