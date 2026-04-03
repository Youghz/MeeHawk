import { useState, useEffect, useRef, useCallback } from 'react';
import { getVideos, getVideo, getSourceVideoUrl, getActiveJobs } from '../services/api';
import VideoUploader from '../components/VideoUploader';
import VideoLibrary from '../components/VideoLibrary';
import AnalysisView from '../components/AnalysisView';

export default function Dashboard() {
  const [videos, setVideos] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [selectedVideo, setSelectedVideo] = useState(null);
  const [jobs, setJobs] = useState([]);
  const pollRef = useRef(null);

  const refresh = useCallback(async () => {
    const [list, activeJobs] = await Promise.all([getVideos(), getActiveJobs()]);
    setVideos(list);
    setJobs(activeJobs);
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  // Poll when there are active jobs or processing videos
  useEffect(() => {
    const hasActive = jobs.length > 0 || videos.some((v) => v.status === 'processing');
    clearInterval(pollRef.current);
    if (hasActive) {
      pollRef.current = setInterval(refresh, 2000);
    }
    return () => clearInterval(pollRef.current);
  }, [videos, jobs, refresh]);

  useEffect(() => {
    if (!selectedId) { setSelectedVideo(null); return; }
    getVideo(selectedId).then(setSelectedVideo);
  }, [selectedId, videos]);

  function handleUploaded(videoId) {
    refresh();
    setSelectedId(videoId);
    setTimeout(refresh, 500);
  }

  return (
    <div className="dashboard">
      <header>
        <h1>MeeHawk</h1>
        <p>Volleyball Video Analysis</p>
      </header>

      <div className="layout">
        <aside className="sidebar">
          <VideoLibrary
            videos={videos}
            jobs={jobs}
            selectedId={selectedId}
            onSelect={setSelectedId}
            onRefresh={refresh}
            onDelete={(id) => {
              if (selectedId === id) setSelectedId(null);
              refresh();
            }}
          />
          <div className="upload-zone">
            <h3>Add Video</h3>
            <VideoUploader onUploaded={handleUploaded} />
          </div>
        </aside>

        <main className="main-area">
          {!selectedId ? (
            <div className="empty-panel">
              <p>Select a video from the library or upload a new one</p>
            </div>
          ) : selectedVideo?.status === 'completed' ? (
            <AnalysisView videoId={selectedId} />
          ) : selectedId ? (
            <div className="preview-panel">
              <video
                key={selectedId}
                controls
                preload="metadata"
                width="100%"
                src={getSourceVideoUrl(selectedId)}
              />
            </div>
          ) : null}
        </main>
      </div>
    </div>
  );
}
