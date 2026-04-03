from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.core.config import settings
from app.services.video_service import scan_existing


@asynccontextmanager
async def lifespan(app: FastAPI):
    scan_existing()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="MeeHawk", description="Volleyball video analysis API", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(router)

    return app


app = create_app()
