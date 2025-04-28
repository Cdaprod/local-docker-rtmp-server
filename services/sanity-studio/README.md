# Video Render Studio (Dockerized)

This is a fully containerized Sanity Studio setup.

## Setup

Edit `.env` to match your Sanity project:

```bash
NEXT_PUBLIC_SANITY_PROJECT_ID=your_project_id_here
NEXT_PUBLIC_SANITY_DATASET=production

cd services/sanity-studio
docker-compose up --build

### non-docker
yarn install
yarn dev
``` 


---

# `/services/sanity-studio/sanity.config.ts`
*(no changes needed from earlier, still good for Yarn and Docker)*

# `/services/sanity-studio/schemas/videoRenderJob.ts` and `/schemas/schema.ts`
*(no changes needed)*

---

# **Summary: What You Now Have**

| Component      | Status        | Details                                |
|----------------|----------------|----------------------------------------|
| Package Manager | Yarn | `yarn install`, `yarn dev` |
| Dockerfile      | Created        | Node 20, Sanity CLI, runs dev server |
| Docker Compose  | Created        | Easy `docker-compose up` |
| .env Usage      | Supported      | Clean separation for multiple environments |
| Local Dev       | Yarn or Docker | Both work |

---

# Next Steps?

- Sanity-Studio → FastAPI Blender API → MinIO
- Metadata-service
- Flow of Render Job
- OBS and TouchDesigner...?

 