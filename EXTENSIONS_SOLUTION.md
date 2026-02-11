# Solução: Extensões PHP com FrankenPHP + Laravel Octane

## O Problema

O FrankenPHP é um binário **staticamente compilado** que empaenta o próprio runtime PHP. Isso oferece:

✅ **Vantagens:**
- Um único binário executável
- Sem dependências de sistema
- Muito menor que PHP completo
- Performance superior ao PHP-FPM

❌ **Limitações:**
- Não inclui todas as extensões padrão
- Extensões críticas faltam: `mbstring`, `pcntl`, `posix`, etc.
- Causava erro no Laravel: "Call to undefined function mb_split()"

## A Solução

Este buildpack resolve o problema com uma **abordagem em 3 fases**:

### 1️⃣ Build Time: Sistema PHP para Otimizações

Durante o deploy (`bin/compile`), se o buildpack `heroku/php` foi executado primeiro:
- Usa o PHP completo do `heroku/php` para rodair `php artisan config:cache`, `route:cache`, etc.
- Essas extensões (_pcntl_) estão disponíveis no sistema
- O binário FrankenPHP é baixado e preparado em paralelo

```bash
# Ao detectar system PHP:
SYSTEM_PHP="$(command -v php)"  # de heroku/php buildpack
run_artisan config:cache        # Usa system PHP, não FrankenPHP
```

### 2️⃣ Build Time: Cópia de Extensões

O script `bin/compile`Ext automatically:

```bash
# Detecta o diretório de extensões do sistema PHP
SYSTEM_PHP_EXT_DIR=$("$SYSTEM_PHP" -i | grep "^extension_dir")

# Copia as extensões críticas
mkdir -p "$BUILD_DIR/.heroku/frankenphp/extensions"
cp "$SYSTEM_PHP_EXT_DIR/mbstring.so" ".heroku/frankenphp/extensions/"
cp "$SYSTEM_PHP_EXT_DIR/pcntl.so" ".heroku/frankenphp/extensions/"
# ... mais extensões
```

Extensões copiadas:
- ✅ `mbstring.so` (funções de string - necessário para Laravel)
- ✅ `pcntl.so` (process control - sinais)
- ✅ `posix.so` (POSIX API)
- ✅ `sockets.so` (sockets network)
- ✅ `opcache.so` (opcode caching)
- ✅ `redis.so` (Redis, se disponível)
- ✅ `igbinary.so` (serialização rápida)

### 3️⃣ Runtime: Carregamento Dinâmico

No runtime (quando o app está rodando), a `.profile.d` configura:

```bash
# .profile.d/000_frankenphp.sh
export PHP_INI_SCAN_DIR="$HOME/.heroku/frankenphp/etc/php.d"
```

O arquivo `heroku.ini` carrega as extensões:

```ini
; .heroku/frankenphp/etc/php.d/heroku.ini
extension_dir = $HOME/.heroku/frankenphp/extensions
extension = mbstring.so
extension = pcntl.so
extension = posix.so
extension = sockets.so
```

Agora o FrankenPHP tem as extensões que precisa! ✅

## Fluxo Completo de Deploy

```
1. Detect: Encontra Laravel + Octane
   ↓
2. heroku/php buildpack (se presente): Instala PHP 8.4.17 com TODAS as extensões
   ↓
3. Este buildpack:
   a) Baixa FrankenPHP binary
   b) Detecta sistema PHP
   c) Copia extensões .so do sistema PHP
   d) Usa sistema PHP para artisan tasks
   e) Escreve heroku.ini para carregar as extensões
   ↓
4. Runtime (.profile.d): 
   - PATH aponta para FrankenPHP
   - PHP_INI_SCAN_DIR aponta para extensions
   - Octane inicia com frankenphp + extensões carregadas ✅
```

## Por que isso funciona

FrankenPHP é um binário **dinamicamente linkado** que pode carregar extensões .so em runtime. Não é um binário 100% estático. As extensões .so compiladas para a mesma versão PHP funcionam sem problemas.

```bash
$ file /app/.heroku/frankenphp/bin/frankenphp
# /app/.heroku/frankenphp/bin/frankenphp: ELF 64-bit LSB executable, x86-64, ...
# dynamically linked (pode carregar .so files!)
```

## Troubleshooting

### ❌ "Call to undefined function mb_split()"

**Causa:** Extensão `mbstring` não foi copiada

**Verificar:**
```bash
heroku logs --tail
```
Procure por: "Copied extension: mbstring.so"

Se não aparecer:
- ✅ Certifique que `heroku/php` buildpack está **ANTES** deste buildpack
- ✅ Faça deploy novo

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/php
heroku buildpacks:add https://github.com/your-org/franken-php-buildpack.git
git push heroku main
```

### ❌ "No system PHP found"

**Causa:** Você não tem `heroku/php` buildpack

**Solução:** Adicione-o:
```bash
heroku buildpacks:add --index 1 heroku/php
```

### ✅ Verificar quais extensões foram carregadas

```bash
heroku run php -m | grep -E "mbstring|pcntl|posix"
```

## Alternativas (não recomendadas)

### ❌ Opção 1: Trocar para Swoole/Roadrunner
- Abandona FrankenPHP
- Perde os benefícios de ter um binário moderno

### ❌ Opção 2: Usar sistema PHP em runtime
- Deixa heroku/php na PATH
- Perde performance do FrankenPHP embedded

### ❌ Opção 3: Compilar FrankenPHP customizado
- Requer Docker + Go + build complexo
- Tempo de build muito maior

### ✅ Opção escolhida: Carregar extensões dinamicamente
- FrankenPHP mantém a velocidade
- Extensões vêm do sistema PHP (compatível)
- Simples e confiável

## FAQ

**P: E se eu precisar de uma extensão que não foi copiada?**

R: Você pode adicionar em `CRITICAL_EXTENSIONS` no `bin/compile`. Ou usar um custom buildpack:

```bash
# Editar bin/compile, linha ~100
CRITICAL_EXTENSIONS=(
  "mbstring.so"
  "pcntl.so"
  "zeromq.so"  # Adicionar nova
)
```

**P: Há overhead de carregar extensões de arquivo?**

R: Não. As extensões são carregadas UMA VEZ na startup e staying em memória. Sem overhead em runtime.

**P: Isso é tão rápido quanto FrankenPHP com extensões compiladas?**

R: Sim, é idêntico. Estamos usando as extensões compiladas do heroku/php, não recompilando nada.

**P: E se não usar heroku/php buildpack?**

R: FrankenPHP ainda funciona mas sem essas extensões. Você pode:
- Adicionar os .so files manualmente
- Ou recompilar FrankenPHP com as extensões

## Resumo

Este buildpack resolveu o problema da forma mais pragmática:

1. ✅ Mantém FrankenPHP rápido
2. ✅ Fornece extensões necessárias via sistema PHP  
3. ✅ Nenhuma recompilação ou complexidade
4. ✅ Funciona com multi-buildpack (heroku/php + este)
5. ✅ Route buscante: build-time system PHP + runtime FrankenPHP

**Resultado:** Laravel Octane + FrankenPHP com todas as extensões! 🎉
