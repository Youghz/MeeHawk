import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.config import settings
from app.main import app


@pytest.fixture
def test_video_path():
    path = settings.VIDEOS_DIR / "video_1.mp4"
    assert path.exists(), f"Test video not found at {path}"
    return path


@pytest.fixture
def test_video_2_path():
    path = settings.VIDEOS_DIR / "video_2.mp4"
    assert path.exists(), f"Test video not found at {path}"
    return path


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
