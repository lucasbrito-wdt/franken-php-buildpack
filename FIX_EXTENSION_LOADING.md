# Fix para Erro de Extensões PHP Não Carregadas

## 🐛 Problema Identificado

Rails executou com erro:
```
PHP Warning: Unable to load dynamic library 'mbstring.so' 
(tried: $HOME/.heroku/frankenphp/extensions/mbstring.so: cannot open shared object file)

Error: Call to undefined function mb_split()
```

**Causa:** O arquivo `heroku.ini` estava usando `$HOME` como caminho ao invés do path absoluto `/app`.

## ✅ O que foi corrigido

### Arquivo: `bin/compile`

**Antes:**
```bash
EXTENSIONS_LOAD="
extension_dir = \$HOME/.heroku/frankenphp/extensions
"
```

**Depois:**
```bash
EXTENSIONS_LOAD="
extension_dir = /app/.heroku/frankenphp/extensions
"
```

**Por quê?** Em tempo de runtime no Heroku, `$HOME` não é uma variável válida no contexto de PHP. O caminho correto é sempre `/app/` (home directory do dyno).

### Arquivo: `bin/compile` (melhorias adicionais)

1. **Verificação de permissões**
   - Agora executa `chmod 755` nas extensões copiadas
   - Garante que os arquivos `.so` têm permissão de execução

2. **Verificação de cópia**
   - Conta quantas extensões foram copiadas
   - Avisa se nenhuma foi copiada

3. **Logging melhorado**
   - Mostra aviso se nenhuma extensão for encontrada
   - Instruções sobre adicionar `heroku/php` buildpack

### Arquivo: `README.md` (novo)

Adicionada seção "Diagnosticar extensões em runtime" com:
- Script para verificar estado das extensões
- Exemplos de output esperado
- Troubleshooting de problemas comuns

### Arquivo: `diagnostics/check-extensions.sh` (novo)

Script para executar em runtime e diagnosticar:
```bash
heroku run bash diagnostics/check-extensions.sh
```

## 🚀 Como fazer o novo deploy

### 1. Puxe as mudanças mais recentes

```bash
git pull origin master
# ou
git fetch && git merge origin/master
```

### 2. Faça um novo deploy

```bash
git push heroku main
# ou se usando branch diferente
git push heroku your-branch:main
```

### 3. Monitore o build

```bash
heroku logs --tail
```

Procure por:
```
-----> FrankenPHP (Laravel Octane) app detected
Copied extension: mbstring.so
Copied extension: pcntl.so
Extensions loaded:
  - /tmp/build_*/...heroku/frankenphp/extensions/mbstring.so
  ...
```

### 4. Verifique em runtime

```bash
heroku run bash diagnostics/check-extensions.sh
```

Deve mostrar:
```
✅ Extensions directory exists: /app/.heroku/frankenphp/extensions
Files in extensions directory:
  /app/.heroku/frankenphp/extensions/mbstring.so
```

### 5. Teste a aplicação

```bash
curl https://seu-app.herokuapp.com/
heroku ps
heroku logs --tail
```

## 📋 Checklist de Verificação

- [ ] Buildpack foi atualizado com novos arquivos
- [ ] Deploy completou sem erros
- [ ] `heroku logs` mostra extensões sendo copiadas
- [ ] `heroku run bash diagnostics/check-extensions.sh` mostra extensões carregadas
- [ ] `php -m` mostra `mbstring` na lista
- [ ] Aplicação responde sem erro de `mb_split()`
- [ ] Octane começou com sucesso: `heroku ps` mostra `web` dyno em execução

## ❓ E se o problema persistir?

### Cenário 1: "❌ Extensions directory NOT found"

```bash
# O diretório não foi criado durante o build
# Motivos possíveis:
# - heroku/php buildpack não foi rodado
# - Caminho errado no script

# Solucionar:
heroku buildpacks:clear
heroku buildpacks:add heroku/php
heroku buildpacks:add https://github.com/lucasbrito-wdt/franken-php-buildpack
git push heroku main
```

### Cenário 2: "❌ Extension NOT loaded but file exists"

```bash
# O arquivo está lá mas não foi carregado
# Motivos possíveis:
# - Permissões incorretas
# - Incompatibilidade de libc (gnu vs musl)

# Verificar:
heroku run ldd /app/.heroku/frankenphp/extensions/mbstring.so
heroku run file /app/.heroku/frankenphp/extensions/mbstring.so

# Tentar musl em vez de gnu:
heroku config:set FRANKENPHP_LIBC=musl
git push heroku main
```

### Cenário 3: "php -m shows mbstring but mb_split still fails"

```bash
# Extensão carregou mas função não disponível
# Motivo possível:
# - FrankenPHP não consegue usar extensão do heroku/php

# Fallback: Usar PHP-FPM ao invés de Octane
# (Não recomendado, pior performance)
```

## 📞 Support

Se problemassistir:

1. Coleta de logs:
```bash
heroku logs --source app > /tmp/heroku.log
heroku run bash diagnostics/check-extensions.sh > /tmp/diag.log
```

2. Compare com esperado em `README.md` seção "Diagnosticar"

3. Verifique `EXTENSIONS_SOLUTION.md` para entender a arquitetura

## 📝 Notas Técnicas

### Por que o caminho precisa ser `/app`?

- **Build time (Heroku)**: Código está em `/tmp/build_*/`
- **Runtime (Dyno)**: Código é extraído em `/app/`
- **PHP.ini**: Precisa ser processado em **runtime**, não build time
- **Solução**: Usar caminho absoluto `/app` que é sempre válido em runtime

### Por que não usar `$HOME`?

- `$HOME` é uma variável shell, não PHP
- Em `.ini` files, variáveis shell NÃO são expandidas
- FrankenPHP procura literalmente por `$HOME` como diretório
- Resultado: "arquivo não encontrado"

### Como FrankenPHP carrega extensões?

```
1. FrankenPHP inicia
2. Lê PHP.ini: extension_dir = /app/.heroku/frankenphp/extensions
3. Lê PHP.ini: extension = mbstring.so
4. dlopen("/app/.heroku/frankenphp/extensions/mbstring.so")
5. Registra funções: mb_split(), mb_strlen(), etc.
6. Pronto! Funções disponíveis ao rodar artisan
```

## ✅ Conclusão

As correções garantem que:
- ✅ Extensões são copiadas do `heroku/php` buildpack
- ✅ Caminho correto `/app` é usado (não `$HOME`)
- ✅ Permissões são ajustadas (`chmod 755`)
- ✅ Logging mostra o que aconteceu
- ✅ Script de diagnóstico facilita troubleshooting

Faça o deploy e tudo deve funcionar! 🎉
