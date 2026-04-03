import { analyzeVideo, deleteVideo } from '../services/api';

const STATUS_LABELS = {
  pending: 'Pending',
  processing: 'Processing',
  completed: 'Completed',
  failed: 'Failed',
};

const STATUS_ICONS = {
  pending: '\u23F3',
  processing: '\u2699\uFE0F',
  completed: '\u2705',
  failed: '\u274C',
};

export default function VideoList({ videos, selectedId, onSelect, onRefresh, onAnalyzeStarted }) {
  async function handleAnalyze(e, videoId) {
    e.stopPropagation();
    try {
      await analyzeVideo(videoId);
      onRefresh?.();
      onAnalyzeStarted?.();
    } catch (err) {
      alert('Failed: ' + (err.response?.data?.detail || err.message));
    }
  }

  async function handleDelete(e, videoId) {
    e.stopPropagation();
    if (!confirm('Delete this video?')) return;
    await deleteVideo(videoId);
    onRefresh?.();
  }

  if (!videos.length) {
    return <p className="empty">No videos uploaded yet.</p>;
  }

  return (
    <ul className="video-list">
      {videos.map((v) => (
        <li
          key={v.video_id}
          className={`video-item ${v.video_id === selectedId ? 'selected' : ''}`}
          onClick={() => onSelect(v.video_id)}
        >
          <div className="video-info">
            <strong>{v.original_name}</strong>
            <span className={`status ${v.status}`}>
              {STATUS_ICONS[v.status]} {STATUS_LABELS[v.status]}
            </span>
          </div>
          <div className="video-actions">
            {v.status === 'pending' && (
              <button onClick={(e) => handleAnalyze(e, v.video_id)}>Analyze</button>
            )}
            {v.status === 'failed' && (
              <button onClick={(e) => handleAnalyze(e, v.video_id)}>Retry</button>
            )}
            <button className="delete" onClick={(e) => handleDelete(e, v.video_id)}>
              {'\u2715'}
            </button>
          </div>
          {v.status === 'processing' && v.progress && (
            <div className="mini-progress">
              <div
                className="progress-bar"
                style={{ width: `${v.progress.percent || 0}%` }}
              />
              <span>{v.progress.percent || 0}%</span>
            </div>
          )}
        </li>
      ))}
    </ul>
  );
}
