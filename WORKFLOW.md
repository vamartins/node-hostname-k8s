# Workflow de Deploy via CI/CD

## Fluxo Simplificado

### 1. Para mudar a versão da aplicação:

**Edite apenas o Dockerfile:**
```dockerfile
# ANTES
ARG APP_VERSION=1.0.0

# DEPOIS  
ARG APP_VERSION=2.0.0
```

### 2. Deploy para Staging:

```bash
git checkout develop
git add Dockerfile
git commit -m "feat: update to v2.0.0"
git push origin develop
```

**A pipeline automaticamente:**
- Extrai versão 2.0.0 do Dockerfile
- Build: `vamartins/node-hostname:develop` e `:2.0.0`
- Push para Docker Hub
- Deploy para Staging

**Verificar:**
```bash
curl http://localhost:8080
# {"hostname":"pod-xxx","version":"2.0.0"}
```

### 3. Deploy para Production:

```bash
git checkout main
git merge develop
git push origin main
```

**A pipeline:**
- Build: `vamartins/node-hostname:latest` e `:2.0.0`
- Push para Docker Hub
- **AGUARDA APROVAÇÃO MANUAL**

**Aprovar:**
- GitHub → Actions → Deploy Application
- Click "Review deployments" → Approve

**Verificar:**
```bash
curl http://localhost:9080
# {"hostname":"pod-xxx","version":"2.0.0"}
```

## Configuração Inicial no GitHub

### 1. Secrets
Settings → Secrets → Actions → New:
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

### 2. Environment Production
Settings → Environments → New environment:
- Nome: `production`
- Required reviewers: [seu usuário]
- Save

## Comandos Úteis

```bash
# Ver versão em execução
curl http://localhost:8080 | jq .version  # Staging
curl http://localhost:9080 | jq .version  # Production

# Ver imagem nos pods
kubectl get pods -n node-hostname-staging -o jsonpath='{.items[0].spec.containers[0].image}'
kubectl get pods -n node-hostname -o jsonpath='{.items[0].spec.containers[0].image}'
```

## Resumo

**Para atualizar a versão:**
1. Mude `ARG APP_VERSION=X.X.X` no Dockerfile
2. Commit e push para `develop`
3. Pipeline deploya staging automaticamente
4. Merge para `main`
5. Aprove o deploy para production
6. Pronto!

**A versão do Dockerfile é a fonte da verdade.**
