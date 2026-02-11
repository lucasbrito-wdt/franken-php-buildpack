# FrankenPHP Laravel Octane — Heroku Buildpack

Buildpack para Heroku que instala o [FrankenPHP](https://frankenphp.dev) como binário standalone e executa sua aplicação Laravel com [Octane](https://laravel.com/docs/octane) — **sem Docker**.

O FrankenPHP é um servidor de aplicações moderno para PHP construído sobre o Caddy. Com o Laravel Octane, sua aplicação é mantida em memória entre requisições, resultando em performance extremamente superior.

## Requisitos

- Aplicação **Laravel 10+** ou **11+**
- Pacote `laravel/octane` instalado
- Octane configurado com servidor `frankenphp`

### Preparar o projeto Laravel

```bash
composer require laravel/octane
php artisan octane:install --server=frankenphp
```

Certifique-se que `config/octane.php` tem:

```php
'server' => env('OCTANE_SERVER', 'frankenphp'),
```

## Instalação no Heroku

```bash
heroku buildpacks:set https://github.com/your-org/franken-php-buildpack.git
```

Se precisar de Node.js para build de assets (Vite/Mix), adicione antes:

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add https://github.com/your-org/franken-php-buildpack.git
```

### Deploy

```bash
git push heroku main
```

## Como funciona

### Detecção

O buildpack detecta automaticamente se o projeto é elegível quando encontra:

- `artisan` (Laravel)
- `composer.json` ou `composer.lock` com `laravel/octane`
- Ou `config/octane.php`

### Build (compile)

1. Baixa o binário standalone do FrankenPHP (com cache entre deploys)
2. Instala dependências via Composer (`--no-dev --optimize-autoloader`)
3. Publica e verifica a config do Octane para FrankenPHP
4. Executa otimizações do Laravel:
   - `config:cache`
   - `route:cache`
   - `view:cache`
   - `event:cache`
5. Build de assets frontend (se Node.js disponível)
6. Configura PHP com OPcache + JIT otimizados para worker mode
7. Gera script `start-octane` para inicialização

### Runtime

O buildpack cria um **shim `php`** que redireciona para `frankenphp php-cli`, permitindo usar comandos padrão do Laravel sem modificação:

```bash
# Tudo isso funciona transparentemente:
php artisan octane:start --server=frankenphp
php artisan queue:work
php artisan migrate
php artisan tinker
```

O processo web executa:

```
php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=$PORT
```

O Octane mantém a aplicação Laravel carregada em memória, processando requisições via workers FrankenPHP.

## Variáveis de ambiente

### FrankenPHP

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `FRANKENPHP_VERSION` | `latest` | Versão do FrankenPHP (ex: `v1.4.0`) |
| `FRANKENPHP_ARCH` | `x86_64` | Arquitetura (`x86_64` ou `aarch64`) |
| `FRANKENPHP_LIBC` | `gnu` | Tipo de libc (`gnu` ou `musl`) |

### Laravel Octane

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `OCTANE_WORKERS` | `auto` | Número de workers (auto = baseado em CPUs) |
| `OCTANE_TASK_WORKERS` | `auto` | Número de task workers |
| `OCTANE_MAX_REQUESTS` | `500` | Máximo de requests antes de reciclar worker |
| `OCTANE_HOST` | `0.0.0.0` | Host de escuta |
| `OCTANE_SERVER` | `frankenphp` | Servidor Octane |
| `RUN_MIGRATIONS` | `false` | Executar migrations automaticamente no startup |
| `RUN_RELEASE_SCRIPT` | `false` | Executar `scripts/release.sh` no startup |

### Queue Worker

| Variável | Padrão | Descrição |
|----------|--------|--------|
| `QUEUE_CONNECTION` | (default do Laravel) | Driver de fila (sqs, redis, database) |
| `SQS_QUEUES` | `default` | Nome das filas SQS (separadas por vírgula) |

### PHP

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `PHP_MEMORY_LIMIT` | `256M` | Limite de memória |
| `PHP_MAX_EXECUTION_TIME` | `30` | Tempo máximo de execução (seg) |
| `PHP_OPCACHE_ENABLE` | `1` | Habilitar OPcache |

### Laravel

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `APP_ENV` | `production` | Ambiente da aplicação |
| `APP_DEBUG` | `false` | Modo debug |
| `LOG_CHANNEL` | `stderr` | Canal de log (stderr para Heroku) |

### Exemplos

```bash
# Definir versão específica do FrankenPHP
heroku config:set FRANKENPHP_VERSION=v1.4.0

# 4 workers fixos
heroku config:set OCTANE_WORKERS=4

# Reciclar workers a cada 1000 requests
heroku config:set OCTANE_MAX_REQUESTS=1000

# Rodar migrations no deploy
heroku config:set RUN_MIGRATIONS=true

# Aumentar memória PHP
heroku config:set PHP_MEMORY_LIMIT=512M
```

## Procfile

O buildpack cria um shim `php` que redireciona para `frankenphp php-cli`. Isso permite usar Procfiles padrão do Laravel:

```
#release: bash scripts/release.sh
web: php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=$PORT --workers=auto
worker: php artisan queue:work ${QUEUE_CONNECTION} --queue=${SQS_QUEUES} --tries=3 --timeout=120
```

Ou use o script `start-octane` que lê variáveis de ambiente automaticamente:

```
web: start-octane
worker: php artisan queue:work ${QUEUE_CONNECTION} --queue=${SQS_QUEUES} --tries=3 --timeout=120
```

### Sobre o shim `php`

Como o FrankenPHP standalone não instala um binário `php` separado (usa `frankenphp php-cli`), o buildpack cria um wrapper em `.heroku/frankenphp/bin/php` que redireciona automaticamente. Isso garante compatibilidade com:

- `php artisan ...` (Octane, migrations, queues, tinker, etc.)
- `php composer.phar ...`
- Scripts que chamam `php` diretamente

## PHP otimizado para Octane

O buildpack configura o PHP automaticamente com:

- **OPcache habilitado** com `validate_timestamps=0` (sem verificar arquivos, ideal para worker mode)
- **JIT tracing** com 64M de buffer (aceleração significativa)
- **Realpath cache** de 4MB (reduz I/O de filesystem)
- Logs para `stderr` (compatível com `heroku logs`)
- `expose_php = Off` (segurança)

### Extensões PHP

O FrankenPHP é um binário standalone estaticamente compilado e não inclui todas as extensões padrão do PHP. O buildpack resolve isso de forma inteligente:

1. **Build time**: Detecta se `heroku/php` buildpack foi executado primeiro e usa esse PHP para comandos que precisam de extensões (como `php artisan config:cache`)
2. **Runtime**: Copia extensões críticas do sistema PHP (`mbstring`, `pcntl`, `posix`, `sockets`, etc.) para o diretório `.heroku/frankenphp/extensions`
3. **PHP.ini**: Configura `extension_dir` e carrega automaticamente as extensões copiadas

Isso permite que o FrankenPHP tenha acesso às extensões necessárias during runtime, enquanto mantém a velocidade do binário standalone.

**Extensões que são incluídas automaticamente:**

- `mbstring` (strings multibyte - necessário para Laravel)
- `pcntl` (process control - para sinais de Laravel)
- `posix` (POSIX API)
- `sockets` (sockets)
- `opcache` (opcode caching)
- `redis` (se disponível)
- `igbinary` (serialização)

Se você precisar de extensões adicionais, configure `heroku/php` buildpack primeiro:

```bash
heroku buildpacks:add --index 1 heroku/php
heroku buildpacks:add --index 2 https://github.com/your-org/franken-php-buildpack.git
```

## Estrutura dos arquivos

```
franken-php-buildpack/
├── bin/
│   ├── detect          # Detecta Laravel + Octane
│   ├── compile         # Instala FrankenPHP, Composer, otimiza Laravel
│   ├── release         # Define web: start-octane
│   └── util/
│       └── common.sh   # Funções utilitárias
├── test/
│   ├── run_tests.sh    # Script de teste local
│   └── fixtures/
│       └── simple-app/ # App de exemplo
├── buildpack.toml      # Metadata do buildpack
├── buildpack.json
├── app.json            # Heroku Button support
├── Procfile            # Processo web padrão
├── LICENSE
└── README.md
```

## Troubleshooting

### "laravel/octane not found"

Instale o Octane no seu projeto:

```bash
composer require laravel/octane
php artisan octane:install --server=frankenphp
```

### Octane usando Swoole em vez de FrankenPHP

Defina a variável de ambiente:

```bash
heroku config:set OCTANE_SERVER=frankenphp
```

### Erro de porta

O Heroku define `$PORT` automaticamente. O script `start-octane` usa `$PORT` com fallback para `8000`.

### Worker ficando sem memória

Reduza o `OCTANE_MAX_REQUESTS` para reciclar workers mais frequentemente:

```bash
heroku config:set OCTANE_MAX_REQUESTS=250
```

### Executar comandos artisan no Heroku

```bash
heroku run php artisan tinker
heroku run php artisan migrate
heroku run php artisan queue:work
heroku run php artisan db:seed
```

Ou diretamente via FrankenPHP:

```bash
heroku run frankenphp php-cli artisan tinker
```

### Logs verbosos

```bash
heroku config:set APP_DEBUG=true LOG_LEVEL=debug
heroku logs --tail
```

### Extensão PHP faltando

Se receber erro como `Call to undefined function mb_split()`:

1. Verifique se o `heroku/php` buildpack foi adicionado ANTES deste buildpack
2. Execute `heroku logs --tail` para ver quais extensões foram copiadas
3. Se a extensão não aparecer, adicione `heroku/php` explicitamente:

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/php
heroku buildpacks:add https://github.com/your-org/franken-php-buildpack.git
```

1. Faça deploy novo e verifique `heroku logs` durante o build
### Diagnosticar extensões em runtime

Se as extensões não carregam mesmo após o deploy, execute:

```bash
heroku run bash diagnostics/check-extensions.sh
```

Isso verifica:
- ✅ Se o diretório `/app/.heroku/frankenphp/extensions/` existe
- ✅ Se os arquivos `.so` estão presentes
- ✅ Se a configuração PHP_INI_SCAN_DIR está correta
- ✅ Se `mb_split()` funciona
- ✅ Análise do binary FrankenPHP (ldd)

Exemplo de output esperado:

```
✅ Extensions directory exists: /app/.heroku/frankenphp/extensions
Files in extensions directory:
  /app/.heroku/frankenphp/extensions/mbstring.so
  /app/.heroku/frankenphp/extensions/pcntl.so
  /app/.heroku/frankenphp/extensions/opcache.so

PHP Configuration File: /app/.heroku/frankenphp/etc/php.d/heroku.ini

Testing mb_split: bool(true)
Result: hello, world
```

Se houver problemas:
- `❌ Extensions directory NOT found` - O diretório não foi criado/copiado. Verifique `heroku logs` no build.
- `Extension NOT loaded but exists` - Problema de permissões. Execute: `heroku run chmod +x /app/.heroku/frankenphp/extensions/*.so`
- `mb_split: bool(false)` - Extensão não foi carregada. Verifique PATH e PHP_INI_SCAN_DIR no `heroku logs`
## Performance

Com Laravel Octane + FrankenPHP no Heroku:

- **~2-10x mais rápido** que PHP-FPM tradicional
- A aplicação Laravel é carregada uma vez e servida da memória
- OPcache + JIT fornecem aceleração adicional no nível PHP
- Workers são reciclados automaticamente para prevenir leaks de memória

## Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.
