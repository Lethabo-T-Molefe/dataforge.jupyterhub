# DataForge notebooks

JupyterLab 4.6, configured as DataForge's notebook surface. It is deployed on its own and connected to the
DataForge API ([`dataforge.backend`](https://github.com/Lethabo-T-Molefe/dataforge.backend)) through settings:
nothing here imports the API's code.

This is a single shared JupyterLab server, not JupyterHub (see [Limits](#limits)).

What this repo adds to stock JupyterLab:

- **Single sign-on from DataForge** (`dataforge_jupyter/auth.py`). Members with code roles (administrator,
  steward, practitioner, curator) open JupyterLab from DataForge with a two-minute, single-use token signed
  with `SSO_SHARED_SECRET`. There is no Jupyter password or login token.
- **Per-member folders and kernels.** A member works in `members/<their id>/` and `shared/`. Other members'
  folders and terminals are refused, and a kernel belongs to the member who started it.
- **Governed data only.** A kernel holds no database password. It starts with the member's own notebook
  token and reads data through the DataForge API with the bundled `dataforge` library, so the member's
  permissions, masking and row policies apply:

  ```python
  import dataforge as df

  df.datasets()
  df.sql("SELECT region, SUM(revenue) FROM gold.revenue_by_region GROUP BY 1")
  ```

  or `%load_ext dataforge` and a `%%sql` cell.
- **The DataForge look** (`dataforge_jupyter/custom`, `overrides.json`): theme, logo, title.

It is served under `/jupyter/`.

## Settings

Copy `.env.example` to `.env` for local runs; on a host, set the same names as environment variables.

| Setting | What it is |
| --- | --- |
| `SSO_SHARED_SECRET` | **Must equal the API's `SSO_SHARED_SECRET`.** |
| `JUPYTER_API_TOKEN` | The token the API uses to save notebooks here. **Must equal the API's `JUPYTER_API_TOKEN`.** |
| `DATAFORGE_API_URL` | Where kernels reach the API, without `/api/v1`. On Render, the API's internal address. |
| `DATAFORGE_JWT_ISSUER` | Must equal the API's `JWT_ISSUER` (`dataforge` by default). |
| `DATAFORGE_FRONTEND_ORIGINS` | The web app's address(es), comma-separated. Only these may frame JupyterLab. |
| `JUPYTER_PORT` / `PORT` | The port to listen on (default 8888). Render sets `PORT`. |
| `JUPYTER_WORKSPACE` | Where notebooks are kept (`./workspace` locally, `/workspace` in the container). |

## Connecting it to the DataForge API

In the **API's** settings:

| API setting | Value |
| --- | --- |
| `JUPYTER_URL` | Where the API reaches this server, ending in `/jupyter`. On Render, the internal address. |
| `JUPYTER_PUBLIC_URL` | Where browsers reach it, if different from `JUPYTER_URL`. |
| `JUPYTER_API_TOKEN` | The same value as here. |
| `SSO_SHARED_SECRET` | The same value as here. |

Members then open notebooks from the web app, and "Open in Jupyter" on any generated SQL or DataForge
notebook saves it into their folder here.

## Running locally

Python 3.12 and [uv](https://docs.astral.sh/uv/). On Linux and macOS use `.venv/bin/python`.

```bash
uv venv --python 3.12 .venv
uv pip install --python .venv/Scripts/python.exe -r requirements.txt
cp .env.example .env                    # fill in the two shared secrets
.venv/Scripts/python run.py             # http://localhost:8888/jupyter
```

## Deploying on Render

`render.yaml` describes the service: a Docker web service in Frankfurt on the 2 GB plan, with a 5 GB disk
mounted at `/workspace` and a health check at `/jupyter/api`. In Render choose **New > Blueprint**, pick this
repo, and fill in the four values it asks for (`SSO_SHARED_SECRET`, `JUPYTER_API_TOKEN`, `DATAFORGE_API_URL`,
`DATAFORGE_FRONTEND_ORIGINS`). Deploys wait for this repo's GitHub checks to pass.

- **The disk matters.** Without it every member's notebooks are lost on each deploy or restart. A service
  with a disk runs as one instance and is briefly down during a deploy.
- A mounted disk arrives owned by root. `entrypoint.sh` gives it to the unprivileged `jupyter` user and then
  runs the server as that user.
- Give the service a subdomain of the same domain as the web app (for example `notebooks.yourdomain.com`),
  so sign-in works without third-party cookies.

## Limits

- **One server for everyone.** Folders, kernels and data access are separated per member, but every kernel
  runs as the same operating-system user, so code in a notebook can read another member's notebook files.
  Data itself stays governed, because it only arrives through the API. For hard isolation between members,
  run JupyterHub with a container per member and the same `dataforge` library.
- **Sign-ins are kept in memory**, so members sign in again (one click from DataForge) after a restart, and
  the service cannot run as more than one instance.

## Checks

```bash
uvx ruff check . && uvx ruff format --check .
docker build -t dataforge-notebooks .
```

GitHub Actions runs both on every push, and also starts the container on a root-owned folder to check that
JupyterLab answers and can write to a mounted disk (`.github/workflows/ci.yml`).
