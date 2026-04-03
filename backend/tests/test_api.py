import pytest


@pytest.mark.asyncio
async def test_upload_video(client, test_video_path):
    with open(test_video_path, "rb") as f:
        response = await client.post(
            "/api/videos/upload",
            files={"file": ("video_1.mp4", f, "video/mp4")},
        )
    assert response.status_code == 200
    data = response.json()
    assert "video_id" in data
    assert data["filename"] == "video_1.mp4"
    assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_list_videos(client, test_video_path):
    # Upload first
    with open(test_video_path, "rb") as f:
        await client.post(
            "/api/videos/upload",
            files={"file": ("video_1.mp4", f, "video/mp4")},
        )
    response = await client.get("/api/videos")
    assert response.status_code == 200
    videos = response.json()["videos"]
    assert len(videos) >= 1


@pytest.mark.asyncio
async def test_get_video_details(client, test_video_path):
    with open(test_video_path, "rb") as f:
        upload = await client.post(
            "/api/videos/upload",
            files={"file": ("video_1.mp4", f, "video/mp4")},
        )
    video_id = upload.json()["video_id"]
    response = await client.get(f"/api/videos/{video_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["video_id"] == video_id
    assert data["metadata"]["fps"] > 0


@pytest.mark.asyncio
async def test_get_nonexistent_video(client):
    response = await client.get("/api/videos/nonexistent")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_upload_invalid_extension(client):
    response = await client.post(
        "/api/videos/upload",
        files={"file": ("test.txt", b"not a video", "text/plain")},
    )
    assert response.status_code == 400
