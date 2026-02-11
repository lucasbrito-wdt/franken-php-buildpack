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

O processo web executa:

```
frankenphp php-cli artisan octane:frankenphp --host=0.0.0.0 --port=$PORT
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
| `RUN_MIGRATIONS` | `false` | Executar migrations automaticamente no deploy |

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

O `Procfile` padrão usa o script `start-octane`:

```
web: start-octane
```

O script `start-octane` lê as variáveis de ambiente e monta o comando Octane. Você pode sobrescrever com um Procfile customizado:

```
web: frankenphp php-cli artisan octane:frankenphp --host=0.0.0.0 --port=${PORT:-8000} --workers=4 --max-requests=1000
```

## PHP otimizado para Octane

O buildpack configura o PHP automaticamente com:

- **OPcache habilitado** com `validate_timestamps=0` (sem verificar arquivos, ideal para worker mode)
- **JIT tracing** com 64M de buffer (aceleração significativa)
- **Realpath cache** de 4MB (reduz I/O de filesystem)
- Logs para `stderr` (compatível com `heroku logs`)
- `expose_php = Off` (segurança)

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
heroku run frankenphp php-cli artisan tinker
heroku run frankenphp php-cli artisan migrate
heroku run frankenphp php-cli artisan queue:work
```

### Logs verbosos

```bash
heroku config:set APP_DEBUG=true LOG_LEVEL=debug
heroku logs --tail
```

## Performance

Com Laravel Octane + FrankenPHP no Heroku:

- **~2-10x mais rápido** que PHP-FPM tradicional
- A aplicação Laravel é carregada uma vez e servida da memória
- OPcache + JIT fornecem aceleração adicional no nível PHP
- Workers são reciclados automaticamente para prevenir leaks de memória

## Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.
