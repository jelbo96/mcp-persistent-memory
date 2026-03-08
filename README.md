# MCP Persistent Memory

Memoria persistente para agentes AI usando [Redis Agent Memory Server](https://github.com/redis/agent-memory-server). Permite que cualquier agente con soporte MCP (Cursor, Claude Code, Windsurf, Cline, etc.) recuerde preferencias, decisiones de arquitectura y convenciones entre sesiones y a traves de multiples repositorios.

## Arquitectura

```
MCP Client (cualquier agente) <--SSE--> MCP Server (:9050) <--> Redis (vector search + persistencia)
                                        REST API (:18000)
                                        Task Worker (background)
```

- **Anthropic** (Claude) para generacion, extraccion de topics y procesamiento de texto
- **OpenAI** para embeddings vectoriales (`text-embedding-3-small`)
- **Redis Stack** para almacenamiento persistente con busqueda vectorial

## Requisitos

- Docker y Docker Compose
- API key de Anthropic (`ANTHROPIC_API_KEY`)
- API key de OpenAI (`OPENAI_API_KEY`) - solo para embeddings

## Setup

### 1. Configurar API keys

```bash
cp .env.example .env
```

Editar `.env` con tus keys reales:

```
ANTHROPIC_API_KEY=sk-ant-tu-key-aqui
OPENAI_API_KEY=sk-tu-key-aqui
```

### 2. Levantar servicios

```bash
docker compose up -d
```

Esto levanta 4 servicios:

| Servicio | Puerto | Descripcion |
|---|---|---|
| Redis | 63790 | Almacenamiento persistente + vector search |
| API | 18000 | REST API ([Swagger UI](http://localhost:18000/docs)) |
| MCP | 9050 | Servidor MCP via SSE |
| Task Worker | - | Procesamiento en background (extraccion de memorias, compaction) |

### 3. Conectar tu agente

El servidor MCP se expone via SSE en `http://localhost:9050/sse`. Configuralo segun tu cliente:

**Cursor** — agregar a `~/.cursor/mcp.json` (global) o `.cursor/mcp.json` (por proyecto):

```json
{
  "mcpServers": {
    "redis-memory-server": {
      "url": "http://localhost:9050/sse"
    }
  }
}
```

**Claude Code** — agregar a `~/.claude/settings.json` o `.claude/settings.json` (por proyecto):

```json
{
  "mcpServers": {
    "redis-memory-server": {
      "type": "sse",
      "url": "http://localhost:9050/sse"
    }
  }
}
```

**Otros agentes MCP** — cualquier cliente que soporte transporte SSE puede conectarse a `http://localhost:9050/sse`.

### 4. Verificar que funciona

- Abrir [http://localhost:18000/docs](http://localhost:18000/docs) para ver la API
- Pedirle al agente: "Guarda en memoria que prefiero TypeScript estricto" - deberia llamar `create_long_term_memories`
- Luego pedir: "Busca en memoria mis preferencias" - deberia llamar `search_long_term_memory`

## Herramientas MCP disponibles

El servidor expone estas herramientas que cualquier agente MCP puede usar:

| Herramienta | Descripcion |
|---|---|
| `create_long_term_memories` | Guardar memorias persistentes (semantic, episodic, message) |
| `search_long_term_memory` | Buscar memorias por similitud semantica + filtros |
| `get_long_term_memory` | Obtener una memoria especifica por ID |
| `edit_long_term_memory` | Editar una memoria existente |
| `delete_long_term_memories` | Eliminar memorias por ID |
| `set_working_memory` | Guardar memoria de sesion (se promueve automaticamente a long-term) |
| `memory_prompt` | Generar un prompt enriquecido con contexto de memorias relevantes |

## Organizacion de memorias (per-repo)

Cada memoria se identifica con:

| Campo | Valor | Proposito |
|---|---|---|
| `user_id` | `"ignaciojelvez"` | Identificar al usuario |
| `namespace` | `"agent"` | Agrupar memorias del agente |
| `session_id` | `"repo:<nombre>"` | Aislar memorias por repositorio |

Esto permite buscar solo en un repo (filtrando por `session_id`) o globalmente (omitiendo `session_id`).

## Inspeccionar memorias

### Swagger UI

Abrir [http://localhost:18000/docs](http://localhost:18000/docs) para explorar y probar los endpoints de la API directamente desde el browser.

### RedisInsight (GUI)

Para inspeccionar Redis directamente con una interfaz visual:

```bash
docker compose --profile debug up -d redis-insight
```

Abrir [http://localhost:16381](http://localhost:16381) y conectar a `redis:6379`.

### curl

```bash
curl -s http://localhost:18000/v1/long-term-memory/search \
  -H "Content-Type: application/json" \
  -d '{"query": "preferencias typescript", "user_id": "ignaciojelvez", "namespace": "agent"}' \
  | python3 -m json.tool
```

## Git hook (ingesta automatica de commits)

El script `scripts/post-commit-hook.sh` envia automaticamente un resumen de cada commit como memoria episodica. Para instalarlo en un repo:

```bash
cp scripts/post-commit-hook.sh <tu-repo>/.git/hooks/post-commit
chmod +x <tu-repo>/.git/hooks/post-commit
```

Cada commit genera una memoria con el mensaje, archivos modificados, y se asocia al repo via `session_id`.

## Comandos utiles

```bash
# Levantar todo
docker compose up -d

# Levantar con RedisInsight
docker compose --profile debug up -d

# Ver logs
docker compose logs -f

# Ver logs de un servicio especifico
docker compose logs -f mcp

# Reiniciar despues de cambiar .env (IMPORTANTE: no usar restart, no re-lee el .env)
docker compose down && docker compose up -d

# Parar todo
docker compose down

# Parar y borrar datos
docker compose down -v
```

## Agent rules

El archivo `.cursor/rules/memory.mdc` incluye instrucciones para que el agente:

1. **Antes de responder** preguntas sobre arquitectura o convenciones: buscar en memoria del repo actual
2. **Despues de tomar decisiones**: guardar un resumen como memoria persistente
3. Usar la convencion de `user_id` / `namespace` / `session_id` para organizar memorias per-repo

Puedes adaptar estas reglas al formato de tu agente (e.g. `CLAUDE.md` para Claude Code, `.windsurfrules` para Windsurf, etc.).

## Seguridad

- `DISABLE_AUTH=true` esta configurado para desarrollo local
- Para uso en red o equipo compartido, cambiar a `AUTH_MODE=token` y configurar HTTPS
- No guardar secretos (API keys, passwords) como memorias
- El `.env` esta en `.gitignore` y nunca se sube al repo
